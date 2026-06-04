<!--
  ClassroomEditSheet.vue — port of `classroom_form_dialog.dart`.
-->
<script setup lang="ts">
import { computed, reactive } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
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
const gradeOptions = computed(() => generateGradeLevels(props.educationLevel));

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
  <Modal
    :title="isEdit ? 'Ubah Kelas' : 'Tambah Kelas'"
    :subtitle="isEdit ? 'Perbarui data kelas.' : 'Buat kelas baru di sekolah ini.'"
    @close="emit('close')"
  >
    <form class="space-y-md" @submit.prevent="submit">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Nama kelas</label>
          <input
            v-model="form.name"
            type="text"
            placeholder="Contoh: 7A"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
          <p v-if="errors.name" class="text-xs text-status-danger mt-1">{{ errors.name }}</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Tingkat</label>
          <select
            v-model="form.grade_level"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
            :disabled="isSaving"
          >
            <option value="">— Pilih tingkat —</option>
            <option v-for="g in gradeOptions" :key="g" :value="g">
              Kelas {{ g }}
            </option>
          </select>
          <p v-if="errors.grade_level" class="text-xs text-status-danger mt-1">
            {{ errors.grade_level }}
          </p>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">
          Wali Kelas <span class="text-slate-400 font-normal">(opsional)</span>
        </label>
        <select
          v-model="form.homeroom_teacher_id"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
          :disabled="isSaving"
        >
          <option value="">— Belum ada wali kelas —</option>
          <option v-for="t in teachers" :key="t.id" :value="t.id">{{ t.name }}</option>
        </select>
      </div>

      <BottomSheetFooter
        :primary-label="isEdit ? 'Simpan perubahan' : 'Tambah kelas'"
        :primary-loading="isSaving"
        @primary="submit"
        @secondary="emit('close')"
      />
    </form>
  </Modal>
</template>
