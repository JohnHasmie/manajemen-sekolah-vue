<!--
  TutoringListTile — consistent list row used everywhere (programs,
  sessions, bills, quick actions). Mirrors Flutter `TutoringListTile`.
  Slot `trailing` overrides the default chevron (used by bill rows that
  carry amount + status pill on the right).
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    icon: string;
    title: string;
    subtitle?: string;
    /** When provided, the row becomes a button; default chevron appears. */
    to?: (() => void) | null;
    accent?: 'admin' | 'tutor' | 'wali';
  }>(),
  { accent: 'admin', to: null },
);

const emit = defineEmits<{ (e: 'click'): void }>();
function handle() {
  if (props.to) props.to();
  emit('click');
}
</script>

<template>
  <button
    type="button"
    class="w-full flex items-center gap-3 p-3 bg-bimbel-panel border border-bimbel-border-soft rounded-2xl text-left transition hover:border-bimbel-accent/50"
    @click="handle"
  >
    <span
      class="w-9 h-9 rounded-xl grid place-items-center flex-shrink-0"
      :class="{
        'bg-bimbel-accent-dim text-bimbel-accent': accent === 'admin',
        'bg-bimbel-accent-dim text-bimbel-accent': accent === 'tutor',
        'bg-bimbel-accent-dim text-bimbel-accent': accent === 'wali',
      }"
    >
      <NavIcon :name="icon" :size="18" />
    </span>
    <span class="min-w-0 flex-1">
      <span class="block text-[13.5px] font-semibold text-bimbel-text-hi tracking-tight">{{ title }}</span>
      <span v-if="subtitle" class="block text-xs text-bimbel-text-mid mt-0.5">{{ subtitle }}</span>
    </span>
    <span v-if="$slots.trailing" class="flex-shrink-0">
      <slot name="trailing" />
    </span>
    <NavIcon
      v-else-if="to"
      name="chevron-right"
      :size="16"
      class="flex-shrink-0 text-bimbel-text-lo"
    />
  </button>
</template>
