<!--
  AdminSecuritySettingsView.vue — "Keamanan & Aktivasi Akun".

  Exposes two per-school security toggles whose backend already lives
  on main (SystemSettingsController):

    1. Aktivasi Akun (Opsi B) — account_activation_mode + activation_channel
       GET/PUT /system/account-activation-settings
       When ON, adding guru/murid/staf creates a password-less account
       and sends a set-password link via the chosen channel (email /
       WhatsApp / both) instead of a default password.

    2. Wajib OTP saat login (2FA) — login_otp_required
       GET/PUT /system/login-otp-settings
       When ON, members enter an emailed OTP after email + password.

  Interaction: each control auto-saves on change (PUT the one field
  that changed), with an optimistic flip that reverts on failure and a
  toast confirmation — matching the app's other settings surfaces.

  Ability gate: `school.settings.view` admits the page (route guard +
  hub tile), `school.settings.manage` unlocks writes. Without manage
  the controls render read-only. A missing active-school context (the
  interceptor's empty-envelope rewrite) shows a "pick a school" banner.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useToast } from '@/composables/useToast';
import { useMeStore } from '@/stores/me';
import {
  SystemSecurityService,
  type ActivationChannel,
} from '@/services/system-security.service';

const router = useRouter();
const { t } = useI18n();
const toast = useToast();
const me = useMeStore();

/** Read admits the page; manage unlocks the controls. */
const canManage = computed(() => me.can('school.settings.manage'));

const isLoading = ref(true);
/** True once a GET came back with no active school context. */
const noSchoolContext = ref(false);

// ── Feature state ──────────────────────────────────────────────────
const activationMode = ref(false);
const activationChannel = ref<ActivationChannel>('email');
const loginOtpRequired = ref(false);

// Per-control in-flight flags so a save spinner shows on the exact
// row being written (and the control disables to prevent double-fire).
const savingActivationMode = ref(false);
const savingChannel = ref(false);
const savingOtp = ref(false);

const CHANNELS: { value: ActivationChannel; icon: string; labelKey: string }[] = [
  { value: 'email', icon: 'mail', labelKey: 'channel_email' },
  { value: 'whatsapp', icon: 'message-circle', labelKey: 'channel_whatsapp' },
  { value: 'both', icon: 'link', labelKey: 'channel_both' },
];

const tp = (k: string) => t(`admin.sekolah.security_settings.${k}`);

async function loadAll() {
  isLoading.value = true;
  try {
    const [activation, otp] = await Promise.all([
      SystemSecurityService.getAccountActivation(),
      SystemSecurityService.getLoginOtp(),
    ]);
    // Either endpoint returning null means the same thing: no active
    // school selected. Show the empty-context banner and keep defaults.
    if (activation === null || otp === null) {
      noSchoolContext.value = true;
      return;
    }
    noSchoolContext.value = false;
    activationMode.value = activation.account_activation_mode;
    activationChannel.value = activation.activation_channel;
    loginOtpRequired.value = otp.login_otp_required;
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    isLoading.value = false;
  }
}

onMounted(loadAll);

/** Guard: block writes when read-only or busy. */
function writable(): boolean {
  return canManage.value && !noSchoolContext.value;
}

async function toggleActivationMode() {
  if (!writable() || savingActivationMode.value) return;
  const next = !activationMode.value;
  activationMode.value = next; // optimistic
  savingActivationMode.value = true;
  try {
    await SystemSecurityService.updateAccountActivation({
      account_activation_mode: next,
    });
    toast.success(tp('toast_saved'));
  } catch (e) {
    activationMode.value = !next; // revert
    toast.error((e as Error).message);
  } finally {
    savingActivationMode.value = false;
  }
}

async function pickChannel(next: ActivationChannel) {
  if (!writable() || savingChannel.value) return;
  if (next === activationChannel.value) return;
  const prev = activationChannel.value;
  activationChannel.value = next; // optimistic
  savingChannel.value = true;
  try {
    await SystemSecurityService.updateAccountActivation({
      activation_channel: next,
    });
    toast.success(tp('toast_saved'));
  } catch (e) {
    activationChannel.value = prev; // revert
    toast.error((e as Error).message);
  } finally {
    savingChannel.value = false;
  }
}

async function toggleOtp() {
  if (!writable() || savingOtp.value) return;
  const next = !loginOtpRequired.value;
  loginOtpRequired.value = next; // optimistic
  savingOtp.value = true;
  try {
    await SystemSecurityService.updateLoginOtp({ login_otp_required: next });
    toast.success(tp('toast_saved'));
  } catch (e) {
    loginOtpRequired.value = !next; // revert
    toast.error((e as Error).message);
  } finally {
    savingOtp.value = false;
  }
}

function goBack() {
  router.push({ name: 'admin.settings' });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ tp('back_to_settings') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="tp('header_kicker')"
      :title="tp('header_title')"
      :meta="tp('header_meta')"
      :live-dot="false"
    />

    <!-- Read-only notice — page is viewable but the user can't write. -->
    <div
      v-if="!canManage"
      class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-[12px] text-amber-800"
    >
      <NavIcon name="lock" :size="14" class="mt-0.5 flex-shrink-0" />
      <span>{{ tp('readonly_notice') }}</span>
    </div>

    <!-- No active school context. -->
    <div
      v-else-if="noSchoolContext"
      class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-[12px] text-amber-800"
    >
      <NavIcon name="shield" :size="14" class="mt-0.5 flex-shrink-0" />
      <span>{{ tp('no_school_context') }}</span>
    </div>

    <!-- Loading skeleton -->
    <div v-if="isLoading" class="space-y-3">
      <div class="h-28 bg-white border border-slate-200 rounded-2xl animate-pulse" />
      <div class="h-24 bg-white border border-slate-200 rounded-2xl animate-pulse" />
    </div>

    <template v-else>
      <!-- ── Section 1: Aktivasi Akun (Opsi B) ── -->
      <div class="flex items-center gap-3 px-1 pt-1">
        <div class="w-9 h-9 rounded-xl bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0">
          <NavIcon name="user-check" :size="16" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-black text-slate-900">{{ tp('section_activation_title') }}</p>
          <p class="text-2xs text-slate-500">{{ tp('section_activation_desc') }}</p>
        </div>
      </div>

      <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <!-- Activation-mode toggle row -->
        <div class="px-4 py-3.5 flex items-start gap-3">
          <div class="flex-1 min-w-0">
            <p class="text-[13.5px] font-bold text-slate-900">{{ tp('activation_toggle_label') }}</p>
            <p class="text-2xs text-slate-500 mt-0.5 leading-relaxed">{{ tp('activation_toggle_help') }}</p>
          </div>
          <button
            type="button"
            role="switch"
            :aria-checked="activationMode"
            :aria-label="tp('activation_toggle_label')"
            class="mt-0.5 inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            :class="activationMode ? 'bg-role-admin' : 'bg-slate-300'"
            :disabled="!writable() || savingActivationMode"
            @click="toggleActivationMode"
          >
            <span
              class="inline-block h-4 w-4 transform rounded-full bg-white transition"
              :class="activationMode ? 'translate-x-[18px]' : 'translate-x-0.5'"
            ></span>
          </button>
        </div>

        <!-- Channel selector — only when activation mode is ON. -->
        <div v-if="activationMode" class="px-4 pb-4 pt-1 border-t border-slate-100">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-2 mt-3">
            {{ tp('channel_label') }}
          </p>
          <div class="grid grid-cols-3 gap-2">
            <button
              v-for="c in CHANNELS"
              :key="c.value"
              type="button"
              class="rounded-xl border px-2 py-2.5 flex flex-col items-center gap-1 text-[12px] font-bold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              :class="activationChannel === c.value
                ? 'border-role-admin bg-role-admin/10 text-role-admin'
                : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'"
              :disabled="!writable() || savingChannel"
              @click="pickChannel(c.value)"
            >
              <NavIcon :name="c.icon" :size="16" />
              {{ tp(c.labelKey) }}
            </button>
          </div>
          <p class="text-2xs text-slate-400 mt-2 leading-relaxed">{{ tp('channel_help') }}</p>
        </div>
      </section>

      <!-- ── Section 2: OTP Login (2FA) ── -->
      <div class="flex items-center gap-3 px-1 pt-3">
        <div class="w-9 h-9 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center flex-shrink-0">
          <NavIcon name="shield" :size="16" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-black text-slate-900">{{ tp('section_otp_title') }}</p>
          <p class="text-2xs text-slate-500">{{ tp('section_otp_desc') }}</p>
        </div>
      </div>

      <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <div class="px-4 py-3.5 flex items-start gap-3">
          <div class="flex-1 min-w-0">
            <p class="text-[13.5px] font-bold text-slate-900">{{ tp('otp_toggle_label') }}</p>
            <p class="text-2xs text-slate-500 mt-0.5 leading-relaxed">{{ tp('otp_toggle_help') }}</p>
          </div>
          <button
            type="button"
            role="switch"
            :aria-checked="loginOtpRequired"
            :aria-label="tp('otp_toggle_label')"
            class="mt-0.5 inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            :class="loginOtpRequired ? 'bg-emerald-600' : 'bg-slate-300'"
            :disabled="!writable() || savingOtp"
            @click="toggleOtp"
          >
            <span
              class="inline-block h-4 w-4 transform rounded-full bg-white transition"
              :class="loginOtpRequired ? 'translate-x-[18px]' : 'translate-x-0.5'"
            ></span>
          </button>
        </div>
      </section>
    </template>
  </div>
</template>
