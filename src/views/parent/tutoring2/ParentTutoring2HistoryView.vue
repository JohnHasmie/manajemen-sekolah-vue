<!--
  ParentTutoring2HistoryView.vue — Wali bimbel payment history (WEB-5).

  Composition mirrors the exemplar: BrandPageHeader + KpiStripCards +
  PageFilterToolbar chips (Anak / Tahun) + AsyncView-wrapped rounded
  surface with divide-y rows. Each row surfaces month/child/amount and
  a StatusBadge (paid=success, overdue=danger).

  MVP note: no /parent/payments/history endpoint yet — a small seeded
  array drives the layout so the shell is exercised end-to-end.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Button from '@/components/ui/Button.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const toast = useToast();

interface HistoryRow {
  month: string;
  child: string;
  amount: number;
  status: 'paid' | 'overdue';
}

// TODO WEB-5+ swap to /tutoring2/parent/payments/history once BE-6 ships.
const SEED: HistoryRow[] = [
  { month: 'Jun 2026', child: 'Nadia', amount: 750_000, status: 'paid' },
  { month: 'Mei 2026', child: 'Nadia', amount: 750_000, status: 'paid' },
  { month: 'Apr 2026', child: 'Nadia', amount: 750_000, status: 'paid' },
  { month: 'Mar 2026', child: 'Rafi', amount: 900_000, status: 'overdue' },
  { month: 'Feb 2026', child: 'Rafi', amount: 900_000, status: 'paid' },
  { month: 'Jan 2026', child: 'Nadia', amount: 750_000, status: 'paid' },
];

const { state, reload } = useDataRefresh(async () => {
  // MVP static seed. Resolves to 'content' because array is non-empty.
  return SEED;
});

const history = computed<HistoryRow[]>(() =>
  state.value.status === 'content' ? (state.value.data as HistoryRow[]) : [],
);

// Nominal filter chips — Anak + Tahun. Values are display-only for MVP;
// wiring live filters is deferred to WEB-5+ when the BE endpoint lands.
const childFilter = ref<string>('');
const yearFilter = ref<string>('');

const childChipValue = computed(() =>
  childFilter.value || t('tutoring2.common.all'),
);
const yearChipValue = computed(() =>
  yearFilter.value || t('tutoring2.common.all'),
);

const kpiCards = computed<KpiCard[]>(() => {
  const paid = history.value.filter((h) => h.status === 'paid').length;
  const overdue = history.value.filter((h) => h.status === 'overdue').length;
  const children = new Set(history.value.map((h) => h.child)).size;
  return [
    {
      icon: 'list',
      label: t('tutoring2.common.total'),
      value: history.value.length,
      tone: 'brand',
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.status.paid'),
      value: paid,
      tone: 'green',
    },
    {
      icon: 'alert-triangle',
      label: t('tutoring2.status.overdue'),
      value: overdue,
      tone: 'red',
    },
    {
      icon: 'users',
      label: t('tutoring2.parent.pay.kpiTotalChildren'),
      value: children,
      tone: 'violet',
    },
  ];
});

function statusLabel(s: HistoryRow['status']): string {
  return s === 'paid'
    ? t('tutoring2.status.paid')
    : t('tutoring2.status.overdue');
}
function statusTone(s: HistoryRow['status']): StatusBadgeTone {
  return s === 'paid' ? 'success' : 'danger';
}
function rupiah(v: number): string {
  return `Rp ${v.toLocaleString('id-ID')}`;
}

function pickChild() {
  toast.info(t('tutoring2.common.notAvailable'));
}
function pickYear() {
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

    <PageFilterToolbar hide-search>
      <template #chips>
        <AppFilterChip
          icon-name="user"
          :label="t('tutoring2.parent.history.filterChild')"
          :value="childChipValue"
          tone="violet"
          @click="pickChild"
        />
        <AppFilterChip
          icon-name="calendar"
          :label="t('tutoring2.parent.history.filterYear')"
          :value="yearChipValue"
          tone="amber"
          @click="pickYear"
        />
      </template>
    </PageFilterToolbar>

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
              v-for="(row, idx) in history"
              :key="`${row.month}-${row.child}-${idx}`"
              class="flex items-center gap-3 px-4 py-3"
            >
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">{{ row.month }}</p>
                <p class="truncate text-2xs text-slate-500">
                  {{ row.child }} · {{ rupiah(row.amount) }}
                </p>
              </div>
              <StatusBadge :label="statusLabel(row.status)" :tone="statusTone(row.status)" uppercase />
            </li>
          </ul>
          <footer class="border-t border-slate-100 px-4 py-3 text-right">
            <Button variant="ghost" size="sm" @click="reload">
              {{ t('tutoring2.common.retry') }}
            </Button>
          </footer>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
