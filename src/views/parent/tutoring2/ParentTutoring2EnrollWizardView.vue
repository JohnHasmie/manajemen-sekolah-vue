<!--
  ParentTutoring2EnrollWizardView.vue — the wali's self-service
  enrollment wizard for one child (CLEAN-2 Phase 2 · greenfield
  replacement for the legacy `parent/tutoring/ParentEnrollWizardView.vue`).

  Route: /parent/tutoring2/enroll/:studentId
  Endpoints (all `/tutoring-v2/*`):
    GET  /tutoring-v2/enrollments?student_id=       — child identity + context
    GET  /tutoring-v2/programs                      — step 1 options
    GET  /tutoring-v2/programs/{id}/packages        — step 2 options
    POST /tutoring-v2/enrollments                   — final submit

  Child scope: `:studentId` route param, same mechanism as every other
  parent/tutoring2 view (see ParentTutoring2AttendanceView). The child's
  display name is read off their existing enrollment rows, which is the
  only wali-readable source of it — `/tutoring-v2/students` is gated on
  the admin-only `tutoring.student.view`.

  ⚠️ AUTHORIZATION GAP — the headline contract difference. Read this
  before assuming the screen is broken:

    The legacy v1 controllers behind this wizard
    (TutoringProgramController / TutoringPackageController /
    TutoringEnrollmentController) contain ZERO `authorize()` calls —
    verified by `grep -c "authorize(" ` returning 0 for all three. That
    is why a wali could drive the v1 wizard at all.

    The v2 controllers are properly gated:
      GET  /programs                → tutoring.program.view
      GET  /programs/{id}/packages  → tutoring.package.view
      POST /enrollments             → tutoring.enrollment.manage

    None of those three keys are in `PermissionCatalog::
    parentTutoringDefaults()` — the wali role holds only the `_view_own`
    read twins. So on a default tenant this screen 403s for its intended
    audience until a backend MR either (a) adds the three keys to the
    wali defaults, or (b) ships wali-scoped self-service twins
    (`tutoring.program.view_public`, `tutoring.enrollment.request`).

    Rather than fabricate a catalogue or point a button at an endpoint
    that will reject it, the view detects the 403 and renders an explicit
    "not permitted yet" panel naming the missing abilities. Nothing here
    calls a v1 endpoint and nothing renders invented data.

  Other contract differences vs the legacy view:

  1. v1 had FOUR steps (program → paket → mode pembayaran → konfirmasi).
     v2 has THREE: the billing mode is chosen on the confirm step,
     constrained to the selected package's `allowed_billing_modes`. v1
     hardcoded a fallback list of `['PREPAID','MONTHLY']` when the
     package didn't declare any; v2's `BimbelPackage.allowed_billing_modes`
     is non-nullable so there is nothing to guess.
  2. Enum casing changed: v1 sent `PREPAID | MONTHLY | PER_SESSION`;
     v2's `BillingMode` enum is lowercase `prepaid | monthly | per_session`.
     Sending the v1 casing fails `Rule::in(BillingMode::values())`.
  3. v1 also fetched `GET /tutoring/groups?program_id=` and let the
     parent pre-pick a learning group. v2's `learning_group_id` is
     nullable on StoreEnrollmentRequest and seat assignment is an admin
     concern (`POST /enrollments/{id}/move-group`), so the group step is
     deliberately dropped — the parent enrolls into a program+package and
     staff seat them.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { formatRupiah } from '@/lib/format';
import { toLocalYmd } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
  type BimbelPackage,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const studentId = String(route.params.studentId ?? '');

/** Billing modes as the v2 `BillingMode` enum spells them (lowercase). */
type BillingMode = BimbelPackage['allowed_billing_modes'][number];

/**
 * HTTP status off a rejected api call without importing axios types.
 * Used only to tell "you lack the ability" (403) apart from a genuine
 * failure, so the UI can explain instead of showing a red generic error.
 */
function httpStatus(e: unknown): number | null {
  const res = (e as { response?: { status?: number } } | null)?.response;
  return typeof res?.status === 'number' ? res.status : null;
}

interface WizardBootstrap {
  childName: string | null;
  programs: BimbelProgram[];
  /** True when GET /programs answered 403 — see the AUTHORIZATION GAP note. */
  catalogueForbidden: boolean;
}

const { state, reload } = useDataRefresh<WizardBootstrap>(async () => {
  // The child's own enrollments are readable with the wali's
  // `tutoring.enrollment.view_own` key, so this half always works.
  let enrollments: BimbelEnrollment[] = [];
  if (studentId) {
    const res = await TutoringBimbelService.listEnrollments({
      student_id: studentId,
      per_page: 20,
    });
    enrollments = res.items;
  }
  const childName = enrollments.find((e) => e.student_name)?.student_name ?? null;

  try {
    const { items } = await TutoringBimbelService.listPrograms({
      status: 'active',
      per_page: 100,
    });
    return { childName, programs: items, catalogueForbidden: false };
  } catch (e) {
    if (httpStatus(e) === 403) {
      return { childName, programs: [], catalogueForbidden: true };
    }
    throw e;
  }
});

