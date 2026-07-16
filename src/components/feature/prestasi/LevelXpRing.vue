<!--
  LevelXpRing.vue — SVG ring showing progress inside the current level.

  Mirrors AttendanceRingKpi's SVG shape. Three sizes:
    sm  60x60 (used inside admin table rows)
    md  96x96 (used in leaderboard row + peringkat)
    lg  128x128 (used in the Prestasi hub Ringkasan tab)

  Progress = xpInLevel / (xpInLevel + xpForNextLevel).
  Center shows the level number; sub-label the level title.
-->
<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    level: number;
    xpInLevel: number;
    xpForNextLevel: number;
    levelTitle?: string;
    size?: 'sm' | 'md' | 'lg';
  }>(),
  { levelTitle: '', size: 'md' },
);

const dims = computed(() => {
  switch (props.size) {
    case 'sm':
      return { box: 60, r: 26, stroke: 5, num: 'text-base', sub: 'text-4xs' };
    case 'lg':
      return { box: 128, r: 56, stroke: 10, num: 'text-3xl', sub: 'text-xs' };
    case 'md':
    default:
      return { box: 96, r: 40, stroke: 7, num: 'text-2xl', sub: 'text-3xs' };
  }
});

const circumference = computed(() => 2 * Math.PI * dims.value.r);

const dash = computed(() => {
  const total = props.xpInLevel + props.xpForNextLevel;
  const pct = total > 0 ? Math.max(0, Math.min(1, props.xpInLevel / total)) : 0;
  return `${pct * circumference.value} ${circumference.value}`;
});
</script>

<template>
  <div class="relative flex-shrink-0" :style="{ width: dims.box + 'px', height: dims.box + 'px' }">
    <svg :viewBox="`0 0 ${dims.box} ${dims.box}`" class="w-full h-full -rotate-90">
      <circle
        :cx="dims.box / 2"
        :cy="dims.box / 2"
        :r="dims.r"
        fill="none"
        stroke="rgb(226,232,240)"
        :stroke-width="dims.stroke"
      />
      <circle
        :cx="dims.box / 2"
        :cy="dims.box / 2"
        :r="dims.r"
        fill="none"
        stroke="url(#level-xp-gradient)"
        :stroke-width="dims.stroke"
        stroke-linecap="round"
        :stroke-dasharray="dash"
      />
      <defs>
        <linearGradient id="level-xp-gradient" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#3B82F6" />
          <stop offset="100%" stop-color="#8B5CF6" />
        </linearGradient>
      </defs>
    </svg>
    <div class="absolute inset-0 flex flex-col items-center justify-center">
      <p class="font-black text-slate-900 leading-none" :class="dims.num">{{ level }}</p>
      <p
        v-if="levelTitle && size !== 'sm'"
        class="font-bold text-slate-500 tracking-wide mt-1 leading-none text-center px-1 truncate max-w-full"
        :class="dims.sub"
      >
        {{ levelTitle }}
      </p>
    </div>
  </div>
</template>
