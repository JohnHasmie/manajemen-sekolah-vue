<!--
  AdminTutoring2SessionDetailView.vue — one bimbel session, for admin.

  Fills the gap reported from prod: "pada website di halaman sesi, list
  sesinya belum ada detail sesi dan edit sesi". The server side was
  complete the whole time — `GET /sessions/{id}` and
  `PUT /sessions/{id}` shipped with BE-4 and had no web caller.

  Composition, matching AdminTutoring2TutorDetailView (the admin
  detail exemplar):

    1. `BrandPageHeader` — role="admin".
    2. `AsyncView` over `TutoringBimbelService.getSession`.
       Default slot renders one info panel + an action row.
    3. An edit dialog in a `<Modal>`. No KPIs, no filter toolbar.

  ── Detail is a ROUTE, the edit form is a MODAL ──

  Both halves follow what this section already does rather than
  inventing a third shape. `admin.tutoring2.tutor.detail` and
  `admin.tutoring2.program.detail` are full routes; every admin bimbel
  EDIT form (`AdminTutoring2GroupCreateSheet`,
  `AdminTutoring2ProgramCreateSheet`,
  `AdminTutoring2StudentCreateEditSheet`,
  `AdminTutoring2InviteTutorModal`) is a sheet or modal over its list or
  detail. A route also gives the detail a shareable URL — an admin
  chasing "which session was this?" can paste it — and it is what the
  tutor's own session detail already is, so the two roles stay
  navigationally symmetric.

  ── The scope of "edit" ──

  Schedule, room and notes. NOT the learning group and NOT the tutor,
  which is a product decision rather than a technical limit: attendance
  is recorded against a session, so moving its group would silently
  re-point marks that were taken for a different set of students.
  `tutor_id` is refused all the way down in the service — see
  `BimbelSessionUpdatePayload`.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import {
  bimbelSessionStatusLabel,
  bimbelSessionStatusTone,
} from '@/lib/bimbel-session-status';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelSession,
  type BimbelSessionUpdatePayload,
} from '@/services/tutoring-bimbel.service';
import { bimbelGroupLabel, bimbelTutorLabel } from '@/lib/bimbel-session-label';
import { localDateTimeInputToWire, toLocalDateTimeInput } from '@/lib/local-date';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const sessionId = computed<string>(() => String(route.params.id));

/**
 * One fetch, one session. Not `listSessions({ per_page: 100 })` filtered
 * client-side, which is what the tutor twin had to do before the service
 * gained a `show` wrapper: that form silently fails for session 101 on a
 * busy centre, and it cannot see `attendances_count`, which only the
 * single-session endpoint counts.
 */
const { state, reload } = useDataRefresh(async () =>
  TutoringBimbelService.getSession(sessionId.value),
);

const session = computed<BimbelSession | null>(() =>
  state.value.status === 'content' ? (state.value.data as BimbelSession) : null,
);

// ── Who may edit ────────────────────────────────────────────────────
//
// `SessionController::update` and `::reschedule` both open with
// `$this->authorize('tutoring.session.manage')`. Read off the /me
// snapshot via `useMe().can`, which the backend scopes to the active
// role through `X-Active-Role` — NEVER `roles[].permission_keys`, which
// is unscoped and exists only for the role switcher.
//
// Disabled with a reason, not deleted: the permission catalog is a SEED,
// not a ceiling, so a tenant that grants the key to a staff role through
// the RBAC picker gets the button working with no code change. Same
// shape as the tutor session detail.
const { can } = useMe();
const canManage = computed(() => can('tutoring.session.manage'));

const editBlockedReason = computed<string | null>(() =>
  canManage.value ? null : t('tutoring2.admin.sessionDetail.noManageAbility'),
);

/**
 * Whether the SCHEDULE half of the form may be submitted at all.
 *
 * Mirrors `RescheduleSessionAction`, which refuses `DONE` and
 * `CANCELLED` and nothing else. This is knowable before the form opens,
 * so the two date inputs are disabled rather than letting an admin
 * retype a time only to be refused.
 *
 * Notes stay editable in that state on purpose, and this is the clearest
 * dividend of the two-endpoint split below: writing the wrap-up note on
 * a session that has just been marked done is exactly when a note is
 * most wanted, and `PUT /sessions/{id}` has no status precondition.
 */
const scheduleLocked = computed<boolean>(() => {
  const s = session.value;
  return !!s && (s.status === 'done' || s.status === 'cancelled');
});

