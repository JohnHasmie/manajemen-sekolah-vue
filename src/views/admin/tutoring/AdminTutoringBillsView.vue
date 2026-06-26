<!--
  AdminTutoringBillsView — all tutoring bills across the tenant.
  Uses the BrandPageHeader + KpiStripCards + PageFilterToolbar chrome.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type { TutoringBill } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BillDetailModal from '@/components/feature/tutoring/BillDetailModal.vue';

type Filter = 'all' | 'unpaid' | 'pending' | 'paid';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const filter = ref<Filter>('all');
const bills = ref<TutoringBill[]>([]);
const showFilterPicker = ref(false);
const openBillId = ref<string | null>(null);
const markPaidBillId = ref<string | null>(null);
const markPaidForm = ref({
  payment_method: 'bank_transfer',
  payment_date: new Date().toISOString().slice(0, 10),
  amount: undefined as number | undefined,
  admin_notes: '',
});
const markPaidSaving = ref(false);

const markPaidBill = computed(() =>
  bills.value.find((b) => b.id === markPaidBillId.value) ?? null,
);

async function confirmMarkPaid() {
  if (!markPaidBillId.value) return;
  markPaidSaving.value = true;
  try {
    await TutoringService.markBillPaid(markPaidBillId.value, {
      payment_method: markPaidForm.value.payment_method,
      payment_date: markPaidForm.value.payment_date,
      amount: markPaidForm.value.amount,
      admin_notes: markPaidForm.value.admin_notes || undefined,
    });
    toast.success(t('admin.bimbel.bills.paid_toast'));
    markPaidBillId.value = null;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.bills.paid_fail'));
  } finally { markPaidSaving.value = false; }
}

const FILTER_OPTIONS = computed<{ key: Filter; label: string }[]>(() => [
  { key: 'all', label: t('admin.bimbel.bills.filter_all') },
  { key: 'unpaid', label: t('tutoring.adminBills.unpaid') },
  { key: 'pending', label: t('tutoring.adminBills.pending') },
  { key: 'paid', label: t('tutoring.adminBills.paid') },
]);

const activeFilterLabel = computed(
  () =>
    FILTER_OPTIONS.value.find((o) => o.key === filter.value)?.label ?? t('admin.bimbel.bills.filter_all'),
);

async function load() {
  loading.value = true;
  try {
    bills.value = await TutoringService.getAllBills(
      filter.value === 'all' ? undefined : filter.value,
    );
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.adminBills.empty'),
    );
  } finally {
    loading.value = false;
  }
}

watch(filter, load);
onMounted(load);

function pickFilter(k: Filter) {
  filter.value = k;
  showFilterPicker.value = false;
}

