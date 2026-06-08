<!--
  RegisterDemoIdentityView.vue — SEPARATE "Data Diri" (requester
  identity) screen, shown AFTER the demo wizard is submitted.

  Why a separate screen (not a wizard step):
    Per founder request, a fresh visitor fills the wizard (school/demo
    data) WITHOUT being asked for personal identity up front. They first
    "submit" the wizard, and only THEN land here to enter their identity
    and do the final send. So this is its own route
    (`/register-demo/identity`), not a step inside RegisterDemoView.

  Flow:
    wizard (school data) → submit → THIS screen (identity form)
      → final send → pending/done state (inline, replaces the form).

  Backend contract is UNCHANGED. The wizard persists its school answers
  in the demo-wizard store (and via the existing wizard-state save). On
  the final send here we patch the requester slice into that same
  payload and call `wizard.provision()`, which POSTs the COMBINED
  payload (school + identity) to the existing `/demo/provision`
  endpoint exactly as before. No new backend endpoint is introduced.

  Direct-nav / refresh guard:
    A user who lands here without wizard data (e.g. hard refresh that
    cleared the store, or typing the URL directly) has no school to
    submit. After hydrating we check `wizard.hasWizardData`; if empty,
    we redirect back to the wizard start (`/register-demo`) instead of
    rendering an empty form that would submit garbage.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import {
  DEMO_SOCIAL_CHANNELS,
  validateRequester,
  type DemoSocialChannel,
} from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';
import ToastHost from '@/components/ui/ToastHost.vue';
import Modal from '@/components/ui/Modal.vue';
import PublicLanguageSwitcher from '@/components/feature/PublicLanguageSwitcher.vue';

const { t, locale } = useI18n();
const wizard = useDemoWizardStore();
const router = useRouter();

// True while we resolve whether the user is allowed on this screen.
// Avoids a flash of the form before the redirect-guard runs.
const checking = ref(true);

onMounted(async () => {
  try {
    // Hydrate from server / localStorage so a refresh on this screen
    // recovers the school answers the user already filled in the wizard.
    await wizard.hydrate();
  } catch {
    // hydrate() is already best-effort internally, but guard here too so
    // a thrown rejection can never leave `checking` stuck true (endless
    // spinner) — fall through to the no-data redirect below.
  }
  // Guard: no wizard (school) data means the user never completed the
  // wizard — bounce them back to its start rather than letting them
  // submit an empty request.
  if (!wizard.hasWizardData) {
    router.replace('/register-demo');
    return;
  }
  checking.value = false;
});

/* ─── Identity form (moved from the old Step11Requester step) ─── */

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
  return (
    (touched[key] || wizard.requesterSubmitAttempted) &&
    !!errors.value[key as keyof typeof errors.value]
  );
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

/* ─── Pending/done state (moved from the old Step10Done step) ─── */

const result = computed(() => wizard.result);
const schoolName = computed(() => wizard.payload.school.name);

