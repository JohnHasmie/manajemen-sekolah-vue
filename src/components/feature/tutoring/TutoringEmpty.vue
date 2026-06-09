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
    class="w-full text-center bg-white border border-dashed border-slate-200 rounded-2xl py-8 px-4"
  >
    <NavIcon
      v-if="icon"
      :name="icon"
      :size="28"
      class="text-slate-400 mx-auto mb-2"
    />
    <p class="text-sm text-slate-500">{{ text }}</p>
  </div>
</template>
