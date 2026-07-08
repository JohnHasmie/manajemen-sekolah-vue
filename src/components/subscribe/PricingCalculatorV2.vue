<!--
  PricingCalculatorV2.vue — sticky sidebar calculator for the redesigned
  subscribe surface. Matches mockup 1 (wizard) + mockup 2 (nudge state)
  cleanly by taking a fully-computed quote from the parent and rendering
  it.

  Parent owns the modular quote fetch — this component is dumb by
  design so the same widget renders correctly in the wizard step AND
  the /subscribe conversion flow.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type {
  AppliedDiscount,
  BillingPeriod,
  DiscountPreviewFailure,
  ModularQuote,
  ModuleCatalog,
} from '@/types/subscription-billing';
import { money, moduleLabel } from './moduleTokens';
import { tenantLabel } from '@/lib/tenantTokens';
import DiscountCodeInput from './DiscountCodeInput.vue';
import DiscountAppliedCard from './DiscountAppliedCard.vue';

const props = defineProps<{
  tenantName: string;
  studentCount: number;
  staffCount: number;
  plan: BillingPeriod;
  quote: ModularQuote | null;
  catalog: ModuleCatalog | null;
  submitting?: boolean;
  submitLabel?: string;
  yearlyDiscountPct?: number;
  /** Show the "Bulanan" / "Tahunan" toggle in the header. */
  showPlanToggle?: boolean;
  /** Tenant type — swaps siswa/peserta + guru/tutor in labels + hint. */
  tenantType?: 'sekolah' | 'bimbel' | null;
  /**
   * When set, we compare per-module total to this value. If ≥, render
   * BundleNudge to help the user save.
   */
  bundleBenchmark?: {
    key: string;
    label: string;
    monthlyTotal: number;
    bonusModuleCount: number;
  } | null;
  // ── Discount code slot ─────────────────────────────────────────
  // Parent owns the wiring: input v-model, apply/remove events,
  // async state. This component just renders + emits.
  discountCode?: string;
  discountApplying?: boolean;
  discountError?: DiscountPreviewFailure | null;
  appliedDiscount?: AppliedDiscount | null;
}>();

const emit = defineEmits<{
  'update:plan': [plan: BillingPeriod];
  submit: [];
  'switch-to-bundle': [key: string];
  'update:discountCode': [value: string];
  'apply-discount': [code: string];
  'remove-discount': [];
}>();

const discountPct = computed(() => props.yearlyDiscountPct ?? 20);
const lines = computed(() => props.quote?.per_module ?? []);
const aiLines = computed(() => props.quote?.ai_quota_lines ?? []);

// ── Discount amounts ─────────────────────────────────────────────
// For the CURRENTLY-CHOSEN plan (monthly/yearly), compute how much
// the discount reduces the sidebar Total row. Discount is a MONTHLY
// value from the backend (`discount_amount`); we apply it for
// `duration_months` months and honour the plan choice:
//
//   • Monthly plan → show the reduced monthly for the first N months.
//     Post-window, price reverts to the honest monthly amount.
//   • Yearly plan  → savings = min(N, 12) × discount_amount over the
//     first year; the pre-paid yearly total is reduced by that much
//     for the first billing cycle.
const discountedMonthlySavings = computed(() => {
  const d = props.appliedDiscount;
  if (!d) return 0;
  return d.discount_amount;
});

const discountedTotalReduction = computed(() => {
  const d = props.appliedDiscount;
  if (!d) return 0;
  const monthly = d.discount_amount;
  if (props.plan === 'monthly') return monthly;
  // Yearly plan: apply across N months of the first year (max 12).
  const months = d.duration_months === null
    ? 12
    : Math.min(d.duration_months, 12);
  return monthly * months;
});

const chosenAmountAfterDiscount = computed(() => {
  const raw = props.quote?.chosen_amount ?? 0;
  return Math.max(0, raw - discountedTotalReduction.value);
});

function labelFor(key: string): string {
  const optional = props.catalog?.optional[key];
  if (optional) return moduleLabel(optional, props.tenantType);
  return props.catalog?.bundles[key]?.label ?? key;
}

const perUnitWord = computed(() => tenantLabel('student', props.tenantType));
const staffWord = computed(() => tenantLabel('teacher', props.tenantType));

