<!--
  ModuleTile.vue — shared row/tile primitive for every place the app
  lists a sellable module: the subscribe picker (toggle mode) and the
  Kelola Modul self-service page (managed mode).

  Before this component existed the two surfaces duplicated their row
  markup + CSS + icon/tint/tagline lookups verbatim, which meant tint
  bugs or label reshuffles had to be fixed twice, and the two lists
  visually drifted apart over time.

  ONE component, two rendering modes:

    mode="toggle"   — the /subscribe picker.
                      * Whole row is a button.
                      * Trailing widget = pill toggle switch.
                      * Emits `toggle` on click.
                      * Price shows the per-seat RATE + unit (e.g.
                        "Rp 1.500 / siswa").
                      * Highlights when :selected is true.

    mode="managed"  — /subscribe/manage-modules.
                      * Row is a container (not a button).
                      * Trailing slot lets the caller drop a "Matikan
                        modul" button in.
                      * Optional pill next to the title (e.g. "Aktif" /
                        "Gratis · hadiah" / "Akan berakhir").
                      * Price shows the monthly TOTAL for the tenant's
                        actual seat count (e.g. "Rp 108.000 / bln").
                      * Never emits toggle.

  Shared visual language stays here so future tint / typography /
  spacing tweaks land in one place.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { ModuleCatalogItem } from '@/types/subscription-billing';
import {
  CATEGORY_TINTS,
  MODULE_ICONS,
  moduleLabel,
  moduleTagline,
  money,
  seatUnit,
} from './moduleTokens';

const props = withDefaults(defineProps<{
  item: ModuleCatalogItem;
  tenantType?: 'sekolah' | 'bimbel' | null;
  /**
   * Toggle mode = interactive picker used by /subscribe.
   * Managed mode = read-with-actions used by /subscribe/manage-modules.
   */
  mode?: 'toggle' | 'managed';
  /** Toggle mode: is this module currently selected? */
  selected?: boolean;
  /**
   * Managed mode: monthly TOTAL to show (Rp 108.000 / bln). If
   * omitted in managed mode the row falls back to showing the per-seat
   * rate like toggle mode — useful for legacy list views that haven't
   * computed the total yet.
   */
  monthlyAmount?: number | null;
  /**
   * Managed mode: optional status label rendered as a pill next to the
   * title (e.g. "Aktif", "Gratis · hadiah", "Akan berakhir").
   */
  pillLabel?: string | null;
  /**
   * Managed mode: pill tone. Keeps the small palette explicit so
   * callers pick "success" / "warn" / "info" rather than passing raw
   * hex, which keeps future retunes trivial.
   */
  pillTone?: 'success' | 'warn' | 'info' | 'muted';
  /**
   * Managed mode: extra sub-line text after the tagline
   * (e.g. "72 siswa × Rp 1.500"). Rendered as an inline strong-tag
   * separated by a middot from the tagline so the eye scans
   * left-to-right without an extra row.
   */
  seatBreakdownText?: string | null;
  /**
   * Override for the small price unit line ("/ siswa", "/ bln", etc).
   * Used by the cancelled-modules section ("/ bln, terakhir") and the
   * available-to-add section ("/ bln, +prorata") to signal the price
   * carries an extra semantic beyond a plain monthly total.
   */
  priceUnitOverride?: string | null;
}>(), {
  mode: 'toggle',
  selected: false,
  monthlyAmount: null,
  pillLabel: null,
  pillTone: 'success',
  seatBreakdownText: null,
  priceUnitOverride: null,
});

defineEmits<{ toggle: [] }>();

const tint = computed(
  () => CATEGORY_TINTS[props.item.group] ?? CATEGORY_TINTS.Default,
);
const icon = computed(() => MODULE_ICONS[props.item.key] ?? 'circle-plus');
const label = computed(() => moduleLabel(props.item, props.tenantType));
const tagline = computed(() => moduleTagline(props.item, props.tenantType));
const rate = computed(() =>
  props.item.pricing_seat === 'staff'
    ? props.item.price_per_staff
    : props.item.price_per_student,
);
const unit = computed(() => seatUnit(props.item, props.tenantType));

/** True when we should show the monthly-total figure instead of the
 *  per-seat rate. Managed mode with a supplied `monthlyAmount` counts. */
const showTotal = computed<boolean>(
  () => props.mode === 'managed' && props.monthlyAmount !== null,
);
</script>

