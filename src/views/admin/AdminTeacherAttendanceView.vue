<!--
  AdminTeacherAttendanceView.vue — admin PEGAWAI attendance dashboard
  (Opsi A · "Dashboard Ringkas", MR-3, backend !491 + !492).

  Layout tree (top → bottom):
    BrandPageHeader             — kicker + title + meta + action cluster
    KpiStripCards               — 4 cards (tepat waktu %, telat, absen, lembur)
    PageFilterToolbar           — periode chips (Hari ini / 7 / bulan / semester /
                                  custom) + Tipe segmented + Pegawai search
    Card: Chart                 — OntimeHarianChart bar chart + legend
    Card: Tab bar               — Rekap per Pegawai · Log Harian
    Section (tab-content):
      · Rekap: EntityRow list — click opens deep-dive drawer
      · Log:   table (no foto column) — click opens row-detail drawer

  Wireframe: https://claude.ai/code/artifact/7f3d02ed-6a7c-4ce6-9c04-5d5ec7db26ef

  Not in this MR (deferred by explicit task scope):
    · Cuti / Izin tab — no backend endpoint yet.
    · PDF export button — backend only ships XLSX (see !492).
    · Real map library (Leaflet/Mapbox) — the row drawer uses a
      stylised SVG placeholder for MR-3; iteration lands later.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import EntityRow from '@/components/feature/EntityRow.vue';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import OntimeHarianChart from '@/components/attendance/OntimeHarianChart.vue';
import EmployeeAttendanceDeepDiveDrawer from '@/components/attendance/EmployeeAttendanceDeepDiveDrawer.vue';
import AttendanceRowDetailDrawer from '@/components/attendance/AttendanceRowDetailDrawer.vue';
// Pulang parity FU-1 — collapsible "Guru Sering Pulang Cepat" digest
// under the Rekap tab. Backend endpoint is
// `GET /teacher-attendance/report/pulang-cepat-summary` (!512). The
// section defaults collapsed so it never pushes the primary rekap
// below the fold on typical viewports.
import PulangCepatDigestCard from '@/components/attendance/PulangCepatDigestCard.vue';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import { useToast } from '@/composables/useToast';
import { useAcademicYearStore } from '@/stores/academic-year';
import { toLocalYmd } from '@/lib/local-date';
import type {
  TeacherAttendanceAdminSummary,
  TeacherAttendanceExportScope,
  TeacherAttendanceListResult,
  TeacherAttendancePersonnelFilter,
  TeacherAttendancePulangCepatRow,
  TeacherAttendanceRecord,
  TeacherAttendanceSummaryRow,
  TeacherAttendanceTimeseries,
} from '@/types/teacher-attendance';
import {
  teacherAttendanceEmployeeNumber,
  teacherAttendancePersonName,
  teacherAttendancePersonnelLabel,
  teacherAttendanceStatusLabel,
} from '@/types/teacher-attendance';

const { t } = useI18n();
const toast = useToast();
const ayStore = useAcademicYearStore();

// ─────────────────────────────────────────────────────────────────
// Periode filter
//
// Quick chips auto-apply on click; the Custom chip reveals two date
// pickers (manual apply). Programmatic anchor changes (chip pick,
// AY switch) never flip `userTouchedDates` — only edits to the two
// inputs do, and manual edits stop the AY watcher from re-anchoring.
// ─────────────────────────────────────────────────────────────────
type Preset =
  | 'today'
  | 'last7'
  | 'this_month'
  | 'this_semester'
  | 'custom';

const preset = ref<Preset>('last7');
const showCustom = computed(() => preset.value === 'custom');

// Date bounds — YYYY-MM-DD strings.
const filterStartDate = ref('');
const filterEndDate = ref('');

/** True once the user manually edits either date input — stops the
 *  auto-reanchor when the AY picker flips. */
const userTouchedDates = ref(false);

// Local-calendar YYYY-MM-DD — MUST NOT use toISOString() here (that
// formats in UTC and shifts the window by one day for WIB users
// opening the app before 07:00). Prod incident MTs Muhammadiyah
// Surakarta 2026-07-20 — see lib/local-date.ts docstring.
const ymd = toLocalYmd;

