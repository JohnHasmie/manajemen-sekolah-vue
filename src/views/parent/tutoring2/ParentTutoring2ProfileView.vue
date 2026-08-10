<!--
  ParentTutoring2ProfileView.vue — settings hub for the wali (parent).
  Mirrors TutorTutoring2ProfileView: 6 clickable setting cards in a
  responsive grid. All actions stubbed to a "not available" toast until
  the wali preference endpoints land — Keluar shows a stub logout toast.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
// Button unused here — setting cards are raw <button> for layout freedom
// (spec allows structural buttons; only real form actions must use the
// Button component).
import { useToast } from '@/composables/useToast';
import { useAuthStore } from '@/stores/auth';

const { t } = useI18n();
const toast = useToast();
const auth = useAuthStore();
const router = useRouter();

interface SettingCard {
  short: string;
  title: string;
  subtitle: string;
  action: () => void;
}

// TODO: swap 'Bpk Anwar' placeholder for the real authenticated wali
// name once the auth store exposes it (BE-8+ profile endpoint).
const placeholderName = 'Bpk Anwar';

/**
 * Actually ends the session.
 *
 * This used to be `toast.info(...)` and nothing else: a wali tapped
 * Keluar, saw a confirmation, and stayed signed in. On a shared device —
 * a family phone, a bimbel front-desk tablet — the next person had their
 * account.
 *
 * `auth.logout()` tears down local state in a `finally`, so a failed or
 * already-expired server call still clears the session; the redirect is
 * unconditional for the same reason.
 */
async function doLogout() {
  try {
    await auth.logout();
  } catch {
    // Swallowed on purpose. The store tears local state down in its own
    // `finally`, so the session is already gone; re-throwing here would
    // only escape as an unhandled rejection — noise in the console and a
    // spurious Sentry event on what is, for the user, a successful
    // logout. The redirect below is what they actually care about.
  } finally {
    router.push({ name: 'login' });
  }
}

const cards = computed<SettingCard[]>(() => [
  {
    short: 'AKN',
    title: t('tutoring2.parent.profile.account'),
    subtitle: t('tutoring2.parent.profile.accountDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'ANK',
    title: t('tutoring2.parent.profile.linkedChildren'),
    subtitle: t('tutoring2.parent.profile.linkedChildrenDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'NTF',
    title: t('tutoring2.parent.profile.notifications'),
    subtitle: t('tutoring2.parent.profile.notificationsDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'BHS',
    title: t('tutoring2.parent.profile.language'),
    subtitle: t('tutoring2.parent.profile.languageDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'HLP',
    title: t('tutoring2.parent.profile.help'),
    subtitle: t('tutoring2.parent.profile.helpDesc'),
    action: () => toast.info(t('tutoring2.common.notAvailable')),
  },
  {
    short: 'KLR',
    title: t('tutoring2.parent.profile.logout'),
    subtitle: t('tutoring2.parent.profile.logoutDesc'),
    action: doLogout,
  },
]);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.profile.title')"
      :meta="t('tutoring2.parent.profile.subtitle', { name: placeholderName })"
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
