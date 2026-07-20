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
    accent?: 'admin' | 'tutor' | 'parent';
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
    class="w-full flex items-center gap-3 p-3 bg-tutoring-panel border border-tutoring-border-soft rounded-2xl text-left transition hover:border-tutoring-accent/50"
    @click="handle"
  >
    <span
      class="w-9 h-9 rounded-xl grid place-items-center flex-shrink-0"
      :class="{
        'bg-tutoring-accent-dim text-tutoring-accent': accent === 'admin',
        'bg-tutoring-accent-dim text-tutoring-accent': accent === 'tutor',
        'bg-tutoring-accent-dim text-tutoring-accent': accent === 'parent',
      }"
    >
      <NavIcon :name="icon" :size="18" />
    </span>
    <span class="min-w-0 flex-1">
      <span class="block text-[14px] font-semibold text-tutoring-text-hi tracking-tight">{{ title }}</span>
      <span v-if="subtitle" class="block text-xs text-tutoring-text-mid mt-0.5">{{ subtitle }}</span>
    </span>
    <span v-if="$slots.trailing" class="flex-shrink-0">
      <slot name="trailing" />
    </span>
    <NavIcon
      v-else-if="to"
      name="chevron-right"
      :size="16"
      class="flex-shrink-0 text-tutoring-text-lo"
    />
  </button>
</template>
