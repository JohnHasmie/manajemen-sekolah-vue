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
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

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
useAcademicYearWatcher(reload);

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
                <dd class="flex-1 truncate text-slate-900">{{ t('tutoring2.common.group') }} {{ session.learning_group_id.slice(0, 8) }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.room') }}</dt>
                <dd class="flex-1 text-slate-900">{{ session.room ?? '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.tutor') }}</dt>
                <dd class="flex-1 truncate text-slate-900">{{ session.tutor_id ?? '—' }}</dd>
              </div>
              <div v-if="session.tutor_note" class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">{{ t('tutoring2.common.notes') }}</dt>
                <dd class="flex-1 text-slate-900">{{ session.tutor_note }}</dd>
              </div>
            </dl>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <Button variant="primary" @click="ambilPresensi">{{ t('tutoring2.common.takeAttendance') }}</Button>
            <Button variant="secondary" @click="rescheduleAction">{{ t('tutoring2.common.reschedule') }}</Button>
            <Button
              v-if="session.status === 'in_progress'"
              variant="success"
              @click="completeSession"
            >
              {{ t('tutoring2.common.markDone') }}
            </Button>
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
