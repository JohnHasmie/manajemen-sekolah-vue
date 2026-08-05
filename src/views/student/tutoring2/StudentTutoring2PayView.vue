<!--
  StudentTutoring2PayView.vue — Siswa bimbel checkout screen (WEB-5).

  MVP: no real bill lookup — the route's `:billId` param is accepted
  but ignored; the summary values are placeholders until a payment
  gateway is wired up (BE-8+). The template still models the final
  flow (summary → method picker → sticky confirm CTA) so we don't
  redesign later.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const toast = useToast();

type PayMethod = 'va' | 'ewallet' | 'qris' | 'transfer';
const selectedMethod = ref<PayMethod>('va');

// TODO WEB-5+ replace with real bill fetch once BE exposes /tutoring2/student/bills/:id
const summary = {
  itemDesc: 'SPP Januari 2026',
  amount: 750000,
  adminFee: 2500,
};
const total = summary.amount + summary.adminFee;

function formatRp(n: number): string {
  return 'Rp ' + n.toLocaleString('id-ID');
}

function pay() {
  toast.info(t('tutoring2.student.pay.stubToast'));
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.pay.title')"
    />

    <!-- Summary -->
    <section class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
      <p class="text-sm font-bold text-slate-900">{{ summary.itemDesc }}</p>
      <div class="mt-3 space-y-2 text-sm">
        <div class="flex justify-between">
          <span class="text-slate-500">{{ t('tutoring2.common.amount') }}</span>
          <span class="font-bold text-slate-900">{{ formatRp(summary.amount) }}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-500">{{ t('tutoring2.student.pay.adminFee') }}</span>
          <span class="font-bold text-slate-900">{{ formatRp(summary.adminFee) }}</span>
        </div>
        <div class="flex justify-between border-t border-slate-100 pt-2">
          <span class="font-bold text-slate-900">{{ t('tutoring2.student.pay.total') }}</span>
          <span class="font-bold text-slate-900">{{ formatRp(total) }}</span>
        </div>
      </div>
    </section>

    <!-- Method picker -->
    <section>
      <h3 class="text-sm font-bold text-slate-900 mb-2">
        {{ t('tutoring2.student.pay.selectMethod') }}
      </h3>
      <div class="space-y-2">
        <button
          type="button"
          class="flex items-center gap-3 w-full rounded-2xl border p-3 text-left"
          :class="selectedMethod === 'va' ? 'border-brand-azure bg-brand-azure/5' : 'border-slate-200'"
          @click="selectedMethod = 'va'"
        >
          <span class="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-azure/10 text-xs font-bold text-brand-azure">VA</span>
          <span class="flex-1 text-sm font-bold text-slate-900">{{ t('tutoring2.student.pay.methodVA') }}</span>
        </button>
        <button
          type="button"
          class="flex items-center gap-3 w-full rounded-2xl border p-3 text-left"
          :class="selectedMethod === 'ewallet' ? 'border-brand-azure bg-brand-azure/5' : 'border-slate-200'"
          @click="selectedMethod = 'ewallet'"
        >
          <span class="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-azure/10 text-xs font-bold text-brand-azure">EWL</span>
          <span class="flex-1 text-sm font-bold text-slate-900">{{ t('tutoring2.student.pay.methodEwallet') }}</span>
        </button>
        <button
          type="button"
          class="flex items-center gap-3 w-full rounded-2xl border p-3 text-left"
          :class="selectedMethod === 'qris' ? 'border-brand-azure bg-brand-azure/5' : 'border-slate-200'"
          @click="selectedMethod = 'qris'"
        >
          <span class="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-azure/10 text-xs font-bold text-brand-azure">QR</span>
          <span class="flex-1 text-sm font-bold text-slate-900">{{ t('tutoring2.student.pay.methodQris') }}</span>
        </button>
        <button
          type="button"
          class="flex items-center gap-3 w-full rounded-2xl border p-3 text-left"
          :class="selectedMethod === 'transfer' ? 'border-brand-azure bg-brand-azure/5' : 'border-slate-200'"
          @click="selectedMethod = 'transfer'"
        >
          <span class="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-azure/10 text-xs font-bold text-brand-azure">TRF</span>
          <span class="flex-1 text-sm font-bold text-slate-900">{{ t('tutoring2.student.pay.methodTransfer') }}</span>
        </button>
      </div>
    </section>

    <!-- Sticky confirm CTA -->
    <div class="fixed inset-x-0 bottom-0 z-40 border-t border-slate-100 bg-white/95 p-3 backdrop-blur">
      <div class="mx-auto max-w-2xl">
        <Button variant="primary" block @click="pay">
          {{ t('tutoring2.student.pay.confirmCta', { amount: '752.500' }) }}
        </Button>
      </div>
    </div>
  </div>
</template>
