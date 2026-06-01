<!--
  Pagination.vue — page navigation strip.
  Mirrors Flutter's PaginationWidget — shows page numbers (with ellipsis)
  and prev/next buttons. Consumes the Pagination type from the Laravel
  envelope (`@/types/api`).
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { Pagination } from '@/types/api';

const props = defineProps<{ pagination: Pagination }>();
const emit = defineEmits<{ change: [page: number] }>();

const pages = computed(() => {
  const total = props.pagination.total_pages;
  const current = props.pagination.current_page;
  const out: (number | '…')[] = [];

  const push = (n: number | '…') => {
    if (out[out.length - 1] === n) return;
    out.push(n);
  };

  push(1);
  if (current - 2 > 2) push('…');
  for (let p = Math.max(2, current - 1); p <= Math.min(total - 1, current + 1); p += 1) {
    push(p);
  }
  if (current + 2 < total - 1) push('…');
  if (total > 1) push(total);
  return out;
});

function go(n: number) {
  if (n < 1 || n > props.pagination.total_pages) return;
  if (n === props.pagination.current_page) return;
  emit('change', n);
}
</script>

<template>
  <nav
    class="flex items-center justify-between gap-md text-sm"
    aria-label="Pagination"
  >
    <p class="text-xs text-slate-500">
      Halaman {{ pagination.current_page }} dari {{ pagination.total_pages }}
      ({{ pagination.total_items }} item)
    </p>

    <div class="flex items-center gap-1">
      <button
        type="button"
        class="px-2 py-1 rounded-md text-slate-600 hover:bg-slate-100 disabled:opacity-40 disabled:cursor-not-allowed"
        :disabled="!pagination.has_prev_page"
        @click="go(pagination.current_page - 1)"
      >
        ‹
      </button>

      <template v-for="(p, idx) in pages" :key="`${p}-${idx}`">
        <span v-if="p === '…'" class="px-2 text-slate-400">…</span>
        <button
          v-else
          type="button"
          class="px-2.5 py-1 rounded-md font-medium"
          :class="
            p === pagination.current_page
              ? 'bg-brand text-white'
              : 'text-slate-600 hover:bg-slate-100'
          "
          @click="go(p)"
        >
          {{ p }}
        </button>
      </template>

      <button
        type="button"
        class="px-2 py-1 rounded-md text-slate-600 hover:bg-slate-100 disabled:opacity-40 disabled:cursor-not-allowed"
        :disabled="!pagination.has_next_page"
        @click="go(pagination.current_page + 1)"
      >
        ›
      </button>
    </div>
  </nav>
</template>
