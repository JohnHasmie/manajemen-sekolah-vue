<!--
  AdminTutoring2StudentCreateEditSheet.vue — WEB-11 · admin CRUD sheet
  for `/api/tutoring-v2/students*` (BE-18).

  Shape:
    - Wrapped in the shared `FormSheet` (Modal + sticky footer +
      Enter-to-submit). Same primitive `StudentEditSheet.vue` uses on
      the school side — a bimbel admin should feel the same seams.
    - Two tabs — **Identitas** (name/gender/dob/NIS) → **Wali**
      (guardian_{name,email,phone}). Simple in-modal tab strip so the
      admin sees the field set at a glance without scrolling.
    - Per-field 422 error mapping — Laravel's `errors: {field: [msg]}`
      envelope is flattened into `errors[name]='msg'` and rendered by
      FormField's `:error` prop. If the sheet is on the Identitas tab
      and the failing field lives on Wali (or vice versa), we auto-jump
      to the failing tab so the admin sees the red line without
      hunting.
    - Structured error codes — `email_conflict` + `already_teacher_here`
      surface as a top-of-sheet friendly banner (yellow warning tone).
      The greenfield BE doesn't raise these today (its wali attach is
      silent reuse), but keeping the FE ready means a future BE swap
      that DOES raise them is a one-line change.
    - Guardian temp password — when create returns a non-null
      `guardian_temp_password`, we show it once in the success toast
      so the admin can copy it to the wali. Post-Opsi B tenants get
      `null` and the toast just says "activation link dispatched".

  Modes: `student` prop `undefined` → create (POST); truthy → edit
  (PUT). Route action Nonaktifkan lives in the parent list view, not
  here, because deactivate reuses the shared `useConfirm()` dialog
  instead of a modal form.
-->
<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { useToast } from '@/composables/useToast';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type {
  BimbelStudent,
  BimbelStudentCreatePayload,
  BimbelStudentUpdatePayload,
} from '@/types/tutoring2/student';

const props = defineProps<{
  /** Edit target — `undefined` puts the sheet in create mode. */
  student?: BimbelStudent | null;
}>();

const emit = defineEmits<{
  close: [];
  /** Fires after a successful create/update — parent reloads its list. */
  saved: [student: BimbelStudent];
}>();

const { t } = useI18n();
const toast = useToast();

const isEdit = computed(() => Boolean(props.student?.id));

const title = computed(() =>
  isEdit.value
    ? t('tutoring2.admin.students.editTitle')
    : t('tutoring2.admin.students.createTitle'),
);
const subtitle = computed(() =>
  isEdit.value
    ? t('tutoring2.admin.students.editSubtitle')
    : t('tutoring2.admin.students.createSubtitle'),
);

// ── Form state ─────────────────────────────────────────────────────

/**
 * Reactive form model. Every field is a string (or empty string) so
 * the FormField inputs stay controlled — the payload builder coerces
 * empties to null before POST/PUT so the BE `nullable` rules match.
 */
const form = reactive({
  name: props.student?.name ?? '',
  student_number: props.student?.student_number ?? '',
  nisn: props.student?.nisn ?? '',
  gender: (props.student?.gender as string | null | undefined) ?? '',
  place_of_birth: props.student?.place_of_birth ?? '',
  date_of_birth: props.student?.date_of_birth ?? '',
  address: props.student?.address ?? '',
  phone_number: props.student?.phone_number ?? '',
  guardian_name: props.student?.guardian_name ?? '',
  guardian_email: props.student?.guardian_email ?? '',
  guardian_phone: props.student?.guardian_phone ?? '',
});

/** Per-field validation / 422 messages, keyed by wire name. */
const errors = reactive<Record<string, string>>({});

/** Top-of-sheet banner for structured error codes (see file header). */
const bannerMessage = ref<string>('');

const isSaving = ref(false);

// ── Tabs ───────────────────────────────────────────────────────────

type TabKey = 'identity' | 'wali';
const activeTab = ref<TabKey>('identity');

/**
 * Which tab each field lives on. Used by the 422 handler to jump the
 * admin to the failing tab — otherwise a red error line under a
 * hidden field looks like nothing happened.
 */
