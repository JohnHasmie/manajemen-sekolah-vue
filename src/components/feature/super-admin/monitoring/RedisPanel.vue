<!--
  RedisPanel.vue — Redis & sistem tab.
    · 4 KPI (Memory · Clients · Evicted · Keys db0)
    · CPU/RAM/Disk meters from Netdata (graceful empty state per-meter)
    · Warning card when maxmemory=0 (uncapped)
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { RedisPayload } from '@/services/monitoring.service';

const props = defineProps<{ data: RedisPayload }>();

const meters = computed(() => [
  { label: 'CPU', value: props.data.system.cpu },
  { label: 'RAM', value: props.data.system.ram },
  { label: 'Disk', value: props.data.system.disk },
]);
</script>

<template>
  <div class="space-y-4">
    <!-- 4 KPI -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Memory</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">
          {{ data.redis.memory.used_human ?? '—' }}
        </p>
        <p class="text-xs text-slate-500 mt-0.5">
          peak {{ data.redis.memory.peak_human ?? '—' }}
        </p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Clients</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ data.redis.clients }}</p>
        <p class="text-xs text-slate-500 mt-0.5">
          blocked {{ data.redis.blocked_clients }}
        </p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Evicted</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ data.redis.evicted_keys }}</p>
        <p class="text-xs text-slate-500 mt-0.5">
          rejected {{ data.redis.rejected_connections }}
        </p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Keys db0</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ data.redis.keys_db0 }}</p>
        <p class="text-xs text-slate-500 mt-0.5">
          db1 · {{ data.redis.keys_db1 }}
        </p>
      </div>
    </div>

    <!-- Netdata meters -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-bold text-slate-900">Sistem (Netdata)</p>
        <span class="text-xs font-bold text-slate-500 inline-flex items-center gap-1">
          Netdata <NavIcon name="external-link" :size="12" />
        </span>
      </div>
      <div class="space-y-2">
        <div v-for="m in meters" :key="m.label" class="flex items-center gap-3 text-xs">
          <label class="w-10 text-slate-500">{{ m.label }}</label>
          <div class="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
            <div
              v-if="m.value !== null"
              class="h-full bg-brand-cobalt"
              :style="{ width: `${m.value}%` }"
            />
          </div>
          <span class="w-12 text-right text-slate-700 tabular-nums font-semibold">
            {{ m.value !== null ? `${Math.round(m.value)}%` : '—' }}
          </span>
        </div>
      </div>
    </div>

    <!-- Maxmemory saran -->
    <div
      v-if="data.maxmemory_warning"
      class="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex items-start gap-3"
    >
      <span class="text-amber-600 flex-none mt-0.5">
        <NavIcon name="alert-circle" :size="16" />
      </span>
      <div class="text-xs text-amber-900">
        <b>Saran:</b> Redis maxmemory belum di-cap (0) + noeviction. Queue aman,
        tetapi cap sekaligus set alert Netdata untuk pencegahan.
      </div>
    </div>
  </div>
</template>
