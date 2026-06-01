<!--
  AdminAttendanceReportView.vue — admin Laporan Kehadiran.

  Web port of Flutter's `AdminAttendanceReportScreen`. Route:
  `/admin/attendance/laporan`.

  Layout:
    1. Back chevron → dashboard
    2. BrandPageHeader (admin) — title "Laporan Sesi" + meta
    3. KpiStripCards — Total Sesi / Filled / Pending / Rata
    4. PageFilterToolbar — Date range / Kelas / Mapel / Hari / Jam-ke
    5. View toggle (List / Tabel)
    6. Paginated session list
    7. Tap row → drill to AdminAttendanceDetailView

  Endpoints: GET /attendance/summary with `with[]` hint server-side.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { AttendanceService } from '@/services/attendance.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import type { AdminAttendanceSummary } from '@/types/attendance';
import type { Classroom, Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';

const router = useRouter();
const academicYearStore = useAcademicYearStore();

// ── Data ────────────────────────────────────────────────────────────
const rows = ref<AdminAttendanceSummary[]>([]);
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Export modal state ─────────────────────────────────────────────
const showExportModal = ref(false);
const exportProcessing = ref(false);
const selectedExportMonths = ref<number[]>([]); // 1-12 within the AY frame

const pagination = reactive({ page: 1, last_page: 1, total: 0 });

// ── Filters ─────────────────────────────────────────────────────────
const filters = reactive<{
  class_id: string;
  subject_id: string;
  date_start: string;
  date_end: string;
  lesson_hour_id: string;
  search: string;
}>({
  class_id: '',
  subject_id: '',
  date_start: '',
  date_end: '',
  lesson_hour_id: '',
  search: '',
});

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);
const showDatePicker = ref(false);
const datePickerStart = ref('');
const datePickerEnd = ref('');

// View mode
type ViewMode = 'list' | 'table';
const viewMode = ref<ViewMode>('list');
const VIEW_OPTIONS: { key: ViewMode; label: string }[] = [
  { key: 'list', label: 'List' },
  { key: 'table', label: 'Tabel' },
];