const FIELD_TAB: Record<string, TabKey> = {
  name: 'identity',
  student_number: 'identity',
  nisn: 'identity',
  gender: 'identity',
  place_of_birth: 'identity',
  date_of_birth: 'identity',
  address: 'identity',
  phone_number: 'identity',
  guardian_name: 'wali',
  guardian_email: 'wali',
  guardian_phone: 'wali',
};

const identityHasError = computed(() =>
  Object.keys(errors).some((k) => FIELD_TAB[k] === 'identity'),
);
const waliHasError = computed(() =>
  Object.keys(errors).some((k) => FIELD_TAB[k] === 'wali'),
);

// ── Select options (localised) ─────────────────────────────────────

const genderOptions = computed<FormFieldOption[]>(() => [
  { value: 'male', label: t('admin.gender.male') },
  { value: 'female', label: t('admin.gender.female') },
]);

// Re-hydrate when the parent swaps the edit target between opens
// (e.g. clicks "Edit" on a different row without closing the sheet
// first). Prop-driven `reactive` state doesn't self-refresh in Vue.
watch(
  () => props.student?.id,
  () => {
    Object.assign(form, {
      name: props.student?.name ?? '',
      student_number: props.student?.student_number ?? '',
      nisn: props.student?.nisn ?? '',
      gender: (props.student?.gender as string | null | undefined) ?? '',
      place_of_birth: props.student?.place_of_birth ?? '',
      date_of_birth: props.student?.date_of_birth ?? '',
      address: props.student?.address ?? '',
      phone_number: props.student?.phone_number ?? '',
      guardian_name: props.student?.guardian_name ?? '',
      guardian_email: props.student?.guardian_email ?? '',
      guardian_phone: props.student?.guardian_phone ?? '',
    });
    for (const k of Object.keys(errors)) delete errors[k];
    bannerMessage.value = '';
    activeTab.value = 'identity';
  },
);

// ── Client-side validation ─────────────────────────────────────────

/** Trim + drop empty-string fields (BE `nullable` rules) → coerce to null. */
function nz(v: string): string | null {
  const t = v.trim();
  return t === '' ? null : t;
}

function validate(): boolean {
  for (const k of Object.keys(errors)) delete errors[k];

  if (!form.name.trim()) {
    errors.name = t('tutoring2.admin.students.form.nameRequired');
  }
  if (!isEdit.value && !form.gender) {
    // Only enforced on create — edit sends a partial PUT and the BE
    // `sometimes` rule tolerates a missing gender on updates.
    errors.gender = t('tutoring2.admin.students.form.genderRequired');
  }
  if (!form.guardian_name.trim()) {
    errors.guardian_name = t('tutoring2.admin.students.form.guardianNameRequired');
  }
  if (!isEdit.value) {
    // Guardian email is required on create (needed to attach the wali
    // user); on edit, PUT accepts a nullable email.
    const emailNorm = form.guardian_email.trim();
    if (!emailNorm) {
      errors.guardian_email = t('tutoring2.admin.students.form.guardianEmailRequired');
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) {
      errors.guardian_email = t('tutoring2.admin.students.form.guardianEmailInvalid');
    }
  } else if (form.guardian_email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.guardian_email.trim())) {
    // On edit, only validate format when the field is non-empty.
    errors.guardian_email = t('tutoring2.admin.students.form.guardianEmailInvalid');
  }

  // If any error landed on a tab that isn't visible, jump to it so
  // the admin actually sees the red line.
  const firstBadField = Object.keys(errors)[0];
  if (firstBadField && FIELD_TAB[firstBadField] !== activeTab.value) {
    activeTab.value = FIELD_TAB[firstBadField] ?? activeTab.value;
  }

  return Object.keys(errors).length === 0;
}

// ── Payload builders ───────────────────────────────────────────────

function buildCreatePayload(): BimbelStudentCreatePayload {
  return {
    name: form.name.trim(),
    student_number: nz(form.student_number),
    nisn: nz(form.nisn),
    gender: form.gender as 'male' | 'female',
    place_of_birth: nz(form.place_of_birth),
    date_of_birth: nz(form.date_of_birth),
    address: nz(form.address),
    phone_number: nz(form.phone_number),
    guardian_name: form.guardian_name.trim(),
    guardian_email: form.guardian_email.trim(),
    guardian_phone: nz(form.guardian_phone),
  };
}