/**
 * Human-readable "how did we get this number" breakdown for a per-module
 * quote line. Renders "500 siswa × Rp 2.000 + 10 guru × Rp 2.500" when
 * both seat types contribute; drops the zero-priced side so a per-guru
 * module doesn't say "+ 500 siswa × Rp 0" (confusing).
 *
 * Without this, the sidebar collapses each module to just its total
 * (Rp 25.000) and users assume the staff seats weren't counted — this
 * exposes the arithmetic explicitly.
 */
function breakdownFor(l: {
  key: string;
  price_per_student?: number;
  price_per_staff?: number;
}): string {
  const parts: string[] = [];
  const ps = Number(l.price_per_student ?? 0);
  const pt = Number(l.price_per_staff ?? 0);
  if (ps > 0) parts.push(`${props.studentCount} ${perUnitWord.value} × ${money(ps)}`);
  if (pt > 0) parts.push(`${props.staffCount} ${staffWord.value} × ${money(pt)}`);
  return parts.join(' + ');
}

const monthlyAmount = computed(() => props.quote?.monthly_amount ?? 0);
const chosenAmount = computed(() => props.quote?.chosen_amount ?? 0);

// Flash the total price for ~500 ms whenever it changes so the user
// can SEE that their checkbox click landed. Without this, the sidebar
// updates silently — the number moves but there's no visual anchor
// tying the interaction to the price change, and users clicked twice.
// `respects prefers-reduced-motion` because the animation is opt-out
// via a media query in the CSS.
const priceFlashing = ref(false);
let flashTimer: ReturnType<typeof setTimeout> | null = null;
watch(chosenAmount, (next, prev) => {
  if (next === prev) return;
  if (flashTimer !== null) clearTimeout(flashTimer);
  priceFlashing.value = true;
  flashTimer = setTimeout(() => {
    priceFlashing.value = false;
    flashTimer = null;
  }, 550);
});

const perStudent = computed(() => {
  const total = monthlyAmount.value;
  const denom = props.studentCount;
  if (!denom) return 0;
  return Math.round(total / denom);
});

/**
 * Honest per-unit breakdown for the little grey line under the big
 * total. Previously "≈ Rp 7.600 per siswa / bln" (monthly / studentCount)
 * — which hid the guru contribution AND misled anyone doing back-of-envelope
 * arithmetic. Now we spell out both components when both contribute so
 * the number can be verified by hand. Falls back to the old per-siswa
 * shorthand when the quote has ONLY a student component (rare but
 * possible for e.g. a students-only add-on).
 */
const perUnitBreakdown = computed<string>(() => {
  const q = props.quote;
  if (!q || !q.per_module?.length) return '';
  let studentContrib = 0;
  let staffContrib = 0;
  for (const l of q.per_module) {
    studentContrib += (l.price_per_student ?? 0) * props.studentCount;
    staffContrib += (l.price_per_staff ?? 0) * props.staffCount;
  }
  const aiTotal = (q.ai_quota_lines ?? []).reduce(
    (sum, ai) => sum + Number(ai.monthly_line ?? 0),
    0,
  );
  const parts: string[] = [];
  if (studentContrib > 0) {
    parts.push(
      `${props.studentCount} ${perUnitWord.value} × ${money(
        Math.round(studentContrib / Math.max(1, props.studentCount)),
      )}`,
    );
  }
  if (staffContrib > 0) {
    parts.push(
      `${props.staffCount} ${staffWord.value} × ${money(
        Math.round(staffContrib / Math.max(1, props.staffCount)),
      )}`,
    );
  }
  if (!parts.length) return '';
  const base = `= ${parts.join(' + ')}`;
  if (aiTotal > 0) return `${base} + AI ${money(aiTotal)}`;
  return base;
});

const alreadyOnBundle = computed<boolean>(() => {
  const b = props.bundleBenchmark;
  if (!b || !props.quote) return false;
  return props.quote.selected_keys.includes(b.key);
});

const showNudge = computed(() => {
  const b = props.bundleBenchmark;
  if (!b) return false;
  return !alreadyOnBundle.value && monthlyAmount.value >= b.monthlyTotal;
});

