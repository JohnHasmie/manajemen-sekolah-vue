<!--
  TutoringEmpty — dashed empty/loading card.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  text: string;
  icon?: string;
}>();
</script>

<template>
  <div
    class="w-full text-center bg-tutoring-panel border border-dashed border-tutoring-border rounded-2xl py-8 px-4"
  >
    <NavIcon
      v-if="icon"
      :name="icon"
      :size="28"
      class="text-tutoring-text-lo mx-auto mb-2"
    />
    <p class="text-sm text-tutoring-text-mid">{{ text }}</p>
  </div>
</template>
