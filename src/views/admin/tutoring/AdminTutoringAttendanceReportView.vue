<!--
  AdminTutoringAttendanceReportView — tenant-wide attendance report
  with 4-pill strip + per-group rates + low-attendance watch list.
  Payload keys mirror GetAdminAttendanceReportAction.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch as watchRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { AdminAttendanceReport } from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();

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
watchRef(range, load);

const total = computed(() => data.value?.pills.total ?? 0);
const groups = computed(() => data.value?.groups ?? []);
const watchlist = computed(() => data.value?.watchlist ?? []);

function pct(n: number): number {
  return total.value > 0 ? Math.round((n / total.value) * 100) : 0;
}

function pctClass(p: number | null): string {
  if (p == null) return 'bg-tutoring-border';
  if (p >= 90) return 'bg-emerald-500';
  if (p >= 75) return 'bg-amber-500';
  return 'bg-rose-500';
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('admin.bimbel.attendance_report.hero_kicker')"
      :title="t('admin.bimbel.attendance_report.hero_title')"
      :subtitle="t('admin.bimbel.attendance_report.hero_subtitle')"
      :stats="[]"
    >
      <template #actions>
        <div class="flex gap-1 rounded-full bg-white/10 ring-1 ring-white/20 p-1">
          <button
            v-for="opt in [
              { id: '30' as const, label: t('admin.bimbel.attendance_report.range_30') },
              { id: '90' as const, label: t('admin.bimbel.attendance_report.range_90') },
              { id: 'sem' as const, label: t('admin.bimbel.attendance_report.range_semester') },
            ]"
            :key="opt.id"
            type="button"
            class="rounded-full px-3 py-1 text-[13px] font-semibold"
            :class="range === opt.id ? 'bg-white text-tutoring-accent' : 'text-white/80'"
            @click="range = opt.id"
          >{{ opt.label }}</button>
        </div>
      </template>
    </TutorHomeHero>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.attendance_report.loading') }}</div>

    <template v-else-if="data">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-2.5">
        <div class="rounded-2xl bg-emerald-500/15 p-3.5">
          <p class="text-[13px] font-bold uppercase tracking-widest text-emerald-700 dark:text-emerald-300">{{ t('admin.bimbel.attendance_report.pill_present') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-emerald-700 dark:text-emerald-300">{{ pct(data.pills.hadir) }}%</p>
        </div>
        <div class="rounded-2xl bg-tutoring-accent-dim p-3.5">
          <p class="text-[13px] font-bold uppercase tracking-widest text-tutoring-accent">{{ t('admin.bimbel.attendance_report.pill_excused') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-tutoring-accent">{{ pct(data.pills.izin) }}%</p>
        </div>
        <div class="rounded-2xl bg-amber-500/15 p-3.5">
          <p class="text-[13px] font-bold uppercase tracking-widest text-amber-700 dark:text-amber-300">{{ t('admin.bimbel.attendance_report.pill_sick') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-amber-700 dark:text-amber-300">{{ pct(data.pills.sakit) }}%</p>
        </div>
        <div class="rounded-2xl bg-rose-500/15 p-3.5">
          <p class="text-[13px] font-bold uppercase tracking-widest text-rose-700 dark:text-rose-300">{{ t('admin.bimbel.attendance_report.pill_absent') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-rose-700 dark:text-rose-300">{{ pct(data.pills.alpa) }}%</p>
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-5">
        <div class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel overflow-hidden lg:col-span-3">
          <table class="w-full text-[14px]">
            <thead class="bg-tutoring-bg/40">
              <tr class="text-left text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">
                <th class="px-3 py-2">{{ t('admin.bimbel.attendance_report.th_group') }}</th>
                <th class="px-3 py-2 w-[90px]">{{ t('admin.bimbel.attendance_report.th_sessions') }}</th>
                <th class="px-3 py-2 w-[140px]">{{ t('admin.bimbel.attendance_report.th_present') }}</th>
                <th class="px-3 py-2 w-[100px]">{{ t('admin.bimbel.attendance_report.th_tutor') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="groups.length === 0">
                <td colspan="4" class="px-3 py-6 text-center text-[14px] text-tutoring-text-mid">
                  {{ t('admin.bimbel.attendance_report.no_data_range') }}
                </td>
              </tr>
              <tr v-for="r in groups" :key="r.group_id" class="border-t border-tutoring-border-soft">
                <td class="px-3 py-2.5">
                  <p class="font-bold text-tutoring-text-hi">{{ r.group_name }}</p>
                  <p class="text-[13px] text-tutoring-text-mid">{{ t('admin.bimbel.attendance_report.students_count', { count: r.students_count }) }}</p>
                </td>
                <td class="px-3 py-2.5 text-tutoring-text-mid">{{ t('admin.bimbel.attendance_report.sessions_count', { count: r.sessions_count }) }}</td>
                <td class="px-3 py-2.5">
                  <span class="inline-block w-16 h-1.5 rounded-full bg-tutoring-border align-middle overflow-hidden mr-1.5">
                    <span class="block h-full" :class="pctClass(r.attendance_rate)" :style="{ width: r.attendance_rate != null ? `${r.attendance_rate}%` : '0%' }" />
                  </span>
                  <span class="text-[14px]">{{ r.attendance_rate ?? '–' }}%</span>
                </td>
                <td class="px-3 py-2.5 text-tutoring-text-mid">{{ r.tutor_name ?? '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <aside class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-4 lg:col-span-2 h-fit">
          <h4 class="text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ t('admin.bimbel.attendance_report.watchlist_title') }}</h4>
          <p class="text-[14px] text-tutoring-text-mid mb-3">{{ t('admin.bimbel.attendance_report.watchlist_subtitle') }}</p>
          <div v-if="watchlist.length === 0" class="text-[14px] text-tutoring-text-mid py-4 text-center">
            {{ t('admin.bimbel.attendance_report.watchlist_empty') }}
          </div>
          <div
            v-for="w in watchlist"
            :key="w.student_id"
            class="border-t border-tutoring-border-soft py-2.5 first:border-t-0 first:pt-0"
          >
            <p class="text-[14px] font-bold text-tutoring-text-hi">{{ w.student_name }}</p>
            <p class="text-[13px] text-tutoring-text-mid">{{ t('admin.bimbel.attendance_report.watchlist_row', { attended: w.attended, total: w.total, rate: w.attendance_rate, alpha: w.alpha_count }) }}</p>
          </div>
          <button
            v-if="watchlist.length > 0"
            type="button"
            class="mt-3 inline-flex items-center gap-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-1.5 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft"
          >
            <NavIcon name="megaphone" :size="12" /> {{ t('admin.bimbel.attendance_report.send_wa') }}
          </button>
        </aside>
      </div>
    </template>
  </div>
</template>
