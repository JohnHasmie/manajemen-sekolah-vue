<!--
  AdminTutoringActivityReportView — tenant-wide activity / tasks
  report. Mockup admin_web_pages_reports_markpaid frame 1.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import type { AdminActivityReport } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const loading = ref(true);
const data = ref<AdminActivityReport | null>(null);
const type = ref<'all' | 'HOMEWORK' | 'QUIZ' | 'EXAM' | 'PROJECT'>('all');

async function load() {
  loading.value = true;
  try {
    data.value = await TutoringService.getAdminActivityReport({
      type: type.value === 'all' ? undefined : type.value,
    });
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(type, load);

const stats = computed(() => {
  const k = data.value?.kpi;
  return [
    { label: 'TOTAL', value: String(k?.total_activities ?? 0) },
    { label: 'DIKUMPUL', value: k?.submitted_pct != null ? `${k.submitted_pct}%` : '–' },
    { label: 'DINILAI', value: k?.graded_pct != null ? `${k.graded_pct}%` : '–' },
    { label: 'RATA NILAI', value: k?.avg_score != null ? String(Math.round(k.avg_score)) : '–' },
  ];
});

function pctClass(pct: number | null): string {
  if (pct == null) return 'bg-bimbel-border';
  if (pct >= 90) return 'bg-emerald-500';
  if (pct >= 70) return 'bg-amber-500';
  return 'bg-rose-500';
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="LAPORAN · AKTIVITAS"
      title="Laporan aktivitas & tugas"
      subtitle="PR, quiz, try-out, materi · 30 hari terakhir"
      :stats="[]"
    >
      <template #actions>
        <button class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[13px] font-bold text-white">
          <NavIcon name="download" :size="13" class="inline -mt-0.5" /> Export
        </button>
      </template>
    </TutorBerandaHero>

    <div class="flex gap-1.5 flex-wrap">
      <button
        v-for="opt in [
          { id: 'all' as const, label: 'Semua' },
          { id: 'HOMEWORK' as const, label: 'PR' },
          { id: 'QUIZ' as const, label: 'Quiz' },
          { id: 'EXAM' as const, label: 'Try-out' },
          { id: 'PROJECT' as const, label: 'Proyek' },
        ]"
        :key="opt.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[13px] font-semibold"
        :class="type === opt.id ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
        @click="type = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-2.5">
      <div v-for="s in stats" :key="s.label" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
        <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">{{ s.label }}</p>
        <p class="mt-1 text-[22px] font-extrabold text-bimbel-text-hi">{{ s.value }}</p>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="data?.rows?.length" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel overflow-hidden">
      <table class="w-full text-[14px]">
        <thead class="bg-bimbel-bg/40">
          <tr class="text-left text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
            <th class="px-3 py-2">Kelompok</th>
            <th class="px-3 py-2 w-[120px]">Tutor</th>
            <th class="px-3 py-2 w-[80px]">Tipe</th>
            <th class="px-3 py-2 w-[80px]">Dibuat</th>
            <th class="px-3 py-2 w-[140px]">Dikumpul</th>
            <th class="px-3 py-2 w-[90px]">Rata nilai</th>
            <th class="px-3 py-2 w-[100px]">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in data.rows" :key="r.group_id + r.type" class="border-t border-bimbel-border-soft">
            <td class="px-3 py-2.5">
              <p class="font-bold text-bimbel-text-hi">{{ r.group_name }}</p>
              <p v-if="r.program_name" class="text-[12px] text-bimbel-text-mid">{{ r.program_name }}</p>
            </td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ r.tutor_name ?? '—' }}</td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ r.type }}</td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ r.created }}</td>
            <td class="px-3 py-2.5">
              <span class="inline-block w-16 h-1.5 rounded-full bg-bimbel-border align-middle overflow-hidden mr-1.5">
                <span class="block h-full" :class="pctClass(r.created > 0 ? Math.round((r.submitted / r.created) * 100) : null)" :style="{ width: r.created > 0 ? `${Math.min(100, Math.round((r.submitted / r.created) * 100))}%` : '0%' }" />
              </span>
              <span class="text-[13px]">{{ r.submitted }}/{{ r.created }}</span>
            </td>
            <td class="px-3 py-2.5 font-bold text-emerald-700 dark:text-emerald-300">{{ r.avg_score != null ? Math.round(r.avg_score) : '—' }}</td>
            <td class="px-3 py-2.5 text-[12px]" :class="r.status === 'on track' ? 'text-emerald-700 dark:text-emerald-300' : r.status === 'belum mulai' ? 'text-rose-700 dark:text-rose-300' : 'text-amber-700 dark:text-amber-300'">{{ r.status }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Belum ada data aktivitas.
    </div>
  </div>
</template>