<template>
  <!-- Toggle mode: whole row is a button. Managed mode: container. -->
  <component
    :is="mode === 'toggle' ? 'button' : 'article'"
    :type="mode === 'toggle' ? 'button' : undefined"
    class="mt-row"
    :class="{
      'is-toggle': mode === 'toggle',
      'is-on': mode === 'toggle' && selected,
      'is-managed': mode === 'managed',
    }"
    @click="mode === 'toggle' ? $emit('toggle') : undefined"
  >
    <div
      class="mt-icon"
      :style="{ background: tint.bg, color: tint.fg }"
    >
      <i :class="`ti ti-${icon}`" aria-hidden="true" />
    </div>

    <div class="mt-body">
      <div class="mt-title">
        {{ label }}
        <span
          v-if="pillLabel"
          class="mt-pill"
          :class="`is-${pillTone}`"
        >{{ pillLabel }}</span>
      </div>
      <div class="mt-desc">
        {{ tagline }}
        <template v-if="seatBreakdownText">
          · <strong>{{ seatBreakdownText }}</strong>
        </template>
      </div>
    </div>

    <div class="mt-price">
      <template v-if="showTotal && monthlyAmount !== null">
        {{ money(monthlyAmount) }}
        <span class="u">{{ priceUnitOverride ?? '/ bln' }}</span>
      </template>
      <template v-else>
        {{ money(rate) }}
        <span class="u">{{ priceUnitOverride ?? unit }}</span>
      </template>
    </div>

    <!-- Trailing widget. Toggle mode renders the switch; managed mode
         lets the parent drop an action button via the slot. -->
    <div class="mt-trail">
      <div v-if="mode === 'toggle'" class="mt-tog" />
      <slot v-else name="trailing" />
    </div>
  </component>
</template>

<style scoped>
.mt-row {
  padding: 12px 14px;
  display: flex; align-items: center; gap: 12px;
  border-bottom: 0.5px solid #F1F5F9;
  width: 100%; text-align: left;
  background: transparent;
  transition: background 0.15s;
}
.mt-row:last-child { border-bottom: none; }

/* Toggle mode = whole row is a button. Give it button-y hover +
   selected states. */
.mt-row.is-toggle {
  cursor: pointer;
  border-left: none; border-right: none; border-top: none;
}
.mt-row.is-toggle:hover { background: #FBFDFF; }
.mt-row.is-toggle.is-on { background: #F0F7FF; }

/* Managed mode = static container with a plain white background.
   Callers usually put these inside their own bordered card. */
.mt-row.is-managed {
  background: #FFFFFF;
  border-bottom: 0.5px solid #F1F5F9;
}
.mt-row.is-managed:last-child { border-bottom: none; }

.mt-icon {
  width: 32px; height: 32px; border-radius: 8px;
  display: grid; place-items: center;
  font-size: 16px;
  flex-shrink: 0;
}

.mt-body { flex: 1; min-width: 0; }
.mt-title {
  font-size: 12.5px; font-weight: 500; color: #0F172A;
  display: inline-flex; align-items: center; gap: 6px;
  flex-wrap: wrap;
}
.mt-desc {
  font-size: 10.5px; color: #64748B;
  margin-top: 1px;
  line-height: 1.4;
}
.mt-desc strong {
  color: #0F172A; font-weight: 600;
  font-variant-numeric: tabular-nums;
}

/* Pill next to title — small palette keyed by tone so tint retunes
   land in one spot. `success` is the default (Aktif); `muted` is for
   gift/comped rows; `warn` for cancel-at-period-end; `info` for other
   informational badges. */
.mt-pill {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  padding: 2px 7px;
  border-radius: 999px;
  line-height: 1.3;
  white-space: nowrap;
}
.mt-pill.is-success {
  background: #DCFCE7;
  color: #0F6E56;
}
.mt-pill.is-warn {
  background: #FEF3C7;
  color: #B45309;
}
.mt-pill.is-info {
  background: #E6F1FB;
  color: #185FA5;
}
.mt-pill.is-muted {
  background: #EDE9FE;
  color: #5B21B6;
}

.mt-price {
  font-size: 12px; font-weight: 500; text-align: right;
  font-variant-numeric: tabular-nums; color: #0F172A;
  flex-shrink: 0;
  white-space: nowrap;
}
.mt-price .u {
  display: block; font-size: 10px;
  color: #64748B; font-weight: 400;
}

.mt-trail {
  flex-shrink: 0;
  display: flex; align-items: center;
}

/* Toggle switch — same visual language as before, just moved here. */
.mt-tog {
  width: 34px; height: 20px; border-radius: 999px;
  background: #CBD5E1; position: relative;
  transition: background 0.15s;
}
.mt-tog::after {
  content: '';
  position: absolute; top: 2px; left: 2px;
  width: 16px; height: 16px;
  background: #FFFFFF; border-radius: 50%;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.15);
  transition: left 0.15s;
}
.mt-row.is-toggle.is-on .mt-tog { background: #1B6FB8; }
.mt-row.is-toggle.is-on .mt-tog::after { left: 16px; }
</style>
