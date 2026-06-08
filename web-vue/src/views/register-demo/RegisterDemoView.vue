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
    - The demo is now a REVIEWED request: the final "Requester" step
      submits a PENDING demo request (no auto-activation). On success
      we show a confirmation popup, then a terminal "request received"
      step whose button returns to /login. Activation + credentials
      arrive later via WhatsApp/email once the team approves.
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
import Modal from '@/components/ui/Modal.vue';

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
import Step11Requester from './steps/Step11Requester.vue';
import Step10Done from './steps/Step10Done.vue';

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
  requester: t('registerDemo.stepLabelRequester'),
  done: t('registerDemo.stepLabelDone'),
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
  requester: Step11Requester,
  done: Step10Done,
} as const;

const currentComponent = computed(() => stepComponentMap[wizard.currentKey]);
const isLastStep = computed(() => wizard.currentStep === DEMO_STEPS.length - 1);
const isFirstStep = computed(() => wizard.currentStep === 0);

function goTo(idx: number) {
  if (idx <= wizard.currentStep + 1) {
    // Allow loncat ke step yang sudah lewat atau langsung berikutnya.
    // Loncat jauh ke depan tidak diizinkan supaya tetap urut.
    wizard.goTo(idx);
  }
}

// Pending-request popup — shown after a successful submit. The demo
// is NOT activated here; the KamilEdu team validates + identifies the
// requester first, then notifies via WhatsApp/email. We deliberately
// do NOT reveal activation internals.
const showPendingDialog = ref(false);

async function handleNext() {
  if (wizard.currentKey === 'requester') {
    // FINAL step — submit the demo request. Client-validate the
    // requester identity first (mirrors the backend rules) so an
    // incomplete form surfaces inline errors instead of a 422.
    wizard.markRequesterSubmitAttempted();
    if (!wizard.requesterValid) {
      wizard.error = t('registerDemo.requesterFormInvalid');
      return;
    }
    const ok = await wizard.provision();
    if (ok) {
      // Show the confirmation popup, then advance to the terminal
      // "request received" step behind it.
      showPendingDialog.value = true;
      wizard.next();
    }
    return;
  }
  if (isLastStep.value) {
    // Terminal step — the demo isn't live yet (pending review), so
    // there's no dashboard to enter. Clear local progress and return
    // to the login screen; activation arrives later via WA/email.
    wizard.clearLocalProgress();
    router.replace('/login');
    return;
  }
  wizard.next();
}

function dismissPendingDialog() {
  showPendingDialog.value = false;
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
  if (wizard.currentKey === 'requester')
    return wizard.isProvisioning
      ? t('registerDemo.nextButtonSubmitting')
      : t('registerDemo.nextButtonSubmit');
  if (isLastStep.value) return t('registerDemo.nextButtonFinish');
  return t('common.next');
});
</script>

<template>
  <div class="min-h-screen bg-slate-50 px-4 py-6 md:px-8 md:py-10">
    <div class="mx-auto max-w-5xl">
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
              v-if="!isFirstStep && !isLastStep"
              type="button"
              class="flex-1 lg:flex-initial inline-flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-lg border border-slate-300 text-[13px] font-bold text-slate-700 hover:bg-slate-50 disabled:opacity-50"
              :disabled="wizard.isProvisioning"
              @click="handleBack"
            >
              <NavIcon name="arrow-left" :size="14" />
              {{ t('common.back') }}
            </button>
            <button
              type="button"
              class="flex-1 lg:flex-initial inline-flex items-center justify-center gap-1.5 px-5 py-2.5 rounded-lg bg-role-admin text-white text-[13px] font-bold hover:bg-role-admin/90 disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="wizard.isProvisioning"
              @click="handleNext"
            >
              <Spinner v-if="wizard.isProvisioning" size="sm" class="!text-white" />
              <span>{{ nextLabel }}</span>
              <NavIcon v-if="!wizard.isProvisioning" name="arrow-right" :size="14" />
            </button>
          </div>
        </main>
      </div>

      <p class="text-center text-[11px] text-slate-400 mt-4">
        {{ t('registerDemo.footerSavedNote') }}
        <span v-if="!wizard.isProvisioning && !isLastStep" class="mx-2 text-slate-300">·</span>
        <button
          v-if="!wizard.isProvisioning && !isLastStep"
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

    <!-- Pending-request confirmation popup. No activation internals. -->
    <Modal v-if="showPendingDialog" size="sm" @close="dismissPendingDialog">
      <div class="text-center">
        <div
          class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-emerald-100"
        >
          <NavIcon name="check-circle" :size="28" class="text-emerald-600" />
        </div>
        <h2 class="text-[18px] font-black text-slate-900">
          {{ t('registerDemo.pendingDialogTitle') }}
        </h2>
        <p class="mt-2 text-[13px] leading-relaxed text-slate-600">
          {{ t('registerDemo.pendingDialogMessage') }}
        </p>
        <div
          class="mt-4 flex items-center justify-center gap-2 rounded-lg bg-slate-50 px-3 py-2 text-[12px] text-slate-600"
        >
          <NavIcon name="send" :size="14" class="text-emerald-500" />
          {{ t('registerDemo.pendingDialogChannels') }}
        </div>
        <button
          type="button"
          class="mt-5 w-full rounded-lg bg-role-admin px-5 py-2.5 text-[13px] font-bold text-white hover:bg-role-admin/90"
          @click="dismissPendingDialog"
        >
          {{ t('registerDemo.pendingDialogButton') }}
        </button>
      </div>
    </Modal>
  </div>
</template>
