<!--
  AdminTutoring2GroupAddStudentSheet.vue — "Tambah siswa" on the admin
  group drill-in (`POST /tutoring-v2/enrollments`, BE-3).

  ── WHY THIS IS A FORM AND NOT A ONE-CLICK ADD ──────────────────────

  Adding a student to a learning group is not a group-membership write;
  there is no such endpoint. Membership IS an enrollment, and
  `StoreEnrollmentRequest` marks three fields `required`:

      student_id        → the picker below
      program_id        → NOT asked; the group already answers it
      billing_mode      → asked, because nothing can answer it

  `program_id` is free: a group belongs to exactly one program, and
  `CreateEnrollmentAction` re-checks the pair
  ("Kelompok bukan milik program ini."), so passing the group's own
  `program_id` is the only value that can ever validate.

  `billing_mode` is the reason a one-click button would be dishonest.
  It is a THREE-way billing decision — prabayar / SPP bulanan / per
  sesi — with no server default and no derivable answer, and it is the
  field the monthly and per-session bill generators read. Picking one
  on the admin's behalf would invent a payment arrangement for a real
  customer. So it is asked, and nothing is submitted until it is.

  Everything else the endpoint accepts (`status`, `price_at_enrollment`,
  `billing_day_of_month`, `notes`) stays SERVER-DEFAULTED rather than
  invented here — the same restraint AdminTutoring2GroupCreateSheet
  records for its own untouched fields. Two consequences worth stating
  out loud, because they are billing-adjacent:

    · `status` defaults to `trial` in `CreateEnrollmentAction`. A student
      added here is a trial member, which is why the sheet says so
      under the button rather than letting the roster's status pill be
      the first place anyone finds out. Promoting to `active` is the
      existing "convert" action, not this form.
    · `price_at_enrollment` is snapshotted FROM THE PACKAGE for prepaid
      / per-session. For MONTHLY there is nothing to snapshot — packages
      hold a total and a session count, never a monthly rate — so a
      monthly enrollment created here carries a NULL rate and the cron
      generates no bill for it. That is the backend's deliberate
      "an unbilled tenant asks why, an over-billed one has already been
      charged" stance, and the sheet repeats it as a hint on the field
      instead of quietly inventing a number.

  ── PICKERS, NOT TYPED IDS — AND NOT MODALS EITHER ──────────────────

  Copied wholesale from AdminTutoring2BillCreateSheet, which records the
  reasoning: FormSheet IS a Modal, so a second Modal on top (the
  FilterFacetPickerModal the filter chips use) would stack two
  `Teleport to="body"` overlays at the same z-50 with two ESC handlers,
  and no screen in the repo does that. Siswa is therefore a FormField
  `type="select"` with a debounced "Cari siswa" FormField above it that
  refetches with `?search=` — server-side, because a client-side filter
  over "the page we happened to load" reports "no match" for a student
  who exists.

  ── ALREADY-IN-THIS-GROUP IS HANDLED HERE, NOT BY THE SERVER ────────

  The server does NOT stop it. Its only duplicate guard fires when the
  NEW row would be `active`:

      if ($status === EnrollmentStatus::ACTIVE) { … 'Siswa sudah punya
      pendaftaran aktif di program ini.' }

  and it is backed by a partial unique index that is likewise
  `WHERE status = 'active'`. Since this sheet creates `trial` rows,
  neither ever fires — posting the same student twice would succeed and
  put TWO rows for one person on the roster.

  So the picker subtracts them: `ongoingStudentIds` drops every student
  who already holds a trial / active / PAUSED enrollment in this group.

  Paused is in that list on purpose, and the difference from the
  server's `LearningGroup::SEATED_STATUSES = ['active', 'trial']` is
  deliberate, not drift. Those two constants answer different
  questions: SEATED asks "does this row consume capacity" (paused frees
  the seat), while this asks "is this person already on the roster"
  (paused still prints a row). Only `graduated` and `withdrawn` truly
  end a membership, and those students stay pickable — re-enrolling a
  returning student is a real flow, and the terminal row beside the new
  one reads as history.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { useToast } from '@/composables/useToast';
import { extractError } from '@/lib/api-error';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
  type BimbelLearningGroup,
  type BimbelPackage,
} from '@/services/tutoring-bimbel.service';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type { BimbelStudent } from '@/types/tutoring2/student';

type BillingMode = BimbelPackage['allowed_billing_modes'][number];

const props = defineProps<{
  /** The group being added to — supplies `program_id` and the labels. */
  group: BimbelLearningGroup;
  /**
   * The roster this screen already holds. Passed in rather than
   * re-fetched: the detail view loaded it one request ago, and the
   * sheet only needs it to subtract already-enrolled students.
   */
  roster: BimbelEnrollment[];
}>();

const emit = defineEmits<{
  close: [];
  saved: [enrollment: BimbelEnrollment];
}>();

const { t } = useI18n();
const toast = useToast();

/** One page of picker rows. Mirrors AdminTutoring2BillCreateSheet. */
const PICKER_PAGE_SIZE = 50;

/**
 * Statuses that mean "already on this roster" — see the file header for
 * why this is NOT `LearningGroup::SEATED_STATUSES`.
 */
