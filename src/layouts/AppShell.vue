<!--
  AppShell.vue — role-aware layout for authenticated routes.

  Layout:
    - Topbar (brand-gradient, role-tinted): logo, SchoolPill,
      NotificationBell, ProfileMenu.
    - Sidebar (desktop ≥md, drawer <md): nav items from `useNavMenu`,
      role-color accent on the active item.
    - Main: <RouterView /> in a max-w container.

  Mirrors Flutter's `Dashboard(role: …)` hub from
  `lib/features/dashboard/presentation/screens/dashboard_screen.dart`.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useBimbelThemeStore } from '@/stores/bimbel-theme';
import { useI18n } from 'vue-i18n';
import { useRoleColor } from '@/composables/useRoleColor';
import { useNavMenu } from '@/composables/useNavMenu';
import { tenantKindFromRaw } from '@/composables/useTenant';
import SchoolPill from '@/components/feature/SchoolPill.vue';
import DemoCountdownBanner from '@/components/feature/DemoCountdownBanner.vue';
import NotificationBell from '@/components/feature/NotificationBell.vue';
import ToastHost from '@/components/ui/ToastHost.vue';
import ProfileMenu from '@/components/feature/ProfileMenu.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useNotificationsStore } from '@/stores/notifications';
import { init as initRealtime } from '@/lib/echo';

const auth = useAuthStore();
const route = useRoute();
const { t } = useI18n();
const color = useRoleColor(() => auth.activeRole);
const bimbelTheme = useBimbelThemeStore();

// Active tenant is a tutoring center? The tenant_type lives on either
// the User payload directly (post-login normalisation) or on the
// active school in the user's schools list. Either source is fine;
// we just need it cheaply at render time so we can branch the surface.
const isBimbelTenant = computed(() => {
  const raw =
    auth.user?.tenant_type ??
    (auth.user?.schools ?? []).find(
      (s) => (s.id ?? s.school_id) === auth.schoolId,
    )?.tenant_type;
  return tenantKindFromRaw(raw) === 'TUTORING_CENTER';
});

// Bimbel routes render on the bimbel surface (dark by default, light
// when the user picks it in Tutor → Tampilan). Two paths into this:
//
//  1. The dedicated tutor routes — their route names start with
//     `teacher.tutoring` / contain `tutoring`, so the substring check
//     catches them regardless of role.
//  2. The role-home route (`teacher.home`) when the active tenant is
//     a tutoring center — `TeacherHomeRouter` swaps the body to
//     `TutorTutoringHomeView` there, and that view uses the
//     `bg-bimbel-panel` / `text-bimbel-text-hi` tokens. Without this
//     branch the wrapper class never lands, so those tokens fall
//     through to their dark `:root` defaults and we get a half-light
//     half-dark dashboard.
//
// School pages keep the light chrome untouched (neither branch matches).
const isBimbelRoute = computed(() => {
  const name = String(route.name ?? '');
  if (name.includes('tutoring')) return true;
  if (name === 'teacher.home' && isBimbelTenant.value) return true;
  return false;
});
const isTutorBimbelRoute = computed(() => {
  const name = String(route.name ?? '');
  if (name.startsWith('teacher.tutoring')) return true;
  // Same reasoning as `isBimbelRoute` — the bimbel tutor home is
  // rendered on `teacher.home` for tutoring-center tenants, and its
  // surface should obey the user's light/dark/auto pick.
  if (name === 'teacher.home' && isBimbelTenant.value) return true;
  return false;
});
const bimbelRoleClass = computed(() =>
  auth.activeRole === 'teacher'
    ? 'bimbel-tutor'
    : auth.activeRole === 'parent'
      ? 'bimbel-wali'
      : 'bimbel-admin',
);
/**
 * Surface class for bimbel pages:
 *   - TUTOR pages obey the user's mode pick (light / dark / auto) via
 *     the bimbel theme store, so the Tutor → Tampilan toggle flips the
 *     whole tutor surface live.
 *   - ADMIN and WALI tutoring pages are still dark-only this pass — the
 *     light palette is scoped to the tutor surface for now.
 */
const bimbelSurfaceClass = computed(() =>
  isTutorBimbelRoute.value ? bimbelTheme.rootClass : 'bimbel-dark',
);
const menu = useNavMenu();
const notifications = useNotificationsStore();

// KamilEdu-team super-admins run in this same shell but on the dedicated
// /super-admin area — they have no active school, so the brand chrome
// (sidebar header + topbar) shows a "Platform" identity instead of a
// school name / SchoolPill.
const isSuperAdmin = computed(() => auth.isSuperAdmin);

