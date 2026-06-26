<!--
  TutoringSectionHeader — section h2 with an optional "+ Tambah" action
  on the right. Mirrors Flutter `TutoringSectionHeader`.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  title: string;
  actionLabel?: string;
}>();
defineEmits<{ (e: 'action'): void }>();
</script>

<template>
  <div class="flex items-center justify-between pt-4 pb-2">
    <h3 class="text-[14px] font-bold text-tutoring-text-hi tracking-tight">{{ title }}</h3>
    <button
      v-if="actionLabel"
      type="button"
      class="inline-flex items-center gap-1 text-xs font-bold text-tutoring-accent px-2 py-1 rounded-lg hover:bg-tutoring-border-soft"
      @click="$emit('action')"
    >
      <NavIcon name="plus" :size="14" />
      {{ actionLabel }}
    </button>
  </div>
</template>
