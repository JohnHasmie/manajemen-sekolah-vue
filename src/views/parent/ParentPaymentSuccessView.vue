<!--
  ParentPaymentSuccessView.vue — wali murid · Kuitansi pembayaran.

  Mirrors Flutter's `parent_payment_success_screen.dart`. Renders
  the verified-payment kuitansi with status hero, bill detail,
  timeline (Submitted → Verified → Receipt), bukti thumbnail, and
  the "Unduh kuitansi" / "Bagikan WA" actions.

  The payment is hydrated via `BillingService.getParentPayment` which
  takes an optional `?billId` query hint to skip the parent-bills scan.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { BillingService } from '@/services/billing.service';
import {
  PAYMENT_STATUS_LABELS,
  PAYMENT_STATUS_TONES,
  type Bill,
  type Payment,
} from '@/types/billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRupiah, formatDateLong } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const paymentId = computed(() => String(route.params.paymentId ?? ''));
const billHint = computed(() => {
  const v = route.query.billId;
  return typeof v === 'string' ? v : undefined;
});

const payment = ref<Payment | null>(null);
const bill = ref<Bill | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);
const isDownloading = ref(false);
const isSharing = ref(false);

// Bukti thumbnail — load receipt as blob and create object URL.
const buktiBlobUrl = ref<string | null>(null);
const buktiIsImage = ref(false);

async function loadBukti() {
  if (!payment.value) return;
  try {
    const blob = await BillingService.fetchReceiptBlob(payment.value.id);
    buktiIsImage.value = blob.type.startsWith('image/');
    if (buktiBlobUrl.value) URL.revokeObjectURL(buktiBlobUrl.value);
    buktiBlobUrl.value = URL.createObjectURL(blob);
  } catch {
    buktiBlobUrl.value = null;
  }
}

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await BillingService.getParentPayment(paymentId.value, {
      billId: billHint.value,
    });
    if (!res) {
      error.value = t('wali.sekolah.paymentSuccess.notFound');
      return;
    }
    payment.value = res.payment;
    bill.value = res.bill;
    void loadBukti();
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

onBeforeUnmount(() => {
  if (buktiBlobUrl.value) URL.revokeObjectURL(buktiBlobUrl.value);
});

