<!--
  AdminFinancePaymentsView.vue — admin · Pembayaran tab.

  Lists payments (verified / pending / rejected) from `GET /payments`.
  Pending payments get an "Approve / Tolak" CTA that opens
  PaymentProofModal (loads bukti via /payment/{id}/receipt blob).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { FinanceService } from '@/services/finance.service';
import {
  PAYMENT_STATUS_LABELS,
  PAYMENT_STATUS_TONES,
  type Payment,
} from '@/types/billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PaymentProofModal from '@/components/feature/PaymentProofModal.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRupiah, formatDateLong } from '@/lib/format';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

defineProps<{ moneyFlow?: unknown }>();

const { t } = useI18n();

const payments = ref<Payment[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

type StatusFilter = 'all' | 'pending' | 'verified' | 'rejected';
const statusFilter = ref<StatusFilter>('pending');
const search = ref('');

const STATUS_OPTS = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('admin.sekolah.payments.status_all') },
  { key: 'pending', label: t('admin.sekolah.payments.status_pending') },
  { key: 'verified', label: t('admin.sekolah.payments.status_verified') },
  { key: 'rejected', label: t('admin.sekolah.payments.status_rejected') },
]);

const showStatusSheet = ref(false);
const activePayment = ref<Payment | null>(null);

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const filters: Parameters<typeof FinanceService.listPayments>[0] = {
      per_page: 100,
    };
    if (statusFilter.value !== 'all') filters.status = statusFilter.value;
    const res = await FinanceService.listPayments(filters);
    payments.value = res.items;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

watch(statusFilter, () => void load());

// Client-side search (server doesn't support it on /payments).
const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return payments.value;
  return payments.value.filter((p) => {
    const hay = `${p.bill?.student?.name ?? ''} ${p.bill?.title ?? ''} ${p.payment_method ?? ''}`.toLowerCase();
    return hay.includes(q);
  });
});

const statusChipValue = computed(
  () => STATUS_OPTS.value.find((o) => o.key === statusFilter.value)?.label ?? t('admin.sekolah.payments.status_all_short'),
);

const listState = computed<AsyncState<Payment[]>>(() => {
  if (isLoading.value && payments.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filtered.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filtered.value };
});

function statusPill(p: Payment) {
  const tone = PAYMENT_STATUS_TONES[p.status];
  return { label: PAYMENT_STATUS_LABELS[p.status], cls: `${tone.bg} ${tone.text}` };
}

function onVerified(updated: Payment) {
  toast.value = {
    message: updated.status === 'verified'
      ? t('admin.sekolah.payments.toast_approved')
      : t('admin.sekolah.payments.toast_rejected'),
    tone: 'success',
  };
  void load();
}
</script>

<template>
  <section class="space-y-md">
    <PageFilterToolbar
      v-model:search="search"
      :search-placeholder="t('admin.sekolah.payments.search_placeholder')"
      :search-min-width="220"
    >
      <template #chips>
        <AppFilterChip
          icon-name="filter"
          :label="t('admin.sekolah.payments.chip_status')"
          :value="statusChipValue"
          tone="amber"
          @click="showStatusSheet = true"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.payments.empty_title')"
      :empty-description="t('admin.sekolah.payments.empty_description')"
      empty-icon="check-circle"
      @retry="load"
    >
      <template #default>
        <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
          <div
            v-for="(p, idx) in filtered"
            :key="p.id"
            class="px-4 py-3 flex items-center gap-3"
            :class="idx > 0 ? 'border-t border-slate-100' : ''"
          >
            <div
              class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
              :class="
                p.status === 'verified'
                  ? 'bg-emerald-100 text-emerald-700'
                  : p.status === 'rejected'
                    ? 'bg-red-100 text-red-700'
                    : 'bg-amber-100 text-amber-700'
              "
            >
              <NavIcon
                :name="p.status === 'verified' ? 'check-circle' : p.status === 'rejected' ? 'x-circle' : 'clock'"
                :size="18"
              />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">
                {{ p.bill?.student?.name ?? t('admin.sekolah.payments.fallback_student') }}
              </p>
              <p class="text-2xs text-slate-500 truncate">
                {{ p.bill?.title ?? t('admin.sekolah.payments.fallback_bill') }}
                <span v-if="p.payment_method"> · {{ p.payment_method }}</span>
                <span v-if="p.payment_date"> · {{ formatDateLong(p.payment_date) }}</span>
              </p>
            </div>
            <div class="text-right flex-shrink-0">
              <p class="text-[13px] font-bold text-slate-900">{{ formatRupiah(p.amount) }}</p>
              <span
                class="inline-block text-4xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full mt-1"
                :class="statusPill(p).cls"
              >{{ statusPill(p).label }}</span>
            </div>
            <Button
              v-if="p.status === 'pending'"
              variant="primary"
              size="sm"
              @click="activePayment = p"
            >
              {{ t('admin.sekolah.payments.verify') }}
            </Button>
            <Button
              v-else
              variant="secondary"
              size="sm"
              @click="activePayment = p"
            >
              {{ t('admin.sekolah.payments.detail') }}
            </Button>
          </div>
        </div>
      </template>
    </AsyncView>

    <!-- Status sheet -->
    <Modal
      v-if="showStatusSheet"
      :title="t('admin.sekolah.payments.status_modal_title')"
      size="sm"
      @close="showStatusSheet = false"
    >
      <div class="space-y-1">
        <button
          v-for="opt in STATUS_OPTS"
          :key="opt.key"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="
            statusFilter === opt.key
              ? 'bg-role-admin/10 text-role-admin'
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

    <!-- Verifikasi sheet -->
    <PaymentProofModal
      v-if="activePayment"
      :payment="activePayment"
      @close="activePayment = null"
      @done="onVerified"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </section>
</template>
