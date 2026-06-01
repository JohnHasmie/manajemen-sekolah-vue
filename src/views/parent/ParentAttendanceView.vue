<!--
  ParentAttendanceView.vue — daftar kehadiran anak.

  Phase-3 rebuild (Flutter parity):
    1. BrandPageHeader (wali) + child chip toggle (multi-child).
    2. AttendanceRingKpi — ring + 4-tile breakdown + delta vs bulan lalu.
    3. PageFilterToolbar — month shifter chip + status filter chip.
    4. AsyncView with dual-mode empty (filtered vs no data) and a
       skeleton loader on first load.
    5. AttendanceDayRow list (one row per record).
    6. CTA → ParentAttendanceCalendarView.
    7. IntersectionObserver auto-marks visible unread rows as read,
       debounced to one batched POST.

  Data shape: we fetch the FULL academic year for the active child
  (cached per studentId + AY) and slice by month client-side so
  switching months feels instant.
-->
<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useChildPicker } from '@/composables/useChildPicker';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useParentAttendance } from '@/composables/useParentAttendance';
import { ParentService } from '@/services/parent.service';
import type {
  ParentAttendanceEntry,
  ParentAttendanceStatus,
} from '@/types/parent';
import { PARENT_ATTENDANCE_LABELS } from '@/types/parent';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import AttendanceRingKpi from '@/components/feature/AttendanceRingKpi.vue';
import AttendanceDayRow from '@/components/feature/AttendanceDayRow.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';

const router = useRouter();
const ayStore = useAcademicYearStore();
const { activeChildId, activeChild } = useChildPicker();
const attCache = useParentAttendance();

// ── Year-scoped cache ─────────────────────────────────────────
const allEntries = ref<ParentAttendanceEntry[]>([]);
const isLoading = ref(true);
const isFirstLoad = ref(true);
const error = ref<string | null>(null);

const month = ref(new Date().toISOString().slice(0, 7));

// ── Filters ───────────────────────────────────────────────────
type StatusFilter = 'all' | ParentAttendanceStatus;
const statusFilter = ref<StatusFilter>('all');

const STATUS_OPTIONS: { key: StatusFilter; label: string }[] = [
  { key: 'all', label: 'Semua status' },
  { key: 'hadir', label: PARENT_ATTENDANCE_LABELS.hadir },
  { key: 'terlambat', label: PARENT_ATTENDANCE_LABELS.terlambat },
  { key: 'izin', label: PARENT_ATTENDANCE_LABELS.izin },
  { key: 'sakit', label: PARENT_ATTENDANCE_LABELS.sakit },
  { key: 'alpha', label: PARENT_ATTENDANCE_LABELS.alpha },
];
const activeStatus = computed(
  () => STATUS_OPTIONS.find((s) => s.key === statusFilter.value) ?? STATUS_OPTIONS[0],
);

const showPeriodPicker = ref(false);
const showStatusPicker = ref(false);

const MONTH_OPTIONS = [
  { val: '01', label: 'Januari' },
  { val: '02', label: 'Februari' },
  { val: '03', label: 'Maret' },
  { val: '04', label: 'April' },
  { val: '05', label: 'Mei' },
  { val: '06', label: 'Juni' },
  { val: '07', label: 'Juli' },
  { val: '08', label: 'Agustus' },
  { val: '09', label: 'September' },
  { val: '10', label: 'Oktober' },
  { val: '11', label: 'November' },
  { val: '12', label: 'Desember' },
];

// ── Loaders ───────────────────────────────────────────────────
async function reload(opts: { force?: boolean } = {}) {
  if (!activeChildId.value) {
    isLoading.value = false;
    isFirstLoad.value = false;
    allEntries.value = [];
    return;
  }
  const ayId = ayStore.selectedYearId;
  if (!opts.force) {
    const hit = attCache.get(activeChildId.value, ayId);
    if (hit) {
      allEntries.value = hit;
      isLoading.value = false;
      isFirstLoad.value = false;
      return;
    }
  }
  isLoading.value = true;
  error.value = null;
  try {
    const rows = await attCache.fetchYear(activeChildId.value, ayId, {
      force: opts.force,
    });
    allEntries.value = rows;
    // One-shot: clear the unread badge for the whole child.
    ParentService.markAttendanceRead(activeChildId.value).catch(() => {});
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
    isFirstLoad.value = false;
  }
}

onMounted(reload);

