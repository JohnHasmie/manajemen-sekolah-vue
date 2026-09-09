<!--
  AdminTutoring2BillingView.vue — greenfield "Keuangan" (tagihan) list.

  Reads BOTH the KPI aggregate + the paginated bill list from
  /api/tutoring-v2/bills* (BE-8). Drops the temporary
  FinanceService.listBills bridge that was in place while the
  greenfield endpoints didn't exist.

  ── THE "+ Buat tagihan" CTA IS NOW WIRED ────────────────────────────

  It shipped with no `@click` and no handler, joining the prod reports
  of "tombol diklik tidak terjadi apa-apa", and was then disabled with
  the reason on the control (!1211's honesty pattern) because there was
  nothing to wire it TO: web-vue had never had a bill create surface.
  Bills reached this list only by being generated — enrollment intake
  raises the first one, the monthly cron raises the rest.

  <AdminTutoring2BillCreateSheet> is that surface. It mirrors the mobile
  "Tambah Tagihan" sheet, which grew the form first and is therefore the
  spec. The CTA is gated on `tutoring.bill.create` — the ability
  `Tutoring\BillController::store` itself authorizes, NOT the
  `tutoring.bill.view` this list reads with. Hiding it without the key
  keeps the affordance honest; the server re-checks regardless.

  Gating reads `/me` abilities via `useMe().can()`, which the backend
  scopes to the role named by `X-Active-Role`, so an account that is
  both admin and tutor gets the answer for the hat it is wearing. Never
  `roles[].permission_keys`: that list is unscoped and exists only to
  drive the role switcher.

  `billing.emptyDesc` stays honest too — it describes where bills come
  from rather than telling admins to press a button, and now that the
  button works it names it as an option instead.

  ── The Periode chip ──────────────────────────────────────────────────

  It now opens <MonthPickerModal>, the same chip → per-facet-modal shape
  the Tutor chip on AdminTutoring2PayoutRequestsView uses. Its handler
  was `@click="monthFilter = monthFilter ? '' : toLocalYm()"`, a
  two-value toggle: an admin could filter to THIS month or to no month
  and could never reach any other one, even though
  `GET /tutoring-v2/bills` takes an arbitrary `month`. The chip also
  displayed the raw wire value ("2026-09") rather than a month name.

  <MonthPickerModal> is used directly rather than through its
  <MonthPickerField> wrapper because the chip already IS the trigger
  chrome — the wrapper would render a second labeled button inside the
  toolbar. `clearable` puts "Semua bulan" back, so the one thing the old
  toggle did right (clearing) survives.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import MonthPickerModal from '@/components/feature/MonthPickerModal.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import AdminTutoring2BillCreateSheet from './AdminTutoring2BillCreateSheet.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { formatYmLabel } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelBill,
  type BimbelBillsSummary,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t, locale } = useI18n();
const { can } = useMe();

/**
 * `tutoring.bill.create` — the ability `BillController::store`
 * authorizes, which is a DIFFERENT key from the `tutoring.bill.view`
 * that lets a caller read this list. Fails closed while `/me` is
 * unloaded, so the CTA is withheld rather than offered.
 */
const canCreateBill = computed(() => can('tutoring.bill.create'));

/** Create sheet visibility. Mounted only while open so it resets. */
const showCreateSheet = ref(false);

/**
 * `tutoring.payment_type.view` — what `Tutoring\PaymentTypeController::
 * index` authorizes. Resolved here and injected so the sheet stays a
 * plain form with one boolean, mirroring the mobile sheet.
 */
const canViewPaymentTypes = computed(() => can('tutoring.payment_type.view'));

function openCreateSheet(): void {
  if (!canCreateBill.value) return;
  showCreateSheet.value = true;
}

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'unpaid' | 'paid' | 'pending' | 'partial'
const sourceFilter = ref<string>(''); // '' | 'TUTORING_PREPAID' | 'TUTORING_MONTHLY' | 'TUTORING_SESSION'
const monthFilter = ref<string>(''); // '' | 'YYYY-MM'
const showMonthPicker = ref(false);

const localeTag = computed(() => (locale.value === 'en' ? 'en-US' : 'id-ID'));

/**
 * The chip shows a month NAME. `formatYmLabel` is the single formatter
 * for that, so the chip, the picker's cell labels and every other
 * "Periode" surface in the app agree on the wording.
 */
const monthChipValue = computed(() =>
  monthFilter.value
    ? formatYmLabel(monthFilter.value, localeTag.value)
    : t('tutoring2.common.all'),
);

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
}, {
  // The summary rides along with the rows, so the payload is an object
  // and `isEmpty()`'s array rule never applies. No bills = empty.
  isEmpty: (d) => d.bills.length === 0,
});

watch([debouncedSearch, statusFilter, sourceFilter, monthFilter], () => reload());

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
          :value="monthChipValue"
          icon-name="calendar"
          :active="!!monthFilter"
          @click="showMonthPicker = true"
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

    <!-- Wired, and hidden outright without `tutoring.bill.create` — the
         key BillController::store authorizes. An admin who cannot
         create is shown no control at all rather than one whose only
         possible outcome is a 403. -->
    <button
      v-if="canCreateBill"
      type="button"
      data-testid="billing-new-cta"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openCreateSheet"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.billing.newCta') }}
    </button>

    <AdminTutoring2BillCreateSheet
      v-if="showCreateSheet"
      :can-view-payment-types="canViewPaymentTypes"
      @close="showCreateSheet = false"
      @saved="reload"
    />

    <!-- Periode picker. It only writes `monthFilter`; the existing
         watcher on [search, status, source, month] does the reload, so
         nothing calls `reload()` here — that second path is exactly how
         a filter change ends up fetching twice. -->
    <MonthPickerModal
      v-if="showMonthPicker"
      :model-value="monthFilter"
      :title="t('tutoring2.common.period')"
      accent="admin"
      clearable
      @apply="(v) => { monthFilter = v; }"
      @close="showMonthPicker = false"
    />
  </div>
</template>
