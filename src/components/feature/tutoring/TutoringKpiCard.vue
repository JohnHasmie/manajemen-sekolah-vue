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
    class="bg-bimbel-panel border border-bimbel-border-soft rounded-3xl p-4 hover:border-bimbel-accent/50 transition flex flex-col gap-2"
  >
    <div
      class="w-10 h-10 rounded-xl grid place-items-center"
      :class="{
        'bg-bimbel-accent-dim text-bimbel-accent': tone === 'brand',
        'bg-bimbel-green-dim text-bimbel-green': tone === 'ok',
        'bg-bimbel-amber-dim text-bimbel-amber': tone === 'warn',
        'bg-bimbel-red-dim text-bimbel-red': tone === 'danger',
        'bg-bimbel-accent-dim text-bimbel-accent': tone === 'info',
      }"
    >
      <NavIcon :name="icon" :size="20" />
    </div>
    <div class="text-2xl font-extrabold text-bimbel-text-hi tracking-tight leading-none">
      {{ value }}
    </div>
    <div class="text-[12px] font-bold text-bimbel-text-mid uppercase tracking-wider">
      {{ label }}
    </div>
    <div v-if="hint" class="text-[12px] text-bimbel-text-mid -mt-1">{{ hint }}</div>
  </div>
</template>
