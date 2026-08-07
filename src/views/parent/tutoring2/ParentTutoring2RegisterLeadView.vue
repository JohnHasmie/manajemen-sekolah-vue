<!--
  ParentTutoring2RegisterLeadView.vue — wali registers a prospective
  child ("daftar calon siswa") — CLEAN-2 Phase 2 greenfield replacement
  for the legacy `parent/tutoring/ParentRegisterLeadView.vue`.

  Route: /parent/tutoring2/register-lead
  Endpoints:
    POST /tutoring-v2/leads                — create the lead
    GET  /tutoring-v2/programs             — interest-program picker
                                             (only when the caller may
                                             read programs, see below)

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. CREATE ONLY. `TutoringLeadsService` also exposes convert / drop /
     update / destroy. Those are ADMIN funnel actions: a wali who could
     convert their own lead would be self-enrolling a child (and minting
     a bill) with no staff in the loop. This view deliberately imports
     nothing but `create`. Do not "helpfully" add a convert button here.

  2. No grade / school columns exist on the greenfield `bimbel_leads`
     table (name, phone, email, source, interest_program_id, status,
     notes). Same as v1, those answers are folded into the free-text
     `notes` field. If they should become first-class columns that is a
     backend migration + LeadResource change, not a frontend workaround.

  3. `source` is a closed BE enum (website|walkin|referral|whatsapp|
     other) and is REQUIRED by StoreLeadRequest. A wali self-registering
     through the app is by definition an inbound web signup, so we send
     `'website'` and do not show a picker — the funnel source is a
     staff-facing attribution attribute, not something the parent should
     be asked to classify.

  ⚠️ V2 ABILITY GAP (verified against PermissionCatalog::
     parentTutoringDefaults() + LeadController/ProgramController):

     - POST /tutoring-v2/leads gates on `tutoring.lead.manage`
     - GET  /tutoring-v2/programs gates on `tutoring.program.view`

     The wali default ability set holds NEITHER. The legacy v1
     controllers (TutoringLegacy\...\TutoringLeadController /
     TutoringProgramController) had no `authorize()` call at all, which
     is the only reason the legacy screen worked for a parent — an authz
     hole, not a feature.

     Rather than ship a form that 403s on submit, this view gates on the
     caller's real abilities (`/me`-scoped, per the standing rule) and
     explains the situation. The backend fix is to grant the wali a
     narrow write key — e.g. a new `tutoring.lead.create_own` on
     LeadController::store plus `tutoring.program.view` (or a public
     program catalogue endpoint) — reported under V2_GAPS.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { useAuthStore } from '@/stores/auth';
