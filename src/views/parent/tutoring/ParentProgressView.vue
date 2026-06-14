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
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · NILAI"
      title="Nilai & progress"
      :subtitle="`Timeline penilaian ${activeChild()?.name ?? 'anak'}`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <template v-else>
      <div class="grid grid-cols-3 gap-2.5">
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <p class="text-[13px] font-bold uppercase tracking-widest text-bimbel-text-mid">RATA-RATA</p>
          <p class="mt-1 text-2xl font-extrabold text-bimbel-text-hi">
            {{ overall?.average != null ? Math.round(overall.average) : '–' }}
          </p>
          <p class="text-[13px] text-bimbel-text-mid">{{ overall?.count ?? 0 }} nilai tercatat</p>
        </div>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <p class="text-[13px] font-bold uppercase tracking-widest text-bimbel-text-mid">TERTINGGI</p>
          <p class="mt-1 text-2xl font-extrabold text-bimbel-text-hi">{{ overall?.best ?? '–' }}</p>
          <p class="text-[13px] text-bimbel-text-mid">nilai terbaik</p>
        </div>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <p class="text-[13px] font-bold uppercase tracking-widest text-bimbel-text-mid">TERAKHIR</p>
          <p class="mt-1 text-2xl font-extrabold text-bimbel-text-hi">{{ overall?.latest ?? '–' }}</p>
          <p class="text-[13px] text-bimbel-text-mid">nilai terbaru</p>
        </div>
      </div>

      <div v-if="subjects.length" class="flex flex-wrap gap-2">
        <span
          v-for="(s, i) in subjects"
          :key="s"
          class="inline-flex items-center gap-1.5 rounded-full bg-bimbel-panel border border-bimbel-border-soft px-3 py-1 text-[13px] text-bimbel-text-hi"
        >
          <span class="h-2 w-2 rounded-full" :style="{ background: HUES[i % HUES.length] }" />
          {{ s }}
        </span>
      </div>

      <div class="grid gap-3 lg:grid-cols-5">
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 lg:col-span-2">
          <h4 class="mb-3 text-[13px] font-bold tracking-tight text-bimbel-text-hi">Trend per mapel</h4>
          <div class="h-32 rounded-xl bg-bimbel-bg/40 p-2">
            <svg viewBox="0 0 280 100" preserveAspectRatio="none" class="h-full w-full">
              <polyline
                v-for="(s, i) in subjects"
                :key="s"
                :points="polyline(trend[s] ?? [])"
                fill="none"
                :stroke="HUES[i % HUES.length]"
                stroke-width="2"
              />
            </svg>
          </div>
        </div>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 lg:col-span-3">
          <h4 class="mb-3 text-[13px] font-bold tracking-tight text-bimbel-text-hi">Penilaian terbaru</h4>
          <div
            v-if="entries.length === 0"
            class="py-6 text-center text-[13px] text-bimbel-text-mid"
          >Belum ada nilai.</div>
          <div
            v-for="p in entries.slice(0, 8)"
            :key="p.assessment_id"
            class="flex items-center justify-between gap-3 border-b border-bimbel-border-soft py-2 last:border-b-0"
          >
            <div class="min-w-0">
              <p class="truncate text-[14px] font-bold text-bimbel-text-hi">{{ p.title }}</p>
              <p class="truncate text-[13px] text-bimbel-text-mid">
                {{ [p.subject, p.type_label, relTime(p.held_at) || dateShort(p.held_at)].filter(Boolean).join(' · ') }}
              </p>
            </div>
            <span class="text-[16px] font-extrabold text-emerald-700 dark:text-emerald-300">{{ p.score ?? '–' }}</span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
