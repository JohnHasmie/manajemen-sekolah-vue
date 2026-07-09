<!--
  ProfileMenu.vue — topbar profile dropdown.
  Shows avatar/initial, role, plus Ganti Sekolah / Ganti Peran / Profile /
  Bahasa / Keluar actions. Switch flows reuse the auth store's
  selectSchool / selectRole pipeline (same as the login wizard).
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import {
  canonicalRole,
  ROLE_ADMIN,
  ROLE_PARENT,
  ROLE_STAFF,
  ROLE_TEACHER,
} from '@/utils/role';
import { useI18n } from 'vue-i18n';
import { usePreferencesStore } from '@/stores/preferences';
import {
  useTutoringThemeStore,
  type TutoringThemeMode,
} from '@/stores/tutoring-theme';
import { tenantKindFromRaw } from '@/composables/useTenant';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import Spinner from '@/components/ui/Spinner.vue';
import type { Role, School } from '@/types/auth';

const auth = useAuthStore();
const prefs = usePreferencesStore();
const tutoringTheme = useTutoringThemeStore();
const router = useRouter();
const { t } = useI18n();

/**
 * Appearance picker is only meaningful on the tutoring surface (the
 * `--tutoring-*` CSS vars are the only thing the light/dark toggle
 * controls). For school tenants the rest of the app is locked to
 * the light chrome anyway, so we hide the menu item to avoid an
 * inert affordance.
 */
const isTutoringTenant = computed(() => {
  const raw =
    auth.user?.tenant_type ??
    (auth.user?.schools ?? []).find(
      (s) => (s.id ?? s.school_id) === auth.schoolId,
    )?.tenant_type;
  return tenantKindFromRaw(raw) === 'TUTORING_CENTER';
});

const showAppearancePicker = ref(false);
const appearanceOptions = computed<
  Array<{
    mode: TutoringThemeMode;
    icon: string;
    titleKey: string;
    subKey: string;
  }>
>(() => [
  {
    mode: 'auto',
    icon: 'smartphone',
    titleKey: 'profileMenu.appearanceAuto',
    subKey: 'profileMenu.appearanceAutoSub',
  },
  {
    mode: 'light',
    icon: 'sun',
    titleKey: 'profileMenu.appearanceLight',
    subKey: 'profileMenu.appearanceLightSub',
  },
  {
    mode: 'dark',
    icon: 'moon',
    titleKey: 'profileMenu.appearanceDark',
    subKey: 'profileMenu.appearanceDarkSub',
  },
]);

function pickAppearance(m: TutoringThemeMode) {
  tutoringTheme.setMode(m);
  showAppearancePicker.value = false;
  open.value = false;
}

const open = ref(false);
const showSchoolPicker = ref(false);
const showRolePicker = ref(false);
const switching = ref<'school' | 'role' | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

/**
 * Schools / roles available to the user — derived live from
 * `auth.user` so any hydrate that fires after mount (the AppShell
 * triggers `auth.hydrateSchoolsRoles()` on its own onMounted) flows
 * straight into the menu without needing a manual refresh.
 *
 * The fallback ensures single-school / single-role users still see
 * the Ganti option (with their current school/role highlighted as
 * "Aktif" inside the modal).
 */
const availableSchools = computed<School[]>(() => {
  const fromUser = auth.user?.schools ?? [];
  if (fromUser.length > 0) return fromUser;
  const sid = auth.schoolId ?? auth.user?.school_id;
  if (sid) {
    return [
      {
        id: sid,
        name: auth.user?.school_name ?? t('profileMenu.fallbackSchool'),
      } as School,
    ];
  }
  return [];
});

const availableRoles = computed<Role[]>(() => {
  if (auth.step === 'role' && auth.roles && auth.roles.length > 0) {
    return auth.roles;
  }
  const fromUser = auth.user?.roles ?? [];
  if (fromUser.length > 0) return fromUser;
  return auth.activeRole ? [auth.activeRole] : [];
});

const refsLoaded = ref(false);

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

const activeSchool = computed<School | null>(() => {
  const sid = auth.schoolId;
  if (!sid) return null;
  const fromList =
    availableSchools.value.find((s) => (s.id ?? s.school_id) === sid) ?? null;
  // Prefer the resolved entry from availableSchools so we get any
  // address/city metadata. Fall back to a synthetic record using the
  // user's cached `school_name`.
  if (fromList) return fromList;
  if (auth.user?.school_name) {
    return { id: sid, name: auth.user.school_name } as School;
  }
  return null;
});

