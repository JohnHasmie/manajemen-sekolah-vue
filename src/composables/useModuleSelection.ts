/**
 * useModuleSelection — shared module-picker engine for the subscribe
 * surfaces (SubscribeView convert flow + SubscribeNewWizardView Step 4).
 *
 * WHY THIS EXISTS: both views used to carry their own copy of the same
 * ±350 LOC selection engine (toggleModule / expandedKeys / bundle
 * benchmark / quote refresh). The exact same toggleModule bundle-explode
 * bug got fixed TWICE in one session — once per copy. This composable is
 * the single home for that logic. The wizard's implementations were the
 * canonical superset (AI-quota cleanup on uncheck, local-quote fallback
 * for anonymous callers), so everything here is lifted from the wizard
 * and the convert view's slimmer needs are expressed via options.
 *
 * Laravel analogy: think of this as a shared Action/Service class — the
 * two views keep their own "controllers" (drafts, orders, navigation)
 * and delegate all selection + pricing math here.
 */
import { computed, ref, watch, type Ref, type WatchSource } from 'vue';
import { SubscriptionBillingService } from '@/services/billing.service';
import type {
  BillingPeriod,
  ModularQuote,
  ModuleCatalog,
  PricingPlan,
} from '@/types/subscription-billing';

/**
 * AI add-on quota pricing steps. Mirrors the backend's
 * ComputeSubscriptionQuoteAction config so the local preview
 * (computeLocalQuote) and the AiQuotaStepper props stay in sync.
 */
export const aiQuotaCfg = {
  ai_recommendation: { base: 20, stepPrice: 1000, topupPrice: 120 },
  ai_material_quiz: { base: 20, stepPrice: 1000, topupPrice: 150 },
  ai_rpp: { base: 15, stepPrice: 1500, topupPrice: 200 },
} as const;

export interface UseModuleSelectionOptions {
  /** Module catalog (loaded async by the view; may start null). */
  catalog: Ref<ModuleCatalog | null>;
  /** Pricing plan — supplies yearly_discount_pct + currency for the local quote. */
  plan: Ref<PricingPlan | null>;
  /** Live seat counts (tenant counts or wizard form fields). */
  studentCount: () => number;
  staffCount: () => number;
  /** Billing period ref shared with the PricingCalculatorV2 v-model. */
  period: Ref<BillingPeriod>;
  /** Preselected module keys (wizard defaults). Empty when omitted. */
  initialKeys?: string[];
  /**
   * Gate for quote/benchmark work. When provided and false, refreshQuote
   * returns WITHOUT touching the current quote and bundleBenchmark is
   * null (convert flow: no tenant picked yet).
   */
  enabled?: () => boolean;
  /** Include `ai_quota` in the backend quote payload (wizard only). */
  withAiQuota?: boolean;
  /**
   * On backend-quote failure, fall back to computeLocalQuote (wizard:
   * POST /billing/quote 401s for anonymous visitors — without this the
   * sidebar reads "Rp 0" while modules are visibly ticked). When false,
   * failures only warn and the last good quote is kept.
   */
  localQuoteFallback?: boolean;
  /**
   * Extra reactive sources that should re-trigger the debounced quote
   * (e.g. the convert flow's selectedTenant, so switching to a tenant
   * with identical seat counts still re-fetches).
   */
  quoteDeps?: WatchSource<unknown>[];
  /** Console-warn tag, e.g. 'SubscribeView'. */
  logTag?: string;
}

