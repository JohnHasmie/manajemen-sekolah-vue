<!--
  WelcomeBanner.vue — warm, one-time greeting for a role's landing view.

  Every role previously dropped the user into a set of KPI cards with
  zero orientation — a new teacher's very first screen was three
  "Belum ada X" tiles that read as broken. This banner replaces that
  with a short "here's how to get around" line, dismissible with one
  tap and stored so it never comes back.

  Dismissal is scoped by an opaque `storageKey` (per role + version) so
  a copy revision can invalidate the old sticker without leaking one
  role's dismissal into another. Cleared on logout by auth store.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { storage } from '@/lib/storage';

const props = defineProps<{
  /**
   * Stable key that identifies THIS banner uniquely (role + copy
   * version). Bump the version suffix — e.g. `guru.welcome.v2` —
   * to re-show the banner after a copy rewrite.
   */
  storageKey: string;
  title: string;
  message: string;
  /** Emoji or short glyph rendered inside the leading avatar. */
  emoji?: string;
  ctaLabel?: string;
}>();

const dismissed = ref<boolean>(storage.get<boolean>(props.storageKey) === true);

// When the caller swaps the storageKey (e.g. role change on the same
// mounted view) re-read the flag so we don't leak one role's state
// into the other's landing.
watch(
  () => props.storageKey,
  (k) => {
    dismissed.value = storage.get<boolean>(k) === true;
  },
);

const visible = computed(() => !dismissed.value);

function dismiss(): void {
  storage.set(props.storageKey, true);
  dismissed.value = true;
}
</script>

<template>
  <div
    v-if="visible"
    class="relative bg-gradient-to-br from-brand-cobalt/8 to-brand-cobalt/3 border border-brand-cobalt/25 rounded-2xl p-4 pr-11"
    role="status"
  >
    <button
      type="button"
      class="absolute top-2 right-2 w-7 h-7 rounded-full text-slate-400 hover:text-slate-700 hover:bg-white grid place-items-center transition-colors"
      :aria-label="'Tutup sambutan'"
      @click="dismiss"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="w-3.5 h-3.5"
      >
        <path d="M18 6 6 18M6 6l12 12" />
      </svg>
    </button>
    <div class="flex items-start gap-3">
      <span
        v-if="emoji"
        class="w-10 h-10 rounded-2xl bg-white border border-brand-cobalt/25 grid place-items-center text-xl flex-shrink-0"
        aria-hidden="true"
      >{{ emoji }}</span>
      <div class="flex-1 min-w-0">
        <p class="text-[13.5px] font-black text-brand-cobalt leading-tight">
          {{ title }}
        </p>
        <p class="mt-1 text-[12px] leading-snug text-slate-700">
          {{ message }}
        </p>
        <button
          v-if="ctaLabel"
          type="button"
          class="mt-2.5 inline-flex items-center gap-1 text-3xs font-black text-brand-cobalt hover:text-brand-cobalt/80 uppercase tracking-widest"
          @click="dismiss"
        >
          {{ ctaLabel }} →
        </button>
      </div>
    </div>
  </div>
</template>
