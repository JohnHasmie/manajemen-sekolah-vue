<!--
  TutorTutoring2SessionDetailView.vue — single bimbel session detail (WEB-4).

  Composition:
    1. BrandPageHeader     — role="teacher".
    2. AsyncView           — state machine.
       Default slot renders one info panel + button row.
    3. No KPIs, no filter toolbar, no floating CTA.

  Data path: `TutoringBimbelService.listSessions({})` filtered client-
  side to `s.id === route.params.id`. TODO: promote to a dedicated
  `getSession(id)` when the service gains it (matches the pattern the
  other tutoring-v2 endpoints already use).
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
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import { bimbelGroupLabel, bimbelTutorLabel } from '@/lib/bimbel-session-label';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const sessionId = computed<string>(() => String(route.params.id));

// TODO: swap for `TutoringBimbelService.getSession(id)` once the
// service exposes a single-fetch endpoint. For now we page through
// `listSessions` and filter client-side — matches the interim
// contract the admin views use.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({ per_page: 100 });
  const match = items.find((s) => s.id === sessionId.value);
  return match ?? null;
});

const session = computed<BimbelSession | null>(() => {
  return state.value.status === 'content' ? (state.value.data as BimbelSession) : null;
});

/**
 * ── Who may move or close a session ──
 *
 * `SessionController::reschedule` and `::complete` both open with
 * `$this->authorize('tutoring.session.manage')`.
 * `PermissionCatalog::tutorTutoringDefaults()` does NOT grant that key —
 * a tutor gets `tutoring.session.view` + `tutoring.session.mark_attendance`,
 * and the lifecycle keys live in `adminTutoringDefaults()`. So on a
 * default bimbel tenant BOTH buttons below were a guaranteed 403, and
 * Reschedule was the worse of the two: it had no condition at all, so
 * the tutor filled in the whole date/time/room form before the server
 * refused it.
 *
 * Read off the /me snapshot via `useMe().can` (which the backend scopes
 * to the active role through `X-Active-Role`) — NEVER
 * `roles[].permission_keys`, which is unscoped and exists only for the
 * role switcher.
 *
 * Disabled, not deleted. The permission catalog is a SEED, not a
 * ceiling: a tenant that grants `tutoring.session.manage` to its tutor
 * role through the RBAC picker gets both buttons back with no code
 * change — the same reasoning !1217 recorded for the two session-write
 * ROUTES, and the shape the mobile app takes for its own copy of this
 * row in !1220 (still unmerged at the time of writing, so there is no
 * path on `main` to cite yet). Hiding them instead would make the row
 * silently differ between two tutors at the same centre with nothing on
 * screen to explain why.
 *
 * "Ambil presensi" is deliberately untouched: it posts to
 * `SessionController::markAttendance`, which authorizes on
 * `tutoring.session.mark_attendance` — a key every tutor really does
 * hold.
 */
const { can } = useMe();
const canManageSession = computed(() => can('tutoring.session.manage'));

/**
 * Why Reschedule refuses, or `null` when it works.
 *
 * The status half mirrors `RescheduleSessionAction` exactly, which
 * refuses `DONE` and `CANCELLED` and nothing else — it is not a rule
 * invented here. It is also knowable BEFORE the form opens, unlike
 * "ends_at must follow starts_at", which depends on what the tutor
 * types and therefore still travels back as a 422 (see
 * `submitReschedule`). Duplicating only the state rule keeps the two
 * from drifting on the part that can drift.
 */
const rescheduleBlockedReason = computed<string | null>(() => {
  if (!canManageSession.value) {
    return t('tutoring2.tutor.sessionDetail.noManageAbility');
  }
  const s = session.value;
  if (s && (s.status === 'done' || s.status === 'cancelled')) {
    return t('tutoring2.tutor.sessionDetail.rescheduleClosed');
  }
  return null;
});

