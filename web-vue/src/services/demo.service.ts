/**
 * Register-demo service — thin wrapper around the Laravel
 * /demo/* and /schools/search endpoints. Mirrors the shape the
 * Pinia store expects (already-parsed objects, no axios leakage).
 */
import { api } from '@/lib/http';
import type {
  DemoProvisionResponse,
  DemoWizardPayload,
  SchoolSearchHit,
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
  name: string;
  jenjang: string | null;
  kota: string | null;
  provinsi: string | null;
  alamat: string | null;
  npsn: string;
  is_demo: false;
  status_resmi?: string;
  akreditasi?: string | null;
  email?: string | null;
  telepon?: string | null;
  /** Present when the NPSN is already claimed by a Kamiledu tenant. */
  kamiledu_school: {
    id: string;
    name: string;
    is_demo: boolean;
    demo_owner_user_id: string | null;
  } | null;
}

interface ExpiryInfo {
  school_id: string;
  school_name: string;
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
   * @param q       partial school name; backend ignores < 2 chars
   * @param jenjang optional filter (SD/SMP/etc.)
   */
  async searchSchools(args: {
    q: string;
    jenjang?: string | null;
    limit?: number;
  }): Promise<SchoolSearchHit[]> {
    const res = await api.get('/schools/search', {
      params: {
        q: args.q,
        jenjang: args.jenjang ?? undefined,
        limit: args.limit ?? 12,
      },
    });
    const body = res.data?.data ?? res.data ?? {};
    return Array.isArray(body.results) ? (body.results as SchoolSearchHit[]) : [];
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
   * Final provisioning. Heavy call — backend runs ~200ms–800ms in a
   * transaction. The wizard shows a loading overlay while waiting.
   *
   * Translates the common 429 / 500 axios failures into user-facing
   * Bahasa Indonesia messages so the wizard's red banner doesn't
   * show "Request failed with status code 429".
   */
  async provision(payload: DemoWizardPayload): Promise<DemoProvisionResponse> {
    try {
      // Provision can run 30-90s on a fresh demo (252 students × 14
      // bills + 315 schedule slots) — override the default 30s axios
      // timeout per-call so big schools don't trip ECONNABORTED.
      const res = await api.post('/demo/provision', payload, {
        timeout: 120_000,
      });
      const data = res.data?.data;
      if (!data) {
        throw new Error('Respons provision tidak valid.');
      }
      return data as DemoProvisionResponse;
    } catch (e: unknown) {
      const err = e as {
        code?: string;
        response?: { status?: number; data?: { message?: string; errors?: unknown } };
        message?: string;
      };
      // Axios timeout: ECONNABORTED with message "timeout of XXXms exceeded".
      if (err.code === 'ECONNABORTED' || /timeout/i.test(err.message ?? '')) {
        throw new Error(
          'Pembuatan sekolah memakan waktu lebih lama dari biasanya. Coba kurangi jumlah siswa/kelas atau ulangi sebentar lagi.',
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
        throw new Error(backendMsg ?? 'Data wizard tidak lengkap. Cek kembali setiap langkah.');
      }
      if (status === 500 || status === 503) {
        throw new Error(
          backendMsg ?? 'Server bermasalah saat membuat sekolah. Coba lagi sebentar.',
        );
      }
      throw new Error(backendMsg ?? err.message ?? 'Gagal membuat sekolah demo.');
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
};
