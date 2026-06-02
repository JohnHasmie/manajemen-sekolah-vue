/**
 * FinanceService — admin surface for Operasional Keuangan.
 *
 * Mirrors Flutter's `lib/features/finance/data/finance_service.dart`
 * admin calls. Backed by Laravel `/finance/*`, `/bills*`, `/payments*`,
 * `/payment-types*`, and `/generate-bill`.
 *
 * Endpoints:
 *   GET    /finance/money-flow                    — hub hero
 *   GET    /finance/dashboard                     — KPI strip + chart
 *   GET    /finance/bill-groups                   — Tagihan tab (aggregated)
 *   GET    /finance/available-years               — AY chip options
 *   GET    /bills?payment_type_id=…&class_id=…    — per-bucket drill
 *   POST   /bills                                 — create single bill
 *   PUT    /bills/{id}                            — update single bill
 *   POST   /finance/bills/{id}/remind             — record reminder send
 *   GET    /payments                              — Pembayaran tab (paginated)
 *   PUT    /payment/{id}/verify                   — verify / reject
 *   GET    /finance/invoice-report                — per-student grouped roster
 *   GET    /payment-types                         — Jenis tab list
 *   POST   /payment-types                         — create jenis (auto-generates bills if active)
 *   PUT    /payment-types/{id}                    — update jenis
 *   DELETE /payment-types/{id}                    — destroy jenis
 *   PATCH  /payment-types/{id}/status             — toggle active/inactive
 *   POST   /generate-bill                         — bulk generate for one month
 */
