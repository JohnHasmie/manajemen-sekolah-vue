<!--
  TutorRecurringSessionsView — bulk-create sessions on a weekday
  template. Same flow as the Flutter screen.

  Server-side action wraps everything in a transaction and skips
  exact (group, scheduled_at) duplicates so re-runs are safe.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringGroup } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const groups = ref<TutoringGroup[]>([]);
const groupId = ref('');
const weekdays = ref<Set<number>>(new Set([1, 3])); // Mon + Wed default
const startDate = ref<string>(isoToday(1));
const endDate = ref<string>(isoToday(60));
const time = ref<string>('16:00');
const duration = ref<number>(90);
const room = ref('');
const meetingUrl = ref('');
const topic = ref('');

const saving = ref(false);
const result = ref<{ created: number; skipped: number } | null>(null);

function isoToday(offset: number): string {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

onMounted(async () => {
  try {
    groups.value = await TutoringService.getAllGroups();
    if (groups.value[0]) groupId.value = groups.value[0].id;
  } catch {/* non-fatal */}
});

function toggleDay(d: number) {
  if (weekdays.value.has(d)) weekdays.value.delete(d);
  else weekdays.value.add(d);
  // Trigger reactivity (Set mutation).
  weekdays.value = new Set(weekdays.value);
}

// Naive client-side preview (server may skip duplicates).
const previewCount = computed(() => {
  if (weekdays.value.size === 0) return 0;
  const start = new Date(startDate.value);
  const end = new Date(endDate.value);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0;
  let n = 0;
  const cursor = new Date(start);
  while (cursor <= end) {
    // ISO weekday: Mon=1..Sun=7 (cursor.getDay() is Sun=0..Sat=6).
    const iso = ((cursor.getDay() + 6) % 7) + 1;
    if (weekdays.value.has(iso)) n++;
    cursor.setDate(cursor.getDate() + 1);
  }
  return n;
});

async function submit() {
  if (!groupId.value) {
    toast.error(t('tutor.bimbel.recurring_sessions.err_pick_group'));
    return;
  }
  if (weekdays.value.size === 0) {
    toast.error(t('tutor.bimbel.recurring_sessions.err_pick_day'));
    return;
  }
  saving.value = true;
  result.value = null;
  try {
    const res = await TutoringService.generateRecurringSessions({
      group_id: groupId.value,
      weekdays: [...weekdays.value].sort(),
      start_date: startDate.value,
      end_date: endDate.value,
      time: time.value,
      duration_minutes: duration.value,
      room: room.value.trim() || undefined,
      meeting_url: meetingUrl.value.trim() || undefined,
      topic: topic.value.trim() || undefined,
    });
    result.value = res;
    toast.success(t('tutor.bimbel.recurring_sessions.toast_created', { count: res.created }));
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutor.bimbel.recurring_sessions.err_generate_failed'));
  } finally {
    saving.value = false;
  }
}

const DAYS = computed<{ iso: number; label: string }[]>(() => [
  { iso: 1, label: t('tutor.bimbel.recurring_sessions.day_mon') },
  { iso: 2, label: t('tutor.bimbel.recurring_sessions.day_tue') },
  { iso: 3, label: t('tutor.bimbel.recurring_sessions.day_wed') },
  { iso: 4, label: t('tutor.bimbel.recurring_sessions.day_thu') },
  { iso: 5, label: t('tutor.bimbel.recurring_sessions.day_fri') },
  { iso: 6, label: t('tutor.bimbel.recurring_sessions.day_sat') },
  { iso: 7, label: t('tutor.bimbel.recurring_sessions.day_sun') },
]);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutor.bimbel.recurring_sessions.kicker')"
      :title="t('tutor.bimbel.recurring_sessions.title')"
      :meta="t('tutor.bimbel.recurring_sessions.meta')"
    />

    <div class="space-y-3 bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 sm:p-5">
      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('tutor.bimbel.recurring_sessions.field_group') }}
        </span>
        <select
          v-model="groupId"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        >
          <option value="" disabled>{{ t('tutor.bimbel.recurring_sessions.field_group_placeholder') }}</option>
          <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
        </select>
      </label>

      <div>
        <p class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider mb-2">
          {{ t('tutor.bimbel.recurring_sessions.field_days') }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="d in DAYS"
            :key="d.iso"
            type="button"
            class="rounded-lg px-3.5 py-1.5 text-xs font-bold border transition"
            :class="weekdays.has(d.iso)
              ? 'bg-role-teacher border-role-teacher text-white'
              : 'bg-tutoring-panel border-tutoring-border text-tutoring-text-mid hover:border-tutoring-accent/50'"
            @click="toggleDay(d.iso)"
          >
            {{ d.label }}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.recurring_sessions.field_start') }}
          </span>
          <input
            v-model="startDate"
            type="date"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.recurring_sessions.field_end') }}
          </span>
          <input
            v-model="endDate"
            type="date"
            :min="startDate"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.recurring_sessions.field_time') }}
          </span>
          <input
            v-model="time"
            type="time"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.recurring_sessions.field_duration') }}
          </span>
          <select
            v-model.number="duration"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option :value="60">60 {{ t('tutor.bimbel.recurring_sessions.duration_minutes_suffix') }}</option>
            <option :value="90">90 {{ t('tutor.bimbel.recurring_sessions.duration_minutes_suffix') }}</option>
            <option :value="120">120 {{ t('tutor.bimbel.recurring_sessions.duration_minutes_suffix') }}</option>
            <option :value="150">150 {{ t('tutor.bimbel.recurring_sessions.duration_minutes_suffix') }}</option>
          </select>
        </label>
      </div>

      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('tutor.bimbel.recurring_sessions.field_room') }}
        </span>
        <input
          v-model="room"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        />
      </label>

      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('tutor.bimbel.recurring_sessions.field_meeting_url') }}
        </span>
        <input
          v-model="meetingUrl"
          type="url"
          placeholder="https://zoom.us/j/…"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        />
      </label>

      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('tutor.bimbel.recurring_sessions.field_topic') }}
        </span>
        <input
          v-model="topic"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        />
      </label>

      <div
        v-if="result"
        class="rounded-xl bg-tutoring-green-soft border border-status-success/30 p-3 text-sm font-bold text-tutoring-green flex items-center gap-2"
      >
        <NavIcon name="check-circle" :size="16" />
        {{ t('tutor.bimbel.recurring_sessions.result_sessions_created', { count: result.created }) }}<span v-if="result.skipped > 0">, {{ t('tutor.bimbel.recurring_sessions.result_skipped_suffix', { count: result.skipped }) }}</span>.
      </div>

      <div class="flex items-center gap-2 justify-end pt-2">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
          @click="router.back"
        >
          {{ t('tutoring.common.close') }}
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submit"
        >
          {{ saving ? t('tutoring.common.saving') : t('tutor.bimbel.recurring_sessions.submit_n', { count: previewCount }) }}
        </button>
      </div>
    </div>
  </div>
</template>
