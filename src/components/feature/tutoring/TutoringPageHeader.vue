<!--
  TutoringPageHeader — single h1 row used at the very top of every
  tutoring web page. Keeps the title chrome (h1 + tenant chip + optional
  CTA slot) identical across pages so the redesign is a single source.
-->
<script setup lang="ts">
import TutoringStatusPill from './TutoringStatusPill.vue';

defineProps<{
  title: string;
  crumbs?: string;
}>();
</script>

<template>
  <header class="flex items-end justify-between gap-4 flex-wrap mb-4">
    <div class="min-w-0">
      <p
        v-if="crumbs"
        class="text-[10.5px] font-bold text-slate-400 uppercase tracking-widest"
      >
        {{ crumbs }}
      </p>
      <div class="flex items-center gap-2.5 mt-1">
        <h1 class="text-xl font-extrabold text-slate-900 tracking-tight">
          {{ title }}
        </h1>
        <TutoringStatusPill label="Bimbel" tone="tenant" />
      </div>
    </div>
    <div v-if="$slots.right" class="flex items-center gap-2 flex-shrink-0">
      <slot name="right" />
    </div>
  </header>
</template>
