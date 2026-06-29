<!--
  AdminMarkPaidDialog — admin marks an APPROVED honor request as PAID,
  optionally attaching a transfer-proof file (PNG/JPG/PDF, max 2MB).

  Multipart POST is shipped by TutoringService.markPayoutRequestPaid via
  FormData. We *preview* image uploads inline so the admin can sanity-
  check that the attached file is actually the transfer receipt, not a
  random screenshot. PDFs show a filename + size summary instead.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutorPayoutRequest } from '@/types/tutoring';

import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  request: TutorPayoutRequest;
}>();
const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done', updated: TutorPayoutRequest): void;
}>();

const { t } = useI18n();
const toast = useToast();

const MAX_BYTES = 2 * 1024 * 1024; // backend cap: 2MB.

const paidAt = ref<string>(todayIso());
const paymentNotes = ref('');
const proofFile = ref<File | null>(null);
const proofPreviewUrl = ref<string | null>(null);
const submitting = ref(false);
const errMsg = ref<string | null>(null);

function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function onFileChange(e: Event) {
  errMsg.value = null;
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) {
    proofFile.value = null;
    proofPreviewUrl.value = null;
    return;
  }
  if (file.size > MAX_BYTES) {
    errMsg.value = t('admin.bimbel.payout_requests.mark_paid_file_too_big');
    input.value = '';
    return;
  }
  proofFile.value = file;
  // Image preview — revoke the previous blob URL first to avoid leaks.
  if (proofPreviewUrl.value) URL.revokeObjectURL(proofPreviewUrl.value);
  if (file.type.startsWith('image/')) {
    proofPreviewUrl.value = URL.createObjectURL(file);
  } else {
    proofPreviewUrl.value = null;
  }
}

function clearFile() {
  proofFile.value = null;
  if (proofPreviewUrl.value) URL.revokeObjectURL(proofPreviewUrl.value);
  proofPreviewUrl.value = null;
}

const fileSizeLabel = computed(() => {
  if (!proofFile.value) return '';
  const kb = proofFile.value.size / 1024;
  return kb < 1024
    ? `${Math.round(kb)} KB`
    : `${(kb / 1024).toFixed(1)} MB`;
});

async function submit() {
  errMsg.value = null;
  submitting.value = true;
  try {
    const updated = await TutoringService.markPayoutRequestPaid(props.request.id, {
      paid_at: paidAt.value || null,
      payment_notes: paymentNotes.value.trim() || null,
      proof_file: proofFile.value,
    });
    toast.success(t('admin.bimbel.payout_requests.mark_paid_ok'));
    emit('done', updated);
  } catch (e) {
    errMsg.value = e instanceof Error ? e.message : String(e);
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <Modal
    :title="t('admin.bimbel.payout_requests.mark_paid_title')"
    :subtitle="
      t('admin.bimbel.payout_requests.mark_paid_subtitle', {
        amount: formatRupiah(request.amount_requested),
        tutor: request.tutor?.name ?? '—',
      })
    "
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('admin.bimbel.payout_requests.mark_paid_field_date') }}
        </span>
        <input
          v-model="paidAt"
          type="date"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
        />
      </label>

      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('admin.bimbel.payout_requests.mark_paid_field_proof') }}
        </span>
        <input
          type="file"
          accept="image/png,image/jpeg,application/pdf"
          class="mt-1.5 block w-full text-xs file:mr-3 file:rounded-md file:border-0 file:bg-tutoring-accent/10 file:text-tutoring-accent file:px-3 file:py-2 file:font-bold file:text-[12px] file:cursor-pointer"
          @change="onFileChange"
        />
        <p class="text-[11px] text-tutoring-text-lo mt-1">
          {{ t('admin.bimbel.payout_requests.mark_paid_proof_hint') }}
        </p>
      </label>

      <div
        v-if="proofFile"
        class="rounded-lg border border-tutoring-border bg-tutoring-bg p-3 flex items-start gap-3"
      >
        <img
          v-if="proofPreviewUrl"
          :src="proofPreviewUrl"
          :alt="t('admin.bimbel.payout_requests.mark_paid_proof_preview_alt')"
          class="h-20 w-20 object-cover rounded-md border border-tutoring-border-soft"
        />
        <div v-else class="h-20 w-20 rounded-md border border-tutoring-border-soft bg-tutoring-panel flex items-center justify-center text-tutoring-text-lo">
          <NavIcon name="book" :size="28" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-semibold text-tutoring-text-hi truncate">
            {{ proofFile.name }}
          </p>
          <p class="text-[11px] text-tutoring-text-mid mt-0.5">{{ fileSizeLabel }}</p>
          <button
            type="button"
            class="text-[12px] font-bold text-tutoring-red hover:underline mt-1"
            @click="clearFile"
          >
            {{ t('admin.bimbel.payout_requests.mark_paid_remove_file') }}
          </button>
        </div>
      </div>

      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('admin.bimbel.payout_requests.mark_paid_field_notes') }}
        </span>
        <textarea
          v-model="paymentNotes"
          rows="3"
          maxlength="1000"
          :placeholder="t('admin.bimbel.payout_requests.mark_paid_notes_ph')"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent resize-none"
        />
      </label>

      <p v-if="errMsg" class="text-xs text-tutoring-red">{{ errMsg }}</p>

      <div class="flex items-center gap-2 justify-end pt-1">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
          @click="emit('close')"
        >
          {{ t('tutoring.common.close') }}
        </button>
        <button
          type="button"
          :disabled="submitting"
          class="rounded-lg bg-tutoring-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submit"
        >
          {{ submitting
            ? t('admin.bimbel.payout_requests.mark_paid_submitting')
            : t('admin.bimbel.payout_requests.mark_paid_confirm') }}
        </button>
      </div>
    </div>
  </Modal>
</template>
