<!--
  ParentBillCheckoutView.vue — wali murid · Bayar tagihan.

  Mirrors Flutter's `parent_bill_checkout_screen.dart` (Mockup #6,
  Surface C). Opens a `POST /bill/{id}/checkout` session and renders
  it as a 3-tab UI:

    QRIS         — QR string preview (download/print outside the app)
    Virtual Acc  — VA number + bank + copy + countdown to expiry
    Manual       — bank account list + upload bukti transfer

  Manual tab posts to `POST /bill/{billId}/payment-proof` (multipart);
  on success the parent is redirected to the payment-success view.

  The web app NEVER auto-charges. QRIS/VA tabs are informational
  (deterministic stub VAs from the backend until a real Snap gateway
  is wired in); Manual is the only branch that produces a Payment row.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { BillingService } from '@/services/billing.service';
import type { Bill, CheckoutSession, ManualBankAccount } from '@/types/billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import { formatRupiah, localISODate } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const billId = computed(() => String(route.params.billId ?? ''));
const session = ref<CheckoutSession | null>(null);
const bill = ref<Bill | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);

const tab = ref<'qris' | 'va' | 'manual'>('va');

const TAB_OPTS = computed(() => [
  { key: 'qris', label: 'QRIS' },
  { key: 'va', label: t('wali.sekolah.billCheckout.tabVa') },
  { key: 'manual', label: t('wali.sekolah.billCheckout.tabManual') },
]);

// Countdown to expires_at — refreshed every second.
const now = ref(Date.now());
let timer: ReturnType<typeof setInterval> | null = null;

const expiresMs = computed(() => {
  if (!session.value?.expires_at) return null;
  const t = new Date(session.value.expires_at).getTime();
  return Number.isFinite(t) ? t : null;
});

const remaining = computed(() => {
  if (!expiresMs.value) return null;
  return Math.max(0, expiresMs.value - now.value);
});

const remainingLabel = computed(() => {
  if (remaining.value === null) return '';
  if (remaining.value === 0) return t('wali.sekolah.billCheckout.sessionExpired');
  const sec = Math.floor(remaining.value / 1000);
  const hours = Math.floor(sec / 3600);
  const minutes = Math.floor((sec % 3600) / 60);
  const seconds = sec % 60;
  if (hours > 0) return t('wali.sekolah.billCheckout.remainingHours', { hours, minutes: String(minutes).padStart(2, '0') });
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
});

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Manual upload state ─────────────────────────────────────────────
const file = ref<File | null>(null);
const fileInput = ref<HTMLInputElement | null>(null);
const paymentDate = ref<string>(localISODate());
const uploadAmount = ref<number | null>(null);
const isUploading = ref(false);

function onFileChange(e: Event) {
  const target = e.target as HTMLInputElement;
  const picked = target.files?.[0] ?? null;
  if (!picked) {
    file.value = null;
    return;
  }
  if (picked.size > 5 * 1024 * 1024) {
    toast.value = { message: t('wali.sekolah.billCheckout.fileTooLarge'), tone: 'error' };
    target.value = '';
    return;
  }
  file.value = picked;
}

async function submitProof() {
  if (!file.value || !session.value) return;
  isUploading.value = true;
  try {
    const payment = await BillingService.uploadProof(billId.value, {
      file: file.value,
      amount: uploadAmount.value ?? session.value.amount,
      payment_date: paymentDate.value,
      payment_method: 'bank_transfer',
    });
    toast.value = {
      message: t('wali.sekolah.billCheckout.proofSent'),
      tone: 'success',
    };
    setTimeout(() => {
      router.replace({
        name: 'parent.payment-success',
        params: { paymentId: payment.id },
        query: { billId: billId.value },
      });
    }, 800);
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isUploading.value = false;
  }
}

// ── Load ────────────────────────────────────────────────────────────
async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    // Get bill metadata in parallel from /bill/parent (no dedicated
    // GET /bill/{id} for parents). We need this so we can render the
    // bill title + amount even before the checkout call resolves.
    const [s, list] = await Promise.all([
      BillingService.openCheckout(billId.value),
      BillingService.listParent(),
    ]);
    session.value = s;
    bill.value = list.find((b) => b.id === billId.value) ?? null;
    uploadAmount.value = s.amount;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => {
  void load();
  timer = setInterval(() => {
    now.value = Date.now();
  }, 1000);
});

onBeforeUnmount(() => {
  if (timer) clearInterval(timer);
});

