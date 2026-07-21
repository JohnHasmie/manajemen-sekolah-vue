<!--
  WaBlastLogView.vue — per-message drill-down for the WA Blast tab.
  Mirror of FcmDeliveryLogView (MR-5). Optional `batchId` prop scopes
  the log to a single batch (from WaBlastPanel row click) — empty
  batchId = cross-batch view with date range.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  MonitoringService,
  type WaBlastLogFilters,
  type WaBlastLogRow,
  type WaBlastLogsPayload,
  type WaBlastRole,
} from '@/services/monitoring.service';

const ROLE_LABEL: Record<WaBlastRole, string> = {
  teacher: 'Guru',
  staff: 'Staf',
  parent: 'Wali',
};

const props = defineProps<{ batchId?: string }>();
const emit = defineEmits<{ back: [] }>();

const payload = ref<WaBlastLogsPayload>({
  data: [],
  meta: { current_page: 1, per_page: 50, total: 0, last_page: 1 },
  summary: { delivered: 0, failed: 0, queued: 0 },
});
const loading = ref(false);
const search = ref('');
const statusFilter = ref<'all' | 'delivered' | 'failed'>('all');
const roleFilter = ref<'all' | WaBlastRole>('all');
const dateRange = ref<'today' | '7d' | '30d'>('today');

async function load() {
  loading.value = true;
  try {
    const filters: WaBlastLogFilters = { per_page: 50 };
    if (props.batchId) filters.batch_id = props.batchId;
    const term = search.value.trim();
    if (term) filters.phone = term;
    if (statusFilter.value !== 'all') {
      filters.status = statusFilter.value;
    }
    if (roleFilter.value !== 'all') {
      filters.role = roleFilter.value;
    }
    // Date range is IGNORED when scoping to a single batch — the batch
    // is coherent regardless of when it was fired.
    if (!props.batchId) {
      const now = new Date();
      if (dateRange.value === 'today') {
        filters.from = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      } else if (dateRange.value === '7d') {
        filters.from = new Date(now.getTime() - 7 * 864e5).toISOString();
      } else {
        filters.from = new Date(now.getTime() - 30 * 864e5).toISOString();
      }
    }
    payload.value = await MonitoringService.getWaBlastLogs(filters);
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  void load();
});

let searchTimer: number | undefined;
watch(search, () => {
  if (searchTimer) window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => void load(), 250);
});
watch([statusFilter, roleFilter, dateRange], () => void load());
watch(() => props.batchId, () => void load());

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
  } catch {
    return '—';
  }
}

function rowClass(row: WaBlastLogRow): string {
  if (row.status === 'failed') return 'bg-rose-50 border-rose-100';
  return '';
}

function statusPill(status: WaBlastLogRow['status']): { klass: string; label: string; icon: string } {
  if (status === 'delivered') return {
    klass: 'bg-emerald-100 text-emerald-700', label: 'terkirim', icon: 'check',
  };
  if (status === 'queued') return {
    klass: 'bg-amber-100 text-amber-700', label: 'antre', icon: 'clock',
  };
  return { klass: 'bg-rose-100 text-rose-700', label: 'gagal', icon: 'x' };
}

const rows = computed(() => payload.value.data);
const summary = computed(() => payload.value.summary);
</script>

