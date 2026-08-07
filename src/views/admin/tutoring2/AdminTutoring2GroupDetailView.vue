<!--
  AdminTutoring2GroupDetailView.vue — admin lens on ONE learning group
  (CLEAN-2 Phase 2 · greenfield replacement for
  `admin/tutoring/AdminTutoringGroupDetailView.vue`).

  The list side is the pre-existing `AdminTutoring2GroupsView.vue`;
  this is its drill-in.

  Route: /admin/tutoring2/groups/:groupId
  Endpoints:
    GET /tutoring-v2/learning-groups/{id}              (BE-3)
    GET /tutoring-v2/learning-groups/{id}/roster       (BE-3)
    GET /tutoring-v2/sessions?learning_group_id=       (BE-4)
    GET /tutoring-v2/learning-groups/{id}/activities   (BE-23)
    GET /tutoring-v2/learning-groups/{id}/leaderboard  (BE-21)

  ── CONTRACT DIFFERENCES vs the legacy view ──────────────────────────

  1. THE GROUP IS FETCHED BY ID. The legacy view had no detail
     endpoint, so it pulled the ENTIRE group list via
     `getAllGroups()` and did `.find(g => g.id === gid)` client-side —
     an O(tenant) request to render one row. v2 has a real
     `GET /learning-groups/{id}` (which also computes `seated_count`),
     so we ask for the one group.

  2. SESSIONS ARE FILTERED SERVER-SIDE. Legacy fetched every session in
     a 30-day window tenant-wide and filtered `s.group_id === gid` in
     the browser. v2's index takes `learning_group_id`, so the filter
     moves to the server. The window also widens: legacy was
     `[today-30d, today]`; we send `from` only, so the tab shows the
     last 30 days AND everything scheduled ahead — which is what a
     group detail page is actually for.

  3. STATUS ENUMS ARE LOWERCASE. v1 shipped SCREAMING_CASE
     (`'DONE'`); the v2 enums are `scheduled | in_progress | done |
     cancelled`. The tone maps below are byte-identical to their
     siblings so the same entity never renders two colours:
       - session status  ⇄ AdminTutoring2ScheduleView.statusPillTone
       - enrollment status ⇄ AdminTutoring2EnrollmentsView.statusPillTone
       - group status    ⇄ AdminTutoring2GroupsView.statusPillTone
     Change one, change both.

  4. THE ROSTER ROW IS AN ENROLLMENT, NOT A BARE STUDENT. Legacy
     rendered every roster row with a hardcoded green "Aktif" pill —
     it had no per-row status on the wire. v2's roster returns
     `EnrollmentResource`, so the pill now shows the row's REAL status
     (trial / active / paused / graduated / withdrawn).

  5. THE 4th TAB IS REAL NOW. Legacy's "Performa" tab was a hardcoded
     "coming soon" placeholder. BE-21 shipped
     `/learning-groups/{id}/leaderboard`, so it renders an actual
     dense-ranked score table.

  6. TWO SESSION FIELDS WERE RESHAPED. v1's per-session `topic` string
     has no v2 column; the closest real field is `materials_note`, so
     that is what the row title renders (falling back to a generic
     label, never to an invented topic). v1's `duration_minutes`
     scalar is likewise gone — v2 ships `starts_at` + `ends_at` and the
     client subtracts (see `durationLabel`).

  ── DROPPED ──────────────────────────────────────────────────────────
  The legacy hero's "Ubah" and "+ Siswa" buttons were dead chrome — no
  click handler was ever bound to either. They are not ported rather
  than shipped as buttons that still do nothing. Group editing lives
  behind `PUT /tutoring-v2/learning-groups/{id}`
  (`TutoringBimbelService.updateGroup`) and enrolling lives on the
  Enrollments screen; both are separate MRs.

  ── PARTIAL-FAILURE POLICY ───────────────────────────────────────────
  The group header is the page; if it fails, the page fails. The four
  tab feeds each sit behind their own ability
  (`tutoring.group.view` / `tutoring.session.view` /
  `tutoring.activity.view` / `tutoring.leaderboard.view`), so they
  soft-fail to empty and render their own empty state instead of
  taking the screen down.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { toLocalYmd } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
  type BimbelLearningGroup,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import { ActivitiesService } from '@/services/tutoring2/activities';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';
