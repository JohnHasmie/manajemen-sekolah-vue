<!--
  TutorTutoring2CreateSessionView.vue — schedule ONE off-cycle bimbel
  session for a learning group (CLEAN-2 Phase 2 · greenfield replacement
  for `teacher/tutoring/TutorCreateSessionView.vue`).

  Route: /teacher/tutoring2/sessions/new
  Endpoints:
    GET  /tutoring-v2/learning-groups   — the group picker
    POST /tutoring-v2/sessions          — create the session

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. TIME MODEL. v1 posted `scheduled_at` + `duration_minutes`. v2's
     StoreSessionRequest wants an explicit `starts_at` / `ends_at`
     pair (`ends_at` must be strictly after `starts_at`). The duration
     dropdown is kept as the *input* affordance because that is what
     tutors think in, but it is converted to `ends_at` here.

  2. NO UTC ROUND-TRIP. v1 sent `new Date(...).toISOString()`, which
     shifts a WIB tutor's 15:00 into 08:00Z and — combined with the
     backend's `strtotime()` on a server in another zone — could land
     the session on the previous day. We send a naive local
     `YYYY-MM-DD HH:MM:SS` string instead, which is exactly the shape
     CreateRecurringSessionsAction already writes, so one-off and
     recurring sessions store identically.

  3. DROPPED FIELDS: `meeting_url` and `topic`. Neither exists on the
     greenfield `bimbel_sessions` table nor in StoreSessionRequest —
     posting them would be silently discarded, and rendering the
     inputs would promise persistence we cannot deliver. The closest
     surviving field is `materials_note`, offered below on its own
     terms (it is NOT a rename of `topic`). Restoring the pair needs a
     backend migration + StoreSessionRequest rule first.

  4. `tutor_id` is deliberately NOT sent. CreateSessionAction defaults
     it to the learning group's own tutor, which is the right answer
     for a tutor scheduling their own class; sending the caller's id
     would need a `teachers.id` resolver the client does not have.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { toLocalYmd } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

// ─── Group picker ─────────────────────────────────────────────────
//
// Scope note: `LearningGroupController::index` accepts an optional
// `?tutor_id=` but does NOT auto-scope to the caller, and no v2 route
// hands the client its own `teachers.id`. So, exactly like the sibling
// tutor views (Activities, GroupAnnouncements), we list the active
// groups the caller is allowed to see and let them pick. See V2_GAPS.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listGroups({
    per_page: 100,
    status: 'active',
  });
  return items;
});

const groups = computed<BimbelLearningGroup[]>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as BimbelLearningGroup[] | undefined) ?? [])
    : [],
);

// ─── Form state ───────────────────────────────────────────────────
const learningGroupId = ref('');
const date = ref<string>(toLocalYmd()); // local today, never toISOString()
const startTime = ref('15:00'); // HH:MM
const durationMinutes = ref(90);
const room = ref('');
const materialsNote = ref('');
const saving = ref(false);

const DURATION_OPTIONS = [60, 90, 120, 150];

/** `YYYY-MM-DD` + `HH:MM` → a Date built from LOCAL parts. */
function toLocalDate(ymd: string, hhmm: string): Date | null {
  const [y, m, d] = ymd.split('-').map(Number);
  const [hh, mi] = hhmm.split(':').map(Number);
  if (!y || !m || !d || Number.isNaN(hh) || Number.isNaN(mi)) return null;
  return new Date(y, m - 1, d, hh, mi, 0, 0);
}

/** Date → naive `YYYY-MM-DD HH:MM:SS` in LOCAL time (no Z suffix). */
function toWireDateTime(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return (
    `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ` +
    `${p(d.getHours())}:${p(d.getMinutes())}:00`
  );
}