const activeSchoolName = computed<string>(
  () =>
    activeSchool.value?.name ??
    activeSchool.value?.school_name ??
    auth.user?.school_name ??
    t('profileMenu.fallbackSchool'),
);

// Hide the "Ganti …" entries if the user only has one option available.
const canSwitchSchool = computed(() => availableSchools.value.length > 1);
const canSwitchRole = computed(() => availableRoles.value.length > 1);

function schoolKey(s: School): string {
  return String(s.id ?? s.school_id ?? '');
}

function schoolDisplayName(s: School): string {
  return s.name ?? s.school_name ?? '—';
}

function roleDisplayLabel(r: Role): string {
  // Map raw backend enums to the keys used in id.json translations
  let key = r as string;
  if (key === 'teacher') key = 'guru';
  if (key === 'parent') key = 'wali';

  try {
    return t(`role.${key}`);
  } catch {
    return r;
  }
}

async function loadRefs() {
  if (refsLoaded.value) return;
  refsLoaded.value = true;
  // Delegate to the auth store. It writes the result into auth.user,
  // which our computed `availableSchools` / `availableRoles` react to.
  await auth.hydrateSchoolsRoles();
}

function close(e: MouseEvent) {
  const target = e.target as HTMLElement;
  if (!target.closest('[data-profile-menu]')) open.value = false;
}

// The `setTimeout(0)` defers the click-outside-to-close listener by
// one tick so THIS toggle-click doesn't count as an "outside" click.
// Round-11 audit: track the timer so a close (or unmount) that fires
// while the timer is still pending can cancel it. Without this, a
// rapid toggle sequence — open → close → open — leaves the first
// listener attached (because removeEventListener ran before the
// setTimeout attached anything) and the second attach stacks another
// listener on top; the menu then dismisses itself on clicks that
// should stay open, or accumulates dangling listeners on unmount if
// the tab closes mid-pending.
let pendingAttach: ReturnType<typeof setTimeout> | null = null;

function toggle() {
  open.value = !open.value;
  if (open.value) {
    loadRefs();
    if (pendingAttach) clearTimeout(pendingAttach);
    pendingAttach = setTimeout(() => {
      pendingAttach = null;
      document.addEventListener('click', close);
    }, 0);
  } else {
    if (pendingAttach) {
      clearTimeout(pendingAttach);
      pendingAttach = null;
    }
    document.removeEventListener('click', close);
  }
}

async function handleLogout() {
  open.value = false;
  // The redirect to /login must happen no matter what: `auth.logout()`
  // already clears the session locally even when the server call fails,
  // so `finally` guarantees the user lands on the login page instead of
  // being stranded on a now-unauthenticated page.
  try {
    await auth.logout();
  } finally {
    router.replace('/login');
  }
}

function goToProfile() {
  open.value = false;
  router.push('/profile');
}

function toggleLocale() {
  prefs.toggleLocale();
}

function openSchoolPicker() {
  open.value = false;
  showSchoolPicker.value = true;
}

function openRolePicker() {
  open.value = false;
  showRolePicker.value = true;
}

function roleHome(role: Role): string {
  switch (role) {
    case 'admin':
      return '/admin';
    case 'guru':
    case 'wali_kelas':
      return '/teacher';
    case 'wali':
      return '/parent';
    case 'staff':
      return '/staff';
    default:
      return '/';
  }
}

async function pickSchool(s: School) {
  const sid = schoolKey(s);
  if (!sid || sid === auth.schoolId) {
    showSchoolPicker.value = false;
    return;
  }
  switching.value = 'school';
  try {
    await auth.selectSchool(sid);
    // The auth store may transition to 'role' if the new school has
    // multiple roles for this user. If so, surface the role picker.
    if (auth.step === 'role') {
      showSchoolPicker.value = false;
      showRolePicker.value = true;
    } else if (auth.step === 'done') {
      showSchoolPicker.value = false;
      toast.value = {
        message: t('profileMenu.toastSchoolSwitched', {
          school: schoolDisplayName(s),
        }),
        tone: 'success',
      };
      const role = auth.activeRole;
      if (role) router.replace(roleHome(role));
    }
  } catch (e) {
    toast.value = {
      message: (e as Error).message ?? t('profileMenu.toastSchoolFailed'),
      tone: 'error',
    };
  } finally {
    switching.value = null;
  }
}

