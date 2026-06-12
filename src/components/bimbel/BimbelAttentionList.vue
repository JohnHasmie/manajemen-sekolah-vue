<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

export interface AttentionItem {
  id: string | number;
  title: string;
  subtitle: string;
  severity: 'high' | 'medium' | 'low';
  onClick?: () => void;
}

defineProps<{
  items: AttentionItem[];
}>();

function getSeverityColor(severity: string) {
  switch (severity) {
    case 'high': return 'bg-bimbel-red';
    case 'medium': return 'bg-bimbel-amber';
    default: return 'bg-bimbel-text-mid';
  }
}
</script>

<template>
  <div class="bg-bimbel-panel border border-bimbel-border rounded-2xl flex flex-col overflow-hidden">
    <div class="px-5 py-4 border-b border-bimbel-border">
      <h3 class="text-base font-bold text-bimbel-text-hi">Perlu Perhatian</h3>
    </div>
    <div class="flex-1 overflow-y-auto">
      <div v-if="items.length === 0" class="p-8 text-center text-sm text-bimbel-text-lo">
        Tidak ada item yang perlu perhatian.
      </div>
      <div v-else class="divide-y divide-bimbel-border/50">
        <button
          v-for="item in items"
          :key="item.id"
          type="button"
          class="w-full text-left px-5 py-4 flex items-center justify-between hover:bg-white/5 transition-colors group"
          @click="item.onClick?.()"
        >
          <div class="flex items-start gap-3">
            <div class="mt-1.5 w-2 h-2 rounded-full shrink-0" :class="getSeverityColor(item.severity)"></div>
            <div>
              <div class="text-sm font-bold text-bimbel-text-hi">{{ item.title }}</div>
              <div class="text-xs font-medium text-bimbel-text-mid mt-0.5">{{ item.subtitle }}</div>
            </div>
          </div>
          <NavIcon name="chevron-right" :size="16" class="text-bimbel-text-lo group-hover:text-bimbel-text-hi transition-colors shrink-0 ml-4" />
        </button>
      </div>
    </div>
  </div>
</template>
