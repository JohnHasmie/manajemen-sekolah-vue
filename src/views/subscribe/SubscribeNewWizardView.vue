<!--
  SubscribeNewWizardView.vue — /subscribe/new

  Five-step wizard for creating a brand-new paid tenant (no demo,
  no seed data). Mirrors the mockup:

    1. Tenant type — sekolah vs bimbel radio.
    2. Profile   — name, education_level (sekolah) / focus (bimbel),
                   city, address, npsn (optional).
    3. Contact   — admin_name, admin_job_title, whatsapp, email.
                   Unauthenticated visitors see the Google button so
                   their email pre-fills automatically.
    4. Scale + plan — reuse PricingCalculator (sliders, monthly/yearly
                       toggle, live total).
    5. Review + pay — order summary + bank transfer instructions +
                       "Saya sudah transfer" CTA that mirrors the
                       inline flow on /subscribe.

  State is Pinia-free (kept local to this component) but auto-saved to
  the backend every 1.5s via `SubscribeNewWizardService.save()` when
  the user is authenticated. Anonymous visitors get localStorage-only
  persistence — the moment they Google-login, `hydrateFromToken`
  publishes a token and the next auto-save catches up.

  Payment: BSI manual transfer only for now. Midtrans stays hidden
  because the plan payload doesn't advertise it (see backend BSI
  fallback in CreateSubscriptionRequest). If the deployment later
  enables Midtrans, the payload flip is enough — no code change here.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import {
  SubscriptionBillingService,
  markTransferredByToken,
  shareTokenFromUrl,
} from '@/services/billing.service';
import { SubscribeNewWizardService } from '@/services/subscribe-new-wizard.service';
import { useAuthStore } from '@/stores/auth';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';
import { useToast } from '@/composables/useToast';
import Button from '@/components/ui/Button.vue';
import PricingCalculator from './PricingCalculator.vue';
import type {
  BillingPeriod,
  ManualTransferInfo,
  PricingPlan,
  TenantType,
} from '@/types/subscription-billing';
import type {
  NewTenantWizardPayload,
  WizardStep,
  EducationLevel,
} from '@/types/subscribe-new-wizard';

const { t } = useI18n();
const auth = useAuthStore();
const toast = useToast();
const router = useRouter();
const google = useGoogleSignIn();

const TOTAL_STEPS = 5;

const step = ref<WizardStep>(0);
const form = reactive<NewTenantWizardPayload>({
  tenant_type: 'sekolah',
  tenant_name: '',
  education_level: 'SMP' as EducationLevel,
  city: '',
  address: '',
  npsn: '',
  admin_name: '',
  admin_job_title: '',
  admin_whatsapp: '',
  admin_email: '',
  plan: 'yearly',
  student_count: 500,
  staff_count: 30,
  gateway: 'bank_transfer_manual',
  agreed_terms: false,
});

// ── Plan payload (drives the calculator + gateway visibility) ─────
const plan = ref<PricingPlan>({
  currency: 'IDR',
  price_per_student: 5000,
  price_per_staff: 5000,
  yearly_discount_pct: 20,
  supported_gateways: ['bank_transfer_manual'],
});
async function loadPlan() {
  try {
    plan.value = await SubscriptionBillingService.getPlans();
  } catch {
    /* keep defaults */
  }
}

// ── Order state (mirrors SubscribeView's flow after submit) ──────
const submitting = ref(false);
const errorMessage = ref<string | null>(null);
const bankInfo = ref<ManualTransferInfo | null>(null);
const shareToken = ref<string | null>(null);
const notifyingTransfer = ref(false);
const transferNotified = ref(false);

const orderLocked = computed(() => bankInfo.value !== null);

// ── Autosave (debounced) ──────────────────────────────────────────
let saveTimer: number | null = null;
function scheduleSave() {
  if (!auth.isAuthenticated) return;
  if (saveTimer !== null) window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    void SubscribeNewWizardService.save(step.value, { ...form });
  }, 1500) as unknown as number;
}
// Watch entire form + step so any keystroke schedules a save.
watch(form, scheduleSave, { deep: true });
watch(step, scheduleSave);