/** Compute the range for a quick preset. Returns null for `custom`
 *  (the caller opens the two pickers instead of firing a fetch). */
function rangeFor(p: Preset): { start: string; end: string } | null {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (p === 'today') {
    const s = ymd(today);
    return { start: s, end: s };
  }
  if (p === 'last7') {
    const start = new Date(today);
    start.setDate(start.getDate() - 6);
    return { start: ymd(start), end: ymd(today) };
  }
  if (p === 'this_month') {
    const start = new Date(today.getFullYear(), today.getMonth(), 1);
    return { start: ymd(start), end: ymd(today) };
  }
  if (p === 'this_semester') {
    const ayStart = ayStore.selectedYear?.start_date as string | undefined;
    const ayEnd = ayStore.selectedYear?.end_date as string | undefined;
    if (ayStart && ayEnd) {
      return { start: ayStart, end: ymd(today) };
    }
    // Fallback: last 90 days when no AY is selected.
    const start = new Date(today);
    start.setDate(start.getDate() - 90);
    return { start: ymd(start), end: ymd(today) };
  }
  return null;
}

function applyPreset(p: Preset) {
  preset.value = p;
  if (p === 'custom') return; // Custom: wait for the manual Terapkan.
  const r = rangeFor(p);
  if (!r) return;
  filterStartDate.value = r.start;
  filterEndDate.value = r.end;
  userTouchedDates.value = false;
  reloadAll();
}

// Personnel-type narrowing (Semua | Guru | Staf) — drives BOTH the
// KPI strip and every panel on the page in lock-step.
const filterPersonnelType = ref<TeacherAttendancePersonnelFilter>('all');
const personnelTypeOptions: {
  value: TeacherAttendancePersonnelFilter;
  label: string;
}[] = [
  { value: 'all', label: 'Semua' },
  { value: 'teacher', label: 'Guru' },
  { value: 'staff', label: 'Staf' },
];

function selectPersonnelType(type: TeacherAttendancePersonnelFilter) {
  if (filterPersonnelType.value === type) return;
  filterPersonnelType.value = type;
  reloadAll();
}

// Employee search — accepts Teacher ID / User ID (server resolves).
// Debounced apply so the admin can type without triggering a burst of
// requests; a small button keeps power users happy too.
const searchInput = ref('');

// Detail-list-only status filter, driven by KPI card click-through.
type StatusFilter = '' | 'present' | 'late';
const filterStatus = ref<StatusFilter>('');

// Tabs
type Tab = 'summary' | 'log';
const activeTab = ref<Tab>('summary');

// ─────────────────────────────────────────────────────────────────
// Timeseries (chart)
// ─────────────────────────────────────────────────────────────────
const timeseries = ref<TeacherAttendanceTimeseries | null>(null);
const timeseriesLoading = ref(false);
const timeseriesError = ref<string | null>(null);

async function loadTimeseries() {
  timeseriesLoading.value = true;
  timeseriesError.value = null;
  try {
    timeseries.value = await TeacherAttendanceService.adminTimeseries({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      personnel_type: filterPersonnelType.value,
    });
  } catch (e) {
    timeseriesError.value = (e as Error).message;
  } finally {
    timeseriesLoading.value = false;
  }
}

const chartRange = computed<'week' | 'month'>(() =>
  (timeseries.value?.data.length ?? 0) > 10 ? 'month' : 'week',
);

