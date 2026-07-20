<!--
  TutorTutoring2AssessmentsView.vue — greenfield "Penilaian" list for
  the tutor-mobile Vue shell (bimbel rebuild). Mirrors the admin
  AdminTutoring2AssessmentsView composition (BrandPageHeader →
  KpiStripCards → PageFilterToolbar → AsyncView → rounded-3xl surface
  → floating CTA) but renders a mobile-first divide-y list with
  per-row "Input skor" + "Hasil" actions instead of a wide desktop
  table.

  Route: teacher/tutoring2/assessments
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelAssessment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const router = useRouter();

// ─── Filter state ─────────────────────────────────────────────────
const search = ref('');
const kindFilter = ref<'' | 'tryout' | 'latihan' | 'kuis'>('');
const statusFilter = ref<'' | 'published' | 'draft'>('');

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

// ─── Loader ───────────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const publishedFlag =
    statusFilter.value === 'published' ? true
    : statusFilter.value === 'draft' ? false
    : undefined;
  const { items } = await TutoringBimbelService.listAssessments({
    per_page: 50,
    kind: kindFilter.value || undefined,
    published: publishedFlag,
  });
  return items;
});

watch([debouncedSearch, kindFilter, statusFilter], () => reload());
useAcademicYearWatcher(reload);

// ─── KPIs ─────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelAssessment[];
  const total = items.length;
  const tryout = items.filter((a) => a.kind === 'tryout').length;
  const latihan = items.filter((a) => a.kind === 'latihan').length;
  const draft = items.filter((a) => a.published_at == null).length;
  return [
    { icon: 'clipboard-list', label: 'Total', value: String(total) },
    { icon: 'award', label: 'Try-out', value: String(tryout), tone: 'violet' },
    { icon: 'edit', label: 'Latihan', value: String(latihan), tone: 'brand' },
    {
      icon: 'file-text',
      label: 'Draft',
      value: String(draft),
      tone: draft > 0 ? 'amber' : 'slate',
    },
  ];
});

// ─── Helpers ──────────────────────────────────────────────────────
function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

function publishedTone(publishedAt: string | null | undefined): StatusBadgeTone {
  return publishedAt ? 'success' : 'warning';
}

function publishedLabel(publishedAt: string | null | undefined): string {
  return publishedAt ? 'Terbit' : 'Draft';
}

const metaLabel = computed(() => {
  if (state.value.status === 'content') {
    return `${(state.value.data as BimbelAssessment[]).length} penilaian`;
  }
  return 'Memuat…';
});

// Client-side name filter — the backend contract for assessments
// doesn't expose a `search` param yet, so we narrow the loaded page.
const filteredItems = computed(() => {
  if (state.value.status !== 'content') return [] as BimbelAssessment[];
  const items = state.value.data as BimbelAssessment[];
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return items;
  return items.filter((a) => a.title.toLowerCase().includes(q));
});

// ─── Navigation ───────────────────────────────────────────────────
function goScores(id: string) {
  router.push({ name: 'teacher.tutoring2.scores', params: { id } });
}

function goResult(id: string) {
  router.push({ name: 'teacher.tutoring2.assessment-result', params: { id } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      kicker="Tutor Bimbel"
      title="Penilaian"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" search-placeholder="Cari penilaian…">
      <template #chips>
        <AppFilterChip
          label="Jenis"
          :value="kindFilter ? kindFilter : 'Semua'"
          icon-name="clipboard-list"
          :active="!!kindFilter"
          @click="kindFilter = kindFilter === '' ? 'tryout' : kindFilter === 'tryout' ? 'latihan' : kindFilter === 'latihan' ? 'kuis' : ''"
        />
        <AppFilterChip
          label="Status"
          :value="statusFilter ? statusFilter : 'Semua'"
          icon-name="check-circle"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter === '' ? 'published' : statusFilter === 'published' ? 'draft' : ''"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      empty-title="Belum ada penilaian"
      empty-description="Ketuk tombol Buat try-out untuk membuat penilaian pertama."
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100">
          <div
            v-for="a in filteredItems"
            :key="a.id"
            class="p-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="min-w-0 flex-1 space-y-1.5">
              <div class="flex items-center gap-2 flex-wrap">
                <p class="font-bold text-slate-900 truncate">{{ a.title }}</p>
                <StatusBadge
                  :label="a.kind_label ?? a.kind"
                  tone="info"
                  uppercase
                />
                <StatusBadge
                  :label="publishedLabel(a.published_at)"
                  :tone="publishedTone(a.published_at)"
                  uppercase
                />
              </div>
              <p class="text-2xs text-slate-500">
                {{ formatShortDate(a.assessment_date) }}
                <span class="mx-1 text-slate-300">•</span>
                Peserta {{ a.scores_count ?? 0 }}
              </p>
            </div>

            <div class="flex items-center gap-2 shrink-0">
              <Button variant="ghost" size="sm" @click="goResult(a.id)">Hasil</Button>
              <Button variant="secondary" size="sm" @click="goScores(a.id)">Input skor</Button>
            </div>
          </div>
        </div>
      </template>
    </AsyncView>

    <router-link
      :to="{ name: 'teacher.tutoring2.assessment-create' }"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
    >
      <span aria-hidden="true">+</span> Buat try-out
    </router-link>
  </div>
</template>
