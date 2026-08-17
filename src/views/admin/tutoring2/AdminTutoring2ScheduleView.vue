<!--
  AdminTutoring2JadwalView.vue — greenfield "Jadwal sesi" list.

  Sibling to AdminTutoring2ProgramsView (the WEB-3 exemplar); same
  composition contract top→bottom:

    1. `BrandPageHeader` — role="admin", gradient tier header.
    2. `KpiStripCards` — 4 tiles.
    3. `PageFilterToolbar` — search + `AppFilterChip`s.
    4. `AsyncView` state machine over `TutoringBimbelService.listSessions`.
    5. Floating "+ Buat sesi" CTA.
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
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'scheduled' | 'done' | 'cancelled'
const groupFilter = ref<string>('');  // '' | learning_group_id
const tutorFilter = ref<string>('');  // '' | tutor_id
const periodFilter = ref<'all' | 'week' | 'month'>('all'); // nominal, UI-only

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 100,
    status: statusFilter.value || undefined,
    learning_group_id: groupFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter, groupFilter, tutorFilter, periodFilter], () => reload());

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelSession[];
  const scheduled = items.filter((s) => s.status === 'scheduled').length;
  const inProgress = items.filter((s) => s.status === 'in_progress').length;
  const done = items.filter((s) => s.status === 'done').length;
  const cancelled = items.filter((s) => s.status === 'cancelled').length;
  return [
    { icon: 'calendar', label: t('tutoring2.admin.schedule.kpiScheduled'), value: String(scheduled) },
    { icon: 'play', label: t('tutoring2.admin.schedule.kpiInProgress'), value: String(inProgress), tone: inProgress > 0 ? 'amber' : undefined },
    { icon: 'circle-check', label: t('tutoring2.admin.schedule.kpiDone'), value: String(done) },
    { icon: 'x', label: t('tutoring2.admin.schedule.kpiCancelled'), value: String(cancelled), tone: cancelled > 0 ? 'amber' : undefined },
  ];
});

function statusLabel(status: BimbelSession['status']): string {
  const key = status === 'in_progress' ? 'inProgress' : status;
  return t(`tutoring2.status.${key}`);
}

function statusPillTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'scheduled': return 'neutral';
    case 'in_progress': return 'info';
    case 'done': return 'success';
    case 'cancelled': return 'danger';
  }
}

function formatWaktu(iso: string): string {
  return new Date(iso).toLocaleString('id-ID', { weekday: 'short', hour: '2-digit', minute: '2-digit' });
}

function truncateId(id: string | null | undefined, len = 8): string {
  if (!id) return '—';
  return id.length > len ? id.slice(0, len) : id;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.schedule.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaSessionsWeek', { count: (state.data as BimbelSession[]).length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.schedule.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'scheduled'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.group')"
          :value="groupFilter ? truncateId(groupFilter) : t('tutoring2.common.all')"
          icon-name="users"
          :active="!!groupFilter"
          @click="groupFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.tutor')"
          :value="tutorFilter ? truncateId(tutorFilter) : t('tutoring2.common.all')"
          icon-name="user"
          :active="!!tutorFilter"
          @click="tutorFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.period')"
          :value="periodFilter === 'all' ? t('tutoring2.common.all') : periodFilter === 'week' ? t('tutoring2.common.thisWeek') : t('tutoring2.common.thisMonth')"
          icon-name="calendar"
          :active="periodFilter !== 'all'"
          @click="periodFilter = periodFilter === 'all' ? 'week' : periodFilter === 'week' ? 'month' : 'all'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.schedule.emptyTitle')"
      :empty-description="t('tutoring2.admin.schedule.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.time') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.group') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.room') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="s in (data as BimbelSession[])"
                :key="s.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ formatWaktu(s.starts_at) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ truncateId(s.learning_group_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ truncateId(s.tutor_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ s.room ?? '—' }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="s.status_label ?? statusLabel(s.status)" :tone="statusPillTone(s.status)" uppercase />
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
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.schedule.newCta') }}
    </button>
  </div>
</template>
