/**
 * Billing types — full parity with Flutter `lib/features/finance/domain/models`.
 *
 * Shared canonical types used by both parent surface (Bill + Checkout +
 * Kuitansi) and admin surface (Operasional Keuangan hub — Bill /
 * Pembayaran / Jenis tabs).
 *
 * Status normalization
 * --------------------
 * Backend stores bills as `paid | unpaid | pending | verified` and
 * payments as `pending | verified | success | rejected` — with assorted
 * informal synonyms (`lunas`, `paid`) sprinkled across legacy data. We
 * collapse those to the canonical UI buckets below via
 * `normalizeBillStatus` / `normalizePaymentStatus` so screens only ever
 * branch on the canonical labels.
 */

// ───────────────────────────────────────────────────────────────────
// Bill (parent + admin)
// ───────────────────────────────────────────────────────────────────

/** UI bucket. Backend `paid | verified | lunas` → 'paid'. */
export type BillStatus = 'paid' | 'overdue' | 'soon' | 'pending';

export type BillRawStatus = 'paid' | 'verified' | 'unpaid' | 'pending';

export interface PaymentTypeMini {
  id: string;
  name: string;
  description?: string | null;
  /** Canonical English value: monthly / yearly / once. */
  period?: string | null;
}

export interface StudentMini {
  id: string;
  name: string;
  student_number?: string | null;
  nisn?: string | null;
  class_name?: string | null;
}

export interface LatestPaymentMini {
  id: string;
  status: string;
  amount: number;
  payment_method?: string | null;
  payment_date?: string | null;
  verified_at?: string | null;
  verifier_name?: string | null;
  payment_proof_url?: string | null;
}

export interface Bill {
  id: string;
  /** Display label e.g. "SPP Mei 2024". Derived from paymentType.name + period. */
  title: string;
  /** Optional subtitle (e.g. "Bulanan · SD Insan Kamil"). */
  subtitle?: string | null;
  amount: number;
  due_date?: string | null;
  /** Negative when overdue, 0 when due today. */
  due_in_days?: number | null;
  raw_status: BillRawStatus | string;
  status: BillStatus;
  is_overdue: boolean;
  overdue_days: number;
  is_read: boolean;
  reminder_count: number;
  last_reminded_at?: string | null;
  description?: string | null;
  month?: string | null;
  academic_year_id?: string | null;
  payment_type?: PaymentTypeMini | null;
  student?: StudentMini | null;
  latest_payment?: LatestPaymentMini | null;
  payment_proof_url?: string | null;
}

// ───────────────────────────────────────────────────────────────────
// Bill group — admin Bill hub (one row per payment_type × class × AY)
// ───────────────────────────────────────────────────────────────────

export interface BillGroup {
  payment_type_id: string;
  payment_type_name: string;
  class_id: string;
  class_name: string;
  class_grade_level?: string | null;
  academic_year_id?: string | null;
  year_label?: string | null;
  total_count: number;
  paid_count: number;
  unpaid_count: number;
  overdue_count: number;
  total_amount: number;
  paid_amount: number;
  /** Computed helpers (filled client-side). */
  outstanding_amount?: number;
  completion_pct?: number;
}

/** Tingkat bucket — used to group BillGroup rows in the admin UI. */
export interface BillTingkatBucket {
  grade_level: string;
  label: string;
  groups: BillGroup[];
  /** Distinct classes inside this tingkat — drives the "Per kelas:"
   *  drill chips in the admin Bill tab. Sorted alphabetically. */
  classes: { id: string; name: string }[];
  total_amount: number;
  paid_amount: number;
  outstanding_amount: number;
}

// ───────────────────────────────────────────────────────────────────
// Checkout session (parent QRIS / VA / Manual)
// ───────────────────────────────────────────────────────────────────

export interface ManualBankAccount {
  bank: string;
  account_number: string;
  account_name: string;
  branch?: string | null;
}

