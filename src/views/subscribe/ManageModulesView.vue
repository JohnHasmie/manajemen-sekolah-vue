<!--
  ManageModulesView.vue — admin self-service module management.

  Three affordances, all driven by the same server truth (GET
  /billing/modules/mine):
    1. See what's active + billed this month + billed next month.
    2. Turn off a module at period-end (cancel_at_period_end=true) —
       stays entitled until expires_at, no refund, dropped from the
       renewal quote. Cancellable.
    3. Turn on a new module mid-cycle via prorata (POST /modules/add
       creates a bank-transfer addon; caller navigates to the
       transfer confirmation UX at /subscribe/addon/transfer/…).

  Matches the approved high-fidelity mockup (mockup_manage_modules.html):
   - Two-column layout — module rows left, sticky summary right.
   - Sections: Modul aktif → Akan berakhir → Tambah modul.
   - Confirm-cancel modal spells out access sampai tgl / no refund /
     bisa dibatalkan; prorata modal shows the exact days × daily rate
     × seat count breakdown the backend will actually charge.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useMeStore } from '@/stores/me';
import { SubscriptionBillingService } from '@/services/billing.service';
import type {
  CycleChangePreview,
  ModuleAddPreview,
  ModuleCatalog,
  MyModules,
  MyModuleRow,
  MyModulesSubscription,
  TenantType,
} from '@/types/subscription-billing';
import {
  isModuleHiddenFor,
  moduleLabel,
  moduleTagline,
  money,
} from '@/components/subscribe/moduleTokens';
import { tenantLabel, tenantVariantLabel } from '@/lib/tenantTokens';
import ModuleTile from '@/components/subscribe/ModuleTile.vue';

/**
 * `embedded` = rendered INSIDE the admin shell (AppShell) at
 * /admin/settings/modules, reached from the Pengaturan hub. In that
 * mode the standalone subscribe chrome (KamilEdu logo bar + "Kembali
 * ke dashboard") is suppressed — the admin sidebar + shell header
 * already frame the page, so the extra top bar would double-chrome
 * and make the module page feel like it teleported out of the admin
 * area (which was the whole IA complaint).
 *
 * The default (false) keeps the full standalone surface for the three
 * out-of-shell entry points that still hit /subscribe/manage-modules:
 * the topbar Berlangganan chip, the mobile url_launcher deep-link, and
 * the kamiledu-ai 402 upgrade_url.
 */
withDefaults(defineProps<{ embedded?: boolean }>(), { embedded: false });

const router = useRouter();
const auth = useAuthStore();
const me = useMeStore();

/**
 * The four subscription-lifecycle endpoints (cycle-change preview +
 * commit, cancel, resume) are all gated on `billing.subscription.manage`
 * in SubscriptionLifecycleController. Gate the CONTROLS on the same
 * ability so an admin who lacks it still sees the state of their
 * subscription (current cycle, a pending cancel) read-only, instead of
 * being handed buttons that 403.
 *
 * Read off /me abilities — scoped to the active role — never off
 * `roles[].permission_keys`, which is unscoped and exists only for the
 * role switcher.
 */
const canManageBilling = computed<boolean>(() =>
  me.can('billing.subscription.manage'),
);

// ── State ──────────────────────────────────────────────────────────
const catalog = ref<ModuleCatalog | null>(null);
const mine = ref<MyModules>({ subscription: null, modules: [] });
const loading = ref(true);
const errorMessage = ref<string | null>(null);
const tenantType = ref<TenantType | null>(null);
const tenantName = ref<string>('');

// Confirm modal state — one modal for both cancel + add.
type ConfirmMode = 'cancel' | 'resume' | 'add';
const confirmMode = ref<ConfirmMode | null>(null);
const confirmKey = ref<string | null>(null);
const confirmBusy = ref(false);

// ── Subscription-lifecycle state (separate from the per-module
// modals above — these act on the `subscriptions` row itself). ──────
type LifecycleMode = 'cycle' | 'cancel-sub';
const lifecycleMode = ref<LifecycleMode | null>(null);
const lifecycleBusy = ref(false);
/**
 * The server's quote for the cycle change. Null until the preview call
 * lands — the confirm button stays disabled while it is, because the
 * amount shown to the admin MUST be the server's `amount_due` and not
 * a local estimate.
 */
const cyclePreview = ref<CycleChangePreview | null>(null);
const cyclePreviewError = ref<string | null>(null);
/** Resume runs without a modal, so it needs its own busy flag. */
const resumeBusy = ref(false);

// ── Derived ────────────────────────────────────────────────────────
const sub = computed<MyModulesSubscription | null>(() => mine.value.subscription);

const rowsByKey = computed<Map<string, MyModuleRow>>(() => {
  const m = new Map<string, MyModuleRow>();
  mine.value.modules.forEach((r) => m.set(r.module_key, r));
  return m;
});

const activeRows = computed<MyModuleRow[]>(() =>
  mine.value.modules.filter((r) => !r.cancel_at_period_end),
);
const cancelledRows = computed<MyModuleRow[]>(() =>
  mine.value.modules.filter((r) => r.cancel_at_period_end),
);

/**
 * Every module key the tenant already holds, with bundle rows expanded
 * to their members and each à la carte module's `requires[]` deps
 * pulled in. This mirrors what GetEntitledModulesAction unlocks at the
 * gate, so the "Tambah modul" list never re-offers a module the tenant
 * already owns THROUGH a package (a bundle stores one `bundle_complete`
 * row, not ten member rows — without this expansion all ten members
 * looked "addable").
 */
const heldModuleKeys = computed<Set<string>>(() => {
  const held = new Set<string>();
  const cat = catalog.value;
  mine.value.modules.forEach((r) => {
    held.add(r.module_key);
    const bundle = cat?.bundles[r.module_key];
    if (bundle) {
      bundle.members.forEach((m) => held.add(m));
    } else {
      (cat?.optional[r.module_key]?.requires ?? []).forEach((req) => held.add(req));
    }
  });
  return held;
});

const availableCatalog = computed(() => {
  if (!catalog.value) return [] as { key: string; item: NonNullable<ModuleCatalog['optional'][string]> }[];
  const held = heldModuleKeys.value;
  const tt = tenantType.value;
  return Object.entries(catalog.value.optional)
    .filter(([key, item]) => {
      if (held.has(key)) return false;
      // Same sekolah↔bimbel visibility rule the wizard picker uses —
      // a bimbel admin never gets offered modules whose backend
      // endpoints don't route bimbel traffic (attendance_class,
      // sekolah-only finance/lms/grades/etc.), and vice versa.
      return !isModuleHiddenFor(key, item.group, tt);
    })
    .map(([key, item]) => ({ key, item }));
});

/**
 * Sum of per-module `monthly_amount` for THIS period — the pre-discount
 * total. Displayed as the strike-through when a discount is active, and
 * as the plain price otherwise.
 */
const monthlyThisPeriodGross = computed<number>(() =>
  mine.value.modules.reduce((sum, r) => sum + r.monthly_amount, 0),
);

/**
 * The actual amount billed this period — prefer the server-computed
 * `subscription.amount` (discount-aware) over summing rows. Falls back
 * to the row sum on pre-!463 backends that don't ship `amount`.
 */
const monthlyThisPeriod = computed<number>(() => {
  const serverAmount = sub.value?.amount;
  if (typeof serverAmount === 'number') return serverAmount;
  return monthlyThisPeriodGross.value;
});

const monthlyNextPeriod = computed<number>(() =>
  activeRows.value.reduce((sum, r) => sum + r.monthly_amount, 0),
);

/**
 * Applied-discount snapshot the server sends. Null when no code was
 * applied at checkout — the "Tagihan bulan ini" card falls back to the
 * plain total in that case.
 */
const appliedDiscount = computed(
  () => sub.value?.applied_discount ?? null,
);

/**
 * Show the strike-through pre-discount price only when a discount is
 * active AND the gross total is strictly greater than what's billed.
 */
const showDiscountStrike = computed<boolean>(
  () => appliedDiscount.value !== null
    && monthlyThisPeriodGross.value > monthlyThisPeriod.value,
);

const discountBadgeLabel = computed<string>(() => {
  const d = appliedDiscount.value;
  if (!d) return '';
  if (d.type === 'percent' && typeof d.value === 'number' && d.value > 0) {
    return `Diskon ${d.value}%${d.code ? ` · ${d.code}` : ''}`;
  }
  if (d.discount_amount > 0) {
    return `Hemat ${money(d.discount_amount)}/bln${d.code ? ` · ${d.code}` : ''}`;
  }
  return d.code ?? '';
});

const discountDurationLabel = computed<string>(() => {
  const d = appliedDiscount.value;
  if (!d) return '';
  const bits: string[] = [];
  if (typeof d.duration_months === 'number' && d.duration_months > 0) {
    bits.push(`${d.duration_months} bulan`);
  }
  if (d.valid_until) {
    const when = new Date(d.valid_until);
    if (!isNaN(when.getTime())) {
      bits.push(
        `s/d ${when.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}`,
      );
    }
  }
  return bits.join(' · ');
});

