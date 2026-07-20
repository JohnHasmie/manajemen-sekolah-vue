<!--
  AdminStaffEngagementView.vue — /admin/staff-engagement

  Staff-side mirror of AdminTeacherEngagementView. Same page skeleton,
  swapped for the staff endpoint bundle + a Peran filter chip that keys
  on the backend `ability_role_tag` field (derived from
  intersect(user_abilities, staff_quest_map.keys)).

  Single fetch of /admin/staff-engagement at mount — the payload
  bundles kpi + highlight + rows + weekly_activity so the page paints
  once. `send-reminders` POSTs `user_ids[]` (not teacher_ids); staff
  rows carry user_id and never teacher_id.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AdminStaffEngagementTable from '@/components/feature/staff-engagement/AdminStaffEngagementTable.vue';
import WeeklyActivityBars from '@/components/feature/teacher-engagement/WeeklyActivityBars.vue';
import SleepyStaffCard from '@/components/feature/staff-engagement/SleepyStaffCard.vue';
import GamificationHighlightCard from '@/components/feature/gamification/GamificationHighlightCard.vue';
import AdminEngagementSkeleton from '@/components/feature/gamification/AdminEngagementSkeleton.vue';
import { TeacherProgressService, type AdminStaffIndexPayload, type TeacherRowStatus } from '@/services/teacher-progress.service';
import { useToast } from '@/composables/useToast';
import { useRouter } from 'vue-router';

const toast = useToast();
const router = useRouter();

const payload = ref<AdminStaffIndexPayload | null>(null);
const loadError = ref<string | null>(null);
const loading = ref(true);
const sending = ref(false);

const search = ref('');
const statusFilter = ref<TeacherRowStatus | ''>('');
const roleFilter = ref<string>('');

const silentStaff = computed(() =>
  (payload.value?.data ?? [])
    .filter((r) => r.status === 'silent')
    .map((r) => ({
      user_id: r.user_id,
      name: r.name,
      last_active_at: r.last_active_at,
    })),
);

// Distinct peran tags actually present in the payload — feeds the
// Peran filter dropdown so we don't offer an option that produces
// zero rows.
const roleOptions = computed<string[]>(() => {
  const set = new Set<string>();
  for (const r of payload.value?.data ?? []) set.add(r.ability_role_tag);
  return Array.from(set).sort();
});

const kpiCards = computed<KpiCard[]>(() => {
  const k = payload.value?.meta.kpi;
  return [
    { icon: 'users', label: 'Total staf', value: k?.total_staff ?? 0, tone: 'brand' },
    { icon: 'activity', label: 'Aktif minggu ini', value: k?.active_this_week ?? 0, tone: 'green' },
    { icon: 'flame', label: 'Rata streak', value: k?.average_streak ?? 0, suffix: 'hari', tone: 'amber' },
    { icon: 'alert-circle', label: 'Perlu perhatian', value: k?.needs_attention_count ?? 0, tone: 'red' },
  ];
});

async function load() {
  loading.value = true;
  loadError.value = null;
  try {
    payload.value = await TeacherProgressService.getAdminStaffIndex();
  } catch (e: any) {
    loadError.value = e?.response?.status === 402
      ? 'Modul Prestasi belum aktif untuk sekolah ini.'
      : 'Gagal memuat data engagement staf.';
  } finally {
    loading.value = false;
  }
}

async function onSendReminder(userIds: string[]) {
  sending.value = true;
  try {
    const res = await TeacherProgressService.sendStaffReminders(userIds);
    toast.success(`Pengingat terkirim ke ${res.sent} staf.`);
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
      role="staff"
      kicker="Retensi Staf"
      title="Prestasi Staf"
      meta="Pantau engagement, apresiasi staf produktif, sapa yang tidur."
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
      <!-- Admin highlight: staff_of_month always visible, needs_attention optional. -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <GamificationHighlightCard
          :state="payload.meta.highlight.staff_of_month.state"
          :eyebrow="payload.meta.highlight.staff_of_month.eyebrow"
          :title="payload.meta.highlight.staff_of_month.title"
          :sub="payload.meta.highlight.staff_of_month.sub"
          :cta-label="payload.meta.highlight.staff_of_month.cta_label"
          :cta-target="payload.meta.highlight.staff_of_month.cta_target"
          :meta="null"
          @cta="router.push(payload.meta.highlight.staff_of_month.cta_target)"
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

      <KpiStripCards :cards="kpiCards" />

      <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4 sm:p-5">
        <div class="flex items-center gap-2 mb-3">
          <span class="w-7 h-7 rounded-lg grid place-items-center bg-role-staff-soft text-role-staff">
            <NavIcon name="bar-chart" :size="15" />
          </span>
          <p class="text-sm font-black text-slate-900">Aktivitas Staf Sekolah 7 Hari</p>
        </div>
        <WeeklyActivityBars :data="payload.meta.weekly_activity" />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div class="lg:col-span-2 space-y-3 min-w-0">
          <PageFilterToolbar
            v-model:search="search"
            search-placeholder="Cari nama staf…"
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
              <select
                v-if="roleOptions.length > 1"
                v-model="roleFilter"
                class="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:ring-2 focus:ring-brand/20 focus:border-brand"
              >
                <option value="">Semua peran</option>
                <option v-for="opt in roleOptions" :key="opt" :value="opt">{{ opt }}</option>
              </select>
            </template>
          </PageFilterToolbar>

          <AdminStaffEngagementTable
            :rows="payload.data"
            :search="search"
            :status-filter="statusFilter"
            :role-filter="roleFilter"
          />
        </div>

        <aside class="space-y-4 min-w-0">
          <SleepyStaffCard
            :silent-staff="silentStaff"
            :sending="sending"
            @send="onSendReminder"
          />

          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
            <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Top minggu ini</p>
            <ul v-if="payload.meta.kpi.top_three.length > 0" class="space-y-2 mt-3">
              <li
                v-for="(t, i) in payload.meta.kpi.top_three"
                :key="t.user_id"
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
