<!--
  AdminTutoring2TermView.vue — greenfield "Term / Batch" list.

  Mirrors AdminTutoring2ProgramsView.vue shape 1:1.

  This view used to derive its list from the distinct `term_id` values
  on learning groups, because nothing served `/tutoring-v2/terms` — and
  it invented the rest of every row:

      name        `Term ${id.slice(0, 8)}`   eight characters of a UUID
      start_date  null
      end_date    null
      status      'draft'                    on EVERY row

  The status was the part that lied loudest: an admin looking at a live
  batch was told it was a draft, and the Draf KPI counted every term
  while Aktif and Ditutup both read zero.

  The `terms` table has held the real name, dates, `is_current` and
  status since BE-1. It is served now, so the derivation is gone.
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
import type { StatusBadgeTone } from '@/types/status-badge';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringTermsService } from '@/services/tutoring2/terms';
import type { BimbelTerm } from '@/types/tutoring2/term';

const { t } = useI18n();

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'draft' | 'active' | 'closed'
const yearFilter = ref<string>(''); // '' = Semua

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  // Search and status filter server-side now — the endpoint does both,
  // and filtering a paginated slice client-side only ever hid rows
  // that were on the next page.
  const { items } = await TutoringTermsService.list({
    per_page: 100,
    status: statusFilter.value || undefined,
    search: debouncedSearch.value.trim() || undefined,
  });

  // The year chip has no server-side equivalent: it narrows on the
  // start date's calendar year, which is a display concern. A term
  // with no start date is not claimed to belong to any year.
  if (!yearFilter.value) return items;
  return items.filter((row) => row.start_date?.startsWith(yearFilter.value));
});

watch([debouncedSearch, statusFilter, yearFilter], () => reload());

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelTerm[];
  const active = items.filter((row) => row.status === 'active').length;
  const closed = items.filter((row) => row.status === 'closed').length;
  const draft = items.filter((row) => row.status === 'draft').length;
  // `groups_count` is optional on the wire. Absent means "not asked",
  // not "zero", so a term missing it contributes nothing to the sum
  // rather than dragging it down as a confident 0.
  const groupsTotal = items.reduce((sum, row) => sum + (row.groups_count ?? 0), 0);
  return [
    { icon: 'circle-check', label: t('tutoring2.admin.term.kpiActive'), value: String(active) },
    { icon: 'flag', label: t('tutoring2.admin.term.kpiClosed'), value: String(closed) },
    { icon: 'file-pencil', label: t('tutoring2.admin.term.kpiDraft'), value: String(draft), tone: draft > 0 ? 'amber' : undefined },
    { icon: 'users', label: t('tutoring2.admin.term.kpiGroupsTotal'), value: String(groupsTotal) },
  ];
});

function statusPillTone(status: BimbelTerm['status']): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    // `terms.status` is free text, not an enum, so an unrecognised
    // value falls here and renders neutrally rather than borrowing the
    // tone of a status it is not.
    default:
      return 'neutral';
  }
}

function formatDate(d: string | null): string {
  return d ?? '—';
}

const termCount = computed(() =>
  state.value.status === 'content' ? (state.value.data as BimbelTerm[]).length : 0,
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.term.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaTermsDetected', { count: termCount }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.term.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.year')"
          :value="yearFilter || t('tutoring2.common.all')"
          icon-name="calendar"
          :active="!!yearFilter"
          @click="yearFilter = yearFilter ? '' : String(new Date().getFullYear())"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.term.emptyTitle')"
      empty-description="Klik + untuk membuat term baru — rombongan kelompok belajar per periode."
      @retry="reload"
    >
      <!-- TODO i18n key: term empty-description -->
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.term') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.startDate') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.endDate') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.group') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in (data as BimbelTerm[])"
                :key="row.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ row.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatDate(row.start_date) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatDate(row.end_date) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="row.status_label" :tone="statusPillTone(row.status)" uppercase />
                </td>
                <td class="px-4 py-3 text-slate-600">
                  <!-- Absent means the endpoint did not compute it, not
                       that the term has no groups — so "—", not "0". -->
                  <template v-if="row.groups_count != null">
                    {{ row.groups_count }} {{ t('tutoring2.common.group').toLowerCase() }}
                  </template>
                  <template v-else>—</template>
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
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.term.newCta') }}
    </button>
  </div>
</template>
