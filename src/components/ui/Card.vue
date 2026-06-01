<!--
  Card.vue — surface primitive (white background, rounded, card shadow).
  Optional title/subtitle/icon header. Compose actions via the #header-actions slot.
-->
<script setup lang="ts">
defineProps<{
  title?: string;
  subtitle?: string;
  padded?: boolean;
}>();
</script>

<template>
  <section
    class="form-card"
    :class="{ 'p-lg sm:p-xl': padded !== false }"
  >
    <header
      v-if="title || subtitle || $slots['header-actions']"
      class="flex items-start justify-between gap-md mb-md"
    >
      <div class="min-w-0">
        <h3 v-if="title" class="text-base font-semibold text-slate-900">
          {{ title }}
        </h3>
        <p v-if="subtitle" class="text-xs text-slate-500 mt-0.5">
          {{ subtitle }}
        </p>
      </div>
      <div v-if="$slots['header-actions']" class="flex items-center gap-2 flex-shrink-0">
        <slot name="header-actions" />
      </div>
    </header>

    <slot />
  </section>
</template>
