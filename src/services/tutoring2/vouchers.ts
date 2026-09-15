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
  BimbelVoucherRecipient,
  BimbelVoucherRedemption,
  VoucherAttachRecipientsPayload,
  VoucherCreatePayload,
  VoucherListParams,
  VoucherRecipientMutationResult,
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
 * Both recipient writes answer with a voucher row PLUS a `meta` count of
 * the rows they actually changed. `meta` is typed optional because a
 * server that stopped sending it must degrade to "0 changed", not to a
 * runtime read of `undefined.attached_count`.
 */
interface RecipientMutationEnvelope {
  data: BimbelVoucher;
  meta?: { attached_count?: number; detached_count?: number };
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

  // ── Recipient targeting ─────────────────────────────────────────────
  //
  // A voucher used to be a code and a quota with NO OWNER. These three
  // endpoints give it named students, which is what turns a general
  // promo into a personal one. Verified against `routes/api.php` and
  // `VoucherController` rather than assumed:
  //
  //   GET    …/{id}/recipients              → `tutoring.voucher.view`
  //   POST   …/{id}/recipients              → `tutoring.voucher.manage`
  //   DELETE …/{id}/recipients/{studentId}  → `tutoring.voucher.manage`
  //
  // THE READ AND THE WRITES DO NOT SHARE A KEY. The read is deliberately
  // the TENANT-WIDE `.view` and not the wali-scoped `.view_own`, because
  // "who else holds this promo" is the one question a parent must never
  // be able to ask. Callers must gate each control on the key its own
  // endpoint authorizes — a single `canManage` covering all three would
  // hide the list from read-only staff who are entitled to it.

  /**
   * The voucher's named recipients.
   *
   * AN EMPTY ARRAY IS A MEANINGFUL ANSWER, not a missing one: it says
   * the voucher is a general promo that anyone holding the code may
   * spend. Do not render it as "failed to load".
   */
  async listRecipients(voucherId: string): Promise<BimbelVoucherRecipient[]> {
    const r = await api.get<ListEnvelope<BimbelVoucherRecipient>>(
      `/tutoring-v2/vouchers/${voucherId}/recipients`,
    );
    return r.data.data;
  },

  /**
   * Name one or more STUDENTS as recipients.
   *
   * Attaching the FIRST recipient NARROWS a circulating code from "anyone
   * who knows it" to "these students only" — enforced in
   * `RedeemVoucherAction`, so an admin redeeming on a family's behalf is
   * held to it too. Idempotent: re-attaching an existing recipient is a
   * no-op returning `changedCount: 0`, not a duplicate and not a 500.
   *
   * The payload is spelled through `VoucherAttachRecipientsPayload` so
   * the wire key `student_ids` is checked at compile time against the
   * FormRequest's own rule names rather than retyped as a literal.
   */
  async attachRecipients(
    voucherId: string,
    studentIds: string[],
  ): Promise<VoucherRecipientMutationResult> {
    const payload: VoucherAttachRecipientsPayload = { student_ids: studentIds };
    const r = await api.post<RecipientMutationEnvelope>(
      `/tutoring-v2/vouchers/${voucherId}/recipients`,
      payload,
    );
    return { voucher: r.data.data, changedCount: r.data.meta?.attached_count ?? 0 };
  },

  /**
   * Remove ONE named recipient. The student is named in the PATH, not in
   * a body — a DELETE carrying a payload is awkward for several clients,
   * and one-student-per-call keeps the operation unambiguous.
   *
   * REMOVING THE LAST RECIPIENT WIDENS THE VOUCHER BACK TO A GENERAL
   * PROMO: "no recipients" is by definition untargeted, so the code
   * becomes spendable by anyone who knows it, capped only by
   * `max_redemptions`. It is the one operation on this surface that
   * loosens access rather than tightening it, which is why the screen
   * confirms it instead of treating a clear-out as tidying up.
   *
   * Idempotent: detaching a non-recipient is 200 with `changedCount: 0`.
   */
  async detachRecipient(
    voucherId: string,
    studentId: string,
  ): Promise<VoucherRecipientMutationResult> {
    const r = await api.delete<RecipientMutationEnvelope>(
      `/tutoring-v2/vouchers/${voucherId}/recipients/${studentId}`,
    );
    return { voucher: r.data.data, changedCount: r.data.meta?.detached_count ?? 0 };
  },
};
