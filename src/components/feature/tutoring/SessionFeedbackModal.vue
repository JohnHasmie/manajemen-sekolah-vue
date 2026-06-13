<!--
  SessionFeedbackModal — parent rates a DONE session.
  PUT /tutoring/sessions/{id}/feedback { student_id, rating, comment? }

  Server gates: only fires when session.status=DONE. UI hides the
  trigger for non-DONE sessions, but the form re-validates server
  errors and surfaces them inline.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  sessionId: string;
  studentId: string;
  sessionTitle?: string;
}>();
const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done'): void;
}>();

const toast = useToast();
const rating = ref<number>(5);
const comment = ref('');
const saving = ref(false);
const errMsg = ref<string | null>(null);

async function submit() {
  saving.value = true;
  errMsg.value = null;
  try {
    await TutoringService.upsertSessionFeedback(props.sessionId, {
      student_id: props.studentId,
      rating: rating.value,
      comment: comment.value.trim() || undefined,
    });
    toast.success('Rating tersimpan. Terima kasih!');
    emit('done');
  } catch (e) {
    errMsg.value = e instanceof Error ? e.message : String(e);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <Modal title="Beri Rating Sesi" @close="emit('close')">
    <p v-if="sessionTitle" class="text-xs text-bimbel-text-mid mb-3">
      {{ sessionTitle }}
    </p>
    <div class="flex items-center justify-center gap-1 my-3">
      <button
        v-for="n in 5"
        :key="n"
        type="button"
        class="p-1.5 transition"
        :class="n <= rating ? 'text-amber-400' : 'text-bimbel-text-lo hover:text-amber-300'"
        @click="rating = n"
      >
        <NavIcon name="sparkles" :size="28" />
      </button>
    </div>
    <p class="text-center text-xs font-bold text-bimbel-text-mid uppercase tracking-widest mb-3">
      {{ rating }} dari 5
    </p>

    <label class="block">
      <span class="text-[12px] font-bold text-bimbel-text-mid uppercase tracking-wider">
        Komentar (opsional)
      </span>
      <textarea
        v-model="comment"
        rows="3"
        placeholder="Bagaimana sesi tadi?"
        class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-parent/20 focus:border-role-parent resize-none"
      />
    </label>

    <p v-if="errMsg" class="text-xs text-bimbel-red mt-2">{{ errMsg }}</p>

    <div class="flex items-center gap-2 justify-end mt-4">
      <button
        type="button"
        class="rounded-lg px-3 py-2 text-sm font-semibold text-bimbel-text-mid hover:bg-bimbel-border-soft"
        @click="emit('close')"
      >
        Batal
      </button>
      <button
        type="button"
        :disabled="saving"
        class="rounded-lg bg-role-parent hover:bg-role-parent/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        @click="submit"
      >
        {{ saving ? 'Menyimpan…' : 'Kirim Rating' }}
      </button>
    </div>
  </Modal>
</template>
