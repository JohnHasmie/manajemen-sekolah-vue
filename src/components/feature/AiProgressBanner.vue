<script setup lang="ts">
import { computed } from 'vue';
import { useAiProgressStore } from '@/stores/ai-progress';
import NavIcon from '@/components/feature/NavIcon.vue';

const store = useAiProgressStore();

const progressPercentage = computed(() => {
  if (store.totalJobs === 0) return 100;
  // If no jobs completed yet, let's at least show a small sliver of progress (e.g., 5%)
  // to indicate it's working, otherwise just the exact percentage.
  const percentage = Math.round((store.completedJobs / store.totalJobs) * 100);
  return percentage === 0 ? 5 : percentage;
});
</script>

<template>
  <Transition
    enter-active-class="transition-all duration-300 ease-out"
    enter-from-class="translate-y-4 opacity-0"
    enter-to-class="translate-y-0 opacity-100"
    leave-active-class="transition-all duration-200 ease-in"
    leave-from-class="translate-y-0 opacity-100"
    leave-to-class="translate-y-4 opacity-0"
  >
    <div
      v-if="store.isProcessing && store.message"
      class="fixed bottom-6 left-1/2 -translate-x-1/2 z-[100] w-[90%] max-w-sm"
    >
      <!-- Modern Glassmorphism Pill -->
      <div
        class="bg-white/80 dark:bg-slate-800/90 backdrop-blur-xl shadow-[0_8px_30px_rgb(0,0,0,0.12)] dark:shadow-[0_8px_30px_rgb(0,0,0,0.5)] border border-slate-200/50 dark:border-slate-700/50 rounded-2xl overflow-hidden flex flex-col"
      >
        <div class="px-4 py-3 flex items-center gap-3">
          <!-- Icon Container with subtle pulse -->
          <div class="w-8 h-8 rounded-full bg-violet-100 dark:bg-violet-500/20 text-violet-600 dark:text-violet-300 flex items-center justify-center flex-shrink-0 relative">
            <span class="absolute inset-0 rounded-full border-2 border-violet-500/30 animate-ping opacity-75"></span>
            <NavIcon name="sparkles" :size="16" class="animate-pulse" />
          </div>
          
          <!-- Message text -->
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-semibold text-slate-800 dark:text-slate-100 truncate leading-snug">
              {{ store.message }}
            </p>
            <p v-if="store.totalJobs > 0" class="text-2xs text-slate-500 dark:text-slate-400 font-medium">
              Sedang memproses ({{ store.completedJobs }}/{{ store.totalJobs }})
            </p>
          </div>
          
          <NavIcon name="loader" :size="16" class="animate-spin flex-shrink-0 text-violet-500" />
        </div>
        
        <!-- Progress Bar at bottom of pill -->
        <div v-if="store.totalJobs > 0" class="h-1 bg-slate-100 dark:bg-slate-700/50 w-full relative overflow-hidden">
          <div
            class="absolute top-0 left-0 h-full bg-gradient-to-r from-violet-500 to-fuchsia-500 transition-all duration-500 ease-out rounded-r-full"
            :style="{ width: `${progressPercentage}%` }"
          >
            <!-- Highlight glow for progress bar -->
            <div class="absolute inset-0 bg-white/20"></div>
          </div>
        </div>
        <!-- Indeterminate progress bar if total is 0 -->
        <div v-else class="h-1 bg-slate-100 dark:bg-slate-700/50 w-full overflow-hidden relative">
          <div class="absolute top-0 h-full bg-gradient-to-r from-violet-500 to-fuchsia-500 w-1/3 animate-[progress-indeterminate_1.5s_infinite_linear]"></div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
@keyframes progress-indeterminate {
  0% { left: -35%; }
  100% { left: 100%; }
}
</style>
