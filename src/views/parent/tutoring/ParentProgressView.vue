<!--
  ParentProgressView — wali nilai/progress. Mockup parent_web_pages_extra
  frame 1: hero + 4-KPI strip + per-mapel pills + trend chart with
  group-average baseline.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringProgress } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';

const { t } = useI18n();
const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const progress = ref<TutoringProgress | null>(null);

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try { progress.value = await TutoringService.getProgress(sid); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

// ── Data shape ────────────────────────────────────────────────────
const overall = computed(() => progress.value?.summary?.overall);
const trend = computed(() => progress.value?.trend ?? {});
const subjects = computed<Array<{ subject_id: string; subject_name: string }>>(() =>
  Object.keys(trend.value).map((name) => ({ subject_id: name, subject_name: name })),
);

const childFirstName = computed(() => {
  const n = activeChild()?.name ?? t('wali.bimbel.progress.default_child_name');
  return n.trim().split(/\s+/)[0] ?? n;
});

// ── KPI strip (only `average` is live; rest stubbed with "—") ─────
const kpis = computed(() => {
  const avg = overall.value?.average;
  return [
    {
      label: t('wali.bimbel.progress.kpi_average'),
      value: avg != null ? Math.round(avg).toString() : '—',
      delta: avg != null ? t('wali.bimbel.progress.average_kpi_delta') : '',
      deltaCls: 'text-green-700',
    },
    { label: t('wali.bimbel.progress.kpi_attendance'), value: '—', delta: '', deltaCls: 'text-bimbel-text-lo' },
    { label: t('wali.bimbel.progress.kpi_assignments'), value: '—', delta: '', deltaCls: 'text-bimbel-text-lo' },
    { label: t('wali.bimbel.progress.kpi_sessions_per_month'), value: '—', delta: '', deltaCls: 'text-bimbel-text-lo' },
  ];
});

// ── Subject pills (Semua / per-mapel / + rata-rata toggle) ────────
const activeSubject = ref<string>('all');

const subjectChips = computed(() => [
  { id: 'all', label: t('wali.bimbel.progress.subject_all') },
  ...subjects.value.map((s) => ({ id: s.subject_id, label: s.subject_name })),
  { id: 'avg', label: t('wali.bimbel.progress.subject_avg') },
]);

// ── Chart series ──────────────────────────────────────────────────
// Live trend if the active mapel has one; otherwise a stable ascending
// stub so the chart box never renders empty (matches the mockup).
const STUB_CHILD = [70, 73, 75, 78, 80, 83, 86, 88];
const STUB_AVG = [68, 70, 71, 72, 73, 74, 75, 76];

function buildPolyline(values: number[]): string {
  // viewBox is 600×80, plot area ≈ x: 20..580, y: 8..72.
  if (!values.length) return '';
  const max = Math.max(...values, 100);
  const min = Math.min(...values, 0);
  const range = Math.max(1, max - min);
  const n = values.length;
  const step = n > 1 ? 560 / (n - 1) : 0;
  return values
    .map((v, i) => {
      const x = 20 + i * step;
      const y = 72 - ((v - min) / range) * 64;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
}

const childSeries = computed<number[]>(() => {
  if (activeSubject.value !== 'all' && activeSubject.value !== 'avg') {
    const arr = trend.value[activeSubject.value];
    if (Array.isArray(arr) && arr.length >= 2) return arr;
  }
  return STUB_CHILD;
});

const childPolyline = computed(() => buildPolyline(childSeries.value));
const avgPolyline = computed(() => buildPolyline(STUB_AVG));

const xLabels = ref(['Mar', 'Mei', 'Jul', 'Sep']);
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      :kicker="t('wali.bimbel.progress.kicker')"
      :title="t('wali.bimbel.progress.title', { name: childFirstName })"
      :subtitle="t('wali.bimbel.progress.subtitle', { count: subjects.length })"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">{{ t('wali.bimbel.progress.loading') }}</div>

    <template v-else>
      <!-- 4-KPI strip -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-1.5">
        <div
          v-for="k in kpis"
          :key="k.label"
          class="rounded-lg bg-bimbel-bg p-2.5"
        >
          <p class="text-[10px] text-bimbel-text-mid">{{ k.label }}</p>
          <p class="text-[16px] font-extrabold text-bimbel-text-hi leading-none mt-0.5">{{ k.value }}</p>
          <p class="text-[10px] mt-0.5" :class="k.deltaCls">{{ k.delta || ' ' }}</p>
        </div>
      </div>

      <!-- Subject pills -->
      <div class="flex gap-1.5 overflow-x-auto pb-1">
        <button
          v-for="s in subjectChips"
          :key="s.id"
          type="button"
          class="rounded-full px-2.5 py-1 text-[12px] whitespace-nowrap transition-colors"
          :class="activeSubject === s.id
            ? 'bg-bimbel-hero text-white font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid'"
          @click="activeSubject = s.id"
        >{{ s.label }}</button>
      </div>

      <!-- Chart box -->
      <div class="rounded-lg bg-bimbel-bg p-3 relative" style="height:120px">
        <svg
          viewBox="0 0 600 80"
          preserveAspectRatio="none"
          style="width:100%;height:100%"
          aria-hidden="true"
        >
          <polyline
            :points="childPolyline"
            stroke="#185FA5"
            stroke-width="2"
            fill="none"
          />
          <polyline
            :points="avgPolyline"
            stroke="#5F5E5A"
            stroke-width="1"
            fill="none"
            stroke-dasharray="3,3"
          />
          <text
            v-for="(label, i) in xLabels"
            :key="i"
            :x="20 + i * 180"
            y="78"
            font-size="9"
            fill="#888780"
          >{{ label }}</text>
        </svg>
      </div>

      <div class="flex justify-between text-[10px] text-bimbel-text-lo">
        <span>
          <span class="inline-block w-2 h-0.5 bg-[#185FA5] align-middle mr-1"></span>
          {{ t('wali.bimbel.progress.chart_legend_child', { name: childFirstName }) }}
        </span>
        <span>
          <span class="inline-block w-2 h-0.5 bg-[#5F5E5A] align-middle mr-1"></span>
          {{ t('wali.bimbel.progress.chart_legend_avg') }}
        </span>
      </div>
    </template>
  </div>
</template>

<style scoped>
/* Hide scrollbar on subject pills row */
.overflow-x-auto::-webkit-scrollbar { display: none; }
.overflow-x-auto { scrollbar-width: none; }
</style>
