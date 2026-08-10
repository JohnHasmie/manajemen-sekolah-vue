<!--
  ParentTutoring2PayView.vue — Wali bimbel payment inbox + checkout (WEB-7).

  Wired to BE-8 `/api/tutoring-v2/bills*`. Backend automatically scopes
  the list to the wali's own children via `tutoring.bill.view_own`.

  Two modes, one route:
  * No `?billId=` query → payment INBOX. Lists unpaid + overdue bills
    across all children. Each row taps into the detail mode.
  * `?billId=X` present → payment DETAIL. Fetches the single bill via
    `getBill` and renders summary (child + amount + due + status) plus
    a "Bayar sekarang" CTA. The CTA stubs a toast — real gateway is
    BE-11 (invoice / QRIS) territory. We deliberately do NOT call
    `markBillPaid` from the FE (admin-only permission).

  This layered mode keeps the existing route `/parent/tutoring2/pay`
  usable both as the default "buka daftar tagihan" landing (from home
  nav) and as a deep link with an explicit bill.
-->
<script setup lang="ts">
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
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
import { TutoringBillingSettingsService } from '@/services/tutoring2/billing-settings';
import type { PaymentAccount } from '@/types/tutoring2/billing';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

// Reactive-safe read — Vue re-fires the loader when the query changes
// because `useDataRefresh` re-runs when we call `reload()` from the
// route watcher (below).
const billIdFromQuery = computed<string | null>(() => {
  const raw = route.query.billId;
  if (!raw) return null;
  return Array.isArray(raw) ? String(raw[0]) : String(raw);
});

interface PayBundle {
  mode: 'list' | 'detail';
  bills: BimbelBill[];      // list mode: unpaid bills; detail mode: [bill]
  focused?: BimbelBill;     // detail mode only
  /**
   * Where to send the money. Null when the tenant has configured no
   * destination at all — rendered as an honest notice rather than a
   * blank bank block, which reads as a real account with missing digits.
   */
  paymentAccount: PaymentAccount | null;
}

const { state, reload } = useDataRefresh<PayBundle | null>(async () => {
  // Fetched alongside the bills, not lazily on tapping "Bayar": a parent
  // opening this screen is already asking how to pay, and a second
  // round-trip at the moment they tap is the one place latency is most
  // visible. It is one small tenant-level row.
  //
  // Tolerated failure — `catch(() => null)`: the payment destination is
  // an ADDITION to this screen. If that call fails, a parent should
  // still see what they owe, with the transfer panel replaced by an
  // honest notice. Letting it reject would turn a partial outage into a
  // blank billing screen.
  const accountPromise = TutoringBillingSettingsService.getPaymentAccount()
    .catch(() => null);

  if (billIdFromQuery.value) {
    const [focused, paymentAccount] = await Promise.all([
      TutoringBimbelService.getBill(billIdFromQuery.value),
      accountPromise,
    ]);
    return { mode: 'detail', bills: [focused], focused, paymentAccount };
  }

  const [{ items }, paymentAccount] = await Promise.all([
    TutoringBimbelService.listBills({ status: 'unpaid', per_page: 50 }),
    accountPromise,
  ]);

  // `null`, not an object with an empty `bills` array. useDataRefresh
  // decides `status: 'empty'` via isEmpty(), which recognises only
  // null/undefined/[] — an object always reads as content, and this view
  // binds :state straight into <AsyncView>, so a wali with nothing
  // outstanding would get a blank panel instead of "tidak ada tagihan".
  // (Third view in this surface to hit that; see useDataRefresh.spec.ts.)
  if (items.length === 0) return null;

  return { mode: 'list', bills: items, paymentAccount };
});

// Re-fetch when the query flips between "no id" and a specific id.
// We watch the computed rather than the raw route.query to keep the
// dep graph shallow (Vue-router replays the whole `route` on any nav).
watch(billIdFromQuery, () => reload());

const bundle = computed<PayBundle | null>(() =>
  state.value.status === 'content' ? (state.value.data as PayBundle) : null,
);
const bills = computed<BimbelBill[]>(() => bundle.value?.bills ?? []);
const focused = computed<BimbelBill | null>(() => bundle.value?.focused ?? null);

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

