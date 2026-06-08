<!--
  LoginForm.vue — email + password step.
  Mirrors Flutter's `LoginFormBuilderMixin.buildLoginForm`.

  • "Ingat saya" checkbox is intentionally omitted — Sanctum tokens
    persist by default, matching the upstream design.
  • Demo accounts skip OTP; the auth store's `_applyResponse` handles
    both branches transparently.
  • Google Sign-In stub: surfaces a button if VITE_GOOGLE_CLIENT_ID is
    set. Task #12 will wire the GIS script + callback fully.
-->
<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';
import DemoCtaCard from './DemoCtaCard.vue';

const { t } = useI18n();
const auth = useAuthStore();

const email = ref('');
const password = ref('');
const showPassword = ref(false);
const localError = ref<string | null>(null);

const emit = defineEmits<{ forgot: [] }>();

const google = useGoogleSignIn();
const googleButtonRef = ref<HTMLDivElement | null>(null);

onMounted(async () => {
  if (!google.isEnabled.value) return;
  // Initialize GIS once (idempotent across all call sites) and render
  // the real Google button. `mountButton` waits for init internally, so
  // the button paints as soon as the GIS script is ready.
  if (googleButtonRef.value) {
    await google.mountButton(googleButtonRef.value);
  } else {
    // Container not in the DOM yet (edge case): still init GIS so the
    // demo CTA's account chooser is primed.
    await google.ensureReady();
  }
});

watch(
  () => google.error.value,
  (msg) => {
    if (msg) localError.value = msg;
  },
);

function validate(): boolean {
  if (!email.value.trim()) {
    localError.value = t('auth.errors.emailRequired');
    return false;
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value.trim())) {
    localError.value = t('auth.errors.emailInvalid');
    return false;
  }
  if (!password.value) {
    localError.value = t('auth.errors.passwordRequired');
    return false;
  }
  localError.value = null;
  return true;
}

async function handleSubmit() {
  if (!validate()) return;
  try {
    await auth.login(email.value.trim(), password.value);
  } catch {
    // store.error already set; LoginView surfaces it as a toast.
  }
}

</script>

