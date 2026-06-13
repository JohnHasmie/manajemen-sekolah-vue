<!--
  ParentChildPickerChip — small avatar+name chip in the top-right
  corner of every parent page hero. Tap → opens dropdown to switch
  active child. Backed by useChildPicker().
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useChildPicker } from '@/composables/useChildPicker';

const { children, activeChildId, setActive } = useChildPicker();
const open = ref(false);

const active = computed(() =>
  children.value.find((c) => c.student_id === activeChildId.value) ?? null,
);

function initial(name?: string | null): string {
  if (!name) return '?';
  return name.trim()[0]?.toUpperCase() ?? '?';
}

function pick(id: string) {
  setActive(id);
  open.value = false;
}
</script>

<template>
  <div class="relative">
    <button
      type="button"
      class="inline-flex items-center gap-2 rounded-full bg-white/15 px-2.5 py-1 text-[12px] font-semibold ring-1 ring-white/20 hover:bg-white/22"
      @click="open = !open"
    >
      <span
        class="grid h-5 w-5 place-items-center rounded-full bg-white/25 text-[10px] font-bold"
      >
        {{ initial(active?.name) }}
      </span>
      <span class="truncate max-w-[140px]">{{ active?.name ?? 'Pilih anak' }}</span>
      <svg class="h-3 w-3 opacity-80" viewBox="0 0 12 12" fill="currentColor"><path d="M6 8L2 4h8z"/></svg>
    </button>
    <div
      v-if="open && children.length > 1"
      class="absolute right-0 z-30 mt-2 w-56 rounded-xl border border-bimbel-border bg-bimbel-panel p-1 shadow-lg"
    >
      <button
        v-for="c in children"
        :key="c.student_id"
        type="button"
        class="flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-[12.5px] text-bimbel-text-hi hover:bg-bimbel-border-soft"
        :class="{ 'bg-bimbel-accent-dim': c.student_id === activeChildId }"
        @click="pick(c.student_id)"
      >
        <span class="grid h-6 w-6 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent text-[10px] font-bold">
          {{ initial(c.name) }}
        </span>
        <span class="truncate">{{ c.name }}</span>
      </button>
    </div>
  </div>
</template>
