<!--
  Step 11 — Requester identity (final step before submit).

  Collects the identity of the person asking for a demo so the
  KamilEdu team can validate + identify them before activating:
    - full_name, nip, jabatan  → all required
    - whatsapp                 → required (digits / + / - / space)
    - social_media             → at least ONE channel required
      (Facebook / Threads / Instagram / LinkedIn / other)

  Client validation mirrors the backend SubmitDemoRequestRequest. The
  wizard footer's submit button (in RegisterDemoView) reads the same
  `validateRequester()` helper to gate the call; here we surface the
  per-field errors inline once the user has touched a field or after a
  submit attempt (`wizard` exposes `requesterSubmitAttempted`).

  We do NOT reveal activation internals — the note only tells the user
  to fill data accurately for a smooth request process.
-->
<script setup lang="ts">
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import {
  DEMO_SOCIAL_CHANNELS,
  validateRequester,
  type DemoSocialChannel,
} from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();

const requester = computed(() => wizard.payload.requester);

// Per-field "touched" flags so we only show an error after the user
// has interacted with a field (or after they attempted to submit).
const touched = reactive<Record<string, boolean>>({});
function markTouched(key: string) {
  touched[key] = true;
}

const errors = computed(() => validateRequester(requester.value));

/** Show a field error once it's been touched OR a submit was attempted. */
function showError(key: string): boolean {
  return (touched[key] || wizard.requesterSubmitAttempted) && !!errors.value[key as keyof typeof errors.value];
}
function errorText(key: string): string {
  const k = errors.value[key as keyof typeof errors.value];
  return k ? t(k) : '';
}

function patch(field: 'full_name' | 'nip' | 'jabatan' | 'whatsapp', value: string) {
  wizard.patchPayload('requester', { [field]: value });
}

function patchSocial(channel: DemoSocialChannel, value: string) {
  wizard.patchPayload('requester', {
    social_media: { ...requester.value.social_media, [channel]: value },
  });
}

const SOCIAL_META: Record<
  DemoSocialChannel,
  { labelKey: string; placeholderKey: string }
> = {
  facebook: {
    labelKey: 'registerDemo.requesterSocialFacebook',
    placeholderKey: 'registerDemo.requesterSocialFacebookPlaceholder',
  },
  instagram: {
    labelKey: 'registerDemo.requesterSocialInstagram',
    placeholderKey: 'registerDemo.requesterSocialInstagramPlaceholder',
  },
  threads: {
    labelKey: 'registerDemo.requesterSocialThreads',
    placeholderKey: 'registerDemo.requesterSocialThreadsPlaceholder',
  },
  linkedin: {
    labelKey: 'registerDemo.requesterSocialLinkedin',
    placeholderKey: 'registerDemo.requesterSocialLinkedinPlaceholder',
  },
  other: {
    labelKey: 'registerDemo.requesterSocialOther',
    placeholderKey: 'registerDemo.requesterSocialOtherPlaceholder',
  },
};

const socialChannels = DEMO_SOCIAL_CHANNELS;

