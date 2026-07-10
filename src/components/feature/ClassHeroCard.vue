<!--
  ClassHeroCard — the shared gradient "class card". One source of the
  gradient-hero markup, used by the bimbel class lists (via TutorClassCard) AND
  the Kelas hub lists.

  The background gradient is either:
    • an explicit `gradient` CSS string — the Kelas hub passes a subject-colour
      gradient (classHubGradientCss) so the card matches the hub header it
      opens; or
    • a deterministic gradient hashed from `identityKey` over a 6-hue palette
      blended with the brand hero — the original bimbel behaviour (default).

  Content: a badge pill + chevron, an optional eyebrow, the title, and an
  optional subline. The footer is either the `#footer` slot (e.g. the Kelas
  white "Buka" bar) or — when `meta` is set and no slot is given — a translucent
  dark meta bar (the bimbel style).
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    /** Stable id (or any string) — hashed to pick the default gradient. */
    identityKey: string;
    /** Title (class / group name). */
    name: string;
    /** Top-left pill text. */
    badge?: string;
    /** Small uppercase line above the title (bimbel: program/tutor). */
    eyebrow?: string | null;
    /** Secondary line under the title, on the gradient (Kelas: status counts). */
    subline?: string | null;
    /** Dark footer-bar text (bimbel). Ignored when the #footer slot is used. */
    meta?: string | null;
    /** Explicit CSS background override; else the hashed palette gradient. */
    gradient?: string;
  }>(),
  { badge: 'Kelas', eyebrow: null, subline: null, meta: null, gradient: '' },
);

const emit = defineEmits<{ (e: 'click'): void }>();

// 6 hue pairs cycled by hash — keeps a class' colour stable across reloads.
const HUES = [
  ['#0ea5e9', '#0369a1'], // sky → cyan-deep
  ['#22c55e', '#15803d'], // emerald
  ['#a855f7', '#6b21a8'], // purple
  ['#f97316', '#c2410c'], // orange
  ['#ec4899', '#9d174d'], // pink
  ['#14b8a6', '#0f766e'], // teal
];
function hashIdx(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) | 0;
  }
  return Math.abs(h) % HUES.length;
}

const background = computed(() => {
  if (props.gradient) return props.gradient;
  const [a, b] = HUES[hashIdx(props.identityKey)];
  // Mix each stop with the role hero (cyan-navy) at 55% so the brand wins.
  return `linear-gradient(135deg, color-mix(in srgb, ${a} 55%, var(--tutoring-hero)), color-mix(in srgb, ${b} 60%, var(--tutoring-hero)))`;
});
</script>

<template>
  <button
    type="button"
    class="group flex flex-col items-stretch overflow-hidden rounded-3xl text-left text-white shadow-md transition hover:scale-[1.01] hover:shadow-lg"
    :style="{ background }"
    @click="emit('click')"
  >
    <div class="flex flex-1 flex-col justify-between gap-3 p-4 min-h-[128px]">
      <div class="flex items-start justify-between gap-2">
        <span
          class="max-w-[80%] truncate rounded-full bg-white/15 px-2.5 py-0.5 text-[11px] font-extrabold uppercase tracking-widest"
        >
          {{ badge }}
        </span>
        <NavIcon name="chevron-right" :size="18" class="shrink-0 text-white/85" />
      </div>
      <div>
        <p
          v-if="eyebrow"
          class="text-[12px] font-semibold uppercase tracking-wide text-white/80"
        >
          {{ eyebrow }}
        </p>
        <h3 class="mt-0.5 text-lg font-black leading-tight tracking-tight line-clamp-2">
          {{ name }}
        </h3>
        <p v-if="subline" class="mt-1.5 text-[13px] text-white/80">{{ subline }}</p>
      </div>
    </div>

    <slot name="footer">
      <div
        v-if="meta"
        class="border-t border-white/15 bg-black/15 px-4 py-2 text-[12px] font-semibold text-white/90 backdrop-blur-sm"
      >
        {{ meta }}
      </div>
    </slot>
  </button>
</template>
