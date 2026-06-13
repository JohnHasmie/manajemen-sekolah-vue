<!--
  Step 1 — Welcome.
  No form binding; pure intro. Footer's "Mulai" advances to step 2.
  Intentionally does NOT mention the 30-day expiry — that's a
  dashboard surprise.

  Parent / teacher heads-up
  -------------------------
  Admin demo accounts always start clean. But a logged-in parent
  (wali / wali murid) or teacher (guru / wali kelas) can ALSO get
  here — and they often have an existing school/bimbel attached
  to their account from somewhere else. In that case we render a
  small info card listing the tenants + role they're already
  connected to, so they don't think the demo wizard is the only
  way they can use the platform. They CAN still proceed to make
  a fresh demo from this screen — it's purely informational.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useAuthStore } from '@/stores/auth';
import { tenantKindFromRaw } from '@/composables/useTenant';

const { t } = useI18n();
const auth = useAuthStore();

/**
 * Indonesian display name for a role code. The wizard targets a
 * non-English audience by default, and the locale flip can still
 * happen — but the user-facing string here is short enough that a
 * single lookup keyed by role suffices (no need to round-trip to
 * useRoleColor).
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

/**
 * Only show the info card for parent/teacher roles. Admin users
 * landing here are typically brand-new owners (the demo wizard's
 * canonical path), so an "already connected" card would be noise.
 */
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

    <!--
      Existing-tenant heads-up for parent/teacher accounts. Tells
      them which schools / bimbel they're already connected to and
      under what role — so they don't think the demo wizard is the
      only path forward. They can still proceed to spin up a fresh
      demo using the footer's "Mulai" button.
    -->
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
            <!--
              List each existing connection. Bimbel vs school is
              surfaced through the leading word ("Bimbel" / "Sekolah")
              so a parent who taught at two schools sees both rows
              with the right kind label.
            -->
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
  </div>
</template>
