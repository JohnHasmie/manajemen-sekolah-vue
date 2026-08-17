<!--
  StudentTutoring2SessionDetailView.vue — single bimbel session view for
  the student (WEB-6).

  Composition:
    1. BrandPageHeader     — role="student".
    2. AsyncView           — state machine.
       Default slot renders one info panel + a materials placeholder.
    3. No KPIs, no filter toolbar, no floating CTA.

  Data path: `TutoringBimbelService.listSessions({})` filtered client-
  side to `s.id === route.params.id`. TODO: promote to a dedicated
  `getSession(id)` once the service gains it (same pattern as the tutor
  detail view).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const route = useRoute();

const sessionId = computed<string>(() => String(route.params.id));

// TODO: swap for `TutoringBimbelService.getSession(id)` once the
// service exposes a single-fetch endpoint. For now we page through
// `listSessions` and filter client-side.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({ per_page: 100 });
  const match = items.find((s) => s.id === sessionId.value);
  return match ?? null;
});

const session = computed<BimbelSession | null>(() => {
  return state.value.status === 'content' ? (state.value.data as BimbelSession) : null;
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

function sessionStatusKey(status: BimbelSession['status']): string {
  return status === 'in_progress' ? 'inProgress' : status;
}

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function formatTimeRange(startIso: string, endIso: string): string {
  const opts: Intl.DateTimeFormatOptions = { hour: '2-digit', minute: '2-digit' };
  return `${new Date(startIso).toLocaleTimeString('id-ID', opts)} – ${new Date(endIso).toLocaleTimeString('id-ID', opts)}`;
}

const metaText = computed(() =>
  session.value ? formatDateTime(session.value.starts_at) : t('tutoring2.common.loading'),
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.sessionDetail.title')"
      :meta="metaText"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="1"
      :empty-title="t('tutoring2.tutor.sessionDetail.notFound')"
      :empty-description="t('tutoring2.tutor.sessionDetail.notFoundHint')"
      @retry="reload"
    >
      <template #default>
        <template v-if="session">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-3">
            <div class="flex items-center justify-between gap-3">
              <div>
                <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.status') }}
                </p>
                <div class="mt-1">
                  <StatusBadge
                    :label="session.status_label ?? t(`tutoring2.status.${sessionStatusKey(session.status)}`)"
                    :tone="sessionTone(session.status)"
                    uppercase
                  />
                </div>
              </div>
            </div>

            <dl class="divide-y divide-slate-100 border-t border-slate-100 pt-3 text-sm">
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.time') }}
                </dt>
                <dd class="flex-1 text-slate-900">
                  {{ formatTimeRange(session.starts_at, session.ends_at) }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.group') }}
                </dt>
                <dd class="flex-1 truncate text-slate-900">
                  {{ t('tutoring2.common.group') }} {{ session.learning_group_id.slice(0, 8) }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.room') }}
                </dt>
                <dd class="flex-1 text-slate-900">{{ session.room ?? '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.tutor') }}
                </dt>
                <dd class="flex-1 truncate text-slate-900">{{ session.tutor_id ?? '—' }}</dd>
              </div>
              <div v-if="session.materials_note" class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.notes') }}
                </dt>
                <dd class="flex-1 text-slate-900">{{ session.materials_note }}</dd>
              </div>
            </dl>
          </div>

          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-3">
            <h3 class="text-sm font-bold text-slate-900">
              {{ t('tutoring2.student.sessionDetail.materialsSection') }}
            </h3>
            <!-- TODO i18n key: "Belum ada materi terkait" -->
            <p class="text-sm text-slate-500">Belum ada materi terkait</p>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
