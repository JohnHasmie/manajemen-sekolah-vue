<!--
  StudentTutoring2BillsView.vue — Siswa bimbel tagihan list (WEB-7).

  Wired to BE-8 `/api/tutoring-v2/bills`. Backend automatically scopes
  to the caller's own bills via `tutoring.bill.view_own`. The list
  therefore requires no explicit `student_id` filter — we just call
  `listBills({ per_page: 50 })` and render whatever comes back.

  KPI strip is computed client-side from the response so we don't
  waste a `/summary` roundtrip when the list already contains
  everything we need (small dataset per student).

  Tapping an unpaid/overdue row navigates to
  `student.tutoring2.bill-detail` for the summary + payment history
  view added in WEB-7. Paid rows are informational and render a
  disabled "Kwitansi" button (real receipt endpoint is a future MR).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelBill,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

const { state, reload } = useDataRefresh<BimbelBill[]>(async () => {
  const { items } = await TutoringBimbelService.listBills({ per_page: 50 });
  return items;
});

const bills = computed<BimbelBill[]>(() =>
  state.value.status === 'content' ? (state.value.data as BimbelBill[]) : [],
);

// Effective status = raw status + client-side "overdue" derivation.
// BE keeps status limited to unpaid|pending|partial|paid; overdue is
// UI-only (unpaid past due_date). Kept as a computed row-level tag.
type EffectiveStatus = 'unpaid' | 'paid' | 'overdue' | 'pending' | 'partial';
function effectiveStatus(b: BimbelBill): EffectiveStatus {
  if (b.status === 'paid') return 'paid';
  if (b.status === 'pending' || b.status === 'partial') {
    return b.status as EffectiveStatus;
  }
  // unpaid — check overdue.
  if (b.due_date) {
    const dueMs = new Date(b.due_date).getTime();
    if (!Number.isNaN(dueMs) && dueMs < Date.now()) return 'overdue';
  }
  return 'unpaid';
}

const unpaidBills = computed(() =>
  bills.value.filter((b) => effectiveStatus(b) !== 'paid'),
);
const paidBills = computed(() =>
  bills.value.filter((b) => effectiveStatus(b) === 'paid'),
);
const overdueBills = computed(() =>
  bills.value.filter((b) => effectiveStatus(b) === 'overdue'),
);

const totalTertagih = computed(() =>
  bills.value.reduce((acc, b) => acc + (b.amount ?? 0), 0),
);
const totalTerbayar = computed(() =>
  paidBills.value.reduce((acc, b) => acc + (b.amount ?? 0), 0),
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'file-text',
    label: t('tutoring2.student.bills.kpiTotal'),
    value: formatRp(totalTertagih.value),
    tone: 'brand',
  },
  {
    icon: 'check-circle',
    label: t('tutoring2.student.bills.kpiPaid'),
    value: formatRp(totalTerbayar.value),
    tone: totalTerbayar.value > 0 ? 'green' : undefined,
  },
  {
    icon: 'alert-triangle',
    label: t('tutoring2.student.bills.kpiOverdue'),
    value: String(overdueBills.value.length),
    tone: overdueBills.value.length > 0 ? 'red' : undefined,
  },
  {
    icon: 'clock',
    label: t('tutoring2.student.bills.kpiOutstanding'),
    value: String(unpaidBills.value.length),
    tone: unpaidBills.value.length > 0 ? 'amber' : undefined,
  },
]);

function formatRp(n: number): string {
  return 'Rp ' + n.toLocaleString('id-ID');
}

function sourceLabel(b: BimbelBill): string {
  // Prefer BE-supplied label. Fall back to a source_type shorthand.
  if (b.source_label) return b.source_label;
  switch (b.source_type) {
    case 'TUTORING_PREPAID':
      return t('tutoring2.common.billingMode') + ' · prepaid';
    case 'TUTORING_MONTHLY':
      return t('tutoring2.common.billingMode') + ' · bulanan';
    case 'TUTORING_SESSION':
      return t('tutoring2.common.billingMode') + ' · per sesi';
    default:
      return b.payment_type_name ?? '—';
  }
}

function statusLabel(s: EffectiveStatus): string {
  switch (s) {
    case 'paid':
      return t('tutoring2.status.paid');
    case 'overdue':
      return t('tutoring2.status.overdue');
    case 'pending':
    case 'partial':
    case 'unpaid':
    default:
      return t('tutoring2.status.unpaid');
  }
}

function statusTone(s: EffectiveStatus): StatusBadgeTone {
  switch (s) {
    case 'paid':
      return 'success';
    case 'overdue':
      return 'danger';
    case 'pending':
    case 'partial':
    case 'unpaid':
    default:
      return 'warning';
  }
}

function openDetail(billId: string) {
  router.push({ name: 'student.tutoring2.bill-detail', params: { id: billId } });
}

</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.bills.title')"
      :meta="state.status === 'content' ? t('tutoring2.student.bills.meta', { count: unpaidBills.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="4"
      :empty-title="t('tutoring2.student.bills.emptyTitle')"
      :empty-description="t('tutoring2.student.bills.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="space-y-md">
          <!-- Pending (unpaid + overdue + pending + partial) -->
          <section
            v-if="unpaidBills.length"
            class="rounded-3xl border border-slate-100 bg-white shadow-sm"
          >
            <ul class="divide-y divide-slate-100">
              <li
                v-for="row in unpaidBills"
                :key="row.id"
                class="flex items-center gap-3 px-4 py-3"
              >
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-bold text-slate-900">{{ sourceLabel(row) }}</p>
                  <p class="truncate text-2xs text-slate-500">
                    {{ formatRp(row.amount) }}
                    <template v-if="row.due_date">
                      · {{ t('tutoring2.student.bills.dueOn', { date: row.due_date }) }}
                    </template>
                  </p>
                </div>
                <StatusBadge
                  :label="statusLabel(effectiveStatus(row))"
                  :tone="statusTone(effectiveStatus(row))"
                  uppercase
                />
                <Button variant="primary" size="sm" @click="openDetail(row.id)">
                  {{ t('tutoring2.bills.detail.viewCta') }}
                </Button>
              </li>
            </ul>
          </section>

          <!-- Paid history -->
          <section
            v-if="paidBills.length"
            class="rounded-3xl border border-slate-100 bg-white shadow-sm"
          >
            <header class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
              <h3 class="text-sm font-bold text-slate-900">
                {{ t('tutoring2.student.bills.history') }}
              </h3>
            </header>
            <ul class="divide-y divide-slate-100">
              <li
                v-for="row in paidBills"
                :key="row.id"
                class="flex items-center gap-3 px-4 py-3"
              >
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-bold text-slate-900">{{ sourceLabel(row) }}</p>
                  <p class="truncate text-2xs text-slate-500">{{ formatRp(row.amount) }}</p>
                </div>
                <StatusBadge
                  :label="statusLabel(effectiveStatus(row))"
                  :tone="statusTone(effectiveStatus(row))"
                  uppercase
                />
              </li>
            </ul>
          </section>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
