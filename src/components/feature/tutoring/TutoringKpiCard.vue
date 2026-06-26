<!--
  TutoringKpiCard — single KPI tile (icon · value · uppercase label ·
  optional hint). Mirrors the Flutter `TutoringKpiCard` AND the
  existing StatSummaryCard's visual.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

withDefaults(
  defineProps<{
    icon: string;
    value: string | number;
    label: string;
    hint?: string;
    tone?: 'brand' | 'ok' | 'warn' | 'danger' | 'info';
  }>(),
  { tone: 'brand' },
);
</script>

<template>
  <div
    class="bg-tutoring-panel border border-tutoring-border-soft rounded-3xl p-4 hover:border-tutoring-accent/50 transition flex flex-col gap-2"
  >
    <div
      class="w-10 h-10 rounded-xl grid place-items-center"
      :class="{
        'bg-tutoring-accent-dim text-tutoring-accent': tone === 'brand',
        'bg-tutoring-green-dim text-tutoring-green': tone === 'ok',
        'bg-tutoring-amber-dim text-tutoring-amber': tone === 'warn',
        'bg-tutoring-red-dim text-tutoring-red': tone === 'danger',
        'bg-tutoring-accent-dim text-tutoring-accent': tone === 'info',
      }"
    >
      <NavIcon :name="icon" :size="20" />
    </div>
    <div class="text-2xl font-extrabold text-tutoring-text-hi tracking-tight leading-none">
      {{ value }}
    </div>
    <div class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
      {{ label }}
    </div>
    <div v-if="hint" class="text-[12px] text-tutoring-text-mid -mt-1">{{ hint }}</div>
  </div>
</template>
