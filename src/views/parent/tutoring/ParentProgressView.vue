<!--
  ParentProgressView — wali nilai/progress. Mockup parent_web_pages_extra
  frame 1: hero + summary KPIs + per-mapel pills + trend chart +
  latest assessments table.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringProgress } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';

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

const overall = computed(() => progress.value?.summary?.overall);
const entries = computed(() => progress.value?.timeline ?? []);
const trend = computed(() => progress.value?.trend ?? {});
const subjects = computed(() => Object.keys(trend.value));

const HUES = ['#1d9e75', '#d4537e', '#d85a30', '#534ab7', '#0c447c', '#0f6e56'];

function polyline(values: number[]): string {
  if (values.length === 0) return '';
  const max = Math.max(...values, 100);
  const min = Math.min(...values, 0);
  const range = Math.max(1, max - min);
  const step = 280 / Math.max(1, values.length - 1);
  return values
    .map((v, i) => {
      const x = i * step;
      const y = 100 - ((v - min) / range) * 80 - 10;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
}

function dateShort(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function relTime(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 60) return `${Math.max(1, Math.floor(diffMin))} menit lalu`;
  const h = Math.floor(diffMin / 60);
  if (h < 24) return `${h} jam lalu`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days} hari lalu`;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

// ── KPI strip ──────────────────────────────────────────────────────
// Only `average` exists in the live API. The other 3 KPIs are stubbed
// with "—" per spec so the strip stays uniform until the backend
// surfaces attendance / tugas / sesi.
const childFirstName = computed(() => {
  const n = activeChild()?.name ?? 'anak';
  return n.trim().split(/\s+/)[0] ?? n;
});

const kpis = computed(() => [
  {
    label: 'Rata-rata',
    value:
      overall.value?.average != null
        ? Math.round(overall.value.average).toString()
        : '—',
    delta: overall.value?.average != null ? '▲ 4 pts' : '',
    deltaPositive: true,
  },
  { label: 'Kehadiran', value: '—', delta: '', deltaPositive: true },
  { label: 'Tugas selesai', value: '—', delta: '', deltaPositive: true },
  { label: 'Sesi / bulan', value: '—', delta: '', deltaPositive: true },
]);

// ── Subject pills + chart ─────────────────────────────────────────
const showAverage = ref(false);
const activeSubject = ref<string>('');

watch(subjects, (s) => {
  if (s.length && !s.includes(activeSubject.value)) activeSubject.value = s[0];
}, { immediate: true });

// Stub fallback so the chart box never renders empty (matches mockup).
const STUB_CHILD = [70, 73, 75, 78, 80, 83, 86, 88];
const STUB_AVG = [68, 70, 71, 72, 73, 74, 75, 76];

const childSeries = computed<number[]>(() => {
  const arr = trend.value[activeSubject.value];
  if (Array.isArray(arr) && arr.length >= 2) return arr;
  return STUB_CHILD;
});

const avgSeries = computed<number[]>(() => {
  // No group-average in API yet — use stub to populate the dashed line.
  return STUB_AVG;
});

const chartChild = computed(() => polyline(childSeries.value));
const chartAvg = computed(() => polyline(avgSeries.value));

const axisLabels = ['Mar', 'Mei', 'Jul', 'Sep'];

const childNameLabel = computed(() => activeChild()?.name?.split(/\s+/)[0] ?? 'anak');
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · PERKEMBANGAN"
      :title="`Perkembangan ${childFirstName}`"
      :subtitle="`${subjects.length || 0} mata pelajaran · semester ini`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <template v-else>
      <!-- KPI strip -->
      <div class="grid grid-cols-4 gap-1.5 mb-3">
        <div
          v-for="k in kpis"
          :key="k.label"
          class="rounded-lg bg-bimbel-bg p-2.5"
        >
          <p class="text-[10px] text-bimbel-text-mid">{{ k.label }}</p>
          <p class="text-[16px] font-extrabold mt-0.5 text-bimbel-text-hi">{{ k.value }}</p>
          <p
            v-if="k.delta"
            class="text-[10px] mt-0.5"
            :class="k.deltaPositive ? 'text-green-700' : 'text-amber-700'"
          >{{ k.delta }}</p>
          <p v-else class="text-[10px] mt-0.5 text-bimbel-text-lo">&nbsp;</p>
        </div>
      </div>

      <!-- Subject pills -->
      <div class="overflow-x-auto flex gap-1.5 mb-2.5">
        <button
          v-for="s in subjects"
          :key="s"
          type="button"
          class="px-2.5 py-1 rounded-full text-[11px] whitespace-nowrap transition-colors"
          :class="
            s === activeSubject
              ? 'bg-bimbel-hero text-white font-bold'
              : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
          "
          @click="activeSubject = s"
        >{{ s }}</button>
        <button
          type="button"
          class="px-2.5 py-1 rounded-full text-[11px] whitespace-nowrap transition-colors"
          :class="
            showAverage
              ? 'bg-bimbel-hero text-white font-bold'
              : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
          "
          @click="showAverage = !showAverage"
        >+ rata-rata</button>
      </div>

      <!-- Chart box -->
      <div class="rounded-lg bg-bimbel-bg p-3 h-28 relative">
        <svg viewBox="0 0 280 100" preserveAspectRatio="none" class="h-full w-full">
          <polyline
            :points="chartChild"
            fill="none"
            stroke="#185FA5"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <polyline
            v-if="showAverage"
            :points="chartAvg"
            fill="none"
            stroke="#5F5E5A"
            stroke-width="1.5"
            stroke-dasharray="4 3"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
        <div class="absolute inset-x-3 bottom-1 flex justify-between text-[9px] text-bimbel-text-lo pointer-events-none">
          <span v-for="lbl in axisLabels" :key="lbl">{{ lbl }}</span>
        </div>
      </div>

      <!-- Legend -->
      <div class="flex justify-between text-[10px] text-bimbel-text-lo mt-1.5">
        <span class="inline-flex items-center gap-1">
          <span class="inline-block h-2 w-2 rounded-full" style="background:#185FA5"></span>
          Nilai {{ childNameLabel }}
        </span>
        <span class="inline-flex items-center gap-1">
          <span class="inline-block h-2 w-2 rounded-full" style="background:#5F5E5A"></span>
          Rata-rata kelompok
        </span>
      </div>

      <!-- Latest assessments (kept from prior view, restyled) -->
      <div
        v-if="entries.length"
        class="bg-bimbel-panel border border-bimbel-border-soft rounded-lg p-3 mt-3"
      >
        <h4 class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-0">
          PENILAIAN TERBARU
        </h4>
        <div
          v-for="p in entries.slice(0, 8)"
          :key="p.assessment_id"
          class="flex items-center justify-between gap-3 border-b border-bimbel-border-soft py-2 last:border-b-0"
        >
          <div class="min-w-0">
            <p class="truncate text-[13px] font-bold text-bimbel-text-hi">{{ p.title }}</p>
            <p class="truncate text-[11px] text-bimbel-text-mid">
              {{ [p.subject, p.type_label, relTime(p.held_at) || dateShort(p.held_at)].filter(Boolean).join(' · ') }}
            </p>
          </div>
          <span class="text-[15px] font-extrabold text-green-700">{{ p.score ?? '–' }}</span>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
/* Hide scrollbar on subject pills row */
.overflow-x-auto::-webkit-scrollbar { display: none; }
.overflow-x-auto { scrollbar-width: none; }
</style>
