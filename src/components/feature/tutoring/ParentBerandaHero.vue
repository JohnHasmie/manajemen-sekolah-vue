<!--
  ParentBerandaHero — cyan/azure hero used on every parent (wali) page.
  Mirrors Flutter `_GreetingHero` in tutoring_child_overview_screen.dart
  + matches the mockup at:
    parent_web_pages_main / parent_web_pages_browse / etc.

  - Title + subtitle on the left
  - Optional child-picker chip on the right (slot `actions`)
  - Optional 3-4 KPI strip below

  Colors are fixed to the parent brand (azure #21afe6) so the hero
  feels distinctly "wali" — body surfaces still adapt via
  tutoring-light / tutoring-dark.
-->
<script setup lang="ts">
withDefaults(
  defineProps<{
    kicker?: string;
    title: string;
    subtitle?: string;
    /** 0..4 stat cells. Empty array hides the strip. */
    stats?: Array<{ label: string; value: string; hint?: string }>;
  }>(),
  { stats: () => [] },
);
</script>

<template>
  <div
    class="rounded-2xl px-4 sm:px-5 py-3.5 text-white"
    style="background: linear-gradient(135deg, #21afe6 0%, #1a8fbe 100%);"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="min-w-0">
        <p
          v-if="kicker"
          class="text-[13px] font-semibold uppercase tracking-widest text-white/75"
        >
          {{ kicker }}
        </p>
        <h1 class="mt-0.5 text-lg sm:text-xl font-extrabold tracking-tight">
          {{ title }}
        </h1>
        <p v-if="subtitle" class="mt-1 text-[14px] text-white/85">{{ subtitle }}</p>
      </div>
      <div v-if="$slots.actions" class="flex-shrink-0 flex items-center gap-2">
        <slot name="actions" />
      </div>
    </div>
    <div
      v-if="stats.length"
      class="mt-3.5 grid gap-2"
      :class="{
        'grid-cols-1': stats.length === 1,
        'grid-cols-2': stats.length === 2,
        'grid-cols-3': stats.length === 3,
        'grid-cols-2 sm:grid-cols-4': stats.length === 4,
      }"
    >
      <div
        v-for="s in stats"
        :key="s.label"
        class="rounded-xl bg-white/12 px-3 py-2 ring-1 ring-white/15"
      >
        <p class="text-[13px] font-bold uppercase tracking-widest text-white/70">
          {{ s.label }}
        </p>
        <p class="mt-0.5 text-lg font-extrabold tracking-tight">{{ s.value }}</p>
        <p v-if="s.hint" class="text-[13px] text-white/65 truncate">{{ s.hint }}</p>
      </div>
    </div>
  </div>
</template>
