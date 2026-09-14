<!--
  TutorTutoring2ActivityDetailView.vue — one bimbel activity, read-only
  (wires BE-23 `ActivityController::show`).

  Reported verbatim by the product owner: "halaman kegiatan ketika di
  klik list kegiatannya seharusnya memunculkan detail kegiatan
  tersebut". The row WAS inert — the `<li>` on
  TutorTutoring2ActivitiesView carried no click handler at all, so the
  only reachable things in it were the four action buttons underneath.
  There was no detail surface anywhere in the tutor shell to reach.

  Composition copies TutorTutoring2SessionDetailView exactly, because
  that is the shape every tutor detail screen in this app already takes:
    1. BrandPageHeader — role="teacher".
    2. AsyncView       — state machine over `ActivitiesService.get(id)`.
                         Default slot renders one info card + a button row.
    3. No KPIs, no filter toolbar, no floating CTA.

  ── The payload is IDENTICAL to a list row. Read this before "optimising"
     the fetch away ──

  `ActivityController@index` and `@show` return the SAME
  `ActivityResource`, with byte-identical eager loads
  (`learningGroup:id,name`, `program:id,name`) and the same
  `->withCount('submissions')`. All sixteen keys — `description`
  included — already ship on every list row. So this request buys no
  FIELD that the list lacks, and any comment claiming otherwise would be
  wrong.

  What it buys is three things the row object cannot:

    1. A URL that survives a refresh. `/teacher/tutoring2/activities/:id`
       has to render for someone who typed it, bookmarked it, or was
       sent it. The list is fetched per GROUP
       (`/learning-groups/{groupId}/activities`) and the group id is not
       in this URL, so there is nothing in memory to read the row out of.
    2. An honest 404. `show` applies the tutor's group scope BEFORE
       `findOrFail`, so a deleted activity, or one belonging to a
       colleague's group, REJECTS — and `useDataRefresh` lands on its
       `error` branch. Passing the row through router state would render
       a stale copy of a row that no longer exists.
    3. Freshness. Publishing or editing from the list and then opening
       the detail shows what the server has, not what the list had.

  What this screen shows that the list ROW does not RENDER is the real
  user-visible gain: the description (rich HTML — today a tutor without
  `tutoring.activity.manage` cannot read the instructions they were
  given ANYWHERE in the web app, because the only consumer of that field
  is the edit composer), the program, the group name, the max score, and
  the publication timestamp.

  ── Ability gate ──

  The route carries `ability: 'tutoring.activity.view'`, which is
  literally the first line of `ActivityController::show`
  (`$this->authorize('tutoring.activity.view')`). It is not a
  plausible-sounding key: a caller without it gets a 403 from the
  server, so bouncing them at the router shows them their home instead
  of an error card. Both admin and tutor bimbel defaults grant it
  (`PermissionCatalog::adminTutoringDefaults()` /
  `tutorTutoringDefaults()`), so nobody entitled to the screen is hidden
  from it.

  ── Why there are no write controls here ──

  Deliberate, not an oversight. Compose / edit / publish / delete all
  authorize on `tutoring.activity.manage` and all already live on the
  list row one tap away. Duplicating them here would mean duplicating
  the `canManage` gate, the publish dialog and the delete confirm, and
  the second copy is what drifts. The only control on this screen is a
  navigation to the submissions grader, which authorizes on
  `tutoring.activity.view` — the SAME key this route is gated on — so it
  cannot 403 for anyone who can see this page.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { ActivitiesService } from '@/services/tutoring2/activities';
import type { Activity } from '@/types/tutoring2/activity';
import { activityKindLabel } from '@/lib/bimbel-activity-kind';
import { bimbelGroupLabel, bimbelProgramLabel } from '@/lib/bimbel-session-label';
// Two content eras, same as announcements: the compose panel writes
// Quill HTML, but an activity created through the API (or by the demo
// provisioner) can hold plain text with real newlines. This helper
// sanitises the first and upgrades the second; a bare `v-html` would
// render stored XSS for the first and collapse every line break for the
// second.
import { renderAnnouncementHtml } from '@/lib/sanitize-html';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const activityId = computed<string>(() => String(route.params.id ?? ''));

// A missing, deleted or out-of-scope id REJECTS with a 404, so
// `useDataRefresh` lands on its `error` branch — never `empty`, and
// never a blank screen. AsyncView's default error card classifies
// "Request failed with status code 404" into its `notFound` hint
// (`classifyError`), which is why no `error-title` is overridden here:
// a network blip must not be reported as "kegiatan tidak ditemukan".
// The `empty-*` labels below stay for the envelope-without-data case,
// exactly as the tutor session detail is wired.
const { state, reload } = useDataRefresh(() =>
  ActivitiesService.get(activityId.value),
);

