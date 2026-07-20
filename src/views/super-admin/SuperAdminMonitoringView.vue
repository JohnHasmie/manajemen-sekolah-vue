<!--
  SuperAdminMonitoringView.vue — /super-admin/monitoring

  Single pane of glass consolidating everything an operator needs to
  answer "is the system healthy right now?" — mirrors the approved
  mockup box-for-box (6 tabs + drill-down).

  Health strip is always visible above the tab bar so the top of the
  layout answers the question at a glance without switching tabs.

  Auto-refresh: light poll every 15 seconds so numbers stay live for a
  passive observer. Poll pauses when the tab is inactive to save the
  backend from pointless queries.

  Auth: gated by `meta.superAdmin` — non-super-admin gets redirected
  by the router guard (router/index.ts).
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import HealthStrip from '@/components/feature/super-admin/monitoring/HealthStrip.vue';
import OverviewPanel from '@/components/feature/super-admin/monitoring/OverviewPanel.vue';
import QueuePanel from '@/components/feature/super-admin/monitoring/QueuePanel.vue';
import RedisPanel from '@/components/feature/super-admin/monitoring/RedisPanel.vue';
import NotificationsPanel from '@/components/feature/super-admin/monitoring/NotificationsPanel.vue';
import FcmDeliveryLogView from '@/components/feature/super-admin/monitoring/FcmDeliveryLogView.vue';
import ErrorsPanel from '@/components/feature/super-admin/monitoring/ErrorsPanel.vue';
import AlertsPanel from '@/components/feature/super-admin/monitoring/AlertsPanel.vue';
import {
  MonitoringService,
  type AlertSettingsPayload,
  type ErrorsPayload,
  type HealthStrip as HealthStripData,
  type NotificationsPayload,
  type OverviewPayload,
  type QueuePayload,
  type RedisPayload,
} from '@/services/monitoring.service';

type Tab = 'overview' | 'queue' | 'redis' | 'notifikasi' | 'error' | 'alert';

const TABS: Array<{ key: Tab; label: string }> = [
  { key: 'overview', label: 'Overview' },
  { key: 'queue', label: 'Queue & jobs' },
  { key: 'redis', label: 'Redis & sistem' },
  { key: 'notifikasi', label: 'Notifikasi & FCM' },
  { key: 'error', label: 'Error & log' },
  { key: 'alert', label: 'Alert' },
];

const activeTab = ref<Tab>('overview');
const showFcmLog = ref(false);

const health = ref<HealthStripData | null>(null);
const overview = ref<OverviewPayload | null>(null);
const queue = ref<QueuePayload | null>(null);
const redis = ref<RedisPayload | null>(null);
const notifications = ref<NotificationsPayload | null>(null);
const errors = ref<ErrorsPayload | null>(null);
const alerts = ref<AlertSettingsPayload | null>(null);

const loading = ref(false);
const lastRefreshed = ref<Date | null>(null);

let pollTimer: number | undefined;

async function loadAll() {
  loading.value = true;
  try {
    // The strip lives above the tab bar so it must always be fresh.
    const [h, ov, q, r, n, e, a] = await Promise.all([
      MonitoringService.getHealthStrip(),
      MonitoringService.getOverview(),
      MonitoringService.getQueue(),
      MonitoringService.getRedis(),
      MonitoringService.getNotifications(),
      MonitoringService.getErrors(),
      MonitoringService.getAlertSettings(),
    ]);
    health.value = h;
    overview.value = ov;
    queue.value = q;
    redis.value = r;
    notifications.value = n;
    errors.value = e;
    alerts.value = a;
    lastRefreshed.value = new Date();
  } finally {
    loading.value = false;
  }
}

function startPolling() {
  stopPolling();
  pollTimer = window.setInterval(() => {
    if (!document.hidden) void loadAll();
  }, 15_000);
}

function stopPolling() {
  if (pollTimer !== undefined) {
    window.clearInterval(pollTimer);
    pollTimer = undefined;
  }
}

onMounted(() => {
  void loadAll();
  startPolling();
});

onBeforeUnmount(() => {
  stopPolling();
});

function switchTab(next: Tab | string) {
  const found = TABS.find((t) => t.key === next);
  if (found) {
    activeTab.value = found.key;
    showFcmLog.value = false;
  }
}

const refreshedLabel = computed(() => {
  if (!lastRefreshed.value) return '';
  return lastRefreshed.value.toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
});
</script>

<template>
  <div class="space-y-4 pb-8">
    <!-- Header -->
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div class="flex items-center gap-3 min-w-0">
        <span class="w-9 h-9 rounded-lg grid place-items-center bg-brand-cobalt/10 text-brand-cobalt flex-none">
          <NavIcon name="activity" :size="18" />
        </span>
        <div class="min-w-0">
          <h1 class="text-base font-black text-slate-900">Pusat kendali sistem</h1>
          <p class="text-xs text-slate-500">SuperAdmin · monitoring</p>
        </div>
      </div>
      <div class="flex items-center gap-2 text-xs text-slate-500">
        <span
          class="w-1.5 h-1.5 rounded-full"
          :class="loading ? 'bg-amber-500 animate-pulse' : 'bg-emerald-500'"
        ></span>
        <span v-if="lastRefreshed">refresh {{ refreshedLabel }}</span>
        <span v-else>memuat…</span>
      </div>
    </div>

    <!-- Health strip (always visible) -->
    <HealthStrip v-if="health" :data="health" />

    <!-- Tab bar -->
    <div class="border-b border-slate-200 flex gap-1 overflow-x-auto">
      <button
        v-for="t in TABS"
        :key="t.key"
        type="button"
        class="px-3 py-2 text-sm border-b-2 transition-colors whitespace-nowrap"
        :class="activeTab === t.key
          ? 'border-brand-cobalt text-slate-900 font-bold'
          : 'border-transparent text-slate-500 hover:text-slate-900'"
        @click="switchTab(t.key)"
      >
        {{ t.label }}
      </button>
    </div>

    <!-- Panels -->
    <template v-if="activeTab === 'overview' && overview">
      <OverviewPanel :data="overview" @switch-tab="switchTab" />
    </template>

    <template v-else-if="activeTab === 'queue' && queue">
      <QueuePanel :data="queue" />
    </template>

    <template v-else-if="activeTab === 'redis' && redis">
      <RedisPanel :data="redis" />
    </template>

    <template v-else-if="activeTab === 'notifikasi'">
      <FcmDeliveryLogView
        v-if="showFcmLog"
        @back="showFcmLog = false"
      />
      <NotificationsPanel
        v-else-if="notifications"
        :data="notifications"
        @open-log-view="showFcmLog = true"
      />
    </template>

    <template v-else-if="activeTab === 'error' && errors">
      <ErrorsPanel :data="errors" />
    </template>

    <template v-else-if="activeTab === 'alert' && alerts">
      <AlertsPanel :data="alerts" />
    </template>

    <!-- Skeleton — mirrors the tab area layout so no reflow when data lands. -->
    <div v-else class="space-y-3">
      <div class="h-24 bg-slate-100 rounded-2xl animate-pulse" />
      <div class="h-40 bg-slate-100 rounded-2xl animate-pulse" />
    </div>
  </div>
</template>
