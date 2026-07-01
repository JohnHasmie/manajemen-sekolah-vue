<!--
  SubscribeView.vue — /subscribe page.

  Composition:
    - Hero (kicker + title + subtitle)
    - PricingCalculator (Bulanan/Tahunan toggle + sliders + live cost)
    - Two pricing cards (Bulanan, Tahunan) side-by-side
    - Blue "Sudah punya demo?" banner (only when the user owns 1+ tenants)
    - SubscribeSignupForm (Google button OR minimal form + tenant type radio)
    - PaymentGatewayStrip (Midtrans + chip row + manual bank fallback)
    - DemoTenantPicker modal (opened from the banner when 2+ tenants exist)

  Flow:
    1. On mount:
       - Load PricingPlan (public, no auth required).
       - If authenticated → load my-tenants (empty for zero-tenant users).
       - Pre-fill calculator from the first tenant when we have exactly one.
    2. When 2+ tenants:
       - Banner shows N sekolah/lembaga demo terdeteksi and opens the picker.
       - Choosing a tenant seeds counts + tenant_type + hides the identity fields.
    3. On submit:
       - Optionally re-run POST /billing/quote for a fresh confirmed price.
       - POST /billing/subscribe with the appropriate payload shape.
       - gateway=midtrans → window.snap.pay(snap_token)
       - gateway=bank_transfer_manual → navigate to /parent-style page with instructions
         (until a dedicated confirmation page exists, we render the info in a toast + banner).
  -->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { SubscriptionBillingService } from '@/services/billing.service';
import { useAuthStore } from '@/stores/auth';
import { useTenant } from '@/composables/useTenant';
import { useSubscription } from '@/composables/useSubscription';
import { useToast } from '@/composables/useToast';
import Button from '@/components/ui/Button.vue';
import PricingCalculator from './PricingCalculator.vue';
import DemoTenantPicker from './DemoTenantPicker.vue';
import SubscribeSignupForm from './SubscribeSignupForm.vue';
import PaymentGatewayStrip from './PaymentGatewayStrip.vue';
import type {
  BillingPeriod,
  ManualTransferInfo,
  PricingPlan,
  SubscribeResult,
  SubscriptionTenant,
  TenantType,
} from '@/types/subscription-billing';

const { t } = useI18n();
const auth = useAuthStore();
const tenant = useTenant();
const toast = useToast();
const { refresh: refreshSubscription } = useSubscription();

// ── State ────────────────────────────────────────────────────────────
const plan = ref<PricingPlan>({
  currency: 'IDR',
  price_per_student: 5000,
  price_per_staff: 5000,
  yearly_discount_pct: 20,
  supported_gateways: ['qris', 'gopay', 'ovo', 'dana', 'shopeepay', 'va', 'credit_card'],
});
const planLoading = ref(true);

const myTenants = ref<SubscriptionTenant[]>([]);
const tenantsLoading = ref(false);
const selectedTenantId = ref<string | null>(null);
const pickerOpen = ref(false);

// Calculator model — the single source of truth for the price shown
// in the calculator + the payload sent to /billing/subscribe.
const calc = reactive({
  studentCount: 500,
  staffCount: 30,
  period: 'monthly' as BillingPeriod,
});

// Signup form model. tenantType defaults to the current tenant kind if
// authenticated (so the calculator copy matches the shell), else sekolah.
const form = reactive({
  tenantType: 'sekolah' as TenantType,
  tenantName: '',
  whatsapp: '',
  adminEmail: '',
});

const submitting = ref(false);
const errorMessage = ref<string | null>(null);
const manualTransfer = ref(false);

// Bank-transfer instructions shown after subscribing via manual path.
// This is the fallback UI when there's no dedicated confirmation page;
// the user sees the details right here so they can copy the VA / bank
// account without losing context.
const bankInfo = ref<ManualTransferInfo | null>(null);

const { user } = storeToRefs(auth);

