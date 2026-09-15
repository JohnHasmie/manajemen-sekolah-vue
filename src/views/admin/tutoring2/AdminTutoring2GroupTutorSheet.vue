<!--
  AdminTutoring2GroupTutorSheet.vue — assign or change the TUTOR of an
  existing learning group (`PUT /tutoring-v2/learning-groups/{id}`,
  BE-3).

  WHY IT EXISTS. `UpdateLearningGroupRequest` has carried
  `tutor_id => ['sometimes','nullable','uuid']` since BE-3, and
  `UpdateLearningGroupAction` applies every key that is PRESENT in the
  body — including an explicit null, which is how a nullable field is
  unset. The web app never sent it. AdminTutoring2GroupDetailView had
  zero references to `tutor_id`: it RENDERED `tutor_name` in the header
  meta and offered no way to change it, and its own header recorded
  that the legacy "Ubah" button was dropped rather than re-shipped
  inert. So a group created without a tutor — which, until the create
  sheet grew its own picker, was every group — could never be given
  one from the web app at all.

  ── SCOPE ───────────────────────────────────────────────────────────
  This sheet edits ONE field. `UpdateLearningGroupRequest` also accepts
  name / term_id / capacity / room / status, and a full group edit form
  is still a separate MR: `capacity` in particular has two server-side
  domain guards (a private group must stay at 1; the new capacity may
  not fall below the seated count) whose 422s need their own handling.
  Narrowing to `tutor_id` keeps the `sometimes` rules doing exactly
  what they are for — an untouched field is an absent key, so nothing
  else on the row can be disturbed by saving here.

  ── "TANPA TUTOR" IS A REAL ANSWER, AND IT IS `null` ────────────────
  The placeholder option is not decoration: `nullable` means a group
  with no tutor is a legitimate row, and choosing it here is the
  instruction "detach this group's tutor". That is sent as an explicit
  `null`, never as `''` and never by omitting the key:
    · omitting it would mean "I did not touch this field" — the
      opposite request;
    · `''` would arrive as `null` anyway, because Laravel 12 keeps
      `ConvertEmptyStringsToNull` in the default global middleware
      stack and this app does not override it — but relying on a
      middleware to translate the intent is how a form ends up meaning
      something different the day that stack changes.
  `UpdateLearningGroupAction` reads presence with `array_key_exists`
  precisely so an explicit null survives, which is what makes the
  detach path work at all.

  ── THE CURRENT TUTOR IS ALWAYS PICKABLE ────────────────────────────
  The option list is the tenant's ACTIVE tutors. A group assigned
  before its tutor was deactivated would therefore hold an id that is
  not in the list, and a select whose value matches no option renders
  as the placeholder — i.e. the screen would claim the group has no
  tutor while the database says otherwise. The current tutor is
  prepended when missing so the field always shows the truth, and
  `saveDisabled` below keeps that from being saved back as a change.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { useBimbelTutorOptions } from '@/composables/useBimbelTutorOptions';
import { useToast } from '@/composables/useToast';
import { extractError } from '@/lib/api-error';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
} from '@/services/tutoring-bimbel.service';

const props = defineProps<{
  /** The group being edited. Its `tutor_id` seeds the picker. */
  group: BimbelLearningGroup;
}>();

const emit = defineEmits<{
  close: [];
  /** Fires after a successful PUT, carrying the server's fresh row. */
  saved: [group: BimbelLearningGroup];
}>();

const { t } = useI18n();
const toast = useToast();

/** '' = "Tanpa tutor". Seeded from the group so the field opens truthful. */
const selectedTutorId = ref<string>(props.group.tutor_id ?? '');

const isSaving = ref(false);
const errorMessage = ref<string | null>(null);

const {
  options: activeTutorOptions,
  loading: tutorsLoading,
  failed: tutorsFailed,
  truncated: tutorsTruncated,
  load: loadTutors,
} = useBimbelTutorOptions();

onMounted(() => void loadTutors());

