<!--
  AdminTutoring2FinancialReportView.vue — greenfield "Laporan Keuangan"
  admin screen (WEB-15). Reads
  `GET /tutoring-v2/admin/reports/financial` and renders one row per
  calendar day across the picked range.

  Columns: date, bills_created_count, bills_created_amount (Rp),
  bills_paid_amount, bills_overdue_amount, refunds_amount (always 0
  in BE-28; column reserved for BE-33).

  KPI strip: total revenue in range (paid) + total outstanding
  (overdue).
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { toLocalYmd } from '@/lib/local-date';
import {
  csvFrom,
  downloadCsv,
  TutoringReportsService,
} from '@/services/tutoring2/reports';
import type { FinancialReportRow } from '@/types/tutoring2/report';

const { t } = useI18n();

const today = new Date();
const startOfRange = new Date(today);
startOfRange.setDate(startOfRange.getDate() - 29);
const from = ref<string>(toLocalYmd(startOfRange));
const to = ref<string>(toLocalYmd(today));

const { state, reload } = useDataRefresh(async () => {
  const res = await TutoringReportsService.getFinancialReport({
    from: from.value,
    to: to.value,
  });
  return res.rows;
});

watch([from, to], () => {
  if (from.value && to.value && from.value <= to.value) reload();
});

const rows = computed<FinancialReportRow[]>(() =>
  state.value.status === 'content' ? (state.value.data as FinancialReportRow[]) : [],
);

function formatRupiah(n: number): string {
  return `Rp ${Math.round(n).toLocaleString('id-ID')}`;
}

// Total revenue in range = sum of `bills_paid_amount` (money in);
// total outstanding = sum of `bills_overdue_amount` (money past due
// and still unpaid). Both are rolled up from per-day rows so the KPI
// stays consistent with what the table shows.
const kpiCards = computed<KpiCard[]>(() => {
  const list = rows.value;
  const totalRevenue = list.reduce((s, r) => s + r.bills_paid_amount, 0);
  const totalOutstanding = list.reduce((s, r) => s + r.bills_overdue_amount, 0);
  const totalBilled = list.reduce((s, r) => s + r.bills_created_amount, 0);
  const totalBillsCount = list.reduce((s, r) => s + r.bills_created_count, 0);
  return [
    {
      icon: 'circle-check',
      label: t('tutoring2.admin.reports.financial.kpiRevenue'),
      value: formatRupiah(totalRevenue),
      tone: totalRevenue > 0 ? 'green' : undefined,
    },
    {
      icon: 'alert-triangle',
      label: t('tutoring2.admin.reports.financial.kpiOutstanding'),
      value: formatRupiah(totalOutstanding),
      tone: totalOutstanding > 0 ? 'red' : undefined,
    },
    {
      icon: 'file-text',
      label: t('tutoring2.admin.reports.financial.kpiBilled'),
      value: formatRupiah(totalBilled),
    },
    {
      icon: 'clock',
      label: t('tutoring2.admin.reports.financial.kpiBillsCount'),
      value: String(totalBillsCount),
    },
  ];
});

function downloadPdf() {
  const url = TutoringReportsService.buildFinancialReportPdfUrl({
    from: from.value,
    to: to.value,
  });
  window.open(url, '_blank', 'noopener');
}

function exportCsv() {
  // Amounts written as plain numbers (no "Rp") so a spreadsheet can
  // sum them without a text-to-number conversion.
  const csv = csvFrom(rows.value as unknown as Record<string, unknown>[], [
    { key: 'date', header: t('tutoring2.common.date') },
    {
      key: 'bills_created_count',
      header: t('tutoring2.admin.reports.financial.colBillsCount'),
    },
    {
      key: 'bills_created_amount',
      header: t('tutoring2.admin.reports.financial.colBilled'),
    },
    {
      key: 'bills_paid_amount',
      header: t('tutoring2.admin.reports.financial.colPaid'),
    },
    {
      key: 'bills_overdue_amount',
      header: t('tutoring2.admin.reports.financial.colOverdue'),
    },
    {
      key: 'refunds_amount',
      header: t('tutoring2.admin.reports.financial.colRefunds'),
    },
  ]);
  downloadCsv(csv, `laporan-keuangan-${from.value}_${to.value}.csv`);
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.reports.financial.title')"
      :meta="
        state.status === 'content'
          ? t('tutoring2.admin.reports.meta', { count: rows.length })
          : t('tutoring2.common.loading')
      "
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <section class="bg-white border border-slate-200 rounded-2xl p-3">
      <div class="flex items-center gap-2 flex-wrap">
        <label class="inline-flex items-center gap-2 text-sm font-medium text-slate-600">
          <span>{{ t('tutoring2.admin.reports.from') }}</span>
          <input
            v-model="from"
            type="date"
            class="rounded-xl border border-slate-200 px-3 py-2 text-sm"
          />
        </label>
        <label class="inline-flex items-center gap-2 text-sm font-medium text-slate-600">
          <span>{{ t('tutoring2.admin.reports.to') }}</span>
          <input
            v-model="to"
            type="date"
            class="rounded-xl border border-slate-200 px-3 py-2 text-sm"
          />
        </label>
        <span class="flex-1"></span>
        <Button variant="secondary" size="sm" @click="exportCsv">
          {{ t('tutoring2.admin.reports.downloadCsv') }}
        </Button>
        <Button variant="primary" size="sm" @click="downloadPdf">
          {{ t('tutoring2.admin.reports.downloadPdf') }}
        </Button>
      </div>
    </section>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.reports.financial.emptyTitle')"
      :empty-description="t('tutoring2.admin.reports.financial.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.date') }}</th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.financial.colBillsCount') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.financial.colBilled') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.financial.colPaid') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.financial.colOverdue') }}
                </th>
                <th class="px-4 py-3 font-bold text-right">
                  {{ t('tutoring2.admin.reports.financial.colRefunds') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in rows"
                :key="r.date"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-semibold text-slate-900">{{ r.date }}</td>
                <td class="px-4 py-3 text-right text-slate-700">{{ r.bills_created_count }}</td>
                <td class="px-4 py-3 text-right text-slate-700">
                  {{ formatRupiah(r.bills_created_amount) }}
                </td>
                <td class="px-4 py-3 text-right text-slate-700">
                  {{ formatRupiah(r.bills_paid_amount) }}
                </td>
                <td class="px-4 py-3 text-right text-slate-700">
                  {{ formatRupiah(r.bills_overdue_amount) }}
                </td>
                <td class="px-4 py-3 text-right text-slate-700">
                  {{ formatRupiah(r.refunds_amount) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