// ── Derived ──────────────────────────────────────────────────────────
const isAuthenticated = computed(() => auth.isAuthenticated);
const selectedTenant = computed<SubscriptionTenant | null>(() =>
  myTenants.value.find((t) => t.id === selectedTenantId.value) ?? null,
);
const usingExistingTenant = computed(() => !!selectedTenant.value);
const hasTenants = computed(() => myTenants.value.length > 0);

const bannerText = computed(() => {
  const n = myTenants.value.length;
  if (n === 1) {
    const only = myTenants.value[0];
    return t('subscribe.banner.oneDetected', { name: only.name });
  }
  return t('subscribe.banner.manyDetected', { count: n });
});

// Money formatter reused across cards + toast text.
function money(v: number, currency = plan.value.currency): string {
  const n = Math.max(0, Math.round(v));
  const grouped = new Intl.NumberFormat('id-ID').format(n);
  const prefix = currency === 'IDR' ? 'Rp' : currency;
  return `${prefix} ${grouped}`;
}

// Card-level derivations (mirror PricingCalculator math so the two
// stay in sync without an extra network round-trip on every keystroke).
const monthlyAmount = computed(
  () =>
    calc.studentCount * plan.value.price_per_student +
    calc.staffCount * plan.value.price_per_staff,
);
const yearlyGross = computed(() => monthlyAmount.value * 12);
const yearlyDiscount = computed(
  () => (yearlyGross.value * plan.value.yearly_discount_pct) / 100,
);
const yearlyAmount = computed(() => yearlyGross.value - yearlyDiscount.value);
const yearlySavings = computed(() => yearlyGross.value - yearlyAmount.value);
// "setara N bulan gratis" — the discount expressed as monthly equivalents.
const yearlyFreeMonths = computed(() => {
  if (monthlyAmount.value === 0) return 0;
  const raw = yearlySavings.value / monthlyAmount.value;
  return Math.round(raw * 10) / 10; // 1 decimal
});

const cardFeatures = computed(() => {
  if (form.tenantType === 'bimbel') {
    return [
      t('subscribe.card.featBimbelSessions'),
      t('subscribe.card.featBimbelPayouts'),
      t('subscribe.card.featSharedAttendance'),
      t('subscribe.card.featSharedAnnouncements'),
      t('subscribe.card.featSharedSupport'),
    ];
  }
  return [
    t('subscribe.card.featSekolahReport'),
    t('subscribe.card.featSekolahRapor'),
    t('subscribe.card.featSharedAttendance'),
    t('subscribe.card.featSharedAnnouncements'),
    t('subscribe.card.featSharedSupport'),
  ];
});

// ── Effects ──────────────────────────────────────────────────────────
async function loadPlan() {
  planLoading.value = true;
  try {
    plan.value = await SubscriptionBillingService.getPlans();
  } finally {
    planLoading.value = false;
  }
}

async function loadTenants() {
  if (!isAuthenticated.value) {
    myTenants.value = [];
    return;
  }
  tenantsLoading.value = true;
  try {
    myTenants.value = await SubscriptionBillingService.getMyTenants();
    // Auto-select on single-tenant users so the calculator + banner
    // reflect their current usage immediately.
    if (myTenants.value.length === 1) {
      applyTenant(myTenants.value[0]);
    }
  } catch (e) {
    // Non-fatal — keep the fresh-signup form usable regardless.
    // eslint-disable-next-line no-console
    console.warn('[SubscribeView.loadTenants]', (e as Error).message);
  } finally {
    tenantsLoading.value = false;
  }
}

function applyTenant(t: SubscriptionTenant) {
  selectedTenantId.value = t.id;
  form.tenantType = t.tenant_type;
  form.tenantName = t.name;
  calc.studentCount = clamp(t.student_count, 0, 2000);
  calc.staffCount = clamp(t.staff_count, 0, 200);
}

function clamp(n: number, lo: number, hi: number): number {
  if (!Number.isFinite(n)) return lo;
  return Math.max(lo, Math.min(hi, Math.round(n)));
}

function clearTenantSelection() {
  selectedTenantId.value = null;
  form.tenantName = '';
  // Keep the calculator numbers where they are — the user may have
  // adjusted them meaningfully; blanking them would feel jumpy.
}

