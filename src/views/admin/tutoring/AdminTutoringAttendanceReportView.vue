<!--
  AdminTutoringAttendanceReportView — tenant-wide attendance report
  with 4-pill strip + per-group rates + low-attendance watch list.
  Mockup admin_web_pages_reports_markpaid frame 2.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import type { AdminAttendanceReport } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const loading = ref(true);
const data = ref<AdminAttendanceReport | null>(null);
const range = ref<'30' | '90' | 'sem'>('30');

async function load() {
  loading.value = true;
  const now = new Date();
  const days = range.value === '30' ? 30 : range.value === '90' ? 90 : 180;
  const from = new Date(now.getTime() - days * 86_400_000).toISOString().slice(0, 10);
  const to = now.toISOString().slice(0, 10);
  try { data.value = await TutoringService.getAdminAttendanceReport({ from, to }); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(range, load);

const total = computed(() => {
  const p = data.value?.pills;
  return p ? p.hadir + p.izin + p.sakit + p.alpha : 0;
});

function pct(n: number): number {
  return total.value > 0 ? Math.round((n / total.value) * 100) : 0;
}

function pctClass(p: number | null): string {
  if (p == null) return 'bg-bimbel-border';
  if (p >= 90) return 'bg-emerald-500';
  if (p >= 75) return 'bg-amber-500';
  return 'bg-rose-500';
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="LAPORAN · PRESENSI"
      title="Tingkat kehadiran"
      subtitle="Per kelompok + watch-list siswa di bawah 80%"
      :stats="[]"
    >
      <template #actions>
        <div class="flex gap-1 rounded-full bg-white/10 ring-1 ring-white/20 p-1">
          <button
            v-for="opt in [
              { id: '30' as const, label: '30 hari' },
              { id: '90' as const, label: '90 hari' },
              { id: 'sem' as const, label: 'Semester' },
            ]"
            :key="opt.id"
            type="button"
            class="rounded-full px-3 py-1 text-[12px] font-semibold"
            :class="range === opt.id ? 'bg-white text-bimbel-accent' : 'text-white/80'"
            @click="range = opt.id"
          >{{ opt.label }}</button>
        </div>
      </template>
    </TutorBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <template v-else-if="data">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-2.5">
        <div class="rounded-2xl bg-emerald-500/15 p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-emerald-700 dark:text-emerald-300">HADIR</p>
          <p class="mt-1 text-[22px] font-extrabold text-emerald-700 dark:text-emerald-300">{{ pct(data.pills.hadir) }}%</p>
        </div>
        <div class="rounded-2xl bg-bimbel-accent-dim p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-accent">IZIN</p>
          <p class="mt-1 text-[22px] font-extrabold text-bimbel-accent">{{ pct(data.pills.izin) }}%</p>
        </div>
        <div class="rounded-2xl bg-amber-500/15 p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-amber-700 dark:text-amber-300">SAKIT</p>
          <p class="mt-1 text-[22px] font-extrabold text-amber-700 dark:text-amber-300">{{ pct(data.pills.sakit) }}%</p>
        </div>
        <div class="rounded-2xl bg-rose-500/15 p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-rose-700 dark:text-rose-300">ALPHA</p>
          <p class="mt-1 text-[22px] font-extrabold text-rose-700 dark:text-rose-300">{{ pct(data.pills.alpha) }}%</p>
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-5">
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel overflow-hidden lg:col-span-3">
          <table class="w-full text-[14px]">
            <thead class="bg-bimbel-bg/40">
              <tr class="text-left text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
                <th class="px-3 py-2">Kelompok</th>
                <th class="px-3 py-2 w-[90px]">Sesi</th>
                <th class="px-3 py-2 w-[140px]">Hadir</th>
                <th class="px-3 py-2 w-[100px]">Tutor</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in data.rows" :key="r.group_id" class="border-t border-bimbel-border-soft">
                <td class="px-3 py-2.5">
                  <p class="font-bold text-bimbel-text-hi">{{ r.group_name }}</p>
                  <p class="text-[12px] text-bimbel-text-mid">{{ r.students }} siswa</p>
                </td>
                <td class="px-3 py-2.5 text-bimbel-text-mid">{{ r.sessions }} sesi</td>
                <td class="px-3 py-2.5">
                  <span class="inline-block w-16 h-1.5 rounded-full bg-bimbel-border align-middle overflow-hidden mr-1.5">
                    <span class="block h-full" :class="pctClass(r.hadir_pct)" :style="{ width: r.hadir_pct != null ? `${r.hadir_pct}%` : '0%' }" />
                  </span>
                  <span class="text-[13px]">{{ r.hadir_pct ?? '–' }}%</span>
                </td>
                <td class="px-3 py-2.5 text-bimbel-text-mid">{{ r.tutor_name ?? '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-2 h-fit">
          <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">Siswa perlu perhatian</h4>
          <p class="text-[13px] text-bimbel-text-mid mb-3">Kehadiran di bawah 80%.</p>
          <div v-if="data.watch.length === 0" class="text-[13px] text-bimbel-text-mid py-4 text-center">
            Tidak ada siswa di bawah ambang.
          </div>
          <div
            v-for="w in data.watch"
            :key="w.student_id"
            class="border-t border-bimbel-border-soft py-2.5 first:border-t-0 first:pt-0"
          >
            <p class="text-[14px] font-bold text-bimbel-text-hi">{{ w.student_name }}</p>
            <p class="text-[12px] text-bimbel-text-mid">{{ w.group_name }} · {{ w.hadir }} dari {{ w.sessions_done }} sesi ({{ w.hadir_pct ?? '–' }}%)</p>
          </div>
          <button
            v-if="data.watch.length > 0"
            type="button"
            class="mt-3 inline-flex items-center gap-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
          >
            <NavIcon name="megaphone" :size="12" /> Kirim WA ke wali
          </button>
        </aside>
      </div>
    </template>
  </div>
</template>
