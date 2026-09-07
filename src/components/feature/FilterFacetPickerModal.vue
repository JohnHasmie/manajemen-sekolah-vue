<!--
  FilterFacetPickerModal.vue — small single/multi-select picker.

  Used by the per-facet AppFilterChip buttons in the Manajemen Data
  pages. The host provides the list of options + current selection;
  this modal renders the list with optional search, supports single
  (radio-like) or multi (checkbox) selection, and emits the new value
  on submit.

  SEARCH HAS TWO MODES, and the default is unchanged:

    • client-side (default) — the search box filters `options` in
      memory. Right for a facet whose whole domain is already loaded
      (a dozen programs, five statuses).

    • server-side (`server-search`) — the box stops filtering locally
      and every keystroke is emitted as `@search`, so the host can
      refetch. Right for a picker over a tenant-sized table (students),
      where a client filter over "the page we happened to load" quietly
      reports "no match" for a row that exists. Hosts in this mode
      should also pass `loading` and `empty-text` so an in-flight fetch
      and a genuinely empty result don't both render as blank space.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';

export interface FacetOption {
  /** Stable identifier passed back on submit. */
  key: string;
  label: string;
  /** Optional secondary line under the label (e.g. "Tingkat 7"). */
  meta?: string;
}

const props = withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    options: FacetOption[];
    /** Single-select active key (empty = "Semua"). */
    selected?: string;
    /** Multi-select active keys (only used when multi=true). */
    selectedKeys?: string[];
    multi?: boolean;
    /** Show a search input. Defaults true when >8 options. */
    showSearch?: boolean | null;
    /** Placeholder for the search input. */
    searchPlaceholder?: string;
    /**
     * Delegate filtering to the host: the local filter is switched off
     * and every keystroke is emitted as `search`. Implies the search
     * box is shown regardless of the option count — with a server-side
     * list, "fewer than 9 options right now" says nothing about how
     * many rows exist.
     */
    serverSearch?: boolean;
    /** Spinner row while the host refetches (server-search hosts). */
    loading?: boolean;
    /** Shown instead of the list when there is nothing to pick. */
    emptyText?: string;
    /** Label for the "Semua" reset button (empty selection). */
    allLabel?: string;
    /** Hide the "Semua" reset (when null=no-selection isn't meaningful). */
    hideAllReset?: boolean;
  }>(),
  {
    subtitle: '',
    selected: '',
    selectedKeys: () => [],
    multi: false,
    showSearch: null,
    searchPlaceholder: 'Cari...',
    serverSearch: false,
    loading: false,
    emptyText: '',
    allLabel: 'Semua',
    hideAllReset: false,
  },
);

const emit = defineEmits<{
  close: [];
  /** Single-select submit. */
  apply: [string];
  /** Multi-select submit. */
  applyMany: [string[]];
  /** Raw search text — only emitted when `serverSearch` is on. */
  search: [string];
}>();

const search = ref('');
const draftMulti = ref<Set<string>>(new Set(props.selectedKeys));

const shouldShowSearch = computed(() => {
  if (props.serverSearch) return true;
  if (props.showSearch === true) return true;
  if (props.showSearch === false) return false;
  return props.options.length > 8;
});

// Debouncing is the host's business (it owns the request); this only
// reports what was typed.
watch(search, (v) => {
  if (props.serverSearch) emit('search', v);
});

const filteredOptions = computed(() => {
  // In server-search mode `options` IS the answer to the current query
  // — filtering it again would drop rows the server matched on a field
  // this component never sees (a guardian's email, say).
  if (props.serverSearch) return props.options;
  const q = search.value.trim().toLowerCase();
  if (!q) return props.options;
  return props.options.filter(
    (o) =>
      o.label.toLowerCase().includes(q) ||
      (o.meta ?? '').toLowerCase().includes(q),
  );
});

function pickSingle(key: string) {
  emit('apply', key);
  emit('close');
}

function toggleMulti(key: string) {
  const set = new Set(draftMulti.value);
  if (set.has(key)) set.delete(key);
  else set.add(key);
  draftMulti.value = set;
}

function clearMulti() {
  draftMulti.value = new Set();
}

function submitMulti() {
  emit('applyMany', Array.from(draftMulti.value));
  emit('close');
}
</script>

<template>
  <Modal :title="title" :subtitle="subtitle" size="sm" @close="emit('close')">
    <div class="space-y-3">
      <input
        v-if="shouldShowSearch"
        v-model="search"
        type="search"
        data-testid="facet-picker-search"
        :placeholder="searchPlaceholder"
        class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
      />

      <p
        v-if="loading"
        data-testid="facet-picker-loading"
        class="px-3 py-2 text-[13px] font-bold text-slate-500"
      >
        Memuat…
      </p>
      <p
        v-else-if="emptyText && filteredOptions.length === 0"
        data-testid="facet-picker-empty"
        class="px-3 py-2 text-[13px] font-medium text-slate-500"
      >
        {{ emptyText }}
      </p>

      <!-- Single-select list -->
      <div v-if="!multi" class="space-y-1 max-h-[60vh] overflow-y-auto">
        <button
          v-if="!hideAllReset"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="
            selected === ''
              ? 'bg-role-admin/10 text-role-admin'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="pickSingle('')"
        >
          {{ allLabel }}
        </button>
        <button
          v-for="o in filteredOptions"
          :key="o.key"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="
            selected === o.key
              ? 'bg-role-admin/10 text-role-admin'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="pickSingle(o.key)"
        >
          {{ o.label }}
          <span
            v-if="o.meta"
            class="block text-3xs text-slate-500 font-medium mt-0.5"
          >{{ o.meta }}</span>
        </button>
      </div>

      <!-- Multi-select list -->
      <template v-else>
        <div class="flex items-center justify-between text-2xs font-bold">
          <span class="text-slate-700">
            {{ draftMulti.size }} dipilih
          </span>
          <button
            v-if="draftMulti.size > 0"
            type="button"
            class="text-role-admin hover:underline"
            @click="clearMulti"
          >
            Bersihkan
          </button>
        </div>
        <div class="max-h-[55vh] overflow-y-auto bg-slate-50 rounded-xl divide-y divide-slate-100">
          <label
            v-for="o in filteredOptions"
            :key="o.key"
            class="flex items-center gap-2 px-3 py-2 cursor-pointer hover:bg-white"
          >
            <input
              type="checkbox"
              class="w-4 h-4 accent-role-admin"
              :checked="draftMulti.has(o.key)"
              @change="toggleMulti(o.key)"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">{{ o.label }}</p>
              <p v-if="o.meta" class="text-3xs text-slate-500">{{ o.meta }}</p>
            </div>
          </label>
        </div>
        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="emit('close')">Batal</Button>
          <Button variant="primary" block @click="submitMulti">
            Terapkan
          </Button>
        </div>
      </template>
    </div>
  </Modal>
</template>