/**
 * When the user IS on the bundle, they can't see the savings the
 * bundle bought them because the à la carte alternative is invisible.
 * Compute what those same modules would cost if bought individually
 * and expose the delta as "Hemat Rp X pakai Paket Lengkap" under the
 * total. Fires on mount because it's a pure computed off the catalog
 * + form counts + selected bundle — no extra network call needed.
 *
 * Only surfaces when:
 *   - a bundle is actually selected (alreadyOnBundle),
 *   - the bundle exists in the catalog (defensive),
 *   - the à la carte equivalent is strictly greater (defensive: if
 *     the owner retunes rates so bundle costs MORE, we don't lie
 *     about savings).
 */
const bundleSavings = computed<{
  bundleKey: string;
  bundleLabel: string;
  alaCarteAmount: number;
  bundleAmount: number;
  savings: number;
} | null>(() => {
  if (!alreadyOnBundle.value) return null;
  const cat = props.catalog;
  if (!cat) return null;

  // Find the selected bundle key + its catalog entry.
  const bundleKey = props.quote?.selected_keys.find((k) => k in cat.bundles);
  if (!bundleKey) return null;
  const bundle = cat.bundles[bundleKey];
  if (!bundle) return null;

  // Sum the bundle's member modules at à la carte rates.
  let alaCarte = 0;
  for (const m of bundle.members) {
    const item = cat.optional[m];
    if (!item) continue;
    alaCarte += item.price_per_student * props.studentCount
      + item.price_per_staff * props.staffCount;
  }
  const bundleAmount = bundle.price_per_student * props.studentCount
    + bundle.price_per_staff * props.staffCount;
  const savings = alaCarte - bundleAmount;
  if (savings <= 0) return null;

  return {
    bundleKey,
    bundleLabel: bundle.label,
    alaCarteAmount: alaCarte,
    bundleAmount,
    savings,
  };
});

/**
 * Scale monthly savings into the period the user is actually viewing.
 * `bundleSavings.savings` is per-month (catalog rates × seat counts).
 * `chosenAmount` is per-period (yearly with discount when plan=yearly).
 * Ratio (chosen / monthly) lets us surface the strike + pill in the
 * SAME denomination as the big total number — no mixed-currency-math
 * flash where "hemat Rp 290k" sits next to a Rp 11jt yearly total.
 */
const savingsForPeriod = computed<number>(() => {
  const bs = bundleSavings.value;
  if (!bs) return 0;
  if (!monthlyAmount.value) return bs.savings;
  const ratio = chosenAmount.value / monthlyAmount.value;
  return Math.round(bs.savings * ratio);
});

const alaCarteEquivalent = computed<number>(() =>
  chosenAmount.value + savingsForPeriod.value,
);

function onPlan(p: BillingPeriod) {
  emit('update:plan', p);
}
</script>