const state = computed<AsyncState<CheckoutSession>>(() => {
  if (isLoading.value && !session.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (!session.value) return { status: 'empty' };
  return { status: 'content', data: session.value };
});

function copy(value: string, label?: string) {
  const okLabel = label ?? t('wali.sekolah.billCheckout.copied');
  if (!navigator.clipboard) {
    toast.value = { message: t('wali.sekolah.billCheckout.clipboardUnavailable'), tone: 'error' };
    return;
  }
  navigator.clipboard.writeText(value).then(
    () => {
      toast.value = { message: okLabel, tone: 'success' };
    },
    () => {
      toast.value = { message: t('wali.sekolah.billCheckout.copyFailed'), tone: 'error' };
    },
  );
}

function formatBank(b: ManualBankAccount): string {
  return `${b.bank}${b.branch ? ` · ${b.branch}` : ''}`;
}

const totalToPay = computed(() => {
  if (!session.value) return 0;
  if (tab.value === 'qris') return session.value.amount + session.value.qris_admin_fee;
  if (tab.value === 'va') return session.value.amount + session.value.va_admin_fee;
  return session.value.amount + session.value.manual_admin_fee;
});

const adminFee = computed(() => {
  if (!session.value) return 0;
  if (tab.value === 'qris') return session.value.qris_admin_fee;
  if (tab.value === 'va') return session.value.va_admin_fee;
  return session.value.manual_admin_fee;
});
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Back -->
    <div class="flex items-center justify-between gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[13px] font-bold text-slate-600 hover:text-role-wali"
        @click="router.back()"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('wali.sekolah.billCheckout.backToBills') }}
      </button>
      <div
        v-if="remainingLabel"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider"
        :class="remaining === 0 ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'"
      >
        <NavIcon name="clock" :size="11" />
        {{ t('wali.sekolah.billCheckout.sessionLabel', { remaining: remainingLabel }) }}
      </div>
    </div>

    <AsyncView
      :state="state"
      :empty-title="t('wali.sekolah.billCheckout.emptyTitle')"
      :empty-description="t('wali.sekolah.billCheckout.emptyDescription')"
      empty-icon="wallet"
      :error-title="t('wali.sekolah.billCheckout.errorTitle')"
      @retry="load"
    >
      <template #default>
        <!-- Hero -->
        <section
          class="rounded-3xl p-6 text-white shadow-xl shadow-role-wali/20 relative overflow-hidden"
          style="background: linear-gradient(135deg, #0B5677 0%, #6B4FB0 100%);"
        >
          <div class="absolute -top-12 -right-12 w-44 h-44 bg-white/15 rounded-full blur-3xl"></div>
          <div class="relative z-10 space-y-2">
            <p class="text-[10px] font-bold tracking-widest uppercase text-white/70">
              {{ t('wali.sekolah.billCheckout.totalPaid') }}
            </p>
            <p class="text-3xl sm:text-4xl font-black tracking-tight">{{ formatRupiah(totalToPay) }}</p>
            <p class="text-[13px] text-white/80">
              {{ session!.bill_name ?? bill?.title ?? t('wali.sekolah.billCheckout.billFallback') }}
              <span v-if="session!.student_name">· {{ session!.student_name }}</span>
            </p>
            <p v-if="adminFee > 0" class="text-[10px] text-white/70 mt-1">
              {{ t('wali.sekolah.billCheckout.adminFee', { fee: formatRupiah(adminFee) }) }}
            </p>
          </div>
        </section>

        <!-- Tabs -->
        <div class="bg-white border border-slate-200 rounded-2xl p-3">
          <SegmentedControl v-model="tab" :options="TAB_OPTS" />
          <!-- QRIS label intentionally untranslated (brand name) -->
        </div>

        <!-- QRIS tab -->
        <section
          v-if="tab === 'qris'"
          class="bg-white border border-slate-200 rounded-2xl p-5 space-y-4 text-center"
        >
          <div class="w-44 h-44 mx-auto bg-slate-100 rounded-2xl grid place-items-center">
            <div class="text-[10px] text-slate-400 font-bold uppercase tracking-widest">
              QRIS · placeholder
            </div>
          </div>
          <p class="text-[13px] text-slate-500">
            {{ t('wali.sekolah.billCheckout.qrInstruction') }}
          </p>
          <div class="bg-slate-50 rounded-xl p-3">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {{ t('wali.sekolah.billCheckout.qrCode') }}
            </p>
            <p class="font-mono text-[13px] font-bold text-slate-900 break-all mt-1">
              {{ session!.qr_string }}
            </p>
            <button
              type="button"
              class="mt-2 text-[12px] font-bold text-role-wali hover:underline"
              @click="copy(session!.qr_string, t('wali.sekolah.billCheckout.qrCodeCopied'))"
            >
              {{ t('wali.sekolah.billCheckout.copyCode') }}
            </button>
          </div>
        </section>

        <!-- VA tab -->
        <section
          v-else-if="tab === 'va'"
          class="bg-white border border-slate-200 rounded-2xl p-5 space-y-3"
        >
          <div class="flex items-center justify-between">
            <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {{ t('wali.sekolah.billCheckout.bank') }}
            </span>
            <span class="text-[14px] font-bold text-slate-900">{{ session!.va_bank }}</span>
          </div>
          <div class="border-t border-slate-100 pt-3">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {{ t('wali.sekolah.billCheckout.vaNumber') }}
            </p>
            <div class="flex items-center gap-2 mt-1.5">
              <p class="text-lg font-mono font-bold text-slate-900 flex-1 tracking-wider">
                {{ session!.va_number }}
              </p>
              <button
                type="button"
                class="text-[12px] font-bold text-role-wali hover:underline px-2 py-1 rounded-lg hover:bg-role-wali/5"
                @click="copy(session!.va_number.replace(/\s/g, ''), t('wali.sekolah.billCheckout.vaCopied'))"
              >
                {{ t('wali.sekolah.billCheckout.copy') }}
              </button>
            </div>
          </div>
          <div class="bg-amber-50 border border-amber-200 rounded-xl p-3 text-[12px] text-amber-700">
            {{ t('wali.sekolah.billCheckout.vaInstruction') }}
          </div>
        </section>

        <!-- Manual tab -->
        <section v-else class="space-y-3">
          <div class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {{ t('wali.sekolah.billCheckout.schoolAccount') }}
            </p>
            <div v-if="session!.manual_bank_list.length === 0" class="text-[13px] text-slate-500">
              {{ t('wali.sekolah.billCheckout.noBankAccount') }}
            </div>
            <div
              v-for="b in session!.manual_bank_list"
              :key="`${b.bank}-${b.account_number}`"
              class="bg-slate-50 rounded-xl p-3 space-y-1"
            >
              <p class="text-[12px] font-bold text-slate-500">{{ formatBank(b) }}</p>
              <div class="flex items-center gap-2">
                <p class="font-mono text-[14px] font-bold text-slate-900 flex-1">
                  {{ b.account_number }}
                </p>
                <button
                  type="button"
                  class="text-[12px] font-bold text-role-wali hover:underline"
                  @click="copy(b.account_number, t('wali.sekolah.billCheckout.accountCopied'))"
                >
                  {{ t('wali.sekolah.billCheckout.copy') }}
                </button>
              </div>
              <p class="text-[12px] text-slate-500">{{ t('wali.sekolah.billCheckout.accountHolder', { name: b.account_name }) }}</p>
            </div>
          </div>

          <!-- Upload bukti -->
          <div class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              {{ t('wali.sekolah.billCheckout.proofSection') }}
            </p>

            <label
              class="block border-2 border-dashed border-slate-300 hover:border-role-wali rounded-xl p-4 cursor-pointer transition-colors"
              :class="file ? 'bg-role-wali/5 border-role-wali' : 'bg-slate-50'"
            >
              <input
                ref="fileInput"
                type="file"
                accept="image/jpeg,image/png,image/webp,image/heic,application/pdf"
                class="sr-only"
                @change="onFileChange"
              />
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl grid place-items-center"
                  :class="file ? 'bg-role-wali/15 text-role-wali' : 'bg-slate-200 text-slate-500'"
                >
                  <NavIcon name="upload" :size="18" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-[14px] font-bold text-slate-900 truncate">
                    {{ file ? file.name : t('wali.sekolah.billCheckout.pickFile') }}
                  </p>
                  <p class="text-[12px] text-slate-500 mt-0.5">
                    {{ t('wali.sekolah.billCheckout.fileHint') }}
                  </p>
                </div>
              </div>
            </label>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                  {{ t('wali.sekolah.billCheckout.transferDate') }}
                </label>
                <input
                  v-model="paymentDate"
                  type="date"
                  class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[14px] font-bold text-slate-900 outline-none focus:border-role-wali"
                />
              </div>
              <div>
                <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                  {{ t('wali.sekolah.billCheckout.transferAmount') }}
                </label>
                <input
                  v-model.number="uploadAmount"
                  type="number"
                  class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[14px] font-bold text-slate-900 outline-none focus:border-role-wali"
                />
              </div>
            </div>

            <Button
              variant="primary"
              block
              :loading="isUploading"
              :disabled="!file || isUploading"
              @click="submitProof"
            >
              <NavIcon name="check-circle" :size="13" />
              {{ t('wali.sekolah.billCheckout.submitProof') }}
            </Button>
          </div>
        </section>
      </template>
    </AsyncView>

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
