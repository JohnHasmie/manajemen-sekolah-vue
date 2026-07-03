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
  MODULE_TAGLINES,
  money,
  seatUnit,
} from './moduleTokens';

const props = defineProps<{
  item: ModuleCatalogItem;
  selected: boolean;
  autoInclude?: string[];
}>();

defineEmits<{
  toggle: [];
}>();

const tint = computed(
  () => CATEGORY_TINTS[props.item.group] ?? CATEGORY_TINTS.Default,
);
const icon = computed(() => MODULE_ICONS[props.item.key] ?? 'circle-plus');
const tagline = computed(
  () => MODULE_TAGLINES[props.item.key] ?? props.item.label,
);
const price = computed(() =>
  props.item.pricing_seat === 'staff'
    ? props.item.price_per_staff
    : props.item.price_per_student,
);
</script>

<template>
  <button
    type="button"
    class="mc-root"
    :class="{ 'is-on': selected }"
    @click="$emit('toggle')"
  >
    <div class="mc-top">
      <div
        class="mc-icon"
        :style="{ background: tint.bg, color: tint.fg }"
      >
        <i :class="`ti ti-${icon}`" aria-hidden="true" />
      </div>
      <div class="mc-body">
        <div class="mc-title">{{ item.label }}</div>
        <div class="mc-desc">{{ tagline }}</div>
      </div>
      <div class="mc-check" :class="{ 'is-on': selected }">
        <i v-if="selected" class="ti ti-check" aria-hidden="true" />
      </div>
    </div>

    <div v-if="autoInclude && autoInclude.length" class="mc-req">
      <i class="ti ti-link" aria-hidden="true" />
      Otomatis termasuk: {{ autoInclude.join(', ') }}
    </div>

    <div class="mc-price">
      <span class="mc-price-n">{{ money(price) }}</span>
      <span class="mc-price-u">{{ seatUnit(item) }} / bln</span>
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
.mc-root.is-on {
  border: 1.5px solid #1B6FB8;
  padding: 11.5px 13.5px;
  background: #FBFDFF;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.06);
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
  width: 18px; height: 18px; border-radius: 5px;
  border: 1.5px solid #CBD5E1;
  display: grid; place-items: center;
  flex-shrink: 0;
  color: transparent;
  font-size: 12px;
}
.mc-check.is-on {
  background: #1B6FB8;
  border-color: #1B6FB8;
  color: #fff;
}

.mc-req {
  font-size: 10px; color: #B45309;
  display: flex; align-items: center; gap: 4px;
}
.mc-req .ti { font-size: 11px; }

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
