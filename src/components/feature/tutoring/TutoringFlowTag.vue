<!--
  TutoringFlowTag — small "this flow does X" banner.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{ text: string }>();
</script>

<template>
  <div
    class="flex items-center gap-2 bg-role-admin-soft text-role-admin rounded-xl px-3 py-2.5 text-xs font-semibold"
  >
    <NavIcon name="zap" :size="14" />
    {{ text }}
  </div>
</template>
