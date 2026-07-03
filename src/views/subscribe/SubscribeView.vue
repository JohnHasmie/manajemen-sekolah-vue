<!--
  SubscribeView.vue — modular-SaaS redesign of the /subscribe surface.
  Matches the approved mockup set:
    · mockup 1 — tenant detection landing (hero + tenant cards)
    · mockup 2 — conversion state (selected tenant + module rows +
                 sticky calculator + payment method cards)
    · mockup 3 — post-order transfer instructions + thanks card

  This view runs three states in the same DOM (no route change):
    STATE_LANDING = signed-in user with demo tenants to convert
    STATE_CONVERT = a tenant is picked, user is choosing modules + gateway
    STATE_ORDER   = order created, waiting for transfer confirmation
    STATE_THANKS  = user pressed "sudah transfer"

  Signed-out users see a lean Google-signin card so the flow always
  works from a fresh browser session.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';
import {
  SubscriptionBillingService,
  markTransferredByToken,
  shareTokenFromUrl,
} from '@/services/billing.service';
import type {
  ManualTransferInfo,
  ModuleCatalog,
  ModularQuote,
  PricingPlan,
  SubscribeResult,
  SubscriptionTenant,
  BillingPeriod,
} from '@/types/subscription-billing';

import TenantPickerHero from '@/components/subscribe/TenantPickerHero.vue';
import SelectedTenantStrip from '@/components/subscribe/SelectedTenantStrip.vue';
import BundleStrip from '@/components/subscribe/BundleStrip.vue';
import ModuleRow from '@/components/subscribe/ModuleRow.vue';
import PricingCalculatorV2 from '@/components/subscribe/PricingCalculatorV2.vue';
import PaymentMethodCards from '@/components/subscribe/PaymentMethodCards.vue';
import OrderTransferCard from '@/components/subscribe/OrderTransferCard.vue';
import OrderThanksCard from '@/components/subscribe/OrderThanksCard.vue';

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();
const google = useGoogleSignIn();

// ── State ──────────────────────────────────────────────────────────
const plan = ref<PricingPlan | null>(null);
const catalog = ref<ModuleCatalog | null>(null);
const myTenants = ref<SubscriptionTenant[]>([]);
const selectedTenant = ref<SubscriptionTenant | null>(null);
const loadingTenants = ref(false);
const loadingCatalog = ref(false);

const selectedKeys = ref<Set<string>>(new Set());
const period = ref<BillingPeriod>('monthly');
const wipeDemoData = ref(true);
const gateway = ref<'bank_transfer_manual' | 'midtrans'>('bank_transfer_manual');
const quote = ref<ModularQuote | null>(null);
const submitting = ref(false);
const errorMessage = ref<string | null>(null);
const loggingOut = ref(false);

interface OrderSnapshot {
  planLabel: string;
  studentCount: number;
  staffCount: number;
  amount: number;
  bankName: string;
  accountNumber: string;
  accountHolder: string;
  referenceCode: string;
  createdAt: string;
  shareToken: string | null;
  gateway: 'midtrans' | 'bank_transfer_manual';
}
const order = ref<OrderSnapshot | null>(null);
const notifyingTransfer = ref(false);
const transferNotified = ref(false);

const googleContainer = ref<HTMLElement | null>(null);

// ── Derived ────────────────────────────────────────────────────────
const state = computed<'landing' | 'convert' | 'order' | 'thanks'>(() => {
  if (order.value) return transferNotified.value ? 'thanks' : 'order';
  if (selectedTenant.value) return 'convert';
  return 'landing';
});

/**
 * Short content states (signin card, order transfer, thanks) look
 * marooned in the top-half of a tall viewport when they hug the top —
 * so we centre those vertically. Landing + convert states have their
 * own tall content that scrolls naturally and looks wrong when
 * centred, so they stay top-aligned.
 */
const centerContent = computed<boolean>(() => {
  if (!auth.isAuthenticated) return true;
  if (state.value === 'order') return true;
  if (state.value === 'thanks') return true;
  return false;
});

