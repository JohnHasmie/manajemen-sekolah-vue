<!--
  ParentBillsView — parent Bill list.

  Mockup-exact: hero + red "outstanding" banner (when unpaid) + 3-tab
  row (Belum lunas / Sudah lunas / Semua) + bill cards. Data via
  TutoringService.getBills.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutoringBill } from '@/types/tutoring';

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { activeChildId } = useChildPicker();
const toast = useToast();

// One bill at a time is fine — parent typically downloads after a single
// payment. Tracking by id keeps the spinner local to the row instead of
// blocking the whole list.
const downloadingId = ref<string | null>(null);

async function downloadInvoice(b: TutoringBill) {
  if (downloadingId.value) return;
  downloadingId.value = b.id;
  try {
    await TutoringService.downloadInvoicePdf(b.id);
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.billDetail.downloadFailed'));
  } finally {
    downloadingId.value = null;
  }
}

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const bills = ref<TutoringBill[]>([]);
type TabKey = 'unpaid' | 'paid' | 'all';
const activeTab = ref<TabKey>('unpaid');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try { bills.value = await TutoringService.getBills(sid); }
  catch { /* non-fatal */ }
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

// ── Status predicates ──────────────────────────────────────────
function isPaid(b: TutoringBill): boolean {
  return /lunas|paid|done/i.test(b.status ?? '');
}
function isPending(b: TutoringBill): boolean {
  return /pending/i.test(b.status ?? '');
}
function isUnpaid(b: TutoringBill): boolean {
  if (isPaid(b)) return false;
  return /unpaid|due|overdue|belum|pending/i.test(b.status ?? '');
}

// ── Aggregates ─────────────────────────────────────────────────
const unpaidList = computed(() => bills.value.filter(isUnpaid));
const paidList = computed(() => bills.value.filter(isPaid));
const unpaidCount = computed(() => unpaidList.value.length);
const paidCount = computed(() => paidList.value.length);

const totalUnpaidFmt = computed(() =>
  formatRupiah(unpaidList.value.reduce((s, b) => s + (b.amount ?? 0), 0)),
);

function daysUntil(iso?: string | null): number | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return null;
  return Math.ceil((d.valueOf() - Date.now()) / 86_400_000);
}

const urgentCount = computed(() =>
  unpaidList.value.filter((b) => {
    const days = daysUntil(b.due_date);
    return days != null && days >= 0 && days <= 3;
  }).length,
);

// ── Tabs ────────────────────────────────────────────────────────
const tabs = computed<{ id: TabKey; label: string }[]>(() => [
  { id: 'unpaid', label: t('wali.bimbel.bills.tab_unpaid', { count: unpaidCount.value }) },
  { id: 'paid', label: t('wali.bimbel.bills.tab_paid', { count: paidCount.value }) },
  { id: 'all', label: t('wali.bimbel.bills.tab_all') },
]);

const visibleBills = computed(() => {
  if (activeTab.value === 'unpaid') return unpaidList.value;
  if (activeTab.value === 'paid') return paidList.value;
  return bills.value;
});

// ── Pill style + label per bill ────────────────────────────────
function pillClass(b: TutoringBill): string {
  const base = 'inline-flex flex-shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide';
  if (isPaid(b)) return `${base} bg-bimbel-green-dim text-green-700`;
  if (isPending(b)) return `${base} bg-bimbel-amber-dim text-amber-700`;
  if (isUnpaid(b)) {
    const days = daysUntil(b.due_date);
    if (days != null && days <= 3) return `${base} bg-bimbel-red-dim text-red-700`;
    return `${base} bg-bimbel-accent-dim text-bimbel-hero`;
  }
  return `${base} bg-bimbel-accent-dim text-bimbel-hero`;
}

function pillLabel(b: TutoringBill): string {
  if (isPaid(b)) return t('wali.bimbel.bills.paid_pill');
  if (isPending(b)) return t('wali.bimbel.bills.due_pending');
  if (isUnpaid(b)) {
    const days = daysUntil(b.due_date);
    if (days != null && days < 0) return t('wali.bimbel.bills.late_pill', { days: Math.abs(days) });
    if (days != null && days <= 3) return t('wali.bimbel.bills.due_soon_pill', { days });
    return t('wali.bimbel.bills.active_pill');
  }
  return b.status ?? '—';
}

function dueLine(b: TutoringBill): string {
  if (isPaid(b)) return t('wali.bimbel.bills.paid_evidence');
  if (!b.due_date) return t('wali.bimbel.bills.no_due_date');
  const d = new Date(b.due_date);
  if (Number.isNaN(d.valueOf())) return t('wali.bimbel.bills.no_due_date');
  const fmt = d.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
  return t('wali.bimbel.bills.due_label', { date: fmt });
}

