<!--
  AdminTutoring2ProgramsView.vue — greenfield "Program & Paket" list.

  Reference implementation for the WEB-3 admin screens. Every literal
  Indonesian string is fetched via `t('tutoring2.…')`; the display copy
  lives only in the i18n locale files (id.json / en.json). Follow this
  pattern in every other tutoring2/*View.vue.
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
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'draft' | 'active' | 'archived'
const gradeLevelFilter = ref<string>(''); // '' | 'SD' | 'SMP' | 'SMA' | 'Umum'

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listPrograms({
    per_page: 50,
    search: debouncedSearch.value || undefined,
    status: statusFilter.value || undefined,
    grade_level: gradeLevelFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter, gradeLevelFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelProgram[];
  const draft = items.filter((p) => p.status === 'draft').length;
  const packages = items.reduce((sum, p) => sum + (p.packages_count ?? 0), 0);
  const minPrice = items.reduce<number | null>((min, p) => {
    if (p.min_price == null) return min;
    return min == null || p.min_price < min ? p.min_price : min;
  }, null);
  return [
    { icon: 'book', label: t('tutoring2.admin.programs.kpiActivePrograms'), value: String(items.length) },
    { icon: 'package', label: t('tutoring2.admin.programs.kpiActivePackages'), value: String(packages) },
    { icon: 'tag', label: t('tutoring2.admin.programs.kpiStartFrom'), value: minPrice != null ? formatRupiah(minPrice) : '—' },
    { icon: 'file-pencil', label: t('tutoring2.admin.programs.kpiDrafts'), value: String(draft), tone: draft > 0 ? 'amber' : undefined },
  ];
});

function statusPillTone(status: BimbelProgram['status']): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'draft': return 'neutral';
    case 'archived': return 'neutral';
  }
}

function statusLabel(status: BimbelProgram['status']): string {
  return t(`tutoring2.status.${status}`);
}

function formatRupiah(n: number | null | undefined): string {
  return n != null ? `Rp ${n.toLocaleString('id-ID')}` : '—';
}

const activeCount = computed(() =>
  state.value.status === 'content' ? (state.value.data as BimbelProgram[]).length : 0,
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.programs.title')"
      :meta="state.status === 'content' ? t('tutoring2.admin.programs.meta', { count: activeCount }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.programs.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.gradeLevel')"
          :value="gradeLevelFilter || t('tutoring2.common.all')"
          icon-name="stairs"
          :active="!!gradeLevelFilter"
          @click="gradeLevelFilter = gradeLevelFilter ? '' : 'SMA'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.programs.emptyTitle')"
      :empty-description="t('tutoring2.admin.programs.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.gradeLevel') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.programs.kpiActivePackages') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.startingPrice') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="p in (data as BimbelProgram[])"
                :key="p.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ p.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ p.grade_level ?? '—' }}</td>
                <td class="px-4 py-3 text-slate-600">{{ p.packages_count ?? 0 }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatRupiah(p.min_price) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="p.status_label ?? statusLabel(p.status)" :tone="statusPillTone(p.status)" uppercase />
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
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.programs.newCta') }}
    </button>
  </div>
</template>
