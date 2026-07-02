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
import {
  SubscriptionBillingService,
  markTransferredByToken,
  shareTokenFromUrl,
} from '@/services/billing.service';
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

// Whether Midtrans is offered by THIS deployment (server sends the
// filtered list on GET /billing/plans). When the deployment has no
// Midtrans key configured, `midtrans` is missing from the list and
// we force + lock the user onto manual transfer.
const midtransAvailable = computed(
  () => plan.value.supported_gateways.includes('midtrans'),
);
const manualOnly = computed(() => !midtransAvailable.value);
// Auto-tick + lock manual when Midtrans isn't offered. Watching plan
// covers the case where the plan payload arrives AFTER the component
// mounted (network-slow first load).
watch(
  manualOnly,
  (v) => {
    if (v) manualTransfer.value = true;
  },
  { immediate: true },
);

// Wipe demo scenarios (dummy siswa/guru/sesi/tagihan) on activation.
// Default TRUE: when the user picks an existing demo tenant, we assume
// they want to start real operations from an empty tenant — that's the
// common case and avoids accidentally showing dummy data to real
// students later. The toggle lets them opt OUT to keep the demo data
// (useful for evaluating features against realistic-looking data
// during trial).
const wipeDemoData = ref(true);

// Bank-transfer instructions shown after subscribing via manual path.
// This is the fallback UI when there's no dedicated confirmation page;
// the user sees the details right here so they can copy the VA / bank
// account without losing context.
const bankInfo = ref<ManualTransferInfo | null>(null);

// Snapshot of the calculator state at the moment the pending order
// was created. Used to render the "Pesanan Anda" summary while the
// user waits to transfer — and to guarantee those numbers match
// whatever we actually POSTed to /billing/subscribe even if the
// backend's manual-transfer amount rounds differently for some plans.
type OrderSnapshot = {
  studentCount: number;
  staffCount: number;
  period: BillingPeriod;
  amount: number;
  gateway: 'midtrans' | 'bank_transfer_manual';
  /** 48-char token from the backend share_url. Feeds the "sudah
   *  transfer" CTA which calls /billing/public/transfer/{token}/
   *  mark-transferred without needing an auth session. */
  shareToken: string | null;
};
const orderSnapshot = ref<OrderSnapshot | null>(null);

// True while a pending manual-transfer order is live. Locks the
// calculator/form so the visible transfer instructions can't
// silently disagree with the amount stored in the backend.
const orderLocked = computed(() => bankInfo.value !== null);

// State machine for the "Sudah transfer" CTA. `submitting` while the
// mark-transferred request is in flight; `notified` once the backend
// confirms the sub is on the bendahara queue. The customer sees a
// distinct thank-you card in the notified state so they know we
// received their signal — separate from the "menunggu pembayaran"
// kicker they were staring at a moment ago.
const notifyingTransfer = ref(false);
const transferNotified = ref(false);

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
  if (v) {
    loadTenants();
    // If the user hit "Lanjut ke pembayaran" BEFORE signing in, we
    // stamped the `subscribe.errors.signInFirst` message under the
    // form. That message is now stale — clear it so the submit-button
    // area doesn't keep pointing at a solved problem. Any real
    // network / server error will re-populate errorMessage on the
    // next click.
    if (errorMessage.value === t('subscribe.errors.signInFirst')) {
      errorMessage.value = null;
    }
  } else {
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
      plan: calc.period,
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
      // Only meaningful for the existing-tenant path AND only when the
      // tenant is still a demo — the backend also guards on `is_demo`,
      // but we scope it here too so the request payload matches intent.
      wipe_demo_data:
        usingExistingTenant.value && (selectedTenant.value?.is_demo ?? false)
          ? wipeDemoData.value
          : undefined,
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
    orderSnapshot.value = {
      studentCount: calc.studentCount,
      staffCount: calc.staffCount,
      period: calc.period,
      amount: result.bank_transfer_info.amount,
      gateway: 'bank_transfer_manual',
      shareToken: shareTokenFromUrl(result.share_url),
    };
    transferNotified.value = false;
    toast.success(t('subscribe.toast.bankInstructions'));
    // Scroll the instructions block into view so the user isn't left
    // wondering where the CTA disappeared to on tall screens.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    requestAnimationFrame(() => {
      document
        .getElementById('subscribe-order-summary')
        ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    return;
  }

  toast.info(t('subscribe.toast.orderPlaced'));
}

