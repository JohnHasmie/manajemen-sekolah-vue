<!--
  AdminTeacherAttendanceView.vue — admin REPORT for PRESENSI GURU.

  Report-only since the Wave 2 IA refactor: the settings + checkin/
  checkout rules tabs moved to AdminAttendanceConfigView.vue (the
  unified "Pengaturan Kehadiran" screen at /admin/settings/attendance).
  This view now only serves /admin/teacher-attendance/report.

  Two stacked sections sharing one periode (date-range) filter:
    · REKAP per-teacher — aggregated Hadir/Telat/(Alpa/Izin…)/Total/%
      table (GET …/admin/summary) with an Export Excel (CSV) button.
      Status columns are DYNAMIC — driven by meta.statuses.
    · Detail per-baris — the school-scoped per-row list
      (GET …/admin) with the existing date/teacher/status filters,
      collapsible below the rekap.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import { useToast } from '@/composables/useToast';
import type {
  TeacherAttendanceAdminSummary,
  TeacherAttendanceListResult,
  TeacherAttendancePersonnelFilter,
  TeacherAttendanceRecord,
  TeacherAttendanceSummaryRow,
} from '@/types/teacher-attendance';
import {
  teacherAttendanceEmployeeNumber,
  teacherAttendancePersonName,
  teacherAttendancePersonnelLabel,
  teacherAttendanceStatusColumnLabel,
  teacherAttendanceStatusLabel,
} from '@/types/teacher-attendance';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import { useAcademicYearStore } from '@/stores/academic-year';

const toast = useToast();
const { t } = useI18n();
const ayStore = useAcademicYearStore();

type Tab = 'report';
const tab = ref<Tab>('report');

// ─────────────────────────────────────────────────────────────────
// Report — shared periode (date range) filter
//
// The periode drives BOTH the per-teacher rekap (admin/summary) and the
// detail per-row list (admin). Empty bounds let the backend default to
// start-of-month → today.
// ─────────────────────────────────────────────────────────────────
// Rekap periode defaults to the active academic year's start/end so
// the admin sees the year they're working in by default, not just the
// last-30-days slice the backend falls back to. Luay called this out
// (2026-06-29): the filter should follow whatever academic year the
// dashboard picker is on. A watcher below keeps the two in sync —
// flipping the dashboard picker also re-anchors this filter (unless
// the user has manually narrowed it, in which case we leave their
// pick alone). `userTouchedDates` tracks the manual-narrow case.
function ayStart(): string {
  return (ayStore.selectedYear?.start_date ?? '') as string;
}
function ayEnd(): string {
  return (ayStore.selectedYear?.end_date ?? '') as string;
}
const filterStartDate = ref(ayStart());
const filterEndDate = ref(ayEnd());
const filterTeacher = ref('');
const userTouchedDates = ref(false);
/**
 * Personnel-type narrowing for the unified report: Semua | Guru | Staf.
 * Defaults to 'all' (both teachers and staff). Drives the detail per-row
 * list + its CSV export; the segmented control refetches on change.
 */
const filterPersonnelType = ref<TeacherAttendancePersonnelFilter>('all');
const personnelTypeOptions: {
  value: TeacherAttendancePersonnelFilter;
  label: string;
}[] = [
  { value: 'all', label: 'Semua' },
  { value: 'teacher', label: 'Guru' },
  { value: 'staff', label: 'Staf' },
];
/** Detail-only filters (the rekap ignores these). */
const filterDate = ref('');
const filterStatus = ref<'' | 'present' | 'late'>('');
const reportPage = ref(1);
const reportPerPage = 25;
/** Detail per-row list is collapsed by default — rekap leads. */
const showDetail = ref(false);

// ── Per-teacher REKAP (admin/summary) ──────────────────────────────────
const summary = ref<TeacherAttendanceAdminSummary | null>(null);
const summaryLoading = ref(false);
const summaryError = ref<string | null>(null);
const summaryLoaded = ref(false);

const summaryRows = computed<TeacherAttendanceSummaryRow[]>(
  () => summary.value?.data ?? [],
);
const summaryStatuses = computed<string[]>(
  () => summary.value?.meta.statuses ?? ['present', 'late'],
);
const summaryTotals = computed(() => summary.value?.totals ?? null);

