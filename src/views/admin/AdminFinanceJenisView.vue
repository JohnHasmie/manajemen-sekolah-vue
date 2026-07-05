<!--
  AdminFinanceJenisView.vue — admin · Jenis Pembayaran tab.

  CRUD on payment_types with bulk generate-bill flow. Endpoints:
    GET    /payment-types
    POST   /payment-types
    PUT    /payment-types/{id}
    DELETE /payment-types/{id}
    PATCH  /payment-types/{id}/status
    POST   /generate-bill
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { FinanceService } from '@/services/finance.service';
import { periodLabel, type PaymentType } from '@/types/billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PaymentTypeFormModal from '@/components/feature/PaymentTypeFormModal.vue';
import GenerateBillModal from '@/components/feature/GenerateBillModal.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRupiah } from '@/lib/format';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

defineProps<{ moneyFlow?: unknown }>();

const { t } = useI18n();

const paymentTypes = ref<PaymentType[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

type StatusFilter = 'all' | 'active' | 'inactive';
const statusFilter = ref<StatusFilter>('all');
const search = ref('');
const showStatusSheet = ref(false);

const STATUS_OPTS = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('admin.sekolah.finance_jenis.status_all') },
  { key: 'active', label: t('admin.sekolah.finance_jenis.status_active') },
  { key: 'inactive', label: t('admin.sekolah.finance_jenis.status_inactive') },
]);

// Form + generate modals
const showForm = ref(false);
const editing = ref<PaymentType | null>(null);
const showGenerate = ref(false);
const generateInitialId = ref<string>('');
const confirmDelete = ref<PaymentType | null>(null);
const isDeleting = ref(false);
const togglingId = ref<string>('');

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const filters: Parameters<typeof FinanceService.listPaymentTypes>[0] = {};
    if (statusFilter.value !== 'all') filters.status = statusFilter.value;
    if (search.value.trim()) filters.search = search.value.trim();
    paymentTypes.value = await FinanceService.listPaymentTypes(filters);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

watch(statusFilter, () => void load());

// Search debounce
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(search, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => void load(), 300);
});

const statusChipValue = computed(
  () => STATUS_OPTS.value.find((o) => o.key === statusFilter.value)?.label ?? t('admin.sekolah.finance_jenis.status_all_short'),
);