// Seed the initial tenant type from the signed-in user's active tenant
// (only when no tenant is auto-selected yet, so we don't fight the
// applyTenant path).
onMounted(() => {
  if (isAuthenticated.value && !selectedTenantId.value) {
    form.tenantType = tenant.isTutoringCenter.value ? 'bimbel' : 'sekolah';
    if (auth.user?.email) form.adminEmail = auth.user.email;
  }
  loadPlan();
  loadTenants();
  ensureMidtransSnap();
});

// Re-fetch tenants when auth state flips (e.g. Google login completes
// while the page is mounted). The useGoogleSignIn callback lives in the
// auth store, so watching `isAuthenticated` catches that transition.
watch(isAuthenticated, (v) => {
  if (v) loadTenants();
  else {
    myTenants.value = [];
    selectedTenantId.value = null;
  }
});

// ── Midtrans Snap loader ─────────────────────────────────────────────
declare global {
  interface Window {
    snap?: {
      pay: (
        token: string,
        cb?: {
          onSuccess?: (r: unknown) => void;
          onPending?: (r: unknown) => void;
          onError?: (r: unknown) => void;
          onClose?: () => void;
        },
      ) => void;
    };
  }
}

const MIDTRANS_CLIENT_KEY = import.meta.env.VITE_MIDTRANS_CLIENT_KEY;
const MIDTRANS_SNAP_SRC = 'https://app.sandbox.midtrans.com/snap/snap.js';
let snapLoadPromise: Promise<void> | null = null;

function ensureMidtransSnap(): Promise<void> {
  if (typeof window === 'undefined') return Promise.resolve();
  if (window.snap) return Promise.resolve();
  if (snapLoadPromise) return snapLoadPromise;
  if (!MIDTRANS_CLIENT_KEY) {
    // Not a hard error — the manual bank-transfer path still works
    // without Snap. Silent noop so the page doesn't red-flash on load.
    return Promise.resolve();
  }
  snapLoadPromise = new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      `script[src="${MIDTRANS_SNAP_SRC}"]`,
    );
    if (existing) {
      existing.addEventListener('load', () => resolve());
      existing.addEventListener('error', () => reject(new Error('SNAP_LOAD_FAILED')));
      return;
    }
    const tag = document.createElement('script');
    tag.src = MIDTRANS_SNAP_SRC;
    tag.async = true;
    tag.defer = true;
    tag.setAttribute('data-client-key', MIDTRANS_CLIENT_KEY);
    tag.onload = () => resolve();
    tag.onerror = () => reject(new Error('SNAP_LOAD_FAILED'));
    document.head.appendChild(tag);
  });
  return snapLoadPromise;
}

// ── Submit ───────────────────────────────────────────────────────────
async function onSubmit() {
  errorMessage.value = null;
  bankInfo.value = null;

  // Local validation. Fresh-signup path requires all three identity
  // fields; existing-tenant path skips them (the tenant already exists).
  if (!usingExistingTenant.value) {
    if (!form.tenantName.trim()) {
      errorMessage.value = t('subscribe.errors.tenantNameRequired');
      return;
    }
    if (!form.whatsapp.trim()) {
      errorMessage.value = t('subscribe.errors.whatsappRequired');
      return;
    }
    if (!isAuthenticated.value && !isValidEmail(form.adminEmail)) {
      errorMessage.value = t('subscribe.errors.emailRequired');
      return;
    }
    if (!isAuthenticated.value) {
      // User must sign in with Google first — the fresh-signup path
      // implicitly requires an authenticated identity. The Google
      // button is prominent above; nudge the user rather than silently
      // failing at the network layer.
      errorMessage.value = t('subscribe.errors.signInFirst');
      return;
    }
  }

  submitting.value = true;
  try {
    const gateway = manualTransfer.value ? 'bank_transfer_manual' : 'midtrans';
    if (gateway === 'midtrans') {
      // Kick off Snap load in parallel with /subscribe so the popup
      // opens as fast as possible.
      ensureMidtransSnap().catch(() => {
        /* handled below */
      });
    }

    const result = await SubscriptionBillingService.subscribe({
      tenant_id: selectedTenantId.value ?? undefined,
      tenant_type: form.tenantType,
      period: calc.period,
      student_count: calc.studentCount,
      staff_count: calc.staffCount,
      gateway,
      new_tenant: usingExistingTenant.value
        ? undefined
        : {
            name: form.tenantName.trim(),
            admin_email: (auth.user?.email ?? form.adminEmail).trim(),
            whatsapp: form.whatsapp.trim(),
          },
    });

    await handleSubscribeResult(result);
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    submitting.value = false;
  }
}

