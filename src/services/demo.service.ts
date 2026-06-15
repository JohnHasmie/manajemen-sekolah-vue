/**
 * Register-demo service — thin wrapper around the Laravel
 * /demo/* and /schools/search endpoints. Mirrors the shape the
 * Pinia store expects (already-parsed objects, no axios leakage).
 */
import { api } from '@/lib/http';
import type {
  DemoPendingResponse,
  DemoWizardPayload,
  SchoolSearchHit,
  MyRegistrationsResponse,
} from '@/types/demo';

interface WizardStateResponse {
  current_step: number;
  payload: DemoWizardPayload | null;
  last_active_at: string;
  completed_at: string | null;
  provisioned_school_id: string | null;
}

export interface NpsnLookupResult {
  kind: 'registry';
  id: null;
  /** Canonical column: `npsn_registry.name` (was `nama`). */
  name: string;
  /** Canonical column: `npsn_registry.education_level` (was `jenjang`). */
  education_level: string | null;
  /** Canonical column: `npsn_registry.city` (was `kota`). */
  city: string | null;
  /** Canonical column: `npsn_registry.province` (was `provinsi`). */
  province: string | null;
  /** Canonical column: `npsn_registry.address` (was `alamat`). */
  address: string | null;
  npsn: string;
  is_demo: false;
  /** Canonical column: `npsn_registry.official_status` (was `status_resmi`). */
  official_status?: string;
  akreditasi?: string | null;
  email?: string | null;
  telepon?: string | null;
  /** Present when the NPSN is already claimed by a Kamiledu tenant. */
  kamiledu_school: {
    id: string;
    /** Canonical column: `schools.name` (was `school_name`). */
    name: string;
    is_demo: boolean;
    demo_owner_user_id: string | null;
  } | null;
}

interface ExpiryInfo {
  school_id: string;
  /** Canonical column: `schools.name` (was `school_name`). */
  name: string;
  is_demo: true;
  expires_at: string | null;
  seconds_remaining: number;
  is_expired: boolean;
  severity: 'normal' | 'warning' | 'danger';
}

