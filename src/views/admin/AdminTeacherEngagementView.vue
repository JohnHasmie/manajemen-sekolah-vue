<!--
  AdminTeacherEngagementView.vue — /admin/teacher-engagement

  Full kepsek-facing engagement page. Left column: 4 KPI + engagement
  table. Right rail: SleepyTeachersCard (silent filter + send
  reminders batch) + top-3 mini leaderboard for glance.

  Single fetch of /admin/teacher-engagement at mount — the payload
  already bundles kpi + highlight + rows so the page paints once with
  everything it needs. `send-reminders` fires from the sleepy card
  without refetching the table (bell entries are async; the guru's
  next activity moves them out of the 7+d bucket on the next daily
  rollup).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AdminTeacherEngagementTable from '@/components/feature/teacher-engagement/AdminTeacherEngagementTable.vue';
import WeeklyActivityBars from '@/components/feature/teacher-engagement/WeeklyActivityBars.vue';
import SleepyTeachersCard from '@/components/feature/teacher-engagement/SleepyTeachersCard.vue';
import GamificationHighlightCard from '@/components/feature/gamification/GamificationHighlightCard.vue';
import AdminEngagementSkeleton from '@/components/feature/gamification/AdminEngagementSkeleton.vue';
import { TeacherProgressService, type AdminIndexPayload, type TeacherRowStatus } from '@/services/teacher-progress.service';
import { useToast } from '@/composables/useToast';
import { useRouter } from 'vue-router';

const toast = useToast();
const router = useRouter();

const payload = ref<AdminIndexPayload | null>(null);
const loadError = ref<string | null>(null);
const loading = ref(true);
const sending = ref(false);

const search = ref('');
const statusFilter = ref<TeacherRowStatus | ''>('');

const silentTeachers = computed(() =>
  (payload.value?.data ?? [])
    .filter((r) => r.status === 'silent')
    .map((r) => ({
      teacher_id: r.teacher_id,
      name: r.name,
      last_active_at: r.last_active_at,
    })),
);

// 4-up KPI strip — maps the backend `meta.kpi` block onto the shared
// KpiStripCards shape (tinted icon-square + big value). Labels stay
// Indonesian (user-visible copy); tones follow the semantic reading
// (green = good, amber = streak/warmth, red = needs attention).
const kpiCards = computed<KpiCard[]>(() => {
  const k = payload.value?.meta.kpi;
  return [
    { icon: 'users', label: 'Total guru', value: k?.total_teachers ?? 0, tone: 'brand' },
    { icon: 'activity', label: 'Aktif minggu ini', value: k?.active_this_week ?? 0, tone: 'green' },
    { icon: 'flame', label: 'Rata streak', value: k?.average_streak ?? 0, suffix: 'hari', tone: 'amber' },
    { icon: 'alert-circle', label: 'Perlu perhatian', value: k?.needs_attention_count ?? 0, tone: 'red' },
  ];
});

async function load() {
  loading.value = true;
  loadError.value = null;
  try {
    payload.value = await TeacherProgressService.getAdminIndex();
  } catch (e: any) {
    loadError.value = e?.response?.status === 402
      ? 'Modul Prestasi belum aktif untuk sekolah ini.'
      : 'Gagal memuat data engagement guru.';
  } finally {
    loading.value = false;
  }
}

async function onSendReminder(teacherIds: string[]) {
  sending.value = true;
  try {
    const res = await TeacherProgressService.sendReminders(teacherIds);
    toast.success(`Pengingat terkirim ke ${res.sent} guru.`);
  } catch {
    toast.error('Gagal mengirim pengingat. Coba lagi.');
  } finally {
    sending.value = false;
  }
}

