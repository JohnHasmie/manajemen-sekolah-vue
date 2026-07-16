<!--
  TutorSessionsView — the tutor's "Session Mengajar" dashboard. Rebuilt to
  mirror the school-teacher page treatment + the Flutter side:
  hero greeting, KPI strip (sessions/hours/attendance/groups), view
  toggle (List/Calendar), and chip filters (range + group + status).

  Calendar view is a month grid with session-count dots per day; tap
  a day to pin the per-day session strip below it.

  Backend:
    - GET /tutoring/schedule?tutor_user_id=&from=&to= (existing)
    - GET /tutoring/tutor-stats (new — KPI strip)
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import { formatDateShort, formatTime } from '@/lib/format';
import type {
  TutoringSession,
  TutoringTutorStats,
} from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type RangeFilter = 'all' | 'today' | 'thisWeek' | 'upcoming' | 'past';
type ViewMode = 'list' | 'calendar';

// '' = no filter (all).
const ALL = '' as const;

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();

const loading = ref(true);
const error = ref<string | null>(null);
const sessions = ref<TutoringSession[]>([]);
const stats = ref<TutoringTutorStats | null>(null);

const view = ref<ViewMode>('list');
const range = ref<RangeFilter>('all');
const groupId = ref<string>(ALL);
const statusFilter = ref<string>(ALL);

// Calendar focus — initialized lazily so the user sees "today" on first
// open. The month is the calendar month being shown.
const focusedDay = ref<Date>(new Date());
const focusedMonth = ref<{ y: number; m: number }>({
  y: new Date().getFullYear(),
  m: new Date().getMonth(),
});

// ── load ────────────────────────────────────────────────────────────

async function load() {
  const tutorId = auth.user?.id;
  if (!tutorId) {
    error.value = t('tutoring.sessions.cannotIdentify');
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = null;
  try {
    const now = new Date();
    const from = new Date(now.getTime() - 14 * 24 * 3600 * 1000);
    const to = new Date(now.getTime() + 28 * 24 * 3600 * 1000);
    const [list, st] = await Promise.all([
      TutoringService.getTutorSessions(tutorId, from, to),
      TutoringService.getTutorStats().catch(() => null),
    ]);
    sessions.value = list.sort((a, b) => {
      const ad = a.scheduled_at ? new Date(a.scheduled_at).getTime() : 0;
      const bd = b.scheduled_at ? new Date(b.scheduled_at).getTime() : 0;
      return ad - bd;
    });
    stats.value = st;
  } catch (e) {
    error.value =
      e instanceof Error ? e.message : t('tutoring.sessions.loadFailed');
  } finally {
    loading.value = false;
  }
}

onMounted(load);

// ── derived ─────────────────────────────────────────────────────────

/** distinct (groupId, groupName) pairs that appear in the loaded data,
 *  so the group filter never has stale options. */
const groupOptions = computed(() => {
  const seen = new Map<string, string>();
  for (const s of sessions.value) {
    const gid = s.group_id ?? '';
    const name = s.group?.name;
    if (gid && name && !seen.has(gid)) seen.set(gid, name);
  }
  return [
    { value: ALL, label: t('tutoring.sessions.filterAllGroups') },
    ...[...seen.entries()].map(([v, l]) => ({ value: v, label: l })),
  ];
});

const filtered = computed(() => {
  const now = new Date();
  const todayStart = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
  );
  const todayEnd = new Date(todayStart.getTime() + 24 * 3600 * 1000);
  // Monday-anchored week (matches Indonesia locale convention).
  const weekday = (todayStart.getDay() + 6) % 7; // 0=Mon, 6=Sun
  const weekStart = new Date(todayStart.getTime() - weekday * 24 * 3600 * 1000);
  const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 3600 * 1000);

  return sessions.value.filter((s) => {
    if (groupId.value && s.group_id !== groupId.value) return false;
    if (statusFilter.value && s.status !== statusFilter.value) return false;
    if (!s.scheduled_at && range.value !== 'all') return false;
    if (s.scheduled_at) {
      const d = new Date(s.scheduled_at);
      switch (range.value) {
        case 'all':
          break;
        case 'today':
          if (d < todayStart || d >= todayEnd) return false;
          break;
        case 'thisWeek':
          if (d < weekStart || d >= weekEnd) return false;
          break;
        case 'upcoming':
          if (d <= now) return false;
          break;
        case 'past':
          if (d >= now) return false;
          break;
      }
    }
    return true;
  });
});

