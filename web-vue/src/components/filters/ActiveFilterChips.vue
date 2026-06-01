<!--
  ActiveFilterChips.vue — port of Flutter's ActiveFilterChips.
  Renders active filter values as removable chips under the search bar.
-->
<script setup lang="ts">
export interface FilterChip {
  key: string;
  label: string;
}

defineProps<{ chips: FilterChip[] }>();
defineEmits<{ remove: [key: string]; clearAll: [] }>();
</script>

<template>
  <div v-if="chips.length" class="flex flex-wrap items-center gap-2">
    <span
      v-for="chip in chips"
      :key="chip.key"
      class="inline-flex items-center gap-1.5 rounded-full bg-brand-50 text-brand-700 px-2.5 py-1 text-xs font-medium"
    >
      {{ chip.label }}
      <button
        type="button"
        class="hover:bg-brand-100 rounded-full p-0.5"
        :aria-label="`Hapus filter ${chip.label}`"
        @click="$emit('remove', chip.key)"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="w-3 h-3"
        >
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </span>
    <button
      v-if="chips.length > 1"
      type="button"
      class="text-xs text-slate-500 hover:text-slate-700 font-medium"
      @click="$emit('clearAll')"
    >
      Hapus semua
    </button>
  </div>
</template>
