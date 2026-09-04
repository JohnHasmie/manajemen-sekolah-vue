<!--
  AdminTutoring2GroupCreateSheet.vue — the ONE create surface for a
  learning group (`POST /tutoring-v2/learning-groups`, BE-3).

  Why it exists: the create call already lived in
  AdminTutoring2ProgramDetailView as an inline <form>, reachable only
  from inside one program. The global list (AdminTutoring2GroupsView)
  rendered a floating "+ Kelompok baru" CTA with NO `@click` at all —
  a convincing button that could not do anything, reported from prod as
  "tombol diklik tidak terjadi apa-apa". Rather than bolt a second form
  onto the list view, the existing one was lifted here so both entry
  points POST through the same component and cannot drift apart.

  Two entry points, one sheet:
    - From the program drill-in — `programId` is passed, so the program
      picker is not rendered at all (it is already decided by the route)
      and the payload uses the prop.
    - From the global list — `programId` is null, so the admin picks the
      program from `programs`, which the list view has already loaded
      for its filter chips. No extra fetch happens here.

  Field set is deliberately IDENTICAL to the inline form it replaces
  (name + capacity, plus program): `StoreLearningGroupRequest` also
  accepts term_id / tutor_id / kind / room / status, but the shipped
  flow never sent them and inventing inputs for them is a product
  decision, not a bug fix. They stay server-defaulted.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';

const props = withDefaults(
  defineProps<{
    /**
     * Pre-decided program (drill-in entry point). When set, the program
     * picker is suppressed — the route already answered that question.
     */
    programId?: string | null;
    /**
     * Options for the picker, used only when `programId` is null. The
     * caller passes the list it already holds; an empty list means the
     * sheet cannot submit and says so rather than 422-ing.
     */
    programs?: BimbelProgram[];
  }>(),
  { programId: null, programs: () => [] },
);

const emit = defineEmits<{
  close: [];
  saved: [group: BimbelLearningGroup];
}>();

const { t } = useI18n();
const toast = useToast();

/** Server default when the admin clears the box; mirrors the old form. */
const DEFAULT_CAPACITY = 10;
const MIN_NAME_LENGTH = 3;

const name = ref('');
const capacity = ref<number>(DEFAULT_CAPACITY);
const selectedProgramId = ref<string>('');

const isSaving = ref(false);
const errors = ref<{ name?: string; program?: string }>({});

/** True when the caller fixed the program, so no picker is rendered. */
const hasPresetProgram = computed(() => !!props.programId);

const programOptions = computed<FormFieldOption[]>(() =>
  props.programs.map((p) => ({ value: p.id, label: p.name })),
);

/** The program the payload will carry: the prop wins over the picker. */
const effectiveProgramId = computed(
  () => props.programId || selectedProgramId.value,
);

/**
 * Disable Save when there is provably nothing to submit. A picker with
 * zero options is the one case the admin cannot resolve from inside the
 * sheet, so it also gets an explanatory line under the field instead of
 * an empty dropdown.
 */
const noProgramsAvailable = computed(
  () => !hasPresetProgram.value && programOptions.value.length === 0,
);

function validate(): boolean {
  const next: { name?: string; program?: string } = {};
  if (name.value.trim().length < MIN_NAME_LENGTH) {
    next.name = t('tutoring2.admin.groupCreate.errName');
  }
  if (!effectiveProgramId.value) {
    next.program = t('tutoring2.admin.groupCreate.errProgram');
  }
  errors.value = next;
  return Object.keys(next).length === 0;
}

async function submit(): Promise<void> {
  if (isSaving.value) return;
  if (!validate()) return;
  isSaving.value = true;
  try {
    const group = await TutoringBimbelService.createGroup({
      program_id: effectiveProgramId.value,
      name: name.value.trim(),
      capacity: capacity.value,
    });
    toast.success(t('tutoring2.admin.groupCreate.success'));
    emit('saved', group);
    emit('close');
  } catch (err) {
    // Prefer Laravel's own message (validation + domain rejections both
    // carry one) so a 422 the client-side checks missed still explains
    // itself instead of collapsing into a generic failure.
    const anyErr = err as {
      response?: { data?: { message?: string; errors?: Record<string, string[]> } };
      message?: string;
    };
    const fieldErrors = anyErr?.response?.data?.errors;
    const first = fieldErrors ? Object.values(fieldErrors)[0] : undefined;
    toast.error(
      (Array.isArray(first) ? first[0] : undefined) ??
        anyErr?.response?.data?.message ??
        anyErr?.message ??
        t('tutoring2.admin.groupCreate.errorGeneric'),
    );
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <FormSheet
    :title="t('tutoring2.admin.groupCreate.title')"
    :subtitle="t('tutoring2.admin.groupCreate.subtitle')"
    :saving="isSaving"
    :save-disabled="noProgramsAvailable"
    size="md"
    :save-label="t('tutoring2.admin.groupCreate.submit')"
    @save="submit"
    @cancel="emit('close')"
  >
    <FormField
      v-if="!hasPresetProgram"
      v-model="selectedProgramId"
      type="select"
      field="program_id"
      :label="t('tutoring2.common.program')"
      :required="true"
      :disabled="isSaving || noProgramsAvailable"
      :options="programOptions"
      :select-placeholder="t('tutoring2.admin.groupCreate.programPh')"
      :error="noProgramsAvailable ? t('tutoring2.admin.groupCreate.noPrograms') : errors.program"
    />

    <FormField
      v-model="name"
      field="name"
      :label="t('tutoring2.admin.groupCreate.nameLabel')"
      :required="true"
      :disabled="isSaving"
      :placeholder="t('tutoring2.admin.groupCreate.namePh')"
      :error="errors.name"
    />

    <FormField
      v-model="capacity"
      type="number"
      field="capacity"
      number-model
      :min="1"
      :max="500"
      :label="t('tutoring2.admin.groupCreate.capacityLabel')"
      :disabled="isSaving"
      :placeholder="t('tutoring2.admin.groupCreate.capacityPh')"
    />
  </FormSheet>
</template>
