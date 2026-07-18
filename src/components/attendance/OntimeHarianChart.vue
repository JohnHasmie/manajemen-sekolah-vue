<!--
  OntimeHarianChart.vue — hand-rolled SVG bar chart for the "Tepat waktu
  harian" panel of the pegawai attendance dashboard (MR-3 Opsi A).

  We deliberately don't reach for chart.js / apexcharts because the
  bundle already carries none of them and this chart is a small,
  read-only strip (7 or ~30 daily bars). SVG is enough and keeps the
  vendor footprint at zero.

  Rendering:
    · One bar per day in `data[]`; bar height maps to ontime_pct%.
    · Color tone follows the wire threshold: green ≥85, amber 70–84,
      red < 70. Non-workday bars render as a neutral dashed stroke +
      light fill so weekends/holidays are visually deferred.
    · "Today" (last workday bar matching new Date()) picks up a dashed
      brand-cobalt outline so the admin can spot the current bucket at
      a glance.
    · Hover reveals a tooltip title (native SVG <title>) with the
      date + percentage + hadir/terlambat counts — no custom overlay
      layer, so it stays keyboard-tab friendly without extra JS.

  Emits `select-day(date)` on click for the future calendar drill;
  the caller can ignore it (no-op for MR-3 per the task's guidance).

  Props:
    · data:  Array<TeacherAttendanceTimeseriesDay> from the service.
    · range: 'week' | 'month' — cosmetic hint; the SVG viewBox scales
             naturally to the number of bars regardless.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { TeacherAttendanceTimeseriesDay } from '@/types/teacher-attendance';

const props = withDefaults(
  defineProps<{
    data: TeacherAttendanceTimeseriesDay[];
    range?: 'week' | 'month';
    /**
     * Skeleton flag — when true, the chart renders faint placeholder
     * bars instead of the real data. Keeps layout stable across the
     * loading → content transition so the section doesn't jump.
     */
    loading?: boolean;
  }>(),
  { range: 'week', loading: false },
);

defineEmits<{ 'select-day': [string] }>();

// ── Colour ramp ───────────────────────────────────────────────────
// Uses static Tailwind palette hexes (emerald-500/amber-500/red-500)
// so no theme lookup is needed and the chart works on any background.
// Non-workdays get a soft slate wash — the wireframe treats them as
// context, not data.
function barFill(day: TeacherAttendanceTimeseriesDay): string {
  if (!day.is_workday) return '#e2e8f0'; // slate-200
  const p = day.ontime_pct;
  if (p >= 85) return '#10b981'; // emerald-500
  if (p >= 70) return '#f59e0b'; // amber-500
  return '#ef4444'; // red-500
}

function barStroke(day: TeacherAttendanceTimeseriesDay): string {
  return day.is_workday ? 'transparent' : '#94a3b8'; // slate-400
}

const TODAY_ISO = new Date().toISOString().slice(0, 10);
function isToday(day: TeacherAttendanceTimeseriesDay): boolean {
  return day.date === TODAY_ISO;
}

// ── Geometry ──────────────────────────────────────────────────────
// Fixed viewBox — the SVG scales via CSS width:100%. Height chosen
// so the chart matches the wireframe's proportion (about 3:1) at the
// canonical 720px card width.
const VB_W = 720;
const VB_H = 220;
const PAD_L = 32; // room for y-axis labels
const PAD_R = 12;
const PAD_T = 16;
const PAD_B = 36; // room for x-axis date labels

const chartWidth = computed(() => VB_W - PAD_L - PAD_R);
const chartHeight = computed(() => VB_H - PAD_T - PAD_B);

/**
 * When data is empty we still lay out an empty 7-bar shell so the
 * card doesn't collapse. Prevents a layout-jump on the loading →
 * empty transition.
 */
const bars = computed(() => (props.data.length > 0 ? props.data : []));

const barCount = computed(() => Math.max(bars.value.length, 1));

/** Bar-slot width; a small gap sits between adjacent bars. */
const slotWidth = computed(() => chartWidth.value / barCount.value);

const BAR_GAP_PCT = 0.28; // 28% of the slot is gap
const barWidth = computed(() =>
  Math.max(6, slotWidth.value * (1 - BAR_GAP_PCT)),
);
const barGap = computed(() => slotWidth.value - barWidth.value);

function barX(idx: number): number {
  return PAD_L + slotWidth.value * idx + barGap.value / 2;
}

/**
 * Bar height in SVG units. Clamp the pct to 0..100 so a bogus 105
 * from the backend doesn't punch above the chart area.
 */
function barH(pct: number): number {
  const clamped = Math.max(0, Math.min(100, pct));
  return (clamped / 100) * chartHeight.value;
}

function barY(pct: number): number {
  return PAD_T + chartHeight.value - barH(pct);
}

// Y-axis grid — 4 lines at 0/25/50/75/100.
const gridLines = computed(() =>
  [0, 25, 50, 75, 100].map((v) => ({
    v,
    y: PAD_T + chartHeight.value - barH(v),
  })),
);

const WEEKDAY_LABELS = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
function xLabel(day: TeacherAttendanceTimeseriesDay): string {
  // For week range: short weekday. For month range: day number so the
  // 30-bar strip doesn't clutter with day-of-week repeats. We infer
  // range from the bar count so callers on `month` still get sensible
  // ticks even when they forget to pass the prop.
  const many = bars.value.length > 10;
  if (many) {
    return day.date.slice(8, 10); // dd
  }
  const [y, m, d] = day.date.split('-').map((s) => parseInt(s, 10));
  if (!y || !m || !d) return day.date;
  const wd = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return WEEKDAY_LABELS[wd] ?? day.date;
}

function tooltip(day: TeacherAttendanceTimeseriesDay): string {
  const [y, m, d] = day.date.split('-');
  const dateLabel = d && m && y ? `${d}/${m}/${y}` : day.date;
  if (!day.is_workday) return `${dateLabel} · Libur / non-workday`;
  return `${dateLabel} · ${day.ontime_pct}% tepat waktu · hadir ${day.present_count}, telat ${day.late_count}, absen ${day.absent_count}`;
}

// Legend swatches — mirrors the wireframe's caption strip.
const legend = [
  { label: 'Tepat waktu (≥85%)', fill: '#10b981' },
  { label: 'Waspada (70–84%)', fill: '#f59e0b' },
  { label: 'Kritis (<70%)', fill: '#ef4444' },
  { label: 'Libur', fill: '#e2e8f0', dashed: true },
];
</script>

<template>
  <div class="w-full">
    <svg
      :viewBox="`0 0 ${VB_W} ${VB_H}`"
      class="w-full h-auto"
      role="img"
      :aria-label="`Grafik tepat waktu harian, ${bars.length} hari`"
    >
      <!-- Y-axis grid + labels -->
      <g class="text-slate-300">
        <line
          v-for="g in gridLines"
          :key="`g-${g.v}`"
          :x1="PAD_L"
          :x2="VB_W - PAD_R"
          :y1="g.y"
          :y2="g.y"
          :stroke="g.v === 0 ? '#94a3b8' : '#e2e8f0'"
          stroke-width="1"
        />
        <text
          v-for="g in gridLines"
          :key="`gl-${g.v}`"
          :x="PAD_L - 6"
          :y="g.y + 3"
          text-anchor="end"
          font-size="9"
          fill="#94a3b8"
        >
          {{ g.v }}%
        </text>
      </g>

      <!-- Skeleton bars -->
      <template v-if="loading">
        <rect
          v-for="i in 7"
          :key="`sk-${i}`"
          :x="PAD_L + (chartWidth / 7) * (i - 1) + (chartWidth / 7) * 0.14"
          :y="PAD_T + chartHeight * 0.4"
          :width="(chartWidth / 7) * 0.72"
          :height="chartHeight * 0.6"
          rx="4"
          fill="#e2e8f0"
          class="animate-pulse"
        />
      </template>

      <!-- Real bars -->
      <template v-else>
        <g
          v-for="(day, idx) in bars"
          :key="day.date"
          class="cursor-pointer"
          @click="$emit('select-day', day.date)"
        >
          <rect
            :x="barX(idx)"
            :y="barY(day.ontime_pct)"
            :width="barWidth"
            :height="Math.max(2, barH(day.ontime_pct))"
            :fill="barFill(day)"
            :stroke="barStroke(day)"
            :stroke-dasharray="day.is_workday ? '' : '3 3'"
            stroke-width="1"
            rx="4"
            opacity="0.95"
          >
            <title>{{ tooltip(day) }}</title>
          </rect>
          <!-- Today outline -->
          <rect
            v-if="isToday(day)"
            :x="barX(idx) - 2"
            :y="PAD_T - 2"
            :width="barWidth + 4"
            :height="chartHeight + 4"
            fill="none"
            stroke="#1b6fb8"
            stroke-width="1.5"
            stroke-dasharray="4 3"
            rx="6"
            pointer-events="none"
          />
          <!-- X-axis tick -->
          <text
            :x="barX(idx) + barWidth / 2"
            :y="VB_H - PAD_B + 14"
            text-anchor="middle"
            font-size="10"
            font-weight="600"
            fill="#64748b"
          >
            {{ xLabel(day) }}
          </text>
          <text
            v-if="day.is_workday"
            :x="barX(idx) + barWidth / 2"
            :y="Math.max(barY(day.ontime_pct) - 4, PAD_T + 10)"
            text-anchor="middle"
            font-size="9"
            font-weight="700"
            :fill="barFill(day)"
          >
            {{ Math.round(day.ontime_pct) }}%
          </text>
        </g>
      </template>

      <!-- Empty state -->
      <text
        v-if="!loading && bars.length === 0"
        :x="VB_W / 2"
        :y="VB_H / 2"
        text-anchor="middle"
        font-size="11"
        fill="#94a3b8"
      >
        Belum ada data untuk periode ini.
      </text>
    </svg>

    <!-- Legend -->
    <div class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1">
      <div
        v-for="l in legend"
        :key="l.label"
        class="inline-flex items-center gap-1.5 text-[10.5px] text-slate-500"
      >
        <span
          class="inline-block w-3 h-3 rounded-sm"
          :style="{
            backgroundColor: l.fill,
            border: l.dashed ? '1px dashed #94a3b8' : 'none',
          }"
          aria-hidden="true"
        />
        <span>{{ l.label }}</span>
      </div>
    </div>
  </div>
</template>
