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

type Filter = 'all' | 'unpaid' | 'pending' | 'paid';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const filter = ref<Filter>('all');
const bills = ref<TutoringBill[]>([]);
const showFilterPicker = ref(false);

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
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white text-role-admin text-[12px] font-bold hover:bg-white/90"
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

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="bills.length === 0"
      :text="t('tutoring.adminBills.empty')"
      icon="wallet"
    />
    <div
      v-else
      class="bg-white border border-slate-100 rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-slate-500">
          <tr class="border-b border-slate-200">
            <th class="text-left font-bold px-3 py-2.5">Siswa</th>
            <th class="text-left font-bold px-3 py-2.5">Sumber</th>
            <th class="text-left font-bold px-3 py-2.5">Periode</th>
            <th class="text-right font-bold px-3 py-2.5">Nominal</th>
            <th class="text-left font-bold px-3 py-2.5">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="b in bills"
            :key="b.id"
            class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
          >
            <td class="px-3 py-3 font-semibold text-slate-900">{{ b.student_name ?? '—' }}</td>
            <td class="px-3 py-3 text-slate-700">{{ b.source_label ?? '—' }}</td>
            <td class="px-3 py-3 text-slate-700">
              {{ b.month ?? (b.due_date ? formatDateShort(b.due_date) : '—') }}
            </td>
            <td class="px-3 py-3 text-right font-semibold text-slate-900">
              {{ formatRupiah(b.amount ?? 0) }}
            </td>
            <td class="px-3 py-3">
              <TutoringStatusPill :bill="b.status" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal
      v-if="showFilterPicker"
      title="Filter Status"
      @close="showFilterPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in FILTER_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': filter === o.key }"
            @click="pickFilter(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
