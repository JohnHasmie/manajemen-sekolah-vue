<!--
  PaymentProofModal.vue — admin verifikasi bukti pembayaran sheet.

  Loads the bukti via `GET /payment/{id}/receipt` (streaming blob,
  needs Sanctum bearer + X-School-ID — NOT a public URL). Admin can:
    - Approve  → PUT /payment/{id}/verify { status: 'verified' }
    - Reject   → PUT /payment/{id}/verify { status: 'rejected', admin_notes }

  Optimistic: on success the modal emits `done` with the new payment
  status; the parent refreshes its list.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { FinanceService } from '@/services/finance.service';
import {
  PAYMENT_STATUS_LABELS,
  PAYMENT_STATUS_TONES,
  type Payment,
} from '@/types/billing';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatRupiah, formatDateLong } from '@/lib/format';

const props = defineProps<{
  payment: Payment;
}>();

const emit = defineEmits<{
  close: [];
  done: [Payment];
}>();

const buktiBlobUrl = ref<string | null>(null);
const buktiIsImage = ref(false);
const buktiError = ref<string | null>(null);
// Distinct from buktiError: a 404 means no proof file was uploaded for this
// payment (e.g. cash or seeded payments) — a neutral empty state, not a
// red error.
const buktiMissing = ref(false);
const adminNotes = ref('');

const isApproving = ref(false);
const isRejecting = ref(false);
const showRejectForm = ref(false);
const err = ref<string | null>(null);

async function loadBukti() {
  buktiError.value = null;
  buktiMissing.value = false;
  try {
    const blob = await FinanceService.fetchReceiptBlob(props.payment.id);
    buktiIsImage.value = blob.type.startsWith('image/');
    buktiBlobUrl.value = URL.createObjectURL(blob);
  } catch (e) {
    // 404 = no proof uploaded → neutral empty state; anything else → a
    // friendly error (never the raw "Request failed with status code …").
    const status = (e as { response?: { status?: number } })?.response?.status;
    if (status === 404) {
      buktiMissing.value = true;
    } else {
      buktiError.value = 'Gagal memuat bukti pembayaran. Coba lagi nanti.';
    }
  }
}

onMounted(loadBukti);

onBeforeUnmount(() => {
  if (buktiBlobUrl.value) URL.revokeObjectURL(buktiBlobUrl.value);
});

async function approve() {
  isApproving.value = true;
  err.value = null;
  try {
    const updated = await FinanceService.verifyPayment(props.payment.id, {
      status: 'verified',
    });
    emit('done', updated);
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isApproving.value = false;
  }
}

async function reject() {
  if (!adminNotes.value.trim()) {
    err.value = 'Tambahkan alasan penolakan.';
    return;
  }
  isRejecting.value = true;
  err.value = null;
  try {
    const updated = await FinanceService.verifyPayment(props.payment.id, {
      status: 'rejected',
      admin_notes: adminNotes.value.trim(),
    });
    emit('done', updated);
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isRejecting.value = false;
  }
}

const tones = computed(() => PAYMENT_STATUS_TONES[props.payment.status]);
const statusLabel = computed(() => PAYMENT_STATUS_LABELS[props.payment.status]);

const studentName = computed(() => props.payment.bill?.student?.name ?? '—');
const billTitle = computed(() => props.payment.bill?.title ?? 'Tagihan');
const isPending = computed(() => props.payment.status === 'pending');
</script>