const monthlyDelta = computed<number>(
  () => monthlyNextPeriod.value - monthlyThisPeriod.value,
);

const expiresDate = computed<string>(() => formatDate(sub.value?.expires_at));

const startsDate = computed<string>(() => formatDate(sub.value?.starts_at));

const daysRemaining = computed<number>(() => sub.value?.days_remaining ?? 0);

// ── Billing cycle + cancel state ───────────────────────────────────
//
// "Plan" on this subscription means the BILLING CYCLE and nothing else
// — monthly or yearly. There is no Basic/Pro tier in this product; the
// feature tiers are the modules listed below. All copy here says
// "siklus tagihan", never "upgrade paket".

const isYearly = computed<boolean>(() => sub.value?.plan === 'yearly');

const cycleLabel = computed<string>(() => (isYearly.value ? 'Tahunan' : 'Bulanan'));

/** "/ tahun" vs "/ bln" — the unit the current charge is quoted in. */
const cycleUnit = computed<string>(() => (isYearly.value ? '/ tahun' : '/ bln'));

/**
 * What the current cycle costs. Prefer the server's discount-aware
 * `amount`; fall back to the summed module rows on older backends
 * (same fallback `monthlyThisPeriod` uses).
 */
const cycleAmount = computed<number>(() => {
  const serverAmount = sub.value?.amount;
  if (typeof serverAmount === 'number') return serverAmount;
  return monthlyThisPeriodGross.value;
});

/**
 * A period-end cancel is pending. `status` is still `active` and the
 * tenant keeps everything until `cancel_effective_at` — this flag only
 * means "do not carry into the next period".
 *
 * Absent on pre-!618 backends, so compare explicitly against true
 * rather than relying on undefined being falsy by accident.
 */
const cancelPending = computed<boolean>(
  () => sub.value?.cancel_at_period_end === true,
);

/**
 * The date access actually stops. The server only populates
 * `cancel_effective_at` while a cancel is pending; fall back to
 * `expires_at` so a pre-!618 backend still renders a real date rather
 * than an em dash in the banner headline.
 */
const cancelEffectiveDate = computed<string>(() =>
  formatDate(sub.value?.cancel_effective_at ?? sub.value?.expires_at),
);

/**
 * Rule 3: yearly → monthly is refused mid-term (the backend 422s with
 * this same reasoning). The control is rendered DISABLED rather than
 * hidden — hiding it makes an admin conclude the product can't switch
 * back at all, when in fact they just have to wait for renewal.
 */
const monthlyBlockedReason = computed<string>(
  () => `Bisa diubah saat perpanjangan (${expiresDate.value})`,
);

const initials = computed<string>(() =>
  (tenantName.value || auth.user?.name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0])
    .join('')
    .toUpperCase(),
);

const perUnitWord = computed<string>(() =>
  tenantLabel('student', tenantType.value),
);

// The row targeted by whichever modal is open.
const confirmRow = computed<MyModuleRow | null>(() =>
  confirmKey.value ? rowsByKey.value.get(confirmKey.value) ?? null : null,
);
const confirmCatalogItem = computed(() =>
  confirmKey.value ? catalog.value?.optional[confirmKey.value] ?? null : null,
);

// Prorata quote — SERVER-COMPUTED, fetched when the add dialog opens.
//
// This used to be a local `computed` that re-ran AddModuleAction's
// formula in TypeScript against the catalog response. It could not stay
// correct: the server prices from `config('billing.modules'|'bundles')`
// first and only falls back to the catalog constants, and that config
// is env-driven — so retuning a BILLING_* var in prod moved the charge
// without moving what this page displayed. It also read bundles out of
// `catalog.optional`, where they do not live, so bundle rows showed no
// price at all.
//
// Never re-derive `amount` here. The whole point is that the number on
// screen and the number charged come from one place.
const proratedAdd = ref<ModuleAddPreview | null>(null);
const proratedAddLoading = ref(false);
const proratedAddError = ref<string | null>(null);

async function loadAddQuote(moduleKey: string): Promise<void> {
  if (!sub.value) return;
  proratedAdd.value = null;
  proratedAddError.value = null;
  proratedAddLoading.value = true;
  const requestedFor = moduleKey;
  try {
    const quote = await SubscriptionBillingService.previewAddModule({
      subscription_id: sub.value.id,
      module_key: moduleKey,
    });
    // Guard against a slow response landing after the admin switched
    // modules or closed the dialog — otherwise the price of a module
    // they are no longer looking at would appear on the button.
    if (confirmMode.value === 'add' && confirmKey.value === requestedFor) {
      proratedAdd.value = quote;
    }
  } catch (e) {
    if (confirmMode.value === 'add' && confirmKey.value === requestedFor) {
      proratedAddError.value =
        e instanceof Error ? e.message : 'Gagal menghitung biaya penambahan modul.';
    }
  } finally {
    if (confirmKey.value === requestedFor) proratedAddLoading.value = false;
  }
}

const requiresLabels = computed<string[]>(() => {
  if (confirmMode.value !== 'add' || !confirmCatalogItem.value || !catalog.value) return [];
  return confirmCatalogItem.value.requires
    .map((k) => catalog.value?.optional[k])
    .filter(Boolean)
    .map((it) => moduleLabel(it!, tenantType.value));
});

// ── Effects ────────────────────────────────────────────────────────
async function loadAll(): Promise<void> {
  loading.value = true;
  errorMessage.value = null;
  try {
    const [cat, m, tenants] = await Promise.all([
      SubscriptionBillingService.getModuleCatalog(),
      SubscriptionBillingService.getMyModules(),
      SubscriptionBillingService.getMyTenants().catch(() => []),
    ]);
    catalog.value = cat;
    mine.value = m;
    // Pick tenant type + display name from the tenant list — the modules
    // endpoint doesn't ship this, and it drives the sekolah/bimbel copy.
    //
    // Match on the CURRENTLY-ACTIVE tenant (auth.schoolId), not on
    // `m.subscription?.id` (that's the subscription id — nothing on
    // a tenant matches it, so this lookup used to always miss and
    // fall through to the "first non-expired" or "any" fallback,
    // which handed us the WRONG tenant when the user manages multiple.
    // When the tenants endpoint fails (returns []) we fall back to
    // the /me store's `activeTenantType` if available, then finally
    // 'sekolah' — never null, since `isModuleHiddenFor` treats null
    // as permissive and lets bimbel-only modules leak into the
    // sekolah picker.
    const target =
      tenants.find((t) => t.id === auth.schoolId) ??
      tenants.find((t) => t.subscription_status !== 'expired') ??
      tenants[0];
    if (target) {
      tenantType.value = target.tenant_type;
      tenantName.value = target.name;
    } else {
      // Defensive default — see comment above.
      tenantType.value = 'sekolah';
    }
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  if (!auth.isAuthenticated) {
    router.replace('/subscribe');
    return;
  }
  loadAll();
});

// ── Actions ────────────────────────────────────────────────────────
function askCancel(key: string): void {
  confirmMode.value = 'cancel';
  confirmKey.value = key;
}
function askResume(key: string): void {
  confirmMode.value = 'resume';
  confirmKey.value = key;
}
function askAdd(key: string): void {
  confirmMode.value = 'add';
  confirmKey.value = key;
  void loadAddQuote(key);
}
function closeModal(): void {
  if (confirmBusy.value) return;
  confirmMode.value = null;
  confirmKey.value = null;
  proratedAdd.value = null;
  proratedAddError.value = null;
  proratedAddLoading.value = false;
}

