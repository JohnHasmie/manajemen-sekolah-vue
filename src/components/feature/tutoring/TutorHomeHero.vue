<!--
  TutorHomeHero — navy gradient hero with greeting, subtitle, and a
  3-stat strip (used by tutor + admin + parent landing pages). Mirrors
  the Flutter `_GreetingHero` in tutor_beranda_screen.dart.

  Greeting + honorific are computed by the caller (Mas / Bu / Pak) and
  passed in via `title`. `stats` is a 1..3 array — fewer stats render
  fewer cells.
-->
<script setup lang="ts">
withDefaults(
  defineProps<{
    /** "Selamat pagi" / "Selamat siang" — micro tagline above the title. */
    greeting: string;
    /** "Pak Yahya" / "Bu Sari" — the big tracking-tight line. */
    title: string;
    /** Sub-line under the title (e.g. role + class count). */
    subtitle?: string;
    /** 1..3 stat cells: { label, value, hint? }. */
    stats?: Array<{ label: string; value: string; hint?: string }>;
  }>(),
  { stats: () => [] },
);
</script>

<template>
  <div
    class="rounded-3xl px-5 pt-4 pb-5 text-white shadow-lg"
    style="background: linear-gradient(135deg, var(--bimbel-hero), color-mix(in srgb, var(--bimbel-hero) 72%, black))"
  >
    <div class="flex items-start justify-between gap-4">
      <div class="min-w-0 flex-1">
        <p class="text-[13px] font-semibold tracking-wide text-white/75">{{ greeting }}</p>
        <h1 class="mt-0.5 text-[22px] sm:text-2xl font-extrabold tracking-tight">
          {{ title }}
        </h1>
        <p v-if="subtitle" class="mt-1 text-[14px] text-white/85">{{ subtitle }}</p>
      </div>
      <div v-if="$slots.actions" class="flex flex-wrap items-center gap-2 shrink-0">
        <slot name="actions" />
      </div>
    </div>

    <div
      v-if="stats.length"
      class="mt-4 grid gap-2.5"
      :class="{
        'grid-cols-1': stats.length === 1,
        'grid-cols-2': stats.length === 2,
        'grid-cols-3': stats.length === 3,
      }"
    >
      <div
        v-for="s in stats"
        :key="s.label"
        class="rounded-2xl bg-white/10 px-3 py-2.5 ring-1 ring-white/15"
      >
        <p class="text-[12px] font-bold uppercase tracking-widest text-white/70">
          {{ s.label }}
        </p>
        <p class="mt-0.5 text-xl font-extrabold tracking-tight">{{ s.value }}</p>
        <p v-if="s.hint" class="mt-0.5 truncate text-[12px] text-white/65">
          {{ s.hint }}
        </p>
      </div>
    </div>
  </div>
</template>
