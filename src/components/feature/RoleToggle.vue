<!--
  RoleToggle.vue — teacher ↔ wali_kelas switcher for teachers.
  Mirrors Flutter's RoleToggle in `lib/core/widgets/`.

  Only renders when both roles are available.
-->
<script setup lang="ts">
import type { Role } from '@/types/auth';

defineProps<{
  modelValue: Role;
  options: { value: Role; label: string }[];
}>();

defineEmits<{ 'update:modelValue': [Role] }>();
</script>

<template>
  <div class="inline-flex rounded-full bg-slate-100 p-0.5 text-sm">
    <button
      v-for="opt in options"
      :key="opt.value"
      type="button"
      class="px-4 py-1.5 rounded-full font-medium transition-colors"
      :class="
        modelValue === opt.value
          ? 'bg-white text-role-teacher shadow-sm'
          : 'text-slate-500 hover:text-slate-700'
      "
      @click="$emit('update:modelValue', opt.value)"
    >
      {{ opt.label }}
    </button>
  </div>
</template>
