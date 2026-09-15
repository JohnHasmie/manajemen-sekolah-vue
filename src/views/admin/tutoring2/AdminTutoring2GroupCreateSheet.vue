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

  ── FIELD SET, AND WHAT IS STILL LEFT OFF ───────────────────────────
  This form started as name + capacity + program, the field set of the
  inline form it replaced. `StoreLearningGroupRequest` also accepts
  term_id / tutor_id / kind / room / status, and the note that used to
  sit here said inventing inputs for any of them was a product
  decision rather than a bug fix.

  That decision has since been made for exactly ONE of them: TUTOR. A
  group is taught by somebody, the column and the rule have accepted
  `tutor_id` since BE-3, and `CreateLearningGroupAction` writes it —
  the form simply never asked, so every group was born tutorless and
  the Tutor column on the list read "—" for rows whose tutor was a
  settled fact everywhere except the database.

  term_id / kind / room / status remain off this form on purpose and
  stay server-defaulted: `term_id` falls back to the tenant's current
  term, `kind` to `group`, `status` to `draft` (the list's
  Aktifkan / Jadikan Draf buttons flip it afterwards), and `room` has
  no product answer yet.

  The tutor field is OPTIONAL, because the rule is `nullable` and a
  group without a tutor is a legitimate row — a kelompok can be opened
  before anyone is assigned to it. Left blank, the key is left OFF the
  body entirely rather than sent as `''`. On create the two would in
  fact land the same (Laravel 12 keeps `ConvertEmptyStringsToNull` in
  the default global middleware stack, which this app does not
  override, so `''` arrives as `null`), but absence is the only
  spelling that means the same thing on every endpoint: through
  `UpdateLearningGroupRequest`'s `sometimes` an EMPTY value is the
  instruction "unassign this group's tutor", which is a different
  request from "I did not touch this field".
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { useBimbelTutorOptions } from '@/composables/useBimbelTutorOptions';
import { useMe } from '@/composables/useMe';
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
const { can } = useMe();

/**
 * `tutoring.group.manage` — the key `LearningGroupController::store`
 * authorizes, read off the `/me` abilities snapshot (scoped by
 * `X-Active-Role`), never off `roles[].permission_keys`.
 *
 * Belt and braces: the CTAs that open this sheet are already gated, so
 * an admin without the key should not be here at all. Withholding the
 * field as well means no path can offer a control whose only possible
 * outcome is a 403, and it is what makes the without-the-ability case
 * testable from outside.
 */
const canAssignTutor = computed(() => can('tutoring.group.manage'));

/** Server default when the admin clears the box; mirrors the old form. */
const DEFAULT_CAPACITY = 10;
const MIN_NAME_LENGTH = 3;

const name = ref('');
const capacity = ref<number>(DEFAULT_CAPACITY);
const selectedProgramId = ref<string>('');
/** '' = no tutor chosen. Never reaches the wire as '' — see submit(). */
const selectedTutorId = ref<string>('');

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

// ── Tutor ───────────────────────────────────────────────────────────
// Fetched HERE rather than handed down as a prop, because the sheet has
// two entry points (the global list and a program drill-in) and only
// one of them already holds a tutor list. Loading it once inside the
// component is what keeps the two doors identical — the alternative is
// a prop that is populated from one caller and empty from the other,
// where "empty" is indistinguishable from "this tenant has no tutors".
const {
  options: tutorOptions,
  loading: tutorsLoading,
  failed: tutorsFailed,
  truncated: tutorsTruncated,
  load: loadTutors,
} = useBimbelTutorOptions();

/**
 * Only fetch when the field will actually be rendered. An admin without
 * `tutoring.group.manage` gets no request at all rather than one whose
 * result nothing can use.
 */
onMounted(() => {
  if (canAssignTutor.value) void loadTutors();
});

/** True once the list is settled and genuinely empty (not refused). */
const noTutorsAvailable = computed(
  () => !tutorsLoading.value && !tutorsFailed.value && tutorOptions.value.length === 0,
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
      // ABSENT, not ''. A blank picker means "no tutor decided yet",
      // and the only spelling of that which reads the same on every
      // endpoint is a key that is not there. Gated a second time so a
      // stale ref can never smuggle a value past the hidden field.
      ...(canAssignTutor.value && selectedTutorId.value
        ? { tutor_id: selectedTutorId.value }
        : {}),
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

    <!--
      Tutor. Hidden — not disabled — without `tutoring.group.manage`.
      The placeholder option IS the "no tutor" answer, so the field
      never needs a separate clear control, and an empty list leaves an
      explanatory line under it instead of a dropdown with nothing in
      it.
    -->
    <div v-if="canAssignTutor">
      <FormField
        v-model="selectedTutorId"
        type="select"
        field="tutor_id"
        :label="t('tutoring2.admin.groupCreate.tutorLabel')"
        :disabled="isSaving || tutorsLoading || tutorsFailed"
        :options="tutorOptions"
        :select-placeholder="t('tutoring2.admin.groupCreate.tutorPh')"
      />
      <p v-if="tutorsLoading" class="mt-1 text-xs text-slate-400">
        {{ t('tutoring2.admin.groupCreate.tutorsLoading') }}
      </p>
      <p
        v-else-if="tutorsFailed"
        data-testid="tutors-failed"
        class="mt-1 text-xs text-slate-500"
      >
        {{ t('tutoring2.admin.groupCreate.tutorsFailed') }}
      </p>
      <p
        v-else-if="noTutorsAvailable"
        data-testid="tutors-none"
        class="mt-1 text-xs text-slate-500"
      >
        {{ t('tutoring2.admin.groupCreate.tutorsNone') }}
      </p>
      <p
        v-else-if="tutorsTruncated"
        data-testid="tutors-truncated"
        class="mt-1 text-xs text-slate-400"
      >
        {{ t('tutoring2.admin.groupCreate.tutorsTruncated') }}
      </p>
    </div>
  </FormSheet>
</template>
