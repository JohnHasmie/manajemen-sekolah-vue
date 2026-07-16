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
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';
import { useModuleSelection, aiQuotaCfg } from '@/composables/useModuleSelection';
import { ensureMidtransSnap } from '@/lib/midtrans';
import {
  SubscriptionBillingService,
  markTransferredByToken,
  shareTokenFromUrl,
} from '@/services/billing.service';
import type {
  AppliedDiscount,
  DiscountPreviewFailure,
  ManualTransferInfo,
  ModuleCatalog,
  PricingPlan,
  SubscribeResult,
  BillingPeriod,
  TenantType,
} from '@/types/subscription-billing';

import WizardChrome from '@/components/subscribe/WizardChrome.vue';
import BundleStrip from '@/components/subscribe/BundleStrip.vue';
import { isModuleHiddenFor } from '@/components/subscribe/moduleTokens';
import { tenantLabel, tenantVariantLabel } from '@/lib/tenantTokens';
import ModuleCatalogGrid from '@/components/subscribe/ModuleCatalogGrid.vue';
import AiQuotaStepper from '@/components/subscribe/AiQuotaStepper.vue';
import PricingCalculatorV2 from '@/components/subscribe/PricingCalculatorV2.vue';
import PaymentMethodCards from '@/components/subscribe/PaymentMethodCards.vue';
import OrderTransferCard from '@/components/subscribe/OrderTransferCard.vue';
import OrderThanksCard from '@/components/subscribe/OrderThanksCard.vue';

const router = useRouter();
const route = useRoute();
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

/**
 * Visible steps for the wizard chrome. When only one payment method
 * is available (`!midtransAvailable`), we skip the "Bayar" picker
 * step entirely — the calculator's CTA on step 4 goes straight to
 * order creation. Hiding "Bayar" from the progress indicator too
 * keeps the top strip honest about how many real steps remain.
 */
const visibleSteps = computed(() => {
  if (midtransAvailable.value) return [...STEPS];
  return STEPS.filter((s) => s.key !== 'bayar');
});

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

// ── Module selection engine (shared with SubscribeView) ────────────
// All picker math (bundle explode on partial uncheck + AI-quota
// cleanup, expanded keys, bundle benchmark, debounced backend quote
// with local fallback for anonymous visitors) lives in the composable.
// Registered BEFORE the draft-restore IIFE below so watcher ordering
// matches the pre-extraction file. The returned refs are writable —
// the draft restore + tenant-type purge watcher assign to them.
const {
  selectedKeys,
  aiQuota,
  quote,
  expandedKeys,
  autoIncluded,
  requiredBy,
  bundleBenchmark,
  selectedAiKeys,
  toggleModule,
  switchToBundle,
  onAiQuotaUpdate,
  refreshQuote,
  buildPlanLabel,
} = useModuleSelection({
  catalog,
  plan,
  studentCount: () => form.student_count,
  staffCount: () => form.staff_count,
  period,
  // Post-split (Jul 2026): the old `attendance_student` default now
  // materialises as both `attendance_class` (per-session teacher flow)
  // and `attendance_gate` (student QR at gerbang). Preselecting both
  // matches what the old single-module default gave the user.
  initialKeys: [
    'attendance_class',
    'attendance_gate',
    'attendance_staff',
    'grades',
    'report_cards',
    'finance',
  ],
  withAiQuota: true,
  localQuoteFallback: true,
  logTag: 'SubscribeNewWizard',
});

const submitting = ref(false);
const errorMessage = ref<string | null>(null);

const googleContainer = ref<HTMLElement | null>(null);

// ── Discount code state ────────────────────────────────────────────
// P1: single active code per subscription (Yahya's "single active code"
// choice). Parent view owns the state; PricingCalculatorV2 renders
// the input/applied card and re-emits events. The applied snapshot
// stays in memory only — a page refresh drops it, because pricing
// may have changed and the code needs to be re-validated fresh.
//
// URL auto-apply: /subscribe/new?discount_code=XYZ auto-fills and
// triggers apply on mount (per Yahya's "on untuk semua code" choice).
const discountCode = ref('');
const discountApplying = ref(false);
const discountError = ref<DiscountPreviewFailure | null>(null);
const appliedDiscount = ref<AppliedDiscount | null>(null);

