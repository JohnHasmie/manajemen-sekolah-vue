<!--
  LoginView.vue — outer chrome for the auth flow.
  Mirrors Flutter's `lib/features/auth/presentation/screens/login_screen.dart`:
    - Brand-gradient hero band (full at login step, compact at other steps)
    - Form-card overlapping the band by -24px
    - Dispatches body to LoginForm / OtpForm / SchoolPicker / RolePicker
      based on `authStore.step`
    - Footer with "Lupa kata sandi?" + "Hubungi admin"
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';

const { t } = useI18n();

import BrandBand from './components/BrandBand.vue';
import FormCard from './components/FormCard.vue';
import LoginForm from './components/LoginForm.vue';
import OtpForm from './components/OtpForm.vue';
import SchoolPicker from './components/SchoolPicker.vue';
import RolePicker from './components/RolePicker.vue';
import ForgotPasswordModal from './components/ForgotPasswordModal.vue';
import HelpRequestModal from './components/HelpRequestModal.vue';
import Toast from '@/components/ui/Toast.vue';
import PublicLanguageSwitcher from '@/components/feature/PublicLanguageSwitcher.vue';

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();

const showForgot = ref(false);
const showHelp = ref(false);
const toast = ref<{ message: string; tone: 'error' | 'success' } | null>(null);

const isLoginStep = computed(() => auth.step === 'login');

// Surface any initial error passed via the query string
// (the 401 interceptor in http.ts redirects with ?reason=...).
onMounted(async () => {
  // If the user is already fully authenticated, redirect immediately
  // instead of showing the "Menyiapkan Dashboard..." spinner forever.
  if (auth.isAuthenticated && auth.step === 'done') {
    router.replace('/');
    return;
  }
  if (auth.step === 'register_demo') {
    router.replace('/register-demo');
    return;
  }

  await auth.checkHealth();
  const reason = route.query.reason;
  if (typeof reason === 'string' && reason.length > 0) {
    toast.value = { message: reason, tone: 'error' };
  }
});

// React to step transitions: redirect once auth completes OR when
// Google login returned `dapat_buat_demo` (user has no schools).
watch(
  () => auth.step,
  (step) => {
    if (step === 'done') {
      router.replace('/');
    } else if (step === 'register_demo') {
      // No matching FormCard branch here — route straight to the
      // wizard. The card otherwise renders empty since no template
      // case matches 'register_demo'.
      router.replace('/register-demo');
    }
  },
);

// Surface errors raised by the store as a toast.
watch(
  () => auth.error,
  (msg) => {
    if (msg) toast.value = { message: msg, tone: 'error' };
  },
);

const whatsappUrl = computed(() => {
  const num = import.meta.env.VITE_WHATSAPP_SUPPORT ?? '6285179819002';
  return `https://wa.me/${num}`;
});
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-50">
    <!-- Public language switcher — floats top-right over the brand band. -->
    <div class="absolute top-4 right-4 z-20">
      <PublicLanguageSwitcher />
    </div>

    <BrandBand :compact="!isLoginStep" />

    <!-- Form-card overlaps the gradient by -24px. -->
    <div class="px-md sm:px-lg -mt-6 z-10">
      <div class="mx-auto w-full max-w-md">
        <FormCard>
          <template v-if="auth.step === 'login'">
            <LoginForm
              @forgot="showForgot = true"
            />
          </template>

          <template v-else-if="auth.step === 'otp'">
            <OtpForm />
          </template>

          <template v-else-if="auth.step === 'school'">
            <SchoolPicker />
          </template>

          <template v-else-if="auth.step === 'role'">
            <RolePicker />
          </template>

          <template v-else-if="auth.step === 'register_demo'">
            <!-- Brief fallback while the watch() redirects to /register-demo. -->
            <div class="py-12 flex flex-col items-center justify-center gap-4">
              <svg class="w-8 h-8 animate-spin text-brand-cobalt" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" stroke-opacity="0.25" />
                <path d="M22 12a10 10 0 0 1-10 10" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
              </svg>
              <p class="text-[14px] font-black text-slate-400 uppercase tracking-widest animate-pulse">{{ t('auth.loadingDemoWizard') }}</p>
            </div>
          </template>

          <template v-else-if="auth.step === 'done'">
            <div class="py-12 flex flex-col items-center justify-center gap-4">
              <svg class="w-8 h-8 animate-spin text-brand-cobalt" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" stroke-opacity="0.25" />
                <path d="M22 12a10 10 0 0 1-10 10" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
              </svg>
              <p class="text-[14px] font-black text-slate-400 uppercase tracking-widest animate-pulse">{{ t('auth.loadingDashboard') }}</p>
              
              <button 
                type="button"
                class="mt-4 text-[12px] font-bold text-slate-400 hover:text-brand-cobalt transition-colors"
                @click="auth.logout()"
              >
                {{ t('auth.notYourAccountLogout') }}
              </button>
            </div>
          </template>
        </FormCard>
      </div>
    </div>

    <ForgotPasswordModal v-if="showForgot" @close="showForgot = false" />
    <HelpRequestModal v-if="showHelp" @close="showHelp = false" />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