async function doCancel(): Promise<void> {
  if (!sub.value || !confirmKey.value) return;
  const key = confirmKey.value;
  confirmBusy.value = true;
  try {
    await SubscriptionBillingService.cancelModule({
      subscription_id: sub.value.id,
      module_key: key,
    });
    // Reflect the change immediately — move the row into the "tidak
    // diperpanjang" section without waiting on the reload — then close
    // the modal. `confirmBusy` MUST be cleared BEFORE closeModal():
    // closeModal()'s guard (`if (confirmBusy) return`) would otherwise
    // swallow the close and leave the dialog stuck open over a
    // still-active-looking list (the reported bug).
    const row = mine.value.modules.find((r) => r.module_key === key);
    if (row) row.cancel_at_period_end = true;
    confirmBusy.value = false;
    closeModal();
    // Resync with the server (source of truth) in the background.
    void loadAll();
  } catch (e) {
    errorMessage.value = (e as Error).message;
    confirmBusy.value = false;
  }
}
async function doResume(): Promise<void> {
  if (!sub.value || !confirmKey.value) return;
  const key = confirmKey.value;
  confirmBusy.value = true;
  try {
    await SubscriptionBillingService.resumeModule({
      subscription_id: sub.value.id,
      module_key: key,
    });
    // Optimistic move back to the active section + close the modal.
    // Clear confirmBusy before closeModal() (see doCancel note).
    const row = mine.value.modules.find((r) => r.module_key === key);
    if (row) row.cancel_at_period_end = false;
    confirmBusy.value = false;
    closeModal();
    void loadAll();
  } catch (e) {
    errorMessage.value = (e as Error).message;
    confirmBusy.value = false;
  }
}
async function doAdd(): Promise<void> {
  if (!sub.value || !confirmKey.value) return;
  confirmBusy.value = true;
  try {
    const created = await SubscriptionBillingService.addModule({
      subscription_id: sub.value.id,
      module_key: confirmKey.value,
    });
    // Backend returns a share_url that ends in /subscribe/addon/transfer/{token}.
    // Push the caller to the transfer confirmation page carrying the
    // AddonCreated payload via history.state — the destination view
    // reads it immediately without re-fetching (no public token
    // endpoint exists yet). Same pattern as the seat top-up flow.
    const token = shareTokenFromShareUrl(created.share_url);
    if (token) {
      // Close the confirm modal FIRST so the transition doesn't leave
      // a dangling backdrop. confirmBusy must be cleared before
      // closeModal (its guard blocks the close otherwise).
      confirmBusy.value = false;
      closeModal();
      await router.push({
        path: `/subscribe/addon/transfer/${token}`,
        // Router 4 forwards the state option through history.state so
        // the destination view can read `window.history.state.addon`.
        state: { addon: created as unknown as Record<string, unknown> },
      });
      return;
    }
    // Fallback: reload the module list; the pending addon shows up in
    // ManageModulesView after admin approval anyway.
    confirmBusy.value = false;
    closeModal();
    void loadAll();
  } catch (e) {
    errorMessage.value = (e as Error).message;
    confirmBusy.value = false;
  }
}

// ── Subscription lifecycle actions ─────────────────────────────────

function closeLifecycleModal(): void {
  if (lifecycleBusy.value) return;
  lifecycleMode.value = null;
  cyclePreview.value = null;
  cyclePreviewError.value = null;
}

/**
 * Open the cycle-change confirmation and fetch the server's quote.
 *
 * The modal opens IMMEDIATELY in a loading state rather than waiting
 * for the preview to land, so the click has instant feedback; the
 * confirm button is disabled until `cyclePreview` is populated. Every
 * figure the admin sees comes from that response — nothing here
 * multiplies a rate by a day count.
 */
async function askCycleChange(): Promise<void> {
  if (!sub.value || !canManageBilling.value) return;
  lifecycleMode.value = 'cycle';
  cyclePreview.value = null;
  cyclePreviewError.value = null;
  lifecycleBusy.value = true;
  try {
    cyclePreview.value = await SubscriptionBillingService.previewCycleChange({
      subscription_id: sub.value.id,
      plan: 'yearly',
    });
  } catch (e) {
    // Surface the backend's own message (it explains WHY — wrong
    // direction, no-op, inactive subscription) inside the modal rather
    // than the page-level error strip, so it sits next to the action
    // that produced it.
    cyclePreviewError.value = (e as Error).message;
  } finally {
    lifecycleBusy.value = false;
  }
}

/**
 * Commit the switch. Guarded on `cyclePreview` being present so we can
 * never POST a change the admin confirmed against a blank/failed quote.
 */
async function doCycleChange(): Promise<void> {
  const quote = cyclePreview.value;
  if (!sub.value || !quote) return;
  lifecycleBusy.value = true;
  try {
    await SubscriptionBillingService.changeCycle({
      subscription_id: sub.value.id,
      plan: quote.target_plan,
    });
    // Clear busy BEFORE closing — closeLifecycleModal()'s guard would
    // otherwise swallow the close and strand the dialog open over a
    // stale plan (the same bug the per-module modals hit).
    lifecycleBusy.value = false;
    closeLifecycleModal();
    void loadAll();
  } catch (e) {
    cyclePreviewError.value = (e as Error).message;
    lifecycleBusy.value = false;
  }
}

function askCancelSubscription(): void {
  if (!canManageBilling.value) return;
  lifecycleMode.value = 'cancel-sub';
}

async function doCancelSubscription(): Promise<void> {
  if (!sub.value) return;
  lifecycleBusy.value = true;
  try {
    const state = await SubscriptionBillingService.cancelSubscription({
      subscription_id: sub.value.id,
    });
    // Optimistically flip into the cancel-pending banner so the page
    // reflects the decision before the refetch lands. Take the date
    // from the server response — it is the authority on when access
    // actually stops.
    if (mine.value.subscription) {
      mine.value.subscription.cancel_at_period_end = true;
      mine.value.subscription.cancel_effective_at = state.active_until;
    }
    lifecycleBusy.value = false;
    closeLifecycleModal();
    void loadAll();
  } catch (e) {
    errorMessage.value = (e as Error).message;
    lifecycleBusy.value = false;
  }
}

/**
 * Resume runs WITHOUT a confirmation step, unlike every other action
 * on this page. It is the recovery path out of an alarming amber
 * banner and it only restores the state the tenant was already in —
 * putting a "are you sure you want to keep your subscription?" gate in
 * front of that would be friction pointed the wrong way.
 */
async function doResumeSubscription(): Promise<void> {
  if (!sub.value || !canManageBilling.value) return;
  resumeBusy.value = true;
  try {
    await SubscriptionBillingService.resumeSubscription({
      subscription_id: sub.value.id,
    });
    if (mine.value.subscription) {
      mine.value.subscription.cancel_at_period_end = false;
      mine.value.subscription.cancel_effective_at = null;
    }
    void loadAll();
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    resumeBusy.value = false;
  }
}

function shareTokenFromShareUrl(url: string | null | undefined): string | null {
  if (!url) return null;
  const parts = String(url).split('/subscribe/addon/transfer/');
  return parts[1]?.replace(/\/.*$/, '') ?? null;
}

// ── Helpers ────────────────────────────────────────────────────────
// `tintFor` + `iconFor` used to live here as inline lookups over the
// moduleTokens maps. Deleted because `<ModuleTile>` now handles the
// tint/icon resolution internally — every place we render a module
// row (subscribe picker, kelola modul, admin dashboard) reads from
// the same visual pipeline.
/**
 * Resolve a module_key back to its catalog entry, with a defensive
 * fallback so the row still renders (with just the key as label) when
 * the catalog fetch failed mid-load. Keeps `<ModuleTile>` happy — the
 * child expects a full `ModuleCatalogItem` and we don't want to guard
 * `v-if` around every row.
 */
function itemFor(key: string) {
  // Bundle rows (e.g. `bundle_complete`) live in `catalog.bundles`, not
  // `catalog.optional`, and have a different shape. Adapt one into the
  // ModuleCatalogItem `<ModuleTile>` expects so a package renders as a
  // proper managed row (label + package icon/tint) instead of falling
  // through to the raw-key fallback below.
  const bundle = catalog.value?.bundles[key];
  if (bundle) {
    return {
      key,
      label: bundle.label,
      group: 'Paket',
      prefixes: [] as string[],
      price_per_student: bundle.price_per_student,
      price_per_staff: bundle.price_per_staff,
      pricing_seat: 'student' as const,
      requires: [] as string[],
      is_ai: false,
    };
  }
  return (
    catalog.value?.optional[key] ?? {
      key,
      label: key,
      group: 'Default',
      prefixes: [] as string[],
      price_per_student: 0,
      price_per_staff: 0,
      pricing_seat: 'student' as const,
      requires: [] as string[],
      is_ai: false,
    }
  );
}
function labelFor(key: string): string {
  const bundle = catalog.value?.bundles[key];
  if (bundle) return bundle.label;
  const item = catalog.value?.optional[key];
  return item ? moduleLabel(item, tenantType.value) : key;
}
function seatBreakdown(row: MyModuleRow): string {
  if (!sub.value) return '';
  const parts: string[] = [];
  if (row.price_per_student_snapshot > 0) {
    parts.push(
      `${sub.value.student_count.toLocaleString('id-ID')} ${perUnitWord.value} × ${money(row.price_per_student_snapshot)}`,
    );
  }
  if (row.price_per_staff_snapshot > 0) {
    const staffWord = tenantLabel('teacher', tenantType.value);
    parts.push(`${sub.value.staff_count} ${staffWord} × ${money(row.price_per_staff_snapshot)}`);
  }
  return parts.join(' + ');
}
/**
 * Sub-line seat breakdown for AVAILABLE-to-add rows (which live off
 * `item` rates rather than a `row`'s snapshot). Same shape as
 * `seatBreakdown()` above but uses live catalog rates so a mid-cycle
 * add reflects any rate retune that landed after the tenant's
 * original purchase.
 */