async function applyDiscount(codeRaw: string) {
  const code = codeRaw.trim().toUpperCase();
  if (!code || discountApplying.value) return;
  discountApplying.value = true;
  discountError.value = null;
  try {
    const monthlySubtotal = quote.value?.monthly_amount ?? 0;
    const result = await SubscriptionBillingService.previewDiscountCode({
      code,
      monthly_subtotal: monthlySubtotal,
      module_keys: Array.from(selectedKeys.value),
      tenant_id: null,
    });
    if (result.valid) {
      appliedDiscount.value = {
        code: result.code,
        description: result.description,
        type: result.type,
        value: result.value,
        duration_months: result.duration_months,
        discount_amount: result.discount_amount,
        valid_until: result.valid_until,
        used_count: result.used_count,
        max_uses: result.max_uses,
      };
      discountError.value = null;
      discountCode.value = '';
    } else {
      discountError.value = result;
    }
  } finally {
    discountApplying.value = false;
  }
}

function removeDiscount() {
  appliedDiscount.value = null;
  discountError.value = null;
  discountCode.value = '';
}

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

// ── Effects ────────────────────────────────────────────────────────
async function loadPlan() {
  try { plan.value = await SubscriptionBillingService.getPlans(); } catch { /* fail-soft */ }
}
async function loadCatalog() {
  try { catalog.value = await SubscriptionBillingService.getModuleCatalog(); } catch { /* fail-soft */ }
}

// ── Draft persistence (localStorage) ────────────────────────────────
// The wizard has a few steps and users bail + resume all the time — a
// browser refresh or accidentally closed tab shouldn't wipe half an
// hour of typing. Snapshot form + selectedKeys + aiQuota + period into
// localStorage on every change (debounced), keyed by the signed-in
// email if available and 'anon' otherwise. On sign-in we transplant
// the anon draft to the email-scoped slot so the same person seeing
// the Google prompt then completing sign-in doesn't start over.
//
// Cleared on a successful subscribe so the next tenant creation starts
// clean. Backend-side draft sync (POST /billing/subscription-wizard)
// exists but requires auth — this local layer is what makes the
// anonymous-then-sign-in path feel seamless.
const DRAFT_VERSION = 'v3';
const DRAFT_ROOT = `subscribe_wizard_draft_${DRAFT_VERSION}`;

function draftKeyFor(email: string | null | undefined): string {
  return `${DRAFT_ROOT}:${email ? email.toLowerCase().trim() : 'anon'}`;
}

interface WizardDraft {
  form: Record<string, unknown>;
  selectedKeys: string[];
  aiQuota: Record<string, number>;
  period: BillingPeriod;
  stepIndex: number;
  savedAt: string;
  /**
   * Order snapshot — persisted so a mid-transfer refresh drops the
   * user back on the OrderTransferCard (with the same rekening +
   * kode referensi + amount) instead of an empty Step 1. Cleared
   * only when the user taps "Saya sudah transfer".
   */
  order?: OrderSnapshot | null;
  transferNotified?: boolean;
}

function snapshotDraft(): WizardDraft {
  return {
    form: JSON.parse(JSON.stringify(form)),
    selectedKeys: Array.from(selectedKeys.value),
    aiQuota: { ...aiQuota.value },
    period: period.value,
    stepIndex: stepIndex.value,
    savedAt: new Date().toISOString(),
    order: order.value ? { ...order.value } : null,
    transferNotified: transferNotified.value,
  };
}

function saveDraft(): void {
  try {
    const key = draftKeyFor(auth.user?.email);
    localStorage.setItem(key, JSON.stringify(snapshotDraft()));
  } catch { /* quota exceeded / disabled — non-fatal */ }
}

function loadDraft(email: string | null | undefined): WizardDraft | null {
  try {
    const raw = localStorage.getItem(draftKeyFor(email));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as WizardDraft;
    if (!parsed || typeof parsed !== 'object') return null;
    return parsed;
  } catch {
    return null;
  }
}

/**
 * True while we're writing loaded draft state INTO the reactive form.
 * The save-on-change watcher checks this and skips — otherwise the
 * draft we just wrote overwrites the draft we're loading, spuriously
 * "empty" if the user is fast on a keyboard while the restore is
 * running.
 */
let hydrating = false;

