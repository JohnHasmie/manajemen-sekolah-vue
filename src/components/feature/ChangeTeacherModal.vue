<!--
  ChangeTeacherModal.vue — admin "Ganti Teacher" sheet.

  Reassigns one schedule's teacher_id (PUT /teaching-schedule/{id}).
  Used by the per-row detail sheet's "Ganti Teacher" action. Bulk variant
  is in BulkTeacherPickerModal (Phase 5) which talks to /bulk/change-teacher.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { ScheduleService } from '@/services/schedule.service';
import type { ScheduleFilterOptions, ScheduleRow } from '@/types/schedule';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';

const props = defineProps<{
  row: ScheduleRow;
  filterOptions?: ScheduleFilterOptions | null;
}>();

const emit = defineEmits<{
  close: [];
  done: [ScheduleRow];
}>();

const teacherId = ref<string>(props.row.teacher_id ?? '');
const isSaving = ref(false);
const err = ref<string | null>(null);

const teachers = computed(() => props.filterOptions?.teachers ?? []);
const hasChanged = computed(() => teacherId.value !== props.row.teacher_id);

async function save() {
  if (!teacherId.value || !hasChanged.value) return;
  isSaving.value = true;
  err.value = null;
  try {
    const updated = await ScheduleService.update(props.row.id, {
      teacher_id: teacherId.value,
      subject_id: props.row.subject_id,
      class_id: props.row.class_id,
      lesson_hour_days_id: props.row.lesson_hour_days_id,
      semester_id: props.row.semester_id ?? undefined,
      academic_year_id: props.row.academic_year_id ?? undefined,
    });
    emit('done', updated);
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <Modal
    title="Ganti Guru"
    :subtitle="`${row.subject_name} · ${row.class_name}`"
    size="sm"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <p class="text-[12px] text-slate-600">
        Guru sekarang: <strong>{{ row.teacher_name ?? '—' }}</strong>
      </p>
      <div>
        <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Guru baru</label>
        <select
          v-model="teacherId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— pilih guru —</option>
          <option v-for="t in teachers" :key="t.id" :value="t.id">{{ t.name }}</option>
        </select>
      </div>

      <p v-if="err" class="text-[11px] text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!hasChanged || isSaving"
          @click="save"
        >
          Ganti
        </Button>
      </div>
    </div>
  </Modal>
</template>
