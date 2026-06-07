<!--
  TeacherScheduleView.vue — Jadwal Mengajar (Pekan Ini).

  Web port of Flutter's `teacher_schedule_screen.dart` redesign:
    1. Header — live-dot kicker + h1 + meta, 2-state view toggle (Kartu/Matrix)
    2. KPI strip — 4 inline cards with tinted icon-squares (Hari Ini accented)
    3. Filter toolbar — AppFilterChip pattern (Hari · Kelas) + search input.
       Semester picker lives behind the bottom-sheet filter on mobile and
       is intentionally not surfaced as a primary toolbar control (parity
       with `teacher_schedule_screen.dart`).
    4. Today banner — cobalt gradient with progress strip + "Buka sesi aktif"
    5. Kartu view — 2-column day-grouped grid with day-coloured cards
       (JP chip + subject + class pill + clock/room + SEDANG/SELANJUTNYA pill
       + Presensi/Kegiatan/Materi action row on today's cards)
    6. Matrix view — JP-row × day-column week grid (live cell red, next cell
       dashed cobalt, today column tinted)
    7. Session detail modal (mirrors Flutter Frame E) — unchanged
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useRouter } from 'vue-router';
import { ScheduleService } from '@/services/schedule.service';
import { ClassroomService } from '@/services/classrooms.service';
import type { DayKey, ScheduleSession, SessionSummary } from '@/types/schedule';
import { DAY_LABELS, DAY_ORDER, sessionSummaryKey } from '@/types/schedule';
import { semesterLabel } from '@/lib/labels';
import type { Classroom } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import RoleToggleChipRow, {
  type RoleOption,
} from '@/components/feature/RoleToggleChipRow.vue';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { fromQuickAction } = useQuickAction();
const { t } = useI18n();

const auth = useAuthStore();
const router = useRouter();

// ── View state ─────────────────────────────────────────────────
type ViewKind = 'kartu' | 'matrix';

const view = ref<ViewKind>('kartu');
/**
 * Active role id from <RoleToggleChipRow>. `'mengajar'` for the
 * teaching view, or `'wali:<classId>'` for a specific homeroom.
 */
const selectedRoleId = ref<string>('mengajar');
const dayFilter = ref<'all' | DayKey>('all');
const classFilter = ref<string>('');
const searchQuery = ref<string>('');

const showHariPicker = ref(false);
const showKelasPicker = ref(false);

// ── Role chip options ──────────────────────────────────────────
const roleOptions = computed<RoleOption[]>(() => {
  const out: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: t('teacher.schedule.teaching'),
      subLabel: t('teacher.schedule.teachingSchedule'),
      avatarInitials: 'M',
    },
  ];
  for (const hc of auth.homeroomClasses) {
    const name = hc.name || hc.id;
    out.push({
      id: `wali:${hc.id}`,
      shortName: `Wali ${name}`,
      subLabel: t('teacher.schedule.homeroomClass'),
      avatarInitials:
        name.length === 0
          ? 'W'
          : name.length <= 2
            ? name.toUpperCase()
            : name.slice(0, 2).toUpperCase(),
    });
  }
  return out;
});

/** True when the active chip is a wali-kelas chip. */
const isWaliMode = computed(() => selectedRoleId.value.startsWith('wali:'));
/** Active homeroom class id (if isWaliMode). */
const activeHomeroomId = computed(() =>
  isWaliMode.value ? selectedRoleId.value.slice(5) : null,
);
const activeHomeroom = computed(() =>
  auth.homeroomClasses.find((h) => h.id === activeHomeroomId.value) ?? null,
);

// ── Data state ─────────────────────────────────────────────────
const sessions = ref<ScheduleSession[]>([]);
const summaries = ref<Record<string, SessionSummary>>({});
const classes = ref<Classroom[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const detail = ref<ScheduleSession | null>(null);

// Refresh "now" once per minute so live banners + status pills stay accurate.
const nowTick = ref(Date.now());
let tickTimer: ReturnType<typeof setInterval> | null = null;

// ── Day colour map (matches Flutter `dayColorMap`) ─────────────
const DAY_COLOR_MAP: Record<DayKey, string> = {
  mon: '#15803D', // emerald-700
  tue: '#0D9488', // teal-600
  wed: '#B45309', // amber-700
  thu: '#7C3AED', // violet-600
  fri: '#E11D48', // rose-600
  sat: '#0284C7', // sky-600
};

/** Sunday — Flutter only ships mon-sat, but `/teaching-schedule/current`
 * can include Minggu sessions on schools that teach weekends. */
const SUNDAY_COLOR = '#4F46E5'; // indigo-600

function dayColor(d: DayKey | 'sun'): string {
  if (d === 'sun') return SUNDAY_COLOR;
  return DAY_COLOR_MAP[d];
}

// ── Computed: today + filtering ────────────────────────────────
/**
 * The real day-of-week of "now" mapped to DayKey, or null on Sunday
 * (the schedule data is mon-sat). Used as the *truth* for live /
 * upcoming / ended status — applying clock comparison to a session
 * whose `day` doesn't match this would falsely flag a Monday class
 * as SELESAI when the user is browsing on Sunday afternoon.
 */
const realTodayDay = computed<DayKey | null>(() => {
  const idx = new Date().getDay();
  if (idx === 0) return null; // Sunday → no teaching day
  return (['mon', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][idx] ??
    null) as DayKey | null;
});

/**
 * The day to visually accent as "today" in the UI. Falls back to
 * Monday on Sunday so a Minggu-less calendar still has *some* column
 * highlighted as the next teaching day.
 */
const todayDay = computed<DayKey>(
  () => realTodayDay.value ?? ('mon' as DayKey),
);

const todayLong = computed(() =>
  new Date().toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }),
);

