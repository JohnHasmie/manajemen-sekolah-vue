<!--
  TutorClassDetailView — single group detail page with 3 tabs:

    - Aliran : chronological feed (recent sessions DONE + announcements
               + activities created), most recent first.
    - Tugas  : list of activities (HOMEWORK / QUIZ / EXAM / PROJECT)
               filtered by this group_id. Click → submissions page.
    - Student  : enrollee roster.

  Mirrors mobile `TutorClassDetailScreen` (Aliran / Tugas / Student tabs).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type {
  TutoringActivity,
  TutoringEnrollee,
  TutoringGroup,
  TutoringSession,
  TutoringGroupAnnouncement,
} from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import TutorActivityRow from '@/components/feature/tutoring/TutorActivityRow.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const groupId = computed(() => String(route.params.groupId || ''));

const tab = ref<'aliran' | 'tugas' | 'siswa'>('aliran');
const loading = ref(true);

const group = ref<TutoringGroup | null>(null);
const activities = ref<TutoringActivity[]>([]);
const enrollees = ref<TutoringEnrollee[]>([]);
const announcements = ref<TutoringGroupAnnouncement[]>([]);
const sessions = ref<TutoringSession[]>([]);

async function load() {
  loading.value = true;
  const now = new Date();
  const from = new Date(now.getTime() - 30 * 86_400_000);
  try {
    const [groups, acts, enrs, anns, sesi] = await Promise.all([
      TutoringService.getAllGroups().catch(() => [] as TutoringGroup[]),
      TutoringService.getActivities({ group_id: groupId.value }).catch(
        () => [] as TutoringActivity[],
      ),
      TutoringService.getGroupEnrollees(groupId.value).catch(
        () => [] as TutoringEnrollee[],
      ),
      TutoringService.getGroupAnnouncements({ group_id: groupId.value }).catch(
        () => [] as TutoringGroupAnnouncement[],
      ),
      TutoringService.getAllSessions(from, now).catch(
        () => [] as TutoringSession[],
      ),
    ]);
    group.value = groups.find((g) => g.id === groupId.value) ?? null;
    activities.value = acts;
    enrollees.value = enrs;
    announcements.value = anns;
    sessions.value = sesi.filter((s) => s.group_id === groupId.value);
  } finally {
    loading.value = false;
  }
}
onMounted(load);

// ── Aliran: merge activities + announcements + DONE sessions ──────
interface FeedEntry {
  type: string;
  occurred_at: string | null;
  title: string;
  subtitle?: string | null;
  onClick?: () => void;
}

const aliran = computed<FeedEntry[]>(() => {
  const rows: FeedEntry[] = [];
  for (const a of activities.value) {
    rows.push({
      type: 'new_submission',
      occurred_at: a.created_at ?? null,
      title: a.title,
      subtitle: a.type_label
        ? `${a.type_label} · ${a.submissions_count ?? 0} ${t('tutor.bimbel.class_detail.submissions_suffix')}`
        : undefined,
      onClick: () =>
        router.push({
          name: 'teacher.tutoring.activity-submissions',
          params: { activityId: a.id },
        }),
    });
  }
  for (const ann of announcements.value) {
    rows.push({
      type: 'announcement_posted',
      occurred_at: ann.created_at ?? null,
      title: ann.title,
      subtitle: ann.body?.slice(0, 80),
    });
  }
  for (const s of sessions.value) {
    if (s.status !== 'DONE') continue;
    rows.push({
      type: 'session_done',
      occurred_at: s.scheduled_at,
      title: s.topic || t('tutor.bimbel.class_detail.session_done_default_title'),
      subtitle: s.room ? `${t('tutor.bimbel.class_detail.room_prefix')} ${s.room}` : undefined,
    });
  }
  return rows
    .filter((r) => r.occurred_at != null)
    .sort(
      (a, b) =>
        new Date(b.occurred_at!).valueOf() - new Date(a.occurred_at!).valueOf(),
    );
});