const bootstrap = computed<WizardBootstrap | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as WizardBootstrap | undefined) ?? null)
    : null,
);

const programs = computed<BimbelProgram[]>(() => bootstrap.value?.programs ?? []);
const catalogueForbidden = computed(() => bootstrap.value?.catalogueForbidden === true);

const childLabel = computed(
  () =>
    bootstrap.value?.childName ??
    `${t('tutoring2.common.studentId')} ${studentId.slice(0, 8)}`,
);

// ── Step state — deliberately plain local refs ────────────────────
type Step = 1 | 2 | 3;

const step = ref<Step>(1);
const programId = ref('');
const packageId = ref('');
const billingMode = ref<BillingMode | ''>('');
const startDate = ref<string>(toLocalYmd()); // LOCAL today, never toISOString()

// Step-2 options load lazily per program and carry their own state so a
// slow / forbidden package fetch never blows away the whole wizard.
const packages = ref<BimbelPackage[]>([]);
const packagesLoading = ref(false);
const packagesForbidden = ref(false);
const packagesError = ref<string | null>(null);

watch(programId, async (id) => {
  // Any program change invalidates every downstream choice.
  packageId.value = '';
  billingMode.value = '';
  packages.value = [];
  packagesForbidden.value = false;
  packagesError.value = null;
  if (!id) return;
  packagesLoading.value = true;
  try {
    const { items } = await TutoringBimbelService.listPackages(id, {
      status: 'active',
      per_page: 100,
    });
    packages.value = items;
  } catch (e) {
    if (httpStatus(e) === 403) packagesForbidden.value = true;
    else packagesError.value = (e as Error).message;
  } finally {
    packagesLoading.value = false;
  }
});

const selectedProgram = computed<BimbelProgram | null>(
  () => programs.value.find((p) => p.id === programId.value) ?? null,
);
const selectedPackage = computed<BimbelPackage | null>(
  () => packages.value.find((p) => p.id === packageId.value) ?? null,
);

const allowedBillingModes = computed<BillingMode[]>(
  () => selectedPackage.value?.allowed_billing_modes ?? [],
);

// Pre-select the package's first allowed mode so the confirm step opens
// in a valid state; the parent can still switch.
watch(selectedPackage, (pkg) => {
  billingMode.value = pkg?.allowed_billing_modes[0] ?? '';
});

// ── Submit state (declared before the validation computeds read it) ─
const submitting = ref(false);
const submitError = ref<string | null>(null);
const submitForbidden = ref(false);
const createdEnrollmentId = ref<string | null>(null);

/** Short form for the success panel — keeps the null-narrowing in TS. */
const createdEnrollmentShortId = computed(
  () => createdEnrollmentId.value?.slice(0, 8) ?? '',
);

// ── Explicit per-step validation ─────────────────────────────────
/** Human reason the current step can't advance, or null when it can. */
const stepBlocker = computed<string | null>(() => {
  if (step.value === 1) {
    return programId.value ? null : t('tutoring2.parent.enroll.errorPickProgram');
  }
  if (step.value === 2) {
    return packageId.value ? null : t('tutoring2.parent.enroll.errorPickPackage');
  }
  if (!billingMode.value) return t('tutoring2.parent.enroll.errorPickBillingMode');
  if (!startDate.value) return t('tutoring2.parent.enroll.errorPickStartDate');
  if (!studentId) return t('tutoring2.parent.enroll.errorNoChild');
  return null;
});

const canAdvance = computed(() => stepBlocker.value === null && !submitting.value);

const stepTitles = computed<string[]>(() => [
  t('tutoring2.parent.enroll.stepProgram'),
  t('tutoring2.parent.enroll.stepPackage'),
  t('tutoring2.parent.enroll.stepConfirm'),
]);

function goBack() {
  if (step.value > 1) step.value = (step.value - 1) as Step;
}

// ── Submit ───────────────────────────────────────────────────────
async function goNext() {
  if (!canAdvance.value) return;
  if (step.value < 3) {
    step.value = (step.value + 1) as Step;
    return;
  }
  const mode = billingMode.value;
  if (!mode) return;

  submitting.value = true;
  submitError.value = null;
  submitForbidden.value = false;
  try {
    const created = await TutoringBimbelService.createEnrollment({
      student_id: studentId,
      program_id: programId.value,
      package_id: packageId.value,
      billing_mode: mode,
      start_date: startDate.value,
    });
    createdEnrollmentId.value = created.id;
  } catch (e) {
    if (httpStatus(e) === 403) submitForbidden.value = true;
    else submitError.value = (e as Error).message;
  } finally {
    submitting.value = false;
  }
}

