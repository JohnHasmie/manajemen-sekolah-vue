<!--
  AdminTutoring2BillingView.vue — greenfield "Keuangan" (tagihan) list.

  Reads BOTH the KPI aggregate + the paginated bill list from
  /api/tutoring-v2/bills* (BE-8). Drops the temporary
  FinanceService.listBills bridge that was in place while the
  greenfield endpoints didn't exist.

  ── THE "+ Buat tagihan" CTA IS DISABLED ON PURPOSE ──────────────────

  It shipped with no `@click` and no handler, so it joined the prod
  reports of "tombol diklik tidak terjadi apa-apa". The fix is NOT to
  wire it, because there is nothing to wire it TO: **web-vue has never
  had a bill create surface.**

  This is the same shape as the "+ Program baru" CTA !1211 disabled.
  `TutoringBimbelService.createBill` exists and wraps
  `POST /tutoring-v2/bills`, and `admin` even holds
  `tutoring.bill.create` in `PermissionCatalog::
  adminTutoringDefaults()` — but the method has ZERO call sites in the
  app. Bills reach this list by being generated: enrollment intake
  raises the first one and the monthly cron raises the rest. Nothing
  anywhere lets a human compose one.

  So this is a MISSING FEATURE, not a missing handler, and inventing a
  create form here would be a product decision made by a bug fix —
  a manual bill needs an amount, a due date, a source_type and a
  student, and picking that field set is exactly the decision this MR
  must not make. Until someone builds it, the button states plainly
  that it is unavailable instead of silently swallowing the click.
  `billing.emptyDesc` — which read "Klik + untuk membuat tagihan
  baru." — no longer tells admins to press it either.

  To finish this: build the create sheet (mirror
  <AdminTutoring2GroupCreateSheet>), call `createBill`, gate on
  `tutoring.bill.create`, then drop `disabled` + the `title` below and
  restore the empty-state copy.

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
import { useDataRefresh } from '@/composables/useDataRefresh';
import { formatYmLabel } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelBill,
  type BimbelBillsSummary,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t, locale } = useI18n();

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

    <!-- Disabled, with the reason on the control itself — see docblock.
         `title` carries it for a pointer, and the aria-describedby'd
         line carries it for a screen reader, which never sees a
         tooltip. -->
    <button
      type="button"
      data-testid="billing-new-cta"
      disabled
      aria-describedby="billing-new-cta-reason"
      :title="t('tutoring2.admin.billing.newCtaUnavailable')"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-slate-300 text-white font-bold shadow-xl cursor-not-allowed"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.billing.newCta') }}
    </button>
    <span id="billing-new-cta-reason" class="sr-only">
      {{ t('tutoring2.admin.billing.newCtaUnavailable') }}
    </span>

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
