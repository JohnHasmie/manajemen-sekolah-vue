<!--
  LessonPlanAdminApproveSheet.vue — admin "Setujui RPP" confirmation.

  Mirrors Flutter's `lesson_plan_admin_approve_sheet.dart`. Single-shot
  confirmation: shows the RPP identity, optional approval note, single
  green primary button. Bulk mode is the same sheet with `count > 1`
  in the subtitle and an array of ids — parent calls `bulkApprove`
  on the service.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { LessonPlanService } from '@/services/lesson-plans.service';
import type { LessonPlan } from '@/types/lesson-plans';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Single-shot: pass one plan. Bulk: pass null + use `bulkIds`. */
  plan?: LessonPlan | null;
  /** Bulk mode: array of ids to approve in one shot. */
  bulkIds?: string[];
}>();

const emit = defineEmits<{
  close: [];
  approved: [];
}>();

const note = ref<string>('');
const isSaving = ref(false);
const error = ref<string | null>(null);

async function confirm() {
  error.value = null;
  isSaving.value = true;
  try {
    if (props.plan) {
      await LessonPlanService.approve(props.plan.id, note.value.trim() || undefined);
    } else if (props.bulkIds && props.bulkIds.length > 0) {
      await LessonPlanService.approveBulk(props.bulkIds);
    } else {
      throw new Error('Tidak ada RPP untuk disetujui.');
    }
    emit('approved');
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
    :title="plan ? 'Setujui RPP' : `Setujui ${bulkCount} RPP`"
    :subtitle="
      plan
        ? `Tindakan ini akan mengubah status RPP ke ${'Disetujui'}.`
        : 'Semua RPP terpilih akan diubah ke status Disetujui sekaligus.'
    "
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Identity card -->
      <div
        v-if="plan"
        class="bg-emerald-50 border border-emerald-200 rounded-xl px-3 py-3 flex items-center gap-3"
      >
        <span class="w-10 h-10 rounded-xl bg-emerald-600 text-white grid place-items-center flex-shrink-0">
          <NavIcon name="check-circle" :size="18" />
        </span>
        <div class="flex-1 min-w-0">
          <p class="text-[12.5px] font-bold text-slate-900 truncate">
            {{ plan.title || 'Tanpa judul' }}
          </p>
          <p class="text-[11px] text-slate-600 truncate">
            {{ plan.subject_name }} · {{ plan.class_name }} · {{ plan.teacher_name }}
          </p>
        </div>
      </div>

      <!-- Optional note -->
      <div v-if="plan">
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
          Catatan untuk guru (opsional)
        </label>
        <textarea
          v-model="note"
          rows="3"
          placeholder="Misal: Bagus, langsung bisa dipakai."
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/15 focus:outline-none bg-white resize-none"
          :disabled="isSaving"
        />
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
        <Button variant="success" block :loading="isSaving" @click="confirm">
          <NavIcon name="check" :size="14" />
          {{ plan ? 'Setujui' : `Setujui ${bulkCount}` }}
        </Button>
      </div>
    </div>
  </Modal>
</template>