// ── Edit form ───────────────────────────────────────────────────────

interface SessionEditForm {
  starts_at: string;
  ends_at: string;
  room: string;
  materials_note: string;
  tutor_note: string;
}

const editOpen = ref(false);
const saving = ref(false);
const form = ref<SessionEditForm>(blankForm());

/**
 * The values the form was OPENED with.
 *
 * Every decision below is a comparison against this snapshot rather
 * than against `session`, so a reload landing mid-edit cannot turn an
 * untouched field into a "change".
 */
const baseline = ref<SessionEditForm>(blankForm());

function blankForm(): SessionEditForm {
  return { starts_at: '', ends_at: '', room: '', materials_note: '', tutor_note: '' };
}

function formFrom(s: BimbelSession): SessionEditForm {
  return {
    // LOCAL wall clock, never `iso.slice(0, 16)` — that hands the admin
    // the UTC instant, so an 08:00 WIB session opens showing 01:00.
    starts_at: toLocalDateTimeInput(s.starts_at),
    ends_at: toLocalDateTimeInput(s.ends_at),
    room: s.room ?? '',
    materials_note: s.materials_note ?? '',
    tutor_note: s.tutor_note ?? '',
  };
}

/**
 * `''` and `null` mean the same thing for a nullable text column, so
 * they must not read as a change. Without this, opening the dialog on a
 * session whose room is `null` and closing it would post `room: ''`.
 */
function normText(v: string): string | null {
  const s = v.trim();
  return s === '' ? null : s;
}

const scheduleChanged = computed(
  () =>
    form.value.starts_at !== baseline.value.starts_at ||
    form.value.ends_at !== baseline.value.ends_at,
);
const roomChanged = computed(
  () => normText(form.value.room) !== normText(baseline.value.room),
);
const materialsNoteChanged = computed(
  () => normText(form.value.materials_note) !== normText(baseline.value.materials_note),
);
const tutorNoteChanged = computed(
  () => normText(form.value.tutor_note) !== normText(baseline.value.tutor_note),
);

const anyChanged = computed(
  () =>
    scheduleChanged.value ||
    roomChanged.value ||
    materialsNoteChanged.value ||
    tutorNoteChanged.value,
);

/**
 * `POST /reschedule` ends with `$session->status = SCHEDULED`,
 * unconditionally. So moving a session that is currently RUNNING also
 * walks its status back to "Terjadwal" — a field the admin never
 * touched, changed as a side effect of touching another one.
 *
 * It cannot be prevented from here (the endpoint has no flag for it),
 * so it is disclosed instead, in the dialog, only in the exact case it
 * applies. Saying nothing would leave an admin to discover it from the
 * status badge afterwards.
 */
const showStatusResetWarning = computed(
  () => scheduleChanged.value && session.value?.status === 'in_progress',
);

function openEdit() {
  const s = session.value;
  // Checked here and not only on the button: the dialog is a SIBLING of
  // the AsyncView branch that owns the button, so the button's own
  // condition does not cover this writer.
  if (!s || editBlockedReason.value) return;
  form.value = formFrom(s);
  baseline.value = formFrom(s);
  editOpen.value = true;
}

/**
 * ── The two-endpoint split, and why only what changed is sent ──
 *
 * One dialog, two endpoints, because the three editable things do not
 * live together:
 *
 *   starts_at / ends_at  →  POST /sessions/{id}/reschedule   (only here)
 *   materials_note /
 *   tutor_note           →  PUT  /sessions/{id}              (only here)
 *   room                 →  accepted by BOTH
 *
 * Each call fires ONLY if its own fields are dirty. That is not a
 * micro-optimisation, it is the correctness requirement:
 *
 *  - Firing reschedule for a notes-only edit would re-stamp `starts_at`
 *    and `ends_at` from the form, and — worse — reset the status of a
 *    running session to `scheduled` (see `showStatusResetWarning`).
 *  - It would also make notes UNEDITABLE on a finished session, because
 *    `RescheduleSessionAction` throws a 422 for `done` and `cancelled`.
 *  - Firing update for a schedule-only edit would re-write notes that
 *    nobody touched.
 *
 * `SessionController::update` copies a key only when
 * `$request->has($k)`, so an omitted key really is left alone in the
 * database — a partial payload is honoured rather than read as null.
 *
 * ── `room` goes to `update`, always, never to reschedule ──
 *
 * It is the one overlapping field. Sending it on whichever call happens
 * to be firing would give one column two writers depending on unrelated
 * state, and when both calls fire the later one would silently clobber
 * the earlier. Pinning it to `update` gives it exactly one writer in
 * every combination. Omitting it from the reschedule payload is safe
 * and verified rather than assumed: `RescheduleSessionAction` guards
 * with `if ($room !== null)`, so a missing room is a no-op there, not a
 * blanking.
 *
 * ── Order: reschedule first ──
 *
 * It is the call with a precondition it can refuse on (`done` /
 * `cancelled`, and `ends_at` after `starts_at`, which depends on what
 * was typed and so cannot be pre-checked). Running it first means a
 * refusal aborts before anything has been written, instead of leaving
 * the notes saved and the time not — which would have reported a
 * partial success as a success.
 */