export function useModuleSelection(opts: UseModuleSelectionOptions) {
  const { catalog, plan, period } = opts;
  const tag = opts.logTag ?? 'useModuleSelection';

  // ── State ────────────────────────────────────────────────────────
  const selectedKeys = ref<Set<string>>(new Set(opts.initialKeys ?? []));
  const aiQuota = ref<Record<string, number>>({});
  const quote = ref<ModularQuote | null>(null);

  // ── Derived ──────────────────────────────────────────────────────
  /**
   * Selection with bundles expanded to their members and required deps
   * (report_cards → grades) pulled in. This is what the picker
   * checkboxes actually read.
   */
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

  /** module key → labels of the deps it auto-includes (for badge copy). */
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

  /**
   * INVERSE of [autoIncluded]: dep key → labels of currently-selected
   * modules that require it. Used by the picker to render each
   * auto-included dep as disabled/read-only with a "Diperlukan oleh …"
   * hint — so users see WHY the card is pinned checked and understand
   * they have to uncheck the requirer to release it. Yahya picked this
   * UX 2026-07-08 (option "c" in the decision thread): "bikin card show
   * as disabled/read-only ketika di-auto-include, plus tooltip".
   */
  const requiredBy = computed(() => {
    const map = new Map<string, string[]>();
    const cat = catalog.value;
    if (!cat) return map;
    selectedKeys.value.forEach((k) => {
      if (k in cat.bundles) return;
      const owner = cat.optional[k];
      if (!owner) return;
      owner.requires.forEach((depKey) => {
        const bucket = map.get(depKey) ?? [];
        bucket.push(owner.label);
        map.set(depKey, bucket);
      });
    });
    return map;
  });

  /**
   * "Would bundle_complete be cheaper?" benchmark for the calculator's
   * swap-to-bundle nudge card.
   */
  const bundleBenchmark = computed(() => {
    if (opts.enabled && !opts.enabled()) return null;
    const cat = catalog.value;
    if (!cat) return null;
    const complete = cat.bundles['bundle_complete'];
    if (!complete) return null;
    const total =
      complete.price_per_student * opts.studentCount() +
      complete.price_per_staff * opts.staffCount();
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

  /** Directly-selected AI modules (drives the AiQuotaStepper list). */
  const selectedAiKeys = computed(() =>
    [...selectedKeys.value].filter((k) => catalog.value?.optional[k]?.is_ai),
  );

  // ── Actions ──────────────────────────────────────────────────────
  function toggleModule(key: string) {
    const next = new Set(selectedKeys.value);
    const cat = catalog.value;
    if (!cat) return;

    // The picker checkbox reads from `expandedKeys`, which merges bundle
    // members into the visible-selected set. So a click on a module
    // whose only source of selection is a bundle expansion needs to
    // "explode" the bundle: drop the bundle from selectedKeys, promote
    // its OTHER members to individual selections, and skip the
    // just-unchecked module. Result — the bundle chip auto-deselects,
    // sidebar switches from bundle pricing to à la carte pricing on the
    // remaining modules, and the module the user just tapped is dropped.
    const wasSelected = next.has(key) || expandedKeys.value.includes(key);

    if (wasSelected) {
      if (next.has(key)) {
        // Directly-selected module (à la carte, or a bundle key itself).
        next.delete(key);
        if (cat.optional[key]?.is_ai) delete aiQuota.value[key];
      } else {
        // Bundle-expanded selection — find the owning bundle + explode.
        for (const selKey of Array.from(next)) {
          const bundle = cat.bundles[selKey];
          if (bundle && bundle.members.includes(key)) {
            next.delete(selKey);
            bundle.members.forEach((m) => {
              if (m !== key) next.add(m);
            });
            break;
          }
        }
      }
    } else {
      // Adding a bundle wipes the à la carte members it covers so the
      // sidebar doesn't double-count them.
      if (key in cat.bundles) {
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

  // ── Quote ────────────────────────────────────────────────────────
  /**
   * Refresh the quote for the current selection. Prefers the backend
   * (authoritative — it also applies the yearly discount + any config
   * overrides), with an optional local fallback for anonymous callers
   * (see `localQuoteFallback`).
   */
  async function refreshQuote() {
    if (opts.enabled && !opts.enabled()) return;
    if (!catalog.value || selectedKeys.value.size === 0) {
      quote.value = null;
      return;
    }
    try {
      quote.value = await SubscriptionBillingService.quoteModular({
        student_count: opts.studentCount(),
        staff_count: opts.staffCount(),
        plan: period.value,
        modules: Array.from(selectedKeys.value),
        ...(opts.withAiQuota ? { ai_quota: aiQuota.value } : {}),
      });
    } catch (e) {
      if (opts.localQuoteFallback) {
        // Backend refused (usually 401 while browsing anonymously) —
        // compute locally from the catalog so the sidebar still reflects
        // the user's selection. Backend re-verifies at subscribe time.
        console.warn(
          `[${tag}.refreshQuote] falling back to local compute:`,
          (e as Error).message,
        );
        quote.value = computeLocalQuote();
      } else {
        console.warn(`[${tag}.refreshQuote]`, (e as Error).message);
      }
    }
  }

  /**
   * Client-side mirror of ComputeSubscriptionQuoteAction::executeWithModules().
   * Uses the module catalog prices we already loaded from GET /billing/plans
   * + /modules/catalog. Yearly discount comes from `plan.yearly_discount_pct`.
   */
  function computeLocalQuote(): ModularQuote | null {
    const cat = catalog.value;
    if (!cat) return null;
    const studentCount = opts.studentCount();
    const staffCount = opts.staffCount();
    const selected = Array.from(selectedKeys.value);
    const bundleKeys = selected.filter((k) => k in cat.bundles);
    const bundleMemberCoverage = new Set<string>();
    bundleKeys.forEach((bk) => cat.bundles[bk]?.members.forEach((m) => bundleMemberCoverage.add(m)));
    const optionalKeys = selected.filter(
      (k) => !(k in cat.bundles) && k in cat.optional && !bundleMemberCoverage.has(k),
    );

    // Also pull in required deps (report_cards → grades) so the calc
    // matches backend when a require is auto-included.
    const withRequires = new Set(optionalKeys);
    optionalKeys.forEach((k) => cat.optional[k]?.requires.forEach((r) => withRequires.add(r)));

    const perModule: { key: string; price_per_student: number; price_per_staff: number; monthly_line: number }[] = [];
    let monthly = 0;

    for (const bk of bundleKeys) {
      const b = cat.bundles[bk];
      if (!b) continue;
      const line = b.price_per_student * studentCount + b.price_per_staff * staffCount;
      perModule.push({
        key: bk,
        price_per_student: b.price_per_student,
        price_per_staff: b.price_per_staff,
        monthly_line: line,
      });
      monthly += line;
    }
    for (const k of withRequires) {
      const it = cat.optional[k];
      if (!it) continue;
      const line = it.price_per_student * studentCount + it.price_per_staff * staffCount;
      perModule.push({
        key: k,
        price_per_student: it.price_per_student,
        price_per_staff: it.price_per_staff,
        monthly_line: line,
      });
      monthly += line;
    }

    // AI quota extras — must mirror what backend adds in
    // ComputeSubscriptionQuoteAction so the local preview matches
    // when the user bumps a stepper.
    const aiLines: { key: string; extra_generates: number; monthly_line: number }[] = [];
    for (const [k, extra] of Object.entries(aiQuota.value)) {
      if (!extra) continue;
      const cfg = aiQuotaCfg[k as keyof typeof aiQuotaCfg];
      if (!cfg) continue;
      const steps = Math.ceil(extra / 10);
      const line = steps * cfg.stepPrice * staffCount;
      aiLines.push({ key: k, extra_generates: extra, monthly_line: line });
      monthly += line;
    }

    const discountPct = plan.value?.yearly_discount_pct ?? 20;
    const yearlyGross = monthly * 12;
    const yearlySavings = Math.round((yearlyGross * discountPct) / 100);
    const yearlyAmount = yearlyGross - yearlySavings;
    const chosen = period.value === 'yearly' ? yearlyAmount : monthly;

    return {
      selected_keys: selected,
      expanded_modules: [...bundleMemberCoverage, ...withRequires],
      student_count: studentCount,
      staff_count: staffCount,
      per_module: perModule,
      ai_quota_lines: aiLines,
      monthly_amount: monthly,
      yearly_gross: yearlyGross,
      yearly_amount: yearlyAmount,
      yearly_savings: yearlySavings,
      chosen_amount: chosen,
      chosen_plan: period.value,
      currency: plan.value?.currency ?? 'IDR',
    };
  }

  // Debounced re-quote on any selection/pricing input change. Seat
  // counts are watched via the option getters; callers add extra
  // sources (e.g. selectedTenant) through `quoteDeps`.
  let quoteDebounce: number | null = null;
  watch(
    [
      selectedKeys,
      aiQuota,
      period,
      opts.studentCount,
      opts.staffCount,
      ...(opts.quoteDeps ?? []),
    ],
    () => {
      if (quoteDebounce !== null) window.clearTimeout(quoteDebounce);
      quoteDebounce = window.setTimeout(refreshQuote, 250) as unknown as number;
    },
    { deep: true },
  );

  return {
    // state (writable refs — the wizard's draft restore + tenant-type
    // purge watcher assign to these directly)
    selectedKeys,
    aiQuota,
    quote,
    // derived
    expandedKeys,
    autoIncluded,
    requiredBy,
    bundleBenchmark,
    selectedAiKeys,
    // actions
    toggleModule,
    switchToBundle,
    onAiQuotaUpdate,
    refreshQuote,
    buildPlanLabel,
  };
}