const midtransAvailable = computed(
  () => !!plan.value?.supported_gateways.includes('midtrans'),
);
const bankName = computed(() => plan.value?.bank_transfer?.bank_name ?? 'BSI');
const bankHolder = computed(
  () => plan.value?.bank_transfer?.account_holder ?? 'Yahya Al Hasymi',
);
const bankAccount = computed(() => plan.value?.bank_transfer?.account_number ?? '');

const expandedKeys = computed<string[]>(() => {
  const cat = catalog.value;
  if (!cat) return [...selectedKeys.value];
  const bundleKeys = Object.keys(cat.bundles);
  const out = new Set<string>();
  selectedKeys.value.forEach((k) => {
    if (bundleKeys.includes(k)) {
      cat.bundles[k].members.forEach((m) => out.add(m));
    } else {
      out.add(k);
      const requires = cat.optional[k]?.requires ?? [];
      requires.forEach((r) => out.add(r));
    }
  });
  return Array.from(out);
});

const autoIncluded = computed(() => {
  const map = new Map<string, string[]>();
  const cat = catalog.value;
  if (!cat) return map;
  selectedKeys.value.forEach((k) => {
    if (k in cat.bundles) return;
    const requires = cat.optional[k]?.requires ?? [];
    if (requires.length) {
      map.set(
        k,
        requires
          .map((r) => cat.optional[r]?.label)
          .filter(Boolean) as string[],
      );
    }
  });
  return map;
});

const bundleBenchmark = computed(() => {
  const cat = catalog.value;
  if (!cat || !selectedTenant.value) return null;
  const complete = cat.bundles['bundle_complete'];
  if (!complete) return null;
  const stu = selectedTenant.value.student_count;
  const sta = selectedTenant.value.staff_count;
  const total = complete.price_per_student * stu + complete.price_per_staff * sta;
  const bonus = complete.members.filter((m) => !expandedKeys.value.includes(m)).length;
  return {
    key: 'bundle_complete',
    label: complete.label,
    monthlyTotal: total,
    bonusModuleCount: bonus,
  };
});

// ── Effects ────────────────────────────────────────────────────────
async function loadPlan() {
  try {
    plan.value = await SubscriptionBillingService.getPlans();
  } catch (e) {
    console.warn('[SubscribeView.loadPlan]', (e as Error).message);
  }
}

async function loadCatalog() {
  loadingCatalog.value = true;
  try {
    catalog.value = await SubscriptionBillingService.getModuleCatalog();
  } catch (e) {
    console.warn('[SubscribeView.loadCatalog]', (e as Error).message);
  } finally {
    loadingCatalog.value = false;
  }
}

async function loadTenants() {
  if (!auth.isAuthenticated) {
    myTenants.value = [];
    return;
  }
  loadingTenants.value = true;
  try {
    myTenants.value = await SubscriptionBillingService.getMyTenants();
  } catch (e) {
    console.warn('[SubscribeView.loadTenants]', (e as Error).message);
  } finally {
    loadingTenants.value = false;
  }
}

// Preselect a sensible default: user's demo student/staff modules.
// We use bundle_complete on first landing so the calculator has a
// non-empty starting number.
function applyDefaultSelection() {
  if (!catalog.value) return;
  selectedKeys.value = new Set([
    'attendance_student',
    'attendance_staff',
    'grades',
    'finance',
  ]);
}

async function refreshQuote() {
  if (!selectedTenant.value || !catalog.value) return;
  if (selectedKeys.value.size === 0) {
    quote.value = null;
    return;
  }
  try {
    quote.value = await SubscriptionBillingService.quoteModular({
      student_count: selectedTenant.value.student_count,
      staff_count: selectedTenant.value.staff_count,
      plan: period.value,
      modules: Array.from(selectedKeys.value),
    });
  } catch (e) {
    console.warn('[SubscribeView.refreshQuote]', (e as Error).message);
  }
}

