<!--
  ParentAnnouncementCard — one announcement on the wali Pengumuman
  page. Avatar of source + meta line + title + body. Source chip
  shows "tutor kelompok" / "admin".
-->
<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  title: string;
  body?: string | null;
  /** Display name of source (Bu Sari / Admin bimbel). */
  sourceName: string;
  /** Source kind — drives the chip color. */
  sourceKind?: 'tutor' | 'admin';
  /** Subject / class context shown beside name. */
  context?: string | null;
  occurredAt?: string | null;
}>();

function initial(name: string): string {
  return name.trim()[0]?.toUpperCase() ?? '?';
}

const rel = computed(() => {
  if (!props.occurredAt) return '';
  const d = new Date(props.occurredAt);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 60) return `${Math.max(1, Math.floor(diffMin))} menit lalu`;
  const h = Math.floor(diffMin / 60);
  if (h < 24) return `${h} jam lalu`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days} hari lalu`;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
});

const chipClass = computed(() =>
  props.sourceKind === 'admin'
    ? 'bg-violet-500/15 text-violet-700 dark:text-violet-300'
    : 'bg-bimbel-accent-dim text-bimbel-accent',
);
const chipLabel = computed(() =>
  props.sourceKind === 'admin' ? 'admin' : 'tutor kelompok',
);
</script>

<template>
  <article class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
    <div class="mb-2 flex items-center gap-2">
      <span class="grid h-6 w-6 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent text-[13px] font-bold">
        {{ initial(sourceName) }}
      </span>
      <span class="text-[13px] text-bimbel-text-mid">
        {{ sourceName }}<template v-if="context"> · {{ context }}</template>
        <template v-if="rel"> · {{ rel }}</template>
      </span>
      <span
        class="ml-auto rounded-full px-2 py-0.5 text-[13px] font-bold uppercase tracking-wider"
        :class="chipClass"
      >
        {{ chipLabel }}
      </span>
    </div>
    <h3 class="text-[14px] font-extrabold tracking-tight text-bimbel-text-hi">
      {{ title }}
    </h3>
    <p v-if="body" class="mt-1 text-[13px] leading-relaxed text-bimbel-text-mid">
      {{ body }}
    </p>
  </article>
</template>
