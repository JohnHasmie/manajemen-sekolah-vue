<!--
  SessionsCalendar — shared month-grid + per-day session strip for any
  TutoringSession list. Same widget the tutor "Session Saya" uses, now
  also used by the admin "Session" view so the calendar UX is identical
  across roles.

  Props:
    - sessions   — full list of sessions to render dots/days from.
    - accent     — 'admin' | 'tutor' | 'parent' (drives the focus tint).
    - onOpen     — optional click handler per session (passed to the
                   per-day list tiles).

  Internally focused on the current day at mount; user can pan months
  with the prev/next arrows.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { formatTime } from '@/lib/format';
import type { TutoringSession } from '@/types/tutoring';
import { useI18n } from 'vue-i18n';

import NavIcon from '@/components/feature/NavIcon.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';

const props = withDefaults(
  defineProps<{
    sessions: TutoringSession[];
    accent?: 'admin' | 'tutor' | 'wali';
    onOpen?: (s: TutoringSession) => void;
  }>(),
  { accent: 'tutor' },
);

const { t } = useI18n();

const focusedDay = ref<Date>(new Date());
const focusedMonth = ref<{ y: number; m: number }>({
  y: new Date().getFullYear(),
  m: new Date().getMonth(),
});

// Bucket sessions by yyyy-mm-dd for O(1) day lookup.
const sessionsByDay = computed(() => {
  const map = new Map<string, TutoringSession[]>();
  for (const s of props.sessions) {
    if (!s.scheduled_at) continue;
    const d = new Date(s.scheduled_at);
    const key = dayKey(d);
    const arr = map.get(key) ?? [];
    arr.push(s);
    map.set(key, arr);
  }
  return map;
});

const focusedDaySessions = computed(
  () => sessionsByDay.value.get(dayKey(focusedDay.value)) ?? [],
);

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
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

const monthCells = computed(() => {
  const { y, m } = focusedMonth.value;
  const first = new Date(y, m, 1);
  const lead = (first.getDay() + 6) % 7; // anchor on Monday
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
  const tt = new Date();
  return d.getFullYear() === tt.getFullYear() &&
    d.getMonth() === tt.getMonth() &&
    d.getDate() === tt.getDate();
}
function isFocused(d: Date): boolean {
  const f = focusedDay.value;
  return d.getFullYear() === f.getFullYear() &&
    d.getMonth() === f.getMonth() &&
    d.getDate() === f.getDate();
}

// Reset focus to month-start when user pans away.
watch(focusedMonth, ({ y, m }) => {
  const f = focusedDay.value;
  if (f.getFullYear() !== y || f.getMonth() !== m) {
    focusedDay.value = new Date(y, m, 1);
  }
});

// Tailwind classes vary by accent — kept as static literals so JIT
// picks them up.
const FOCUSED_BG = computed(() => ({
  admin: 'bg-bimbel-accent text-bimbel-ring',
  tutor: 'bg-role-teacher text-white',
  wali: 'bg-role-parent text-white',
}[props.accent]));
const TODAY_TEXT = computed(() => ({
  admin: 'bg-status-info-soft text-bimbel-accent',
  tutor: 'bg-status-info-soft text-bimbel-accent',
  wali: 'bg-status-info-soft text-bimbel-accent',
}[props.accent]));
const DOT_BG = computed(() => ({
  admin: 'bg-bimbel-accent',
  tutor: 'bg-role-teacher',
  wali: 'bg-role-parent',
}[props.accent]));
</script>

<template>
  <div>
    <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-3xl p-4">
      <!-- header — < Month YYYY > -->
      <div class="flex items-center gap-2 mb-2">
        <button
          type="button"
          class="p-1.5 rounded-lg text-bimbel-text-mid hover:bg-bimbel-border-soft"
          @click="prevMonth"
        >
          <NavIcon name="chevron-left" :size="18" />
        </button>
        <div class="flex-1 text-center text-sm font-extrabold text-bimbel-text-hi tracking-tight">
          {{ monthLabel(focusedMonth.y, focusedMonth.m) }}
        </div>
        <button
          type="button"
          class="p-1.5 rounded-lg text-bimbel-text-mid hover:bg-bimbel-border-soft"
          @click="nextMonth"
        >
          <NavIcon name="chevron-right" :size="18" />
        </button>
      </div>
      <!-- weekday header -->
      <div class="grid grid-cols-7 mb-1">
        <div
          v-for="(d, i) in ['S', 'S', 'R', 'K', 'J', 'S', 'M']"
          :key="i"
          class="text-center text-[12px] font-bold text-bimbel-text-mid tracking-widest py-1"
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
              ? FOCUSED_BG
              : cell && isToday(cell.date)
                ? TODAY_TEXT
                : 'text-bimbel-text-hi hover:bg-bimbel-border-soft',
            cell && !isFocused(cell.date) && (sessionsByDay.get(dayKey(cell.date))?.length ?? 0) > 0
              ? 'border border-bimbel-border'
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
              :class="isFocused(cell.date) ? 'bg-bimbel-panel' : DOT_BG"
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
        :accent="accent"
        :title="s.scheduled_at ? formatTime(s.scheduled_at) : '—'"
        :subtitle="[
          s.group?.name,
          s.tutor?.name,
          s.topic,
          s.room ? t('tutoring.sessions.room') + ' ' + s.room : null,
        ].filter(Boolean).join(' · ')"
        :to="s.status === 'CANCELLED' ? null : onOpen ? () => onOpen!(s) : null"
      >
        <template #trailing>
          <span class="inline-flex items-center gap-1.5">
            <a
              v-if="s.meeting_url"
              :href="s.meeting_url"
              target="_blank"
              rel="noopener"
              class="inline-flex items-center gap-1 rounded-lg bg-status-info-soft text-brand-cobalt px-2 py-0.5 text-[12px] font-bold uppercase tracking-wider hover:bg-status-info-soft/80"
              @click.stop
            >
              <NavIcon name="external-link" :size="11" />
              Join
            </a>
            <TutoringStatusPill :session="s.status" />
          </span>
        </template>
      </TutoringListTile>
    </div>
  </div>
</template>
