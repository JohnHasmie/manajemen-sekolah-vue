<!--
  AdminActionMenu — kebab dropdown for admin row/card actions.

  Floats absolutely-positioned under the trigger. Items are passed via
  the `items` prop with optional danger flag; emits `pick` with the
  item key. Uses bimbel-* tokens so it adapts to light/dark.
-->
<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

export interface AdminMenuItem {
  key: string;
  label: string;
  icon?: string;
  danger?: boolean;
  disabled?: boolean;
}

const props = defineProps<{
  items: AdminMenuItem[];
  ariaLabel?: string;
}>();
const emit = defineEmits<{ (e: 'pick', key: string): void }>();

const open = ref(false);
const wrapRef = ref<HTMLElement | null>(null);

function toggle() { open.value = !open.value; }
function pick(it: AdminMenuItem) {
  if (it.disabled) return;
  open.value = false;
  emit('pick', it.key);
}
function onDocClick(e: MouseEvent) {
  if (!open.value) return;
  if (wrapRef.value && !wrapRef.value.contains(e.target as Node)) open.value = false;
}
function onEsc(e: KeyboardEvent) {
  if (e.key === 'Escape') open.value = false;
}
onMounted(() => {
  document.addEventListener('click', onDocClick);
  document.addEventListener('keydown', onEsc);
});
onBeforeUnmount(() => {
  document.removeEventListener('click', onDocClick);
  document.removeEventListener('keydown', onEsc);
});
</script>

<template>
  <div ref="wrapRef" class="relative inline-block">
    <button
      type="button"
      :aria-label="ariaLabel ?? 'Aksi'"
      class="grid h-7 w-7 place-items-center rounded-md border border-bimbel-border bg-bimbel-panel text-bimbel-text-mid hover:bg-bimbel-border-soft hover:text-bimbel-text-hi transition"
      @click.stop="toggle"
    >
      <NavIcon name="more-horizontal" :size="14" />
    </button>
    <div
      v-if="open"
      class="absolute right-0 z-30 mt-1 min-w-[180px] rounded-xl border border-bimbel-border bg-bimbel-panel py-1 shadow-lg"
    >
      <button
        v-for="it in items"
        :key="it.key"
        type="button"
        :disabled="it.disabled"
        class="flex w-full items-center gap-2.5 px-3 py-2 text-[13px] font-semibold text-left transition disabled:opacity-40"
        :class="it.danger ? 'text-rose-600 dark:text-rose-400 hover:bg-rose-500/10' : 'text-bimbel-text-hi hover:bg-bimbel-border-soft'"
        @click.stop="pick(it)"
      >
        <NavIcon v-if="it.icon" :name="it.icon" :size="13" />
        {{ it.label }}
      </button>
    </div>
  </div>
</template>