const activity = computed<Activity | null>(() =>
  state.value.status === 'content' ? (state.value.data as Activity) : null,
);

const kindText = computed(() =>
  activity.value ? activityKindLabel(activity.value.kind, t) : '',
);

const isPublished = computed(() => !!activity.value?.published_at);

const descriptionHtml = computed(() =>
  renderAnnouncementHtml(activity.value?.description),
);

function formatDate(iso?: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

function formatDateTime(iso?: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

const metaText = computed(() =>
  activity.value ? activity.value.title : t('tutoring2.common.loading'),
);

/**
 * The grader for THIS activity. Same target the list row's "Nilai"
 * button uses, and the same query-param contract
 * `TutorTutoring2SubmissionsView` reads (`route.query.activity_id`) —
 * not a second, prettier one, because two ways of addressing the same
 * screen is how the two drift.
 */
function openSubmissions() {
  router.push({
    name: 'teacher.tutoring2.submissions',
    query: { activity_id: activityId.value },
  });
}

function backToList() {
  router.push({ name: 'teacher.tutoring2.activities' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.activityDetail.title')"
      :meta="metaText"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="1"
      :empty-title="t('tutoring2.tutor.activityDetail.notFound')"
      :empty-description="t('tutoring2.tutor.activityDetail.notFoundHint')"
      @retry="reload"
    >
      <template #default>
        <template v-if="activity">
          <div
            data-testid="activity-detail-card"
            class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-3"
          >
            <div class="flex items-center gap-2 flex-wrap">
              <StatusBadge :label="kindText" tone="info" uppercase />
              <StatusBadge
                :label="isPublished ? t('tutoring2.status.published') : t('tutoring2.status.draft')"
                :tone="isPublished ? 'success' : 'neutral'"
                uppercase
              />
            </div>

            <h2
              data-testid="activity-detail-title"
              class="text-base font-bold text-slate-900"
            >
              {{ activity.title }}
            </h2>

            <dl class="divide-y divide-slate-100 border-t border-slate-100 pt-3 text-sm">
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.group') }}</dt>
                <!-- Name, not id — the same ladder the list rows and the
                     session detail use, so a row and the detail it opens
                     cannot disagree about what the group is called. -->
                <dd data-testid="activity-detail-group" class="flex-1 truncate text-slate-900">
                  {{ bimbelGroupLabel(activity, t('tutoring2.common.group')) }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.program') }}</dt>
                <dd data-testid="activity-detail-program" class="flex-1 truncate text-slate-900">
                  {{ bimbelProgramLabel(activity, t('tutoring2.common.program')) }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.dueDate') }}</dt>
                <dd data-testid="activity-detail-due" class="flex-1 text-slate-900">{{ formatDate(activity.due_at) }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.maxScore') }}</dt>
                <dd data-testid="activity-detail-max-points" class="flex-1 text-slate-900">{{ activity.max_points ?? '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.publication') }}</dt>
                <dd data-testid="activity-detail-published" class="flex-1 text-slate-900">
                  {{ isPublished
                    ? formatDateTime(activity.published_at)
                    : t('tutoring2.tutor.activityDetail.notPublishedYet') }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.tutor.activityDetail.submissionsLabel') }}</dt>
                <dd data-testid="activity-detail-submissions" class="flex-1 text-slate-900">
                  {{ t('tutoring2.tutor.activities.submissionsCount', { n: activity.submissions_count ?? 0 }) }}
                </dd>
              </div>
            </dl>
          </div>

          <!-- The description. This is the field the list row never
               renders, and the whole reason a tutor opens the screen. -->
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-2">
            <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">
              {{ t('tutoring2.common.description') }}
            </p>
            <article
              v-if="descriptionHtml"
              data-testid="activity-detail-description"
              class="rpp-prose text-sm text-slate-700 leading-relaxed"
              v-html="descriptionHtml"
            ></article>
            <p
              v-else
              data-testid="activity-detail-description-empty"
              class="text-sm italic text-slate-400"
            >
              {{ t('tutoring2.tutor.activityDetail.noDescription') }}
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <Button
              variant="primary"
              data-testid="activity-open-submissions"
              @click="openSubmissions"
            >
              <NavIcon name="inbox" :size="16" />
              <span class="ml-1">{{ t('tutoring2.tutor.activities.gradeCta') }}</span>
            </Button>
            <Button
              variant="secondary"
              data-testid="activity-back-to-list"
              @click="backToList"
            >
              {{ t('tutoring2.common.back') }}
            </Button>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
