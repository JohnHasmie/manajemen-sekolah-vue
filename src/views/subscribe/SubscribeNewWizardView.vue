<!--
  SubscribeNewWizardView.vue — 5-step wizard for brand-new tenants
  (no demo), redesigned to match the approved mockups:
    · WizardChrome (nav + step indicator)
    · ModuleCatalogGrid + BundleStrip on Step 4
    · Sticky PricingCalculatorV2 with AI quota stepper + bundle nudge
    · Manual/Midtrans payment method cards on Step 5

  Preserves the underlying form + Google-signin gate + subscribe API
  contract from the previous implementation; the difference is
  entirely UI + module selection payload.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
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
  BillingPeriod,
  TenantType,
} from '@/types/subscription-billing';

import WizardChrome from '@/components/subscribe/WizardChrome.vue';
import BundleStrip from '@/components/subscribe/BundleStrip.vue';
import ModuleCatalogGrid from '@/components/subscribe/ModuleCatalogGrid.vue';
import AiQuotaStepper from '@/components/subscribe/AiQuotaStepper.vue';
import PricingCalculatorV2 from '@/components/subscribe/PricingCalculatorV2.vue';
import PaymentMethodCards from '@/components/subscribe/PaymentMethodCards.vue';
import OrderTransferCard from '@/components/subscribe/OrderTransferCard.vue';
import OrderThanksCard from '@/components/subscribe/OrderThanksCard.vue';

const router = useRouter();
const auth = useAuthStore();
const google = useGoogleSignIn();

const STEPS = [
  { key: 'lembaga', label: 'Data lembaga' },
  { key: 'admin', label: 'Admin' },
  { key: 'kapasitas', label: 'Kapasitas' },
  { key: 'modul', label: 'Pilih modul' },
  { key: 'bayar', label: 'Bayar' },
] as const;

const stepIndex = ref(0);

const form = reactive({
  tenant_type: 'sekolah' as TenantType,
  tenant_name: '',
  education_level: 'SMP',
  city: '',
  address: '',
  npsn: '',
  admin_name: '',
  admin_job_title: 'Kepala Sekolah',
  admin_whatsapp: '',
  admin_email: '',
  student_count: 100,
  staff_count: 10,
});

const plan = ref<PricingPlan | null>(null);
const catalog = ref<ModuleCatalog | null>(null);
const period = ref<BillingPeriod>('monthly');
const gateway = ref<'bank_transfer_manual' | 'midtrans'>('bank_transfer_manual');
const selectedKeys = ref<Set<string>>(new Set([
  'attendance_student',
  'attendance_staff',
  'grades',
  'report_cards',
  'finance',
]));
const aiQuota = ref<Record<string, number>>({});
const quote = ref<ModularQuote | null>(null);

const submitting = ref(false);
const errorMessage = ref<string | null>(null);

const googleContainer = ref<HTMLElement | null>(null);

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
}
const order = ref<OrderSnapshot | null>(null);
const notifyingTransfer = ref(false);
const transferNotified = ref(false);

