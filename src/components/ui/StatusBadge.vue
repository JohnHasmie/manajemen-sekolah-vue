<!--
  StatusBadge — the single source of truth for the tone-coloured pill
  that labels a row/entity status ("Terbit", "Draft", "Lunas", "Belum
  verif", …). Before this component ~40 admin views hand-rolled the same
  `text-3xs font-bold px-2 py-1 rounded-full` chrome, each pairing it
  with its own status→colour lookup — so the styling drifted view to
  view.

  Domain logic (which status maps to which tone) STAYS in the calling
  view; the badge only owns the chrome + the canonical tone palette.
  Callers pass a translated `label` and a semantic `tone`.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { StatusBadgeTone as Tone } from '@/types/status-badge';

const props = withDefaults(
  defineProps<{
    label: string;
    tone?: Tone;
    /** UPPERCASE the label (common on report-card / grade statuses). */
    uppercase?: boolean;
    /** Show a leading status dot. */
    dot?: boolean;
  }>(),
  { tone: 'neutral', uppercase: false, dot: false },
);

// Canonical tone palette. Readable soft-bg + darker-text pairings that
// match the most common existing usage; tuning any tone here now
// re-skins every badge in the app at once.
const TONES: Record<Tone, { chip: string; dot: string }> = {
  success: { chip: 'bg-emerald-50 text-emerald-700', dot: 'bg-emerald-500' },
  warning: { chip: 'bg-amber-50 text-amber-700', dot: 'bg-amber-500' },
  danger: { chip: 'bg-red-50 text-red-700', dot: 'bg-red-500' },
  info: { chip: 'bg-sky-50 text-sky-700', dot: 'bg-sky-500' },
  neutral: { chip: 'bg-slate-100 text-slate-500', dot: 'bg-slate-400' },
};

const tone = computed(() => TONES[props.tone]);
</script>

<template>
  <span
    class="inline-flex items-center gap-1 text-3xs font-bold px-2 py-1 rounded-full tracking-wider flex-shrink-0"
    :class="[tone.chip, uppercase ? 'uppercase' : '']"
  >
    <span
      v-if="dot"
      class="w-1.5 h-1.5 rounded-full"
      :class="tone.dot"
      aria-hidden="true"
    ></span>
    {{ label }}
  </span>
</template>
