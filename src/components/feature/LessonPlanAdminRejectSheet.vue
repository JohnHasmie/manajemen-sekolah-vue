<!--
  LessonPlanAdminRejectSheet.vue — admin "Tolak RPP" sheet.

  Mirrors Flutter's `lesson_plan_admin_reject_sheet.dart`. Requires a
  textarea note explaining the rejection — the teacher reads it in the
  detail screen's red banner. Differs from "Send Back" in that
  Rejected is terminal-ish (teacher can edit + resubmit, but the
  history shows it as a hard rejection) while SentBack is a softer
  "please revise these areas" loop.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { LessonPlanService } from '@/services/lesson-plans.service';
import type { LessonPlan } from '@/types/lesson-plans';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  plan?: LessonPlan | null;
  /** Bulk mode: passes an id array. Single mode: use `plan`. */
  bulkIds?: string[];
}>();

const emit = defineEmits<{
  close: [];
  rejected: [];
}>();

const note = ref<string>('');
const isSaving = ref(false);
const error = ref<string | null>(null);

async function confirm() {
  error.value = null;
  if (!note.value.trim()) {
    error.value = 'Catatan alasan tolak wajib diisi.';
    return;
  }
  isSaving.value = true;
  try {
    if (props.plan) {
      await LessonPlanService.reject(props.plan.id, note.value.trim());
    } else if (props.bulkIds && props.bulkIds.length > 0) {
      await LessonPlanService.rejectBulk(props.bulkIds, note.value.trim());
    } else {
      throw new Error('Tidak ada RPP untuk ditolak.');
    }
    emit('rejected');
    emit('close');
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

const bulkCount = props.bulkIds?.length ?? 0;
</script>

<template>
  <Modal
    :title="plan ? 'Tolak RPP' : `Tolak ${bulkCount} RPP`"
    :subtitle="
      plan
        ? `Catatan akan dikirim ke ${plan.teacher_name || 'guru'}.`
        : 'Catatan ini akan dikirim ke semua guru terkait.'
    "
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Identity -->
      <div
        v-if="plan"
        class="bg-red-50 border border-red-200 rounded-xl px-3 py-3 flex items-center gap-3"
      >
        <span class="w-10 h-10 rounded-xl bg-red-600 text-white grid place-items-center flex-shrink-0">
          <NavIcon name="x-circle" :size="18" />
        </span>
        <div class="flex-1 min-w-0">
          <p class="text-[12.5px] font-bold text-slate-900 truncate">
            {{ plan.title || 'Tanpa judul' }}
          </p>
          <p class="text-2xs text-slate-600 truncate">
            {{ plan.subject_name }} · {{ plan.class_name }} · {{ plan.teacher_name }}
          </p>
        </div>
      </div>

      <!-- Reject note (required) -->
      <div>
        <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
          Alasan tolak <span class="text-red-600">*</span>
        </label>
        <textarea
          v-model="note"
          rows="4"
          placeholder="Jelaskan alasan tolak. Guru akan melihat catatan ini saat membuka RPP."
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-red-500 focus:ring-2 focus:ring-red-500/15 focus:outline-none bg-white resize-none"
          :disabled="isSaving"
        />
        <p class="text-3xs text-slate-400 mt-1">
          Tip: tulis poin yang spesifik supaya guru tahu cara memperbaiki.
        </p>
      </div>

      <!-- Error -->
      <div
        v-if="error"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-[12px] text-red-700"
      >
        {{ error }}
      </div>

      <!-- Footer -->
      <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" block :disabled="isSaving" @click="emit('close')">
          Batal
        </Button>
        <Button variant="danger" block :loading="isSaving" @click="confirm">
          <NavIcon name="x" :size="14" />
          {{ plan ? 'Tolak RPP' : `Tolak ${bulkCount}` }}
        </Button>
      </div>
    </div>
  </Modal>
</template>
