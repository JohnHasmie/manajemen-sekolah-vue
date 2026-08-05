<!--
  AdminTutoring2InviteTutorModal.vue — standalone dialog wrapping the
  greenfield POST /tutoring-v2/tutors/invite (BE-17). Consumed by
  AdminTutoring2TutorsView.

  Behaviour:
    - Fields: email (required), name (required when the BE would need
      to CREATE a fresh User — enforced client-side; BE also defaults
      from the email local part), phone (optional), initial_rate (opt).
    - Submits via TutoringTutorsService.invite; emits `saved` with the
      returned Tutor on success (parent shows a toast + reloads list).
    - `phone` and `initial_rate` are sent even though BE-17 ignores
      them today — a future BE MR can persist them without a FE change.
    - Ability-gated by the parent (`tutoring.tutor.manage`); we do NOT
      re-check inside the modal because a modal that can be OPENED but
      then refuses to save reads as a bug. Parent hides the trigger.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { Tutor } from '@/types/tutoring2/tutor';

const emit = defineEmits<{
  close: [];
  saved: [tutor: Tutor];
}>();

const { t } = useI18n();

const email = ref('');
const name = ref('');
const phone = ref('');
const initialRate = ref<string>(''); // string-in-input; parsed on submit

const isSaving = ref(false);
const errorMsg = ref<string | null>(null);

// Simple RFC-ish email pattern — matches the BE `email:rfc` validation
// closely enough to catch the common typos before the round-trip.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const isValid = computed(() => {
  if (email.value.trim() === '') return false;
  if (!EMAIL_RE.test(email.value.trim())) return false;
  // `name` stays optional — BE defaults from the email local part when
  // omitted, and re-inviting an existing user doesn't need one either.
  return true;
});

async function submit() {
  if (!isValid.value || isSaving.value) return;
  isSaving.value = true;
  errorMsg.value = null;
  try {
    const rate = initialRate.value.trim() === '' ? null : Number(initialRate.value);
    const tutor = await TutoringTutorsService.invite({
      email: email.value.trim().toLowerCase(),
      name: name.value.trim() || null,
      phone: phone.value.trim() || null,
      initial_rate: rate != null && !Number.isNaN(rate) ? rate : null,
    });
    emit('saved', tutor);
    emit('close');
  } catch (e: unknown) {
    // Prefer the BE `message` when Laravel surfaced one (validation +
    // domain rejections both carry it).
    const anyErr = e as {
      response?: { data?: { message?: string; errors?: Record<string, string[]> } };
      message?: string;
    };
    const beMsg = anyErr?.response?.data?.message;
    const beErrors = anyErr?.response?.data?.errors;
    if (beErrors && Object.keys(beErrors).length > 0) {
      const first = Object.values(beErrors)[0];
      errorMsg.value = Array.isArray(first) ? first[0] : String(first);
    } else {
      errorMsg.value = beMsg || anyErr?.message || t('tutoring2.admin.tutorInvite.errorGeneric');
    }
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <Modal
    :title="t('tutoring2.admin.tutorInvite.title')"
    :subtitle="t('tutoring2.admin.tutorInvite.subtitle')"
    size="md"
    @close="emit('close')"
  >
    <form class="space-y-md" @submit.prevent="submit">
      <label class="block">
        <span class="text-2xs font-bold text-slate-500 uppercase tracking-wide">
          {{ t('tutoring2.admin.tutorInvite.emailLabel') }} *
        </span>
        <input
          v-model="email"
          type="email"
          required
          autocomplete="email"
          class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          :placeholder="t('tutoring2.admin.tutorInvite.emailPh')"
        />
      </label>

      <label class="block">
        <span class="text-2xs font-bold text-slate-500 uppercase tracking-wide">
          {{ t('tutoring2.admin.tutorInvite.nameLabel') }}
        </span>
        <input
          v-model="name"
          type="text"
          maxlength="160"
          autocomplete="name"
          class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          :placeholder="t('tutoring2.admin.tutorInvite.namePh')"
        />
        <span class="mt-1 block text-3xs text-slate-400">
          {{ t('tutoring2.admin.tutorInvite.nameHint') }}
        </span>
      </label>

      <div class="grid grid-cols-2 gap-md">
        <label class="block">
          <span class="text-2xs font-bold text-slate-500 uppercase tracking-wide">
            {{ t('tutoring2.admin.tutorInvite.phoneLabel') }}
          </span>
          <input
            v-model="phone"
            type="tel"
            autocomplete="tel"
            class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
            :placeholder="t('tutoring2.admin.tutorInvite.phonePh')"
          />
        </label>
        <label class="block">
          <span class="text-2xs font-bold text-slate-500 uppercase tracking-wide">
            {{ t('tutoring2.admin.tutorInvite.rateLabel') }}
          </span>
          <input
            v-model="initialRate"
            type="number"
            min="0"
            step="1000"
            inputmode="numeric"
            class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
            :placeholder="t('tutoring2.admin.tutorInvite.ratePh')"
          />
        </label>
      </div>

      <p v-if="errorMsg" class="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700">
        {{ errorMsg }}
      </p>

      <footer class="flex items-center justify-end gap-sm pt-md border-t border-slate-100">
        <Button variant="ghost" type="button" @click="emit('close')" :disabled="isSaving">
          {{ t('tutoring2.common.cancel') }}
        </Button>
        <Button variant="primary" type="submit" :disabled="!isValid || isSaving">
          {{ isSaving ? t('tutoring2.admin.tutorInvite.saving') : t('tutoring2.admin.tutorInvite.submit') }}
        </Button>
      </footer>
    </form>
  </Modal>
</template>