async function download() {
  if (!payment.value) return;
  isDownloading.value = true;
  try {
    const name = `kuitansi-${bill.value?.title?.replace(/\s+/g, '-') ?? payment.value.id}.pdf`;
    await BillingService.downloadReceipt(payment.value.id, name);
    toast.value = { message: t('wali.sekolah.paymentSuccess.receiptDownloaded'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDownloading.value = false;
  }
}

async function share() {
  if (!payment.value || !bill.value) return;
  const text = [
    t('wali.sekolah.paymentSuccess.shareConfirm', { title: bill.value.title }),
    t('wali.sekolah.paymentSuccess.shareAmount', { amount: formatRupiah(payment.value.amount) }),
    t('wali.sekolah.paymentSuccess.shareStatus', { status: PAYMENT_STATUS_LABELS[payment.value.status] }),
    payment.value.payment_date ? t('wali.sekolah.paymentSuccess.shareDate', { date: formatDateLong(payment.value.payment_date) }) : '',
  ].filter(Boolean).join('\n');

  // Native share where supported (mobile + some desktops).
  if (typeof navigator !== 'undefined' && (navigator as any).share) {
    try {
      isSharing.value = true;
      await (navigator as any).share({
        title: t('wali.sekolah.paymentSuccess.shareTitle'),
        text,
      });
      return;
    } catch {
      // user cancelled or unsupported — fall through to WA fallback
    } finally {
      isSharing.value = false;
    }
  }

  // WhatsApp web fallback.
  const url = `https://wa.me/?text=${encodeURIComponent(text)}`;
  window.open(url, '_blank', 'noopener');
}

const state = computed<AsyncState<Payment>>(() => {
  if (isLoading.value && !payment.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (!payment.value) return { status: 'empty' };
  return { status: 'content', data: payment.value };
});

const heroGradient = computed(() => {
  if (!payment.value) return 'linear-gradient(135deg, #475569 0%, #94A3B8 100%)';
  if (payment.value.status === 'verified')
    return 'linear-gradient(135deg, #047857 0%, #10B981 100%)';
  if (payment.value.status === 'rejected')
    return 'linear-gradient(135deg, #991B1B 0%, #EF4444 100%)';
  return 'linear-gradient(135deg, #B45309 0%, #F59E0B 100%)';
});

const heroIcon = computed(() => {
  if (payment.value?.status === 'verified') return 'check-circle';
  if (payment.value?.status === 'rejected') return 'x-circle';
  return 'clock';
});

const timelineSteps = computed(() => {
  if (!payment.value) return [];
  const steps: { label: string; meta: string | null; done: boolean }[] = [];
  steps.push({
    label: t('wali.sekolah.paymentSuccess.timelineSubmitted'),
    meta: payment.value.created_at ? formatDateLong(payment.value.created_at) : null,
    done: true,
  });
  steps.push({
    label: t('wali.sekolah.paymentSuccess.timelineVerified'),
    meta: payment.value.verified_at ? formatDateLong(payment.value.verified_at) : null,
    done: payment.value.status === 'verified',
  });
  steps.push({
    label: t('wali.sekolah.paymentSuccess.timelineReceipt'),
    meta: payment.value.verified_at ? t('wali.sekolah.paymentSuccess.timelineReceiptReady') : null,
    done: payment.value.status === 'verified',
  });
  return steps;
});
</script>

<template>
  <div class="space-y-md pb-12">
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[13px] font-bold text-slate-600 hover:text-role-wali"
        @click="router.push({ name: 'parent.billing' })"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('wali.sekolah.paymentSuccess.backToBills') }}
      </button>
    </div>

    <AsyncView
      :state="state"
      :empty-title="t('wali.sekolah.paymentSuccess.emptyTitle')"
      :empty-description="t('wali.sekolah.paymentSuccess.emptyDescription')"
      empty-icon="wallet"
      :error-title="t('wali.sekolah.paymentSuccess.errorTitle')"
      @retry="load"
    >
      <template #default>
        <!-- Status hero -->
        <section
          class="rounded-3xl p-6 text-white text-center shadow-xl shadow-role-wali/10"
          :style="{ background: heroGradient }"
        >
          <div class="w-14 h-14 mx-auto rounded-full bg-white/20 grid place-items-center mb-2">
            <NavIcon :name="heroIcon" :size="28" />
          </div>
          <p class="text-[10px] font-bold tracking-widest uppercase text-white/70">
            {{ t('wali.sekolah.paymentSuccess.heroLabel') }}
          </p>
          <p class="text-3xl font-black tracking-tight mt-1">
            {{ formatRupiah(payment!.amount) }}
          </p>
          <span
            class="inline-block text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full mt-2"
            :class="`${PAYMENT_STATUS_TONES[payment!.status].bg} ${PAYMENT_STATUS_TONES[payment!.status].text}`"
          >
            {{ PAYMENT_STATUS_LABELS[payment!.status] }}
          </span>
          <p v-if="bill" class="text-[13px] text-white/80 mt-3">
            {{ bill.title }}
          </p>
        </section>

        <!-- Bill detail -->
        <section v-if="bill" class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
            {{ t('wali.sekolah.paymentSuccess.billSection') }}
          </p>
          <dl class="text-[13px] space-y-1.5">
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.billKind') }}</dt>
              <dd class="font-bold text-slate-900 text-right">
                {{ bill.payment_type?.name ?? bill.title }}
              </dd>
            </div>
            <div v-if="bill.student?.name" class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.billFor') }}</dt>
              <dd class="font-bold text-slate-900 text-right">{{ bill.student.name }}</dd>
            </div>
            <div v-if="bill.due_date" class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.billDueDate') }}</dt>
              <dd class="font-bold text-slate-900 text-right">{{ formatDateLong(bill.due_date) }}</dd>
            </div>
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.billAmount') }}</dt>
              <dd class="font-bold text-slate-900 text-right">{{ formatRupiah(bill.amount) }}</dd>
            </div>
          </dl>
        </section>

        <!-- Payment detail -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
            {{ t('wali.sekolah.paymentSuccess.paymentSection') }}
          </p>
          <dl class="text-[13px] space-y-1.5">
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.paymentMethod') }}</dt>
              <dd class="font-bold text-slate-900 text-right">{{ payment!.payment_method ?? '—' }}</dd>
            </div>
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.paymentDate') }}</dt>
              <dd class="font-bold text-slate-900 text-right">
                {{ payment!.payment_date ? formatDateLong(payment!.payment_date) : '—' }}
              </dd>
            </div>
            <div v-if="payment!.verified_at" class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.paymentVerifiedAt') }}</dt>
              <dd class="font-bold text-slate-900 text-right">{{ formatDateLong(payment!.verified_at) }}</dd>
            </div>
            <div v-if="payment!.verifier_name" class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.paymentVerifier') }}</dt>
              <dd class="font-bold text-slate-900 text-right">{{ payment!.verifier_name }}</dd>
            </div>
            <div v-if="payment!.admin_notes" class="flex justify-between gap-2">
              <dt class="text-slate-500">{{ t('wali.sekolah.paymentSuccess.paymentAdminNotes') }}</dt>
              <dd class="font-bold text-slate-900 text-right max-w-[60%]">{{ payment!.admin_notes }}</dd>
            </div>
          </dl>
        </section>

        <!-- Timeline -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-3">
            {{ t('wali.sekolah.paymentSuccess.timelineSection') }}
          </p>
          <ol class="space-y-3">
            <li
              v-for="(step, idx) in timelineSteps"
              :key="idx"
              class="flex items-start gap-3"
            >
              <div
                class="w-7 h-7 rounded-full grid place-items-center flex-shrink-0 mt-0.5"
                :class="step.done ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-400'"
              >
                <NavIcon :name="step.done ? 'check' : 'clock'" :size="13" />
              </div>
              <div class="flex-1 min-w-0">
                <p
                  class="text-[14px] font-bold"
                  :class="step.done ? 'text-slate-900' : 'text-slate-400'"
                >{{ step.label }}</p>
                <p v-if="step.meta" class="text-[12px] text-slate-500 mt-0.5">
                  {{ step.meta }}
                </p>
              </div>
            </li>
          </ol>
        </section>

        <!-- Bukti thumbnail -->
        <section
          v-if="buktiBlobUrl"
          class="bg-white border border-slate-200 rounded-2xl p-4"
        >
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-3">
            {{ t('wali.sekolah.paymentSuccess.proofSection') }}
          </p>
          <a
            v-if="buktiIsImage"
            :href="buktiBlobUrl"
            target="_blank"
            rel="noopener"
            class="block rounded-xl overflow-hidden border border-slate-200 bg-slate-50"
          >
            <img :src="buktiBlobUrl" :alt="t('wali.sekolah.paymentSuccess.proofAlt')" class="w-full max-h-80 object-contain" />
          </a>
          <a
            v-else
            :href="buktiBlobUrl"
            target="_blank"
            rel="noopener"
            class="inline-flex items-center gap-2 text-[13px] font-bold text-role-wali hover:underline"
          >
            <NavIcon name="file-text" :size="14" />
            {{ t('wali.sekolah.paymentSuccess.openProofPdf') }}
          </a>
        </section>

        <!-- Actions -->
        <section class="grid grid-cols-2 gap-2">
          <Button
            variant="secondary"
            block
            :loading="isSharing"
            @click="share"
          >
            <NavIcon name="share-2" :size="13" />
            {{ t('wali.sekolah.paymentSuccess.share') }}
          </Button>
          <Button
            variant="primary"
            block
            :loading="isDownloading"
            @click="download"
          >
            <NavIcon name="download" :size="13" />
            {{ t('wali.sekolah.paymentSuccess.download') }}
          </Button>
        </section>
      </template>
    </AsyncView>

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