async function submitEdit() {
  if (saving.value || !anyChanged.value) return;
  const f = form.value;
  if (scheduleChanged.value && (!f.starts_at || !f.ends_at)) return;

  saving.value = true;
  try {
    if (scheduleChanged.value) {
      await TutoringBimbelService.rescheduleSession(sessionId.value, {
        starts_at: localDateTimeInputToWire(f.starts_at),
        ends_at: localDateTimeInputToWire(f.ends_at),
        // `room` deliberately absent — see the docblock above.
      });
    }

    const patch: BimbelSessionUpdatePayload = {};
    if (roomChanged.value) patch.room = normText(f.room);
    if (materialsNoteChanged.value) patch.materials_note = normText(f.materials_note);
    if (tutorNoteChanged.value) patch.tutor_note = normText(f.tutor_note);
    if (Object.keys(patch).length > 0) {
      await TutoringBimbelService.updateSession(sessionId.value, patch);
    }

    editOpen.value = false;
    toast.success(t('tutoring2.admin.sessionDetail.saved'));
    await reload();
  } catch (e) {
    // The backend owns the rules — "ends after starts", "not on a
    // cancelled session" — and returns them as a 422 message. Surfacing
    // it verbatim beats re-implementing them here and letting the two
    // drift.
    toast.error((e as Error).message || t('tutoring2.common.saveFailed'));
  } finally {
    saving.value = false;
  }
}

// ── Display helpers ─────────────────────────────────────────────────

function sessionTone(s: BimbelSession): StatusBadgeTone {
  return bimbelSessionStatusTone(s);
}

/**
 * The status as the reader sees it, Terlewat included.
 *
 * Replaces a local `sessionStatusKey()` snake→camel mapper plus an
 * inline `session.status_label ?? t(...)` in the template: the
 * status_label precedence rule now lives in one module rather than
 * being restated at each of a dozen badges.
 */
function sessionStatusText(s: BimbelSession): string {
  return bimbelSessionStatusLabel(s, t);
}

/**
 * `toLocaleString` renders in the browser's LOCAL zone, which is the
 * point: the wire carries `+07:00` instants and an admin in Jakarta must
 * read back the wall-clock time the session was booked at.
 */
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

