<!--
  TutorClassCard — gradient card representing one kelas (group). The
  background is a deterministic gradient picked from a small palette
  (so the user can recognize each class visually), with the program
  name + tutor name + capacity hint over it.

  Mirrors Flutter `TutorClassColors.gradientFor` — we hash the
  group id into one of 6 paired hues, then blend with --bimbel-hero
  via color-mix so the brand identity wins over the random tint.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Stable id (or any string) — used to pick gradient color. */
  identityKey: string;
  /** Display name (Kelas IPA Pagi, etc.) */
  name: string;
  /** Optional program/subject line. */
  program?: string | null;
  /** Optional small meta — capacity / enrollment count. */
  meta?: string | null;
}>();

const emit = defineEmits<{ (e: 'click'): void }>();

// 6 hue pairs cycled by hash — keeps a class' color stable across reloads.
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

const gradient = computed(() => {
  const [a, b] = HUES[hashIdx(props.identityKey)];
  // Mix each stop with the role hero (cyan-navy) at 55% so the brand wins.
  return `linear-gradient(135deg, color-mix(in srgb, ${a} 55%, var(--bimbel-hero)), color-mix(in srgb, ${b} 60%, var(--bimbel-hero)))`;
});
</script>

<template>
  <button
    type="button"
    class="group flex flex-col items-stretch overflow-hidden rounded-3xl text-left text-white shadow-md transition hover:scale-[1.01] hover:shadow-lg"
    :style="{ background: gradient }"
    @click="emit('click')"
  >
    <div class="flex h-32 flex-col justify-between p-4">
      <div class="flex items-start justify-between">
        <span
          class="rounded-full bg-white/15 px-2 py-0.5 text-[9.5px] font-extrabold uppercase tracking-widest"
        >
          Kelas
        </span>
        <NavIcon name="chevron-right" :size="18" class="text-white/85" />
      </div>
      <div>
        <p v-if="program" class="text-[11px] font-semibold uppercase tracking-wide text-white/80">
          {{ program }}
        </p>
        <h3 class="mt-0.5 text-base font-extrabold leading-tight tracking-tight line-clamp-2">
          {{ name }}
        </h3>
      </div>
    </div>
    <div
      v-if="meta"
      class="border-t border-white/15 bg-black/15 px-4 py-2 text-[11.5px] font-semibold text-white/90 backdrop-blur-sm"
    >
      {{ meta }}
    </div>
  </button>
</template>