onMounted(() => {
  void load();
});
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="teacher"
      kicker="Retensi Guru"
      title="Prestasi Guru"
      meta="Pantau engagement, apresiasi guru rajin, sapa yang tidur."
    />

    <AdminEngagementSkeleton v-if="loading" />

    <div
      v-else-if="loadError"
      class="rounded-2xl p-6 bg-amber-50 border border-amber-200 text-amber-800 flex items-start gap-3"
    >
      <NavIcon name="alert-circle" :size="20" />
      <p class="text-sm font-bold">{{ loadError }}</p>
    </div>

    <template v-else-if="payload">
      <!-- Admin highlight: teacher_of_month always visible, needs_attention optional. -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <GamificationHighlightCard
          :state="payload.meta.highlight.teacher_of_month.state"
          :eyebrow="payload.meta.highlight.teacher_of_month.eyebrow"
          :title="payload.meta.highlight.teacher_of_month.title"
          :sub="payload.meta.highlight.teacher_of_month.sub"
          :cta-label="payload.meta.highlight.teacher_of_month.cta_label"
          :cta-target="payload.meta.highlight.teacher_of_month.cta_target"
          :meta="null"
          @cta="router.push(payload.meta.highlight.teacher_of_month.cta_target)"
        />
        <GamificationHighlightCard
          v-if="payload.meta.highlight.needs_attention.count > 0"
          :state="payload.meta.highlight.needs_attention.state"
          :eyebrow="payload.meta.highlight.needs_attention.eyebrow"
          :title="payload.meta.highlight.needs_attention.title ?? ''"
          :sub="payload.meta.highlight.needs_attention.sub"
          :cta-label="payload.meta.highlight.needs_attention.cta_label ?? 'Kirim pengingat'"
          :cta-target="payload.meta.highlight.needs_attention.cta_target ?? ''"
          :meta="null"
        />
      </div>

      <!-- 4-up KPI strip (shared component). -->
      <KpiStripCards :cards="kpiCards" />

      <!-- School-wide weekly activity — familiar bar chart. -->
      <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 sm:p-5">
        <div class="flex items-center gap-2 mb-3">
          <span class="w-7 h-7 rounded-lg grid place-items-center bg-role-teacher-soft text-role-teacher">
            <NavIcon name="bar-chart" :size="15" />
          </span>
          <p class="text-sm font-black text-slate-900">Aktivitas Sekolah 7 Hari</p>
        </div>
        <WeeklyActivityBars :data="payload.meta.weekly_activity" />
      </div>

      <!-- Table + right rail -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div class="lg:col-span-2 space-y-3 min-w-0">
          <!-- Search + status filter (shared toolbar). -->
          <PageFilterToolbar
            v-model:search="search"
            search-placeholder="Cari nama guru…"
            :search-min-width="220"
          >
            <template #chips>
              <select
                v-model="statusFilter"
                class="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:ring-2 focus:ring-brand/20 focus:border-brand"
              >
                <option value="">Semua status</option>
                <option value="active">Aktif</option>
                <option value="slowing">Melambat</option>
                <option value="silent">Sepi</option>
                <option value="never">Belum aktif</option>
              </select>
            </template>
          </PageFilterToolbar>

          <AdminTeacherEngagementTable
            :rows="payload.data"
            :search="search"
            :status-filter="statusFilter"
          />
        </div>

        <aside class="space-y-4 min-w-0">
          <SleepyTeachersCard
            :silent-teachers="silentTeachers"
            :sending="sending"
            @send="onSendReminder"
          />

          <!-- Top 3 mini list -->
          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
            <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Top minggu ini</p>
            <ul v-if="payload.meta.kpi.top_three.length > 0" class="space-y-2 mt-3">
              <li
                v-for="(t, i) in payload.meta.kpi.top_three"
                :key="t.teacher_id"
                class="flex items-center gap-3"
              >
                <span
                  class="w-6 text-sm font-black text-center flex-shrink-0"
                  :class="i === 0
                    ? 'text-amber-500'
                    : i === 1
                      ? 'text-slate-500'
                      : 'text-orange-500'"
                >
                  #{{ i + 1 }}
                </span>
                <p class="flex-1 text-2xs font-bold text-slate-800 truncate">{{ t.name }}</p>
                <p class="text-2xs font-black text-slate-800">
                  {{ t.points }}<span class="text-3xs text-slate-500 font-bold ml-1">XP</span>
                </p>
              </li>
            </ul>
            <p v-else class="text-2xs text-slate-500 mt-3">Belum ada aktivitas minggu ini.</p>
          </div>
        </aside>
      </div>
    </template>
  </div>
</template>
