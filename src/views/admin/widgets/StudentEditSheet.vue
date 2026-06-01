<!--
  StudentEditSheet.vue — port of `student_add_edit_dialog.dart`.
  Modal for adding or editing a student. Owns its own form state, calls
  the parent's `save` event with the raw API payload.
-->
<script setup lang="ts">
import { reactive, computed } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import type { Student, Classroom } from '@/types/entities';

const props = defineProps<{
  student?: Student | null;
  classes: Classroom[];
  primaryColor: string;
  isSaving?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  save: [payload: Record<string, unknown>];
}>();

const form = reactive({
  name: props.student?.name ?? '',
  student_number: props.student?.student_number ?? '',
  class_id: props.student?.class_id ?? '',
  gender: props.student?.gender ?? '',
  date_of_birth: props.student?.date_of_birth ?? '',
  address: props.student?.address ?? '',
  guardian_name: props.student?.guardian_name ?? '',
  guardian_email: props.student?.guardian_email ?? '',
  phone_number: props.student?.phone_number ?? '',
});

const isEdit = computed(() => Boolean(props.student?.id));
const title = computed(() => (isEdit.value ? 'Ubah Siswa' : 'Tambah Siswa'));
const subtitle = computed(() =>
  isEdit.value
    ? 'Perbarui data siswa di bawah ini.'
    : 'Lengkapi data siswa baru.',
);

const errors = reactive<Record<string, string>>({});

function validate(): boolean {
  Object.keys(errors).forEach((k) => delete errors[k]);
  if (!form.name.trim()) errors.name = 'Nama wajib diisi.';
  if (!form.student_number.trim())
    errors.student_number = 'NIS wajib diisi.';
  if (!form.class_id) errors.class_id = 'Kelas wajib dipilih.';
  if (!form.guardian_name.trim())
    errors.guardian_name = 'Nama wali wajib diisi.';
  return Object.keys(errors).length === 0;
}

function submit() {
  if (!validate()) return;
  emit('save', {
    name: form.name.trim(),
    student_number: form.student_number.trim(),
    class_id: form.class_id,
    gender: form.gender || null,
    date_of_birth: form.date_of_birth || null,
    address: form.address.trim(),
    guardian_name: form.guardian_name.trim(),
    guardian_email: form.guardian_email.trim() || null,
    phone_number: form.phone_number.trim(),
  });
}
</script>

<template>
  <Modal :title="title" :subtitle="subtitle" @close="emit('close')">
    <form class="space-y-md" @submit.prevent="submit">
      <!-- Nama -->
      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">Nama lengkap</label>
        <input
          v-model="form.name"
          type="text"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
          :disabled="isSaving"
        />
        <p v-if="errors.name" class="text-xs text-status-danger mt-1">{{ errors.name }}</p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">NIS / NISN</label>
          <input
            v-model="form.student_number"
            type="text"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
          <p v-if="errors.student_number" class="text-xs text-status-danger mt-1">
            {{ errors.student_number }}
          </p>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Kelas</label>
          <select
            v-model="form.class_id"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
            :disabled="isSaving"
          >
            <option value="">— Pilih kelas —</option>
            <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
          <p v-if="errors.class_id" class="text-xs text-status-danger mt-1">
            {{ errors.class_id }}
          </p>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Jenis kelamin</label>
          <select
            v-model="form.gender"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
            :disabled="isSaving"
          >
            <option value="">— Pilih —</option>
            <option value="L">Laki-laki</option>
            <option value="P">Perempuan</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Tanggal lahir</label>
          <input
            v-model="form.date_of_birth"
            type="date"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">Alamat</label>
        <textarea
          v-model="form.address"
          rows="2"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none resize-none"
          :disabled="isSaving"
        ></textarea>
      </div>

      <div class="border-t border-slate-100 pt-md space-y-md">
        <p class="text-xs uppercase tracking-wider text-slate-400 font-semibold">
          Data wali
        </p>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Nama wali</label>
          <input
            v-model="form.guardian_name"
            type="text"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
          <p v-if="errors.guardian_name" class="text-xs text-status-danger mt-1">
            {{ errors.guardian_name }}
          </p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">Email wali</label>
            <input
              v-model="form.guardian_email"
              type="email"
              class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
              :disabled="isSaving"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">No. HP</label>
            <input
              v-model="form.phone_number"
              type="tel"
              class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
              :disabled="isSaving"
            />
          </div>
        </div>
      </div>

      <BottomSheetFooter
        :primary-label="isEdit ? 'Simpan perubahan' : 'Tambah siswa'"
        :primary-loading="isSaving"
        @primary="submit"
        @secondary="emit('close')"
      />
    </form>
  </Modal>
</template>