// Sidebar state
const isCollapsed = ref(localStorage.getItem('sidebar_collapsed') === 'true');
const drawerOpen = ref(false);

const toggleSidebar = () => {
  isCollapsed.value = !isCollapsed.value;
  localStorage.setItem('sidebar_collapsed', isCollapsed.value.toString());
};

watch(() => route.fullPath, () => {
  drawerOpen.value = false;
});

const isActive = (to: string) => {
  // The role home (e.g. /admin, /super-admin) is active only on exact
  // match; everything else is active on prefix match.
  if (to === route.path) return true;
  if (
    to === '/admin' ||
    to === '/teacher' ||
    to === '/parent' ||
    to === '/staff' ||
    to === '/super-admin'
  ) {
    return false;
  }
  return route.path.startsWith(`${to}/`) || route.path === to;
};

const topbarStyle = computed(() => ({
  backgroundImage: `linear-gradient(120deg, ${color.value.hex} 0%, ${color.value.hex}dd 60%, ${color.value.hex}aa 100%)`,
}));

// Hydrate the unread-count on mount (awaited) so the NotificationBell
// renders the right badge on first paint — previously this fired at
// script-setup time and the bell briefly showed a stale 0 / cached
// count before the response landed.
onMounted(async () => {
  await notifications.refreshUnreadCount();
  // Open the realtime channel so the bell updates live. No-op unless
  // Reverb is configured (VITE_REVERB_APP_KEY set) and the user is
  // logged in — realtime is purely additive over the polling above.
  initRealtime(auth.user?.id);
});

// Hydrate the user's schools/roles lists so the SchoolPill shows the
// actual school name and the ProfileMenu can offer Ganti Sekolah /
// Ganti Peran — the login response only carries these when the user
// has to pick (i.e. >1 of each).
auth.hydrateSchoolsRoles();

// ── Active school branding for sidebar ────────────────────────────
const activeSchoolName = computed<string>(() => {
  const match = (auth.user?.schools ?? []).find(
    (s) => (s.id ?? s.school_id) === auth.schoolId,
  );
  return (
    match?.name ??
    match?.school_name ??
    auth.user?.school_name ??
    'KamilEdu'
  );
});

const activeSchoolLogo = computed<string | null>(() => {
  const schools = auth.user?.schools ?? [];
  const match = schools.find(
    (s) => (s.id ?? s.school_id) === auth.schoolId,
  );
  return match?.logo_url ?? null;
});

const schoolInitial = computed(() => {
  const name = activeSchoolName.value.trim();
  if (!name) return '?';
  return name.charAt(0).toUpperCase();
});
</script>

