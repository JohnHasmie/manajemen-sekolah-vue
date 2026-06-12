<!--
  InviteTutorModal — modal form for POST /tutoring/tutors/invite. On
  success shows the result (incl. one-time temp password when a new
  account was created so the admin can hand it to the tutor).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringInviteResult } from '@/types/tutoring';

const { t } = useI18n();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done'): void;
}>();

const email = ref('');
const name = ref('');
const saving = ref(false);
const errMsg = ref<string | null>(null);
const result = ref<TutoringInviteResult | null>(null);

const headline = computed(() => {
  if (!result.value) return '';
  return result.value.status === 'created'
    ? t('tutoring.invite.created')
    : result.value.status === 'attached'
      ? t('tutoring.invite.attached')
      : t('tutoring.invite.alreadyTutor');
});

async function submit() {
  const e = email.value.trim();
  if (!e || !e.includes('@')) {
    errMsg.value = t('tutoring.invite.emailInvalid');
    return;
  }
  saving.value = true;
  errMsg.value = null;
  try {
    result.value = await TutoringService.inviteTutor({
      email: e,
      name: name.value.trim() || null,
    });
  } catch (err) {
    errMsg.value = err instanceof Error ? err.message : String(err);
  } finally {
    saving.value = false;
  }
}

function close() {
  emit('close');
}
function done() {
  emit('done');
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4"
    @click.self="close"
  >
    <div class="w-full max-w-md bg-bimbel-panel rounded-2xl p-5 sm:p-6">
      <h2 class="text-base font-bold text-bimbel-text-hi tracking-tight">
        {{ t('tutoring.invite.title') }}
      </h2>
      <p class="text-xs text-bimbel-text-mid mt-1">
        {{ t('tutoring.invite.subtitle') }}
      </p>

      <template v-if="!result">
        <div class="mt-4 space-y-3">
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              {{ t('tutoring.invite.emailLabel') }}
            </span>
            <input
              v-model="email"
              type="email"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
              :placeholder="t('tutoring.invite.emailHint')"
            />
          </label>
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              {{ t('tutoring.invite.nameLabel') }}
            </span>
            <input
              v-model="name"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
              :placeholder="t('tutoring.invite.nameHint')"
            />
          </label>
          <p v-if="errMsg" class="text-xs text-bimbel-red">{{ errMsg }}</p>
        </div>
        <div class="mt-5 flex items-center gap-2 justify-end">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-bimbel-text-mid hover:bg-bimbel-border-soft"
            @click="close"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-bimbel-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="submit"
          >
            {{ saving ? t('tutoring.common.saving') : t('tutoring.invite.submit') }}
          </button>
        </div>
      </template>

      <template v-else>
        <div class="mt-4">
          <p class="font-bold text-bimbel-green">{{ headline }}</p>
          <div class="mt-3 space-y-1 text-sm">
            <div>
              <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider mr-2">Nama</span>
              <span class="font-semibold text-bimbel-text-hi">{{ result.name }}</span>
            </div>
            <div>
              <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider mr-2">Email</span>
              <span class="font-semibold text-bimbel-text-hi">{{ result.email }}</span>
            </div>
          </div>
          <div
            v-if="result.status === 'created' && result.temp_password"
            class="mt-3 rounded-xl bg-bimbel-amber-soft border border-status-warning/30 p-3"
          >
            <p class="text-[10.5px] font-bold text-bimbel-amber uppercase tracking-wider">
              {{ t('tutoring.invite.tempPwd') }}
            </p>
            <p class="mt-1 font-mono font-bold text-bimbel-text-hi select-all">
              {{ result.temp_password }}
            </p>
          </div>
        </div>
        <div class="mt-5 flex justify-end">
          <button
            type="button"
            class="rounded-lg bg-bimbel-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white"
            @click="done"
          >
            {{ t('tutoring.invite.done') }}
          </button>
        </div>
      </template>
    </div>
  </div>
</template>