watch(activeChildId, () => {
  isFirstLoad.value = true;
  reload();
});

useAcademicYearWatcher(() => {
  attCache.clearAll();
  isFirstLoad.value = true;
  reload({ force: true });
});

// ── Slicing ───────────────────────────────────────────────────
// The KPI ring summarises the selected month, but the daily-history
// list shows the FULL academic year (most-recent first) — same as
// the mobile parent flow. The status chip narrows that list; the
// month chip only steers the KPI window.
function inMonth(iso: string, ym: string): boolean {
  return typeof iso === 'string' && iso.startsWith(ym);
}

const monthEntries = computed<ParentAttendanceEntry[]>(() =>
  allEntries.value.filter((r) => inMonth(r.date, month.value)),
);

const sortedAll = computed<ParentAttendanceEntry[]>(() => {
  return [...allEntries.value].sort((a, b) => (b.date || '').localeCompare(a.date || ''));
});

const filteredEntries = computed<ParentAttendanceEntry[]>(() => {
  const s = statusFilter.value;
  if (s === 'all') return sortedAll.value;
  return sortedAll.value.filter((e) => e.status === s);
});

const monthLabel = computed(() => {
  const [yr, mo] = month.value.split('-').map(Number);
  if (!Number.isFinite(yr) || !Number.isFinite(mo)) return month.value;
  return new Date(yr, mo - 1, 1).toLocaleDateString('id-ID', {
    month: 'long',
    year: 'numeric',
  });
});

const derivedSemester = computed(() => {
  const mo = Number(month.value.split('-')[1]);
  return mo >= 7 ? 'Ganjil' : 'Genap';
});

const periodLabel = computed(() => `${monthLabel.value} · ${derivedSemester.value}`);

const currentYearLabel = computed(() => month.value.split('-')[0]);

