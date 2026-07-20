<!--
  AdminTutoring2NilaiView.vue — greenfield "Nilai" (assessments) list.

  Sibling of AdminTutoring2ProgramsView; same composition contract:
  BrandPageHeader → KpiStripCards → PageFilterToolbar → AsyncView →
  white rounded-3xl table surface → floating "+" CTA.

  This is the LIST view — the score matrix opens on assessment detail.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelAssessment,
} from '@/services/tutoring-bimbel.service';

const search = ref('');
const kindFilter = ref<string>(''); // '' | 'tryout' | 'latihan' | 'kuis'
const programFilter = ref<string>(''); // '' | program uuid
const statusFilter = ref<string>(''); // '' | 'published' | 'draft'

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const publishedFlag =
    statusFilter.value === 'published' ? true
    : statusFilter.value === 'draft' ? false
    : undefined;
  const { items } = await TutoringBimbelService.listAssessments({
    per_page: 50,
    kind: kindFilter.value || undefined,
    program_id: programFilter.value || undefined,
    published: publishedFlag,
  });
  return items;
});

watch([debouncedSearch, kindFilter, programFilter, statusFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelAssessment[];
  const tryout = items.filter((a) => a.kind === 'tryout').length;
  const latihan = items.filter((a) => a.kind === 'latihan').length;
  const kuis = items.filter((a) => a.kind === 'kuis').length;
  const draft = items.filter((a) => a.published_at == null).length;
  return [
    { icon: 'clipboard-list', label: 'Total tryout', value: String(tryout) },
    { icon: 'pencil', label: 'Latihan', value: String(latihan) },
    { icon: 'help-circle', label: 'Kuis', value: String(kuis) },
    { icon: 'file-pencil', label: 'Belum dipublikasi', value: String(draft), tone: draft > 0 ? 'amber' : undefined },
  ];
});

function truncateId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
}

function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      kicker="Admin Bimbel"
      title="Nilai"
      :meta="state.status === 'content' ? `${(state.data as BimbelAssessment[]).length} penilaian` : 'Memuat…'"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" search-placeholder="Cari penilaian…">
      <template #chips>
        <AppFilterChip
          label="Jenis"
          :value="kindFilter || 'Semua'"
          icon-name="clipboard-list"
          :active="!!kindFilter"
          @click="kindFilter = kindFilter ? '' : 'tryout'"
        />
        <AppFilterChip
          label="Program"
          :value="programFilter ? truncateId(programFilter) : 'Semua'"
          icon-name="book"
          :active="!!programFilter"
          @click="programFilter = ''"
        />
        <AppFilterChip
          label="Status"
          :value="statusFilter || 'Semua'"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'published'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      empty-title="Belum ada penilaian"
      empty-description="Klik + untuk membuat try-out atau latihan baru."
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">Judul</th>
                <th class="px-4 py-3 font-bold">Jenis</th>
                <th class="px-4 py-3 font-bold">Program</th>
                <th class="px-4 py-3 font-bold">Tanggal</th>
                <th class="px-4 py-3 font-bold">Peserta</th>
                <th class="px-4 py-3 font-bold">Max</th>
                <th class="px-4 py-3 font-bold">Publikasi</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="a in (data as BimbelAssessment[])"
                :key="a.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ a.title }}</td>
                <td class="px-4 py-3 text-slate-600">{{ a.kind_label ?? a.kind }}</td>
                <td class="px-4 py-3 font-mono text-2xs text-slate-500">{{ truncateId(a.program_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatShortDate(a.assessment_date) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ a.scores_count ?? 0 }}</td>
                <td class="px-4 py-3 text-slate-600">{{ a.max_score }}</td>
                <td class="px-4 py-3">
                  <span v-if="a.published_at" class="text-2xs font-bold text-success">
                    ✓ {{ formatShortDate(a.published_at) }}
                  </span>
                  <span v-else class="rounded-full bg-warning-soft px-2 py-0.5 text-2xs font-bold text-warning">
                    Draft
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 flex items-center gap-2 rounded-full bg-brand-cobalt px-5 py-3 text-sm font-bold text-white shadow-lg transition hover:brightness-110"
    >
      <span aria-hidden="true">+</span> Buat try-out
    </button>
  </div>
</template>
