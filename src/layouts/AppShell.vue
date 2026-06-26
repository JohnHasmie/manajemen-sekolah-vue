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
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useTutoringThemeStore } from '@/stores/tutoring-theme';
import { useI18n } from 'vue-i18n';
import { useRoleColor } from '@/composables/useRoleColor';
import { useNavMenu } from '@/composables/useNavMenu';
import { tenantKindFromRaw } from '@/composables/useTenant';
import SchoolPill from '@/components/feature/SchoolPill.vue';
import DemoCountdownBanner from '@/components/feature/DemoCountdownBanner.vue';
import NotificationBell from '@/components/feature/NotificationBell.vue';
import ToastHost from '@/components/ui/ToastHost.vue';
import AiProgressBanner from '@/components/feature/AiProgressBanner.vue';
import ProfileMenu from '@/components/feature/ProfileMenu.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useNotificationsStore } from '@/stores/notifications';
import { init as initRealtime } from '@/lib/echo';

const auth = useAuthStore();
const route = useRoute();
const { t } = useI18n();
const color = useRoleColor(() => auth.activeRole);
const tutoringTheme = useTutoringThemeStore();

// Active tenant is a tutoring center? The tenant_type lives on either
// the User payload directly (post-login normalisation) or on the
// active school in the user's schools list. Either source is fine;
// we just need it cheaply at render time so we can branch the surface.
const isTutoringTenant = computed(() => {
  const raw =
    auth.user?.tenant_type ??
    (auth.user?.schools ?? []).find(
      (s) => (s.id ?? s.school_id) === auth.schoolId,
    )?.tenant_type;
  return tenantKindFromRaw(raw) === 'TUTORING_CENTER';
});

// Bimbel routes render on the bimbel surface (dark by default, light
// when the user picks it in Tutor → Appearance). Three paths into this:
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
//  3. Anything else under a tutoring-center tenant. The sidebar uses
//     `bg-bimbel-panel` regardless of route, and even shared routes
//     like `/admin/announcements` belong to the bimbel UX for these
//     users — without this branch the sidebar stays dark while the
//     page bg is light. School-tenant sessions never hit this branch.
//
// School pages keep the light chrome untouched (no branch matches).
const isTutoringRoute = computed(() => {
  const name = String(route.name ?? '');
  if (name.includes('tutoring')) return true;
  if (name === 'teacher.home' && isTutoringTenant.value) return true;
  if (isTutoringTenant.value) return true;
  return false;
});
const isTutorBimbelRoute = computed(() => {
  const name = String(route.name ?? '');
  if (name.startsWith('teacher.tutoring')) return true;
  // Same reasoning as `isTutoringRoute` — the bimbel tutor home is
  // rendered on `teacher.home` for tutoring-center tenants, and its
  // surface should obey the user's light/dark/auto pick.
  if (name === 'teacher.home' && isTutoringTenant.value) return true;
  return false;
});
const tutoringRoleClass = computed(() =>
  auth.activeRole === 'teacher'
    ? 'bimbel-tutor'
    : auth.activeRole === 'parent'
      ? 'bimbel-wali'
      : 'bimbel-admin',
);
/**
 * Surface class for bimbel pages.
 *
 * Every bimbel surface (admin / tutor / parent) now obeys the user's
 * mode pick (light / dark / auto) via the bimbel theme store. The
 * whole tokenised CSS-var system (`--bimbel-panel`, `--bimbel-text-hi`,
 * etc.) is the SHARED mechanism — each component already reads those
 * vars, so flipping `.tutoring-light` ↔ `.tutoring-dark` on this single
 * `<main>` element re-skins every page underneath at once. No
 * per-page light/dark wiring needed.
 *
 * Previously the admin + parent branches were pinned to `'tutoring-dark'`,
 * which is why "/admin/tutoring" and friends came out fully dark even
 * with the tutor toggle set to light — the toggle simply wasn't
 * consulted for those roles. Removing the branch lets the same store
 * drive all three roles.
 */
const tutoringSurfaceClass = computed(() => tutoringTheme.rootClass);

