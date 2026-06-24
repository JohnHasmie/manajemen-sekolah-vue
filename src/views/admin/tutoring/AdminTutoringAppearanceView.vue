<!--
  AdminTutoringAppearanceView — mode picker + bahasa + push toggles.
  Mockup admin_web_pages_account frame 2.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useTutoringThemeStore } from '@/stores/tutoring-theme';
import { useI18n } from 'vue-i18n';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';

const theme = useTutoringThemeStore();
const { locale, t } = useI18n();

const modes = computed(() => [
  { id: 'light' as const, label: t('admin.bimbel.appearance.mode_light'), sub: t('admin.bimbel.appearance.mode_light_sub') },
  { id: 'dark' as const, label: t('admin.bimbel.appearance.mode_dark'), sub: t('admin.bimbel.appearance.mode_dark_sub') },
  { id: 'auto' as const, label: t('admin.bimbel.appearance.mode_auto'), sub: t('admin.bimbel.appearance.mode_auto_sub') },
]);

const notif = computed({
  get: () => ({
    leads: localStorage.getItem('admin.notif.leads') !== '0',
    bills: localStorage.getItem('admin.notif.bills') !== '0',
    tutor: localStorage.getItem('admin.notif.tutor') !== '0',
    proof: localStorage.getItem('admin.notif.proof') !== '0',
    daily: localStorage.getItem('admin.notif.daily') === '1',
  }),
  set: () => {},
});
function toggle(key: string) {
  const cur = localStorage.getItem(`admin.notif.${key}`);
  const on = cur === '0' ? '1' : '0';
  localStorage.setItem(`admin.notif.${key}`, on);
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      :greeting="t('admin.bimbel.appearance.hero_kicker')"
      :title="t('admin.bimbel.appearance.hero_title')"
      :subtitle="t('admin.bimbel.appearance.hero_subtitle')"
      :stats="[]"
    />

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 space-y-3">
      <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('admin.bimbel.appearance.mode_section') }}</h4>
      <div class="grid gap-2 sm:grid-cols-3">
        <button
          v-for="m in modes"
          :key="m.id"
          type="button"
          class="flex flex-col items-center gap-2 rounded-xl border p-3 transition"
          :class="theme.mode === m.id ? 'border-bimbel-accent bg-bimbel-accent-dim' : 'border-bimbel-border-soft hover:border-bimbel-border'"
          @click="theme.setMode(m.id)"
        >
          <span
            class="h-9 w-16 rounded-md border"
            :style="m.id === 'light' ? 'background:#f7faff;border-color:#e2e8f0;' : m.id === 'dark' ? 'background:#0a1428;border-color:#2a3147;' : 'background:linear-gradient(90deg,#f7faff 50%,#0a1428 50%);border-color:#94a3b8;'"
          />
          <p class="text-[14px] font-bold text-bimbel-text-hi">{{ m.label }}</p>
          <p class="text-[13px] text-bimbel-text-mid">{{ m.sub }}</p>
        </button>
      </div>
      <p v-if="theme.autoHint" class="text-[14px] text-bimbel-text-mid">{{ theme.autoHint }}</p>
    </section>

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
      <h4 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi mb-3">{{ t('admin.bimbel.appearance.language_section') }}</h4>
      <div class="flex gap-2">
        <button
          type="button"
          class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
          :class="locale === 'id' ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
          @click="locale = 'id'"
        >{{ t('admin.bimbel.appearance.language_id') }}</button>
        <button
          type="button"
          class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
          :class="locale === 'en' ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
          @click="locale = 'en'"
        >{{ t('admin.bimbel.appearance.language_en') }}</button>
      </div>
    </section>

    <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
      <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ t('admin.bimbel.appearance.push_section') }}</h4>
      <div
        v-for="row in [
          { id: 'leads', name: t('admin.bimbel.appearance.push_leads_name'), sub: t('admin.bimbel.appearance.push_leads_sub') },
          { id: 'bills', name: t('admin.bimbel.appearance.push_bills_name'), sub: t('admin.bimbel.appearance.push_bills_sub') },
          { id: 'tutor', name: t('admin.bimbel.appearance.push_tutor_name'), sub: t('admin.bimbel.appearance.push_tutor_sub') },
          { id: 'proof', name: t('admin.bimbel.appearance.push_proof_name'), sub: t('admin.bimbel.appearance.push_proof_sub') },
          { id: 'daily', name: t('admin.bimbel.appearance.push_daily_name'), sub: t('admin.bimbel.appearance.push_daily_sub') },
        ]"
        :key="row.id"
        class="flex items-center justify-between border-t border-bimbel-border-soft py-2.5 first:border-t-0"
      >
        <div>
          <p class="text-[14px] font-bold text-bimbel-text-hi">{{ row.name }}</p>
          <p class="text-[14px] text-bimbel-text-mid">{{ row.sub }}</p>
        </div>
        <button
          type="button"
          class="h-5 w-9 rounded-full transition"
          :class="(notif as any)[row.id] ? 'bg-emerald-500' : 'bg-bimbel-border'"
          @click="toggle(row.id)"
        >
          <span
            class="block h-3.5 w-3.5 rounded-full bg-white transition"
            :class="(notif as any)[row.id] ? 'translate-x-[18px]' : 'translate-x-[2px]'"
          />
        </button>
      </div>
    </section>
  </div>
</template>