function goBack() {
  router.push({ name: 'admin.tutoring2.schedule' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.sessionDetail.title')"
      :meta="metaText"
    />

    <button
      type="button"
      data-testid="session-detail-back"
      class="inline-flex items-center gap-1 text-sm font-bold text-brand-cobalt hover:underline"
      @click="goBack"
    >
      <span aria-hidden="true">&larr;</span> {{ t('tutoring2.common.back') }}
    </button>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="1"
      :empty-title="t('tutoring2.admin.sessionDetail.notFound')"
      :empty-description="t('tutoring2.admin.sessionDetail.notFoundHint')"
      @retry="reload"
    >
      <template #default>
        <template v-if="session">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-3">
            <div>
              <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">
                {{ t('tutoring2.common.status') }}
              </p>
              <div class="mt-1">
                <StatusBadge
                  data-testid="session-detail-status"
                  :label="sessionStatusText(session)"
                  :tone="sessionTone(session)"
                  uppercase
                />
              </div>
            </div>

            <dl class="divide-y divide-slate-100 border-t border-slate-100 pt-3 text-sm">
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.time') }}
                </dt>
                <dd data-testid="session-detail-time" class="flex-1 text-slate-900">
                  {{ formatDateTime(session.starts_at) }}
                  <span class="text-slate-500">
                    ({{ formatTimeRange(session.starts_at, session.ends_at) }})
                  </span>
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.group') }}
                </dt>
                <!-- Name, not id — the same shared ladder the list rows
                     use, so a row and the detail it opens cannot
                     disagree about what the group is called. -->
                <dd data-testid="session-detail-group" class="flex-1 truncate text-slate-900">
                  {{ bimbelGroupLabel(session, t('tutoring2.common.group')) }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.tutor') }}
                </dt>
                <dd data-testid="session-detail-tutor" class="flex-1 truncate text-slate-900">
                  {{ bimbelTutorLabel(session, t('tutoring2.common.tutor')) }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.room') }}
                </dt>
                <dd data-testid="session-detail-room" class="flex-1 text-slate-900">
                  {{ session.room ?? '—' }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.admin.sessionDetail.materialsNote') }}
                </dt>
                <dd data-testid="session-detail-materials-note" class="flex-1 whitespace-pre-line text-slate-900">
                  {{ session.materials_note ?? '—' }}
                </dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.admin.sessionDetail.tutorNote') }}
                </dt>
                <dd data-testid="session-detail-tutor-note" class="flex-1 whitespace-pre-line text-slate-900">
                  {{ session.tutor_note ?? '—' }}
                </dd>
              </div>
            </dl>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <Button
              variant="primary"
              data-testid="session-edit"
              :disabled="editBlockedReason !== null"
              :title="editBlockedReason ?? undefined"
              :aria-describedby="editBlockedReason ? 'session-edit-notice' : undefined"
              @click="openEdit"
            >
              {{ t('tutoring2.admin.sessionDetail.editCta') }}
            </Button>
          </div>

          <div
            v-if="editBlockedReason"
            id="session-edit-notice"
            data-testid="session-edit-notice"
            class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-xs text-amber-800"
          >
            <span aria-hidden="true">&#9432;</span>
            <p>{{ editBlockedReason }}</p>
          </div>
        </template>
      </template>
    </AsyncView>

    <Modal
      v-if="editOpen"
      size="md"
      :title="t('tutoring2.admin.sessionDetail.editTitle')"
      @close="editOpen = false"
    >
      <div class="space-y-md">
        <!-- Schedule. Disabled outright once the session is done or
             cancelled, because `RescheduleSessionAction` refuses both —
             better to say so than to let an admin retype a time and be
             refused. The notes below stay editable in that state. -->
        <p
          v-if="scheduleLocked"
          data-testid="session-edit-schedule-locked"
          class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 text-xs text-slate-600"
        >
          {{ t('tutoring2.admin.sessionDetail.scheduleLocked') }}
        </p>

        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.admin.sessionDetail.startsAt') }}
          </span>
          <input
            v-model="form.starts_at"
            data-testid="session-edit-starts-at"
            type="datetime-local"
            :disabled="scheduleLocked"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-400"
          />
        </label>
        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.admin.sessionDetail.endsAt') }}
          </span>
          <input
            v-model="form.ends_at"
            data-testid="session-edit-ends-at"
            type="datetime-local"
            :disabled="scheduleLocked"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-400"
          />
        </label>

        <!-- Moving a RUNNING session also walks its status back to
             "Terjadwal", server-side and unconditionally. Disclosed
             only in the case it actually applies. -->
        <p
          v-if="showStatusResetWarning"
          data-testid="session-edit-status-reset-warning"
          class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-xs text-amber-800"
        >
          <span aria-hidden="true">&#9432;</span>
          {{ t('tutoring2.admin.sessionDetail.statusResetWarning') }}
        </p>

        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.common.room') }}
          </span>
          <input
            v-model="form.room"
            data-testid="session-edit-room"
            type="text"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>

        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.admin.sessionDetail.materialsNote') }}
          </span>
          <textarea
            v-model="form.materials_note"
            data-testid="session-edit-materials-note"
            rows="3"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>

        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.admin.sessionDetail.tutorNote') }}
          </span>
          <textarea
            v-model="form.tutor_note"
            data-testid="session-edit-tutor-note"
            rows="3"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>
      </div>

      <BottomSheetFooter
        :primary-label="t('tutoring2.common.save')"
        :secondary-label="t('tutoring2.common.cancel')"
        :primary-loading="saving"
        :primary-disabled="!anyChanged"
        @primary="submitEdit"
        @secondary="editOpen = false"
      />
    </Modal>
  </div>
</template>