const summaryState = computed<AsyncState<TeacherAttendanceSummaryRow[]>>(() => {
  if (summaryLoading.value && summaryRows.value.length === 0)
    return { status: 'loading' };
  if (summaryError.value)
    return { status: 'error', error: summaryError.value };
  if (summaryRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: summaryRows.value };
});

async function loadSummary() {
  summaryLoading.value = true;
  summaryError.value = null;
  try {
    summary.value = await TeacherAttendanceService.adminSummary({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      teacher_id: filterTeacher.value.trim() || undefined,
    });
    summaryLoaded.value = true;
  } catch (e) {
    summaryError.value = (e as Error).message;
  } finally {
    summaryLoading.value = false;
  }
}

/** Pretty range label for the rekap card subtitle. */
const summaryRangeLabel = computed(() => {
  const m = summary.value?.meta;
  if (!m) return '';
  return `${fmtDate(m.start_date)} – ${fmtDate(m.end_date)}`;
});

// ── Export Excel (client-side CSV, opens in Excel) ──────────────────
function csvEscape(v: unknown): string {
  const s = v === null || v === undefined ? '' : String(v);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

/**
 * Export the per-day report rows as CSV. Distinct from
 * [exportRekapCsv] (the aggregate per-teacher summary) — this one
 * writes one row per (teacher × day) with the actual check-in and
 * check-out times so admins can share/audit HR-relevant details
 * without opening the app.
 *
 * We refetch with a wide `per_page` cap so the export isn't limited
 * to the current 15-per-page report table. 5000 comfortably covers
 * "a school × a full month" (say 60 teachers × 30 days = 1800 rows).
 * If a school actually exceeds that we surface a toast asking them
 * to narrow the filter; a wider ceiling risks OOM on the client.
 */
async function exportReportDetailCsv() {
  const MAX_ROWS = 5000;
  const params = {
    date: filterDate.value || undefined,
    start_date: filterStartDate.value || undefined,
    end_date: filterEndDate.value || undefined,
    teacher_id: filterTeacher.value.trim() || undefined,
    status: filterStatus.value || undefined,
    personnel_type: filterPersonnelType.value,
    per_page: MAX_ROWS,
    page: 1,
  };
  let bulk;
  try {
    bulk = await TeacherAttendanceService.adminReport(params);
  } catch (e) {
    toast.error(`Gagal mengambil detail: ${(e as Error).message}`);
    return;
  }
  const items = bulk?.items ?? [];
  if (items.length === 0) {
    toast.error('Belum ada data detail untuk diekspor.');
    return;
  }
  if ((bulk?.meta?.total ?? items.length) > MAX_ROWS) {
    toast.error(
      `Data terlalu banyak (${bulk?.meta?.total ?? '?'}). Persempit periode/guru.`,
    );
    return;
  }
  const header = [
    'Nama Pegawai',
    'Tipe',
    'NIP',
    'Tanggal',
    'Status',
    'Jam Datang',
    'Jam Pulang',
  ];
  const body = items.map((r) =>
    [
      // Name-by-personnel_type: teacher rows read teacher.name, staff
      // rows read user.name — staff used to export blank.
      teacherAttendancePersonName(r),
      teacherAttendancePersonnelLabel(r.personnel_type),
      teacherAttendanceEmployeeNumber(r) ?? '',
      // date arrives as YYYY-MM-DD; render dd/mm/yyyy so Excel doesn't
      // misinterpret + so it matches the local admin conventions.
      r.date ? fmtDateShort(r.date) : '-',
      teacherAttendanceStatusColumnLabel(r.status),
      fmtTime(r.check_in_at),
      fmtTime(r.check_out_at),
    ]
      .map(csvEscape)
      .join(','),
  );
  const csv = [header.map(csvEscape).join(','), ...body].join('\n');
  // Same UTF-8 BOM prefix as exportRekapCsv so Excel renders id
  // characters (Cendekia, Utama, Rekan) correctly.
  const blob = new Blob(['﻿' + csv], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  const range = bulk?.meta
    ? `${bulk.meta.start_date ?? bulk.meta.date ?? 'range'}_${bulk.meta.end_date ?? ''}`.replace(/_$/, '')
    : new Date().toISOString().slice(0, 10);
  a.download = `presensi_pegawai_detail_${range}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  toast.success(`Detail ${items.length} baris ter-export.`);
}

/**
 * Format a YYYY-MM-DD date string as dd/mm/yyyy for the CSV — the
 * detail export ships to admin desktops where Excel's default id-ID
 * locale otherwise interprets `2026-06-30` as text and left-aligns
 * it. This matches the dd/mm/yyyy convention the rest of the admin
 * surface uses.
 */
function fmtDateShort(ymd: string): string {
  const [y, m, d] = ymd.split('-');
  if (!y || !m || !d) return ymd;
  return `${d}/${m}/${y}`;
}

function exportRekapCsv() {
  if (summaryRows.value.length === 0) {
    toast.error('Belum ada data rekap untuk diekspor.');
    return;
  }
  const statuses = summaryStatuses.value;
  const header = [
    'Nama Guru',
    'NIP',
    ...statuses.map(teacherAttendanceStatusColumnLabel),
    'Total',
    '% Kehadiran',
  ];
  const body = summaryRows.value.map((row) =>
    [
      row.teacher_name,
      row.employee_number ?? '',
      ...statuses.map((s) => row[s] ?? 0),
      row.total,
      `${row.present_pct}%`,
    ]
      .map(csvEscape)
      .join(','),
  );
  const t = summaryTotals.value;
  const footer = t
    ? [
        'TOTAL',
        '',
        ...statuses.map((s) => t[s] ?? 0),
        t.total,
        `${t.present_pct}%`,
      ]
        .map(csvEscape)
        .join(',')
    : null;
  const lines = [header.map(csvEscape).join(','), ...body];
  if (footer) lines.push(footer);
  const csv = lines.join('\n');
  // Prepend a UTF-8 BOM so Excel renders Indonesian characters.
  const blob = new Blob(['﻿' + csv], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  const range = summary.value
    ? `${summary.value.meta.start_date}_${summary.value.meta.end_date}`
    : new Date().toISOString().slice(0, 10);
  a.download = `rekap_presensi_guru_${range}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  toast.success('Rekap presensi guru ter-export.');
}

const report = ref<TeacherAttendanceListResult | null>(null);
const reportLoading = ref(false);
const reportError = ref<string | null>(null);
const reportLoaded = ref(false);

const reportRows = computed<TeacherAttendanceRecord[]>(
  () => report.value?.items ?? [],
);
const reportMeta = computed(() => report.value?.meta ?? null);

const presentCount = computed(
  () => reportRows.value.filter((r) => r.status === 'present').length,
);
const lateCount = computed(
  () => reportRows.value.filter((r) => r.status === 'late').length,
);

const reportState = computed<AsyncState<TeacherAttendanceRecord[]>>(() => {
  if (reportLoading.value && reportRows.value.length === 0)
    return { status: 'loading' };
  if (reportError.value) return { status: 'error', error: reportError.value };
  if (reportRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: reportRows.value };
});

async function loadReport() {
  reportLoading.value = true;
  reportError.value = null;
  try {
    report.value = await TeacherAttendanceService.adminReport({
      date: filterDate.value || undefined,
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      teacher_id: filterTeacher.value.trim() || undefined,
      status: filterStatus.value || undefined,
      personnel_type: filterPersonnelType.value,
      per_page: reportPerPage,
      page: reportPage.value,
    });
    reportLoaded.value = true;
  } catch (e) {
    reportError.value = (e as Error).message;
  } finally {
    reportLoading.value = false;
  }
}

/**
 * Apply the shared periode/teacher filter: always refresh the rekap;
 * refresh the detail list only when it's expanded (lazy — no wasted
 * request while collapsed).
 */
function applyReportFilters() {
  reportPage.value = 1;
  loadSummary();
  if (showDetail.value) loadReport();
}

/**
 * Switch the personnel-type narrowing (Semua/Guru/Staf). The filter
 * applies to the detail per-row list (the unified teacher+staff report),
 * so we surface that list when it was collapsed and refetch it. The
 * per-teacher rekap above is unaffected by this narrowing.
 */
function selectPersonnelType(type: TeacherAttendancePersonnelFilter) {
  if (filterPersonnelType.value === type) return;
  filterPersonnelType.value = type;
  reportPage.value = 1;
  if (!showDetail.value) showDetail.value = true;
  loadReport();
}

function clearReportFilters() {
  filterDate.value = '';
  // Reset to the active AY bounds (not empty) — "Kosongkan" should
  // still respect the dashboard period the user is anchored on, per
  // Luay 2026-06-29. Anyone who genuinely wants a custom range types
  // it in; that path sets userTouchedDates and stops AY-following.
  filterStartDate.value = ayStart();
  filterEndDate.value = ayEnd();
  userTouchedDates.value = false;
  filterTeacher.value = '';
  filterStatus.value = '';
  filterPersonnelType.value = 'all';
  reportPage.value = 1;
  loadSummary();
  if (showDetail.value) loadReport();
}

// Watch the date inputs — once the user manually edits either, we stop
// re-anchoring to the active AY on AY changes. They've expressed an
// explicit periode preference; respect it until they hit Clear.
watch([filterStartDate, filterEndDate], ([s, e], [ps, pe]) => {
  if (s === ps && e === pe) return;
  if (s === ayStart() && e === ayEnd()) {
    // Switched BACK to the AY bounds (probably via clearReportFilters
    // or programmatic re-anchor) — stop treating as user-narrowed.
    userTouchedDates.value = false;
    return;
  }
  userTouchedDates.value = true;
});

// Re-anchor when the dashboard AY picker flips, but only if the user
// hasn't taken over the periode manually. This is the load-bearing
// half of Luay's request: changing AY on the dashboard should pull the
// rekap with it.
watch(
  () => ayStore.selectedYear?.id,
  () => {
    if (userTouchedDates.value) return;
    filterStartDate.value = ayStart();
    filterEndDate.value = ayEnd();
    reportPage.value = 1;
    loadSummary();
    if (showDetail.value) loadReport();
  },
);

/** Expand/collapse the detail per-row list; load it on first open. */
function toggleDetail() {
  showDetail.value = !showDetail.value;
  if (showDetail.value && !reportLoaded.value) loadReport();
}

function goReportPage(n: number) {
  if (!reportMeta.value) return;
  if (
    n < 1 ||
    n > reportMeta.value.last_page ||
    n === reportMeta.value.current_page
  )
    return;
  reportPage.value = n;
  loadReport();
}

function switchTab(t: Tab) {
  tab.value = t;
  // The rekap leads the report tab — load it on first entry. The
  // detail list stays lazy until the admin expands it.
  if (t === 'report' && !summaryLoaded.value) loadSummary();
}

function fmtDate(d: string): string {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function fmtTime(iso?: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}
</script>

<template>
  <div class="space-y-md">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.teacher_attendance.header_kicker')"
      :title="t('admin.sekolah.teacher_attendance.header_title')"
      :meta="t('admin.sekolah.teacher_attendance.header_meta')"
    >
      <div
        class="inline-flex gap-0.5 p-0.5 rounded-xl bg-white/20 border border-white/25 backdrop-blur-sm"
      >
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="
            tab === 'report'
              ? 'bg-white text-slate-900 shadow-sm'
              : 'text-white/90 hover:text-white'
          "
          @click="switchTab('report')"
        >
          <NavIcon name="bar-chart" :size="13" />{{ t('admin.sekolah.teacher_attendance.tab_report') }}
        </button>
      </div>
    </BrandPageHeader>

    <!-- ════════════════════ REPORT ════════════════════ -->
    <template v-if="tab === 'report'">
      <!-- Periode filter (drives BOTH rekap + detail) -->
      <section
        class="bg-white border border-slate-200 rounded-2xl p-3 flex flex-wrap items-end gap-3"
      >
        <div>
          <label
            class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
          >
            Dari (periode)
          </label>
          <input
            v-model="filterStartDate"
            type="date"
            class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          />
        </div>
        <div>
          <label
            class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
          >
            Sampai (periode)
          </label>
          <input
            v-model="filterEndDate"
            type="date"
            class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          />
        </div>
        <div>
          <label
            class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
          >
            ID Pegawai
          </label>
          <input
            v-model="filterTeacher"
            type="text"
            placeholder="Teacher / User ID"
            class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 w-44 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          />
        </div>
        <!--
          Tipe pegawai — narrows the unified report to Guru / Staf / all.
          Segmented buttons refetch the detail per-row list on click (the
          rekap above is per-guru and unaffected).
        -->
        <div>
          <label
            class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
          >
            Tipe
          </label>
          <div
            class="inline-flex gap-0.5 p-0.5 rounded-lg bg-slate-100 border border-slate-200"
          >
            <button
              v-for="opt in personnelTypeOptions"
              :key="opt.value"
              type="button"
              class="px-2.5 py-1 rounded-md text-[11.5px] font-bold transition-all"
              :class="
                filterPersonnelType === opt.value
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500 hover:text-slate-700'
              "
              @click="selectPersonnelType(opt.value)"
            >
              {{ opt.label }}
            </button>
          </div>
        </div>
        <Button variant="primary" size="sm" @click="applyReportFilters">
          <NavIcon name="filter" :size="13" />Terapkan
        </Button>
        <Button
          v-if="
            filterStartDate ||
            filterEndDate ||
            filterTeacher ||
            filterPersonnelType !== 'all'
          "
          variant="ghost"
          size="sm"
          @click="clearReportFilters"
        >
          Reset
        </Button>
        <p class="basis-full text-[10.5px] text-slate-400">
          Kosongkan tanggal untuk memakai periode default (awal bulan ini
          sampai hari ini).
        </p>
      </section>

      <!-- ─────────────── REKAP PER-GURU (admin/summary) ─────────────── -->
      <section
        class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
      >
        <div
          class="px-4 py-3 border-b border-slate-100 flex items-center justify-between gap-3 flex-wrap"
        >
          <div>
            <h3 class="text-[13px] font-black text-slate-900">
              Rekap Kehadiran per Guru
            </h3>
            <p class="text-2xs text-slate-500 mt-0.5">
              <template v-if="summaryRangeLabel"
                >Periode {{ summaryRangeLabel }} ·
              </template>
              {{ summaryTotals?.teacher_count ?? summaryRows.length }} guru
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <!--
              Detail export ships one row per (teacher × day) with the
              actual check-in and check-out times. Distinct from Export
              Excel (the aggregate summary above) — HR / payroll users
              asked for the per-day times, not just the daily counts.
            -->
            <Button
              variant="secondary"
              size="sm"
              @click="exportReportDetailCsv"
            >
              <NavIcon name="download" :size="13" />Export Detail
            </Button>
            <Button
              variant="secondary"
              size="sm"
              :disabled="summaryRows.length === 0"
              @click="exportRekapCsv"
            >
              <NavIcon name="download" :size="13" />Export Excel
            </Button>
          </div>
        </div>

        <AsyncView
          :state="summaryState"
          :empty-title="t('admin.sekolah.teacher_attendance.empty_title')"
          :empty-description="t('admin.sekolah.teacher_attendance.empty_description')"
          @retry="loadSummary"
        >
          <template #default>
            <div class="overflow-x-auto">
              <table class="w-full min-w-[640px] text-left">
                <thead>
                  <tr
                    class="bg-slate-50 text-3xs font-bold text-slate-400 uppercase tracking-widest"
                  >
                    <th class="px-4 py-2.5">Nama</th>
                    <th
                      v-for="s in summaryStatuses"
                      :key="s"
                      class="px-4 py-2.5 text-right tabular-nums"
                    >
                      {{ teacherAttendanceStatusColumnLabel(s) }}
                    </th>
                    <th class="px-4 py-2.5 text-right tabular-nums">Total</th>
                    <th class="px-4 py-2.5 text-right tabular-nums">
                      % Kehadiran
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="row in summaryRows"
                    :key="row.person_id"
                    class="border-t border-slate-100 text-[12.5px] hover:bg-slate-50"
                  >
                    <td class="px-4 py-2.5">
                      <p class="font-bold text-slate-900">
                        {{ row.teacher_name }}
                      </p>
                      <p
                        v-if="row.employee_number"
                        class="text-[10.5px] text-slate-400"
                      >
                        {{ row.employee_number }}
                      </p>
                    </td>
                    <td
                      v-for="s in summaryStatuses"
                      :key="s"
                      class="px-4 py-2.5 text-right tabular-nums text-slate-700"
                    >
                      {{ row[s] ?? 0 }}
                    </td>
                    <td
                      class="px-4 py-2.5 text-right tabular-nums font-bold text-slate-900"
                    >
                      {{ row.total }}
                    </td>
                    <td class="px-4 py-2.5 text-right">
                      <span
                        class="text-2xs font-bold px-1.5 py-0.5 rounded-full tabular-nums"
                        :class="
                          row.present_pct >= 90
                            ? 'bg-emerald-100 text-emerald-700'
                            : row.present_pct >= 75
                              ? 'bg-amber-100 text-amber-700'
                              : 'bg-red-100 text-red-700'
                        "
                      >
                        {{ row.present_pct }}%
                      </span>
                    </td>
                  </tr>
                </tbody>
                <tfoot v-if="summaryTotals">
                  <tr
                    class="border-t-2 border-slate-200 bg-slate-50 text-[12.5px] font-black text-slate-900"
                  >
                    <td class="px-4 py-2.5">Total</td>
                    <td
                      v-for="s in summaryStatuses"
                      :key="s"
                      class="px-4 py-2.5 text-right tabular-nums"
                    >
                      {{ summaryTotals[s] ?? 0 }}
                    </td>
                    <td class="px-4 py-2.5 text-right tabular-nums">
                      {{ summaryTotals.total }}
                    </td>
                    <td class="px-4 py-2.5 text-right tabular-nums">
                      {{ summaryTotals.present_pct }}%
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </template>
        </AsyncView>
      </section>

      <!-- ─────────────── DETAIL PER-BARIS (collapsible) ─────────────── -->
      <section
        class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
      >
        <button
          type="button"
          class="w-full px-4 py-3 flex items-center justify-between gap-3 hover:bg-slate-50 transition-colors"
          @click="toggleDetail"
        >
          <div class="text-left">
            <h3 class="text-[13px] font-black text-slate-900">
              Detail per Baris
            </h3>
            <p class="text-2xs text-slate-500 mt-0.5">
              Catatan presensi harian pegawai (guru & staf): masuk/pulang,
              lokasi, foto.
            </p>
          </div>
          <NavIcon
            :name="showDetail ? 'chevron-up' : 'chevron-down'"
            :size="16"
            class="text-slate-400 flex-shrink-0"
          />
        </button>
      </section>

      <template v-if="showDetail">
        <!-- Detail-only filters (tanggal tunggal + status) -->
        <section
          class="bg-white border border-slate-200 rounded-2xl p-3 flex flex-wrap items-end gap-3"
        >
          <div>
            <label
              class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
            >
              Tanggal (1 hari)
            </label>
            <input
              v-model="filterDate"
              type="date"
              class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            />
          </div>
          <div>
            <label
              class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
            >
              Status
            </label>
            <select
              v-model="filterStatus"
              class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            >
              <option value="">Semua</option>
              <option value="present">Tepat Waktu</option>
              <option value="late">Terlambat</option>
            </select>
          </div>
          <Button variant="primary" size="sm" @click="applyReportFilters">
            <NavIcon name="filter" :size="13" />Terapkan
          </Button>
        </section>

        <!-- Summary chips -->
      <div
        v-if="reportRows.length > 0"
        class="flex items-center gap-2 flex-wrap"
      >
        <span
          class="text-2xs font-bold px-2.5 py-1 rounded-full bg-slate-100 text-slate-600"
        >
          {{ reportMeta?.total ?? reportRows.length }} catatan
        </span>
        <span
          class="text-2xs font-bold px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700"
        >
          {{ presentCount }} tepat waktu (hal. ini)
        </span>
        <span
          class="text-2xs font-bold px-2.5 py-1 rounded-full bg-amber-100 text-amber-700"
        >
          {{ lateCount }} terlambat (hal. ini)
        </span>
      </div>

      <!-- List -->
      <AsyncView
        :state="reportState"
        empty-title="Belum ada data presensi"
        empty-description="Tidak ada catatan presensi pegawai untuk filter ini."
        @retry="loadReport"
      >
        <template #default>
          <div
            class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
          >
            <div class="overflow-x-auto">
              <table class="w-full min-w-[720px] text-left">
                <thead>
                  <tr
                    class="bg-slate-50 text-3xs font-bold text-slate-400 uppercase tracking-widest"
                  >
                    <th class="px-4 py-2.5">Nama</th>
                    <th class="px-4 py-2.5">Tipe</th>
                    <th class="px-4 py-2.5">Tanggal</th>
                    <th class="px-4 py-2.5">Status</th>
                    <th class="px-4 py-2.5">Masuk</th>
                    <th class="px-4 py-2.5">Pulang</th>
                    <th class="px-4 py-2.5">Lokasi</th>
                    <th class="px-4 py-2.5">Foto</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="r in reportRows"
                    :key="r.id"
                    class="border-t border-slate-100 text-[12.5px] hover:bg-slate-50"
                  >
                    <td class="px-4 py-2.5">
                      <p class="font-bold text-slate-900">
                        {{ teacherAttendancePersonName(r) }}
                      </p>
                      <p
                        v-if="teacherAttendanceEmployeeNumber(r)"
                        class="text-[10.5px] text-slate-400"
                      >
                        {{ teacherAttendanceEmployeeNumber(r) }}
                      </p>
                    </td>
                    <td class="px-4 py-2.5">
                      <span
                        class="text-3xs font-bold px-1.5 py-0.5 rounded-full"
                        :class="
                          r.personnel_type === 'staff'
                            ? 'bg-violet-100 text-violet-700'
                            : 'bg-sky-100 text-sky-700'
                        "
                      >
                        {{ teacherAttendancePersonnelLabel(r.personnel_type) }}
                      </span>
                    </td>
                    <td class="px-4 py-2.5 text-slate-600">
                      {{ fmtDate(r.date) }}
                    </td>
                    <td class="px-4 py-2.5">
                      <span
                        class="text-3xs font-bold px-1.5 py-0.5 rounded-full"
                        :class="
                          r.status === 'late'
                            ? 'bg-amber-100 text-amber-700'
                            : 'bg-emerald-100 text-emerald-700'
                        "
                      >
                        {{ teacherAttendanceStatusLabel(r.status) }}
                      </span>
                    </td>
                    <td
                      class="px-4 py-2.5 text-slate-700 font-bold tabular-nums"
                    >
                      {{ fmtTime(r.check_in_at) }}
                    </td>
                    <td
                      class="px-4 py-2.5 text-slate-700 font-bold tabular-nums"
                    >
                      {{ fmtTime(r.check_out_at) }}
                    </td>
                    <td class="px-4 py-2.5">
                      <span
                        v-if="r.check_in_outside_geofence"
                        class="text-2xs font-bold text-red-600"
                      >
                        Luar area
                      </span>
                      <span
                        v-else-if="r.check_in_distance_m != null"
                        class="text-2xs text-slate-500"
                      >
                        {{ r.check_in_distance_m }} m
                      </span>
                      <span v-else class="text-2xs text-slate-300">-</span>
                    </td>
                    <td class="px-4 py-2.5">
                      <div class="flex flex-col gap-1">
                        <!-- Foto Masuk (check-in selfie) -->
                        <a
                          v-if="r.check_in_photo_url"
                          :href="r.check_in_photo_url"
                          target="_blank"
                          rel="noopener"
                          class="inline-flex items-center gap-1 text-role-admin text-2xs font-bold hover:underline"
                        >
                          <NavIcon name="camera" :size="12" />Masuk
                        </a>
                        <span v-else class="text-2xs text-slate-300">
                          Masuk -
                        </span>
                        <!-- Foto Pulang (check-out selfie) -->
                        <a
                          v-if="r.check_out_photo_url"
                          :href="r.check_out_photo_url"
                          target="_blank"
                          rel="noopener"
                          class="inline-flex items-center gap-1 text-role-admin text-2xs font-bold hover:underline"
                        >
                          <NavIcon name="camera" :size="12" />Pulang
                        </a>
                        <span
                          v-else
                          class="inline-flex items-center text-2xs text-slate-300"
                        >
                          Pulang -
                        </span>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Pagination -->
          <div
            v-if="reportMeta && reportMeta.last_page > 1"
            class="flex items-center justify-center gap-2 pt-3"
          >
            <Button
              variant="secondary"
              size="sm"
              :disabled="reportMeta.current_page <= 1"
              @click="goReportPage(reportMeta.current_page - 1)"
            >
              <NavIcon name="chevron-left" :size="13" />
            </Button>
            <span class="text-[12px] text-slate-500 font-bold px-2">
              Hal {{ reportMeta.current_page }} / {{ reportMeta.last_page }}
            </span>
            <Button
              variant="secondary"
              size="sm"
              :disabled="reportMeta.current_page >= reportMeta.last_page"
              @click="goReportPage(reportMeta.current_page + 1)"
            >
              <NavIcon name="chevron-right" :size="13" />
            </Button>
          </div>
        </template>
      </AsyncView>
      </template>
    </template>
  </div>
</template>
