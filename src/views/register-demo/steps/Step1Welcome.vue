<!--
  Step 1 — Welcome + Google auth gate.

  Anonymous visitors must Google-sign-in before the wizard advances.
  Rationale (from product): the demo request ties to a real Google
  identity so the provisioning + activation notifications reach a
  real inbox — a fully-anonymous wizard would leave dangling records
  the team can't follow up on.

  Layout branches on `auth.isAuthenticated`:
    - NOT authed → prominent Google sign-in card; bullet points and
      the parent/teacher heads-up are hidden. RegisterDemoView's
      "Mulai" footer button is gated on the same auth check so the
      user can't skip past this step by pressing Enter.
    - Authed → original welcome content (bullets + "Signed in as X"
      badge + the parent/teacher tenant heads-up).

  Google implementation:
    - Renders the real GIS button via useGoogleSignIn (redirect mode
      lands the user back at /register-demo with a fresh Sanctum PAT).
    - Sets `sessionStorage.demo_intent_v1` on the container's
      pointerdown so the App.vue post-redirect router branch keeps
      the user here instead of routing to the SchoolPicker for their
      existing tenants (my earlier fix on !452 already handles the
      LoginView side; this reuses the same flag for the wizard side).

  Parent / teacher heads-up (authed-only)
  ---------------------------------------
  A logged-in parent or teacher with an existing tenant sees a small
  info card so they know the demo is optional, not the only path.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useAuthStore } from '@/stores/auth';
import { useGoogleSignIn } from '@/composables/useGoogleSignIn';
import { tenantKindFromRaw } from '@/composables/useTenant';

const { t } = useI18n();
const auth = useAuthStore();
const google = useGoogleSignIn();

const googleButtonRef = ref<HTMLDivElement | null>(null);

/**
 * Mount the real GIS button. Wraps the ready check because the
 * container conditionally renders — the ref may be null on the tick
 * we first try. Re-runs when the auth state flips to unauthenticated
 * (rare, but possible during dev with hot reload).
 */
async function mountGoogleButton() {
  if (auth.isAuthenticated) return;
  if (!google.isEnabled.value) return;
  if (!googleButtonRef.value) return;
  const width = googleButtonRef.value.clientWidth || 320;
  await google.mountButton(googleButtonRef.value, {
    theme: 'filled_blue',
    text: 'signin_with',
    width,
  });
}

/**
 * Set the demo-intent flag BEFORE the GIS popup opens so the post-
 * redirect App.vue check keeps the user on /register-demo instead of
 * routing multi-tenant users to the picker at /login.
 */
function flagDemoIntent(): void {
  try {
    sessionStorage.setItem('demo_intent_v1', '1');
  } catch {
    // sessionStorage may throw in private mode — non-fatal.
  }
}

onMounted(() => {
  void mountGoogleButton();
});

// Re-mount if the auth state changes (e.g. session expiry mid-wizard).
watch(() => auth.isAuthenticated, (v) => {
  if (!v) void mountGoogleButton();
});

/**
 * Indonesian display name for a role code.
 */
function roleLabel(code: string | null | undefined): string {
  if (!code) return '';
  switch (code) {
    case 'guru':
    case 'teacher':
      return t('registerDemo.roleLabelTeacher');
    case 'wali_kelas':
      return t('registerDemo.roleLabelHomeroom');
    case 'wali':
    case 'parent':
    case 'wali_murid':
      return t('registerDemo.roleLabelParent');
    case 'admin':
      return t('registerDemo.roleLabelAdmin');
    case 'staff':
      return t('registerDemo.roleLabelStaff');
    default:
      return code;
  }
}

const isParentOrTeacher = computed(() => {
  const r = auth.activeRole;
  return r === 'guru' || r === 'wali_kelas' || r === 'wali';
});

interface ExistingTenant {
  name: string;
  kind: 'SCHOOL' | 'TUTORING_CENTER';
}

const existingTenants = computed<ExistingTenant[]>(() => {
  const schools = auth.user?.schools ?? [];
  if (schools.length === 0) return [];
  return schools.map((s) => ({
    name: String(s.name ?? s.school_name ?? '—'),
    kind: tenantKindFromRaw(s.tenant_type),
  }));
});

const showExistingTenantInfo = computed(
  () => isParentOrTeacher.value && existingTenants.value.length > 0,
);

const activeRoleLabel = computed(() => roleLabel(auth.activeRole));
</script>

