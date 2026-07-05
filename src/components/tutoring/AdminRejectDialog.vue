<!--
  AdminRejectDialog — admin rejects a PENDING honor request with a
  required `reject_reason`. The reason ships back to the tutor in the
  notification body, so the chips here are short canned strings; the
  free-form textarea is the source of truth.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutorPayoutRequest } from '@/types/tutoring';

import Modal from '@/components/ui/Modal.vue';

const props = defineProps<{
  request: TutorPayoutRequest;
}>();
const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done', updated: TutorPayoutRequest): void;
}>();

const { t } = useI18n();
const toast = useToast();

// i18n keys for the four canned reasons.
const QUICK_KEYS = [
  'admin.bimbel.payout_requests.reject_quick_amount_mismatch',
  'admin.bimbel.payout_requests.reject_quick_already_paid',
  'admin.bimbel.payout_requests.reject_quick_period_invalid',
  'admin.bimbel.payout_requests.reject_quick_bank_invalid',
] as const;

const reason = ref('');
const submitting = ref(false);
const errMsg = ref<string | null>(null);

function applyQuick(text: string) {
  // Append on top of any existing free-form input — the admin can
  // expand on it before submit.
  reason.value = reason.value.trim()
    ? `${reason.value.trim()} ${text}`
    : text;
}

async function submit() {
  errMsg.value = null;
  const trimmed = reason.value.trim();
  if (!trimmed) {
    errMsg.value = t('admin.bimbel.payout_requests.reject_reason_required');
    return;
  }
  submitting.value = true;
  try {
    const updated = await TutoringService.rejectPayoutRequest(props.request.id, {
      reject_reason: trimmed,
    });
    toast.success(t('admin.bimbel.payout_requests.reject_ok'));
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
    :title="t('admin.bimbel.payout_requests.reject_title')"
    :subtitle="
      t('admin.bimbel.payout_requests.reject_subtitle', {
        amount: formatRupiah(request.amount_requested),
        tutor: request.tutor?.name ?? '—',
      })
    "
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Quick-pick chips -->
      <div>
        <p class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider mb-1.5">
          {{ t('admin.bimbel.payout_requests.reject_quick_label') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="key in QUICK_KEYS"
            :key="key"
            type="button"
            class="rounded-full bg-tutoring-red-dim text-tutoring-red text-[12px] font-bold px-3 py-1 hover:opacity-90"
            @click="applyQuick(t(key))"
          >
            {{ t(key) }}
          </button>
        </div>
      </div>

      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('admin.bimbel.payout_requests.reject_field_reason') }}
        </span>
        <textarea
          v-model="reason"
          rows="4"
          maxlength="2000"
          :placeholder="t('admin.bimbel.payout_requests.reject_reason_ph')"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-tutoring-red/20 focus:border-tutoring-red resize-none"
        />
        <p class="text-2xs text-tutoring-text-lo mt-1">
          {{ t('admin.bimbel.payout_requests.reject_reason_hint') }}
        </p>
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
          class="rounded-lg bg-tutoring-red hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submit"
        >
          {{ submitting
            ? t('admin.bimbel.payout_requests.reject_submitting')
            : t('admin.bimbel.payout_requests.reject_confirm') }}
        </button>
      </div>
    </div>
  </Modal>
</template>
