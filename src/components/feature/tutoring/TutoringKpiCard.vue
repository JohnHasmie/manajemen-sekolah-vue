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
    class="bg-white border border-slate-100 rounded-3xl p-4 hover:border-slate-300 hover:shadow-md hover:shadow-slate-100/60 transition flex flex-col gap-2"
  >
    <div
      class="w-10 h-10 rounded-xl grid place-items-center"
      :class="{
        'bg-role-admin-soft text-role-admin': tone === 'brand',
        'bg-status-success-soft text-status-success': tone === 'ok',
        'bg-status-warning-soft text-status-warning': tone === 'warn',
        'bg-status-danger-soft text-status-danger': tone === 'danger',
        'bg-status-info-soft text-status-info': tone === 'info',
      }"
    >
      <NavIcon :name="icon" :size="20" />
    </div>
    <div class="text-2xl font-extrabold text-slate-900 tracking-tight leading-none">
      {{ value }}
    </div>
    <div class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
      {{ label }}
    </div>
    <div v-if="hint" class="text-[11px] text-slate-500 -mt-1">{{ hint }}</div>
  </div>
</template>
