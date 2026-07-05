<!--
  PriorityInbox.vue — the "Perlu Perhatian" section for the Teacher Dashboard.
  Mirrors Flutter's `PendingInboxCard.priorityItems`.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NavIcon from './NavIcon.vue';

const { t, locale } = useI18n();

export interface PriorityItem {
  id: string;
  type: string;
  severity: 'critical' | 'warning' | 'info';
  label: string;
  subtitle: string;
  count: number;
  occurred_at: string;
  target_route: string;
  target_params: Record<string, any>;
}

const props = withDefaults(defineProps<{
  items: PriorityItem[];
  isLoading?: boolean;
  showHeader?: boolean;
}>(), {
  showHeader: true
});

defineEmits<{
  (e: 'itemTap', item: PriorityItem): void;
  (e: 'seeAll'): void;
}>();

const formatRelativeTime = (dateStr: string) => {
  const date = new Date(dateStr);
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const mins = Math.floor(diff / 60000);
  const hours = Math.floor(mins / 60);
  const days = Math.floor(hours / 24);

  if (mins < 1) return t('inbox.justNow');
  if (mins < 60) return t('inbox.minutesAgo', { n: mins });
  if (hours < 24) return t('inbox.hoursAgo', { n: hours });
  if (days < 7) return t('inbox.daysAgo', { n: days });
  return date.toLocaleDateString(locale.value === 'en' ? 'en-US' : 'id-ID', {
    day: '2-digit',
    month: '2-digit',
  });
};

const getSeverityColor = (severity: string) => {
  switch (severity) {
    case 'critical': return 'bg-status-danger text-status-danger';
    case 'warning': return 'bg-status-warning text-status-warning';
    default: return 'bg-brand-cobalt text-brand-cobalt';
  }
};

const getIconForType = (type: string) => {
  if (type.includes('attendance')) return 'check-square';
  if (type.includes('lesson_plan')) return 'file-text';
  if (type.includes('grade')) return 'edit';
  return 'bell';
};
</script>

<template>
  <div class="space-y-4">
    <div v-if="showHeader" class="flex items-center justify-between px-1">
      <div class="flex items-center gap-2">
        <h3 class="text-[15px] font-black text-slate-900 uppercase tracking-tight">{{ t('inbox.title') }}</h3>
        <div v-if="items.length > 0" class="px-1.5 py-0.5 rounded-md bg-status-danger-soft text-status-danger text-3xs font-black">
          {{ items.length }}
        </div>
      </div>
      <button 
        v-if="items.length > 0"
        type="button" 
        class="text-2xs font-black text-brand-cobalt uppercase tracking-wider hover:underline"
        @click="$emit('seeAll')"
      >
        {{ t('inbox.seeAll') }}
      </button>
    </div>

    <div v-if="isLoading" class="space-y-3">
      <div v-for="i in 2" :key="i" class="h-20 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <div v-else-if="items.length === 0" class="bg-white rounded-3xl p-8 border border-slate-100 text-center space-y-2">
      <div class="w-16 h-16 rounded-full bg-emerald-50 text-emerald-500 grid place-items-center mx-auto mb-4">
        <NavIcon name="check-circle" :size="32" />
      </div>
      <h4 class="text-sm font-bold text-slate-900">{{ t('inbox.allClear') }}</h4>
      <p class="text-xs text-slate-500 leading-relaxed">{{ t('inbox.allClearMsg') }}</p>
    </div>

    <div v-else class="space-y-2.5">
      <button
        v-for="item in items"
        :key="item.id"
        type="button"
        class="w-full text-left bg-white rounded-2xl p-4 border border-slate-100 hover:border-brand-cobalt/30 hover:shadow-lg hover:shadow-brand-cobalt/5 transition-all group flex items-start gap-4"
        @click="$emit('itemTap', item)"
      >
        <div 
          class="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 transition-colors"
          :class="getSeverityColor(item.severity).replace('text-', 'bg-').replace('bg-', 'bg-opacity-10 text-')"
        >
          <NavIcon :name="getIconForType(item.type)" :size="20" />
        </div>

        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <h4 class="text-sm font-bold text-slate-900 truncate">{{ item.label }}</h4>
            <div v-if="item.count > 1" class="px-1.5 py-0.5 rounded-md bg-slate-100 text-slate-500 text-4xs font-black">
              ·{{ item.count }}
            </div>
          </div>
          <p class="text-[12px] text-slate-500 mt-0.5 line-clamp-1">{{ item.subtitle }}</p>
          <p class="text-3xs font-bold text-slate-400 mt-2 uppercase tracking-wide">
            {{ formatRelativeTime(item.occurred_at) }}
          </p>
        </div>

        <div class="w-2 h-2 rounded-full mt-2" :class="getSeverityColor(item.severity).split(' ')[0]"></div>
      </button>
    </div>
  </div>
</template>
