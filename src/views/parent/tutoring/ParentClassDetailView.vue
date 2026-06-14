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
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const { activeChildId } = useChildPicker();

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
  <div class="space-y-3 pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-[12px] text-bimbel-text-mid hover:text-bimbel-text-hi"
      @click="router.push({ name: 'parent.tutoring.classes' })"
    >
      <NavIcon name="chevron-left" :size="13" /> Kembali ke daftar kelas
    </button>

    <ParentBerandaHero
      kicker="BIMBEL · KELAS"
      :title="meta?.group_name || 'Memuat…'"
      :subtitle="
        meta
          ? [
              meta.tutor_name ? `Tutor ${meta.tutor_name}` : null,
              meta.program_name,
              `${meta.attendance.total_recorded || sessions.length} siswa`,
            ].filter(Boolean).join(' · ')
          : undefined
      "
      :stats="heroStats"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <!-- Underline tab bar -->
    <div
      class="flex gap-0.5 border-b border-bimbel-border-soft bg-bimbel-bg -mt-0 px-3 sm:px-4"
      role="tablist"
    >
      <button
        v-for="t in [
          { id: 'aliran' as const, label: 'Aliran' },
          { id: 'sesi' as const, label: 'Sesi anak' },
          { id: 'nilai' as const, label: 'Nilai anak' },
        ]"
        :key="t.id"
        type="button"
        role="tab"
        :aria-selected="tab === t.id"
        class="px-3 py-2 text-[12px] border-b-2 transition-colors"
        :class="
          tab === t.id
            ? 'text-bimbel-hero border-bimbel-hero font-bold bg-bimbel-panel'
            : 'text-bimbel-text-mid border-transparent hover:text-bimbel-text-hi'
        "
        @click="tab = t.id"
      >
        {{ t.label }}
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-[12px] text-bimbel-text-mid">Memuat…</div>

    <div v-else class="grid gap-3 lg:grid-cols-3">
      <div class="rounded-lg border border-bimbel-border-soft bg-bimbel-panel p-3 lg:col-span-2">
        <!-- Aliran tab — chronological feed -->
        <template v-if="tab === 'aliran'">
          <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-1">
            Aliran kelas
          </p>
          <div
            v-if="feed.length === 0"
            class="py-8 text-center text-[12px] text-bimbel-text-mid"
          >
            Belum ada aktivitas di kelas ini.
          </div>
          <div v-else>
            <div
              v-for="(e, i) in feed"
              :key="i"
              class="flex items-center gap-2.5 border-b border-bimbel-border-soft py-2 last:border-b-0"
            >
              <span
                class="grid h-[30px] w-[30px] flex-shrink-0 place-items-center rounded-md"
                :class="
                  e.type === 'note' || e.type === 'score' || e.type === 'new_submission'
                    ? 'bg-bimbel-amber-dim text-amber-700'
                    : e.type === 'announcement' || e.type === 'announcement_posted'
                    ? 'bg-bimbel-accent-dim text-bimbel-hero'
                    : 'bg-bimbel-green-dim text-green-700'
                "
              >
                <NavIcon
                  :name="
                    e.type === 'announcement' || e.type === 'announcement_posted'
                      ? 'megaphone'
                      : e.type === 'note' || e.type === 'score' || e.type === 'new_submission'
                      ? 'book'
                      : 'school'
                  "
                  :size="14"
                />
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-[12px] font-bold text-bimbel-text-hi truncate">{{ e.title }}</p>
                <p
                  v-if="e.subtitle"
                  class="text-[11px] text-bimbel-text-mid truncate"
                >{{ e.subtitle }}</p>
              </div>
              <span class="flex-shrink-0 text-[11px] text-bimbel-text-lo">
                {{ whenLabel(e.occurred_at) }}
              </span>
            </div>
          </div>
        </template>

        <!-- Sesi anak tab -->
        <template v-else-if="tab === 'sesi'">
          <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-1">
            Sesi anak
          </p>
          <div
            v-if="sessionsSorted.length === 0"
            class="py-8 text-center text-[12px] text-bimbel-text-mid"
          >
            Belum ada sesi di kelas ini.
          </div>
          <div v-else>
            <div
              v-for="s in sessionsSorted"
              :key="s.id"
              class="flex items-center gap-2.5 border-b border-bimbel-border-soft py-2 last:border-b-0"
            >
              <span class="grid h-[30px] w-[30px] flex-shrink-0 place-items-center rounded-md bg-bimbel-accent-dim text-bimbel-hero">
                <NavIcon name="calendar" :size="14" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-[12px] font-bold text-bimbel-text-hi truncate">
                  {{ s.topic || 'Sesi terjadwal' }}
                </p>
                <p class="text-[11px] text-bimbel-text-mid truncate">
                  {{ whenLabel(s.scheduled_at) }} · {{ s.duration_minutes }} menit<template v-if="s.room"> · ruang {{ s.room }}</template>
                </p>
              </div>
              <span
                class="flex-shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide"
                :class="
                  s.status === 'DONE'
                    ? 'bg-bimbel-green-dim text-green-700'
                    : s.status === 'CANCELLED'
                    ? 'bg-bimbel-red-dim text-red-700'
                    : 'bg-bimbel-accent-dim text-bimbel-hero'
                "
              >
                {{ s.status_label ?? s.status }}
              </span>
            </div>
          </div>
        </template>

        <!-- Nilai anak tab -->
        <template v-else>
          <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-1">
            Nilai anak
          </p>
          <div
            v-if="progressEntries.length === 0"
            class="py-8 text-center text-[12px] text-bimbel-text-mid"
          >
            Belum ada nilai tercatat.
          </div>
          <div v-else>
            <div
              v-for="p in progressEntries"
              :key="p.assessment_id"
              class="flex items-center gap-2.5 border-b border-bimbel-border-soft py-2 last:border-b-0"
            >
              <span class="grid h-[30px] w-[30px] flex-shrink-0 place-items-center rounded-md bg-bimbel-amber-dim text-amber-700">
                <NavIcon name="star" :size="14" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-[12px] font-bold text-bimbel-text-hi truncate">{{ p.title }}</p>
                <p class="text-[11px] text-bimbel-text-mid truncate">
                  {{ [p.type_label, p.subject, whenLabel(p.held_at)].filter(Boolean).join(' · ') }}
                </p>
              </div>
              <span class="flex-shrink-0 text-[13px] font-extrabold text-green-700">
                {{ p.score ?? '–' }}
              </span>
            </div>
          </div>
        </template>
      </div>

      <!-- Info kelas sidebar -->
      <aside class="h-fit rounded-lg border border-bimbel-border-soft bg-bimbel-panel p-3">
        <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-1">
          Info kelas
        </p>
        <dl class="space-y-2 text-[12px]">
          <div>
            <dt class="text-bimbel-text-mid">Tutor</dt>
            <dd class="font-bold text-bimbel-text-hi">{{ meta?.tutor_name ?? '—' }}</dd>
          </div>
          <div>
            <dt class="text-bimbel-text-mid">Program</dt>
            <dd class="font-bold text-bimbel-text-hi">{{ meta?.program_name ?? '—' }}</dd>
          </div>
          <div>
            <dt class="text-bimbel-text-mid">Status</dt>
            <dd class="font-bold text-bimbel-text-hi">{{ meta?.status ?? '—' }}</dd>
          </div>
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
          <p class="text-[11px] text-bimbel-text-mid">Sesi berikutnya</p>
          <p class="mt-0.5 text-[12px] font-bold text-bimbel-text-hi">
            {{ whenLabel(meta.next_session.scheduled_at) }}
          </p>
          <p v-if="meta.next_session.topic" class="text-[11px] text-bimbel-text-mid">
            {{ meta.next_session.topic }} · {{ meta.next_session.duration_minutes }} menit
          </p>
        </div>
      </aside>
    </div>
  </div>
</template>
