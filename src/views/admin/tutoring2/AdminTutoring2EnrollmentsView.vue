<!--
  AdminTutoring2PendaftaranView.vue — greenfield "Pendaftaran" list.

  Mirrors AdminTutoring2ProgramsView.vue exactly: BrandPageHeader →
  KpiStripCards → PageFilterToolbar (+ AppFilterChip trio) → AsyncView
  wrapping the table → floating "+ Daftarkan siswa" CTA. Data loads
  via `useDataRefresh(loader)` and re-runs when the debounced search,
  any filter chip, or the active academic year changes.
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
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'trial' | 'active' | 'paused' | 'graduated' | 'withdrawn'
const programFilter = ref<string>(''); // '' | program uuid
const billingModeFilter = ref<string>(''); // '' | 'prepaid' | 'monthly' | 'per_session'

const { t } = useI18n();

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({
    per_page: 100,
    status: statusFilter.value || undefined,
    program_id: programFilter.value || undefined,
    billing_mode: billingModeFilter.value || undefined,
  });
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return items;
  return items.filter(
    (e) =>
      e.student_id.toLowerCase().includes(q) ||
      e.program_id.toLowerCase().includes(q),
  );
});

watch([debouncedSearch, statusFilter, programFilter, billingModeFilter], () => {
  reload();
});
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  const active = items.filter((e) => e.status === 'active').length;
  const trial = items.filter((e) => e.status === 'trial').length;
  const exited = items.filter((e) => e.status === 'graduated' || e.status === 'withdrawn').length;
  return [
    { icon: 'circle-check', label: t('tutoring2.admin.enrollments.kpiActive'), value: String(active), tone: 'green' },
    { icon: 'sparkles', label: t('tutoring2.admin.enrollments.kpiTrial'), value: String(trial), tone: trial > 0 ? 'amber' : undefined },
    { icon: 'log-out', label: t('tutoring2.admin.enrollments.kpiGraduated'), value: String(exited) },
    { icon: 'calendar', label: t('tutoring2.admin.enrollments.kpiThisMonth'), value: '+23' },
  ];
});

function statusPillTone(status: BimbelEnrollment['status']): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'trial': return 'warning';
    case 'paused': return 'neutral';
    case 'graduated': return 'neutral';
    case 'withdrawn': return 'neutral';
    default: return 'neutral';
  }
}

function statusLabel(status: BimbelEnrollment['status']): string {
  return t(`tutoring2.status.${status}`);
}

function truncateId(id: string, len = 8): string {
  return id.length > len ? `${id.slice(0, len)}…` : id;
}

function remainingQuota(e: BimbelEnrollment): string {
  if (e.billing_mode !== 'prepaid') return '—';
  const total = e.total_sessions_snapshot;
  const rem = e.remaining_sessions;
  if (total == null || rem == null) return '—';
  return `${rem} / ${total}`;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.enrollments.title')"
      :meta="state.status === 'content'
        ? `${(state.data as BimbelEnrollment[]).length} ${t('tutoring2.admin.enrollments.title').toLowerCase()}`
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.enrollments.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="programFilter ? truncateId(programFilter) : t('tutoring2.common.all')"
          icon-name="book"
          :active="!!programFilter"
          @click="programFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.billingMode')"
          :value="billingModeFilter || t('tutoring2.common.all')"
          icon-name="wallet"
          :active="!!billingModeFilter"
          @click="billingModeFilter = billingModeFilter ? '' : 'prepaid'"
        />
      </template>
    </PageFilterToolbar>

    <!-- TODO i18n key: empty-description literal below -->
    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.enrollments.emptyTitle')"
      empty-description="Klik + untuk mendaftarkan siswa baru."
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.student') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.billingMode') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.remainingQuota') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="e in (data as BimbelEnrollment[])"
                :key="e.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ truncateId(e.student_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ truncateId(e.program_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ e.billing_mode_label ?? e.billing_mode }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="e.status_label ?? statusLabel(e.status)" :tone="statusPillTone(e.status)" uppercase />
                </td>
                <td class="px-4 py-3 text-slate-600">{{ remainingQuota(e) }}</td>
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
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.enrollments.newCta') }}
    </button>
  </div>
</template>
