<!--
  DEPRECATED shim (WEB-1). Renamed + moved to
  `@/components/feature/TutoringTabBar.vue` — the "Parent" scope name
  became stale once admin / tutor / student screens all landed on top
  of the same tab bar in the bimbel rebuild.

  I grep'd — nothing in the current tree imports this file. Kept as a
  re-export shim in case a stale WIP branch merges in with an old
  import; CLEAN-2 removes it once the rebuild lands.
-->
<script setup lang="ts">
import TutoringTabBar from '@/components/feature/TutoringTabBar.vue';

defineProps<{
  modelValue: string;
  tabs: Array<{ id: string; label: string }>;
  fit?: boolean;
}>();

defineEmits<{ (e: 'update:modelValue', v: string): void }>();
</script>

<template>
  <TutoringTabBar
    :model-value="modelValue"
    :tabs="tabs"
    :fit="fit"
    @update:model-value="(v) => $emit('update:modelValue', v)"
  />
</template>
