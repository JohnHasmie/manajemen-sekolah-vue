<!--
  TutorTutoring2HomeView.vue — Tutor bimbel dashboard (WEB-4 exemplar).
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
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

const { state, reload } = useDataRefresh(async () => {
  const today = new Date();
  const todayIso = today.toISOString().slice(0, 10);
  const tomorrow = new Date(today.getTime() + 24 * 3600 * 1000).toISOString().slice(0, 10);
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 50,
    from: todayIso,
    to: tomorrow,
  });
  return items;
});
useAcademicYearWatcher(reload);

const todaySessions = computed<BimbelSession[]>(() => {
  return state.value.status === 'content' ? (state.value.data as BimbelSession[]) : [];
});

const kpiCards = computed<KpiCard[]>(() => {
  const sessions = todaySessions.value;
  const done = sessions.filter((s) => s.status === 'done').length;
  const rate = sessions.length > 0 ? Math.round((done / sessions.length) * 100) : 0;
  return [
    { icon: 'calendar', label: t('tutoring2.tutor.home.kpiSessionsToday'), value: String(sessions.length) },
    { icon: 'user-check', label: t('tutoring2.tutor.home.kpiAttendance'), value: `${rate}%`, tone: rate >= 80 ? 'green' : 'amber' },
    { icon: 'clipboard', label: t('tutoring2.tutor.home.kpiScoresPending'), value: '0' },
    { icon: 'users', label: t('tutoring2.tutor.home.kpiStudentsActive'), value: '—' },
  ];
});

function sessionTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'done': return 'success';
    case 'in_progress': return 'info';
    case 'scheduled': return 'neutral';
    case 'cancelled': return 'danger';
  }
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

function openSession(id: string) {
  router.push({ name: 'teacher.tutoring2.session-detail', params: { id } });
}

function statusLabel(status: BimbelSession['status']): string {
  return t(`tutoring2.status.${status === 'in_progress' ? 'inProgress' : status}`);
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.home.title')"
      :meta="state.status === 'content' ? t('tutoring2.tutor.home.meta', { count: todaySessions.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.tutor.home.emptyTitle')"
      :empty-description="t('tutoring2.tutor.home.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <header class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
            <h3 class="text-sm font-bold text-slate-900">{{ t('tutoring2.tutor.home.sectionToday') }}</h3>
            <button type="button" class="text-2xs font-bold text-brand-cobalt" @click="router.push({ name: 'teacher.tutoring2.sessions' })">
              {{ t('tutoring2.common.seeAll') }} →
            </button>
          </header>
          <ul class="divide-y divide-slate-100">
            <li v-for="s in (data as BimbelSession[])" :key="s.id" class="flex items-center gap-3 px-4 py-3 hover:bg-slate-50">
              <div class="w-14 shrink-0 text-center">
                <span class="text-sm font-bold text-brand-cobalt">{{ formatTime(s.starts_at) }}</span>
              </div>
              <div class="min-w-0 flex-1">
                <!-- TODO i18n key: "Grup {short-id}" prefix noun -->
                <p class="truncate text-sm font-bold text-slate-900">{{ t('tutoring2.common.group') }} {{ s.learning_group_id.slice(0, 8) }}</p>
                <p class="truncate text-2xs text-slate-500">{{ s.room ?? '—' }}</p>
              </div>
              <StatusBadge :label="s.status_label ?? statusLabel(s.status)" :tone="sessionTone(s.status)" uppercase />
              <Button
                v-if="s.status === 'in_progress' || s.status === 'scheduled'"
                variant="primary"
                size="sm"
                @click="openSession(s.id)"
              >{{ t('tutoring2.common.takeAttendance') }}</Button>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