import type { Activity } from '@/types/tutoring2/activity';
import type { LeaderboardRow } from '@/types/tutoring2/leaderboard';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const groupId = computed(() => String(route.params.groupId ?? ''));

type TabKey = 'students' | 'sessions' | 'tasks' | 'leaderboard';
const TAB_KEYS: TabKey[] = ['students', 'sessions', 'tasks', 'leaderboard'];
const tab = ref<TabKey>('students');

interface GroupDetailPayload {
  group: BimbelLearningGroup;
  roster: BimbelEnrollment[];
  sessions: BimbelSession[];
  activities: Activity[];
  leaderboard: LeaderboardRow[];
}

/** Scoped soft-fail for the ability-gated tab feeds — see file header. */
function optional<T>(p: Promise<T>, fallback: T): Promise<T> {
  return p.catch(() => fallback);
}

/**
 * 30 days back in LOCAL time. Built from a local `Date` through
 * `toLocalYmd`, never `toISOString().slice(0,10)` — the latter is UTC
 * and shifts a WIB user's window by a day.
 */
function sessionsFrom(): string {
  return toLocalYmd(new Date(Date.now() - 30 * 86_400_000));
}

const { state, reload } = useDataRefresh<GroupDetailPayload | null>(async () => {
  const id = groupId.value;
  if (!id) return null;

  const [group, roster, sessions, activities, leaderboard] = await Promise.all([
    TutoringBimbelService.getGroup(id),
    optional(TutoringBimbelService.getGroupRoster(id), {
      items: [],
      pagination: undefined,
    }),
    optional(
      TutoringBimbelService.listSessions({
        learning_group_id: id,
        per_page: 50,
        from: sessionsFrom(),
      }),
      { items: [], pagination: undefined },
    ),
    optional(ActivitiesService.listByGroup(id, { per_page: 50 }), {
      items: [],
      pagination: undefined,
    }),
    optional(TutoringLeaderboardService.getGroup(id, { limit: 50 }), {
      items: [],
      generated_at: '',
    }),
  ]);

  return {
    group,
    roster: roster.items,
    sessions: sessions.items,
    activities: activities.items,
    leaderboard: leaderboard.items,
  };
});

watch(groupId, () => void reload());

const payload = computed<GroupDetailPayload | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? (state.value.data ?? null)
    : null,
);

const group = computed<BimbelLearningGroup | null>(() => payload.value?.group ?? null);
const roster = computed<BimbelEnrollment[]>(() => payload.value?.roster ?? []);
const sessions = computed<BimbelSession[]>(() => payload.value?.sessions ?? []);
const activities = computed<Activity[]>(() => payload.value?.activities ?? []);
const leaderboard = computed<LeaderboardRow[]>(() => payload.value?.leaderboard ?? []);

const doneSessions = computed(() => sessions.value.filter((s) => s.status === 'done').length);

const kpiCards = computed<KpiCard[]>(() => {
  const g = group.value;
  return [
    {
      icon: 'users',
      label: t('tutoring2.admin.groupDetail.kpiStudents'),
      value: String(roster.value.length),
      suffix: g ? t('tutoring2.admin.groupDetail.kpiCapacitySuffix', { capacity: g.capacity }) : undefined,
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'calendar',
      label: t('tutoring2.admin.groupDetail.kpiSessions'),
      value: String(sessions.value.length),
      suffix: t('tutoring2.admin.groupDetail.kpiSessionsDoneSuffix', { count: doneSessions.value }),
      tone: 'violet',
    },
    {
      icon: 'clipboard-list',
      label: t('tutoring2.admin.groupDetail.kpiTasks'),
      value: String(activities.value.length),
      tone: 'green',
    },
    {
      icon: 'trophy',
      label: t('tutoring2.admin.groupDetail.kpiRanked'),
      value: String(leaderboard.value.length),
      tone: 'slate',
    },
  ];
});

const headerMeta = computed(() => {
  if (state.value.status === 'loading') return t('tutoring2.common.loading');
  const g = group.value;
  if (!g) return t('tutoring2.admin.groupDetail.notFound');
  const tutor = g.tutor_name
    ? t('tutoring2.admin.groupDetail.tutorPrefix', { name: g.tutor_name })
    : t('tutoring2.admin.groupDetail.noTutor');
  return [tutor, g.program_name, g.room ?? t('tutoring2.common.noRoom')]
    .filter(Boolean)
    .join(' · ');
});

