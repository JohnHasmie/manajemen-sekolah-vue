/**
 * VouchersService — greenfield BE-16 voucher endpoints under
 * `/api/tutoring-v2/vouchers/*`. Kept in its own file (not folded into
 * the monolithic `tutoring-bimbel.service.ts`) per the WEB-9 task
 * convention: greenfield services live under `services/tutoring2/*.ts`,
 * types under `types/tutoring2/*.ts`.
 *
 * Every method returns a typed DTO; list flattens the Laravel
 * `{ data, meta }` envelope into `{ items, pagination }` to match the
 * rest of the app (see StaffService, TutoringBimbelService).
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  BimbelVoucher,
  BimbelVoucherRedemption,
  VoucherCreatePayload,
  VoucherListParams,
  VoucherRedeemPayload,
  VoucherUpdatePayload,
} from '@/types/tutoring2/voucher';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

/**
 * Build the query-string map the backend controller actually reads.
 * The controller accepts `status` + `code` (case-insensitive contains).
 * We also accept a UI-side `search` alias to keep call sites idiomatic.
 */
function buildListParams(params: VoucherListParams): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  if (params.page != null) out.page = params.page;
  if (params.per_page != null) out.per_page = params.per_page;
  if (params.status) out.status = params.status;
  const code = params.code ?? params.search;
  if (code) out.code = code;
  return out;
}

export const VouchersService = {
  async list(params: VoucherListParams = {}) {
    const r = await api.get<ListEnvelope<BimbelVoucher>>(
      '/tutoring-v2/vouchers',
      { params: buildListParams(params) },
    );
    return { items: r.data.data, pagination: r.data.meta };
  },

  async get(id: string) {
    const r = await api.get<OneEnvelope<BimbelVoucher>>(
      `/tutoring-v2/vouchers/${id}`,
    );
    return r.data.data;
  },

  async create(payload: VoucherCreatePayload) {
    const r = await api.post<OneEnvelope<BimbelVoucher>>(
      '/tutoring-v2/vouchers',
      payload,
    );
    return r.data.data;
  },

  async update(id: string, payload: VoucherUpdatePayload) {
    const r = await api.put<OneEnvelope<BimbelVoucher>>(
      `/tutoring-v2/vouchers/${id}`,
      payload,
    );
    return r.data.data;
  },

  async archive(id: string) {
    const r = await api.post<OneEnvelope<BimbelVoucher>>(
      `/tutoring-v2/vouchers/${id}/archive`,
      {},
    );
    return r.data.data;
  },

  async redeem(id: string, payload: VoucherRedeemPayload) {
    const r = await api.post<OneEnvelope<BimbelVoucherRedemption>>(
      `/tutoring-v2/vouchers/${id}/redeem`,
      payload,
    );
    return r.data.data;
  },
};
