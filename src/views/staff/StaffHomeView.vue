<!--
  StaffHomeView.vue — staff role home (F3).

  The `staff` role finally gets a REAL, honest web self-service surface:
  self-attendance check-in. This is NOT a fabricated dashboard — there are
  no invented KPIs and no admin-management tiles. Staff get exactly the
  capabilities they actually have on the web:

    1. Presensi Saya   → the SAME selfie + GPS check-in flow teachers use.
                          The /teacher-attendance endpoints are staff-aware
                          server-side (Phase C: the backend resolves the
                          caller as teacher OR staff and writes the correct
                          personnel_type row), so this reuses the teacher
                          check-in view verbatim under a staff route.
    2. Riwayat Presensi → the staff member's own check-in log.
    3. Akun            → profile / account (cross-role /profile route).

  GATING: the self check-in tiles are shown only when the user actually
  holds the `attendance.self.view_own` ability (the same key the teacher
  my-attendance route + nav gate on). When it isn't granted — e.g. a staff
  user who has no `staff` roster row at this school, so the backend would
  403 the check-in — we fall back to the HONEST empty state (unchanged from
  the prior RoleHomeStub copy) rather than dangling a tile that 403s.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useMeStore } from '@/stores/me';
import NavIcon from '@/components/feature/NavIcon.vue';
import Card from '@/components/ui/Card.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import type { Role } from '@/types/auth';

const auth = useAuthStore();
const me = useMeStore();
const router = useRouter();
const { t } = useI18n();

const roleLabel = computed(() => {
  const r = auth.activeRole as Role | null;
  return r ? t(`role.${r}`) : '';
});

// Same ability the teacher my-attendance route + nav gate on. Fail-closed
// (me.can returns false pre-hydration) so we never flash a tile the staff
// member can't actually use.
const canSelfCheckIn = computed(() => me.can('attendance.self.view_own'));

interface StaffTile {
  labelKey: string;
  hintKey: string;
  icon: string;
  route: string;
}

// Only routes that ACTUALLY exist. No fabricated management surfaces.
const tiles = computed<StaffTile[]>(() => [
  {
    labelKey: 'staffHome.tileCheckInLabel',
    hintKey: 'staffHome.tileCheckInHint',
    icon: 'camera',
    route: 'staff.my-attendance',
  },
  {
    labelKey: 'staffHome.tileHistoryLabel',
    hintKey: 'staffHome.tileHistoryHint',
    icon: 'clipboard-list',
    route: 'staff.my-attendance.history',
  },
  {
    labelKey: 'staffHome.tileAccountLabel',
    hintKey: 'staffHome.tileAccountHint',
    icon: 'user',
    route: 'profile',
  },
]);

function go(routeName: string) {
  router.push({ name: routeName });
}
</script>

<template>
  <div class="space-y-md">
    <BrandPageHeader
      :kicker="t('staffHome.kicker')"
      :title="t('staffHome.greeting', { name: auth.user?.name ?? '' })"
      :meta="t('staffHome.roleMeta', { role: roleLabel })"
    />

    <!-- Real self-service surface — only when the ability is granted. -->
    <template v-if="canSelfCheckIn">
      <button
        v-for="tile in tiles"
        :key="tile.route"
        type="button"
        class="w-full flex items-center gap-3 bg-white border border-slate-200 rounded-2xl px-4 py-3 hover:bg-slate-50 transition-colors"
        @click="go(tile.route)"
      >
        <div
          class="w-10 h-10 rounded-xl bg-role-staff-soft text-role-staff grid place-items-center flex-shrink-0"
        >
          <NavIcon :name="tile.icon" :size="18" />
        </div>
        <div class="flex-1 text-left min-w-0">
          <p class="text-[13px] font-bold text-slate-900">
            {{ t(tile.labelKey) }}
          </p>
          <p class="text-2xs text-slate-500">{{ t(tile.hintKey) }}</p>
        </div>
        <NavIcon name="arrow-right" :size="16" class="text-slate-300" />
      </button>
    </template>

    <!-- Honest empty state — staff without the self-checkin ability. -->
    <Card v-else :title="t('staffHome.title')">
      <p class="text-sm text-slate-600 leading-relaxed">
        {{ t('staffHome.body') }}
      </p>
    </Card>
  </div>
</template>
