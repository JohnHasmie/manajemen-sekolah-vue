<!--
  WeeklyActivityBars.vue — school-wide 7-day XP as a labeled vertical
  bar chart (the "familiar" chart admins recognise, replacing the old
  line/area chart on this page).

  Consumes the backend's `meta.weekly_activity` (7 entries, oldest →
  newest, zero days included). Each bar is labeled with the weekday
  abbreviation derived from its own date (Sen/Sel/Rab/Kam/Jum/Sab/Min),
  so the axis reads correctly for whatever 7-day window ends today.

  Modeled on WeeklyPointsChart.vue's SVG approach, but draws BARS +
  weekday labels instead of a polyline. preserveAspectRatio is left at
  its default (meet) so the <text> labels never distort.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { WeeklyActivityPoint } from '@/services/teacher-progress.service';

const props = defineProps<{
  /** 7 entries, oldest → newest. */
  data: WeeklyActivityPoint[];
}>();

// viewBox geometry. Extra headroom on top for the value label and a
// bottom band for the weekday axis labels.
const dims = { width: 336, height: 150, padX: 6, padTop: 22, padBottom: 26 };

const WEEKDAY_ID: readonly string[] = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

/** Local-safe weekday from a YYYY-MM-DD string (avoids UTC day-shift). */
function weekdayLabel(dateStr: string): string {
  const [y, m, d] = dateStr.split('-').map(Number);
  if (!y || !m || !d) return '';
  return WEEKDAY_ID[new Date(y, m - 1, d).getDay()] ?? '';
}

const maxPoints = computed(() =>
  Math.max(1, ...props.data.map((p) => p.points)),
);

const bars = computed(() => {
  const n = props.data.length;
  if (n === 0) return [];
  const chartH = dims.height - dims.padTop - dims.padBottom;
  const slotW = (dims.width - dims.padX * 2) / n;
  const barW = Math.min(28, slotW * 0.58);
  return props.data.map((p, i) => {
    const slotX = dims.padX + slotW * i;
    const x = slotX + (slotW - barW) / 2;
    // Zero days still draw a 2px stub so the day is visibly present.
    const h = p.points <= 0 ? 2 : Math.max(3, (p.points / maxPoints.value) * chartH);
    const y = dims.padTop + (chartH - h);
    return {
      key: p.date,
      x,
      y,
      w: barW,
      h,
      cx: slotX + slotW / 2,
      points: p.points,
      label: weekdayLabel(p.date),
      active: p.points > 0,
    };
  });
});

const totalWeek = computed(() =>
  props.data.reduce((sum, p) => sum + p.points, 0),
);
</script>

<template>
  <div class="w-full overflow-x-auto">
    <svg
      :viewBox="`0 0 ${dims.width} ${dims.height}`"
      class="w-full h-auto"
      role="img"
      aria-label="Aktivitas XP sekolah 7 hari terakhir"
    >
      <!-- Baseline under the bars. -->
      <line
        :x1="dims.padX"
        :x2="dims.width - dims.padX"
        :y1="dims.height - dims.padBottom"
        :y2="dims.height - dims.padBottom"
        stroke="rgb(226,232,240)"
        stroke-width="1"
      />

      <g v-for="b in bars" :key="b.key">
        <!-- Bar -->
        <rect
          :x="b.x"
          :y="b.y"
          :width="b.w"
          :height="b.h"
          rx="3"
          :class="b.active ? 'fill-brand-cobalt' : 'fill-slate-200'"
        />
        <!-- Value label (only when there's activity, to avoid clutter). -->
        <text
          v-if="b.active"
          :x="b.cx"
          :y="b.y - 6"
          text-anchor="middle"
          class="fill-slate-700 font-bold"
          style="font-size: 11px"
        >
          {{ b.points }}
        </text>
        <!-- Weekday axis label. -->
        <text
          :x="b.cx"
          :y="dims.height - dims.padBottom + 16"
          text-anchor="middle"
          class="fill-slate-500 font-bold"
          style="font-size: 11px"
        >
          {{ b.label }}
        </text>
      </g>
    </svg>
    <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest text-center mt-1">
      Total {{ totalWeek }} XP · 7 hari terakhir
    </p>
  </div>
</template>