const filteredSessions = computed<ScheduleSession[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return sessions.value.filter((s) => {
    if (dayFilter.value !== 'all' && s.day !== dayFilter.value) return false;
    if (classFilter.value && s.class_id !== classFilter.value) return false;
    if (q) {
      const blob = `${s.subject_name} ${s.class_name} ${s.room ?? ''}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

// Group filtered sessions by day for the Kartu view.
const grouped = computed<Record<DayKey, ScheduleSession[]>>(() => {
  const out: Record<string, ScheduleSession[]> = {};
  for (const d of DAY_ORDER) out[d] = [];
  for (const s of filteredSessions.value) {
    if (out[s.day]) out[s.day].push(s);
  }
  for (const d of DAY_ORDER) {
    out[d].sort((a, b) => a.start_time.localeCompare(b.start_time));
  }
  return out as Record<DayKey, ScheduleSession[]>;
});

// Unique hour slots across the loaded sessions for the matrix view.
const hourSlots = computed(() => {
  const set = new Map<string, { start: string; end: string; hour?: number }>();
  for (const s of sessions.value) {
    const key = `${s.start_time}-${s.end_time}`;
    if (!set.has(key)) {
      set.set(key, {
        start: s.start_time,
        end: s.end_time,
        hour: s.hour_index,
      });
    }
  }
  return Array.from(set.values()).sort((a, b) =>
    a.start.localeCompare(b.start),
  );
});

function findCell(day: DayKey, start: string): ScheduleSession | null {
  return (
    filteredSessions.value.find(
      (s) => s.day === day && s.start_time === start,
    ) ?? null
  );
}

// ── KPI numbers ────────────────────────────────────────────────
const totalSessions = computed(() => filteredSessions.value.length);
const sessionsToday = computed(() => grouped.value[todayDay.value]?.length ?? 0);
const uniqueClasses = computed(
  () => new Set(filteredSessions.value.map((s) => s.class_id)).size,
);
const uniqueSubjects = computed(
  () => new Set(filteredSessions.value.map((s) => s.subject_id)).size,
);

// KPI cards bundle for the shared <KpiStripCards>.
const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'calendar',
    label: t('teacher.schedule.sessionsWeek'),
    value: totalSessions.value,
    tone: 'brand',
  },
  {
    icon: 'check-circle',
    label: t('common.today'),
    value: sessionsToday.value,
    suffix: t('common.sessions'),
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'book',
    label: t('teacher.schedule.subjects'),
    value: uniqueSubjects.value,
    tone: 'violet',
  },
  {
    icon: 'layers',
    label: t('common.classes'),
    value: uniqueClasses.value,
    tone: 'green',
  },
]);

// ── Live + next status ────────────────────────────────────────
function parseTime(time?: string | null): number {
  if (!time) return 0;
  const [hh, mm] = time.split(':');
  return (Number(hh) || 0) * 60 + (Number(mm) || 0);
}

function liveStatusFor(s: ScheduleSession): {
  isLive: boolean;
  isUpcoming: boolean;
  isEnded: boolean;
  remainingMin: number;
} {
  // Re-read nowTick so this stays reactive on the minute tick.
  void nowTick.value;
  // Only apply clock comparison when the session sits on the *real*
  // today day-of-week. On Sunday this is null → nothing is live or
  // ended (every weekday session is just neutral upcoming).
  const today = realTodayDay.value;
  if (!today || s.day !== today) {
    return { isLive: false, isUpcoming: false, isEnded: false, remainingMin: 0 };
  }
  const now = new Date();
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const startMin = parseTime(s.start_time);
  const endMin = parseTime(s.end_time);
  const isLive = startMin <= nowMin && nowMin < endMin;
  const isUpcoming = nowMin < startMin;
  const isEnded = nowMin >= endMin;
  const remainingMin = isLive
    ? endMin - nowMin
    : isUpcoming
      ? startMin - nowMin
      : 0;
  return { isLive, isUpcoming, isEnded, remainingMin };
}

// ── Today aggregates (drives the Today banner) ─────────────────
/**
 * Today's session list. On Sunday this is empty so the banner hides
 * and the "next teaching day" fallback can take over.
 */
const todaySessions = computed<ScheduleSession[]>(() =>
  realTodayDay.value ? (grouped.value[realTodayDay.value] ?? []) : [],
);

/**
 * Next teaching day to surface when today has no sessions
 * (weekend, holiday, term break). Picks the earliest day in
 * DAY_ORDER that has at least one session.
 */
const nextTeachingDay = computed<{
  day: DayKey;
  firstSession: ScheduleSession;
} | null>(() => {
  if (todaySessions.value.length > 0) return null;
  // Start from tomorrow's day-of-week and wrap.
  const dayIdx = new Date().getDay(); // 0 = Sun
  const order: DayKey[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  // Build a search order starting from tomorrow.
  const startIdx = dayIdx % 6;
  for (let i = 0; i < 6; i++) {
    const d = order[(startIdx + i) % 6];
    const list = grouped.value[d];
    if (list && list.length > 0) {
      return { day: d, firstSession: list[0] };
    }
  }
  return null;
});

const liveSession = computed<ScheduleSession | null>(() => {
  for (const s of todaySessions.value) {
    if (liveStatusFor(s).isLive) return s;
  }
  return null;
});

const nextSession = computed<ScheduleSession | null>(() => {
  for (const s of todaySessions.value) {
    if (liveStatusFor(s).isUpcoming) return s;
  }
  return null;
});

const todayDoneCount = computed(() => {
  // "Done" mirrors Flutter — attendance.filled = true means the sesi
  // was properly recorded.
  return todaySessions.value.filter((s) => {
    const att = summaryFor(s)?.attendance;
    return att?.filled === true;
  }).length;
});

const todayProgressPct = computed(() => {
  const total = todaySessions.value.length;
  if (total === 0) return 0;
  return Math.min(100, Math.round((todayDoneCount.value / total) * 100));
});

// ── Async state for AsyncView ──────────────────────────────────
const state = computed<AsyncState<ScheduleSession[]>>(() => {
  if (isLoading.value && sessions.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filteredSessions.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredSessions.value };
});

// ── Data loaders ───────────────────────────────────────────────
async function reload() {
  isLoading.value = true;
  error.value = null;
  try {
    // Wali-kelas mode → fetch the homeroom class's full week.
    // Mengajar mode → fetch the teacher's own week via /current.
    const list = activeHomeroomId.value
      ? await ScheduleService.classWeek(activeHomeroomId.value)
      : await ScheduleService.myWeek();
    const dayOrderMap: Record<string, number> = {
      mon: 1,
      tue: 2,
      wed: 3,
      thu: 4,
      fri: 5,
      sat: 6,
    };
    sessions.value = [...list].sort((a, b) => {
      const dCmp = (dayOrderMap[a.day] ?? 99) - (dayOrderMap[b.day] ?? 99);
      if (dCmp !== 0) return dCmp;
      return a.start_time.localeCompare(b.start_time);
    });

    // Load today's summary so action-tile sub-labels populate and the
    // Today banner can count "done" sessions.
    const tid = auth.teacherId ?? auth.user?.id;
    if (tid) {
      summaries.value = await ScheduleService.getDailySummary({
        teacher_id: tid,
      });
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadClasses() {
  try {
    classes.value = (await ClassroomService.list({ per_page: 100 })).items;
  } catch {
    // non-fatal — filter just shows empty
  }
}

onMounted(() => {
  reload();
  loadClasses();
  tickTimer = setInterval(() => (nowTick.value = Date.now()), 60_000);
});

onUnmounted(() => {
  if (tickTimer) clearInterval(tickTimer);
});

// Refetch the week when the user changes academic year via the chip.
useAcademicYearWatcher(() => reload());

watch(
  () => detail.value?.id,
  (newId) => {
    if (newId && (auth.teacherId || auth.user?.id)) {
      ScheduleService.getDailySummary({
        teacher_id: auth.teacherId ?? auth.user!.id,
      }).then((s) => {
        summaries.value = s;
      });
    }
  },
);

// Reload the week when the user flips the role chip.
watch(selectedRoleId, () => {
  reload();
});

// ── Detail modal helpers ───────────────────────────────────────
function summaryFor(s: ScheduleSession): SessionSummary | undefined {
  return summaries.value[sessionSummaryKey(s.class_id, s.subject_id)];
}

function attLabel(s: ScheduleSession): string {
  const att = summaryFor(s)?.attendance;
  if (att && att.filled) return `${att.hadir ?? 0}/${att.total ?? 0} Hadir`;
  return 'Belum diisi';
}

function actLabel(s: ScheduleSession): string {
  const a = summaryFor(s)?.class_activity;
  const c = a?.count ?? 0;
  return c > 0 ? `${c} kegiatan` : 'Belum ada kegiatan';
}

function matLabel(s: ScheduleSession): string {
  const m = summaryFor(s)?.material_progress;
  if (!m) return 'Belum ada data materi';
  return `${m.checked ?? 0}/${m.total ?? 0} bab ditandai`;
}

function periodeLabel(s: ScheduleSession): string {
  const parts: string[] = [];
  if (s.semester_name) parts.push(semesterLabel(s.semester_name));
  if (s.academic_year) parts.push(s.academic_year);
  return parts.join(' · ');
}

function formatDay(d?: string | null): string {
  if (!d) return '';
  const raw = d.toLowerCase();
  if (raw.startsWith('mon') || raw.startsWith('sen')) return t('common.monday');
  if (raw.startsWith('tue') || raw.startsWith('sel')) return t('common.tuesday');
  if (raw.startsWith('wed') || raw.startsWith('rab')) return t('common.wednesday');
  if (raw.startsWith('thu') || raw.startsWith('kam')) return t('common.thursday');
  if (raw.startsWith('fri') || raw.startsWith('jum')) return t('common.friday');
  if (raw.startsWith('sat') || raw.startsWith('sab')) return t('common.saturday');
  return d;
}

// ── Quick actions ──────────────────────────────────────────────
function gotoAttendance(target?: ScheduleSession) {
  const s = target ?? detail.value;
  if (!s) return;
  // Route directly into the input flow — tapping "Presensi" on a
  // schedule card means "take attendance for this session". When the
  // session is already recorded the input view's save action will
  // redirect to the detail view via router.replace().
  router.push({
    path: '/teacher/attendance/input',
    query: {
      from: 'quick-action',
      class_id: s.class_id,
      subject_id: s.subject_id,
      date: new Date().toISOString().slice(0, 10),
    },
  });
  detail.value = null;
}
function gotoActivity(target?: ScheduleSession) {
  const s = target ?? detail.value;
  if (!s) return;
  router.push({
    path: '/teacher/class-activity',
    query: {
      from: 'quick-action',
      class_id: s.class_id,
      subject_id: s.subject_id,
    },
  });
  detail.value = null;
}
function gotoLessonPlan() {
  if (!detail.value) return;
  router.push({
    path: '/teacher/lesson-plans',
    query: {
      from: 'quick-action',
      class_id: detail.value.class_id,
      subject_id: detail.value.subject_id,
    },
  });
  detail.value = null;
}
function gotoMaterial(target?: ScheduleSession) {
  const s = target ?? detail.value;
  if (!s) return;
  router.push({
    path: '/teacher/materials',
    query: {
      from: 'quick-action',
      subject_id: s.subject_id,
    },
  });
  detail.value = null;
}
function gotoGradeBook() {
  if (!detail.value) return;
  router.push({
    path: '/teacher/grade-book',
    query: {
      from: 'quick-action',
      class_id: detail.value.class_id,
      subject_id: detail.value.subject_id,
    },
  });
  detail.value = null;
}

function openLiveSession() {
  if (liveSession.value) detail.value = liveSession.value;
}

// ── Picker option labels ───────────────────────────────────────
const hariOptions = computed<{ key: 'all' | DayKey; label: string }[]>(() => [
  { key: 'all', label: t('teacher.schedule.allDays') },
  { key: 'mon', label: t('common.monday') },
  { key: 'tue', label: t('common.tuesday') },
  { key: 'wed', label: t('common.wednesday') },
  { key: 'thu', label: t('common.thursday') },
  { key: 'fri', label: t('common.friday') },
  { key: 'sat', label: t('common.saturday') },
]);

const activeHari = computed(
  () =>
    hariOptions.value.find((h) => h.key === dayFilter.value) ??
    hariOptions.value[0],
);
const activeClass = computed(() =>
  classes.value.find((c) => c.id === classFilter.value),
);

function pickHari(k: 'all' | DayKey) {
  dayFilter.value = k;
  showHariPicker.value = false;
}
function pickKelas(id: string) {
  classFilter.value = id;
  showKelasPicker.value = false;
}

// Wire fromQuickAction so quick-action navigations land on a sensible state.
onMounted(() => {
  if (fromQuickAction.value) {
    // no-op for now; quick-action lands on the default Kartu view
  }
});
</script>

<template>
  <div class="space-y-md">
    <!-- ── 1. Header ────────────────────────────────────────── -->
    <BrandPageHeader
      role="guru"
      :kicker="isWaliMode ? `Wali Kelas · ${activeHomeroom?.name ?? ''}` : 'Jadwal Mengajar · Realtime'"
      :title="isWaliMode ? `${t('teacher.schedule.thisWeek')} · ${activeHomeroom?.name ?? ''}` : t('teacher.schedule.thisWeek')"
      :meta="`${totalSessions} sesi · ${uniqueClasses} kelas · ${sessionsToday} sesi hari ini`"
      :live-dot="!isWaliMode"
    >
      <!-- Right-side action: view toggle (Kartu / Matrix) -->
      <div class="inline-flex gap-0.5 p-0.5 rounded-xl bg-white/20 border border-white/25 backdrop-blur-sm">
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="view === 'kartu' ? 'bg-white text-slate-900 shadow-sm' : 'text-white/90 hover:text-white'"
          @click="view = 'kartu'"
        >
          <NavIcon name="layers" :size="13" />{{ t('teacher.schedule.cards') }}
        </button>
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="view === 'matrix' ? 'bg-white text-slate-900 shadow-sm' : 'text-white/90 hover:text-white'"
          @click="view = 'matrix'"
        >
          <NavIcon name="layers" :size="13" />{{ t('teacher.schedule.matrix') }}
        </button>
      </div>

      <!-- Role chips sit inside the gradient header -->
      <template #role-toggle>
        <RoleToggleChipRow
          :roles="roleOptions"
          :selected-role-id="selectedRoleId"
          accent-color="#1B6FB8"
          @update:selected-role-id="(v) => (selectedRoleId = v)"
        />
      </template>
    </BrandPageHeader>

    <!-- ── 2. KPI strip ─────────────────────────────────────── -->
    <KpiStripCards :cards="kpiCards" />

    <!-- ── 3. Filter toolbar ────────────────────────────────── -->
    <!-- Mode (Mengajar / Wali) lives in the brand header above —
         this row only carries day + class + semester + search. -->
    <PageFilterToolbar
      :search="searchQuery"
      :search-placeholder="t('teacher.schedule.searchPlaceholder')"
      @update:search="(v) => (searchQuery = v)"
    >
      <template #chips>
        <AppFilterChip
          :label="t('common.day')"
          :value="activeHari.label"
          icon-name="calendar"
          tone="amber"
          @click="showHariPicker = true"
        />
        <AppFilterChip
          v-if="!isWaliMode"
          :label="t('common.class')"
          :value="activeClass?.name ?? t('teacher.schedule.allClasses')"
          icon-name="layers"
          tone="violet"
          @click="showKelasPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- ── 4. Today banner ──────────────────────────────────── -->
    <!-- Active teaching day with sessions today -->
    <section
      v-if="todaySessions.length > 0"
      class="rounded-2xl p-4 sm:p-5 text-white flex items-center gap-4"
      style="background: linear-gradient(120deg, #0F2A45 0%, #1B6FB8 100%); box-shadow: 0 10px 30px rgba(27,111,184,0.18);"
    >
      <div class="w-14 h-14 rounded-2xl bg-white/15 grid place-items-center flex-shrink-0">
        <NavIcon name="calendar" :size="26" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-[10px] font-bold tracking-widest text-white/80 uppercase">
          {{ t('common.today') }} · {{ todayLong }}
        </p>
        <p class="text-base sm:text-lg font-black mt-1 leading-tight">
          {{ todaySessions.length }} {{ t('common.sessions') }}
          <span v-if="liveSession">· 1 {{ t('common.inProgress') }}</span>
          <span v-else-if="nextSession">· {{ todayDoneCount }} {{ t('common.completed') }}</span>
          <span v-else>· {{ t('teacher.schedule.dayCompleted') }}</span>
        </p>
        <div class="text-[12px] text-white/85 mt-1 flex items-center gap-1.5 flex-wrap">
          <span>{{ t('common.completed') }}</span>
          <span class="bg-white/18 px-2 py-0.5 rounded-full text-white font-bold">
            {{ todayDoneCount }} / {{ todaySessions.length }}
          </span>
          <template v-if="nextSession">
            · {{ t('common.next') }}
            <span class="text-white font-bold">{{ nextSession.subject_name }} {{ nextSession.class_name }}</span>
            {{ t('common.at') }}
            <span class="text-white font-bold">{{ nextSession.start_time }}</span>
          </template>
        </div>
        <div class="mt-2 h-1.5 bg-white/22 rounded-full overflow-hidden max-w-[360px]">
          <div
            class="h-full bg-emerald-400 rounded-full transition-all"
            :style="{ width: `${todayProgressPct}%` }"
          ></div>
        </div>
      </div>
      <button
        v-if="liveSession"
        type="button"
        class="px-3.5 py-2 bg-white/18 hover:bg-white/25 border border-white/25 rounded-xl text-white text-[12px] font-bold inline-flex items-center gap-1.5 flex-shrink-0 transition-colors"
        @click="openLiveSession"
      >
        <NavIcon name="check-square" :size="13" />
        {{ t('teacher.schedule.openActiveSession') }}
      </button>
    </section>

    <!-- Off-day fallback (Sunday / holiday) — surface the next teaching day -->
    <section
      v-else-if="nextTeachingDay"
      class="rounded-2xl p-4 bg-slate-50 border border-slate-200 flex items-center gap-3"
    >
      <div class="w-10 h-10 rounded-xl bg-white border border-slate-200 text-slate-500 grid place-items-center flex-shrink-0">
        <NavIcon name="calendar" :size="18" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-[12.5px] font-bold text-slate-700">
          {{ t('teacher.schedule.noTeachingSessions') }} · {{ todayLong }}
        </p>
        <p class="text-[11.5px] text-slate-500 mt-0.5">
          {{ t('teacher.schedule.nextSession') }}
          <span class="font-bold text-brand-cobalt">
            {{ DAY_LABELS[nextTeachingDay.day] }} {{ nextTeachingDay.firstSession.start_time }}
          </span>
          · {{ nextTeachingDay.firstSession.subject_name }} {{ nextTeachingDay.firstSession.class_name }}
        </p>
      </div>
    </section>

    <!-- ── 5/6. Body ────────────────────────────────────────── -->
    <AsyncView
      :state="state"
      :empty-title="t('teacher.schedule.noScheduleYet')"
      :empty-description="t('teacher.schedule.noScheduleForFilter')"
      @retry="reload"
    >
      <template #default>

        <!-- ── 5. Kartu view ─────────────────────────────── -->
        <section
          v-if="view === 'kartu'"
          class="grid grid-cols-1 lg:grid-cols-2 gap-4"
        >
          <div
            v-for="d in DAY_ORDER.filter((day) => (grouped[day]?.length ?? 0) > 0)"
            :key="d"
          >
            <div class="flex items-center gap-2 px-1 pb-2">
              <NavIcon
                :name="d === todayDay ? 'check-circle' : 'calendar'"
                :size="15"
                :style="{ color: dayColor(d) }"
              />
              <span
                class="text-[13px] font-bold"
                :style="{ color: dayColor(d) }"
              >
                {{ DAY_LABELS[d] }}
              </span>
              <span
                v-if="d === todayDay"
                class="text-[10px] font-bold px-1.5 py-0.5 rounded"
                :style="{ background: `${dayColor(d)}22`, color: dayColor(d) }"
              >
                {{ t('common.today') }}
              </span>
              <div
                class="flex-1 h-px"
                :style="{ background: `${dayColor(d)}40` }"
              ></div>
              <span
                class="text-[10px] font-bold px-2 py-0.5 rounded-full"
                :style="{ background: `${dayColor(d)}1a`, color: dayColor(d) }"
              >
                {{ grouped[d]?.length ?? 0 }} {{ t('common.sessions') }}
              </span>
            </div>

            <button
              v-for="s in grouped[d]"
              :key="s.id"
              type="button"
              class="w-full text-left bg-white rounded-xl p-3 mb-2 transition-all hover:shadow-md focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
              :class="[
                liveStatusFor(s).isLive
                  ? 'border-2 border-red-500 shadow-lg shadow-red-100'
                  : 'border border-slate-200',
                liveStatusFor(s).isEnded ? 'opacity-70' : '',
              ]"
              @click="detail = s"
            >
              <div class="flex items-center gap-3">
                <div
                  class="w-10 h-10 rounded-xl grid place-items-center text-white flex-shrink-0"
                  :style="{
                    background: liveStatusFor(s).isEnded ? '#94a3b8' : dayColor(d),
                    boxShadow: liveStatusFor(s).isEnded
                      ? 'none'
                      : `0 4px 10px ${dayColor(d)}40`,
                  }"
                >
                  <div class="text-center leading-none">
                    <div class="text-[15px] font-black">{{ s.hour_index ?? '–' }}</div>
                    <div class="text-[7px] font-bold tracking-widest opacity-90 mt-0.5">{{ t('teacher.schedule.hour') }}</div>
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-1.5">
                    <span
                      class="text-[13px] font-black flex-1 truncate"
                      :class="liveStatusFor(s).isEnded ? 'text-slate-500 line-through' : 'text-slate-900'"
                    >
                      {{ s.subject_name }}
                    </span>
                    <span class="bg-brand-cobalt/10 text-brand-cobalt px-1.5 py-0.5 rounded-full text-[10px] font-bold">
                      {{ s.class_name }}
                    </span>
                  </div>
                  <div class="flex items-center gap-1.5 mt-1 text-[11px] text-slate-500">
                    <NavIcon name="calendar" :size="11" />
                    <span>{{ s.start_time }} – {{ s.end_time }}</span>
                    <template v-if="s.room">
                      <NavIcon name="home" :size="11" class="ml-1" />
                      <span>{{ s.room }}</span>
                    </template>
                  </div>
                </div>
                <span
                  v-if="liveStatusFor(s).isLive"
                  class="inline-flex items-center gap-1 bg-red-500 text-white px-2 py-0.5 rounded-full text-[9.5px] font-bold tracking-wider flex-shrink-0"
                >
                  <span class="w-1.5 h-1.5 rounded-full bg-white animate-pulse"></span>
                  {{ t('common.live') }}
                </span>
                <span
                  v-else-if="nextSession?.id === s.id"
                  class="bg-brand-cobalt text-white px-2 py-0.5 rounded-full text-[9.5px] font-bold tracking-wider flex-shrink-0"
                >
                  {{ t('common.nextBadge') }}
                </span>
                <span
                  v-else-if="liveStatusFor(s).isEnded"
                  class="bg-slate-200 text-slate-600 px-2 py-0.5 rounded-full text-[9.5px] font-bold tracking-wider flex-shrink-0"
                >
                  {{ t('common.completedBadge') }}
                </span>
              </div>

              <!-- Action row — only on today's sessions -->
              <div
                v-if="s.day === todayDay && !liveStatusFor(s).isEnded"
                class="mt-2.5 pt-2.5 border-t border-slate-100 grid grid-cols-3 gap-1.5"
              >
                <button
                  type="button"
                  class="inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg text-[11px] font-bold transition-colors"
                  :class="
                    summaryFor(s)?.attendance?.filled
                      ? 'border border-emerald-500 bg-emerald-50 text-emerald-700'
                      : 'border border-slate-200 bg-white text-slate-600 hover:border-emerald-300'
                  "
                  @click.stop="gotoAttendance(s)"
                >
                  <NavIcon name="check-square" :size="12" />{{ t('common.attendance') }}
                </button>
                <button
                  type="button"
                  class="inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg text-[11px] font-bold transition-colors"
                  :class="
                    (summaryFor(s)?.class_activity?.count ?? 0) > 0
                      ? 'border border-amber-500 bg-amber-50 text-amber-700'
                      : 'border border-slate-200 bg-white text-slate-600 hover:border-amber-300'
                  "
                  @click.stop="gotoActivity(s)"
                >
                  <NavIcon name="activity" :size="12" />{{ t('common.activity') }}
                </button>
                <button
                  type="button"
                  class="inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg text-[11px] font-bold transition-colors border border-slate-200 bg-white text-slate-600 hover:border-brand-cobalt"
                  @click.stop="gotoMaterial(s)"
                >
                  <NavIcon name="book" :size="12" />{{ t('common.materials') }}
                </button>
              </div>
            </button>
          </div>
        </section>

        <!-- ── 6. Matrix view ────────────────────────────── -->
        <section
          v-else
          class="bg-white border border-slate-200 rounded-2xl p-2 overflow-x-auto"
        >
          <div class="min-w-[800px]">
            <div
              class="grid gap-px bg-slate-200 rounded-xl overflow-hidden"
              style="grid-template-columns: 64px repeat(6, 1fr);"
            >
              <!-- Header row -->
              <div class="bg-slate-50 py-3 grid place-items-center">
                <span class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">{{ t('teacher.schedule.hour') }}</span>
              </div>
              <div
                v-for="d in DAY_ORDER"
                :key="`head-${d}`"
                class="py-2.5 text-center"
                :style="d === todayDay
                  ? `background: ${dayColor(d)}0d; box-shadow: inset 0 -2px 0 ${dayColor(d)};`
                  : 'background: #fff;'"
              >
                <p class="text-[11.5px] font-bold m-0" :style="{ color: dayColor(d) }">
                  {{ DAY_LABELS[d] }}
                </p>
                <p
                  v-if="d === todayDay"
                  class="text-[10px] font-bold mt-0.5"
                  :style="{ color: dayColor(d) }"
                >
                  {{ t('common.today') }}
                </p>
                <p v-else class="text-[10px] text-slate-400 mt-0.5">
                  {{ grouped[d]?.length ?? 0 }} {{ t('common.sessions') }}
                </p>
              </div>

              <!-- Body rows -->
              <template v-for="(slot, idx) in hourSlots" :key="`row-${idx}`">
                <div class="bg-slate-50 py-2.5 grid place-items-center">
                  <div class="text-center leading-tight">
                    <p class="text-[14px] font-black text-slate-900">{{ slot.hour ?? idx + 1 }}</p>
                    <p class="text-[9px] text-slate-400 mt-0.5">{{ slot.start }}</p>
                  </div>
                </div>
                <template v-for="d in DAY_ORDER" :key="`cell-${d}-${idx}`">
                  <button
                    v-if="findCell(d, slot.start)"
                    type="button"
                    class="text-left transition-all"
                    :class="[
                      liveStatusFor(findCell(d, slot.start)!).isLive
                        ? 'border-2 border-red-500 rounded-md shadow-sm shadow-red-100'
                        : nextSession?.id === findCell(d, slot.start)?.id
                          ? 'border border-dashed border-brand-cobalt rounded-md'
                          : 'border border-transparent',
                    ]"
                    :style="d === todayDay
                      ? 'background: rgba(79,70,229,0.04); padding: 8px;'
                      : 'background: #fff; padding: 8px;'"
                    @click="detail = findCell(d, slot.start)"
                  >
                    <span
                      v-if="liveStatusFor(findCell(d, slot.start)!).isLive"
                      class="inline-flex items-center gap-1 bg-red-500 text-white px-1.5 py-0.5 rounded text-[8.5px] font-bold tracking-wider mb-1"
                    >
                      <span class="w-1 h-1 rounded-full bg-white animate-pulse"></span>{{ t('common.live') }}
                    </span>
                    <span
                      v-else-if="nextSession?.id === findCell(d, slot.start)?.id"
                      class="inline-block bg-brand-cobalt text-white px-1.5 py-0.5 rounded text-[8.5px] font-bold tracking-wider mb-1"
                    >{{ t('common.nextBadge') }}</span>
                    <p class="text-[11px] font-bold text-slate-900 leading-tight truncate">
                      {{ findCell(d, slot.start)!.subject_name }}
                    </p>
                    <div class="flex items-center gap-1.5 mt-1">
                      <span class="bg-brand-cobalt/10 text-brand-cobalt px-1.5 py-0.5 rounded text-[9.5px] font-bold">
                        {{ findCell(d, slot.start)!.class_name }}
                      </span>
                      <span
                        v-if="findCell(d, slot.start)!.room"
                        class="text-[9.5px] text-slate-400 truncate"
                      >{{ findCell(d, slot.start)!.room }}</span>
                    </div>
                  </button>
                  <div
                    v-else
                    :style="d === todayDay ? 'background: rgba(79,70,229,0.04);' : 'background: #fff;'"
                  ></div>
                </template>
              </template>
            </div>

            <div class="flex items-center gap-4 px-2 pt-3 text-[11px] text-slate-500 flex-wrap">
              <span class="inline-flex items-center gap-1.5">
                <span class="w-2.5 h-2.5 rounded-sm bg-red-50 border-[1.5px] border-red-500"></span>
                {{ t('common.inProgress') }}
              </span>
              <span class="inline-flex items-center gap-1.5">
                <span class="w-2.5 h-2.5 rounded-sm bg-brand-cobalt/5 border border-dashed border-brand-cobalt"></span>
                {{ t('common.next') }}
              </span>
              <span class="inline-flex items-center gap-1.5">
                <span class="w-2.5 h-2.5 rounded-sm" style="background: rgba(79,70,229,0.04);"></span>
                {{ t('teacher.schedule.todayColumn') }}
              </span>
              <span class="flex-1"></span>
              <span class="text-slate-400">{{ t('teacher.schedule.clickForDetails') }}</span>
            </div>
          </div>
        </section>
      </template>
    </AsyncView>

    <!-- ── Hari picker ──────────────────────────────────────── -->
    <Modal v-if="showHariPicker" :title="t('teacher.schedule.selectDay')" @close="showHariPicker = false">
      <ul class="space-y-1 max-h-[360px] overflow-y-auto">
        <li v-for="h in hariOptions" :key="h.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': h.key === dayFilter }"
            @click="pickHari(h.key)"
          >
            <span>{{ h.label }}</span>
            <span v-if="h.key === dayFilter" class="text-[10px] font-bold uppercase tracking-wider">{{ t('common.active') }}</span>
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Kelas picker ─────────────────────────────────────── -->
    <Modal v-if="showKelasPicker" :title="t('teacher.schedule.selectClass')" @close="showKelasPicker = false">
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': classFilter === '' }"
            @click="pickKelas('')"
          >
            {{ t('teacher.schedule.allClasses') }}
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': c.id === classFilter }"
            @click="pickKelas(c.id)"
          >
            <span>{{ c.name }}</span>
            <span v-if="c.student_count" class="text-[10px] text-slate-400">{{ c.student_count }} {{ t('common.students') }}</span>
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── 7. Session detail modal (mirrors Flutter Frame E) ── -->
    <Teleport v-if="detail" to="body">
      <div
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/40 px-md py-md sm:p-lg"
        @click.self="detail = null"
      >
        <div
          class="w-full max-w-2xl bg-white rounded-2xl shadow-2xl max-h-[92vh] flex flex-col"
          role="dialog"
          aria-modal="true"
        >
          <header class="px-5 py-4 border-b border-slate-100 flex items-start gap-3">
            <div
              class="w-14 h-14 rounded-2xl text-white flex flex-col items-center justify-center flex-shrink-0 shadow-md"
              style="background: linear-gradient(135deg, #0F2A45 0%, #1B6FB8 100%);"
            >
              <p class="text-[20px] font-black leading-none">{{ detail.hour_index ?? '-' }}</p>
              <p class="text-[8px] font-bold tracking-widest mt-0.5 opacity-90">{{ t('teacher.schedule.hour') }}</p>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[10px] font-bold text-brand-cobalt uppercase tracking-widest mb-0.5">
                {{ t('teacher.schedule.sessionDetails') }} · {{ formatDay(detail.day_name ?? detail.day) }}
              </p>
              <h2 class="text-base font-black text-slate-900 leading-tight">
                {{ detail.subject_name }}
              </h2>
              <p class="text-[11px] text-slate-500 mt-0.5">
                <span class="font-bold text-brand-cobalt">{{ detail.class_name }}</span>
                <span> · {{ detail.start_time }} – {{ detail.end_time }}</span>
                <span v-if="detail.room"> · {{ detail.room }}</span>
              </p>
            </div>
            <button
              type="button"
              class="text-slate-400 hover:text-slate-700 p-1 -m-1"
              aria-label="Tutup"
              @click="detail = null"
            >
              <NavIcon name="x" :size="18" />
            </button>
          </header>

          <div class="flex-1 overflow-y-auto px-5 py-4 space-y-md">
            <template v-if="liveStatusFor(detail).isLive">
              <div class="bg-red-50 border border-red-200 rounded-xl px-3 py-2.5 flex items-center gap-2">
                <span class="w-2 h-2 rounded-full bg-red-500 animate-pulse"></span>
                <p class="text-[12px] font-bold text-red-700">
                  Sedang berlangsung — sisa {{ liveStatusFor(detail).remainingMin }} menit
                </p>
              </div>
            </template>
            <template v-else-if="liveStatusFor(detail).isUpcoming && liveStatusFor(detail).remainingMin < 240">
              <div class="bg-brand-cobalt/5 border border-brand-cobalt/20 rounded-xl px-3 py-2.5 flex items-center gap-2">
                <NavIcon name="calendar" :size="13" class="text-brand-cobalt" />
                <p class="text-[12px] font-bold text-brand-cobalt">
                  Akan dimulai dalam {{ liveStatusFor(detail).remainingMin }} menit
                </p>
              </div>
            </template>
            <template v-else-if="liveStatusFor(detail).isEnded">
              <div class="bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 flex items-center gap-2">
                <NavIcon name="check-circle" :size="13" class="text-slate-500" />
                <p class="text-[12px] font-bold text-slate-600">Sesi sudah selesai</p>
              </div>
            </template>

            <section>
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">{{ t('teacher.schedule.quickActions') }}</p>
              <div class="grid grid-cols-2 gap-2">
                <button type="button" class="text-left p-3.5 rounded-xl border border-slate-200 bg-white hover:border-emerald-300 hover:shadow-sm transition-all" @click="gotoAttendance()">
                  <div class="w-9 h-9 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center mb-2">
                    <NavIcon name="check-square" :size="16" />
                  </div>
                  <p class="text-[13px] font-black text-slate-900 leading-tight">{{ t('teacher.schedule.takeAttendance') }}</p>
                  <p class="text-[10.5px] font-medium text-slate-500 mt-0.5 leading-snug">{{ attLabel(detail) }}</p>
                </button>
                <button type="button" class="text-left p-3.5 rounded-xl border border-slate-200 bg-white hover:border-amber-300 hover:shadow-sm transition-all" @click="gotoActivity()">
                  <div class="w-9 h-9 rounded-xl bg-amber-100 text-amber-700 grid place-items-center mb-2">
                    <NavIcon name="activity" :size="16" />
                  </div>
                  <p class="text-[13px] font-black text-slate-900 leading-tight">{{ t('teacher.schedule.classActivity') }}</p>
                  <p class="text-[10.5px] font-medium text-slate-500 mt-0.5 leading-snug">{{ actLabel(detail) }}</p>
                </button>
                <button type="button" class="text-left p-3.5 rounded-xl border border-slate-200 bg-white hover:border-brand-cobalt/30 hover:shadow-sm transition-all" @click="gotoMaterial()">
                  <div class="w-9 h-9 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center mb-2">
                    <NavIcon name="book" :size="16" />
                  </div>
                  <p class="text-[13px] font-black text-slate-900 leading-tight">{{ t('teacher.schedule.materialsAndLessonPlan') }}</p>
                  <p class="text-[10.5px] font-medium text-slate-500 mt-0.5 leading-snug">{{ matLabel(detail) }}</p>
                </button>
                <button type="button" class="text-left p-3.5 rounded-xl border border-slate-200 bg-white hover:border-violet-300 hover:shadow-sm transition-all" @click="gotoGradeBook">
                  <div class="w-9 h-9 rounded-xl bg-violet-100 text-violet-700 grid place-items-center mb-2">
                    <NavIcon name="bar-chart" :size="16" />
                  </div>
                  <p class="text-[13px] font-black text-slate-900 leading-tight">{{ t('teacher.schedule.gradeBook') }}</p>
                  <p class="text-[10.5px] font-medium text-slate-500 mt-0.5 leading-snug">{{ t('teacher.schedule.viewEnterGrades') }}</p>
                </button>
              </div>

              <button type="button" class="mt-2 w-full text-center p-2.5 rounded-xl border border-dashed border-brand-cobalt/30 text-brand-cobalt text-[11.5px] font-bold hover:bg-brand-cobalt/5" @click="gotoLessonPlan">
                <NavIcon name="file-text" :size="13" class="inline-block mr-1.5 -mt-0.5" />
                {{ t('teacher.schedule.viewLessonPlan') }}
              </button>
            </section>

            <section>
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">{{ t('teacher.schedule.sessionDetails') }}</p>
              <div class="space-y-2">
                <div class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl p-3">
                  <span class="w-9 h-9 rounded-lg bg-brand-cobalt/8 text-brand-cobalt grid place-items-center flex-shrink-0">
                    <NavIcon name="calendar" :size="14" />
                  </span>
                  <p class="text-[12.5px] font-bold text-slate-800 flex-1">{{ t('common.time') }}</p>
                  <p class="text-[12.5px] font-bold text-brand-cobalt">{{ detail.start_time }} – {{ detail.end_time }}</p>
                </div>
                <div class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl p-3">
                  <span class="w-9 h-9 rounded-lg bg-brand-cobalt/8 text-brand-cobalt grid place-items-center flex-shrink-0">
                    <NavIcon name="layers" :size="14" />
                  </span>
                  <p class="text-[12.5px] font-bold text-slate-800 flex-1">{{ t('common.day') }}</p>
                  <p class="text-[12.5px] font-bold text-brand-cobalt">{{ formatDay(detail.day_name ?? detail.day) }}</p>
                </div>
                <div v-if="detail.room" class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl p-3">
                  <span class="w-9 h-9 rounded-lg bg-brand-cobalt/8 text-brand-cobalt grid place-items-center flex-shrink-0">
                    <NavIcon name="home" :size="14" />
                  </span>
                  <p class="text-[12.5px] font-bold text-slate-800 flex-1">{{ t('common.room') }}</p>
                  <p class="text-[12.5px] font-bold text-brand-cobalt">{{ detail.room }}</p>
                </div>
                <div v-if="periodeLabel(detail)" class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl p-3">
                  <span class="w-9 h-9 rounded-lg bg-brand-cobalt/8 text-brand-cobalt grid place-items-center flex-shrink-0">
                    <NavIcon name="book" :size="14" />
                  </span>
                  <p class="text-[12.5px] font-bold text-slate-800 flex-1">{{ t('common.period') }}</p>
                  <p class="text-[12.5px] font-bold text-brand-cobalt text-right">{{ periodeLabel(detail) }}</p>
                </div>
                <div v-if="detail.teacher_name" class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl p-3">
                  <span class="w-9 h-9 rounded-lg bg-brand-cobalt/8 text-brand-cobalt grid place-items-center flex-shrink-0">
                    <NavIcon name="users" :size="14" />
                  </span>
                  <p class="text-[12.5px] font-bold text-slate-800 flex-1">{{ t('common.teacher') }}</p>
                  <p class="text-[12.5px] font-bold text-brand-cobalt truncate ml-2">{{ detail.teacher_name }}</p>
                </div>
              </div>
            </section>
          </div>

          <footer class="px-5 py-3 border-t border-slate-100 bg-slate-50 rounded-b-2xl flex items-center gap-2">
            <Button variant="secondary" size="sm" @click="detail = null">{{ t('common.close') }}</Button>
            <span class="flex-1"></span>
            <Button variant="primary" size="sm" @click="gotoAttendance()">
              <NavIcon name="check-square" :size="13" />
              {{ t('teacher.schedule.startSession') }}
            </Button>
          </footer>
        </div>
      </div>
    </Teleport>
  </div>
</template>