function goCreateActivity() {
  router.push({ name: 'teacher.tutoring.activities' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="group?.tutor?.name ? `${t('tutor.bimbel.class_detail.greeting_tutor_prefix')}: ${group.tutor.name}` : t('tutor.bimbel.class_detail.greeting_class')"
      :title="group?.name ?? t('tutor.bimbel.class_detail.loading_title')"
      :subtitle="
        group
          ? [
              group.enrollments_count != null
                ? `${group.enrollments_count} ${t('tutor.bimbel.class_detail.meta_students_suffix')}`
                : null,
              group.capacity ? `${t('tutor.bimbel.class_detail.meta_capacity_prefix')} ${group.capacity}` : null,
            ]
              .filter(Boolean)
              .join(' · ')
          : undefined
      "
      :stats="[
        { label: t('tutor.bimbel.class_detail.stat_tasks'), value: String(activities.length) },
        {
          label: t('tutor.bimbel.class_detail.stat_sessions_30d'),
          value: String(sessions.length),
          hint: `${sessions.filter((s) => s.status === 'DONE').length} ${t('tutor.bimbel.class_detail.stat_done_suffix')}`,
        },
        { label: t('tutor.bimbel.class_detail.stat_announcements'), value: String(announcements.length) },
      ]"
    />

    <div class="flex items-center gap-2 rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-1.5">
      <button
        v-for="tabKey in ['aliran', 'tugas', 'siswa'] as const"
        :key="tabKey"
        type="button"
        class="flex-1 rounded-xl px-3 py-2 text-[13px] font-bold tracking-tight capitalize transition"
        :class="
          tab === tabKey
            ? 'bg-tutoring-accent text-white shadow'
            : 'text-tutoring-text-mid hover:text-tutoring-text-hi'
        "
        @click="tab = tabKey"
      >
        {{ tabKey === 'aliran' ? t('tutor.bimbel.class_detail.tab_aliran') : tabKey === 'tugas' ? t('tutor.bimbel.class_detail.tab_tugas') : t('tutor.bimbel.class_detail.tab_siswa') }}
      </button>
    </div>

    <div v-if="loading" class="py-16 text-center text-tutoring-text-mid">
      {{ t('tutor.bimbel.class_detail.loading') }}
    </div>

    <!-- Aliran -->
    <template v-else-if="tab === 'aliran'">
      <div v-if="aliran.length" class="space-y-2">
        <TutorActivityRow
          v-for="(e, i) in aliran"
          :key="i"
          :type="e.type"
          :title="e.title"
          :subtitle="e.subtitle"
          :occurred-at="e.occurred_at"
          @click="e.onClick && e.onClick()"
        />
      </div>
      <p
        v-else
        class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid"
      >
        {{ t('tutor.bimbel.class_detail.aliran_empty') }}
      </p>
    </template>

    <!-- Tugas -->
    <template v-else-if="tab === 'tugas'">
      <TutoringSectionHeader
        :title="t('tutor.bimbel.class_detail.tugas_heading')"
        :action-label="t('tutor.bimbel.class_detail.tugas_action_add')"
        @action="goCreateActivity"
      />
      <div v-if="activities.length" class="space-y-2">
        <TutoringListTile
          v-for="a in activities"
          :key="a.id"
          icon="check-circle"
          accent="tutor"
          :title="a.title"
          :subtitle="[a.type_label, `${a.submissions_count ?? 0} ${t('tutor.bimbel.class_detail.submissions_suffix')}`].filter(Boolean).join(' · ')"
          :to="() => router.push({ name: 'teacher.tutoring.activity-submissions', params: { activityId: a.id } })"
        />
      </div>
      <p
        v-else
        class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid"
      >
        {{ t('tutor.bimbel.class_detail.tugas_empty') }}
      </p>
    </template>

    <!-- Student -->
    <template v-else>
      <div v-if="enrollees.length" class="grid gap-2 sm:grid-cols-2">
        <div
          v-for="e in enrollees"
          :key="e.id"
          class="flex items-center gap-3 rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3"
        >
          <span class="grid h-10 w-10 place-items-center rounded-full bg-tutoring-accent-dim text-tutoring-accent">
            <NavIcon name="user" :size="18" />
          </span>
          <span class="min-w-0">
            <span class="block truncate text-[14px] font-bold text-tutoring-text-hi">
              {{ e.student?.name || t('tutor.bimbel.class_detail.student_dash') }}
            </span>
            <span class="block text-[12px] text-tutoring-text-mid">{{ t('tutor.bimbel.class_detail.student_active') }}</span>
          </span>
        </div>
      </div>
      <p
        v-else
        class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid"
      >
        {{ t('tutor.bimbel.class_detail.siswa_empty') }}
      </p>
    </template>
  </div>
</template>