<template>
  <div class="min-h-screen flex bg-slate-50">
    <!-- Sidebar (desktop) -->
    <aside
      class="hidden md:flex md:flex-col bg-white border-r border-slate-200 flex-shrink-0 transition-all duration-500 ease-in-out relative z-40 sticky top-0 h-screen"
      :class="isCollapsed ? 'w-20' : 'w-72'"
    >
      <!-- School / Brand Logo Section -->
      <div class="h-20 flex items-center px-6 gap-4 border-b border-slate-100 bg-slate-50/50 backdrop-blur-md">
        <!-- Super-admins: platform shield instead of a school logo -->
        <template v-if="isSuperAdmin">
          <div class="flex-shrink-0 w-10 h-10 rounded-xl shadow-md shadow-brand-cobalt/10 flex items-center justify-center bg-gradient-to-br from-brand-cobalt to-brand-azure text-white">
            <NavIcon name="shield" :size="20" />
          </div>
          <div v-if="!isCollapsed" class="min-w-0 animate-in fade-in slide-in-from-left-4 duration-500">
            <p class="font-bold text-slate-900 text-sm leading-tight truncate">
              {{ t('superAdmin.platformName') }}
            </p>
            <p class="text-[10px] font-bold uppercase tracking-widest text-brand-cobalt">
              {{ t('superAdmin.kicker') }}
            </p>
          </div>
        </template>
        <!-- Regular roles: school logo or fallback initial -->
        <template v-else>
          <div class="flex-shrink-0 w-10 h-10 rounded-xl shadow-md shadow-brand-cobalt/10 flex items-center justify-center overflow-hidden"
               :class="activeSchoolLogo ? 'bg-white p-0.5' : 'bg-gradient-to-br from-brand-cobalt to-brand-azure'"
          >
            <img
              v-if="activeSchoolLogo"
              :src="activeSchoolLogo"
              :alt="activeSchoolName"
              class="w-full h-full object-cover rounded-lg"
            />
            <span
              v-else
              class="text-white font-black text-lg leading-none"
            >{{ schoolInitial }}</span>
          </div>
          <span
            v-if="!isCollapsed"
            class="font-bold text-slate-900 text-sm leading-tight truncate animate-in fade-in slide-in-from-left-4 duration-500"
            :title="activeSchoolName"
          >
            {{ activeSchoolName }}
          </span>
        </template>
      </div>

      <!-- Navigation with Brand Styling -->
      <nav class="flex-1 overflow-y-auto px-4 py-8 space-y-10 no-scrollbar">
        <div v-for="(section, idx) in menu" :key="idx">
          <p
            v-if="section.titleKey && !isCollapsed"
            class="px-4 py-1 text-[10px] font-black uppercase tracking-[0.25em] text-slate-400 mb-4"
          >
            {{ t(section.titleKey) }}
          </p>
          <ul class="space-y-2">
            <li v-for="item in section.items" :key="item.to">
              <RouterLink
                :to="item.to"
                class="group flex items-center gap-4 px-4 py-3.5 rounded-2xl text-sm font-bold transition-all relative overflow-hidden"
                :class="
                  isActive(item.to)
                    ? `${color.bgSoft} ${color.text}`
                    : 'text-slate-500 hover:bg-slate-50'
                "
                :style="
                  isActive(item.to)
                    ? {}
                    : { '--hover-color': color.hex }
                "
              >
                <!-- Active accent rail — picks up the role color so admin
                     pages glow navy, parent pages glow azure, etc. -->
                <div
                  v-if="isActive(item.to)"
                  class="absolute left-0 top-3 bottom-3 w-1 rounded-r-full"
                  :style="{
                    backgroundColor: color.hex,
                    boxShadow: `0 0 12px ${color.hex}4D`,
                  }"
                ></div>

                <div class="relative z-10 flex-shrink-0 transition-transform duration-300 group-hover:scale-110">
                  <NavIcon :name="item.icon" :size="20" />
                </div>
                
                <span v-if="!isCollapsed" class="flex-1 truncate tracking-tight relative z-10">{{ t(item.labelKey) }}</span>
                
                <span
                  v-if="item.badge"
                  class="min-w-[20px] h-[20px] px-1.5 rounded-full text-white text-[10px] font-black flex items-center justify-center shadow-lg relative z-10"
                  :class="{ 'absolute top-2 right-2': isCollapsed }"
                  :style="{
                    backgroundColor: color.hex,
                    boxShadow: `0 4px 12px ${color.hex}33`,
                  }"
                >
                  {{ item.badge }}
                </span>

                <!-- Tooltip for collapsed state -->
                <div v-if="isCollapsed" class="absolute left-[calc(100%+12px)] px-3 py-2 bg-slate-900 text-white text-xs font-bold rounded-xl opacity-0 translate-x-4 pointer-events-none group-hover:opacity-100 group-hover:translate-x-0 transition-all z-50 whitespace-nowrap shadow-2xl">
                  {{ t(item.labelKey) }}
                </div>
              </RouterLink>
            </li>
          </ul>
        </div>
      </nav>

      <!-- Sidebar Toggle (Clean Style) -->
      <div class="p-4 border-t border-slate-100 bg-slate-50/50">
        <button 
          type="button" 
          class="w-full h-12 bg-white border border-slate-200 text-slate-400 hover:text-brand-cobalt hover:border-brand-cobalt/30 flex items-center justify-center transition-all group shadow-sm"
          :class="isCollapsed ? 'rounded-full' : 'rounded-2xl'"
          @click="toggleSidebar"
        >
          <div class="transition-transform duration-500 group-hover:scale-125" :class="isCollapsed ? 'rotate-180' : ''">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"
            >
              <path d="m15 18-6-6 6-6"/>
            </svg>
          </div>
        </button>
      </div>
    </aside>

    <!-- Mobile drawer -->
    <Transition
      enter-active-class="transition-opacity"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="drawerOpen"
        class="fixed inset-0 bg-slate-900/40 z-40 md:hidden"
        @click="drawerOpen = false"
      />
    </Transition>
    <Transition
      enter-active-class="transition-transform"
      enter-from-class="-translate-x-full"
      enter-to-class="translate-x-0"
      leave-active-class="transition-transform"
      leave-from-class="translate-x-0"
      leave-to-class="-translate-x-full"
    >
      <aside
        v-if="drawerOpen"
        class="fixed inset-y-0 left-0 w-72 bg-white z-50 md:hidden flex flex-col"
      >
        <div class="h-16 flex items-center justify-between px-lg border-b border-slate-100">
          <div class="flex items-center gap-3 min-w-0">
            <template v-if="isSuperAdmin">
              <div class="flex-shrink-0 w-9 h-9 rounded-xl shadow-md shadow-brand-cobalt/10 flex items-center justify-center bg-gradient-to-br from-brand-cobalt to-brand-azure text-white">
                <NavIcon name="shield" :size="18" />
              </div>
              <span class="font-bold text-slate-900 text-sm leading-tight truncate">{{ t('superAdmin.platformName') }}</span>
            </template>
            <template v-else>
              <div class="flex-shrink-0 w-9 h-9 rounded-xl shadow-md shadow-brand-cobalt/10 flex items-center justify-center overflow-hidden"
                   :class="activeSchoolLogo ? 'bg-white p-0.5' : 'bg-gradient-to-br from-brand-cobalt to-brand-azure'"
              >
                <img
                  v-if="activeSchoolLogo"
                  :src="activeSchoolLogo"
                  :alt="activeSchoolName"
                  class="w-full h-full object-cover rounded-lg"
                />
                <span
                  v-else
                  class="text-white font-black text-base leading-none"
                >{{ schoolInitial }}</span>
              </div>
              <span class="font-bold text-slate-900 text-sm leading-tight truncate" :title="activeSchoolName">{{ activeSchoolName }}</span>
            </template>
          </div>
          <button
            type="button"
            class="p-1 rounded-full hover:bg-slate-100"
            aria-label="Tutup menu"
            @click="drawerOpen = false"
          >
            <NavIcon name="x" :size="20" />
          </button>
        </div>
        <nav class="flex-1 overflow-y-auto px-sm py-md space-y-md">
          <div v-for="(section, idx) in menu" :key="idx">
            <p
              v-if="section.titleKey"
              class="px-md py-1 text-[11px] font-semibold uppercase tracking-wider text-slate-400"
            >
              {{ t(section.titleKey) }}
            </p>
            <ul class="space-y-0.5">
              <li v-for="item in section.items" :key="item.to">
                <RouterLink
                  :to="item.to"
                  class="flex items-center gap-2.5 px-md py-2 rounded-lg text-sm font-medium"
                  :class="
                    isActive(item.to)
                      ? `${color.bgSoft} ${color.text}`
                      : 'text-slate-600 hover:bg-slate-50'
                  "
                >
                  <NavIcon :name="item.icon" />
                  {{ t(item.labelKey) }}
                </RouterLink>
              </li>
            </ul>
          </div>
        </nav>
      </aside>
    </Transition>

    <!-- Main column -->
    <div class="flex-1 min-w-0 flex flex-col relative">
      <header
        class="h-16 px-4 sm:px-8 flex items-center gap-4 text-white shadow-xl shadow-slate-900/5 sticky top-0 z-30 backdrop-blur-md border-b border-white/10"
        :style="topbarStyle"
      >
        <button
          type="button"
          class="md:hidden rounded-full bg-white/10 hover:bg-white/20 w-10 h-10 grid place-items-center transition-colors"
          aria-label="Buka menu"
          @click="drawerOpen = true"
        >
          <NavIcon name="menu" :size="20" />
        </button>

        <!-- Super-admins: a static platform badge (no school context). -->
        <span
          v-if="isSuperAdmin"
          class="inline-flex items-center gap-2 rounded-full bg-white/15 px-3 py-1.5 text-sm font-semibold text-white"
        >
          <NavIcon name="shield" :size="16" />
          {{ t('superAdmin.kicker') }}
        </span>
        <!-- School pill — always visible so the user knows their active
             tenant. On the dashboard route this is the only context cue. -->
        <SchoolPill v-else />

        <div class="flex-1" />

        <div class="flex items-center gap-2 sm:gap-4">
          <!-- Demo countdown pill — only visible on demo tenants;
               internally guards on the /demo/expiry response so
               regular schools see nothing. -->
          <DemoCountdownBanner />
          <!-- NotificationBell reads the notifications store directly, so the
               badge stays reactive (mount hydration + realtime) without a
               prop snapshot. The shell still hydrates the count on mount
               below (refreshUnreadCount) so it shows on first paint. -->
          <NotificationBell />
          <div class="w-px h-6 bg-white/10 mx-1"></div>
          <ProfileMenu />
        </div>
      </header>

      <main
        class="flex-1 overflow-y-auto no-scrollbar"
        :class="isBimbelRoute ? [bimbelSurfaceClass, bimbelRoleClass] : 'bg-slate-50'"
      >
        <div class="max-w-7xl mx-auto px-4 sm:px-6 py-8">
          <RouterView />
        </div>
      </main>
    </div>

    <ToastHost />
  </div>
</template>
