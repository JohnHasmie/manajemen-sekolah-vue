/**
 * MobileAppBroadcastService — client for the per-school WA blast
 * trigger that lives at the "guru belum instal aplikasi mobile" gap
 * on the Readiness dashboard.
 *
 * Mirrors `/api/admin/mobile-app-broadcast/*` (backend MR-B).
 * Auth: `readiness.view` ability, `X-School-ID` header from the
 * standard axios interceptor.
 */
import { api } from '@/lib/http';

export interface MobileAppRecipient {
  user_id: string;
  name: string;
  email: string;
  phone_masked: string;
}

export interface RecipientsPayload {
  data: MobileAppRecipient[];
  meta: {
    total: number;
    /** Guru without token AND without phone — surface so admin can fix data. */
    excluded_missing_phone: number;
  };
}

export interface TriggerResponse {
  data: {
    batch_id: string;
    queued: number;
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
}

const BASE = '/admin/mobile-app-broadcast';

export const MobileAppBroadcastService = {
  async getRecipients(): Promise<RecipientsPayload> {
    try {
      const res = await api.get(`${BASE}/recipients`);
      return res.data as RecipientsPayload;
    } catch {
      return { data: [], meta: { total: 0, excluded_missing_phone: 0 } };
    }
  },

  /**
   * Trigger a blast. Backend rejects with 429 + retry_after_seconds
   * when the school hit its hourly cap — callers should surface that
   * to the operator instead of retrying silently.
   */
  async trigger(
    message: string,
    recipientUserIds: string[],
  ): Promise<
    | { ok: true; data: TriggerResponse['data'] }
    | { ok: false; error: string; retryAfterSeconds?: number }
  > {
    try {
      const res = await api.post(`${BASE}/trigger`, {
        message,
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
      return { ok: false, error: body.message ?? body.error ?? 'Gagal memicu blast.' };
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