/**
 * Mirror the surface classes (`.tutoring-light` / `.tutoring-dark`
 * + role tier `.bimbel-tutor` / `.bimbel-admin` / `.bimbel-parent`)
 * onto `<html>` whenever we're rendering a tutoring route.
 *
 * Why this exists: `<main>` already carries those classes for the
 * in-tree cascade, but our `<Modal>` primitive teleports its content
 * to `<body>` — outside the `<main>` cascade. Without this mirror,
 * `bg-bimbel-panel` / `text-bimbel-text-hi` inside a teleported
 * dialog fall through to the `:root` DARK defaults, so an admin
 * with the toggle set to "Selalu terang" still sees a dark
 * `Detail Bill` modal. By writing the classes to
 * `document.documentElement` (i.e. `<html>`), every teleport target
 * inherits the same CSS-var values as the rest of the page.
 *
 * On school routes (and after logout) we strip the classes so we
 * don't leak the tutoring palette onto the standard school chrome.
 *
 * NOTE: only the .tutoring-{light,dark} surface classes were renamed
 * in the 2026-06-26 cutover. The role tier classes (.bimbel-{tutor,
 * admin,parent}) and the underlying `--bimbel-*` CSS variables stay
 * unchanged because they are tightly coupled to the `bimbel:` Tailwind
 * namespace (see tailwind.config.ts), and renaming them would force a
 * sweep across every component that uses `bg-bimbel-panel` /
 * `text-bimbel-text-hi` / etc. — out of scope for this PR.
 */