// ─────────────────────────────────────────────────────────────────
// KPI strip
//
// Rolls the timeseries into the 4 cards on top. This keeps a single
// canonical source of truth (the backend's timeseries payload) and
// spares a second dedicated `/kpi` request.
// ─────────────────────────────────────────────────────────────────
const kpiValues = computed(() => {
  const days = timeseries.value?.data ?? [];
  if (days.length === 0) {
    return {
      ontime_pct: 0,
      late_count: 0,
      absent_count: 0,
      overtime_minutes: 0,
    };
  }
  const workdays = days.filter((d) => d.is_workday);
  const totalOntime = workdays.reduce(
    (acc, d) => acc + d.ontime_pct,
    0,
  );
  const avgOntime =
    workdays.length > 0 ? Math.round(totalOntime / workdays.length) : 0;
  return {
    ontime_pct: avgOntime,
    late_count: days.reduce((a, d) => a + d.late_count, 0),
    absent_count: days.reduce((a, d) => a + d.absent_count, 0),
    overtime_minutes: days.reduce((a, d) => a + d.overtime_minutes, 0),
  };
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'check-circle',
    label: 'Tepat Waktu',
    value: kpiValues.value.ontime_pct,
    suffix: '%',
    tone: 'green',
    accented: true,
  },
  {
    icon: 'clock',
    label: 'Terlambat',
    value: kpiValues.value.late_count,
    tone: 'amber',
  },
  {
    icon: 'user-x',
    label: 'Belum Absen',
    value: kpiValues.value.absent_count,
    tone: 'red',
  },
  {
    icon: 'sun',
    label: 'Jam Lembur',
    value: Math.round(kpiValues.value.overtime_minutes / 60),
    suffix: 'jam',
    tone: 'violet',
  },
]);

// ─────────────────────────────────────────────────────────────────
// Rekap per-pegawai (adminSummary)
// ─────────────────────────────────────────────────────────────────
const summary = ref<TeacherAttendanceAdminSummary | null>(null);
const summaryLoading = ref(false);
const summaryError = ref<string | null>(null);

const summaryRows = computed<TeacherAttendanceSummaryRow[]>(
  () => summary.value?.data ?? [],
);
const summaryTotals = computed(() => summary.value?.totals ?? null);

/** Filter the summary rows client-side by search term — the backend
 *  filters by teacher_id (exact) so a partial name typed in the search
 *  input is handled locally against the loaded list. */
const filteredSummaryRows = computed(() => {
  const q = searchInput.value.trim().toLowerCase();
  if (!q) return summaryRows.value;
  return summaryRows.value.filter((r) =>
    r.teacher_name.toLowerCase().includes(q),
  );
});

const summaryState = computed<AsyncState<TeacherAttendanceSummaryRow[]>>(() => {
  if (summaryLoading.value && summaryRows.value.length === 0)
    return { status: 'loading' };
  if (summaryError.value)
    return { status: 'error', error: summaryError.value };
  if (filteredSummaryRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredSummaryRows.value };
});

async function loadSummary() {
  summaryLoading.value = true;
  summaryError.value = null;
  try {
    summary.value = await TeacherAttendanceService.adminSummary({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      personnel_type: filterPersonnelType.value,
      status: filterStatus.value || undefined,
    });
  } catch (e) {
    summaryError.value = (e as Error).message;
  } finally {
    summaryLoading.value = false;
  }
}

// ─────────────────────────────────────────────────────────────────
// Detail per-baris (adminReport)
// ─────────────────────────────────────────────────────────────────
const logList = ref<TeacherAttendanceListResult | null>(null);
const logLoading = ref(false);
const logError = ref<string | null>(null);
const logPage = ref(1);
const LOG_PER_PAGE = 25;

const logRows = computed<TeacherAttendanceRecord[]>(
  () => logList.value?.items ?? [],
);
const logMeta = computed(() => logList.value?.meta ?? null);

const filteredLogRows = computed(() => {
  const q = searchInput.value.trim().toLowerCase();
  if (!q) return logRows.value;
  return logRows.value.filter((r) =>
    teacherAttendancePersonName(r).toLowerCase().includes(q),
  );
});

const logState = computed<AsyncState<TeacherAttendanceRecord[]>>(() => {
  if (logLoading.value && logRows.value.length === 0)
    return { status: 'loading' };
  if (logError.value) return { status: 'error', error: logError.value };
  if (filteredLogRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredLogRows.value };
});

