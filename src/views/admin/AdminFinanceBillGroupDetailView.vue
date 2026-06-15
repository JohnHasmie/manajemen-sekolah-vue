<!--
  AdminFinanceBillGroupDetailView.vue — admin · per-bucket per-student
  tagihan detail.

  Drilled into from AdminFinanceTagihanView when a BillGroupCard is
  tapped. Fetches `GET /bills?payment_type_id=…&class_id=…&academic_year_id=…`
  and lists the individual bills with student name + amount + status.

  Bulk select unpaid bills → TagihReminderModal (bulk reminder).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { FinanceService } from '@/services/finance.service';
import type { Bill } from '@/types/billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import BillCard from '@/components/feature/BillCard.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import TagihReminderModal from '@/components/feature/TagihReminderModal.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRupiah } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));
const paymentTypeId = computed(() => String(route.params.paymentTypeId ?? ''));
const academicYearId = computed(() => {
  const v = route.query.academicYearId;
  return typeof v === 'string' && v.length > 0 ? v : undefined;
});

const bills = ref<Bill[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);

const selectedIds = ref<Set<string>>(new Set());
const showReminder = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await FinanceService.listBills({
      payment_type_id: paymentTypeId.value,
      class_id: classId.value,
      academic_year_id: academicYearId.value,
      per_page: 200,
    });
    bills.value = res.items;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

const className = computed(() => bills.value[0]?.student?.class_name ?? '');
const paymentTypeName = computed(() => bills.value[0]?.payment_type?.name ?? t('admin.sekolah.bill_group_detail.fallback_payment_type'));

const unpaid = computed(() => bills.value.filter((b) => b.status !== 'paid'));
const paid = computed(() => bills.value.filter((b) => b.status === 'paid'));
const overdue = computed(() => bills.value.filter((b) => b.status === 'overdue'));

const totalAmount = computed(() => bills.value.reduce((s, b) => s + b.amount, 0));
const paidAmount = computed(() => paid.value.reduce((s, b) => s + b.amount, 0));
const outstandingAmount = computed(() => Math.max(0, totalAmount.value - paidAmount.value));

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: t('admin.sekolah.bill_group_detail.kpi_total_students'),
    value: bills.value.length,
    tone: 'brand',
  },
  {
    icon: 'check-circle',
    label: t('admin.sekolah.bill_group_detail.kpi_paid'),
    value: paid.value.length,
    tone: 'green',
  },
  {
    icon: 'clock',
    label: t('admin.sekolah.bill_group_detail.kpi_in_progress'),
    value: unpaid.value.length - overdue.value.length,
    tone: 'amber',
  },
  {
    icon: 'alert-triangle',
    label: t('admin.sekolah.bill_group_detail.kpi_overdue'),
    value: overdue.value.length,
    tone: overdue.value.length > 0 ? 'red' : 'slate',
    accented: overdue.value.length > 0,
  },
]);

