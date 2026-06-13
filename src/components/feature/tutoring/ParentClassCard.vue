<!--
  ParentClassCard — gradient kelas card on the wali Kelas list +
  Beranda. Differs from TutorClassCard by also showing a "new"
  badge (count of unread announcements) and a footer with
  schedule + attendance % (the per-class wali context).
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  identityKey: string;
  /** Class display name. */
  name: string;
  /** Subject / program (top kicker). */
  subject?: string | null;
  /** Tutor name (above the foot). */
  tutorName?: string | null;
  /** Footer text — schedule + attendance, e.g. "Sen Rab Jum 16:00 · hadir 92%". */
  footer?: string | null;
  /** Number of unread announcements / activities. */
  newCount?: number;
}>();

const emit = defineEmits<{ (e: 'click'): void }>();

const HUES: Array<[string, string]> = [
  ['#1d9e75', '#0f6e56'],   // emerald
  ['#d4537e', '#993556'],   // pink
  ['#d85a30', '#993c1d'],   // coral
  ['#534ab7', '#3c3489'],   // purple
  ['#1f3a5f', '#0c2545'],   // navy
  ['#0f6e56', '#0a4d3c'],   // teal
];

function hashIdx(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h) % HUES.length;
}

const gradient = computed(() => {
  const [a, b] = HUES[hashIdx(props.identityKey)];
  return `linear-gradient(135deg, ${a}, ${b})`;
});
</script>

<template>
  <button
    type="button"
    class="group flex flex-col overflow-hidden rounded-2xl text-left text-white shadow-md transition hover:scale-[1.01] hover:shadow-lg"
    :style="{ background: gradient }"
    @click="emit('click')"
  >
    <div class="flex flex-col gap-1 p-3.5 flex-1">
      <div class="flex items-start justify-between gap-2">
        <span
          v-if="subject"
          class="rounded-full bg-white/15 px-2 py-0.5 text-[9px] font-extrabold uppercase tracking-widest"
        >
          {{ subject }}
        </span>
        <span
          v-if="newCount && newCount > 0"
          class="flex-shrink-0 rounded-full bg-white px-2 py-0.5 text-[9.5px] font-extrabold tracking-tight"
          style="color: #0c447c;"
        >
          {{ newCount }} baru
        </span>
      </div>
      <h3 class="mt-1.5 text-[13.5px] font-extrabold leading-tight tracking-tight line-clamp-2">
        {{ name }}
      </h3>
      <p v-if="tutorName" class="text-[10.5px] text-white/85">{{ tutorName }}</p>
    </div>
    <div
      v-if="footer"
      class="border-t border-white/20 bg-black/15 px-3.5 py-1.5 text-[10.5px] font-semibold text-white/90"
    >
      {{ footer }}
    </div>
  </button>
</template>
