<!--
  RejectSubscriptionModal.vue — Frame 3 of the super-admin
  subscription approvals mockup.

  Confirms a rejection with a mandatory written reason (3..500 chars)
  that the backend inlines into both the customer's email + WhatsApp,
  so the copy asks the user to write something the *customer* will
  read rather than an internal admin note.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import type { PendingApproval } from '@/types/subscription-approval';

const props = defineProps<{
  open: boolean;
  approval: PendingApproval | null;
  submitting: boolean;
}>();

const emit = defineEmits<{
  close: [];
  confirm: [reason: string];
}>();

const REASON_MIN = 3;
const REASON_MAX = 500;

const reason = ref('');
const touched = ref(false);

// Reset reason each time the modal re-opens so the previous rejection
// doesn't leak into a different row's flow.
watch(
  () => props.open,
  (v) => {
    if (v) {
      reason.value = '';
      touched.value = false;
    }
  },
);

const trimmed = computed(() => reason.value.trim());
const length = computed(() => trimmed.value.length);
const isValid = computed(
  () => length.value >= REASON_MIN && length.value <= REASON_MAX,
);
const remaining = computed(() => REASON_MAX - length.value);

function onConfirm() {
  touched.value = true;
  if (!isValid.value || props.submitting) return;
  emit('confirm', trimmed.value);
}
</script>

<template>
  <Modal
    v-if="open"
    title="Tolak pembayaran ini?"
    :subtitle="approval
        ? `Alasan dikirim ke ${approval.admin_email ?? 'admin tenant'} lewat email dan WhatsApp. Pelanggan bisa buat pesanan baru dengan kode referensi baru.`
        : 'Alasan dikirim lewat email dan WhatsApp ke admin tenant.'"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <div>
        <label
          for="reject-reason"
          class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1.5"
        >
          Alasan penolakan · dibaca pelanggan
        </label>
        <textarea
          id="reject-reason"
          v-model="reason"
          rows="4"
          maxlength="500"
          placeholder="Contoh: Nominal transfer masuk Rp 4.750.000, kurang Rp 2.000. Silakan transfer selisihnya atau buat pesanan baru."
          class="w-full rounded-lg border border-slate-300 px-3 py-2.5 text-[13px] leading-relaxed text-slate-900 focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none resize-y"
          :class="touched && !isValid ? 'border-rose-300 focus:border-rose-400 focus:ring-rose-200' : ''"
          @blur="touched = true"
        />
        <div class="mt-1.5 flex items-center justify-between text-[11px]">
          <p class="text-slate-400">
            Minimal {{ REASON_MIN }}, maksimal {{ REASON_MAX }} karakter.
          </p>
          <p
            class="tabular-nums"
            :class="length > REASON_MAX
                ? 'text-rose-600'
                : length < REASON_MIN
                    ? 'text-slate-400'
                    : 'text-slate-500'"
          >
            {{ length }} / {{ REASON_MAX }}
          </p>
        </div>
        <p
          v-if="touched && length > 0 && length < REASON_MIN"
          class="mt-1 text-[11px] text-rose-600"
        >
          Alasan terlalu singkat. Tulis minimal {{ REASON_MIN }} karakter supaya pelanggan tahu langkah selanjutnya.
        </p>
      </div>

      <div class="rounded-lg bg-slate-50 border border-slate-200 p-3 text-[12px] text-slate-600 leading-relaxed">
        Setelah dikonfirmasi, pesanan langsung <span class="font-semibold text-slate-800">dibatalkan</span> dan status di sisi pelanggan berubah jadi
        <span class="inline-flex items-center rounded bg-rose-100 text-rose-700 px-1.5 py-0.5 text-[10px] font-semibold ml-0.5">Ditolak</span>.
        Aksi ini bersifat final — kalau ternyata salah tolak, minta pelanggan buat pesanan baru.
      </div>

      <div class="mt-5 flex flex-col sm:flex-row-reverse gap-2">
        <Button
          variant="danger"
          :loading="submitting"
          :disabled="!isValid"
          @click="onConfirm"
        >
          Konfirmasi tolak
        </Button>
        <Button variant="ghost" :disabled="submitting" @click="emit('close')">
          Batal
        </Button>
      </div>
    </div>
  </Modal>
</template>
