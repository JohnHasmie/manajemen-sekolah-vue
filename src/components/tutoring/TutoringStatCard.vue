<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  title: string;
  value: string | number;
  subtitle?: string;
  icon: string;
  iconColorClass?: string;
  subtitleColorClass?: string;
}>();
</script>

<template>
  <div class="bg-tutoring-panel border border-tutoring-border rounded-2xl p-5 flex flex-col justify-between">
    <div class="flex justify-between items-start">
      <div class="text-[11px] font-bold text-tutoring-text-mid uppercase tracking-widest">{{ title }}</div>
      <div class="p-2 rounded-lg bg-white/5">
        <NavIcon :name="icon" :size="18" :class="iconColorClass || 'text-tutoring-text-mid'" />
      </div>
    </div>
    <div class="mt-4">
      <div class="text-3xl font-black text-tutoring-text-hi">{{ value }}</div>
      <div v-if="subtitle" class="text-xs mt-1 font-medium" :class="subtitleColorClass || 'text-tutoring-text-lo'">
        {{ subtitle }}
      </div>
    </div>
  </div>
</template>
