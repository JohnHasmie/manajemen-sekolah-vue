<!--
  OverviewPanel.vue — Overview tab body. Mockup order: 4 KPI tile row,
  throughput 30-menit bars, then a red incident banner when there was a
  token deactivation today (clickable to jump straight into Notifikasi).

  The banner emits `switch-tab` upward — the parent view knows how to
  activate the Notifikasi tab. Keeps the panel decoupled from the shell's
  tab state.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { OverviewPayload } from '@/services/monitoring.service';

const props = defineProps<{ data: OverviewPayload }>();
const emit = defineEmits<{ 'switch-tab': [tab: string] }>();

const kpi = computed(() => props.data.overview.kpi);
const incident = computed(() => props.data.overview.incident);
const bars = computed(() => props.data.overview.throughput_30m);

const maxJobs = computed(() =>
  Math.max(1, ...bars.value.map((b) => b.jobs)),
);
</script>

<template>
  <div class="space-y-4">
    <!-- 4 KPI tiles -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Jobs / menit</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.jobs_per_minute }}</p>
        <p class="text-xs text-slate-500 mt-0.5">throughput</p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Pending</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.pending }}</p>
        <p class="text-xs text-slate-500 mt-0.5">antrean</p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Failed 24 jam</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.failed_24h }}</p>
        <p class="text-xs text-slate-500 mt-0.5">gagal</p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">FCM terkirim</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.fcm_delivered_today }}</p>
        <p class="text-xs text-slate-500 mt-0.5">hari ini</p>
      </div>
    </div>

    <!-- Throughput 30-menit -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-bold text-slate-900">Throughput 30 menit</p>
        <a
          href="/horizon"
          target="_blank"
          rel="noopener"
          class="text-xs font-bold text-brand-cobalt inline-flex items-center gap-1 hover:underline"
        >
          Horizon <NavIcon name="external-link" :size="12" />
        </a>
      </div>
      <div v-if="bars.length === 0" class="text-xs text-slate-500 py-6 text-center">
        Belum ada data throughput.
      </div>
      <div v-else class="flex items-end gap-1 h-20">
        <div
          v-for="(b, i) in bars"
          :key="i"
          class="flex-1 bg-brand-cobalt/85 rounded-t"
          :style="{ height: `${Math.max(4, (b.jobs / maxJobs) * 100)}%` }"
          :title="`${b.minute} · ${b.jobs} jobs/min`"
        />
      </div>
    </div>

    <!-- Insiden banner -->
    <button
      v-if="incident"
      type="button"
      class="w-full bg-rose-50 border border-rose-200 rounded-2xl p-4 flex items-start gap-3 text-left hover:bg-rose-100 transition-colors"
      @click="emit('switch-tab', 'notifikasi')"
    >
      <span class="text-rose-600 flex-none mt-0.5">
        <NavIcon name="alert-triangle" :size="18" />
      </span>
      <div class="flex-1">
        <p class="text-sm font-bold text-rose-900">{{ incident.message }}</p>
        <p class="text-xs text-rose-700 mt-0.5">
          Push tidak terkirim walau notifikasi dibuat. Buka tab Notifikasi &amp; FCM.
        </p>
      </div>
      <NavIcon name="chevron-right" :size="16" class="text-rose-500 flex-none mt-0.5" />
    </button>
  </div>
</template>
