<!--
  FcmDeliveryLogView.vue — the per-message "Log pengiriman" drill-down
  inside the Notifikasi & FCM tab.

  Mockup layout (top → bottom):
    · breadcrumb "Notifikasi & FCM › Log pengiriman"
    · filter bar (search email/token, status chips, date range)
    · 3 stat pill (Terkirim / Gagal / Token dimatikan)
    · list per-pesan (waktu · email + token prefix + tipe · status pill;
      failed rows have an error line beneath; `deactivated` rows are
      highlighted in rose)
    · footer note "Retensi 14 hari"

  Emits `back` when the user clicks the breadcrumb crumb — the parent
  swaps the drill-down out for NotificationsPanel again.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { MonitoringService, type FcmLogsPayload, type FcmLogFilters, type FcmLogRow } from '@/services/monitoring.service';

const emit = defineEmits<{ back: [] }>();

const payload = ref<FcmLogsPayload>({
  data: [],
  meta: { current_page: 1, per_page: 50, total: 0, last_page: 1 },
  summary: { delivered: 0, failed: 0, deactivated: 0, no_token: 0 },
});
const loading = ref(false);

const search = ref('');
const statusFilter = ref<'all' | 'delivered' | 'failed'>('all');
const dateRange = ref<'today' | '7d' | '14d'>('today');

async function load() {
  loading.value = true;
  try {
    const filters: FcmLogFilters = { per_page: 50 };
    // Search is applied on either email OR token; the BE looks at both.
    const term = search.value.trim();
    if (term) {
      // Heuristic: contains '@' → email; else token prefix.
      if (term.includes('@')) filters.email = term;
      else filters.token = term;
    }
    if (statusFilter.value !== 'all') {
      // "failed" chip includes token-deactivations from the ops POV
      // (mockup: a token deactivation is visually a fail).
      filters.status = statusFilter.value === 'failed'
        ? 'failed,deactivated,no_token'
        : 'delivered';
    }
    const now = new Date();
    if (dateRange.value === 'today') {
      filters.from = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
    } else if (dateRange.value === '7d') {
      filters.from = new Date(now.getTime() - 7 * 864e5).toISOString();
    } else {
      filters.from = new Date(now.getTime() - 14 * 864e5).toISOString();
    }

    payload.value = await MonitoringService.getFcmLogs(filters);
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  void load();
});

// Debounce the search input so a fast typist doesn't hammer the endpoint.
let searchTimer: number | undefined;
watch(search, () => {
  if (searchTimer) window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => void load(), 250);
});
watch([statusFilter, dateRange], () => void load());

function formatTime(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
  } catch {
    return '—';
  }
}

function rowClass(row: FcmLogRow): string {
  if (row.status === 'deactivated') return 'bg-rose-50 border-rose-100';
  return '';
}

function statusPill(status: FcmLogRow['status']): { klass: string; label: string; icon: string } {
  if (status === 'delivered') return {
    klass: 'bg-emerald-100 text-emerald-700', label: 'terkirim', icon: 'check',
  };
  if (status === 'deactivated') return {
    klass: 'bg-rose-100 text-rose-700', label: 'gagal', icon: 'x',
  };
  if (status === 'no_token') return {
    klass: 'bg-amber-100 text-amber-700', label: 'tanpa token', icon: 'alert-circle',
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
        Notifikasi &amp; FCM
      </button>
      <NavIcon name="chevron-right" :size="12" />
      <span class="text-slate-700">Log pengiriman</span>
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
          placeholder="Cari email atau token…"
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
        v-model="dateRange"
        class="px-3 py-1.5 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none"
      >
        <option value="today">Hari ini</option>
        <option value="7d">7 hari</option>
        <option value="14d">14 hari</option>
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
        <b class="text-amber-700">{{ summary.deactivated }}</b> token dimatikan
      </span>
    </div>

    <!-- Log list -->
    <div class="bg-white border border-slate-100 rounded-2xl overflow-hidden shadow-sm">
      <div v-if="loading" class="p-6 text-center text-xs text-slate-500">
        Memuat log…
      </div>
      <div v-else-if="rows.length === 0" class="p-6 text-center text-xs text-slate-500">
        Tidak ada log pengiriman untuk filter ini.
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
              {{ row.email ?? '(tanpa akun)' }}
              <span v-if="row.token_prefix" class="text-xs text-slate-400 font-mono font-normal ml-1">
                {{ row.token_prefix }}…
              </span>
            </p>
            <p class="text-xs text-slate-500 mt-0.5 font-mono">
              {{ row.notification_type ?? '(tanpa tipe)' }} · {{ row.device_type ?? '—' }}
            </p>
            <p
              v-if="row.error_code || row.error_message"
              class="text-xs mt-1 flex items-start gap-1"
              :class="row.status === 'deactivated' ? 'text-rose-700' : 'text-amber-700'"
            >
              <NavIcon
                :name="row.status === 'deactivated' ? 'plug' : 'alert-circle'"
                :size="12"
                class="flex-none mt-0.5"
              />
              <span>
                <b v-if="row.error_code">{{ row.error_code }}</b>
                <template v-if="row.error_code && row.error_message"> · </template>
                {{ row.error_message }}
              </span>
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
      <NavIcon name="info" :size="12" />
      Retensi 14 hari — baris otomatis dihapus setelah itu.
    </p>
  </div>
</template>
