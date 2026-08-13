<!--
  StudentTutoring2ProfileView.vue — Siswa bimbel settings hub.

  ── What changed ──

  Every card except Keluar called `notAvailable`, "so the target IA is
  visible without shipping half a feature". Four of the five had nothing
  behind them, and the two that did — theme and language — were never
  offered at all, even though both stores have worked the whole time.

  Akun now opens the shared profile view; Tampilan and Bahasa open the
  shared bimbel preferences view.

  Guardian ("Wali tertaut"), Notifikasi and Bantuan are REMOVED rather
  than left as toasts. There is no linked-guardian view, web has no push
  preference to set, and there is no help centre — a card that announces
  a feature nobody can reach is a promise, not an IA sketch. Each is one
  line to restore the day its screen lands.

  The header subtitle read "Siswa Bimbel Cendekia" — an invented
  institution shown to every siswa on every tenant. It is the signed-in
  user now.
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
 * The signed-in siswa.
 *
 * The header used to render `tutoring2.student.profile.subtitle`, which
 * was the literal string "Siswa Bimbel Cendekia" — a tenant nobody is
 * enrolled at. Falls back to the role label rather than a person: an
 * account with no name yet should read "Siswa", not a stranger's name.
 */
const displayName = computed(
  () => auth.user?.name?.trim() || t('tutoring2.common.roleStudent'),
);

/**
 * Actually ends the session — this was a toast and nothing else, so a
 * siswa tapping Keluar stayed signed in. Teardown runs regardless of
 * what the server says, and the redirect is unconditional.
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

interface SettingCard {
  short: string;
  title: string;
  subtitle: string;
  action: () => void;
}

const cards = computed<SettingCard[]>(() => [
  {
    short: 'AKN',
    title: t('tutoring2.student.profile.account'),
    subtitle: t('tutoring2.student.profile.accountDesc'),
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
    title: t('tutoring2.student.profile.logout'),
    subtitle: t('tutoring2.student.profile.logoutDesc'),
    action: doLogout,
  },
]);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.profile.title')"
      :meta="displayName"
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
