<!--
  QueuePanel.vue — Queue & jobs tab.
    · per-queue table (Pending · Wait · Proses)
    · supervisor + worker pills
    · failed jobs 24 jam list (or an empty-state)
  Deep-link `Horizon ↗` for retry / stack inspection.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';
import type { QueuePayload } from '@/services/monitoring.service';

defineProps<{ data: QueuePayload }>();

function statusPill(status: string): string {
  if (status === 'running') return 'bg-emerald-100 text-emerald-700';
  if (status === 'paused') return 'bg-amber-100 text-amber-700';
  return 'bg-rose-100 text-rose-700';
}
</script>

<template>
  <div class="space-y-4">
    <!-- Queue table -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-bold text-slate-900">Antrean per queue</p>
        <a
          href="/horizon"
          target="_blank"
          rel="noopener"
          class="text-xs font-bold text-brand-cobalt inline-flex items-center gap-1 hover:underline"
        >
          Horizon <NavIcon name="external-link" :size="12" />
        </a>
      </div>
      <div v-if="data.queues.length === 0" class="text-xs text-slate-500 py-4">
        Belum ada queue aktif.
      </div>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="text-xs text-slate-500 text-left border-b border-slate-100">
            <th class="py-2 font-semibold">Queue</th>
            <th class="py-2 font-semibold">Pending</th>
            <th class="py-2 font-semibold">Wait</th>
            <th class="py-2 font-semibold">Proses</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="q in data.queues" :key="q.name" class="border-b border-slate-50">
            <td class="py-2 font-mono">{{ q.name }}</td>
            <td class="py-2 tabular-nums">{{ q.pending }}</td>
            <td class="py-2 tabular-nums">{{ q.wait_seconds }} dtk</td>
            <td class="py-2 tabular-nums">{{ q.processes }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Supervisor + worker pills -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <p class="text-sm font-bold text-slate-900 mb-3">Supervisor &amp; worker</p>
      <div v-if="data.supervisors.length === 0" class="text-xs text-slate-500 py-2">
        Tidak ada supervisor terdaftar.
      </div>
      <div v-else class="flex flex-wrap gap-2">
        <span
          v-for="s in data.supervisors"
          :key="s.name"
          class="inline-flex items-center gap-2 text-xs font-bold px-3 py-1.5 rounded-full"
          :class="statusPill(s.status)"
        >
          <NavIcon name="cpu" :size="14" />
          {{ s.name }} · {{ s.status }} · {{ s.processes }} proc
        </span>
      </div>
    </div>

    <!-- Failed jobs -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <p class="text-sm font-bold text-slate-900 mb-3">Failed jobs 24 jam</p>
      <div
        v-if="data.failed_jobs.length === 0"
        class="text-xs text-slate-500 py-3 flex items-center gap-2"
      >
        <NavIcon name="smile" :size="14" /> Tidak ada job gagal.
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li v-for="j in data.failed_jobs" :key="j.id ?? j.name" class="py-2">
          <p class="text-sm font-bold text-slate-900">{{ j.name }}</p>
          <p class="text-xs text-slate-500 mt-0.5">
            {{ j.queue }} · {{ j.failed_at }}
          </p>
          <p v-if="j.exception" class="text-xs text-rose-600 mt-1 font-mono">
            {{ j.exception }}
          </p>
        </li>
      </ul>
    </div>
  </div>
</template>