<template>
  <div class="pc-calc">
    <!-- Header now spells out capacity as pills instead of the cryptic
         "10/4" shorthand. Two pills so the eye lands on siswa + guru
         separately, and each carries its own icon so a screen-reader
         (or user) never has to guess which side is which. -->
    <div class="pc-calc-head">
      <div class="pc-calc-kicker">Ringkasan Langganan</div>
      <div class="pc-calc-title">{{ tenantName }}</div>
      <div class="pc-calc-caps">
        <span class="pc-cap-pill">
          <svg width="12" height="12" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M10 4a3 3 0 100 6 3 3 0 000-6zM4 16c0-3 2.5-5 6-5s6 2 6 5v1H4v-1z" />
          </svg>
          <b>{{ studentCount }}</b> {{ perUnitWord }}
        </span>
        <span class="pc-cap-pill">
          <svg width="12" height="12" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <rect x="4" y="6" width="12" height="10" rx="2" />
            <path d="M8 4h4v2H8z" />
          </svg>
          <b>{{ staffCount }}</b> {{ staffWord }} &amp; staf
        </span>
      </div>
    </div>

    <div v-if="showPlanToggle !== false" class="pc-plan-toggle">
      <button
        type="button"
        class="pc-plan-opt"
        :class="{ 'is-on': plan === 'monthly' }"
        @click="onPlan('monthly')"
      >Bulanan</button>
      <button
        type="button"
        class="pc-plan-opt"
        :class="{ 'is-on': plan === 'yearly' }"
        @click="onPlan('yearly')"
      >
        Tahunan
        <span class="save">hemat {{ discountPct }}%</span>
      </button>
    </div>

    <div class="pc-lines" v-if="lines.length">
      <div v-for="l in lines" :key="l.key" class="pc-line">
        <div class="pc-line-body">
          <div class="pc-line-lbl">{{ labelFor(l.key) }}</div>
          <div class="pc-line-sub">{{ breakdownFor(l) }}</div>
        </div>
        <span class="pc-line-val">{{ money(l.monthly_line) }}</span>
      </div>
      <div v-for="ai in aiLines" :key="`ai-${ai.key}`" class="pc-line">
        <div class="pc-line-body">
          <div class="pc-line-lbl">{{ labelFor(ai.key) }}</div>
          <div class="pc-line-sub">
            kuota +{{ ai.extra_generates }} / {{ staffWord }} / bln
          </div>
        </div>
        <span class="pc-line-val">{{ money(ai.monthly_line) }}</span>
      </div>

      <!-- Discount line — nyisip di antara module lines dan total.
           Hanya render kalau ada applied discount. Green-ink; hemat
           terlihat langsung. Duration-months hint biar user paham
           discount cuma buat N bulan pertama. -->
      <div v-if="appliedDiscount" class="pc-line pc-line-discount">
        <div class="pc-line-body">
          <div class="pc-line-lbl">
            Diskon {{ appliedDiscount.code }}
            <span v-if="appliedDiscount.type === 'percent'" class="pc-line-disc-pct">
              −{{ appliedDiscount.value }}%
            </span>
          </div>
          <div class="pc-line-sub">
            {{ appliedDiscount.duration_months === null
              ? 'Berlaku seumur langganan'
              : `${appliedDiscount.duration_months} bulan pertama` }}
          </div>
        </div>
        <span class="pc-line-val pc-line-val-neg">
          − {{ money(discountedMonthlySavings) }}<span class="pc-line-val-mo">/bln</span>
        </span>
      </div>
    </div>
    <div v-else class="pc-empty">
      Belum ada modul dipilih.
    </div>

    <!-- Total block. Three states:
         (a) Plain — no bundle selected, no bundle nudge fires. Label +
             big number and per-year hint.
         (b) On-bundle compare-anchored — a bundle IS selected AND its
             members would cost strictly more à la carte. Show the
             hypothetical à la carte row as a struck-through
             comparison, then the bundle price wins as the emerald
             final. Bottom-of-block emerald HEMAT strip surfaces the
             per-year delta because that's the number that
             actually moves the needle on cost decisions.
         (c) Off-bundle nudge — user picked à la carte but their total
             met/exceeded the bundle price. Big number stays at their
             honest à la carte total, and a compact emerald swap
             card appears BELOW it with an "Ambil" button to switch.
             Same visual family as case (b) but semantics reversed:
             here the bundle is the OPPORTUNITY, not the current state.
    -->
    <div class="pc-total" :class="{ 'is-bundle': !!bundleSavings }">
      <div class="pc-total-lbl">
        Total per {{ plan === 'yearly' ? 'tahun' : 'bulan' }}
      </div>

      <!-- Compare row: "Kalau beli terpisah" struck-through above the
           final number. Only in on-bundle mode. -->
      <div v-if="bundleSavings" class="pc-total-strike-row">
        <span class="pc-total-strike-lbl">Kalau beli terpisah</span>
        <span class="pc-total-strike-val">{{ money(alaCarteEquivalent) }}</span>
      </div>

      <!-- Big price row. Bundle label appears in emerald ink to the
           left when on-bundle; otherwise the price stands alone. -->
      <div class="pc-total-final-row">
        <div v-if="bundleSavings" class="pc-total-final-lbl">
          <svg width="12" height="12" viewBox="0 0 16 16" fill="none" aria-hidden="true">
            <path d="M3 8.5l3.5 3.5L13 4.5" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
          {{ bundleSavings.bundleLabel }}
        </div>
        <div
          class="pc-total-val"
          :class="{ 'pc-total-val--flash': priceFlashing, 'pc-total-val--strike': !!appliedDiscount }"
        >{{ money(chosenAmount) }}</div>
      </div>

      <!-- Discounted final row — only when a code is applied. The
           original chosenAmount above gets a strikethrough class,
           and the effective post-discount amount lands here in a
           green-ink "after" row so the user sees exactly what they
           are being charged this cycle. -->
      <div v-if="appliedDiscount" class="pc-total-final-row pc-total-final-row-after">
        <div class="pc-total-after-lbl">Setelah diskon</div>
        <div class="pc-total-val pc-total-val-after">{{ money(chosenAmountAfterDiscount) }}</div>
      </div>

      <!-- Honest per-unit breakdown replaces the misleading "per siswa"
           divide that mixed guru + siswa costs into one number. This
           says "your Rp 76.000 is Rp 6.000 × 10 siswa + Rp 4.000 × 4
           guru", which the user can verify by hand. -->
      <div v-if="perUnitBreakdown" class="pc-total-per">
        {{ perUnitBreakdown }}
      </div>

      <!-- Emerald HEMAT strip. Ships whenever savings exist (on-bundle).
           Amount rendered big + white on emerald so it reads as a
           standalone signal, and the small line under it shows the
           per-year projection which is what people compare against
           other tools' pricing. -->
      <div v-if="bundleSavings" class="pc-total-hemat">
        <div class="pc-total-hemat-icon">
          <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
            <path d="M8 1l2 5 5 .5-4 3.5 1 5.5-4-2.5-4 2.5 1-5.5-4-3.5 5-.5z" />
          </svg>
        </div>
        <div class="pc-total-hemat-body">
          <div class="pc-total-hemat-main">
            Anda hemat
            <b>{{ money(savingsForPeriod) }}/{{ plan === 'yearly' ? 'thn' : 'bln' }}</b>
            pakai {{ bundleSavings.bundleLabel }}
          </div>
          <div v-if="plan !== 'yearly'" class="pc-total-hemat-sub">
            Setara <b>{{ money(savingsForPeriod * 12) }}/tahun</b>
          </div>
        </div>
      </div>

      <!-- Off-bundle swap card. When user's à la carte pick meets or
           exceeds the bundle price, present the switch option here
           (before CTA) instead of a separate below-CTA nudge card. -->
      <div v-if="showNudge && bundleBenchmark" class="pc-total-swap">
        <div class="pc-total-swap-body">
          <div class="pc-total-swap-top">
            <svg width="12" height="12" viewBox="0 0 16 16" fill="none" aria-hidden="true">
              <path d="M3 8.5l3.5 3.5L13 4.5" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            <span class="pc-total-swap-title">{{ bundleBenchmark.label }} lebih hemat</span>
            <span class="pc-total-swap-hemat">
              −{{ money(monthlyAmount - bundleBenchmark.monthlyTotal) }}
            </span>
          </div>
          <div class="pc-total-swap-sub">
            <span>{{ money(bundleBenchmark.monthlyTotal) }}/bln</span>
            <span v-if="bundleBenchmark.bonusModuleCount > 0" class="pc-total-swap-bonus">
              · {{ bundleBenchmark.bonusModuleCount }} modul bonus
            </span>
          </div>
        </div>
        <button
          type="button"
          class="pc-total-swap-btn"
          @click="emit('switch-to-bundle', bundleBenchmark.key)"
        >
          Ambil
        </button>
      </div>
    </div>

    <!-- Discount code slot — sits between the total block and the CTA,
         matching the approved mockup. When a discount is applied, the
         green DiscountAppliedCard renders here with description, meta,
         and a remove ✕. Otherwise the 4-state DiscountCodeInput lets
         the user paste a code and press Terapkan. Parent (Subscribe
         wizard) owns the state via v-model:discountCode + the
         apply-discount / remove-discount events. -->
    <div class="pc-discount-slot">
      <DiscountAppliedCard
        v-if="appliedDiscount"
        :discount="appliedDiscount"
        @remove="emit('remove-discount')"
      />
      <DiscountCodeInput
        v-else
        :model-value="discountCode ?? ''"
        :applying="!!discountApplying"
        :error="discountError ?? null"
        @update:model-value="v => emit('update:discountCode', v)"
        @apply="c => emit('apply-discount', c)"
      />
    </div>

    <div class="pc-cta">
      <button
        type="button"
        class="pc-cta-btn"
        :disabled="submitting || chosenAmount === 0"
        @click="emit('submit')"
      >
        <template v-if="submitting">Memproses…</template>
        <template v-else>
          {{ submitLabel ?? 'Lanjut ke pembayaran' }}
          <i class="ti ti-arrow-right" aria-hidden="true" />
        </template>
      </button>
      <div class="pc-cta-back">Ubah kapan saja · tanpa biaya batal</div>
    </div>

    <!-- Legacy BundleNudge below CTA — kept as a fallback slot so any
         host that skipped adopting the inline swap card still has the
         old prompt. Never renders while the inline card is showing to
         avoid a double-prompt. -->
  </div>
