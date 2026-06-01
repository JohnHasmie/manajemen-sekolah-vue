<!--
  BulkActionBar.vue — floating action bar shown when items are selected.
  Mirrors Flutter's BulkActionBar in `lib/core/widgets/`.
  Slots: actions (right-aligned buttons), leading (left of count)
-->
<script setup lang="ts">
defineProps<{
  selectedCount: number;
  show: boolean;
}>();

defineEmits<{ clear: [] }>();
</script>

<template>
  <Transition
    enter-active-class="transition-transform duration-200 ease-out"
    enter-from-class="translate-y-full"
    enter-to-class="translate-y-0"
    leave-active-class="transition-transform duration-150 ease-in"
    leave-from-class="translate-y-0"
    leave-to-class="translate-y-full"
  >
    <div
      v-if="show && selectedCount > 0"
      class="fixed bottom-md inset-x-md sm:inset-x-auto sm:right-md sm:max-w-2xl sm:left-1/2 sm:-translate-x-1/2 z-40 form-card p-sm sm:p-md flex items-center gap-md shadow-card"
    >
      <button
        type="button"
        class="rounded-md hover:bg-slate-100 p-1.5"
        aria-label="Batalkan pilihan"
        @click="$emit('clear')"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="w-4 h-4 text-slate-600"
        >
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
      <p class="text-sm font-medium text-slate-900 flex-1 min-w-0 truncate">
        <slot name="leading" />
        {{ selectedCount }} item dipilih
      </p>
      <div class="flex items-center gap-2 flex-shrink-0">
        <slot name="actions" />
      </div>
    </div>
  </Transition>
</template>
