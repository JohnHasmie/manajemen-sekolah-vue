<!--
  ClassroomEditSheet.vue — port of `classroom_form_dialog.dart`.
  Uses the shared FormSheet + FormField primitives; behaviour, fields,
  validation messages and submit payload are unchanged.
-->
<script setup lang="ts">
import { computed, reactive } from 'vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import { generateGradeLevels } from '@/services/classrooms.service';
import type { Classroom, Teacher } from '@/types/entities';

const props = defineProps<{
  classroom?: Classroom | null;
  teachers: Teacher[];
  isSaving?: boolean;
  /**
   * School jenjang (`schools.education_level`, e.g. SD/SMP/SMA/SMK).
   * Constrains the tingkat dropdown: SD→1-6, SMP→7-9, SMA/SMK→10-12.
   * Falls back to 1-12 when unknown.
   */
  educationLevel?: string | null;
}>();

/** Tingkat options matched to the active school's jenjang. */
const gradeOptions = computed<FormFieldOption[]>(() =>
  generateGradeLevels(props.educationLevel).map((g) => ({
    value: g,
    label: `Kelas ${g}`,
  })),
);

/** Wali kelas dropdown options (optional field). */
const teacherOptions = computed<FormFieldOption[]>(() =>
  props.teachers.map((t) => ({ value: t.id, label: t.name })),
);

const emit = defineEmits<{
  close: [];
  save: [payload: Record<string, unknown>];
}>();

const form = reactive({
  name: props.classroom?.name ?? '',
  grade_level: props.classroom?.grade_level ?? '',
  homeroom_teacher_id: props.classroom?.homeroom_teacher_id ?? '',
});

const isEdit = computed(() => Boolean(props.classroom?.id));
const errors = reactive<Record<string, string>>({});

function validate(): boolean {
  Object.keys(errors).forEach((k) => delete errors[k]);
  if (!form.name.trim()) errors.name = 'Nama kelas wajib diisi.';
  if (!form.grade_level) errors.grade_level = 'Tingkat wajib dipilih.';
  return Object.keys(errors).length === 0;
}

function submit() {
  if (!validate()) return;
  emit('save', {
    name: form.name.trim(),
    grade_level: form.grade_level,
    homeroom_teacher_id: form.homeroom_teacher_id || null,
  });
}
</script>

<template>
  <FormSheet
    :title="isEdit ? 'Ubah Kelas' : 'Tambah Kelas'"
    :subtitle="isEdit ? 'Perbarui data kelas.' : 'Buat kelas baru di sekolah ini.'"
    :saving="isSaving"
    :save-label="isEdit ? 'Simpan perubahan' : 'Tambah kelas'"
    @save="submit"
    @cancel="emit('close')"
  >
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
      <FormField
        v-model="form.name"
        label="Nama kelas"
        placeholder="Contoh: 7A"
        :disabled="isSaving"
        :error="errors.name"
      />
      <FormField
        v-model="form.grade_level"
        type="select"
        label="Tingkat"
        select-placeholder="— Pilih tingkat —"
        :options="gradeOptions"
        :disabled="isSaving"
        :error="errors.grade_level"
      />
    </div>

    <FormField
      v-model="form.homeroom_teacher_id"
      type="select"
      select-placeholder="— Belum ada wali kelas —"
      :options="teacherOptions"
      :disabled="isSaving"
    >
      <template #label>
        Wali Kelas <span class="text-slate-400 font-normal">(opsional)</span>
      </template>
    </FormField>
  </FormSheet>
</template>
