<!--
  AdminDataMenu.vue — shared admin manajemen-data overflow menu.

  Mirrors Flutter's `AdminDataMenu` widget. Sits in the header of
  Student / Teacher / Kelas / Mapel pages and surfaces 4 actions:
    Refresh · Export Excel · Import Excel · Unduh Template

  Each emits its action; the host wires the actual service call.
  Items can be disabled when AY is read-only by passing
  `read-only="true"`.
-->
<script setup lang="ts">
import { ref } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  /** When true, edits are hidden — only Refresh + downloads enabled. */
  readOnly?: boolean;
}>();

const emit = defineEmits<{
  refresh: [];
  exportExcel: [];
  importExcel: [];
  downloadTemplate: [];
}>();

const open = ref(false);

function close() {
  open.value = false;
}

function trigger(action: 'refresh' | 'exportExcel' | 'importExcel' | 'downloadTemplate') {
  close();
  if (action === 'refresh') emit('refresh');
  else if (action === 'exportExcel') emit('exportExcel');
  else if (action === 'importExcel') emit('importExcel');
  else emit('downloadTemplate');
}
</script>

<template>
  <div class="relative inline-block">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[11px] font-bold text-slate-700 hover:text-role-admin px-3 py-1.5 rounded-lg bg-white border border-slate-200 hover:border-role-admin/40 transition-colors"
      @click="open = !open"
    >
      <NavIcon name="more-vertical" :size="12" />
      Menu
    </button>

    <!-- Backdrop -->
    <div
      v-if="open"
      class="fixed inset-0 z-40"
      @click="close"
    ></div>

    <!-- Dropdown -->
    <div
      v-if="open"
      class="absolute right-0 mt-2 w-56 bg-white border border-slate-200 rounded-2xl shadow-xl z-50 overflow-hidden"
    >
      <button
        type="button"
        class="w-full text-left px-3 py-2.5 flex items-center gap-2 hover:bg-slate-50 text-[12px] font-bold text-slate-700"
        @click="trigger('refresh')"
      >
        <NavIcon name="refresh-cw" :size="13" class="text-role-admin" />
        Refresh
      </button>
      <button
        type="button"
        class="w-full text-left px-3 py-2.5 flex items-center gap-2 hover:bg-slate-50 text-[12px] font-bold text-slate-700 border-t border-slate-100"
        @click="trigger('exportExcel')"
      >
        <NavIcon name="download" :size="13" class="text-emerald-600" />
        Export Excel
      </button>
      <button
        type="button"
        class="w-full text-left px-3 py-2.5 flex items-center gap-2 hover:bg-slate-50 text-[12px] font-bold text-slate-700 border-t border-slate-100 disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="readOnly"
        @click="trigger('importExcel')"
      >
        <NavIcon name="upload" :size="13" class="text-amber-600" />
        Import Excel
      </button>
      <button
        type="button"
        class="w-full text-left px-3 py-2.5 flex items-center gap-2 hover:bg-slate-50 text-[12px] font-bold text-slate-700 border-t border-slate-100"
        @click="trigger('downloadTemplate')"
      >
        <NavIcon name="file-text" :size="13" class="text-slate-500" />
        Unduh Template
      </button>
    </div>
  </div>
</template>
