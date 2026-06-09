<!--
  RegisterDemoView.vue — top-level wizard shell.

  Responsive 2-layout:
    - Desktop (≥1024px): sidebar stepper kiri + form pane kanan
    - Mobile  (<1024px): pill stepper di atas + form pane satu kolom
  Both layouts dispatch the same step component based on
  `wizard.currentKey`. Step components live in ./steps/* and own
  their own form bindings via the demo-wizard store.

  Flow control (per CLAUDE.md):
    - AppNavigator NOT used — this is a pre-auth-shell route, so we
      use vue-router directly via the wizard's footer buttons.
    - The wizard collects SCHOOL/demo data only. The requester identity
      (Data Diri) now lives on a SEPARATE screen
      (route `/register-demo/identity`): when the user finishes the
      wizard's last step they "submit" by navigating to that screen,
      where they enter their identity and do the FINAL send. The demo
      is a REVIEWED request — that final send records a PENDING request
      (no auto-activation); activation + credentials arrive later via
      WhatsApp/email once the team approves.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { DEMO_STEPS, type DemoStepKey } from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';
import ToastHost from '@/components/ui/ToastHost.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import PublicLanguageSwitcher from '@/components/feature/PublicLanguageSwitcher.vue';

import Step1Welcome from './steps/Step1Welcome.vue';
import Step2School from './steps/Step2School.vue';
import Step3Identity from './steps/Step3Identity.vue';
import Step4Subjects from './steps/Step4Subjects.vue';
import Step4Teacher from './steps/Step4Teacher.vue';
import Step5Class from './steps/Step5Class.vue';
import Step6Student from './steps/Step6Student.vue';
import Step7Parent from './steps/Step7Parent.vue';
import Step8Schedule from './steps/Step8Schedule.vue';
import Step9Billing from './steps/Step9Billing.vue';
import Step10Scenarios from './steps/Step10Scenarios.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();
const router = useRouter();

onMounted(() => {
  // Hydrate from server / localStorage so a partial wizard resumes
  // on the right step. No-op if already hydrated.
  wizard.hydrate();
});

const STEP_LABELS = computed<Record<DemoStepKey, string>>(() => ({
  welcome: t('registerDemo.stepLabelWelcome'),
  school: t('registerDemo.stepLabelSchool'),
  identity: t('registerDemo.stepLabelIdentity'),
  subjects: t('registerDemo.stepLabelSubjects'),
  teacher: t('registerDemo.stepLabelTeacher'),
  class: t('registerDemo.stepLabelClass'),
  student: t('registerDemo.stepLabelStudent'),
  parent: t('registerDemo.stepLabelParent'),
  schedule: t('registerDemo.stepLabelSchedule'),
  billing: t('registerDemo.stepLabelBilling'),
  scenarios: t('registerDemo.stepLabelScenarios'),
}));

const stepComponentMap = {
  welcome: Step1Welcome,
  school: Step2School,
  identity: Step3Identity,
  subjects: Step4Subjects,
  teacher: Step4Teacher,
  class: Step5Class,
  student: Step6Student,
  parent: Step7Parent,
  schedule: Step8Schedule,
  billing: Step9Billing,
  scenarios: Step10Scenarios,
} as const;

const currentComponent = computed(() => stepComponentMap[wizard.currentKey]);
// The wizard's last step is now the final SCHOOL/demo-data step. Its
// button doesn't submit — it hands off to the separate identity screen.
const isLastStep = computed(() => wizard.currentStep === DEMO_STEPS.length - 1);
const isFirstStep = computed(() => wizard.currentStep === 0);

// Steps whose data is throwaway DEMO content (teachers, classes, students,
// etc.) — the requester can fill them with random values to move fast and
// re-enter real data later. Shown as a banner so people don't labour over it.
// Deliberately EXCLUDES `school` and `identity` (the real school + the
// requester's own role setup) and `welcome`/`scenarios` (no data entry). The
// separate Data Diri screen carries the opposite guidance (match yourself).
const SAMPLE_DATA_STEPS: DemoStepKey[] = [
  'subjects',
  'teacher',
  'class',
  'student',
  'parent',
  'schedule',
  'billing',
];
const showSampleDataNote = computed(() =>
  SAMPLE_DATA_STEPS.includes(wizard.currentKey),
);

function goTo(idx: number) {
  if (idx <= wizard.currentStep + 1) {
    // Allow loncat ke step yang sudah lewat atau langsung berikutnya.
    // Loncat jauh ke depan tidak diizinkan supaya tetap urut.
    wizard.goTo(idx);
  }
}

function handleNext() {
  if (isLastStep.value) {
    // Finished the SCHOOL/demo-data steps — this is the "submit" the
    // founder described. We DON'T send anything yet; the school answers
    // are already persisted (localStorage + debounced wizard-state
    // save). Hand off to the SEPARATE Data Diri (identity) screen,
    // where the user enters their identity and does the FINAL send
    // (combined school + identity payload).
    //
    // prepareIdentityHandoff() persists the live answers, flushes the
    // pending debounced remote save (so a cross-device resume sees the
    // latest state), AND marks the store hydrated so the identity
    // screen's `await wizard.hydrate()` guard is a no-op instead of
    // re-fetching a possibly-stale empty server snapshot that would
    // clobber the in-memory school name and bounce the user back here.
    wizard.prepareIdentityHandoff();
    router.push('/register-demo/identity');
    return;
  }
  wizard.next();
}

function handleBack() {
  if (!isFirstStep.value) wizard.back();
}

const showResetConfirm = ref(false);
function handleResetWizard() {
  showResetConfirm.value = true;
}
async function confirmResetWizard() {
  showResetConfirm.value = false;
  // Wipe BOTH localStorage and server-side wizard state, then reset
  // payload to defaults + jump to step 0. Single button replaces the
  // old "clear localStorage + reload" workaround that didn't work
  // because hydrate() preferred remote state.
  await wizard.reset();
}

const nextLabel = computed(() => {
  if (wizard.currentKey === 'welcome') return t('registerDemo.nextButtonStart');
  // Last SCHOOL-data step — button hands off to the separate identity
  // screen rather than submitting, so label it as "continue to Data Diri".
  if (isLastStep.value) return t('registerDemo.nextButtonToIdentity');
  return t('common.next');
});
</script>

<template>
  <div class="min-h-screen bg-slate-50 px-4 py-6 md:px-8 md:py-10">
    <div class="mx-auto max-w-5xl">
      <!-- Public language switcher — visible above the wizard on every
           step (the stepper + form pane render below it). -->
      <div class="mb-4 flex justify-end">
        <PublicLanguageSwitcher />
      </div>

      <!-- Mobile-only pill stepper at top -->
      <nav class="lg:hidden mb-4 -mx-1 overflow-x-auto">
        <div class="flex gap-1.5 px-1">
          <button
            v-for="(key, idx) in DEMO_STEPS"
            :key="key"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold whitespace-nowrap transition border"
            :class="[
              idx === wizard.currentStep
                ? 'bg-role-admin text-white border-role-admin'
                : idx < wizard.currentStep
                ? 'bg-white text-slate-700 border-slate-300'
                : 'bg-white text-slate-400 border-slate-200',
              idx > wizard.currentStep + 1 ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer',
            ]"
            :disabled="idx > wizard.currentStep + 1"
            @click="goTo(idx)"
          >
            {{ idx + 1 }} · {{ STEP_LABELS[key] }}
          </button>
        </div>
      </nav>

      <div
        class="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden lg:flex lg:min-h-[600px]"
      >
        <!-- Desktop sidebar -->
        <aside
          class="hidden lg:flex lg:flex-col w-[230px] flex-shrink-0 bg-slate-50 border-r border-slate-200 p-5"
        >
          <div class="flex items-center gap-2.5 pb-4 mb-4 border-b border-slate-200">
            <div class="w-9 h-9 rounded-xl bg-role-admin/10 flex items-center justify-center">
              <NavIcon name="school" :size="18" class="text-role-admin" />
            </div>
            <div>
              <p class="text-[13px] font-bold text-slate-900 leading-tight">{{ t('registerDemo.sidebarTitle') }}</p>
              <p class="text-[10.5px] text-slate-500">{{ t('registerDemo.sidebarDuration') }}</p>
            </div>
          </div>
          <ul class="space-y-1">
            <li v-for="(key, idx) in DEMO_STEPS" :key="key">
              <button
                type="button"
                class="w-full flex items-center gap-3 px-2.5 py-2 rounded-lg text-[12.5px] transition text-left"
                :class="[
                  idx === wizard.currentStep
                    ? 'bg-role-admin/10 text-role-admin font-bold'
                    : idx < wizard.currentStep
                    ? 'text-slate-700 hover:bg-slate-100'
                    : 'text-slate-400',
                  idx > wizard.currentStep + 1 ? 'cursor-not-allowed' : 'cursor-pointer',
                ]"
                :disabled="idx > wizard.currentStep + 1"
                @click="goTo(idx)"
              >
                <span
                  class="w-6 h-6 rounded-full flex items-center justify-center text-[10.5px] font-bold flex-shrink-0"
                  :class="
                    idx === wizard.currentStep
                      ? 'bg-role-admin text-white'
                      : idx < wizard.currentStep
                      ? 'bg-emerald-500 text-white'
                      : 'bg-white border border-slate-300 text-slate-500'
                  "
                >
                  <NavIcon v-if="idx < wizard.currentStep" name="check" :size="11" />
                  <span v-else>{{ idx + 1 }}</span>
                </span>
                {{ STEP_LABELS[key] }}
              </button>
            </li>
          </ul>
        </aside>

        <!-- Form pane -->
        <main class="flex-1 flex flex-col min-w-0 p-6 md:p-8">
          <div class="flex-1 min-w-0">
            <!-- Mobile dots -->
            <div class="lg:hidden flex gap-1 mb-5">
              <span
                v-for="(_, idx) in DEMO_STEPS"
                :key="idx"
                class="h-1 flex-1 rounded-full"
                :class="
                  idx === wizard.currentStep
                    ? 'bg-role-admin'
                    : idx < wizard.currentStep
                    ? 'bg-role-admin/40'
                    : 'bg-slate-200'
                "
              />
            </div>

            <!-- Throwaway demo-data steps: tell the requester they can fill
                 random values to go fast and re-enter the real data later. -->
            <div
              v-if="showSampleDataNote"
              class="mb-4 flex items-start gap-2 rounded-xl bg-amber-50 border border-amber-200 px-3.5 py-2.5 text-[12px] leading-relaxed text-amber-800"
            >
              <NavIcon name="info" :size="15" class="mt-0.5 flex-shrink-0 text-amber-600" />
              <span>{{ t('registerDemo.sampleDataNote') }}</span>
            </div>

            <Spinner v-if="wizard.isLoading && !wizard.hydrated" />
            <component v-else :is="currentComponent" />

            <p
              v-if="wizard.error"
              class="mt-4 text-[12.5px] text-red-700 bg-red-50 border border-red-200 rounded-lg px-3 py-2"
            >
              <NavIcon name="alert-circle" :size="14" class="inline-block mr-1.5 -mt-0.5" />
              {{ wizard.error }}
            </p>
          </div>

          <!-- Footer nav -->
          <div
            class="flex items-center gap-2 mt-6 pt-4 border-t border-slate-100 lg:justify-end"
          >
            <button
              v-if="!isFirstStep"
              type="button"
              class="flex-1 lg:flex-initial inline-flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-lg border border-slate-300 text-[13px] font-bold text-slate-700 hover:bg-slate-50 disabled:opacity-50"
              @click="handleBack"
            >
              <NavIcon name="arrow-left" :size="14" />
              {{ t('common.back') }}
            </button>
            <button
              type="button"
              class="flex-1 lg:flex-initial inline-flex items-center justify-center gap-1.5 px-5 py-2.5 rounded-lg bg-role-admin text-white text-[13px] font-bold hover:bg-role-admin/90 disabled:opacity-60 disabled:cursor-not-allowed"
              @click="handleNext"
            >
              <span>{{ nextLabel }}</span>
              <NavIcon name="arrow-right" :size="14" />
            </button>
          </div>
        </main>
      </div>

      <p class="text-center text-[11px] text-slate-400 mt-4">
        {{ t('registerDemo.footerSavedNote') }}
        <span class="mx-2 text-slate-300">·</span>
        <button
          type="button"
          class="text-role-admin hover:underline font-bold"
          @click="handleResetWizard"
        >
          {{ t('registerDemo.resetButton') }}
        </button>
      </p>
    </div>

    <ToastHost />

    <ConfirmationDialog
      v-if="showResetConfirm"
      :title="t('registerDemo.resetConfirmTitle')"
      :message="t('registerDemo.resetConfirmMessage')"
      :confirm-label="t('registerDemo.resetConfirmButton')"
      :cancel-label="t('common.cancel')"
      :danger="true"
      @confirm="confirmResetWizard"
      @close="showResetConfirm = false"
    />
  </div>
</template>
