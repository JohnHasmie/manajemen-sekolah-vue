<!--
  AttendanceMiniKpi.vue — 4 white-on-gradient KPI tiles.

  Used by the parent calendar screen header to show per-month
  breakdown (Hadir / Izin / Sakit / Alpa) on top of the brand
  gradient banner.
-->
<script setup lang="ts">
defineProps<{
  hadir: number;
  izin: number;
  sakit: number;
  alpha: number;
}>();
</script>

<template>
  <div class="grid grid-cols-4 gap-2">
    <div class="bg-white/15 rounded-xl px-2 py-2 text-white">
      <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">Hadir</p>
      <p class="text-[15px] font-black mt-0.5">{{ hadir }}</p>
    </div>
    <div class="bg-white/15 rounded-xl px-2 py-2 text-white">
      <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">Izin</p>
      <p class="text-[15px] font-black mt-0.5">{{ izin }}</p>
    </div>
    <div class="bg-white/15 rounded-xl px-2 py-2 text-white">
      <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">Sakit</p>
      <p class="text-[15px] font-black mt-0.5">{{ sakit }}</p>
    </div>
    <div class="bg-white/15 rounded-xl px-2 py-2 text-white">
      <p class="text-[9px] font-bold text-white/70 uppercase tracking-widest">Alpa</p>
      <p class="text-[15px] font-black mt-0.5">{{ alpha }}</p>
    </div>
  </div>
</template>