function applyDraft(d: WizardDraft): void {
  hydrating = true;
  try {
    if (d.form && typeof d.form === 'object') {
      Object.assign(form, d.form);
    }
    if (Array.isArray(d.selectedKeys)) {
      selectedKeys.value = new Set(d.selectedKeys.filter((k) => typeof k === 'string'));
    }
    if (d.aiQuota && typeof d.aiQuota === 'object') {
      aiQuota.value = { ...d.aiQuota };
    }
    if (d.period === 'monthly' || d.period === 'yearly') {
      period.value = d.period;
    }
    if (typeof d.stepIndex === 'number' && d.stepIndex >= 0 && d.stepIndex < STEPS.length) {
      // Only restore stepIndex if the user got past step 1 — a fresh
      // return should still show the intro step so they orient.
      if (d.stepIndex > 0) stepIndex.value = d.stepIndex;
    }
    // Order state — mid-transfer refresh should land the user back on
    // OrderTransferCard, not the empty Step 1. The `!order` guard on
    // the Step 4 template + the OrderTransferCard's own `v-else-if`
    // do the rest: as soon as `order.value` is truthy the template
    // chain jumps straight to the transfer instructions.
    if (d.order && typeof d.order === 'object') {
      order.value = d.order as OrderSnapshot;
    }
    if (typeof d.transferNotified === 'boolean') {
      transferNotified.value = d.transferNotified;
    }
  } finally {
    // Flush the microtask queue before releasing the guard so the
    // reactivity system finishes propagating our writes to any
    // watchers we tripped mid-apply.
    Promise.resolve().then(() => { hydrating = false; });
  }
}

function clearDraft(email: string | null | undefined): void {
  try {
    localStorage.removeItem(draftKeyFor(email));
  } catch { /* non-fatal */ }
}

// Restore the draft SYNCHRONOUSLY at setup — BEFORE the save-on-change
// watcher registers, and long before `await Promise.all(loadPlan/Catalog)`
// gives up the microtask queue. Without this, a fast typist can enter a
// character during the ~1-2 s of network loading, `saveDraft` fires 500 ms
// later, and then `onMounted` calls `applyDraft` which overwrites what
// they just typed with the older draft.
//
// The load helpers are already synchronous (localStorage is sync), so
// there's no reason to defer this to onMounted at all.
(() => {
  const restored = loadDraft(auth.user?.email) ?? loadDraft(null);
  if (restored) applyDraft(restored);
})();

let draftSaveTimer: number | null = null;
watch(
  [
    () => form.tenant_name,
    () => form.tenant_type,
    () => form.education_level,
    () => form.city,
    () => form.address,
    () => form.npsn,
    () => form.admin_name,
    () => form.admin_job_title,
    () => form.admin_whatsapp,
    () => form.admin_email,
    () => form.student_count,
    () => form.staff_count,
    selectedKeys,
    aiQuota,
    period,
    stepIndex,
    // Persist the mid-transfer state too: order arrives after submit,
    // transferNotified flips when the user taps "Saya sudah transfer".
    // Without these, `onSubmit()` sets `order.value` and the next
    // debounced save skips it because none of the OLD watched refs
    // changed.
    order,
    transferNotified,
  ],
  () => {
    // Silence writes we're triggering ourselves during a restore, so
    // an in-progress load doesn't schedule a save that would overwrite
    // exactly what we're loading.
    if (hydrating) return;
    if (draftSaveTimer !== null) window.clearTimeout(draftSaveTimer);
    draftSaveTimer = window.setTimeout(saveDraft, 500) as unknown as number;
  },
  { deep: true },
);

