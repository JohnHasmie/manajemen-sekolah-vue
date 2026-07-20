<!--
  AdminEngagementSkeleton.vue — placeholder for the initial fetch of
  the /admin/teacher-engagement + /admin/staff-engagement views. Mirrors
  the real layout box-for-box so the page doesn't shift when the
  payload lands:

    · two highlight cards (2-col grid)
    · 4-up KPI strip
    · weekly-activity bar-chart card
    · table (2/3) + aside (SleepyCard + Top-3)

  Kept dumb — one component, no props. Both engagement views share it,
  so future admin engagement surfaces (e.g. by cohort) get free reuse.
-->
<script setup lang="ts">
import Skeleton from '@/components/data/Skeleton.vue';
</script>

<template>
  <div class="space-y-md pb-12" aria-busy="true">
    <!-- Two highlight cards (mirror GamificationHighlightCard 2-col grid). -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div
        v-for="i in 2"
        :key="`h-${i}`"
        class="rounded-2xl bg-white border border-slate-100 shadow-sm p-5 space-y-3"
      >
        <div class="flex items-center gap-3">
          <Skeleton shape="rect" class="w-11 h-11" />
          <div class="flex-1 space-y-2">
            <Skeleton class="h-2 w-20" />
            <Skeleton class="h-4 w-40" />
          </div>
        </div>
        <Skeleton class="h-3 w-full" />
        <Skeleton class="h-3 w-4/5" />
        <div class="pt-1">
          <Skeleton class="h-8 w-32 rounded-lg" />
        </div>
      </div>
    </div>

    <!-- 4-up KPI strip (mirror KpiStripCards). -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div
        v-for="i in 4"
        :key="`k-${i}`"
        class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 space-y-2"
      >
        <div class="flex items-center gap-2">
          <Skeleton shape="rect" class="w-8 h-8" />
          <Skeleton class="h-3 w-20" />
        </div>
        <Skeleton class="h-6 w-16" />
      </div>
    </div>

    <!-- Weekly bar chart card (mirror WeeklyActivityBars container). -->
    <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 sm:p-5">
      <div class="flex items-center gap-2 mb-4">
        <Skeleton shape="rect" class="w-7 h-7" />
        <Skeleton class="h-3 w-40" />
      </div>
      <div class="flex items-end gap-2 h-28">
        <div
          v-for="(h, i) in [60, 78, 42, 88, 65, 30, 55]"
          :key="`b-${i}`"
          class="flex-1"
        >
          <Skeleton shape="rect" :style="{ height: `${h}%` }" class="w-full" />
        </div>
      </div>
    </div>

    <!-- Table (2/3) + aside (1/3). -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <div class="lg:col-span-2 space-y-3 min-w-0">
        <!-- Filter toolbar row. -->
        <div class="flex items-center gap-2">
          <Skeleton class="h-9 w-56 rounded-xl" />
          <Skeleton class="h-9 w-32 rounded-xl" />
          <Skeleton class="h-9 w-32 rounded-xl" />
        </div>
        <!-- Table body — 6 person rows. -->
        <div class="rounded-2xl bg-white border border-slate-100 shadow-sm divide-y divide-slate-100">
          <div
            v-for="i in 6"
            :key="`r-${i}`"
            class="flex items-center gap-3 px-4 py-3"
          >
            <Skeleton shape="circle" class="w-9 h-9" />
            <div class="flex-1 min-w-0 space-y-2">
              <Skeleton class="h-3 w-40" />
              <Skeleton class="h-2 w-24" />
            </div>
            <Skeleton class="h-3 w-14 hidden sm:block" />
            <Skeleton class="h-3 w-10 hidden md:block" />
            <Skeleton class="h-6 w-16 rounded-full" />
          </div>
        </div>
      </div>

      <aside class="space-y-4 min-w-0">
        <!-- Sleepy card. -->
        <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 space-y-3">
          <div class="flex items-center gap-2">
            <Skeleton shape="rect" class="w-7 h-7" />
            <Skeleton class="h-3 w-32" />
          </div>
          <Skeleton class="h-2 w-4/5" />
          <div v-for="i in 3" :key="`s-${i}`" class="flex items-center gap-3">
            <Skeleton shape="circle" class="w-7 h-7" />
            <Skeleton class="h-3 flex-1" />
          </div>
          <Skeleton class="h-8 w-full rounded-lg" />
        </div>

        <!-- Top 3 mini list. -->
        <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 space-y-3">
          <Skeleton class="h-2 w-24" />
          <div v-for="i in 3" :key="`t-${i}`" class="flex items-center gap-3">
            <Skeleton class="h-3 w-4" />
            <Skeleton class="h-3 flex-1" />
            <Skeleton class="h-3 w-10" />
          </div>
        </div>
      </aside>
    </div>
  </div>
</template>
