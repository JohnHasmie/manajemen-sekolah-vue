<!--
  TutorShortcutTile — square-ish icon tile used in 2×2 / 4-col shortcut
  grids on the Home. Mirrors Flutter `_ShortcutsRow` items.

  Defaults to brand (cyan) tint. Optional `tone` lets a tile stand out
  (success/warning/danger) — e.g. honor → success, peringatan → danger.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    icon: string;
    label: string;
    /** Optional second line — e.g. "3 menunggu". */
    hint?: string;
    tone?: 'brand' | 'success' | 'warning' | 'danger';
  }>(),
  { tone: 'brand' },
);

const emit = defineEmits<{ (e: 'click'): void }>();

const styles = computed(() => {
  switch (props.tone) {
    case 'success':
      return { chip: 'bg-emerald-500/15', icon: 'text-emerald-600 dark:text-emerald-400' };
    case 'warning':
      return { chip: 'bg-amber-500/15', icon: 'text-amber-700 dark:text-amber-400' };
    case 'danger':
      return { chip: 'bg-rose-500/15', icon: 'text-rose-600 dark:text-rose-400' };
    default:
      return { chip: 'bg-tutoring-accent-dim', icon: 'text-tutoring-accent' };
  }
});
</script>

<template>
  <button
    type="button"
    class="flex w-full flex-col items-start gap-2 rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5 text-left transition hover:border-tutoring-accent/50"
    @click="emit('click')"
  >
    <span
      class="grid h-10 w-10 place-items-center rounded-xl"
      :class="[styles.chip, styles.icon]"
    >
      <NavIcon :name="icon" :size="20" />
    </span>
    <div class="min-w-0">
      <p class="text-[14px] font-bold tracking-tight text-tutoring-text-hi">
        {{ label }}
      </p>
      <p v-if="hint" class="mt-0.5 truncate text-[12px] text-tutoring-text-mid">
        {{ hint }}
      </p>
    </div>
  </button>
</template>
