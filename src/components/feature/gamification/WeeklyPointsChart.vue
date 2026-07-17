<!--
  WeeklyPointsChart.vue — SVG polyline + area fill for 14-day XP.

  Backend returns the full array (zeros included) so we render a
  solid chart from left to right without gaps.
-->
<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  points: { date: string; xp: number }[];
}>();

const dims = { width: 320, height: 120, padX: 8, padY: 12 };

const maxXp = computed(() => Math.max(1, ...props.points.map((p) => p.xp)));

const coords = computed(() => {
  const n = props.points.length;
  if (n === 0) return [];
  const stepX = (dims.width - dims.padX * 2) / Math.max(1, n - 1);
  return props.points.map((p, i) => {
    const x = dims.padX + stepX * i;
    const y = dims.height - dims.padY - ((p.xp / maxXp.value) * (dims.height - dims.padY * 2));
    return { x, y, xp: p.xp, date: p.date };
  });
});

const polylineD = computed(() => coords.value.map((c) => `${c.x},${c.y}`).join(' '));

const areaD = computed(() => {
  const c = coords.value;
  if (c.length === 0) return '';
  const first = `M ${c[0].x} ${dims.height - dims.padY}`;
  const line = c.map((p) => `L ${p.x} ${p.y}`).join(' ');
  const close = `L ${c[c.length - 1].x} ${dims.height - dims.padY} Z`;
  return `${first} ${line} ${close}`;
});
</script>

<template>
  <div class="w-full overflow-x-auto">
    <svg
      :viewBox="`0 0 ${dims.width} ${dims.height}`"
      preserveAspectRatio="none"
      class="w-full h-32"
    >
      <defs>
        <linearGradient id="gamification-area" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#3B82F6" stop-opacity="0.35" />
          <stop offset="100%" stop-color="#3B82F6" stop-opacity="0" />
        </linearGradient>
      </defs>
      <!-- Baseline grid -->
      <line
        v-for="i in 3"
        :key="i"
        :x1="dims.padX"
        :x2="dims.width - dims.padX"
        :y1="dims.padY + ((dims.height - dims.padY * 2) / 3) * i"
        :y2="dims.padY + ((dims.height - dims.padY * 2) / 3) * i"
        stroke="rgb(226,232,240)"
        stroke-width="1"
        stroke-dasharray="2 4"
      />
      <path :d="areaD" fill="url(#gamification-area)" />
      <polyline
        v-if="polylineD"
        :points="polylineD"
        fill="none"
        stroke="#3B82F6"
        stroke-width="2"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
      <circle
        v-for="c in coords"
        :key="c.date"
        :cx="c.x"
        :cy="c.y"
        r="2.5"
        fill="#3B82F6"
      />
    </svg>
    <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest text-center mt-1">
      {{ points.length }} hari terakhir
    </p>
  </div>
</template>