/** Short, human-readable submitted-at — falls back gracefully. */
const submittedAt = computed(() => {
  const raw = result.value?.submitted_at;
  if (!raw) return '';
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleString(locale.value === 'en' ? 'en-US' : 'id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
});

/* ─── Final submit (same combined-payload contract as before) ─── */

// Pending-request popup — shown after a successful submit. The demo is
// NOT activated here; the KamilEdu team validates + identifies the
// requester first, then notifies via WhatsApp/email.
const showPendingDialog = ref(false);

async function handleSend() {
  // Client-validate the requester identity first (mirrors the backend
  // rules) so an incomplete form surfaces inline errors instead of a 422.
  wizard.markRequesterSubmitAttempted();
  if (!wizard.requesterValid) {
    wizard.error = t('registerDemo.requesterFormInvalid');
    return;
  }
  // provision() POSTs the COMBINED payload (school answers collected in
  // the wizard + the requester identity just filled here) to the
  // existing /demo/provision endpoint — backend contract unchanged.
  const ok = await wizard.provision();
  if (ok) {
    showPendingDialog.value = true;
  }
}

function dismissPendingDialog() {
  showPendingDialog.value = false;
}

function handleBack() {
  // Return to the wizard so the user can review/adjust school answers.
  router.push('/register-demo');
}

function handleFinish() {
  // Terminal — the demo isn't live yet (pending review). Clear local
  // progress and return to login; activation arrives later via WA/email.
  wizard.clearLocalProgress();
  router.replace('/login');
}

const sendLabel = computed(() =>
  wizard.isProvisioning
    ? t('registerDemo.nextButtonSubmitting')
    : t('registerDemo.nextButtonSubmit'),
);
</script>

<template>
  <div class="min-h-screen bg-slate-50 px-4 py-6 md:px-8 md:py-10">
    <div class="mx-auto max-w-3xl">
      <!-- Public language switcher — same chrome as the wizard. -->
      <div class="mb-4 flex justify-end">
        <PublicLanguageSwitcher />
      </div>

      <div
        class="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden"
      >
        <main class="flex flex-col p-6 md:p-8">
          <!-- Resolving the guard — brief spinner before form/redirect. -->
          <div v-if="checking" class="py-16 text-center">
            <Spinner size="lg" />
          </div>

          <!-- DONE / PENDING state — replaces the form after a send. -->
          <div v-else-if="result">
            <div
              class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-emerald-100"
            >
              <NavIcon name="check-circle" :size="32" class="text-emerald-600" />
            </div>
            <h2 class="mb-1 text-center text-[22px] font-black text-slate-900">
              {{ t('registerDemo.pendingTitle') }}
            </h2>
            <p class="mb-5 text-center text-[13px] leading-relaxed text-slate-600">
              {{ t('registerDemo.pendingSubtitle') }}
            </p>

            <!-- Request summary card -->
            <div class="rounded-xl border border-slate-200 bg-slate-50 p-4">
              <p class="mb-3 text-[10.5px] font-bold uppercase tracking-widest text-slate-500">
                {{ t('registerDemo.pendingSummaryLabel') }}
              </p>
              <dl class="space-y-2.5 text-[13px]">
                <div class="flex items-start gap-3">
                  <dt class="w-28 flex-shrink-0 text-slate-500">
                    {{ t('registerDemo.pendingFieldSchool') }}
                  </dt>
                  <dd class="flex-1 font-bold text-slate-900">{{ schoolName || '—' }}</dd>
                </div>
                <div class="flex items-start gap-3">
                  <dt class="w-28 flex-shrink-0 text-slate-500">
                    {{ t('registerDemo.pendingFieldRequester') }}
                  </dt>
                  <dd class="flex-1 font-bold text-slate-900">{{ requester.full_name || '—' }}</dd>
                </div>
                <div class="flex items-start gap-3">
                  <dt class="w-28 flex-shrink-0 text-slate-500">
                    {{ t('registerDemo.pendingFieldWhatsapp') }}
                  </dt>
                  <dd class="flex-1 font-mono text-[12.5px] text-slate-900">
                    {{ requester.whatsapp || '—' }}
                  </dd>
                </div>
                <div v-if="submittedAt" class="flex items-start gap-3">
                  <dt class="w-28 flex-shrink-0 text-slate-500">
                    {{ t('registerDemo.pendingFieldSubmittedAt') }}
                  </dt>
                  <dd class="flex-1 text-slate-900">{{ submittedAt }}</dd>
                </div>
                <div class="flex items-start gap-3">
                  <dt class="w-28 flex-shrink-0 text-slate-500">
                    {{ t('registerDemo.pendingFieldStatus') }}
                  </dt>
                  <dd class="flex-1">
                    <span
                      class="inline-flex items-center gap-1.5 rounded-full bg-amber-100 px-2.5 py-0.5 text-[11.5px] font-bold text-amber-800"
                    >
                      <NavIcon name="clock" :size="12" />
                      {{ t('registerDemo.pendingStatusBadge') }}
                    </span>
                  </dd>
                </div>
              </dl>
            </div>

            <!-- What happens next — no activation internals. -->
            <div
              class="mt-4 flex items-start gap-2.5 rounded-lg border border-emerald-200 bg-emerald-50 px-3.5 py-3"
            >
              <NavIcon name="send" :size="16" class="mt-0.5 flex-shrink-0 text-emerald-600" />
              <p class="text-[12.5px] leading-relaxed text-emerald-900">
                {{ t('registerDemo.pendingNextSteps') }}
              </p>
            </div>

            <p class="mt-4 text-center text-[11.5px] leading-snug text-slate-500">
              {{ t('registerDemo.pendingFinalNote') }}
            </p>

            <!-- Terminal action — back to login (demo not live yet). -->
            <button
              type="button"
              class="mt-6 w-full inline-flex items-center justify-center gap-1.5 px-5 py-2.5 rounded-lg bg-role-admin text-white text-[13px] font-bold hover:bg-role-admin/90"
              @click="handleFinish"
            >
              {{ t('registerDemo.nextButtonFinish') }}
            </button>
          </div>

          <!-- IDENTITY FORM — the separate "Data Diri" screen body. -->
          <div v-else>
            <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
              {{ t('registerDemo.identityScreenLabel') }}
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

            <p
              v-if="wizard.error"
              class="mt-4 text-[12.5px] text-red-700 bg-red-50 border border-red-200 rounded-lg px-3 py-2"
            >
              <NavIcon name="alert-circle" :size="14" class="inline-block mr-1.5 -mt-0.5" />
              {{ wizard.error }}
            </p>

            <!-- Footer nav: back to wizard + final send -->
            <div
              class="flex items-center gap-2 mt-6 pt-4 border-t border-slate-100 lg:justify-end"
            >
              <button
                type="button"
                class="flex-1 lg:flex-initial inline-flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-lg border border-slate-300 text-[13px] font-bold text-slate-700 hover:bg-slate-50 disabled:opacity-50"
                :disabled="wizard.isProvisioning"
                @click="handleBack"
              >
                <NavIcon name="arrow-left" :size="14" />
                {{ t('common.back') }}
              </button>
              <button
                type="button"
                class="flex-1 lg:flex-initial inline-flex items-center justify-center gap-1.5 px-5 py-2.5 rounded-lg bg-role-admin text-white text-[13px] font-bold hover:bg-role-admin/90 disabled:opacity-60 disabled:cursor-not-allowed"
                :disabled="wizard.isProvisioning"
                @click="handleSend"
              >
                <Spinner v-if="wizard.isProvisioning" size="sm" class="!text-white" />
                <span>{{ sendLabel }}</span>
                <NavIcon v-if="!wizard.isProvisioning" name="send" :size="14" />
              </button>
            </div>
          </div>
        </main>
      </div>
    </div>

    <ToastHost />

    <!-- Pending-request confirmation popup. No activation internals. -->
    <Modal v-if="showPendingDialog" size="sm" @close="dismissPendingDialog">
      <div class="text-center">
        <div
          class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-emerald-100"
        >
          <NavIcon name="check-circle" :size="28" class="text-emerald-600" />
        </div>
        <h2 class="text-[18px] font-black text-slate-900">
          {{ t('registerDemo.pendingDialogTitle') }}
        </h2>
        <p class="mt-2 text-[13px] leading-relaxed text-slate-600">
          {{ t('registerDemo.pendingDialogMessage') }}
        </p>
        <div
          class="mt-4 flex items-center justify-center gap-2 rounded-lg bg-slate-50 px-3 py-2 text-[12px] text-slate-600"
        >
          <NavIcon name="send" :size="14" class="text-emerald-500" />
          {{ t('registerDemo.pendingDialogChannels') }}
        </div>
        <button
          type="button"
          class="mt-5 w-full rounded-lg bg-role-admin px-5 py-2.5 text-[13px] font-bold text-white hover:bg-role-admin/90"
          @click="dismissPendingDialog"
        >
          {{ t('registerDemo.pendingDialogButton') }}
        </button>
      </div>
    </Modal>
  </div>
</template>
