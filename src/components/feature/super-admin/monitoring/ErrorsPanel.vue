<!--
  ErrorsPanel.vue — Error & log tab body.
    · Recent exceptions from telescope_entries (deep-link /telescope)
    · Slow queries > threshold (config-driven, default 500ms)
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';
import type { ErrorsPayload } from '@/services/monitoring.service';

defineProps<{ data: ErrorsPayload }>();
</script>

<template>
  <div class="space-y-4">
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-bold text-slate-900">Exception terbaru</p>
        <a
          href="/telescope"
          target="_blank"
          rel="noopener"
          class="text-xs font-bold text-brand-cobalt inline-flex items-center gap-1 hover:underline"
        >
          Telescope <NavIcon name="external-link" :size="12" />
        </a>
      </div>
      <div
        v-if="data.exceptions.length === 0"
        class="text-xs text-slate-500 py-2 flex items-center gap-2"
      >
        <NavIcon name="shield-check" :size="14" /> Tidak ada exception 1 jam terakhir.
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li v-for="e in data.exceptions" :key="e.uuid" class="py-2">
          <p class="text-sm font-bold text-slate-900">{{ e.class }}</p>
          <p class="text-xs text-slate-500 mt-0.5">{{ e.created_at }}</p>
          <p class="text-xs text-rose-600 mt-1 font-mono break-words">{{ e.message }}</p>
          <p
            v-if="e.file"
            class="text-xs text-slate-400 mt-0.5 font-mono truncate"
          >
            {{ e.file }}<template v-if="e.line">:{{ e.line }}</template>
          </p>
        </li>
      </ul>
    </div>

    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <p class="text-sm font-bold text-slate-900 mb-3">Query lambat (&gt; 500 ms)</p>
      <div v-if="data.slow_queries.length === 0" class="text-xs text-slate-500 py-2 flex items-center gap-2">
        <NavIcon name="check-circle" :size="14" /> Tidak ada query lambat.
      </div>
      <table v-else class="w-full text-xs">
        <thead>
          <tr class="text-slate-500 text-left border-b border-slate-100">
            <th class="py-2 font-semibold">Query</th>
            <th class="py-2 font-semibold text-right">Waktu</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="q in data.slow_queries" :key="q.uuid" class="border-b border-slate-50">
            <td class="py-2 pr-2 font-mono text-slate-700 break-words">{{ q.sql }}</td>
            <td class="py-2 text-right tabular-nums whitespace-nowrap">{{ Math.round(q.time_ms) }} ms</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
