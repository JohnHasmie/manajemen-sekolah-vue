<!--
  TutorClassDetailView — single kelompok detail page with 3 tabs:

    - Aliran : chronological feed (recent sessions DONE + announcements
               + activities created), most recent first.
    - Tugas  : list of activities (HOMEWORK / QUIZ / EXAM / PROJECT)
               filtered by this group_id. Click → submissions page.
    - Siswa  : enrollee roster.

  Mirrors mobile `TutorClassDetailScreen` (Aliran / Tugas / Siswa tabs).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import type {
  TutoringActivity,
  TutoringEnrollee,
  TutoringGroup,
  TutoringSession,
  TutoringGroupAnnouncement,
} from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import TutorActivityRow from '@/components/feature/tutoring/TutorActivityRow.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

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
        ? `${a.type_label} · ${a.submissions_count ?? 0} pengumpulan`
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
      title: s.topic || 'Sesi selesai',
      subtitle: s.room ? `Ruang ${s.room}` : undefined,
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
    <TutorBerandaHero
      :greeting="group?.tutor?.name ? `Tutor: ${group.tutor.name}` : 'Kelas'"
      :title="group?.name ?? 'Memuat…'"
      :subtitle="
        group
          ? [
              group.enrollments_count != null
                ? `${group.enrollments_count} siswa`
                : null,
              group.capacity ? `kapasitas ${group.capacity}` : null,
            ]
              .filter(Boolean)
              .join(' · ')
          : undefined
      "
      :stats="[
        { label: 'Tugas', value: String(activities.length) },
        {
          label: 'Sesi 30h',
          value: String(sessions.length),
          hint: `${sessions.filter((s) => s.status === 'DONE').length} DONE`,
        },
        { label: 'Pengumuman', value: String(announcements.length) },
      ]"
    />

    <div class="flex items-center gap-2 rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-1.5">
      <button
        v-for="t in ['aliran', 'tugas', 'siswa'] as const"
        :key="t"
        type="button"
        class="flex-1 rounded-xl px-3 py-2 text-[12.5px] font-bold tracking-tight capitalize transition"
        :class="
          tab === t
            ? 'bg-bimbel-accent text-white shadow'
            : 'text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="tab = t"
      >
        {{ t === 'aliran' ? 'Aliran' : t === 'tugas' ? 'Tugas' : 'Siswa' }}
      </button>
    </div>

    <div v-if="loading" class="py-16 text-center text-bimbel-text-mid">
      Memuat…
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
        class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
      >
        Belum ada aktivitas di kelas ini.
      </p>
    </template>

    <!-- Tugas -->
    <template v-else-if="tab === 'tugas'">
      <TutoringSectionHeader
        title="Daftar tugas"
        action-label="Tambah"
        @action="goCreateActivity"
      />
      <div v-if="activities.length" class="space-y-2">
        <TutoringListTile
          v-for="a in activities"
          :key="a.id"
          icon="check-circle"
          accent="tutor"
          :title="a.title"
          :subtitle="[a.type_label, `${a.submissions_count ?? 0} pengumpulan`].filter(Boolean).join(' · ')"
          :to="() => router.push({ name: 'teacher.tutoring.activity-submissions', params: { activityId: a.id } })"
        />
      </div>
      <p
        v-else
        class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
      >
        Belum ada tugas — ketuk Tambah untuk membuat satu.
      </p>
    </template>

    <!-- Siswa -->
    <template v-else>
      <div v-if="enrollees.length" class="grid gap-2 sm:grid-cols-2">
        <div
          v-for="e in enrollees"
          :key="e.id"
          class="flex items-center gap-3 rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3"
        >
          <span class="grid h-10 w-10 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent">
            <NavIcon name="user" :size="18" />
          </span>
          <span class="min-w-0">
            <span class="block truncate text-[13px] font-bold text-bimbel-text-hi">
              {{ e.student?.name || '—' }}
            </span>
            <span class="block text-[11px] text-bimbel-text-mid">aktif</span>
          </span>
        </div>
      </div>
      <p
        v-else
        class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
      >
        Belum ada siswa terdaftar.
      </p>
    </template>
  </div>
</template>