</template>

<style scoped>
.pc-calc {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04),
              0 4px 12px rgba(15, 23, 42, 0.04);
  position: sticky; top: 12px;
}
.pc-calc-head {
  padding: 12px 14px;
  border-bottom: 0.5px solid #F1F5F9;
}
.pc-calc-kicker {
  font-size: 10px; font-weight: 600;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: #64748B;
}
.pc-calc-title {
  font-size: 15px; font-weight: 700; margin-top: 3px; color: #0B1B2B;
  letter-spacing: -0.2px;
}
.pc-calc-caps {
  display: flex; gap: 6px; align-items: center;
  margin-top: 6px; flex-wrap: wrap;
}
.pc-cap-pill {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 3px 8px; border-radius: 6px;
  background: #F1F5F9;
  color: #334155;
  font-size: 11px; font-weight: 500;
  font-variant-numeric: tabular-nums;
}
.pc-cap-pill svg { color: #64748B; }
.pc-cap-pill b { font-weight: 700; color: #0B1B2B; }

.pc-plan-toggle {
  display: flex; padding: 4px;
  background: #F5F8FC;
  margin: 12px 14px 4px;
  border-radius: 8px; gap: 3px;
}
.pc-plan-opt {
  flex: 1; padding: 7px 8px;
  text-align: center;
  font-size: 11.5px; font-weight: 500;
  color: #64748B; border-radius: 6px;
  cursor: pointer;
  background: transparent; border: none;
}
.pc-plan-opt.is-on {
  background: #FFFFFF; color: #0F172A;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.08);
}
.pc-plan-opt .save {
  display: block;
  font-size: 9.5px; color: #0F6E56;
  font-weight: 500; margin-top: 1px;
}

/* Cap the line list at ~5 rows so 13+-module bundles don't push the
   Total + CTA off-screen. Overflow scrolls INSIDE this section
   (visible scrollbar on hover), while the Total block + emerald
   hemat strip + CTA stay pinned below — the user always sees what
   they'll pay and the button that submits it. */
.pc-lines {
  padding: 10px 14px;
  max-height: 260px;
  overflow-y: auto;
  scrollbar-width: thin;
  scrollbar-color: #CBD5E1 transparent;
}
.pc-lines::-webkit-scrollbar { width: 6px; }
.pc-lines::-webkit-scrollbar-thumb {
  background: #CBD5E1; border-radius: 3px;
}
.pc-lines::-webkit-scrollbar-track { background: transparent; }
.pc-line {
  display: flex; justify-content: space-between;
  align-items: flex-start;
  gap: 8px;
  padding: 6px 0; font-size: 11.5px;
}
.pc-line + .pc-line { border-top: 0.5px solid #F1F5F9; padding-top: 8px; }
.pc-line-body { min-width: 0; flex: 1; }
.pc-line-lbl { color: #0F172A; font-weight: 500; }
.pc-line-sub {
  font-size: 10.5px; color: #64748B;
  margin-top: 2px;
  font-variant-numeric: tabular-nums;
  line-height: 1.4;
}
.pc-line-val {
  font-weight: 600; color: #0F172A;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  flex-shrink: 0;
}

.pc-empty {
  padding: 20px 14px;
  text-align: center;
  color: #94A3B8; font-size: 11.5px;
  border-top: 0.5px dashed #E7ECF3;
  border-bottom: 0.5px dashed #E7ECF3;
  margin: 6px 14px;
}

.pc-total {
  padding: 12px 14px;
  background: linear-gradient(180deg, #FBFDFF 0%, #F0F7FF 100%);
  border-top: 0.5px solid #E7ECF3;
}
.pc-total-lbl {
  font-size: 11px; color: #64748B;
  text-transform: uppercase; letter-spacing: 0.4px;
  font-weight: 500;
}
.pc-total-val {
  font-size: 24px; font-weight: 600;
  letter-spacing: -0.5px; color: #113E75;
  margin-top: 3px;
  font-variant-numeric: tabular-nums;
  line-height: 1.05;
  /* Base transform so the flash keyframe can scale relative to it. */
  transform: translateZ(0);
}
/* One-shot pulse fired for ~500 ms whenever the amount changes so the
   user has a clear anchor tying their click to the price. Same
   brand-blue base colour temporarily brightens + scales a hair, then
   settles. Guarded by prefers-reduced-motion so a11y-mode users don't
   get the animation. */
.pc-total-val--flash {
  animation: pc-price-flash 500ms ease-out;
}
@keyframes pc-price-flash {
  0%   { transform: scale(1);    color: #113E75; }
  35%  { transform: scale(1.06); color: #2563EB; }
  100% { transform: scale(1);    color: #113E75; }
}
@media (prefers-reduced-motion: reduce) {
  .pc-total-val--flash { animation: none; }
}
.pc-total-per {
  font-size: 11px; color: #64748B;
  margin-top: 4px;
  font-variant-numeric: tabular-nums;
  line-height: 1.4;
}

/* Discount-applied styling — big total gets a strikethrough treatment
   in muted ink, and the row below shows the post-discount amount in
   emerald green so the user's eye jumps to what they actually pay. */
.pc-total-val--strike {
  text-decoration: line-through;
  text-decoration-thickness: 2px;
  color: #94A3B8;
  font-size: 18px;
  animation: none;
}
.pc-total-final-row-after {
  margin-top: 6px;
  align-items: baseline;
}
.pc-total-after-lbl {
  font-size: 10.5px; font-weight: 700;
  color: #15803D; letter-spacing: 0.3px;
  text-transform: uppercase;
}
.pc-total-val-after {
  font-size: 24px; font-weight: 700;
  color: #15803D;
  letter-spacing: -0.5px;
  font-variant-numeric: tabular-nums;
  margin-top: 0;
}

/* Discount line row — sits inside pc-lines above the total. Green ink
   marks a savings row without collapsing into the neutral module
   rows. Negative amount rendered with an explicit minus glyph. */
.pc-line-discount .pc-line-lbl {
  color: #166534;
  display: inline-flex; align-items: center; gap: 6px;
}
.pc-line-disc-pct {
  font-size: 10px; font-weight: 800;
  color: #15803D;
  background: #DCFCE7;
  padding: 2px 5px; border-radius: 4px;
  letter-spacing: 0.3px;
}
.pc-line-val-neg {
  color: #15803D;
  font-weight: 800;
}
.pc-line-val-mo {
  font-size: 10px; font-weight: 600;
  color: #16A34A; letter-spacing: 0;
  margin-left: 2px;
}

/* Discount slot — wraps DiscountCodeInput or DiscountAppliedCard.
   Sits between total block and CTA with matching side-padding. */
.pc-discount-slot {
  padding: 0 14px;
}

/* Bundle-mode overrides. Emerald tint anchors the whole block as
   "you saved here" without changing the ink of the big number
   itself — we want the price to stay #113E75 like every other
   total in the app, only the framing changes. */
.pc-total.is-bundle {
  background: linear-gradient(180deg, #F0FDF6 0%, #E8FAF0 100%);
  border-top: 0.5px solid #C6ECDA;
}

/* Strike row = "kalau beli terpisah Rp 1.220.000". Sits between
   the label and the final number so the eye reads top-to-bottom:
   old price → new price → savings badge. */
.pc-total-strike-row {
  display: flex; justify-content: space-between; align-items: baseline;
  gap: 8px;
  margin-top: 6px;
}
.pc-total-strike-lbl {
  font-size: 11px; color: #64748B; font-weight: 500;
  text-transform: none; letter-spacing: 0;
}
.pc-total-strike-val {
  font-size: 12.5px;
  color: #64748B;
  text-decoration: line-through;
  text-decoration-color: rgba(100, 116, 139, 0.5);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

/* Final row wraps the big price. In non-bundle mode it's the
   price alone (flex-end via justify-end so nothing looks
   asymmetric). In bundle mode it gains a green label with a
   check icon on the left. */
.pc-total-final-row {
  display: flex; justify-content: space-between; align-items: baseline;
  gap: 10px;
  margin-top: 2px;
}
.pc-total:not(.is-bundle) .pc-total-final-row { justify-content: flex-start; }
.pc-total-final-lbl {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 11.5px; font-weight: 600;
  color: #0A5744;
  letter-spacing: -0.1px;
  min-width: 0;
}
.pc-total-final-lbl svg { color: #1D9E75; flex-shrink: 0; }

/* Emerald HEMAT strip — Opsi A treatment. Solid emerald background
   with amount as an eye-catching bold + a per-year projection
   underneath. Sits BELOW the honest per-unit breakdown so the flow
   reads: total → how it's computed → what you saved. */
.pc-total-hemat {
  margin-top: 10px;
  display: flex; align-items: flex-start; gap: 9px;
  padding: 10px 11px;
  border-radius: 10px;
  background: #0F6E56;
  color: #FFFFFF;
  font-size: 12px;
  letter-spacing: -0.1px;
  line-height: 1.35;
}
.pc-total-hemat-icon {
  width: 24px; height: 24px; border-radius: 7px;
  background: rgba(255, 255, 255, 0.16);
  color: #FFFFFF;
  display: grid; place-items: center;
  flex-shrink: 0;
}
.pc-total-hemat-body { flex: 1; min-width: 0; }
.pc-total-hemat-main {
  font-weight: 500;
}
.pc-total-hemat-main b {
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.pc-total-hemat-sub {
  margin-top: 2px;
  font-size: 10.5px;
  color: rgba(255, 255, 255, 0.78);
  font-weight: 400;
}
.pc-total-hemat-sub b {
  color: #FFFFFF;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

/* Bundle-swap card for the OFF-bundle nudge case. Emerald tint,
   sits below the honest per-siswa hint but still inside the Total
   block so it catches the eye at the exact moment before the CTA.
   Compact single-row layout: title + hemat chip on top, price hint
   underneath, "Ambil" button on the right. */
.pc-total-swap {
  margin-top: 10px;
  padding: 10px 12px;
  border-radius: 10px;
  background: linear-gradient(180deg, #ECFDF5 0%, #D6F5E3 100%);
  border: 0.5px solid #A7E7CF;
  display: flex; align-items: center; gap: 10px;
}
.pc-total-swap-body { flex: 1; min-width: 0; }
.pc-total-swap-top {
  display: flex; align-items: center; gap: 5px;
  font-size: 12px; font-weight: 600;
  color: #0A5744;
  letter-spacing: -0.1px;
  min-width: 0;
}
.pc-total-swap-top svg { color: #1D9E75; flex-shrink: 0; }
.pc-total-swap-title {
  min-width: 0;
  flex: 1;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.pc-total-swap-hemat {
  background: #FFFFFF;
  color: #0A5744;
  border: 0.5px solid #A7E7CF;
  padding: 2px 7px;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  flex-shrink: 0;
}
.pc-total-swap-sub {
  font-size: 10.5px; color: #0F6E56;
  margin-top: 2px;
  font-variant-numeric: tabular-nums;
}
.pc-total-swap-bonus { color: #0A5744; font-weight: 500; }
.pc-total-swap-btn {
  flex-shrink: 0;
  background: #1D9E75; color: #FFFFFF;
  border: none;
  padding: 6px 12px;
  border-radius: 7px;
  font-size: 11.5px; font-weight: 600;
  cursor: pointer;
  letter-spacing: -0.1px;
}
.pc-total-swap-btn:hover { background: #0F6E56; }

.pc-cta { padding: 10px 14px 14px; }
.pc-cta-btn {
  width: 100%;
  background: #1B6FB8; color: #fff; border: none;
  padding: 11px 12px; border-radius: 10px;
  font-size: 13px; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: 6px;
}
.pc-cta-btn:hover { background: #185FA5; }
.pc-cta-btn:disabled {
  background: #CBD5E1; cursor: not-allowed;
}
.pc-cta-back {
  text-align: center;
  font-size: 11px; color: #64748B;
  margin-top: 8px;
}
</style>
