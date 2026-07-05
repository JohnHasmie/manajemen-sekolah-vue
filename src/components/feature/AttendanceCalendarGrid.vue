<!--
  AttendanceCalendarGrid.vue — Sen-Min 7-column attendance calendar.

  Mirrors Flutter's `AttendanceCalendarGrid`. Renders a month grid
  starting on Monday. Each cell is colored by the worst-status of
  that day's records (alpha > sakit > izin > terlambat > hadir).
  Tap a cell with records → emits select(dateIso).
-->
<script setup lang="ts">
import { computed } from 'vue';
import type {
  ParentAttendanceEntry,
  ParentAttendanceStatus,
} from '@/types/parent';

const props = defineProps<{
  /** YYYY-MM of the month to render. */
  monthIso: string;
  /** Records for THIS month only (pre-sliced by host). */
  records: ParentAttendanceEntry[];
  /** Currently selected day (YYYY-MM-DD). */
  selectedDate?: string | null;
}>();

defineEmits<{
  select: [string];
}>();

const DAY_LABELS = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

// Status severity — higher wins on a day with multiple records.
const SEVERITY: Record<ParentAttendanceStatus, number> = {
  hadir: 0,
  terlambat: 1,
  izin: 2,
  sakit: 3,
  alpha: 4,
};

const monthMeta = computed(() => {
  const [year, mo] = props.monthIso.split('-').map(Number);
  if (!Number.isFinite(year) || !Number.isFinite(mo)) {
    const now = new Date();
    return { year: now.getFullYear(), month: now.getMonth() + 1 };
  }
  return { year, month: mo };
});

// Map "YYYY-MM-DD" → worst status of that day.
const byDate = computed(() => {
  const out = new Map<string, ParentAttendanceStatus>();
  for (const r of props.records) {
    if (!r.date) continue;
    const prev = out.get(r.date);
    if (!prev || SEVERITY[r.status] > SEVERITY[prev]) {
      out.set(r.date, r.status);
    }
  }
  return out;
});

interface Cell {
  date: string | null;
  day: number | null;
  status: ParentAttendanceStatus | null;
  isSelected: boolean;
  isToday: boolean;
}

const todayIso = (() => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
})();

const cells = computed<Cell[]>(() => {
  const { year, month } = monthMeta.value;
  const first = new Date(year, month - 1, 1);
  // JS getDay(): 0 = Sun, 1 = Mon … 6 = Sat. We want Monday-indexed (0..6).
  const firstMondayIndex = (first.getDay() + 6) % 7;
  const daysInMonth = new Date(year, month, 0).getDate();

  const out: Cell[] = [];
  // Leading blanks.
  for (let i = 0; i < firstMondayIndex; i++) {
    out.push({ date: null, day: null, status: null, isSelected: false, isToday: false });
  }
  for (let d = 1; d <= daysInMonth; d++) {
    const iso = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    out.push({
      date: iso,
      day: d,
      status: byDate.value.get(iso) ?? null,
      isSelected: iso === props.selectedDate,
      isToday: iso === todayIso,
    });
  }
  // Trailing blanks to keep grid 7-wide.
  while (out.length % 7 !== 0) {
    out.push({ date: null, day: null, status: null, isSelected: false, isToday: false });
  }
  return out;
});

function cellBg(c: Cell): string {
  if (c.date === null) return 'bg-transparent';
  if (c.isSelected) return 'bg-role-wali text-white';
  if (!c.status) return 'bg-slate-50 text-slate-400';
  switch (c.status) {
    case 'hadir':
      return 'bg-emerald-100 text-emerald-800';
    case 'terlambat':
      return 'bg-amber-100 text-amber-800';
    case 'izin':
      return 'bg-brand-cobalt/15 text-brand-cobalt';
    case 'sakit':
      return 'bg-orange-100 text-orange-800';
    case 'alpha':
    default:
      return 'bg-red-100 text-red-800';
  }
}
</script>

<template>
  <section class="bg-white border border-slate-200 rounded-2xl p-3">
    <!-- Day headers -->
    <div class="grid grid-cols-7 gap-1.5 mb-2">
      <div
        v-for="d in DAY_LABELS"
        :key="d"
        class="text-center text-4xs font-bold text-slate-400 uppercase tracking-widest py-1"
      >
        {{ d }}
      </div>
    </div>
    <!-- Cells -->
    <div class="grid grid-cols-7 gap-1.5">
      <button
        v-for="(c, idx) in cells"
        :key="idx"
        type="button"
        class="aspect-square rounded-lg text-2xs font-bold transition-all"
        :class="[
          cellBg(c),
          c.date == null ? 'cursor-default pointer-events-none' : 'hover:opacity-80',
          c.isToday && !c.isSelected ? 'ring-2 ring-role-wali/40' : '',
        ]"
        :disabled="c.date == null"
        @click="c.date && $emit('select', c.date)"
      >
        <span v-if="c.day !== null">{{ c.day }}</span>
      </button>
    </div>
  </section>
</template>
