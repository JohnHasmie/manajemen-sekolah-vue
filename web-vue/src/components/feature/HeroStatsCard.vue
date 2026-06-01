<!--
  HeroStatsCard.vue — large gradient KPI card for the top of dashboards.
  Mirrors Flutter's HeroStatsCard in `lib/core/widgets/`.

  Themed by role color via `useRoleColor`.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useRoleColor } from '@/composables/useRoleColor';

withDefaults(
  defineProps<{
    label: string;
    value: string | number;
    sublabel?: string;
    icon?: string;
    trend?: 'up' | 'down' | 'flat';
    trendLabel?: string;
  }>(),
  { sublabel: '', icon: '', trend: undefined, trendLabel: '' },
);

const auth = useAuthStore();
const color = useRoleColor(() => auth.activeRole);

const gradient = computed(() => ({
  backgroundImage: `linear-gradient(135deg, ${color.value.hex} 0%, ${color.value.hex}cc 100%)`,
}));
</script>

<template>
  <div
    class="rounded-card text-white shadow-card p-lg flex items-center gap-md"
    :style="gradient"
  >
    <div
      v-if="icon"
      class="w-12 h-12 rounded-xl bg-white/15 flex items-center justify-center flex-shrink-0"
    >
      <slot name="icon">{{ icon }}</slot>
    </div>

    <div class="flex-1 min-w-0">
      <p class="text-xs uppercase tracking-wider opacity-80">{{ label }}</p>
      <p class="text-3xl font-bold mt-0.5 truncate">{{ value }}</p>
      <p
        v-if="sublabel || trendLabel"
        class="text-xs opacity-90 mt-1 flex items-center gap-1"
      >
        <span v-if="trend === 'up'">▲</span>
        <span v-else-if="trend === 'down'">▼</span>
        <span v-else-if="trend === 'flat'">▬</span>
        {{ trendLabel || sublabel }}
      </p>
    </div>
  </div>
</template>
