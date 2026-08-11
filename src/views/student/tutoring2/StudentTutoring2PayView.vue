<!--
  StudentTutoring2PayView.vue — Siswa bimbel checkout.

  Route: /student/tutoring2/pay/:billId

  ── History ──

  This shipped with an INVENTED bill:

      const summary = {
        itemDesc: 'SPP Januari 2026',
        amount: 750000,
        adminFee: 2500,
      };

  and it IGNORED the `:billId` in the route, so every bill a siswa
  opened showed Rp 750.000 plus a Rp 2.500 fee they did not owe. The
  method picker offered VA / e-wallet / QRIS / transfer, and the confirm
  button raised a toast. A student could read a total, believe it, and
  act on it.

  The header blamed BE-8. `GET /tutoring-v2/bills/{id}` had shipped —
  the sibling StudentTutoring2BillDetailView, which links HERE, was
  already reading it.

  ── Now ──

  The real bill, by id, plus the tenant's payment destination from
  `GET /tutoring-v2/payment-account` — the same block the wali sees.

  The admin fee is GONE rather than zeroed: nothing in the bill model
  carries one, so any figure shown would be invented. If a tenant starts
  charging one it has to come from the bill.

  Online payment is not offered. There is no gateway wired, and a picker
  that cannot charge anything is the fabrication this screen already had.
  Transfer details are shown instead, which is how these bills are paid
  today.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelBill,
} from '@/services/tutoring-bimbel.service';
import { TutoringBillingSettingsService } from '@/services/tutoring2/billing-settings';
import type { PaymentAccount } from '@/types/tutoring2/billing';

const { t } = useI18n();
const route = useRoute();

const billId = String(route.params.billId ?? '');

interface Checkout {
  bill: BimbelBill;
  /** Null when the tenant has configured no destination at all. */
  paymentAccount: PaymentAccount | null;
}

const { state, reload } = useDataRefresh<Checkout | null>(async () => {
  if (!billId) return null;

  // The destination is an ADDITION to this screen: if it fails, the
  // student should still see what they owe rather than a blank page.
  const [bill, paymentAccount] = await Promise.all([
    TutoringBimbelService.getBill(billId),
    TutoringBillingSettingsService.getPaymentAccount().catch(() => null),
  ]);

  return { bill, paymentAccount };
});

const checkout = computed<Checkout | null>(() =>
  state.value.status === 'content' ? (state.value.data as Checkout) : null,
);
const bill = computed<BimbelBill | null>(() => checkout.value?.bill ?? null);
const account = computed<PaymentAccount | null>(() => checkout.value?.paymentAccount ?? null);

const hasDestination = computed(() => {
  const a = account.value;
  return Boolean(a?.bank_account_number || a?.qris_image_url || a?.payment_instructions);
});

function formatRp(n: number | null | undefined): string {
  if (n == null) return '—';
  return 'Rp ' + n.toLocaleString('id-ID');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.pay.title')"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="2"
      :empty-title="t('tutoring2.student.pay.emptyTitle')"
      @retry="reload"
    >
      <template #default>
        <section v-if="bill" class="rounded-3xl border border-slate-100 bg-white p-md shadow-sm">
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="truncate text-sm font-bold text-slate-900">{{ bill.payment_type_name ?? bill.id }}</p>
              <p class="mt-0.5 text-2xs text-slate-500">{{ bill.due_date ?? '' }}</p>
            </div>
            <StatusBadge :label="bill.status ?? ''" tone="neutral" uppercase />
          </div>

          <!-- The amount ON THE BILL. No fee is added: the bill model
               carries none, so any figure here would be invented. -->
          <p class="mt-3 text-lg font-bold tabular-nums text-slate-900">
            {{ formatRp(bill.amount) }}
          </p>
        </section>

        <section
          v-if="hasDestination"
          class="rounded-3xl border border-slate-100 bg-white p-md shadow-sm"
        >
          <h3 class="text-sm font-bold text-slate-900">
            {{ t('tutoring2.student.pay.howToPay') }}
          </h3>

          <dl v-if="account?.bank_account_number" class="mt-3 space-y-1.5">
            <div class="flex items-baseline justify-between gap-3">
              <dt class="text-2xs text-slate-500">{{ t('tutoring2.student.pay.bank') }}</dt>
              <dd class="text-sm font-semibold text-slate-900">{{ account.bank_name ?? '—' }}</dd>
            </div>
            <div class="flex items-baseline justify-between gap-3">
              <dt class="text-2xs text-slate-500">{{ t('tutoring2.student.pay.accountNumber') }}</dt>
              <dd class="text-sm font-bold tabular-nums tracking-wide text-slate-900">
                {{ account.bank_account_number }}
              </dd>
            </div>
            <div v-if="account.bank_account_holder" class="flex items-baseline justify-between gap-3">
              <dt class="text-2xs text-slate-500">{{ t('tutoring2.student.pay.accountHolder') }}</dt>
              <dd class="text-sm text-slate-900">{{ account.bank_account_holder }}</dd>
            </div>
          </dl>

          <img
            v-if="account?.qris_image_url"
            :src="account.qris_image_url"
            :alt="t('tutoring2.student.pay.qrisAlt')"
            class="mt-3 h-48 w-48 rounded-xl border border-slate-100 object-contain"
          />

          <!-- Tenant-authored copy, rendered as TEXT. Never v-html: it is
               admin-entered and reaches every student on the tenant. -->
          <p
            v-if="account?.payment_instructions"
            class="mt-3 whitespace-pre-line text-2xs leading-relaxed text-slate-600"
          >
            {{ account.payment_instructions }}
          </p>
        </section>

        <section v-else class="rounded-3xl border border-amber-100 bg-amber-50/60 p-md">
          <p class="text-2xs leading-relaxed text-amber-800">
            {{ t('tutoring2.student.pay.noDestination') }}
          </p>
        </section>
      </template>
    </AsyncView>
  </div>
</template>