<template>
  <div class="text-center max-w-md mx-auto py-4">
    <div class="w-16 h-16 rounded-2xl bg-role-admin/10 mx-auto mb-5 flex items-center justify-center">
      <NavIcon name="school" :size="32" class="text-role-admin" />
    </div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.step1Label') }}
    </p>
    <h2 class="text-[22px] font-black text-slate-900 mb-2 leading-tight">
      {{ t('registerDemo.step1Title') }}
    </h2>
    <p class="text-[13.5px] text-slate-600 leading-relaxed">
      {{ t('registerDemo.step1Subtitle') }}
    </p>

    <!-- Google auth gate — the only path forward for anonymous
         visitors. Everything else (bullets, heads-up) is hidden so
         the ask is unambiguous. -->
    <section
      v-if="!auth.isAuthenticated"
      class="mt-6 max-w-sm mx-auto text-left rounded-xl border border-brand-cobalt/30 bg-white p-4 shadow-sm"
    >
      <p class="text-[11px] font-black uppercase tracking-widest text-brand-cobalt">
        {{ t('registerDemo.googleGateKicker') }}
      </p>
      <h3 class="mt-1 text-[15px] font-bold text-slate-900">
        {{ t('registerDemo.googleGateTitle') }}
      </h3>
      <p class="mt-1 text-[12px] text-slate-600 leading-relaxed">
        {{ t('registerDemo.googleGateSubtitle') }}
      </p>

      <!-- In-app browser (Threads/IG/…) can't run GIS. Point them out. -->
      <div
        v-if="google.isInAppBrowser.value || google.error.value === 'GIS_LOAD_FAILED'"
        class="mt-3 rounded-lg border-2 border-dashed border-amber-300 bg-amber-50 py-2.5 px-3 text-center text-[11px] font-bold text-amber-800 leading-relaxed"
      >
        {{ google.isInAppBrowser.value
            ? t('auth.demo.googleInAppBrowser')
            : t('auth.googleLoadFailed') }}
      </div>
      <div
        v-else-if="google.isEnabled.value"
        class="mt-3 flex justify-center min-h-[44px]"
      >
        <div
          v-show="google.isReady.value"
          ref="googleButtonRef"
          class="w-full flex justify-center"
          data-google-intent="demo"
          @pointerdown="flagDemoIntent"
        />
        <div
          v-if="!google.isReady.value"
          class="w-full rounded-lg border-2 border-brand-dark-blue/30 bg-white/60 py-2.5 flex items-center justify-center gap-3 animate-pulse"
        >
          <div class="w-3.5 h-3.5 rounded-full bg-brand-dark-blue/20"></div>
          <span class="text-[11px] font-extrabold text-brand-dark-blue/50 uppercase tracking-widest">
            {{ t('auth.loadingGoogle') }}
          </span>
        </div>
      </div>
      <div
        v-else
        class="mt-3 rounded-lg border-2 border-dashed border-slate-300 bg-white/60 py-2.5 px-3 text-center text-[11px] font-bold text-slate-500"
      >
        {{ t('auth.demo.googleNotConfigured') }}
      </div>

      <p class="mt-3 text-[11px] text-slate-400 text-center leading-relaxed">
        {{ t('registerDemo.googleGateFootnote') }}
      </p>
    </section>

    <!-- Authenticated path: original welcome content -->
    <template v-else>
      <div
        class="mt-6 max-w-sm mx-auto flex items-center gap-2.5 rounded-lg bg-emerald-50 border border-emerald-200 px-3 py-2.5"
      >
        <div class="w-8 h-8 rounded-full bg-emerald-500 text-white grid place-items-center flex-shrink-0">
          <NavIcon name="check" :size="16" />
        </div>
        <div class="min-w-0 flex-1 text-left">
          <p class="text-[10px] font-black uppercase tracking-widest text-emerald-700">
            {{ t('registerDemo.signedInKicker') }}
          </p>
          <p class="text-[12.5px] font-semibold text-emerald-900 truncate">
            {{ auth.user?.name || auth.user?.email || t('registerDemo.signedInAnon') }}
          </p>
          <p v-if="auth.user?.email && auth.user?.name" class="text-[11px] text-emerald-700 truncate">
            {{ auth.user.email }}
          </p>
        </div>
      </div>

      <ul class="text-left mt-6 space-y-3 max-w-sm mx-auto">
        <li
          v-for="bullet in [
            t('registerDemo.step1Bullet1'),
            t('registerDemo.step1Bullet2'),
            t('registerDemo.step1Bullet3'),
            t('registerDemo.step1Bullet4'),
          ]"
          :key="bullet"
          class="flex items-start gap-2.5 text-[13px] text-slate-700"
        >
          <span class="w-5 h-5 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center flex-shrink-0 mt-0.5">
            <NavIcon name="check" :size="11" />
          </span>
          {{ bullet }}
        </li>
      </ul>

      <div
        v-if="showExistingTenantInfo"
        class="mt-6 max-w-sm mx-auto text-left rounded-xl border border-amber-200 bg-amber-50 p-4"
      >
        <div class="flex items-start gap-2.5">
          <span class="w-5 h-5 rounded-full bg-amber-100 text-amber-700 flex items-center justify-center flex-shrink-0 mt-0.5">
            <NavIcon name="info" :size="11" />
          </span>
          <div class="min-w-0 flex-1">
            <p class="text-[12px] font-bold text-amber-900 leading-snug">
              {{ t('registerDemo.existingTenantTitle') }}
            </p>
            <ul class="mt-1.5 space-y-1">
              <li
                v-for="(tn, idx) in existingTenants"
                :key="`${tn.name}-${idx}`"
                class="text-[12px] text-amber-800 leading-relaxed"
              >
                {{ tn.kind === 'TUTORING_CENTER'
                  ? t('registerDemo.existingTenantLineBimbel', { name: tn.name, role: activeRoleLabel })
                  : t('registerDemo.existingTenantLineSchool', { name: tn.name, role: activeRoleLabel }) }}
              </li>
            </ul>
            <p class="mt-2 text-[11px] text-amber-700 leading-snug">
              {{ t('registerDemo.existingTenantHint') }}
            </p>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
