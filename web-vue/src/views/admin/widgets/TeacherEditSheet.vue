<!--
  TeacherEditSheet.vue — port of `teacher_add_edit_dialog.dart`.

  Includes "Ganti akun terkait" toggle (only in edit mode) — when ON,
  submit payload carries `use_another_user: true` which tells the
  backend `UpdateTeacherAction::swapUserAccount()` to migrate this
  teacher row to a different user (matching by email). Required when
  the typed email already belongs to another user — without the toggle
  the backend rejects the save outright. Mirrors Flutter's
  `isChangeUserMode` flag in `teacher_form_init_mixin.dart`.
-->
<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import type { Teacher, Classroom, Subject } from '@/types/entities';

const props = defineProps<{
  teacher?: Teacher | null;
  classes: Classroom[];
  subjects: Subject[];
  isSaving?: boolean;
  /**
   * When the parent catches an 'email_conflict' error from the
   * backend, it flips this to `true` so the toggle pops open with
   * a yellow callout, telling the admin to enable migration mode
   * and click Save again.
   */
  emailConflictHint?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  save: [payload: Record<string, unknown>];
}>();

const form = reactive({
  name: props.teacher?.name ?? '',
  email: props.teacher?.email ?? '',
  role: props.teacher?.role ?? 'guru',
  employee_number: props.teacher?.employee_number ?? '',
  phone_number: props.teacher?.phone_number ?? '',
  address: props.teacher?.address ?? '',
  gender: props.teacher?.gender ?? '',
  employment_status: props.teacher?.employment_status ?? '',
  homeroom_class_id: props.teacher?.homeroom_class_id ?? '',
  subject_ids: props.teacher?.subject_ids ? [...props.teacher.subject_ids] : ([] as string[]),
});

const isEdit = computed(() => Boolean(props.teacher?.id));
const errors = reactive<Record<string, string>>({});

/**
 * "Ganti akun terkait" — only meaningful in edit mode. When ON, the
 * submit handler sends `use_another_user: true` which triggers the
 * backend's swapUserAccount() (migrates teacher row to another user
 * by email, instead of trying to update the current user's email).
 */
const isChangeUserMode = ref(false);

// Auto-flip the toggle on when the parent reports an email conflict
// from a prior save attempt — admin shouldn't have to find the
// toggle themselves to recover.
watch(
  () => props.emailConflictHint,
  (hint) => {
    if (hint) isChangeUserMode.value = true;
  },
);

function toggleSubject(id: string) {
  const idx = form.subject_ids.indexOf(id);
  if (idx >= 0) form.subject_ids.splice(idx, 1);
  else form.subject_ids.push(id);
}

function validate(): boolean {
  Object.keys(errors).forEach((k) => delete errors[k]);
  if (!form.name.trim()) errors.name = 'Nama wajib diisi.';
  if (!form.email.trim()) errors.email = 'Email wajib diisi.';
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim()))
    errors.email = 'Format email tidak valid.';
  return Object.keys(errors).length === 0;
}

function submit() {
  if (!validate()) return;
  emit('save', {
    name: form.name.trim(),
    email: form.email.trim(),
    role: form.role,
    employee_number: form.employee_number.trim() || null,
    phone_number: form.phone_number.trim() || null,
    address: form.address.trim() || null,
    gender: form.gender || null,
    employment_status: form.employment_status || null,
    homeroom_class_id: form.homeroom_class_id || null,
    subject_ids: form.subject_ids,
    // Only meaningful on edit. When true, backend swaps teacher.user_id
    // to point at the user matching `email` (or creates that user
    // first) instead of trying to update the current user's email.
    ...(isEdit.value && isChangeUserMode.value
      ? { use_another_user: true }
      : {}),
  });
}
</script>

<template>
  <Modal
    :title="isEdit ? 'Ubah Guru' : 'Tambah Guru'"
    :subtitle="
      isEdit ? 'Perbarui data guru di bawah ini.' : 'Lengkapi data guru baru.'
    "
    @close="emit('close')"
  >
    <form class="space-y-md" @submit.prevent="submit">
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

      <!-- "Ganti akun terkait" toggle — only in edit mode. -->
      <div
        v-if="isEdit"
        class="rounded-xl border p-3"
        :class="
          isChangeUserMode
            ? 'border-amber-300 bg-amber-50'
            : 'border-slate-200 bg-slate-50'
        "
      >
        <div class="flex items-start gap-3">
          <button
            type="button"
            role="switch"
            :aria-checked="isChangeUserMode"
            class="mt-0.5 inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors"
            :class="isChangeUserMode ? 'bg-amber-500' : 'bg-slate-300'"
            :disabled="isSaving"
            @click="isChangeUserMode = !isChangeUserMode"
          >
            <span
              class="inline-block h-4 w-4 transform rounded-full bg-white transition"
              :class="isChangeUserMode ? 'translate-x-[18px]' : 'translate-x-0.5'"
            ></span>
          </button>
          <div class="flex-1">
            <p class="text-sm font-semibold text-slate-900">Ganti akun terkait</p>
            <p class="text-xs text-slate-600 mt-0.5 leading-snug">
              Pindahkan guru ini ke akun lain berdasarkan email di
              bawah. Pakai ini kalau email yang baru sudah dipakai user
              lain di sistem.
            </p>
            <p
              v-if="emailConflictHint"
              class="text-xs text-amber-700 mt-1.5 font-medium leading-snug"
            >
              Email yang Anda masukkan sudah dipakai user lain. Toggle ini
              telah diaktifkan otomatis — klik Simpan lagi untuk
              memindahkan guru ke akun tersebut.
            </p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Email</label>
          <input
            v-model="form.email"
            type="email"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
          <p v-if="errors.email" class="text-xs text-status-danger mt-1">{{ errors.email }}</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">NIP / No. Pegawai</label>
          <input
            v-model="form.employee_number"
            type="text"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Peran</label>
          <select
            v-model="form.role"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
            :disabled="isSaving"
          >
            <option value="guru">Guru</option>
            <option value="wali_kelas">Wali Kelas</option>
          </select>
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
          <label class="block text-sm font-medium text-slate-700 mb-1">Status kepegawaian</label>
          <select
            v-model="form.employment_status"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
            :disabled="isSaving"
          >
            <option value="">— Pilih —</option>
            <option value="tetap">Tetap</option>
            <option value="tidak_tetap">Tidak Tetap</option>
            <option value="kontrak">Kontrak</option>
            <option value="honorer">Honorer</option>
          </select>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-slate-700 mb-1">
          Kelas Wali <span class="text-slate-400 font-normal">(opsional)</span>
        </label>
        <select
          v-model="form.homeroom_class_id"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
          :disabled="isSaving"
        >
          <option value="">— Tidak menjabat wali kelas —</option>
          <option v-for="c in classes" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-slate-700 mb-2">
          Mata pelajaran yang diampu
        </label>
        <div class="flex flex-wrap gap-2 max-h-40 overflow-y-auto">
          <button
            v-for="s in subjects"
            :key="s.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-xs font-medium border"
            :class="
              form.subject_ids.includes(s.id)
                ? 'bg-brand text-white border-brand'
                : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
            "
            @click="toggleSubject(s.id)"
          >
            {{ s.name }}
          </button>
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

      <BottomSheetFooter
        :primary-label="isEdit ? 'Simpan perubahan' : 'Tambah guru'"
        :primary-loading="isSaving"
        @primary="submit"
        @secondary="emit('close')"
      />
    </form>
  </Modal>
</template>
