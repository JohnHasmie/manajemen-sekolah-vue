<script setup lang="ts">
export interface SessionItem {
  id: string | number;
  time: string;
  title: string;
  subtitle: string;
  actionLabel?: string;
  onActionClick?: () => void;
}

defineProps<{
  items: SessionItem[];
}>();
</script>

<template>
  <div class="bg-bimbel-panel border border-bimbel-border rounded-2xl flex flex-col overflow-hidden">
    <div class="px-5 py-4 border-b border-bimbel-border flex justify-between items-center">
      <h3 class="text-base font-bold text-bimbel-text-hi">Sesi Hari Ini</h3>
      <button type="button" class="text-xs font-bold text-bimbel-accent hover:text-bimbel-accent-soft transition-colors">Lihat Semua</button>
    </div>
    <div class="flex-1 overflow-y-auto">
      <div v-if="items.length === 0" class="p-8 text-center text-sm text-bimbel-text-lo">
        Tidak ada sesi hari ini.
      </div>
      <div v-else class="divide-y divide-bimbel-border/50">
        <div
          v-for="item in items"
          :key="item.id"
          class="px-5 py-4 flex items-center justify-between hover:bg-white/5 transition-colors"
        >
          <div class="flex items-center gap-4">
            <div class="w-14 text-center">
              <span class="inline-block px-2 py-1 rounded-md bg-bimbel-accent/10 text-bimbel-accent font-black text-xs">{{ item.time }}</span>
            </div>
            <div>
              <div class="text-sm font-bold text-bimbel-text-hi">{{ item.title }}</div>
              <div class="text-xs font-medium text-bimbel-text-mid mt-0.5">{{ item.subtitle }}</div>
            </div>
          </div>
          <button
            v-if="item.actionLabel"
            type="button"
            class="px-3 py-1.5 rounded-lg bg-bimbel-accent text-white text-xs font-bold shadow-sm shadow-bimbel-accent/20 hover:bg-bimbel-accent-soft transition-colors shrink-0"
            @click="item.onActionClick?.()"
          >
            {{ item.actionLabel }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
