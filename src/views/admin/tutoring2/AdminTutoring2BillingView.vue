<!--
  AdminTutoring2KeuanganView.vue — greenfield "Keuangan" (tagihan) list.

  Sibling of AdminTutoring2ProgramsView; same composition contract:
  BrandPageHeader → KpiStripCards → PageFilterToolbar → AsyncView →
  white rounded-3xl table surface → floating "+" CTA.
-->
<script setup lang="ts">
// TODO WEB-3+ swap to /tutoring-v2/bills once BE exposes the Finance filtered view (source_type ∈ TUTORING_*, bimbel_enrollment_id NOT NULL). MVP derives one nominal bill per active enrollment so the screen isn't empty.
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
import { FinanceService } from '@/services/finance.service';
import type { Bill } from '@/types/billing';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

// TODO WEB-3+ swap the table to /tutoring-v2/bills once the BE exposes
// a source_type-filtered Finance list. KPI counters below already pull
// real bills via FinanceService.listBills (all tenant bills; a bimbel
// tenant only has bimbel bills so the numbers land correct there).

const search = ref('');
const modeFilter = ref<string>(''); // '' | 'prepaid' | 'monthly' | 'per_session'
const statusFilter = ref<string>(''); // '' | 'unpaid' | 'paid' — nominal (see TODO)
const periodeFilter = ref<string>(''); // '' | '2026-07' | … — nominal (see TODO)

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

interface BillingBundle {
  enrollments: BimbelEnrollment[];
  bills: Bill[];
}

const { state, reload } = useDataRefresh<BillingBundle>(async () => {
  // Parallel fetch — enrollments feeds the table (until /tutoring-v2/bills
  // lands), bills feed the KPI aggregates so counters aren't stuck at 0.
  const [enrollmentsRes, billsRes] = await Promise.all([
    TutoringBimbelService.listEnrollments({
      per_page: 200,
      billing_mode: modeFilter.value || undefined,
    }),
    FinanceService.listBills({ per_page: 200 }),
  ]);
  return { enrollments: enrollmentsRes.items, bills: billsRes.items };
});

watch([debouncedSearch, modeFilter, statusFilter, periodeFilter], () => reload());
useAcademicYearWatcher(reload);

const kpiCards = computed<KpiCard[]>(() => {
  const bundle = (state.value.status === 'content' ? state.value.data : { enrollments: [], bills: [] }) as BillingBundle;
  const bills = bundle.bills;
  // paid = raw_status covers both 'paid' and 'verified' (Finance uses either).
  const isPaid = (b: Bill) => b.raw_status === 'paid' || b.raw_status === 'verified';
  const tertagih = bills.reduce((s, b) => s + b.amount, 0);
  const terbayar = bills.filter(isPaid).reduce((s, b) => s + b.amount, 0);
  const overdueBills = bills.filter((b) => !isPaid(b) && b.is_overdue);
  const menunggak = overdueBills.reduce((s, b) => s + b.amount, 0);
  return [
    { icon: 'file-text', label: t('tutoring2.admin.billing.kpiBilled'), value: `Rp ${tertagih.toLocaleString('id-ID')}` },
    { icon: 'circle-check', label: t('tutoring2.admin.billing.kpiPaid'), value: `Rp ${terbayar.toLocaleString('id-ID')}`, tone: terbayar > 0 ? 'green' : undefined },
    { icon: 'alert-triangle', label: t('tutoring2.admin.billing.kpiOverdue'), value: `Rp ${menunggak.toLocaleString('id-ID')}`, tone: menunggak > 0 ? 'red' : undefined },
    { icon: 'clock', label: t('tutoring2.admin.billing.kpiOverdueCount'), value: String(overdueBills.length), tone: overdueBills.length > 0 ? 'amber' : undefined },
  ];
});

// Table still projects enrollment rows (see TODO). Extract once for reuse.
const enrollmentsList = computed(() =>
  state.value.status === 'content' ? (state.value.data as BillingBundle).enrollments : []
);

function truncateId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
}

function formatRupiah(n: number | null | undefined): string {
  return n != null ? `Rp ${n.toLocaleString('id-ID')}` : '—';
}

// TODO WEB-3+ when /tutoring-v2/bills lands, extend to paid|unpaid|overdue.
// active|paid → success, unpaid → warning, overdue → danger.
function billStatusTone(status: 'active' | 'paid' | 'unpaid' | 'overdue'): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'paid': return 'success';
    case 'unpaid': return 'warning';
    case 'overdue': return 'danger';
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.billing.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaActiveEnrolls', { count: enrollmentsList.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.billing.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.billingMode')"
          :value="modeFilter || t('tutoring2.common.all')"
          icon-name="credit-card"
          :active="!!modeFilter"
          @click="modeFilter = modeFilter ? '' : 'monthly'"
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
          :value="periodeFilter || t('tutoring2.common.all')"
          icon-name="calendar"
          :active="!!periodeFilter"
          @click="periodeFilter = periodeFilter ? '' : '2026-07'"
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
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.mode') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.period') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.amount') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="e in enrollmentsList"
                :key="e.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-semibold text-slate-900">{{ e.student_name ?? truncateId(e.student_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ e.billing_mode_label ?? e.billing_mode }}</td>
                <td class="px-4 py-3 text-slate-600">
                  {{ e.billing_day_of_month ? t('tutoring2.admin.billing.dayPrefix', { day: e.billing_day_of_month }) : '—' }}
                </td>
                <td class="px-4 py-3 text-slate-600">{{ formatRupiah(e.price_at_enrollment) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="t('tutoring2.status.active')" :tone="billStatusTone('active')" uppercase />
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
