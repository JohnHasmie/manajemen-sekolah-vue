<!--
  OtpForm.vue — 6-digit OTP step.
  Mirrors Flutter's `AuthFormBuilderMixin.buildOtpStep` / `otp_helper.dart`.

  • 6 inputs with auto-advance and backspace-to-previous.
  • Resend countdown (60s) — calling `auth.login(pendingEmail, ...)` again
    would reset the OTP flow, so for now resend triggers the existing
    login call.
  • Shows `otp_debug` from dev backend when present.
-->
<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';

const { t } = useI18n();
const auth = useAuthStore();

const digits = ref<string[]>(['', '', '', '', '', '']);
const inputs = ref<HTMLInputElement[]>([]);
const countdown = ref(60);
let timer: ReturnType<typeof setInterval> | null = null;

const otp = computed(() => digits.value.join(''));
const isValid = computed(() => otp.value.length === 6);

onMounted(() => {
  startCountdown();
  nextTick(() => inputs.value[0]?.focus());
});

onUnmounted(() => {
  if (timer) clearInterval(timer);
});

function startCountdown() {
  countdown.value = 60;
  if (timer) clearInterval(timer);
  timer = setInterval(() => {
    if (countdown.value > 0) countdown.value -= 1;
    else if (timer) clearInterval(timer);
  }, 1000);
}

function onInput(idx: number, event: Event) {
  const input = event.target as HTMLInputElement;
  const value = input.value.replace(/\D/g, '');
  digits.value[idx] = value.slice(-1);
  if (value && idx < 5) {
    nextTick(() => inputs.value[idx + 1]?.focus());
  }
}

function onKeydown(idx: number, event: KeyboardEvent) {
  if (event.key === 'Backspace' && !digits.value[idx] && idx > 0) {
    nextTick(() => inputs.value[idx - 1]?.focus());
  }
}

function onPaste(event: ClipboardEvent) {
  event.preventDefault();
  const text = event.clipboardData?.getData('text') ?? '';
  const cleaned = text.replace(/\D/g, '').slice(0, 6);
  for (let i = 0; i < 6; i += 1) {
    digits.value[i] = cleaned[i] ?? '';
  }
  const next = Math.min(cleaned.length, 5);
  nextTick(() => inputs.value[next]?.focus());
}

async function handleSubmit() {
  if (!isValid.value) return;
  try {
    await auth.verifyOtp(otp.value);
  } catch {
    // store.error → toast in LoginView.
  }
}

async function handleResend() {
  // Re-trigger the login call with the cached email.
  if (countdown.value > 0 || !auth.pendingEmail) return;
  // We can't resend without the password; instead, ask user to go back.
  auth.goBack();
}
</script>

<template>
  <div class="space-y-6">
    <header>
      <h2 class="text-[17px] font-black text-slate-900 tracking-[-0.3px]">
        {{ t('auth.otp.title') }}
      </h2>
      <p class="text-[12px] text-slate-500 font-semibold mt-1 leading-relaxed">
        {{ t('auth.otp.sentTo') }}
        <span class="font-bold text-slate-700">{{ auth.pendingEmail }}</span>.
      </p>
      <div
        v-if="auth.otpDebug"
        class="mt-2 text-[10px] font-bold text-amber-700 bg-amber-50 border border-amber-100 rounded px-2 py-0.5 inline-block"
      >
        [DEBUG] OTP: {{ auth.otpDebug }}
      </div>
    </header>

    <form @submit.prevent="handleSubmit" class="space-y-6">
      <div class="space-y-2">
        <label class="block text-[11px] font-extrabold text-slate-700 tracking-[0.4px] uppercase">
          {{ t('auth.otp.label') }}
        </label>
        <div class="flex justify-between gap-2" @paste="onPaste">
          <input
            v-for="(_, idx) in digits"
            :key="idx"
            :ref="(el) => { if (el) inputs[idx] = el as HTMLInputElement }"
            v-model="digits[idx]"
            type="text"
            inputmode="numeric"
            maxlength="1"
            autocomplete="one-time-code"
            class="w-full h-14 text-center text-xl font-black rounded-xl border border-slate-200 bg-slate-50 focus:border-brand-cobalt focus:ring-0 focus:outline-none transition-all"
            :disabled="auth.isLoading"
            @input="onInput(idx, $event)"
            @keydown="onKeydown(idx, $event)"
          />
        </div>
      </div>

      <button
        type="submit"
        class="w-full rounded-xl bg-gradient-to-br from-brand-dark-blue to-brand-cobalt hover:opacity-90 disabled:from-slate-300 disabled:to-slate-300 text-white font-black py-[14px] shadow-lg shadow-brand-dark-blue/30 disabled:shadow-none transition-all flex items-center justify-center gap-2"
        :disabled="!isValid || auth.isLoading"
      >
        <svg
          v-if="auth.isLoading"
          class="w-4 h-4 animate-spin"
          viewBox="0 0 24 24"
          fill="none"
        >
          <circle
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            stroke-width="3"
            stroke-opacity="0.25"
          />
          <path
            d="M22 12a10 10 0 0 1-10 10"
            stroke="currentColor"
            stroke-width="3"
            stroke-linecap="round"
          />
        </svg>
        <span class="text-[13.5px] tracking-wide uppercase">{{ auth.isLoading ? t('auth.otp.verifying') : t('auth.otp.submit') }}</span>
      </button>
    </form>

    <div class="flex flex-col items-center gap-3 pt-2">
      <button
        type="button"
        :disabled="countdown > 0"
        class="text-[12px] font-extrabold text-brand-cobalt hover:underline disabled:text-slate-400 disabled:no-underline"
        @click="handleResend"
      >
        <span v-if="countdown > 0">{{ t('auth.otp.resendCountdown', { countdown }) }}</span>
        <span v-else>{{ t('auth.otp.resend') }}</span>
      </button>

      <button
        type="button"
        class="text-[12px] font-extrabold text-slate-500 hover:text-slate-800"
        @click="auth.goBack()"
      >
        {{ t('auth.backToLogin') }}
      </button>
    </div>
  </div>
</template>
