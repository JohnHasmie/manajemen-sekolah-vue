<!--
  ParentChildPickerChip — small avatar+name chip in the top-right
  corner of every parent page hero. Tap → opens dropdown to switch
  active child. Backed by useChildPicker().

  When the parent has 0 children loaded, the chip flips to a "List
  anak" affordance that opens the enroll wizard instead of a dead
  dropdown.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useChildPicker } from '@/composables/useChildPicker';

const router = useRouter();
const route = useRoute();
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
  // When the current route is pinned to a specific child via :studentId,
  // route.params.studentId always wins over activeChildId in the page
  // computeds — so swapping activeChildId alone leaves the data frozen
  // on the old child. Push the same route with the new studentId so the
  // page reloads. Routes without :studentId (profile, appearance, etc.)
  // pick up activeChildId directly and don't need a navigation.
  if (route.params.studentId && route.params.studentId !== id) {
    router.push({
      name: route.name as string,
      params: { ...route.params, studentId: id },
      query: route.query,
    });
  }
}

function onChipClick() {
  if (children.value.length === 0) {
    router.push({ name: 'parent.tutoring.register-lead' });
    return;
  }
  open.value = !open.value;
}
</script>

<template>
  <div class="relative">
    <button
      type="button"
      class="inline-flex items-center gap-2 rounded-full bg-white/15 px-2.5 py-1 text-[13px] font-semibold ring-1 ring-white/20 hover:bg-white/22"
      @click="onChipClick"
    >
      <span
        class="grid h-5 w-5 place-items-center rounded-full bg-white/25 text-[13px] font-bold"
      >
        {{ initial(active?.name) }}
      </span>
      <span class="truncate max-w-[140px]">
        {{ children.length === 0
            ? 'Daftar anak'
            : (active?.name ?? 'Pilih anak') }}
      </span>
      <svg class="h-3 w-3 opacity-80" viewBox="0 0 12 12" fill="currentColor"><path d="M6 8L2 4h8z"/></svg>
    </button>
    <div
      v-if="open && children.length > 0"
      class="absolute right-0 z-30 mt-2 w-56 rounded-xl border border-tutoring-border bg-tutoring-panel p-1 shadow-lg"
    >
      <button
        v-for="c in children"
        :key="c.student_id"
        type="button"
        class="flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-[14px] text-tutoring-text-hi hover:bg-tutoring-border-soft"
        :class="{ 'bg-tutoring-accent-dim': c.student_id === activeChildId }"
        @click="pick(c.student_id)"
      >
        <span class="grid h-6 w-6 place-items-center rounded-full bg-tutoring-accent-dim text-tutoring-accent text-[13px] font-bold">
          {{ initial(c.name) }}
        </span>
        <span class="truncate">{{ c.name }}</span>
      </button>
    </div>
  </div>
</template>
