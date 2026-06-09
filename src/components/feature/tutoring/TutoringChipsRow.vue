<!--
  TutoringChipsRow — single-select filter chips. Mirrors Flutter
  `TutoringChipsRow`. Bind via v-model.
-->
<script setup lang="ts" generic="T extends string | number">
defineProps<{
  modelValue: T;
  options: { value: T; label: string }[];
}>();

defineEmits<{ (e: 'update:modelValue', v: T): void }>();
</script>

<template>
  <div class="flex flex-wrap gap-1.5">
    <button
      v-for="o in options"
      :key="String(o.value)"
      type="button"
      class="rounded-lg px-2.5 py-1.5 text-xs font-semibold border transition"
      :class="
        o.value === modelValue
          ? 'bg-role-admin border-role-admin text-white'
          : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300'
      "
      @click="$emit('update:modelValue', o.value)"
    >
      {{ o.label }}
    </button>
  </div>
</template>
