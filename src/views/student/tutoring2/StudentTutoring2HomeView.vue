<!--
  StudentTutoring2HomeView.vue — Siswa bimbel dashboard (WEB-5 exemplar).

  Composition contract (identical to tutor/admin views):
    BrandPageHeader (role="student") → KpiStripCards → AsyncView.

  All display copy sourced via `t('tutoring2.student.…')` — hardcoded
  Indonesian never appears inline. Follow this pattern in every other
  student/tutoring2/*View.vue.
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
import { useDataRefresh } from '@/composables/useDataRefresh';
import { toLocalYmd } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

const { state, reload } = useDataRefresh(async () => {
  const today = new Date();
  const todayIso = toLocalYmd(today);
  const tomorrow = toLocalYmd(new Date(today.getTime() + 24 * 3600 * 1000));
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 20,
    from: todayIso,
    to: tomorrow,
  });
  return items;
});

const todaySessions = computed<BimbelSession[]>(() => {
  return state.value.status === 'content' ? (state.value.data as BimbelSession[]) : [];
});

const kpiCards = computed<KpiCard[]>(() => {
  const n = todaySessions.value.length;
  return [
    { icon: 'calendar', label: t('tutoring2.student.home.kpiSessionsToday'), value: String(n) },
    { icon: 'user-check', label: t('tutoring2.student.home.kpiAttendance'), value: '—' },
    { icon: 'chart-bar', label: t('tutoring2.student.home.kpiScoreAvg'), value: '—' },
    { icon: 'cash', label: t('tutoring2.student.home.kpiOutstanding'), value: '0', tone: 'brand' },
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

function statusLabel(status: BimbelSession['status']): string {
  return t(`tutoring2.status.${status === 'in_progress' ? 'inProgress' : status}`);
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

function openSession(id: string) {
  router.push({ name: 'student.tutoring2.session-detail', params: { id } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.home.title')"
      :meta="state.status === 'content' ? t('tutoring2.student.home.meta', { count: todaySessions.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.student.home.emptyTitle')"
      :empty-description="t('tutoring2.student.home.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <header class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
            <h3 class="text-sm font-bold text-slate-900">{{ t('tutoring2.student.home.sectionToday') }}</h3>
            <button type="button" class="text-2xs font-bold text-brand-azure" @click="router.push({ name: 'student.tutoring2.schedule' })">
              {{ t('tutoring2.common.seeAll') }} →
            </button>
          </header>
          <ul class="divide-y divide-slate-100">
            <li v-for="s in (data as BimbelSession[])" :key="s.id" class="flex items-center gap-3 px-4 py-3 hover:bg-slate-50">
              <div class="w-14 shrink-0 text-center">
                <span class="text-sm font-bold text-brand-azure">{{ formatTime(s.starts_at) }}</span>
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">{{ t('tutoring2.common.group') }} {{ s.learning_group_id.slice(0, 8) }}</p>
                <p class="truncate text-2xs text-slate-500">{{ s.room ?? '—' }}</p>
              </div>
              <StatusBadge :label="s.status_label ?? statusLabel(s.status)" :tone="sessionTone(s.status)" uppercase />
              <Button
                v-if="s.status === 'in_progress'"
                variant="primary"
                size="sm"
                @click="openSession(s.id)"
              >{{ t('tutoring2.student.home.joinSession') }}</Button>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
