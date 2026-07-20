<!--
  HealthStrip.vue — the 6-chip lampu status row that sits ABOVE the tab
  bar of the SuperAdmin monitoring dashboard. Kept as its own component
  because it renders in every tab (always visible), so we don't want each
  panel re-implementing the pill row.

  Chip semantics — matches the mockup:
    · up   = green pill  → operationally healthy
    · warn = amber pill  → non-blocking signal (e.g. 1 token nonaktif hari ini)
    · down = red pill    → outage; alert engine likely already paged

  Data from GET /super-admin/monitoring/health-strip. The parent view
  polls the endpoint on refresh; this component is purely presentational.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { HealthStrip as HealthStripData, HealthCheckStatus } from '@/services/monitoring.service';

const props = defineProps<{ data: HealthStripData }>();

interface ChipDef {
  key: keyof HealthStripData;
  icon: string;
  label: string;
}

const CHIPS: ChipDef[] = [
  { key: 'database', icon: 'database', label: 'Database' },
  { key: 'redis', icon: 'server', label: 'Redis' },
  { key: 'queue', icon: 'layers', label: 'Queue' },
  { key: 'scheduler', icon: 'clock', label: 'Scheduler' },
  { key: 'worker', icon: 'cpu', label: 'Worker' },
  { key: 'fcm_token', icon: 'bell', label: 'FCM token' },
];

function statusClass(status: HealthCheckStatus): string {
  if (status === 'up') return 'bg-emerald-50 text-emerald-700';
  if (status === 'warn') return 'bg-amber-50 text-amber-700';
  return 'bg-rose-50 text-rose-700';
}

function statusLabel(status: HealthCheckStatus, detail?: string): string {
  if (status === 'up') return 'OK';
  if (status === 'warn') return detail ?? 'perhatian';
  return detail ?? 'gagal';
}

const chips = computed(() =>
  CHIPS.map((c) => {
    const check = props.data[c.key];
    return {
      ...c,
      status: check?.status ?? 'down',
      statusLabel: statusLabel(check?.status ?? 'down', check?.detail),
      klass: statusClass(check?.status ?? 'down'),
    };
  }),
);
</script>

<template>
  <div class="flex flex-wrap gap-2">
    <span
      v-for="chip in chips"
      :key="chip.key"
      class="inline-flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-full"
      :class="chip.klass"
    >
      <NavIcon :name="chip.icon" :size="14" />
      {{ chip.label }}
      <b class="font-bold">{{ chip.statusLabel }}</b>
    </span>
  </div>
</template>
