/**
 * discount-code.service.ts — super-admin CRUD wrapper.
 *
 * All calls hit /billing/admin/discount-codes/… routes gated by the
 * `super_admin` middleware on the backend. Callers get thrown Errors
 * with human copy on failure (auth 403 / validation 422 / server
 * 500 all get the same treatment — the FE picks the message from
 * the response body when the backend sends one).
 *
 * Kept as its own file rather than folded into billing.service.ts:
 * the super-admin surface has zero overlap with the subscribe /
 * seat-top-up flows the billing service covers, and its FE consumer
 * (SuperAdminDiscountCodesView) never touches those flows either.
 */
import { api } from '@/lib/http';
import type {
  CreateDiscountCodePayload,
  DiscountCodeDetail,
  DiscountCodeListParams,
  DiscountCodeListResponse,
  DiscountCodeRedemptionListResponse,
  UpdateDiscountCodePayload,
} from '@/types/discount-code';

function humanError(e: unknown, fallback: string): string {
  const ax = e as any;
  if (ax?.response?.data) {
    const data = ax.response.data;
    if (typeof data === 'string') return data;
    if (data?.message) return String(data.message);
    if (data?.error) return String(data.error);
    if (data?.errors && typeof data.errors === 'object') {
      const first = Object.values(data.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

const BASE = '/billing/admin/discount-codes';

export const DiscountCodeService = {
  async list(params: DiscountCodeListParams = {}): Promise<DiscountCodeListResponse> {
    try {
      const res = await api.get(BASE, { params });
      return res.data as DiscountCodeListResponse;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat daftar kode diskon.'));
    }
  },

  async show(id: string): Promise<DiscountCodeDetail> {
    try {
      const res = await api.get(`${BASE}/${id}`);
      return res.data as DiscountCodeDetail;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat detail kode.'));
    }
  },

  async create(payload: CreateDiscountCodePayload): Promise<DiscountCodeDetail> {
    try {
      const res = await api.post(BASE, this.normalize(payload));
      return res.data as DiscountCodeDetail;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menyimpan kode diskon.'));
    }
  },

  async update(id: string, payload: UpdateDiscountCodePayload): Promise<DiscountCodeDetail> {
    try {
      const res = await api.patch(`${BASE}/${id}`, this.normalize(payload));
      return res.data as DiscountCodeDetail;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui kode diskon.'));
    }
  },

  async destroy(id: string): Promise<void> {
    try {
      await api.delete(`${BASE}/${id}`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus kode diskon.'));
    }
  },

  async redemptions(
    id: string,
    params: { page?: number; per_page?: number } = {},
  ): Promise<DiscountCodeRedemptionListResponse> {
    try {
      const res = await api.get(`${BASE}/${id}/redemptions`, { params });
      return res.data as DiscountCodeRedemptionListResponse;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat riwayat pemakaian.'));
    }
  },

  /**
   * Coerce raw form values to the exact shape the backend expects.
   * Two jobs:
   *   • `code` uppercased + trimmed (matches the model's setter, but
   *     the wire benefits from the same normalisation so a debugger
   *     staring at the payload sees the honest value).
   *   • Empty-string date/number fields → null so the backend's
   *     nullable validation succeeds (empty inputs otherwise fail
   *     the date/integer rules).
   */
  normalize<T extends CreateDiscountCodePayload | UpdateDiscountCodePayload>(payload: T): T {
    const out: Record<string, unknown> = { ...payload };
    if (typeof out.code === 'string') {
      out.code = out.code.toUpperCase().trim();
    }
    for (const k of [
      'duration_months',
      'max_uses',
      'valid_from',
      'valid_until',
      'min_amount_monthly',
    ] as const) {
      const v = out[k];
      if (v === '' || v === undefined) delete out[k];
      // Explicit null passes through — backend clears the field.
    }
    return out as T;
  },
};