let quoteDebounce: number | null = null;
watch(
  [selectedKeys, period, selectedTenant],
  () => {
    if (quoteDebounce !== null) window.clearTimeout(quoteDebounce);
    quoteDebounce = window.setTimeout(refreshQuote, 250) as unknown as number;
  },
  { deep: true },
);

onMounted(async () => {
  await Promise.all([loadPlan(), loadCatalog(), loadTenants()]);
  if (!auth.isAuthenticated) {
    setTimeout(mountGoogleButton, 100);
  }
});

// ── Actions ────────────────────────────────────────────────────────
function pickTenant(t: SubscriptionTenant) {
  selectedTenant.value = t;
  if (selectedKeys.value.size === 0) applyDefaultSelection();
}

function switchTenant() {
  selectedTenant.value = null;
  order.value = null;
  quote.value = null;
}

function toggleModule(key: string) {
  const next = new Set(selectedKeys.value);
  const cat = catalog.value;
  if (next.has(key)) {
    next.delete(key);
  } else {
    // Selecting a bundle wipes the à la carte keys it covers.
    if (cat && key in cat.bundles) {
      const members = cat.bundles[key].members;
      members.forEach((m) => next.delete(m));
    }
    next.add(key);
  }
  selectedKeys.value = next;
}

function switchToBundle(key: string) {
  const next = new Set<string>([key]);
  selectedKeys.value = next;
}

function goToNewTenant() {
  router.push('/subscribe/new');
}

