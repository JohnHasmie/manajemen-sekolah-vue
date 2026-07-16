<!--
  SparklineTinyBar.vue — 7-bar mini chart for the admin engagement
  table row. Renders one thin SVG per teacher; kept intentionally
  small (24px tall) so it doesn't dominate the row.

  Empty days (0 XP) still render as a 1px baseline mark so an
  otherwise-blank teacher visibly has SOMETHING drawn — differentiates
  "quiet week" from "no data at all".
-->
<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  points: number[];
}>();

const dims = { width: 84, height: 24, barGap: 3 };

const maxVal = computed(() => Math.max(1, ...props.points));

const bars = computed(() => {
  const n = props.points.length;
  if (n === 0) return [];
  const barWidth = Math.max(1, (dims.width - dims.barGap * (n - 1)) / n);
  return props.points.map((v, i) => {
    const h = v <= 0 ? 1 : Math.max(2, (v / maxVal.value) * dims.height);
    const x = i * (barWidth + dims.barGap);
    const y = dims.height - h;
    return { x, y, w: barWidth, h, tone: v <= 0 ? 'silent' : 'active' };
  });
});
</script>

<template>
  <svg
    :viewBox="`0 0 ${dims.width} ${dims.height}`"
    preserveAspectRatio="none"
    class="w-20 h-6 flex-shrink-0"
    role="img"
    aria-label="Aktivitas 7 hari"
  >
    <rect
      v-for="(b, i) in bars"
      :key="i"
      :x="b.x"
      :y="b.y"
      :width="b.w"
      :height="b.h"
      rx="1.5"
      :class="b.tone === 'silent' ? 'fill-slate-200' : 'fill-brand-cobalt'"
    />
  </svg>
</template>
