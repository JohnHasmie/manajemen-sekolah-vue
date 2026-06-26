<!--
  AdminTutoringChangePasswordView — mirror of TutorChangePasswordView
  but back-link goes to admin.tutoring.profile.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { SettingsService } from '@/services/settings.service';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const current = ref(''); const next = ref(''); const confirm = ref('');
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

const strength = computed(() => {
  const p = next.value;
  if (!p) return 0;
  let s = 0;
  if (p.length >= 8) s++;
  if (/[A-Z]/.test(p) && /[a-z]/.test(p)) s++;
  if (/\d/.test(p)) s++;
  if (/[^\w\s]/.test(p)) s++;
  return s;
});
const strengthColor = computed(() => strength.value <= 1 ? '#e24b4a' : strength.value === 2 ? '#f59e0b' : '#1d9e75');

const canSubmit = computed(() => current.value.length >= 6 && next.value.length >= 8 && next.value === confirm.value && !saving.value);

async function submit() {
  if (!canSubmit.value) return;
  saving.value = true; message.value = null;
  try {
    await SettingsService.updatePassword({ old_password: current.value, new_password: next.value, confirm_password: confirm.value });
    message.value = { kind: 'ok', text: t('admin.bimbel.change_password.success') };
    current.value = ''; next.value = ''; confirm.value = '';
  } catch (e) {
    message.value = { kind: 'err', text: e instanceof Error ? e.message : t('admin.bimbel.change_password.failure') };
  } finally { saving.value = false; }
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <button type="button" class="inline-flex items-center gap-1 text-[14px] text-bimbel-text-mid hover:text-bimbel-text-hi" @click="router.push({ name: 'admin.tutoring.profile' })">
      <NavIcon name="chevron-left" :size="13" /> {{ t('admin.bimbel.change_password.back') }}
    </button>

    <TutorHomeHero :greeting="t('admin.bimbel.change_password.hero_kicker')" :title="t('admin.bimbel.change_password.hero_title')" :subtitle="t('admin.bimbel.change_password.hero_subtitle')" :stats="[]" />

    <div class="grid gap-4 lg:grid-cols-5">
      <form class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-3 space-y-3" @submit.prevent="submit">
        <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('admin.bimbel.change_password.section_title') }}</h4>
        <label class="block"><span class="block text-[13px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('admin.bimbel.change_password.current_label') }}</span>
          <input v-model="current" type="password" required class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <label class="block"><span class="block text-[13px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('admin.bimbel.change_password.new_label') }}</span>
          <input v-model="next" type="password" required minlength="8" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <label class="block"><span class="block text-[13px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('admin.bimbel.change_password.confirm_label') }}</span>
          <input v-model="confirm" type="password" required class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <div class="flex gap-1">
          <div v-for="i in 4" :key="i" class="h-1.5 flex-1 rounded-full" :style="{ background: strength >= i ? strengthColor : 'var(--bimbel-border)' }" />
        </div>
        <div v-if="message" class="rounded-lg px-3 py-2 text-[14px]" :class="message.kind === 'ok' ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-rose-500/10 text-rose-700 dark:text-rose-300'">{{ message.text }}</div>
        <div class="flex gap-2 pt-2">
          <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[14px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="router.push({ name: 'admin.tutoring.profile' })">{{ t('admin.bimbel.change_password.cancel') }}</button>
          <button type="submit" :disabled="!canSubmit" class="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50">{{ saving ? t('admin.bimbel.change_password.saving') : t('admin.bimbel.change_password.save') }}</button>
        </div>
      </form>
      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-2 h-fit">
        <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('admin.bimbel.change_password.tips_title') }}</h4>
        <ul class="space-y-1.5 text-[14px] text-bimbel-text-mid list-disc pl-4">
          <li>{{ t('admin.bimbel.change_password.tips_min') }}</li>
          <li>{{ t('admin.bimbel.change_password.tips_mix') }}</li>
          <li>{{ t('admin.bimbel.change_password.tips_avoid') }}</li>
          <li>{{ t('admin.bimbel.change_password.tips_no_reuse') }}</li>
        </ul>
      </aside>
    </div>
  </div>
</template>
