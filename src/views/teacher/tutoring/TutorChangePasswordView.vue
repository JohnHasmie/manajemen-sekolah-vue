<!--
  TutorChangePasswordView — mirrors ParentChangePasswordView but
  cyan-tinted. Mockup tutor_web_pages_profile_rating frame 2.
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
const current = ref('');
const next = ref('');
const confirm = ref('');
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

const strength = computed(() => {
  const p = next.value;
  if (!p) return 0;
  let score = 0;
  if (p.length >= 8) score++;
  if (/[A-Z]/.test(p) && /[a-z]/.test(p)) score++;
  if (/\d/.test(p)) score++;
  if (/[^\w\s]/.test(p)) score++;
  return score;
});
const strengthLabel = computed(() =>
  strength.value === 0 ? t('tutor.bimbel.change_password.strength_empty')
    : strength.value === 1 ? t('tutor.bimbel.change_password.strength_weak')
    : strength.value === 2 ? t('tutor.bimbel.change_password.strength_medium')
    : strength.value === 3 ? t('tutor.bimbel.change_password.strength_strong')
    : t('tutor.bimbel.change_password.strength_very_strong'),
);
const strengthColor = computed(() =>
  strength.value <= 1 ? '#e24b4a' : strength.value === 2 ? '#f59e0b' : '#1d9e75',
);

const canSubmit = computed(
  () => current.value.length >= 6 && next.value.length >= 8 && next.value === confirm.value && !saving.value,
);

async function submit() {
  if (!canSubmit.value) return;
  saving.value = true; message.value = null;
  try {
    await SettingsService.updatePassword({
      old_password: current.value,
      new_password: next.value,
      confirm_password: confirm.value,
    });
    message.value = { kind: 'ok', text: t('tutor.bimbel.change_password.save_ok') };
    current.value = ''; next.value = ''; confirm.value = '';
  } catch (e) {
    message.value = { kind: 'err', text: e instanceof Error ? e.message : t('tutor.bimbel.change_password.save_failed') };
  } finally { saving.value = false; }
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-[13px] text-bimbel-text-mid hover:text-bimbel-text-hi"
      @click="router.push({ name: 'teacher.tutoring.profile' })"
    >
      <NavIcon name="chevron-left" :size="13" /> {{ t('tutor.bimbel.change_password.back') }}
    </button>

    <TutorHomeHero
      :greeting="t('tutor.bimbel.change_password.greeting')"
      :title="t('tutor.bimbel.change_password.title')"
      :subtitle="t('tutor.bimbel.change_password.subtitle')"
      :stats="[]"
    />

    <div class="grid gap-4 lg:grid-cols-5">
      <form class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-3 space-y-3" @submit.prevent="submit">
        <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('tutor.bimbel.change_password.form_heading') }}</h4>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('tutor.bimbel.change_password.current_label') }}</span>
          <input v-model="current" type="password" required class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('tutor.bimbel.change_password.new_label') }}</span>
          <input v-model="next" type="password" required minlength="8" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
          <span class="mt-0.5 block text-[12px] text-bimbel-text-lo">{{ t('tutor.bimbel.change_password.new_hint') }}</span>
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('tutor.bimbel.change_password.confirm_label') }}</span>
          <input v-model="confirm" type="password" required class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <div>
          <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">{{ t('tutor.bimbel.change_password.strength_heading') }}</p>
          <div class="mt-1 flex gap-1">
            <div v-for="i in 4" :key="i" class="h-1.5 flex-1 rounded-full" :style="{ background: strength >= i ? strengthColor : 'var(--bimbel-border)' }" />
          </div>
          <p class="mt-1 text-[13px]" :style="{ color: strengthColor }">{{ strengthLabel }}</p>
        </div>
        <div v-if="message" class="rounded-lg px-3 py-2 text-[13px]" :class="message.kind === 'ok' ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-rose-500/10 text-rose-700 dark:text-rose-300'">{{ message.text }}</div>
        <div class="flex gap-2 pt-2">
          <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[14px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="router.push({ name: 'teacher.tutoring.profile' })">{{ t('tutor.bimbel.change_password.cancel') }}</button>
          <button type="submit" :disabled="!canSubmit" class="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50">{{ saving ? t('tutor.bimbel.change_password.saving') : t('tutor.bimbel.change_password.save_btn') }}</button>
        </div>
      </form>

      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-2 h-fit">
        <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('tutor.bimbel.change_password.tips_heading') }}</h4>
        <ul class="space-y-1.5 text-[13px] text-bimbel-text-mid list-disc pl-4">
          <li>{{ t('tutor.bimbel.change_password.tip_min') }}</li>
          <li>{{ t('tutor.bimbel.change_password.tip_mix') }}</li>
          <li>{{ t('tutor.bimbel.change_password.tip_avoid_birthday') }}</li>
          <li>{{ t('tutor.bimbel.change_password.tip_no_reuse') }}</li>
        </ul>
      </aside>
    </div>
  </div>
</template>