async function loadLog() {
  logLoading.value = true;
  logError.value = null;
  try {
    logList.value = await TeacherAttendanceService.adminReport({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      personnel_type: filterPersonnelType.value,
      status: filterStatus.value || undefined,
      per_page: LOG_PER_PAGE,
      page: logPage.value,
    });
  } catch (e) {
    logError.value = (e as Error).message;
  } finally {
    logLoading.value = false;
  }
}

function goLogPage(n: number) {
  const m = logMeta.value;
  if (!m) return;
  if (n < 1 || n > m.last_page || n === m.current_page) return;
  logPage.value = n;
  loadLog();
}

function switchTab(tab: Tab) {
  activeTab.value = tab;
  // Lazy-load the log list on first visit — the KPI + rekap already
  // paid the initial cost, no reason to fan out unless the admin
  // asks for the raw feed.
  if (tab === 'log' && logList.value === null && !logLoading.value) {
    loadLog();
  }
}

// ─────────────────────────────────────────────────────────────────
// Reload orchestrator
// ─────────────────────────────────────────────────────────────────
function reloadAll() {
  logPage.value = 1;
  loadTimeseries();
  loadSummary();
  if (activeTab.value === 'log') loadLog();
}

// Watchers ────────────────────────────────────────────────────────
watch([filterStartDate, filterEndDate], ([s, e], [ps, pe]) => {
  if (s === ps && e === pe) return;
  userTouchedDates.value = true;
});

watch(
  () => ayStore.selectedYear?.id,
  () => {
    if (userTouchedDates.value) return;
    if (preset.value === 'this_semester') applyPreset('this_semester');
  },
);

// Initial anchor: last 7 days by default (matches the wireframe).
applyPreset('last7');

// ─────────────────────────────────────────────────────────────────
// Drill-downs (drawers)
// ─────────────────────────────────────────────────────────────────
const deepDivePersonId = ref<string | null>(null);
const deepDivePersonName = ref<string | null>(null);
const deepDiveOpen = computed(() => deepDivePersonId.value !== null);

function openDeepDive(row: TeacherAttendanceSummaryRow) {
  deepDivePersonId.value = row.person_id;
  deepDivePersonName.value = row.teacher_name;
}
function closeDeepDive() {
  deepDivePersonId.value = null;
  deepDivePersonName.value = null;
}

/**
 * Bridge from the pulang-cepat digest row → the same deep-dive drawer
 * the rekap list uses. The digest row carries `display_name` where the
 * rekap row carries `teacher_name`; the drawer only needs the `id +
 * name` pair for its header while it fetches its own detail payload.
 */
function openDeepDiveFromDigest(row: TeacherAttendancePulangCepatRow) {
  deepDivePersonId.value = row.person_id;
  deepDivePersonName.value = row.display_name;
}

const rowDetail = ref<TeacherAttendanceRecord | null>(null);
const rowDetailOpen = computed(() => rowDetail.value !== null);
function openRowDetail(row: TeacherAttendanceRecord) {
  rowDetail.value = row;
}
function closeRowDetail() {
  rowDetail.value = null;
}

function handleRowNote(row: TeacherAttendanceRecord) {
  toast.info(`Catatan manual untuk ${teacherAttendancePersonName(row)} akan hadir di iterasi berikutnya.`);
}
function handleRowVerify(row: TeacherAttendanceRecord) {
  toast.info(`Verifikasi manual untuk ${teacherAttendancePersonName(row)} akan hadir di iterasi berikutnya.`);
}

// ─────────────────────────────────────────────────────────────────
// Export (server-generated XLSX)
// ─────────────────────────────────────────────────────────────────
const exportMenuOpen = ref(false);
const exporting = ref(false);

function toggleExportMenu() {
  exportMenuOpen.value = !exportMenuOpen.value;
}
function closeExportMenu() {
  exportMenuOpen.value = false;
}