const listState = computed<AsyncState<Bill[]>>(() => {
  if (isLoading.value && bills.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (bills.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: bills.value };
});

function toggleSelect(b: Bill) {
  if (b.status === 'paid') return;
  const set = new Set(selectedIds.value);
  if (set.has(b.id)) set.delete(b.id);
  else set.add(b.id);
  selectedIds.value = set;
}

function selectAllUnpaid() {
  if (selectedIds.value.size === unpaid.value.length) {
    selectedIds.value = new Set();
  } else {
    selectedIds.value = new Set(unpaid.value.map((b) => b.id));
  }
}

const selectedBills = computed(() =>
  bills.value.filter((b) => selectedIds.value.has(b.id)),
);

function onReminderSent(payload: { count: number; channel: string }) {
  toast.value = {
    message: t('admin.sekolah.bill_group_detail.toast_reminder_sent', {
      count: payload.count,
      channel: payload.channel === 'whatsapp' ? 'WhatsApp' : t('admin.sekolah.bill_group_detail.channel_email'),
    }),
    tone: 'success',
  };
  selectedIds.value = new Set();
  void load();
}

function goBack() {
  router.push({ name: 'admin.finance.tagihan' });
}

const headerMeta = computed(
  () =>
    t('admin.sekolah.bill_group_detail.header_meta', {
      className: className.value || t('admin.sekolah.bill_group_detail.fallback_class'),
      count: bills.value.length,
      remaining: formatRupiah(outstandingAmount.value),
    }),
);

const kicker = computed(() =>
  t('admin.sekolah.bill_group_detail.header_kicker', { className: className.value || '—' }),
);
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('admin.sekolah.bill_group_detail.back_to_hub') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="kicker"
      :title="paymentTypeName"
      :meta="headerMeta"
    />

    <KpiStripCards :cards="kpiCards" />

    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.bill_group_detail.empty_title')"
      empty-icon="credit-card"
      @retry="load"
    >
      <template #default>
        <div class="space-y-3">
          <!-- Belum lunas -->
          <section v-if="unpaid.length > 0" class="bg-white border border-slate-200 rounded-2xl p-2">
            <header class="flex items-center justify-between gap-2 px-3 pt-2 pb-1">
              <h3 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                {{ t('admin.sekolah.bill_group_detail.section_unpaid', { count: unpaid.length }) }}
              </h3>
              <button
                type="button"
                class="text-[11px] font-bold text-role-admin hover:underline"
                @click="selectAllUnpaid"
              >
                {{ selectedIds.size === unpaid.length ? t('admin.sekolah.bill_group_detail.unselect_all') : t('admin.sekolah.bill_group_detail.select_all') }}
              </button>
            </header>
            <div class="divide-y divide-slate-100">
              <label
                v-for="b in unpaid"
                :key="b.id"
                class="flex items-center gap-2 px-2 py-1 cursor-pointer hover:bg-slate-50 rounded-xl"
              >
                <input
                  type="checkbox"
                  class="w-4 h-4 accent-role-admin"
                  :checked="selectedIds.has(b.id)"
                  @change="toggleSelect(b)"
                />
                <div class="flex-1 min-w-0">
                  <BillCard :bill="b" show-student-name readonly />
                </div>
              </label>
            </div>
          </section>

          <!-- Lunas -->
          <section v-if="paid.length > 0" class="bg-white border border-slate-200 rounded-2xl p-2">
            <h3 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1 px-3 pt-2">
              {{ t('admin.sekolah.bill_group_detail.section_paid', { count: paid.length }) }}
            </h3>
            <div class="divide-y divide-slate-100">
              <BillCard
                v-for="b in paid"
                :key="b.id"
                :bill="b"
                show-student-name
                readonly
              />
            </div>
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- Bulk-action bar (sticky) -->
    <section
      v-if="selectedIds.size > 0"
      class="sticky bottom-4 z-30 bg-white border border-slate-200 rounded-2xl shadow-lg p-3 flex items-center gap-2"
    >
      <div class="flex-1 min-w-0">
        <p class="text-[11px] font-bold text-slate-700">
          {{ t('admin.sekolah.bill_group_detail.selected_count', { count: selectedIds.size }) }}
        </p>
        <p class="text-[10px] text-slate-500">
          {{ t('admin.sekolah.bill_group_detail.total_label') }}: {{ formatRupiah(selectedBills.reduce((s, b) => s + b.amount, 0)) }}
        </p>
      </div>
      <Button variant="secondary" size="sm" @click="selectedIds = new Set()">
        {{ t('admin.sekolah.bill_group_detail.cancel') }}
      </Button>
      <Button variant="primary" size="sm" @click="showReminder = true">
        <NavIcon name="bell" :size="13" />
        {{ t('admin.sekolah.bill_group_detail.bulk_remind', { count: selectedIds.size }) }}
      </Button>
    </section>

    <TagihReminderModal
      v-if="showReminder"
      :bills="selectedBills"
      @close="showReminder = false"
      @sent="onReminderSent"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
