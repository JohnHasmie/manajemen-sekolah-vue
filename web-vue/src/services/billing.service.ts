/**
 * BillingService — parent surface for tagihan & pembayaran.
 *
 * Hits the Laravel `/bill/*` endpoints (singular — `/billing/*` does NOT
 * exist, that was a bug in the original Vue port). Mirrors Flutter's
 * `lib/features/finance/data/finance_service.dart` parent calls.
 *
 * Endpoints:
 *   GET  /bill/parent                       — list bills for parent's children
 *   POST /bill/{id}/checkout                — open a checkout session (QRIS/VA/Manual)
 *   POST /bill/{id}/payment-proof           — upload manual transfer proof (multipart)
 *   GET  /payment/{id}/receipt              — binary blob (kuitansi PDF/image)
 *   GET  /payments?bill_id=…                — list verifications for a single bill (parent kuitansi)
 *
 * The web app NEVER auto-charges. QRIS/VA tabs show the static payment
 * instructions (deterministic VA stub on the backend); manual tab lets
 * the parent upload a bukti transfer photo for admin verification.
 */
import { api } from '@/lib/http';
import {
  normalizeBillStatus,
  normalizePaymentStatus,
  type Bill,
  type CheckoutSession,
  type ManualBankAccount,
  type Payment,
} from '@/types/billing';

function asNum(v: unknown, fallback = 0): number {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }
  return fallback;
}

function asStr(v: unknown, fallback = ''): string {
  if (v === null || v === undefined) return fallback;
  return String(v);
}

function diffDays(due: string | null | undefined): number | null {
  if (!due) return null;
  const t = new Date(due).getTime();
  if (!Number.isFinite(t)) return null;
  return Math.round((t - Date.now()) / 86_400_000);
}

function parsePaymentTypeMini(raw: any): Bill['payment_type'] {
  if (!raw || typeof raw !== 'object') return null;
  return {
    id: asStr(raw.id),
    name: asStr(raw.name),
    description: raw.description ?? null,
    periode: raw.periode ?? null,
  };
}

function parseStudentMini(raw: any): Bill['student'] {
  if (!raw || typeof raw !== 'object') return null;
  const classes = Array.isArray(raw.classes) ? raw.classes : [];
  const cls = classes[0] ?? null;
  return {
    id: asStr(raw.id),
    name: asStr(raw.name),
    student_number: raw.student_number ?? null,
    nisn: raw.nisn ?? null,
    class_name: cls?.name ?? null,
  };
}

function parseLatestPayment(raw: any): Bill['latest_payment'] {
  if (!raw || typeof raw !== 'object') return null;
  const verifierRaw = raw.verifier ?? raw.verified_by_user ?? null;
  return {
    id: asStr(raw.id),
    status: asStr(raw.status),
    amount: asNum(raw.amount),
    payment_method: raw.payment_method ?? null,
    payment_date: raw.payment_date ?? null,
    verified_at: raw.verified_at ?? null,
    verifier_name: verifierRaw?.name ?? null,
    payment_proof_url: raw.payment_proof_url ?? null,
  };
}

function billTitle(raw: any, pt: Bill['payment_type']): string {
  const direct = asStr(raw.title ?? raw.description ?? '', '').trim();
  if (direct) return direct;
  const name = pt?.name ?? '';
  const month = asStr(raw.month ?? '', '').trim();
  return [name, month].filter(Boolean).join(' · ') || 'Tagihan';
}

function billSubtitle(raw: any, pt: Bill['payment_type'], stu: Bill['student']): string | null {
  const parts: string[] = [];
  if (pt?.periode) {
    const p = String(pt.periode).toLowerCase();
    if (p === 'bulanan' || p === 'monthly') parts.push('Bulanan');
    else if (p === 'tahunan' || p === 'yearly') parts.push('Tahunan');
    else if (p === 'sekali' || p === 'once') parts.push('Sekali');
  }
  if (stu?.class_name) parts.push(stu.class_name);
  if (parts.length === 0) return null;
  return parts.join(' · ');
}