function billingModeLabel(mode: BillingMode): string {
  switch (mode) {
    case 'prepaid':
      return t('tutoring2.parent.enroll.billingPrepaid');
    case 'monthly':
      return t('tutoring2.parent.enroll.billingMonthly');
    case 'per_session':
      return t('tutoring2.parent.enroll.billingPerSession');
  }
}

function packageSubtitle(pkg: BimbelPackage): string {
  const parts: string[] = [];
  if (pkg.total_sessions != null) {
    parts.push(t('tutoring2.common.metaSessions', { count: pkg.total_sessions }));
  }
  parts.push(
    pkg.allowed_billing_modes.map((m) => billingModeLabel(m)).join(' · '),
  );
  return parts.join(' · ');
}

function goToPay() {
  router.push({ name: 'parent.tutoring2.pay' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.enroll.title')"
      :meta="
        state.status === 'loading'
          ? t('tutoring2.common.loading')
          : t('tutoring2.parent.enroll.meta', {
              name: childLabel,
              step: step,
              total: 3,
            })
      "
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.enroll.emptyTitle')"
      :empty-description="t('tutoring2.parent.enroll.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <!-- Success terminal state ------------------------------------- -->
        <div
          v-if="createdEnrollmentId"
          class="rounded-3xl border border-emerald-100 bg-emerald-50 p-6 text-center"
        >
          <h2 class="text-sm font-bold text-emerald-900">
            {{ t('tutoring2.parent.enroll.successTitle') }}
          </h2>
          <p class="mt-1 text-2xs text-emerald-700">
            {{
              t('tutoring2.parent.enroll.successBody', {
                id: createdEnrollmentShortId,
              })
            }}
          </p>
          <Button class="mt-4" variant="primary" @click="goToPay">
            {{ t('tutoring2.parent.enroll.successCta') }}
          </Button>
        </div>

        <!-- Authorization gap ------------------------------------------ -->
        <div
          v-else-if="catalogueForbidden"
          class="rounded-3xl border border-amber-100 bg-amber-50 p-6"
        >
          <h2 class="text-sm font-bold text-amber-900">
            {{ t('tutoring2.parent.enroll.forbiddenTitle') }}
          </h2>
          <p class="mt-1 text-2xs leading-relaxed text-amber-800">
            {{ t('tutoring2.parent.enroll.forbiddenBody') }}
          </p>
        </div>

        <template v-else>
          <!-- Stepper --------------------------------------------------- -->
          <ol class="flex items-center gap-2">
            <li
              v-for="(label, i) in stepTitles"
              :key="label"
              class="flex flex-1 items-center gap-2"
            >
              <span
                :class="[
                  'grid h-6 w-6 flex-none place-items-center rounded-full text-2xs font-bold',
                  i + 1 < step
                    ? 'bg-emerald-500 text-white'
                    : i + 1 === step
                      ? 'bg-brand-azure text-white'
                      : 'bg-slate-100 text-slate-500',
                ]"
              >
                {{ i + 1 }}
              </span>
              <span
                :class="[
                  'truncate text-2xs',
                  i + 1 === step ? 'font-bold text-slate-900' : 'text-slate-500',
                ]"
              >
                {{ label }}
              </span>
            </li>
          </ol>

          <!-- Step 1 — program ------------------------------------------ -->
          <div
            v-if="step === 1"
            class="rounded-3xl border border-slate-100 bg-white shadow-sm"
          >
            <p
              v-if="programs.length === 0"
              class="px-4 py-8 text-center text-sm text-slate-500"
            >
              {{ t('tutoring2.parent.enroll.noPrograms') }}
            </p>
            <ul v-else class="divide-y divide-slate-100">
              <li v-for="p in programs" :key="p.id">
                <button
                  type="button"
                  class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-slate-50"
                  :class="programId === p.id ? 'bg-brand-azure/5' : ''"
                  @click="programId = p.id"
                >
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm font-bold text-slate-900">{{ p.name }}</p>
                    <p class="truncate text-2xs text-slate-500">
                      {{ p.grade_level ?? t('tutoring2.common.notAvailable') }}
                      <span class="mx-1 text-slate-300">·</span>
                      {{ t('tutoring2.common.startingPrice') }}
                      {{ p.min_price != null ? formatRupiah(p.min_price) : '—' }}
                    </p>
                  </div>
                  <StatusBadge
                    v-if="programId === p.id"
                    :label="t('tutoring2.parent.enroll.selected')"
                    tone="info"
                    uppercase
                  />
                </button>
              </li>
            </ul>
          </div>

          <!-- Step 2 — package ------------------------------------------ -->
          <div
            v-else-if="step === 2"
            class="rounded-3xl border border-slate-100 bg-white shadow-sm"
          >
            <p v-if="packagesLoading" class="px-4 py-8 text-center text-sm text-slate-500">
              {{ t('tutoring2.common.loading') }}
            </p>
            <p
              v-else-if="packagesForbidden"
              class="px-4 py-8 text-center text-sm text-amber-800"
            >
              {{ t('tutoring2.parent.enroll.forbiddenBody') }}
            </p>
            <p
              v-else-if="packagesError"
              class="px-4 py-8 text-center text-sm text-red-700"
            >
              {{ packagesError }}
            </p>
            <p
              v-else-if="packages.length === 0"
              class="px-4 py-8 text-center text-sm text-slate-500"
            >
              {{ t('tutoring2.parent.enroll.noPackages') }}
            </p>
            <ul v-else class="divide-y divide-slate-100">
              <li v-for="pkg in packages" :key="pkg.id">
                <button
                  type="button"
                  class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-slate-50"
                  :class="packageId === pkg.id ? 'bg-brand-azure/5' : ''"
                  @click="packageId = pkg.id"
                >
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm font-bold text-slate-900">{{ pkg.name }}</p>
                    <p class="truncate text-2xs text-slate-500">{{ packageSubtitle(pkg) }}</p>
                  </div>
                  <p class="flex-none text-sm font-bold text-brand-azure">
                    {{ formatRupiah(pkg.price) }}
                  </p>
                </button>
              </li>
            </ul>
          </div>

          <!-- Step 3 — confirm ------------------------------------------ -->
          <div v-else class="space-y-3">
            <dl
              class="divide-y divide-slate-100 rounded-3xl border border-slate-100 bg-white shadow-sm"
            >
              <div class="flex items-center justify-between px-4 py-3">
                <dt class="text-2xs uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.student') }}
                </dt>
                <dd class="text-sm font-bold text-slate-900">{{ childLabel }}</dd>
              </div>
              <div class="flex items-center justify-between px-4 py-3">
                <dt class="text-2xs uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.program') }}
                </dt>
                <dd class="text-sm font-bold text-slate-900">
                  {{ selectedProgram?.name ?? '—' }}
                </dd>
              </div>
              <div class="flex items-center justify-between px-4 py-3">
                <dt class="text-2xs uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.parent.enroll.stepPackage') }}
                </dt>
                <dd class="text-right">
                  <p class="text-sm font-bold text-slate-900">
                    {{ selectedPackage?.name ?? '—' }}
                  </p>
                  <p class="text-2xs text-slate-500">
                    {{ selectedPackage ? formatRupiah(selectedPackage.price) : '—' }}
                  </p>
                </dd>
              </div>
            </dl>

            <div class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
              <p class="text-2xs uppercase tracking-wide text-slate-400">
                {{ t('tutoring2.common.billingMode') }}
              </p>
              <div class="mt-2 flex flex-wrap gap-2">
                <button
                  v-for="mode in allowedBillingModes"
                  :key="mode"
                  type="button"
                  :class="[
                    'rounded-full px-3 py-1.5 text-2xs font-bold',
                    billingMode === mode
                      ? 'bg-brand-azure text-white'
                      : 'bg-slate-100 text-slate-600 hover:bg-slate-200',
                  ]"
                  @click="billingMode = mode"
                >
                  {{ billingModeLabel(mode) }}
                </button>
              </div>

              <label
                class="mt-4 block text-2xs uppercase tracking-wide text-slate-400"
                for="enroll-start-date"
              >
                {{ t('tutoring2.common.startDate') }}
              </label>
              <input
                id="enroll-start-date"
                v-model="startDate"
                type="date"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm"
              />
            </div>

            <div
              v-if="submitForbidden"
              class="rounded-3xl border border-amber-100 bg-amber-50 p-4 text-2xs leading-relaxed text-amber-800"
            >
              {{ t('tutoring2.parent.enroll.forbiddenSubmit') }}
            </div>
            <div
              v-else-if="submitError"
              class="rounded-3xl border border-red-100 bg-red-50 p-4 text-2xs text-red-700"
            >
              {{ submitError }}
            </div>
          </div>

          <!-- Navigation ------------------------------------------------ -->
          <p v-if="stepBlocker" class="text-2xs text-slate-500">{{ stepBlocker }}</p>

          <div class="flex gap-2">
            <Button v-if="step > 1" variant="secondary" @click="goBack">
              {{ t('tutoring2.common.back') }}
            </Button>
            <Button
              variant="primary"
              block
              :disabled="!canAdvance"
              :loading="submitting"
              @click="goNext"
            >
              {{
                step === 3
                  ? t('tutoring2.parent.enroll.submitCta')
                  : t('tutoring2.parent.enroll.nextCta')
              }}
            </Button>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
