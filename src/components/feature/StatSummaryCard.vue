<!--
  StatSummaryCard.vue - small KPI card for dashboard grids.
  Mirrors Flutter's HeroStatsCard from
  lib/core/widgets/brand_kpi_carousel.dart + HeroStatsCard widget.

  Carousel support:
    - slices: total number of slices the carousel cycles through
    - activeSlice: 0-indexed current slice (drives the progress strip)
    - sliceProgress: 0..1 fill of the active slice's bar
    - sliceLabel: small chip rendered above the value ("Hari Ini", "7A", ...)
    - sliceLabelMuted: when true, label renders as muted (used for the
      synthesised "Mengajar" / "all" aggregate slice)
    - trend: optional { direction, label } chip rendered next to the value
      (matches the attendance-delta chip on Flutter)
-->
<script setup lang="ts">
import NavIcon from './NavIcon.vue';

export interface StatTrend {
  direction: 'up' | 'down' | 'flat';
  label: string;
}

withDefaults(
  defineProps<{
    label: string;
    value: string | number;
    tone?: 'brand' | 'success' | 'warning' | 'danger' | 'info' | 'slate';
    icon?: string;
    iconName?: string;
    sublabel?: string;
    /** Carousel props - mirror Flutter's HeroStatsCard story timer. */
    slices?: number;
    activeSlice?: number;
    sliceProgress?: number;
    sliceLabel?: string;
    sliceLabelMuted?: boolean;
    trend?: StatTrend | null;
  }>(),
  {
    tone: 'slate',
    icon: '',
    iconName: '',
    sublabel: '',
    slices: 1,
    activeSlice: 0,
    sliceProgress: 0,
    sliceLabel: '',
    sliceLabelMuted: false,
    trend: null,
  },
);
</script>

<template>
  <div
    class="bg-white rounded-3xl p-5 border border-slate-100 hover:border-brand-cobalt/30 hover:shadow-xl hover:shadow-brand-cobalt/5 transition-all group flex flex-col gap-4 cursor-pointer relative overflow-hidden"
  >
    <!-- Progress slices (stories style) -->
    <div v-if="slices > 1" class="absolute top-2 left-5 right-5 flex gap-1 h-1">
      <div
        v-for="i in slices"
        :key="i"
        class="flex-1 rounded-full overflow-hidden"
        :class="i - 1 < activeSlice ? 'bg-brand-cobalt' : 'bg-slate-100'"
      >
        <div
          v-if="i - 1 === activeSlice"
          class="h-full bg-brand-cobalt transition-all duration-100 ease-linear"
          :style="{ width: `${sliceProgress * 100}%` }"
        ></div>
      </div>
    </div>

    <div
      class="w-12 h-12 rounded-2xl flex items-center justify-center transition-colors shadow-sm"
      :class="{
        'bg-brand-cobalt/10 text-brand-cobalt group-hover:bg-brand-cobalt group-hover:text-white':
          tone === 'brand',
        'bg-status-success-soft text-status-success': tone === 'success',
        'bg-status-warning-soft text-status-warning': tone === 'warning',
        'bg-status-danger-soft text-status-danger': tone === 'danger',
        'bg-status-info-soft text-status-info group-hover:bg-brand-azure group-hover:text-white':
          tone === 'info',
        'bg-slate-50 text-slate-400 group-hover:bg-slate-900 group-hover:text-white':
          tone === 'slate',
      }"
    >
      <slot name="icon">
        <NavIcon v-if="iconName" :name="iconName" :size="24" />
        <span v-else class="text-xl">{{ icon }}</span>
      </slot>
    </div>

    <div class="space-y-1">
      <div class="flex items-center gap-2 flex-wrap">
        <p
          class="text-2xs font-black uppercase tracking-widest leading-none"
          :class="sliceLabelMuted ? 'text-slate-300' : 'text-slate-400'"
        >
          {{ label }}
        </p>
        <span
          v-if="sliceLabel"
          class="text-4xs font-black uppercase tracking-widest leading-none px-1.5 py-0.5 rounded-md"
          :class="
            sliceLabelMuted
              ? 'bg-slate-50 text-slate-400'
              : 'bg-brand-cobalt/10 text-brand-cobalt'
          "
        >
          {{ sliceLabel }}
        </span>
      </div>

      <div class="flex items-baseline gap-2">
        <p class="text-2xl font-black text-slate-900 tracking-tight">
          {{ value }}
        </p>
        <span
          v-if="trend"
          class="text-3xs font-black uppercase tracking-wider px-1.5 py-0.5 rounded-md inline-flex items-center gap-0.5"
          :class="{
            'bg-emerald-50 text-emerald-700': trend.direction === 'up',
            'bg-red-50 text-red-700': trend.direction === 'down',
            'bg-slate-50 text-slate-500': trend.direction === 'flat',
          }"
        >
          <span aria-hidden="true">
            {{
              trend.direction === 'up'
                ? '▲'
                : trend.direction === 'down'
                  ? '▼'
                  : '▬'
            }}
          </span>
          {{ trend.label }}
        </span>
      </div>

      <p
        v-if="sublabel"
        class="text-2xs font-bold text-slate-400 mt-2 flex items-center gap-1 group-hover:text-brand-cobalt transition-colors"
      >
        {{ sublabel }}
        <NavIcon name="megaphone" :size="10" />
      </p>
    </div>
  </div>
</template>
