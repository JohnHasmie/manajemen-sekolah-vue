/**
 * MobileAppBroadcastService — client for the per-school WA blast
 * trigger reached from the "belum instal aplikasi mobile" gap on the
 * Readiness dashboard.
 *
 * Mirrors `/api/admin/mobile-app-broadcast/*` (backend MR-B + MR-E).
 * Auth: `readiness.view` ability, `X-School-ID` header from the
 * standard axios interceptor.
 *
 * MR-E expanded scope: recipients now include guru + staf + wali,
 * `role` field carries the group, and `trigger` accepts a per-role
 * `templates` map. The legacy single-`message` form is kept in the
 * type so callers migrating to the map can go in one PR without a
 * compile break.
 */
import { api } from '@/lib/http';

export type BroadcastRole = 'teacher' | 'staff' | 'parent';

export const ALL_ROLES: readonly BroadcastRole[] = ['teacher', 'staff', 'parent'];

export interface MobileAppRecipient {
  user_id: string;
  name: string;
  email: string;
  role: BroadcastRole;
  phone_masked: string;
}

export interface RecipientsPayload {
  data: MobileAppRecipient[];
  meta: {
    total: number;
    /** Distinct users reachable (has phone AND no active FCM) — per role. */
    per_role_totals: Partial<Record<BroadcastRole, number>>;
    /** People we can't reach because they have no phone on file. */
    excluded_missing_phone: number;
    excluded_missing_phone_per_role: Partial<Record<BroadcastRole, number>>;
  };
}

export interface TriggerResponse {
  data: {
    batch_id: string;
    queued: number;
    queued_per_role: Record<BroadcastRole, number>;
    first_send_at: string;
    last_send_at: string;
    interval_seconds: number;
  };
}

export interface BatchSummary {
  batch_id: string;
  started_at: string;
  last_activity_at: string;
  total: number;
  delivered: number;
  failed: number;
  queued: number;
  /** Backend MR-E aggregates this per batch — undefined on rows written pre-MR-E. */
  per_role?: Record<BroadcastRole, number>;
}

const BASE = '/admin/mobile-app-broadcast';

export const MobileAppBroadcastService = {
  async getRecipients(): Promise<RecipientsPayload> {
    try {
      const res = await api.get(`${BASE}/recipients`);
      return res.data as RecipientsPayload;
    } catch {
      return {
        data: [],
        meta: {
          total: 0,
          per_role_totals: {},
          excluded_missing_phone: 0,
          excluded_missing_phone_per_role: {},
        },
      };
    }
  },

  /**
   * Trigger a blast. Accepts a per-role `templates` map — a role
   * missing from the map falls back to the server-side default for
   * that role. Backend rejects with 429 + `retry_after_seconds` when
   * the school hit its hourly cap; callers should surface that to the
   * operator instead of retrying silently.
   */
  async trigger(
    templates: Partial<Record<BroadcastRole, string>>,
    recipientUserIds: string[],
  ): Promise<
    | { ok: true; data: TriggerResponse['data'] }
    | { ok: false; error: string; retryAfterSeconds?: number }
  > {
    try {
      const res = await api.post(`${BASE}/trigger`, {
        templates,
        recipient_user_ids: recipientUserIds,
      });
      return { ok: true, data: (res.data as TriggerResponse).data };
    } catch (e: any) {
      const status = e?.response?.status;
      const body = e?.response?.data ?? {};
      if (status === 429) {
        return {
          ok: false,
          error: body.message ?? 'Batas 1 blast per jam.',
          retryAfterSeconds: body.retry_after_seconds,
        };
      }
      return {
        ok: false,
        error: body.message ?? body.error ?? 'Gagal memicu blast.',
      };
    }
  },

  async getBatches(): Promise<BatchSummary[]> {
    try {
      const res = await api.get(`${BASE}/batches`);
      return (res.data?.data ?? []) as BatchSummary[];
    } catch {
      return [];
    }
  },
};

/**
 * Default template per role — the FE seeds these into the textareas on
 * first render so the operator only has to tweak, not compose from
 * scratch. Kept in sync with the backend's defaults (see
 * `AdminMobileAppBroadcastController::defaultTemplates`) so a role
 * that goes over the wire without an override doesn't surprise the
 * operator with different copy than the textarea shows.
 */
export const DEFAULT_TEMPLATES: Record<BroadcastRole, string> = {
  teacher: `Halo {name}, aplikasi KamilEdu untuk guru sudah tersedia.

Silakan install & login supaya kamu dapat notifikasi presensi & nilai siswa langsung di HP.

Android: https://play.google.com/store/apps/details?id=com.kamiledu.mobile

Terima kasih.`,
  staff: `Halo {name}, aplikasi KamilEdu untuk staf sudah tersedia.

Silakan install & login supaya kamu dapat pengumuman & kehadiran sekolah langsung di HP.

Android: https://play.google.com/store/apps/details?id=com.kamiledu.mobile

Terima kasih.`,
  parent: `Halo Bapak/Ibu {name}, aplikasi KamilEdu untuk wali murid sudah tersedia.

Silakan install & login supaya Bapak/Ibu dapat pantau kehadiran, nilai, dan pengumuman anak langsung di HP.

Android: https://play.google.com/store/apps/details?id=com.kamiledu.mobile

Terima kasih.`,
};

export const ROLE_LABELS: Record<BroadcastRole, string> = {
  teacher: 'Guru',
  staff: 'Staf',
  parent: 'Wali murid',
};