/** Bucket all (unfiltered) sessions by yyyy-mm-dd for O(1) day lookup
 *  inside the calendar grid. Calendar dots always reflect the full
 *  load so chip filters don't make the grid look empty. */
const sessionsByDay = computed(() => {
  const map = new Map<string, TutoringSession[]>();
  for (const s of sessions.value) {
    if (!s.scheduled_at) continue;
    const d = new Date(s.scheduled_at);
    const key = dayKey(d);
    const arr = map.get(key) ?? [];
    arr.push(s);
    map.set(key, arr);
  }
  return map;
});

const focusedDaySessions = computed(() =>
  sessionsByDay.value.get(dayKey(focusedDay.value)) ?? [],
);

// ── helpers ─────────────────────────────────────────────────────────

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

function hoursLabel(h: number | undefined | null): string {
  if (h == null) return '0h';
  return h === Math.round(h) ? `${h}h` : `${h.toFixed(1)}h`;
}

const MONTHS_ID = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const DAYS_ID = [
  'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu',
];

function monthLabel(y: number, m: number): string {
  return `${MONTHS_ID[m]} ${y}`;
}

function focusedDayLabel(d: Date): string {
  return `${DAYS_ID[d.getDay()]}, ${d.getDate()} ${MONTHS_ID[d.getMonth()]} ${d.getFullYear()}`;
}

/** Build the cell grid for the focused month — leading blanks first,
 *  then 1..N day numbers, padded to a full row of 7 columns. */
const monthCells = computed(() => {
  const { y, m } = focusedMonth.value;
  const first = new Date(y, m, 1);
  // Monday = 0, Sunday = 6 (locale-id convention).
  const lead = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(y, m + 1, 0).getDate();
  const totalCells = Math.ceil((lead + daysInMonth) / 7) * 7;
  const cells: ({ day: number; date: Date } | null)[] = [];
  for (let i = 0; i < totalCells; i++) {
    const dayNum = i - lead + 1;
    if (dayNum < 1 || dayNum > daysInMonth) cells.push(null);
    else cells.push({ day: dayNum, date: new Date(y, m, dayNum) });
  }
  return cells;
});

function prevMonth() {
  const { y, m } = focusedMonth.value;
  focusedMonth.value = m === 0 ? { y: y - 1, m: 11 } : { y, m: m - 1 };
}
function nextMonth() {
  const { y, m } = focusedMonth.value;
  focusedMonth.value = m === 11 ? { y: y + 1, m: 0 } : { y, m: m + 1 };
}

function isToday(d: Date): boolean {
  const t = new Date();
  return d.getFullYear() === t.getFullYear() &&
    d.getMonth() === t.getMonth() &&
    d.getDate() === t.getDate();
}
function isFocused(d: Date): boolean {
  const f = focusedDay.value;
  return d.getFullYear() === f.getFullYear() &&
    d.getMonth() === f.getMonth() &&
    d.getDate() === f.getDate();
}

function openAttendance(s: TutoringSession) {
  if (s.status === 'CANCELLED') return;
  router.push({
    name: 'teacher.tutoring.attendance',
    params: { sessionId: s.id },
    query: {
      groupId: s.group_id,
      title: s.scheduled_at
        ? formatDateShort(s.scheduled_at)
        : t('tutoring.attendance.title'),
    },
  });
}

// Reset focused day if it falls outside the visible month after nav.
watch(focusedMonth, ({ y, m }) => {
  const f = focusedDay.value;
  if (f.getFullYear() !== y || f.getMonth() !== m) {
    focusedDay.value = new Date(y, m, 1);
  }
});

// ── filter pickers (school-pattern: AppFilterChip + modal) ──────────