async function runExport(scope: TeacherAttendanceExportScope) {
  closeExportMenu();
  exporting.value = true;
  try {
    const { blob, filename } = await TeacherAttendanceService.adminExport({
      scope,
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      personnel_type: filterPersonnelType.value,
      teacher_id: undefined,
      status: filterStatus.value || undefined,
    });
    const stamp = new Date().toISOString().slice(0, 10);
    const fallback = `Kehadiran-Pegawai-${scope}-${stamp}.xlsx`;
    triggerBlobDownload(blob, filename || fallback);
    toast.success('Export selesai. Cek folder unduhan.');
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    exporting.value = false;
  }
}

function triggerBlobDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  try {
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
  } finally {
    setTimeout(() => URL.revokeObjectURL(url), 1500);
  }
}

// ─────────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────────
function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function fmtTime(iso: string | null | undefined): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

const periodLabel = computed(() => {
  if (!filterStartDate.value || !filterEndDate.value) return '';
  return `${fmtDate(filterStartDate.value)} – ${fmtDate(filterEndDate.value)}`;
});

/** Copy for the empty state — picks the right message by personnel filter. */
const emptyDescription = computed(() => {
  const type = filterPersonnelType.value;
  if (type === 'teacher') {
    return t('admin.sekolah.teacher_attendance.empty_description_teacher');
  }
  if (type === 'staff') {
    return t('admin.sekolah.teacher_attendance.empty_description_staff');
  }
  return t('admin.sekolah.teacher_attendance.empty_description_all');
});

// Presets — the chip row.
const presetOptions: { value: Preset; label: string }[] = [
  { value: 'today', label: 'Hari ini' },
  { value: 'last7', label: '7 Hari' },
  { value: 'this_month', label: 'Bulan' },
  { value: 'this_semester', label: 'Semester' },
  { value: 'custom', label: 'Custom' },
];

// pct → tone class for the rekap row bar.
function pctBarClass(pct: number): string {
  if (pct >= 85) return 'bg-emerald-500';
  if (pct >= 70) return 'bg-amber-500';
  return 'bg-red-500';
}

function pctChipClass(pct: number): string {
  if (pct >= 90) return 'bg-emerald-100 text-emerald-700';
  if (pct >= 75) return 'bg-amber-100 text-amber-700';
  return 'bg-red-100 text-red-700';
}
</script>