// When the user signs in mid-flow — OR when auth hydrates after mount
// and turns out to already be signed in — migrate the anonymous draft
// to the email-keyed slot so their answers survive the login round-trip.
// `immediate: true` fires this handler at registration too, so the
// "already-signed-in-on-mount" case does the migration once even
// though newEmail didn't strictly change.
watch(
  () => auth.user?.email ?? null,
  (newEmail, oldEmail) => {
    if (!newEmail) return;
    if (oldEmail === newEmail) {
      // Immediate-fire on mount with no prior email — check for an
      // anon draft one more time (in case the sync restore above ran
      // before auth hydrated) and adopt it under the email slot.
      const anon = loadDraft(null);
      const emailSlot = loadDraft(newEmail);
      if (anon && !emailSlot) {
        try {
          localStorage.setItem(draftKeyFor(newEmail), JSON.stringify(anon));
          clearDraft(null);
          applyDraft(anon);
        } catch { /* non-fatal */ }
      } else if (emailSlot && !form.tenant_name) {
        // Auth arrived AFTER our setup-time restore; if we haven't
        // hydrated the email-scoped draft yet, do it now.
        applyDraft(emailSlot);
      }
      return;
    }
    // Real email change (sign-in mid-flow).
    const anon = loadDraft(null);
    const emailSlot = loadDraft(newEmail);
    if (anon && !emailSlot) {
      try {
        localStorage.setItem(draftKeyFor(newEmail), JSON.stringify(anon));
      } catch { /* non-fatal */ }
    }
    clearDraft(null);
    if (!emailSlot && anon) applyDraft(anon);
    if (emailSlot) applyDraft(emailSlot);
  },
  { immediate: true },
);

onMounted(async () => {
  await Promise.all([loadPlan(), loadCatalog()]);
  if (!auth.isAuthenticated) setTimeout(mountGoogleButton, 100);
  // Fill from the auth store ONLY when the draft didn't provide a value —
  // the user's own words always win over the Google profile default.
  if (!form.admin_email && auth.user?.email) form.admin_email = auth.user.email;
  if (!form.admin_name && auth.user?.name) form.admin_name = auth.user.name;
  // Kick the quote ONCE now that the catalog is loaded. Vue's watch is
  // lazy — since selectedKeys already had its 5 defaults at setup, the
  // reactive value never "changed" and the save-on-change watcher never
  // fired refreshQuote(). Result: sidebar reads "Belum ada modul dipilih
  // · Rp 0" while 5 module cards are visibly ticked. Firing it here
  // primes the sidebar with a real number before the first paint the
  // user actually looks at.
  refreshQuote();

  // Auto-apply from URL — /subscribe/new?discount_code=XYZ. Runs AFTER
  // the initial quote fires so previewDiscountCode() has a monthly
  // subtotal to lock against. Silent-fail: an invalid URL code just
  // populates the error state and stays visible until the user
  // types over it, so campaign links with a typo don't confuse the
  // flow. Only fires on load — subsequent query changes are ignored.
  const urlCode = route.query.discount_code;
  if (typeof urlCode === 'string' && urlCode.trim() !== '') {
    // Give refreshQuote() a beat to populate monthly_amount so the
    // preview's discount math sees a non-zero subtotal.
    setTimeout(() => applyDiscount(urlCode), 400);
  }
});

// ── Step navigation ────────────────────────────────────────────────
// Pak Agus (Kepala Sekolah SMP Rushd) stuck 2 days on step 1 because the
// "Lanjut" button was silently disabled — no asterisk on the label, a
// filled-looking placeholder ("SMP Rushd"), no error message. He never
// realised the empty Nama lembaga field was what greyed the button out.
//
// The fix: DON'T silent-disable. Let the user click, then validate on
// click and tell them exactly which field is missing (red border, inline
// error, focus jump). `validateStep()` replaces the old `canGoNext`
// computed — same rules, but it returns the first invalid field name so
// `next()` can focus + scroll to it. `fieldErrors` powers the per-field
// error copy and red border in the template.
const fieldErrors = ref<Record<string, string>>({});

/**
 * Validate the current step. Populates `fieldErrors` with a map of
 * field name → message, and returns the FIRST invalid field name (for
 * focus + scroll) or null when the step is clean and safe to advance.
 *
 * Field names match the `data-field="..."` attribute stamped on each
 * `<input>` — `focusField()` uses that to locate the element.
 * `'__modules__'` is a virtual field for the module picker (no
 * focusable input, so the top banner alone communicates).
 */