const RANGE_OPTIONS = computed<{ key: RangeFilter; label: string }[]>(() => [
  { key: 'all', label: t('tutoring.sessions.filterAll') },
  { key: 'today', label: t('tutoring.sessions.filterToday') },
  { key: 'thisWeek', label: t('tutoring.sessions.filterThisWeek') },
  { key: 'upcoming', label: t('tutoring.sessions.filterUpcoming') },
  { key: 'past', label: t('tutoring.sessions.filterPast') },
]);
const STATUS_OPTIONS = computed(() => [
  { value: '' as string, label: t('tutoring.sessions.filterAll') },
  { value: 'SCHEDULED' as string, label: t('tutoring.sessions.filterScheduled') },
  { value: 'DONE' as string, label: t('tutoring.sessions.filterDone') },
  { value: 'CANCELLED' as string, label: t('tutoring.sessions.filterCancelled') },
]);
const activeRangeLabel = computed(
  () => RANGE_OPTIONS.value.find((o) => o.key === range.value)?.label ?? t('tutor.bimbel.sessions.filter_all_fallback'),
);
const activeStatusLabel = computed(
  () => STATUS_OPTIONS.value.find((o) => o.value === statusFilter.value)?.label ?? t('tutor.bimbel.sessions.filter_all_fallback'),
);
const activeGroupLabel = computed(
  () => groupOptions.value.find((o) => o.value === groupId.value)?.label ?? t('tutor.bimbel.sessions.filter_all_groups'),
);
const showRangePicker = ref(false);
const showStatusPicker = ref(false);
const showGroupPicker = ref(false);

function pickRange(k: RangeFilter) {
  range.value = k;
  showRangePicker.value = false;
}
function pickStatus(v: string) {
  statusFilter.value = v;
  showStatusPicker.value = false;
}
function pickGroup(v: string) {
  groupId.value = v;
  showGroupPicker.value = false;
}

// KPI cards for the strip — same data as before, KpiCard shape now.
const kpiCards = computed<KpiCard[]>(() => {
  const s = stats.value;
  if (!s) return [];
  return [
    {
      icon: 'calendar',
      label: t('tutoring.sessions.kpiSessionsWeek'),
      value: s.sessions_this_week,
      suffix:
        s.sessions_today > 0
          ? `${s.sessions_today} ${t('tutoring.sessions.kpiHintToday')}`
          : undefined,
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'clock',
      label: t('tutoring.sessions.kpiHoursWeek'),
      value: hoursLabel(s.hours_this_week),
      tone: 'violet',
    },
    {
      icon: 'check-circle',
      label: t('tutoring.sessions.kpiAttendance'),
      value: s.attendance_rate == null ? '–' : `${s.attendance_rate}%`,
      tone: 'green',
    },
    {
      icon: 'users',
      label: t('tutoring.sessions.kpiGroups'),
      value: s.groups,
      suffix:
        s.students > 0
          ? `${s.students} ${t('tutoring.sessions.kpiStudents')}`
          : undefined,
      tone: 'amber',
    },
  ];
});
</script>

