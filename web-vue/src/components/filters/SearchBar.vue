<!--
  SearchBar.vue — list-screen search input.
  Mirrors Flutter's EnhancedSearchBar in `lib/core/widgets/`.

  Debounces input via @vueuse/core's useDebounceFn (300ms default).
  v-model for the query, @search for the debounced commit.
-->
<script setup lang="ts">
import { ref, watch } from 'vue';
import { useDebounceFn } from '@vueuse/core';

const props = withDefaults(
  defineProps<{
    modelValue: string;
    placeholder?: string;
    debounceMs?: number;
    autofocus?: boolean;
  }>(),
  {
    placeholder: 'Cari…',
    debounceMs: 300,
    autofocus: false,
  },
);

const emit = defineEmits<{
  'update:modelValue': [string];
  search: [string];
}>();

const internal = ref(props.modelValue);

const fire = useDebounceFn((value: string) => {
  emit('search', value);
}, props.debounceMs);

watch(internal, (value) => {
  emit('update:modelValue', value);
  fire(value);
});

watch(
  () => props.modelValue,
  (v) => {
    if (v !== internal.value) internal.value = v;
  },
);

function clear() {
  internal.value = '';
  emit('search', '');
}
</script>

<template>
  <div class="relative">
    <span
      class="absolute inset-y-0 left-3 flex items-center text-slate-400 pointer-events-none"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-4 h-4"
      >
        <circle cx="11" cy="11" r="8" />
        <line x1="21" y1="21" x2="16.65" y2="16.65" />
      </svg>
    </span>
    <input
      v-model="internal"
      type="search"
      :placeholder="placeholder"
      :autofocus="autofocus"
      class="w-full rounded-xl border border-slate-200 bg-white pl-9 pr-9 py-sm text-sm placeholder:text-slate-400 focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
    />
    <button
      v-if="internal"
      type="button"
      class="absolute inset-y-0 right-2 my-auto h-7 w-7 grid place-items-center text-slate-400 hover:text-slate-600"
      aria-label="Kosongkan pencarian"
      @click="clear"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-4 h-4"
      >
        <line x1="18" y1="6" x2="6" y2="18" />
        <line x1="6" y1="6" x2="18" y2="18" />
      </svg>
    </button>
  </div>
</template>
