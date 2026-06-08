<!--
  DemoCtaCard.vue — "Buat sekolah demo" prompt on the login screen.
  Variant A from the wireframe: tinted card with kicker + title +
  benefit chips + primary outline CTA.

  The CTA triggers Google One Tap (since the demo wizard requires
  an authenticated user). We set a session-scoped `demo_intent`
  flag first so:
    - If the user is brand-new on Google (no schools), the backend
      returns `dapat_buat_demo: true` and the auth store routes to
      /register-demo automatically.
    - If the user already has schools, RegisterDemoView guard reads
      the flag and offers a confirmation to start a parallel demo
      (TODO follow-up).
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const google = useGoogleSignIn();
const toast = useToast();

const SESSION_KEY = 'demo_intent_v1';
const busy = ref(false);

// Pre-load GIS + render the hidden chooser button so the first click on
// "Buat demo gratis" can open the Google account-chooser popup
// synchronously (browsers block popups opened after an async gap).
onMounted(() => {
  void google.prewarm();
});

async function handleClick() {
  if (busy.value) return;
  if (!google.isEnabled.value) {
    toast.error(t('auth.demo.googleNotConfigured'));
    return;
  }
  // Flag the intent so the auth store / router can prefer the demo
  // path post-Google. Cleared by the wizard after first read.
  try {
    sessionStorage.setItem(SESSION_KEY, '1');
  } catch {
    // sessionStorage may be blocked in private mode — non-fatal.
  }

  busy.value = true;
  try {
    // Open the Google account chooser reliably (popup, not FedCM/One Tap).
    // This works even when One Tap is suppressed by the browser.
    const opened = await google.openAccountChooser();
    if (!opened) {
      // GIS truly unavailable (script blocked / no client id). Surface a
      // real error and point the user at the standard Google button.
      toast.error(google.error.value ?? t('auth.demo.clickGoogleButton'));
    }
  } catch (e) {
    toast.error((e as Error).message || t('auth.demo.clickGoogleButton'));
  } finally {
    busy.value = false;
  }
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
      :disabled="busy"
      class="w-full rounded-lg border-2 border-brand-dark-blue bg-white text-brand-dark-blue py-2.5 text-[12.5px] font-extrabold hover:bg-brand-dark-blue hover:text-white disabled:opacity-60 disabled:cursor-not-allowed disabled:hover:bg-white disabled:hover:text-brand-dark-blue transition-colors flex items-center justify-center gap-2"
      @click="handleClick"
    >
      <svg
        v-if="busy"
        class="w-3.5 h-3.5 animate-spin"
        viewBox="0 0 24 24"
        fill="none"
      >
        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" stroke-opacity="0.25" />
        <path d="M22 12a10 10 0 0 1-10 10" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
      </svg>
      <svg
        v-else
        xmlns="http://www.w3.org/2000/svg"
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z" />
        <path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z" />
        <path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0" />
        <path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5" />
      </svg>
      {{ t('auth.demo.createButton') }}
    </button>

    <div class="mt-2.5 flex items-center justify-center gap-2 flex-wrap text-[10px] text-slate-500">
      <span class="inline-flex items-center gap-1">
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        {{ t('auth.demo.twoMinSetup') }}
      </span>
      <span class="text-slate-300">·</span>
      <span class="inline-flex items-center gap-1">
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        {{ t('auth.demo.googleSignIn') }}
      </span>
      <span class="text-slate-300">·</span>
      <span class="inline-flex items-center gap-1">
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        {{ t('auth.demo.noCardRequired') }}
      </span>
    </div>
  </div>
</template>
