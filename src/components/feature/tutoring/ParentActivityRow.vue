<!--
  ParentActivityRow — one row in the "Yang baru" feed on parent
  Beranda + Kelas detail Aliran tab. Icon mapped by event type,
  title + subtitle + relative-time chip.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  type: string;
  title: string;
  subtitle?: string | null;
  occurredAt?: string | null;
  /** When true, renders compact (no rounded border) so it fits as a
   *  list-item under a Panel header. */
  compact?: boolean;
}>();

const emit = defineEmits<{ (e: 'click'): void }>();

const meta = computed(() => {
  switch (props.type) {
    case 'note':
    case 'score':
      return { icon: 'star', chip: 'bg-amber-500/15', text: 'text-amber-700 dark:text-amber-300' };
    case 'announcement':
    case 'announcement_posted':
      return { icon: 'megaphone', chip: 'bg-violet-500/15', text: 'text-violet-700 dark:text-violet-300' };
    case 'bill':
    case 'bill_paid':
      return { icon: 'wallet', chip: 'bg-emerald-500/15', text: 'text-emerald-700 dark:text-emerald-300' };
    case 'attendance':
      return { icon: 'check-circle', chip: 'bg-emerald-500/15', text: 'text-emerald-700 dark:text-emerald-300' };
    case 'session_done':
      return { icon: 'calendar', chip: 'bg-bimbel-accent-dim', text: 'text-bimbel-accent' };
    case 'new_submission':
      return { icon: 'book', chip: 'bg-amber-500/15', text: 'text-amber-700 dark:text-amber-300' };
    default:
      return { icon: 'circle', chip: 'bg-bimbel-border-soft', text: 'text-bimbel-text-mid' };
  }
});

const rel = computed(() => {
  if (!props.occurredAt) return '';
  const d = new Date(props.occurredAt);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 1) return 'baru';
  if (diffMin < 60) return `${Math.floor(diffMin)}m`;
  const h = Math.floor(diffMin / 60);
  if (h < 24) return `${h}j`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days}h`;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
});
</script>

<template>
  <button
    type="button"
    class="flex w-full items-start gap-3 text-left transition"
    :class="
      compact
        ? 'py-2 border-b border-bimbel-border-soft last:border-b-0 hover:bg-bimbel-border-soft/30'
        : 'rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3 hover:border-bimbel-accent/40'
    "
    @click="emit('click')"
  >
    <span
      class="mt-0.5 grid h-9 w-9 flex-shrink-0 place-items-center rounded-xl"
      :class="[meta.chip, meta.text]"
    >
      <NavIcon :name="meta.icon" :size="15" />
    </span>
    <div class="min-w-0 flex-1">
      <p class="truncate text-[13px] font-bold tracking-tight text-bimbel-text-hi">
        {{ title }}
      </p>
      <p v-if="subtitle" class="truncate text-[12px] text-bimbel-text-mid">
        {{ subtitle }}
      </p>
    </div>
    <span
      v-if="rel"
      class="flex-shrink-0 text-[12px] font-semibold text-bimbel-text-lo"
    >
      {{ rel }}
    </span>
  </button>
</template>
