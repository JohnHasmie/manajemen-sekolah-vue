<!--
  TutorSessionsView — the tutor's "Sesi Mengajar" dashboard. Rebuilt to
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

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringHero from '@/components/feature/tutoring/TutoringHero.vue';
import TutoringKpiCard from '@/components/feature/tutoring/TutoringKpiCard.vue';
import TutoringChipsRow from '@/components/feature/tutoring/TutoringChipsRow.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type RangeFilter = 'all' | 'today' | 'thisWeek' | 'upcoming' | 'past';
type ViewMode = 'list' | 'calendar';

// '' = no filter (all). TutoringChipsRow's generic constraint is
// `string | number`, so we use empty string as the sentinel instead
// of null.
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
</script>

<template>
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.sessions.title')"
      crumbs="Bimbel · Sesi Saya"
    >
      <template #right>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-role-teacher hover:bg-role-teacher/90 text-white rounded-xl px-3.5 py-2 text-sm font-semibold"
          @click="router.push({ name: 'teacher.tutoring.session-create' })"
        >
          <NavIcon name="plus" :size="14" />
          {{ t('tutoring.sessions.addBtn') }}
        </button>
      </template>
    </TutoringPageHeader>

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else-if="error">
      <TutoringEmpty :text="error" icon="alert-circle" />
    </template>

    <template v-else>
      <!-- Hero greeting — matches the school teacher pages' brand
           chrome but uses the tutoring shared components so visuals
           line up with the rest of bimbel. -->
      <TutoringHero
        icon="calendar"
        :greet="t('tutoring.sessions.greet')"
        title="Halo, "
        :accent-name="auth.user?.name ?? 'Tutor'"
        accent="tutor"
      >
        <template #trailing>
          <TutoringStatusPill label="Realtime" tone="ok" dot />
        </template>
      </TutoringHero>

      <!-- KPI strip — graceful when stats fail (the page still works). -->
      <div v-if="stats" class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4">
        <TutoringKpiCard
          icon="calendar"
          :value="stats.sessions_this_week"
          :label="t('tutoring.sessions.kpiSessionsWeek')"
          :hint="stats.sessions_today > 0
            ? stats.sessions_today + ' ' + t('tutoring.sessions.kpiHintToday')
            : undefined"
          tone="info"
        />
        <TutoringKpiCard
          icon="clock"
          :value="hoursLabel(stats.hours_this_week)"
          :label="t('tutoring.sessions.kpiHoursWeek')"
        />
        <TutoringKpiCard
          icon="check-circle"
          :value="stats.attendance_rate == null
            ? '–'
            : stats.attendance_rate + '%'"
          :label="t('tutoring.sessions.kpiAttendance')"
          tone="ok"
        />
        <TutoringKpiCard
          icon="users"
          :value="stats.groups"
          :label="t('tutoring.sessions.kpiGroups')"
          :hint="stats.students > 0
            ? stats.students + ' ' + t('tutoring.sessions.kpiStudents')
            : undefined"
        />
      </div>

      <!-- View toggle — segmented control between list + calendar. -->
      <div
        class="mt-4 inline-flex p-1 bg-white border border-slate-200 rounded-xl"
      >
        <button
          type="button"
          class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition"
          :class="view === 'list'
            ? 'bg-role-teacher text-white'
            : 'text-slate-500 hover:text-slate-900'"
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
            : 'text-slate-500 hover:text-slate-900'"
          @click="view = 'calendar'"
        >
          <NavIcon name="calendar" :size="14" />
          {{ t('tutoring.sessions.viewCalendar') }}
        </button>
      </div>

      <!-- Filter chips. Group filter only renders when the load has
           more than one distinct group; otherwise it's noise. -->
      <div class="mt-3 space-y-2">
        <TutoringChipsRow
          v-model="range"
          :options="[
            { value: 'all', label: t('tutoring.sessions.filterAll') },
            { value: 'today', label: t('tutoring.sessions.filterToday') },
            { value: 'thisWeek', label: t('tutoring.sessions.filterThisWeek') },
            { value: 'upcoming', label: t('tutoring.sessions.filterUpcoming') },
            { value: 'past', label: t('tutoring.sessions.filterPast') },
          ]"
        />
        <TutoringChipsRow
          v-if="groupOptions.length > 2"
          v-model="groupId"
          :options="groupOptions"
        />
        <TutoringChipsRow
          v-model="statusFilter"
          :options="[
            { value: ALL, label: t('tutoring.sessions.filterAll') },
            { value: 'SCHEDULED', label: t('tutoring.sessions.filterScheduled') },
            { value: 'DONE', label: t('tutoring.sessions.filterDone') },
            { value: 'CANCELLED', label: t('tutoring.sessions.filterCancelled') },
          ]"
        />
      </div>

      <!-- List view ───────────────────────────────────────────── -->
      <div v-if="view === 'list'" class="mt-4">
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
              <TutoringStatusPill :session="s.status" />
            </template>
          </TutoringListTile>
        </div>
      </div>

      <!-- Calendar view ───────────────────────────────────────── -->
      <div v-else class="mt-4">
        <div class="bg-white border border-slate-100 rounded-3xl p-4">
          <!-- header — < Month YYYY > -->
          <div class="flex items-center gap-2 mb-2">
            <button
              type="button"
              class="p-1.5 rounded-lg text-slate-500 hover:bg-slate-100"
              @click="prevMonth"
            >
              <NavIcon name="chevron-left" :size="18" />
            </button>
            <div class="flex-1 text-center text-sm font-extrabold text-slate-900 tracking-tight">
              {{ monthLabel(focusedMonth.y, focusedMonth.m) }}
            </div>
            <button
              type="button"
              class="p-1.5 rounded-lg text-slate-500 hover:bg-slate-100"
              @click="nextMonth"
            >
              <NavIcon name="chevron-right" :size="18" />
            </button>
          </div>
          <!-- weekday header — Senin..Minggu, single letter -->
          <div class="grid grid-cols-7 mb-1">
            <div
              v-for="d in ['S', 'S', 'R', 'K', 'J', 'S', 'M']"
              :key="d + Math.random()"
              class="text-center text-[10.5px] font-bold text-slate-500 tracking-widest py-1"
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
                    ? 'bg-status-info-soft text-role-teacher'
                    : 'text-slate-900 hover:bg-slate-100',
                cell && !isFocused(cell.date) && (sessionsByDay.get(dayKey(cell.date))?.length ?? 0) > 0
                  ? 'border border-slate-200'
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
                  :class="isFocused(cell.date) ? 'bg-white' : 'bg-role-teacher'"
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
              <TutoringStatusPill :session="s.status" />
            </template>
          </TutoringListTile>
        </div>
      </div>
    </template>
  </div>
</template>