<template>
  <Modal
    title="Verifikasi Pembayaran"
    :subtitle="`${studentName} · ${billTitle}`"
    size="lg"
    @close="emit('close')"
  >
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <!-- Bukti preview -->
      <div class="space-y-2">
        <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Bukti transfer
        </p>
        <div class="bg-slate-50 border border-slate-200 rounded-xl overflow-hidden min-h-48 grid place-items-center">
          <p v-if="buktiMissing" class="text-[12px] text-slate-400 p-4 text-center">
            Bukti pembayaran belum diunggah.
          </p>
          <p v-else-if="buktiError" class="text-[12px] text-red-600 p-4 text-center">
            {{ buktiError }}
          </p>
          <p v-else-if="!buktiBlobUrl" class="text-[12px] text-slate-400 p-4">
            Memuat bukti...
          </p>
          <a
            v-else-if="buktiIsImage"
            :href="buktiBlobUrl"
            target="_blank"
            rel="noopener"
            class="block w-full"
          >
            <img :src="buktiBlobUrl" alt="Bukti" class="w-full max-h-72 object-contain" />
          </a>
          <a
            v-else
            :href="buktiBlobUrl"
            target="_blank"
            rel="noopener"
            class="inline-flex items-center gap-2 text-[12px] font-bold text-role-admin hover:underline p-4"
          >
            <NavIcon name="file-text" :size="14" />
            Buka bukti (PDF)
          </a>
        </div>
      </div>

      <!-- Detail + actions -->
      <div class="space-y-3">
        <div class="bg-slate-50 rounded-xl p-3 space-y-1.5">
          <dl class="text-[12px] space-y-1.5">
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">Status sekarang</dt>
              <dd>
                <span
                  class="inline-block text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full"
                  :class="`${tones.bg} ${tones.text}`"
                >{{ statusLabel }}</span>
              </dd>
            </div>
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">Nominal bayar</dt>
              <dd class="font-bold text-slate-900">{{ formatRupiah(payment.amount) }}</dd>
            </div>
            <div v-if="payment.bill" class="flex justify-between gap-2">
              <dt class="text-slate-500">Nominal tagihan</dt>
              <dd class="font-bold text-slate-900">{{ formatRupiah(payment.bill.amount) }}</dd>
            </div>
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">Metode</dt>
              <dd class="font-bold text-slate-900">{{ payment.payment_method ?? '—' }}</dd>
            </div>
            <div class="flex justify-between gap-2">
              <dt class="text-slate-500">Tanggal transfer</dt>
              <dd class="font-bold text-slate-900">
                {{ payment.payment_date ? formatDateLong(payment.payment_date) : '—' }}
              </dd>
            </div>
            <div v-if="payment.verified_at" class="flex justify-between gap-2">
              <dt class="text-slate-500">Diverifikasi</dt>
              <dd class="font-bold text-slate-900">{{ formatDateLong(payment.verified_at) }}</dd>
            </div>
            <div v-if="payment.verifier_name" class="flex justify-between gap-2">
              <dt class="text-slate-500">Oleh</dt>
              <dd class="font-bold text-slate-900">{{ payment.verifier_name }}</dd>
            </div>
            <div v-if="payment.admin_notes" class="flex justify-between gap-2">
              <dt class="text-slate-500">Catatan</dt>
              <dd class="font-bold text-slate-900 text-right max-w-[60%]">
                {{ payment.admin_notes }}
              </dd>
            </div>
          </dl>
        </div>

        <!-- Reject form -->
        <div v-if="showRejectForm" class="space-y-2">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Alasan penolakan
          </p>
          <textarea
            v-model="adminNotes"
            rows="3"
            placeholder="Jelaskan ke wali murid kenapa bukti ditolak..."
            class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] text-slate-900 outline-none focus:border-red-500"
          ></textarea>
        </div>

        <p
          v-if="err"
          class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3"
        >
          {{ err }}
        </p>

        <!-- Actions -->
        <div v-if="isPending" class="grid grid-cols-2 gap-2">
          <Button
            v-if="!showRejectForm"
            variant="danger"
            block
            @click="showRejectForm = true"
          >
            <NavIcon name="x-circle" :size="13" />
            Tolak
          </Button>
          <Button
            v-else
            variant="danger"
            block
            :loading="isRejecting"
            @click="reject"
          >
            Konfirmasi tolak
          </Button>
          <Button
            variant="success"
            block
            :loading="isApproving"
            :disabled="isApproving || isRejecting"
            @click="approve"
          >
            <NavIcon name="check-circle" :size="13" />
            Approve
          </Button>
        </div>
        <Button
          v-else
          variant="secondary"
          block
          @click="emit('close')"
        >
          Tutup
        </Button>
      </div>
    </div>
  </Modal>
</template>