async function onSubmit() {
  if (!selectedTenant.value) return;
  if (selectedKeys.value.size === 0) {
    errorMessage.value = t('subscribe.errors.pickAtLeastOneModule', {}, { default: 'Pilih setidaknya satu modul.' });
    return;
  }
  submitting.value = true;
  errorMessage.value = null;
  try {
    const result = await SubscriptionBillingService.subscribe({
      tenant_id: selectedTenant.value.id,
      tenant_type: selectedTenant.value.tenant_type,
      plan: period.value,
      student_count: selectedTenant.value.student_count,
      staff_count: selectedTenant.value.staff_count,
      gateway: gateway.value,
      wipe_demo_data: selectedTenant.value.is_demo ? wipeDemoData.value : undefined,
      modules: Array.from(selectedKeys.value),
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
    await ensureMidtransSnap();
    if (window.snap?.pay) {
      window.snap.pay(result.snap_token, {
        onSuccess: () => router.push('/'),
        onPending: () => router.push('/'),
      });
    } else if (result.snap_redirect_url) {
      window.location.assign(result.snap_redirect_url);
    }
    return;
  }
  // Manual transfer path
  order.value = {
    planLabel: `${period.value === 'yearly' ? 'Tahunan' : 'Bulanan'} · ${selectedKeys.value.size} modul`,
    studentCount: selectedTenant.value?.student_count ?? 0,
    staffCount: selectedTenant.value?.staff_count ?? 0,
    amount: result.amount ?? quote.value?.chosen_amount ?? 0,
    bankName:
      result.bank_transfer_info?.bank_name ?? bankName.value,
    accountNumber:
      (result.bank_transfer_info as ManualTransferInfo | undefined)?.account_number
      ?? bankAccount.value,
    accountHolder:
      (result.bank_transfer_info as ManualTransferInfo | undefined)?.account_name
      ?? bankHolder.value,
    referenceCode: result.order_id,
    createdAt: new Date().toISOString(),
    shareToken: shareTokenFromUrl(result.share_url ?? null),
    gateway: 'bank_transfer_manual',
  };
}

async function onMarkTransferred() {
  if (!order.value?.shareToken) {
    transferNotified.value = true;
    return;
  }
  notifyingTransfer.value = true;
  try {
    await markTransferredByToken(order.value.shareToken);
    transferNotified.value = true;
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    notifyingTransfer.value = false;
  }
}

function editOrder() {
  order.value = null;
  transferNotified.value = false;
}

async function shareOrder() {
  const share = order.value;
  if (!share?.shareToken) return;
  const url = `${window.location.origin}/subscribe/transfer/${share.shareToken}`;
  try {
    await navigator.clipboard.writeText(url);
  } catch { /* non-fatal */ }
}

function goHome() {
  router.push('/');
}

function downloadInvoice() {
  window.open(`/subscribe/receipt/${order.value?.referenceCode}`, '_blank');
}

// ── Midtrans Snap loader (unchanged) ───────────────────────────────
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
  if (!MIDTRANS_CLIENT_KEY) return Promise.resolve();
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

// ── Google sign-in for anonymous visitors ──────────────────────────
async function mountGoogleButton() {
  if (auth.isAuthenticated || !googleContainer.value || !google.isEnabled.value) {
    return;
  }
  const w = googleContainer.value.clientWidth || 320;
  await google.mountButton(googleContainer.value, {
    width: w,
    theme: 'outline',
    text: 'continue_with',
  });
}
function flagSubscribeIntent(): void {
  try { sessionStorage.setItem('subscribe_intent_v1', '1'); } catch { /* non-fatal */ }
}

/**
 * Ganti akun Google. The user got here signed in with the wrong Gmail
 * (e.g. clicked the wrong Chrome profile) and needs to swap. We clear
 * the session locally + on the server, reset the picker state, then
 * re-mount the Google button so they can pick a different account in
 * the same tab — no full page reload needed.
 */
async function onSwitchAccount(): Promise<void> {
  if (loggingOut.value) return;
  loggingOut.value = true;
  try {
    await auth.logout();
  } catch (e) {
    // Non-fatal — auth.logout already clears session locally.
    console.warn('[SubscribeView.switchAccount]', (e as Error).message);
  } finally {
    // Reset view state so the wrong tenant list vanishes with the
    // wrong account, and the anonymous card renders again.
    myTenants.value = [];
    selectedTenant.value = null;
    order.value = null;
    quote.value = null;
    transferNotified.value = false;
    loggingOut.value = false;
    flagSubscribeIntent();
    // Re-mount the Google button on the next tick so the anonymous
    // signin card actually gets a fresh button.
    setTimeout(mountGoogleButton, 100);
  }
}
watch(() => auth.isAuthenticated, (v) => {
  if (v) {
    loadTenants();
  }
});
</script>

<template>
  <div class="sv-page">
    <!-- Persistent nav -->
    <div class="sv-nav">
      <div class="sv-logo">K</div>
      <div class="sv-brand">KamilEdu</div>
      <div class="sv-nav-links">
        <a
          href="https://wa.me/6285179819002"
          target="_blank"
          rel="noopener"
          class="sv-nav-link"
        >
          <i class="ti ti-message-circle" aria-hidden="true" />
          Bantuan
        </a>
        <div
          v-if="auth.isAuthenticated"
          class="sv-account"
        >
          <div class="sv-avatar" :title="auth.user?.email ?? undefined">
            {{ (auth.user?.name ?? auth.user?.email ?? '?').slice(0, 2).toUpperCase() }}
          </div>
          <div class="sv-account-menu">
            <div class="sv-account-email">
              {{ auth.user?.email ?? auth.user?.name ?? 'Akun Google' }}
            </div>
            <button
              type="button"
              class="sv-account-switch"
              :disabled="loggingOut"
              @click="onSwitchAccount"
            >
              <i class="ti ti-switch-horizontal" aria-hidden="true" />
              <template v-if="loggingOut">Keluar…</template>
              <template v-else>Ganti akun Google</template>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Main region flexes to fill vertical space between nav + footer.
         When a state's content is short (signin card, thanks card) the
         region centres it; when the content is tall (landing, convert)
         it scrolls normally. Keeps the footer sticky at the bottom
         without introducing empty gaps above it on wide viewports. -->
    <main class="sv-main-region" :class="{ 'is-centered': centerContent }">
      <!-- ANONYMOUS: sign in first -->
      <div v-if="!auth.isAuthenticated" class="sv-signin">
        <div class="sv-signin-card">
          <div class="sv-signin-h1">Masuk untuk mulai berlangganan</div>
          <p class="sv-signin-sub">
            Kami perlu tahu lembaga demo mana yang mau dilanjutkan. Masuk
            dengan akun Google yang sama seperti saat mendaftar demo.
          </p>
          <div
            ref="googleContainer"
            data-google-intent="subscribe"
            class="sv-google-slot"
            @pointerdown="flagSubscribeIntent"
          />
          <div class="sv-signin-alt">
            Belum punya demo? <a href="/register-demo">Coba demo dulu</a>
            atau <a href="/subscribe/new">daftar langsung berbayar</a>.
          </div>
        </div>
      </div>

      <!-- STATE_LANDING: tenant picker -->
      <TenantPickerHero
        v-else-if="state === 'landing'"
        :user-name="auth.user?.name ?? 'Anda'"
        :tenants="myTenants"
        :loading="loadingTenants"
        @select="pickTenant"
        @new-tenant="goToNewTenant"
      />

    <!-- STATE_CONVERT: selected + module picker + calculator -->
    <template v-else-if="state === 'convert' && selectedTenant && catalog">
      <a class="sv-back" href="#" @click.prevent="switchTenant">
        <i class="ti ti-arrow-left" style="font-size:13px" aria-hidden="true" />
        Kembali ke daftar lembaga
      </a>

      <SelectedTenantStrip
        :tenant="selectedTenant"
        @switch-tenant="switchTenant"
      />

      <div class="sv-body">
        <div class="sv-main">
          <!-- Step 1: modules -->
          <div class="sv-sec-head">
            <div class="sv-sec-num">1</div>
            <div class="sv-sec-lbl">Pilih modul yang akan dipakai</div>
            <div class="sv-sec-hint">Bisa ubah kapan saja</div>
          </div>

          <BundleStrip
            v-if="catalog.bundles.bundle_complete"
            label="Paket Lengkap · semua modul non-AI"
            description="9 modul: absensi, nilai, raport, jadwal, RPP, keuangan, komunikasi, aktivitas kelas."
            :price-per-student="catalog.bundles.bundle_complete.price_per_student"
            :active="selectedKeys.has('bundle_complete')"
            @select="toggleModule('bundle_complete')"
          />

          <div class="sv-modrows">
            <ModuleRow
              v-for="key in Object.keys(catalog.optional)"
              :key="key"
              :item="catalog.optional[key]"
              :selected="selectedKeys.has(key) || expandedKeys.includes(key)"
              :tenant-type="selectedTenant.tenant_type"
              @toggle="toggleModule(key)"
            />
          </div>

          <!-- Step 2: Wipe demo -->
          <template v-if="selectedTenant.is_demo">
            <div class="sv-sec-head" style="margin-top:20px">
              <div class="sv-sec-num">2</div>
              <div class="sv-sec-lbl">Data awal setelah aktif</div>
            </div>

            <label class="sv-wipe">
              <div class="sv-wipe-cb" :class="{ 'is-on': wipeDemoData }">
                <i v-if="wipeDemoData" class="ti ti-check" style="font-size:12px" aria-hidden="true" />
                <input
                  v-model="wipeDemoData"
                  type="checkbox"
                  class="sr-only"
                />
              </div>
              <div>
                <div class="sv-wipe-t">Hapus data contoh demo, mulai dari kosong</div>
                <div class="sv-wipe-d">
                  Data siswa, guru, dan tagihan bawaan demo akan
                  dihapus. Anda mulai dengan tenant kosong siap diisi
                  data asli. Kalau tidak dicentang, data demo
                  dipertahankan sebagai starter.
                </div>
              </div>
            </label>
          </template>

          <!-- Step 3: Payment -->
          <div class="sv-sec-head" style="margin-top:20px">
            <div class="sv-sec-num">{{ selectedTenant.is_demo ? 3 : 2 }}</div>
            <div class="sv-sec-lbl">Cara bayar</div>
          </div>

          <PaymentMethodCards
            v-model:value="gateway"
            :midtrans-available="midtransAvailable"
            :bank-name="bankName"
            :bank-holder="bankHolder"
          />

          <p v-if="errorMessage" class="sv-err">{{ errorMessage }}</p>
        </div>

        <div class="sv-side">
          <PricingCalculatorV2
            :tenant-name="selectedTenant.name"
            :student-count="selectedTenant.student_count"
            :staff-count="selectedTenant.staff_count"
            v-model:plan="period"
            :quote="quote"
            :catalog="catalog"
            :tenant-type="selectedTenant.tenant_type"
            :submitting="submitting"
            :yearly-discount-pct="plan?.yearly_discount_pct"
            :bundle-benchmark="bundleBenchmark"
            submit-label="Buat pesanan & tampilkan transfer"
            @submit="onSubmit"
            @switch-to-bundle="switchToBundle"
          />
        </div>
      </div>
    </template>

    <!-- STATE_ORDER: transfer instructions -->
    <div v-else-if="state === 'order' && order" class="sv-order-wrap">
      <a class="sv-back" href="#" @click.prevent="editOrder">
        <i class="ti ti-arrow-left" style="font-size:13px" aria-hidden="true" />
        Kembali ke pilihan modul
      </a>
      <OrderTransferCard
        :plan-label="order.planLabel"
        :student-count="order.studentCount"
        :staff-count="order.staffCount"
        :amount="order.amount"
        :bank-name="order.bankName"
        :account-number="order.accountNumber"
        :account-holder="order.accountHolder"
        :reference-code="order.referenceCode"
        :created-at="order.createdAt"
        :submitting="notifyingTransfer"
        @mark-transferred="onMarkTransferred"
        @edit="editOrder"
        @share="shareOrder"
      />
    </div>

    <!-- STATE_THANKS: confirmation -->
    <div v-else-if="state === 'thanks' && order" class="sv-order-wrap">
      <OrderThanksCard
        :email="auth.user?.email"
        :whatsapp="auth.user?.phone_number ?? null"
        :expired-demo="selectedTenant?.subscription_status === 'expired'"
        @home="goHome"
        @invoice="downloadInvoice"
      />
    </div>
    </main>

    <!-- Minimal footer — brand + legal micro-strip. The four trust
         chips (TLS / Midtrans-BSI / cancel / support) have been
         dropped: TLS is table-stakes, payment methods live inline on
         the picker, cancel-anytime is already in the calculator
         subcopy, and Bantuan is still one click away in the nav
         above. What's left tells the user WHOSE product this is
         and where the legals are — nothing that competes for
         attention with the primary CTA. -->
    <footer class="sv-trust">
      <div class="sv-trust-inner">
        <div class="sv-trust-brand">
          <div class="sv-trust-logo">K</div>
          <div>
            <div class="sv-trust-brand-name">KamilEdu</div>
            <div class="sv-trust-brand-tag">Manajemen sekolah &amp; bimbel</div>
          </div>
        </div>
        <div class="sv-trust-legal">
          &copy; {{ new Date().getFullYear() }} KamilEdu &middot;
          <a href="/legal/terms">Syarat</a> &middot;
          <a href="/legal/privacy">Privasi</a>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.sv-page {
  min-height: 100vh;
  background: #FBFCFE;
  color: #0F172A;
  font-family: var(--font-sans);
  display: flex;
  flex-direction: column;
}

/* Grows to fill vertical space between nav + footer so the footer
   naturally sticks to the bottom on short-content states, without
   introducing awkward empty gaps under long-content ones. */
.sv-main-region {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  min-height: 0;
}
/* .is-centered — grid drop-in for the short states so the card sits
   in the exact middle of the region on every viewport height. Uses
   grid instead of flex align-items so wide-viewport centring still
   collapses gracefully on mobile without the card being cut off. */
.sv-main-region.is-centered {
  display: grid;
  place-items: center;
  padding: 32px 22px;
}

.sv-nav {
  background: #FFFFFF;
  padding: 14px 22px;
  border-bottom: 0.5px solid #E7ECF3;
  display: flex; align-items: center; gap: 14px;
}
.sv-logo {
  width: 30px; height: 30px; border-radius: 8px;
  background: linear-gradient(135deg, #1B6FB8 0%, #113E75 100%);
  color: #fff;
  display: grid; place-items: center;
  font-weight: 600; font-size: 13px;
}
.sv-brand { font-size: 13.5px; font-weight: 600; letter-spacing: -0.1px; }
.sv-nav-links {
  margin-left: auto;
  display: flex; align-items: center; gap: 16px;
  font-size: 12px; color: #64748B;
}
.sv-nav-link {
  color: #64748B; text-decoration: none;
  display: inline-flex; align-items: center; gap: 6px;
}
.sv-nav-link:hover { color: #1B6FB8; }
.sv-account {
  position: relative;
  display: flex; align-items: center;
}
.sv-avatar {
  width: 30px; height: 30px; border-radius: 50%;
  background: #E6F1FB; color: #185FA5;
  display: grid; place-items: center;
  font-size: 11px; font-weight: 600;
  cursor: pointer;
}
.sv-account-menu {
  position: absolute;
  top: calc(100% + 8px); right: 0;
  min-width: 210px;
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 10px;
  box-shadow: 0 4px 14px rgba(15, 23, 42, 0.10),
              0 12px 36px rgba(15, 23, 42, 0.06);
  padding: 10px;
  opacity: 0; transform: translateY(-4px);
  pointer-events: none;
  transition: opacity 0.15s, transform 0.15s;
  z-index: 20;
}
.sv-account:hover .sv-account-menu,
.sv-account:focus-within .sv-account-menu {
  opacity: 1; transform: translateY(0);
  pointer-events: auto;
}
.sv-account-email {
  font-size: 11.5px; color: #0F172A;
  padding: 4px 6px 8px;
  border-bottom: 0.5px solid #F1F5F9;
  margin-bottom: 6px;
  word-break: break-all;
}
.sv-account-switch {
  width: 100%;
  display: flex; align-items: center; gap: 8px;
  padding: 8px 10px;
  border-radius: 8px;
  background: transparent; border: none;
  font-family: inherit;
  font-size: 12px; color: #185FA5;
  cursor: pointer; text-align: left;
}
.sv-account-switch:hover:not(:disabled) { background: #F0F7FF; }
.sv-account-switch:disabled { opacity: 0.6; cursor: not-allowed; }
.sv-account-switch i { color: #1B6FB8; }

/* Sign-in wrapper is now a plain block — vertical centring lives on
   the parent .sv-main-region.is-centered so the card sits at the
   exact optical midpoint between nav + footer on every viewport. */
.sv-signin { width: 100%; display: flex; justify-content: center; }
.sv-signin-card {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 14px;
  padding: 28px 24px;
  max-width: 420px;
  width: 100%;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04),
              0 8px 24px rgba(15, 23, 42, 0.06);
  text-align: center;
}
.sv-signin-h1 {
  font-size: 20px; font-weight: 500;
  letter-spacing: -0.2px; color: #0F172A;
}
.sv-signin-sub {
  font-size: 12.5px; color: #64748B;
  margin: 8px 0 20px;
  line-height: 1.55;
}
.sv-google-slot {
  min-height: 42px;
  display: flex; justify-content: center;
}
.sv-signin-alt {
  margin-top: 18px;
  font-size: 11.5px; color: #64748B;
}
.sv-signin-alt a { color: #1B6FB8; text-decoration: underline; text-underline-offset: 2px; }

.sv-back {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 11.5px; color: #64748B;
  text-decoration: none;
  padding: 12px 22px 8px;
}
.sv-back:hover { color: #1B6FB8; }

.sv-body {
  display: grid;
  /* Matches the wizard — 340px keeps large IDR amounts on one line
     and the bundle CTA from wrapping. */
  grid-template-columns: minmax(0, 1fr) 340px;
  gap: 0;
  border-top: 0.5px solid #E7ECF3;
  background: #FFFFFF;
}
.sv-main { padding: 18px 22px 26px; }
.sv-side {
  background: #F5F8FC;
  border-left: 0.5px solid #E7ECF3;
  padding: 18px;
}

.sv-sec-head {
  display: flex; align-items: center; gap: 8px;
  margin: 10px 0 8px;
}
.sv-sec-num {
  width: 22px; height: 22px; border-radius: 50%;
  background: #1B6FB8; color: #fff;
  display: grid; place-items: center;
  font-size: 11px; font-weight: 600;
  flex-shrink: 0;
}
.sv-sec-lbl {
  font-size: 13.5px; font-weight: 500;
  letter-spacing: -0.1px; color: #0F172A;
}
.sv-sec-hint {
  font-size: 11px; color: #64748B;
  margin-left: auto;
}

.sv-modrows {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  overflow: hidden;
}

.sv-wipe {
  margin-top: 12px;
  padding: 12px 14px;
  background: #FFFBEB;
  border: 0.5px solid #FDE68A;
  border-radius: 10px;
  display: flex; align-items: flex-start; gap: 10px;
  cursor: pointer;
}
.sv-wipe-cb {
  width: 18px; height: 18px; border-radius: 5px;
  background: #FFFFFF;
  border: 1.5px solid #FDE68A;
  color: transparent;
  display: grid; place-items: center;
  flex-shrink: 0;
  margin-top: 1px;
  position: relative;
}
.sv-wipe-cb.is-on {
  background: #B45309;
  border-color: #B45309;
  color: #fff;
}
.sr-only {
  position: absolute;
  width: 1px; height: 1px;
  padding: 0; margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap; border: 0;
}
.sv-wipe-t { font-size: 11.5px; font-weight: 500; color: #78350F; }
.sv-wipe-d {
  font-size: 10.5px; color: #92400E;
  margin-top: 2px; line-height: 1.45;
}

.sv-err {
  margin-top: 12px;
  font-size: 12px; color: #B91C1C;
  padding: 10px 12px;
  border-radius: 8px;
  background: #FEE2E2;
  border: 0.5px solid #FCA5A5;
}

.sv-order-wrap {
  padding: 12px 22px 32px;
  max-width: 720px;
  margin: 0 auto;
}

/* Minimal footer — brand mark on the left, legal micro-strip on the
   right. Cheap trust chips (TLS / Midtrans / cancel / support) were
   the wrong signal to lead with: they read as filler at the bottom of
   an otherwise clean surface. Kept: WHOSE product this is + where the
   legals live. Everything else lives inline where the user actually
   needs it (payment picker, calculator subcopy, Bantuan link in the
   nav above). */
.sv-trust {
  border-top: 0.5px solid #E7ECF3;
  background: #FBFDFF;
}
.sv-trust-inner {
  max-width: 960px;
  margin: 0 auto;
  padding: 16px 22px;
  display: flex; align-items: center; gap: 18px;
  flex-wrap: wrap;
}
.sv-trust-brand {
  display: flex; align-items: center; gap: 10px;
  min-width: 0;
}
.sv-trust-logo {
  width: 30px; height: 30px; border-radius: 8px;
  background: linear-gradient(135deg, #1B6FB8 0%, #113E75 100%);
  color: #fff;
  display: grid; place-items: center;
  font-weight: 600; font-size: 12.5px;
  flex-shrink: 0;
}
.sv-trust-brand-name {
  font-size: 12px; font-weight: 600; color: #0F172A;
  letter-spacing: -0.1px;
}
.sv-trust-brand-tag {
  font-size: 10.5px; color: #64748B;
  margin-top: 1px;
}
.sv-trust-legal {
  margin-left: auto;
  font-size: 11px; color: #94A3B8;
}
.sv-trust-legal a { color: #64748B; text-decoration: none; }
.sv-trust-legal a:hover { color: #1B6FB8; text-decoration: underline; }

@media (max-width: 640px) {
  .sv-trust-inner {
    justify-content: center; text-align: center;
    gap: 8px;
  }
  .sv-trust-legal { margin-left: 0; }
}

@media (max-width: 720px) {
  .sv-body { grid-template-columns: 1fr; }
  .sv-side { border-left: none; border-top: 0.5px solid #E7ECF3; }
}
</style>
