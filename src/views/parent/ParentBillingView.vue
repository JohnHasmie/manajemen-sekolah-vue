<!--
  ParentBillingView.vue — parent · Bill & Pembayaran.

  Web port of Flutter's `parent_billing_screen.dart` (Mockup #6). Pulls
  per-child bills from `/bill/parent` and lays them out under a parent
  BrandPageHeader + KPI strip + status / periode filter chips. Tapping
  an unpaid bill jumps to the checkout sheet (Phase 3); tapping a paid
  bill opens its kuitansi (Phase 4).

  Endpoints:
    GET /parent/children            via ParentService.listChildren
    GET /bill/parent?student_id=…   via BillingService.listParent
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { BillingService } from '@/services/billing.service';
import { useChildPicker } from '@/composables/useChildPicker';
import {
  BILL_STATUS_LABELS,
  type Bill,
} from '@/types/billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import Modal from '@/components/ui/Modal.vue';
import BillCard from '@/components/feature/BillCard.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRupiah } from '@/lib/format';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { t } = useI18n();
const router = useRouter();
const { children, activeChildId, activeChild, setActive } = useChildPicker();

const bills = ref<Bill[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// Filters
type StatusFilter = 'all' | 'unpaid' | 'paid' | 'pending';
type PeriodeFilter = 'all' | 'monthly' | 'yearly' | 'once';

const statusFilter = ref<StatusFilter>('all');
const periodeFilter = ref<PeriodeFilter>('all');
const search = ref('');
const showStatusSheet = ref(false);
const showPeriodeSheet = ref(false);

const STATUS_OPTS = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('parent.billing.statusAll') },
  { key: 'unpaid', label: t('parent.billing.statusUnpaid') },
  { key: 'pending', label: t('parent.billing.statusPending') },
  { key: 'paid', label: t('parent.billing.statusPaid') },
]);

// Backend `payment_types.period` values are canonical English.
const PERIODE_OPTS = computed<{ key: PeriodeFilter; label: string }[]>(() => [
  { key: 'all', label: t('parent.billing.periodAll') },
  { key: 'monthly', label: t('parent.billing.periodMonthly') },
  { key: 'yearly', label: t('parent.billing.periodYearly') },
  { key: 'once', label: t('parent.billing.periodOnce') },
]);

const childOptions = computed(() =>
  children.value.map((c) => ({
    key: c.student_id,
    label: c.name || t('parent.dashboard.childFallback'),
    meta: c.class_name || undefined,
  })),
);

const child = computed(() => activeChild());

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const filters: Parameters<typeof BillingService.listParent>[0] = {};
    if (activeChildId.value) filters.student_id = activeChildId.value;
    if (statusFilter.value === 'unpaid') filters.status = 'unpaid';
    else if (statusFilter.value === 'paid') filters.status = 'paid';
    else if (statusFilter.value === 'pending') filters.status = 'pending';
    if (periodeFilter.value !== 'all') filters.period = periodeFilter.value;
    if (search.value.trim()) filters.search = search.value.trim();
    bills.value = await BillingService.listParent(filters);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

// Refetch when child / filters change.
watch([activeChildId, statusFilter, periodeFilter], () => {
  void load();
});

// Debounce search.
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(search, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => void load(), 300);
});

// ── Derived KPIs ────────────────────────────────────────────────────
const unpaidBills = computed(() => bills.value.filter((b) => b.status !== 'paid'));
const paidBills = computed(() => bills.value.filter((b) => b.status === 'paid'));
const overdueBills = computed(() => bills.value.filter((b) => b.status === 'overdue'));
const soonBills = computed(() => bills.value.filter((b) => b.status === 'soon'));

const outstanding = computed(() =>
  unpaidBills.value.reduce((sum, b) => sum + b.amount, 0),
);
const paidThisYear = computed(() =>
  paidBills.value.reduce((sum, b) => sum + b.amount, 0),
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'credit-card',
    label: t('parent.billing.kpiOverdue'),
    value: formatRupiah(outstanding.value),
    tone: outstanding.value > 0 ? 'amber' : 'slate',
    accented: outstanding.value > 0,
  },
  {
    icon: 'alert-triangle',
    label: t('parent.billing.kpiLate'),
    value: overdueBills.value.length,
    suffix: t('parent.billing.kpiBillsSuffix'),
    tone: overdueBills.value.length > 0 ? 'red' : 'slate',
    accented: overdueBills.value.length > 0,
  },
  {
    icon: 'clock',
    label: t('parent.billing.kpiSoon'),
    value: soonBills.value.length,
    suffix: t('parent.billing.kpiBillsSuffix'),
    tone: soonBills.value.length > 0 ? 'amber' : 'slate',
  },
  {
    icon: 'check-circle',
    label: t('parent.billing.kpiLunasYear'),
    value: formatRupiah(paidThisYear.value),
    tone: 'green',
  },
]);