/**
 * Leave "order locked" mode: clear the bank instructions and let the
 * user re-adjust the calculator. The previous pending order stays on
 * the backend (it'll expire on its own) — we warn about that in the
 * toast so the user knows a fresh reference code will be issued on
 * the next submit. This is deliberately optimistic: doing a hard
 * cancel would need a dedicated backend endpoint + a confirm dialog,
 * which is overkill for a "typo in seat count" moment.
 */
function onEditOrder() {
  bankInfo.value = null;
  orderSnapshot.value = null;
  transferNotified.value = false;
  errorMessage.value = null;
  toast.info(t('subscribe.toast.orderEditing'));
}

/**
 * Customer taps "Sudah transfer" — call the public mark-transferred
 * endpoint using the share_token embedded in the create-subscription
 * response. Backend has two rate-limits (5 req/min per IP, 1 successful
 * flip per hour per token); a same-hour replay returns the current
 * state silently, so we still flip the FE to the notified card if the
 * request resolves without an axios error.
 */
async function onMarkTransferred() {
  if (!orderSnapshot.value?.shareToken) {
    // Older backend deployments don't emit share_url. Rather than
    // stalling the user, tell them what to do and stay in the
    // "menunggu pembayaran" state.
    toast.info(t('subscribe.toast.markTransferredFallback'));
    return;
  }
  if (notifyingTransfer.value) return;
  notifyingTransfer.value = true;
  try {
    await markTransferredByToken(orderSnapshot.value.shareToken);
    transferNotified.value = true;
    toast.success(t('subscribe.toast.markTransferredOk'));
    requestAnimationFrame(() => {
      document
        .getElementById('subscribe-order-summary')
        ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  } catch (e) {
    // 429 or 404 land here — surface as an inline error, not a modal,
    // so the user can retry or hit "Ubah pesanan" if the token is
    // genuinely stale.
    errorMessage.value = (e as Error).message;
  } finally {
    notifyingTransfer.value = false;
  }
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
      :locked="orderLocked"
      @update:studentCount="calc.studentCount = $event"
      @update:staffCount="calc.staffCount = $event"
      @update:period="calc.period = $event"
    />

    <!-- ── Two pricing cards (Bulanan / Tahunan) ────────────────── -->
    <section class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <!-- Monthly card -->
      <div
        class="relative rounded-2xl bg-white p-5 sm:p-6 flex flex-col transition-all duration-150"
        :class="calc.period === 'monthly'
          ? 'border-2 border-brand-cobalt bg-brand-50/40 ring-4 ring-brand-cobalt/15 shadow-md'
          : 'border border-slate-200'"
      >
        <!-- "TERPILIH" chip — semantically a STATE indicator (user's
             current pick), so it uses emerald + a ✓ leading icon.
             That distinguishes it from the persistent brand-cobalt
             "DIREKOMENDASIKAN" label on the yearly card. Users can
             now read the two chips at a glance: green ✓ = "aku pilih
             ini", blue = "platform bilang ini paling worth it". -->
        <span
          v-if="calc.period === 'monthly'"
          class="absolute -top-2.5 left-4 inline-flex items-center gap-1 rounded-full bg-emerald-500 text-white px-2.5 py-0.5 text-[10px] font-black uppercase tracking-widest shadow-sm"
        >
          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <polyline points="20 6 9 17 4 12" />
          </svg>
          {{ t('subscribe.card.selected') }}
        </span>
        <h3 class="text-sm font-bold uppercase tracking-wider text-slate-500">
          {{ t('subscribe.card.monthlyTitle') }}
        </h3>
        <p class="mt-2 text-3xl sm:text-4xl font-black text-slate-900 tabular-nums">
          {{ money(monthlyAmount) }}
        </p>
        <p class="text-xs text-slate-500 mt-1">{{ t('subscribe.calc.perMonth') }}</p>
        <div class="flex-1 min-h-[24px]"></div>
        <Button
          class="mt-6"
          :variant="calc.period === 'monthly' ? 'primary' : 'secondary'"
          block
          :disabled="orderLocked"
          @click="calc.period = 'monthly'"
        >
          {{ t('subscribe.card.monthlyCta') }}
        </Button>
      </div>

      <!-- Yearly card (recommended) -->
      <div
        class="relative rounded-2xl border-2 border-brand-cobalt bg-white p-5 sm:p-6 flex flex-col transition-all duration-150"
        :class="calc.period === 'yearly'
          ? 'bg-brand-50/40 ring-4 ring-brand-cobalt/15 shadow-md'
          : ''"
      >
        <!-- Two chips side-by-side when selected:
               - DIREKOMENDASIKAN — persistent brand-cobalt label,
                 always present, means "platform recommends this
                 tier".
               - TERPILIH — emerald + ✓, only when active, means
                 "user picked this".
             Two visually distinct colors so the meaning of each is
             obvious even when they sit next to each other. -->
        <span class="absolute -top-2.5 left-4 inline-flex items-center gap-1.5">
          <span class="inline-flex items-center rounded-full bg-brand-cobalt text-white px-2.5 py-0.5 text-[10px] font-black uppercase tracking-widest shadow-sm">
            {{ t('subscribe.card.recommended') }}
          </span>
          <span
            v-if="calc.period === 'yearly'"
            class="inline-flex items-center gap-1 rounded-full bg-emerald-500 text-white px-2.5 py-0.5 text-[10px] font-black uppercase tracking-widest shadow-sm"
          >
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <polyline points="20 6 9 17 4 12" />
            </svg>
            {{ t('subscribe.card.selected') }}
          </span>
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
        <div class="flex-1 min-h-[24px]"></div>
        <Button
          class="mt-6"
          :variant="calc.period === 'yearly' ? 'primary' : 'secondary'"
          block
          :disabled="orderLocked"
          @click="calc.period = 'yearly'"
        >
          {{ t('subscribe.card.yearlyCta') }}
        </Button>
      </div>
    </section>

    <!-- ── Existing demo banner ─────────────────────────────────── -->
    <div
      v-if="isAuthenticated && hasTenants && !orderLocked"
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

          <!--
            Wipe demo scenarios toggle. Only shown when:
              1. The picked tenant is still a demo (is_demo=true), AND
              2. It actually has data worth wiping (student + staff > 0).
            Default on — most admins converting demo→paid don't want the
            dummy siswa/guru accidentally visible to real students later.
          -->
          <label
            v-if="selectedTenant?.is_demo && (selectedTenant.student_count + selectedTenant.staff_count) > 0"
            class="mt-3 flex items-start gap-2 rounded-md bg-white/80 border border-blue-200 p-2.5 cursor-pointer"
          >
            <input
              type="checkbox"
              class="mt-0.5 h-4 w-4 text-brand-cobalt focus:ring-brand-cobalt rounded border-slate-300"
              :checked="wipeDemoData"
              @change="wipeDemoData = ($event.target as HTMLInputElement).checked"
            />
            <span class="flex-1 min-w-0 text-[12px] text-blue-900 leading-snug">
              <span class="font-semibold block">
                Hapus data dummy dari demo (siswa, guru, sesi contoh)
              </span>
              <span class="text-blue-800/80 text-[11px]">
                Mulai berlangganan dari kosong. Akun admin, WhatsApp, dan pengaturan tenant tetap aman —
                yang dihapus hanya data seed contoh. Matikan untuk mempertahankan data demo saat ini.
              </span>
            </span>
          </label>
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

    <!-- Wizard CTA — visible only on the fresh-signup path (no
         existing demo tenant selected). Redirects to /subscribe/new
         for users who prefer a guided multi-step flow. -->
    <div
      v-if="!orderLocked && !usingExistingTenant"
      class="rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:p-5 flex flex-col sm:flex-row items-start sm:items-center gap-3 sm:gap-4"
    >
      <div class="flex-1 min-w-0">
        <p class="text-[11px] font-black uppercase tracking-widest text-brand-cobalt">
          {{ t('subscribe.wizardCta.kicker') }}
        </p>
        <p class="mt-1 text-sm text-slate-800 leading-relaxed">
          {{ t('subscribe.wizardCta.body') }}
        </p>
      </div>
      <RouterLink
        to="/subscribe/new"
        class="inline-flex items-center justify-center rounded-lg bg-brand-cobalt hover:bg-brand-dark-blue text-white font-semibold px-4 py-2.5 text-sm transition-colors whitespace-nowrap"
      >
        {{ t('subscribe.wizardCta.action') }} →
      </RouterLink>
    </div>

    <!-- ── Signup / confirm card (hidden after order placed) ────── -->
    <SubscribeSignupForm
      v-if="!orderLocked"
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

    <!--
      Order-status card — replaces the signup form once we've placed a
      pending manual-transfer order. Holds three things:
        1. A snapshot of what the user ordered (period, seats, amount)
           so they can double-check before transferring.
        2. Bank details + reference code, same info the amber block
           used to show — folded in here so there's only one panel.
        3. A prominent "Ubah pesanan" secondary CTA so a mistake in the
           seat sliders doesn't dead-end the flow.
      Rendered ABOVE the two pricing cards' section-order because it's
      the primary "what do I do next?" surface once submitted.
    -->
    <section
      v-if="orderLocked && bankInfo && orderSnapshot"
      id="subscribe-order-summary"
      class="rounded-2xl border-2 overflow-hidden shadow-sm transition-colors duration-300"
      :class="transferNotified
          ? 'border-emerald-300 bg-emerald-50/50'
          : 'border-amber-300 bg-amber-50/50'"
    >
      <!--
        Header transforms once the customer taps "Sudah transfer":
          - Amber "Menunggu pembayaran" clock → Emerald "Terima kasih!"
            check icon that scales in from 90%. Copy explains verification
            timeline so the customer isn't left wondering what happens next.
        Transition is subtle (opacity + translate) so it doesn't feel
        gaudy — the color swap alone is already a strong signal.
      -->
      <transition
        enter-active-class="transition-all duration-300 ease-out"
        leave-active-class="transition-all duration-200 ease-in"
        enter-from-class="opacity-0 -translate-y-1"
        leave-to-class="opacity-0 translate-y-1"
        mode="out-in"
      >
        <header
          v-if="!transferNotified"
          key="pending"
          class="flex items-start gap-3 p-5 border-b border-amber-200 bg-amber-100/60"
        >
          <div class="flex-shrink-0 w-10 h-10 rounded-lg bg-amber-500 text-white grid place-items-center">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10" />
              <polyline points="12 6 12 12 16 14" />
            </svg>
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-[10px] font-black uppercase tracking-widest text-amber-700">
              {{ t('subscribe.orderStatus.kicker') }}
            </p>
            <h3 class="text-base font-bold text-amber-900 leading-tight mt-0.5">
              {{ t('subscribe.orderStatus.title') }}
            </h3>
            <p class="text-[12px] text-amber-800/90 mt-1 leading-relaxed">
              {{ t('subscribe.orderStatus.subtitle') }}
            </p>
          </div>
        </header>
        <header
          v-else
          key="thanks"
          class="flex items-start gap-3 p-5 border-b border-emerald-200 bg-emerald-100/60"
        >
          <div class="flex-shrink-0 w-10 h-10 rounded-lg bg-emerald-500 text-white grid place-items-center animate-thanks-pop">
            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12" />
            </svg>
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-[10px] font-black uppercase tracking-widest text-emerald-700">
              {{ t('subscribe.orderStatus.thanksKicker') }}
            </p>
            <h3 class="text-base font-bold text-emerald-900 leading-tight mt-0.5">
              {{ t('subscribe.orderStatus.thanksTitle') }}
            </h3>
            <p class="text-[12px] text-emerald-800/90 mt-1 leading-relaxed">
              {{ t('subscribe.orderStatus.thanksSubtitle') }}
            </p>
          </div>
        </header>
      </transition>

      <div class="p-5 space-y-5">
        <!-- What the user ordered — visible at a glance -->
        <dl class="grid grid-cols-1 sm:grid-cols-3 gap-4 rounded-xl bg-white border border-amber-200 p-4">
          <div>
            <dt class="text-[10px] font-black uppercase tracking-widest text-slate-500">
              {{ t('subscribe.orderStatus.planLabel') }}
            </dt>
            <dd class="mt-1 text-sm font-bold text-slate-900">
              {{ orderSnapshot.period === 'yearly'
                  ? t('subscribe.calc.yearly')
                  : t('subscribe.calc.monthly') }}
            </dd>
          </div>
          <div>
            <dt class="text-[10px] font-black uppercase tracking-widest text-slate-500">
              {{ t('subscribe.orderStatus.seatsLabel') }}
            </dt>
            <dd class="mt-1 text-sm font-semibold text-slate-900 tabular-nums leading-tight">
              {{ orderSnapshot.studentCount }}
              <span class="font-normal text-slate-500 text-xs">{{ t('subscribe.calc.unitStudent') }}</span>
              <span class="text-slate-400"> · </span>
              {{ orderSnapshot.staffCount }}
              <span class="font-normal text-slate-500 text-xs">
                {{ form.tenantType === 'bimbel'
                    ? t('subscribe.calc.unitTutor')
                    : t('subscribe.calc.unitStaff') }}
              </span>
            </dd>
          </div>
          <div>
            <dt class="text-[10px] font-black uppercase tracking-widest text-slate-500">
              {{ t('subscribe.orderStatus.amountLabel') }}
            </dt>
            <dd class="mt-1 text-lg font-black text-slate-900 tabular-nums leading-tight">
              {{ money(orderSnapshot.amount) }}
            </dd>
          </div>
        </dl>

        <!-- Bank details block -->
        <div>
          <h4 class="text-sm font-bold text-amber-900 mb-2">
            {{ t('subscribe.bank.title') }}
          </h4>
          <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3 text-[13px]">
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

        <!--
          "Sudah transfer" CTA — the primary next action for the
          customer while `!transferNotified`. After the click resolves
          the whole card flips to the thanks state and this section
          swaps for a soft confirmation strip so the user isn't tempted
          to re-tap (backend rate-limits that to a silent no-op, but
          suppressing the affordance is a nicer UX than a "you already
          did this" hint).
        -->
        <transition
          enter-active-class="transition-all duration-300 ease-out"
          leave-active-class="transition-all duration-200 ease-in"
          enter-from-class="opacity-0 scale-95"
          leave-to-class="opacity-0 scale-95"
          mode="out-in"
        >
          <div v-if="!transferNotified" key="cta" class="space-y-2">
            <button
              type="button"
              class="w-full inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 hover:bg-emerald-700 disabled:bg-emerald-400 disabled:cursor-not-allowed text-white font-semibold px-4 py-3 text-sm shadow-sm transition-colors"
              :disabled="notifyingTransfer"
              @click="onMarkTransferred"
            >
              <svg v-if="notifyingTransfer" class="animate-spin" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 12a9 9 0 1 1-6.219-8.56" />
              </svg>
              <svg v-else xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="20 6 9 17 4 12" />
              </svg>
              {{ notifyingTransfer
                  ? t('subscribe.orderStatus.markingTransferred')
                  : t('subscribe.orderStatus.markTransferredCta') }}
            </button>
            <p class="text-[11px] text-slate-500 text-center leading-relaxed px-2">
              {{ t('subscribe.orderStatus.markTransferredHint') }}
            </p>
          </div>
          <div
            v-else
            key="confirmed"
            class="rounded-xl border border-emerald-200 bg-white p-4 flex items-start gap-3"
          >
            <div class="flex-shrink-0 w-8 h-8 rounded-lg bg-emerald-100 text-emerald-700 grid place-items-center">
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                <polyline points="22 4 12 14.01 9 11.01" />
              </svg>
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-[13px] font-bold text-emerald-900">
                {{ t('subscribe.orderStatus.confirmedTitle') }}
              </p>
              <p class="mt-0.5 text-[11px] text-emerald-800/90 leading-relaxed">
                {{ t('subscribe.orderStatus.confirmedSubtitle') }}
              </p>
            </div>
          </div>
        </transition>

        <!--
          Actions row.

          - `!transferNotified`: original two-button row — "Ubah pesanan"
            (secondary, amber-tinted) + "Kembali ke dashboard" (primary
            cobalt). Two options because the user still has choices
            here (finish transferring, or bail out and re-edit).
          - `transferNotified`: the "next action" is unambiguous — go
            back to the app and wait for the activation email. Promote
            "Kembali ke dashboard" to a big full-width emerald CTA (same
            palette as the thanks card so it reads as the continuation
            of that motion) and drop the secondary — nothing else makes
            sense at that point.
        -->
        <transition
          enter-active-class="transition-all duration-300 ease-out"
          leave-active-class="transition-all duration-200 ease-in"
          enter-from-class="opacity-0 translate-y-1"
          leave-to-class="opacity-0 translate-y-1"
          mode="out-in"
        >
          <div
            v-if="!transferNotified"
            key="two-actions"
            class="flex flex-col sm:flex-row-reverse gap-2 pt-1"
          >
            <RouterLink
              v-if="isAuthenticated"
              to="/"
              class="inline-flex items-center justify-center rounded-lg bg-brand-cobalt hover:bg-brand-dark-blue text-white font-semibold px-4 py-2.5 text-sm transition-colors"
            >
              {{ t('subscribe.orderStatus.backToAppCta') }}
            </RouterLink>
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-lg border border-amber-300 bg-white hover:bg-amber-50 text-amber-900 font-semibold px-4 py-2.5 text-sm transition-colors"
              @click="onEditOrder"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" class="mr-1.5">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                <path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
              </svg>
              {{ t('subscribe.orderStatus.editCta') }}
            </button>
          </div>
          <RouterLink
            v-else-if="isAuthenticated"
            key="one-action"
            to="/"
            class="mt-1 w-full inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-semibold px-4 py-3 text-sm shadow-sm transition-colors"
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2v-6h-2v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            </svg>
            {{ t('subscribe.orderStatus.backToAppCta') }}
          </RouterLink>
        </transition>
      </div>
    </section>

    <!--
      Payment gateway strip.
      When Midtrans isn't offered by this deployment, the strip is
      REPLACED by a compact "Metode pembayaran: transfer manual ke [X]"
      panel so the user sees exactly how they'll pay upfront — no
      confusing checkbox to tick, no Midtrans chips they can't use.
      Hidden entirely once the order is locked — user is past choosing
      a gateway at that point.
    -->
    <PaymentGatewayStrip
      v-if="!manualOnly && !orderLocked"
      :supported-gateways="plan.supported_gateways"
      :manual-transfer="manualTransfer"
      @update:manualTransfer="manualTransfer = $event"
    />
    <section
      v-else-if="manualOnly && !orderLocked"
      class="rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:p-5"
    >
      <div class="flex items-start gap-3">
        <div class="flex-shrink-0 w-9 h-9 rounded-lg bg-white text-slate-700 grid place-items-center border border-slate-200">
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="7" width="18" height="12" rx="2" />
            <path d="M3 11h18" />
          </svg>
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-[11px] font-black uppercase tracking-widest text-slate-500">
            {{ t('subscribe.gateway.manualOnlyKicker') }}
          </p>
          <p class="mt-0.5 text-sm font-semibold text-slate-900">
            {{ t('subscribe.gateway.manualOnlyTitle') }}
          </p>
          <p v-if="plan.bank_transfer" class="mt-2 text-[13px] text-slate-700">
            <span>{{ t('subscribe.gateway.manualOnlyTransferTo') }}</span>
            <span class="font-semibold">{{ plan.bank_transfer.bank_name }}</span>
            <span> · </span>
            <span class="font-mono font-semibold">{{ plan.bank_transfer.account_number }}</span>
            <span class="block text-[12px] text-slate-500 mt-0.5">
              {{ t('subscribe.gateway.manualOnlyAccountHolder') }}
              <span class="text-slate-700 font-medium">{{ plan.bank_transfer.account_holder }}</span>
            </span>
          </p>
          <p class="mt-2 text-[11px] text-slate-500 leading-relaxed">
            {{ t('subscribe.gateway.manualOnlyHint') }}
          </p>
        </div>
      </div>
    </section>

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

<style scoped>
/*
  Tiny celebration for the "Terima kasih" check icon — a single pop
  when the emerald header mounts. Kept scoped so no other check icon
  on the page inherits this. We deliberately don't loop it: repeating
  animation on a status card feels like an unfinished loading state.
*/
@keyframes thanks-pop {
  0% {
    transform: scale(0.6);
    opacity: 0;
  }
  60% {
    transform: scale(1.15);
    opacity: 1;
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}
.animate-thanks-pop {
  animation: thanks-pop 420ms cubic-bezier(0.34, 1.56, 0.64, 1) both;
}
@media (prefers-reduced-motion: reduce) {
  .animate-thanks-pop {
    animation: none;
  }
}
</style>