function tabLabel(key: TabKey): string {
  return t(`tutoring2.admin.groupDetail.tab_${key}`);
}

/**
 * Header badge, pre-resolved in script so the template never has to
 * narrow a possibly-null `group` across a `v-if`.
 */
const groupStatus = computed<{ label: string; tone: StatusBadgeTone } | null>(() => {
  const g = group.value;
  if (!g) return null;
  return {
    label: g.status_label ?? t(`tutoring2.status.${g.status}`),
    tone: groupStatusTone(g.status),
  };
});

/** ⇄ AdminTutoring2GroupsView.statusPillTone — keep in lockstep. */
function groupStatusTone(status: BimbelLearningGroup['status']): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'draft':
      return 'neutral';
    case 'closed':
      return 'neutral';
  }
}

/** ⇄ AdminTutoring2EnrollmentsView.statusPillTone — keep in lockstep. */
function enrollmentStatusTone(status: BimbelEnrollment['status']): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'trial':
      return 'warning';
    case 'paused':
      return 'neutral';
    case 'graduated':
      return 'neutral';
    case 'withdrawn':
      return 'neutral';
  }
}

/** ⇄ AdminTutoring2ScheduleView.statusPillTone — keep in lockstep. */
function sessionStatusTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'scheduled':
      return 'neutral';
    case 'in_progress':
      return 'info';
    case 'done':
      return 'success';
    case 'cancelled':
      return 'danger';
  }
}

/**
 * Session timestamps are full ISO-8601 with an offset, so `new Date()`
 * is unambiguous — no local-parts reconstruction needed here.
 */
