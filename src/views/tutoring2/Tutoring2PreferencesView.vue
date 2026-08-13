<!--
  Tutoring2PreferencesView.vue — Tampilan + Bahasa for every bimbel role.

  ── What this replaces ──

  The three greenfield Profil views (siswa / wali / tutor) each carried a
  Tampilan and a Bahasa card whose action was:

      const notAvailable = () => toast.info(t('tutoring2.common.notAvailable'));

  Both stores they needed had existed the whole time — `useTutoringThemeStore`
  (three modes, persisted to localStorage, drives the `.tutoring-{light,dark}`
  root class) and `usePreferencesStore.setLocale` (persisted AND PATCHed to
  `/profile/language`). The mobile app hit the same wall from the other side:
  its Profil toggles flipped local state and changed nothing.

  ── Why a new view when three appearance views already exist ──

  `ParentAppearanceView`, `TutorAppearanceView` and `AdminTutoringAppearanceView`
  are three near-identical copies of a theme picker under the LEGACY
  `views/*/tutoring/` tree. Two of them are already orphaned — routed, but
  nothing in the app links to them — and none offers a language control.
  Pointing the greenfield cards at legacy views would have tied this surface
  to code that is scheduled for teardown, so the greenfield gets one view for
  all roles. The legacy three are left alone: `ParentMoreView` still links one,
  and they belong to the v1 removal, not here.

  ── Auto is the default, so this is not a toggle ──

  A two-state light/dark switch cannot express `auto`, and a user who touched
  it would be pinned to a fixed mode with no way back. Three options, and the
  auto row says WHEN it flips — a theme that changes by itself with no
  explanation reads as a rendering fault.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useTutoringThemeStore, type TutoringThemeMode } from '@/stores/tutoring-theme';
import { usePreferencesStore } from '@/stores/preferences';
import type { AppLocale } from '@/lib/i18n';

const { t } = useI18n();
const theme = useTutoringThemeStore();
const preferences = usePreferencesStore();

interface ModeOption {
  id: TutoringThemeMode;
  label: string;
  sub: string;
}

const modes = computed<ModeOption[]>(() => [
  {
    id: 'light',
    label: t('tutoring2.preferences.themeLight'),
    sub: t('tutoring2.preferences.themeLightDesc'),
  },
  {
    id: 'dark',
    label: t('tutoring2.preferences.themeDark'),
    sub: t('tutoring2.preferences.themeDarkDesc'),
  },
  {
    id: 'auto',
    label: t('tutoring2.preferences.themeAuto'),
    // The times come from the store rather than the copy, so the note
    // stays true if the schedule is changed elsewhere.
    sub: t('tutoring2.preferences.themeAutoDesc', {
      light: lightStart.value,
      dark: darkStart.value,
    }),
  },
]);

const lightStart = computed(() => `${String(theme.lightStartHour).padStart(2, '0')}:00`);
const darkStart = computed(
  () =>
    `${String(theme.darkStartHour).padStart(2, '0')}:` +
    `${String(theme.darkStartMinute).padStart(2, '0')}`,
);

const locales = computed<{ id: AppLocale; label: string }[]>(() => [
  { id: 'id', label: 'Bahasa Indonesia' },
  { id: 'en', label: 'English' },
]);

/**
 * Switching locale AWAITS the backend PATCH before the store bumps its
 * change token — server-rendered strings are read back afterwards, and
 * firing the re-fetch first would hand back the old language. That
 * ordering lives in the store; this view only has to await it.
 */
async function chooseLocale(locale: AppLocale) {
  if (preferences.locale === locale) return;
  await preferences.setLocale(locale);
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      :kicker="t('tutoring2.preferences.kicker')"
      :title="t('tutoring2.preferences.title')"
    />

    <section class="rounded-3xl border border-slate-100 bg-white p-md shadow-sm">
      <h2 class="text-sm font-bold text-slate-900">
        {{ t('tutoring2.preferences.theme') }}
      </h2>

      <div class="mt-3 space-y-2">
        <button
          v-for="m in modes"
          :key="m.id"
          type="button"
          class="flex w-full items-start gap-3 rounded-2xl border p-3 text-left transition"
          :class="
            theme.mode === m.id
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-100 hover:border-slate-200'
          "
          :aria-pressed="theme.mode === m.id"
          @click="theme.setMode(m.id)"
        >
          <span
            class="mt-0.5 inline-block h-4 w-4 shrink-0 rounded-full border-2"
            :class="theme.mode === m.id ? 'border-brand-cobalt bg-brand-cobalt' : 'border-slate-300'"
          />
          <span class="min-w-0">
            <span class="block text-sm font-semibold text-slate-900">{{ m.label }}</span>
            <span class="mt-0.5 block text-2xs leading-relaxed text-slate-500">{{ m.sub }}</span>
          </span>
        </button>
      </div>
    </section>

    <section class="rounded-3xl border border-slate-100 bg-white p-md shadow-sm">
      <h2 class="text-sm font-bold text-slate-900">
        {{ t('tutoring2.preferences.language') }}
      </h2>

      <div class="mt-3 space-y-2">
        <button
          v-for="l in locales"
          :key="l.id"
          type="button"
          class="flex w-full items-center gap-3 rounded-2xl border p-3 text-left transition"
          :class="
            preferences.locale === l.id
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-100 hover:border-slate-200'
          "
          :aria-pressed="preferences.locale === l.id"
          @click="chooseLocale(l.id)"
        >
          <span
            class="inline-block h-4 w-4 shrink-0 rounded-full border-2"
            :class="
              preferences.locale === l.id
                ? 'border-brand-cobalt bg-brand-cobalt'
                : 'border-slate-300'
            "
          />
          <span class="text-sm font-semibold text-slate-900">{{ l.label }}</span>
        </button>
      </div>

      <p class="mt-3 text-2xs leading-relaxed text-slate-500">
        {{ t('tutoring2.preferences.languageNote') }}
      </p>
    </section>
  </div>
</template>
