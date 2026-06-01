<!--
  AppFilterChip.vue - label + value pill with icon, used in the filter
  toolbar pattern for Teacher Presensi, Buku Nilai, and similar pages.

  Layout: [icon] [label / value] [chevron]
  Tone determines the icon-square color.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

withDefaults(
  defineProps<{
    label: string;
    value: string;
    iconName?: string;
    tone?: 'brand' | 'amber' | 'violet' | 'green' | 'red' | 'slate';
    disabled?: boolean;
  }>(),
  { iconName: '', tone: 'brand', disabled: false },
);

defineEmits<{ click: [] }>();
</script>

<template>
  <button
    type="button"
    class="inline-flex items-center gap-2.5 rounded-xl border transition-all px-3 py-2"
    :class="[
      disabled
        ? 'bg-slate-50 border-slate-100 text-slate-400 cursor-not-allowed'
        : 'bg-slate-50 border-slate-200 hover:bg-white hover:border-brand-cobalt text-slate-900',
    ]"
    :disabled="disabled"
    @click="$emit('click')"
  >
    <span
      v-if="iconName"
      class="w-7 h-7 rounded-lg grid place-items-center flex-shrink-0"
      :class="{
        'bg-brand-cobalt/10 text-brand-cobalt': tone === 'brand',
        'bg-amber-100 text-amber-700': tone === 'amber',
        'bg-violet-100 text-violet-700': tone === 'violet',
        'bg-emerald-100 text-emerald-700': tone === 'green',
        'bg-red-100 text-red-700': tone === 'red',
        'bg-slate-100 text-slate-600': tone === 'slate',
      }"
    >
      <NavIcon :name="iconName" :size="14" />
    </span>
    <span class="flex flex-col items-start min-w-0 leading-none">
      <span class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">{{ label }}</span>
      <span class="text-[13px] font-bold text-slate-900 truncate mt-0.5">{{ value }}</span>
    </span>
    <svg
      v-if="!disabled"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="w-3 h-3 text-slate-400 ml-1"
      aria-hidden="true"
    >
      <polyline points="6 9 12 15 18 9" />
    </svg>
  </button>
</template>