async function handleSubscribeResult(result: SubscribeResult) {
  if (result.gateway === 'midtrans' && result.snap_token) {
    try {
      await ensureMidtransSnap();
    } catch {
      // Snap failed to load — fall back to redirect URL if we got one.
      if (result.snap_redirect_url) {
        window.location.assign(result.snap_redirect_url);
        return;
      }
      errorMessage.value = t('subscribe.errors.snapLoadFailed');
      return;
    }
    if (window.snap && result.snap_token) {
      window.snap.pay(result.snap_token, {
        onSuccess: () => {
          toast.success(t('subscribe.toast.success'));
          refreshSubscription();
        },
        onPending: () => {
          toast.info(t('subscribe.toast.pending'));
          refreshSubscription();
        },
        onError: () => {
          toast.error(t('subscribe.toast.error'));
        },
        onClose: () => {
          // User dismissed the Snap popup — do nothing (they can retry
          // by clicking the CTA again). Order is still pending server-side.
        },
      });
      return;
    }
    if (result.snap_redirect_url) {
      window.location.assign(result.snap_redirect_url);
      return;
    }
    errorMessage.value = t('subscribe.errors.snapUnavailable');
    return;
  }

  // Manual bank transfer path — surface instructions inline. A dedicated
  // /subscribe/confirmation route can be layered in later; for now the
  // user sees the details right where they are and gets a toast reminder.
  if (result.bank_transfer_info) {
    bankInfo.value = result.bank_transfer_info;
    toast.success(t('subscribe.toast.bankInstructions'));
    return;
  }

  toast.info(t('subscribe.toast.orderPlaced'));
}

function isValidEmail(s: string): boolean {
  const trimmed = s.trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
}

// ── Banner handlers ──────────────────────────────────────────────────
function onBannerCta() {
  if (myTenants.value.length === 1) {
    // Single tenant — already pre-filled. This CTA acts as a "re-apply"
    // in case the user changed counts and wants to reset.
    applyTenant(myTenants.value[0]);
    return;
  }
  pickerOpen.value = true;
}

function onPickerConfirm(t: SubscriptionTenant) {
  applyTenant(t);
  pickerOpen.value = false;
}

