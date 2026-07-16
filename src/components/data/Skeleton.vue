<!--
  Skeleton.vue — one placeholder rectangle that pulses while a fetch is
  in flight. The primitive every skeleton composite (`SkeletonList`,
  `SkeletonCards`, the inline `<Skeleton class="..."/>` in views) is
  built from.

  Kept intentionally dumb: it's a `<div>` with `animate-pulse` +
  `bg-slate-200`. Callers control shape/size/margin through Tailwind
  utilities on the class attribute so pages can match the eventual
  content's geometry (e.g. a title bar is `h-4 w-40`, a numeric KPI
  value is `h-6 w-14`).

  Motion: respects `prefers-reduced-motion` — the pulse turns off, but
  the bar still shows so the layout is still stable.
-->
<script setup lang="ts">
withDefaults(
  defineProps<{
    /**
     * Shape hint. `line` = short flat bar (default; the typical text
     * line). `circle` = round avatar / icon slot. `rect` = square-ish
     * block for image / hero / card body. All three flip to different
     * default heights so a caller can just say `<Skeleton shape="circle" />`
     * without adding utilities.
     */
    shape?: 'line' | 'circle' | 'rect';
  }>(),
  { shape: 'line' },
);
</script>

<template>
  <div
    aria-hidden="true"
    class="animate-pulse bg-slate-200 motion-reduce:animate-none"
    :class="{
      'rounded-md h-3': shape === 'line',
      'rounded-full': shape === 'circle',
      'rounded-xl': shape === 'rect',
    }"
  />
</template>