function buildUpdatePayload(): BimbelStudentUpdatePayload {
  // `student_number` is intentionally NOT sent — it's create-only per
  // UpdateStudentRequest. Sending it would be silently dropped by the
  // `sometimes` filter but keeping it out makes the wire cleaner.
  return {
    name: form.name.trim(),
    nisn: nz(form.nisn),
    gender: form.gender ? (form.gender as 'male' | 'female') : undefined,
    place_of_birth: nz(form.place_of_birth),
    date_of_birth: nz(form.date_of_birth),
    address: nz(form.address),
    phone_number: nz(form.phone_number),
    guardian_name: form.guardian_name.trim() || undefined,
    guardian_email: nz(form.guardian_email),
    guardian_phone: nz(form.guardian_phone),
  };
}

// ── 422 mapper ─────────────────────────────────────────────────────

/**
 * Flatten Laravel's `errors: {field: [msg, ...]}` into
 * `errors[field]='msg'`. Also handles the structured `code: X`
 * payload the wali-attach path may return.
 */
function applyServerError(err: unknown): void {
  const anyErr = err as {
    response?: {
      status?: number;
      data?: {
        message?: string;
        errors?: Record<string, string[]>;
        code?: string;
        error?: string;
      };
    };
    message?: string;
  };
  const status = anyErr?.response?.status;
  const body = anyErr?.response?.data;

  // Structured code first — routes to the banner, not per-field.
  const code = body?.code;
  if (code === 'email_conflict') {
    bannerMessage.value = t('tutoring2.admin.students.errors.emailConflict');
    activeTab.value = 'wali';
    return;
  }
  if (code === 'already_teacher_here') {
    bannerMessage.value = t('tutoring2.admin.students.errors.alreadyTeacherHere');
    activeTab.value = 'wali';
    return;
  }

  // Standard Laravel 422 with per-field bag.
  if (status === 422 && body?.errors) {
    for (const [field, msgs] of Object.entries(body.errors)) {
      const first = Array.isArray(msgs) ? msgs[0] : String(msgs);
      if (first) errors[field] = first;
    }
    const badField = Object.keys(body.errors)[0];
    if (badField && FIELD_TAB[badField] && FIELD_TAB[badField] !== activeTab.value) {
      activeTab.value = FIELD_TAB[badField];
    }
    // Also surface the generic message as a toast so the admin knows
    // there's a validation error even if every failing field is
    // already visible.
    toast.error(body.message ?? t('common.error'));
    return;
  }

  // Fallback — surface whatever we've got as a toast + banner.
  const msg = body?.message ?? anyErr?.message ?? t('common.error');
  bannerMessage.value = msg;
  toast.error(msg);
}

// ── Submit ─────────────────────────────────────────────────────────