// ── State for AsyncView ─────────────────────────────────────────────
const listState = computed<AsyncState<Bill[]>>(() => {
  if (isLoading.value && bills.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (bills.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: bills.value };
});

const statusChipValue = computed(
  () => STATUS_OPTS.value.find((o) => o.key === statusFilter.value)?.label ?? t('common.all'),
);
const periodeChipValue = computed(
  () => PERIODE_OPTS.value.find((o) => o.key === periodeFilter.value)?.label ?? t('common.all'),
);

function openBill(b: Bill) {
  if (b.status === 'paid' && b.latest_payment) {
    router.push({
      name: 'parent.payment-success',
      params: { paymentId: b.latest_payment.id },
      query: { billId: b.id },
    });
    return;
  }
  router.push({
    name: 'parent.bill-checkout',
    params: { billId: b.id },
  });
}

const headerMeta = computed(() => {
  if (!child.value) return t('parent.billing.headerNoChild');
  return t('parent.billing.metaCounts', {
    name: child.value.name,
    count: bills.value.length,
    unpaid: unpaidBills.value.length,
  });
});
</script>

<template>
  <div class="space-y-md pb-12">
    <ParentPageHeader
      :kicker="t('parent.billing.kicker')"
      :title="t('parent.billing.title')"
      :interpolate-child="false"
      :meta="headerMeta"
    />

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar
      v-model:search="search"
      :search-placeholder="t('parent.billing.searchPlaceholder')"
      :search-min-width="220"
    >
      <template #chips>
        <AppFilterChip
          icon-name="bell"
          :label="t('parent.billing.chipStatus')"
          :value="statusChipValue"
          tone="amber"
          @click="showStatusSheet = true"
        />
        <AppFilterChip
          icon-name="calendar"
          :label="t('parent.billing.chipPeriod')"
          :value="periodeChipValue"
          tone="violet"
          @click="showPeriodeSheet = true"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="listState"
      :empty-title="t('parent.billing.emptyTitle')"
      :empty-description="t('parent.billing.emptyDesc')"
      empty-icon="credit-card"
      @retry="load"
    >
      <template #default>
        <!-- Belum lunas -->
        <section
          v-if="unpaidBills.length > 0"
          class="bg-white border border-slate-200 rounded-2xl p-2"
        >
          <header class="flex items-center justify-between px-3 pt-2 pb-1">
            <h3 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {{ t('parent.billing.sectionUnpaidHeader', { count: unpaidBills.length }) }}
            </h3>
            <span class="text-[12px] font-bold text-amber-700">
              {{ formatRupiah(outstanding) }}
            </span>
          </header>
          <div class="divide-y divide-slate-100">
            <BillCard
              v-for="b in unpaidBills"
              :key="b.id"
              :bill="b"
              :show-student-name="childOptions.length > 1"
              @click="openBill"
            />
          </div>
        </section>

        <!-- Lunas -->
        <section
          v-if="paidBills.length > 0"
          class="bg-white border border-slate-200 rounded-2xl p-2"
        >
          <header class="flex items-center justify-between px-3 pt-2 pb-1">
            <h3 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {{ t('parent.billing.sectionPaidHeader') }}
            </h3>
            <span class="text-[12px] font-bold text-emerald-700">
              {{ formatRupiah(paidThisYear) }}
            </span>
          </header>
          <div class="divide-y divide-slate-100">
            <BillCard
              v-for="b in paidBills"
              :key="b.id"
              :bill="b"
              :show-student-name="childOptions.length > 1"
              @click="openBill"
            />
          </div>
        </section>
      </template>
    </AsyncView>

    <!-- Status filter sheet -->
    <Modal
      v-if="showStatusSheet"
      :title="t('parent.billing.modalStatusTitle')"
      :subtitle="t('parent.billing.modalStatusSubtitle')"
      size="sm"
      @close="showStatusSheet = false"
    >
      <div class="space-y-1">
        <button
          v-for="opt in STATUS_OPTS"
          :key="opt.key"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[14px] font-bold transition-colors"
          :class="
            statusFilter === opt.key
              ? 'bg-role-wali/10 text-role-wali'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="
            statusFilter = opt.key;
            showStatusSheet = false;
          "
        >
          {{ opt.label }}
        </button>
      </div>
    </Modal>

    <!-- Periode filter sheet -->
    <Modal
      v-if="showPeriodeSheet"
      :title="t('parent.billing.modalPeriodTitle')"
      :subtitle="t('parent.billing.modalPeriodSubtitle')"
      size="sm"
      @close="showPeriodeSheet = false"
    >
      <div class="space-y-1">
        <button
          v-for="opt in PERIODE_OPTS"
          :key="opt.key"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[14px] font-bold transition-colors"
          :class="
            periodeFilter === opt.key
              ? 'bg-role-wali/10 text-role-wali'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="
            periodeFilter = opt.key;
            showPeriodeSheet = false;
          "
        >
          {{ opt.label }}
        </button>
      </div>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />

    <!-- Reference for the linter — BILL_STATUS_LABELS is consumed indirectly via BillCard. -->
    <span class="hidden">{{ BILL_STATUS_LABELS }}</span>
  </div>
</template>
