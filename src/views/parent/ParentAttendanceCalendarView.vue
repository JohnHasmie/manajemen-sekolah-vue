<!--
  ParentAttendanceCalendarView.vue — kalender kehadiran anak.

  Phase-4 rebuild (Flutter parity with `ParentAttendanceCalendarScreen`):
    1. BrandPageHeader (wali) — month label + chevrons + AttendanceMiniKpi
       row (Hadir/Izin/Sakit/Alpa) sitting inside #role-toggle.
    2. AttendanceCalendarGrid — SEN-MIN 7-column grid, worst-status wins,
       click a day to drill in.
    3. Inline detail panel — list of records for the selected day with
       lesson hour name + subject + status pill + notes.

  Data: reuses `useParentAttendance` so flipping in from the list view
  is instant (no extra round-trip). Local viewMonth chevrons only
  re-slice the cached year — never refetch.
-->
<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
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
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import AttendanceMiniKpi from '@/components/feature/AttendanceMiniKpi.vue';
import AttendanceCalendarGrid from '@/components/feature/AttendanceCalendarGrid.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';

const router = useRouter();
const { t } = useI18n();
const ayStore = useAcademicYearStore();
const { activeChildId, activeChild } = useChildPicker();
const attCache = useParentAttendance();

const allEntries = ref<ParentAttendanceEntry[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);

// View state.
const month = ref(new Date().toISOString().slice(0, 7));
const selectedDate = ref<string>(new Date().toISOString().slice(0, 10));

