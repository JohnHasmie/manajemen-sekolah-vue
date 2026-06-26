<!--
  TutorAppearanceView — bimbel (tutor) appearance settings.

  Mirrors `lib/features/tutoring/presentation/screens/tutoring_appearance_screen.dart`
  for the tutor role. Three radio tiles (Otomatis / Selalu terang /
  Selalu gelap) drive the `useTutoringThemeStore` mode; the tutor surface
  then flips between `tutoring-dark` and `tutoring-light` via the AppShell
  wrapper class.

  The page itself uses bimbel surface tokens, so it previews the chosen
  mode in-situ — pick "Selalu terang" and the cards flip white instantly.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useTutoringThemeStore, type TutoringThemeMode } from '@/stores/tutoring-theme';

const { t } = useI18n();
const router = useRouter();
const theme = useTutoringThemeStore();

interface ModeOption {
  mode: TutoringThemeMode;
  icon: string;
  title: string;
  subtitle: string;
}

const options = computed<ModeOption[]>(() => [
  {
    mode: 'auto',
    icon: 'smartphone',
    title: t('tutor.bimbel.appearance.mode_auto_title'),
    subtitle: t('tutor.bimbel.appearance.mode_auto_subtitle'),
  },
  {
    mode: 'light',
    icon: 'sun',
    title: t('tutor.bimbel.appearance.mode_light_title'),
    subtitle: t('tutor.bimbel.appearance.mode_light_subtitle'),
  },
  {
    mode: 'dark',
    icon: 'moon',
    title: t('tutor.bimbel.appearance.mode_dark_title'),
    subtitle: t('tutor.bimbel.appearance.mode_dark_subtitle'),
  },
]);

const previewText = computed(() =>
  theme.isDark
    ? t('tutor.bimbel.appearance.preview_dark')
    : t('tutor.bimbel.appearance.preview_light'),
);

function pick(m: TutoringThemeMode) {
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
      :kicker="t('tutor.bimbel.appearance.kicker')"
      :title="t('tutor.bimbel.appearance.title')"
      :meta="t('tutor.bimbel.appearance.meta')"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-1.5 text-xs font-bold text-tutoring-text-mid hover:text-tutoring-text-hi"
        @click="goBack"
      >
        <NavIcon name="arrow-left" :size="14" />
        {{ t('tutor.bimbel.appearance.back_btn') }}
      </button>
    </BrandPageHeader>

    <!-- MODE TEMA ─────────────────────────────────────────────────── -->
    <div>
      <p class="px-1 pb-2 text-[12px] font-extrabold tracking-widest text-tutoring-text-mid">
        {{ t('tutor.bimbel.appearance.section_mode') }}
      </p>
      <div class="space-y-2.5">
        <button
          v-for="opt in options"
          :key="opt.mode"
          type="button"
          class="block w-full text-left rounded-2xl border p-3.5 transition-colors"
          :class="
            theme.mode === opt.mode
              ? 'border-tutoring-accent bg-tutoring-accent-dim'
              : 'border-tutoring-border bg-tutoring-panel hover:border-tutoring-accent/40'
          "
          @click="pick(opt.mode)"
        >
          <div class="flex items-center gap-3">
            <div
              class="grid h-9 w-9 flex-shrink-0 place-items-center rounded-lg"
              :class="
                theme.mode === opt.mode
                  ? 'bg-tutoring-accent/20 text-tutoring-accent'
                  : 'bg-tutoring-border-soft text-tutoring-text-mid'
              "
            >
              <NavIcon :name="opt.icon" :size="18" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-sm font-bold text-tutoring-text-hi">{{ opt.title }}</div>
              <div class="text-xs text-tutoring-text-mid">{{ opt.subtitle }}</div>
            </div>
            <span
              class="inline-grid h-[18px] w-[18px] flex-shrink-0 place-items-center rounded-full border-2"
              :class="theme.mode === opt.mode ? 'border-tutoring-accent' : 'border-tutoring-text-lo'"
            >
              <span
                v-if="theme.mode === opt.mode"
                class="block h-2 w-2 rounded-full bg-tutoring-accent"
              />
            </span>
          </div>

          <!-- Auto-mode hint: shown only inside the "Otomatis" tile and
               only when auto IS the active mode. Mirrors the green chip
               in the Flutter screen. -->
          <div
            v-if="opt.mode === 'auto' && theme.autoHint"
            class="mt-3 flex items-start gap-2 rounded-lg border border-tutoring-green/40 bg-tutoring-green-dim px-2.5 py-2"
          >
            <NavIcon
              :name="theme.isDark ? 'moon' : 'sun'"
              :size="13"
              class="mt-0.5 text-tutoring-green"
            />
            <span class="text-[12px] leading-snug text-tutoring-text-hi">
              {{ theme.autoHint }}
            </span>
          </div>
        </button>
      </div>
    </div>

    <!-- Preview card ──────────────────────────────────────────────── -->
    <div class="rounded-2xl border border-tutoring-border bg-tutoring-panel p-3.5">
      <div class="flex items-center gap-3">
        <div
          class="grid h-11 w-11 flex-shrink-0 place-items-center rounded-xl"
          :style="{ backgroundColor: 'var(--tutoring-hero)' }"
        >
          <div class="h-5 w-5 rounded-md" :style="{ backgroundColor: 'var(--tutoring-accent)' }" />
        </div>
        <div class="min-w-0 flex-1">
          <div class="text-sm font-bold text-tutoring-text-hi">{{ t('tutor.bimbel.appearance.preview_title') }}</div>
          <div class="text-xs text-tutoring-text-mid">{{ previewText }}</div>
        </div>
      </div>
    </div>
  </div>
</template>