const ONGOING_STATUSES: ReadonlyArray<BimbelEnrollment['status']> = [
  'trial',
  'active',
  'paused',
];

/** All three modes, used when no package narrows them. */
const ALL_BILLING_MODES: readonly BillingMode[] = ['prepaid', 'monthly', 'per_session'];

const studentSearch = ref('');
const studentId = ref('');
const packageId = ref('');
const billingMode = ref<BillingMode | ''>('');
const startDate = ref('');

const students = ref<BimbelStudent[]>([]);
const studentsLoading = ref(false);
const packages = ref<BimbelPackage[]>([]);
const packagesLoading = ref(false);

const isSaving = ref(false);
const errors = ref<{ student_id?: string; billing_mode?: string }>({});

// ── Students ───────────────────────────────────────────────────────

/**
 * `active` is stated explicitly rather than left to the default:
 * omitting it does NOT mean "all" on the server, which reads a missing
 * param as true.
 */
async function loadStudents(): Promise<void> {
  studentsLoading.value = true;
  const query = studentSearch.value.trim();
  try {
    const res = await TutoringStudentsService.list({
      per_page: PICKER_PAGE_SIZE,
      active: true,
      ...(query ? { search: query } : {}),
    });
    students.value = res.items;
  } catch {
    students.value = [];
  } finally {
    studentsLoading.value = false;
  }
}

const debouncedStudentReload = useDebounceFn(() => void loadStudents(), 300);
watch(studentSearch, () => debouncedStudentReload());

const ongoingStudentIds = computed<Set<string>>(
  () =>
    new Set(
      props.roster
        .filter((e) => ONGOING_STATUSES.includes(e.status))
        .map((e) => e.student_id),
    ),
);

const studentOptions = computed<FormFieldOption[]>(() =>
  students.value
    .filter((s) => !ongoingStudentIds.value.has(s.id))
    .map((s) => ({
      value: s.id,
      label: [s.name.trim() || t('tutoring2.admin.groupAddStudent.unnamed'), s.student_number?.trim()]
        .filter(Boolean)
        .join(' · '),
    })),
);

/**
 * True when the server filled a whole page, so the list in hand is
 * provably partial. Said out loud under the field — an admin who cannot
 * find a student needs to know the list is a page, not the roster.
 */
const studentsTruncated = computed(() => students.value.length >= PICKER_PAGE_SIZE);

/** How many of the fetched page were dropped as already-enrolled. */
const hiddenAlreadyEnrolled = computed(
  () => students.value.length - studentOptions.value.length,
);

// ── Packages ───────────────────────────────────────────────────────

/**
 * Packages of THIS group's program. Optional on the wire, but the only
 * thing that supplies `price_at_enrollment` for prepaid / per-session,
 * so it is offered rather than hidden.
 */
async function loadPackages(): Promise<void> {
  packagesLoading.value = true;
  try {
    const res = await TutoringBimbelService.listPackages(props.group.program_id, {
      per_page: PICKER_PAGE_SIZE,
      status: 'active',
    });
    packages.value = res.items;
  } catch {
    packages.value = [];
  } finally {
    packagesLoading.value = false;
  }
}

const packageOptions = computed<FormFieldOption[]>(() =>
  packages.value.map((p) => ({ value: p.id, label: p.name })),
);

const selectedPackage = computed<BimbelPackage | null>(
  () => packages.value.find((p) => p.id === packageId.value) ?? null,
);

/**
 * `CreateEnrollmentAction` rejects a mode outside the package's
 * `allowed_billing_modes` ("Mode tagihan tidak diizinkan pada paket
 * ini."), so the select narrows to them — the same constraint
 * ParentTutoring2EnrollWizardView applies. With no package chosen the
 * server's only remaining constraint is the tenant's enabled modes,
 * which no endpoint this role can read exposes, so all three are
 * offered and a rejected one surfaces the server's own sentence.
 */
const billingModeOptions = computed<FormFieldOption[]>(() => {
  const allowed = selectedPackage.value?.allowed_billing_modes ?? ALL_BILLING_MODES;
  return allowed.map((m) => ({ value: m, label: billingModeLabel(m) }));
});

function billingModeLabel(mode: BillingMode): string {
  switch (mode) {
    case 'prepaid':
      return t('tutoring2.admin.groupAddStudent.billingPrepaid');
    case 'monthly':
      return t('tutoring2.admin.groupAddStudent.billingMonthly');
    case 'per_session':
      return t('tutoring2.admin.groupAddStudent.billingPerSession');
  }
}

/**
 * Changing the package can invalidate the chosen mode. Clearing it is
 * the honest move: silently posting a mode the new package forbids
 * would 422, and silently rewriting it would change a billing decision
 * the admin made.
 */
watch(packageId, () => {
  const allowed = selectedPackage.value?.allowed_billing_modes ?? ALL_BILLING_MODES;
  if (billingMode.value && !allowed.includes(billingMode.value)) {
    billingMode.value = '';
  }
});

watch(studentId, () => {
  delete errors.value.student_id;
});

