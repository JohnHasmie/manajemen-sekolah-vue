<!--
  DemoCtaCard.vue — "Coba demo gratis" prompt on the login screen.

  Simplified to a plain "Daftar Demo" button. The Google login on this
  card conflicted with the top-of-form Google login and often landed
  multi-tenant users on the SchoolPicker for their existing tenants
  instead of the demo path they wanted. Now this button just routes to
  /register-demo — the wizard itself asks for Google identity at its
  Data Diri step where the context makes the ask obvious.
-->
<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';

const { t } = useI18n();
const router = useRouter();

function goToWizard() {
  router.push({ path: '/register-demo', query: { intent: 'demo' } });
}
</script>

<template>
  <div
    class="relative rounded-xl border border-dashed border-brand-cobalt/40 bg-gradient-to-br from-blue-50 to-indigo-50 p-4"
  >
    <span
      class="absolute -top-2 left-3 inline-flex items-center gap-1 bg-amber-300 text-amber-900 text-[9px] font-extrabold tracking-widest uppercase px-2 py-0.5 rounded-full"
    >
      {{ t('auth.demo.new') }}
    </span>

    <div class="flex items-center gap-1.5 mb-1">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="text-brand-cobalt"
        aria-hidden="true"
      >
        <path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3z" />
      </svg>
      <p class="text-[10px] font-extrabold text-brand-cobalt tracking-[0.08em] uppercase">
        {{ t('auth.demo.newToKamilEdu') }}
      </p>
    </div>

    <h3 class="text-[14px] font-black text-brand-dark-blue mb-1 leading-tight">
      {{ t('auth.demo.title') }}
    </h3>
    <p class="text-[11.5px] text-slate-600 leading-relaxed mb-3">
      {{ t('auth.demo.description') }}
    </p>

    <button
      type="button"
      class="w-full inline-flex items-center justify-center gap-2 rounded-lg bg-brand-cobalt hover:bg-brand-dark-blue text-white font-bold text-[13px] py-2.5 shadow-sm transition-colors"
      @click="goToWizard"
    >
      {{ t('auth.demo.startCta') }}
      <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M5 12h14" />
        <path d="m12 5 7 7-7 7" />
      </svg>
    </button>

    <div class="mt-2.5 flex items-center justify-center gap-2 flex-wrap text-[10px] text-slate-500">
      <span class="inline-flex items-center gap-1">
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>
        {{ t('auth.demo.twoMinSetup') }}
      </span>
      <span class="text-slate-300">·</span>
      <span class="inline-flex items-center gap-1">
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>
        {{ t('auth.demo.noCardRequired') }}
      </span>
      <span class="text-slate-300">·</span>
      <span class="inline-flex items-center gap-1">
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>
        {{ t('auth.demo.trialDays', { days: 7 }) }}
      </span>
    </div>
  </div>
</template>