// Restore server draft on mount whenever authed. When not authed,
// localStorage takes over via the reactive default seed.
async function tryRestoreDraft() {
  if (!auth.isAuthenticated) return;
  const row = await SubscribeNewWizardService.load();
  if (!row || !row.payload) return;
  // Never blow away a locked order (unlikely — the wizard would only
  // hit this branch on a fresh render — but be defensive).
  if (orderLocked.value) return;
  Object.assign(form, row.payload);
  step.value = Math.min(row.current_step, 4) as WizardStep;
}

// Re-fire draft restore the moment the user Google-logins mid-flow.
watch(
  () => auth.isAuthenticated,
  (isAuth, wasAuth) => {
    if (isAuth && !wasAuth) {
      // Prime admin_email from the freshly-hydrated user, then check
      // for a pre-existing server draft (from a different device).
      if (!form.admin_email && auth.user?.email) {
        form.admin_email = auth.user.email;
      }
      if (!form.admin_name && auth.user?.name) {
        form.admin_name = auth.user.name;
      }
      void tryRestoreDraft();
    }
  },
);

// ── Google Sign-In wiring (step 3) ────────────────────────────────
const googleContainer = ref<HTMLElement | null>(null);
const showGoogle = computed(
  () => step.value === 2 && !auth.isAuthenticated && google.isEnabled.value,
);
async function mountGoogleButton() {
  if (!showGoogle.value || !googleContainer.value) return;
  const w = googleContainer.value.clientWidth || 320;
  await google.mountButton(googleContainer.value, {
    width: w,
    theme: 'outline',
    text: 'continue_with',
  });
}

// See SubscribeSignupForm — GIS in redirect mode navigates away before
// the credential callback runs, so flagIntentFromFocusedGisButton()
// never fires for a rendered-button click. Set the flag on pointerdown.
function flagSubscribeIntent(): void {
  try {
    sessionStorage.setItem('subscribe_intent_v1', '1');
  } catch {
    /* non-fatal */
  }
}
watch(showGoogle, (v) => {
  if (v) mountGoogleButton();
});

// ── Validation per step ───────────────────────────────────────────
const step1Valid = computed(() => !!form.tenant_type);
const step2Valid = computed(() => {
  if (!form.tenant_name?.trim() || (form.tenant_name.trim().length < 3)) {
    return false;
  }
  if (form.tenant_type === 'sekolah' && !form.education_level) {
    return false;
  }
  return true;
});
function isValidEmail(s: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s.trim());
}
const step3Valid = computed(() => {
  if (!form.admin_name?.trim()) return false;
  if (!form.admin_job_title?.trim()) return false;
  if (!form.admin_whatsapp?.trim()) return false;
  if (!form.admin_email?.trim() || !isValidEmail(form.admin_email)) return false;
  return true;
});
const step4Valid = computed(
  () =>
    Number.isFinite(form.student_count) &&
    (form.student_count ?? 0) >= 0 &&
    Number.isFinite(form.staff_count) &&
    (form.staff_count ?? 0) >= 0,
);
const step5Valid = computed(() => form.agreed_terms === true);

const canAdvance = computed(() => {
  switch (step.value) {
    case 0: return step1Valid.value;
    case 1: return step2Valid.value;
    case 2: return step3Valid.value;
    case 3: return step4Valid.value;
    case 4: return step5Valid.value;
    default: return false;
  }
});

function goNext() {
  if (!canAdvance.value) return;
  if (step.value < 4) step.value = (step.value + 1) as WizardStep;
}
function goBack() {
  if (step.value > 0) step.value = (step.value - 1) as WizardStep;
}

// ── Derived — amount + display copy ───────────────────────────────
const monthlyAmount = computed(
  () =>
    (form.student_count ?? 0) * plan.value.price_per_student +
    (form.staff_count ?? 0) * plan.value.price_per_staff,
);
const yearlyGross = computed(() => monthlyAmount.value * 12);
const yearlyDiscount = computed(
  () => (yearlyGross.value * plan.value.yearly_discount_pct) / 100,
);
const yearlyAmount = computed(() => yearlyGross.value - yearlyDiscount.value);
const yearlySavings = computed(() => yearlyDiscount.value);
const totalAmount = computed(() =>
  form.plan === 'yearly' ? yearlyAmount.value : monthlyAmount.value,
);
function money(v: number): string {
  const n = Math.max(0, Math.round(v));
  const grouped = new Intl.NumberFormat('id-ID').format(n);
  return `Rp ${grouped}`;
}