const TUTORING_HTML_CLASSES = ['tutoring-light', 'tutoring-dark', 'bimbel-tutor', 'bimbel-admin', 'bimbel-wali'];
function syncTutoringHtmlClasses() {
  if (typeof document === 'undefined') return;
  const root = document.documentElement;
  // Clear any previous classes so role/mode swaps don't pile up.
  root.classList.remove(...TUTORING_HTML_CLASSES);
  if (isTutoringRoute.value) {
    root.classList.add(tutoringSurfaceClass.value);
    root.classList.add(tutoringRoleClass.value);
    return;
  }
  // School (non-tutoring) routes still render the sidebar with
  // `bg-bimbel-panel` / `text-bimbel-text-*` utilities. Those tokens
  // default to the DARK palette on `:root` — without a class on <html>
  // the school sidebar comes out fully dark while the page body is
  // light, which is what was reported. School has light-only mode, so
  // force `tutoring-light` here. The role tier class isn't needed
  // because the navy hero gradient isn't used on school pages.
  root.classList.add('tutoring-light');
}
watch(
  [isTutoringRoute, tutoringSurfaceClass, tutoringRoleClass],
  syncTutoringHtmlClasses,
  { immediate: true },
);
onBeforeUnmount(() => {
  // Logout / route to /login destroys AppShell — make sure the
  // login screen doesn't inherit a stale dark palette.
  if (typeof document !== 'undefined') {
    document.documentElement.classList.remove(...TUTORING_HTML_CLASSES);
  }
});

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
  // Exact match always wins.
  if (to === route.path) return true;
  // Role-home roots are exact-match only — otherwise /admin would
  // light up on every /admin/* page.
  if (
    to === '/admin' ||
    to === '/teacher' ||
    to === '/parent' ||
    to === '/staff' ||
    to === '/super-admin'
  ) {
    return false;
  }
  // Bimbel parent's "Home" link is /parent/tutoring/:sid (with no
  // further segments). Without this exception its prefix would match
  // every sibling page like /parent/tutoring/:sid/announcements and
  // both Home + that page would highlight. Same shape applies to
  // any tutoring-home pattern (3 path segments under /parent/tutoring/).
  if (/^\/parent\/tutoring\/[^/]+$/.test(to)) {
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
    <!--
      Sidebar — Option A "Lifted panel".

      Surface:
        bg-bimbel-panel sits one tier above the page bg, so the page
        feels recessed below it. Border-right on bimbel-border-soft
        gives a subtle seam. Tokens flip via .tutoring-light /
        .tutoring-dark so the same markup serves both modes.

      Brand header:
        Compact 60px row with the role-tinted square logo + school
        name + sub label (role tier). The whole row condenses to just
        the logo when collapsed.

      Nav:
        - Section labels (titleKey) render as compact uppercase
          captions in text-bimbel-text-lo.
        - Each item is a rounded pill with the icon + label.
        - Hover: subtle accent-tinted tint + brighter text.
        - Active: accent-tinted bg + accent text + a 3px left rail
          with role-color glow. The rail uses the role hex via
          inline style so it matches admin navy / tutor cyan / parent
          azure precisely.
        - Collapsed: items become 44px squares centered on the icon,
          with the label as a tooltip on hover.
    -->
    <aside
      class="hidden md:flex md:flex-col bg-bimbel-panel border-r border-bimbel-border-soft flex-shrink-0 transition-[width] duration-300 ease-out relative z-40 sticky top-0 h-screen"
      :class="isCollapsed ? 'w-20' : 'w-64'"
    >
      <!-- Brand header -->
      <div class="h-[60px] flex items-center px-4 gap-3 border-b border-bimbel-border-soft flex-shrink-0">
        <template v-if="isSuperAdmin">
          <div
            class="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center text-white"
            :style="{ background: color.hex }"
          >
            <NavIcon name="shield" :size="18" />
          </div>
          <div v-if="!isCollapsed" class="min-w-0">
            <p class="text-[13px] font-extrabold text-bimbel-text-hi leading-tight truncate">{{ t('superAdmin.platformName') }}</p>
            <p class="text-[11px] text-bimbel-text-lo">{{ t('superAdmin.kicker') }}</p>
          </div>
        </template>
        <template v-else>
          <div
            class="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center overflow-hidden"
            :style="!activeSchoolLogo ? { background: color.hex } : undefined"
            :class="activeSchoolLogo ? 'bg-bimbel-bg' : ''"
          >
            <img v-if="activeSchoolLogo" :src="activeSchoolLogo" :alt="activeSchoolName" class="w-full h-full object-cover" />
            <span v-else class="text-white font-extrabold text-[15px]">{{ schoolInitial }}</span>
          </div>
          <div v-if="!isCollapsed" class="min-w-0">
            <p class="text-[13px] font-extrabold text-bimbel-text-hi leading-tight truncate" :title="activeSchoolName">{{ activeSchoolName }}</p>
            <p class="text-[11px] text-bimbel-text-lo capitalize">{{ auth.activeRole || 'role' }}</p>
          </div>
        </template>
      </div>

      <!-- Nav -->
      <nav class="flex-1 overflow-y-auto px-3 py-4 no-scrollbar">
        <div v-for="(section, idx) in menu" :key="idx" class="mb-4 last:mb-0">
          <p
            v-if="section.titleKey && !isCollapsed"
            class="px-3 mb-1.5 text-[11px] font-bold uppercase tracking-[0.14em] text-bimbel-text-lo"
          >
            {{ t(section.titleKey) }}
          </p>
          <ul class="space-y-0.5">
            <li v-for="item in section.items" :key="item.to">
              <RouterLink
                :to="item.to"
                class="group relative flex items-center gap-3 rounded-lg text-[13px] font-semibold transition-colors"
                :class="[
                  isCollapsed ? 'justify-center px-0 py-2.5 h-11' : 'px-3 py-2.5',
                  isActive(item.to)
                    ? 'text-bimbel-text-hi'
                    : 'text-bimbel-text-mid hover:text-bimbel-text-hi hover:bg-bimbel-border-soft/60',
                ]"
                :style="
                  isActive(item.to)
                    ? { background: `color-mix(in srgb, ${color.hex} 14%, transparent)` }
                    : undefined
                "
              >
                <span
                  v-if="isActive(item.to)"
                  class="absolute left-0 top-1.5 bottom-1.5 w-[3px] rounded-r"
                  :style="{ background: color.hex, boxShadow: `0 0 12px ${color.hex}66` }"
                />
                <NavIcon
                  :name="item.icon"
                  :size="18"
                  :style="isActive(item.to) ? { color: color.hex } : undefined"
                  class="flex-shrink-0"
                />
                <span v-if="!isCollapsed" class="flex-1 truncate">{{ t(item.labelKey) }}</span>
                <span
                  v-if="item.badge && !isCollapsed"
                  class="min-w-[18px] h-[18px] px-1 rounded-full text-white text-[10px] font-bold flex items-center justify-center"
                  :style="{ background: color.hex }"
                >{{ item.badge }}</span>
                <span
                  v-if="item.badge && isCollapsed"
                  class="absolute top-1 right-1 w-2 h-2 rounded-full"
                  :style="{ background: color.hex }"
                />
                <span
                  v-if="isCollapsed"
                  class="pointer-events-none absolute left-[calc(100%+12px)] px-2.5 py-1.5 bg-bimbel-panel border border-bimbel-border-soft rounded-md text-[12px] font-semibold text-bimbel-text-hi opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition z-50 whitespace-nowrap shadow-xl"
                >{{ t(item.labelKey) }}</span>
              </RouterLink>
            </li>
          </ul>
        </div>
      </nav>

      <!-- Collapse toggle -->
      <div class="px-3 py-3 border-t border-bimbel-border-soft flex-shrink-0">
        <button
          type="button"
          class="w-full h-9 rounded-lg bg-bimbel-bg/60 border border-bimbel-border-soft text-bimbel-text-mid hover:text-bimbel-text-hi hover:bg-bimbel-border-soft flex items-center justify-center transition"
          @click="toggleSidebar"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"
            stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
            class="transition-transform"
            :class="isCollapsed ? 'rotate-180' : ''"
          >
            <path d="m15 18-6-6 6-6"/>
          </svg>
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
      <!-- Mobile drawer — same Option A treatment as the desktop
           sidebar (panel-lifted surface, role-tinted active pill +
           left rail, bimbel-* tokens so light/dark adapts). -->
      <aside
        v-if="drawerOpen"
        class="fixed inset-y-0 left-0 w-64 bg-bimbel-panel border-r border-bimbel-border-soft z-50 md:hidden flex flex-col"
      >
        <div class="h-[60px] flex items-center justify-between px-4 border-b border-bimbel-border-soft">
          <div class="flex items-center gap-3 min-w-0">
            <template v-if="isSuperAdmin">
              <div class="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center text-white" :style="{ background: color.hex }">
                <NavIcon name="shield" :size="18" />
              </div>
              <span class="text-[13px] font-extrabold text-bimbel-text-hi truncate">{{ t('superAdmin.platformName') }}</span>
            </template>
            <template v-else>
              <div
                class="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center overflow-hidden"
                :style="!activeSchoolLogo ? { background: color.hex } : undefined"
              >
                <img v-if="activeSchoolLogo" :src="activeSchoolLogo" :alt="activeSchoolName" class="w-full h-full object-cover" />
                <span v-else class="text-white font-extrabold text-[15px]">{{ schoolInitial }}</span>
              </div>
              <div class="min-w-0">
                <p class="text-[13px] font-extrabold text-bimbel-text-hi leading-tight truncate" :title="activeSchoolName">{{ activeSchoolName }}</p>
                <p class="text-[11px] text-bimbel-text-lo capitalize">{{ auth.activeRole || 'role' }}</p>
              </div>
            </template>
          </div>
          <button
            type="button"
            class="p-1 rounded-md text-bimbel-text-mid hover:text-bimbel-text-hi hover:bg-bimbel-border-soft"
            aria-label="Tutup menu"
            @click="drawerOpen = false"
          >
            <NavIcon name="x" :size="18" />
          </button>
        </div>
        <nav class="flex-1 overflow-y-auto px-3 py-4">
          <div v-for="(section, idx) in menu" :key="idx" class="mb-4 last:mb-0">
            <p
              v-if="section.titleKey"
              class="px-3 mb-1.5 text-[11px] font-bold uppercase tracking-[0.14em] text-bimbel-text-lo"
            >{{ t(section.titleKey) }}</p>
            <ul class="space-y-0.5">
              <li v-for="item in section.items" :key="item.to">
                <RouterLink
                  :to="item.to"
                  class="relative flex items-center gap-3 px-3 py-2.5 rounded-lg text-[13px] font-semibold transition-colors"
                  :class="isActive(item.to) ? 'text-bimbel-text-hi' : 'text-bimbel-text-mid hover:text-bimbel-text-hi hover:bg-bimbel-border-soft/60'"
                  :style="isActive(item.to) ? { background: `color-mix(in srgb, ${color.hex} 14%, transparent)` } : undefined"
                  @click="drawerOpen = false"
                >
                  <span
                    v-if="isActive(item.to)"
                    class="absolute left-0 top-1.5 bottom-1.5 w-[3px] rounded-r"
                    :style="{ background: color.hex, boxShadow: `0 0 12px ${color.hex}66` }"
                  />
                  <NavIcon
                    :name="item.icon"
                    :size="18"
                    :style="isActive(item.to) ? { color: color.hex } : undefined"
                    class="flex-shrink-0"
                  />
                  <span class="flex-1 truncate">{{ t(item.labelKey) }}</span>
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
        :class="isTutoringRoute ? [tutoringSurfaceClass, tutoringRoleClass] : 'bg-slate-50'"
      >
        <div class="max-w-7xl mx-auto px-4 sm:px-6 py-8">
          <RouterView />
        </div>
      </main>
    </div>

    <AiProgressBanner />
    <ToastHost />
  </div>
</template>