export interface CheckoutSession {
  bill_id: string;
  amount: number;
  qris_admin_fee: number;
  va_admin_fee: number;
  manual_admin_fee: number;
  qr_string: string;
  va_number: string;
  va_bank: string;
  manual_bank_list: ManualBankAccount[];
  expires_at: string;
  student_name?: string | null;
  bill_name?: string | null;
}

export type CheckoutMethod = 'qris' | 'va' | 'manual';

// ───────────────────────────────────────────────────────────────────
// Payment (admin verifikasi + parent kuitansi)
// ───────────────────────────────────────────────────────────────────

export type PaymentStatus = 'pending' | 'verified' | 'rejected';
export type PaymentRawStatus = 'pending' | 'verified' | 'success' | 'paid' | 'rejected';

export interface Payment {
  id: string;
  bill_id: string;
  school_id?: string;
  amount: number;
  payment_method?: string | null;
  payment_date?: string | null;
  payment_receipt?: string | null;
  payment_proof_url?: string | null;
  raw_status: PaymentRawStatus | string;
  status: PaymentStatus;
  verified_at?: string | null;
  verified_by?: string | null;
  verifier_name?: string | null;
  admin_notes?: string | null;
  created_at?: string | null;
  bill?: Bill | null;
}

// ───────────────────────────────────────────────────────────────────
// Money flow (admin hub hero)
// ───────────────────────────────────────────────────────────────────

export interface MoneyFlowSummary {
  income: {
    amount: number;
    transaction_count: number;
    delta_pct_vs_last_month: number | null;
  };
  outstanding: { amount: number; count: number };
  overdue: { amount: number; count: number; guardians_count: number };
  flow_bar: { paid_pct: number; outstanding_pct: number; overdue_pct: number };
  period: { month: string; academic_year_id?: string | null };
  computed_at?: string;
}

export interface DashboardStats {
  pendapatan_bulan_ini: number;
  tagihan_belum_dibayar: number;
  pembayaran_pending: number;
  tagihan_terverifikasi: number;
  chart_data: { month: string; total: number }[];
  generated_batches: {
    payment_type_id: string;
    name: string;
    amount: number;
    month: string;
    count: number;
  }[];
}

// ───────────────────────────────────────────────────────────────────
// Payment Type (Jenis Pembayaran)
// ───────────────────────────────────────────────────────────────────

export type PaymentTypeStatus = 'active' | 'inactive';
export type PaymentTypePeriod = 'once' | 'monthly' | 'yearly';
/** @deprecated Use PaymentTypePeriod. */
export type PaymentTypePeriode = PaymentTypePeriod;

export interface PaymentType {
  id: string;
  school_id?: string;
  name: string;
  description?: string | null;
  amount: number;
  /** Canonical English value: monthly / yearly / once. */
  period: PaymentTypePeriod | string;
  status: PaymentTypeStatus | string;
  goal?: string | null;
  start_date?: string | null;
  day_of_month?: number | null;
  created_at?: string | null;
  updated_at?: string | null;
}

export interface PaymentTypePayload {
  name: string;
  description?: string | null;
  amount: number;
  /** Canonical English value: monthly / yearly / once. */
  period: string;
  status?: string;
  goal?: string | null;
  start_date?: string | null;
  day_of_month?: number | null;
}

// ───────────────────────────────────────────────────────────────────
// Generate bill (admin bulk)
// ───────────────────────────────────────────────────────────────────

export interface GenerateBillPayload {
  payment_type_id?: string | null;
  month: string; // YYYY-MM
  academic_year_id: string | number;
}

export interface GenerateBillResult {
  created: number;
  skipped: number;
  skipped_reasons: Record<string, number>;
}

// ───────────────────────────────────────────────────────────────────
// Invoice report (per-student)
// ───────────────────────────────────────────────────────────────────

export interface InvoiceReportRow {
  student_id: string;
  student_name: string;
  student_number?: string | null;
  class_name?: string | null;
  total_bills: number;
  paid_bills: number;
  pending_bills: number;
  unpaid_bills: number;
  total_amount: number;
  paid_amount: number;
  outstanding_amount: number;
}

