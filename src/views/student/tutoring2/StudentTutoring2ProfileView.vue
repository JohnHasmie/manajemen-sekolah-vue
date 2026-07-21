<!--
  StudentTutoring2ProfileView.vue — Siswa bimbel settings hub (WEB-5).
  Mirrors TutorTutoring2ProfileView: 5 clickable setting cards in a
  responsive grid, all stubbed until BE-8+ wires the real preference
  endpoints. Every card except "Keluar" flashes a `notAvailable`
  toast so the target IA is visible without shipping half a feature.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const toast = useToast();

interface SettingCard {
  short: string;
  title: string;
  subtitle: string;
  action: () => void;
}

const notAvailable = () => toast.info(t('tutoring2.common.notAvailable'));

const cards = computed<SettingCard[]>(() => [
  {
    short: 'AKN',
    title: t('tutoring2.student.profile.account'),
    subtitle: t('tutoring2.student.profile.accountDesc'),
    action: notAvailable,
  },
  {
    short: 'WLI',
    title: t('tutoring2.student.profile.guardian'),
    subtitle: t('tutoring2.student.profile.guardianDesc'),
    action: notAvailable,
  },
  {
    short: 'NTF',
    title: t('tutoring2.student.profile.notifications'),
    subtitle: t('tutoring2.student.profile.notificationsDesc'),
    action: notAvailable,
  },
  {
    short: 'HLP',
    title: t('tutoring2.student.profile.help'),
    subtitle: t('tutoring2.student.profile.helpDesc'),
    action: notAvailable,
  },
  {
    short: 'KLR',
    title: t('tutoring2.student.profile.logout'),
    subtitle: t('tutoring2.student.profile.logoutDesc'),
    // TODO WEB-5+ wire to auth.logout() once the flow is finalised.
    action: () => toast.info(t('tutoring2.student.profile.logout')),
  },
]);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.profile.title')"
      :meta="t('tutoring2.student.profile.subtitle')"
    />

    <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
      <button
        v-for="c in cards"
        :key="c.title"
        type="button"
        class="flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-4 text-left shadow-sm transition hover:border-brand-azure hover:shadow-md"
        @click="c.action"
      >
        <span
          class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-azure/10 text-brand-azure text-xs font-bold uppercase"
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