<template>
  <div class="space-y-md" @click="closeExportMenu">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.teacher_attendance.header_kicker')"
      :title="t('admin.sekolah.teacher_attendance.header_title')"
      :meta="t('admin.sekolah.teacher_attendance.header_meta')"
    >
      <!-- Action cluster (export dropdown + manual entry stub) -->
      <div class="flex items-center gap-2 relative" @click.stop>
        <Button
          variant="secondary"
          size="sm"
          :loading="exporting"
          @click="toggleExportMenu"
        >
          <NavIcon name="download" :size="13" />Export
          <NavIcon name="chevron-down" :size="12" />
        </Button>
        <div
          v-if="exportMenuOpen"
          class="absolute right-0 top-full mt-1 w-56 rounded-xl bg-white border border-slate-200 shadow-lg overflow-hidden z-30"
        >
          <button
            type="button"
            class="w-full text-left px-3 py-2 hover:bg-slate-50 text-[12.5px] font-bold text-slate-700 inline-flex items-center gap-2"
            @click="runExport('summary')"
          >
            <NavIcon name="file-text" :size="13" class="text-emerald-600" />
            Excel (Rekap)
          </button>
          <button
            type="button"
            class="w-full text-left px-3 py-2 hover:bg-slate-50 text-[12.5px] font-bold text-slate-700 inline-flex items-center gap-2 border-t border-slate-100"
            @click="runExport('detail')"
          >
            <NavIcon name="list" :size="13" class="text-sky-600" />
            Excel (Detail per Baris)
          </button>
        </div>
        <Button
          variant="primary"
          size="sm"
          @click="toast.info('Catat manual akan hadir di iterasi berikutnya.')"
        >
          <NavIcon name="plus" :size="13" />Catat Manual
        </Button>
      </div>
    </BrandPageHeader>

    <!-- KPI strip — 4 cards -->
    <KpiStripCards :cards="kpiCards" :loading="timeseriesLoading" />

    <!-- Filter toolbar — preset chips + Tipe segmented + search -->
    <PageFilterToolbar
      v-model:search="searchInput"
      search-placeholder="Cari pegawai…"
    >
      <template #chips>
        <button
          v-for="opt in presetOptions"
          :key="opt.value"
          type="button"
          class="px-3 py-1.5 rounded-xl text-[12px] font-bold transition-colors border"
          :class="
            preset === opt.value
              ? 'bg-role-admin text-white border-role-admin shadow-sm'
              : 'bg-white text-slate-600 border-slate-200 hover:border-role-admin/40'
          "
          @click="applyPreset(opt.value)"
        >
          {{ opt.label }}
        </button>
      </template>
      <template #segmented>
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
      </template>
    </PageFilterToolbar>

    <!-- Custom date-picker row — only when the Custom chip is active -->
    <section
      v-if="showCustom"
      class="bg-white border border-slate-200 rounded-2xl p-3 flex flex-wrap items-end gap-3"
    >
      <div>
        <label
          class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
        >
          Dari
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
          Sampai
        </label>
        <input
          v-model="filterEndDate"
          type="date"
          class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
        />
      </div>
      <Button variant="primary" size="sm" @click="reloadAll">
        <NavIcon name="filter" :size="13" />Terapkan
      </Button>
    </section>

    <!-- Chart card — Tepat Waktu Harian -->
    <section
      class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
    >
      <header
        class="px-4 py-3 border-b border-slate-100 flex items-center justify-between gap-3 flex-wrap"
      >
        <div>
          <h3 class="text-[13px] font-black text-slate-900">
            Tepat Waktu Harian
          </h3>
          <p class="text-2xs text-slate-500 mt-0.5">
            <template v-if="periodLabel">Periode {{ periodLabel }}</template>
            <template v-else>Periode default (7 hari terakhir)</template>
          </p>
        </div>
        <div class="flex items-center gap-1.5 text-2xs text-slate-500">
          <span
            class="inline-block w-2 h-2 rounded-full bg-brand-cobalt animate-pulse"
            aria-hidden="true"
          />
          <span>{{ timeseries?.meta.day_count ?? 0 }} hari</span>
        </div>
      </header>
      <div class="p-4">
        <div v-if="timeseriesError" class="text-2xs text-red-600 py-2">
          {{ timeseriesError }}
          <button
            type="button"
            class="ml-2 underline text-role-admin"
            @click="loadTimeseries"
          >
            Coba lagi
          </button>
        </div>
        <OntimeHarianChart
          v-else
          :data="timeseries?.data ?? []"
          :range="chartRange"
          :loading="timeseriesLoading"
          @select-day="() => {}"
        />
      </div>
    </section>

    <!-- Tab bar -->
    <section
      class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
    >
      <div class="px-4 py-2 border-b border-slate-100 flex items-center gap-1">
        <button
          type="button"
          class="px-3 py-2 text-[12.5px] font-bold rounded-lg inline-flex items-center gap-1.5 transition-colors"
          :class="
            activeTab === 'summary'
              ? 'bg-role-admin/10 text-role-admin'
              : 'text-slate-500 hover:bg-slate-50'
          "
          @click="switchTab('summary')"
        >
          <NavIcon name="users" :size="13" />
          Rekap per Pegawai
          <span
            v-if="summaryTotals"
            class="ml-1 text-3xs px-1.5 py-0.5 rounded-full bg-slate-100 text-slate-500 font-bold"
          >
            {{ summaryTotals.teacher_count }}
          </span>
        </button>
        <button
          type="button"
          class="px-3 py-2 text-[12.5px] font-bold rounded-lg inline-flex items-center gap-1.5 transition-colors"
          :class="
            activeTab === 'log'
              ? 'bg-role-admin/10 text-role-admin'
              : 'text-slate-500 hover:bg-slate-50'
          "
          @click="switchTab('log')"
        >
          <NavIcon name="list" :size="13" />
          Log Harian
          <span
            v-if="logMeta"
            class="ml-1 text-3xs px-1.5 py-0.5 rounded-full bg-slate-100 text-slate-500 font-bold"
          >
            {{ logMeta.total }}
          </span>
        </button>
      </div>

      <!-- Rekap tab -->
      <div v-if="activeTab === 'summary'">
        <!--
          Pulang parity FU-1 — collapsed by default so it never pushes
          the primary rekap table below the fold. Lazy-fetches on first
          expand (parent-driven filter changes reset its cache so the
          section stays in lock-step with the surrounding period picker).
        -->
        <div class="p-3 border-b border-slate-100 bg-slate-50">
          <PulangCepatDigestCard
            :start-date="filterStartDate || undefined"
            :end-date="filterEndDate || undefined"
            :personnel-type="filterPersonnelType"
            @open-person="openDeepDiveFromDigest"
          />
        </div>
        <AsyncView
          :state="summaryState"
          :empty-title="t('admin.sekolah.teacher_attendance.empty_title')"
          :empty-description="emptyDescription"
          @retry="loadSummary"
        >
          <template #default>
            <ul class="divide-y divide-slate-100">
              <li v-for="row in filteredSummaryRows" :key="row.person_id">
                <EntityRow
                  :avatar="{ name: row.teacher_name, size: 40 }"
                  :title="row.teacher_name"
                  :subtitle="
                    row.employee_number
                      ? `NIP ${row.employee_number}`
                      : teacherAttendancePersonnelLabel(row.personnel_type)
                  "
                  chevron
                  @click="openDeepDive(row)"
                >
                  <template #trailing>
                    <div class="flex items-center gap-3 min-w-0">
                      <!-- Personnel chip -->
                      <span
                        class="hidden sm:inline text-3xs font-bold px-1.5 py-0.5 rounded-full"
                        :class="
                          row.personnel_type === 'staff'
                            ? 'bg-violet-100 text-violet-700'
                            : 'bg-sky-100 text-sky-700'
                        "
                      >
                        {{
                          teacherAttendancePersonnelLabel(row.personnel_type)
                        }}
                      </span>
                      <!-- Progress bar -->
                      <div class="hidden md:flex items-center gap-2 w-40">
                        <div class="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden">
                          <div
                            class="h-full rounded-full"
                            :class="pctBarClass(row.present_pct)"
                            :style="{
                              width: `${Math.min(100, Math.max(0, row.present_pct))}%`,
                            }"
                          />
                        </div>
                        <span
                          class="text-2xs font-bold px-1.5 py-0.5 rounded-full tabular-nums"
                          :class="pctChipClass(row.present_pct)"
                        >
                          {{ row.present_pct }}%
                        </span>
                      </div>
                      <!-- Numeric strip -->
                      <div class="hidden lg:flex items-center gap-3 text-2xs tabular-nums">
                        <span class="text-emerald-600 font-bold">
                          {{ row.present ?? 0 }}<span class="text-slate-400 font-normal ml-0.5">hadir</span>
                        </span>
                        <span class="text-amber-600 font-bold">
                          {{ row.late ?? 0 }}<span class="text-slate-400 font-normal ml-0.5">telat</span>
                        </span>
                        <span class="text-red-600 font-bold">
                          {{ row.absent ?? 0 }}<span class="text-slate-400 font-normal ml-0.5">absen</span>
                        </span>
                      </div>
                    </div>
                  </template>
                </EntityRow>
              </li>
            </ul>
          </template>
        </AsyncView>
        <footer
          v-if="summaryTotals && filteredSummaryRows.length > 0"
          class="px-4 py-3 border-t border-slate-100 flex items-center justify-between text-2xs text-slate-500 flex-wrap gap-2"
        >
          <span>
            Total: {{ summaryTotals.teacher_count }} pegawai ·
            {{ summaryTotals.total }} catatan
          </span>
          <span class="font-bold text-slate-700">
            {{ summaryTotals.present_pct }}% tepat waktu (school-wide)
          </span>
        </footer>
      </div>

      <!-- Log tab -->
      <div v-else-if="activeTab === 'log'">
        <AsyncView
          :state="logState"
          :empty-title="t('admin.sekolah.teacher_attendance.empty_title')"
          :empty-description="emptyDescription"
          @retry="loadLog"
        >
          <template #default>
            <div class="overflow-x-auto">
              <table class="w-full min-w-[760px] text-left">
                <thead>
                  <tr
                    class="bg-slate-50 text-3xs font-bold text-slate-400 uppercase tracking-widest"
                  >
                    <th class="px-4 py-2.5">Nama · Tipe</th>
                    <th class="px-4 py-2.5">Tanggal</th>
                    <th class="px-4 py-2.5">Status</th>
                    <th class="px-4 py-2.5">Masuk</th>
                    <th class="px-4 py-2.5">Pulang</th>
                    <th class="px-4 py-2.5">Lokasi</th>
                    <th class="px-4 py-2.5 w-8"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="r in filteredLogRows"
                    :key="r.id"
                    class="border-t border-slate-100 text-[12.5px] hover:bg-slate-50 cursor-pointer"
                    @click="openRowDetail(r)"
                  >
                    <td class="px-4 py-2.5">
                      <p class="font-bold text-slate-900">
                        {{ teacherAttendancePersonName(r) }}
                      </p>
                      <p class="text-3xs text-slate-400 flex items-center gap-1.5">
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
                        <span v-if="teacherAttendanceEmployeeNumber(r)">
                          NIP {{ teacherAttendanceEmployeeNumber(r) }}
                        </span>
                      </p>
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
                    <td class="px-4 py-2.5 text-slate-700 font-bold tabular-nums">
                      {{ fmtTime(r.check_in_at) }}
                    </td>
                    <td class="px-4 py-2.5 text-slate-700 font-bold tabular-nums">
                      {{ fmtTime(r.check_out_at) }}
                    </td>
                    <td class="px-4 py-2.5">
                      <span
                        v-if="r.check_in_outside_geofence"
                        class="text-2xs font-bold text-red-600 inline-flex items-center gap-1"
                      >
                        <NavIcon name="map-pin" :size="11" />Luar area
                      </span>
                      <span
                        v-else-if="r.check_in_distance_m !== null"
                        class="text-2xs text-slate-500 tabular-nums"
                      >
                        {{ r.check_in_distance_m }} m
                      </span>
                      <span v-else class="text-2xs text-slate-300">-</span>
                    </td>
                    <td class="px-4 py-2.5 text-right">
                      <NavIcon
                        name="chevron-right"
                        :size="14"
                        class="text-slate-300"
                      />
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>
        </AsyncView>

        <!-- Pagination -->
        <div
          v-if="logMeta && logMeta.last_page > 1"
          class="px-4 py-3 border-t border-slate-100 flex items-center justify-center gap-2"
        >
          <Button
            variant="secondary"
            size="sm"
            :disabled="logMeta.current_page <= 1"
            @click="goLogPage(logMeta.current_page - 1)"
          >
            <NavIcon name="chevron-left" :size="13" />
          </Button>
          <span class="text-[12px] text-slate-500 font-bold px-2">
            Hal {{ logMeta.current_page }} / {{ logMeta.last_page }}
          </span>
          <Button
            variant="secondary"
            size="sm"
            :disabled="logMeta.current_page >= logMeta.last_page"
            @click="goLogPage(logMeta.current_page + 1)"
          >
            <NavIcon name="chevron-right" :size="13" />
          </Button>
        </div>
      </div>
    </section>

    <!-- Deep-dive drawer -->
    <EmployeeAttendanceDeepDiveDrawer
      :open="deepDiveOpen"
      :person-id="deepDivePersonId"
      :person-name="deepDivePersonName"
      :start-date="filterStartDate || undefined"
      :end-date="filterEndDate || undefined"
      @close="closeDeepDive"
    />

    <!-- Row-detail drawer -->
    <AttendanceRowDetailDrawer
      :open="rowDetailOpen"
      :row="rowDetail"
      @close="closeRowDetail"
      @note="handleRowNote"
      @verify="handleRowVerify"
    />
  </div>
</template>
