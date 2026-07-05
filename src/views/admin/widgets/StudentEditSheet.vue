<!--
  StudentEditSheet.vue — port of `student_add_edit_dialog.dart`.
  Modal for adding or editing a student. Owns its own form state, calls
  the parent's `save` event with the raw API payload. Uses the shared
  FormSheet + FormField primitives; every field, validation message and
  payload key is unchanged.
-->
<script setup lang="ts">
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import FormSheet from '@/components/ui/FormSheet.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import type { Student, Classroom } from '@/types/entities';

const { t } = useI18n();

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
const title = computed(() => (isEdit.value ? t('admin.student.editTitle') : t('admin.student.addTitle')));
const subtitle = computed(() =>
  isEdit.value
    ? t('admin.student.editSubtitle')
    : t('admin.student.addSubtitle'),
);

const classOptions = computed<FormFieldOption[]>(() =>
  props.classes.map((c) => ({ value: c.id, label: c.name })),
);
const genderOptions = computed<FormFieldOption[]>(() => [
  { value: 'L', label: t('admin.gender.male') },
  { value: 'P', label: t('admin.gender.female') },
]);

const errors = reactive<Record<string, string>>({});

function validate(): boolean {
  Object.keys(errors).forEach((k) => delete errors[k]);
  if (!form.name.trim()) errors.name = t('admin.student.nameRequired');
  if (!form.student_number.trim())
    errors.student_number = t('admin.student.nisRequired');
  if (!form.class_id) errors.class_id = t('admin.student.classRequired');
  if (!form.guardian_name.trim())
    errors.guardian_name = t('admin.student.guardianRequired');
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
  <FormSheet
    :title="title"
    :subtitle="subtitle"
    :saving="isSaving"
    :save-label="isEdit ? t('common.saveChanges') : t('admin.student.addButton')"
    @save="submit"
    @cancel="emit('close')"
  >
    <FormField
      v-model="form.name"
      :label="t('common.fullName')"
      :disabled="isSaving"
      :error="errors.name"
    />

    <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
      <FormField
        v-model="form.student_number"
        :label="t('admin.student.nisLabel')"
        :disabled="isSaving"
        :error="errors.student_number"
      />
      <FormField
        v-model="form.class_id"
        type="select"
        :label="t('common.class')"
        :select-placeholder="t('admin.student.selectClassPlaceholder')"
        :options="classOptions"
        :disabled="isSaving"
        :error="errors.class_id"
      />
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
      <FormField
        v-model="form.gender"
        type="select"
        :label="t('common.gender')"
        :select-placeholder="t('common.selectPlaceholder')"
        :options="genderOptions"
        :disabled="isSaving"
      />
      <FormField v-model="form.date_of_birth" :label="t('common.dateOfBirth')">
        <input
          v-model="form.date_of_birth"
          type="date"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
          :disabled="isSaving"
        />
      </FormField>
    </div>

    <FormField
      v-model="form.address"
      type="textarea"
      :label="t('common.address')"
      :rows="2"
      :disabled="isSaving"
    />

    <div class="border-t border-slate-100 pt-md space-y-md">
      <p class="text-xs uppercase tracking-wider text-slate-400 font-semibold">
        {{ t('admin.student.guardianDataSection') }}
      </p>
      <FormField
        v-model="form.guardian_name"
        :label="t('admin.student.guardianName')"
        :disabled="isSaving"
        :error="errors.guardian_name"
      />
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <FormField
          v-model="form.guardian_email"
          type="email"
          :label="t('admin.student.guardianEmail')"
          :disabled="isSaving"
        />
        <FormField
          v-model="form.phone_number"
          type="tel"
          :label="t('common.phoneNumber')"
          :disabled="isSaving"
        />
      </div>
    </div>
  </FormSheet>
</template>