<template>
  <div class="space-y-4">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 text-xs text-slate-500">
      <button
        type="button"
        class="hover:text-slate-900 font-bold"
        @click="emit('back')"
      >
        WA Blast
      </button>
      <NavIcon name="chevron-right" :size="12" />
      <span class="text-slate-700">
        {{ batchId ? `Batch ${batchId.slice(0, 8)}…` : 'Semua log' }}
      </span>
    </div>

    <!-- Filter bar -->
    <div class="flex flex-wrap gap-2 items-center">
      <div class="relative flex-1 min-w-[200px]">
        <NavIcon
          name="search"
          :size="14"
          class="absolute left-3 top-2.5 text-slate-400"
        />
        <input
          v-model="search"
          type="text"
          placeholder="Cari nomor HP (4 digit terakhir)…"
          class="w-full pl-9 pr-3 py-2 text-sm border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none"
        />
      </div>
      <button
        type="button"
        class="px-3 py-1.5 text-xs font-bold rounded-full border transition-colors"
        :class="statusFilter === 'all'
          ? 'bg-brand-cobalt/10 text-brand-cobalt border-brand-cobalt/30'
          : 'border-slate-200 text-slate-600 hover:bg-slate-50'"
        @click="statusFilter = 'all'"
      >
        Semua
      </button>
      <button
        type="button"
        class="px-3 py-1.5 text-xs font-bold rounded-full border transition-colors"
        :class="statusFilter === 'delivered'
          ? 'bg-brand-cobalt/10 text-brand-cobalt border-brand-cobalt/30'
          : 'border-slate-200 text-slate-600 hover:bg-slate-50'"
        @click="statusFilter = 'delivered'"
      >
        Terkirim
      </button>
      <button
        type="button"
        class="px-3 py-1.5 text-xs font-bold rounded-full border transition-colors"
        :class="statusFilter === 'failed'
          ? 'bg-brand-cobalt/10 text-brand-cobalt border-brand-cobalt/30'
          : 'border-slate-200 text-slate-600 hover:bg-slate-50'"
        @click="statusFilter = 'failed'"
      >
        Gagal
      </button>
      <select
        v-model="roleFilter"
        class="px-3 py-1.5 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none"
      >
        <option value="all">Semua peran</option>
        <option value="teacher">Guru</option>
        <option value="staff">Staf</option>
        <option value="parent">Wali</option>
      </select>
      <select
        v-if="!batchId"
        v-model="dateRange"
        class="px-3 py-1.5 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none"
      >
        <option value="today">Hari ini</option>
        <option value="7d">7 hari</option>
        <option value="30d">30 hari</option>
      </select>
    </div>

    <!-- Stat pills -->
    <div class="flex flex-wrap gap-2">
      <span class="text-xs bg-slate-50 px-3 py-1.5 rounded-lg">
        <b class="text-slate-900">{{ summary.delivered }}</b> terkirim
      </span>
      <span class="text-xs bg-slate-50 px-3 py-1.5 rounded-lg">
        <b class="text-rose-700">{{ summary.failed }}</b> gagal
      </span>
      <span class="text-xs bg-slate-50 px-3 py-1.5 rounded-lg">
        <b class="text-amber-700">{{ summary.queued }}</b> antre
      </span>
    </div>

    <!-- Log list -->
    <div class="bg-white border border-slate-100 rounded-2xl overflow-hidden shadow-sm">
      <div v-if="loading" class="p-6 text-center text-xs text-slate-500">
        Memuat log…
      </div>
      <div v-else-if="rows.length === 0" class="p-6 text-center text-xs text-slate-500">
        Tidak ada log untuk filter ini.
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li
          v-for="row in rows"
          :key="row.id"
          class="flex items-start gap-3 p-3 border-l-2"
          :class="rowClass(row)"
        >
          <div class="w-10 text-xs text-slate-500 pt-0.5 font-mono tabular-nums flex-none">
            {{ formatTime(row.created_at) }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-bold text-slate-900 break-words">
              {{ row.recipient_name }}
              <span class="text-xs text-slate-400 font-mono font-normal ml-1">
                {{ row.recipient_phone_masked }}
              </span>
            </p>
            <p class="text-xs text-slate-500 mt-0.5 font-mono">
              {{ row.school_name ?? '(tanpa sekolah)' }} · {{ row.notification_type }}
              <span
                v-if="row.recipient_role"
                class="ml-1 px-1.5 py-0.5 rounded bg-slate-100 text-slate-700 font-sans font-bold text-[10px] uppercase"
              >
                {{ ROLE_LABEL[row.recipient_role] }}
              </span>
            </p>
            <p
              v-if="row.error_message"
              class="text-xs mt-1 flex items-start gap-1 text-rose-700"
            >
              <NavIcon name="alert-circle" :size="12" class="flex-none mt-0.5" />
              <span>{{ row.error_message }}</span>
            </p>
          </div>
          <span
            class="text-xs font-bold px-2.5 py-1 rounded-full flex-none inline-flex items-center gap-1"
            :class="statusPill(row.status).klass"
          >
            <NavIcon :name="statusPill(row.status).icon" :size="12" />
            {{ statusPill(row.status).label }}
          </span>
        </li>
      </ul>
    </div>

    <p class="text-xs text-slate-400 flex items-center gap-1.5">
      <NavIcon name="info-circle" :size="12" />
      Retensi 30 hari — baris otomatis dihapus setelah itu.
    </p>
  </div>
</template>