// ───────────────────────────────────────────────────────────────────
// Status label maps
// ───────────────────────────────────────────────────────────────────

export const BILL_STATUS_LABELS: Record<BillStatus, string> = {
  paid: 'Lunas',
  overdue: 'Telat',
  soon: 'Segera',
  pending: 'Belum lunas',
};

export const BILL_STATUS_TONES: Record<BillStatus, { bg: string; text: string; chip: string }> = {
  paid: { bg: 'bg-emerald-100', text: 'text-emerald-700', chip: 'bg-emerald-50 text-emerald-700' },
  overdue: { bg: 'bg-red-100', text: 'text-red-700', chip: 'bg-red-50 text-red-700' },
  soon: { bg: 'bg-amber-100', text: 'text-amber-700', chip: 'bg-amber-50 text-amber-700' },
  pending: { bg: 'bg-slate-100', text: 'text-slate-600', chip: 'bg-slate-50 text-slate-600' },
};

export const PAYMENT_STATUS_LABELS: Record<PaymentStatus, string> = {
  pending: 'Menunggu',
  verified: 'Terverifikasi',
  rejected: 'Ditolak',
};

export const PAYMENT_STATUS_TONES: Record<PaymentStatus, { bg: string; text: string }> = {
  pending: { bg: 'bg-amber-100', text: 'text-amber-700' },
  verified: { bg: 'bg-emerald-100', text: 'text-emerald-700' },
  rejected: { bg: 'bg-red-100', text: 'text-red-700' },
};

export const PERIOD_LABELS: Record<string, string> = {
  // Canonical English values
  monthly: 'Bulanan',
  yearly: 'Tahunan',
  once: 'Sekali',
  // Legacy Indonesian / upper-case fallbacks
  bulanan: 'Bulanan',
  MONTHLY: 'Bulanan',
  tahunan: 'Tahunan',
  YEARLY: 'Tahunan',
  sekali: 'Sekali',
  ONCE: 'Sekali',
};

/** @deprecated Use PERIOD_LABELS. */
export const PERIODE_LABELS = PERIOD_LABELS;

/** Normalise legacy values to canonical English. */
export function normalizePaymentTypePeriod(
  raw: string | null | undefined,
): PaymentTypePeriod | string {
  if (!raw) return 'monthly';
  const v = String(raw).toLowerCase().trim();
  if (v === 'monthly' || v === 'bulanan') return 'monthly';
  if (v === 'yearly' || v === 'tahunan') return 'yearly';
  if (v === 'once' || v === 'sekali') return 'once';
  return v;
}

// ───────────────────────────────────────────────────────────────────
// Normalisers
// ───────────────────────────────────────────────────────────────────

export function normalizeBillStatus(
  raw: string | null | undefined,
  opts: { dueInDays?: number | null; isOverdue?: boolean } = {},
): BillStatus {
  const s = String(raw ?? '').toLowerCase().trim();
  if (s === 'paid' || s === 'verified' || s === 'lunas' || s === 'success') return 'paid';
  if (opts.isOverdue === true) return 'overdue';
  const days = opts.dueInDays;
  if (typeof days === 'number' && Number.isFinite(days)) {
    if (days < 0) return 'overdue';
    if (days <= 3) return 'soon';
  }
  return 'pending';
}

export function normalizePaymentStatus(raw: string | null | undefined): PaymentStatus {
  const s = String(raw ?? '').toLowerCase().trim();
  if (s === 'verified' || s === 'success' || s === 'paid' || s === 'lunas') return 'verified';
  if (s === 'rejected' || s === 'ditolak') return 'rejected';
  return 'pending';
}

export function periodLabel(raw: string | null | undefined): string {
  if (!raw) return '—';
  return PERIOD_LABELS[raw] ?? PERIOD_LABELS[String(raw).toLowerCase()] ?? String(raw);
}

/** @deprecated Use periodLabel. */
export const periodeLabel = periodLabel;
