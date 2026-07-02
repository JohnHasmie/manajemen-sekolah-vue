/**
 * Super-admin billing review service — wraps the three endpoints on
 * AdminBillingController:
 *
 *   GET  /billing/admin/pending-approvals
 *   POST /billing/admin/approve/{id}
 *   POST /billing/admin/reject/{id}
 *
 * Every call is gated server-side by the `super_admin` middleware.
 * Non-super-admin callers get a 403 which we translate into a
 * user-facing Indonesian string so the page can render a friendly
 * error state instead of a raw axios failure.
 */
import { api } from '@/lib/http';
import type {
  ApproveResult,
  PendingApproval,
  PendingApprovalListParams,
  PendingApprovalListResult,
  PendingApprovalMeta,
  RejectResult,
} from '@/types/subscription-approval';

function toFriendlyError(e: unknown, fallback: string): Error {
  const err = e as {
    response?: { status?: number; data?: { error?: string; message?: string } };
    message?: string;
  };
  const status = err.response?.status;
  const backendMsg = err.response?.data?.error ?? err.response?.data?.message;
  if (status === 401) {
    return new Error('Sesi Anda telah berakhir. Silakan masuk kembali.');
  }
  if (status === 403) {
    return new Error(
      'Halaman ini hanya untuk super-admin KamilEdu.',
    );
  }
  if (status === 404) {
    return new Error('Pesanan langganan tidak ditemukan.');
  }
  if (status === 422) {
    return new Error(
      backendMsg ?? 'Pesanan sudah tidak berstatus menunggu verifikasi.',
    );
  }
  if (status === 429) {
    return new Error('Terlalu banyak percobaan. Coba lagi sebentar.');
  }
  return new Error(backendMsg ?? err.message ?? fallback);
}

export const SubscriptionApprovalService = {
  /** GET /billing/admin/pending-approvals — paginated queue. */
  async list(
    params: PendingApprovalListParams = {},
  ): Promise<PendingApprovalListResult> {
    try {
      const res = await api.get('/billing/admin/pending-approvals', {
        params: {
          per_page: params.per_page ?? undefined,
          page: params.page ?? undefined,
        },
      });
      const body = res.data ?? {};
      // Defensive parse: older backend deployments (pre the
      // pending_payment-inclusion patch) don't emit `status` or
      // `is_claimed`. Default them here so the FE is forward and
      // backward compatible during the rollout window.
      const items: PendingApproval[] = Array.isArray(body.data)
        ? body.data.map((r: Partial<PendingApproval>) => ({
            ...r,
            status: r.status ?? 'awaiting_verify',
            is_claimed:
              r.is_claimed ?? (r.status ?? 'awaiting_verify') === 'awaiting_verify',
          } as PendingApproval))
        : [];
      const meta: PendingApprovalMeta = body.meta ?? {
        current_page: 1,
        last_page: 1,
        per_page: items.length,
        total: items.length,
      };
      return { items, meta };
    } catch (e) {
      throw toFriendlyError(
        e,
        'Gagal memuat antrian verifikasi langganan.',
      );
    }
  },

  /**
   * POST /billing/admin/approve/{id} — activate a manual-transfer sub.
   * Idempotent: a repeat approve on an already-active sub returns
   * `already_active: true` and does NOT re-send notifications.
   */
  async approve(id: string): Promise<ApproveResult> {
    try {
      const res = await api.post(`/billing/admin/approve/${id}`);
      return res.data as ApproveResult;
    } catch (e) {
      throw toFriendlyError(e, 'Gagal menyetujui pembayaran.');
    }
  },

  /**
   * POST /billing/admin/reject/{id} — cancel with a written reason.
   * The reason is included in the customer's email + WhatsApp so it
   * must be actionable (backend validates 3..500 chars).
   */
  async reject(id: string, reason: string): Promise<RejectResult> {
    try {
      const res = await api.post(`/billing/admin/reject/${id}`, {
        reason,
      });
      return res.data as RejectResult;
    } catch (e) {
      throw toFriendlyError(e, 'Gagal menolak pembayaran.');
    }
  },
};