// Count of filled social handles — drives the "at least one" hint.
const filledSocialCount = computed(
  () =>
    socialChannels.filter(
      (c) => (requester.value.social_media[c] ?? '').trim() !== '',
    ).length,
);
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.requesterLabel') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.requesterTitle') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">
      {{ t('registerDemo.requesterSubtitle') }}
    </p>

    <!-- Accuracy note — do NOT reveal activation internals. -->
    <div
      class="mb-5 flex items-start gap-2 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2.5"
    >
      <NavIcon name="alert-circle" :size="15" class="mt-0.5 flex-shrink-0 text-amber-600" />
      <p class="text-[12px] leading-snug text-amber-900">
        {{ t('registerDemo.accuracyNote') }}
      </p>
    </div>

    <!-- Identity fields -->
    <div class="space-y-4">
      <!-- Full name -->
      <div>
        <label class="mb-1.5 block text-[10.5px] font-bold uppercase tracking-widest text-slate-500">
          {{ t('registerDemo.requesterFullNameLabel') }}
          <span class="text-red-500">*</span>
        </label>
        <div
          class="flex items-center gap-2 rounded-lg border bg-white px-3 py-2.5"
          :class="showError('full_name') ? 'border-red-400' : 'border-slate-300 focus-within:border-role-admin'"
        >
          <NavIcon name="user" :size="16" class="flex-shrink-0 text-slate-400" />
          <input
            :value="requester.full_name"
            type="text"
            :placeholder="t('registerDemo.requesterFullNamePlaceholder')"
            class="flex-1 bg-transparent text-[14px] text-slate-900 placeholder-slate-400 outline-none"
            autocomplete="name"
            @input="patch('full_name', ($event.target as HTMLInputElement).value)"
            @blur="markTouched('full_name')"
          />
        </div>
        <p v-if="showError('full_name')" class="mt-1 text-[11.5px] text-red-600">
          {{ errorText('full_name') }}
        </p>
      </div>

      <!-- NIP + Jabatan in a 2-col grid on wider panes -->
      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <label class="mb-1.5 block text-[10.5px] font-bold uppercase tracking-widest text-slate-500">
            {{ t('registerDemo.requesterNipLabel') }}
            <span class="text-red-500">*</span>
          </label>
          <div
            class="flex items-center gap-2 rounded-lg border bg-white px-3 py-2.5"
            :class="showError('nip') ? 'border-red-400' : 'border-slate-300 focus-within:border-role-admin'"
          >
            <NavIcon name="clipboard" :size="16" class="flex-shrink-0 text-slate-400" />
            <input
              :value="requester.nip"
              type="text"
              :placeholder="t('registerDemo.requesterNipPlaceholder')"
              class="flex-1 bg-transparent text-[14px] text-slate-900 placeholder-slate-400 outline-none"
              autocomplete="off"
              @input="patch('nip', ($event.target as HTMLInputElement).value)"
              @blur="markTouched('nip')"
            />
          </div>
          <p v-if="showError('nip')" class="mt-1 text-[11.5px] text-red-600">
            {{ errorText('nip') }}
          </p>
        </div>

        <div>
          <label class="mb-1.5 block text-[10.5px] font-bold uppercase tracking-widest text-slate-500">
            {{ t('registerDemo.requesterJabatanLabel') }}
            <span class="text-red-500">*</span>
          </label>
          <div
            class="flex items-center gap-2 rounded-lg border bg-white px-3 py-2.5"
            :class="showError('jabatan') ? 'border-red-400' : 'border-slate-300 focus-within:border-role-admin'"
          >
            <NavIcon name="user-check" :size="16" class="flex-shrink-0 text-slate-400" />
            <input
              :value="requester.jabatan"
              type="text"
              :placeholder="t('registerDemo.requesterJabatanPlaceholder')"
              class="flex-1 bg-transparent text-[14px] text-slate-900 placeholder-slate-400 outline-none"
              autocomplete="organization-title"
              @input="patch('jabatan', ($event.target as HTMLInputElement).value)"
              @blur="markTouched('jabatan')"
            />
          </div>
          <p v-if="showError('jabatan')" class="mt-1 text-[11.5px] text-red-600">
            {{ errorText('jabatan') }}
          </p>
        </div>
      </div>

      <!-- WhatsApp -->
      <div>
        <label class="mb-1.5 block text-[10.5px] font-bold uppercase tracking-widest text-slate-500">
          {{ t('registerDemo.requesterWhatsappLabel') }}
          <span class="text-red-500">*</span>
        </label>
        <div
          class="flex items-center gap-2 rounded-lg border bg-white px-3 py-2.5"
          :class="showError('whatsapp') ? 'border-red-400' : 'border-slate-300 focus-within:border-role-admin'"
        >
          <NavIcon name="send" :size="16" class="flex-shrink-0 text-emerald-500" />
          <input
            :value="requester.whatsapp"
            type="tel"
            inputmode="tel"
            :placeholder="t('registerDemo.requesterWhatsappPlaceholder')"
            class="flex-1 bg-transparent text-[14px] text-slate-900 placeholder-slate-400 outline-none"
            autocomplete="tel"
            @input="patch('whatsapp', ($event.target as HTMLInputElement).value)"
            @blur="markTouched('whatsapp')"
          />
        </div>
        <p v-if="showError('whatsapp')" class="mt-1 text-[11.5px] text-red-600">
          {{ errorText('whatsapp') }}
        </p>
        <p v-else class="mt-1 text-[11px] text-slate-400">
          {{ t('registerDemo.requesterWhatsappHint') }}
        </p>
      </div>
    </div>

    <!-- Social media — at least one required -->
    <div class="mt-6">
      <div class="mb-2 flex items-center justify-between">
        <label class="text-[10.5px] font-bold uppercase tracking-widest text-slate-500">
          {{ t('registerDemo.requesterSocialLabel') }}
          <span class="text-red-500">*</span>
        </label>
        <span
          class="text-[10.5px] font-bold"
          :class="filledSocialCount > 0 ? 'text-emerald-600' : 'text-slate-400'"
        >
          {{ filledSocialCount > 0
            ? t('registerDemo.requesterSocialFilled', { count: filledSocialCount })
            : t('registerDemo.requesterSocialAtLeastOne') }}
        </span>
      </div>

      <div class="grid gap-2.5 sm:grid-cols-2">
        <div v-for="channel in socialChannels" :key="channel">
          <div
            class="flex items-center gap-2 rounded-lg border bg-white px-3 py-2"
            :class="
              showError('social_media') && filledSocialCount === 0
                ? 'border-red-300'
                : 'border-slate-300 focus-within:border-role-admin'
            "
          >
            <NavIcon name="link" :size="14" class="flex-shrink-0 text-slate-400" />
            <span class="w-[78px] flex-shrink-0 text-[11.5px] font-bold text-slate-600">
              {{ t(SOCIAL_META[channel].labelKey) }}
            </span>
            <input
              :value="requester.social_media[channel] ?? ''"
              type="text"
              :placeholder="t(SOCIAL_META[channel].placeholderKey)"
              class="min-w-0 flex-1 bg-transparent text-[13px] text-slate-900 placeholder-slate-400 outline-none"
              autocomplete="off"
              @input="patchSocial(channel, ($event.target as HTMLInputElement).value)"
              @blur="markTouched('social_media')"
            />
          </div>
        </div>
      </div>

      <p v-if="showError('social_media')" class="mt-1.5 text-[11.5px] text-red-600">
        {{ errorText('social_media') }}
      </p>
    </div>

    <p class="mt-5 text-[11.5px] leading-snug text-slate-500">
      {{ t('registerDemo.requesterFinalNote') }}
    </p>
  </div>
</template>