export function billFromJson(raw: any): Bill {
  const pt = parsePaymentTypeMini(raw.payment_type ?? raw.paymentType ?? null);
  const stu = parseStudentMini(raw.student ?? null);
  const latest = parseLatestPayment(raw.latest_payment_relation ?? raw.latestPaymentRelation ?? raw.latest_payment ?? null);

  const dueDate = raw.due_date ?? null;
  const dueInDaysRaw = raw.due_in_days;
  const dueInDays = typeof dueInDaysRaw === 'number' ? dueInDaysRaw : diffDays(dueDate);
  const overdue = Boolean(raw.is_overdue);
  const status = normalizeBillStatus(raw.status, { dueInDays, isOverdue: overdue });

  return {
    id: asStr(raw.id),
    title: billTitle(raw, pt),
    subtitle: billSubtitle(raw, pt, stu),
    amount: asNum(raw.amount),
    due_date: dueDate,
    due_in_days: dueInDays,
    raw_status: asStr(raw.status, 'unpaid'),
    status,
    is_overdue: overdue || status === 'overdue',
    overdue_days: asNum(raw.overdue_days),
    is_read: raw.is_read === true,
    reminder_count: asNum(raw.reminder_count),
    last_reminded_at: raw.last_reminded_at ?? null,
    description: raw.description ?? null,
    month: raw.month ?? null,
    academic_year_id: raw.academic_year_id ? asStr(raw.academic_year_id) : null,
    payment_type: pt,
    student: stu,
    latest_payment: latest,
    payment_proof_url: raw.payment_proof_url ?? latest?.payment_proof_url ?? null,
  };
}

export function paymentFromJson(raw: any): Payment {
  const billRaw = raw.bill ?? null;
  return {
    id: asStr(raw.id),
    bill_id: asStr(raw.bill_id),
    school_id: raw.school_id ?? undefined,
    amount: asNum(raw.amount),
    payment_method: raw.payment_method ?? null,
    payment_date: raw.payment_date ?? null,
    payment_receipt: raw.payment_receipt ?? null,
    payment_proof_url: raw.payment_proof_url ?? null,
    raw_status: asStr(raw.status, 'pending'),
    status: normalizePaymentStatus(raw.status),
    verified_at: raw.verified_at ?? null,
    verified_by: raw.verified_by ?? null,
    verifier_name: raw.verifier?.name ?? null,
    admin_notes: raw.admin_notes ?? null,
    created_at: raw.created_at ?? null,
    bill: billRaw ? billFromJson(billRaw) : null,
  };
}

// ───────────────────────────────────────────────────────────────────
// Filters
// ───────────────────────────────────────────────────────────────────

export interface ParentBillFilters {
  student_id?: string;
  status?: 'paid' | 'unpaid' | 'pending';
  payment_type_id?: string;
  periode?: 'bulanan' | 'tahunan' | 'sekali';
  search?: string;
  due_date_from?: string;
  due_date_to?: string;
}

// ───────────────────────────────────────────────────────────────────
// Service
// ───────────────────────────────────────────────────────────────────