async function pickRole(role: Role) {
  if (!auth.schoolId) {
    toast.value = {
      message: t('profileMenu.toastNoSchoolId'),
      tone: 'error',
    };
    return;
  }
  if (role === auth.activeRole) {
    showRolePicker.value = false;
    return;
  }
  switching.value = 'role';
  try {
    await auth.selectRole(role);
    if (auth.step === 'done') {
      showRolePicker.value = false;
      toast.value = {
        message: t('profileMenu.toastRoleSwitched', {
          role: roleDisplayLabel(role),
        }),
        tone: 'success',
      };
      router.replace(roleHome(role));
    }
  } catch (e) {
    toast.value = {
      message: (e as Error).message ?? t('profileMenu.toastRoleFailed'),
      tone: 'error',
    };
  } finally {
    switching.value = null;
  }
}

onMounted(() => {
  // Pre-warm the school/role list so the chips appear instantly
  // when the user opens the menu.
  loadRefs();
});

onBeforeUnmount(() => {
  if (pendingAttach) clearTimeout(pendingAttach);
  document.removeEventListener('click', close);
});
</script>

<template>
  <div data-profile-menu class="relative">
    <button
      type="button"
      class="inline-flex items-center gap-2 rounded-full bg-white/15 hover:bg-white/25 p-1 sm:py-1 sm:pl-1 sm:pr-3 text-sm font-medium text-white"
      :aria-expanded="open"
      @click="toggle"
    >
      <span
        class="w-7 h-7 rounded-full bg-white/25 grid place-items-center text-xs font-bold"
      >
        {{ initials }}
      </span>
      <span class="hidden sm:inline truncate max-w-[6rem]">{{
        auth.user?.name ?? '—'
      }}</span>
    </button>

    <Transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="opacity-0 scale-95"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition duration-75 ease-in"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-if="open"
        class="absolute right-0 mt-2 w-72 form-card p-1 z-50 origin-top-right"
      >
        <!-- Identity card -->
        <div class="px-md py-sm border-b border-slate-100">
          <p class="text-sm font-semibold text-slate-900 truncate">
            {{ auth.user?.name }}
          </p>
          <p class="text-xs text-slate-500 truncate">{{ auth.user?.email }}</p>
          <div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
            <span
              class="text-3xs font-bold uppercase tracking-wider text-brand-cobalt bg-brand-cobalt/10 px-2 py-0.5 rounded-full"
            >
              {{ roleLabel }}
            </span>
            <span
              v-if="auth.schoolId"
              class="text-3xs font-bold uppercase tracking-wider text-slate-600 bg-slate-100 px-2 py-0.5 rounded-full truncate max-w-[10rem]"
              :title="activeSchoolName"
            >
              {{ activeSchoolName }}
            </span>
          </div>
        </div>

        <!-- Profile -->
        <button
          type="button"
          class="w-full text-left px-md py-sm rounded-lg hover:bg-slate-50 flex items-center gap-2 text-sm text-slate-700"
          @click="goToProfile"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-4 h-4"
          >
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
            <circle cx="12" cy="7" r="4" />
          </svg>
          {{ t('common.profile') }}
        </button>

        <!-- Switch school (only when user has multiple schools) -->
        <button
          v-if="canSwitchSchool"
          type="button"
          class="w-full text-left px-md py-sm rounded-lg hover:bg-slate-50 flex items-center gap-2 text-sm text-slate-700"
          @click="openSchoolPicker"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-4 h-4"
          >
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            <polyline points="9 22 9 12 15 12 15 22" />
          </svg>
          <span class="flex-1">{{ t('profileMenu.switchSchool') }}</span>
          <span class="text-3xs font-bold text-slate-400 tabular-nums">{{
            availableSchools.length
          }}</span>
        </button>

        <!-- Switch role (only when user has multiple roles) -->
        <button
          v-if="canSwitchRole"
          type="button"
          class="w-full text-left px-md py-sm rounded-lg hover:bg-slate-50 flex items-center gap-2 text-sm text-slate-700"
          @click="openRolePicker"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-4 h-4"
          >
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          <span class="flex-1">{{ t('profileMenu.switchRole') }}</span>
          <span class="text-3xs font-bold text-slate-400 tabular-nums">{{
            availableRoles.length
          }}</span>
        </button>

        <!-- Language -->
        <button
          type="button"
          class="w-full text-left px-md py-sm rounded-lg hover:bg-slate-50 flex items-center gap-2 text-sm text-slate-700"
          @click="toggleLocale"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-4 h-4"
          >
            <circle cx="12" cy="12" r="10" />
            <line x1="2" y1="12" x2="22" y2="12" />
            <path
              d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"
            />
          </svg>
          <!--
            Label is the language the user would switch TO (so it acts
            as an action). When currently in Indonesian, show "English";
            when in English, show "Bahasa Indonesia".
          -->
          <span class="flex-1">{{
            prefs.locale === 'id'
              ? t('profileMenu.languageEn')
              : t('profileMenu.languageId')
          }}</span>
          <span class="text-xs text-slate-400 uppercase">{{
            prefs.locale
          }}</span>
        </button>

        <!--
          Appearance (Appearance) — only shown on tutoring tenants because
          the light/dark switch is wired to the `--tutoring-*` CSS
          variables; school tenants render on the locked-light school
          chrome where the toggle would be a no-op.
        -->
        <button
          v-if="isTutoringTenant"
          type="button"
          class="w-full text-left px-md py-sm rounded-lg hover:bg-slate-50 flex items-center gap-2 text-sm text-slate-700"
          @click="
            showAppearancePicker = true;
            open = false;
          "
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-4 h-4"
          >
            <circle cx="12" cy="12" r="5" />
            <line x1="12" y1="1" x2="12" y2="3" />
            <line x1="12" y1="21" x2="12" y2="23" />
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
            <line x1="1" y1="12" x2="3" y2="12" />
            <line x1="21" y1="12" x2="23" y2="12" />
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
          </svg>
          <span class="flex-1">{{ t('profileMenu.appearance') }}</span>
          <span class="text-3xs font-bold text-slate-400 uppercase">{{
            t(
              `profileMenu.appearance${tutoringTheme.mode.charAt(0).toUpperCase() + tutoringTheme.mode.slice(1)}`,
            )
          }}</span>
        </button>

        <!-- Logout -->
        <div class="border-t border-slate-100 mt-1 pt-1">
          <button
            type="button"
            class="w-full text-left px-md py-sm rounded-lg hover:bg-status-danger-soft hover:text-status-danger flex items-center gap-2 text-sm text-slate-700"
            @click="handleLogout"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="w-4 h-4"
            >
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
            {{ t('common.logout') }}
          </button>
        </div>
      </div>
    </Transition>

    <!-- ── School picker modal ── -->
    <Modal
      v-if="showSchoolPicker"
      :title="t('profileMenu.schoolPickerTitle')"
      :subtitle="t('profileMenu.schoolPickerSubtitle')"
      @close="switching ? null : (showSchoolPicker = false)"
    >
      <div
        v-if="availableSchools.length === 0"
        class="py-6 text-center text-slate-400 text-sm"
      >
        {{ t('profileMenu.noOtherSchools') }}
      </div>
      <ul v-else class="space-y-1 max-h-[400px] overflow-y-auto -mx-1">
        <li v-for="s in availableSchools" :key="schoolKey(s)">
          <button
            type="button"
            class="w-full text-left px-3 py-3 rounded-xl flex items-start gap-3 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
            :class="
              schoolKey(s) === auth.schoolId
                ? 'bg-brand-cobalt/5 border border-brand-cobalt/20'
                : 'hover:bg-slate-50 border border-transparent'
            "
            :disabled="switching === 'school'"
            @click="pickSchool(s)"
          >
            <span
              class="w-10 h-10 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center font-black text-sm flex-shrink-0"
            >
              {{ schoolDisplayName(s).slice(0, 1).toUpperCase() }}
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">
                {{ schoolDisplayName(s) }}
              </p>
              <p
                v-if="s.city || s.address"
                class="text-2xs text-slate-500 truncate"
              >
                {{ s.city ?? s.address }}
              </p>
              <p
                v-if="s.roles && s.roles.length > 0"
                class="text-3xs text-slate-400 mt-0.5"
              >
                {{ s.roles.map((r) => roleDisplayLabel(r)).join(' · ') }}
              </p>
            </div>
            <span
              v-if="schoolKey(s) === auth.schoolId"
              class="text-3xs font-bold text-brand-cobalt bg-brand-cobalt/10 px-2 py-0.5 rounded-full uppercase tracking-wider"
            >
              {{ t('profileMenu.activeBadge') }}
            </span>
            <Spinner v-else-if="switching === 'school'" size="sm" />
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Role picker modal ── -->
    <Modal
      v-if="showRolePicker"
      :title="t('profileMenu.rolePickerTitle')"
      :subtitle="t('profileMenu.rolePickerSubtitle')"
      @close="switching ? null : (showRolePicker = false)"
    >
      <div
        v-if="availableRoles.length === 0"
        class="py-6 text-center text-slate-400 text-sm"
      >
        {{ t('profileMenu.noOtherRoles') }}
      </div>
      <ul v-else class="space-y-1 max-h-[400px] overflow-y-auto -mx-1">
        <li v-for="role in availableRoles" :key="role">
          <button
            type="button"
            class="w-full text-left px-3 py-3 rounded-xl flex items-center gap-3 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
            :class="
              role === auth.activeRole
                ? 'bg-brand-cobalt/5 border border-brand-cobalt/20'
                : 'hover:bg-slate-50 border border-transparent'
            "
            :disabled="switching === 'role'"
            @click="pickRole(role)"
          >
            <span
              class="w-10 h-10 rounded-xl bg-violet-100 text-violet-700 grid place-items-center flex-shrink-0"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </svg>
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">
                {{ roleDisplayLabel(role) }}
              </p>
              <p class="text-2xs text-slate-500">
                {{
                  canonicalRole(role) === ROLE_ADMIN
                    ? t('profileMenu.roleDescAdmin')
                    : canonicalRole(role) === ROLE_TEACHER
                      ? t('profileMenu.roleDescGuru')
                      : role === 'wali_kelas'
                        ? t('profileMenu.roleDescWaliKelas')
                        : canonicalRole(role) === ROLE_PARENT
                          ? t('profileMenu.roleDescWali')
                          : canonicalRole(role) === ROLE_STAFF
                            ? t('profileMenu.roleDescStaff')
                            : ''
                }}
              </p>
            </div>
            <span
              v-if="role === auth.activeRole"
              class="text-3xs font-bold text-brand-cobalt bg-brand-cobalt/10 px-2 py-0.5 rounded-full uppercase tracking-wider"
            >
              {{ t('profileMenu.activeBadge') }}
            </span>
            <Spinner v-else-if="switching === 'role'" size="sm" />
          </button>
        </li>
      </ul>
    </Modal>

    <!--
      Appearance picker — three radio tiles (Otomatis / Selalu terang /
      Selalu gelap). Picking a mode calls `tutoringTheme.setMode` which
      mutates the store + persists to localStorage; AppShell's
      `tutoringSurfaceClass` is reactive so the surface flips on the
      same frame.

      We don't re-route to TutorAppearanceView because that screen is
      tutor-themed (kicker "Bimbel · Tutor", role 'teacher') and only
      sits in the tutor nav — admins / parent wouldn't have a clean
      back path. A small in-place modal keeps it role-agnostic.
    -->
    <Modal
      v-if="showAppearancePicker"
      :title="t('profileMenu.appearancePickerTitle')"
      :subtitle="t('profileMenu.appearancePickerSubtitle')"
      @close="showAppearancePicker = false"
    >
      <ul class="space-y-2">
        <li v-for="opt in appearanceOptions" :key="opt.mode">
          <button
            type="button"
            class="w-full text-left px-4 py-3 rounded-xl border flex items-start gap-3 transition-colors"
            :class="
              tutoringTheme.mode === opt.mode
                ? 'border-brand-cobalt bg-brand-cobalt/5'
                : 'border-slate-200 hover:bg-slate-50'
            "
            @click="pickAppearance(opt.mode)"
          >
            <span
              class="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center"
              :class="
                tutoringTheme.mode === opt.mode
                  ? 'bg-brand-cobalt text-white'
                  : 'bg-slate-100 text-slate-600'
              "
            >
              <!-- Inline icon shapes — keeps this modal independent of NavIcon registration. -->
              <svg
                v-if="opt.icon === 'smartphone'"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-4 h-4"
              >
                <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
                <line x1="12" y1="18" x2="12.01" y2="18" />
              </svg>
              <svg
                v-else-if="opt.icon === 'sun'"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-4 h-4"
              >
                <circle cx="12" cy="12" r="5" />
                <line x1="12" y1="1" x2="12" y2="3" />
                <line x1="12" y1="21" x2="12" y2="23" />
                <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
                <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
                <line x1="1" y1="12" x2="3" y2="12" />
                <line x1="21" y1="12" x2="23" y2="12" />
                <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
                <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
              </svg>
              <svg
                v-else
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-4 h-4"
              >
                <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
              </svg>
            </span>
            <span class="min-w-0 flex-1">
              <span class="block text-sm font-bold text-slate-900">{{
                t(opt.titleKey)
              }}</span>
              <span class="block text-2xs text-slate-500">{{
                t(opt.subKey)
              }}</span>
            </span>
            <span
              v-if="tutoringTheme.mode === opt.mode"
              class="text-3xs font-bold text-brand-cobalt bg-brand-cobalt/10 px-2 py-0.5 rounded-full uppercase tracking-wider"
            >
              {{ t('profileMenu.activeBadge') }}
            </span>
          </button>
        </li>
      </ul>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
