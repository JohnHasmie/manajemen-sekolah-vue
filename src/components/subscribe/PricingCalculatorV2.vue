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
import { computed } from 'vue';
import type {
  BillingPeriod,
  ModularQuote,
  ModuleCatalog,
} from '@/types/subscription-billing';
import { money, moduleLabel } from './moduleTokens';
import BundleNudge from './BundleNudge.vue';

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
}>();

const emit = defineEmits<{
  'update:plan': [plan: BillingPeriod];
  submit: [];
  'switch-to-bundle': [key: string];
}>();

const discountPct = computed(() => props.yearlyDiscountPct ?? 20);
const lines = computed(() => props.quote?.per_module ?? []);
const aiLines = computed(() => props.quote?.ai_quota_lines ?? []);

function labelFor(key: string): string {
  const optional = props.catalog?.optional[key];
  if (optional) return moduleLabel(optional, props.tenantType);
  return props.catalog?.bundles[key]?.label ?? key;
}

const perUnitWord = computed(() =>
  props.tenantType === 'bimbel' ? 'peserta' : 'siswa',
);
const staffWord = computed(() =>
  props.tenantType === 'bimbel' ? 'tutor' : 'guru',
);

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

const perStudent = computed(() => {
  const total = monthlyAmount.value;
  const denom = props.studentCount;
  if (!denom) return 0;
  return Math.round(total / denom);
});

const showNudge = computed(() => {
  const b = props.bundleBenchmark;
  if (!b) return false;
  const alreadyOnBundle = props.quote?.selected_keys.includes(b.key);
  return !alreadyOnBundle && monthlyAmount.value >= b.monthlyTotal;
});

function onPlan(p: BillingPeriod) {
  emit('update:plan', p);
}
</script>

<template>
  <div class="pc-calc">
    <div class="pc-calc-head">
      <div class="pc-calc-kicker">Ringkasan</div>
      <div class="pc-calc-title">
        {{ tenantName }} · {{ studentCount }}/{{ staffCount }}
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
    </div>
    <div v-else class="pc-empty">
      Belum ada modul dipilih.
    </div>

    <!-- Total + primary CTA sit BEFORE the bundle nudge so the user
         never has to scroll the sidebar to see the amount they're
         paying or the button that submits it. The nudge is
         opportunistic — if they want the cheaper bundle, they can act
         on it, but it's not allowed to hide the total. -->
    <div class="pc-total">
      <div class="pc-total-lbl">
        Total per {{ plan === 'yearly' ? 'tahun' : 'bulan' }}
      </div>
      <div class="pc-total-val">{{ money(chosenAmount) }}</div>
      <div v-if="studentCount > 0" class="pc-total-per">
        ≈ {{ money(perStudent) }} per {{ perUnitWord }} / bln
      </div>
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

    <BundleNudge
      v-if="showNudge && bundleBenchmark"
      :alacarte-total="monthlyAmount"
      :bundle-total="bundleBenchmark.monthlyTotal"
      :bonus-module-count="bundleBenchmark.bonusModuleCount"
      @switch="emit('switch-to-bundle', bundleBenchmark.key)"
      @skip="() => {}"
    />
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
.pc-calc-title { font-size: 13.5px; font-weight: 500; margin-top: 3px; color: #0F172A; }

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

.pc-lines { padding: 10px 14px; }
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
}
.pc-total-per {
  font-size: 11px; color: #64748B;
  margin-top: 1px;
}

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