// ── Derived ────────────────────────────────────────────────────────
const activeStep = computed(() => STEPS[stepIndex.value]?.key);

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
  const out = new Set<string>();
  selectedKeys.value.forEach((k) => {
    if (k in cat.bundles) {
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
  if (!cat) return null;
  const complete = cat.bundles['bundle_complete'];
  if (!complete) return null;
  const total =
    complete.price_per_student * form.student_count +
    complete.price_per_staff * form.staff_count;
  const bonus = complete.members.filter(
    (m) => !expandedKeys.value.includes(m),
  ).length;
  return {
    key: 'bundle_complete',
    label: complete.label,
    monthlyTotal: total,
    bonusModuleCount: bonus,
  };
});

const selectedAiKeys = computed(() =>
  [...selectedKeys.value].filter((k) => catalog.value?.optional[k]?.is_ai),
);

const aiQuotaCfg = {
  ai_recommendation: { base: 20, stepPrice: 1000, topupPrice: 120 },
  ai_material_quiz: { base: 20, stepPrice: 1000, topupPrice: 150 },
  ai_rpp: { base: 15, stepPrice: 1500, topupPrice: 200 },
} as const;

// ── Effects ────────────────────────────────────────────────────────
async function loadPlan() {
  try { plan.value = await SubscriptionBillingService.getPlans(); } catch { /* fail-soft */ }
}
async function loadCatalog() {
  try { catalog.value = await SubscriptionBillingService.getModuleCatalog(); } catch { /* fail-soft */ }
}

async function refreshQuote() {
  if (!catalog.value || selectedKeys.value.size === 0) {
    quote.value = null;
    return;
  }
  try {
    quote.value = await SubscriptionBillingService.quoteModular({
      student_count: form.student_count,
      staff_count: form.staff_count,
      plan: period.value,
      modules: Array.from(selectedKeys.value),
      ai_quota: aiQuota.value,
    });
  } catch (e) {
    console.warn('[SubscribeNewWizard.refreshQuote]', (e as Error).message);
  }
}

let quoteDebounce: number | null = null;
watch(
  [selectedKeys, aiQuota, period, () => form.student_count, () => form.staff_count],
  () => {
    if (quoteDebounce !== null) window.clearTimeout(quoteDebounce);
    quoteDebounce = window.setTimeout(refreshQuote, 250) as unknown as number;
  },
  { deep: true },
);

onMounted(async () => {
  await Promise.all([loadPlan(), loadCatalog()]);
  if (!auth.isAuthenticated) setTimeout(mountGoogleButton, 100);
  if (!form.admin_email && auth.user?.email) form.admin_email = auth.user.email;
  if (!form.admin_name && auth.user?.name) form.admin_name = auth.user.name;
});

// ── Step navigation ────────────────────────────────────────────────
const canGoNext = computed(() => {
  switch (activeStep.value) {
    case 'lembaga':
      return !!form.tenant_type && form.tenant_name.trim().length >= 3;
    case 'admin':
      return (
        form.admin_name.trim().length > 0 &&
        /.+@.+\..+/.test(form.admin_email.trim()) &&
        form.admin_whatsapp.trim().length >= 8
      );
    case 'kapasitas':
      return form.student_count + form.staff_count > 0;
    case 'modul':
      return selectedKeys.value.size > 0;
    default:
      return true;
  }
});
function next() {
  if (!canGoNext.value) return;
  stepIndex.value = Math.min(STEPS.length - 1, stepIndex.value + 1);
}
function back() {
  stepIndex.value = Math.max(0, stepIndex.value - 1);
}

function toggleModule(key: string) {
  const next = new Set(selectedKeys.value);
  const cat = catalog.value;
  if (next.has(key)) {
    next.delete(key);
    if (cat?.optional[key]?.is_ai) delete aiQuota.value[key];
  } else {
    if (cat && key in cat.bundles) {
      cat.bundles[key].members.forEach((m) => next.delete(m));
    }
    next.add(key);
  }
  selectedKeys.value = next;
}
function switchToBundle(key: string) {
  selectedKeys.value = new Set<string>([key]);
}
function onAiQuotaUpdate(key: string, extra: number) {
  aiQuota.value = { ...aiQuota.value, [key]: extra };
}

/**
 * "Bulanan · N modul" is wrong when the user picked a bundle — the
 * user sees `selectedKeys.size === 1` and thinks they only bought one
 * module. Render the bundle label when a bundle is present, otherwise
 * count expanded keys (bundle members counted individually so 9-member
 * bundles read as 9 modules, not 1).
 */
function buildPlanLabel(): string {
  const periodLbl = period.value === 'yearly' ? 'Tahunan' : 'Bulanan';
  const cat = catalog.value;
  if (cat) {
    const bundleKeys = [...selectedKeys.value].filter((k) => k in cat.bundles);
    if (bundleKeys.length) {
      return `${periodLbl} · ${bundleKeys.map((k) => cat.bundles[k].label).join(' + ')}`;
    }
  }
  const n = expandedKeys.value.length || selectedKeys.value.size;
  return `${periodLbl} · ${n} modul`;
}

// ── Submit ─────────────────────────────────────────────────────────
async function onSubmit() {
  if (!auth.isAuthenticated) {
    errorMessage.value = 'Masuk dengan Google dulu untuk melanjutkan.';
    return;
  }
  submitting.value = true;
  errorMessage.value = null;
  try {
    const result = await SubscriptionBillingService.subscribe({
      tenant_type: form.tenant_type,
      plan: period.value,
      student_count: form.student_count,
      staff_count: form.staff_count,
      gateway: gateway.value,
      new_tenant: {
        name: form.tenant_name.trim(),
        tenant_type: form.tenant_type,
        admin_email: form.admin_email.trim(),
        admin_whatsapp: form.admin_whatsapp.trim(),
        admin_name: form.admin_name.trim(),
        admin_job_title: form.admin_job_title.trim(),
        education_level: form.education_level || null,
        city: form.city.trim() || undefined,
        address: form.address.trim() || undefined,
        npsn: form.npsn.trim() || undefined,
      },
      modules: Array.from(selectedKeys.value),
      ai_quota: aiQuota.value,
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
  order.value = {
    planLabel: buildPlanLabel(),
    studentCount: form.student_count,
    staffCount: form.staff_count,
    amount: result.amount ?? quote.value?.chosen_amount ?? 0,
    bankName: result.bank_transfer_info?.bank_name ?? bankName.value,
    accountNumber:
      (result.bank_transfer_info as ManualTransferInfo | undefined)?.account_number
      ?? bankAccount.value,
    accountHolder:
      (result.bank_transfer_info as ManualTransferInfo | undefined)?.account_name
      ?? bankHolder.value,
    referenceCode: result.order_id,
    createdAt: new Date().toISOString(),
    shareToken: shareTokenFromUrl(result.share_url ?? null),
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
function editOrder() { order.value = null; transferNotified.value = false; stepIndex.value = 3; }
async function shareOrder() {
  if (!order.value?.shareToken) return;
  const url = `${window.location.origin}/subscribe/transfer/${order.value.shareToken}`;
  try { await navigator.clipboard.writeText(url); } catch { /* non-fatal */ }
}
function goHome() { router.push('/'); }
function downloadInvoice() {
  window.open(`/subscribe/receipt/${order.value?.referenceCode}`, '_blank');
}

// ── Midtrans Snap loader ───────────────────────────────────────────
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

// ── Google ────────────────────────────────────────────────────────
async function mountGoogleButton() {
  if (auth.isAuthenticated || !googleContainer.value || !google.isEnabled.value) return;
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
</script>

<template>
  <div class="sn-page">
    <WizardChrome
      :steps="[...STEPS]"
      :active-index="stepIndex"
      help-url="https://wa.me/6285179819002"
    />

    <!-- Anonymous gate — Step 1 is signin, everything else disabled -->
    <div v-if="!auth.isAuthenticated" class="sn-anon">
      <div class="sn-anon-card">
        <div class="sn-anon-h1">Masuk dengan Google untuk mulai</div>
        <p class="sn-anon-sub">
          Wizard ini menyimpan progres per akun Google Anda supaya bisa
          dilanjut di device lain. Login lebih dulu, baru kita isi
          bareng-bareng.
        </p>
        <div
          ref="googleContainer"
          data-google-intent="subscribe"
          class="sn-google-slot"
          @pointerdown="flagSubscribeIntent"
        />
      </div>
    </div>

    <!-- STEP 1: LEMBAGA -->
    <div v-else-if="activeStep === 'lembaga'" class="sn-step">
      <div class="sn-h">
        <h1 class="sn-h1">Ceritakan lembaga Anda</h1>
        <p class="sn-sub">
          Info dasar ini kami pakai untuk membuat akun lembaga baru dan
          mencetak dokumen resmi ({{ form.tenant_type === 'bimbel' ? 'laporan progres, sertifikat' : 'raport, sertifikat' }}).
        </p>
      </div>
      <div class="sn-form">
        <div class="sn-tenant-toggle">
          <button
            type="button"
            class="sn-toggle-opt"
            :class="{ 'is-on': form.tenant_type === 'sekolah' }"
            @click="form.tenant_type = 'sekolah'"
          >
            <i class="ti ti-school" aria-hidden="true" /> Sekolah formal
          </button>
          <button
            type="button"
            class="sn-toggle-opt"
            :class="{ 'is-on': form.tenant_type === 'bimbel' }"
            @click="form.tenant_type = 'bimbel'"
          >
            <i class="ti ti-books" aria-hidden="true" /> Bimbel / kursus
          </button>
        </div>
        <label class="sn-field">
          <span class="sn-lbl">Nama lembaga</span>
          <input
            v-model="form.tenant_name"
            type="text"
            :placeholder="form.tenant_type === 'bimbel' ? 'Bimbel Rushd' : 'SMP Rushd'"
          />
        </label>
        <label v-if="form.tenant_type === 'sekolah'" class="sn-field">
          <span class="sn-lbl">Jenjang</span>
          <select v-model="form.education_level">
            <option value="TK">TK</option>
            <option value="SD">SD</option>
            <option value="SMP">SMP</option>
            <option value="SMA">SMA</option>
            <option value="SMK">SMK</option>
          </select>
        </label>
        <div class="sn-field-row">
          <label class="sn-field">
            <span class="sn-lbl">Kota</span>
            <input v-model="form.city" type="text" placeholder="Surakarta" />
          </label>
          <label v-if="form.tenant_type === 'sekolah'" class="sn-field">
            <span class="sn-lbl">NPSN (opsional)</span>
            <input v-model="form.npsn" type="text" placeholder="20330001" />
          </label>
        </div>
        <label class="sn-field">
          <span class="sn-lbl">Alamat</span>
          <input v-model="form.address" type="text" placeholder="Jl. Pendidikan No. 99" />
        </label>
      </div>
    </div>

    <!-- STEP 2: ADMIN -->
    <div v-else-if="activeStep === 'admin'" class="sn-step">
      <div class="sn-h">
        <h1 class="sn-h1">Siapa yang jadi admin utama?</h1>
        <p class="sn-sub">
          Admin utama menerima notifikasi tagihan dan bisa mengundang
          admin lain nanti dari dashboard.
        </p>
      </div>
      <div class="sn-form">
        <label class="sn-field">
          <span class="sn-lbl">Nama lengkap</span>
          <input v-model="form.admin_name" type="text" />
        </label>
        <label class="sn-field">
          <span class="sn-lbl">Jabatan</span>
          <input v-model="form.admin_job_title" type="text" placeholder="Kepala Sekolah" />
        </label>
        <div class="sn-field-row">
          <label class="sn-field">
            <span class="sn-lbl">WhatsApp</span>
            <input v-model="form.admin_whatsapp" type="tel" placeholder="0812…" />
          </label>
          <label class="sn-field">
            <span class="sn-lbl">Email</span>
            <input v-model="form.admin_email" type="email" placeholder="admin@sekolah.sch.id" />
          </label>
        </div>
      </div>
    </div>

    <!-- STEP 3: KAPASITAS -->
    <div v-else-if="activeStep === 'kapasitas'" class="sn-step">
      <div class="sn-h">
        <h1 class="sn-h1">
          Berapa besar {{ form.tenant_type === 'bimbel' ? 'bimbel' : 'sekolah' }} Anda?
        </h1>
        <p class="sn-sub">
          Perkiraan cukup — Anda bisa naikkan atau turunkan kapan saja
          di dashboard, kami hitung ulang saat perpanjangan.
        </p>
      </div>
      <div class="sn-form">
        <div class="sn-field-row">
          <label class="sn-field">
            <span class="sn-lbl">
              Jumlah {{ form.tenant_type === 'bimbel' ? 'peserta' : 'siswa' }}
            </span>
            <input v-model.number="form.student_count" type="number" min="0" />
          </label>
          <label class="sn-field">
            <span class="sn-lbl">
              Jumlah {{ form.tenant_type === 'bimbel' ? 'tutor / staf' : 'guru / staf' }}
            </span>
            <input v-model.number="form.staff_count" type="number" min="0" />
          </label>
        </div>
      </div>
    </div>

    <!-- STEP 4: MODUL — the star -->
    <template v-else-if="activeStep === 'modul' && catalog">
      <div class="sn-body">
        <div class="sn-main">
          <h1 class="sn-h1">
            Rakit paket <span class="sn-h1-hi">yang benar-benar Anda pakai</span>
          </h1>
          <p class="sn-sub" style="max-width: 460px;">
            Bayar hanya untuk modul yang aktif. Tambah atau matikan modul
            kapan saja — perubahan berlaku di periode berikutnya, tanpa
            biaya batal.
          </p>

          <BundleStrip
            v-if="catalog.bundles.bundle_complete"
            label="Paket Lengkap · semua modul non-AI"
            :description="form.tenant_type === 'bimbel'
              ? '9 modul: absensi, nilai, laporan progres, jadwal sesi, materi ajar, pembayaran, komunikasi, tugas.'
              : '9 modul: absensi, nilai, raport, jadwal, RPP, keuangan, komunikasi, aktivitas kelas.'"
            :price-per-student="catalog.bundles.bundle_complete.price_per_student"
            :active="selectedKeys.has('bundle_complete')"
            @select="toggleModule('bundle_complete')"
          />

          <ModuleCatalogGrid
            :catalog="catalog"
            :selected-keys="new Set(expandedKeys)"
            :auto-included="autoIncluded"
            :tenant-type="form.tenant_type"
            @toggle="toggleModule"
          />

          <div
            v-for="key in selectedAiKeys"
            :key="`ai-${key}`"
            class="sn-ai-slot"
          >
            <AiQuotaStepper
              :item="catalog.optional[key]"
              :monthly-base="aiQuotaCfg[key as keyof typeof aiQuotaCfg]?.base ?? 20"
              :step-unit-price="aiQuotaCfg[key as keyof typeof aiQuotaCfg]?.stepPrice ?? 1000"
              :topup-unit-price="aiQuotaCfg[key as keyof typeof aiQuotaCfg]?.topupPrice ?? 150"
              :staff-count="form.staff_count"
              :total-quota="(aiQuotaCfg[key as keyof typeof aiQuotaCfg]?.base ?? 20) + (aiQuota[key] ?? 0)"
              @update:quota="(extra) => onAiQuotaUpdate(key, extra)"
            />
          </div>
        </div>

        <div class="sn-side">
          <PricingCalculatorV2
            :tenant-name="form.tenant_name || (form.tenant_type === 'bimbel' ? 'Bimbel Anda' : 'Sekolah Anda')"
            :student-count="form.student_count"
            :staff-count="form.staff_count"
            v-model:plan="period"
            :quote="quote"
            :catalog="catalog"
            :tenant-type="form.tenant_type"
            :yearly-discount-pct="plan?.yearly_discount_pct"
            :bundle-benchmark="bundleBenchmark"
            submit-label="Lanjut ke pembayaran"
            @submit="next"
            @switch-to-bundle="switchToBundle"
          />
        </div>
      </div>
    </template>

    <!-- STEP 5: BAYAR -->
    <div v-else-if="activeStep === 'bayar' && !order" class="sn-step">
      <div class="sn-h">
        <h1 class="sn-h1">Cara bayar</h1>
        <p class="sn-sub">
          <template v-if="midtransAvailable">
            Pilih transfer manual (verifikasi 1×24 jam) atau Midtrans
            (aktivasi otomatis dalam hitungan menit).
          </template>
          <template v-else>
            Transfer manual ke rekening tim keuangan kami. Setelah
            transfer, aktivasi maks 1×24 jam kerja.
          </template>
        </p>
      </div>
      <PaymentMethodCards
        v-model:value="gateway"
        :midtrans-available="midtransAvailable"
        :bank-name="bankName"
        :bank-holder="bankHolder"
      />
      <p v-if="errorMessage" class="sn-err">{{ errorMessage }}</p>
    </div>

    <!-- ORDER (post-submit) -->
    <div v-else-if="order && !transferNotified" class="sn-order-wrap">
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
    <div v-else-if="order && transferNotified" class="sn-order-wrap">
      <OrderThanksCard
        :email="auth.user?.email"
        :whatsapp="form.admin_whatsapp"
        @home="goHome"
        @invoice="downloadInvoice"
      />
    </div>

    <!-- Footer nav — hidden after order created -->
    <div v-if="auth.isAuthenticated && !order" class="sn-foot">
      <button
        type="button"
        class="sn-foot-back"
        :disabled="stepIndex === 0"
        @click="back"
      >
        <i class="ti ti-arrow-left" style="font-size:13px" aria-hidden="true" />
        Kembali
      </button>
      <button
        v-if="activeStep === 'bayar'"
        type="button"
        class="sn-foot-next"
        :disabled="submitting"
        @click="onSubmit"
      >
        <template v-if="submitting">Memproses…</template>
        <template v-else>
          Buat pesanan
          <i class="ti ti-arrow-right" style="font-size:13px" aria-hidden="true" />
        </template>
      </button>
      <button
        v-else-if="activeStep !== 'modul'"
        type="button"
        class="sn-foot-next"
        :disabled="!canGoNext"
        @click="next"
      >
        Lanjut
        <i class="ti ti-arrow-right" style="font-size:13px" aria-hidden="true" />
      </button>
    </div>
  </div>
</template>

<style scoped>
.sn-page {
  min-height: 100vh;
  background: #FBFCFE;
  color: #0F172A;
  font-family: var(--font-sans);
  display: flex; flex-direction: column;
}

.sn-anon {
  padding: 60px 22px;
  display: grid; place-items: center;
  flex: 1;
}
.sn-anon-card {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 14px;
  padding: 28px 24px;
  max-width: 420px; width: 100%;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04),
              0 8px 24px rgba(15, 23, 42, 0.06);
  text-align: center;
}
.sn-anon-h1 { font-size: 20px; font-weight: 500; letter-spacing: -0.2px; }
.sn-anon-sub {
  font-size: 12.5px; color: #64748B;
  margin: 8px 0 20px; line-height: 1.55;
}
.sn-google-slot { min-height: 42px; display: flex; justify-content: center; }

/* Center the step content horizontally so the form sits in the
   middle of a wide viewport instead of pinning to the top-left. On
   tall viewports the flex-column layout of .sn-page + auto margins
   above/below keep the form near the vertical middle too. max-width
   640px keeps line-lengths readable at desktop widths. */
.sn-step {
  padding: 32px 22px;
  max-width: 640px;
  width: 100%;
  margin: auto;
  align-self: center;
}
.sn-h { margin-bottom: 18px; }
.sn-h1 {
  font-size: 22px; font-weight: 500;
  letter-spacing: -0.3px; margin: 0;
}
.sn-h1-hi {
  background: linear-gradient(135deg, #1B6FB8 0%, #113E75 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.sn-sub {
  font-size: 12.5px; color: #64748B;
  margin: 6px 0 0; line-height: 1.55;
}

.sn-form { display: flex; flex-direction: column; gap: 12px; }
.sn-field-row {
  display: grid; grid-template-columns: 1fr 1fr; gap: 12px;
}
.sn-field { display: flex; flex-direction: column; gap: 4px; }
.sn-lbl {
  font-size: 10.5px; text-transform: uppercase;
  letter-spacing: 0.4px; color: #64748B; font-weight: 500;
}
.sn-field input,
.sn-field select {
  border: 0.5px solid #CBD5E1;
  border-radius: 8px;
  padding: 9px 12px;
  font-size: 13px;
  color: #0F172A;
  background: #FFFFFF;
  font-family: inherit;
}
.sn-field input:focus,
.sn-field select:focus {
  outline: none;
  border-color: #1B6FB8;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.14);
}

.sn-tenant-toggle {
  display: grid; grid-template-columns: 1fr 1fr;
  gap: 8px; margin-bottom: 4px;
}
.sn-toggle-opt {
  padding: 12px 14px;
  border: 0.5px solid #E2E8F0;
  border-radius: 10px;
  background: #FFFFFF;
  font-size: 12.5px; color: #475569;
  font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; gap: 6px;
  justify-content: center;
}
.sn-toggle-opt.is-on {
  border: 1.5px solid #1B6FB8;
  padding: 11.5px 13.5px;
  color: #113E75;
  background: #FBFDFF;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.06);
}

.sn-body {
  display: grid;
  /* 340px is wide enough to keep the calculator's line items on one
     row for 7-digit rupiah amounts + hosts a comfortable Ambil Paket
     Lengkap CTA without wrapping. Below 720px we collapse to single
     column (see media query). */
  grid-template-columns: minmax(0, 1fr) 340px;
  gap: 0;
  flex: 1;
}
.sn-main { padding: 20px 22px 26px; }
.sn-side {
  background: #F5F8FC;
  border-left: 0.5px solid #E7ECF3;
  padding: 20px 18px;
}
.sn-ai-slot { margin-top: 12px; }

.sn-err {
  margin-top: 12px;
  font-size: 12px; color: #B91C1C;
  padding: 10px 12px;
  border-radius: 8px;
  background: #FEE2E2;
  border: 0.5px solid #FCA5A5;
}

.sn-order-wrap {
  padding: 22px;
  max-width: 720px;
  margin: 0 auto;
}

.sn-foot {
  padding: 10px 20px;
  background: #FFFFFF;
  border-top: 0.5px solid #E7ECF3;
  display: flex; align-items: center; gap: 12px;
  margin-top: auto;
}
.sn-foot-back,
.sn-foot-next {
  padding: 8px 14px;
  border-radius: 8px;
  font-size: 12px; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; gap: 5px;
  font-family: inherit;
}
.sn-foot-back {
  background: transparent;
  border: 0.5px solid #CBD5E1;
  color: #475569;
}
.sn-foot-back:disabled { opacity: 0.5; cursor: not-allowed; }
.sn-foot-next {
  background: #1B6FB8; color: #fff; border: none;
  margin-left: auto;
}
.sn-foot-next:hover:not(:disabled) { background: #185FA5; }
.sn-foot-next:disabled { background: #CBD5E1; cursor: not-allowed; }

@media (max-width: 720px) {
  .sn-body { grid-template-columns: 1fr; }
  .sn-side { border-left: none; border-top: 0.5px solid #E7ECF3; }
}
</style>