export const BillingService = {
  /**
   * GET /bill/parent — list bills for the signed-in parent's children.
   * Returns a plain array (not paginated by default).
   */
  async listParent(filters: ParentBillFilters = {}): Promise<Bill[]> {
    try {
      const params: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(filters)) {
        if (v !== undefined && v !== null && v !== '') params[k] = v;
      }
      const res = await api.get('/bill/parent', { params });
      const body = res.data;
      const list = Array.isArray(body) ? body : Array.isArray(body?.data) ? body.data : [];
      return list.map(billFromJson);
    } catch (e) {
      // Wrap so callers can show a useful message — but never swallow.
      throw new Error(humanError(e, 'Gagal memuat daftar tagihan.'));
    }
  },

  /**
   * POST /bill/{id}/checkout — open a Bayar checkout session.
   * Returns QRIS string, VA number, manual bank list, expires_at.
   */
  async openCheckout(billId: string): Promise<CheckoutSession> {
    try {
      const res = await api.post(`/bill/${billId}/checkout`);
      const body = res.data?.data ?? res.data;
      if (!body || typeof body !== 'object') {
        throw new Error('Respons checkout tidak valid.');
      }
      return checkoutFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal membuka sesi pembayaran.'));
    }
  },

  /**
   * POST /bill/{billId}/payment-proof — upload manual transfer proof.
   * Multipart payload: payment_receipt (image/pdf), amount, payment_method,
   * payment_date. Returns the created Payment.
   */
  async uploadProof(
    billId: string,
    input: {
      file: File;
      amount?: number;
      payment_date?: string;
      payment_method?: string;
    },
  ): Promise<Payment> {
    const fd = new FormData();
    fd.append('payment_receipt', input.file);
    if (typeof input.amount === 'number') fd.append('amount', String(input.amount));
    if (input.payment_date) fd.append('payment_date', input.payment_date);
    fd.append('payment_method', input.payment_method ?? 'manual_transfer');
    try {
      const res = await api.post(`/bill/${billId}/payment-proof`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const body = res.data?.data ?? res.data ?? {};
      const payment = body.payment ?? body;
      return paymentFromJson({ ...payment, payment_proof_url: body.payment_proof_url });
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengunggah bukti pembayaran.'));
    }
  },

  /**
   * Lookup a single parent payment by id.
   *
   * The backend does not expose a parent-facing `GET /payment/{id}`
   * JSON endpoint — only the binary receipt stream. We hydrate by
   * first listing parent bills (cheap, cached server-side) and then
   * querying `/payments?bill_id=…` for the bill that owns the
   * payment. Pass `billId` as a hint when known (e.g. from the
   * checkout flow) to skip the bill scan.
   */
  async getParentPayment(
    paymentId: string,
    opts: { billId?: string } = {},
  ): Promise<{ payment: Payment; bill: Bill } | null> {
    let bill: Bill | null = null;
    if (opts.billId) {
      const parentList = await this.listParent();
      bill = parentList.find((b) => b.id === opts.billId) ?? null;
      if (bill) {
        const payments = await this.listForBill(bill.id);
        const found = payments.find((p) => p.id === paymentId);
        if (found) return { payment: found, bill };
      }
    }
    // Fallback: scan all parent bills.
    const parentList = await this.listParent();
    for (const b of parentList) {
      if (b.latest_payment?.id === paymentId) {
        const payments = await this.listForBill(b.id);
        const found = payments.find((p) => p.id === paymentId);
        if (found) return { payment: found, bill: b };
      }
    }
    return null;
  },

  /**
   * GET /payments?bill_id=… — list verifications for a single bill.
   * Used by the parent kuitansi to show payment history per bill.
   */
  async listForBill(billId: string): Promise<Payment[]> {
    try {
      const res = await api.get('/payments', { params: { bill_id: billId, per_page: 50 } });
      const body = res.data;
      const list = Array.isArray(body?.data) ? body.data : Array.isArray(body) ? body : [];
      return list.map(paymentFromJson);
    } catch {
      return [];
    }
  },

  /**
   * GET /payment/{id}/receipt — fetch kuitansi as a Blob.
   * Streams via Laravel (Sanctum-authed); never use a raw <img src>
   * because MinIO endpoints in Docker dev are private hostnames.
   *
   * Returns a Blob; callers wrap in URL.createObjectURL for display
   * or trigger a download via an anchor.
   */
  async fetchReceiptBlob(paymentId: string): Promise<Blob> {
    const res = await api.get(`/payment/${paymentId}/receipt`, {
      responseType: 'blob',
    });
    return res.data as Blob;
  },

  /**
   * Convenience: download the receipt as a file in the browser.
   */
  async downloadReceipt(paymentId: string, suggestedName = 'kuitansi.pdf'): Promise<void> {
    const blob = await this.fetchReceiptBlob(paymentId);
    const url = URL.createObjectURL(blob);
    try {
      const a = document.createElement('a');
      a.href = url;
      a.download = suggestedName;
      document.body.appendChild(a);
      a.click();
      a.remove();
    } finally {
      // Defer revoke so the click can settle on some browsers.
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
  },

  /**
   * POST /bill/mark-single-read — mark a bill as read.
   * Optional; the inbox does this transparently when a card is tapped.
   */
  async markRead(billId: string): Promise<void> {
    try {
      await api.post('/bill/mark-single-read', { bill_id: billId });
    } catch {
      // Best-effort; never block UI on this.
    }
  },
};

// ───────────────────────────────────────────────────────────────────
// Helpers
// ───────────────────────────────────────────────────────────────────

function checkoutFromJson(raw: any): CheckoutSession {
  const banks = Array.isArray(raw.manual_bank_list)
    ? (raw.manual_bank_list as any[]).map(parseBank)
    : [];
  return {
    bill_id: asStr(raw.bill_id),
    amount: asNum(raw.amount),
    qris_admin_fee: asNum(raw.qris_admin_fee),
    va_admin_fee: asNum(raw.va_admin_fee),
    manual_admin_fee: asNum(raw.manual_admin_fee),
    qr_string: asStr(raw.qr_string),
    va_number: asStr(raw.va_number),
    va_bank: asStr(raw.va_bank, 'BANK'),
    manual_bank_list: banks,
    expires_at: asStr(raw.expires_at),
    student_name: raw.student_name ?? null,
    bill_name: raw.bill_name ?? null,
  };
}

function parseBank(raw: any): ManualBankAccount {
  return {
    bank: asStr(raw.bank ?? raw.bank_name ?? 'BANK'),
    account_number: asStr(raw.account_number ?? raw.no_rekening ?? ''),
    account_name: asStr(raw.account_name ?? raw.nama_pemilik ?? ''),
    branch: raw.branch ?? null,
  };
}

function humanError(e: unknown, fallback: string): string {
  // axios error
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
