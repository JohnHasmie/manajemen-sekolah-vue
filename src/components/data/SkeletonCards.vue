<!--
  SkeletonCards.vue — N placeholder cards laid out in a responsive grid.

  For pages whose loaded content is a grid of cards rather than a list:
  Kelas hub class-card list, tutoring dashboard hero + tiles, dashboards.
-->
<script setup lang="ts">
import Skeleton from './Skeleton.vue';

withDefaults(
  defineProps<{
    /** Number of card slots. Default 4 — enough to fill a 2×2 or 4×1
     * grid without dominating the viewport. */
    cards?: number;
    /** Columns at the lg breakpoint. Default 2. */
    lgCols?: 1 | 2 | 3 | 4;
  }>(),
  { cards: 4, lgCols: 2 },
);
</script>

<template>
  <div
    class="grid gap-3"
    :class="{
      'lg:grid-cols-1': lgCols === 1,
      'lg:grid-cols-2 sm:grid-cols-2': lgCols === 2,
      'lg:grid-cols-3 sm:grid-cols-2': lgCols === 3,
      'lg:grid-cols-4 sm:grid-cols-2': lgCols === 4,
    }"
  >
    <div
      v-for="i in cards"
      :key="i"
      class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3"
    >
      <div class="flex items-center gap-2">
        <Skeleton shape="rect" class="h-7 w-7" />
        <Skeleton class="h-3 w-24" />
      </div>
      <Skeleton class="h-5 w-2/3" />
      <div class="space-y-2">
        <Skeleton class="h-2 w-full" />
        <Skeleton class="h-2 w-4/5" />
      </div>
    </div>
  </div>
</template>
