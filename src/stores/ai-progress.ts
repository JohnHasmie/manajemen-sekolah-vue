import { defineStore } from 'pinia';
import { ref } from 'vue';

export const useAiProgressStore = defineStore('ai-progress', () => {
  const isProcessing = ref(false);
  const message = ref<string | null>(null);
  const totalJobs = ref(0);
  const completedJobs = ref(0);

  function startProcess(msg: string, total: number = 0) {
    isProcessing.value = true;
    message.value = msg;
    totalJobs.value = total;
    completedJobs.value = 0;
  }

  function updateProgress(msg: string, completed: number, total?: number) {
    message.value = msg;
    completedJobs.value = completed;
    if (total !== undefined) {
      totalJobs.value = total;
    }
  }

  function finishProcess() {
    isProcessing.value = false;
    message.value = null;
    totalJobs.value = 0;
    completedJobs.value = 0;
  }

  return {
    isProcessing,
    message,
    totalJobs,
    completedJobs,
    startProcess,
    updateProgress,
    finishProcess,
  };
});
