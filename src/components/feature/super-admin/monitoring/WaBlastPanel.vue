<!--
  WaBlastPanel.vue — WA Blast tab body (5th tab of SuperAdmin
  monitoring). Cross-tenant view of wa_blast_events (backend MR-B).

  Layout:
    · 4 KPI (Batches 24h · Delivered 24h · Failed 24h · Unique users 30d)
    · Recent batches list — click → drill-down WaBlastLogView filtered
      by batch_id
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { WaBlastMetricsPayload } from '@/services/monitoring.service';

const props = defineProps<{ data: WaBlastMetricsPayload }>();
const emit = defineEmits<{ 'open-log-view': [batchId?: string] }>();

const kpi = computed(() => props.data.kpi);
const batches = computed(() => props.data.recent_batches);

function formatDateTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return '—';
  }
}
</script>

<template>
  <div class="space-y-4">
    <!-- 4 KPI -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Batches</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.batches_24h }}</p>
        <p class="text-xs text-slate-500 mt-0.5">24 jam</p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Terkirim</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.delivered_24h }}</p>
        <p class="text-xs text-slate-500 mt-0.5">24 jam</p>
      </div>
      <div
        class="rounded-xl p-4"
        :class="kpi.failed_24h > 0 ? 'bg-rose-50' : 'bg-slate-50'"
      >
        <p class="text-xs text-slate-500">Gagal</p>
        <p
          class="text-2xl font-bold mt-1"
          :class="kpi.failed_24h > 0 ? 'text-rose-700' : 'text-slate-900'"
        >
          {{ kpi.failed_24h }}
        </p>
        <p class="text-xs text-slate-500 mt-0.5">24 jam</p>
      </div>
      <div class="bg-slate-50 rounded-xl p-4">
        <p class="text-xs text-slate-500">Guru unik</p>
        <p class="text-2xl font-bold text-slate-900 mt-1">{{ kpi.unique_users_30d }}</p>
        <p class="text-xs text-slate-500 mt-0.5">30 hari</p>
      </div>
    </div>

    <!-- Recent batches -->
    <div class="bg-white border border-slate-100 rounded-2xl shadow-sm">
      <div class="flex items-center justify-between p-4 border-b border-slate-100">
        <p class="text-sm font-bold text-slate-900">Batch terbaru</p>
        <button
          type="button"
          class="text-xs font-bold text-brand-cobalt inline-flex items-center gap-1 hover:underline"
          @click="emit('open-log-view')"
        >
          Semua log <NavIcon name="chevron-right" :size="14" />
        </button>
      </div>
      <div
        v-if="batches.length === 0"
        class="p-6 text-center text-xs text-slate-500 flex items-center justify-center gap-2"
      >
        <NavIcon name="check-circle" :size="14" />
        Belum ada blast dijalankan.
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li
          v-for="b in batches"
          :key="b.batch_id"
          class="p-3 hover:bg-slate-50 cursor-pointer"
          @click="emit('open-log-view', b.batch_id)"
        >
          <div class="flex items-center justify-between gap-3 flex-wrap">
            <div class="min-w-0 flex-1">
              <p class="text-sm font-bold text-slate-900 truncate">
                {{ b.school_name ?? '(tanpa sekolah)' }}
              </p>
              <p class="text-xs text-slate-500 mt-0.5">
                {{ formatDateTime(b.started_at) }}
                <template v-if="b.initiated_by_name">
                  · oleh {{ b.initiated_by_name }}
                </template>
              </p>
            </div>
            <div class="flex flex-wrap gap-1.5 text-xs">
              <span class="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 font-bold">
                {{ b.delivered }}
              </span>
              <span
                v-if="b.failed > 0"
                class="px-2 py-0.5 rounded-full bg-rose-100 text-rose-700 font-bold"
              >
                {{ b.failed }}
              </span>
              <span
                v-if="b.queued > 0"
                class="px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 font-bold"
              >
                {{ b.queued }}
              </span>
              <span class="px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 font-bold">
                / {{ b.total }}
              </span>
            </div>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>
