<!--
  StreakFlameKpi.vue — current streak in days + longest as sub-text.
  Uses the same tile shape as AttendanceMiniKpi so the two live
  happily side-by-side on the hub.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  current: number;
  longest: number;
  /** Show as a raised card (default) vs a flat inline tile. */
  variant?: 'card' | 'flat';
}>();
</script>

<template>
  <div
    class="rounded-2xl p-4 flex items-center gap-3"
    :class="variant === 'flat'
      ? 'bg-orange-50 border border-orange-100'
      : 'bg-white border border-slate-100 shadow-sm'"
  >
    <div class="w-11 h-11 rounded-xl bg-orange-500/10 text-orange-600 grid place-items-center flex-shrink-0">
      <NavIcon name="flame" :size="22" />
    </div>
    <div class="min-w-0">
      <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Beruntun</p>
      <p class="text-xl font-black text-slate-900 leading-none mt-0.5">
        {{ current }}<span class="text-sm text-slate-500 font-bold ml-1">hari</span>
      </p>
      <p class="text-2xs text-slate-500 mt-1">
        Terpanjang: <span class="font-bold text-slate-700">{{ longest }} hari</span>
      </p>
    </div>
  </div>
</template>
