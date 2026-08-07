<!--
  TutorTutoring2RecurringSessionsView.vue — generate a weekly-recurring
  series of bimbel sessions (CLEAN-2 Phase 2 · greenfield replacement
  for `teacher/tutoring/TutorRecurringSessionsView.vue`).

  Route: /teacher/tutoring2/sessions/recurring
  Endpoints:
    GET  /tutoring-v2/learning-groups     — the group picker
    POST /tutoring-v2/sessions/recurring  — fan out the series

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. PAYLOAD RESHAPE. v1 posted to `/tutoring/sessions/generate-recurring`
     with `{group_id, weekdays, start_date, end_date, time,
     duration_minutes, room, meeting_url, topic}`. v2's
     StoreRecurringSessionsRequest wants
     `{learning_group_id, weekdays, start_time, end_time, from_date,
     to_date, room?, materials_note?}` — note the from/to naming, and
     that duration is expressed as an explicit `end_time`. The duration
     dropdown survives as an input affordance and is converted below.

  2. NO DEDUPLICATION. v1's action skipped exact
     (group, scheduled_at) duplicates, so the response carried a
     `skipped` count and re-running the form was safe.
     CreateRecurringSessionsAction does NOT dedupe — it creates a row
     for every matching day, unconditionally, and returns the created
     sessions. Re-submitting the same range therefore DOUBLES the
     sessions. The "skipped" line is gone (there is nothing to report)
     and a warning replaces it. Do not fake a skipped count.

  3. DROPPED: SERIES MANAGEMENT. v1 had a whole
     `/tutoring/session-series` surface (index / show / PATCH update /
     POST cancel) for editing or cancelling an existing series after
     the fact. v2 stamps a shared `series_key` on every spawned row but
     exposes NO series routes — only per-session
     `/sessions/{id}/{reschedule,cancel}`. So this view can create a
     series but not list, edit, or bulk-cancel one; the tutor cancels
     the individual sessions from the session list instead. Restoring
     it needs backend routes on `series_key` first (see V2_GAPS).

  4. DROPPED FIELDS: `meeting_url` and `topic` — same reason as the
     one-off create view: no column, no validation rule, no silent
     persistence. `materials_note` is offered on its own terms.

  5. Weekday numbers are ISO (1 = Mon … 7 = Sun) on BOTH sides, so the
     v1 mapping carries over unchanged.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
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
// Same scope caveat as TutorTutoring2CreateSessionView: the v2 group
// index has no server-side tutor auto-scope and no route hands the
// client its own `teachers.id`. See V2_GAPS.
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

/** Local `YYYY-MM-DD`, `offsetDays` from today. Never toISOString(). */
function localYmdOffset(offsetDays: number): string {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return toLocalYmd(d);
}

const learningGroupId = ref('');
// Plain array (not a Set) so Vue reactivity needs no manual re-seat.
const weekdays = ref<number[]>([1, 3]); // Mon + Wed, matching v1's default
const fromDate = ref<string>(localYmdOffset(1));
const toDate = ref<string>(localYmdOffset(60));
const startTime = ref('16:00');
const durationMinutes = ref(90);
const room = ref('');
const materialsNote = ref('');

const saving = ref(false);
/** Number of sessions the last successful submit actually created. */
const createdCount = ref<number | null>(null);

const DURATION_OPTIONS = [60, 90, 120, 150];

const WEEKDAYS = computed<Array<{ iso: number; label: string }>>(() => [
  { iso: 1, label: t('tutoring2.tutor.recurringSessions.dayMon') },
  { iso: 2, label: t('tutoring2.tutor.recurringSessions.dayTue') },
  { iso: 3, label: t('tutoring2.tutor.recurringSessions.dayWed') },
  { iso: 4, label: t('tutoring2.tutor.recurringSessions.dayThu') },
  { iso: 5, label: t('tutoring2.tutor.recurringSessions.dayFri') },
  { iso: 6, label: t('tutoring2.tutor.recurringSessions.daySat') },
  { iso: 7, label: t('tutoring2.tutor.recurringSessions.daySun') },
]);

function toggleDay(iso: number) {
  const i = weekdays.value.indexOf(iso);
  if (i === -1) weekdays.value = [...weekdays.value, iso].sort((a, b) => a - b);
  else weekdays.value = weekdays.value.filter((d) => d !== iso);
}