function availSeatBreakdown(item: ModuleCatalog['optional'][string]): string {
  if (!sub.value) return '';
  const parts: string[] = [];
  if (item.price_per_student > 0) {
    parts.push(
      `${sub.value.student_count.toLocaleString('id-ID')} ${perUnitWord.value} × ${money(item.price_per_student)}`,
    );
  }
  if (item.price_per_staff > 0) {
    const staffWord = tenantLabel('teacher', tenantType.value);
    parts.push(`${sub.value.staff_count} ${staffWord} × ${money(item.price_per_staff)}`);
  }
  return parts.join(' + ');
}
function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Intl.DateTimeFormat('id-ID', {
      day: 'numeric', month: 'short', year: 'numeric',
    }).format(new Date(iso));
  } catch { return '—'; }
}
</script>

<template>
  <div class="mm-page" :class="{ 'is-embedded': embedded }">
    <!-- Standalone subscribe chrome. Hidden when embedded in the admin
         shell — the shell's own sidebar + header already frame it. -->
    <div v-if="!embedded" class="mm-nav">
      <div class="mm-logo">K</div>
      <div class="mm-brand">
        <div class="mm-brand-name">KamilEdu</div>
        <div class="mm-brand-tag">Langganan · Kelola modul</div>
      </div>
      <div class="mm-nav-right">
        <a
          href="https://wa.me/6285179819002"
          target="_blank"
          rel="noopener"
          class="mm-nav-link"
        >
          <i class="ti ti-message-circle" aria-hidden="true" />
          Bantuan
        </a>
        <router-link to="/" class="mm-nav-link">
          <i class="ti ti-arrow-left" aria-hidden="true" />
          Kembali ke dashboard
        </router-link>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mm-loading">
      <div class="mm-spinner" aria-hidden="true"></div>
      <div>Memuat modul langganan…</div>
    </div>

    <!-- No active subscription -->
    <div v-else-if="!sub" class="mm-empty">
      <div class="mm-empty-card">
        <div class="mm-empty-h1">Belum ada langganan aktif</div>
        <p class="mm-empty-sub">
          Halaman ini menampilkan modul yang aktif di langganan Anda.
          Belum ada langganan yang bisa dikelola — silakan mulai dulu.
        </p>
        <button type="button" class="btn primary" @click="router.push('/subscribe')">
          Mulai langganan
          <i class="ti ti-arrow-right" aria-hidden="true" />
        </button>
      </div>
    </div>

    <!-- Main content -->
    <template v-else>
      <!-- Hero strip -->
      <div class="mm-hero">
        <div class="mm-hero-avatar">{{ initials }}</div>
        <div class="mm-hero-body">
          <div class="mm-hero-kicker">
            {{ tenantName || 'Langganan Anda' }} ·
            {{ tenantVariantLabel('tenantTypeFormal', tenantType) }}
          </div>
          <h1 class="mm-hero-h1">Kelola modul langganan Anda</h1>
          <div class="mm-hero-meta">
            <span>Periode berjalan {{ startsDate }} – {{ expiresDate }}</span>
            <span>{{ sub.student_count }} {{ perUnitWord }} · {{ sub.staff_count }}
              {{ tenantLabel('teacher', tenantType) }}</span>
            <span>Sisa {{ daysRemaining }} hari</span>
          </div>
        </div>
        <div class="mm-hero-side">
          <span class="pill is-active">Aktif</span>
          <!-- `status` stays `active` through a pending cancel, so the
               pill is correct — but the sub-line must not keep
               promising a renewal that will not happen. -->
          <div v-if="cancelPending" class="mm-hero-side-sub is-ending">
            Berhenti {{ cancelEffectiveDate }}
          </div>
          <div v-else class="mm-hero-side-sub">Perpanjangan otomatis</div>
        </div>
      </div>

      <p v-if="errorMessage" class="mm-err">{{ errorMessage }}</p>

      <!-- ═════════ Siklus tagihan + status langganan ═════════
           Sits directly under the subscription summary and above the
           module lists: it describes the subscription as a whole,
           while everything in `.mm-body` is per-module. A pending
           cancel has to be the first thing an admin sees on open, and
           full-width here is the only spot that guarantees that
           without competing with the sticky billing summary. -->
      <section class="mm-lifecycle">
        <!-- STATE 3 — cancel pending. Replaces the whole area: an
             admin who is mid-cancel should be offered exactly one
             action (undo), not a cadence upgrade. This is also what
             keeps a cancelling tenant away from a renewal purchase —
             see the `.side-preview` card below. -->
        <div v-if="cancelPending" class="mm-cancel-banner">
          <div class="mm-cancel-icon" aria-hidden="true">
            <i class="ti ti-alert-triangle" />
          </div>
          <div class="mm-cancel-body">
            <h2 class="mm-cancel-title">
              Langganan berhenti pada {{ cancelEffectiveDate }}
            </h2>
            <p class="mm-cancel-sub">
              Semua fitur <strong>tetap aktif sampai {{ cancelEffectiveDate }}</strong> — periode ini
              sudah dibayar dan tidak ada refund. Setelah tanggal itu langganan tidak diperpanjang.
              Anda bisa membatalkan keputusan ini kapan saja sebelum tanggal tersebut.
            </p>
            <div class="mm-cancel-meta">
              Siklus tagihan saat ini: <strong>{{ cycleLabel }}</strong>
              · {{ money(cycleAmount) }} {{ cycleUnit }}
            </div>
          </div>
          <div class="mm-cancel-cta">
            <button
              v-if="canManageBilling"
              type="button"
              class="btn primary"
              :disabled="resumeBusy"
              @click="doResumeSubscription"
            >
              <template v-if="resumeBusy">Memproses…</template>
              <template v-else>
                <i class="ti ti-refresh" aria-hidden="true" />
                Lanjutkan langganan
              </template>
            </button>
            <!-- STATE 4 (read-only) — no ability, so no action. The
                 state above is still fully visible. -->
            <span v-else class="mm-lifecycle-readonly">
              Hubungi admin dengan akses penagihan untuk melanjutkan langganan.
            </span>
          </div>
        </div>

        <!-- STATE 1 / 2 — normal. Current cycle + the cadence options. -->
        <div v-else class="mm-cycle-card">
          <div class="mm-cycle-current">
            <div class="side-kicker">Siklus tagihan</div>
            <div class="mm-cycle-now">
              <span class="mm-cycle-name">{{ cycleLabel }}</span>
              <span class="mm-cycle-amount">{{ money(cycleAmount) }} {{ cycleUnit }}</span>
            </div>
            <div class="mm-cycle-hint">
              Periode berjalan sampai {{ expiresDate }}
            </div>
          </div>

          <div class="mm-cycle-options">
            <!-- STATE 1 — on monthly: yearly is offered. The amount is
                 NOT computed here; clicking fetches the server quote. -->
            <template v-if="!isYearly">
              <button
                v-if="canManageBilling"
                type="button"
                class="row-cta is-add"
                @click="askCycleChange"
              >
                <i class="ti ti-calendar-up" aria-hidden="true" />
                Ubah ke Tahunan
              </button>
              <span class="mm-cycle-note">
                Sisa hari di periode bulanan ini dihitung sebagai potongan.
              </span>
            </template>

            <!-- STATE 2 — on yearly: monthly is shown DISABLED with the
                 reason + date, never hidden (rule 3). -->
            <template v-else>
              <button
                type="button"
                class="row-cta"
                disabled
                aria-describedby="mm-cycle-monthly-reason"
              >
                Ubah ke Bulanan
              </button>
              <span id="mm-cycle-monthly-reason" class="mm-cycle-note">
                {{ monthlyBlockedReason }}
              </span>
            </template>
          </div>

          <!-- Low-emphasis, destructive-adjacent. Deliberately a text
               link, not a button — it must not compete with the module
               actions in the list below. -->
          <div class="mm-cycle-foot">
            <button
              v-if="canManageBilling"
              type="button"
              class="mm-cancel-link"
              @click="askCancelSubscription"
            >
              Batalkan langganan
            </button>
            <span v-else class="mm-lifecycle-readonly">
              Anda tidak memiliki akses untuk mengubah langganan.
            </span>
          </div>
        </div>
      </section>

      <div class="mm-body">
        <!-- MAIN column -->
        <div class="mm-main">
          <!-- MODUL AKTIF -->
          <section class="mm-sec">
            <header class="mm-sec-head">
              <span class="mm-sec-lbl">Modul aktif</span>
              <span class="mm-sec-count">{{ activeRows.length }}</span>
              <span class="mm-sec-hint">Diperpanjang otomatis bulan depan</span>
            </header>

            <div v-if="!activeRows.length" class="mm-sec-empty">
              Tidak ada modul aktif di langganan ini.
            </div>

            <ModuleTile
              v-for="row in activeRows"
              :key="`a-${row.module_key}`"
              :item="itemFor(row.module_key)"
              :tenant-type="tenantType"
              mode="managed"
              :monthly-amount="row.source === 'comp' ? 0 : row.monthly_amount"
              :pill-label="row.source === 'comp' ? 'Gratis · hadiah' : 'Aktif'"
              :pill-tone="row.source === 'comp' ? 'muted' : 'success'"
              :seat-breakdown-text="seatBreakdown(row) || null"
              :price-unit-override="row.source === 'comp' ? 'Gratis' : null"
            >
              <template #trailing>
                <button
                  v-if="row.source !== 'comp'"
                  type="button"
                  class="row-cta is-danger"
                  @click="askCancel(row.module_key)"
                >Matikan modul</button>
              </template>
            </ModuleTile>
          </section>

          <!-- AKAN BERAKHIR -->
          <section v-if="cancelledRows.length" class="mm-sec">
            <header class="mm-sec-head">
              <span class="mm-sec-lbl">Akan berakhir {{ expiresDate }}</span>
              <span class="mm-sec-count">{{ cancelledRows.length }}</span>
              <span class="mm-sec-hint">Tidak dihitung di tagihan bulan depan</span>
            </header>

            <div class="mm-note-strip">
              <i class="ti ti-alert-triangle" aria-hidden="true" />
              <div>
                Modul di bawah ini <strong>tetap aktif sampai {{ expiresDate }}</strong> — sudah dibayar untuk periode ini,
                tidak ada refund. Perpanjangan otomatis <strong>tidak</strong> akan menyertakan modul tersebut. Anda bisa
                membatalkan keputusan ini kapan saja sebelum periode berakhir.
              </div>
            </div>

            <ModuleTile
              v-for="row in cancelledRows"
              :key="`c-${row.module_key}`"
              :item="itemFor(row.module_key)"
              :tenant-type="tenantType"
              mode="managed"
              :monthly-amount="row.monthly_amount"
              :pill-label="`Aktif sampai ${expiresDate}`"
              pill-tone="warn"
              :seat-breakdown-text="`${seatBreakdown(row)}${seatBreakdown(row) ? ' · ' : ''}tersisa ${daysRemaining} hari`"
              price-unit-override="/ bln, terakhir"
            >
              <template #trailing>
                <button type="button" class="row-cta is-resume" @click="askResume(row.module_key)">
                  <i class="ti ti-refresh" aria-hidden="true" />
                  Batalkan penonaktifan
                </button>
              </template>
            </ModuleTile>
          </section>

          <!-- TAMBAH MODUL -->
          <section v-if="availableCatalog.length" class="mm-sec">
            <header class="mm-sec-head">
              <span class="mm-sec-lbl">Tambah modul</span>
              <span class="mm-sec-count">{{ availableCatalog.length }}</span>
              <span class="mm-sec-hint">Biaya prorata untuk sisa periode berjalan</span>
            </header>

            <ModuleTile
              v-for="{ key, item } in availableCatalog"
              :key="`v-${key}`"
              :item="item"
              :tenant-type="tenantType"
              mode="managed"
              :monthly-amount="item.price_per_student * sub.student_count + item.price_per_staff * sub.staff_count"
              :seat-breakdown-text="availSeatBreakdown(item)"
              price-unit-override="/ bln, +prorata"
            >
              <template #trailing>
                <button type="button" class="row-cta is-add" @click="askAdd(key)">
                  <i class="ti ti-plus" aria-hidden="true" />
                  Tambahkan
                </button>
              </template>
            </ModuleTile>
          </section>
        </div>

        <!-- SIDE column (sticky summary) -->
        <aside class="mm-side">
          <div class="side-card">
            <div class="side-kicker">Tagihan bulan ini</div>
            <div class="side-total">{{ money(monthlyThisPeriod) }}</div>
            <!-- Strike-through pre-discount total + discount badge when
                 an applied code is in play. Only rendered when the gross
                 total is strictly greater than the billed amount so we
                 don't strike through a number equal to itself. -->
            <div v-if="showDiscountStrike" class="side-strike">
              {{ money(monthlyThisPeriodGross) }}
            </div>
            <div v-if="appliedDiscount" class="side-discount">
              <span class="side-discount-tag">
                <i class="ti ti-sparkles" aria-hidden="true" />
                {{ discountBadgeLabel }}
              </span>
              <span
                v-if="discountDurationLabel"
                class="side-discount-meta"
              >{{ discountDurationLabel }}</span>
            </div>
            <div class="side-total-sub">
              {{ mine.modules.length }} modul aktif · sudah dibayar {{ startsDate }}
            </div>
          </div>

          <!-- Renewal preview. Suppressed entirely while a cancel is
               pending: quoting "perpanjangan otomatis Rp X" at a tenant
               who has just cancelled is a false promise, and it is the
               one place on this page that could walk them into a
               renewal purchase instead of the resume they actually
               need. The backend's renewalQuote does NOT check
               cancel_at_period_end, so the guard has to live here. -->
          <div v-if="cancelPending" class="side-card side-ending">
            <div class="side-kicker">Tidak diperpanjang</div>
            <div class="side-title">Berakhir {{ cancelEffectiveDate }}</div>
            <div class="side-ending-note">
              Langganan dijadwalkan berhenti. Lanjutkan langganan dulu untuk
              mengaktifkan kembali perpanjangan.
            </div>
          </div>
          <div v-else class="side-card side-preview">
            <div class="side-kicker">Perpanjangan otomatis</div>
            <div class="side-title">{{ expiresDate }}</div>
            <div class="side-total">{{ money(monthlyNextPeriod) }}</div>
            <span v-if="monthlyDelta < 0" class="side-delta">
              <i class="ti ti-arrow-down-right" aria-hidden="true" />
              −{{ money(-monthlyDelta) }} ·
              {{ cancelledRows.length }} modul berakhir
            </span>
            <span v-else-if="monthlyDelta === 0" class="side-delta neutral">
              Sama dengan bulan ini
            </span>
          </div>
        </aside>
      </div>
    </template>

    <!-- ═════════ Modal — Matikan modul ═════════ -->
    <div
      v-if="confirmMode === 'cancel' && confirmRow"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-cancel-title"
      @click.self="closeModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon warn"><i class="ti ti-alert-triangle" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-cancel-title" class="mm-modal-title">
              Matikan modul <em>{{ labelFor(confirmRow.module_key) }}</em>?
            </div>
            <div class="mm-modal-sub">
              Modul akan berhenti diperpanjang mulai <strong>{{ expiresDate }}</strong>. Fitur tetap bisa
              dipakai sampai tanggal itu — sudah dibayar untuk periode ini, tidak ada refund.
            </div>
          </div>
        </div>
        <ul class="mm-bullet">
          <li>Guru &amp; wali kelas tetap bisa akses <strong>sampai {{ expiresDate }}</strong>.</li>
          <li>Perpanjangan otomatis di {{ expiresDate }} <strong>tidak</strong> menyertakan modul ini
            (hemat {{ money(confirmRow.monthly_amount) }}/bln).</li>
          <li>Bisa diaktifkan kembali sebelum {{ expiresDate }} — cukup satu klik, tanpa biaya tambahan.</li>
          <li class="x">Setelah {{ expiresDate }} data terkait menjadi read-only. Ekspor tersedia 30 hari lagi.</li>
        </ul>
        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="confirmBusy" @click="closeModal">
            Batal, tetap aktif
          </button>
          <button class="btn warn" :disabled="confirmBusy" @click="doCancel">
            <template v-if="confirmBusy">Memproses…</template>
            <template v-else>Ya, matikan di {{ expiresDate }}</template>
          </button>
        </div>
      </div>
    </div>

    <!-- ═════════ Modal — Batalkan penonaktifan ═════════ -->
    <div
      v-if="confirmMode === 'resume' && confirmRow"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-resume-title"
      @click.self="closeModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon good"><i class="ti ti-refresh" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-resume-title" class="mm-modal-title">
              Aktifkan kembali <em>{{ labelFor(confirmRow.module_key) }}</em>?
            </div>
            <div class="mm-modal-sub">
              Modul akan ikut diperpanjang otomatis di <strong>{{ expiresDate }}</strong> dengan tarif snapshot
              yang sudah Anda bayarkan. Tidak ada biaya tambahan sekarang.
            </div>
          </div>
        </div>
        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="confirmBusy" @click="closeModal">Batal</button>
          <button class="btn primary" :disabled="confirmBusy" @click="doResume">
            <template v-if="confirmBusy">Memproses…</template>
            <template v-else>Ya, aktifkan kembali</template>
          </button>
        </div>
      </div>
    </div>

    <!-- ═════════ Modal — Tambahkan modul (prorata) ═════════ -->
    <div
      v-if="confirmMode === 'add' && confirmCatalogItem && sub"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-add-title"
      @click.self="closeModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon add"><i class="ti ti-plus" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-add-title" class="mm-modal-title">
              Tambahkan <em>{{ moduleLabel(confirmCatalogItem, tenantType) }}</em>
            </div>
            <div class="mm-modal-sub">
              {{ moduleTagline(confirmCatalogItem, tenantType) }} Modul aktif otomatis begitu pembayaran masuk —
              biasanya di bawah 15 menit lewat Midtrans, atau maks 1×24 jam lewat transfer.
            </div>
          </div>
        </div>

        <div class="mm-quote">
          <div class="mm-quote-row">
            <span class="mm-quote-lbl">Sisa periode berjalan</span>
            <span class="mm-quote-val">{{ daysRemaining }} hari</span>
          </div>
          <div v-if="proratedAdd" class="mm-quote-row">
            <span class="mm-quote-lbl">Tarif harian × seat</span>
            <span class="mm-quote-val">{{ money(proratedAdd.daily_rate) }} / hari</span>
          </div>
          <div v-if="proratedAdd" class="mm-quote-row">
            <span class="mm-quote-lbl">Bulan depan (mulai {{ expiresDate }})</span>
            <span class="mm-quote-val">{{ money(proratedAdd.monthly) }} / bln</span>
          </div>
          <div class="mm-quote-sep"></div>
          <div v-if="proratedAdd" class="mm-quote-row total">
            <span class="mm-quote-lbl">Bayar sekarang (prorata)</span>
            <span class="mm-quote-val">{{ money(proratedAdd.amount) }}</span>
          </div>
          <div v-else-if="proratedAddLoading" class="mm-quote-row total">
            <span class="mm-quote-lbl">Bayar sekarang (prorata)</span>
            <span class="mm-quote-val muted">Menghitung…</span>
          </div>
          <div v-else-if="proratedAddError" class="mm-quote-note error" role="alert">
            {{ proratedAddError }}
          </div>
        </div>

        <ul class="mm-bullet mm-bullet-tight">
          <li>Aktif otomatis begitu pembayaran diverifikasi.</li>
          <li>Bulan depan sudah ikut perpanjangan otomatis.</li>
          <li v-if="requiresLabels.length" class="x">
            Modul ini butuh <strong>{{ requiresLabels.join(', ') }}</strong> aktif — hubungi kami lewat Bantuan
            jika belum tersedia di langganan Anda.
          </li>
          <li v-else>Bisa dimatikan kapan saja lewat halaman ini.</li>
        </ul>

        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="confirmBusy" @click="closeModal">Batal</button>
          <!-- Disabled until the server quote lands, so the admin can
               never approve a figure the server did not produce. -->
          <button class="btn primary" :disabled="confirmBusy || !proratedAdd" @click="doAdd">
            <template v-if="confirmBusy">Memproses…</template>
            <template v-else-if="proratedAddLoading">Menghitung biaya…</template>
            <template v-else-if="!proratedAdd">Biaya tidak tersedia</template>
            <template v-else>
              Bayar {{ money(proratedAdd.amount) }} &amp; aktifkan
              <i class="ti ti-arrow-right" aria-hidden="true" />
            </template>
          </button>
        </div>
      </div>
    </div>

    <!-- ═════════ Modal — Ubah siklus tagihan ═════════
         Every rupiah in this dialog comes from the preview response.
         The confirm button stays disabled until that response lands,
         so the admin can never approve a number the server did not
         produce — and the commit re-runs the same action, so the
         charge matches what is on screen. -->
    <div
      v-if="lifecycleMode === 'cycle'"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-cycle-title"
      @click.self="closeLifecycleModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon add"><i class="ti ti-calendar-up" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-cycle-title" class="mm-modal-title">
              Ubah siklus tagihan ke <em>Tahunan</em>
            </div>
            <div class="mm-modal-sub">
              Sisa hari yang belum terpakai di periode bulanan Anda dihitung sebagai
              potongan dari tagihan tahunan.
            </div>
          </div>
        </div>

        <!-- Loading the quote -->
        <div v-if="!cyclePreview && !cyclePreviewError" class="mm-quote-loading">
          <div class="mm-spinner" aria-hidden="true"></div>
          <span>Menghitung tagihan…</span>
        </div>

        <!-- Quote failed — show the backend's reason verbatim -->
        <p v-else-if="cyclePreviewError" class="mm-err mm-err-inline">
          {{ cyclePreviewError }}
        </p>

        <!-- Server-computed figures -->
        <div v-else-if="cyclePreview" class="mm-quote">
          <div class="mm-quote-row">
            <span class="mm-quote-lbl">Tagihan tahunan</span>
            <span class="mm-quote-val">{{ money(cyclePreview.target_amount) }}</span>
          </div>
          <div class="mm-quote-row">
            <span class="mm-quote-lbl">
              Potongan sisa {{ cyclePreview.unused_days }} hari periode bulanan
            </span>
            <span class="mm-quote-val is-credit">
              −{{ money(cyclePreview.unused_days_credit) }}
            </span>
          </div>
          <div class="mm-quote-sep"></div>
          <div class="mm-quote-row total">
            <span class="mm-quote-lbl">Bayar sekarang</span>
            <span class="mm-quote-val">{{ money(cyclePreview.amount_due) }}</span>
          </div>
        </div>

        <ul v-if="cyclePreview" class="mm-bullet mm-bullet-tight">
          <li>
            Periode tahunan baru berlaku sampai
            <strong>{{ formatDate(cyclePreview.new_expires_at) }}</strong>.
          </li>
          <li>Semua modul aktif Anda ikut terbawa ke periode baru.</li>
          <li class="x">
            Setelah beralih, siklus tahunan tidak bisa dikembalikan ke bulanan
            di tengah periode — hanya saat perpanjangan.
          </li>
        </ul>

        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="lifecycleBusy" @click="closeLifecycleModal">
            Batal
          </button>
          <button
            class="btn primary"
            :disabled="lifecycleBusy || !cyclePreview"
            @click="doCycleChange"
          >
            <template v-if="lifecycleBusy">Memproses…</template>
            <template v-else-if="cyclePreview">
              Ya, bayar {{ money(cyclePreview.amount_due) }}
            </template>
            <template v-else>Ya, ubah siklus</template>
          </button>
        </div>
      </div>
    </div>

    <!-- ═════════ Modal — Batalkan langganan ═════════ -->
    <div
      v-if="lifecycleMode === 'cancel-sub'"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-cancelsub-title"
      @click.self="closeLifecycleModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon warn"><i class="ti ti-alert-triangle" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-cancelsub-title" class="mm-modal-title">
              Batalkan <em>seluruh langganan</em>?
            </div>
            <div class="mm-modal-sub">
              Langganan berhenti di akhir periode berjalan. Tidak ada yang dimatikan
              sekarang.
            </div>
          </div>
        </div>
        <ul class="mm-bullet">
          <li>
            Semua fitur &amp; modul tetap bisa dipakai
            <strong>sampai {{ expiresDate }}</strong>.
          </li>
          <li class="x">
            Periode ini sudah dibayar — <strong>tidak ada refund</strong>.
          </li>
          <li>
            Bisa dibatalkan kapan saja sebelum {{ expiresDate }} lewat tombol
            <strong>Lanjutkan langganan</strong> di halaman ini.
          </li>
          <li class="x">
            Setelah {{ expiresDate }} langganan tidak diperpanjang dan akses berhenti.
          </li>
        </ul>
        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="lifecycleBusy" @click="closeLifecycleModal">
            Batal, tetap berlangganan
          </button>
          <button class="btn warn" :disabled="lifecycleBusy" @click="doCancelSubscription">
            <template v-if="lifecycleBusy">Memproses…</template>
            <template v-else>Ya, hentikan di {{ expiresDate }}</template>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.mm-page {
  min-height: 100vh;
  background: #FBFCFE;
  color: #0F172A;
  font-family: var(--font-sans);
  display: flex; flex-direction: column;
}
/* Embedded in the admin shell: the shell owns the viewport height +
   background, so drop the full-height + surface here to sit naturally
   in the content column. */
