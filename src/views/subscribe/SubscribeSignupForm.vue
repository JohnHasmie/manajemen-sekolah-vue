<!--
  SubscribeSignupForm.vue — the "Buat akun dan konfirmasi" card.

  Renders three progressive states depending on the parent's inputs:

  1. Not signed in
     - Blue banner hidden (handled by parent).
     - Google Sign-In button at the top.
     - "ATAU" divider.
     - Minimal form: nama sekolah/lembaga, WhatsApp, email admin.
     - Tenant type radio (Sekolah / Bimbel).

  2. Signed in with no existing tenants
     - Google Sign-In hidden (already authenticated).
     - Blue banner hidden (parent handles).
     - Minimal form + tenant type radio shown for a fresh signup.

  3. Signed in AND a demo tenant is selected (via banner or picker)
     - Google Sign-In hidden.
     - Minimal form + tenant type radio HIDDEN (the tenant already
       exists — we're just topping up subscription).
     - Only the primary "Lanjut ke pembayaran" CTA remains.

  All state is model-driven from the parent so the calculator + card
  copy + this form stay in sync via a single reactive tenantType.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from '@/components/ui/Button.vue';
import { useAuthStore } from '@/stores/auth';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';
import type { TenantType } from '@/types/subscription-billing';

const props = defineProps<{
  /** Signed-in flag; drives the Google button + hides the identity fields. */
  isAuthenticated: boolean;
  /** True when the user picked an existing demo tenant (banner or picker). */
  usingExistingTenant: boolean;
  /** Two-way bound tenant type — drives calculator + card copy in the parent. */
  tenantType: TenantType;
  /** Form fields (only shown for the new-signup path). */
  tenantName: string;
  whatsapp: string;
  adminEmail: string;
  /** Loading state for the CTA button. */
  submitting: boolean;
  /** Optional error banner text (validation or backend). */
  errorMessage?: string | null;
}>();

const emit = defineEmits<{
  'update:tenantType': [TenantType];
  'update:tenantName': [string];
  'update:whatsapp': [string];
  'update:adminEmail': [string];
  submit: [];
}>();

const { t } = useI18n();
const auth = useAuthStore();
const google = useGoogleSignIn();
const googleContainer = ref<HTMLElement | null>(null);

const showGoogle = computed(
  () => !props.isAuthenticated && google.isEnabled.value,
);
// Identity fields only make sense when we're creating a fresh tenant.
const showIdentityFields = computed(() => !props.usingExistingTenant);
const showTenantRadio = computed(() => !props.usingExistingTenant);

/**
 * Mount the real GIS button (see composable — GIS refuses synthetic
 * clicks). Re-mount whenever `showGoogle` flips on so the button
 * re-appears after logout without a hard reload.
 */
async function mountGoogleButton() {
  if (!showGoogle.value || !googleContainer.value) return;
  const width = googleContainer.value.clientWidth || 320;
  await google.mountButton(googleContainer.value, {
    width,
    theme: 'outline',
    text: 'continue_with',
  });
}

onMounted(() => {
  if (showGoogle.value) mountGoogleButton();
});

// Re-render on state changes (auth flip, layout resize) but NOT on
// every keystroke — only when the visibility itself toggles.
watch(showGoogle, (v) => {
  if (v) mountGoogleButton();
});

// Handle window resize so the pixel-width GIS button doesn't overflow
// the card on mobile.
let resizeTimer: number | null = null;
function onResize() {
  if (!showGoogle.value) return;
  if (resizeTimer !== null) window.clearTimeout(resizeTimer);
  resizeTimer = window.setTimeout(() => {
    mountGoogleButton();
  }, 200) as unknown as number;
}
onMounted(() => window.addEventListener('resize', onResize));
onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize);
  if (resizeTimer !== null) window.clearTimeout(resizeTimer);
});

function submit() {
  if (props.submitting) return;
  emit('submit');
}

// Field-level validation preview — the real validation lives in the
// parent (SubscribeView) because it also depends on the calculator
// state, but disabling the CTA locally when fields are obviously
// missing improves the UX.
const canSubmit = computed(() => {
  if (props.submitting) return false;
  if (!props.usingExistingTenant) {
    if (!props.isAuthenticated && !props.adminEmail.trim()) return false;
    if (!props.tenantName.trim()) return false;
    if (!props.whatsapp.trim()) return false;
  }
  return true;
});
</script>