// ── Loaders ─────────────────────────────────────────────────────────
async function load(page = 1) {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await AttendanceService.getAdminSummary({
      page,
      per_page: 25,
      class_id: filters.class_id || undefined,
      subject_id: filters.subject_id || undefined,
      date_start: filters.date_start || undefined,
      date_end: filters.date_end || undefined,
      lesson_hour_id: filters.lesson_hour_id || undefined,
      search: filters.search || undefined,
    });
    rows.value = res.items;
    pagination.page = res.current_page;
    pagination.last_page = res.last_page;
    pagination.total = res.total;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadRefs() {
  try {
    const [cls, subs] = await Promise.all([
      ClassroomService.list({ per_page: 200 }),
      SubjectService.list({ per_page: 200 }),
    ]);
    classes.value = cls.items;
    subjects.value = subs.items;
  } catch {
    classes.value = [];
    subjects.value = [];
  }
}

/**
 * Default the date range to the active AY window (mobile parity —
 * Flutter pre-fills start_date / end_date from the academic year so
 * the page lands populated instead of empty). Only fills when the
 * caller hasn't already typed a custom range.
 */
function applyDefaultDateRange() {
  const start = academicYearStore.selectedYear?.start_date;
  const end = academicYearStore.selectedYear?.end_date;
  if (!filters.date_start && start) filters.date_start = start;
  if (!filters.date_end && end) filters.date_end = end;
}

onMounted(async () => {
  applyDefaultDateRange();
  await loadRefs();
  await load();
});

useAcademicYearWatcher(async () => {
  // AY change should reset filters + pagination (mirrors Flutter),
  // then re-seed the date range from the newly active AY.
  filters.class_id = '';
  filters.subject_id = '';
  filters.date_start = '';
  filters.date_end = '';
  filters.lesson_hour_id = '';
  filters.search = '';
  applyDefaultDateRange();
  await loadRefs();
  await load(1);
});

// Debounced search
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(
  () => filters.search,
  () => {
    if (searchTimer) clearTimeout(searchTimer);
    searchTimer = setTimeout(() => void load(1), 300);
  },
);

// ── Facet options ──────────────────────────────────────────────────
const classOptions = computed<FacetOption[]>(() =>
  classes.value.map((c) => ({
    key: c.id,
    label: c.name,
    meta: c.grade_level ? `Tingkat ${c.grade_level}` : undefined,
  })),
);

const subjectOptions = computed<FacetOption[]>(() =>
  subjects.value.map((s) => ({ key: s.id, label: s.name })),
);

// ── Chip display values ────────────────────────────────────────────
const classChipValue = computed(() => {
  if (!filters.class_id) return 'Semua';
  return classes.value.find((c) => c.id === filters.class_id)?.name ?? '—';
});
const subjectChipValue = computed(() => {
  if (!filters.subject_id) return 'Semua';
  return subjects.value.find((s) => s.id === filters.subject_id)?.name ?? '—';
});
const dateChipValue = computed(() => {
  if (!filters.date_start && !filters.date_end) return 'Semua';
  if (filters.date_start && filters.date_end) {
    if (filters.date_start === filters.date_end) return filters.date_start;
    return `${filters.date_start} → ${filters.date_end}`;
  }
  return filters.date_start || filters.date_end || 'Semua';
});

const activeFilterCount = computed(() => {
  let n = 0;
  if (filters.class_id) n++;
  if (filters.subject_id) n++;
  if (filters.date_start || filters.date_end) n++;
  if (filters.lesson_hour_id) n++;
  return n;
});

function clearAllFilters() {
  filters.class_id = '';
  filters.subject_id = '';
  filters.date_start = '';
  filters.date_end = '';
  filters.lesson_hour_id = '';
  filters.search = '';
  void load(1);
}

// ── KPI ────────────────────────────────────────────────────────────
const totalSessions = computed(() => pagination.total);
const filledCount = computed(() => rows.value.filter((r) => r.present > 0 || r.absent > 0).length);
const pendingCount = computed(() => rows.value.filter((r) => r.present === 0 && r.absent === 0).length);
const avgPct = computed(() => {
  const list = rows.value.filter((r) => r.total_students > 0);
  if (list.length === 0) return 0;
  const sum = list.reduce((s, r) => s + (r.percentage ?? 0), 0);
  return Math.round(sum / list.length);
});

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'calendar', label: 'Total Sesi', value: totalSessions.value, tone: 'brand' },
  {
    icon: 'check-circle',
    label: 'Terisi',
    value: filledCount.value,
    suffix: '/halaman',
    tone: 'green',
  },
  {
    icon: 'clock',
    label: 'Pending',
    value: pendingCount.value,
    suffix: '/halaman',
    tone: pendingCount.value > 0 ? 'amber' : 'slate',
  },
  {
    icon: 'activity',
    label: 'Rata Hadir',
    value: `${avgPct.value}%`,
    suffix: '/halaman',
    tone: avgPct.value >= 80 ? 'green' : 'red',
  },
]);