function validateStep(): string | null {
  const errors: Record<string, string> = {};
  let firstInvalid: string | null = null;
  const mark = (field: string, msg: string) => {
    errors[field] = msg;
    if (firstInvalid === null) firstInvalid = field;
  };
  switch (activeStep.value) {
    case 'lembaga':
      if (form.tenant_name.trim().length < 3) {
        mark('tenant_name', 'Nama lembaga wajib diisi (min. 3 karakter)');
      }
      break;
    case 'admin':
      if (form.admin_name.trim().length === 0) {
        mark('admin_name', 'Nama admin wajib diisi');
      }
      if (form.admin_job_title.trim().length === 0) {
        mark('admin_job_title', 'Jabatan wajib diisi');
      }
      if (form.admin_whatsapp.trim().length < 8) {
        mark('admin_whatsapp', 'Nomor WhatsApp wajib diisi (min. 8 digit)');
      }
      if (!/.+@.+\..+/.test(form.admin_email.trim())) {
        mark('admin_email', 'Email admin belum valid');
      }
      break;
    case 'kapasitas':
      if (form.student_count + form.staff_count <= 0) {
        mark('student_count', 'Isi jumlah minimal 1 orang');
      }
      break;
    case 'modul':
      if (selectedKeys.value.size === 0) {
        mark('__modules__', 'Pilih minimal satu modul dulu.');
      }
      break;
  }
  fieldErrors.value = errors;
  return firstInvalid;
}

/**
 * Scroll the invalid input into view and focus it. Uses `[data-field]`
 * instead of a ref map so adding a new required input stays a template
 * concern — just stamp the attribute and validateStep() picks it up.
 * The focus is deferred one tick after scrollIntoView begins so the
 * viewport can start moving without the focus jump snapping it.
 */
function focusField(field: string): void {
  const el = document.querySelector<HTMLElement>(`[data-field="${field}"]`);
  if (!el) return;
  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  setTimeout(() => {
    if (typeof (el as HTMLInputElement).focus === 'function') {
      (el as HTMLInputElement).focus();
    }
  }, 120);
}

/**
 * Best-effort per-field error clearing as the user fixes the input.
 * Keyed to the same validity check as `validateStep()` so the red
 * border disappears the moment the field turns valid — not on the
 * first keystroke (which would flash green on "SM" then red again).
 */
watch(() => form.tenant_name, (v) => {
  if (fieldErrors.value.tenant_name && v.trim().length >= 3) {
    const { tenant_name, ...rest } = fieldErrors.value;
    void tenant_name;
    fieldErrors.value = rest;
  }
});
watch(() => form.admin_name, (v) => {
  if (fieldErrors.value.admin_name && v.trim().length > 0) {
    const { admin_name, ...rest } = fieldErrors.value;
    void admin_name;
    fieldErrors.value = rest;
  }
});
watch(() => form.admin_job_title, (v) => {
  if (fieldErrors.value.admin_job_title && v.trim().length > 0) {
    const { admin_job_title, ...rest } = fieldErrors.value;
    void admin_job_title;
    fieldErrors.value = rest;
  }
});
watch(() => form.admin_whatsapp, (v) => {
  if (fieldErrors.value.admin_whatsapp && v.trim().length >= 8) {
    const { admin_whatsapp, ...rest } = fieldErrors.value;
    void admin_whatsapp;
    fieldErrors.value = rest;
  }
});
watch(() => form.admin_email, (v) => {
  if (fieldErrors.value.admin_email && /.+@.+\..+/.test(v.trim())) {
    const { admin_email, ...rest } = fieldErrors.value;
    void admin_email;
    fieldErrors.value = rest;
  }
});

function next() {
  const invalid = validateStep();
  if (invalid !== null) {
    errorMessage.value = 'Ada field yang belum diisi. Lengkapi dulu ya.';
    focusField(invalid);
    return;
  }
  errorMessage.value = null;
  // Short-circuit: when there's only one payment method, going "next"
  // from Step 4 (modul) doesn't need to stop on Step 5 (payment picker)
  // — the picker would show a single card that self-selects. Fire
  // onSubmit() directly and the OrderTransferCard renders when the API
  // responds. Everything else keeps advancing normally.
  if (activeStep.value === 'modul' && !midtransAvailable.value) {
    void onSubmit();
    return;
  }
  stepIndex.value = Math.min(STEPS.length - 1, stepIndex.value + 1);
}
function back() {
  // Clearing errors on back-nav means bouncing between steps doesn't
  // carry stale red borders forward into a step the user hadn't
  // clicked Lanjut on yet.
  fieldErrors.value = {};
  errorMessage.value = null;
  stepIndex.value = Math.max(0, stepIndex.value - 1);
}