const listState = computed<AsyncState<PaymentType[]>>(() => {
  if (isLoading.value && paymentTypes.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (paymentTypes.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: paymentTypes.value };
});

function openAdd() {
  editing.value = null;
  showForm.value = true;
}
function openEdit(pt: PaymentType) {
  editing.value = pt;
  showForm.value = true;
}
function openGenerate(pt?: PaymentType) {
  generateInitialId.value = pt?.id ?? '';
  showGenerate.value = true;
}

function onSaved(_pt: PaymentType, meta: { bills_generated?: number; bills_skipped?: number }) {
  const created = meta.bills_generated ?? 0;
  toast.value = {
    message: created > 0
      ? t('admin.sekolah.finance_jenis.toast_saved_with_bills', { count: created })
      : t('admin.sekolah.finance_jenis.toast_saved'),
    tone: 'success',
  };
  void load();
}

function onGenerated(res: { created: number; skipped: number }) {
  toast.value = {
    message: res.skipped > 0
      ? t('admin.sekolah.finance_jenis.toast_generated_with_skipped', { created: res.created, skipped: res.skipped })
      : t('admin.sekolah.finance_jenis.toast_generated', { created: res.created }),
    tone: 'success',
  };
}

async function doDelete() {
  if (!confirmDelete.value) return;
  isDeleting.value = true;
  try {
    await FinanceService.destroyPaymentType(confirmDelete.value.id);
    toast.value = { message: t('admin.sekolah.finance_jenis.toast_deleted'), tone: 'success' };
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDeleting.value = false;
    confirmDelete.value = null;
  }
}

async function toggleStatus(pt: PaymentType) {
  togglingId.value = pt.id;
  try {
    const next = pt.status === 'active' ? 'inactive' : 'active';
    await FinanceService.setPaymentTypeStatus(pt.id, next);
    toast.value = {
      message: next === 'active'
        ? t('admin.sekolah.finance_jenis.toast_activated', { name: pt.name })
        : t('admin.sekolah.finance_jenis.toast_deactivated', { name: pt.name }),
      tone: 'success',
    };
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    togglingId.value = '';
  }
}

const deleteMessage = computed(() =>
  confirmDelete.value
    ? t('admin.sekolah.finance_jenis.delete_message', { name: confirmDelete.value.name })
    : '',
);
</script>

<template>
  <section class="space-y-md">
    <PageFilterToolbar
      v-model:search="search"
      :search-placeholder="t('admin.sekolah.finance_jenis.search_placeholder')"
      :search-min-width="220"
    >
      <template #chips>
        <AppFilterChip
          icon-name="filter"
          :label="t('admin.sekolah.finance_jenis.chip_status')"
          :value="statusChipValue"
          tone="amber"
          @click="showStatusSheet = true"
        />
      </template>
    </PageFilterToolbar>

    <div class="flex items-center justify-between gap-2">
      <p class="text-2xs font-bold text-slate-500">
        {{ t('admin.sekolah.finance_jenis.count_label', { count: paymentTypes.length }) }}
      </p>
      <div class="flex gap-2">
        <Button variant="secondary" size="sm" @click="openGenerate()">
          <NavIcon name="zap" :size="13" />
          {{ t('admin.sekolah.finance_jenis.generate_bill') }}
        </Button>
        <Button variant="primary" size="sm" @click="openAdd">
          <NavIcon name="plus" :size="13" />
          {{ t('admin.sekolah.finance_jenis.add_type') }}
        </Button>
      </div>
    </div>

    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.finance_jenis.empty_title')"
      :empty-description="t('admin.sekolah.finance_jenis.empty_description')"
      empty-icon="layers"
      @retry="load"
    >
      <template #default>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <article
            v-for="pt in paymentTypes"
            :key="pt.id"
            class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3"
          >
            <header class="flex items-start gap-3">
              <div
                class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
                :class="pt.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'"
              >
                <NavIcon name="layers" :size="18" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-[13px] font-bold text-slate-900 truncate">{{ pt.name }}</p>
                <p class="text-2xs text-slate-500 mt-0.5">
                  {{ periodLabel(pt.period) }} · {{ formatRupiah(pt.amount) }}
                </p>
              </div>
              <span
                class="text-4xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full"
                :class="
                  pt.status === 'active'
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-slate-100 text-slate-600'
                "
              >{{ pt.status === 'active' ? t('admin.sekolah.finance_jenis.badge_active') : t('admin.sekolah.finance_jenis.badge_inactive') }}</span>
            </header>

            <p v-if="pt.description" class="text-2xs text-slate-500 line-clamp-2">
              {{ pt.description }}
            </p>

            <div class="flex flex-wrap gap-1.5">
              <Button variant="secondary" size="sm" @click="openEdit(pt)">
                <NavIcon name="edit" :size="12" />
                {{ t('admin.sekolah.finance_jenis.edit') }}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                :loading="togglingId === pt.id"
                @click="toggleStatus(pt)"
              >
                {{ pt.status === 'active' ? t('admin.sekolah.finance_jenis.deactivate') : t('admin.sekolah.finance_jenis.activate') }}
              </Button>
              <Button variant="ghost" size="sm" @click="openGenerate(pt)">
                <NavIcon name="zap" :size="12" />
                {{ t('admin.sekolah.finance_jenis.generate') }}
              </Button>
              <Button variant="danger" size="sm" @click="confirmDelete = pt">
                <NavIcon name="trash-2" :size="12" />
                {{ t('admin.sekolah.finance_jenis.delete') }}
              </Button>
            </div>
          </article>
        </div>
      </template>
    </AsyncView>

    <!-- Status filter sheet -->
    <Modal
      v-if="showStatusSheet"
      :title="t('admin.sekolah.finance_jenis.status_modal_title')"
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

    <PaymentTypeFormModal
      v-if="showForm"
      :payment-type="editing"
      @close="showForm = false"
      @saved="onSaved"
    />

    <GenerateBillModal
      v-if="showGenerate"
      :payment-types="paymentTypes.filter((pt) => pt.status === 'active')"
      :initial-payment-type-id="generateInitialId"
      @close="showGenerate = false"
      @done="onGenerated"
    />

    <ConfirmationDialog
      v-if="confirmDelete"
      :title="t('admin.sekolah.finance_jenis.delete_title')"
      :message="deleteMessage"
      :confirm-label="t('admin.sekolah.finance_jenis.delete')"
      :loading="isDeleting"
      @close="confirmDelete = null"
      @confirm="doDelete"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </section>
</template>
