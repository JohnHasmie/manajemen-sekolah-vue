<!--
  TutorAppearanceView — bimbel (tutor) appearance settings.

  Mirrors `lib/features/tutoring/presentation/screens/tutoring_appearance_screen.dart`
  for the tutor role. Three radio tiles (Otomatis / Selalu terang /
  Selalu gelap) drive the `useBimbelThemeStore` mode; the tutor surface
  then flips between `bimbel-dark` and `bimbel-light` via the AppShell
  wrapper class.

  The page itself uses bimbel surface tokens, so it previews the chosen
  mode in-situ — pick "Selalu terang" and the cards flip white instantly.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useBimbelThemeStore, type BimbelThemeMode } from '@/stores/bimbel-theme';

const router = useRouter();
const theme = useBimbelThemeStore();

interface ModeOption {
  mode: BimbelThemeMode;
  icon: string;
  title: string;
  subtitle: string;
}

const options: ModeOption[] = [
  {
    mode: 'auto',
    icon: 'smartphone',
    title: 'Otomatis',
    subtitle: 'Terang di pagi-sore, gelap di malam hari.',
  },
  {
    mode: 'light',
    icon: 'sun',
    title: 'Selalu terang',
    subtitle: 'Latar putih sepanjang hari.',
  },
  {
    mode: 'dark',
    icon: 'moon',
    title: 'Selalu gelap',
    subtitle: 'Latar gelap untuk hemat mata di malam.',
  },
];

const previewText = computed(() =>
  theme.isDark
    ? 'Sekarang gelap · navy + accent terang'
    : 'Sekarang terang · navy + accent dalam',
);

function pick(m: BimbelThemeMode) {
  theme.setMode(m);
}

function goBack() {
  if (window.history.length > 1) {
    router.back();
  } else {
    router.push({ name: 'teacher.home' });
  }
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="guru"
      kicker="Bimbel · Tutor"
      title="Tampilan"
      meta="Pilih mode terang / gelap untuk seluruh surface bimbel"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-xs font-bold text-bimbel-text-mid hover:text-bimbel-text-hi"
        @click="goBack"
      >
        <NavIcon name="arrow-left" :size="14" />
        Kembali
      </button>
    </BrandPageHeader>

    <!-- MODE TEMA ─────────────────────────────────────────────────── -->
    <div>
      <p class="px-1 pb-2 text-[10.5px] font-extrabold tracking-widest text-bimbel-text-mid">
        MODE TEMA
      </p>
      <div class="space-y-2.5">
        <button
          v-for="opt in options"
          :key="opt.mode"
          type="button"
          class="block w-full text-left rounded-2xl border p-3.5 transition-colors"
          :class="
            theme.mode === opt.mode
              ? 'border-bimbel-accent bg-bimbel-accent-dim'
              : 'border-bimbel-border bg-bimbel-panel hover:border-bimbel-accent/40'
          "
          @click="pick(opt.mode)"
        >
          <div class="flex items-center gap-3">
            <div
              class="grid h-9 w-9 flex-shrink-0 place-items-center rounded-lg"
              :class="
                theme.mode === opt.mode
                  ? 'bg-bimbel-accent/20 text-bimbel-accent'
                  : 'bg-bimbel-border-soft text-bimbel-text-mid'
              "
            >
              <NavIcon :name="opt.icon" :size="18" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-sm font-bold text-bimbel-text-hi">{{ opt.title }}</div>
              <div class="text-xs text-bimbel-text-mid">{{ opt.subtitle }}</div>
            </div>
            <span
              class="inline-grid h-[18px] w-[18px] flex-shrink-0 place-items-center rounded-full border-2"
              :class="theme.mode === opt.mode ? 'border-bimbel-accent' : 'border-bimbel-text-lo'"
            >
              <span
                v-if="theme.mode === opt.mode"
                class="block h-2 w-2 rounded-full bg-bimbel-accent"
              />
            </span>
          </div>

          <!-- Auto-mode hint: shown only inside the "Otomatis" tile and
               only when auto IS the active mode. Mirrors the green chip
               in the Flutter screen. -->
          <div
            v-if="opt.mode === 'auto' && theme.autoHint"
            class="mt-3 flex items-start gap-2 rounded-lg border border-bimbel-green/40 bg-bimbel-green-dim px-2.5 py-2"
          >
            <NavIcon
              :name="theme.isDark ? 'moon' : 'sun'"
              :size="13"
              class="mt-0.5 text-bimbel-green"
            />
            <span class="text-[11px] leading-snug text-bimbel-text-hi">
              {{ theme.autoHint }}
            </span>
          </div>
        </button>
      </div>
    </div>

    <!-- Preview card ──────────────────────────────────────────────── -->
    <div class="rounded-2xl border border-bimbel-border bg-bimbel-panel p-3.5">
      <div class="flex items-center gap-3">
        <div
          class="grid h-11 w-11 flex-shrink-0 place-items-center rounded-xl"
          :style="{ backgroundColor: 'var(--bimbel-hero)' }"
        >
          <div class="h-5 w-5 rounded-md" :style="{ backgroundColor: 'var(--bimbel-accent)' }" />
        </div>
        <div class="min-w-0 flex-1">
          <div class="text-sm font-bold text-bimbel-text-hi">Tema role Tutor</div>
          <div class="text-xs text-bimbel-text-mid">{{ previewText }}</div>
        </div>
      </div>
    </div>
  </div>
</template>
