<!--
  AdminTutoring2BillingView.vue — greenfield "Keuangan" (tagihan) list.

  Reads BOTH the KPI aggregate + the paginated bill list from
  /api/tutoring-v2/bills* (BE-8). Drops the temporary
  FinanceService.listBills bridge that was in place while the
  greenfield endpoints didn't exist.
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
  type BimbelBill,
  type BimbelBillsSummary,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'unpaid' | 'paid' | 'pending' | 'partial'
const sourceFilter = ref<string>(''); // '' | 'TUTORING_PREPAID' | 'TUTORING_MONTHLY' | 'TUTORING_SESSION'
const monthFilter = ref<string>(''); // '' | 'YYYY-MM'

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

interface BillingBundle {
  bills: BimbelBill[];
  summary: BimbelBillsSummary;
}

const { state, reload } = useDataRefresh<BillingBundle>(async () => {
  const [billsRes, summaryRes] = await Promise.all([
    TutoringBimbelService.listBills({
      per_page: 100,
      status: statusFilter.value || undefined,
      source_type: sourceFilter.value || undefined,
      month: monthFilter.value || undefined,
    }),
    TutoringBimbelService.getBillsSummary({
      source_type: sourceFilter.value || undefined,
      month: monthFilter.value || undefined,
    }),
  ]);
  return { bills: billsRes.items, summary: summaryRes };
});

watch([debouncedSearch, statusFilter, sourceFilter, monthFilter], () => reload());
useAcademicYearWatcher(reload);

const billsList = computed(() => {
  const bundle = state.value.status === 'content' ? (state.value.data as BillingBundle) : null;
  if (!bundle) return [];
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return bundle.bills;
  return bundle.bills.filter((b) =>
    (b.student_name ?? b.student_id).toLowerCase().includes(q)
    || (b.student_number ?? '').toLowerCase().includes(q),
  );
});

const kpiCards = computed<KpiCard[]>(() => {
  const bundle = state.value.status === 'content' ? (state.value.data as BillingBundle) : null;
  const s: BimbelBillsSummary = bundle?.summary ?? { tertagih: 0, terbayar: 0, menunggak: 0, overdue_count: 0 };
  return [
    { icon: 'file-text', label: t('tutoring2.admin.billing.kpiBilled'), value: `Rp ${s.tertagih.toLocaleString('id-ID')}` },
    { icon: 'circle-check', label: t('tutoring2.admin.billing.kpiPaid'), value: `Rp ${s.terbayar.toLocaleString('id-ID')}`, tone: s.terbayar > 0 ? 'green' : undefined },
    { icon: 'alert-triangle', label: t('tutoring2.admin.billing.kpiOverdue'), value: `Rp ${s.menunggak.toLocaleString('id-ID')}`, tone: s.menunggak > 0 ? 'red' : undefined },
    { icon: 'clock', label: t('tutoring2.admin.billing.kpiOverdueCount'), value: String(s.overdue_count), tone: s.overdue_count > 0 ? 'amber' : undefined },
  ];
});

function truncateId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
}

function formatRupiah(n: number | null | undefined): string {
  return n != null ? `Rp ${n.toLocaleString('id-ID')}` : '—';
}

function billStatusTone(status: string): StatusBadgeTone {
  switch (status) {
    case 'paid': return 'success';
    case 'unpaid': return 'warning';
    case 'pending': return 'warning';
    case 'partial': return 'warning';
    default: return 'neutral';
  }
}

function billStatusLabel(status: string): string {
  // Keep raw values for now; upstream i18n mapping can happen in a
  // future MR once product locks the copy.
  return status.toUpperCase();
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.billing.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaBills', { count: billsList.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.billing.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.source')"
          :value="sourceFilter || t('tutoring2.common.all')"
          icon-name="credit-card"
          :active="!!sourceFilter"
          @click="sourceFilter = sourceFilter ? '' : 'TUTORING_MONTHLY'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'unpaid'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.period')"
          :value="monthFilter || t('tutoring2.common.all')"
          icon-name="calendar"
          :active="!!monthFilter"
          @click="monthFilter = monthFilter ? '' : new Date().toISOString().slice(0, 7)"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.billing.emptyTitle')"
      :empty-description="t('tutoring2.admin.billing.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.student') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.source') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.dueDate') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.amount') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="b in billsList"
                :key="b.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-semibold text-slate-900">{{ b.student_name ?? truncateId(b.student_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ b.source_label ?? b.source_type }}</td>
                <td class="px-4 py-3 text-slate-600">{{ b.due_date ?? '—' }}</td>
                <td class="px-4 py-3 font-semibold text-slate-900">{{ formatRupiah(b.amount) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="billStatusLabel(b.status)" :tone="billStatusTone(b.status)" uppercase />
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
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.billing.newCta') }}
    </button>
  </div>
</template>