import { api } from '@/lib/http';
import {
  billFromJson,
  paymentFromJson,
} from '@/services/billing.service';
import type {
  Bill,
  BillGroup,
  DashboardStats,
  GenerateBillPayload,
  GenerateBillResult,
  InvoiceReportRow,
  MoneyFlowSummary,
  Payment,
  PaymentType,
  PaymentTypePayload,
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

// ───────────────────────────────────────────────────────────────────
// Parsers
// ───────────────────────────────────────────────────────────────────

function billGroupFromJson(raw: any): BillGroup {
  const total = asNum(raw.total_amount);
  const paid = asNum(raw.paid_amount);
  return {
    payment_type_id: asStr(raw.payment_type_id),
    payment_type_name: asStr(raw.payment_type_name, 'Tagihan'),
    class_id: asStr(raw.class_id),
    class_name: asStr(raw.class_name),
    class_grade_level: raw.class_grade_level ? String(raw.class_grade_level) : null,
    academic_year_id: raw.academic_year_id ? String(raw.academic_year_id) : null,
    year_label: raw.year_label ?? null,
    total_count: asNum(raw.total_count),
    paid_count: asNum(raw.paid_count),
    unpaid_count: asNum(raw.unpaid_count),
    overdue_count: asNum(raw.overdue_count),
    total_amount: total,
    paid_amount: paid,
    outstanding_amount: Math.max(0, total - paid),
    completion_pct: total > 0 ? Math.round((paid / total) * 1000) / 10 : 0,
  };
}

function paymentTypeFromJson(raw: any): PaymentType {
  // Canonical column is `payment_types.period` (was `periode`).
  return {
    id: asStr(raw.id),
    school_id: raw.school_id ?? undefined,
    name: asStr(raw.name),
    description: raw.description ?? null,
    amount: asNum(raw.amount),
    period: asStr(raw.period ?? raw.periode ?? 'once'),
    status: asStr(raw.status ?? 'active'),
    goal: raw.goal ?? null,
    start_date: raw.start_date ?? null,
    day_of_month: raw.day_of_month ?? null,
    created_at: raw.created_at ?? null,
    updated_at: raw.updated_at ?? null,
  };
}

function moneyFlowFromJson(raw: any): MoneyFlowSummary {
  const income = raw?.income ?? {};
  const outstanding = raw?.outstanding ?? {};
  const overdue = raw?.overdue ?? {};
  const flow = raw?.flow_bar ?? {};
  const period = raw?.period ?? {};
  return {
    income: {
      amount: asNum(income.amount),
      transaction_count: asNum(income.transaction_count),
      delta_pct_vs_last_month:
        income.delta_pct_vs_last_month === null || income.delta_pct_vs_last_month === undefined
          ? null
          : asNum(income.delta_pct_vs_last_month),
    },
    outstanding: { amount: asNum(outstanding.amount), count: asNum(outstanding.count) },
    overdue: {
      amount: asNum(overdue.amount),
      count: asNum(overdue.count),
      guardians_count: asNum(overdue.guardians_count),
    },
    flow_bar: {
      paid_pct: asNum(flow.paid_pct),
      outstanding_pct: asNum(flow.outstanding_pct),
      overdue_pct: asNum(flow.overdue_pct),
    },
    period: {
      month: asStr(period.month, ''),
      academic_year_id: period.academic_year_id ?? null,
    },
    computed_at: raw?.computed_at,
  };
}

function dashboardFromJson(raw: any): DashboardStats {
  return {
    pendapatan_bulan_ini: asNum(raw?.pendapatan_bulan_ini),
    tagihan_belum_dibayar: asNum(raw?.tagihan_belum_dibayar),
    pembayaran_pending: asNum(raw?.pembayaran_pending),
    tagihan_terverifikasi: asNum(raw?.tagihan_terverifikasi),
    chart_data: Array.isArray(raw?.chart_data)
      ? raw.chart_data.map((r: any) => ({
          month: asStr(r.month),
          total: asNum(r.total),
        }))
      : [],
    generated_batches: Array.isArray(raw?.generated_batches)
      ? raw.generated_batches.map((r: any) => ({
          payment_type_id: asStr(r.payment_type_id),
          name: asStr(r.name),
          amount: asNum(r.amount),
          month: asStr(r.month),
          count: asNum(r.count),
        }))
      : [],
  };
}

function invoiceRowFromJson(raw: any): InvoiceReportRow {
  // The backend invoice-report joins per-student stats. Field names
  // vary across versions — accept both snake_case and the older
  // grouped shapes.
  return {
    student_id: asStr(raw.student_id ?? raw.id),
    student_name: asStr(raw.student_name ?? raw.name),
    student_number: raw.student_number ?? null,
    class_name: raw.class_name ?? raw.class?.name ?? null,
    total_bills: asNum(raw.total_bills ?? raw.bills_count),
    paid_bills: asNum(raw.paid_bills ?? raw.paid_count),
    pending_bills: asNum(raw.pending_bills ?? raw.pending_count),
    unpaid_bills: asNum(raw.unpaid_bills ?? raw.unpaid_count),
    total_amount: asNum(raw.total_amount),
    paid_amount: asNum(raw.paid_amount),
    outstanding_amount: asNum(raw.outstanding_amount ?? (asNum(raw.total_amount) - asNum(raw.paid_amount))),
  };
}

// ───────────────────────────────────────────────────────────────────
// Filters
// ───────────────────────────────────────────────────────────────────

export interface BillGroupFilters {
  academic_year_id?: string | number | null;
  status?: 'paid' | 'unpaid' | 'pending' | 'verified';
  payment_type_id?: string;
  payment_type_ids?: string[];
  class_ids?: string[];
  grade_levels?: string[];
  month?: string | number; // YYYY-MM or 1-12
  year?: string | number;
}

export interface BillListFilters extends BillGroupFilters {
  student_id?: string;
  class_id?: string;
  per_page?: number;
  page?: number;
}

export interface PaymentListFilters {
  status?: 'pending' | 'verified' | 'rejected' | 'success';
  bill_id?: string;
  academic_year_id?: string | number;
  per_page?: number;
  page?: number;
}

export interface PaginatedList<T> {
  items: T[];
  total: number;
  current_page: number;
  last_page: number;
  per_page: number;
}

function parsePaginatedBills(body: any): PaginatedList<Bill> {
  const data = Array.isArray(body?.data) ? body.data : Array.isArray(body) ? body : [];
  return {
    items: data.map(billFromJson),
    total: asNum(body?.total ?? data.length),
    current_page: asNum(body?.current_page ?? 1),
    last_page: asNum(body?.last_page ?? 1),
    per_page: asNum(body?.per_page ?? data.length ?? 0),
  };
}

function parsePaginatedPayments(body: any): PaginatedList<Payment> {
  const data = Array.isArray(body?.data) ? body.data : Array.isArray(body) ? body : [];
  return {
    items: data.map(paymentFromJson),
    total: asNum(body?.total ?? data.length),
    current_page: asNum(body?.current_page ?? 1),
    last_page: asNum(body?.last_page ?? 1),
    per_page: asNum(body?.per_page ?? data.length ?? 0),
  };
}

// ───────────────────────────────────────────────────────────────────
// Service
// ───────────────────────────────────────────────────────────────────

export const FinanceService = {
  // ── Hub hero ──────────────────────────────────────────────────────
  async moneyFlow(filters: { academic_year_id?: string } = {}): Promise<MoneyFlowSummary> {
    try {
      const res = await api.get('/finance/money-flow', { params: filters });
      const body = res.data?.data ?? res.data;
      return moneyFlowFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat ringkasan keuangan.'));
    }
  },

  async dashboardStats(filters: { academic_year_id?: string } = {}): Promise<DashboardStats> {
    try {
      const res = await api.get('/finance/dashboard', { params: filters });
      return dashboardFromJson(res.data?.data ?? res.data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat dashboard keuangan.'));
    }
  },

  async availableYears(): Promise<{ id: string | number; year: string; current?: boolean }[]> {
    try {
      const res = await api.get('/finance/available-years');
      const data = res.data?.data ?? res.data ?? [];
      return Array.isArray(data) ? data : [];
    } catch {
      return [];
    }
  },

  // ── Tagihan tab ──────────────────────────────────────────────────
  async billGroups(filters: BillGroupFilters = {}): Promise<BillGroup[]> {
    try {
      const params = sanitize(filters);
      const res = await api.get('/finance/bill-groups', { params });
      const data = res.data?.data ?? res.data ?? [];
      return Array.isArray(data) ? data.map(billGroupFromJson) : [];
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat tagihan.'));
    }
  },

  async listBills(filters: BillListFilters = {}): Promise<PaginatedList<Bill>> {
    try {
      const params = sanitize({ per_page: 100, ...filters });
      const res = await api.get('/bills', { params });
      return parsePaginatedBills(res.data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat daftar tagihan.'));
    }
  },

  async createBill(payload: {
    student_id: string;
    payment_type_id: string;
    amount: number;
    due_date: string;
    description?: string;
  }): Promise<Bill> {
    try {
      const res = await api.post('/bills', payload);
      const body = res.data?.data ?? res.data;
      return billFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal membuat tagihan.'));
    }
  },

  async updateBill(
    id: string,
    payload: { status?: string; amount?: number; due_date?: string; description?: string },
  ): Promise<Bill> {
    try {
      const res = await api.put(`/bills/${id}`, payload);
      const body = res.data?.data ?? res.data;
      return billFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui tagihan.'));
    }
  },

  /**
   * POST /finance/bills/{id}/remind — record a reminder send.
   * Persists reminder_count + last_reminded_at. The actual outbound
   * WhatsApp/Email is dispatched by a downstream job.
   */
  async remindBill(billId: string, channel: 'whatsapp' | 'email'): Promise<{
    reminder_count: number;
    last_reminded_at: string;
    channel: string;
  }> {
    try {
      const res = await api.post(`/finance/bills/${billId}/remind`, { channel });
      const body = res.data?.data ?? res.data;
      return {
        reminder_count: asNum(body?.reminder_count),
        last_reminded_at: asStr(body?.last_reminded_at),
        channel: asStr(body?.channel ?? channel),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengirim pengingat.'));
    }
  },

  // ── Pembayaran tab ───────────────────────────────────────────────
  async listPayments(filters: PaymentListFilters = {}): Promise<PaginatedList<Payment>> {
    try {
      const params = sanitize({ per_page: 50, ...filters });
      const res = await api.get('/payments', { params });
      return parsePaginatedPayments(res.data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat pembayaran.'));
    }
  },

  async verifyPayment(
    paymentId: string,
    payload: {
      status: 'verified' | 'pending' | 'rejected';
      admin_notes?: string;
    },
  ): Promise<Payment> {
    try {
      const res = await api.put(`/payment/${paymentId}/verify`, payload);
      const body = res.data?.data ?? res.data;
      return paymentFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui status pembayaran.'));
    }
  },

  /**
   * GET /payment/{id}/receipt — streaming kuitansi blob.
   * Same helper as parent-side, exposed here for admin verifikasi modal.
   */
  async fetchReceiptBlob(paymentId: string): Promise<Blob> {
    const res = await api.get(`/payment/${paymentId}/receipt`, {
      responseType: 'blob',
    });
    return res.data as Blob;
  },

  // ── Per-student invoice report (per-class drill) ─────────────────
  async invoiceReport(filters: {
    academic_year_id?: string;
    class_id?: string;
    status?: 'paid' | 'pending' | 'unpaid';
    payment_type_id?: string;
    search?: string;
    per_page?: number;
    page?: number;
  } = {}): Promise<PaginatedList<InvoiceReportRow>> {
    try {
      const params = sanitize({ per_page: 50, ...filters });
      const res = await api.get('/finance/invoice-report', { params });
      const body = res.data;
      const data = Array.isArray(body?.data) ? body.data : Array.isArray(body) ? body : [];
      return {
        items: data.map(invoiceRowFromJson),
        total: asNum(body?.total ?? data.length),
        current_page: asNum(body?.current_page ?? 1),
        last_page: asNum(body?.last_page ?? 1),
        per_page: asNum(body?.per_page ?? data.length ?? 0),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat laporan tagihan.'));
    }
  },

  // ── Jenis pembayaran ─────────────────────────────────────────────
  async listPaymentTypes(filters: { status?: 'active' | 'inactive'; period?: string; search?: string } = {}): Promise<PaymentType[]> {
    try {
      const params = sanitize({ per_page: 100, ...filters });
      const res = await api.get('/payment-types', { params });
      const body = res.data;
      // Paginated when per_page is passed; envelope when not.
      const list = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : Array.isArray(body?.data?.data)
            ? body.data.data
            : [];
      return list.map(paymentTypeFromJson);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat jenis pembayaran.'));
    }
  },

  async getPaymentType(id: string): Promise<PaymentType> {
    try {
      const res = await api.get(`/payment-types/${id}`);
      const body = res.data?.data ?? res.data;
      return paymentTypeFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat jenis pembayaran.'));
    }
  },

  async createPaymentType(payload: PaymentTypePayload): Promise<{
    type: PaymentType;
    bills_generated: number;
    bills_skipped: number;
    bills_skipped_reasons: Record<string, number>;
  }> {
    try {
      const res = await api.post('/payment-types', payload);
      const body = res.data ?? {};
      return {
        type: paymentTypeFromJson(body.data ?? {}),
        bills_generated: asNum(body.bills_generated),
        bills_skipped: asNum(body.bills_skipped),
        bills_skipped_reasons: (body.bills_skipped_reasons as Record<string, number>) ?? {},
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menyimpan jenis pembayaran.'));
    }
  },

  async updatePaymentType(id: string, payload: PaymentTypePayload): Promise<PaymentType> {
    try {
      const res = await api.put(`/payment-types/${id}`, payload);
      const body = res.data?.data ?? res.data;
      return paymentTypeFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui jenis pembayaran.'));
    }
  },

  async destroyPaymentType(id: string): Promise<void> {
    try {
      await api.delete(`/payment-types/${id}`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus jenis pembayaran.'));
    }
  },

  async setPaymentTypeStatus(id: string, status: 'active' | 'inactive'): Promise<PaymentType> {
    try {
      const res = await api.patch(`/payment-types/${id}/status`, { status });
      const body = res.data?.data ?? res.data;
      return paymentTypeFromJson(body);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengubah status jenis pembayaran.'));
    }
  },

  // ── Generate bills ───────────────────────────────────────────────
  async generateBills(payload: GenerateBillPayload): Promise<GenerateBillResult> {
    try {
      const res = await api.post('/generate-bill', payload);
      const body = res.data ?? {};
      return {
        created: asNum(body.created ?? body.data?.created),
        skipped: asNum(body.skipped ?? body.data?.skipped),
        skipped_reasons:
          (body.skipped_reasons as Record<string, number>) ??
          (body.data?.skipped_reasons as Record<string, number>) ?? {},
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal generate tagihan.'));
    }
  },

  /**
   * GET /finance/generated-months — list months for which bills have
   * already been generated for a given payment type. Used by the
   * generate-bill modal to disable months that would create
   * duplicates.
   */
  async generatedMonths(filters: { payment_type_id?: string; academic_year_id?: string } = {}): Promise<string[]> {
    try {
      const res = await api.get('/finance/generated-months', { params: sanitize(filters) });
      const data = res.data?.data ?? res.data ?? [];
      return Array.isArray(data) ? data.map((m: any) => String(m)) : [];
    } catch {
      return [];
    }
  },
};

// ───────────────────────────────────────────────────────────────────
// Helpers
// ───────────────────────────────────────────────────────────────────

function sanitize(obj: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null || v === '') continue;
    if (Array.isArray(v) && v.length === 0) continue;
    out[k] = v;
  }
  return out;
}
