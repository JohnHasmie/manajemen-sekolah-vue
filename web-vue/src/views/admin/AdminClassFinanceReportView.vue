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
import Toast from '@/components/ui/Toast.vue';

const route = useRoute();
const router = useRouter();
const ayStore = useAcademicYearStore();

const classId = computed(() => String(route.params.classId ?? ''));
const classNameQ = computed(() => String(route.query.className ?? '—'));

// ── Data ──────────────────────────────────────────────────────────
const students = ref<Student[]>([]);
const bills = ref<Bill[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

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

const FILTERS: { key: FilterKey; label: string }[] = [
  { key: 'all', label: 'Semua' },
  { key: 'belum', label: 'Belum bayar' },
  { key: 'partial', label: 'Sebagian' },
  { key: 'lunas', label: 'Lunas' },
];

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
    label: 'Siswa',
    value: students.value.length,
    tone: 'brand',
  },
  {
    icon: 'wallet',
    label: 'Total Tagihan',
    value: fmtIDR(totals.value.total),
    tone: 'violet',
  },
  {
    icon: 'check-circle',
    label: 'Sudah Bayar',
    value: fmtIDR(totals.value.paid),
    tone: 'green',
  },
  {
    icon: 'clock',
    label: 'Outstanding',
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
  if (bucket === 'lunas') return 'LUNAS';
  if (bucket === 'partial') return 'SEBAGIAN';
  return 'BELUM';
}
function progressBarCls(bucket: StudentBillSummary['bucket']): string {
  if (bucket === 'lunas') return 'bg-emerald-500';
  if (bucket === 'partial') return 'bg-amber-500';
  return 'bg-red-500';
}

function openStudent(_s: StudentBillSummary) {
  // The shared bill-group detail page is keyed by payment_type×class, not
  // student. Without a per-student-bill drill route on the admin side, we
  // surface a toast pointing back to the Tagihan tab for now.
  toast.value = {
    message:
      'Tap salah satu tagihan dari tab Tagihan untuk melihat detail per siswa.',
    tone: 'success',
  };
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
      Keuangan
    </button>

    <BrandPageHeader
      role="admin"
      kicker="Keuangan · Per Kelas"
      :title="`Tagihan ${classNameQ}`"
      :meta="`${students.length} siswa · ${bills.length} tagihan`"
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
      empty-title="Tidak ada siswa di kategori ini"
      empty-description="Coba ubah filter status pembayaran."
      empty-icon="users"
      @retry="reload"
    >
      <template #default>
        <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
          <article
            v-for="(s, idx) in filtered"
            :key="s.student.id"
            class="px-4 py-3 flex items-center gap-3 hover:bg-slate-50 cursor-pointer transition-colors"
            :class="idx > 0 ? 'border-t border-slate-100' : ''"
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
                · {{ s.paid_count }}/{{ s.total_count }} tagihan lunas
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
                outstanding
              </p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300 ml-1" />
          </article>
        </section>
      </template>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
