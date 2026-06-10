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
import type {
  TutoringAdminStats,
  TutoringFeedEvent,
  TutoringProgram,
} from '@/types/tutoring';

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
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const stats = ref<TutoringAdminStats | null>(null);
const programs = ref<TutoringProgram[]>([]);
const feed = ref<TutoringFeedEvent[]>([]);
const feedLoading = ref(true);
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

async function loadFeed() {
  feedLoading.value = true;
  try {
    feed.value = await TutoringService.getAdminActivity({
      limit: 8,
      sinceDays: 7,
    });
  } catch {/* non-fatal — empty state covers */} finally {
    feedLoading.value = false;
  }
}

onMounted(async () => {
  await load();
  try {
    programs.value = await TutoringService.getPrograms();
  } catch {/* non-fatal */}
  await loadFeed();
});

watch(programId, load);

function pickProgram(id: string) {
  programId.value = id;
  showProgramPicker.value = false;
}

function shortRupiah(value: number): string {
  if (value >= 1_000_000_000) return `Rp ${(value / 1_000_000_000).toFixed(1)}M`;
  if (value >= 1_000_000) return `Rp ${(value / 1_000_000).toFixed(1)}jt`;
  if (value >= 1_000) return `Rp ${Math.round(value / 1_000)}rb`;
  return formatRupiah(value);
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
      label: 'Pemasukan bulan ini',
      value: s.month_revenue > 0 ? shortRupiah(s.month_revenue) : 'Rp 0',
      suffix: 'Lunas selama 30h',
      tone: 'green',
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
    {
      icon: 'users',
      label: 'Calon siswa (TRIAL)',
      value: s.hot_leads,
      suffix: s.new_enrollments_today > 0
        ? `+${s.new_enrollments_today} daftar hari ini`
        : undefined,
      tone: s.hot_leads > 0 ? 'amber' : 'brand',
    },
  ];
});

/** Today snapshot pills. */
const todayStrip = computed(() => {
  const s = stats.value;
  if (!s) return [];
  return [
    { label: 'Sesi', value: s.sessions_today, warn: false },
    {
      label: 'Tagihan jatuh tempo',
      value: s.bills_due_today,
      warn: s.bills_due_today > 0,
    },
    { label: 'Daftar baru', value: s.new_enrollments_today, warn: false },
  ];
});

/** Relative time formatter for feed rows. */
const dateFmt = new Intl.DateTimeFormat('id-ID', {
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
});
function feedTime(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.valueOf()) ? '—' : dateFmt.format(d);
}

interface FeedStyle { icon: string; tone: string }
function feedStyle(type: string): FeedStyle {
  switch (type) {
    case 'enrollment_new':
      return { icon: 'user-plus', tone: 'text-role-admin bg-role-admin/12' };
    case 'lead_new':
      return { icon: 'fire', tone: 'text-amber-600 bg-amber-50' };
    case 'lead_converted':
      return { icon: 'check-circle', tone: 'text-emerald-600 bg-emerald-50' };
    case 'session_done':
      return { icon: 'check-circle', tone: 'text-role-guru bg-role-guru/12' };
    case 'bill_paid':
      return { icon: 'wallet', tone: 'text-emerald-600 bg-emerald-50' };
    default:
      return { icon: 'circle', tone: 'text-slate-500 bg-slate-100' };
  }
}

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
      <!-- ── 2. Today snapshot ─────────────────────────────────── -->
      <div
        class="flex items-center gap-3 rounded-lg border border-role-admin/25 bg-gradient-to-r from-role-admin/8 to-white px-3 py-2.5"
      >
        <NavIcon name="calendar" :size="16" class="text-role-admin" />
        <div class="flex flex-wrap gap-x-4 gap-y-1">
          <div v-for="p in todayStrip" :key="p.label" class="flex items-center gap-1">
            <span
              class="text-sm font-extrabold tracking-tight"
              :class="p.warn ? 'text-status-danger' : 'text-slate-900'"
            >{{ p.value }}</span>
            <span class="text-[11px] font-semibold text-slate-500">{{ p.label }}</span>
          </div>
        </div>
      </div>

      <!-- ── 3. KPI strip ────────────────────────────────────── -->
      <KpiStripCards :cards="kpiCards" />

      <!-- ── 4. Filter toolbar — program slice picker ────────── -->
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

      <!-- ── 5. Activity feed (last 7d) ───────────────────────── -->
      <TutoringSectionHeader title="Aktivitas Terbaru" />
      <div
        v-if="feedLoading"
        class="py-6 text-center text-xs text-slate-400"
      >
        Memuat…
      </div>
      <TutoringEmpty
        v-else-if="feed.length === 0"
        text="Belum ada aktivitas 7 hari terakhir."
        icon="clock"
      />
      <div v-else class="space-y-1.5">
        <div
          v-for="(ev, i) in feed"
          :key="i"
          class="flex gap-3 rounded-lg border border-slate-200 bg-white p-3"
        >
          <div
            class="flex h-8 w-8 shrink-0 items-center justify-center rounded-md"
            :class="feedStyle(ev.type).tone"
          >
            <NavIcon :name="feedStyle(ev.type).icon" :size="14" />
          </div>
          <div class="flex-1 min-w-0">
            <div class="line-clamp-2 text-[13px] font-bold text-slate-900">
              {{ ev.title }}
            </div>
            <div
              v-if="ev.subtitle"
              class="line-clamp-2 text-[11.5px] text-slate-500"
            >
              {{ ev.subtitle }}
            </div>
          </div>
          <div class="shrink-0 self-start text-[10px] font-semibold text-slate-400">
            {{ feedTime(ev.occurred_at) }}
          </div>
        </div>
      </div>

      <!-- ── 6. Management tiles ─────────────────────────────── -->
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