/** `YYYY-MM-DD` → Date built from LOCAL parts (`new Date(str)` is UTC). */
function parseLocalYmd(ymd: string): Date | null {
  const [y, m, d] = ymd.split('-').map(Number);
  if (!y || !m || !d) return null;
  return new Date(y, m - 1, d, 0, 0, 0, 0);
}

/** `HH:MM` → minutes since midnight, or null when malformed. */
function toMinutes(hhmm: string): number | null {
  const [hh, mi] = hhmm.split(':').map(Number);
  if (Number.isNaN(hh) || Number.isNaN(mi)) return null;
  return hh * 60 + mi;
}

/**
 * `end_time` derived from start + duration. Null when the pair would
 * cross midnight — CreateRecurringSessionsAction validates
 * `end_time > start_time` on the same calendar day, so an overnight
 * series is simply not expressible in v2.
 */
const endTime = computed<string | null>(() => {
  const start = toMinutes(startTime.value);
  if (start == null) return null;
  const end = start + durationMinutes.value;
  if (end >= 24 * 60) return null;
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(Math.floor(end / 60))}:${p(end % 60)}`;
});

/**
 * How many sessions the range will produce. Unlike v1 this is EXACT,
 * not a lower bound: v2 never skips duplicates, so every matching day
 * becomes a row.
 */
const previewCount = computed<number>(() => {
  if (weekdays.value.length === 0) return 0;
  const start = parseLocalYmd(fromDate.value);
  const end = parseLocalYmd(toDate.value);
  if (!start || !end || end < start) return 0;
  let n = 0;
  const cursor = new Date(start.getTime());
  while (cursor <= end) {
    // ISO weekday: Mon=1..Sun=7 (getDay() is Sun=0..Sat=6).
    const iso = ((cursor.getDay() + 6) % 7) + 1;
    if (weekdays.value.includes(iso)) n += 1;
    cursor.setDate(cursor.getDate() + 1);
  }
  return n;
});

async function submit() {
  if (saving.value) return;
  if (!learningGroupId.value) {
    toast.error(t('tutoring2.tutor.recurringSessions.errPickGroup'));
    return;
  }
  if (weekdays.value.length === 0) {
    toast.error(t('tutoring2.tutor.recurringSessions.errPickDay'));
    return;
  }
  const end = endTime.value;
  if (!end) {
    toast.error(t('tutoring2.tutor.recurringSessions.errOvernight'));
    return;
  }
  const start = parseLocalYmd(fromDate.value);
  const finish = parseLocalYmd(toDate.value);
  if (!start || !finish || finish < start) {
    toast.error(t('tutoring2.tutor.recurringSessions.errRange'));
    return;
  }

  saving.value = true;
  createdCount.value = null;
  try {
    const sessions = await TutoringBimbelService.createRecurringSessions({
      learning_group_id: learningGroupId.value,
      weekdays: [...weekdays.value].sort((a, b) => a - b),
      start_time: startTime.value,
      end_time: end,
      from_date: fromDate.value,
      to_date: toDate.value,
      room: room.value.trim() || null,
      materials_note: materialsNote.value.trim() || null,
    });
    // The endpoint returns the created rows themselves — the count is
    // their length, not a server-reported tally.
    createdCount.value = sessions.length;
    toast.success(
      t('tutoring2.tutor.recurringSessions.created', { count: sessions.length }),
    );
  } catch (e) {
    toast.error(
      (e as Error).message || t('tutoring2.tutor.recurringSessions.createFailed'),
    );
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
      :title="t('tutoring2.tutor.recurringSessions.title')"
      :meta="t('tutoring2.tutor.recurringSessions.meta')"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.tutor.recurringSessions.emptyTitle')"
      :empty-description="t('tutoring2.tutor.recurringSessions.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <form
          class="rounded-3xl border border-slate-100 bg-white shadow-sm p-5 space-y-4"
          @submit.prevent="submit"
        >
          <div class="space-y-1.5">
            <label for="recurring-group" :class="fieldLabelCls">
              {{ t('tutoring2.common.group') }}
            </label>
            <select id="recurring-group" v-model="learningGroupId" :class="inputCls">
              <option value="" disabled>
                {{ t('tutoring2.tutor.recurringSessions.pickGroup') }}
              </option>
              <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
            </select>
          </div>

          <div class="space-y-1.5">
            <p :class="fieldLabelCls">{{ t('tutoring2.tutor.recurringSessions.days') }}</p>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="d in WEEKDAYS"
                :key="d.iso"
                type="button"
                class="rounded-lg px-3.5 py-1.5 text-xs font-bold border transition-colors"
                :class="
                  weekdays.includes(d.iso)
                    ? 'bg-brand-cobalt border-brand-cobalt text-white'
                    : 'bg-white border-slate-200 text-slate-500 hover:border-brand-cobalt/50'
                "
                :aria-pressed="weekdays.includes(d.iso)"
                @click="toggleDay(d.iso)"
              >
                {{ d.label }}
              </button>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div class="space-y-1.5">
              <label for="recurring-from" :class="fieldLabelCls">
                {{ t('tutoring2.common.startDate') }}
              </label>
              <input id="recurring-from" v-model="fromDate" type="date" :class="inputCls" />
            </div>
            <div class="space-y-1.5">
              <label for="recurring-to" :class="fieldLabelCls">
                {{ t('tutoring2.common.endDate') }}
              </label>
              <input
                id="recurring-to"
                v-model="toDate"
                type="date"
                :min="fromDate"
                :class="inputCls"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div class="space-y-1.5">
              <label for="recurring-time" :class="fieldLabelCls">
                {{ t('tutoring2.common.time') }}
              </label>
              <input id="recurring-time" v-model="startTime" type="time" :class="inputCls" />
            </div>
            <div class="space-y-1.5">
              <label for="recurring-duration" :class="fieldLabelCls">
                {{ t('tutoring2.tutor.recurringSessions.duration') }}
              </label>
              <select id="recurring-duration" v-model.number="durationMinutes" :class="inputCls">
                <option v-for="d in DURATION_OPTIONS" :key="d" :value="d">
                  {{ t('tutoring2.tutor.recurringSessions.durationOption', { minutes: d }) }}
                </option>
              </select>
            </div>
          </div>

          <p class="text-2xs text-slate-500">
            <template v-if="endTime">
              {{ t('tutoring2.tutor.recurringSessions.endsAtHint', { time: endTime }) }}
            </template>
            <template v-else>
              {{ t('tutoring2.tutor.recurringSessions.errOvernight') }}
            </template>
          </p>

          <div class="space-y-1.5">
            <label for="recurring-room" :class="fieldLabelCls">
              {{ t('tutoring2.common.room') }}
            </label>
            <input
              id="recurring-room"
              v-model="room"
              type="text"
              maxlength="64"
              :class="inputCls"
            />
          </div>

          <div class="space-y-1.5">
            <label for="recurring-materials" :class="fieldLabelCls">
              {{ t('tutoring2.tutor.recurringSessions.materialsNote') }}
            </label>
            <textarea
              id="recurring-materials"
              v-model="materialsNote"
              rows="3"
              maxlength="4000"
              :class="inputCls"
            />
          </div>

          <!-- v2 does not deduplicate: re-submitting the same range
               creates a second full set of sessions. Say so plainly
               rather than shipping a "skipped: 0" line that would
               imply a guard that no longer exists. -->
          <div
            class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-2xs text-amber-800"
          >
            <NavIcon name="alert-triangle" :size="14" />
            <span>{{ t('tutoring2.tutor.recurringSessions.noDedupeWarning') }}</span>
          </div>

          <div
            v-if="createdCount !== null"
            class="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm font-bold text-emerald-700"
          >
            <NavIcon name="check-circle" :size="16" />
            {{ t('tutoring2.tutor.recurringSessions.created', { count: createdCount }) }}
          </div>

          <div class="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
            <Button variant="secondary" size="md" type="button" @click="router.back()">
              {{ t('tutoring2.common.cancel') }}
            </Button>
            <Button variant="primary" size="md" type="submit" :loading="saving">
              {{ t('tutoring2.tutor.recurringSessions.submit', { count: previewCount }) }}
            </Button>
          </div>
        </form>
      </template>
    </AsyncView>
  </div>
</template>