<template>
  <div class="space-y-6">
    <header>
      <h2 class="text-[17px] font-black text-slate-900 tracking-[-0.3px]">
        {{ t('auth.welcomeBack') }}
      </h2>
      <p class="text-[12px] text-slate-500 font-semibold mt-1 leading-relaxed">
        {{ t('auth.signInSubtitle') }}
      </p>
    </header>

    <!-- Offline banner -->
    <div
      v-if="!auth.serverOnline"
      class="rounded-xl bg-red-50 px-md py-sm text-[11.5px] text-red-600 border border-red-100 flex items-center gap-2"
    >
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
      <span class="font-bold">{{ t('auth.errors.serverOffline') }}</span>
    </div>

    <form class="space-y-md" novalidate @submit.prevent="handleSubmit">
      <!-- Email Field -->
      <div class="space-y-1.5">
        <label
          for="email"
          class="block text-[11px] font-extrabold text-slate-700 tracking-[0.4px]"
        >EMAIL <span class="text-red-500">*</span></label>
        <div class="relative">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-3.92 7.94"/></svg>
          </div>
          <input
            id="email"
            v-model="email"
            type="email"
            autocomplete="email"
            inputmode="email"
            :placeholder="t('auth.emailPlaceholder')"
            class="w-full rounded-xl border border-slate-200 bg-slate-50 pl-10 pr-md py-[14px] text-[13px] font-medium text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:ring-0 focus:outline-none transition-all"
            :disabled="auth.isLoading"
          />
        </div>
      </div>

      <!-- Password Field -->
      <div class="space-y-1.5">
        <label
          for="password"
          class="block text-[11px] font-extrabold text-slate-700 tracking-[0.4px]"
        >KATA SANDI <span class="text-red-500">*</span></label>
        <div class="relative">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          </div>
          <input
            id="password"
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="current-password"
            :placeholder="t('auth.passwordPlaceholder')"
            class="w-full rounded-xl border border-slate-200 bg-slate-50 pl-10 pr-10 py-[14px] text-[13px] font-medium text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:ring-0 focus:outline-none transition-all"
            :disabled="auth.isLoading"
          />
          <button
            type="button"
            class="absolute inset-y-0 right-2 my-auto h-8 w-8 grid place-items-center text-slate-400 hover:text-slate-600 rounded-full"
            @click="showPassword = !showPassword"
          >
            <svg v-if="!showPassword" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.52 13.52 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/><line x1="2" x2="22" y1="2" y2="22"/></svg>
          </button>
        </div>
        <div class="flex justify-end pt-1">
          <button
            type="button"
            class="text-[12px] font-extrabold text-brand-cobalt hover:underline"
            @click="emit('forgot')"
          >
            {{ t('auth.forgotPassword') }}
          </button>
        </div>
      </div>

      <p
        v-if="localError"
        class="text-sm text-status-danger -mt-1 font-medium"
        role="alert"
      >
        {{ localError }}
      </p>

      <button
        type="submit"
        :disabled="auth.isLoading || !auth.serverOnline"
        class="w-full rounded-xl bg-gradient-to-br from-brand-dark-blue to-brand-cobalt hover:opacity-90 disabled:from-slate-300 disabled:to-slate-300 text-white font-black py-[14px] shadow-lg shadow-brand-dark-blue/30 disabled:shadow-none transition-all flex items-center justify-center gap-2"
      >
        <template v-if="auth.isLoading">
          <svg class="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" stroke-opacity="0.25" />
            <path d="M22 12a10 10 0 0 1-10 10" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
          </svg>
          <span class="text-[13.5px] tracking-wide uppercase">{{ t('auth.verifying') }}</span>
        </template>
        <template v-else>
          <span class="text-[13.5px] tracking-wide">{{ t('auth.signIn') }}</span>
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
        </template>
      </button>
    </form>

    <!-- Divider + Google (GIS-rendered button) -->
    <div class="space-y-4">
      <div class="relative flex items-center">
        <div class="flex-grow border-t border-slate-200"></div>
        <span class="flex-shrink mx-2.5 text-[10px] font-extrabold text-slate-400 uppercase tracking-widest">{{ t('auth.or') }}</span>
        <div class="flex-grow border-t border-slate-200"></div>
      </div>

      <!-- Google Button (GIS) -->
      <div v-if="google.isEnabled.value" class="flex justify-center min-h-[44px]">
        <div 
          v-show="google.isReady.value" 
          ref="googleButtonRef" 
          class="w-full flex justify-center"
        />
        <!-- Loading state while GIS script loads -->
        <div 
          v-if="!google.isReady.value" 
          class="w-full rounded-xl border-1.5 border-slate-200 bg-slate-50 py-3 flex items-center justify-center gap-3 animate-pulse"
        >
          <div class="w-4 h-4 rounded-full bg-slate-200"></div>
          <span class="text-[12px] font-bold text-slate-400 uppercase tracking-widest">{{ t('auth.loadingGoogle') }}</span>
        </div>
      </div>

      <!-- Fallback button if VITE_GOOGLE_CLIENT_ID is missing -->
      <button
        v-else
        type="button"
        class="w-full rounded-xl border-1.5 border-slate-200 bg-white py-3 flex items-center justify-center gap-2.5 text-[13px] font-extrabold text-slate-800 hover:bg-slate-50 transition-colors"
        @click="localError = t('auth.errors.googleNotConfigured')"
      >
        <img src="/icon/google_logo.png" class="w-[18px] h-[18px]" alt="Google" />
        {{ t('auth.continueWithGoogle') }}
      </button>
    </div>

    <!-- Demo CTA — calon customer yang belum punya sekolah -->
    <DemoCtaCard />

    <!-- Help Row — "Hubungi admin" tetap ada untuk user yang sebenarnya
         sudah punya sekolah di Kamiledu tapi belum dapat akun. -->
    <div class="flex flex-col items-center gap-3 pt-1">
      <button
        type="button"
        class="flex items-center gap-1.5 text-[11.5px] font-bold text-slate-600 hover:text-slate-900"
        @click="emit('forgot')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/></svg>
        <!-- TODO(i18n): review -->
        <span>{{ t('auth.needHelp') }}</span>
      </button>

      <a
        href="https://wa.me/6285179819002"
        target="_blank"
        class="text-[11.5px] font-semibold text-slate-500"
      >
        <!-- TODO(i18n): review -->
        {{ t('auth.contactAdmin') }}
      </a>
    </div>
  </div>
</template>