function formatWhen(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleString('id-ID', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * v1 carried a `duration_minutes` scalar; v2 ships `starts_at` +
 * `ends_at` and expects the client to subtract. Returns '' (not a
 * placeholder) when the pair is unusable, so the template can just
 * `v-if` on the string.
 */
function durationLabel(session: BimbelSession): string {
  const start = new Date(session.starts_at).valueOf();
  const end = new Date(session.ends_at).valueOf();
  if (Number.isNaN(start) || Number.isNaN(end) || end <= start) return '';
  return t('tutoring2.admin.groupDetail.durationMinutes', {
    count: Math.round((end - start) / 60_000),
  });
}

function activityIcon(kind: Activity['kind']): string {
  switch (kind) {
    case 'tugas':
      return 'clipboard-list';
    case 'kuis':
      return 'sparkles';
    case 'materi_baca':
      return 'book';
  }
}

function goBack(): void {
  void router.push({ name: 'admin.tutoring2.groups' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-2xs font-bold text-slate-500 hover:text-slate-900"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="13" />
      {{ t('tutoring2.common.back') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.admin.groupDetail.kicker')"
      :title="group?.name ?? t('tutoring2.common.loading')"
      :meta="headerMeta"
    >
      <StatusBadge
        v-if="groupStatus"
        :label="groupStatus.label"
        :tone="groupStatus.tone"
        uppercase
      />
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <div class="flex max-w-xl gap-1 rounded-2xl border border-slate-100 bg-white p-1">
      <button
        v-for="key in TAB_KEYS"
        :key="key"
        type="button"
        class="flex-1 rounded-xl px-3 py-1.5 text-2xs font-bold transition"
        :class="tab === key ? 'bg-brand-cobalt text-white' : 'text-slate-500 hover:text-slate-900'"
        :aria-pressed="tab === key"
        @click="tab = key"
      >
        {{ tabLabel(key) }}
      </button>
    </div>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.admin.groupDetail.notFound')"
      :empty-description="t('tutoring2.admin.groupDetail.notFoundDesc')"
      @retry="reload"
    >
      <template #default>
        <!-- Peserta -->
        <template v-if="tab === 'students'">
          <p
            v-if="roster.length === 0"
            class="rounded-3xl border border-slate-100 bg-white p-8 text-center text-2xs text-slate-400"
          >
            {{ t('tutoring2.admin.groupDetail.emptyStudents') }}
          </p>
          <div v-else class="rounded-3xl border border-slate-100 bg-white shadow-sm">
            <table class="w-full text-sm">
              <thead>
                <tr
                  class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400"
                >
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.student') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.billingMode') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.remainingQuota') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="e in roster"
                  :key="e.id"
                  class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
                >
                  <td class="px-4 py-3 font-bold text-slate-900">{{ e.student_name ?? '—' }}</td>
                  <td class="px-4 py-3 text-slate-600">
                    {{ e.billing_mode_label ?? e.billing_mode }}
                  </td>
                  <td class="px-4 py-3 text-slate-600">{{ e.remaining_sessions ?? '—' }}</td>
                  <td class="px-4 py-3">
                    <StatusBadge
                      :label="e.status_label ?? t(`tutoring2.status.${e.status}`)"
                      :tone="enrollmentStatusTone(e.status)"
                      uppercase
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>

        <!-- Sesi -->
        <template v-else-if="tab === 'sessions'">
          <p
            v-if="sessions.length === 0"
            class="rounded-3xl border border-slate-100 bg-white p-8 text-center text-2xs text-slate-400"
          >
            {{ t('tutoring2.admin.groupDetail.emptySessions') }}
          </p>
          <ul v-else class="space-y-2">
            <li
              v-for="s in sessions"
              :key="s.id"
              class="rounded-3xl border border-slate-100 bg-white p-3.5 shadow-sm"
            >
              <div class="flex items-center justify-between gap-2">
                <span class="text-2xs text-slate-500">
                  {{ [formatWhen(s.starts_at), durationLabel(s)].filter(Boolean).join(' · ') }}
                </span>
                <StatusBadge
                  :label="s.status_label ?? t(`tutoring2.status.${s.status}`)"
                  :tone="sessionStatusTone(s.status)"
                  uppercase
                />
              </div>
              <p class="mt-1 text-2xs font-bold text-slate-900">
                {{ s.materials_note ?? t('tutoring2.admin.groupDetail.sessionUntitled') }}
              </p>
              <p v-if="s.tutor_name" class="text-2xs text-slate-500">{{ s.tutor_name }}</p>
            </li>
          </ul>
        </template>

        <!-- Tugas -->
        <template v-else-if="tab === 'tasks'">
          <p
            v-if="activities.length === 0"
            class="rounded-3xl border border-slate-100 bg-white p-8 text-center text-2xs text-slate-400"
          >
            {{ t('tutoring2.admin.groupDetail.emptyTasks') }}
          </p>
          <ul v-else class="space-y-2">
            <li
              v-for="a in activities"
              :key="a.id"
              class="flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-3.5 shadow-sm"
            >
              <span
                class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-brand-cobalt/10 text-brand-cobalt"
              >
                <NavIcon :name="activityIcon(a.kind)" :size="16" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-2xs font-bold text-slate-900">{{ a.title }}</p>
                <p class="truncate text-2xs text-slate-500">
                  {{
                    [
                      a.kind_label ?? a.kind,
                      t('tutoring2.admin.groupDetail.submissionsCount', {
                        count: a.submissions_count ?? 0,
                      }),
                    ].join(' · ')
                  }}
                </p>
              </div>
              <StatusBadge
                :label="
                  a.published_at ? t('tutoring2.status.published') : t('tutoring2.status.draft')
                "
                :tone="a.published_at ? 'success' : 'neutral'"
                uppercase
              />
            </li>
          </ul>
        </template>

        <!-- Peringkat -->
        <template v-else>
          <p
            v-if="leaderboard.length === 0"
            class="rounded-3xl border border-slate-100 bg-white p-8 text-center text-2xs text-slate-400"
          >
            {{ t('tutoring2.admin.groupDetail.emptyLeaderboard') }}
          </p>
          <div v-else class="rounded-3xl border border-slate-100 bg-white shadow-sm">
            <table class="w-full text-sm">
              <thead>
                <tr
                  class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400"
                >
                  <th class="px-4 py-3 font-bold">#</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.student') }}</th>
                  <th class="px-4 py-3 font-bold">
                    {{ t('tutoring2.admin.groupDetail.thAvgScore') }}
                  </th>
                  <th class="px-4 py-3 font-bold">
                    {{ t('tutoring2.admin.groupDetail.thAssessmentsTaken') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in leaderboard"
                  :key="row.enrollment_id"
                  class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
                >
                  <td class="px-4 py-3 font-black text-slate-900">{{ row.rank }}</td>
                  <td class="px-4 py-3 font-bold text-slate-900">{{ row.student_name }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ row.avg_score }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ row.assessments_taken }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