async function reload(opts: { force?: boolean } = {}) {
  if (!activeChildId.value) {
    isLoading.value = false;
    allEntries.value = [];
    return;
  }
  const ayId = ayStore.selectedYearId;
  if (!opts.force) {
    const hit = attCache.get(activeChildId.value, ayId);
    if (hit) {
      allEntries.value = hit;
      isLoading.value = false;
      return;
    }
  }
  isLoading.value = true;
  error.value = null;
  try {
    allEntries.value = await attCache.fetchYear(activeChildId.value, ayId, {
      force: opts.force,
    });
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(reload);
watch(activeChildId, () => reload());
useAcademicYearWatcher(() => {
  attCache.clearAll();
  reload({ force: true });
});

// ── Month slice ───────────────────────────────────────────────
const monthRecords = computed<ParentAttendanceEntry[]>(() =>
  allEntries.value.filter((r) => r.date && r.date.startsWith(month.value)),
);

const monthLabel = computed(() => {
  const [yr, mo] = month.value.split('-').map(Number);
  if (!Number.isFinite(yr) || !Number.isFinite(mo)) return month.value;
  return new Date(yr, mo - 1, 1).toLocaleDateString('id-ID', {
    month: 'long',
    year: 'numeric',
  });
});

function shiftMonth(delta: number) {
  const [yr, mo] = month.value.split('-').map(Number);
  const d = new Date(yr, mo - 1 + delta, 1);
  month.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

// ── KPI tile counts (per month) ──────────────────────────────
const monthCounts = computed(() => {
  let hadir = 0, izin = 0, sakit = 0, alpha = 0;
  for (const r of monthRecords.value) {
    switch (r.status) {
      case 'hadir':
      case 'terlambat':
        hadir++;
        break;
      case 'izin':
        izin++;
        break;
      case 'sakit':
        sakit++;
        break;
      case 'alpha':
        alpha++;
        break;
    }
  }
  return { hadir, izin, sakit, alpha };
});

// ── Selected-day records ──────────────────────────────────────
const selectedDayRecords = computed<ParentAttendanceEntry[]>(() =>
  monthRecords.value
    .filter((r) => r.date === selectedDate.value)
    .sort((a, b) => (a.lesson_hour_name ?? '').localeCompare(b.lesson_hour_name ?? '')),
);

const selectedDayLabel = computed(() => {
  if (!selectedDate.value) return '';
  const d = new Date(selectedDate.value);
  if (!Number.isFinite(d.getTime())) return selectedDate.value;
  return d.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
});

function onSelectDay(iso: string) {
  selectedDate.value = iso;
}

// ── IntersectionObserver mark-as-read (mirrors list view) ──────
//
// When the parent picks a day on the calendar, the records list
// underneath becomes visible. Any unread row that scrolls into the
// detail panel auto-marks as read after a 600ms debounce — same
// pattern used by ParentAttendanceView so cache state stays in
// sync regardless of which view the parent opens first.
const recordsRoot = ref<HTMLElement | null>(null);
let observer: IntersectionObserver | null = null;
const pendingUnread = new Set<string>();
let flushTimer: number | null = null;

function flushMarkRead() {
  if (pendingUnread.size === 0) return;
  const ids = Array.from(pendingUnread);
  pendingUnread.clear();
  ParentService.markPresenceAsRead(ids).then(() => {
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
  if (!observer || !recordsRoot.value) return;
  const nodes = recordsRoot.value.querySelectorAll<HTMLElement>('[data-unread="1"]');
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

// Re-attach observers whenever the visible day's records change
// (different day picked, fresh fetch arrived, etc.).
watch(selectedDayRecords, async () => {
  await nextTick();
  attachUnreadObservers();
});

// Pill styling.
function pillCls(s: ParentAttendanceStatus): string {
  switch (s) {
    case 'hadir':
      return 'bg-emerald-50 text-emerald-700 border border-emerald-200';
    case 'terlambat':
      return 'bg-amber-50 text-amber-700 border border-amber-200';
    case 'izin':
      return 'bg-brand-cobalt/10 text-brand-cobalt border border-brand-cobalt/20';
    case 'sakit':
      return 'bg-orange-50 text-orange-700 border border-orange-200';
    case 'alpha':
    default:
      return 'bg-red-50 text-red-700 border border-red-200';
  }
}
function dotCls(s: ParentAttendanceStatus): string {
  switch (s) {
    case 'hadir':
      return 'bg-emerald-500';
    case 'terlambat':
      return 'bg-amber-500';
    case 'izin':
      return 'bg-brand-cobalt';
    case 'sakit':
      return 'bg-orange-500';
    case 'alpha':
    default:
      return 'bg-red-500';
  }
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Back chevron -->
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-xs font-bold text-slate-500 hover:text-slate-800 transition-colors"
      @click="router.push({ name: 'parent.attendance' })"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('wali.sekolah.attendanceCalendar.back') }}
    </button>

    <!-- 1. Header -->
    <ParentPageHeader
      :kicker="t('wali.sekolah.attendanceCalendar.kicker')"
      :title="monthLabel"
      :interpolate-child="false"
      :meta="activeChild()?.name ?? ''"
    >
      <template #actions>
        <div class="flex items-center gap-1">
          <button
            type="button"
            class="w-7 h-7 rounded-full flex items-center justify-center bg-white/15 hover:bg-white/25 text-white transition-colors"
            @click="shiftMonth(-1)"
          >
            <NavIcon name="chevron-left" :size="14" />
          </button>
          <button
            type="button"
            class="w-7 h-7 rounded-full flex items-center justify-center bg-white/15 hover:bg-white/25 text-white transition-colors"
            @click="shiftMonth(1)"
          >
            <NavIcon name="chevron-right" :size="14" />
          </button>
        </div>
      </template>

      <AttendanceMiniKpi
        :hadir="monthCounts.hadir"
        :izin="monthCounts.izin"
        :sakit="monthCounts.sakit"
        :alpha="monthCounts.alpha"
      />
    </ParentPageHeader>

    <!-- Loading + error fallbacks -->
    <div
      v-if="isLoading && allEntries.length === 0"
      class="bg-white border border-slate-200 rounded-2xl p-6 flex items-center justify-center text-slate-400"
    >
      <Spinner size="md" />
    </div>
    <div
      v-else-if="error"
      class="bg-red-50 border border-red-200 rounded-2xl p-4 text-sm text-red-700 flex items-center justify-between"
    >
      <span>{{ error }}</span>
      <button
        type="button"
        class="text-xs font-bold text-red-700 hover:text-red-900"
        @click="reload({ force: true })"
      >
        {{ t('wali.sekolah.attendanceCalendar.retry') }}
      </button>
    </div>

    <!-- 2. Calendar grid -->
    <AttendanceCalendarGrid
      v-else
      :month-iso="month"
      :records="monthRecords"
      :selected-date="selectedDate"
      @select="onSelectDay"
    />

    <!-- 3. Selected-day detail panel -->
    <section
      v-if="!isLoading && !error"
      class="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm space-y-md"
    >
      <header class="border-b border-slate-100 pb-2">
        <p class="text-[10px] font-black text-slate-400 uppercase tracking-wider">
          {{ t('wali.sekolah.attendanceCalendar.detail') }}
        </p>
        <p class="text-sm font-extrabold text-slate-900 mt-0.5">
          {{ selectedDayLabel }}
        </p>
      </header>

      <div
        v-if="selectedDayRecords.length === 0"
        class="text-slate-500 text-xs py-3 text-center"
      >
        {{ t('wali.sekolah.attendanceCalendar.empty') }}
      </div>
      <div v-else ref="recordsRoot" class="space-y-4">
        <div
          v-for="(record, rIdx) in selectedDayRecords"
          :key="record.id"
          :data-attendance-id="record.id"
          :data-unread="record.is_read === false ? '1' : '0'"
          class="space-y-2"
          :class="{ 'pt-4 border-t border-slate-100': rIdx > 0 }"
        >
          <div
            class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider"
            :class="pillCls(record.status)"
          >
            <span class="w-1.5 h-1.5 rounded-full" :class="dotCls(record.status)"></span>
            {{ PARENT_ATTENDANCE_LABELS[record.status] }}
          </div>

          <h5 class="text-[14px] font-extrabold text-slate-900 leading-tight">
            {{ record.subject_name || t('wali.sekolah.attendanceCalendar.dailyPresence') }}
          </h5>

          <p
            v-if="record.lesson_hour_name || record.session"
            class="text-[12px] text-slate-500 font-medium"
          >
            {{ record.lesson_hour_name || record.session }}
          </p>

          <p
            v-if="record.notes"
            class="text-[12px] text-slate-600 bg-slate-50 p-2 rounded-lg border border-slate-100 mt-1"
          >
            {{ t('wali.sekolah.attendanceCalendar.notes', { notes: record.notes }) }}
          </p>
        </div>
      </div>
    </section>
  </div>
</template>
