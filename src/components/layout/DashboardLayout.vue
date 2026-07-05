<!--
  DashboardLayout.vue — shared vertical scaffold for role home dashboards
  (Admin, Teacher, Parent, …).

  WHY THIS EXISTS
  ---------------
  Before this, each role dashboard hand-rolled its own outer wrapper,
  max-width, and inter-section spacing. They drifted: admin + parent used
  `space-y-md`, teacher used `space-y-6`; ordering of the greeting / KPI /
  hero / content / quick-actions blocks differed per view. This component
  owns ONE predictable vertical rhythm and a FIXED slot order so every
  dashboard reads top-to-bottom the same way, no matter the role.

  Think of it like a Laravel Blade layout with @yield sections: the host
  view just fills the named "sections" (slots) it has content for, and the
  layout decides the outer container, the max-width, and the gap between
  sections. A slot with no content renders nothing at all (we guard every
  slot with `$slots.x`), so a sparse dashboard collapses cleanly instead of
  leaving empty gaps — same idea as an `@hasSection` check in Blade.

  FIXED VERTICAL ORDER (top → bottom)
  -----------------------------------
    #greeting     — hero/greeting header row (name, date, year chip)
    #kpis         — the KPI strip (StatSummaryCards / KpiStripCards)
    #hero         — an alert / feature / spotlight card (e.g. parent's
                    attendance gradient, or a banner)
    #main         — primary page content. This is the DEFAULT slot, so
                    `<template #main>` and bare default children both land
                    here. Put your heatmaps / feeds / inbox / schedule here.
    #quickActions — the action grid / shortcuts at the bottom.

  Every slot is OPTIONAL. Render order is fixed regardless of which slots
  are supplied, so two dashboards that fill different subsets still line up.

  PROPS
  -----
    - maxWidth  — max content width in px (the container is centered with
                  `mx-auto`). Defaults to 1600 to match the existing
                  `max-w-[1600px]` all three views already used.
    - gap       — spacing token between sections: one of the AppSpacing
                  tokens ('sm' | 'md' | 'lg'). Defaults to 'md' (16px),
                  which is what admin + parent already used. The layout
                  owns this so rhythm is identical across roles.
    - padded    — when true, adds horizontal + top padding to the inner
                  container (teacher's old `px-4 sm:px-6 lg:px-8 pt-6`).
                  Defaults to false; admin/parent were rendered inside a
                  shell that already supplies page padding.

  USAGE
  -----
    <DashboardLayout>
      <template #greeting> …greeting row… </template>
      <template #kpis> …KpiStripCards / StatSummaryCards… </template>
      <template #hero> …feature/alert card… </template>
      <template #main> …primary content… </template>
      <template #quickActions> …action grid… </template>
    </DashboardLayout>
-->
<script setup lang="ts">
import { computed, useSlots } from 'vue';

const props = withDefaults(
  defineProps<{
    /** Max centered content width in px. Defaults to 1600. */
    maxWidth?: number;
    /** Vertical rhythm between sections. Defaults to 'md' (16px). */
    gap?: 'sm' | 'md' | 'lg';
    /** Add inner horizontal + top padding (teacher shell). Off by default. */
    padded?: boolean;
  }>(),
  {
    maxWidth: 1600,
    gap: 'md',
    padded: false,
  },
);

const slots = useSlots();

// Static class map so Tailwind's JIT keeps these `space-y-*` utilities.
const GAP_CLASS: Record<'sm' | 'md' | 'lg', string> = {
  sm: 'space-y-sm',
  md: 'space-y-md',
  lg: 'space-y-lg',
};

const containerClass = computed(() =>
  [
    'mx-auto',
    GAP_CLASS[props.gap],
    props.padded ? 'px-4 sm:px-6 lg:px-8 pt-6 pb-12' : '',
  ]
    .filter(Boolean)
    .join(' '),
);

const containerStyle = computed(() => ({
  maxWidth: `${props.maxWidth}px`,
}));
</script>

<template>
  <div :class="containerClass" :style="containerStyle">
    <!-- 1. Greeting / hero header row -->
    <div v-if="slots.greeting">
      <slot name="greeting" />
    </div>

    <!-- 2. KPI strip -->
    <div v-if="slots.kpis">
      <slot name="kpis" />
    </div>

    <!-- 3. Alert / feature / spotlight card -->
    <div v-if="slots.hero">
      <slot name="hero" />
    </div>

    <!-- 4. Primary content (default slot) -->
    <div v-if="slots.main || slots.default">
      <slot name="main">
        <slot />
      </slot>
    </div>

    <!-- 5. Quick actions / shortcuts grid -->
    <div v-if="slots.quickActions">
      <slot name="quickActions" />
    </div>
  </div>
</template>
