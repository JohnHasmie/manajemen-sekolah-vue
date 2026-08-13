<!--
  TutorTutoring2ProfileView.vue — tutor bimbel settings hub.

  ── What changed ──

  Every card except Keluar called `notAvailable`. Two of them — Bahasa
  and Tampilan — named settings whose stores have worked the whole time
  (`usePreferencesStore` and `useTutoringThemeStore`); they now open the
  shared bimbel preferences view. Akun opens the shared profile view.

  Notifikasi ("Preferensi push & email") is REMOVED: web has no push
  registration to toggle, so the card was announcing a setting that
  cannot exist here. It is one line to restore if email preferences
  land.

  The header subtitle read "Tutor Bimbel Cendekia" — an invented
  institution shown to every tutor on every tenant. It is the signed-in
  user now.

  The logout toast fallback also lost its `TODO i18n key` placeholder:
  it fired `toast.info('logout')`, printing the literal word "logout" at
  a user.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useAuthStore } from '@/stores/auth';

const { t } = useI18n();
const auth = useAuthStore();
const router = useRouter();

/**
 * The signed-in tutor. Falls back to the role label rather than a
 * person — an account with no name yet should read "Tutor", not a
 * stranger's name and not an invented institution.
 */
const displayName = computed(
  () => auth.user?.name?.trim() || t('tutoring2.common.roleTutor'),
);

interface SettingCard {
  short: string;
  title: string;
  subtitle: string;
  action: () => void;
}

/**
 * Actually ends the session AND leaves the page.
 *
 * This had no redirect: `auth.logout()` tore the session down and the
 * tutor stayed on a bimbel screen until something else happened to
 * trigger a guard. Its `catch` toasted the literal string `'logout'` —
 * a TODO placeholder that reached users.
 *
 * Same shape as the siswa and wali views now: the teardown runs in the
 * store's own `finally`, so a failed or already-expired server call
 * still clears local state, and the redirect is unconditional.
 */
async function doLogout() {
  try {
    await auth.logout();
  } catch {
    // Swallowed on purpose — the store has already cleared local state,
    // and re-throwing would surface as an unhandled rejection on what
    // is, for the user, a successful logout.
  } finally {
    router.push({ name: 'login' });
  }
}

const cards = computed<SettingCard[]>(() => [
  {
    short: 'AKN',
    title: t('tutoring2.tutor.profile.account'),
    subtitle: t('tutoring2.tutor.profile.accountDesc'),
    action: () => router.push({ name: 'profile' }),
  },
  {
    short: 'TEM',
    title: t('tutoring2.preferences.theme'),
    subtitle: t('tutoring2.preferences.themeAuto'),
    action: () => router.push({ name: 'tutoring2.preferences' }),
  },
  {
    short: 'BHS',
    title: t('tutoring2.preferences.language'),
    subtitle: t('tutoring2.preferences.title'),
    action: () => router.push({ name: 'tutoring2.preferences' }),
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
      :meta="displayName"
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
