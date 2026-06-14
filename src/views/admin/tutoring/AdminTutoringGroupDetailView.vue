<!--
  AdminTutoringGroupDetailView — admin lens on one kelompok with 4
  tabs: Siswa (default), Sesi, Tugas, Performa. Mockup
  admin_web_pages_beranda_groups frame 3.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import type {
  TutoringEnrollee,
  TutoringGroup,
  TutoringSession,
  TutoringActivity,
} from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const groupId = computed(() => String(route.params.groupId || ''));

const tab = ref<'students' | 'sessions' | 'tasks' | 'perf'>('students');
const loading = ref(true);
const group = ref<TutoringGroup | null>(null);
const enrollees = ref<TutoringEnrollee[]>([]);
const sessions = ref<TutoringSession[]>([]);
const activities = ref<TutoringActivity[]>([]);

async function load() {
  const gid = groupId.value;
  if (!gid) { loading.value = false; return; }
  loading.value = true;
  const now = new Date();
  const from = new Date(now.getTime() - 30 * 86_400_000);
  try {
    const [allGroups, enrs, sess, acts] = await Promise.all([
      TutoringService.getAllGroups().catch(() => []),
      TutoringService.getGroupEnrollees(gid).catch(() => []),
      TutoringService.getAllSessions(from, now).catch(() => []),
      TutoringService.getActivities({ group_id: gid }).catch(() => []),
    ]);
    group.value = (allGroups as TutoringGroup[]).find((g) => g.id === gid) ?? null;
    enrollees.value = enrs as TutoringEnrollee[];
    sessions.value = (sess as TutoringSession[]).filter((s) => s.group_id === gid);
    activities.value = acts as TutoringActivity[];
  } finally { loading.value = false; }
}
onMounted(load);
watch(groupId, load);

const heroStats = computed(() => {
  const sessDone = sessions.value.filter((s) => s.status === 'DONE').length;
  return [
    { label: 'SISWA', value: String(enrollees.value.length) },
    { label: 'SESI 30H', value: String(sessions.value.length), hint: `${sessDone} DONE` },
    { label: 'TUGAS', value: String(activities.value.length) },
  ];
});

function whenLabel(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleString('id-ID', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-[13px] text-bimbel-text-mid hover:text-bimbel-text-hi"
      @click="router.push({ name: 'admin.tutoring.groups' })"
    >
      <NavIcon name="chevron-left" :size="13" /> Kembali ke daftar kelompok
    </button>

    <TutorBerandaHero
      greeting="KELOMPOK"
      :title="group?.name ?? 'Memuat…'"
      :subtitle="group ? [group.tutor?.name ? `Tutor: ${group.tutor.name}` : 'Belum ada tutor', `${group.enrollments_count ?? 0} / ${group.capacity} siswa`].join(' · ') : undefined"
      :stats="heroStats"
    >
      <template #actions>
        <button class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[13px] font-bold text-white"><NavIcon name="edit" :size="12" class="inline -mt-0.5" /> Edit</button>
        <button class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[13px] font-bold"><NavIcon name="plus" :size="12" class="inline -mt-0.5" /> Tambah siswa</button>
      </template>
    </TutorBerandaHero>

    <div class="flex gap-1 rounded-xl border border-bimbel-border-soft bg-bimbel-panel p-1 max-w-md">
      <button
        v-for="t in ['students', 'sessions', 'tasks', 'perf'] as const"
        :key="t"
        type="button"
        class="flex-1 rounded-lg px-3 py-1.5 text-[13px] font-bold tracking-tight transition"
        :class="tab === t ? 'bg-bimbel-accent text-white' : 'text-bimbel-text-mid hover:text-bimbel-text-hi'"
        @click="tab = t"
      >
        {{ t === 'students' ? 'Siswa' : t === 'sessions' ? 'Sesi' : t === 'tasks' ? 'Tugas' : 'Performa' }}
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <template v-else>
      <template v-if="tab === 'students'">
        <div v-if="enrollees.length === 0" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
          Belum ada siswa terdaftar.
        </div>
        <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel overflow-hidden">
          <table class="w-full text-[14px]">
            <thead class="bg-bimbel-bg/40">
              <tr class="text-left text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">
                <th class="px-3 py-2">Siswa</th>
                <th class="px-3 py-2 w-[120px]">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="e in enrollees" :key="e.id" class="border-t border-bimbel-border-soft">
                <td class="px-3 py-2.5 font-bold text-bimbel-text-hi">{{ e.student?.name ?? '—' }}</td>
                <td class="px-3 py-2.5"><span class="inline-flex rounded-full bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 px-2 py-0.5 text-[12px] font-bold">Aktif</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>

      <template v-else-if="tab === 'sessions'">
        <div v-if="sessions.length === 0" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
          Belum ada sesi.
        </div>
        <div v-else class="space-y-2">
          <div v-for="s in sessions" :key="s.id" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3">
            <div class="flex items-center justify-between text-[12px] text-bimbel-text-mid">
              <span>{{ whenLabel(s.scheduled_at) }} · {{ s.duration_minutes }}m</span>
              <span class="rounded-full px-2 py-0.5 text-[12px] font-bold" :class="s.status === 'DONE' ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300' : 'bg-bimbel-accent-dim text-bimbel-accent'">{{ s.status_label ?? s.status }}</span>
            </div>
            <p class="mt-1 text-[14px] font-bold text-bimbel-text-hi">{{ s.topic ?? 'Sesi terjadwal' }}</p>
          </div>
        </div>
      </template>

      <template v-else-if="tab === 'tasks'">
        <div v-if="activities.length === 0" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
          Belum ada tugas.
        </div>
        <div v-else class="space-y-2">
          <div v-for="a in activities" :key="a.id" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3 flex items-center gap-3">
            <NavIcon :name="a.type === 'EXAM' ? 'check-circle' : a.type === 'QUIZ' ? 'sparkles' : 'book'" :size="20" class="text-bimbel-accent" />
            <div class="flex-1 min-w-0">
              <p class="text-[14px] font-bold text-bimbel-text-hi truncate">{{ a.title }}</p>
              <p class="text-[12px] text-bimbel-text-mid">{{ a.type_label ?? a.type }} · {{ a.submissions_count ?? 0 }} pengumpulan</p>
            </div>
          </div>
        </div>
      </template>

      <template v-else>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
          Performa kelompok — laporan terbuka di menu Laporan.
        </div>
      </template>
    </template>
  </div>
</template>
