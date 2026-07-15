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
import FormSheet from '@/components/ui/FormSheet.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import type { Teacher, Classroom, Subject } from '@/types/entities';
import { subjectLabel } from '@/lib/labels';

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

/**
 * Fold a stored gender value down to the `L` / `P` codes the dropdown
 * offers. The deployed teacher records mostly store gender as the English
 * labels `male` / `female` (left over from the rename migration), but the
 * <select> only has L/P options — so a male/female value would render the
 * field blank and (before the backend `in:L,P` fix) get re-sent verbatim,
 * tripping a 422 on edit teacher. Normalising here makes the field pre-fill
 * correctly and always submit a valid code. Unknown values fall back to ''.
 */
function normalizeGender(g: string | null | undefined): string {
  switch ((g ?? '').toLowerCase()) {
    case 'male':
    case 'm':
    case 'l':
    case 'laki-laki':
      return 'male';
    case 'female':
    case 'f':
    case 'p':
    case 'perempuan':
      return 'female';
    default:
      return '';
  }
}

const form = reactive({
  name: props.teacher?.name ?? '',
  email: props.teacher?.email ?? '',
  role: props.teacher?.role ?? 'guru',
  employee_number: props.teacher?.employee_number ?? '',
  phone_number: props.teacher?.phone_number ?? '',
  address: props.teacher?.address ?? '',
  gender: normalizeGender(props.teacher?.gender),
  employment_status: props.teacher?.employment_status ?? '',
  homeroom_class_id: props.teacher?.homeroom_class_id ?? '',
  subject_ids: props.teacher?.subject_ids ? [...props.teacher.subject_ids] : ([] as string[]),
});

const isEdit = computed(() => Boolean(props.teacher?.id));
const errors = reactive<Record<string, string>>({});

// ── Dropdown option lists ────────────────────────────────────────────
const roleOptions: FormFieldOption[] = [
  { value: 'guru', label: 'Guru' },
  { value: 'wali_kelas', label: 'Wali Kelas' },
];
const genderOptions: FormFieldOption[] = [
  { value: 'male', label: 'Laki-laki' },
  { value: 'female', label: 'Perempuan' },
];
const employmentOptions: FormFieldOption[] = [
  { value: 'tetap', label: 'Tetap' },
  { value: 'tidak_tetap', label: 'Tidak Tetap' },
  { value: 'kontrak', label: 'Kontrak' },
  { value: 'honorer', label: 'Honorer' },
];
const homeroomOptions = computed<FormFieldOption[]>(() =>
  props.classes.map((c) => ({ value: c.id, label: c.name })),
);

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
  <FormSheet
    :title="isEdit ? 'Ubah Guru' : 'Tambah Guru'"
    :subtitle="
      isEdit ? 'Perbarui data guru di bawah ini.' : 'Lengkapi data guru baru.'
    "
    :saving="isSaving"
    :save-label="isEdit ? 'Simpan perubahan' : 'Tambah guru'"
    @save="submit"
    @cancel="emit('close')"
  >
      <FormField
        v-model="form.name"
        label="Nama lengkap"
        :disabled="isSaving"
        :error="errors.name"
      />

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
        <FormField
          v-model="form.email"
          type="email"
          label="Email"
          :disabled="isSaving"
          :error="errors.email"
        />
        <FormField
          v-model="form.employee_number"
          label="NIP / No. Pegawai"
          :disabled="isSaving"
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <FormField
          v-model="form.role"
          type="select"
          label="Peran"
          :options="roleOptions"
          :disabled="isSaving"
        />
        <FormField
          v-model="form.phone_number"
          type="tel"
          label="No. HP"
          :disabled="isSaving"
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <FormField
          v-model="form.gender"
          type="select"
          label="Jenis kelamin"
          select-placeholder="— Pilih —"
          :options="genderOptions"
          :disabled="isSaving"
        />
        <FormField
          v-model="form.employment_status"
          type="select"
          label="Status kepegawaian"
          select-placeholder="— Pilih —"
          :options="employmentOptions"
          :disabled="isSaving"
        />
      </div>

      <FormField
        v-model="form.homeroom_class_id"
        type="select"
        select-placeholder="— Tidak menjabat wali kelas —"
        :options="homeroomOptions"
        :disabled="isSaving"
      >
        <template #label>
          Kelas Wali <span class="text-slate-400 font-normal">(opsional)</span>
        </template>
      </FormField>

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
            {{ subjectLabel(s) }}
          </button>
        </div>
      </div>

      <FormField
        v-model="form.address"
        type="textarea"
        label="Alamat"
        :rows="2"
        :disabled="isSaving"
      />
  </FormSheet>
</template>
