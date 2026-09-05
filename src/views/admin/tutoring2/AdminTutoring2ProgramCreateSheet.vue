<!--
  AdminTutoring2ProgramCreateSheet.vue — the create surface for a bimbel
  program (`POST /tutoring-v2/programs`, BE-2).

  Why it exists: AdminTutoring2ProgramsView rendered a floating
  "+ Program baru" CTA that was DISABLED on purpose, because web-vue had
  never had a program create surface — `TutoringBimbelService.createProgram`
  wrapped a live endpoint with zero call sites. This is that missing
  surface, so the CTA can stop apologising and start working.

  Shape mirrors <AdminTutoring2GroupCreateSheet> — the house pattern for
  "floating CTA on a list view opens a FormSheet" — with the richer error
  handling of <AdminTutoring2StudentCreateEditSheet>: a 422 maps onto the
  field that failed, and anything else lands in a banner INSIDE the sheet.
  A failed create must never close the form or vanish into a toast the
  admin can miss.

  ── FIELD SET: read off StoreProgramRequest, not guessed ──────────────

    name        required · string · max 120
    grade_level nullable · string · max 16   (free text on the BE; the
                migration documents "SD / SMP / SMA / Umum", so that is a
                placeholder HINT here, not an invented enum)
    description nullable · string · max 2000
    status      nullable · draft|active|archived · server-defaults to draft

  `status` is offered even though the server would default it, because
  web-vue has NO program edit surface: a program created as Draft could
  never be activated from the web again. Only draft/active are offered —
  archiving is its own lifecycle endpoint (`POST …/archive`), not a
  starting state.

  ── The duplicate-name trap ───────────────────────────────────────────

  `bimbel_programs` carries a partial unique index on
  (school_id, LOWER(name)) WHERE deleted_at IS NULL, but StoreProgramRequest
  has NO `unique` rule — so a duplicate name is a Postgres 23505 that
  surfaces as a 500, not a 422. The mapper below recognises that shape and
  says "the name is taken" instead of showing the admin a SQL error (or,
  with APP_DEBUG off, a bare "Server Error"). The real fix belongs in the
  FormRequest; this is the client half of it.
-->
<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';

const emit = defineEmits<{
  close: [];
  /** Fires after a successful POST — the parent list reloads. */
  saved: [program: BimbelProgram];
}>();

const { t } = useI18n();
const toast = useToast();

/** Mirrors StoreProgramRequest's `max:` rules so the sheet refuses first. */
const MIN_NAME_LENGTH = 3;
const MAX_NAME_LENGTH = 120;
const MAX_GRADE_LEVEL_LENGTH = 16;
const MAX_DESCRIPTION_LENGTH = 2000;

const form = reactive({
  name: '',
  grade_level: '',
  description: '',
  /** Server default. Kept explicit so the select has a real initial value. */
  status: 'draft' as 'draft' | 'active',
});

/** Per-field messages, keyed by WIRE name so a 422 bag maps straight in. */
const errors = reactive<Record<string, string>>({});

/** In-sheet banner for anything that is not a per-field 422. */
const bannerMessage = ref('');

const isSaving = ref(false);

const statusOptions = computed<FormFieldOption[]>(() => [
  { value: 'draft', label: t('tutoring2.status.draft') },
  { value: 'active', label: t('tutoring2.status.active') },
]);

/** Trim, then coerce an empty string to null for the BE `nullable` rules. */
function nz(v: string): string | null {
  const trimmed = v.trim();
  return trimmed === '' ? null : trimmed;
}

function clearErrors(): void {
  for (const k of Object.keys(errors)) delete errors[k];
}

function validate(): boolean {
  clearErrors();

  const name = form.name.trim();
  if (name.length < MIN_NAME_LENGTH) {
    errors.name = t('tutoring2.admin.programCreate.errName');
  } else if (name.length > MAX_NAME_LENGTH) {
    errors.name = t('tutoring2.admin.programCreate.errNameTooLong');
  }
  if (form.grade_level.trim().length > MAX_GRADE_LEVEL_LENGTH) {
    errors.grade_level = t('tutoring2.admin.programCreate.errGradeLevelTooLong');
  }
  if (form.description.trim().length > MAX_DESCRIPTION_LENGTH) {
    errors.description = t('tutoring2.admin.programCreate.errDescriptionTooLong');
  }

  return Object.keys(errors).length === 0;
}