function shiftMonth(delta: number) {
  const [yr, mo] = month.value.split('-').map(Number);
  const d = new Date(yr, mo - 1 + delta, 1);
  month.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function shiftYear(delta: number) {
  const [yr, mo] = month.value.split('-');
  month.value = `${Number(yr) + delta}-${mo}`;
}

function isSelectedMonth(val: string) {
  return month.value.split('-')[1] === val;
}

function selectMonth(val: string) {
  const [yr] = month.value.split('-');
  month.value = `${yr}-${val}`;
  showPeriodPicker.value = false;
}

function pickStatus(k: StatusFilter) {
  statusFilter.value = k;
  showStatusPicker.value = false;
}

// ── Counts for KPI ring ───────────────────────────────────────
interface Counts {
  hadir: number;
  terlambat: number;
  izin: number;
  sakit: number;
  alpha: number;
}
function tally(rows: ParentAttendanceEntry[]): Counts {
  const c: Counts = { hadir: 0, terlambat: 0, izin: 0, sakit: 0, alpha: 0 };
  for (const r of rows) c[r.status]++;
  return c;
}
function presentRate(c: Counts): number {
  const total = c.hadir + c.terlambat + c.izin + c.sakit + c.alpha;
  if (total === 0) return 0;
  // Flutter counts terlambat as "present".
  return ((c.hadir + c.terlambat) / total) * 100;
}

const monthCounts = computed<Counts>(() => tally(monthEntries.value));
const monthRate = computed<number>(() => presentRate(monthCounts.value));
const monthDays = computed<number>(
  () => new Set(monthEntries.value.map((r) => r.date)).size,
);

const previousMonth = computed<string>(() => {
  const [yr, mo] = month.value.split('-').map(Number);
  const d = new Date(yr, mo - 2, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
});

const previousMonthRate = computed<number | null>(() => {
  const rows = allEntries.value.filter((r) => inMonth(r.date, previousMonth.value));
  if (rows.length === 0) return null;
  return presentRate(tally(rows));
});

const deltaPct = computed<number | null>(() => {
  if (previousMonthRate.value == null) return null;
  return monthRate.value - previousMonthRate.value;
});

// ── Async state ───────────────────────────────────────────────
const state = computed<AsyncState<ParentAttendanceEntry[]>>(() => {
  if (isLoading.value && isFirstLoad.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filteredEntries.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredEntries.value };
});

// Dual-mode empty:
// - There are records overall but the status filter excluded all → tell the
//   parent to clear it.
// - Otherwise the child genuinely has nothing in this academic year.
const emptyTitle = computed(() => {
  const hasUnfiltered = allEntries.value.length > 0;
  if (hasUnfiltered) return 'Tidak ada catatan untuk filter ini';
  return 'Belum ada catatan kehadiran';
});
const emptyDescription = computed(() => {
  const hasUnfiltered = allEntries.value.length > 0;
  if (hasUnfiltered) {
    return 'Coba ubah filter status.';
  }
  return `${activeChild()?.name ?? 'Anak ini'} belum punya catatan presensi pada tahun ajaran ini.`;
});

// ── IntersectionObserver mark-as-read ─────────────────────────
const observerRoot = ref<HTMLElement | null>(null);
let observer: IntersectionObserver | null = null;
const pendingUnread = new Set<string>();
let flushTimer: number | null = null;

function flushMarkRead() {
  if (pendingUnread.size === 0) return;
  const ids = Array.from(pendingUnread);
  pendingUnread.clear();
  ParentService.markPresenceAsRead(ids).then(() => {
    // Sync the shared cache so the row no longer shows as unread.
    const ayId = ayStore.selectedYearId;
    const cached = attCache.get(activeChildId.value, ayId);
    if (cached) {
      const idSet = new Set(ids);
      const updated = cached.map((r) =>
        idSet.has(r.id) ? { ...r, is_read: true } : r,
      );
      attCache.patch(activeChildId.value, ayId, updated);
      allEntries.value = updated;
    }
  });
}

function scheduleFlush() {
  if (flushTimer != null) window.clearTimeout(flushTimer);
  flushTimer = window.setTimeout(flushMarkRead, 600);
}

function setupObserver() {
  if (observer) return;
  if (typeof IntersectionObserver === 'undefined') return;
  observer = new IntersectionObserver(
    (records) => {
      for (const r of records) {
        if (!r.isIntersecting) continue;
        const id = (r.target as HTMLElement).dataset.attendanceId;
        if (id) pendingUnread.add(id);
      }
      if (pendingUnread.size > 0) scheduleFlush();
    },
    { threshold: 0.6 },
  );
}

function attachUnreadObservers() {
  if (!observer || !observerRoot.value) return;
  const nodes = observerRoot.value.querySelectorAll<HTMLElement>('[data-unread="1"]');
  nodes.forEach((n) => observer!.observe(n));
}

onMounted(() => {
  setupObserver();
});
onBeforeUnmount(() => {
  observer?.disconnect();
  observer = null;
  if (flushTimer != null) window.clearTimeout(flushTimer);
});

// Re-attach observers when the filtered list changes.
watch(filteredEntries, async () => {
  await nextTick();
  attachUnreadObservers();
});

function openCalendar() {
  router.push({ name: 'parent.attendance.calendar' });
}

// Static skeleton rows for first paint.
const SKELETON_ROWS = Array.from({ length: 5 });

</script>

<template>
  <div class="space-y-md pb-12">
    <!-- 1. Header -->
    <ParentPageHeader
      kicker="Akademik · Anak"
      title="Kehadiran"
      :meta="`${activeChild()?.class_name ?? '—'}`"
    />

    <!-- 2. Ring KPI hero -->
    <AttendanceRingKpi
      :rate="monthRate"
      :period-label="periodLabel"
      :present="monthCounts.hadir + monthCounts.terlambat"
      :izin="monthCounts.izin"
      :sakit="monthCounts.sakit"
      :alpha="monthCounts.alpha"
      :school-days="monthDays"
      :delta-pct="deltaPct"
    />

    <!-- 3. Filter toolbar -->
    <PageFilterToolbar hide-search>
      <template #chips>
        <div class="flex items-center gap-2 flex-wrap">
          <!-- Month shifter -->
          <div
            class="inline-flex items-center rounded-xl border border-slate-200 bg-white p-0.5 shadow-sm"
          >
            <button
              type="button"
              class="p-1 rounded-lg bg-slate-50 hover:bg-slate-100 text-slate-500 transition-colors"
              @click="shiftMonth(-1)"
            >
              <NavIcon name="chevron-left" :size="12" />
            </button>
            <span
              class="px-2.5 text-[11px] font-bold text-slate-800 cursor-pointer hover:text-role-wali"
              @click="showPeriodPicker = true"
            >
              {{ periodLabel }}
            </span>
            <button
              type="button"
              class="p-1 rounded-lg bg-slate-50 hover:bg-slate-100 text-slate-500 transition-colors"
              @click="shiftMonth(1)"
            >
              <NavIcon name="chevron-right" :size="12" />
            </button>
          </div>

          <AppFilterChip
            label="Status"
            :value="activeStatus.label"
            icon-name="check-circle"
            tone="violet"
            @click="showStatusPicker = true"
          />
        </div>
      </template>
    </PageFilterToolbar>

    <!-- 4. Skeleton on first load, otherwise AsyncView. -->
    <div
      v-if="isLoading && isFirstLoad"
      class="space-y-2.5"
      aria-hidden="true"
    >
      <div
        v-for="(_, i) in SKELETON_ROWS"
        :key="i"
        class="flex items-center gap-3 p-3.5 bg-white border border-slate-100 rounded-2xl"
      >
        <div class="w-11 h-12 rounded-xl bg-slate-100 animate-pulse"></div>
        <div class="flex-1 space-y-2">
          <div class="h-3 w-2/3 bg-slate-100 rounded animate-pulse"></div>
          <div class="h-2.5 w-1/2 bg-slate-100 rounded animate-pulse"></div>
        </div>
        <div class="w-12 h-4 bg-slate-100 rounded-full animate-pulse"></div>
      </div>
    </div>

    <div v-else>
      <!-- Section title (matches mobile "Riwayat harian") -->
      <header
        v-if="state.status === 'content'"
        class="flex items-center justify-between mb-2"
      >
        <h3 class="text-sm font-extrabold text-slate-900">Riwayat harian</h3>
        <span class="text-[11px] font-bold text-slate-500">
          {{ filteredEntries.length }} catatan
        </span>
      </header>

      <AsyncView
        :state="state"
        :empty-title="emptyTitle"
        :empty-description="emptyDescription"
        empty-icon="calendar"
        @retry="reload({ force: true })"
      >
        <template #default>
          <section ref="observerRoot" class="space-y-1">
            <AttendanceDayRow
              v-for="e in filteredEntries"
              :key="e.id"
              :entry="e"
              :data-attendance-id="e.id"
              :data-unread="e.is_read === false ? '1' : '0'"
            />
          </section>
        </template>
      </AsyncView>
    </div>

    <!-- CTA → calendar (always visible, even in empty state) -->
    <button
      v-if="!(isLoading && isFirstLoad)"
      type="button"
      class="w-full flex items-center justify-center gap-2 py-3.5 bg-role-wali/5 text-role-wali border border-role-wali/20 rounded-2xl font-bold hover:bg-role-wali/10 transition-colors shadow-sm"
      @click="openCalendar"
    >
      <NavIcon name="calendar" :size="16" />
      Lihat kalender penuh →
    </button>

    <!-- Period picker modal -->
    <Modal
      v-if="showPeriodPicker"
      title="Filter Bulan & Tahun"
      @close="showPeriodPicker = false"
    >
      <div class="space-y-md">
        <div class="flex items-center justify-between border-b border-slate-100 pb-3">
          <button
            type="button"
            class="p-1.5 rounded-lg bg-slate-50 hover:bg-slate-100 text-slate-500 transition-colors"
            @click="shiftYear(-1)"
          >
            <NavIcon name="chevron-left" :size="14" />
          </button>
          <span class="text-sm font-extrabold text-slate-900">
            {{ currentYearLabel }}
          </span>
          <button
            type="button"
            class="p-1.5 rounded-lg bg-slate-50 hover:bg-slate-100 text-slate-500 transition-colors"
            @click="shiftYear(1)"
          >
            <NavIcon name="chevron-right" :size="14" />
          </button>
        </div>
        <div class="grid grid-cols-3 gap-2">
          <button
            v-for="mOpt in MONTH_OPTIONS"
            :key="mOpt.val"
            type="button"
            class="py-3 text-center rounded-xl text-xs font-bold transition-all border"
            :class="
              isSelectedMonth(mOpt.val)
                ? 'bg-role-wali/5 text-role-wali border-role-wali font-black'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50 hover:border-slate-300'
            "
            @click="selectMonth(mOpt.val)"
          >
            {{ mOpt.label }}
          </button>
        </div>
      </div>
    </Modal>

    <!-- Status picker modal -->
    <Modal
      v-if="showStatusPicker"
      title="Filter Status Kehadiran"
      @close="showStatusPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="s in STATUS_OPTIONS" :key="s.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors"
            :class="{
              'bg-role-wali/5 text-role-wali font-bold': s.key === statusFilter,
            }"
            @click="pickStatus(s.key)"
          >
            {{ s.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