// Aggregates — computed against the loaded set, which reflects the
// active filter (so "Lunas" shows paid totals only). Acceptable since
// the strip describes the visible slice.
const total = computed(() => bills.value.reduce((s, b) => s + (b.amount ?? 0), 0));
const paidCount = computed(
  () => bills.value.filter((b) => b.status === 'paid').length,
);
const unpaidCount = computed(
  () => bills.value.filter((b) => b.status !== 'paid').length,
);
const unpaidTotal = computed(() =>
  bills.value
    .filter((b) => b.status !== 'paid')
    .reduce((s, b) => s + (b.amount ?? 0), 0),
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'wallet',
    label: t('admin.bimbel.bills.kpi_total_label'),
    value: bills.value.length,
    suffix: formatRupiah(total.value),
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: t('admin.bimbel.bills.kpi_paid_label'),
    value: paidCount.value,
    tone: 'green',
  },
  {
    icon: 'alert-circle',
    label: t('admin.bimbel.bills.kpi_unpaid_label'),
    value: unpaidCount.value,
    suffix:
      unpaidCount.value > 0 ? formatRupiah(unpaidTotal.value) : undefined,
    tone: unpaidCount.value > 0 ? 'amber' : 'green',
  },
  {
    icon: 'calendar',
    label: t('admin.bimbel.bills.kpi_due_7d_label'),
    value: bills.value.filter((b) => {
      if (!b.due_date || b.status === 'paid') return false;
      const d = new Date(b.due_date).getTime();
      return d - Date.now() < 7 * 24 * 3600 * 1000;
    }).length,
    tone: 'red',
  },
]);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.bills.kicker')"
      :title="t('tutoring.adminBills.title')"
      :meta="t('admin.bimbel.bills.meta', { total: bills.length, unpaid: formatRupiah(unpaidTotal) })"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-tutoring-panel text-tutoring-accent text-[13px] font-bold hover:bg-tutoring-panel/90"
        @click="router.push({ name: 'admin.tutoring.billing-settings' })"
      >
        <NavIcon name="settings" :size="13" />
        {{ t('tutoring.nav.billingSettings') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          :label="t('admin.bimbel.bills.filter_status')"
          :value="activeFilterLabel"
          icon-name="wallet"
          tone="amber"
          @click="showFilterPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="bills.length === 0"
      :text="t('tutoring.adminBills.empty')"
      icon="wallet"
    />
    <div
      v-else
      class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-tutoring-text-mid">
          <tr class="border-b border-tutoring-border">
            <th class="text-left font-bold px-3 py-2.5">{{ t('admin.bimbel.bills.th_student') }}</th>
            <th class="text-left font-bold px-3 py-2.5">{{ t('admin.bimbel.bills.th_source') }}</th>
            <th class="text-left font-bold px-3 py-2.5">{{ t('admin.bimbel.bills.th_period') }}</th>
            <th class="text-right font-bold px-3 py-2.5">{{ t('admin.bimbel.bills.th_amount') }}</th>
            <th class="text-left font-bold px-3 py-2.5">{{ t('admin.bimbel.bills.th_status') }}</th>
            <th class="px-3 py-2.5"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="b in bills"
            :key="b.id"
            class="border-b border-tutoring-border-soft last:border-0 hover:bg-tutoring-bg cursor-pointer"
            @click="openBillId = b.id"
          >
            <td class="px-3 py-3 font-semibold text-tutoring-text-hi">{{ b.student_name ?? '—' }}</td>
            <td class="px-3 py-3 text-tutoring-text-mid">{{ b.source_label ?? '—' }}</td>
            <td class="px-3 py-3 text-tutoring-text-mid">
              {{ b.month ?? (b.due_date ? formatDateShort(b.due_date) : '—') }}
            </td>
            <td class="px-3 py-3 text-right font-semibold text-tutoring-text-hi">
              {{ formatRupiah(b.amount ?? 0) }}
            </td>
            <td class="px-3 py-3">
              <TutoringStatusPill :bill="b.status" />
            </td>
            <td class="px-3 py-3 text-right">
              <div class="inline-flex items-center gap-1.5">
                <button
                  v-if="b.status !== 'paid'"
                  type="button"
                  class="inline-flex items-center gap-1 rounded-md bg-emerald-600 px-2 py-1 text-[12px] font-bold text-white hover:opacity-90"
                  @click.stop="markPaidBillId = b.id"
                >
                  {{ t('admin.bimbel.bills.mark_paid') }}
                </button>
                <button
                  type="button"
                  class="inline-flex items-center gap-1 rounded-md border border-tutoring-border px-2 py-1 text-[12px] font-bold text-tutoring-accent hover:bg-tutoring-accent/5"
                  @click.stop="openBillId = b.id"
                >
                  {{ t('admin.bimbel.bills.detail') }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mark as paid modal -->
    <div v-if="markPaidBillId && markPaidBill" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="markPaidBillId = null">
      <div class="w-full max-w-md rounded-2xl bg-tutoring-panel p-5 shadow-xl">
        <h3 class="text-[16px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.bills.modal_title') }}</h3>
        <p class="text-[14px] text-tutoring-text-mid mt-0.5">{{ t('admin.bimbel.bills.modal_subtitle') }}</p>

        <div class="relative my-3 overflow-hidden rounded-xl border border-tutoring-border-soft bg-tutoring-bg/40 pl-4 pr-3 py-3">
          <span class="absolute left-0 top-0 h-full w-1.5 bg-emerald-500" />
          <p class="text-[13px] font-extrabold uppercase tracking-widest text-emerald-700 dark:text-emerald-300">{{ t('admin.bimbel.bills.modal_bill_kicker') }}</p>
          <p class="mt-0.5 text-[20px] font-extrabold text-tutoring-text-hi">{{ formatRupiah(markPaidBill.amount ?? 0) }}</p>
          <p class="text-[14px] text-tutoring-text-mid">
            {{ [markPaidBill.source_label, markPaidBill.student_name, markPaidBill.due_date ? t('admin.bimbel.bills.due_date_prefix', { date: formatDateShort(markPaidBill.due_date) }) : null].filter(Boolean).join(' · ') }}
          </p>
        </div>

        <div class="space-y-2.5">
          <label class="grid items-center gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.bills.field_method') }}</span>
            <select v-model="markPaidForm.payment_method" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none">
              <option value="bank_transfer">{{ t('admin.bimbel.bills.method_transfer') }}</option>
              <option value="qris">{{ t('admin.bimbel.bills.method_qris') }}</option>
              <option value="cash">{{ t('admin.bimbel.bills.method_cash') }}</option>
            </select>
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.bills.field_payment_date') }}</span>
            <input v-model="markPaidForm.payment_date" type="date" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.bills.field_amount_received') }}</span>
            <input v-model.number="markPaidForm.amount" type="number" :placeholder="markPaidBill.amount?.toString()" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="pt-2 text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.bills.field_admin_notes') }}</span>
            <textarea v-model="markPaidForm.admin_notes" rows="2" :placeholder="t('admin.bimbel.bills.notes_ph')" class="rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none"></textarea>
          </label>
        </div>

        <div class="mt-4 flex gap-2">
          <button type="button" class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft" @click="markPaidBillId = null">{{ t('admin.bimbel.bills.cancel') }}</button>
          <button type="button" :disabled="markPaidSaving" class="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="confirmMarkPaid">
            {{ markPaidSaving ? t('admin.bimbel.bills.saving') : t('admin.bimbel.bills.mark_paid') }}
          </button>
        </div>
      </div>
    </div>

    <BillDetailModal
      v-if="openBillId"
      :bill-id="openBillId"
      @close="openBillId = null"
      @done="() => { openBillId = null; load(); }"
    />

    <Modal
      v-if="showFilterPicker"
      :title="t('admin.bimbel.bills.filter_modal_title')"
      @close="showFilterPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in FILTER_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-bg"
            :class="{ 'bg-tutoring-accent/5 text-tutoring-accent font-bold': filter === o.key }"
            @click="pickFilter(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
