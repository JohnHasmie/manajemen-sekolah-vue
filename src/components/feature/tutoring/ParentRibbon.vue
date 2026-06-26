<!--
  ParentRibbon — wide horizontal ribbon used on parent Home /
  Bill for "Bill aktif", "Pengingat session", etc. Tinted bg +
  border. Distinct from TutorRibbon by tone defaults.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    icon: string;
    label: string;
    value: string;
    hint?: string;
    tone?: 'warning' | 'success' | 'danger' | 'brand';
    /** When set, shows action button on the right (success bg). */
    actionLabel?: string;
    clickable?: boolean;
  }>(),
  { tone: 'warning', clickable: false },
);

const emit = defineEmits<{ (e: 'click'): void; (e: 'action'): void }>();

const styles = computed(() => {
  switch (props.tone) {
    case 'success':
      return {
        bg: 'bg-emerald-500/10 dark:bg-emerald-500/15',
        border: 'border-emerald-500/40',
        icon: 'text-emerald-700 dark:text-emerald-300 bg-emerald-500/20',
        accent: 'text-emerald-700 dark:text-emerald-300',
      };
    case 'danger':
      return {
        bg: 'bg-rose-500/10 dark:bg-rose-500/15',
        border: 'border-rose-500/40',
        icon: 'text-rose-700 dark:text-rose-300 bg-rose-500/20',
        accent: 'text-rose-700 dark:text-rose-300',
      };
    case 'brand':
      return {
        bg: 'bg-[#21afe6]/10 dark:bg-[#21afe6]/15',
        border: 'border-[#21afe6]/40',
        icon: 'text-[#1a8fbe] dark:text-[#85d4f4] bg-[#21afe6]/20',
        accent: 'text-[#1a8fbe] dark:text-[#85d4f4]',
      };
    default:
      return {
        bg: 'bg-amber-500/10 dark:bg-amber-500/15',
        border: 'border-amber-500/40',
        icon: 'text-amber-800 dark:text-amber-300 bg-amber-500/20',
        accent: 'text-amber-800 dark:text-amber-300',
      };
  }
});
</script>

<template>
  <component
    :is="clickable && !actionLabel ? 'button' : 'div'"
    :type="clickable && !actionLabel ? 'button' : undefined"
    class="flex items-center gap-3 rounded-2xl border px-4 py-3 text-left w-full"
    :class="[styles.bg, styles.border]"
    @click="clickable && !actionLabel && emit('click')"
  >
    <span
      class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-xl"
      :class="styles.icon"
    >
      <NavIcon :name="icon" :size="18" />
    </span>
    <div class="min-w-0 flex-1">
      <p class="text-[13px] font-bold uppercase tracking-wider" :class="styles.accent">
        {{ label }}
      </p>
      <p class="truncate text-[16px] font-extrabold tracking-tight text-bimbel-text-hi">
        {{ value }}
      </p>
      <p v-if="hint" class="truncate text-[13px]" :class="styles.accent">{{ hint }}</p>
    </div>
    <button
      v-if="actionLabel"
      type="button"
      class="flex-shrink-0 rounded-lg bg-[#21afe6] px-3.5 py-2 text-[13px] font-bold text-white hover:opacity-90"
      @click="emit('action')"
    >
      {{ actionLabel }}
    </button>
    <NavIcon
      v-else-if="clickable"
      name="chevron-right"
      :size="16"
      class="flex-shrink-0 text-bimbel-text-lo"
    />
  </component>
</template>