.mm-page.is-embedded {
  min-height: 0;
  background: transparent;
}

/* Nav */
.mm-nav {
  background: #FFFFFF;
  padding: 14px 22px;
  border-bottom: 0.5px solid #E7ECF3;
  display: flex; align-items: center; gap: 14px;
}
.mm-logo {
  width: 30px; height: 30px; border-radius: 8px;
  background: linear-gradient(135deg, #1B6FB8 0%, #113E75 100%);
  color: #fff; display: grid; place-items: center;
  font-weight: 600; font-size: 13px;
}
.mm-brand { display: flex; flex-direction: column; }
.mm-brand-name { font-size: 13.5px; font-weight: 600; letter-spacing: -0.1px; }
.mm-brand-tag { font-size: 10.5px; color: #64748B; margin-top: 1px; }
.mm-nav-right { margin-left: auto; display: flex; align-items: center; gap: 16px; }
.mm-nav-link {
  color: #64748B; text-decoration: none;
  font-size: 12px;
  display: inline-flex; align-items: center; gap: 6px;
}
.mm-nav-link:hover { color: #1B6FB8; }

/* Loading + empty */
.mm-loading {
  flex: 1;
  display: grid; place-items: center;
  color: #64748B; font-size: 13px;
  gap: 12px;
}
.mm-spinner {
  width: 22px; height: 22px;
  border: 2px solid #E2E8F0;
  border-top-color: #1B6FB8;
  border-radius: 50%;
  animation: mm-spin 0.8s linear infinite;
}
@keyframes mm-spin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) {
  .mm-spinner { animation: none; }
}
.mm-empty {
  flex: 1;
  display: grid; place-items: center;
  padding: 32px 22px;
}
.mm-empty-card {
  max-width: 420px;
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 14px;
  padding: 28px 24px;
  text-align: center;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04), 0 8px 24px rgba(15, 23, 42, 0.06);
}
.mm-empty-h1 { font-size: 18px; font-weight: 600; letter-spacing: -0.2px; }
.mm-empty-sub { font-size: 12.5px; color: #64748B; margin: 8px 0 18px; line-height: 1.55; }

/* Hero */
.mm-hero {
  padding: 22px 24px 18px;
  background: linear-gradient(180deg, #FBFDFF 0%, #FBFCFE 100%);
  border-bottom: 0.5px solid #E7ECF3;
  display: flex; align-items: flex-start; gap: 14px;
}
.mm-hero-avatar {
  width: 44px; height: 44px; border-radius: 10px;
  background: #E6F1FB; color: #113E75;
  display: grid; place-items: center;
  font-weight: 600; font-size: 14px;
  flex-shrink: 0;
}
.mm-hero-body { flex: 1; min-width: 0; }
.mm-hero-kicker {
  font-size: 10.5px; font-weight: 600;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: #1B6FB8;
}
.mm-hero-h1 {
  font-size: 20px; font-weight: 600;
  letter-spacing: -0.3px;
  margin: 2px 0 4px;
  text-wrap: balance;
}
.mm-hero-meta {
  font-size: 12px; color: #64748B;
  display: flex; gap: 14px; flex-wrap: wrap;
}
.mm-hero-meta span:not(:first-child)::before {
  content: "·"; margin-right: 10px; color: #94A3B8;
}
.mm-hero-side {
  display: flex; flex-direction: column; align-items: flex-end; gap: 6px;
  flex-shrink: 0;
}
.mm-hero-side-sub { font-size: 10.5px; color: #94A3B8; }

/* Body layout */
.mm-body {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 320px;
  background: #fff;
  flex: 1;
}
.mm-main { padding: 22px 24px 32px; min-width: 0; }
.mm-side {
  background: #F7FAFD;
  border-left: 0.5px solid #E7ECF3;
  padding: 22px 20px 24px;
  display: flex; flex-direction: column; gap: 14px;
  position: sticky; top: 0;
  align-self: flex-start;
  max-height: 100vh; overflow: auto;
}

.mm-err {
  margin: 0 24px 12px;
  font-size: 12px; color: #B91C1C;
  padding: 10px 12px;
  border-radius: 8px;
  background: #FEE2E2;
  border: 0.5px solid #FCA5A5;
}

/* Sections */
.mm-sec + .mm-sec { margin-top: 24px; }
.mm-sec-head {
  display: flex; align-items: center; gap: 10px;
  margin: 6px 0 12px;
}
.mm-sec-lbl {
  font-size: 10.5px; font-weight: 600;
  letter-spacing: 0.7px; text-transform: uppercase;
  color: #64748B;
}
.mm-sec-count {
  background: #E7ECF3; color: #64748B;
  padding: 1px 8px; border-radius: 999px;
  font-size: 10.5px; font-weight: 600;
}
.mm-sec-hint {
  font-size: 11px; color: #94A3B8;
  margin-left: auto;
}
.mm-sec-empty {
  padding: 20px 14px;
  text-align: center;
  color: #94A3B8; font-size: 11.5px;
  border: 0.5px dashed #E7ECF3;
  border-radius: 10px;
}

/* Row-frame around each ModuleTile so the managed-mode surfaces get
   the card look (rounded border + white bg) — the tile itself is
   surface-agnostic so the caller decides how to frame it. */
:deep(.mt-row.is-managed) {
  background: #fff;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 14px 16px;
  margin-bottom: 10px;
}

/* Row CTA */
.row-cta {
  font-family: inherit;
  background: transparent; color: #64748B;
  border: 0.5px solid #E2E8F0;
  padding: 7px 12px; border-radius: 8px;
  font-size: 11.5px; font-weight: 500;
  cursor: pointer;
  display: inline-flex; align-items: center; gap: 6px;
  white-space: nowrap;
}
.row-cta:hover { color: #1B6FB8; border-color: #C7DBEF; }
.row-cta.is-danger { color: #B91C1C; border-color: #FCA5A5; }
.row-cta.is-danger:hover { background: #FEF2F2; }
.row-cta.is-add {
  background: #1B6FB8; color: #fff; border-color: #1B6FB8;
}
.row-cta.is-add:hover { background: #113E75; }
.row-cta.is-resume {
  background: #DCFCE7; color: #0F6E56;
  border-color: transparent;
}
.row-cta.is-resume:hover { background: #BBF7D0; }

/* Pills used to live here; now handled inside ModuleTile via
   :pill-label + :pill-tone. Keeping the comment as breadcrumb. */

/* Note strip inside cancelled section */
.mm-note-strip {
  background: #FEF3C7;
  border: 0.5px solid #FDE68A;
  border-radius: 10px;
  padding: 10px 12px;
  display: flex; align-items: flex-start; gap: 10px;
  font-size: 11.5px; color: #78350F;
  line-height: 1.5;
  margin-bottom: 12px;
}
.mm-note-strip i { color: #B45309; font-size: 14px; flex-shrink: 0; margin-top: 1px; }
.mm-note-strip strong { color: #78350F; font-weight: 600; }

/* Sidebar cards */
.side-card {
  background: #fff;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 14px 16px;
}
.side-kicker {
  font-size: 10px; font-weight: 600;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: #64748B;
  margin-bottom: 6px;
}
.side-title {
  font-size: 13px; font-weight: 600;
  color: #0F172A; letter-spacing: -0.1px;
}
.side-total {
  font-size: 24px; font-weight: 700;
  color: #113E75; letter-spacing: -0.5px;
  font-variant-numeric: tabular-nums;
  margin-top: 4px;
}
.side-total-sub {
  font-size: 11px; color: #64748B;
  margin-top: 4px;
  line-height: 1.4;
}
/* Discount strike-through of the pre-discount monthly total. Kept
   quiet (muted grey) so it doesn't compete with `.side-total`. */
.side-strike {
  font-size: 12px;
  color: #94A3B8;
  font-weight: 500;
  text-decoration: line-through;
  text-decoration-color: rgba(148, 163, 184, 0.7);
  font-variant-numeric: tabular-nums;
  margin-top: 2px;
}
/* Discount ribbon under the total — emerald so it echoes the
   savings language elsewhere in this view (quote box + BundleStrip). */
.side-discount {
  margin-top: 8px;
  padding: 6px 10px;
  border-radius: 8px;
  background: #ECFDF5;
  border: 0.5px solid #A7F3D0;
  color: #065F46;
  font-size: 11px;
  line-height: 1.4;
  display: flex; flex-direction: column; gap: 2px;
}
.side-discount-tag {
  display: inline-flex; align-items: center; gap: 5px;
  font-weight: 700;
  letter-spacing: 0.1px;
}
.side-discount-meta {
  color: #047857;
  font-weight: 500;
}
.side-preview { background: #F0F7FF; border-color: transparent; }
.side-preview .side-total { font-size: 20px; }
.side-delta {
  display: inline-flex; align-items: center; gap: 4px;
  background: rgba(15, 111, 86, 0.12);
  color: #0F6E56;
  padding: 3px 8px; border-radius: 6px;
  font-size: 11px; font-weight: 600;
  margin-top: 8px;
}
.side-delta i { font-size: 13px; }
.side-delta.neutral {
  background: rgba(100, 116, 139, 0.12);
  color: #475569;
}

/* Modal */
.mm-scrim {
  position: fixed; inset: 0;
  background: rgba(15, 23, 42, 0.42);
  display: grid; place-items: center;
  padding: 22px;
  z-index: 40;
}
.mm-modal {
  background: #fff;
  border: 0.5px solid #E2E8F0;
  border-radius: 14px;
  padding: 22px 22px 20px;
  max-width: 520px; width: 100%;
  box-shadow: 0 20px 60px rgba(15, 23, 42, 0.20);
}
.mm-modal-head {
  display: flex; align-items: flex-start; gap: 12px;
  margin-bottom: 14px;
}
.mm-modal-icon {
  width: 40px; height: 40px; border-radius: 10px;
  display: grid; place-items: center;
  flex-shrink: 0; font-size: 18px;
}
.mm-modal-icon.warn { background: #FEF3C7; color: #B45309; }
.mm-modal-icon.add { background: #E6F1FB; color: #1B6FB8; }
.mm-modal-icon.good { background: #DCFCE7; color: #0F6E56; }
.mm-modal-body { flex: 1; min-width: 0; }
.mm-modal-title {
  font-size: 16px; font-weight: 600; letter-spacing: -0.2px;
  text-wrap: balance;
}
.mm-modal-title em { font-style: normal; color: #1B6FB8; }
.mm-modal-icon.warn ~ .mm-modal-body .mm-modal-title em { color: #B45309; }
.mm-modal-icon.good ~ .mm-modal-body .mm-modal-title em { color: #0F6E56; }
.mm-modal-sub {
  font-size: 12.5px; color: #64748B;
  margin-top: 4px; line-height: 1.5;
}
.mm-modal-sub strong { color: #0F172A; font-weight: 500; }

.mm-bullet {
  background: #FBFCFE;
  border-radius: 10px;
  padding: 12px 14px;
  margin: 8px 0 0;
  font-size: 12px; color: #64748B;
  line-height: 1.55;
  list-style: none;
}
.mm-bullet-tight { margin-top: 12px; }
.mm-bullet li {
  padding-left: 22px;
  position: relative;
  margin: 4px 0;
}
.mm-bullet li::before {
  content: "✓"; position: absolute; left: 4px;
  color: #0F6E56; font-weight: 700;
}
.mm-bullet li.x::before { content: "×"; color: #991B1B; }
.mm-bullet strong { color: #0F172A; font-weight: 600; }

/* Quote box */
.mm-quote {
  background: #FBFCFE;
  border: 0.5px solid #E7ECF3;
  border-radius: 10px;
  padding: 12px 14px;
  margin-top: 14px;
  font-variant-numeric: tabular-nums;
}
.mm-quote-row {
  display: flex; justify-content: space-between; align-items: baseline;
  padding: 4px 0;
  font-size: 12.5px;
}
.mm-quote-lbl { color: #64748B; }
.mm-quote-val { color: #0F172A; font-weight: 500; }
.mm-quote-sep {
  height: 1px; background: #E7ECF3;
  margin: 6px -14px;
}
.mm-quote-row.total .mm-quote-lbl { color: #0F172A; font-weight: 600; }
.mm-quote-row.total .mm-quote-val { color: #113E75; font-weight: 700; font-size: 15px; }
/* While the server quote is in flight the total reads "Menghitung…" —
   muted, so it never looks like a settled figure. */
.mm-quote-val.muted { color: #64748B; font-weight: 500; font-size: 13px; }
.mm-quote-note.error {
  color: #A3231C;
  background: #FEF2F2;
  border: 1px solid #FCA5A5;
  border-radius: 8px;
  padding: 8px 10px;
  font-size: 13px;
  line-height: 1.45;
}

/* Modal footer */
.mm-modal-cta {
  display: flex; gap: 10px; margin-top: 16px;
}
.btn {
  font-family: inherit; cursor: pointer;
  padding: 9px 14px; border-radius: 8px;
  font-size: 12.5px; font-weight: 500;
  display: inline-flex; align-items: center; justify-content: center; gap: 6px;
  border: 0.5px solid transparent;
  flex: 1;
}
.btn:disabled { opacity: 0.6; cursor: not-allowed; }
.btn.ghost { background: #fff; color: #64748B; border-color: #E2E8F0; }
.btn.ghost:hover:not(:disabled) { color: #1B6FB8; border-color: #C7DBEF; }
.btn.warn { background: #B45309; color: #fff; }
.btn.warn:hover:not(:disabled) { background: #92400E; }
.btn.primary { background: #1B6FB8; color: #fff; }
.btn.primary:hover:not(:disabled) { background: #113E75; }

/* ── Siklus tagihan + status langganan ───────────────────────────
   Full-width band between the hero and the module lists. Aligned to
   the hero's 24px gutter so the card's left edge lines up with the
   heading above it. */
.mm-lifecycle { padding: 16px 24px 0; }

/* Cancel-pending banner. Deliberately louder than `.mm-note-strip`
   (the per-module warning): a solid left rule + a full amber field, so
   a tenant whose whole subscription is ending sees it the moment the
   page paints. */
.mm-cancel-banner {
  display: flex; align-items: flex-start; gap: 14px;
  background: #FEF3C7;
  border: 0.5px solid #FDE68A;
  /* Same amber field as `.mm-note-strip`; the solid rule + larger type
     is what makes it read as louder, so no new hex is introduced. */
  border-left: 3px solid #B45309;
  border-radius: 12px;
  padding: 16px 18px;
}
.mm-cancel-icon {
  width: 36px; height: 36px; border-radius: 9px;
  background: #FDE68A; color: #B45309;
  display: grid; place-items: center;
  font-size: 18px; flex-shrink: 0;
}
.mm-cancel-body { flex: 1; min-width: 0; }
.mm-cancel-title {
  font-size: 15px; font-weight: 600;
  letter-spacing: -0.2px; color: #78350F;
  margin: 0; text-wrap: balance;
}
.mm-cancel-sub {
  font-size: 12.5px; color: #92400E;
  margin: 5px 0 0; line-height: 1.55;
}
.mm-cancel-sub strong { color: #78350F; font-weight: 600; }
.mm-cancel-meta {
  font-size: 11.5px; color: #A16207;
  margin-top: 8px;
}
.mm-cancel-meta strong { color: #78350F; font-weight: 600; }
.mm-cancel-cta { flex-shrink: 0; align-self: center; }
/* `.btn` is flex:1 for the modal footer; that must not stretch it
   here, where it sits alone in a non-flex container. */
.mm-cancel-cta .btn { flex: 0 0 auto; }

/* Normal state — current cycle + cadence options. */
.mm-cycle-card {
  background: #fff;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 14px 16px;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px 18px;
  align-items: center;
}
.mm-cycle-current { min-width: 0; }
.mm-cycle-now {
  display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap;
  margin-top: 2px;
}
.mm-cycle-name {
  font-size: 16px; font-weight: 600;
  color: #113E75; letter-spacing: -0.2px;
}
.mm-cycle-amount {
  font-size: 12.5px; color: #475569; font-weight: 500;
  font-variant-numeric: tabular-nums;
}
.mm-cycle-hint { font-size: 11.5px; color: #94A3B8; margin-top: 3px; }
.mm-cycle-options {
  display: flex; flex-direction: column;
  align-items: flex-end; gap: 5px;
  text-align: right;
}
.mm-cycle-note {
  font-size: 11px; color: #94A3B8;
  line-height: 1.45; max-width: 240px;
}
.mm-cycle-foot {
  grid-column: 1 / -1;
  border-top: 0.5px solid #F1F5F9;
  padding-top: 10px;
}
/* Destructive-adjacent, so a plain text link rather than a button —
   it must not read as a peer of "Tambahkan" / "Matikan modul" in the
   lists below. */
.mm-cancel-link {
  font-family: inherit;
  background: none; border: none; padding: 0;
  font-size: 11.5px; color: #94A3B8;
  text-decoration: underline;
  text-underline-offset: 2px;
  cursor: pointer;
}
.mm-cancel-link:hover { color: #B91C1C; }
.mm-lifecycle-readonly {
  font-size: 11.5px; color: #94A3B8; line-height: 1.45;
}

/* Disabled cadence option (yearly → monthly). Shown, never hidden. */
.row-cta:disabled {
  opacity: 1;
  color: #94A3B8;
  background: #F8FAFC;
  border-color: #E2E8F0;
  cursor: not-allowed;
}
.row-cta:disabled:hover { color: #94A3B8; border-color: #E2E8F0; }

/* Hero sub-line when a cancel is pending. */
.mm-hero-side-sub.is-ending { color: #B45309; font-weight: 600; }

/* Sidebar card that replaces the renewal preview while cancelling. */
.side-ending {
  background: #FEF3C7;
  border-color: #FDE68A;
}
.side-ending .side-kicker { color: #B45309; }
.side-ending .side-title { color: #78350F; }
.side-ending-note {
  font-size: 11px; color: #92400E;
  margin-top: 6px; line-height: 1.45;
}

/* Quote-loading state inside the cycle-change modal. */
.mm-quote-loading {
  display: flex; align-items: center; gap: 10px;
  padding: 18px 14px;
  margin-top: 14px;
  border: 0.5px solid #E7ECF3;
  border-radius: 10px;
  background: #FBFCFE;
  color: #64748B; font-size: 12.5px;
}
/* Page-level error strip reused inside a modal — drop the page gutter. */
.mm-err-inline { margin: 14px 0 0; }
/* The credit line reads as money coming back, so tint it like the
   savings language used elsewhere in this view. */
.mm-quote-val.is-credit { color: #0F6E56; }

@media (max-width: 900px) {
  .mm-body { grid-template-columns: 1fr; }
  .mm-side { border-left: none; border-top: 0.5px solid #E7ECF3; position: static; max-height: none; }
}
@media (max-width: 640px) {
  .mm-cancel-banner { flex-wrap: wrap; }
  .mm-cancel-cta { width: 100%; }
  .mm-cancel-cta .btn { width: 100%; }
  .mm-cycle-card { grid-template-columns: 1fr; }
  .mm-cycle-options { align-items: flex-start; text-align: left; }
  .mm-cycle-note { max-width: none; }
}
@media (max-width: 640px) {
  .mm-row { grid-template-columns: 40px 1fr; }
  .mm-row-price { grid-column: 2 / 3; text-align: left; }
  .mm-row-action { grid-column: 2 / 3; }
}
</style>
