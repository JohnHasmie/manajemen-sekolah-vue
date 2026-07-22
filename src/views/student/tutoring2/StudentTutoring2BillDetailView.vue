<!--
  StudentTutoring2BillDetailView.vue — Siswa bimbel tagihan detail (WEB-7).

  Loads a single bill via BE-8 `GET /api/tutoring-v2/bills/:id`. BE
  enforces `view_own` — an unrelated bill 403s. Renders a hero card
  (amount + due + status) and a payment-history section that is
  intentionally empty until BE ships a `bill_payments` list endpoint
  (out of scope for BE-8; deferred to invoice/QRIS territory in
  BE-11). Primary CTA hands off to the existing checkout view
  (`student.tutoring2.pay`) which owns method-picker + confirm.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
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
const route = useRoute();
const router = useRouter();

const billId = computed<string>(() => String(route.params.id));

const { state, reload } = useDataRefresh<BimbelBill>(async () => {
  return TutoringBimbelService.getBill(billId.value);
});

const bill = computed<BimbelBill | null>(() =>
  state.value.status === 'content' ? (state.value.data as BimbelBill) : null,
);

type EffectiveStatus = 'unpaid' | 'paid' | 'overdue' | 'pending' | 'partial';
function effectiveStatus(b: BimbelBill): EffectiveStatus {
  if (b.status === 'paid') return 'paid';
  if (b.status === 'pending' || b.status === 'partial') {
    return b.status as EffectiveStatus;
  }
  if (b.due_date) {
    const dueMs = new Date(b.due_date).getTime();
    if (!Number.isNaN(dueMs) && dueMs < Date.now()) return 'overdue';
  }
  return 'unpaid';
}

const isPaid = computed(() => bill.value && effectiveStatus(bill.value) === 'paid');

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

function sourceLabel(b: BimbelBill): string {
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

function formatRp(n: number | null | undefined): string {
  return n != null ? 'Rp ' + n.toLocaleString('id-ID') : '—';
}

function openCheckout() {
  if (!bill.value) return;
  router.push({ name: 'student.tutoring2.pay', params: { billId: bill.value.id } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.bills.detail.title')"
      :meta="t('tutoring2.bills.detail.meta')"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.bills.detail.emptyTitle')"
      :empty-description="t('tutoring2.bills.detail.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <template v-if="bill">
          <!-- Hero card: amount + due + status -->
          <section class="rounded-3xl border border-slate-100 bg-white p-5 shadow-sm">
            <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">
              {{ sourceLabel(bill) }}
            </p>
            <p class="mt-2 text-3xl font-black text-slate-900">
              {{ formatRp(bill.amount) }}
            </p>
            <div class="mt-3 flex items-center gap-3">
              <StatusBadge
                :label="statusLabel(effectiveStatus(bill))"
                :tone="statusTone(effectiveStatus(bill))"
                uppercase
              />
              <span v-if="bill.due_date" class="text-2xs text-slate-500">
                {{ t('tutoring2.student.bills.dueOn', { date: bill.due_date }) }}
              </span>
            </div>
            <div v-if="bill.student_name" class="mt-4 border-t border-slate-100 pt-3 text-sm text-slate-600">
              <span class="font-semibold text-slate-500">{{ t('tutoring2.common.student') }}:</span>
              {{ bill.student_name }}
              <span v-if="bill.student_number" class="text-slate-400"> · {{ bill.student_number }}</span>
            </div>
          </section>

          <!-- Payment history — empty until BE-11 lands -->
          <section class="rounded-3xl border border-slate-100 bg-white shadow-sm">
            <header class="border-b border-slate-100 px-4 py-3">
              <h3 class="text-sm font-bold text-slate-900">
                {{ t('tutoring2.bills.detail.paymentsSection') }}
              </h3>
            </header>
            <div class="px-4 py-6 text-center text-sm text-slate-400">
              {{ t('tutoring2.bills.detail.noPayments') }}
            </div>
          </section>
        </template>
      </template>
    </AsyncView>

    <!-- Sticky "Bayar sekarang" CTA when the bill is not paid -->
    <div
      v-if="bill && !isPaid"
      class="fixed inset-x-0 bottom-0 z-40 border-t border-slate-100 bg-white/95 p-3 backdrop-blur"
    >
      <div class="mx-auto max-w-2xl">
        <Button variant="primary" block @click="openCheckout">
          {{ t('tutoring2.student.bills.payCta') }}
        </Button>
      </div>
    </div>
  </div>
</template>
