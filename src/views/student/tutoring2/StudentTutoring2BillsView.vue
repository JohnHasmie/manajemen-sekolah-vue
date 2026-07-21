<!--
  StudentTutoring2BillsView.vue — Siswa bimbel tagihan list (WEB-5).

  MVP: backend `/tutoring2/student/bills` does not exist yet, so we
  derive nominal bill rows from the student's enrollments. The row
  shape (`StudentBillRow`) is intentionally scoped local — once
  BE-8+ exposes the real endpoint we swap the loader and delete the
  mapper without touching the template.
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
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

interface StudentBillRow {
  id: string;
  source: 'prepaid' | 'monthly' | 'per_session';
  amount: number;
  status: 'unpaid' | 'paid' | 'overdue';
  due_date: string;
}

// TODO WEB-5+ swap to /tutoring2/student/bills once BE exposes it
const { state, reload } = useDataRefresh<StudentBillRow[]>(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({ per_page: 100 });
  return items.map(enrollmentToBill);
});

function enrollmentToBill(e: BimbelEnrollment): StudentBillRow {
  let status: StudentBillRow['status'] = 'unpaid';
  if (e.status === 'graduated' || e.status === 'withdrawn') status = 'paid';
  else if (e.status === 'paused') status = 'overdue';
  return {
    id: e.id,
    source: e.billing_mode,
    amount: e.price_at_enrollment ?? 0,
    status,
    due_date: e.end_date ?? e.start_date ?? new Date().toISOString().slice(0, 10),
  };
}

const bills = computed<StudentBillRow[]>(() =>
  state.value.status === 'content' ? (state.value.data as StudentBillRow[]) : [],
);

const unpaidBills = computed(() => bills.value.filter((b) => b.status === 'unpaid'));
const overdueBills = computed(() => bills.value.filter((b) => b.status === 'overdue'));
const paidBills = computed(() => bills.value.filter((b) => b.status === 'paid'));
const pendingBills = computed(() =>
  bills.value.filter((b) => b.status === 'unpaid' || b.status === 'overdue'),
);
const totalAmount = computed(() => bills.value.reduce((acc, b) => acc + b.amount, 0));

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'clock',
    label: t('tutoring2.student.bills.kpiOutstanding'),
    value: String(unpaidBills.value.length),
  },
  {
    icon: 'alert-triangle',
    label: t('tutoring2.student.bills.kpiOverdue'),
    value: String(overdueBills.value.length),
    tone: 'red',
  },
  {
    icon: 'cash',
    label: t('tutoring2.student.bills.kpiTotal'),
    value: formatRp(totalAmount.value),
  },
  {
    icon: 'check-circle',
    label: t('tutoring2.student.bills.kpiPaid'),
    value: String(paidBills.value.length),
    tone: 'green',
  },
]);

function formatRp(n: number): string {
  return 'Rp ' + n.toLocaleString('id-ID');
}

function sourceLabel(src: StudentBillRow['source']): string {
  // Re-uses the tutoring2.common labels shipped for admin billing.
  switch (src) {
    case 'prepaid':
      return t('tutoring2.common.billingMode') + ' · prepaid';
    case 'monthly':
      return t('tutoring2.common.billingMode') + ' · bulanan';
    case 'per_session':
      return t('tutoring2.common.billingMode') + ' · per sesi';
  }
}

function statusLabel(s: StudentBillRow['status']): string {
  return t(`tutoring2.status.${s}`);
}

function statusTone(s: StudentBillRow['status']): StatusBadgeTone {
  switch (s) {
    case 'paid':
      return 'success';
    case 'unpaid':
      return 'warning';
    case 'overdue':
      return 'danger';
  }
}

function openPay(billId: string) {
  router.push({ name: 'student.tutoring2.pay', params: { billId } });
}

function stubReceipt() {
  toast.info(t('tutoring2.common.notAvailable'));
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
          <!-- Pending (unpaid + overdue) -->
          <section
            v-if="pendingBills.length"
            class="rounded-3xl border border-slate-100 bg-white shadow-sm"
          >
            <ul class="divide-y divide-slate-100">
              <li
                v-for="row in pendingBills"
                :key="row.id"
                class="flex items-center gap-3 px-4 py-3"
              >
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-bold text-slate-900">{{ sourceLabel(row.source) }}</p>
                  <p class="truncate text-2xs text-slate-500">
                    {{ formatRp(row.amount) }} · {{ t('tutoring2.student.bills.dueOn', { date: row.due_date }) }}
                  </p>
                </div>
                <StatusBadge :label="statusLabel(row.status)" :tone="statusTone(row.status)" uppercase />
                <Button variant="primary" size="sm" @click="openPay(row.id)">
                  {{ t('tutoring2.student.bills.payCta') }}
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
                  <p class="truncate text-sm font-bold text-slate-900">{{ sourceLabel(row.source) }}</p>
                  <p class="truncate text-2xs text-slate-500">{{ formatRp(row.amount) }}</p>
                </div>
                <StatusBadge :label="statusLabel(row.status)" :tone="statusTone(row.status)" uppercase />
                <Button variant="secondary" size="sm" @click="stubReceipt">
                  {{ t('tutoring2.student.bills.receiptCta') }}
                </Button>
              </li>
            </ul>
          </section>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
