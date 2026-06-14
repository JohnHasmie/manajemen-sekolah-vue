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
    toast.success('Tagihan ditandai lunas.');
    markPaidBillId.value = null;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menandai lunas.');
  } finally { markPaidSaving.value = false; }
}

const FILTER_OPTIONS = computed<{ key: Filter; label: string }[]>(() => [
  { key: 'all', label: 'Semua' },
  { key: 'unpaid', label: t('tutoring.adminBills.unpaid') },
  { key: 'pending', label: t('tutoring.adminBills.pending') },
  { key: 'paid', label: t('tutoring.adminBills.paid') },
]);

const activeFilterLabel = computed(
  () =>
    FILTER_OPTIONS.value.find((o) => o.key === filter.value)?.label ?? 'Semua',
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
    label: 'Total tagihan',
    value: bills.value.length,
    suffix: formatRupiah(total.value),
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: 'Lunas',
    value: paidCount.value,
    tone: 'green',
  },
  {
    icon: 'alert-circle',
    label: 'Belum lunas',
    value: unpaidCount.value,
    suffix:
      unpaidCount.value > 0 ? formatRupiah(unpaidTotal.value) : undefined,
    tone: unpaidCount.value > 0 ? 'amber' : 'green',
  },
  {
    icon: 'calendar',
    label: 'Jatuh tempo 7h',
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
      kicker="Bimbel · Tagihan"
      :title="t('tutoring.adminBills.title')"
      :meta="`${bills.length} tagihan · ${formatRupiah(unpaidTotal)} belum lunas`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-panel text-bimbel-accent text-[13px] font-bold hover:bg-bimbel-panel/90"
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
          label="Status"
          :value="activeFilterLabel"
          icon-name="wallet"
          tone="amber"
          @click="showFilterPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="bills.length === 0"
      :text="t('tutoring.adminBills.empty')"
      icon="wallet"
    />
    <div
      v-else
      class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-bimbel-text-mid">
          <tr class="border-b border-bimbel-border">
            <th class="text-left font-bold px-3 py-2.5">Siswa</th>
            <th class="text-left font-bold px-3 py-2.5">Sumber</th>
            <th class="text-left font-bold px-3 py-2.5">Periode</th>
            <th class="text-right font-bold px-3 py-2.5">Nominal</th>
            <th class="text-left font-bold px-3 py-2.5">Status</th>
            <th class="px-3 py-2.5"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="b in bills"
            :key="b.id"
            class="border-b border-bimbel-border-soft last:border-0 hover:bg-bimbel-bg cursor-pointer"
            @click="openBillId = b.id"
          >
            <td class="px-3 py-3 font-semibold text-bimbel-text-hi">{{ b.student_name ?? '—' }}</td>
            <td class="px-3 py-3 text-bimbel-text-mid">{{ b.source_label ?? '—' }}</td>
            <td class="px-3 py-3 text-bimbel-text-mid">
              {{ b.month ?? (b.due_date ? formatDateShort(b.due_date) : '—') }}
            </td>
            <td class="px-3 py-3 text-right font-semibold text-bimbel-text-hi">
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
                  Tandai lunas
                </button>
                <button
                  type="button"
                  class="inline-flex items-center gap-1 rounded-md border border-bimbel-border px-2 py-1 text-[12px] font-bold text-bimbel-accent hover:bg-bimbel-accent/5"
                  @click.stop="openBillId = b.id"
                >
                  Detail
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mark as paid modal -->
    <div v-if="markPaidBillId && markPaidBill" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="markPaidBillId = null">
      <div class="w-full max-w-md rounded-2xl bg-bimbel-panel p-5 shadow-xl">
        <h3 class="text-[16px] font-bold text-bimbel-text-hi">Tandai sebagai lunas</h3>
        <p class="text-[14px] text-bimbel-text-mid mt-0.5">Catat pembayaran manual yang sudah diterima admin.</p>

        <div class="relative my-3 overflow-hidden rounded-xl border border-bimbel-border-soft bg-bimbel-bg/40 pl-4 pr-3 py-3">
          <span class="absolute left-0 top-0 h-full w-1.5 bg-emerald-500" />
          <p class="text-[13px] font-extrabold uppercase tracking-widest text-emerald-700 dark:text-emerald-300">TAGIHAN</p>
          <p class="mt-0.5 text-[20px] font-extrabold text-bimbel-text-hi">{{ formatRupiah(markPaidBill.amount ?? 0) }}</p>
          <p class="text-[14px] text-bimbel-text-mid">
            {{ [markPaidBill.source_label, markPaidBill.student_name, markPaidBill.due_date ? `jatuh tempo ${formatDateShort(markPaidBill.due_date)}` : null].filter(Boolean).join(' · ') }}
          </p>
        </div>

        <div class="space-y-2.5">
          <label class="grid items-center gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">Metode</span>
            <select v-model="markPaidForm.payment_method" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none">
              <option value="bank_transfer">Transfer bank</option>
              <option value="qris">QRIS</option>
              <option value="cash">Tunai</option>
            </select>
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">Tanggal bayar</span>
            <input v-model="markPaidForm.payment_date" type="date" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-center gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="text-[14px] text-bimbel-text-mid">Jumlah diterima</span>
            <input v-model.number="markPaidForm.amount" type="number" :placeholder="markPaidBill.amount?.toString()" class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          </label>
          <label class="grid items-start gap-3" style="grid-template-columns: 120px 1fr;">
            <span class="pt-2 text-[14px] text-bimbel-text-mid">Catatan admin</span>
            <textarea v-model="markPaidForm.admin_notes" rows="2" placeholder="Opsional — bukti transfer diverifikasi, dll." class="rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"></textarea>
          </label>
        </div>

        <div class="mt-4 flex gap-2">
          <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[14px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="markPaidBillId = null">Batal</button>
          <button type="button" :disabled="markPaidSaving" class="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="confirmMarkPaid">
            {{ markPaidSaving ? 'Menyimpan…' : 'Tandai lunas' }}
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
      title="Filter Status"
      @close="showFilterPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in FILTER_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-bimbel-bg"
            :class="{ 'bg-bimbel-accent/5 text-bimbel-accent font-bold': filter === o.key }"
            @click="pickFilter(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