/**
 * When the tenant type flips (sekolah ↔ bimbel), purge any picked
 * modules that are hidden for the new type. Without this, a user who
 * selects AI modules while on sekolah, then flips to bimbel, still
 * has AI in `selectedKeys` — the picker cards are hidden but the
 * `<AiQuotaStepper>` block below the grid still renders (it iterates
 * `selectedAiKeys` off the raw selection) AND the calculator still
 * bills for them. Same story in the reverse direction for the
 * bimbel-only `tutoring` module. `bundle_complete` is sekolah-only
 * too — it's a sekolah preset.
 *
 * Also purges the matching `aiQuota` entries so the calculator's AI
 * quota line disappears alongside the module row.
 */
watch(() => form.tenant_type, (newType, oldType) => {
  if (!newType || newType === oldType) return;
  const cat = catalog.value;
  if (!cat) return;

  const next = new Set<string>();
  selectedKeys.value.forEach((k) => {
    // Bundle keys aren't in `cat.optional` — evaluate them by their
    // key alone. Currently only `bundle_complete` exists and it's
    // sekolah-oriented, so drop it for bimbel.
    if (k in cat.bundles) {
      if (newType === 'bimbel' && k === 'bundle_complete') return;
      next.add(k);
      return;
    }
    const item = cat.optional[k];
    if (!item) return;
    if (!isModuleHiddenFor(k, item.group, newType)) next.add(k);
  });
  selectedKeys.value = next;

  // Drop AI quota entries whose module is no longer selected — no
  // point keeping the value alive if the module row is gone.
  const nextAi: Record<string, number> = {};
  Object.entries(aiQuota.value).forEach(([k, v]) => {
    if (next.has(k)) nextAi[k] = v;
  });
  aiQuota.value = nextAi;
});

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
      // Only send when we have a validated applied code — backend
      // re-locks + re-validates on payment success (P1b) so an
      // expired/exhausted code between apply and pay is caught there.
      applied_discount_code: appliedDiscount.value?.code ?? undefined,
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
  // Order is created but the user hasn't confirmed transfer yet. We
  // deliberately DO NOT clearDraft here — a refresh (or accidental
  // tab close) mid-transfer used to dump them back on Step 1 with an
  // empty form. Draft now persists through the "menunggu pembayaran"
  // window and is cleared only when `onMarkTransferred` succeeds
  // (user tapped "Saya sudah transfer" and the mark-paid call went
  // through). The `order` snapshot is included in the draft so the
  // OrderTransferCard state itself survives the reload.
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
    // No share token = no server-side mark-paid to fire, so we're done
    // with the draft too. This is the terminal state — user has told
    // us they transferred, next visit to /subscribe/new starts clean.
    clearDraft(auth.user?.email);
    clearDraft(null);
    return;
  }
  notifyingTransfer.value = true;
  try {
    await markTransferredByToken(order.value.shareToken);
    transferNotified.value = true;
    clearDraft(auth.user?.email);
    clearDraft(null);
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
      :steps="visibleSteps"
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
          mencetak dokumen resmi ({{ tenantVariantLabel('documentTypes', form.tenant_type) }}).
        </p>
      </div>
      <!-- Top banner fires when the user clicks Lanjut with an invalid
           field — companion to the inline red text below each input. -->
      <div v-if="errorMessage" class="sn-form-banner" role="alert">
        <i class="ti ti-alert-circle" aria-hidden="true" />
        {{ errorMessage }}
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
          <span class="sn-lbl">
            Nama lembaga<em class="req" aria-label="wajib diisi">*</em>
          </span>
          <input
            v-model="form.tenant_name"
            type="text"
            data-field="tenant_name"
            :class="{ 'sn-input-error': fieldErrors.tenant_name }"
            :placeholder="form.tenant_type === 'bimbel' ? 'mis. Bimbel Rushd Cabang Solo' : 'mis. SMP Muhammadiyah Surakarta'"
          />
          <!-- Error takes priority over the hint so the user always sees
               the most actionable message. Hint stays subtle grey and only
               surfaces on a fresh empty field to teach the expected shape. -->
          <span v-if="fieldErrors.tenant_name" class="sn-field-err">{{ fieldErrors.tenant_name }}</span>
          <span v-else-if="!form.tenant_name.trim()" class="sn-hint">
            Contohnya "SMP Muhammadiyah Surakarta" atau "Bimbel Rushd Cabang Solo"
          </span>
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
            <input v-model="form.city" type="text" placeholder="mis. Surakarta" />
          </label>
          <label v-if="form.tenant_type === 'sekolah'" class="sn-field">
            <span class="sn-lbl">NPSN (opsional)</span>
            <input v-model="form.npsn" type="text" placeholder="mis. 20330001" />
          </label>
        </div>
        <label class="sn-field">
          <span class="sn-lbl">Alamat</span>
          <input v-model="form.address" type="text" placeholder="mis. Jl. Pendidikan No. 99" />
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
      <div v-if="errorMessage" class="sn-form-banner" role="alert">
        <i class="ti ti-alert-circle" aria-hidden="true" />
        {{ errorMessage }}
      </div>
      <div class="sn-form">
        <label class="sn-field">
          <span class="sn-lbl">
            Nama lengkap<em class="req" aria-label="wajib diisi">*</em>
          </span>
          <input
            v-model="form.admin_name"
            type="text"
            data-field="admin_name"
            :class="{ 'sn-input-error': fieldErrors.admin_name }"
            placeholder="mis. Budi Santoso"
          />
          <span v-if="fieldErrors.admin_name" class="sn-field-err">{{ fieldErrors.admin_name }}</span>
        </label>
        <label class="sn-field">
          <span class="sn-lbl">
            Jabatan<em class="req" aria-label="wajib diisi">*</em>
          </span>
          <input
            v-model="form.admin_job_title"
            type="text"
            data-field="admin_job_title"
            :class="{ 'sn-input-error': fieldErrors.admin_job_title }"
            placeholder="mis. Kepala Sekolah"
          />
          <span v-if="fieldErrors.admin_job_title" class="sn-field-err">{{ fieldErrors.admin_job_title }}</span>
        </label>
        <div class="sn-field-row">
          <label class="sn-field">
            <span class="sn-lbl">
              WhatsApp<em class="req" aria-label="wajib diisi">*</em>
            </span>
            <input
              v-model="form.admin_whatsapp"
              type="tel"
              data-field="admin_whatsapp"
              :class="{ 'sn-input-error': fieldErrors.admin_whatsapp }"
              placeholder="mis. 08123456789"
            />
            <span v-if="fieldErrors.admin_whatsapp" class="sn-field-err">{{ fieldErrors.admin_whatsapp }}</span>
          </label>
          <label class="sn-field">
            <span class="sn-lbl">
              Email<em class="req" aria-label="wajib diisi">*</em>
            </span>
            <input
              v-model="form.admin_email"
              type="email"
              data-field="admin_email"
              :class="{ 'sn-input-error': fieldErrors.admin_email }"
              placeholder="mis. admin@sekolah.sch.id"
            />
            <span v-if="fieldErrors.admin_email" class="sn-field-err">{{ fieldErrors.admin_email }}</span>
          </label>
        </div>
      </div>
    </div>

    <!-- STEP 3: KAPASITAS -->
    <div v-else-if="activeStep === 'kapasitas'" class="sn-step">
      <div class="sn-h">
        <h1 class="sn-h1">
          Berapa besar {{ tenantVariantLabel('tenantTypeLower', form.tenant_type) }} Anda?
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
              Jumlah {{ tenantLabel('student', form.tenant_type) }}
            </span>
            <input v-model.number="form.student_count" type="number" min="0" />
          </label>
          <label class="sn-field">
            <span class="sn-lbl">
              Jumlah {{ tenantVariantLabel('teacherStaff', form.tenant_type) }}
            </span>
            <input v-model.number="form.staff_count" type="number" min="0" />
          </label>
        </div>
      </div>
    </div>

    <!-- STEP 4: MODUL — the star. Also gates on `!order` so that when
         we skip the payment-method picker (single-gateway path via
         `next()`) and `onSubmit()` sets `order.value` while stepIndex
         is still 3, the v-else-if chain falls through past this block
         and renders the OrderTransferCard below. Without this guard
         `activeStep === 'modul'` keeps matching first and the user
         sees nothing happen on click — silent success. -->
    <template v-else-if="activeStep === 'modul' && catalog && !order">
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

          <!-- bundle_complete = Paket Lengkap (Sekolah). Its members are
               sekolah-only modules (attendance_*, grades, report_cards,
               etc.) that don't route bimbel traffic — offering it to a
               bimbel admin sells them a bundle where none of the parts
               work. Hide until we ship a bimbel-native bundle. -->
          <BundleStrip
            v-if="catalog.bundles.bundle_complete && form.tenant_type !== 'bimbel'"
            label="Paket Lengkap · semua modul non-AI"
            description="9 modul: absensi, nilai, raport, jadwal, RPP, keuangan, komunikasi, aktivitas kelas."
            :price-per-student="catalog.bundles.bundle_complete.price_per_student"
            :price-per-staff="catalog.bundles.bundle_complete.price_per_staff"
            :student-count="form.student_count"
            :staff-count="form.staff_count"
            :active="selectedKeys.has('bundle_complete')"
            @select="toggleModule('bundle_complete')"
          />

          <ModuleCatalogGrid
            :catalog="catalog"
            :selected-keys="new Set(expandedKeys)"
            :auto-included="autoIncluded"
            :required-by="requiredBy"
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
            :tenant-name="form.tenant_name || tenantVariantLabel('tenantSelfName', form.tenant_type)"
            :student-count="form.student_count"
            :staff-count="form.staff_count"
            v-model:plan="period"
            :quote="quote"
            :catalog="catalog"
            :tenant-type="form.tenant_type"
            :yearly-discount-pct="plan?.yearly_discount_pct"
            :bundle-benchmark="bundleBenchmark"
            :submit-label="midtransAvailable ? 'Lanjut ke pembayaran' : 'Buat pesanan'"
            :submitting="!midtransAvailable && submitting"
            v-model:discount-code="discountCode"
            :discount-applying="discountApplying"
            :discount-error="discountError"
            :applied-discount="appliedDiscount"
            @apply-discount="applyDiscount"
            @remove-discount="removeDiscount"
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
      <!-- No :disabled — a greyed-out Lanjut with no explanation is exactly
           what got a real user (pak Agus, SMP Rushd) stuck for two days.
           The click now always fires; validateStep() decides whether to
           advance or to surface the missing field. -->
      <button
        v-else-if="activeStep !== 'modul'"
        type="button"
        class="sn-foot-next"
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
/* Red asterisk marks required inputs. Reset italic + tiny left gap so
   it sits tight against the label without visually merging with it. */
.sn-lbl .req {
  color: #EF4444;
  font-style: normal;
  margin-left: 2px;
  font-weight: 600;
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
/* Error state: red border + red focus ring override the blue defaults.
   Also raises specificity via `input.sn-input-error` so it wins over
   `.sn-field input` on both idle and focus. */
.sn-field input.sn-input-error,
.sn-field input.sn-input-error:focus {
  border-color: #EF4444;
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.14);
}
/* Inline field error copy — sits directly under the input. Different
   class name from the top .sn-err banner so the two don't collide. */
.sn-field-err {
  color: #EF4444;
  font-size: 12px;
  margin-top: 4px;
  display: block;
  line-height: 1.4;
}
/* Fresh-empty hint — subtle grey, teaches the expected shape. Hidden
   the moment the user types anything OR when the error takes over. */
.sn-hint {
  color: #94A3B8;
  font-size: 11.5px;
  margin-top: 4px;
  display: block;
  line-height: 1.4;
  font-style: italic;
}
/* Top-of-step banner shown when validateStep() flags any field. Sits
   just above the form so the user sees WHY the click didn't advance
   before their eyes reach the (now red) input. */
.sn-form-banner {
  display: flex; align-items: center; gap: 8px;
  margin-bottom: 12px;
  padding: 10px 12px;
  border-radius: 8px;
  background: #FEF2F2;
  border: 0.5px solid #FCA5A5;
  color: #B91C1C;
  font-size: 12.5px;
  line-height: 1.4;
}
.sn-form-banner i { font-size: 15px; flex-shrink: 0; }

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
  /* 400px so the calculator can host 8-digit rupiah amounts alongside
     the Ambil button on the swap card (Rp -83.000 needed room), the
     capacity pills stay on one line, and "Paket Lengkap (Sekolah)"
     doesn't have to wrap in the swap-card title. Below 900px we
     collapse to single column (see media query). */
  grid-template-columns: minmax(0, 1fr) 400px;
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

@media (max-width: 900px) {
  .sn-body { grid-template-columns: 1fr; }
  .sn-side { border-left: none; border-top: 0.5px solid #E7ECF3; }
}
</style>
