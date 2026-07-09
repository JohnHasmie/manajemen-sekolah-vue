<!--
  TutorActivitySubmissionsView — per-activity roster.

  Loads the group's active enrollees + any already-saved submissions,
  merges them (saved status/score wins, otherwise defaults to
  ASSIGNED), and bulk-saves on submit. Backend POST is idempotent.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const STATUS_OPTIONS = computed(() => [
  { key: 'ASSIGNED', label: t('tutor.bimbel.activity_submissions.status_assigned') },
  { key: 'SUBMITTED', label: t('tutor.bimbel.activity_submissions.status_submitted') },
  { key: 'LATE', label: t('tutor.bimbel.activity_submissions.status_late') },
  { key: 'GRADED', label: t('tutor.bimbel.activity_submissions.status_graded') },
  { key: 'MISSED', label: t('tutor.bimbel.activity_submissions.status_missed') },
]);

const activityId = String(route.params.activityId ?? '');
const groupId = String(route.query.groupId ?? '');
const title = String(route.query.title ?? t('tutor.bimbel.activity_submissions.default_title'));
const groupName = String(route.query.groupName ?? '');

const loading = ref(true);
const saving = ref(false);
const error = ref<string | null>(null);

interface Row {
  studentId: string;
  name: string;
  status: string;
  score: string;
}
const rows = reactive<Row[]>([]);

async function load() {
  loading.value = true;
  error.value = null;
  rows.length = 0;
  try {
    const [enrollees, saved] = await Promise.all([
      TutoringService.getGroupEnrollees(groupId),
      TutoringService.getActivitySubmissions(activityId),
    ]);
    const savedBy = new Map<string, typeof saved[number]>();
    for (const s of saved) savedBy.set(s.student_id, s);

    for (const e of enrollees) {
      const sid = e.student_id;
      const s = savedBy.get(sid);
      rows.push({
        studentId: sid,
        name: e.student?.name ?? '—',
        status: s?.status ?? 'ASSIGNED',
        score: s?.score != null ? String(s.score) : '',
      });
    }
    // Include saved rows whose student isn't currently enrolled.
    for (const s of saved) {
      if (!rows.find((r) => r.studentId === s.student_id)) {
        rows.push({
          studentId: s.student_id,
          name: s.student?.name ?? s.student_name ?? '—',
          status: s.status,
          score: s.score != null ? String(s.score) : '',
        });
      }
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e);
  } finally {
    loading.value = false;
  }
}
onMounted(load);

async function save() {
  saving.value = true;
  try {
    const items = rows.map((r) => ({
      student_id: r.studentId,
      status: r.status,
      ...(r.score.trim()
        ? { score: Number.parseFloat(r.score.trim()) }
        : {}),
    }));
    await TutoringService.recordActivitySubmissions(activityId, items);
    toast.success(t('tutor.bimbel.activity_submissions.saved_ok'));
    router.back();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : String(e));
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="space-y-md pb-32">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutor.bimbel.activity_submissions.kicker_prefix') + ' · ' + groupName"
      :title="title"
      :meta="t('tutor.bimbel.activity_submissions.meta_students', { count: rows.length })"
    />

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="error"
      :text="error"
      icon="alert-circle"
    />
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('tutor.bimbel.activity_submissions.no_students')"
      icon="user"
    />
    <template v-else>
      <div class="space-y-2">
        <div
          v-for="r in rows"
          :key="r.studentId"
          class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-3"
        >
          <div class="flex items-center gap-3 mb-2">
            <span class="w-9 h-9 rounded-xl bg-tutoring-accent-dim text-tutoring-accent grid place-items-center flex-shrink-0">
              <NavIcon name="user" :size="18" />
            </span>
            <span class="flex-1 text-sm font-semibold text-tutoring-text-hi">{{ r.name }}</span>
          </div>
          <div class="flex gap-2">
            <select
              v-model="r.status"
              class="flex-1 rounded-lg border border-tutoring-border px-2.5 py-1.5 text-xs font-semibold text-tutoring-text-mid focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            >
              <option v-for="o in STATUS_OPTIONS" :key="o.key" :value="o.key">
                {{ o.label }}
              </option>
            </select>
            <input
              v-model="r.score"
              type="number"
              step="0.1"
              :placeholder="t('tutor.bimbel.activity_submissions.score_placeholder')"
              class="w-24 rounded-lg border border-tutoring-border px-2.5 py-1.5 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            />
          </div>
        </div>
      </div>

      <!-- sticky save bar -->
      <div class="fixed bottom-0 inset-x-0 bg-tutoring-panel border-t border-tutoring-border p-4 z-10">
        <div class="mx-auto max-w-3xl">
          <button
            :disabled="saving"
            class="w-full rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
            @click="save"
          >
            {{ saving ? t('tutoring.common.saving') : t('tutor.bimbel.activity_submissions.save_btn') }}
          </button>
        </div>
      </div>
    </template>
  </div>
</template>