const overdueCount = computed(
  () => bills.value.filter((b) => effectiveStatus(b) === 'overdue').length,
);
const totalDue = computed(() =>
  bills.value.reduce((acc, b) => acc + (b.amount ?? 0), 0),
);
const uniqueChildren = computed(() => {
  const s = new Set<string>();
  for (const b of bills.value) s.add(b.student_id);
  return s.size;
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'cash',
    label: t('tutoring2.parent.pay.kpiOutstanding'),
    value: rupiah(totalDue.value),
    tone: 'brand',
  },
  {
    icon: 'alert-triangle',
    label: t('tutoring2.parent.pay.kpiOverdue'),
    value: overdueCount.value,
    tone: overdueCount.value > 0 ? 'red' : undefined,
  },
  {
    icon: 'file-text',
    label: t('tutoring2.common.total'),
    value: bills.value.length,
    tone: 'green',
  },
  {
    icon: 'users',
    label: t('tutoring2.parent.pay.kpiTotalChildren'),
    value: uniqueChildren.value,
    tone: 'violet',
  },
]);

function rupiah(v: number | null | undefined): string {
  return v != null ? `Rp ${v.toLocaleString('id-ID')}` : '—';
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

function openDetail(b: BimbelBill) {
  router.push({ name: 'parent.tutoring2.pay', query: { billId: b.id } });
}

function backToInbox() {
  router.push({ name: 'parent.tutoring2.pay' });
}

/**
 * The transfer destination for the current tenant.
 *
 * This screen used to answer "how do I pay?" with a toast saying the
 * feature was not ready, because v2 had no route for it — a parent could
 * see what they owed and had no way to discover where to send it. The
 * details now come from `GET /tutoring-v2/payment-account`.
 */
const paymentAccount = computed<PaymentAccount | null>(
  () => bundle.value?.paymentAccount ?? null,
);

/** Manual transfer is possible when the tenant filled in ANY of these. */
const hasManualDestination = computed(() => {
  const a = paymentAccount.value;
  if (!a) return false;
  return Boolean(a.bank_account_number || a.qris_image_url || a.payment_instructions);
});

async function copyAccountNumber() {
  const number = paymentAccount.value?.bank_account_number;
  if (!number) return;
  try {
    await navigator.clipboard.writeText(number);
    toast.success(t('tutoring2.parent.pay.accountCopied'));
  } catch {
    // Clipboard is permission-gated and unavailable over plain http.
    // The number is on screen regardless, so this is a convenience that
    // failed, not an error worth alarming a parent about.
    toast.info(t('tutoring2.parent.pay.accountCopyFailed'));
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.pay.title')"
      :meta="bundle?.mode === 'detail'
        ? t('tutoring2.bills.detail.meta')
        : t('tutoring2.parent.pay.meta', { children: uniqueChildren, count: bills.length })"
    />

    <KpiStripCards
      v-if="bundle?.mode !== 'detail'"
      :cards="kpiCards"
      :loading="state.status === 'loading'"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.pay.emptyTitle')"
      @retry="reload"
    >
      <template #default>
        <!-- DETAIL MODE ─────────────────────────────────────────────── -->
        <template v-if="bundle?.mode === 'detail' && focused">
          <section class="rounded-3xl border border-slate-100 bg-white p-5 shadow-sm">
            <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">
              {{ sourceLabel(focused) }}
            </p>
            <p class="mt-2 text-3xl font-black text-slate-900">
              {{ rupiah(focused.amount) }}
            </p>
            <div class="mt-3 flex items-center gap-3">
              <StatusBadge
                :label="statusLabel(effectiveStatus(focused))"
                :tone="statusTone(effectiveStatus(focused))"
                uppercase
              />
              <span v-if="focused.due_date" class="text-2xs text-slate-500">
                {{ t('tutoring2.student.bills.dueOn', { date: focused.due_date }) }}
              </span>
            </div>
            <div
              v-if="focused.student_name"
              class="mt-4 border-t border-slate-100 pt-3 text-sm text-slate-600"
            >
              <span class="font-semibold text-slate-500">{{ t('tutoring2.common.student') }}:</span>
              {{ focused.student_name }}
              <span v-if="focused.student_number" class="text-slate-400"> · {{ focused.student_number }}</span>
            </div>
          </section>

          <!--
            WHERE TO PAY. This block replaces a "Bayar sekarang" button
            whose only behaviour was a toast saying the feature was not
            ready — the screen could state the amount but not the
            destination, which is the one thing a parent opens it for.

            Rendered inline rather than behind a tap: it is the answer to
            the question the screen exists to answer.
          -->
          <section
            v-if="hasManualDestination"
            class="rounded-3xl border border-slate-100 bg-white p-md shadow-sm"
          >
            <h3 class="text-sm font-bold text-slate-900">
              {{ t('tutoring2.parent.pay.howToPay') }}
            </h3>

            <dl v-if="paymentAccount?.bank_account_number" class="mt-3 space-y-1.5">
              <div class="flex items-baseline justify-between gap-3">
                <dt class="text-2xs text-slate-500">{{ t('tutoring2.parent.pay.bank') }}</dt>
                <dd class="text-sm font-semibold text-slate-900">
                  {{ paymentAccount.bank_name ?? '—' }}
                </dd>
              </div>
              <div class="flex items-baseline justify-between gap-3">
                <dt class="text-2xs text-slate-500">{{ t('tutoring2.parent.pay.accountNumber') }}</dt>
                <dd class="flex items-center gap-2">
                  <!-- tabular-nums so digits line up and are easy to read back -->
                  <span class="text-sm font-bold tabular-nums tracking-wide text-slate-900">
                    {{ paymentAccount.bank_account_number }}
                  </span>
                  <button
                    type="button"
                    class="rounded-md px-2 py-0.5 text-2xs font-semibold text-cobalt-700 hover:bg-cobalt-50"
                    @click="copyAccountNumber"
                  >
                    {{ t('tutoring2.parent.pay.copy') }}
                  </button>
                </dd>
              </div>
              <div v-if="paymentAccount.bank_account_holder" class="flex items-baseline justify-between gap-3">
                <dt class="text-2xs text-slate-500">{{ t('tutoring2.parent.pay.accountHolder') }}</dt>
                <dd class="text-sm text-slate-900">{{ paymentAccount.bank_account_holder }}</dd>
              </div>
            </dl>

            <img
              v-if="paymentAccount?.qris_image_url"
              :src="paymentAccount.qris_image_url"
              :alt="t('tutoring2.parent.pay.qrisAlt')"
              class="mt-3 h-48 w-48 rounded-xl border border-slate-100 object-contain"
            />

            <!--
              Tenant-authored copy. Rendered as TEXT, never v-html: it is
              admin-entered and would otherwise be a stored-XSS sink into
              every parent's browser on the tenant.
            -->
            <p
              v-if="paymentAccount?.payment_instructions"
              class="mt-3 whitespace-pre-line text-2xs leading-relaxed text-slate-600"
            >
              {{ paymentAccount.payment_instructions }}
            </p>
          </section>

          <!-- Nothing configured. Say so plainly instead of showing an
               empty bank block, and point somewhere useful. -->
          <section
            v-else
            class="rounded-3xl border border-amber-100 bg-amber-50/60 p-md"
          >
            <p class="text-2xs leading-relaxed text-amber-800">
              {{ t('tutoring2.parent.pay.noDestination') }}
            </p>
          </section>

          <div class="flex gap-3 pt-1">
            <Button variant="ghost" size="sm" class="flex-1" @click="backToInbox">
              {{ t('tutoring2.common.back') }}
            </Button>
          </div>
        </template>

        <!-- LIST (INBOX) MODE ─────────────────────────────────────────── -->
        <template v-else>
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
            <ul class="divide-y divide-slate-100">
              <li
                v-for="b in bills"
                :key="b.id"
                class="flex items-center gap-3 px-4 py-3"
              >
                <div
                  class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-azure/10 text-xs font-bold uppercase text-brand-azure"
                >
                  {{ (b.student_name ?? b.student_id).slice(0, 2).toUpperCase() }}
                </div>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-bold text-slate-900">
                    {{ b.student_name ?? t('tutoring2.common.studentId') + ' ' + b.student_id.slice(0, 8) }}
                  </p>
                  <p class="truncate text-2xs text-slate-500">
                    {{ sourceLabel(b) }} · {{ rupiah(b.amount) }}
                    <template v-if="b.due_date"> · {{ b.due_date }}</template>
                  </p>
                </div>
                <StatusBadge
                  :label="statusLabel(effectiveStatus(b))"
                  :tone="statusTone(effectiveStatus(b))"
                  uppercase
                />
                <Button variant="primary" size="sm" @click="openDetail(b)">
                  {{ t('tutoring2.parent.pay.payCta') }}
                </Button>
              </li>
            </ul>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