<template>
  <section class="rounded-2xl border border-slate-200 bg-white p-5 sm:p-6">
    <header class="mb-4">
      <h2 class="text-base font-bold text-slate-900">
        {{ t('subscribe.form.title') }}
      </h2>
      <p class="text-xs text-slate-500 mt-1">
        {{ usingExistingTenant
            ? t('subscribe.form.subtitleExisting')
            : t('subscribe.form.subtitleNew') }}
      </p>
    </header>

    <!-- Google Sign-In — only for unauthenticated visitors -->
    <div v-if="showGoogle" class="mb-4">
      <div
        ref="googleContainer"
        data-google-intent="subscribe"
        class="w-full flex justify-center min-h-[42px]"
      />
      <p v-if="google.error.value" class="mt-2 text-[11px] text-rose-600 text-center">
        {{ google.error.value === 'IN_APP_BROWSER'
            ? t('subscribe.form.googleInAppBrowser')
            : t('subscribe.form.googleError') }}
      </p>
      <div class="mt-4 flex items-center gap-3">
        <div class="flex-1 h-px bg-slate-200" />
        <span class="text-[11px] font-semibold uppercase tracking-widest text-slate-400">
          {{ t('subscribe.form.divider') }}
        </span>
        <div class="flex-1 h-px bg-slate-200" />
      </div>
    </div>

    <!-- Signed-in badge — shows the user we already have -->
    <div
      v-else-if="isAuthenticated"
      class="mb-4 flex items-center gap-2.5 rounded-lg bg-slate-50 border border-slate-200 px-3 py-2.5"
    >
      <div class="w-8 h-8 rounded-full bg-brand-cobalt/10 text-brand-cobalt grid place-items-center text-xs font-bold">
        {{ (auth.user?.name?.[0] ?? auth.user?.email?.[0] ?? '?').toUpperCase() }}
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-[13px] font-semibold text-slate-900 truncate">
          {{ auth.user?.name || t('subscribe.form.signedInFallback') }}
        </p>
        <p class="text-[11px] text-slate-500 truncate">
          {{ auth.user?.email }}
        </p>
      </div>
    </div>

    <!-- Tenant-type radio (only for the fresh-signup path). -->
    <div v-if="showTenantRadio" class="mb-4">
      <p class="text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-2">
        {{ t('subscribe.form.tenantTypeLabel') }}
      </p>
      <div class="grid grid-cols-2 gap-2">
        <label
          class="flex items-start gap-2 rounded-lg border p-3 cursor-pointer transition-colors"
          :class="tenantType === 'sekolah'
            ? 'border-brand-cobalt bg-brand-50/50'
            : 'border-slate-200 hover:border-slate-300'"
        >
          <input
            type="radio"
            name="tenant-type"
            value="sekolah"
            class="mt-0.5 h-4 w-4 text-brand-cobalt focus:ring-brand-cobalt"
            :checked="tenantType === 'sekolah'"
            @change="emit('update:tenantType', 'sekolah')"
          />
          <span class="flex-1 min-w-0">
            <span class="block text-[13px] font-semibold text-slate-900">
              {{ t('subscribe.form.tenantTypeSekolah') }}
            </span>
            <span class="block text-[11px] text-slate-500 mt-0.5">
              {{ t('subscribe.form.tenantTypeSekolahHint') }}
            </span>
          </span>
        </label>
        <label
          class="flex items-start gap-2 rounded-lg border p-3 cursor-pointer transition-colors"
          :class="tenantType === 'bimbel'
            ? 'border-brand-cobalt bg-brand-50/50'
            : 'border-slate-200 hover:border-slate-300'"
        >
          <input
            type="radio"
            name="tenant-type"
            value="bimbel"
            class="mt-0.5 h-4 w-4 text-brand-cobalt focus:ring-brand-cobalt"
            :checked="tenantType === 'bimbel'"
            @change="emit('update:tenantType', 'bimbel')"
          />
          <span class="flex-1 min-w-0">
            <span class="block text-[13px] font-semibold text-slate-900">
              {{ t('subscribe.form.tenantTypeBimbel') }}
            </span>
            <span class="block text-[11px] text-slate-500 mt-0.5">
              {{ t('subscribe.form.tenantTypeBimbelHint') }}
            </span>
          </span>
        </label>
      </div>
    </div>

    <!-- Identity fields — only for fresh signup. -->
    <div v-if="showIdentityFields" class="space-y-3 mb-4">
      <div>
        <label class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
          {{ tenantType === 'bimbel'
              ? t('subscribe.form.tenantNameLabelBimbel')
              : t('subscribe.form.tenantNameLabelSekolah') }}
        </label>
        <input
          type="text"
          class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
          :placeholder="tenantType === 'bimbel'
              ? t('subscribe.form.tenantNamePlaceholderBimbel')
              : t('subscribe.form.tenantNamePlaceholderSekolah')"
          :value="tenantName"
          @input="emit('update:tenantName', ($event.target as HTMLInputElement).value)"
        />
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
            {{ t('subscribe.form.whatsappLabel') }}
          </label>
          <input
            type="tel"
            inputmode="tel"
            class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            placeholder="0812…"
            :value="whatsapp"
            @input="emit('update:whatsapp', ($event.target as HTMLInputElement).value)"
          />
        </div>
        <div>
          <label class="block text-[11px] font-semibold uppercase tracking-wider text-slate-500 mb-1">
            {{ t('subscribe.form.emailLabel') }}
          </label>
          <input
            type="email"
            inputmode="email"
            class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
            :placeholder="isAuthenticated ? (auth.user?.email ?? 'admin@sekolah.sch.id') : 'admin@sekolah.sch.id'"
            :disabled="isAuthenticated"
            :value="isAuthenticated ? (auth.user?.email ?? '') : adminEmail"
            @input="emit('update:adminEmail', ($event.target as HTMLInputElement).value)"
          />
        </div>
      </div>
    </div>

    <p v-if="errorMessage" class="mb-3 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-xs text-rose-700">
      {{ errorMessage }}
    </p>

    <Button
      variant="primary"
      size="lg"
      :loading="submitting"
      :disabled="!canSubmit"
      block
      @click="submit"
    >
      {{ t('subscribe.form.submit') }}
    </Button>

    <p class="mt-3 text-[11px] text-slate-400 text-center">
      {{ t('subscribe.form.footNote') }}
    </p>
  </section>
</template>
