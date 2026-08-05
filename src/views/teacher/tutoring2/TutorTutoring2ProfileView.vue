<!--
  TutorTutoring2ProfileView.vue — settings hub for the tutor.
  Hub-style layout mirroring AdminTutoring2SettingsView: 5 clickable
  setting cards in a responsive grid. All actions except "Keluar" are
  stubbed until BE-8+ wires the real preference endpoints.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useToast } from '@/composables/useToast';
import { useAuthStore } from '@/stores/auth';

const { t } = useI18n();
const toast = useToast();
const auth = useAuthStore();

interface SettingCard {
  short: string;
  title: string;
  subtitle: string;
  action: () => void;
}

async function doLogout() {
  try {
    await auth.logout();
  } catch {
    // TODO i18n key: 'logout' toast fallback
    toast.info('logout');
  }
}

const cards = computed<SettingCard[]>(() => [
  {
    short: 'AKN',
    title: t('tutoring2.tutor.profile.account'),
    subtitle: t('tutoring2.tutor.profile.accountDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'NTF',
    title: t('tutoring2.tutor.profile.notifications'),
    subtitle: t('tutoring2.tutor.profile.notificationsDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'BHS',
    title: t('tutoring2.tutor.profile.language'),
    subtitle: t('tutoring2.tutor.profile.languageDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'TEM',
    title: t('tutoring2.tutor.profile.appearance'),
    subtitle: t('tutoring2.tutor.profile.appearanceDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'KLR',
    title: t('tutoring2.tutor.profile.logout'),
    subtitle: t('tutoring2.tutor.profile.logoutDesc'),
    action: doLogout,
  },
]);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.profile.title')"
      :meta="t('tutoring2.tutor.profile.subtitle')"
    />

    <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
      <button
        v-for="c in cards"
        :key="c.title"
        type="button"
        class="flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-4 text-left shadow-sm transition hover:border-brand-cobalt hover:shadow-md"
        @click="c.action"
      >
        <span
          class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-cobalt/10 text-brand-cobalt text-xs font-bold uppercase"
        >
          {{ c.short }}
        </span>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-bold text-slate-900">{{ c.title }}</p>
          <p class="truncate text-2xs text-slate-500">{{ c.subtitle }}</p>
        </div>
        <span class="text-slate-300" aria-hidden="true">›</span>
      </button>
    </div>
  </div>
</template>
