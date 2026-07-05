<!--
  StickyActionBar — the floating bottom bar that anchors 2–3 primary
  actions (Export, Terbitkan, Verifikasi, …) on long admin list screens.
  Report-card, finance, grade-recap and lesson-plan-review views each
  hand-rolled the identical `sticky bottom-4 z-30 grid grid-cols-N …`
  markup; this centralizes the chrome so the bar looks and floats the
  same everywhere.

  Buttons go in the default slot. `cols` sets the button grid; the
  column count is applied via inline style so Tailwind's JIT never has
  to see a dynamic `grid-cols-N` class.
-->
<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(defineProps<{ cols?: number }>(), { cols: 2 });

const gridStyle = computed(() => ({
  gridTemplateColumns: `repeat(${props.cols}, minmax(0, 1fr))`,
}));
</script>

<template>
  <section
    class="sticky bottom-4 z-30 grid gap-2 px-4 py-3 bg-white border border-slate-200 rounded-2xl shadow-lg"
    :style="gridStyle"
  >
    <slot />
  </section>
</template>
