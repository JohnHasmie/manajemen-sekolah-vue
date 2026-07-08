<!--
  ModuleCard.vue — single sellable module card used in the wizard's
  grid picker (2 columns). Matches mockup 1's `.sw-mod` layout.

  Displays selected state, dependency chip, and per-seat price.
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

const props = defineProps<{
  item: ModuleCatalogItem;
  selected: boolean;
  autoInclude?: string[];
  /**
   * Labels of currently-selected modules that `requires` this one.
   * When non-empty the card renders read-only (disabled cursor, muted
   * check pill, "Diperlukan oleh …" hint) so the user can see WHY the
   * checkbox is pinned and how to release it. Yahya picked this UX
   * 2026-07-08 ("kenapa aku tidak bisa yang unchecklist rpp dan
   * materi" thread — chose option c "disabled + tooltip").
   */
  requiredBy?: string[];
  /** Tenant type so labels/taglines/units read naturally for bimbel. */
  tenantType?: 'sekolah' | 'bimbel' | null;
}>();

const emit = defineEmits<{
  toggle: [];
}>();

const isRequiredDep = computed(
  () => (props.requiredBy?.length ?? 0) > 0,
);

function handleClick() {
  // Read-only when this card is only checked because something else
  // requires it — clicking is a no-op so the state is honest. The
  // "Diperlukan oleh …" hint tells the user which upstream module to
  // uncheck to release this dep.
  if (isRequiredDep.value) return;
  emit('toggle');
}

const tint = computed(
  () => CATEGORY_TINTS[props.item.group] ?? CATEGORY_TINTS.Default,
);
const icon = computed(() => MODULE_ICONS[props.item.key] ?? 'circle-plus');
const label = computed(() => moduleLabel(props.item, props.tenantType));
const tagline = computed(() => moduleTagline(props.item, props.tenantType));
const price = computed(() =>
  props.item.pricing_seat === 'staff'
    ? props.item.price_per_staff
    : props.item.price_per_student,
);
const unit = computed(() => seatUnit(props.item, props.tenantType));
</script>

<template>
  <button
    type="button"
    class="mc-root"
    :class="{ 'is-on': selected, 'is-locked': isRequiredDep }"
    :aria-disabled="isRequiredDep || undefined"
    :title="isRequiredDep ? `Diperlukan oleh ${requiredBy!.join(', ')}` : undefined"
    @click="handleClick"
  >
    <div class="mc-top">
      <div
        class="mc-icon"
        :style="{ background: tint.bg, color: tint.fg }"
      >
        <i :class="`ti ti-${icon}`" aria-hidden="true" />
      </div>
      <div class="mc-body">
        <div class="mc-title">{{ label }}</div>
        <div class="mc-desc">{{ tagline }}</div>
      </div>
      <div class="mc-check" :class="{ 'is-on': selected }" aria-hidden="true">
        <!-- Inline SVG check so we don't depend on the Tabler icon
             font shipping at a legible weight/size — the previous
             `ti-check` at 12px rendered as a hairline that read as
             blank on high-DPI screens. -->
        <svg
          v-if="selected"
          viewBox="0 0 16 16"
          width="14"
          height="14"
          fill="none"
          stroke="currentColor"
          stroke-width="2.6"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <polyline points="3 8.5 6.5 12 13 4.5" />
        </svg>
      </div>
    </div>

    <div v-if="autoInclude && autoInclude.length" class="mc-req">
      <i class="ti ti-link" aria-hidden="true" />
      Otomatis termasuk: {{ autoInclude.join(', ') }}
    </div>

    <div v-if="isRequiredDep" class="mc-req mc-req-locked">
      <i class="ti ti-lock" aria-hidden="true" />
      Diperlukan oleh {{ requiredBy!.join(', ') }} — uncheck itu dulu untuk mematikan modul ini.
    </div>

    <div class="mc-price">
      <span class="mc-price-n">{{ money(price) }}</span>
      <span class="mc-price-u">{{ unit }} / bln</span>
    </div>
  </button>
</template>

<style scoped>
.mc-root {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 12px 14px;
  display: flex; flex-direction: column;
  gap: 8px;
  cursor: pointer;
  text-align: left;
  width: 100%;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.mc-root:hover { border-color: #C7D2E1; }
/* Selected state — enough visual weight to read at a glance: brand-
   blue border, tinted background that matches ModuleRow, and a soft
   blue focus-ring. The filled check marker at top-right does the rest. */
.mc-root.is-on {
  border: 1.5px solid #1B6FB8;
  padding: 11.5px 13.5px;
  background: #F0F7FF;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.10);
}

.mc-top { display: flex; align-items: flex-start; gap: 8px; }
.mc-icon {
  width: 30px; height: 30px; border-radius: 8px;
  display: grid; place-items: center;
  font-size: 16px;
  flex-shrink: 0;
}
.mc-body { flex: 1; min-width: 0; }
.mc-title { font-size: 12.5px; font-weight: 500; color: #0F172A; }
.mc-desc {
  font-size: 10.5px; color: #64748B;
  line-height: 1.45; margin-top: 2px;
}

.mc-check {
  width: 20px; height: 20px; border-radius: 6px;
  border: 1.5px solid #CBD5E1;
  display: grid; place-items: center;
  flex-shrink: 0;
  color: transparent;
  transition: background 0.12s, border-color 0.12s;
}
.mc-check.is-on {
  background: #1B6FB8;
  border-color: #1B6FB8;
  color: #fff;
  box-shadow: 0 1px 2px rgba(27, 111, 184, 0.28);
}
.mc-check svg { display: block; }

.mc-req {
  font-size: 10px; color: #B45309;
  display: flex; align-items: center; gap: 4px;
}
.mc-req .ti { font-size: 11px; }

/* Locked / read-only state — cursor + subtle desaturation cue that
   clicks won't do anything, but the checkbox still reads as selected
   because the module IS in the effective subscription (dep of the
   requirer). */
.mc-root.is-locked { cursor: not-allowed; }
.mc-root.is-locked .mc-icon,
.mc-root.is-locked .mc-title,
.mc-root.is-locked .mc-desc,
.mc-root.is-locked .mc-price { opacity: 0.75; }
.mc-req-locked { color: #64748B; }
.mc-req-locked .ti { font-size: 11px; }

.mc-price {
  display: flex; align-items: baseline; gap: 4px;
  padding-top: 6px;
  border-top: 0.5px solid #F1F5F9;
  margin-top: auto;
}
.mc-price-n {
  font-size: 13.5px; font-weight: 600; color: #0F172A;
  letter-spacing: -0.1px;
}
.mc-price-u { font-size: 10.5px; color: #64748B; }
</style>
