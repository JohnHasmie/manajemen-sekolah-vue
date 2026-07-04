<!--
  BundleStrip.vue — "Rekomendasi · Paket Lengkap" horizontal card that
  sits above the module catalog.

  Priority order for the right-side price display:
    1. If both `studentCount` and `staffCount` are known (which the
       wizard step 4 always has because they're required to render
       the pricing calculator anyway), show the HONEST monthly total
       for that specific capacity plus a per-unit sub-line. Previously
       we showed "Rp 6.000 per siswa/bln" which
       (a) hid the staff-rate contribution and
       (b) never lined up with the calculator's Rp {total}/bln number
           because the calculator sums staff + student.
    2. Fallback: show both rates side by side ("Rp 6.000/siswa · Rp
       4.000/guru") when the parent only has rate info.
    3. Last resort: single-rate display for a truly per-seat bundle
       (e.g. an AI bundle that only bills per-guru).

  Click emits `select` so the parent can toggle bundle selection.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { money } from './moduleTokens';

const props = defineProps<{
  label: string;
  description: string;
  /** Per-student rate for this bundle. Set to 0 if the bundle is
      not billed per student (rare — most sekolah bundles are per
      siswa; the AI bundle is per guru). */
  pricePerStudent: number;
  /** Per-staff rate. Also set to 0 if not per-staff. */
  pricePerStaff?: number;
  /** Actual tenant capacity — when supplied, we compute the true
      monthly total instead of showing a per-unit rate that
      doesn't line up with the calculator. */
  studentCount?: number;
  staffCount?: number;
  /** Localised seat unit override — bimbel swaps "siswa" → "peserta"
      and "guru" → "tutor". */
  seatUnit?: string;
  staffUnit?: string;
  active?: boolean;
}>();

defineEmits<{
  select: [];
}>();

const studentUnitWord = computed(() => props.seatUnit ?? 'siswa');
const staffUnitWord = computed(() => props.staffUnit ?? 'guru');

/**
 * "Honest" monthly total for the tenant's capacity. Only returned
 * when we actually know how many students + staff the tenant has;
 * without that info we can't quote a total number.
 */
const monthlyTotal = computed<number | null>(() => {
  const sc = props.studentCount;
  const tc = props.staffCount;
  if (sc === undefined || tc === undefined) return null;
  return (
    props.pricePerStudent * sc +
    (props.pricePerStaff ?? 0) * tc
  );
});

/**
 * Which pricing surface to render:
 *   - 'total'    → both counts known → big monthly total + breakdown
 *   - 'two-rate' → only one rate is zero (uncommon) → show single rate
 *   - 'both-rate'→ neither zero, counts unknown → dual rate hint
 */
const priceMode = computed<'total' | 'two-rate' | 'both-rate'>(() => {
  if (monthlyTotal.value !== null) return 'total';
  const hasStudent = props.pricePerStudent > 0;
  const hasStaff = (props.pricePerStaff ?? 0) > 0;
  if (hasStudent && hasStaff) return 'both-rate';
  return 'two-rate';
});
</script>

<template>
  <button
    type="button"
    class="bs-root"
    :class="{ 'is-active': active }"
    @click="$emit('select')"
  >
    <div class="bs-icon">
      <i class="ti ti-package" aria-hidden="true" />
    </div>
    <div class="bs-body">
      <div class="bs-title-row">
        <span class="bs-badge">Rekomendasi</span>
        <span class="bs-title">{{ label }}</span>
      </div>
      <div class="bs-desc">{{ description }}</div>
    </div>

    <!-- Honest total mode — user sees the exact number they'll pay. -->
    <div v-if="priceMode === 'total' && monthlyTotal !== null" class="bs-price">
      <span class="bs-price-total">{{ money(monthlyTotal) }}/bln</span>
      <span class="bs-price-break">
        <template v-if="pricePerStudent > 0 && (pricePerStaff ?? 0) > 0">
          {{ studentCount }} {{ studentUnitWord }} × {{ money(pricePerStudent) }}
          + {{ staffCount }} {{ staffUnitWord }} × {{ money(pricePerStaff ?? 0) }}
        </template>
        <template v-else-if="pricePerStudent > 0">
          {{ studentCount }} {{ studentUnitWord }} × {{ money(pricePerStudent) }}
        </template>
        <template v-else>
          {{ staffCount }} {{ staffUnitWord }} × {{ money(pricePerStaff ?? 0) }}
        </template>
      </span>
    </div>

    <!-- Dual-rate mode — counts unknown, show both rates. -->
    <div v-else-if="priceMode === 'both-rate'" class="bs-price">
      <span class="bs-price-total">
        {{ money(pricePerStudent) }}/{{ studentUnitWord }}
      </span>
      <span class="bs-price-break">
        + {{ money(pricePerStaff ?? 0) }}/{{ staffUnitWord }} · per bulan
      </span>
    </div>

    <!-- Single-rate mode — the bundle only bills one seat type. -->
    <div v-else class="bs-price">
      <span class="bs-price-total">
        <template v-if="pricePerStudent > 0">
          {{ money(pricePerStudent) }}
        </template>
        <template v-else>
          {{ money(pricePerStaff ?? 0) }}
        </template>
      </span>
      <span class="bs-price-break">
        <template v-if="pricePerStudent > 0">per {{ studentUnitWord }} / bln</template>
        <template v-else>per {{ staffUnitWord }} / bln</template>
      </span>
    </div>
  </button>
</template>

<style scoped>
.bs-root {
  border: 0.5px solid #B5D4F4;
  background: linear-gradient(180deg, #F0F7FF 0%, #E7F1FE 100%);
  border-radius: 12px;
  padding: 12px 14px;
  margin: 0 0 16px;
  display: flex; align-items: center; gap: 12px;
  width: 100%;
  cursor: pointer; text-align: left;
  transition: box-shadow 0.15s, border-color 0.15s;
}
.bs-root:hover {
  box-shadow: 0 2px 6px rgba(27, 111, 184, 0.08),
              0 8px 20px rgba(27, 111, 184, 0.06);
}
.bs-root.is-active {
  border: 1.5px solid #1B6FB8;
  padding: 11.5px 13.5px;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.08);
}

.bs-icon {
  width: 32px; height: 32px; border-radius: 10px;
  background: #1B6FB8; color: #fff;
  display: grid; place-items: center;
  flex-shrink: 0;
}
.bs-icon .ti { font-size: 18px; }

.bs-body { flex: 1; min-width: 0; }
.bs-title-row {
  display: flex; align-items: center; gap: 6px;
  flex-wrap: wrap;
}
.bs-badge {
  background: #1B6FB8; color: #fff;
  font-size: 10px; font-weight: 600;
  letter-spacing: 0.4px;
  padding: 2px 8px; border-radius: 999px;
  text-transform: uppercase;
}
.bs-title { font-size: 12.5px; font-weight: 500; color: #113E75; }
.bs-desc { font-size: 11px; color: #185FA5; margin-top: 1px; }

/* Right price cell. `.bs-price-total` is the eye-catching number,
   `.bs-price-break` sits under it with the arithmetic that leads
   to it — so the reader can verify without reaching for the
   calculator sidebar. */
.bs-price {
  text-align: right;
  flex-shrink: 0;
  min-width: 0;
  display: flex; flex-direction: column;
  align-items: flex-end; gap: 2px;
}
.bs-price-total {
  font-size: 13.5px; font-weight: 700; color: #113E75;
  letter-spacing: -0.1px;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.bs-price-break {
  font-size: 10px; color: #185FA5;
  font-weight: 500;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
</style>
