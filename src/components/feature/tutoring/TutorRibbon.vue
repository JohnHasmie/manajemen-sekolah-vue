<!--
  TutorRibbon — a wide horizontal pill used for the Honor / Bill
  ribbon on the Home. Tinted background, bold leading icon, value +
  hint stacked, optional trailing chevron when clickable.

  Mirrors Flutter `_HonorRibbon` / `_TagihanRibbon` in
  tutor_beranda_screen.dart + tutoring_child_overview_screen.dart.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    icon: string;
    label: string;
    /** Big right-side value, e.g. "Rp 4.250.000". */
    value: string;
    /** Optional small line under the value. */
    hint?: string;
    tone?: 'success' | 'warning' | 'danger' | 'brand';
    /** Pass true to render a chevron on the far right. */
    clickable?: boolean;
  }>(),
  { tone: 'success', clickable: false },
);

const emit = defineEmits<{ (e: 'click'): void }>();

const styles = computed(() => {
  switch (props.tone) {
    case 'warning':
      return {
        bg: 'bg-amber-500/10 dark:bg-amber-500/15',
        border: 'border-amber-500/40',
        icon: 'text-amber-700 dark:text-amber-400 bg-amber-500/20',
      };
    case 'danger':
      return {
        bg: 'bg-rose-500/10 dark:bg-rose-500/15',
        border: 'border-rose-500/40',
        icon: 'text-rose-600 dark:text-rose-400 bg-rose-500/20',
      };
    case 'brand':
      return {
        bg: 'bg-bimbel-accent-dim',
        border: 'border-bimbel-accent/40',
        icon: 'text-bimbel-accent bg-bimbel-accent-dim',
      };
    default:
      return {
        bg: 'bg-emerald-500/10 dark:bg-emerald-500/15',
        border: 'border-emerald-500/40',
        icon: 'text-emerald-700 dark:text-emerald-400 bg-emerald-500/20',
      };
  }
});
</script>

<template>
  <component
    :is="clickable ? 'button' : 'div'"
    :type="clickable ? 'button' : undefined"
    class="flex w-full items-center gap-3 rounded-2xl border px-4 py-3 text-left"
    :class="[styles.bg, styles.border]"
    @click="clickable && emit('click')"
  >
    <span
      class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-xl"
      :class="styles.icon"
    >
      <NavIcon :name="icon" :size="18" />
    </span>
    <div class="min-w-0 flex-1">
      <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
        {{ label }}
      </p>
      <p class="truncate text-base font-extrabold tracking-tight text-bimbel-text-hi">
        {{ value }}
      </p>
      <p v-if="hint" class="truncate text-[12px] text-bimbel-text-mid">{{ hint }}</p>
    </div>
    <NavIcon
      v-if="clickable"
      name="chevron-right"
      :size="16"
      class="flex-shrink-0 text-bimbel-text-lo"
    />
  </component>
</template>
