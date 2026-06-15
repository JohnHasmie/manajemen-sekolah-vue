<!--
  AdminClassFinanceReportView.vue — admin Laporan Keuangan per Kelas.

  Mirrors Flutter's `class_finance_report_screen.dart`. Per-class
  drill showing every student in the class with their billing
  totals + outstanding count + paid percentage, filterable by
  payment status. Tap a row to drill into the existing bill-group
  detail for that student × payment type.

  Route: `/admin/finance/class/:classId`
    - reads `:className` and `:academicYearId` from query
    - reads `classId` from path param

  Endpoints:
    GET /student/class/{classId}              — roster
    GET /bills?class_id&academic_year_id      — every bill in the class
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { FinanceService } from '@/services/finance.service';
import { StudentService } from '@/services/students.service';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import type { Bill } from '@/types/billing';
import type { Student } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const ayStore = useAcademicYearStore();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));
const classNameQ = computed(() => String(route.query.className ?? '—'));

// ── Data ──────────────────────────────────────────────────────────
const students = ref<Student[]>([]);
const bills = ref<Bill[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
// Which student's per-bill detail is expanded inline (null = none).
const expandedStudentId = ref<string | null>(null);

async function reload() {
  if (!classId.value) {
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    const ayId = ayStore.selectedYearId ?? undefined;
    const [roster, billPage] = await Promise.all([
      StudentService.byClass(classId.value, { academic_year_id: ayId }),
      FinanceService.listBills({
        class_id: classId.value,
        academic_year_id: ayId ?? undefined,
        per_page: 1000,
      }),
    ]);
    students.value = roster;
    bills.value = billPage.items;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(reload);
useAcademicYearWatcher(reload);
watch(classId, reload);

// ── Per-student aggregation ──────────────────────────────────────
interface StudentBillSummary {
  student: Student;
  bills: Bill[];
  total_amount: number;
  paid_amount: number;
  outstanding_amount: number;
  paid_count: number;
  total_count: number;
  /** 0..100 — drives the progress bar and the chip tone. */
  paid_pct: number;
  /** Bucket: 'lunas' if paid_pct === 100, 'partial' if 0<…<100, else 'belum'. */
  bucket: 'lunas' | 'partial' | 'belum';
}

const summaries = computed<StudentBillSummary[]>(() => {
  const byStudent = new Map<string, Bill[]>();
  for (const b of bills.value) {
    const sid = String(b.student?.id ?? '');
    if (!sid) continue;
    if (!byStudent.has(sid)) byStudent.set(sid, []);
    byStudent.get(sid)!.push(b);
  }
  return students.value
    .map((s): StudentBillSummary => {
      const myBills = byStudent.get(s.id) ?? [];
      let total = 0,
        paid = 0,
        paid_count = 0;
      for (const b of myBills) {
        total += b.amount;
        // Heuristic: status='paid' contributes the full amount; partial uses
        // latest_payment hint if present; otherwise nothing counted as paid.
        if (b.status === 'paid' || b.raw_status === 'paid') {
          paid += b.amount;
          paid_count += 1;
        } else if (b.latest_payment?.amount) {
          paid += Number(b.latest_payment.amount) || 0;
        }
      }
      const outstanding = Math.max(0, total - paid);
      const pct = total > 0 ? Math.round((paid / total) * 100) : 0;
      const bucket: StudentBillSummary['bucket'] =
        total === 0
          ? 'lunas'
          : pct >= 100
            ? 'lunas'
            : pct > 0
              ? 'partial'
              : 'belum';
      return {
        student: s,
        bills: myBills,
        total_amount: total,
        paid_amount: paid,
        outstanding_amount: outstanding,
        paid_count,
        total_count: myBills.length,
        paid_pct: pct,
        bucket,
      };
    })
    .sort((a, b) => {
      // Outstanding first (so admins see overdue students at the top),
      // then alphabetical by student name.
      const bucketOrder = { belum: 0, partial: 1, lunas: 2 } as const;
      const cmp = bucketOrder[a.bucket] - bucketOrder[b.bucket];
      if (cmp !== 0) return cmp;
      return (a.student.name ?? '').localeCompare(b.student.name ?? '');
    });
});

// ── Filter state ─────────────────────────────────────────────────
type FilterKey = 'all' | 'lunas' | 'partial' | 'belum';
const activeFilter = ref<FilterKey>('all');

const FILTERS = computed<{ key: FilterKey; label: string }[]>(() => [
  { key: 'all', label: t('admin.sekolah.class_finance.filter_all') },
  { key: 'belum', label: t('admin.sekolah.class_finance.filter_unpaid') },
  { key: 'partial', label: t('admin.sekolah.class_finance.filter_partial') },
  { key: 'lunas', label: t('admin.sekolah.class_finance.filter_paid') },
]);

const filtered = computed(() =>
  activeFilter.value === 'all'
    ? summaries.value
    : summaries.value.filter((s) => s.bucket === activeFilter.value),
);

const bucketCounts = computed(() => ({
  all: summaries.value.length,
  lunas: summaries.value.filter((s) => s.bucket === 'lunas').length,
  partial: summaries.value.filter((s) => s.bucket === 'partial').length,
  belum: summaries.value.filter((s) => s.bucket === 'belum').length,
}));

// ── KPI ──────────────────────────────────────────────────────────
const totals = computed(() => {
  let total = 0,
    paid = 0,
    outstanding = 0;
  for (const s of summaries.value) {
    total += s.total_amount;
    paid += s.paid_amount;
    outstanding += s.outstanding_amount;
  }
  return { total, paid, outstanding };
});

const fmtIDR = (n: number) =>
  n.toLocaleString('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  });

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: t('admin.sekolah.class_finance.kpi_students'),
    value: students.value.length,
    tone: 'brand',
  },
  {
    icon: 'wallet',
    label: t('admin.sekolah.class_finance.kpi_total'),
    value: fmtIDR(totals.value.total),
    tone: 'violet',
  },
  {
    icon: 'check-circle',
    label: t('admin.sekolah.class_finance.kpi_paid'),
    value: fmtIDR(totals.value.paid),
    tone: 'green',
  },
  {
    icon: 'clock',
    label: t('admin.sekolah.class_finance.kpi_outstanding'),
    value: fmtIDR(totals.value.outstanding),
    tone: totals.value.outstanding > 0 ? 'amber' : 'slate',
  },
]);

// ── AsyncView state ──────────────────────────────────────────────
const listState = computed<AsyncState<StudentBillSummary[]>>(() => {
  if (isLoading.value && students.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filtered.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filtered.value };
});

// ── UI helpers ───────────────────────────────────────────────────
function bucketBadgeCls(bucket: StudentBillSummary['bucket']): string {
  if (bucket === 'lunas') return 'bg-emerald-100 text-emerald-700';
  if (bucket === 'partial') return 'bg-amber-100 text-amber-700';
  return 'bg-red-100 text-red-700';
}
function bucketLabel(bucket: StudentBillSummary['bucket']): string {
  if (bucket === 'lunas') return t('admin.sekolah.class_finance.bucket_paid');
  if (bucket === 'partial') return t('admin.sekolah.class_finance.bucket_partial');
  return t('admin.sekolah.class_finance.bucket_unpaid');
}
function progressBarCls(bucket: StudentBillSummary['bucket']): string {
  if (bucket === 'lunas') return 'bg-emerald-500';
  if (bucket === 'partial') return 'bg-amber-500';
  return 'bg-red-500';
}

function openStudent(s: StudentBillSummary) {
  // Toggle an inline per-student bill detail. This view already aggregates
  // each student's bills (StudentBillSummary.bills), so we expand them in
  // place — there's no per-student drill route on the admin side, and the
  // old behaviour just showed a toast telling admins to go to the Tagihan
  // tab, which is what the bug report was about.
  expandedStudentId.value =
    expandedStudentId.value === s.student.id ? null : s.student.id;
}

/** Status chip label + colour for a single bill in the expanded detail. */
function billStatusChip(b: Bill): { label: string; cls: string } {
  if (b.status === 'paid') {
    return { label: t('admin.sekolah.class_finance.bill_paid'), cls: 'text-emerald-600' };
  }
  if (b.status === 'overdue' || b.is_overdue) {
    return { label: t('admin.sekolah.class_finance.bill_overdue'), cls: 'text-red-600' };
  }
  if (b.latest_payment?.amount) {
    return { label: t('admin.sekolah.class_finance.bill_partial'), cls: 'text-amber-600' };
  }
  return { label: t('admin.sekolah.class_finance.bill_unpaid'), cls: 'text-slate-500' };
}

function goBack() {
  router.push({ name: 'admin.finance.tagihan' });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('admin.sekolah.class_finance.back_to_finance') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.class_finance.header_kicker')"
      :title="t('admin.sekolah.class_finance.header_title', { className: classNameQ })"
      :meta="t('admin.sekolah.class_finance.header_meta', { studentCount: students.length, billCount: bills.length })"
      :live-dot="false"
    />

    <KpiStripCards :cards="kpiCards" />

    <!-- Filter bucket chips -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="f in FILTERS"
        :key="f.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border inline-flex items-center gap-1.5"
        :class="
          activeFilter === f.key
            ? 'bg-role-admin text-white border-role-admin shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-slate-400'
        "
        @click="activeFilter = f.key"
      >
        {{ f.label }}
        <span
          class="text-[9.5px] font-black px-1.5 py-0.5 rounded-md tabular-nums"
          :class="
            activeFilter === f.key
              ? 'bg-white/20 text-white'
              : 'bg-slate-100 text-slate-500'
          "
        >
          {{ bucketCounts[f.key] }}
        </span>
      </button>
    </div>

    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.class_finance.empty_title')"
      :empty-description="t('admin.sekolah.class_finance.empty_description')"
      empty-icon="users"
      @retry="reload"
    >
      <template #default>
        <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
          <div
            v-for="(s, idx) in filtered"
            :key="s.student.id"
            :class="idx > 0 ? 'border-t border-slate-100' : ''"
          >
            <article
              class="px-4 py-3 flex items-center gap-3 hover:bg-slate-50 cursor-pointer transition-colors"
              @click="openStudent(s)"
            >
              <div class="w-10 h-10 rounded-full bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0 text-[12px] font-black">
                {{ (s.student.name ?? '?').slice(0, 1).toUpperCase() }}
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <p class="text-[13.5px] font-bold text-slate-900 truncate">
                    {{ s.student.name }}
                  </p>
                  <span
                    class="px-2 py-0.5 rounded-md text-[9px] font-black tracking-widest"
                    :class="bucketBadgeCls(s.bucket)"
                  >
                    {{ bucketLabel(s.bucket) }}
                  </span>
                </div>
                <p class="text-[11px] text-slate-500 mt-0.5">
                  {{ s.student.student_number || '—' }}
                  {{ t('admin.sekolah.class_finance.paid_summary', { paid: s.paid_count, total: s.total_count }) }}
                </p>
                <!-- Progress bar -->
                <div class="mt-2 h-1.5 rounded-full overflow-hidden bg-slate-100 max-w-xs">
                  <div
                    class="h-full transition-all"
                    :class="progressBarCls(s.bucket)"
                    :style="{ width: `${s.paid_pct}%` }"
                  />
                </div>
              </div>
              <div class="text-right flex-shrink-0">
                <p class="text-[12.5px] font-black text-slate-900 tabular-nums">
                  {{ fmtIDR(s.outstanding_amount) }}
                </p>
                <p class="text-[10px] text-slate-500 tabular-nums">
                  {{ t('admin.sekolah.class_finance.outstanding_label') }}
                </p>
              </div>
              <NavIcon
                name="chevron-right"
                :size="14"
                class="text-slate-300 ml-1 transition-transform"
                :class="expandedStudentId === s.student.id ? 'rotate-90' : ''"
              />
            </article>

            <!-- Inline per-student bill detail (toggled by the row click) -->
            <div
              v-if="expandedStudentId === s.student.id"
              class="px-4 pb-3 -mt-1"
            >
              <p
                v-if="s.bills.length === 0"
                class="text-[11.5px] text-slate-400 py-2"
              >
                {{ t('admin.sekolah.class_finance.no_bills_for_student') }}
              </p>
              <ul
                v-else
                class="rounded-xl border border-slate-100 overflow-hidden divide-y divide-slate-100"
              >
                <li
                  v-for="b in s.bills"
                  :key="b.id"
                  class="px-3 py-2 flex items-center justify-between gap-3 bg-slate-50/60"
                >
                  <div class="min-w-0">
                    <p class="text-[12px] font-semibold text-slate-800 truncate">
                      {{ b.title }}
                    </p>
                    <p
                      v-if="b.is_overdue"
                      class="text-[10px] font-bold text-red-500"
                    >
                      {{ t('admin.sekolah.class_finance.overdue_days', { days: b.overdue_days }) }}
                    </p>
                  </div>
                  <div class="text-right flex-shrink-0">
                    <p class="text-[12px] font-black text-slate-900 tabular-nums">
                      {{ fmtIDR(b.amount) }}
                    </p>
                    <span
                      class="text-[9px] font-black tracking-widest"
                      :class="billStatusChip(b).cls"
                    >{{ billStatusChip(b).label }}</span>
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </section>
      </template>
    </AsyncView>
  </div>
</template>