function onPickerClear() {
  clearTenantSelection();
  pickerOpen.value = false;
}
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <!-- Minimal topbar so the page is usable standalone (no AppShell). -->
    <header class="bg-white border-b border-slate-200 sticky top-0 z-30">
      <div class="max-w-6xl mx-auto px-6 h-14 flex items-center justify-between">
        <RouterLink to="/" class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-brand-dark-blue text-white text-sm font-black grid place-items-center">
            K
          </div>
          <span class="text-sm font-bold text-slate-900">KamilEdu</span>
        </RouterLink>
        <nav class="flex items-center gap-3 text-xs">
          <RouterLink
            v-if="isAuthenticated"
            to="/"
            class="font-semibold text-slate-500 hover:text-brand-cobalt"
          >
            {{ t('subscribe.nav.backToApp') }}
          </RouterLink>
          <RouterLink
            v-else
            to="/login"
            class="font-semibold text-slate-500 hover:text-brand-cobalt"
          >
            {{ t('subscribe.nav.signIn') }}
          </RouterLink>
        </nav>
      </div>
    </header>

    <main class="max-w-6xl mx-auto space-y-6 px-4 sm:px-6 py-8">
      <!-- ── Hero ──────────────────────────────────────────────────── -->
    <header class="text-center pt-4">
      <p class="text-[11px] font-black tracking-[0.32em] uppercase text-brand-cobalt">
        {{ t('subscribe.hero.kicker') }}
      </p>
      <h1 class="mt-2 text-3xl sm:text-4xl font-black text-slate-900 tracking-tight">
        {{ t('subscribe.hero.title') }}
      </h1>
      <p class="mt-3 text-sm sm:text-base text-slate-500 max-w-2xl mx-auto leading-relaxed">
        {{ t('subscribe.hero.subtitle') }}
      </p>
    </header>

    <!-- ── Calculator ───────────────────────────────────────────── -->
    <PricingCalculator
      :plan="plan"
      :tenant-type="form.tenantType"
      :student-count="calc.studentCount"
      :staff-count="calc.staffCount"
      :period="calc.period"
      :from-existing-tenant="usingExistingTenant"
      @update:studentCount="calc.studentCount = $event"
      @update:staffCount="calc.staffCount = $event"
      @update:period="calc.period = $event"
    />

    <!-- ── Two pricing cards (Bulanan / Tahunan) ────────────────── -->
    <section class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <!-- Monthly card -->
      <div
        class="relative rounded-2xl border border-slate-200 bg-white p-5 sm:p-6 flex flex-col"
        :class="calc.period === 'monthly' ? 'ring-2 ring-brand-cobalt/20' : ''"
      >
        <h3 class="text-sm font-bold uppercase tracking-wider text-slate-500">
          {{ t('subscribe.card.monthlyTitle') }}
        </h3>
        <p class="mt-2 text-3xl sm:text-4xl font-black text-slate-900 tabular-nums">
          {{ money(monthlyAmount) }}
        </p>
        <p class="text-xs text-slate-500 mt-1">{{ t('subscribe.calc.perMonth') }}</p>
        <ul class="mt-4 space-y-1.5 text-[13px] text-slate-700 flex-1">
          <li v-for="(feat, i) in cardFeatures" :key="`m-${i}`" class="flex items-start gap-2">
            <svg class="mt-0.5 flex-shrink-0 w-4 h-4 text-emerald-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12" /></svg>
            <span>{{ feat }}</span>
          </li>
        </ul>
        <Button
          class="mt-5"
          :variant="calc.period === 'monthly' ? 'primary' : 'secondary'"
          block
          @click="calc.period = 'monthly'"
        >
          {{ t('subscribe.card.monthlyCta') }}
        </Button>
      </div>

      <!-- Yearly card (recommended) -->
      <div
        class="relative rounded-2xl border-2 bg-white p-5 sm:p-6 flex flex-col"
        :class="calc.period === 'yearly' ? 'border-brand-cobalt ring-2 ring-brand-cobalt/20' : 'border-brand-cobalt'"
      >
        <span class="absolute -top-2.5 left-4 inline-flex items-center rounded-full bg-brand-cobalt text-white px-2.5 py-0.5 text-[10px] font-black uppercase tracking-widest shadow-sm">
          {{ t('subscribe.card.recommended') }}
        </span>
        <h3 class="text-sm font-bold uppercase tracking-wider text-slate-500">
          {{ t('subscribe.card.yearlyTitle') }}
        </h3>
        <p class="mt-2 text-3xl sm:text-4xl font-black text-slate-900 tabular-nums">
          {{ money(yearlyAmount) }}
        </p>
        <p class="text-xs text-slate-500 mt-1">{{ t('subscribe.calc.perYear') }}</p>
        <p class="mt-2 text-xs font-semibold text-emerald-600">
          {{ t('subscribe.card.yearlySavings', { amount: money(yearlySavings) }) }}
          <span class="text-slate-500 font-normal">
            · {{ t('subscribe.card.yearlyFreeMonths', { months: yearlyFreeMonths }) }}
          </span>
        </p>
        <ul class="mt-4 space-y-1.5 text-[13px] text-slate-700 flex-1">
          <li v-for="(feat, i) in cardFeatures" :key="`y-${i}`" class="flex items-start gap-2">
            <svg class="mt-0.5 flex-shrink-0 w-4 h-4 text-emerald-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12" /></svg>
            <span>{{ feat }}</span>
          </li>
        </ul>
        <Button
          class="mt-5"
          :variant="calc.period === 'yearly' ? 'primary' : 'secondary'"
          block
          @click="calc.period = 'yearly'"
        >
          {{ t('subscribe.card.yearlyCta') }}
        </Button>
      </div>
    </section>

    <!-- ── Existing demo banner ─────────────────────────────────── -->
    <div
      v-if="isAuthenticated && hasTenants"
      class="rounded-xl border border-blue-200 bg-blue-50 p-4 sm:p-5"
    >
      <div class="flex items-start gap-3">
        <div class="flex-shrink-0 w-9 h-9 rounded-lg bg-blue-100 text-blue-700 grid place-items-center">
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M9 12l2 2 4-4" />
            <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9 9 4.03 9 9z" />
          </svg>
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-semibold text-blue-900">
            {{ t('subscribe.banner.title') }}
          </p>
          <p class="text-xs text-blue-800 mt-0.5">
            {{ bannerText }}
          </p>
          <div v-if="selectedTenant" class="mt-2 flex flex-wrap items-center gap-2 text-[11px] text-blue-800">
            <span class="rounded bg-white px-2 py-0.5 font-semibold">
              {{ selectedTenant.name }}
            </span>
            <span>
              {{ t('subscribe.banner.selectedCounts', {
                  students: selectedTenant.student_count,
                  staff: selectedTenant.staff_count,
                }) }}
            </span>
          </div>
        </div>
        <div class="flex flex-col sm:flex-row gap-2 flex-shrink-0">
          <Button size="sm" variant="primary" @click="onBannerCta">
            {{ myTenants.length === 1
                ? t('subscribe.banner.useOne', { name: myTenants[0].name })
                : t('subscribe.banner.choose') }}
          </Button>
          <Button
            v-if="selectedTenantId"
            size="sm"
            variant="ghost"
            @click="clearTenantSelection"
          >
            {{ t('subscribe.banner.clear') }}
          </Button>
        </div>
      </div>
    </div>

    <!-- ── Signup / confirm card ────────────────────────────────── -->
    <SubscribeSignupForm
      :is-authenticated="isAuthenticated"
      :using-existing-tenant="usingExistingTenant"
      :tenant-type="form.tenantType"
      :tenant-name="form.tenantName"
      :whatsapp="form.whatsapp"
      :admin-email="form.adminEmail"
      :submitting="submitting"
      :error-message="errorMessage"
      @update:tenantType="form.tenantType = $event"
      @update:tenantName="form.tenantName = $event"
      @update:whatsapp="form.whatsapp = $event"
      @update:adminEmail="form.adminEmail = $event"
      @submit="onSubmit"
    />

    <!-- ── Bank-transfer instructions (only after manual submit) ── -->
    <div
      v-if="bankInfo"
      class="rounded-2xl border border-amber-200 bg-amber-50 p-5"
    >
      <h3 class="text-sm font-bold text-amber-900">
        {{ t('subscribe.bank.title') }}
      </h3>
      <dl class="mt-2 grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-1.5 text-[13px]">
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
      <p class="mt-3 text-[12px] text-amber-800 leading-relaxed">
        {{ t('subscribe.bank.hint') }}
      </p>
    </div>

    <!-- ── Payment gateway strip ────────────────────────────────── -->
    <PaymentGatewayStrip
      :supported-gateways="plan.supported_gateways"
      :manual-transfer="manualTransfer"
      @update:manualTransfer="manualTransfer = $event"
    />

    <!-- ── Multi-tenant picker modal ────────────────────────────── -->
    <DemoTenantPicker
      :open="pickerOpen"
      :tenants="myTenants"
      :selected-tenant-id="selectedTenantId"
      @close="pickerOpen = false"
      @confirm="onPickerConfirm"
      @clear="onPickerClear"
    />
    </main>
  </div>
</template>