/**
 * Why "Tandai selesai" refuses, or `null` when it works.
 *
 * The ability gate is ADDITIONAL to the `v-if` on the button: a tutor
 * whose tenant granted the key still may not close a session that is
 * not running. That half of the original condition was always correct.
 *
 * Deliberately ability-ONLY: the status half stays on the `v-if`, so
 * nothing in this computed would notice if that `v-if` were dropped.
 * The gate spec pins it separately — see the "status rule for Tandai
 * selesai, held by the v-if not by the ability" block.
 */
const completeBlockedReason = computed<string | null>(() =>
  canManageSession.value ? null : t('tutoring2.tutor.sessionDetail.noManageAbility'),
);

/**
 * The reason lines printed under the row, de-duplicated.
 *
 * A default tutor blocks both buttons for the same reason, and printing
 * the same "peran Anda belum diberi izin" line twice reads as a
 * rendering bug rather than an explanation. Only reasons for controls
 * that are actually on screen are listed — "Tandai selesai" is absent
 * unless the session is running.
 */
const actionNotices = computed<string[]>(() => {
  const shown = [rescheduleBlockedReason.value];
  if (session.value?.status === 'in_progress') {
    shown.push(completeBlockedReason.value);
  }
  return [...new Set(shown.filter((r): r is string => r !== null))];
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

// Map backend status snake_case to the tutoring2.status.* camelCase keys.
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

function ambilPresensi() {
  router.push({
    name: 'teacher.tutoring2.attendance',
    params: { sessionId: sessionId.value },
  });
}

/**
 * Reschedule.
 *
 * `POST /tutoring-v2/sessions/{id}/reschedule` shipped with BE-4 and had
 * no caller: this button was `toast.info('Belum tersedia')` for as long
 * as it existed, next to two siblings that worked.
 *
 * The form is prefilled from the session so the common case — nudging a
 * class by half an hour — is two edits, not four. `datetime-local`
 * yields a LOCAL wall-clock string with no zone, which is what the
 * backend's `date` validation expects and what a tutor means when they
 * say 16:00; sending an ISO instant here would shift every session by
 * the UTC offset.
 */
const rescheduleOpen = ref(false);
const rescheduleSaving = ref(false);
const rescheduleForm = ref({ starts_at: '', ends_at: '', room: '' });

/** `2026-07-18T09:00:00+07:00` → `2026-07-18T09:00`, in LOCAL time. */
function toLocalInput(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    `T${pad(d.getHours())}:${pad(d.getMinutes())}`
  );
}

function rescheduleAction() {
  const s = session.value;
  if (!s) return;
  // Also refused here, not only on the button. The dialog below is a
  // SIBLING of the AsyncView branch that owns the button, so it is not
  // covered by the button's own condition; keeping the check next to
  // the only writer of `rescheduleOpen` is what actually keeps the form
  // shut for a caller the server would refuse.
  if (rescheduleBlockedReason.value) return;
  rescheduleForm.value = {
    starts_at: toLocalInput(s.starts_at),
    ends_at: toLocalInput(s.ends_at),
    room: s.room ?? '',
  };
  rescheduleOpen.value = true;
}

async function submitReschedule() {
  if (rescheduleSaving.value) return;
  const f = rescheduleForm.value;
  if (!f.starts_at || !f.ends_at) return;

  rescheduleSaving.value = true;
  try {
    await TutoringBimbelService.rescheduleSession(sessionId.value, {
      starts_at: f.starts_at.replace('T', ' '),
      ends_at: f.ends_at.replace('T', ' '),
      room: f.room.trim() || null,
    });
    rescheduleOpen.value = false;
    toast.success(t('tutoring2.tutor.sessionDetail.rescheduled'));
    await reload();
  } catch (e) {
    // The backend owns the rules (ends after starts, not on a cancelled
    // session) and returns them as a 422 message. Surfacing it verbatim
    // beats re-implementing the checks here and letting the two drift.
    toast.error((e as Error).message || t('tutoring2.tutor.sessionDetail.rescheduleFailed'));
  } finally {
    rescheduleSaving.value = false;
  }
}

async function completeSession() {
  if (completeBlockedReason.value) return;
  try {
    await TutoringBimbelService.completeSession(sessionId.value);
    toast.success(t('tutoring2.tutor.sessionDetail.completed'));
    await reload();
  } catch (e) {
    toast.error((e as Error).message || t('tutoring2.tutor.sessionDetail.completeFailed'));
  }
}

const metaText = computed(() =>
  session.value ? formatDateTime(session.value.starts_at) : t('tutoring2.common.loading'),
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.sessionDetail.title')"
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
                <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.status') }}</p>
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
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.time') }}</dt>
                <dd class="flex-1 text-slate-900">{{ formatTimeRange(session.starts_at, session.ends_at) }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.group') }}</dt>
                <!-- Name, not id — same helper the session LIST rows
                     use, so a row and the detail it opens cannot
                     disagree about what the group is called. -->
                <dd class="flex-1 truncate text-slate-900">{{ bimbelGroupLabel(session, t('tutoring2.common.group')) }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.room') }}</dt>
                <dd class="flex-1 text-slate-900">{{ session.room ?? '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.tutor') }}</dt>
                <dd class="flex-1 truncate text-slate-900">{{ bimbelTutorLabel(session, t('tutoring2.common.tutor')) }}</dd>
              </div>
              <div v-if="session.tutor_note" class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.notes') }}</dt>
                <dd class="flex-1 text-slate-900">{{ session.tutor_note }}</dd>
              </div>
            </dl>
          </div>

          <!-- Blocked controls stay rendered and keep their label, with
               the reason on `title` for a pointer and on an
               `aria-describedby` line for a screen reader, which never
               sees a tooltip. Same four properties the admin bimbel
               CTAs are held to. -->
          <div class="flex flex-wrap items-center gap-2">
            <Button
              variant="primary"
              data-testid="session-take-attendance"
              @click="ambilPresensi"
            >
              {{ t('tutoring2.common.takeAttendance') }}
            </Button>
            <Button
              variant="secondary"
              data-testid="session-reschedule"
              :disabled="rescheduleBlockedReason !== null"
              :title="rescheduleBlockedReason ?? undefined"
              :aria-describedby="rescheduleBlockedReason ? 'session-action-notice' : undefined"
              @click="rescheduleAction"
            >
              {{ t('tutoring2.common.reschedule') }}
            </Button>
            <Button
              v-if="session.status === 'in_progress'"
              variant="success"
              data-testid="session-complete"
              :disabled="completeBlockedReason !== null"
              :title="completeBlockedReason ?? undefined"
              :aria-describedby="completeBlockedReason ? 'session-action-notice' : undefined"
              @click="completeSession"
            >
              {{ t('tutoring2.common.markDone') }}
            </Button>
          </div>

          <div
            v-if="actionNotices.length"
            id="session-action-notice"
            data-testid="session-action-notice"
            class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-xs text-amber-800"
          >
            <span aria-hidden="true">&#9432;</span>
            <div class="space-y-1">
              <p v-for="reason in actionNotices" :key="reason">{{ reason }}</p>
            </div>
          </div>
        </template>
      </template>
    </AsyncView>

    <Modal
      v-if="rescheduleOpen"
      size="md"
      :title="t('tutoring2.common.reschedule')"
      @close="rescheduleOpen = false"
    >
      <div class="space-y-md">
        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.tutor.sessionDetail.startsAt') }}
          </span>
          <input
            v-model="rescheduleForm.starts_at"
            type="datetime-local"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>
        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.tutor.sessionDetail.endsAt') }}
          </span>
          <input
            v-model="rescheduleForm.ends_at"
            type="datetime-local"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>
        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.common.room') }}
          </span>
          <input
            v-model="rescheduleForm.room"
            type="text"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>
      </div>

      <!-- Modal has one slot; actions go inline, the way every other
           dialog on this surface does it. -->
      <BottomSheetFooter
        :primary-label="t('tutoring2.common.save')"
        :secondary-label="t('tutoring2.common.cancel')"
        :primary-loading="rescheduleSaving"
        :primary-disabled="!rescheduleForm.starts_at || !rescheduleForm.ends_at"
        @primary="submitReschedule"
        @secondary="rescheduleOpen = false"
      />
    </Modal>
  </div>
</template>
