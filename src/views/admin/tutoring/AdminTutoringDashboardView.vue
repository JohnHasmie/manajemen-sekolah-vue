<!--
  AdminTutoringDashboardView — admin home for a tutoring-center tenant.

  Adopts the same chrome as the school admin/teacher pages
  (BrandPageHeader + KpiStripCards + PageFilterToolbar) so the
  bimbel surfaces visually match the rest of the app.

  Pulls bimbel-native KPIs from GET /tutoring/admin-stats. The program
  slice filter scopes the four "per-program" counters; bills stay
  tenant-wide.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutoringAdminStats, TutoringProgram } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const stats = ref<TutoringAdminStats | null>(null);
const programs = ref<TutoringProgram[]>([]);
/** '' = aggregate; otherwise a program id. */
const programId = ref<string>('');
const showProgramPicker = ref(false);

const activeProgramLabel = computed(() =>
  programId.value === ''
    ? t('tutoring.students.filterAll')
    : programs.value.find((p) => p.id === programId.value)?.name ?? '—',
);

async function load() {
  loading.value = true;
  try {
    stats.value = await TutoringService.getAdminStats(
      programId.value || undefined,
    );
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.dashboard.loadError'),
    );
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await load();
  try {
    programs.value = await TutoringService.getPrograms();
  } catch {/* non-fatal */}
});

watch(programId, load);

function pickProgram(id: string) {
  programId.value = id;
  showProgramPicker.value = false;
}

const kpiCards = computed<KpiCard[]>(() => {
  const s = stats.value;
  if (!s) return [];
  return [
    {
      icon: 'users',
      label: t('tutoring.dashboard.students'),
      value: s.students,
      suffix: s.groups > 0 ? `· ${s.groups} kelompok` : undefined,
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'layers',
      label: t('tutoring.dashboard.programs'),
      value: s.active_programs,
      tone: 'violet',
    },
    {
      icon: 'check-circle',
      label: t('tutoring.dashboard.attendance'),
      value: s.attendance_rate == null ? '–' : `${s.attendance_rate}%`,
      tone: 'green',
    },
    {
      icon: 'wallet',
      label: t('tutoring.dashboard.unpaid'),
      value: s.unpaid_bills,
      suffix: s.unpaid_total > 0 ? formatRupiah(s.unpaid_total) : undefined,
      tone: s.unpaid_bills > 0 ? 'amber' : 'green',
    },
  ];
});

const manageTiles = [
  {
    icon: 'users',
    label: 'Siswa Bimbel',
    sub: 'Daftar siswa terdaftar',
    to: 'admin.tutoring.students',
  },
  {
    icon: 'user-check',
    label: 'Tutor',
    sub: 'Daftar tutor & beban mengajar',
    to: 'admin.tutoring.tutors',
  },
] as const;

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
  <div class="space-y-md pb-12">
    <!-- ── 1. Header ─────────────────────────────────────────── -->
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Dashboard"
      :title="t('tutoring.dashboard.title')"
      :meta="stats
        ? `${stats.students} siswa · ${stats.groups} kelompok · ${stats.active_programs} program aktif`
        : ''"
      live-dot
    />

    <div v-if="loading" class="py-16 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else-if="stats">
      <!-- ── 2. KPI strip ────────────────────────────────────── -->
      <KpiStripCards :cards="kpiCards" />

      <!-- ── 3. Filter toolbar — program slice picker ────────── -->
      <PageFilterToolbar :hide-default-search="true">
        <template #chips>
          <AppFilterChip
            label="Program"
            :value="activeProgramLabel"
            icon-name="layers"
            tone="violet"
            @click="showProgramPicker = true"
          />
        </template>
      </PageFilterToolbar>

      <!-- ── 4. Body ─────────────────────────────────────────── -->
      <TutoringSectionHeader :title="t('tutoring.nav.manajemen')" />
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <TutoringListTile
          v-for="m in manageTiles"
          :key="m.label"
          :icon="m.icon"
          :title="m.label"
          :subtitle="m.sub"
          :to="() => router.push({ name: m.to })"
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

    <!-- Program picker modal -->
    <Modal
      v-if="showProgramPicker"
      title="Pilih Program"
      @close="showProgramPicker = false"
    >
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': programId === '' }"
            @click="pickProgram('')"
          >
            {{ t('tutoring.students.filterAll') }}
          </button>
        </li>
        <li v-for="p in programs" :key="p.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': programId === p.id }"
            @click="pickProgram(p.id)"
          >
            {{ p.name }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
