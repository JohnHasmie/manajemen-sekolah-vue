<!--
  StudentTutoring2ScheduleView.vue — Siswa bimbel upcoming schedule (WEB-6).

  Mirrors StudentTutoring2HomeView.vue composition:
    1. BrandPageHeader        — role="student".
    2. KpiStripCards          — 4 tiles (Hari ini / Minggu ini / Akan datang / Selesai).
    3. AsyncView              — day-grouped list of the student's upcoming sessions.

  No FAB — students never create sessions. Filtering for upcoming happens
  client-side (`starts_at >= today`); server paginates 100 rows.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

// ── Data ──────────────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({ per_page: 100 });
  return items;
});

// ── Derived ───────────────────────────────────────────────────────
const allSessions = computed<BimbelSession[]>(() => {
  return state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as BimbelSession[] | undefined) ?? [])
    : [];
});

function startOfToday(): number {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

const upcomingSessions = computed<BimbelSession[]>(() => {
  const cutoff = startOfToday();
  return allSessions.value.filter((s) => new Date(s.starts_at).getTime() >= cutoff);
});

// ── KPIs ─────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const items = allSessions.value;
  const todayKey = new Date().toLocaleDateString('en-CA');
  const startWeek = startOfToday();
  const endWeek = startWeek + 7 * 24 * 3600 * 1000;

  const todayCount = items.filter((s) => sessionDateKey(s.starts_at) === todayKey).length;
  const thisWeekCount = items.filter((s) => {
    const ts = new Date(s.starts_at).getTime();
    return ts >= startWeek && ts < endWeek;
  }).length;
  const upcomingCount = upcomingSessions.value.length;
  const doneCount = items.filter((s) => s.status === 'done').length;

  return [
    { icon: 'sun', label: t('tutoring2.student.schedule.kpiToday'), value: String(todayCount), tone: 'brand' },
    { icon: 'calendar', label: t('tutoring2.student.schedule.kpiThisWeek'), value: String(thisWeekCount), tone: 'violet' },
    { icon: 'clock', label: t('tutoring2.student.schedule.kpiUpcoming'), value: String(upcomingCount), tone: 'amber' },
    { icon: 'check-circle', label: t('tutoring2.student.schedule.kpiCompleted'), value: String(doneCount), tone: 'green' },
  ];
});

// ── Day grouping ─────────────────────────────────────────────────
interface DayGroup {
  key: string;
  label: string;
  sessions: BimbelSession[];
}

function sessionDateKey(iso: string): string {
  const d = new Date(iso);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function formatDayHeader(iso: string): string {
  return new Date(iso).toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
  });
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

const grouped = computed<DayGroup[]>(() => {
  const map = new Map<string, DayGroup>();
  for (const s of upcomingSessions.value) {
    const key = sessionDateKey(s.starts_at);
    let g = map.get(key);
    if (!g) {
      g = { key, label: formatDayHeader(s.starts_at), sessions: [] };
      map.set(key, g);
    }
    g.sessions.push(s);
  }
  return Array.from(map.values())
    .sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0))
    .map((g) => ({
      ...g,
      sessions: g.sessions.sort((a, b) => a.starts_at.localeCompare(b.starts_at)),
    }));
});

function sessionTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'done':
      return 'success';
    case 'in_progress':
      return 'info';
    case 'scheduled':
      return 'neutral';
    case 'cancelled':
      return 'danger';
  }
}

function statusLabel(status: BimbelSession['status']): string {
  return t(`tutoring2.status.${status === 'in_progress' ? 'inProgress' : status}`);
}

function openDetail(id: string) {
  router.push({ name: 'student.tutoring2.session-detail', params: { id } });
}

const metaLabel = computed(() =>
  state.value.status === 'loading'
    ? t('tutoring2.common.loading')
    : t('tutoring2.student.schedule.meta', { count: upcomingSessions.value.length }),
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.schedule.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="4"
      :empty-title="t('tutoring2.student.schedule.emptyTitle')"
      :empty-description="t('tutoring2.student.schedule.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div
          v-if="grouped.length === 0"
          class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-sm text-slate-500 shadow-sm"
        >
          <!-- TODO i18n key: "Belum ada jadwal mendatang." -->
          {{ t('tutoring2.student.schedule.emptyDesc') }}
        </div>
        <div v-else class="space-y-md">
          <section v-for="group in grouped" :key="group.key" class="space-y-sm">
            <h3 class="px-1 text-2xs font-bold uppercase tracking-wide text-slate-500">
              {{ group.label }}
            </h3>
            <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
              <ul class="divide-y divide-slate-100">
                <li
                  v-for="s in group.sessions"
                  :key="s.id"
                  class="flex items-center gap-3 px-4 py-3 hover:bg-slate-50 cursor-pointer"
                  @click="openDetail(s.id)"
                >
                  <div class="w-14 shrink-0 text-center">
                    <span class="text-sm font-bold text-brand-azure">{{ formatTime(s.starts_at) }}</span>
                  </div>
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm font-bold text-slate-900">
                      {{ t('tutoring2.common.group') }} {{ s.learning_group_id.slice(0, 8) }}
                    </p>
                    <p class="truncate text-2xs text-slate-500">
                      {{ s.room ?? t('tutoring2.common.noRoom') }}
                    </p>
                  </div>
                  <StatusBadge
                    :label="s.status_label ?? statusLabel(s.status)"
                    :tone="sessionTone(s.status)"
                    uppercase
                  />
                </li>
              </ul>
            </div>
          </section>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