/** MONTHLY has no rate to snapshot — see the file header. */
const monthlyRateWarning = computed(() => billingMode.value === 'monthly');

onMounted(() => {
  void loadStudents();
  void loadPackages();
});

// ── Submit ─────────────────────────────────────────────────────────

function validate(): boolean {
  const next: { student_id?: string; billing_mode?: string } = {};
  if (!studentId.value) {
    next.student_id = t('tutoring2.admin.groupAddStudent.errStudent');
  }
  if (!billingMode.value) {
    next.billing_mode = t('tutoring2.admin.groupAddStudent.errBillingMode');
  }
  errors.value = next;
  return Object.keys(next).length === 0;
}

async function submit(): Promise<void> {
  if (isSaving.value) return;
  if (!validate()) return;
  const mode = billingMode.value;
  if (!mode) return;

  isSaving.value = true;
  try {
    const enrollment = await TutoringBimbelService.createEnrollment({
      student_id: studentId.value,
      program_id: props.group.program_id,
      learning_group_id: props.group.id,
      billing_mode: mode,
      // Omitted, not nulled: `package_id` is `nullable|uuid`, and an
      // empty string is neither.
      ...(packageId.value ? { package_id: packageId.value } : {}),
      ...(startDate.value ? { start_date: startDate.value } : {}),
    });
    toast.success(t('tutoring2.admin.groupAddStudent.success'));
    emit('saved', enrollment);
    emit('close');
  } catch (err) {
    // `extractError` is the house single implementation of "what did the
    // server actually say?" — it carries Laravel's Indonesian 422 text
    // through verbatim ("Kelompok penuh (8 / 10).", "Program telah
    // diarsipkan.", "Mode tagihan tidak diaktifkan pada tenant ini.")
    // while refusing the statuses whose message describes internals.
    toast.error(extractError(err) ?? t('tutoring2.admin.groupAddStudent.errorGeneric'));
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <FormSheet
    :title="t('tutoring2.admin.groupAddStudent.title')"
    :subtitle="t('tutoring2.admin.groupAddStudent.subtitle', { group: props.group.name })"
    :saving="isSaving"
    size="md"
    :save-label="t('tutoring2.admin.groupAddStudent.submit')"
    @save="submit"
    @cancel="emit('close')"
  >
    <div class="space-y-3">
      <FormField
        v-model="studentSearch"
        field="student_search"
        :label="t('tutoring2.admin.groupAddStudent.studentSearchLabel')"
        :disabled="isSaving"
        :placeholder="t('tutoring2.admin.groupAddStudent.studentSearchPh')"
      />

      <FormField
        v-model="studentId"
        type="select"
        field="student_id"
        :label="t('tutoring2.common.student')"
        :required="true"
        :disabled="isSaving"
        :options="studentOptions"
        :select-placeholder="t('tutoring2.admin.groupAddStudent.studentPh')"
        :error="errors.student_id"
      />

      <p v-if="studentsLoading" class="-mt-1 text-xs text-slate-500">
        {{ t('tutoring2.admin.groupAddStudent.loading') }}
      </p>
      <p
        v-else-if="studentOptions.length === 0"
        data-testid="students-none"
        class="-mt-1 text-xs text-slate-500"
      >
        {{ t('tutoring2.admin.groupAddStudent.studentsNone') }}
      </p>
      <template v-else>
        <p
          v-if="hiddenAlreadyEnrolled > 0"
          data-testid="students-already-enrolled"
          class="-mt-1 text-xs text-slate-500"
        >
          {{
            t('tutoring2.admin.groupAddStudent.studentsAlreadyEnrolled', {
              count: hiddenAlreadyEnrolled,
            })
          }}
        </p>
        <p
          v-if="studentsTruncated"
          data-testid="students-truncated"
          class="-mt-1 text-xs text-slate-500"
        >
          {{ t('tutoring2.admin.groupAddStudent.studentsTruncated') }}
        </p>
      </template>

      <FormField
        v-model="packageId"
        type="select"
        field="package_id"
        :label="t('tutoring2.admin.groupAddStudent.packageLabel')"
        :disabled="isSaving || packagesLoading"
        :options="packageOptions"
        :select-placeholder="t('tutoring2.admin.groupAddStudent.packagePh')"
      />

      <FormField
        v-model="billingMode"
        type="select"
        field="billing_mode"
        :label="t('tutoring2.common.billingMode')"
        :required="true"
        :disabled="isSaving"
        :options="billingModeOptions"
        :select-placeholder="t('tutoring2.admin.groupAddStudent.billingModePh')"
        :error="errors.billing_mode"
      />

      <p
        v-if="monthlyRateWarning"
        data-testid="monthly-rate-warning"
        class="-mt-1 text-xs text-amber-600"
      >
        {{ t('tutoring2.admin.groupAddStudent.monthlyRateHint') }}
      </p>

      <FormField
        v-model="startDate"
        type="date"
        field="start_date"
        :label="t('tutoring2.common.startDate')"
        :disabled="isSaving"
      />

      <p class="text-xs text-slate-500">
        {{ t('tutoring2.admin.groupAddStudent.trialNote') }}
      </p>
    </div>
  </FormSheet>
</template>
