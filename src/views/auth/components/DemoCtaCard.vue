<!--
  DemoCtaCard.vue — "Buat sekolah demo" prompt on the login screen.
  Variant A from the wireframe: tinted card with kicker + title +
  benefit chips + a REAL Google Sign-In button.

  ── Why a real GIS button (not a custom button) ──────────────────────
  The demo wizard requires an authenticated user, so the CTA must sign
  the user in with Google first. The backend requires a Google id_token
  (GoogleLoginRequest → `id_token` required), which means the GIS
  id_token flow — and GIS only emits that token from a button the user
  clicks DIRECTLY. A custom button that proxies a synthetic `.click()`
  to a hidden GIS button is silently ignored by GIS (its rendered button
  only honours trusted, user-initiated clicks) — that was the previous
  "nothing happens on click" bug. So we render the actual GIS button
  here and let the user click it.

  On callback (shared `handleCredentialResponse` in useGoogleSignIn):
    - Brand-new Google user with no schools → backend returns
      `dapat_buat_demo: true` → auth store routes to /register-demo.
    - User who already has schools → normal login → dashboard.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';

const { t } = useI18n();
const google = useGoogleSignIn();

const SESSION_KEY = 'demo_intent_v1';
const googleButtonRef = ref<HTMLDivElement | null>(null);

// Flag the demo intent for any future post-Google branch that wants to
// distinguish "came from the demo CTA" from a plain login. Functionally
// inert today (routing is driven by the backend `dapat_buat_demo` flag),
// kept for the documented follow-up. Wrapped because sessionStorage can
// throw in private mode.
function flagDemoIntent() {
  try {
    sessionStorage.setItem(SESSION_KEY, '1');
  } catch {
    // non-fatal
  }
}

// Render the real Google button into the card. The user clicks it
// directly, which opens Google's account-chooser popup and yields an
// id_token via the composable's shared callback.
onMounted(async () => {
  if (!google.isEnabled.value) return;
  flagDemoIntent();
  if (googleButtonRef.value) {
    await google.mountButton(googleButtonRef.value, {
      theme: 'filled_blue',
      text: 'continue_with',
      width: googleButtonRef.value.clientWidth || 320,
    });
  } else {
    // Container not in the DOM yet — still prime GIS so the login form's
    // own button (and a later mount) work.
    await google.ensureReady();
  }
});

// Copy the current URL so a user stuck in an in-app browser (Threads/IG/…)
// can paste it into a real browser where Google sign-in / demo works.
const linkCopied = ref(false);
async function copyCurrentLink() {
  try {
    await navigator.clipboard.writeText(window.location.href);
    linkCopied.value = true;
    setTimeout(() => { linkCopied.value = false; }, 2000);
  } catch {
    // Clipboard may be blocked in the webview; the URL is still in the bar.
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

    <!-- In-app browser (Threads/IG/FB/…) OR GIS failed to load: creating a
         demo needs Google sign-in, which can't work here. Tell the user to
         open in a real browser + offer a copy-link. -->
    <div
      v-if="google.isInAppBrowser.value || google.error.value === 'GIS_LOAD_FAILED'"
      class="w-full rounded-lg border-2 border-dashed border-amber-300 bg-amber-50 py-2.5 px-3 text-center text-[11px] font-bold text-amber-800 leading-relaxed"
    >
      <p>{{ google.isInAppBrowser.value ? t('auth.demo.googleInAppBrowser') : t('auth.googleLoadFailed') }}</p>
      <button
        v-if="google.isInAppBrowser.value"
        type="button"
        class="mt-2 inline-flex items-center gap-1.5 rounded-lg bg-white border border-amber-300 px-2.5 py-1.5 text-[10.5px] font-extrabold text-amber-900 hover:bg-amber-100 transition-colors"
        @click="copyCurrentLink"
      >
        <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>
        {{ linkCopied ? t('auth.linkCopied') : t('auth.copyLink') }}
      </button>
    </div>

    <!-- Real Google Sign-In button. Clicking it opens the account
         chooser and runs the demo/login flow. -->
    <div v-else-if="google.isEnabled.value" class="flex justify-center min-h-[44px]">
      <div
        v-show="google.isReady.value"
        ref="googleButtonRef"
        class="w-full flex justify-center"
      />
      <!-- Loading state while the GIS script loads -->
      <div
        v-if="!google.isReady.value"
        class="w-full rounded-lg border-2 border-brand-dark-blue/30 bg-white/60 py-2.5 flex items-center justify-center gap-3 animate-pulse"
      >
        <div class="w-3.5 h-3.5 rounded-full bg-brand-dark-blue/20"></div>
        <span class="text-[11px] font-extrabold text-brand-dark-blue/50 uppercase tracking-widest">{{ t('auth.loadingGoogle') }}</span>
      </div>
    </div>

    <!-- Fallback when Google isn't configured (no VITE_GOOGLE_CLIENT_ID). -->
    <div
      v-else
      class="w-full rounded-lg border-2 border-dashed border-slate-300 bg-white/60 py-2.5 px-3 text-center text-[11px] font-bold text-slate-500"
    >
      {{ t('auth.demo.googleNotConfigured') }}
    </div>

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