async function submit(): Promise<void> {
  bannerMessage.value = '';
  if (!validate()) return;
  if (isSaving.value) return;
  isSaving.value = true;
  try {
    if (isEdit.value && props.student?.id) {
      const updated = await TutoringStudentsService.update(
        props.student.id,
        buildUpdatePayload(),
      );
      toast.success(t('tutoring2.admin.students.updateSuccess'));
      emit('saved', updated);
      emit('close');
    } else {
      const res = await TutoringStudentsService.create(buildCreatePayload());
      // One-time show the temp password when a fresh wali user was
      // minted; otherwise a plain success toast is enough.
      if (res.guardian_temp_password) {
        toast.success(
          t('tutoring2.admin.students.createSuccessWithPassword', {
            password: res.guardian_temp_password,
          }),
          10_000,
        );
      } else {
        toast.success(t('tutoring2.admin.students.createSuccess'));
      }
      emit('saved', res.data);
      emit('close');
    }
  } catch (err) {
    applyServerError(err);
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <FormSheet
    :title="title"
    :subtitle="subtitle"
    :saving="isSaving"
    size="lg"
    :save-label="isEdit ? t('common.saveChanges') : t('tutoring2.admin.students.createCta')"
    @save="submit"
    @cancel="emit('close')"
  >
    <!-- Structured error banner (email_conflict / already_teacher_here). -->
    <div
      v-if="bannerMessage"
      role="alert"
      class="rounded-2xl border border-amber-200 bg-amber-50 px-md py-sm text-sm text-amber-800"
    >
      {{ bannerMessage }}
    </div>

    <!-- Tab strip — Identitas / Wali. -->
    <div class="flex gap-2 border-b border-slate-200">
      <button
        type="button"
        class="px-md py-sm text-sm font-semibold border-b-2 transition-colors"
        :class="activeTab === 'identity'
          ? 'border-brand-cobalt text-brand-cobalt'
          : 'border-transparent text-slate-500 hover:text-slate-700'"
        @click="activeTab = 'identity'"
      >
        {{ t('tutoring2.admin.students.form.tabIdentity') }}
        <span
          v-if="identityHasError"
          class="ml-1 inline-block h-1.5 w-1.5 rounded-full bg-status-danger"
          aria-hidden="true"
        ></span>
      </button>
      <button
        type="button"
        class="px-md py-sm text-sm font-semibold border-b-2 transition-colors"
        :class="activeTab === 'wali'
          ? 'border-brand-cobalt text-brand-cobalt'
          : 'border-transparent text-slate-500 hover:text-slate-700'"
        @click="activeTab = 'wali'"
      >
        {{ t('tutoring2.admin.students.form.tabWali') }}
        <span
          v-if="waliHasError"
          class="ml-1 inline-block h-1.5 w-1.5 rounded-full bg-status-danger"
          aria-hidden="true"
        ></span>
      </button>
    </div>

    <!-- ── Tab: Identitas ─────────────────────────────────────────── -->
    <div v-if="activeTab === 'identity'" class="space-y-md">
      <FormField
        v-model="form.name"
        :label="t('common.fullName')"
        :required="true"
        :disabled="isSaving"
        :error="errors.name"
      />

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <FormField
          v-model="form.student_number"
          :label="t('tutoring2.admin.students.form.studentNumber')"
          :disabled="isSaving || isEdit"
          :error="errors.student_number"
          :placeholder="isEdit ? t('tutoring2.admin.students.form.studentNumberLocked') : ''"
        />
        <FormField
          v-model="form.nisn"
          :label="t('tutoring2.admin.students.form.nisn')"
          :disabled="isSaving"
          :error="errors.nisn"
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <FormField
          v-model="form.gender"
          type="select"
          :label="t('common.gender')"
          :required="!isEdit"
          :select-placeholder="t('common.selectPlaceholder')"
          :options="genderOptions"
          :disabled="isSaving"
          :error="errors.gender"
        />
        <FormField :label="t('common.dateOfBirth')">
          <input
            v-model="form.date_of_birth"
            type="date"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
        </FormField>
      </div>

      <FormField
        v-model="form.place_of_birth"
        :label="t('tutoring2.admin.students.form.placeOfBirth')"
        :disabled="isSaving"
        :error="errors.place_of_birth"
      />

      <FormField
        v-model="form.phone_number"
        type="tel"
        :label="t('common.phoneNumber')"
        :disabled="isSaving"
        :error="errors.phone_number"
      />

      <FormField
        v-model="form.address"
        type="textarea"
        :label="t('common.address')"
        :rows="2"
        :disabled="isSaving"
        :error="errors.address"
      />
    </div>

    <!-- ── Tab: Wali ──────────────────────────────────────────────── -->
    <div v-else class="space-y-md">
      <p class="text-xs text-slate-500">
        {{ t('tutoring2.admin.students.form.waliHint') }}
      </p>

      <FormField
        v-model="form.guardian_name"
        :label="t('tutoring2.admin.students.form.waliName')"
        :required="true"
        :disabled="isSaving"
        :error="errors.guardian_name"
      />

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
        <FormField
          v-model="form.guardian_email"
          type="email"
          :label="t('tutoring2.admin.students.form.waliEmail')"
          :required="!isEdit"
          :disabled="isSaving"
          :error="errors.guardian_email"
          :placeholder="t('tutoring2.admin.students.form.waliEmailPlaceholder')"
        />
        <FormField
          v-model="form.guardian_phone"
          type="tel"
          :label="t('tutoring2.admin.students.form.waliPhone')"
          :disabled="isSaving"
          :error="errors.guardian_phone"
        />
      </div>

      <p v-if="!isEdit" class="text-xs text-slate-400">
        {{ t('tutoring2.admin.students.form.waliCreateNote') }}
      </p>
    </div>
  </FormSheet>
</template>
