<!--
  ParentClassDetailView — wali kelas detail. 3 tabs (Aliran / Sesi
  anak / Nilai anak). Mirrors mockup parent_web_pages_main frame 3
  (hero + tab + 2-col layout: feed/sesi/nilai on left, info-kelas
  card on right).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type {
  TutoringFeedEvent,
  TutoringProgress,
  TutoringSession,
  TutoringWaliClassMeta,
} from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import ParentTabBar from '@/components/feature/tutoring/ParentTabBar.vue';
import ParentActivityRow from '@/components/feature/tutoring/ParentActivityRow.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);
const groupId = computed(() => String(route.params.groupId || ''));

const tab = ref<'aliran' | 'sesi' | 'nilai'>('aliran');
const loading = ref(true);
const meta = ref<TutoringWaliClassMeta | null>(null);
const feed = ref<TutoringFeedEvent[]>([]);
const sessions = ref<TutoringSession[]>([]);
const progress = ref<TutoringProgress | null>(null);

async function load() {
  const sid = studentId.value;
  const gid = groupId.value;
  if (!sid || !gid) { loading.value = false; return; }
  loading.value = true;
  const now = new Date();
  const from = new Date(now.getTime() - 60 * 86_400_000);
  const to = new Date(now.getTime() + 30 * 86_400_000);
  try {
    const [allMeta, f, sched, prog] = await Promise.all([
      TutoringService.getWaliClassMeta(sid).catch(() => []),
      TutoringService.getStudentFeed(sid, { limit: 30, sinceDays: 60 }).catch(() => []),
      TutoringService.getSchedule(sid, from, to).catch(() => []),
      TutoringService.getProgress(sid).catch(() => null),
    ]);
    meta.value = (allMeta as TutoringWaliClassMeta[]).find((m) => m.group_id === gid) ?? null;
    feed.value = (f as TutoringFeedEvent[]).filter((e) => {
      const m = e.meta as Record<string, unknown> | undefined;
      return !m || !m.group_id || String(m.group_id) === gid;
    });
    sessions.value = (sched as TutoringSession[]).filter((s) => s.group_id === gid);
    progress.value = prog;
  } finally { loading.value = false; }
}
onMounted(load);
watch([studentId, groupId], load);

const sessionsSorted = computed(() =>
  [...sessions.value].sort((a, b) => {
    const ta = a.scheduled_at ? new Date(a.scheduled_at).valueOf() : 0;
    const tb = b.scheduled_at ? new Date(b.scheduled_at).valueOf() : 0;
    return tb - ta;
  }),
);

const progressEntries = computed(() => progress.value?.timeline ?? []);