/**
 * Active tutors, with THIS group's tutor prepended when the list does
 * not already contain them — see the header. `tutor_name` is eager-
 * loaded by `LearningGroupController::show`, so the prepended row
 * normally carries a real name; the translated fallback covers the
 * case where it did not arrive.
 */
const tutorOptions = computed<FormFieldOption[]>(() => {
  const options: FormFieldOption[] = [...activeTutorOptions.value];
  const currentId = props.group.tutor_id;
  if (currentId && !options.some((o) => o.value === currentId)) {
    options.unshift({
      value: currentId,
      label: props.group.tutor_name ?? t('tutoring2.admin.groupTutor.currentUnnamed'),
    });
  }
  return options;
});

/** True once the list is settled and genuinely empty (not refused). */
const noTutorsAvailable = computed(
  () => !tutorsLoading.value && !tutorsFailed.value && tutorOptions.value.length === 0,
);

/**
 * Nothing to save until the choice actually differs from what the row
 * already holds. Both sides are normalised to '' first so a `null`
 * tutor_id and an untouched placeholder compare equal — otherwise
 * opening and closing the sheet on a tutorless group would offer a PUT
 * that changes nothing.
 */
const isDirty = computed(
  () => selectedTutorId.value !== (props.group.tutor_id ?? ''),
);

async function submit(): Promise<void> {
  if (isSaving.value || !isDirty.value) return;
  isSaving.value = true;
  errorMessage.value = null;
  try {
    // `|| null` is the detach path: '' is the placeholder, and an
    // explicit null is what unsets a nullable column.
    const updated = await TutoringBimbelService.updateGroup(props.group.id, {
      tutor_id: selectedTutorId.value || null,
    });
    toast.success(t('tutoring2.admin.groupTutor.success'));
    emit('saved', updated);
    emit('close');
  } catch (err) {
    // The server's own Indonesian text wins where there is one — 402
    // ("Modul Bimbel belum aktif…") and 403 both reach this path.
    errorMessage.value =
      extractError(err) ?? t('tutoring2.admin.groupTutor.errorGeneric');
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <FormSheet
    :title="t('tutoring2.admin.groupTutor.title')"
    :subtitle="t('tutoring2.admin.groupTutor.subtitle', { group: group.name })"
    :saving="isSaving"
    :save-disabled="!isDirty || tutorsLoading || tutorsFailed"
    size="sm"
    :save-label="t('tutoring2.admin.groupTutor.submit')"
    @save="submit"
    @cancel="emit('close')"
  >
    <p
      v-if="errorMessage"
      data-testid="group-tutor-error"
      class="rounded-2xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700"
      role="alert"
    >
      {{ errorMessage }}
    </p>

    <FormField
      v-model="selectedTutorId"
      type="select"
      field="tutor_id"
      :label="t('tutoring2.admin.groupTutor.label')"
      :disabled="isSaving || tutorsLoading || tutorsFailed"
      :options="tutorOptions"
      :select-placeholder="t('tutoring2.admin.groupTutor.placeholder')"
    />

    <p v-if="tutorsLoading" class="text-xs text-slate-400">
      {{ t('tutoring2.admin.groupTutor.loading') }}
    </p>
    <p
      v-else-if="tutorsFailed"
      data-testid="group-tutor-list-failed"
      class="text-xs text-slate-500"
    >
      {{ t('tutoring2.admin.groupTutor.failed') }}
    </p>
    <p
      v-else-if="noTutorsAvailable"
      data-testid="group-tutor-list-empty"
      class="text-xs text-slate-500"
    >
      {{ t('tutoring2.admin.groupTutor.none') }}
    </p>
    <template v-else>
      <p v-if="tutorsTruncated" class="text-xs text-slate-400">
        {{ t('tutoring2.admin.groupTutor.truncated') }}
      </p>
      <p class="text-xs text-slate-400">
        {{ t('tutoring2.admin.groupTutor.unassignHint') }}
      </p>
    </template>
  </FormSheet>
</template>