/** Preview of the computed end time, e.g. "16:30". */
const endTimePreview = computed<string>(() => {
  const start = toLocalDate(date.value, startTime.value);
  if (!start) return '—';
  const end = new Date(start.getTime() + durationMinutes.value * 60_000);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(end.getHours())}:${p(end.getMinutes())}`;
});

async function submit() {
  if (saving.value) return;
  if (!learningGroupId.value) {
    toast.error(t('tutoring2.tutor.createSession.errPickGroup'));
    return;
  }
  const start = toLocalDate(date.value, startTime.value);
  if (!start) {
    toast.error(t('tutoring2.tutor.createSession.errPickDate'));
    return;
  }
  const end = new Date(start.getTime() + durationMinutes.value * 60_000);

  saving.value = true;
  try {
    await TutoringBimbelService.createSession({
      learning_group_id: learningGroupId.value,
      starts_at: toWireDateTime(start),
      ends_at: toWireDateTime(end),
      room: room.value.trim() || null,
      materials_note: materialsNote.value.trim() || null,
    });
    toast.success(t('tutoring2.tutor.createSession.created'));
    router.push({ name: 'teacher.tutoring2.sessions' });
  } catch (e) {
    toast.error((e as Error).message || t('tutoring2.tutor.createSession.createFailed'));
  } finally {
    saving.value = false;
  }
}

const fieldLabelCls = 'text-xs font-bold text-slate-600 uppercase tracking-wider';
const inputCls =
  'w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20';
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.createSession.title')"
      :meta="t('tutoring2.tutor.createSession.meta')"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.tutor.createSession.emptyTitle')"
      :empty-description="t('tutoring2.tutor.createSession.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <form
          class="rounded-3xl border border-slate-100 bg-white shadow-sm p-5 space-y-4"
          @submit.prevent="submit"
        >
          <div class="space-y-1.5">
            <label for="session-group" :class="fieldLabelCls">
              {{ t('tutoring2.common.group') }}
            </label>
            <select id="session-group" v-model="learningGroupId" :class="inputCls">
              <option value="" disabled>
                {{ t('tutoring2.tutor.createSession.pickGroup') }}
              </option>
              <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
            </select>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div class="space-y-1.5">
              <label for="session-date" :class="fieldLabelCls">
                {{ t('tutoring2.common.date') }}
              </label>
              <input id="session-date" v-model="date" type="date" :class="inputCls" />
            </div>
            <div class="space-y-1.5">
              <label for="session-time" :class="fieldLabelCls">
                {{ t('tutoring2.common.time') }}
              </label>
              <input id="session-time" v-model="startTime" type="time" :class="inputCls" />
            </div>
            <div class="space-y-1.5">
              <label for="session-duration" :class="fieldLabelCls">
                {{ t('tutoring2.tutor.createSession.duration') }}
              </label>
              <select id="session-duration" v-model.number="durationMinutes" :class="inputCls">
                <option v-for="d in DURATION_OPTIONS" :key="d" :value="d">
                  {{ t('tutoring2.tutor.createSession.durationOption', { minutes: d }) }}
                </option>
              </select>
            </div>
          </div>

          <!-- v2 stores an explicit ends_at, so show the tutor what we
               are about to derive from duration. -->
          <p class="text-2xs text-slate-500">
            {{ t('tutoring2.tutor.createSession.endsAtHint', { time: endTimePreview }) }}
          </p>

          <div class="space-y-1.5">
            <label for="session-room" :class="fieldLabelCls">
              {{ t('tutoring2.common.room') }}
            </label>
            <input id="session-room" v-model="room" type="text" maxlength="64" :class="inputCls" />
          </div>

          <div class="space-y-1.5">
            <label for="session-materials" :class="fieldLabelCls">
              {{ t('tutoring2.tutor.createSession.materialsNote') }}
            </label>
            <textarea
              id="session-materials"
              v-model="materialsNote"
              rows="3"
              maxlength="4000"
              :class="inputCls"
            />
            <p class="text-2xs text-slate-500">
              {{ t('tutoring2.tutor.createSession.materialsNoteHint') }}
            </p>
          </div>

          <div class="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
            <Button variant="secondary" size="md" type="button" @click="router.back()">
              {{ t('tutoring2.common.cancel') }}
            </Button>
            <Button variant="primary" size="md" type="submit" :loading="saving">
              {{ t('tutoring2.common.save') }}
            </Button>
          </div>
        </form>
      </template>
    </AsyncView>
  </div>
</template>