function whenLabel(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleString('id-ID', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

const heroStats = computed(() => {
  const m = meta.value;
  return [
    { label: 'KEHADIRAN', value: m?.attendance.rate != null ? `${m.attendance.rate}%` : '–' },
    { label: 'SESI', value: String(sessions.value.length) },
    { label: 'TUGAS BARU', value: String(meta.value?.new_announcements_count_7d ?? 0) },
  ];
});
</script>

<template>
  <div class="space-y-4 pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-[12px] text-bimbel-text-mid hover:text-bimbel-text-hi"
      @click="router.push({ name: 'parent.tutoring.kelas' })"
    >
      <NavIcon name="chevron-left" :size="13" /> Kembali ke daftar kelas
    </button>

    <ParentBerandaHero
      kicker="KELAS"
      :title="meta?.group_name || 'Memuat…'"
      :subtitle="
        meta
          ? [
              meta.program_name,
              meta.tutor_name ? `Tutor: ${meta.tutor_name}` : null,
            ].filter(Boolean).join(' · ')
          : undefined
      "
      :stats="heroStats"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <ParentTabBar
      v-model="tab"
      :tabs="[
        { id: 'aliran', label: 'Aliran' },
        { id: 'sesi', label: 'Sesi anak' },
        { id: 'nilai', label: 'Nilai anak' },
      ]"
      fit
    />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else class="grid gap-3 lg:grid-cols-3">
      <div class="space-y-2 lg:col-span-2">
        <template v-if="tab === 'aliran'">
          <div
            v-if="feed.length === 0"
            class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
          >
            Belum ada aktivitas di kelas ini.
          </div>
          <ParentActivityRow
            v-for="(e, i) in feed"
            :key="i"
            :type="e.type"
            :title="e.title"
            :subtitle="e.subtitle"
            :occurred-at="e.occurred_at"
          />
        </template>

        <template v-else-if="tab === 'sesi'">
          <div
            v-if="sessionsSorted.length === 0"
            class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
          >
            Belum ada sesi di kelas ini.
          </div>
          <div
            v-for="s in sessionsSorted"
            :key="s.id"
            class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3"
          >
            <div class="flex items-center justify-between text-[12px] text-bimbel-text-mid">
              <span>{{ whenLabel(s.scheduled_at) }} · {{ s.duration_minutes }}m</span>
              <span
                class="rounded-full px-2 py-0.5 text-[12px] font-bold"
                :class="
                  s.status === 'DONE'
                    ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300'
                    : s.status === 'CANCELLED'
                    ? 'bg-rose-500/15 text-rose-700 dark:text-rose-300'
                    : 'bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
                "
              >
                {{ s.status_label ?? s.status }}
              </span>
            </div>
            <p class="mt-1 text-[13px] font-bold text-bimbel-text-hi">{{ s.topic || 'Sesi terjadwal' }}</p>
            <p v-if="s.room" class="text-[12px] text-bimbel-text-mid">ruang {{ s.room }}</p>
          </div>
        </template>

        <template v-else>
          <div
            v-if="progressEntries.length === 0"
            class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
          >
            Belum ada nilai tercatat.
          </div>
          <div
            v-for="p in progressEntries"
            :key="p.assessment_id"
            class="flex items-center gap-3 rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3"
          >
            <span class="grid h-9 w-9 place-items-center rounded-xl bg-amber-500/15 text-amber-700 dark:text-amber-300">
              <NavIcon name="star" :size="15" />
            </span>
            <div class="min-w-0 flex-1">
              <p class="truncate text-[13px] font-bold text-bimbel-text-hi">{{ p.title }}</p>
              <p class="truncate text-[12px] text-bimbel-text-mid">
                {{ [p.type_label, p.subject, whenLabel(p.held_at)].filter(Boolean).join(' · ') }}
              </p>
            </div>
            <span class="flex-shrink-0 text-[15px] font-extrabold text-emerald-700 dark:text-emerald-300">
              {{ p.score ?? '–' }}
            </span>
          </div>
        </template>
      </div>

      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 h-fit">
        <h4 class="mb-3 text-[12px] font-bold tracking-tight text-bimbel-text-hi">Info kelas</h4>
        <dl class="space-y-2 text-[12px]">
          <div><dt class="text-bimbel-text-mid">Tutor</dt><dd class="font-bold text-bimbel-text-hi">{{ meta?.tutor_name ?? '—' }}</dd></div>
          <div><dt class="text-bimbel-text-mid">Program</dt><dd class="font-bold text-bimbel-text-hi">{{ meta?.program_name ?? '—' }}</dd></div>
          <div><dt class="text-bimbel-text-mid">Status</dt><dd class="font-bold text-bimbel-text-hi">{{ meta?.status ?? '—' }}</dd></div>
          <div v-if="meta?.attendance.total_recorded">
            <dt class="text-bimbel-text-mid">Kehadiran</dt>
            <dd class="font-bold text-bimbel-text-hi">
              {{ meta.attendance.attended }} dari {{ meta.attendance.total_recorded }} sesi
            </dd>
          </div>
        </dl>
        <div
          v-if="meta?.next_session?.scheduled_at"
          class="mt-3 border-t border-bimbel-border-soft pt-3"
        >
          <p class="text-[12px] text-bimbel-text-mid">Sesi berikutnya</p>
          <p class="mt-0.5 text-[13px] font-bold text-bimbel-text-hi">
            {{ whenLabel(meta.next_session.scheduled_at) }}
          </p>
          <p v-if="meta.next_session.topic" class="text-[12px] text-bimbel-text-mid">
            {{ meta.next_session.topic }} · {{ meta.next_session.duration_minutes }}m
          </p>
        </div>
      </aside>
    </div>
  </div>
</template>
