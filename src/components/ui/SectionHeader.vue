<!--
  SectionHeader.vue — the repeated section title row used across admin
  views: a bold h3 on the left, an optional right-side action (button /
  meta) via the `action` slot.

  Extracted from the hand-rolled pattern seen in e.g.
  AdminGradeOverviewView ("Sebaran Grade" card header):
    <header class="flex items-center justify-between mb-3">
      <h3 class="text-[13px] font-black text-slate-700 tracking-tight">…</h3>
      <span …>meta / action</span>
    </header>

  Props:
    - title     — required heading text
    - subtitle? — optional muted line under the title

  Slot:
    - action — right-aligned content (a button, a meta span, etc.)
-->
<script setup lang="ts">
defineProps<{
  title: string;
  subtitle?: string;
}>();
</script>

<template>
  <header class="flex items-center justify-between gap-3 mb-3">
    <div class="min-w-0">
      <h3 class="text-[13px] font-black text-slate-700 tracking-tight truncate">
        {{ title }}
      </h3>
      <p v-if="subtitle" class="text-2xs font-medium text-slate-400 mt-0.5 truncate">
        {{ subtitle }}
      </p>
    </div>
    <div v-if="$slots.action" class="flex-shrink-0">
      <slot name="action" />
    </div>
  </header>
</template>