<template>
  <div class="space-y-md pb-12">
    <TutorHomeHero
      :greeting="t('tutor.bimbel.sessions.greeting')"
      :title="t('tutoring.sessions.title')"
      :subtitle="auth.user?.name ? t('tutor.bimbel.sessions.subtitle_hello', { name: auth.user.name }) : undefined"
      :stats="[]"
    />
    <div class="flex justify-end -mt-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-tutoring-accent text-white text-[13px] font-bold hover:opacity-90"
        @click="router.push({ name: 'teacher.tutoring.session-create' })"
      >
        <NavIcon name="plus" :size="13" />
        {{ t('tutoring.sessions.addBtn') }}
      </button>
    </div>

    <div v-if="loading" class="space-y-2 py-4" aria-hidden="true">
      <div v-for="i in 3" :key="i" class="flex items-center gap-3 rounded-xl bg-tutoring-panel border border-tutoring-border-soft p-3">
        <div class="h-8 w-8 rounded-lg bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        <div class="flex-1 space-y-2">
          <div class="h-3 w-2/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
          <div class="h-2 w-3/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        </div>
      </div>
    </div>

    <template v-else-if="error">
      <TutoringEmpty :text="error" icon="alert-circle" />
    </template>

    <template v-else>
      <KpiStripCards v-if="stats" :cards="kpiCards" />

      <!-- Filter toolbar — view-toggle as segmented, range/group/status
           as picker chips. -->
      <PageFilterToolbar :hide-default-search="true">
        <template #chips>
          <AppFilterChip
            :label="t('tutor.bimbel.sessions.filter_range_label')"
            :value="activeRangeLabel"
            icon-name="calendar"
            tone="violet"
            @click="showRangePicker = true"
          />
          <AppFilterChip
            v-if="groupOptions.length > 2"
            :label="t('tutor.bimbel.sessions.filter_group_label')"
            :value="activeGroupLabel"
            icon-name="users"
            tone="brand"
            @click="showGroupPicker = true"
          />
          <AppFilterChip
            :label="t('tutor.bimbel.sessions.filter_status_label')"
            :value="activeStatusLabel"
            icon-name="check-circle"
            tone="green"
            @click="showStatusPicker = true"
          />
        </template>
        <template #segmented>
          <div class="inline-flex p-1 bg-tutoring-bg border border-tutoring-border rounded-xl">
            <button
              type="button"
              class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition"
              :class="view === 'list'
                ? 'bg-role-teacher text-white'
                : 'text-tutoring-text-mid hover:text-tutoring-text-hi'"
              @click="view = 'list'"
            >
              <NavIcon name="list" :size="14" />
              {{ t('tutoring.sessions.viewList') }}
            </button>
            <button
              type="button"
              class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition"
              :class="view === 'calendar'
                ? 'bg-role-teacher text-white'
                : 'text-tutoring-text-mid hover:text-tutoring-text-hi'"
              @click="view = 'calendar'"
            >
              <NavIcon name="calendar" :size="14" />
              {{ t('tutoring.sessions.viewCalendar') }}
            </button>
          </div>
        </template>
      </PageFilterToolbar>

      <!-- List view ───────────────────────────────────────────── -->
      <div v-if="view === 'list'">
        <TutoringEmpty
          v-if="filtered.length === 0"
          :text="t('tutoring.sessions.empty')"
          icon="calendar"
        />
        <div v-else class="space-y-2">
          <TutoringListTile
            v-for="s in filtered"
            :key="s.id"
            icon="calendar"
            accent="tutor"
            :title="s.scheduled_at ? formatDateShort(s.scheduled_at) : '—'"
            :subtitle="[
              s.group?.name,
              s.topic,
              s.room ? t('tutoring.sessions.room') + ' ' + s.room : null,
            ].filter(Boolean).join(' · ')"
            :to="s.status === 'CANCELLED' ? null : () => openAttendance(s)"
          >
            <template #trailing>
              <span class="inline-flex items-center gap-1.5">
                <a
                  v-if="s.meeting_url"
                  :href="s.meeting_url"
                  target="_blank"
                  rel="noopener"
                  class="inline-flex items-center gap-1 rounded-lg bg-status-info-soft text-tutoring-accent px-2 py-0.5 text-[12px] font-bold uppercase tracking-wider hover:bg-status-info-soft/80"
                  @click.stop
                >
                  <NavIcon name="external-link" :size="11" />
                  {{ t('tutor.bimbel.sessions.join_btn') }}
                </a>
                <TutoringStatusPill :session="s.status" />
              </span>
            </template>
          </TutoringListTile>
        </div>
      </div>

      <!-- Calendar view ───────────────────────────────────────── -->
      <div v-else>
        <div class="bg-tutoring-panel border border-tutoring-border-soft rounded-3xl p-4">
          <!-- header — < Month YYYY > -->
          <div class="flex items-center gap-2 mb-2">
            <button
              type="button"
              class="p-1.5 rounded-lg text-tutoring-text-mid hover:bg-tutoring-border-soft"
              @click="prevMonth"
            >
              <NavIcon name="chevron-left" :size="18" />
            </button>
            <div class="flex-1 text-center text-sm font-extrabold text-tutoring-text-hi tracking-tight">
              {{ monthLabel(focusedMonth.y, focusedMonth.m) }}
            </div>
            <button
              type="button"
              class="p-1.5 rounded-lg text-tutoring-text-mid hover:bg-tutoring-border-soft"
              @click="nextMonth"
            >
              <NavIcon name="chevron-right" :size="18" />
            </button>
          </div>
          <!-- weekday header — Senin..Minggu, single letter -->
          <div class="grid grid-cols-7 mb-1">
            <div
              v-for="(d, idx) in [
                t('tutor.bimbel.sessions.calendar_weekday_sen'),
                t('tutor.bimbel.sessions.calendar_weekday_sel'),
                t('tutor.bimbel.sessions.calendar_weekday_rab'),
                t('tutor.bimbel.sessions.calendar_weekday_kam'),
                t('tutor.bimbel.sessions.calendar_weekday_jum'),
                t('tutor.bimbel.sessions.calendar_weekday_sab'),
                t('tutor.bimbel.sessions.calendar_weekday_min'),
              ]"
              :key="idx"
              class="text-center text-[12px] font-bold text-tutoring-text-mid tracking-widest py-1"
            >
              {{ d }}
            </div>
          </div>
          <!-- day grid -->
          <div class="grid grid-cols-7 gap-1">
            <button
              v-for="(cell, i) in monthCells"
              :key="i"
              type="button"
              :disabled="!cell"
              class="h-11 rounded-lg text-xs font-bold relative transition flex flex-col items-center justify-center"
              :class="[
                cell ? '' : 'invisible',
                cell && isFocused(cell.date)
                  ? 'bg-role-teacher text-white'
                  : cell && isToday(cell.date)
                    ? 'bg-status-info-soft text-tutoring-accent'
                    : 'text-tutoring-text-hi hover:bg-tutoring-border-soft',
                cell && !isFocused(cell.date) && (sessionsByDay.get(dayKey(cell.date))?.length ?? 0) > 0
                  ? 'border border-tutoring-border'
                  : '',
              ]"
              @click="cell && (focusedDay = cell.date)"
            >
              <span v-if="cell">{{ cell.day }}</span>
              <span
                v-if="cell && (sessionsByDay.get(dayKey(cell.date))?.length ?? 0) > 0"
                class="flex items-center gap-0.5 mt-0.5"
              >
                <span
                  v-for="n in Math.min(sessionsByDay.get(dayKey(cell.date))?.length ?? 0, 3)"
                  :key="n"
                  class="w-1 h-1 rounded-full"
                  :class="isFocused(cell.date) ? 'bg-tutoring-panel' : 'bg-role-teacher'"
                ></span>
              </span>
            </button>
          </div>
        </div>

        <TutoringSectionHeader :title="focusedDayLabel(focusedDay)" />
        <TutoringEmpty
          v-if="focusedDaySessions.length === 0"
          :text="t('tutoring.sessions.calendarNoSessions')"
          icon="calendar"
        />
        <div v-else class="space-y-2">
          <TutoringListTile
            v-for="s in focusedDaySessions"
            :key="s.id"
            icon="clock"
            accent="tutor"
            :title="s.scheduled_at ? formatTime(s.scheduled_at) : '—'"
            :subtitle="[
              s.group?.name,
              s.topic,
              s.room ? t('tutoring.sessions.room') + ' ' + s.room : null,
            ].filter(Boolean).join(' · ')"
            :to="s.status === 'CANCELLED' ? null : () => openAttendance(s)"
          >
            <template #trailing>
              <span class="inline-flex items-center gap-1.5">
                <a
                  v-if="s.meeting_url"
                  :href="s.meeting_url"
                  target="_blank"
                  rel="noopener"
                  class="inline-flex items-center gap-1 rounded-lg bg-status-info-soft text-tutoring-accent px-2 py-0.5 text-[12px] font-bold uppercase tracking-wider hover:bg-status-info-soft/80"
                  @click.stop
                >
                  <NavIcon name="external-link" :size="11" />
                  {{ t('tutor.bimbel.sessions.join_btn') }}
                </a>
                <TutoringStatusPill :session="s.status" />
              </span>
            </template>
          </TutoringListTile>
        </div>
      </div>
    </template>

    <Modal
      v-if="showRangePicker"
      :title="t('tutor.bimbel.sessions.modal_range_title')"
      @close="showRangePicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in RANGE_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-bg"
            :class="{ 'bg-role-teacher/5 text-tutoring-accent font-bold': range === o.key }"
            @click="pickRange(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <Modal
      v-if="showStatusPicker"
      :title="t('tutor.bimbel.sessions.modal_status_title')"
      @close="showStatusPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in STATUS_OPTIONS" :key="o.value">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-bg"
            :class="{ 'bg-role-teacher/5 text-tutoring-accent font-bold': statusFilter === o.value }"
            @click="pickStatus(o.value)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <Modal
      v-if="showGroupPicker"
      :title="t('tutor.bimbel.sessions.modal_group_title')"
      @close="showGroupPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in groupOptions" :key="String(o.value)">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-bg"
            :class="{ 'bg-role-teacher/5 text-tutoring-accent font-bold': groupId === o.value }"
            @click="pickGroup(o.value)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
