<!--
  AdminTutoring2PayoutSummaryView.vue — WEB-16 (BE-26 admin summary).

  Tenant-wide monthly payout aggregate: one row per tutor for the
  selected `YYYY-MM`. Backing endpoint is a COMPUTED aggregate (no
  persistence) so we don't cache; the month selector re-fetches.

  Kept in its own route rather than embedded in the Requests view so
  the sidebar has a stable "Summary" landing. Ability:
  `tutoring.payout.view_all`.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import FormField from '@/components/ui/FormField.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { toLocalYm } from '@/lib/local-date';
import { PayoutsService } from '@/services/tutoring2/payouts';
import type { PayoutSummaryMeta, PayoutSummaryRow } from '@/types/tutoring2/payout';

const { t } = useI18n();

const month = ref(toLocalYm());

interface SummaryBundle {
  rows: PayoutSummaryRow[];
  meta?: PayoutSummaryMeta;
}

const { state, reload } = useDataRefresh<SummaryBundle>(async () => {
  const { rows, meta } = await PayoutsService.getAdminSummary({ month: month.value });
  return { rows, meta };
});
watch(month, () => reload());

const totals = computed(() => {
  const bundle = state.value.status === 'content' ? (state.value.data as SummaryBundle) : null;
  if (!bundle) return { base: 0, adj: 0, net: 0, sessions: 0 };
  return bundle.rows.reduce(
    (acc, r) => {
      acc.base += r.base_amount;
      acc.adj += r.adjustments;
      acc.net += r.net_amount;
      acc.sessions += r.sessions_taught;
      return acc;
    },
    { base: 0, adj: 0, net: 0, sessions: 0 },
  );
});

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'users', label: t('tutoring2.admin.payoutSummary.kpiTutors'), value: String(state.value.status === 'content' ? (state.value.data as SummaryBundle).meta?.tutor_count ?? 0 : 0) },
  { icon: 'calendar-check', label: t('tutoring2.admin.payoutSummary.kpiSessions'), value: String(totals.value.sessions) },
  { icon: 'wallet', label: t('tutoring2.admin.payoutSummary.kpiBase'), value: `Rp ${totals.value.base.toLocaleString('id-ID')}` },
  { icon: 'file-text', label: t('tutoring2.admin.payoutSummary.kpiNet'), value: `Rp ${totals.value.net.toLocaleString('id-ID')}`, tone: 'green' },
]);

function fmt(n: number): string {
  return `Rp ${n.toLocaleString('id-ID')}`;
}

function truncateId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.payoutSummary.title')"
      :meta="t('tutoring2.admin.payoutSummary.meta', { month })"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <div class="flex items-end gap-3">
      <FormField
        v-model="month"
        :label="t('tutoring2.common.period')"
        type="text"
        placeholder="YYYY-MM"
      />
    </div>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="5"
      :empty-title="t('tutoring2.admin.payoutSummary.emptyTitle')"
      :empty-description="t('tutoring2.admin.payoutSummary.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutSummary.sessionsTaught') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutSummary.baseAmount') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutSummary.adjustments') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutSummary.netAmount') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in (state.status === 'content' ? (state.data as SummaryBundle).rows : [])"
                :key="r.tutor_id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-semibold text-slate-900">{{ r.tutor_name || truncateId(r.tutor_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ r.sessions_taught }}</td>
                <td class="px-4 py-3 text-slate-600">{{ fmt(r.base_amount) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ fmt(r.adjustments) }}</td>
                <td class="px-4 py-3 font-semibold text-slate-900">{{ fmt(r.net_amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