export const DemoService = {
  /**
   * Live school search for the wizard's step 2.
   *
   * @param q               partial school name; backend ignores < 2 chars
   * @param education_level optional filter (SD/SMP/etc.) — backend
   *                        param is now `education_level` (was `jenjang`)
   */
  async searchSchools(args: {
    q: string;
    education_level?: string | null;
    limit?: number;
  }): Promise<SchoolSearchHit[]> {
    // The conversational wizard runs BEFORE OAuth — `/api/schools/search`
    // 401s for unauthenticated callers. `/api/demo/schools/search` is
    // the same controller mounted publicly + IP-rate-limited for the
    // pre-login wizard. Falls back to the auth'd alias for older
    // backends that haven't deployed the public alias yet.
    const params = {
      q: args.q,
      education_level: args.education_level ?? undefined,
      limit: args.limit ?? 12,
    };
    try {
      const res = await api.get('/demo/schools/search', { params });
      const body = res.data?.data ?? res.data ?? {};
      return Array.isArray(body.results) ? (body.results as SchoolSearchHit[]) : [];
    } catch {
      try {
        const res = await api.get('/schools/search', { params });
        const body = res.data?.data ?? res.data ?? {};
        return Array.isArray(body.results) ? (body.results as SchoolSearchHit[]) : [];
      } catch {
        return [];
      }
    }
  },

  /**
   * Live NPSN lookup — proxies to api.fazriansyah.eu.org/v1/sekolah
   * via our backend (so we can rate-limit + cache). Returns null
   * when the NPSN isn't in Dapodik / upstream is down.
   */
  async lookupNpsn(npsn: string): Promise<NpsnLookupResult | null> {
    try {
      const res = await api.get('/npsn-lookup', { params: { npsn } });
      const body = res.data?.data;
      return body ?? null;
    } catch {
      return null;
    }
  },

  /**
   * Submit a "Minta akun / akses" request from the wizard's
   * school-match cards. Returns the created request id on success.
   */
  async requestSchoolAccess(args: {
    school_id: string;
    school_type: 'real_school' | 'demo_school';
    requested_role?: 'admin' | 'teacher' | 'parent';
    message?: string;
  }): Promise<{ id: string }> {
    const res = await api.post('/school-access-requests', args);
    const data = res.data?.data ?? res.data;
    return { id: String(data?.id ?? '') };
  },

  /**
   * Resume state from the server. Returns null if the user hasn't
   * started the wizard yet — caller then falls back to localStorage
   * or the defaults.
   */
  async loadWizardState(): Promise<WizardStateResponse | null> {
    const res = await api.get('/demo/wizard-state');
    const body = res.data?.data;
    return body ?? null;
  },

  /**
   * Persist current step + payload server-side. Called debounced on
   * every step change. Best-effort: failures shouldn't block the UI.
   */
  async saveWizardState(args: {
    current_step: number;
    payload: DemoWizardPayload;
  }): Promise<void> {
    try {
      await api.post('/demo/wizard-state', args);
    } catch {
      // Server-side persistence is purely for cross-device resume —
      // localStorage already saved the same data. Don't surface.
    }
  },

  async resetWizardState(): Promise<void> {
    try {
      await api.delete('/demo/wizard-state');
    } catch {
      // ignore — local reset is what the user actually sees.
    }
  },

  /**
   * Self-service "Reset Data Demo" — the authed demo owner asks the
   * backend to wipe their demo school back to a freshly-provisioned
   * state. Ownership is enforced server-side via `demo_owner_user_id`;
   * the client passes no school id (the endpoint shape is "reset MY
   * demo"). `demo_expires_at` is preserved on the new school, so a
   * reset never extends the demo TTL.
   *
   * Optional `payload` overrides the original wizard answers with a
   * fresh configuration; omitted → "restart with the same setup".
   *
   * Heavy work happens server-side (delete + full re-provision) —
   * timeout matches /demo/provision so a slow network doesn't trip
   * ECONNABORTED before the seed work finishes.
   */
  async reset(payload?: DemoWizardPayload): Promise<{
    school_id: string;
    school_name: string;
    demo_expires_at: string | null;
  }> {
    try {
      const res = await api.post(
        '/demo/reset',
        payload ? { payload } : {},
        { timeout: 120_000 },
      );
      const data = res.data?.data;
      if (!data?.school_id) {
        throw new Error('Respons reset demo tidak valid.');
      }
      return {
        school_id: String(data.school_id),
        school_name: String(data.school_name ?? ''),
        demo_expires_at: data.demo_expires_at ? String(data.demo_expires_at) : null,
      };
    } catch (err: unknown) {
      const e = err as { response?: { status?: number; data?: { message?: string } } };
      const status = e.response?.status;
      const msg = e.response?.data?.message;
      if (status === 404) {
        throw new Error(msg ?? 'Anda tidak memiliki sekolah demo aktif.');
      }
      if (status === 422) {
        throw new Error(msg ?? 'Reset demo ditolak oleh server.');
      }
      if (status === 429) {
        throw new Error('Terlalu banyak permintaan reset. Coba lagi dalam beberapa saat.');
      }
      throw new Error(msg ?? 'Gagal mereset data demo. Mohon coba lagi.');
    }
  },

  /**
   * Submit the final demo request. The endpoint is still
   * `POST /demo/provision` (kept backward-compatible) but it no longer
   * activates a demo — it validates the wizard payload + requester
   * identity and records a PENDING demo request that the KamilEdu team
   * approves manually later. Returns the pending receipt
   * ({ demo_request_id, status, submitted_at }) so the wizard can
   * show the "request received" confirmation.
   *
   * Translates the common 429 / 422 / 500 axios failures into
   * user-facing Bahasa Indonesia messages so the wizard's red banner
   * doesn't show "Request failed with status code 429".
   */
  async provision(payload: DemoWizardPayload): Promise<DemoPendingResponse> {
    try {
      // Submit is a light insert now (no heavy seeding), but keep a
      // generous timeout so a slow network never trips ECONNABORTED
      // before the request lands.
      const res = await api.post('/demo/provision', payload, {
        timeout: 60_000,
      });
      const data = res.data?.data;
      if (!data?.demo_request_id) {
        throw new Error('Respons permintaan demo tidak valid.');
      }
      return data as DemoPendingResponse;
    } catch (e: unknown) {
      const err = e as {
        code?: string;
        response?: { status?: number; data?: { message?: string; errors?: unknown } };
        message?: string;
      };
      // Axios timeout: ECONNABORTED with message "timeout of XXXms exceeded".
      if (err.code === 'ECONNABORTED' || /timeout/i.test(err.message ?? '')) {
        throw new Error(
          'Pengiriman memakan waktu lebih lama dari biasanya. Periksa koneksi Anda lalu coba lagi.',
        );
      }
      const status = err.response?.status;
      const backendMsg = err.response?.data?.message;
      if (status === 429) {
        throw new Error(
          'Terlalu banyak percobaan dalam waktu singkat. Tunggu sekitar 1 menit, lalu coba lagi.',
        );
      }
      if (status === 422) {
        throw new Error(backendMsg ?? 'Data belum lengkap. Cek kembali setiap langkah.');
      }
      if (status === 500 || status === 503) {
        throw new Error(
          backendMsg ?? 'Server bermasalah saat mengirim permintaan. Coba lagi sebentar.',
        );
      }
      throw new Error(backendMsg ?? err.message ?? 'Gagal mengirim permintaan demo.');
    }
  },

  /**
   * Live countdown for the dashboard banner. Returns null on
   * non-demo schools — caller hides the banner.
   */
  async getExpiry(): Promise<ExpiryInfo | null> {
    try {
      const res = await api.get('/demo/expiry');
      const body = res.data?.data;
      return body ?? null;
    } catch {
      return null;
    }
  },

  async getMyRegistrations(): Promise<MyRegistrationsResponse> {
    try {
      const res = await api.get('/demo/my-registrations');
      const data = res.data?.data;
      return data ?? { demo_requests: [], active_schools: [] };
    } catch {
      return { demo_requests: [], active_schools: [] };
    }
  },
};
