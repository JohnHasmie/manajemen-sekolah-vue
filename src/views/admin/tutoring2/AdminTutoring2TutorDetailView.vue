<!--
  AdminTutoring2TutorDetailView.vue — admin-facing tutor profile page.

  Consumes:
    - GET  /tutoring-v2/tutors/{id}             (BE-17)
    - GET  /tutoring-v2/learning-groups?tutor_id  (BE-3 — active kelompok list)
    - GET  /tutoring-v2/sessions?tutor_id&from    (BE-4 — upcoming sesi list)
    - POST /tutoring-v2/tutors/{id}/deactivate    (BE-17 — 409 branch surfaced)

  Ratings tab intentionally reads "belum tersedia" — the BE-20
  `/tutors/{id}/ratings` endpoint has not shipped yet in this branch's
  backend snapshot (only 4 tutor routes live), so we render an
  informative empty state instead of firing a 404 network call. When
  BE-20 lands, the fetch + comment list can be wired here without any
  layout change.

  Ability gates:
    - `tutoring.tutor.view`   → whole view (route guard could also handle
                                 this later; we double-gate here so a
                                 stale link doesn't leak fields.)
    - `tutoring.tutor.manage` → the danger-footer Deactivate button.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import EmptyState from '@/components/data/EmptyState.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useAuthStore } from '@/stores/auth';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import type { Tutor, DeactivateTutorConflict } from '@/types/tutoring2/tutor';
import type { StatusBadgeTone } from '@/types/status-badge';
import { formatDateTime } from '@/lib/format';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const auth = useAuthStore();

const canView = computed(() => auth.hasAbility('tutoring.tutor.view'));
const canManage = computed(() => auth.hasAbility('tutoring.tutor.manage'));

const tutorId = computed(() => String(route.params.id ?? ''));

interface TutorBundle {
  tutor: Tutor;
  activeGroups: BimbelLearningGroup[];
  upcomingSessions: BimbelSession[];
}

const { state, reload } = useDataRefresh<TutorBundle>(async () => {
  // Parallel fetches — the tutor detail is the primary payload; the
  // groups + sessions feed the two tabs. Failure of the tab lists
  // shouldn't kill the whole page, so we catch each list independently
  // and degrade to an empty array. The tutor GET is the only fatal one.
  const tutor = await TutoringTutorsService.get(tutorId.value);
  const [groupsRes, sessionsRes] = await Promise.allSettled([
    TutoringBimbelService.listGroups({ tutor_id: tutorId.value }),
    TutoringBimbelService.listSessions({
      tutor_id: tutorId.value,
      status: 'scheduled',
      // Only look forward from today so the "upcoming" tab doesn't
      // pull historical rows. Local date is fine — sessions are
      // filtered coarsely and the exact tz cutoff isn't load-bearing.
      from: new Date().toISOString().slice(0, 10),
    }),
  ]);
  const activeGroups =
    groupsRes.status === 'fulfilled'
      ? (groupsRes.value.items ?? []).filter((g) => g.status === 'active')
      : [];
  const upcomingSessions = sessionsRes.status === 'fulfilled' ? sessionsRes.value.items ?? [] : [];
  return { tutor, activeGroups, upcomingSessions };
});

// Re-run when the route id changes (deep-linking between tutor rows).
watch(tutorId, () => {
  if (tutorId.value) reload();
});

type TabKey = 'groups' | 'sessions' | 'ratings';
const activeTab = ref<TabKey>('groups');
const tabs = computed(() => [
  { key: 'groups' as const, label: t('tutoring2.admin.tutorDetail.tabGroups') },
  { key: 'sessions' as const, label: t('tutoring2.admin.tutorDetail.tabSessions') },
  { key: 'ratings' as const, label: t('tutoring2.admin.tutorDetail.tabRatings') },
]);

const kpiCards = computed<KpiCard[]>(() => {
  const bundle = state.value.status === 'content' ? (state.value.data as TutorBundle) : null;
  return [
    {
      icon: 'users',
      label: t('tutoring2.admin.tutorDetail.kpiActiveGroups'),
      value: bundle ? String(bundle.tutor.active_group_count) : '—',
    },
    {
      icon: 'calendar',
      label: t('tutoring2.admin.tutorDetail.kpiUpcomingSessions'),
      value: bundle ? String(bundle.upcomingSessions.length) : '—',
    },
    {
      // BE-20 not shipped — render em-dash so the tile stays visible
      // and the layout doesn't jump once the endpoint lands.
      icon: 'star',
      label: t('tutoring2.admin.tutorDetail.kpiAvgRating'),
      value: '—',
    },
  ];
});

const statusTone = computed<StatusBadgeTone>(() =>
  state.value.status === 'content' && (state.value.data as TutorBundle).tutor.is_active
    ? 'success'
    : 'neutral',
);

const statusLabel = computed(() => {
  if (state.value.status !== 'content') return '';
  return (state.value.data as TutorBundle).tutor.is_active
    ? t('tutoring2.admin.tutorDetail.statusActive')
    : t('tutoring2.admin.tutorDetail.statusInactive');
});

// ── Deactivate flow ──────────────────────────────────────────────────
const confirmOpen = ref(false);
const isDeactivating = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

async function onConfirmDeactivate() {
  if (isDeactivating.value) return;
  isDeactivating.value = true;
  try {
    await TutoringTutorsService.deactivate(tutorId.value);
    confirmOpen.value = false;
    toast.value = { message: t('tutoring2.admin.tutorDetail.deactivateOk'), tone: 'success' };
    await reload();
  } catch (e: unknown) {
    const anyErr = e as {
      response?: { status?: number; data?: DeactivateTutorConflict & { message?: string } };
      message?: string;
    };
    // 409 → BE returns { message, active_group_count } — surface both
    // verbatim so admins see the exact blocker count in Indonesian.
    if (anyErr?.response?.status === 409 && anyErr.response.data?.message) {
      const cnt = anyErr.response.data.active_group_count ?? 0;
      toast.value = {
        message: t('tutoring2.admin.tutorDetail.deactivateBlocked', { count: cnt }),
        tone: 'error',
      };
    } else {
      toast.value = {
        message: anyErr?.response?.data?.message || anyErr?.message || t('tutoring2.admin.tutorDetail.deactivateFail'),
        tone: 'error',
      };
    }
    confirmOpen.value = false;
  } finally {
    isDeactivating.value = false;
  }
}

function goToGroup(g: BimbelLearningGroup) {
  // Deep-link back to the greenfield groups list — a dedicated detail
  // route lands with WEB-11; for now the list is the safest target.
  router.push({ name: 'admin.tutoring2.groups', query: { focus: g.id } });
}
</script>

<template>
  <div v-if="!canView" class="p-lg">
    <EmptyState
      icon="lock"
      :title="t('tutoring2.admin.tutorDetail.forbiddenTitle')"
      :description="t('tutoring2.admin.tutorDetail.forbiddenDesc')"
    />
  </div>

  <div v-else class="space-y-md pb-24">
    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.admin.tutorDetail.notFoundTitle')"
      :empty-description="t('tutoring2.admin.tutorDetail.notFoundDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="space-y-md">
          <!-- Header with kicker + name + email meta. The status badge
               goes in the default (trailing) slot so it sits on the
               right of the title. Uses the tutoring-themed
               BrandPageHeader so the surface stays on the bimbel
               palette (route name contains `tutoring`). -->
          <BrandPageHeader
            role="admin"
            :kicker="t('tutoring2.common.tutor')"
            :title="(data as TutorBundle).tutor.name"
            :meta="(data as TutorBundle).tutor.email ?? t('tutoring2.admin.tutorDetail.noEmail')"
          >
            <StatusBadge :label="statusLabel" :tone="statusTone" uppercase dot />
          </BrandPageHeader>

          <!-- Avatar strip sits under the header (BrandPageHeader has
               no leading slot; keep the avatar visible but decoupled). -->
          <div class="flex items-center gap-3 -mt-1">
            <InitialsAvatar
              :name="(data as TutorBundle).tutor.name"
              :size="44"
            />
            <div class="min-w-0">
              <p class="text-sm font-bold text-slate-800 truncate">
                {{ (data as TutorBundle).tutor.name }}
              </p>
              <p class="text-xs text-slate-500 truncate">
                {{ (data as TutorBundle).tutor.email ?? t('tutoring2.admin.tutorDetail.noEmail') }}
                <span v-if="(data as TutorBundle).tutor.employee_number">
                  · {{ (data as TutorBundle).tutor.employee_number }}
                </span>
              </p>
            </div>
          </div>

          <KpiStripCards :cards="kpiCards" :loading="false" />

          <!-- Tab strip — hand-rolled: matches the tone of the rest of
               tutoring2 (small, brand-underlined). Keeps the dependency
               footprint tight for this MR. -->
          <div class="border-b border-slate-200 flex gap-6 text-sm font-bold">
            <button
              v-for="tab in tabs"
              :key="tab.key"
              type="button"
              class="pb-2 -mb-px border-b-2 transition-colors"
              :class="activeTab === tab.key
                ? 'border-brand-cobalt text-brand-cobalt'
                : 'border-transparent text-slate-500 hover:text-slate-700'"
              @click="activeTab = tab.key"
            >
              {{ tab.label }}
            </button>
          </div>

          <!-- Tab: Kelompok -->
          <section v-if="activeTab === 'groups'" class="rounded-3xl border border-slate-100 bg-white shadow-sm">
            <div
              v-if="(data as TutorBundle).activeGroups.length === 0"
              class="p-lg"
            >
              <EmptyState
                icon="users"
                :title="t('tutoring2.admin.tutorDetail.emptyGroupsTitle')"
                :description="t('tutoring2.admin.tutorDetail.emptyGroupsDesc')"
              />
            </div>
            <ul v-else class="divide-y divide-slate-100">
              <li
                v-for="g in (data as TutorBundle).activeGroups"
                :key="g.id"
                class="flex items-center justify-between px-4 py-3 hover:bg-slate-50 cursor-pointer"
                @click="goToGroup(g)"
              >
                <div class="min-w-0">
                  <p class="font-bold text-slate-900 truncate">{{ g.name }}</p>
                  <p class="text-xs text-slate-500 truncate">
                    {{ g.program_name ?? t('tutoring2.common.notAvailable') }}
                    <span v-if="g.term_name"> · {{ g.term_name }}</span>
                  </p>
                </div>
                <div class="flex items-center gap-2 flex-shrink-0">
                  <span class="text-xs text-slate-500">
                    {{ g.seated_count ?? 0 }} / {{ g.capacity }}
                  </span>
                  <StatusBadge
                    :label="g.status_label ?? t(`tutoring2.status.${g.status}`)"
                    tone="success"
                    uppercase
                  />
                </div>
              </li>
            </ul>
          </section>

          <!-- Tab: Sesi mendatang -->
          <section v-if="activeTab === 'sessions'" class="rounded-3xl border border-slate-100 bg-white shadow-sm">
            <div
              v-if="(data as TutorBundle).upcomingSessions.length === 0"
              class="p-lg"
            >
              <EmptyState
                icon="calendar"
                :title="t('tutoring2.admin.tutorDetail.emptySessionsTitle')"
                :description="t('tutoring2.admin.tutorDetail.emptySessionsDesc')"
              />
            </div>
            <ul v-else class="divide-y divide-slate-100">
              <li
                v-for="s in (data as TutorBundle).upcomingSessions"
                :key="s.id"
                class="px-4 py-3"
              >
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <p class="font-bold text-slate-900 truncate">
                      {{ s.learning_group_name ?? t('tutoring2.common.notAvailable') }}
                    </p>
                    <p class="text-xs text-slate-500">
                      {{ formatDateTime(s.starts_at) }}
                      <span v-if="s.room"> · {{ s.room }}</span>
                    </p>
                  </div>
                  <StatusBadge
                    :label="s.status_label ?? t(`tutoring2.status.${s.status}`)"
                    tone="info"
                    uppercase
                  />
                </div>
              </li>
            </ul>
          </section>

          <!-- Tab: Rating (BE-20 not shipped in this branch's BE) -->
          <section v-if="activeTab === 'ratings'" class="rounded-3xl border border-slate-100 bg-white shadow-sm p-lg">
            <EmptyState
              icon="star"
              :title="t('tutoring2.admin.tutorDetail.ratingsSoonTitle')"
              :description="t('tutoring2.admin.tutorDetail.ratingsSoonDesc')"
            />
          </section>

          <!-- Danger footer — only for users with tutor.manage. Warning
               copy in the body of the confirm dialog quotes the exact
               active-group count so admins don't have to guess. -->
          <footer
            v-if="canManage"
            class="rounded-3xl border border-red-100 bg-red-50/40 p-md flex items-center justify-between gap-md"
          >
            <div class="min-w-0">
              <p class="font-bold text-red-800 text-sm">
                {{ t('tutoring2.admin.tutorDetail.dangerTitle') }}
              </p>
              <p class="text-xs text-red-700/80">
                {{ t('tutoring2.admin.tutorDetail.dangerDesc') }}
              </p>
            </div>
            <Button
              variant="danger"
              :disabled="!(data as TutorBundle).tutor.is_active"
              @click="confirmOpen = true"
            >
              {{ t('tutoring2.admin.tutorDetail.deactivateCta') }}
            </Button>
          </footer>
        </div>
      </template>
    </AsyncView>

    <Modal
      v-if="confirmOpen && state.status === 'content'"
      size="sm"
      :title="t('tutoring2.admin.tutorDetail.confirmTitle')"
      @close="confirmOpen = false"
    >
      <p class="text-sm text-slate-700">
        {{
          t('tutoring2.admin.tutorDetail.confirmBody', {
            name: (state.data as TutorBundle).tutor.name,
          })
        }}
      </p>
      <p
        v-if="(state.data as TutorBundle).tutor.active_group_count > 0"
        class="mt-2 rounded-xl bg-amber-50 px-3 py-2 text-xs text-amber-800"
      >
        {{
          t('tutoring2.admin.tutorDetail.confirmActiveGroups', {
            count: (state.data as TutorBundle).tutor.active_group_count,
          })
        }}
      </p>
      <footer class="flex justify-end gap-sm pt-md border-t border-slate-100 mt-md">
        <Button variant="ghost" @click="confirmOpen = false" :disabled="isDeactivating">
          {{ t('tutoring2.common.cancel') }}
        </Button>
        <Button variant="danger" :loading="isDeactivating" @click="onConfirmDeactivate">
          {{ t('tutoring2.admin.tutorDetail.deactivateCta') }}
        </Button>
      </footer>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