function pay(b: TutoringBill) {
  router.push({ name: 'parent.tutoring.pay-bill', params: { billId: b.id } });
}
function payFirst() {
  const first = unpaidList.value[0];
  if (first) pay(first);
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentHomeHero
      :kicker="t('wali.bimbel.bills.kicker')"
      :title="t('wali.bimbel.bills.title')"
      :subtitle="t('wali.bimbel.bills.subtitle')"
      :stats="[]"
    >
      <template #actions>
        <ParentChildPickerChip />
      </template>
    </ParentHomeHero>

    <!-- Outstanding banner -->
    <div
      v-if="unpaidCount > 0"
      class="rounded-xl bg-bimbel-red-dim border border-red-300 p-3.5 flex justify-between items-center"
    >
      <div>
        <p class="text-[12px] text-red-800 tracking-wider font-bold">{{ t('wali.bimbel.bills.outstanding_label') }}</p>
        <p class="text-[22px] font-extrabold text-red-900 leading-tight mt-0.5">{{ totalUnpaidFmt }}</p>
        <p class="text-[12px] text-red-800">
          {{ urgentCount
            ? t('wali.bimbel.bills.outstanding_caption_extra', { count: unpaidCount, urgent: urgentCount })
            : t('wali.bimbel.bills.outstanding_caption_simple', { count: unpaidCount }) }}
        </p>
      </div>
      <button
        type="button"
        class="bg-red-900 text-white text-[13px] font-bold px-3 py-2 rounded-lg flex-shrink-0"
        @click="payFirst"
      >
        {{ t('wali.bimbel.bills.pay_all_button') }}
      </button>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 border-b border-bimbel-border-soft">
      <button
        v-for="t in tabs"
        :key="t.id"
        type="button"
        class="px-3.5 py-2 text-[13px] border-b-2 -mb-px transition-colors"
        :class="
          activeTab === t.id
            ? 'text-bimbel-hero border-bimbel-hero font-bold'
            : 'text-bimbel-text-mid border-transparent'
        "
        @click="activeTab = t.id"
      >
        {{ t.label }}
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">{{ t('wali.bimbel.bills.loading') }}</div>

    <!-- Bill cards -->
    <div v-else-if="visibleBills.length" class="space-y-2.5">
      <div
        v-for="b in visibleBills"
        :key="b.id"
        class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-3.5"
        :class="{ 'opacity-70': isPaid(b) }"
      >
        <div class="flex justify-between items-start gap-3">
          <div class="min-w-0 flex-1">
            <p class="text-[14px] font-bold text-bimbel-text-hi">
              {{ b.source_label ?? b.source_type ?? t('wali.bimbel.bills.default_source') }}
            </p>
            <p class="text-[12px] text-bimbel-text-mid mt-0.5">
              {{ b.month ?? '—' }}
              <template v-if="b.student_name"> · {{ b.student_name }}</template>
            </p>
          </div>
          <span :class="pillClass(b)">{{ pillLabel(b) }}</span>
        </div>
        <div class="flex justify-between items-center mt-2.5 pt-2.5 border-t border-bimbel-border-soft">
          <div>
            <p class="text-[18px] font-extrabold text-bimbel-text-hi">
              {{ b.amount != null ? formatRupiah(b.amount) : '—' }}
            </p>
            <p class="text-[12px] text-bimbel-text-mid">{{ dueLine(b) }}</p>
          </div>
          <button
            v-if="!isPaid(b)"
            type="button"
            class="bg-bimbel-hero text-white text-[13px] font-bold px-3.5 py-2 rounded-lg"
            @click="pay(b)"
          >
            {{ t('wali.bimbel.bills.pay_button') }}
          </button>
          <button
            v-else
            type="button"
            :disabled="downloadingId === b.id"
            class="bg-bimbel-bg text-bimbel-text-mid text-[13px] px-3.5 py-2 rounded-lg disabled:opacity-50"
            @click="downloadInvoice(b)"
          >
            {{ downloadingId === b.id
              ? t('tutoring.billDetail.downloadingInvoice')
              : t('tutoring.billDetail.downloadInvoice') }}
          </button>
        </div>
      </div>
    </div>
    <p v-else class="text-center text-[14px] text-bimbel-text-mid py-8">
      {{ t('wali.bimbel.bills.empty_filter') }}
    </p>
  </div>
</template>