// ── State for AsyncView ─────────────────────────────────────────────
const listState = computed<AsyncState<AdminAttendanceSummary[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

function openDetail(r: AdminAttendanceSummary) {
  router.push({
    name: 'admin.attendance.detail',
    query: {
      class_id: r.class_id,
      subject_id: r.subject_id,
      date: r.date,
      lesson_hour_id: r.lesson_hour_id ?? '',
      attendance_id: r.id,
    },
  });
}

function goBack() {
  router.push({ name: 'admin.attendance' });
}

const headerMeta = computed(() => {
  return `${totalSessions.value.toLocaleString('id-ID')} sesi · halaman ${pagination.page} dari ${pagination.last_page}`;
});

function applyDateRange() {
  filters.date_start = datePickerStart.value;
  filters.date_end = datePickerEnd.value;
  showDatePicker.value = false;
  void load(1);
}

function openDatePicker() {
  datePickerStart.value = filters.date_start;
  datePickerEnd.value = filters.date_end;
  showDatePicker.value = true;
}

function formatPct(pct: number | undefined): string {
  return `${pct ?? 0}%`;
}

// ── Export ─────────────────────────────────────────────────────────
//
// Mirrors Flutter's `AdminReportActionsMixin.showExportDialog` →
// `_processMonthlyExports`: the admin picks one or more months
// from the active academic-year frame (Jul of start year → Jun of end
// year), then we fetch attendance + roster for each month, build a
// flat presence-row list, and POST it to `/attendance/export`.
//
// The export requires a selected class — the report KPI is per-session
// but the XLSX format pivots students × dates × subjects so a class
// scope is mandatory. We surface that as a Toast when missing instead
// of disabling the button (so the user can discover the requirement).

interface MonthOption {
  label: string;          // e.g. "Juli 2024"
  year: number;
  month: number;          // 1-12
  key: number;            // 0-11 within the AY (for stable selection)
}

const academicYearLabel = computed(
  () => academicYearStore.selectedYear?.year ?? '—',
);

const exportMonths = computed<MonthOption[]>(() => {
  const yearStr = academicYearStore.selectedYear?.year ?? '';
  const parts = yearStr.split('/');
  let startYear = new Date().getFullYear();
  if (parts.length > 0) {
    const n = Number(parts[0]);
    if (!Number.isNaN(n)) startYear = n;
  }
  const names = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  return Array.from({ length: 12 }, (_, i) => {
    // July of startYear = index 0
    const monthIdx = (6 + i) % 12;            // 6 = July
    const year = startYear + (6 + i >= 12 ? 1 : 0);
    return {
      label: `${names[monthIdx]} ${year}`,
      year,
      month: monthIdx + 1,
      key: i,
    };
  });
});

function toggleExportMonth(key: number) {
  const i = selectedExportMonths.value.indexOf(key);
  if (i >= 0) selectedExportMonths.value.splice(i, 1);
  else selectedExportMonths.value.push(key);
}

function openExportDialog() {
  if (!filters.class_id) {
    toast.value = {
      message: 'Pilih kelas terlebih dahulu untuk export presensi.',
      tone: 'error',
    };
    return;
  }
  selectedExportMonths.value = [];
  showExportModal.value = true;
}

async function processExport() {
  if (selectedExportMonths.value.length === 0) return;
  const cls = classes.value.find((c) => c.id === filters.class_id);
  if (!cls) {
    toast.value = { message: 'Kelas tidak ditemukan.', tone: 'error' };
    return;
  }

  exportProcessing.value = true;
  try {
    const sortedKeys = [...selectedExportMonths.value].sort((a, b) => a - b);
    const selected = sortedKeys
      .map((k) => exportMonths.value.find((m) => m.key === k))
      .filter((m): m is MonthOption => !!m);

    let successCount = 0;
    let skippedCount = 0;
    for (const m of selected) {
      try {
        const ok = await AttendanceService.downloadMonthlyReport({
          class_id: cls.id,
          class_name: cls.name,
          academic_year_name: academicYearLabel.value,
          academic_year_id:
            academicYearStore.selectedYearId ?? undefined,
          year: m.year,
          month: m.month,
        });
        if (ok) successCount++;
        else skippedCount++;
        // Small breather so browsers don't block multi-download.
        await new Promise((r) => setTimeout(r, 600));
      } catch {
        skippedCount++;
      }
    }

    showExportModal.value = false;
    if (successCount > 0) {
      const skipNote =
        skippedCount > 0 ? ` (${skippedCount} bulan kosong dilewati)` : '';
      toast.value = {
        message: `Berhasil mengexport ${successCount} file XLSX${skipNote}.`,
        tone: 'success',
      };
    } else {
      toast.value = {
        message: 'Tidak ada data presensi pada bulan yang dipilih.',
        tone: 'error',
      };
    }
  } catch (e) {
    toast.value = {
      message: `Export gagal: ${(e as Error).message}`,
      tone: 'error',
    };
  } finally {
    exportProcessing.value = false;
  }
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
      Dashboard Kehadiran
    </button>

    <BrandPageHeader
      role="admin"
      kicker="Akademik · Kehadiran"
      title="Laporan Sesi"
      :meta="headerMeta"
      :live-dot="false"
    >
      <div class="flex items-center gap-2">
        <SegmentedControl
          :model-value="viewMode"
          :options="VIEW_OPTIONS"
          size="sm"
          @update:model-value="(v) => (viewMode = v as ViewMode)"
        />
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-[12px] font-bold px-3 py-1.5 transition-colors"
          @click="openExportDialog"
        >
          <NavIcon name="download" :size="13" />
          Export XLSX
        </button>
      </div>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar
      v-model:search="filters.search"
      search-placeholder="Cari kelas / mapel..."
      :search-min-width="240"
    >
      <template #chips>
        <AppFilterChip
          icon-name="calendar"
          label="Tanggal"
          :value="dateChipValue"
          tone="brand"
          @click="openDatePicker"
        />
        <AppFilterChip
          icon-name="layers"
          label="Kelas"
          :value="classChipValue"
          tone="violet"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          icon-name="book-open"
          label="Mapel"
          :value="subjectChipValue"
          tone="green"
          @click="showSubjectPicker = true"
        />
        <button
          v-if="activeFilterCount > 0"
          type="button"
          class="text-[11px] font-bold text-slate-500 hover:text-role-admin px-2"
          @click="clearAllFilters"
        >
          Bersihkan ({{ activeFilterCount }})
        </button>
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="listState"
      empty-title="Belum ada sesi"
      empty-description="Coba longgarkan filter atau periode tanggal."
      empty-icon="calendar"
      @retry="load(pagination.page)"
    >
      <template #default>
        <!-- LIST view -->
        <ul v-if="viewMode === 'list'" class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
          <li
            v-for="(r, idx) in rows"
            :key="r.id"
            class="px-4 py-3 flex items-center gap-3 hover:bg-slate-50 transition-colors cursor-pointer"
            :class="idx > 0 ? 'border-t border-slate-100' : ''"
            @click="openDetail(r)"
          >
            <div class="w-12 text-center flex-shrink-0">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">JP</p>
              <p class="text-[14px] font-black text-role-admin">{{ r.jam_ke ?? '?' }}</p>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">
                {{ r.subject_name }}
                <span class="text-slate-500 font-normal">· {{ r.class_name }}</span>
              </p>
              <p class="text-[11px] text-slate-500 truncate">
                {{ r.date }}
                <span v-if="r.teacher_name"> · {{ r.teacher_name }}</span>
                <span v-if="r.lesson_hour_name"> · {{ r.lesson_hour_name }}</span>
              </p>
            </div>
            <div class="text-right flex-shrink-0">
              <p
                class="text-[14px] font-black tabular-nums"
                :class="{
                  'text-emerald-700': (r.percentage ?? 0) >= 80,
                  'text-amber-700': (r.percentage ?? 0) >= 60 && (r.percentage ?? 0) < 80,
                  'text-red-700': (r.percentage ?? 0) < 60,
                }"
              >
                {{ formatPct(r.percentage) }}
              </p>
              <p class="text-[10px] text-slate-500 tabular-nums">
                {{ r.present }}/{{ r.total_students }}
              </p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300 ml-1" />
          </li>
        </ul>

        <!-- TABLE view -->
        <section
          v-else
          class="bg-white border border-slate-200 rounded-2xl overflow-x-auto"
        >
          <table class="w-full text-[12px] border-collapse">
            <thead>
              <tr class="bg-slate-50 text-[9px] font-bold text-slate-500 uppercase tracking-widest">
                <th class="px-3 py-2 text-left">Tanggal</th>
                <th class="px-3 py-2 text-left">Mapel</th>
                <th class="px-3 py-2 text-left">Kelas</th>
                <th class="px-3 py-2 text-center">JP</th>
                <th class="px-3 py-2 text-center">Hadir</th>
                <th class="px-3 py-2 text-center">Total</th>
                <th class="px-3 py-2 text-right">Persen</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in rows"
                :key="r.id"
                class="border-t border-slate-100 hover:bg-slate-50 cursor-pointer"
                @click="openDetail(r)"
              >
                <td class="px-3 py-2 tabular-nums">{{ r.date }}</td>
                <td class="px-3 py-2 font-bold text-slate-900">{{ r.subject_name }}</td>
                <td class="px-3 py-2">{{ r.class_name }}</td>
                <td class="px-3 py-2 text-center font-bold text-role-admin">{{ r.jam_ke ?? '—' }}</td>
                <td class="px-3 py-2 text-center tabular-nums">{{ r.present }}</td>
                <td class="px-3 py-2 text-center text-slate-500 tabular-nums">{{ r.total_students }}</td>
                <td
                  class="px-3 py-2 text-right font-black tabular-nums"
                  :class="{
                    'text-emerald-700': (r.percentage ?? 0) >= 80,
                    'text-amber-700': (r.percentage ?? 0) >= 60 && (r.percentage ?? 0) < 80,
                    'text-red-700': (r.percentage ?? 0) < 60,
                  }"
                >
                  {{ formatPct(r.percentage) }}
                </td>
              </tr>
            </tbody>
          </table>
        </section>

        <!-- Pagination -->
        <div
          v-if="pagination.last_page > 1"
          class="flex items-center justify-between gap-2 bg-white border border-slate-200 rounded-2xl px-3 py-2"
        >
          <Button
            variant="secondary"
            size="sm"
            :disabled="pagination.page <= 1"
            @click="load(pagination.page - 1)"
          >
            <NavIcon name="chevron-left" :size="12" />
            Sebelumnya
          </Button>
          <p class="text-[11px] font-bold text-slate-600">
            Halaman {{ pagination.page }} dari {{ pagination.last_page }}
          </p>
          <Button
            variant="secondary"
            size="sm"
            :disabled="pagination.page >= pagination.last_page"
            @click="load(pagination.page + 1)"
          >
            Selanjutnya
            <NavIcon name="chevron-right" :size="12" />
          </Button>
        </div>
      </template>
    </AsyncView>

    <!-- Class picker -->
    <FilterFacetPickerModal
      v-if="showClassPicker"
      title="Filter Kelas"
      :options="classOptions"
      :selected="filters.class_id"
      all-label="Semua kelas"
      @close="showClassPicker = false"
      @apply="(v) => { filters.class_id = v; void load(1); }"
    />

    <!-- Subject picker -->
    <FilterFacetPickerModal
      v-if="showSubjectPicker"
      title="Filter Mata Pelajaran"
      :options="subjectOptions"
      :selected="filters.subject_id"
      all-label="Semua mapel"
      @close="showSubjectPicker = false"
      @apply="(v) => { filters.subject_id = v; void load(1); }"
    />

    <!-- Date range picker -->
    <Modal
      v-if="showDatePicker"
      title="Filter Tanggal"
      subtitle="Pilih rentang tanggal"
      size="sm"
      @close="showDatePicker = false"
    >
      <div class="space-y-3">
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Mulai</label>
          <input
            v-model="datePickerStart"
            type="date"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Selesai</label>
          <input
            v-model="datePickerEnd"
            type="date"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>
        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="datePickerStart = ''; datePickerEnd = ''; applyDateRange()">
            Bersihkan
          </Button>
          <Button variant="primary" block @click="applyDateRange">Terapkan</Button>
        </div>
      </div>
    </Modal>

    <!-- Export month picker (mirrors Flutter AttendanceExportDialog) -->
    <Modal
      v-if="showExportModal"
      title="Export Absensi"
      :subtitle="`Tahun Ajaran ${academicYearLabel} · Pilih bulan yang akan diexport`"
      size="sm"
      @close="showExportModal = false"
    >
      <div class="space-y-3">
        <p class="text-[12px] text-slate-500 leading-relaxed">
          Satu file XLSX per bulan akan diunduh. Bulan tanpa data presensi
          akan dilewati otomatis.
        </p>
        <div class="max-h-72 overflow-y-auto rounded-xl border border-slate-200">
          <label
            v-for="m in exportMonths"
            :key="m.key"
            class="flex items-center gap-2.5 px-3 py-2.5 border-b border-slate-100 last:border-b-0 cursor-pointer hover:bg-slate-50"
          >
            <input
              type="checkbox"
              :checked="selectedExportMonths.includes(m.key)"
              :disabled="exportProcessing"
              class="w-4 h-4 accent-role-admin cursor-pointer"
              @change="toggleExportMonth(m.key)"
            />
            <span class="text-[13px] font-semibold text-slate-800">
              {{ m.label }}
            </span>
          </label>
        </div>
        <p
          v-if="exportProcessing"
          class="text-[11px] text-slate-500 italic"
        >
          Memproses export — jangan tutup tab ini…
        </p>
        <div class="grid grid-cols-2 gap-2 pt-1">
          <Button
            variant="secondary"
            block
            :disabled="exportProcessing"
            @click="showExportModal = false"
          >
            Batal
          </Button>
          <Button
            variant="primary"
            block
            :disabled="selectedExportMonths.length === 0 || exportProcessing"
            @click="processExport"
          >
            <NavIcon name="download" :size="12" />
            {{ exportProcessing ? 'Memproses…' : `Export (${selectedExportMonths.length})` }}
          </Button>
        </div>
      </div>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
