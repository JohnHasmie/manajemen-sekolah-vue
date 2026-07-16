<!--
  AdminTeacherEngagementTable.vue — the main table on the admin
  Prestasi page. One row per teacher, with a status dot, level chip,
  streak, 7-day poin, sparkline, and last-active date.

  Sort + search are host-driven; the table just renders the rows it
  gets. Kepsek can click a row to see the teacher's own Prestasi
  view (deferred to MR 7b — for now the row is display-only).
-->
<script setup lang="ts">
import { computed } from 'vue';
import SparklineTinyBar from './SparklineTinyBar.vue';
import type { AdminTeacherEngagementRow, TeacherRowStatus } from '@/services/teacher-progress.service';

const props = defineProps<{
  rows: AdminTeacherEngagementRow[];
  /** Optional filter — hosted search box. Case-insensitive substring on nama. */
  search?: string;
  /** Optional status filter. Empty = show all. */
  statusFilter?: TeacherRowStatus | '';
}>();

const emit = defineEmits<{
  (e: 'select', row: AdminTeacherEngagementRow): void;
}>();

const filtered = computed(() => {
  const q = (props.search ?? '').trim().toLowerCase();
  return props.rows.filter((r) => {
    if (props.statusFilter && r.status !== props.statusFilter) return false;
    if (q && !r.nama.toLowerCase().includes(q)) return false;
    return true;
  });
});

const STATUS_META: Record<TeacherRowStatus, { dot: string; label: string; tone: string }> = {
  aktif: { dot: 'bg-emerald-500', label: 'Aktif', tone: 'text-emerald-700 bg-emerald-50' },
  melambat: { dot: 'bg-amber-500', label: 'Melambat', tone: 'text-amber-700 bg-amber-50' },
  sepi: { dot: 'bg-red-500', label: 'Sepi', tone: 'text-red-700 bg-red-50' },
  never: { dot: 'bg-slate-300', label: 'Belum aktif', tone: 'text-slate-500 bg-slate-100' },
};

function initials(name: string): string {
  return name.split(/\s+/).map((s) => s[0]?.toUpperCase() ?? '').slice(0, 2).join('');
}

function daysAgo(dateStr: string | null): string {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  const diff = Math.max(0, Math.floor((Date.now() - d.getTime()) / (1000 * 60 * 60 * 24)));
  if (diff === 0) return 'Hari ini';
  if (diff === 1) return '1 hari lalu';
  return `${diff} hari lalu`;
}
</script>

<template>
  <div class="rounded-2xl bg-white border border-slate-100 shadow-sm overflow-hidden">
    <div class="overflow-x-auto">
      <table class="w-full text-2xs">
        <thead class="bg-slate-50 text-slate-500">
          <tr>
            <th class="text-left font-bold uppercase tracking-widest px-4 py-3">Guru</th>
            <th class="text-left font-bold uppercase tracking-widest px-2 py-3 hidden sm:table-cell">Status</th>
            <th class="text-right font-bold uppercase tracking-widest px-2 py-3">Level</th>
            <th class="text-right font-bold uppercase tracking-widest px-2 py-3">Beruntun</th>
            <th class="text-right font-bold uppercase tracking-widest px-2 py-3">7 hari</th>
            <th class="text-left font-bold uppercase tracking-widest px-4 py-3 hidden md:table-cell">Aktivitas</th>
            <th class="text-right font-bold uppercase tracking-widest px-4 py-3 hidden lg:table-cell">Terakhir</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="filtered.length === 0">
            <td colspan="7" class="text-center text-slate-500 py-8">
              Tidak ada guru yang cocok filter ini.
            </td>
          </tr>
          <tr
            v-for="row in filtered"
            :key="row.teacher_id"
            class="border-t border-slate-100 hover:bg-slate-50 cursor-pointer"
            @click="emit('select', row)"
          >
            <!-- Guru cell (avatar + nama + status dot on mobile) -->
            <td class="px-4 py-3">
              <div class="flex items-center gap-2 min-w-0">
                <div
                  class="w-8 h-8 rounded-full flex-shrink-0 grid place-items-center overflow-hidden"
                  :class="row.foto_url ? 'bg-slate-100' : 'bg-brand-cobalt/10 text-brand-cobalt text-3xs font-black'"
                >
                  <img v-if="row.foto_url" :src="row.foto_url" :alt="row.nama" class="w-full h-full object-cover" />
                  <span v-else>{{ initials(row.nama) }}</span>
                </div>
                <div class="min-w-0">
                  <p class="text-2xs font-bold text-slate-900 truncate">{{ row.nama }}</p>
                  <p class="text-3xs text-slate-500 sm:hidden flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full" :class="STATUS_META[row.status].dot"></span>
                    {{ STATUS_META[row.status].label }}
                  </p>
                </div>
              </div>
            </td>
            <!-- Status -->
            <td class="px-2 py-3 hidden sm:table-cell">
              <span
                class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-3xs font-bold uppercase tracking-widest"
                :class="STATUS_META[row.status].tone"
              >
                <span class="w-1.5 h-1.5 rounded-full" :class="STATUS_META[row.status].dot"></span>
                {{ STATUS_META[row.status].label }}
              </span>
            </td>
            <!-- Level -->
            <td class="px-2 py-3 text-right font-black text-slate-800">L{{ row.level }}</td>
            <!-- Streak -->
            <td class="px-2 py-3 text-right font-bold text-slate-800">{{ row.hari_beruntun }}h</td>
            <!-- 7 hari poin -->
            <td class="px-2 py-3 text-right font-black text-slate-800">{{ row.poin_7_hari }}</td>
            <!-- Sparkline -->
            <td class="px-4 py-3 hidden md:table-cell">
              <SparklineTinyBar :points="row.sparkline" />
            </td>
            <!-- Last active -->
            <td class="px-4 py-3 text-right text-slate-500 hidden lg:table-cell">
              {{ daysAgo(row.terakhir_aktif) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
