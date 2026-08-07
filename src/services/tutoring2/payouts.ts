/**
 * PayoutsService — thin wrapper over the greenfield admin payouts
 * endpoints (`/api/tutoring-v2/payouts/*` — BE-24 rates + settings,
 * BE-25 self-service requests, BE-26 summary + monthly close).
 *
 * Kept in its own `tutoring2/` subdirectory (not folded into the big
 * `tutoring-bimbel.service.ts`) because the payouts surface is
 * self-contained and this MR is the first of a new pattern — future
 * WEB-1x MRs can drop their own domain service next to this one.
 *
 * Every method returns the unwrapped `data` payload (or `{items,
 * pagination}` for paginated reads) so callers never touch the
 * envelope shape directly. `X-Tenant-ID` is added by the shared http
 * layer.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  ClosePayoutMonthPayload,
  CreatePayoutRequestPayload,
  ListPayoutRateParams,
  ListPayoutRequestParams,
  MarkPayoutRequestPaidPayload,
  PayoutClose,
  PayoutRate,
  PayoutRequest,
  PayoutSettings,
  PayoutSummaryMeta,
  PayoutSummaryRow,
  RejectPayoutRequestPayload,
  SelfPayoutSummary,
  UpdatePayoutSettingsPayload,
  UpsertPayoutRatePayload,
} from '@/types/tutoring2/payout';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

interface SummaryListEnvelope {
  data: PayoutSummaryRow[];
  meta?: PayoutSummaryMeta;
}

const BASE = '/tutoring-v2/payouts';

export const PayoutsService = {
  // ─── Rates (BE-24) ────────────────────────────────────────────────

  async listRates(params: ListPayoutRateParams = {}) {
    const r = await api.get<ListEnvelope<PayoutRate>>(`${BASE}/rates`, { params });
    return { items: r.data.data, pagination: r.data.meta };
  },

  async upsertRate(payload: UpsertPayoutRatePayload): Promise<PayoutRate> {
    const r = await api.post<OneEnvelope<PayoutRate>>(`${BASE}/rates`, payload);
    return r.data.data;
  },

  async endRate(id: string): Promise<PayoutRate> {
    const r = await api.post<OneEnvelope<PayoutRate>>(`${BASE}/rates/${id}/end`, {});
    return r.data.data;
  },

  // ─── Settings (BE-24) ────────────────────────────────────────────

  async getSettings(): Promise<PayoutSettings> {
    const r = await api.get<OneEnvelope<PayoutSettings>>(`${BASE}/settings`);
    return r.data.data;
  },

  async updateSettings(payload: UpdatePayoutSettingsPayload): Promise<PayoutSettings> {
    const r = await api.put<OneEnvelope<PayoutSettings>>(`${BASE}/settings`, payload);
    return r.data.data;
  },

  // ─── Requests (BE-25) ────────────────────────────────────────────

  async listRequests(params: ListPayoutRequestParams = {}) {
    const r = await api.get<ListEnvelope<PayoutRequest>>(`${BASE}/requests`, { params });
    return { items: r.data.data, pagination: r.data.meta };
  },

  async getRequest(id: string): Promise<PayoutRequest> {
    const r = await api.get<OneEnvelope<PayoutRequest>>(`${BASE}/requests/${id}`);
    return r.data.data;
  },

  async approveRequest(id: string): Promise<PayoutRequest> {
    const r = await api.patch<OneEnvelope<PayoutRequest>>(`${BASE}/requests/${id}/approve`, {});
    return r.data.data;
  },

  async rejectRequest(id: string, payload: RejectPayoutRequestPayload): Promise<PayoutRequest> {
    const r = await api.patch<OneEnvelope<PayoutRequest>>(`${BASE}/requests/${id}/reject`, payload);
    return r.data.data;
  },

  async markRequestPaid(
    id: string,
    payload: MarkPayoutRequestPaidPayload = {},
  ): Promise<PayoutRequest> {
    const r = await api.patch<OneEnvelope<PayoutRequest>>(
      `${BASE}/requests/${id}/mark-paid`,
      payload,
    );
    return r.data.data;
  },

  async rollbackRequest(id: string): Promise<PayoutRequest> {
    const r = await api.patch<OneEnvelope<PayoutRequest>>(`${BASE}/requests/${id}/rollback`, {});
    return r.data.data;
  },

  // ─── Self-service (tutor's own view) ─────────────────────────────

  /**
   * The calling tutor's own payout summary for `month` (default:
   * backend's current period). Backend resolves the tutor from the
   * auth context — there is deliberately no `user_id` param, unlike
   * the legacy v1 endpoint. Admins wanting a tenant-wide view use
   * {@link getAdminSummary} instead.
   */
  async getSelfSummary(params: { month?: string } = {}): Promise<SelfPayoutSummary> {
    const r = await api.get<OneEnvelope<SelfPayoutSummary>>(`${BASE}/summary`, { params });
    return r.data.data;
  },

  /**
   * The calling tutor's own withdrawal requests. Same endpoint as
   * {@link listRequests}; the backend scopes to the caller when they
   * hold only `tutoring.payout.view_own`, so no client-side tutor
   * filter is sent (sending one would be a no-op at best and an IDOR
   * probe at worst).
   */
  async listMyRequests(params: { page?: number; per_page?: number } = {}) {
    const r = await api.get<ListEnvelope<PayoutRequest>>(`${BASE}/requests`, { params });
    return { items: r.data.data, pagination: r.data.meta };
  },

  async createRequest(payload: CreatePayoutRequestPayload): Promise<PayoutRequest> {
    const r = await api.post<OneEnvelope<PayoutRequest>>(`${BASE}/requests`, payload);
    return r.data.data;
  },

  // ─── Summary + monthly close (BE-26) ─────────────────────────────

  async getAdminSummary(params: { month?: string } = {}) {
    const r = await api.get<SummaryListEnvelope>(`${BASE}/admin-summary`, { params });
    return { rows: r.data.data, meta: r.data.meta };
  },

  async closeMonth(payload: ClosePayoutMonthPayload): Promise<PayoutClose> {
    const r = await api.post<OneEnvelope<PayoutClose>>(`${BASE}/close-month`, payload);
    return r.data.data;
  },

  async reopenMonth(id: string): Promise<void> {
    await api.delete(`${BASE}/close-month/${id}`);
  },

  async listCloses(params: { page?: number; per_page?: number } = {}) {
    const r = await api.get<ListEnvelope<PayoutClose>>(`${BASE}/closes`, { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
};
