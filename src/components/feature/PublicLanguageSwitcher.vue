<!--
  PublicLanguageSwitcher.vue — compact language toggle for PUBLIC
  (non-authenticated) pages: login + register-demo wizard.

  Why a separate component from ProfileMenu's toggle:
    The post-auth toggle lives inside the ProfileMenu dropdown and
    depends on the preferences store's cross-device PATCH path (which
    hits an authenticated endpoint). On the public pages there's no
    session yet, so we drive `@/lib/i18n` directly:
      - `setLocale()` flips vue-i18n's global reactive locale (the whole
        page re-renders instantly), persists to localStorage via the
        StorageKeys.language key, and sets <html lang>. Because the
        choice is persisted, it carries straight into the app after the
        user logs in (and the http client already forwards it as the
        Accept-Language header).
      - `currentLocale()` is the source of truth for which pill is active.

  Shape: a small segmented control (ID | EN) — like a physical
  two-position rocker switch. Brand-token styled, keyboard accessible
  (real <button>s, aria-pressed, focus ring), drop it in a page corner.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { setLocale, currentLocale, type AppLocale } from '@/lib/i18n';

const { t } = useI18n();

// Local reactive mirror of the active locale. We seed it from
// currentLocale() and update it on click; vue-i18n's own reactivity
// drives the page re-render, this ref only drives the pill highlight.
const active = ref<AppLocale>(currentLocale());

const OPTIONS: { code: AppLocale; label: string }[] = [
  { code: 'id', label: 'ID' },
  { code: 'en', label: 'EN' },
];

function choose(code: AppLocale) {
  if (code === active.value) return;
  setLocale(code);
  active.value = code;
}
</script>

<template>
  <div
    class="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-white/80 p-0.5 shadow-sm backdrop-blur"
    role="group"
    :aria-label="t('languageSwitcher.label')"
  >
    <button
      v-for="opt in OPTIONS"
      :key="opt.code"
      type="button"
      class="rounded-full px-2.5 py-1 text-2xs font-bold uppercase tracking-wide transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-cobalt/60"
      :class="
        active === opt.code
          ? 'bg-brand-cobalt text-white shadow-sm'
          : 'text-slate-500 hover:text-slate-700'
      "
      :aria-pressed="active === opt.code"
      :title="
        opt.code === 'id'
          ? t('languageSwitcher.switchToId')
          : t('languageSwitcher.switchToEn')
      "
      @click="choose(opt.code)"
    >
      {{ opt.label }}
    </button>
  </div>
</template>