// ── Submit → /billing/subscribe (manual gateway) ──────────────────
async function onSubmit() {
  if (!auth.isAuthenticated) {
    errorMessage.value = t('subscribe.errors.signInFirst');
    return;
  }
  if (!step5Valid.value) return;
  submitting.value = true;
  errorMessage.value = null;
  try {
    const result = await SubscriptionBillingService.subscribe({
      tenant_type: form.tenant_type as TenantType,
      plan: form.plan as BillingPeriod,
      student_count: form.student_count ?? 0,
      staff_count: form.staff_count ?? 0,
      gateway: 'bank_transfer_manual',
      new_tenant: {
        name: (form.tenant_name ?? '').trim(),
        tenant_type: form.tenant_type as TenantType,
        admin_email: (form.admin_email ?? '').trim(),
        admin_whatsapp: (form.admin_whatsapp ?? '').trim(),
        admin_name: (form.admin_name ?? '').trim(),
        admin_job_title: (form.admin_job_title ?? '').trim(),
        education_level: form.education_level ?? null,
        city: (form.city ?? '').trim() || undefined,
        address: (form.address ?? '').trim() || undefined,
        npsn: (form.npsn ?? '').trim() || undefined,
      },
    });

    if (!result.bank_transfer_info) {
      // Shouldn't happen when gateway=bank_transfer_manual — surface
      // whatever the backend sent so the user isn't stuck.
      errorMessage.value = t('subscribe.errors.snapUnavailable');
      return;
    }
    bankInfo.value = result.bank_transfer_info;
    shareToken.value = shareTokenFromUrl(result.share_url);
    // Advance past the last step (visible via v-if=step===5, which we
    // model with step=5 as an artificial "done" marker for the order
    // status card). Keep step at 4; toggle via `orderLocked` instead.
    // Clear the server draft — this order is now committed.
    void SubscribeNewWizardService.clear();
    requestAnimationFrame(() => {
      document
        .getElementById('subscribe-new-order-summary')
        ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    submitting.value = false;
  }
}

async function onMarkTransferred() {
  if (!shareToken.value) {
    toast.info(t('subscribe.toast.markTransferredFallback'));
    return;
  }
  if (notifyingTransfer.value) return;
  notifyingTransfer.value = true;
  try {
    await markTransferredByToken(shareToken.value);
    transferNotified.value = true;
    toast.success(t('subscribe.toast.markTransferredOk'));
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    notifyingTransfer.value = false;
  }
}

// ── Init ──────────────────────────────────────────────────────────
onMounted(async () => {
  loadPlan();
  // Prime admin_email from the auth store when the user landed here
  // already-authed (e.g. arrived via /subscribe → "Buat tenant baru").
  if (auth.isAuthenticated) {
    if (!form.admin_email && auth.user?.email) {
      form.admin_email = auth.user.email;
    }
    if (!form.admin_name && auth.user?.name) {
      form.admin_name = auth.user.name;
    }
  }
  await tryRestoreDraft();
});

// Step-3 Google button waits for the container ref to mount.
watch(step, async (s) => {
  if (s === 2 && showGoogle.value) {
    // Give Vue a tick to render the container before mounting.
    await Promise.resolve();
    mountGoogleButton();
  }
});
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <!-- Topbar -->
    <header class="bg-white border-b border-slate-200 sticky top-0 z-20">
      <div class="max-w-4xl mx-auto px-6 h-14 flex items-center justify-between">
        <RouterLink to="/" class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-brand-dark-blue text-white text-sm font-black grid place-items-center">
            K
          </div>
          <span class="text-sm font-bold text-slate-900">KamilEdu</span>
        </RouterLink>
        <RouterLink
          to="/subscribe"
          class="text-xs font-semibold text-slate-500 hover:text-brand-cobalt"
        >
          {{ t('subscribeNew.nav.hasExisting') }}
        </RouterLink>
      </div>
    </header>

    <main class="max-w-3xl mx-auto px-4 sm:px-6 py-8 space-y-5">
      <!-- Progress rail -->
      <nav class="flex items-center gap-2 overflow-x-auto pb-2 -mx-4 px-4 sm:mx-0 sm:px-0">
        <template v-for="(label, i) in [
          t('subscribeNew.steps.type'),
          t('subscribeNew.steps.profile'),
          t('subscribeNew.steps.contact'),
          t('subscribeNew.steps.scale'),
          t('subscribeNew.steps.pay'),
        ]" :key="i">
          <div
            class="flex items-center gap-2 flex-shrink-0"
            :class="i === step ? 'text-slate-900' : 'text-slate-400'"
          >
            <span
              class="w-6 h-6 rounded-full grid place-items-center text-[11px] font-bold border"
              :class="i < step
                  ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
                  : i === step
                      ? 'bg-brand-cobalt text-white border-brand-cobalt'
                      : 'bg-white text-slate-400 border-slate-200'"
            >
              {{ i < step ? '✓' : i + 1 }}
            </span>
            <span class="text-xs font-semibold whitespace-nowrap">{{ label }}</span>
          </div>
          <span
            v-if="i < 4"
            class="w-6 h-px bg-slate-300 flex-shrink-0"
          />
        </template>
      </nav>

      <!-- Step 1: Tenant type -->
      <section v-if="step === 0 && !orderLocked" class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-7">
        <p class="text-[11px] font-black uppercase tracking-widest text-brand-cobalt">
          {{ t('subscribeNew.stepIndicator', { current: 1, total: TOTAL_STEPS }) }}
        </p>
        <h2 class="mt-1 text-lg font-bold text-slate-900">
          {{ t('subscribeNew.step1.title') }}
        </h2>
        <p class="mt-1 text-sm text-slate-500 max-w-md leading-relaxed">
          {{ t('subscribeNew.step1.subtitle') }}
        </p>
        <div class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label
            v-for="opt in ['sekolah', 'bimbel'] as TenantType[]"
            :key="opt"
            class="flex items-start gap-3 rounded-xl border p-4 cursor-pointer transition-colors"
            :class="form.tenant_type === opt
                ? 'border-brand-cobalt bg-brand-50/40 ring-2 ring-brand-cobalt/20'
                : 'border-slate-200 hover:border-slate-300'"
          >
            <input
              type="radio"
              name="wizard-tenant-type"
              class="mt-0.5 h-4 w-4 text-brand-cobalt focus:ring-brand-cobalt"
              :checked="form.tenant_type === opt"
              @change="form.tenant_type = opt"
            />
            <span class="min-w-0">
              <span class="block text-sm font-bold text-slate-900">
                {{ opt === 'sekolah'
                    ? t('subscribeNew.step1.sekolahTitle')
                    : t('subscribeNew.step1.bimbelTitle') }}
              </span>
              <span class="block text-[12px] text-slate-500 mt-0.5 leading-relaxed">
                {{ opt === 'sekolah'
                    ? t('subscribeNew.step1.sekolahDesc')
                    : t('subscribeNew.step1.bimbelDesc') }}
              </span>
            </span>
          </label>
        </div>
      </section>

      <!-- Step 2: Profile -->
      <section v-else-if="step === 1 && !orderLocked" class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-7">
        <p class="text-[11px] font-black uppercase tracking-widest text-brand-cobalt">
          {{ t('subscribeNew.stepIndicator', { current: 2, total: TOTAL_STEPS }) }}
        </p>
        <h2 class="mt-1 text-lg font-bold text-slate-900">
          {{ form.tenant_type === 'bimbel'
              ? t('subscribeNew.step2.titleBimbel')
              : t('subscribeNew.step2.titleSekolah') }}
        </h2>
        <p class="mt-1 text-sm text-slate-500 max-w-md leading-relaxed">
          {{ t('subscribeNew.step2.subtitle') }}
        </p>
        <div class="mt-5 space-y-4">
          <label class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ form.tenant_type === 'bimbel'
                  ? t('subscribeNew.step2.nameLabelBimbel')
                  : t('subscribeNew.step2.nameLabelSekolah') }} *
            </span>
            <input
              v-model="form.tenant_name"
              type="text"
              maxlength="255"
              :placeholder="form.tenant_type === 'bimbel'
                  ? t('subscribeNew.step2.namePlaceholderBimbel')
                  : t('subscribeNew.step2.namePlaceholderSekolah')"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            />
          </label>
          <div v-if="form.tenant_type === 'sekolah'" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <label class="block">
              <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
                {{ t('subscribeNew.step2.educationLevel') }} *
              </span>
              <select
                v-model="form.education_level"
                class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm bg-white focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
              >
                <option value="SD">SD</option>
                <option value="SMP">SMP</option>
                <option value="SMA">SMA</option>
                <option value="SMK">SMK</option>
                <option value="MI">MI</option>
                <option value="MTs">MTs</option>
                <option value="MA">MA</option>
              </select>
            </label>
            <label class="block">
              <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
                {{ t('subscribeNew.step2.city') }}
              </span>
              <input
                v-model="form.city"
                type="text"
                maxlength="100"
                :placeholder="t('subscribeNew.step2.cityPlaceholder')"
                class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
              />
            </label>
          </div>
          <label v-else class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('subscribeNew.step2.city') }}
            </span>
            <input
              v-model="form.city"
              type="text"
              maxlength="100"
              :placeholder="t('subscribeNew.step2.cityPlaceholder')"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            />
          </label>
          <label class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('subscribeNew.step2.address') }}
            </span>
            <input
              v-model="form.address"
              type="text"
              maxlength="500"
              :placeholder="t('subscribeNew.step2.addressPlaceholder')"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            />
          </label>
          <label v-if="form.tenant_type === 'sekolah'" class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('subscribeNew.step2.npsn') }}
              <span class="text-slate-400 normal-case tracking-normal font-normal text-[10px]"> — {{ t('subscribeNew.step2.optional') }}</span>
            </span>
            <input
              v-model="form.npsn"
              type="text"
              maxlength="20"
              placeholder="8-digit NPSN"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            />
            <p class="text-[11px] text-slate-400 mt-1">
              {{ t('subscribeNew.step2.npsnHint') }}
            </p>
          </label>
        </div>
      </section>

      <!-- Step 3: Contact -->
      <section v-else-if="step === 2 && !orderLocked" class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-7">
        <p class="text-[11px] font-black uppercase tracking-widest text-brand-cobalt">
          {{ t('subscribeNew.stepIndicator', { current: 3, total: TOTAL_STEPS }) }}
        </p>
        <h2 class="mt-1 text-lg font-bold text-slate-900">
          {{ t('subscribeNew.step3.title') }}
        </h2>
        <p class="mt-1 text-sm text-slate-500 max-w-md leading-relaxed">
          {{ t('subscribeNew.step3.subtitle') }}
        </p>

        <!-- Google button — anonymous only -->
        <div v-if="showGoogle" class="mt-4">
          <div
            ref="googleContainer"
            data-google-intent="subscribe"
            class="w-full flex justify-center min-h-[42px]"
            @pointerdown="flagSubscribeIntent"
          />
          <p v-if="google.error.value" class="mt-2 text-[11px] text-rose-600 text-center">
            {{ t('subscribe.form.googleError') }}
          </p>
          <div class="mt-4 flex items-center gap-3">
            <div class="flex-1 h-px bg-slate-200" />
            <span class="text-[11px] font-semibold uppercase tracking-widest text-slate-400">
              {{ t('subscribe.form.divider') }}
            </span>
            <div class="flex-1 h-px bg-slate-200" />
          </div>
        </div>
        <!-- Signed-in badge -->
        <div
          v-else-if="auth.isAuthenticated"
          class="mt-4 mb-1 flex items-center gap-2.5 rounded-lg bg-slate-50 border border-slate-200 px-3 py-2.5"
        >
          <div class="w-8 h-8 rounded-full bg-brand-cobalt/10 text-brand-cobalt grid place-items-center text-xs font-bold">
            {{ (auth.user?.name?.[0] ?? auth.user?.email?.[0] ?? '?').toUpperCase() }}
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-[13px] font-semibold text-slate-900 truncate">
              {{ auth.user?.name || t('subscribe.form.signedInFallback') }}
            </p>
            <p class="text-[11px] text-slate-500 truncate">
              {{ auth.user?.email }}
            </p>
          </div>
        </div>

        <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('subscribeNew.step3.fullName') }} *
            </span>
            <input
              v-model="form.admin_name"
              type="text"
              maxlength="255"
              :placeholder="t('subscribeNew.step3.fullNamePlaceholder')"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            />
          </label>
          <label class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('subscribeNew.step3.jobTitle') }} *
            </span>
            <input
              v-model="form.admin_job_title"
              type="text"
              maxlength="100"
              :placeholder="t('subscribeNew.step3.jobTitlePlaceholder')"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            />
          </label>
          <label class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('subscribeNew.step3.whatsapp') }} *
            </span>
            <input
              v-model="form.admin_whatsapp"
              type="tel"
              inputmode="tel"
              maxlength="30"
              placeholder="0812…"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            />
          </label>
          <label class="block">
            <span class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('subscribeNew.step3.adminEmail') }} *
            </span>
            <input
              v-model="form.admin_email"
              type="email"
              inputmode="email"
              maxlength="255"
              :disabled="auth.isAuthenticated"
              placeholder="admin@sekolah.sch.id"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none disabled:bg-slate-50 disabled:text-slate-500"
            />
          </label>
        </div>
        <p class="mt-3 text-[11px] text-slate-400 leading-relaxed">
          {{ t('subscribeNew.step3.footNote') }}
        </p>
      </section>

      <!-- Step 4: Scale + plan -->
      <section v-else-if="step === 3 && !orderLocked" class="space-y-3">
        <div class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-7">
          <p class="text-[11px] font-black uppercase tracking-widest text-brand-cobalt">
            {{ t('subscribeNew.stepIndicator', { current: 4, total: TOTAL_STEPS }) }}
          </p>
          <h2 class="mt-1 text-lg font-bold text-slate-900">
            {{ t('subscribeNew.step4.title') }}
          </h2>
          <p class="mt-1 text-sm text-slate-500 max-w-md leading-relaxed">
            {{ t('subscribeNew.step4.subtitle') }}
          </p>
        </div>
        <PricingCalculator
          :plan="plan"
          :tenant-type="(form.tenant_type ?? 'sekolah') as TenantType"
          :student-count="form.student_count ?? 0"
          :staff-count="form.staff_count ?? 0"
          :period="(form.plan ?? 'monthly') as BillingPeriod"
          :from-existing-tenant="false"
          @update:studentCount="form.student_count = $event"
          @update:staffCount="form.staff_count = $event"
          @update:period="form.plan = $event"
        />
      </section>

      <!-- Step 5: Review + pay -->
      <section v-else-if="step === 4 && !orderLocked" class="space-y-3">
        <div class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-7">
          <p class="text-[11px] font-black uppercase tracking-widest text-brand-cobalt">
            {{ t('subscribeNew.stepIndicator', { current: 5, total: TOTAL_STEPS }) }}
          </p>
          <h2 class="mt-1 text-lg font-bold text-slate-900">
            {{ t('subscribeNew.step5.title') }}
          </h2>
          <p class="mt-1 text-sm text-slate-500 max-w-md leading-relaxed">
            {{ t('subscribeNew.step5.subtitle') }}
          </p>
          <dl class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3 text-sm">
            <div>
              <dt class="text-[11px] text-slate-500 font-semibold uppercase tracking-wider">
                {{ form.tenant_type === 'bimbel'
                    ? t('subscribeNew.step5.tenantNameBimbel')
                    : t('subscribeNew.step5.tenantNameSekolah') }}
              </dt>
              <dd class="text-slate-900 font-semibold">{{ form.tenant_name }}</dd>
            </div>
            <div>
              <dt class="text-[11px] text-slate-500 font-semibold uppercase tracking-wider">
                {{ t('subscribeNew.step5.admin') }}
              </dt>
              <dd class="text-slate-900">
                {{ form.admin_name }}
                <span class="text-slate-500">· {{ form.admin_email }}</span>
              </dd>
            </div>
            <div>
              <dt class="text-[11px] text-slate-500 font-semibold uppercase tracking-wider">
                {{ t('subscribeNew.step5.package') }}
              </dt>
              <dd class="text-slate-900 font-semibold">
                {{ form.plan === 'yearly'
                    ? t('subscribe.calc.yearly')
                    : t('subscribe.calc.monthly') }}
                <span v-if="form.plan === 'yearly'" class="text-emerald-700 text-xs ml-1">
                  · {{ t('subscribeNew.step5.savings', { amount: money(yearlySavings) }) }}
                </span>
              </dd>
            </div>
            <div>
              <dt class="text-[11px] text-slate-500 font-semibold uppercase tracking-wider">
                {{ t('subscribeNew.step5.seats') }}
              </dt>
              <dd class="text-slate-900 tabular-nums">
                {{ form.student_count }} {{ t('subscribe.calc.unitStudent') }}
                <span class="text-slate-400"> · </span>
                {{ form.staff_count }}
                {{ form.tenant_type === 'bimbel'
                    ? t('subscribe.calc.unitTutor')
                    : t('subscribe.calc.unitStaff') }}
              </dd>
            </div>
            <div class="sm:col-span-2 border-t border-slate-200 pt-3 mt-1">
              <dt class="text-[11px] text-emerald-700 font-semibold uppercase tracking-wider">
                {{ t('subscribeNew.step5.seedNoteLabel') }}
              </dt>
              <dd class="text-emerald-900 text-[13px] leading-relaxed">
                {{ t('subscribeNew.step5.seedNote') }}
              </dd>
            </div>
            <div class="sm:col-span-2 border-t border-slate-200 pt-3">
              <div class="flex items-baseline justify-between">
                <dt class="text-sm text-slate-500 font-semibold">
                  {{ t('subscribeNew.step5.totalDue') }}
                </dt>
                <dd class="text-2xl font-black text-slate-900 tabular-nums">
                  {{ money(totalAmount) }}
                </dd>
              </div>
            </div>
          </dl>
        </div>

        <!-- Payment method — manual only for now -->
        <div class="rounded-2xl border-2 border-brand-cobalt bg-brand-50/40 p-4 sm:p-5">
          <div class="flex items-start gap-3">
            <div class="w-9 h-9 rounded-lg bg-white text-brand-cobalt grid place-items-center border border-brand-cobalt/30 flex-shrink-0">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="7" width="18" height="12" rx="2" />
                <path d="M3 11h18" />
              </svg>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[11px] font-bold uppercase tracking-widest text-brand-cobalt">
                {{ t('subscribeNew.step5.methodKicker') }}
              </p>
              <p class="mt-0.5 text-sm font-bold text-slate-900">
                {{ t('subscribeNew.step5.methodTitle') }}
              </p>
              <p v-if="plan.bank_transfer" class="mt-2 text-[13px] text-slate-700">
                {{ plan.bank_transfer.bank_name }}
                <span class="font-mono font-semibold">· {{ plan.bank_transfer.account_number }}</span>
                <span class="block text-[12px] text-slate-500 mt-0.5">
                  {{ t('subscribe.gateway.manualOnlyAccountHolder') }}
                  <span class="text-slate-700 font-medium">{{ plan.bank_transfer.account_holder }}</span>
                </span>
              </p>
              <p class="mt-2 text-[11px] text-slate-500 leading-relaxed">
                {{ t('subscribeNew.step5.methodHint') }}
              </p>
            </div>
          </div>
        </div>

        <!-- Consent -->
        <label class="flex items-start gap-2.5 rounded-2xl border border-slate-200 bg-white p-4 cursor-pointer">
          <input
            type="checkbox"
            class="mt-0.5 h-4 w-4 text-brand-cobalt focus:ring-brand-cobalt rounded border-slate-300"
            :checked="form.agreed_terms"
            @change="form.agreed_terms = ($event.target as HTMLInputElement).checked"
          />
          <span class="text-[12px] text-slate-700 leading-relaxed">
            {{ t('subscribeNew.step5.termsAgree') }}
          </span>
        </label>

        <p
          v-if="errorMessage"
          class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-xs text-rose-700"
        >
          {{ errorMessage }}
        </p>
      </section>

      <!-- Order status card (mirrors SubscribeView's post-submit state) -->
      <section
        v-if="orderLocked && bankInfo"
        id="subscribe-new-order-summary"
        class="rounded-2xl border-2 overflow-hidden shadow-sm transition-colors duration-300"
        :class="transferNotified ? 'border-emerald-300 bg-emerald-50/50' : 'border-amber-300 bg-amber-50/50'"
      >
        <header
          class="flex items-start gap-3 p-5 border-b transition-colors"
          :class="transferNotified
              ? 'bg-emerald-100/60 border-emerald-200'
              : 'bg-amber-100/60 border-amber-200'"
        >
          <div
            class="flex-shrink-0 w-10 h-10 rounded-lg grid place-items-center text-white"
            :class="transferNotified ? 'bg-emerald-500' : 'bg-amber-500'"
          >
            <svg v-if="transferNotified" xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12" />
            </svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10" />
              <polyline points="12 6 12 12 16 14" />
            </svg>
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-[10px] font-black uppercase tracking-widest"
              :class="transferNotified ? 'text-emerald-700' : 'text-amber-700'"
            >
              {{ transferNotified
                  ? t('subscribe.orderStatus.thanksKicker')
                  : t('subscribe.orderStatus.kicker') }}
            </p>
            <h3
              class="text-base font-bold leading-tight mt-0.5"
              :class="transferNotified ? 'text-emerald-900' : 'text-amber-900'"
            >
              {{ transferNotified
                  ? t('subscribe.orderStatus.thanksTitle')
                  : t('subscribe.orderStatus.title') }}
            </h3>
            <p
              class="text-[12px] mt-1 leading-relaxed"
              :class="transferNotified ? 'text-emerald-800/90' : 'text-amber-800/90'"
            >
              {{ transferNotified
                  ? t('subscribe.orderStatus.thanksSubtitle')
                  : t('subscribe.orderStatus.subtitle') }}
            </p>
          </div>
        </header>
        <div class="p-5 space-y-4">
          <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-2 text-[13px]">
            <div>
              <dt class="text-amber-800/70 text-[11px] font-semibold uppercase tracking-wider">
                {{ t('subscribe.bank.bank') }}
              </dt>
              <dd class="font-semibold text-amber-900">{{ bankInfo.bank_name }}</dd>
            </div>
            <div>
              <dt class="text-amber-800/70 text-[11px] font-semibold uppercase tracking-wider">
                {{ t('subscribe.bank.account') }}
              </dt>
              <dd class="font-mono font-semibold text-amber-900">{{ bankInfo.account_number }}</dd>
            </div>
            <div>
              <dt class="text-amber-800/70 text-[11px] font-semibold uppercase tracking-wider">
                {{ t('subscribe.bank.name') }}
              </dt>
              <dd class="font-semibold text-amber-900">{{ bankInfo.account_name }}</dd>
            </div>
            <div>
              <dt class="text-amber-800/70 text-[11px] font-semibold uppercase tracking-wider">
                {{ t('subscribe.bank.amount') }}
              </dt>
              <dd class="font-bold text-amber-900 tabular-nums">{{ money(bankInfo.amount) }}</dd>
            </div>
            <div class="sm:col-span-2">
              <dt class="text-amber-800/70 text-[11px] font-semibold uppercase tracking-wider">
                {{ t('subscribe.bank.reference') }}
              </dt>
              <dd class="font-mono font-semibold text-amber-900">{{ bankInfo.reference }}</dd>
            </div>
          </dl>
          <button
            v-if="!transferNotified"
            type="button"
            class="w-full inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 hover:bg-emerald-700 disabled:bg-emerald-400 disabled:cursor-not-allowed text-white font-semibold px-4 py-3 text-sm shadow-sm transition-colors"
            :disabled="notifyingTransfer"
            @click="onMarkTransferred"
          >
            {{ notifyingTransfer
                ? t('subscribe.orderStatus.markingTransferred')
                : t('subscribe.orderStatus.markTransferredCta') }}
          </button>
          <RouterLink
            v-else
            to="/"
            class="w-full inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-semibold px-4 py-3 text-sm shadow-sm transition-colors"
          >
            {{ t('subscribe.orderStatus.backToAppCta') }}
          </RouterLink>
        </div>
      </section>

      <!-- Wizard nav — hidden once order placed -->
      <nav v-if="!orderLocked" class="flex flex-col-reverse sm:flex-row justify-between gap-2 pt-1">
        <Button
          v-if="step > 0"
          variant="ghost"
          @click="goBack"
        >
          ← {{ t('subscribeNew.nav.back') }}
        </Button>
        <span v-else />
        <Button
          v-if="step < 4"
          variant="primary"
          :disabled="!canAdvance"
          @click="goNext"
        >
          {{ t('subscribeNew.nav.next') }} →
        </Button>
        <Button
          v-else
          variant="primary"
          :disabled="!canAdvance || submitting"
          :loading="submitting"
          @click="onSubmit"
        >
          {{ t('subscribeNew.nav.submit') }}
        </Button>
      </nav>
    </main>
  </div>
</template>