import { TutoringLeadsService } from '@/services/tutoring2/leads';
import {
  TutoringBimbelService,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';
import type { CreateLeadPayload } from '@/types/tutoring2/lead';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();
const auth = useAuthStore();

// ── Ability gates ─────────────────────────────────────────────────
// Gated on `/me` abilities (X-Active-Role-scoped) — never on
// roles[].permission_keys, which is unscoped and only feeds the role
// switcher.
const canCreateLead = computed(() => auth.hasAbility('tutoring.lead.manage'));
const canViewPrograms = computed(() => auth.hasAbility('tutoring.program.view'));

// ── Form state ────────────────────────────────────────────────────
interface LeadForm {
  childName: string;
  phone: string;
  email: string;
  /** Numeric grade level 1..12, '' when unanswered. Folded into notes. */
  gradeLevel: string;
  schoolName: string;
  programId: string;
  notes: string;
}

function emptyForm(): LeadForm {
  return {
    childName: '',
    phone: '',
    email: '',
    gradeLevel: '',
    schoolName: '',
    programId: '',
    notes: '',
  };
}

const form = reactive<LeadForm>(emptyForm());
const saving = ref(false);
const submitError = ref<string | null>(null);

const DRAFT_KEY = 'parent.tutoring2.registerLead.draft';

// ── Grade options ─────────────────────────────────────────────────
// Identifiers stay English/numeric; only the rendered label is
// localised (id.json holds "Kelas {grade} {stage}").
const GRADE_LEVELS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as const;

function stageLabel(grade: number): string {
  if (grade <= 6) return t('tutoring2.parent.registerLead.stagePrimary');
  if (grade <= 9) return t('tutoring2.parent.registerLead.stageJunior');
  return t('tutoring2.parent.registerLead.stageSenior');
}

const gradeOptions = computed<FormFieldOption[]>(() =>
  GRADE_LEVELS.map((grade) => ({
    value: String(grade),
    label: t('tutoring2.parent.registerLead.gradeLabel', {
      grade,
      stage: stageLabel(grade),
    }),
  })),
);

// ── Programs (interest picker) ────────────────────────────────────
// Skipped entirely when the caller cannot read the catalogue, so we
// don't fire a request we know 403s. `interest_program_id` is optional
// on StoreLeadRequest, so the lead is still creatable without it.
const { state: programsState, reload: reloadPrograms } = useDataRefresh(
  async () => {
    if (!canViewPrograms.value) return [];
    const { items } = await TutoringBimbelService.listPrograms({
      status: 'active',
      per_page: 100,
    });
    return items;
  },
);

const programs = computed<BimbelProgram[]>(() =>
  programsState.value.status === 'content'
    ? ((programsState.value.data as BimbelProgram[] | undefined) ?? [])
    : [],
);

// ── Draft persistence (client-side only, same as the legacy view) ──
onMounted(() => {
  try {
    const raw = localStorage.getItem(DRAFT_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw) as Partial<LeadForm>;
    Object.assign(form, { ...emptyForm(), ...parsed });
  } catch {
    // A corrupt draft must never block the form — start empty.
  }
});

function saveDraft() {
  try {
    // `form` is a reactive proxy; JSON.stringify walks it fine, but a
    // structuredClone would throw (see reference_vue_structuredclone_reactive).
    localStorage.setItem(DRAFT_KEY, JSON.stringify({ ...form }));
    toast.success(t('tutoring2.parent.registerLead.draftSaved'));
  } catch {
    toast.error(t('tutoring2.parent.registerLead.draftFailed'));
  }
}

function clearDraft() {
  try {
    localStorage.removeItem(DRAFT_KEY);
  } catch {
    // Non-fatal: the lead is already created server-side.
  }
}

// ── Validation + submit ───────────────────────────────────────────
const canSubmit = computed(
  () => canCreateLead.value && form.childName.trim().length >= 2 && !saving.value,
);

/**
 * Fold the answers the greenfield lead table has no column for into the
 * free-text `notes` payload — identical strategy to the legacy view.
 */
function composeNotes(): string | null {
  const gradeText = form.gradeLevel
    ? t('tutoring2.parent.registerLead.noteGrade', {
        value: t('tutoring2.parent.registerLead.gradeLabel', {
          grade: form.gradeLevel,
          stage: stageLabel(Number(form.gradeLevel)),
        }),
      })
    : '';
  const schoolText = form.schoolName.trim()
    ? t('tutoring2.parent.registerLead.noteSchool', { value: form.schoolName.trim() })
    : '';
  const freeText = form.notes.trim()
    ? t('tutoring2.parent.registerLead.noteExtra', { value: form.notes.trim() })
    : '';
  const joined = [gradeText, schoolText, freeText].filter(Boolean).join(' · ');
  return joined || null;
}

async function submit() {
  if (!canSubmit.value) return;
  saving.value = true;
  submitError.value = null;
  const payload: CreateLeadPayload = {
    name: form.childName.trim(),
    phone: form.phone.trim() || null,
    email: form.email.trim() || null,
    // See contract note 3 — closed BE enum, inbound app signup.
    source: 'website',
    interest_program_id: form.programId || null,
    notes: composeNotes(),
  };
  try {
    await TutoringLeadsService.create(payload);
    Object.assign(form, emptyForm());
    clearDraft();
    toast.success(t('tutoring2.parent.registerLead.submitSuccess'));
  } catch (e: unknown) {
    const err = e as { response?: { status?: number; data?: { message?: string } } };
    submitError.value =
      err?.response?.status === 403
        ? t('tutoring2.parent.registerLead.forbidden')
        : (err?.response?.data?.message ??
          t('tutoring2.parent.registerLead.submitFailed'));
  } finally {
    saving.value = false;
  }
}

function cancel() {
  router.back();
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.registerLead.title')"
      :meta="t('tutoring2.parent.registerLead.meta')"
    />

    <!--
      Ability wall. The wali default role does not hold
      `tutoring.lead.manage`, so rendering an enabled form would produce
      a guaranteed 403 on submit. Show the honest explanation instead.
    -->
    <div
      v-if="!canCreateLead"
      class="rounded-3xl border border-slate-100 bg-white p-6 text-center shadow-sm"
    >
      <p class="text-sm font-bold text-slate-900">
        {{ t('tutoring2.parent.registerLead.noPermissionTitle') }}
      </p>
      <p class="mt-2 text-2xs text-slate-500">
        {{ t('tutoring2.parent.registerLead.noPermissionDesc') }}
      </p>
    </div>

    <form v-else class="space-y-md" @submit.prevent="submit">
      <section class="space-y-3 rounded-3xl border border-slate-100 bg-white p-5 shadow-sm">
        <h2 class="text-2xs font-bold uppercase tracking-wide text-slate-400">
          {{ t('tutoring2.parent.registerLead.childSection') }}
        </h2>

        <FormField
          v-model="form.childName"
          field="child_name"
          type="text"
          required
          :label="t('tutoring2.parent.registerLead.childNameLabel')"
          :placeholder="t('tutoring2.parent.registerLead.childNamePh')"
        />

        <div class="grid gap-3 sm:grid-cols-2">
          <FormField
            v-model="form.gradeLevel"
            field="grade_level"
            type="select"
            :label="t('tutoring2.parent.registerLead.gradeFieldLabel')"
            :options="gradeOptions"
            :select-placeholder="t('tutoring2.parent.registerLead.gradePh')"
          />
          <FormField
            v-model="form.schoolName"
            field="school_name"
            type="text"
            :label="t('tutoring2.parent.registerLead.schoolLabel')"
            :placeholder="t('tutoring2.parent.registerLead.schoolPh')"
          />
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <FormField
            v-model="form.phone"
            field="phone"
            type="tel"
            :label="t('tutoring2.parent.registerLead.phoneLabel')"
            :placeholder="t('tutoring2.parent.registerLead.phonePh')"
          />
          <FormField
            v-model="form.email"
            field="email"
            type="email"
            :label="t('tutoring2.parent.registerLead.emailLabel')"
            :placeholder="t('tutoring2.parent.registerLead.emailPh')"
          />
        </div>
      </section>

      <!--
        Interest program. Hidden outright when the caller cannot read
        `/tutoring-v2/programs` — the field is optional on the BE request
        so the lead still submits without it.
      -->
      <section
        v-if="canViewPrograms"
        class="space-y-3 rounded-3xl border border-slate-100 bg-white p-5 shadow-sm"
      >
        <h2 class="text-2xs font-bold uppercase tracking-wide text-slate-400">
          {{ t('tutoring2.parent.registerLead.programSection') }}
        </h2>

        <AsyncView
          :state="programsState"
          loading-variant="list"
          :loading-rows="3"
          :empty-title="t('tutoring2.parent.registerLead.programsEmptyTitle')"
          :empty-description="t('tutoring2.parent.registerLead.programsEmptyDesc')"
          @retry="reloadPrograms"
        >
          <template #default>
            <ul class="space-y-2">
              <li v-for="p in programs" :key="p.id">
                <button
                  type="button"
                  class="flex w-full items-center gap-3 rounded-2xl border px-4 py-3 text-left transition-colors"
                  :class="
                    form.programId === p.id
                      ? 'border-brand-azure bg-brand-azure/5'
                      : 'border-slate-200 hover:bg-slate-50'
                  "
                  @click="form.programId = form.programId === p.id ? '' : p.id"
                >
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm font-bold text-slate-900">{{ p.name }}</p>
                    <p class="truncate text-2xs text-slate-500">
                      {{ p.description || p.grade_level || t('tutoring2.common.notAvailable') }}
                    </p>
                  </div>
                  <span
                    class="h-4 w-4 shrink-0 rounded-full border-2"
                    :class="
                      form.programId === p.id
                        ? 'border-brand-azure bg-brand-azure/30'
                        : 'border-slate-300'
                    "
                  ></span>
                </button>
              </li>
            </ul>
          </template>
        </AsyncView>
      </section>

      <section class="space-y-3 rounded-3xl border border-slate-100 bg-white p-5 shadow-sm">
        <h2 class="text-2xs font-bold uppercase tracking-wide text-slate-400">
          {{ t('tutoring2.parent.registerLead.notesSection') }}
        </h2>
        <FormField
          v-model="form.notes"
          field="notes"
          type="textarea"
          :rows="3"
          :placeholder="t('tutoring2.parent.registerLead.notesPh')"
        />
      </section>

      <p v-if="submitError" class="text-xs text-status-danger">{{ submitError }}</p>

      <div class="flex gap-3">
        <Button variant="ghost" size="sm" @click="cancel">
          {{ t('tutoring2.common.cancel') }}
        </Button>
        <Button variant="secondary" size="sm" @click="saveDraft">
          {{ t('tutoring2.parent.registerLead.saveDraft') }}
        </Button>
        <Button
          type="submit"
          variant="primary"
          size="sm"
          class="flex-1"
          :disabled="!canSubmit"
          :loading="saving"
        >
          {{ t('tutoring2.parent.registerLead.submit') }}
        </Button>
      </div>
    </form>
  </div>
</template>
