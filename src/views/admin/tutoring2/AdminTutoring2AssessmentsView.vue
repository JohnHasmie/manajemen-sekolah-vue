<!--
  AdminTutoring2NilaiView.vue — greenfield "Nilai" (assessments) list.

  Sibling of AdminTutoring2ProgramsView; same composition contract:
  BrandPageHeader → KpiStripCards → PageFilterToolbar → AsyncView →
  white rounded-3xl table surface → floating "+" CTA.

  This is the LIST view — the score matrix opens on assessment detail.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelAssessment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

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
    { icon: 'clipboard-list', label: t('tutoring2.admin.assessments.kpiTryout'), value: String(tryout) },
    { icon: 'pencil', label: t('tutoring2.admin.assessments.kpiLatihan'), value: String(latihan) },
    { icon: 'help-circle', label: t('tutoring2.admin.assessments.kpiKuis'), value: String(kuis) },
    { icon: 'file-pencil', label: t('tutoring2.admin.assessments.kpiDrafts'), value: String(draft), tone: draft > 0 ? 'amber' : undefined },
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

function publishedTone(publishedAt: string | null | undefined): StatusBadgeTone {
  return publishedAt ? 'success' : 'warning';
}

function publishedLabel(publishedAt: string | null | undefined): string {
  return publishedAt
    ? `${t('tutoring2.status.published')} ${formatShortDate(publishedAt)}`
    : t('tutoring2.status.draft');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.assessments.title')"
      :meta="state.status === 'content' ? `${(state.data as BimbelAssessment[]).length} penilaian` : t('tutoring2.common.loading')"
    />
    <!-- TODO i18n key for meta '{count} penilaian' -->

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.assessments.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.kind')"
          :value="kindFilter || t('tutoring2.common.all')"
          icon-name="clipboard-list"
          :active="!!kindFilter"
          @click="kindFilter = kindFilter ? '' : 'tryout'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="programFilter ? truncateId(programFilter) : t('tutoring2.common.all')"
          icon-name="book"
          :active="!!programFilter"
          @click="programFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
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
      :empty-title="t('tutoring2.admin.assessments.emptyTitle')"
      empty-description="Klik + untuk membuat try-out atau latihan baru."
      @retry="reload"
    >
      <!-- TODO i18n key for empty-description 'Klik + untuk membuat try-out atau latihan baru.' -->
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.title') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.kind') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.date') }}</th>
                <!-- TODO i18n key for column headers 'Peserta' / 'Max' / 'Publikasi' -->
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
                  <StatusBadge :label="publishedLabel(a.published_at)" :tone="publishedTone(a.published_at)" uppercase />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.assessments.newCta') }}
    </button>
  </div>
</template>
