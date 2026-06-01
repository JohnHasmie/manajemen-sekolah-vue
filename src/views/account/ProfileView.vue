<!--
  ProfileView.vue — port of `profile_screen.dart`.
  Read-only user info + language toggle + logout. Avatar editing,
  password change, etc. are out of scope for the initial port.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { usePreferencesStore } from '@/stores/preferences';
import { useRoleColor } from '@/composables/useRoleColor';
import Card from '@/components/ui/Card.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import ChangePasswordModal from './ChangePasswordModal.vue';
import type { Role } from '@/types/auth';

const auth = useAuthStore();
const prefs = usePreferencesStore();
const router = useRouter();
const { t } = useI18n();
const color = useRoleColor(() => auth.activeRole);

const initials = computed(() => {
  const name = auth.user?.name?.trim() ?? '';
  if (!name) return '?';
  const parts = name.split(/\s+/);
  return (parts[0][0] + (parts[1]?.[0] ?? '')).toUpperCase();
});

const roleLabel = computed(() => {
  const r = auth.activeRole as Role | null;
  return r ? t(`role.${r}`) : '';
});

const activeSchool = computed(() => {
  if (auth.user?.school_name) return auth.user.school_name;
  const match = auth.user?.schools?.find(
    (s) => (s.id ?? s.school_id) === auth.schoolId,
  );
  return (
    match?.name ??
    match?.school_name ??
    (auth.schoolId ? 'Sekolah Aktif' : '—')
  );
});

async function handleLogout() {
  await auth.logout();
  router.replace('/login');
}

// ── Change password modal state ──
const showChangePw = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

function onPasswordChanged() {
  toast.value = {
    message: 'Password berhasil diubah.',
    tone: 'success',
  };
}
</script>

<template>
  <div class="max-w-2xl mx-auto space-y-md">
    <header>
      <h1 class="text-xl sm:text-2xl font-bold text-slate-900">
        {{ t('profile.title') }}
      </h1>
    </header>

    <Card padded>
      <div class="flex items-center gap-md">
        <div
          v-if="auth.user?.avatar"
          class="w-16 h-16 rounded-full overflow-hidden bg-slate-100"
        >
          <img
            :src="auth.user.avatar"
            :alt="auth.user.name"
            class="w-full h-full object-cover"
          />
        </div>
        <div
          v-else
          class="w-16 h-16 rounded-full grid place-items-center text-white font-bold text-xl"
          :class="[color.bg]"
        >
          {{ initials }}
        </div>
        <div class="min-w-0">
          <p class="text-lg font-semibold text-slate-900 truncate">
            {{ auth.user?.name }}
          </p>
          <p class="text-sm text-slate-500 truncate">{{ auth.user?.email }}</p>
          <span
            class="mt-1 inline-flex items-center text-xs font-medium px-2 py-0.5 rounded-full"
            :class="[color.bgSoft, color.text]"
          >
            {{ roleLabel }}
          </span>
        </div>
      </div>
    </Card>

    <Card padded :title="t('profile.title')">
      <dl class="text-sm grid grid-cols-1 sm:grid-cols-[160px_1fr] gap-y-3 gap-x-md">
        <dt class="text-slate-500">{{ t('common.profile') }}</dt>
        <dd class="font-medium text-slate-900">{{ auth.user?.name }}</dd>

        <dt class="text-slate-500">Email</dt>
        <dd class="font-medium text-slate-900">{{ auth.user?.email }}</dd>

        <dt class="text-slate-500">{{ t('profile.school') }}</dt>
        <dd class="font-medium text-slate-900">{{ activeSchool }}</dd>

        <dt class="text-slate-500">{{ t('profile.role') }}</dt>
        <dd class="font-medium text-slate-900">{{ roleLabel }}</dd>
      </dl>
    </Card>

    <Card padded :title="t('profile.language')">
      <div class="flex items-center gap-2">
        <Button
          :variant="prefs.locale === 'id' ? 'primary' : 'secondary'"
          @click="prefs.setLocale('id')"
        >
          {{ t('profile.languageId') }}
        </Button>
        <Button
          :variant="prefs.locale === 'en' ? 'primary' : 'secondary'"
          @click="prefs.setLocale('en')"
        >
          {{ t('profile.languageEn') }}
        </Button>
      </div>
    </Card>

    <Card padded :title="t('profile.security') || 'Keamanan'">
      <Button
        variant="secondary"
        block
        @click="showChangePw = true"
      >
        <NavIcon name="shield" :size="14" />
        Ubah Kata Sandi
      </Button>
    </Card>

    <Card padded>
      <Button variant="danger" block @click="handleLogout">
        {{ t('common.logout') }}
      </Button>
    </Card>

    <ChangePasswordModal
      v-if="showChangePw"
      @close="showChangePw = false"
      @success="onPasswordChanged"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
