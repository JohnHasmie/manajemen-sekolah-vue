<!--
  SkeletonList.vue — N stacked skeleton rows shaped like the canonical
  "row with an icon square + title line + subtitle line" used across
  most list views (schedule, roster, activity feed, announcement list).

  Mounted as `<AsyncView>`'s default loading branch — the shape is
  generic enough to read as "loading" on non-list pages too (dashboards,
  detail views) without misrepresenting the layout.

  The container matches the "bg-white border rounded-2xl" style of the
  actual list rows so the swap on load doesn't collapse the layout.
-->
<script setup lang="ts">
import Skeleton from './Skeleton.vue';

withDefaults(
  defineProps<{
    /** How many placeholder rows to render. Default 3 — enough to
     * signal "list of things" without over-dominating short viewports. */
    rows?: number;
  }>(),
  { rows: 3 },
);
</script>

<template>
  <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
    <div
      v-for="i in rows"
      :key="i"
      class="flex items-center gap-3 px-4 py-3"
      :class="i > 1 ? 'border-t border-slate-100' : ''"
    >
      <Skeleton shape="rect" class="h-9 w-9 flex-shrink-0" />
      <div class="flex-1 min-w-0 space-y-2">
        <Skeleton class="h-3 w-2/5" />
        <Skeleton class="h-2 w-3/5" />
      </div>
      <Skeleton class="h-3 w-12 flex-shrink-0" />
    </div>
  </div>
</template>
