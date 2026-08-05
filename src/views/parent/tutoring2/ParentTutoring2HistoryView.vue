<!--
  ParentTutoring2HistoryView.vue — Wali bimbel payment history (WEB-7).

  Wired to BE-8 `/api/tutoring-v2/bills?status=paid`. Backend scopes
  automatically to the wali's own children via `tutoring.bill.view_own`.

  KPI focuses on annual totals: total paid this year, count paid this
  year, count children with paid bills. The list surfaces paid month
  / child name / amount so wali can eyeball the payment cadence.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Button from '@/components/ui/Button.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelBill,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const toast = useToast();

const { state, reload } = useDataRefresh<BimbelBill[]>(async () => {
  const { items } = await TutoringBimbelService.listBills({
    status: 'paid',
    per_page: 50,
  });
  return items;
});

const history = computed<BimbelBill[]>(() =>
  state.value.status === 'content' ? (state.value.data as BimbelBill[]) : [],
);

const currentYear = new Date().getFullYear();
function billYear(b: BimbelBill): number | null {
  // Prefer `month` (YYYY-MM) — that's the accounting period the bill
  // was raised for. Fall back to updated_at (when it was marked paid).
  if (b.month) {
    const y = Number(b.month.slice(0, 4));
    if (Number.isFinite(y)) return y;
  }
  if (b.updated_at) {
    const y = new Date(b.updated_at).getFullYear();
    if (Number.isFinite(y)) return y;
  }
  return null;
}

const thisYearBills = computed(() =>
  history.value.filter((b) => billYear(b) === currentYear),
);
const totalPaidThisYear = computed(() =>
  thisYearBills.value.reduce((acc, b) => acc + (b.amount ?? 0), 0),
);
const uniqueChildrenPaid = computed(() => {
  const s = new Set<string>();
  for (const b of history.value) s.add(b.student_id);
  return s.size;
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'cash',
    label: t('tutoring2.parent.history.kpiPaidThisYear'),
    value: rupiah(totalPaidThisYear.value),
    tone: 'brand',
  },
  {
    icon: 'check-circle',
    label: t('tutoring2.status.paid'),
    value: history.value.length,
    tone: 'green',
  },
  {
    icon: 'calendar',
    label: t('tutoring2.parent.history.kpiThisYearCount'),
    value: thisYearBills.value.length,
    tone: 'amber',
  },
  {
    icon: 'users',
    label: t('tutoring2.parent.pay.kpiTotalChildren'),
    value: uniqueChildrenPaid.value,
    tone: 'violet',
  },
]);

function rupiah(v: number | null | undefined): string {
  return v != null ? `Rp ${v.toLocaleString('id-ID')}` : '—';
}

function paidDate(b: BimbelBill): string {
  // Prefer `month` display (e.g. "2026-07"), else fall back to
  // updated_at as the payment date proxy.
  if (b.month) return b.month;
  if (b.updated_at) return b.updated_at.slice(0, 10);
  return '—';
}

function statusTone(): StatusBadgeTone {
  return 'success';
}

function stubReceipt() {
  toast.info(t('tutoring2.common.notAvailable'));
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.history.title')"
      :meta="t('tutoring2.parent.history.meta', { count: history.length })"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.history.emptyTitle')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="row in history"
              :key="row.id"
              class="flex items-center gap-3 px-4 py-3"
            >
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ paidDate(row) }}
                </p>
                <p class="truncate text-2xs text-slate-500">
                  {{ row.student_name ?? row.student_id.slice(0, 8) }} · {{ rupiah(row.amount) }}
                </p>
              </div>
              <StatusBadge :label="t('tutoring2.status.paid')" :tone="statusTone()" uppercase />
              <Button variant="ghost" size="sm" @click="stubReceipt">
                {{ t('tutoring2.student.bills.receiptCta') }}
              </Button>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
