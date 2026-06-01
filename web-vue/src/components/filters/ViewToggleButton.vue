<!--
  ViewToggleButton.vue — list/grid/matrix view switcher.
  Mirrors Flutter's ViewToggleButton in `lib/core/widgets/`.

  Two-option segmented control with icon + label.
-->
<script setup lang="ts">
export interface ViewOption {
  key: string;
  label: string;
  icon: 'list' | 'grid' | 'matrix' | 'calendar';
}

defineProps<{
  modelValue: string;
  options: ViewOption[];
}>();

defineEmits<{ 'update:modelValue': [string] }>();
</script>

<template>
  <div
    class="inline-flex rounded-xl bg-slate-100 p-0.5 text-sm"
    role="tablist"
  >
    <button
      v-for="opt in options"
      :key="opt.key"
      type="button"
      role="tab"
      :aria-selected="modelValue === opt.key"
      class="px-3 py-1.5 rounded-lg font-medium transition-colors inline-flex items-center gap-1.5"
      :class="
        modelValue === opt.key
          ? 'bg-white text-slate-900 shadow-sm'
          : 'text-slate-500 hover:text-slate-700'
      "
      @click="$emit('update:modelValue', opt.key)"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-3.5 h-3.5"
      >
        <template v-if="opt.icon === 'list'">
          <line x1="8" y1="6" x2="21" y2="6" />
          <line x1="8" y1="12" x2="21" y2="12" />
          <line x1="8" y1="18" x2="21" y2="18" />
          <line x1="3" y1="6" x2="3.01" y2="6" />
          <line x1="3" y1="12" x2="3.01" y2="12" />
          <line x1="3" y1="18" x2="3.01" y2="18" />
        </template>
        <template v-else-if="opt.icon === 'grid'">
          <rect x="3" y="3" width="7" height="7" />
          <rect x="14" y="3" width="7" height="7" />
          <rect x="14" y="14" width="7" height="7" />
          <rect x="3" y="14" width="7" height="7" />
        </template>
        <template v-else-if="opt.icon === 'matrix'">
          <line x1="3" y1="9" x2="21" y2="9" />
          <line x1="3" y1="15" x2="21" y2="15" />
          <line x1="9" y1="3" x2="9" y2="21" />
          <line x1="15" y1="3" x2="15" y2="21" />
        </template>
        <template v-else>
          <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
          <line x1="16" y1="2" x2="16" y2="6" />
          <line x1="8" y1="2" x2="8" y2="6" />
          <line x1="3" y1="10" x2="21" y2="10" />
        </template>
      </svg>
      {{ opt.label }}
    </button>
  </div>
</template>