/**
 * Is this the (school_id, LOWER(name)) unique index firing? The BE lets
 * the QueryException through, so the shape depends on APP_DEBUG: with it
 * on we get the raw SQLSTATE text, with it off a bare 500. Only the
 * former is identifiable, so the fallback stays the generic message.
 */
function isDuplicateNameError(status: number | undefined, raw: string): boolean {
  if (status !== undefined && status !== 500) return false;
  return (
    raw.includes('bimbel_programs_school_name_uniq') ||
    (raw.includes('23505') && raw.toLowerCase().includes('bimbel_programs'))
  );
}

/**
 * Put the server's own words in front of the admin. Laravel sends
 * `errors: {field: [msg]}` on a 422; anything else becomes the banner.
 * Nothing is swallowed — an unrecognised failure still shows its text.
 */
function applyServerError(err: unknown): void {
  const anyErr = err as {
    response?: {
      status?: number;
      data?: { message?: string; errors?: Record<string, string[]> };
    };
    message?: string;
  };
  const status = anyErr?.response?.status;
  const body = anyErr?.response?.data;

  if (status === 422 && body?.errors) {
    for (const [field, msgs] of Object.entries(body.errors)) {
      const first = Array.isArray(msgs) ? msgs[0] : String(msgs);
      if (first) errors[field] = first;
    }
    bannerMessage.value =
      body.message ?? t('tutoring2.admin.programCreate.errorGeneric');
    return;
  }

  const raw = `${body?.message ?? ''} ${anyErr?.message ?? ''}`;
  if (isDuplicateNameError(status, raw)) {
    errors.name = t('tutoring2.admin.programCreate.errDuplicate');
    bannerMessage.value = t('tutoring2.admin.programCreate.errDuplicate');
    return;
  }

  bannerMessage.value =
    body?.message ??
    anyErr?.message ??
    t('tutoring2.admin.programCreate.errorGeneric');
}

async function submit(): Promise<void> {
  if (isSaving.value) return;
  bannerMessage.value = '';
  if (!validate()) return;
  isSaving.value = true;
  try {
    const program = await TutoringBimbelService.createProgram({
      name: form.name.trim(),
      grade_level: nz(form.grade_level),
      description: nz(form.description),
      status: form.status,
    });
    toast.success(t('tutoring2.admin.programCreate.success'));
    emit('saved', program);
    emit('close');
  } catch (err) {
    // The sheet STAYS OPEN on failure, holding what the admin typed.
    applyServerError(err);
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <FormSheet
    :title="t('tutoring2.admin.programCreate.title')"
    :subtitle="t('tutoring2.admin.programCreate.subtitle')"
    :saving="isSaving"
    size="md"
    :save-label="t('tutoring2.admin.programCreate.submit')"
    @save="submit"
    @cancel="emit('close')"
  >
    <div
      v-if="bannerMessage"
      role="alert"
      data-testid="program-create-error"
      class="rounded-2xl border border-red-200 bg-red-50 px-md py-sm text-sm text-red-700"
    >
      {{ bannerMessage }}
    </div>

    <FormField
      v-model="form.name"
      field="name"
      :label="t('tutoring2.admin.programCreate.nameLabel')"
      :required="true"
      :disabled="isSaving"
      :placeholder="t('tutoring2.admin.programCreate.namePh')"
      :error="errors.name"
    />

    <FormField
      v-model="form.grade_level"
      field="grade_level"
      :label="t('tutoring2.common.gradeLevel')"
      :disabled="isSaving"
      :placeholder="t('tutoring2.admin.programCreate.gradeLevelPh')"
      :error="errors.grade_level"
    />

    <FormField
      v-model="form.status"
      type="select"
      field="status"
      :label="t('tutoring2.admin.programCreate.statusLabel')"
      :disabled="isSaving"
      :options="statusOptions"
      :error="errors.status"
    />
    <p class="-mt-2 text-xs text-slate-500">
      {{ t('tutoring2.admin.programCreate.statusHint') }}
    </p>

    <FormField
      v-model="form.description"
      type="textarea"
      field="description"
      :rows="3"
      :label="t('tutoring2.admin.programCreate.descriptionLabel')"
      :disabled="isSaving"
      :placeholder="t('tutoring2.admin.programCreate.descriptionPh')"
      :error="errors.description"
    />
  </FormSheet>
</template>
