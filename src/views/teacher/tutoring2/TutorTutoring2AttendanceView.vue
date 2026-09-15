<!--
  TutorTutoring2AttendanceView.vue — Presensi per sesi (WEB-4 exemplar).

  Wraps the WEB-2 `TutoringAttendanceRoster` component end-to-end.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringAttendanceRoster from '@/components/tutoring/TutoringAttendanceRoster.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { AttendanceStatus } from '@/types/attendance';
import type { TutoringAttendanceRow } from '@/types/tutoring-bimbel';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();
const { can } = useMe();

const sessionId = ref<string>((route.params.sessionId as string) ?? '');
if (!sessionId.value) {
  router.replace({ name: 'teacher.tutoring2.sessions' });
}

const rows = ref<TutoringAttendanceRow[]>([]);
const search = ref('');
const filterMode = ref<'all' | 'unmarked'>('all');
const saving = ref(false);

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessionAttendance(sessionId.value);
  return items;
});

watch(state, (s) => {
  if (s.status === 'content' || s.status === 'empty') {
    rows.value = (s as { status: string; data?: TutoringAttendanceRow[] }).data ?? [];
  }
});

function onUpdateRow(payload: { enrollment_id: string; status: AttendanceStatus; notes?: string }) {
  const idx = rows.value.findIndex((r) => r.enrollment_id === payload.enrollment_id);
  if (idx >= 0) {
    rows.value[idx] = { ...rows.value[idx], status: payload.status, notes: payload.notes };
  }
}

/**
 * Whether this role may close the session as well as mark it.
 *
 * `SessionController::complete` opens with
 * `$this->authorize('tutoring.session.manage')`, and
 * `PermissionCatalog::tutorTutoringDefaults()` grants a tutor only
 * `tutoring.session.view` + `tutoring.session.mark_attendance`. Posting
 * to `/complete` without the key is a guaranteed 403, so the button must
 * not promise it. The catalog is a SEED, not a ceiling — a tenant that
 * grants the key through the RBAC picker gets the second half back with
 * no code change, which is why this is a live check and not a constant.
 *
 * Read via `useMe().can`, i.e. the `/me` abilities scoped by
 * `X-Active-Role`, never the unscoped `roles[].permission_keys`.
 */
const canCompleteSession = computed(() => can('tutoring.session.manage'));

/** Why the button will not close the session, or `null` when it will. */
const completeNotice = computed<string | null>(() =>
  canCompleteSession.value ? null : t('tutoring2.tutor.sessionDetail.noManageAbility'),
);

/**
 * Save the marks, then close the session.
 *
 * ── Why this order, and not the reverse ──
 *
 * The two calls are independent — `CompleteSessionAction` has no
 * attendance precondition; its only refusal is a CANCELLED session — so
 * the backend does not force an order. The choice is about which
 * half-finished state is survivable.
 *
 *   save → complete : a failed complete leaves the marks stored and the
 *                     session still open. Nothing is lost and the tutor
 *                     can retry; `complete` is idempotent, so the retry
 *                     is safe.
 *   complete → save : a failed save leaves a session reading "Selesai"
 *                     with no attendance behind it. Per
 *                     `bimbel-session-status.ts`, `done` is the basis
 *                     for tutor honor, so that state actively lies and
 *                     the tutor's real work is the part that vanished.
 *
 * Saving first also pre-empts `complete`'s one precondition for free: a
 * cancelled session is refused by `MarkAttendanceAction` too, so the
 * save fails first and carries the backend's own message — `complete`
 * is never reached and never contributes a second, confusing error.
 *
 * Re-entry is guarded by `saving` (and the button's own `:disabled`);
 * `complete` is idempotent besides, so a double submit could at worst
 * re-close an already-closed session.
 */
async function onSave() {
  if (saving.value) return;
  saving.value = true;
  const marked = rows.value
    .filter((r) => r.status !== null)
    .map((r) => ({
      enrollment_id: r.enrollment_id,
      status: r.status as string,
      notes: r.notes,
    }));

  try {
    await TutoringBimbelService.markSessionAttendance(sessionId.value, marked);
  } catch (e) {
    // Nothing was written; the plain "gagal menyimpan" message is true.
    toast.error(t('tutoring2.tutor.attendance.saveFailed', { msg: (e as Error).message }));
    saving.value = false;
    return;
  }

  // The marks are safely stored from here on. Every message below must
  // say so, because "gagal" alone would read as "your marks are gone".
  if (!canCompleteSession.value) {
    toast.success(t('tutoring2.tutor.attendance.saved', { count: marked.length }));
    saving.value = false;
    reload();
    return;
  }

  try {
    await TutoringBimbelService.completeSession(sessionId.value);
    toast.success(t('tutoring2.tutor.attendance.savedAndCompleted', { count: marked.length }));
  } catch (e) {
    toast.error(
      t('tutoring2.tutor.attendance.savedNotCompleted', {
        count: marked.length,
        msg: (e as Error).message,
      }),
    );
  } finally {
    saving.value = false;
    reload();
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.attendance.title')"
      :meta="t('tutoring2.tutor.attendance.meta', { count: rows.length })"
    />

    <AsyncView :state="state" loading-variant="list" :loading-rows="6" :empty-title="t('tutoring2.tutor.attendance.emptyTitle')" @retry="reload">
      <template #default>
        <TutoringAttendanceRoster
          :rows="rows"
          :session-id="sessionId"
          :loading="state.status === 'loading'"
          :saving="saving"
          :can-complete="canCompleteSession"
          :complete-notice="completeNotice"
          :search="search"
          :filter-mode="filterMode"
          @update:row="onUpdateRow"
          @save="onSave"
          @update:search="(v) => (search = v)"
          @update:filter-mode="(v) => (filterMode = v)"
        />
      </template>
    </AsyncView>
  </div>
</template>
