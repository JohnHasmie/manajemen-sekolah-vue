<!--
  NotificationsPanel.vue — Notifikasi & FCM tab body (page-level).
    · 4 KPI: Terkirim · Delivered · Gagal · Dinonaktifkan 24 jam
    · Token donut (aktif / nonaktif)
    · "Pengguna tanpa token aktif" list
    · Tombol drill-down "Buka log pengiriman" → FcmDeliveryLogView

  The drill-down is emitted upward (`open-log-view`) so the parent shell
  can swap the panel body for the log view without leaving the tab.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { NotificationsPayload } from '@/services/monitoring.service';

const props = defineProps<{ data: NotificationsPayload }>();
const emit = defineEmits<{ 'open-log-view': [] }>();

const kpi = computed(() => props.data.kpi);
const tokens = computed(() => props.data.tokens);
const deliveredPct = computed(() => {
  const s = kpi.value.sent;
  return s > 0 ? Math.round((kpi.value.delivered / s) * 100) : 0;
});
const activePct = computed(() => {
  const total = tokens.value.active + tokens.value.inactive;
  return total > 0 ? Math.round((tokens.value.active / total) * 100) : 0;
});
</script>

<template>
  <div class="space-y-4">
    <!-- 4 KPI -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Terkirim</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.sent }}</p>
        <p class="text-xs text-slate-500 mt-0.5">hari ini</p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Delivered</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.delivered }}</p>
        <p class="text-xs text-slate-500 mt-0.5">{{ deliveredPct }}%</p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Gagal</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.failed }}</p>
        <p class="text-xs text-slate-500 mt-0.5">hari ini</p>
      </div>
      <div
        class="rounded-xl p-4"
        :class="kpi.deactivated_24h > 0 ? 'bg-rose-50' : 'bg-slate-50'"
      >
        <p class="text-xs text-slate-500">Dinonaktifkan</p>
        <p
          class="text-2xl font-bold mt-1"
          :class="kpi.deactivated_24h > 0 ? 'text-rose-700' : 'text-slate-900'"
        >
          {{ kpi.deactivated_24h }}
        </p>
        <p class="text-xs text-slate-500 mt-0.5">24 jam</p>
      </div>
    </div>

    <!-- Donut token + drill-down CTA -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-bold text-slate-900">Token perangkat</p>
        <button
          type="button"
          class="text-xs font-bold text-brand-cobalt inline-flex items-center gap-1 hover:underline"
          @click="emit('open-log-view')"
        >
          Buka log pengiriman <NavIcon name="chevron-right" :size="14" />
        </button>
      </div>
      <div class="flex items-center gap-6">
        <div
          class="w-16 h-16 rounded-full"
          :style="{
            background:
              `conic-gradient(#059669 ${activePct}%, #dc2626 0)`,
          }"
        />
        <div class="text-xs space-y-1">
          <div class="flex items-center gap-2">
            <span class="w-2.5 h-2.5 rounded-sm bg-emerald-600"></span>
            {{ tokens.active }} aktif
          </div>
          <div class="flex items-center gap-2">
            <span class="w-2.5 h-2.5 rounded-sm bg-rose-600"></span>
            {{ tokens.inactive }} nonaktif
          </div>
        </div>
      </div>
    </div>

    <!-- Users without token -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <p class="text-sm font-bold text-slate-900 mb-3">Pengguna tanpa token aktif</p>
      <div
        v-if="data.users_without_token.length === 0"
        class="text-xs text-slate-500 py-2 flex items-center gap-2"
      >
        <NavIcon name="check-circle" :size="14" /> Semua pengguna mobile punya token aktif.
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li
          v-for="u in data.users_without_token"
          :key="u.user_id"
          class="py-2 flex items-center justify-between gap-3 bg-rose-50/60 rounded px-2 -mx-2"
        >
          <div class="min-w-0">
            <p class="text-sm font-bold text-slate-900 truncate">{{ u.name }}</p>
            <p class="text-xs text-slate-500 truncate">{{ u.email }}</p>
          </div>
          <span class="text-xs font-bold px-2 py-1 rounded-full bg-rose-100 text-rose-700 flex-none">
            {{ u.reason }}
          </span>
        </li>
      </ul>
    </div>
  </div>
</template>
