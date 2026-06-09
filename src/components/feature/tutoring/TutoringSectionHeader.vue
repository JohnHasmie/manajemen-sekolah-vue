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
    <h3 class="text-[13px] font-bold text-slate-900 tracking-tight">{{ title }}</h3>
    <button
      v-if="actionLabel"
      type="button"
      class="inline-flex items-center gap-1 text-xs font-bold text-role-admin px-2 py-1 rounded-lg hover:bg-slate-100"
      @click="$emit('action')"
    >
      <NavIcon name="plus" :size="14" />
      {{ actionLabel }}
    </button>
  </div>
</template>
