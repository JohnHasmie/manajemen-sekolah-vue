<!--
  AcademicYearChip.vue — compact tahun-ajaran chip rendered on every
  dashboard hero (and beside any role-coloured header that wants it).
  Web port of Flutter's `lib/core/widgets/academic_year_chip.dart`.

  Two visual variants:
    - `variant="dark"` (default) — translucent-white pill for dark
      gradient surfaces (BrandPageHeader, dashboard hero).
    - `variant="light"` — slate pill for light surfaces.

  Tap → emits `open`. Mount AcademicYearPickerModal on a sibling and
  bind a `v-model` to its `open` prop.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useAcademicYearStore } from '@/stores/academic-year';
import NavIcon from '@/components/feature/NavIcon.vue';

withDefaults(
  defineProps<{
    variant?: 'dark' | 'light';
    /** Override min-width (px). Default fits next to a SchoolPill. */
    minWidth?: number;
  }>(),
  { variant: 'dark', minWidth: 132 },
);

defineEmits<{ open: [] }>();

const store = useAcademicYearStore();
const yearLabel = computed(() => store.yearLabel);
const semesterLabel = computed(() => store.semesterLabel);
</script>

<template>
  <button
    type="button"
    class="inline-flex items-center gap-2 rounded-2xl px-3 py-1.5 transition-colors text-left"
    :class="[
      variant === 'dark'
        ? 'bg-white/25 border border-white/35 hover:bg-white/35 text-white'
        : 'bg-slate-100 border border-slate-200 hover:bg-slate-200 text-slate-900',
    ]"
    :style="{ minWidth: `${minWidth}px` }"
    :aria-label="`Tahun ajaran ${yearLabel}, klik untuk ganti`"
    @click="$emit('open')"
  >
    <span
      class="w-7 h-7 rounded-lg grid place-items-center flex-shrink-0"
      :class="
        variant === 'dark'
          ? 'bg-white/20 text-white'
          : 'bg-brand-cobalt/10 text-brand-cobalt'
      "
    >
      <NavIcon name="calendar" :size="14" />
    </span>
    <span class="flex flex-col min-w-0 leading-none flex-1">
      <span
        class="text-[9px] font-bold uppercase tracking-widest"
        :class="variant === 'dark' ? 'text-white/80' : 'text-slate-400'"
      >
        Tahun Ajaran
      </span>
      <span class="flex items-center gap-1 mt-0.5">
        <span
          class="text-[13px] font-black truncate"
          :class="variant === 'dark' ? 'text-white' : 'text-slate-900'"
        >
          {{ yearLabel }}
        </span>
        <span
          v-if="semesterLabel"
          class="text-[10px] font-bold truncate"
          :class="variant === 'dark' ? 'text-white/75' : 'text-slate-500'"
        >
          · {{ semesterLabel }}
        </span>
      </span>
    </span>
    <NavIcon
      name="chevron-down"
      :size="12"
      :class="variant === 'dark' ? 'text-white/70' : 'text-slate-400'"
    />
  </button>
</template>
