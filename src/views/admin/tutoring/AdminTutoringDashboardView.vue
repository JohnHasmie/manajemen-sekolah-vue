<!--
  AdminTutoringDashboardView — admin home for a tutoring-center tenant.
  Pulls bimbel-native KPIs from GET /tutoring/admin-stats and links
  into the management surfaces. Rebuilt on the tutoring shared
  components so the visual exactly matches the Flutter app + the
  approved redesign mockup.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { useAuthStore } from '@/stores/auth';
import { formatRupiah } from '@/lib/format';
import type { TutoringAdminStats } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringHero from '@/components/feature/tutoring/TutoringHero.vue';
import TutoringKpiCard from '@/components/feature/tutoring/TutoringKpiCard.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();
const auth = useAuthStore();

const loading = ref(true);
const stats = ref<TutoringAdminStats | null>(null);

async function load() {
  loading.value = true;
  try {
    stats.value = await TutoringService.getAdminStats();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.dashboard.loadError'),
    );
  } finally {
    loading.value = false;
  }
}

onMounted(load);

const quickActions = [
  {
    key: 'quickPrograms',
    icon: 'layers',
    sub: 'Kelola katalog akademik',
    to: 'admin.tutoring.programs',
  },
  {
    key: 'quickSessions',
    icon: 'calendar',
    sub: 'Semua sesi + absensi',
    to: 'admin.tutoring.sessions',
  },
  {
    key: 'quickBills',
    icon: 'wallet',
    sub: 'Status pembayaran per siswa',
    to: 'admin.tutoring.bills',
  },
  {
    key: 'quickBilling',
    icon: 'settings',
    sub: 'Mode prabayar / bulanan / per sesi',
    to: 'admin.tutoring.billing-settings',
  },
] as const;
</script>

<template>
  <div class="mx-auto max-w-5xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.dashboard.title')"
      crumbs="Bimbel · Dashboard"
    />

    <div v-if="loading" class="py-16 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else-if="stats">
      <TutoringHero
        icon="sparkles"
        greet="SELAMAT DATANG"
        title="Halo, "
        :accent-name="auth.user?.name ?? 'Admin'"
        accent="admin"
      >
        <template #trailing>
          <TutoringStatusPill label="Realtime" tone="ok" dot />
        </template>
      </TutoringHero>

      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4">
        <TutoringKpiCard
          icon="users"
          :value="stats.students"
          :label="t('tutoring.dashboard.students')"
          :hint="stats.groups + ' kelompok'"
        />
        <TutoringKpiCard
          icon="layers"
          :value="stats.active_programs"
          :label="t('tutoring.dashboard.programs')"
        />
        <TutoringKpiCard
          icon="check-circle"
          :value="stats.attendance_rate == null ? '–' : stats.attendance_rate + '%'"
          :label="t('tutoring.dashboard.attendance')"
          tone="ok"
        />
        <TutoringKpiCard
          icon="wallet"
          :value="stats.unpaid_bills"
          :label="t('tutoring.dashboard.unpaid')"
          tone="danger"
          :hint="stats.unpaid_total > 0 ? formatRupiah(stats.unpaid_total) : undefined"
        />
      </div>

      <TutoringSectionHeader :title="t('tutoring.dashboard.manage')" />
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <TutoringListTile
          v-for="a in quickActions"
          :key="a.key"
          :icon="a.icon"
          :title="t('tutoring.dashboard.' + a.key)"
          :subtitle="a.sub"
          :to="() => router.push({ name: a.to })"
        />
      </div>
    </template>

    <TutoringEmpty
      v-else
      :text="t('tutoring.dashboard.loadError')"
      icon="alert-circle"
    />
  </div>
</template>
