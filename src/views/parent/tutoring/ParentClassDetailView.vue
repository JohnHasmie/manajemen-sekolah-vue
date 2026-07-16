<!--
  ParentClassDetailView — homeroom teacher detail. 4 tabs (Aliran / Tugas /
  Grade / Student) per redesigned mockup. Single-column card layout under
  a tab bar; no sidebar.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type {
  TutoringFeedEvent,
  TutoringProgress,
  TutoringParentClassMeta,
} from '@/types/tutoring';

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);
const groupId = computed(() => String(route.params.groupId || ''));

type TabId = 'aliran' | 'tugas' | 'nilai' | 'siswa';
const activeTab = ref<TabId>('aliran');

const loading = ref(true);
const meta = ref<(TutoringParentClassMeta & {
  subject?: string | null;
  schedule_label?: string | null;
  students_count?: number | null;
}) | null>(null);
const feed = ref<TutoringFeedEvent[]>([]);
const progress = ref<TutoringProgress | null>(null);

async function load() {
  const sid = studentId.value;
  const gid = groupId.value;
  if (!sid || !gid) { loading.value = false; return; }
  loading.value = true;
  try {
    const [allMeta, f, prog] = await Promise.all([
      TutoringService.getWaliClassMeta(sid).catch(() => [] as TutoringParentClassMeta[]),
      TutoringService.getStudentFeed(sid, { limit: 30, sinceDays: 60 }).catch(() => [] as TutoringFeedEvent[]),
      TutoringService.getProgress(sid).catch(() => null as TutoringProgress | null),
    ]);
    meta.value = (allMeta as TutoringParentClassMeta[]).find((m) => m.group_id === gid) ?? null;
    feed.value = (f as TutoringFeedEvent[]).filter((e) => {
      const m = e.meta as Record<string, unknown> | undefined;
      return !m || !m.group_id || String(m.group_id) === gid;
    });
    progress.value = prog;
  } finally { loading.value = false; }
}
onMounted(load);
watch([studentId, groupId], load);

// ── Derived rows per tab ────────────────────────────────────────
type AliranRow = {
  id?: string;
  type?: string;
  title: string;
  subtitle?: string | null;
  time_label?: string;
  pill?: { cls: string; label: string } | null;
};

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

const aliran = computed<AliranRow[]>(() =>
  feed.value.map((e, i) => ({
    id: `${e.type}-${i}`,
    type: e.type,
    title: e.title,
    subtitle: e.subtitle ?? null,
    time_label: whenLabel(e.occurred_at),
    pill: null,
  })),
);

type TugasRow = { id?: string; title: string; subtitle: string; pillCls: string; pillLabel: string };

const tugas = computed<TugasRow[]>(() => {
  const out: TugasRow[] = [];
  for (const e of feed.value) {
    if (e.type !== 'note' && e.type !== 'new_submission' && e.type !== 'score') continue;
    const m = e.meta as Record<string, unknown> | undefined;
    const status = String(m?.status ?? '').toUpperCase();
    const isDone = status === 'GRADED' || status === 'SUBMITTED' || e.type === 'score';
    out.push({
      id: String((m?.id ?? m?.assessment_id ?? Math.random())),
      title: e.title,
      subtitle: e.subtitle ?? whenLabel(e.occurred_at),
      pillCls: isDone
        ? 'rounded-full px-2 py-0.5 text-3xs font-bold uppercase tracking-wide bg-tutoring-green-dim text-green-700'
        : 'rounded-full px-2 py-0.5 text-3xs font-bold uppercase tracking-wide bg-tutoring-amber-dim text-amber-700',
      pillLabel: isDone ? t('wali.bimbel.class_detail.task_done_pill') : t('wali.bimbel.class_detail.task_pending_pill'),
    });
  }
  return out;
});

type NilaiRow = { title: string; subtitle: string; score: string };

const nilai = computed<NilaiRow[]>(() => {
  const entries = progress.value?.timeline ?? [];
  return entries.map((p) => ({
    title: p.title,
    subtitle: [p.type_label, p.subject, whenLabel(p.held_at)].filter(Boolean).join(' · '),
    score: p.score != null ? String(p.score) : '–',
  }));
});

type SiswaRow = { id?: string; name: string; attendance_rate: number | null };

const siswa = computed<SiswaRow[]>(() => {
  const child = activeChild();
  if (!child) return [];
  return [
    {
      id: child.student_id,
      name: child.name,
      attendance_rate: meta.value?.attendance?.rate ?? null,
    },
  ];
});

const tabs = computed(() => [
  { id: 'aliran' as TabId, label: t('wali.bimbel.class_detail.tab_stream') },
  { id: 'tugas' as TabId, label: t('wali.bimbel.class_detail.tab_tasks') },
  { id: 'nilai' as TabId, label: t('wali.bimbel.class_detail.tab_grades') },
  { id: 'siswa' as TabId, label: t('wali.bimbel.class_detail.tab_students', { count: siswa.value.length }) },
]);

// ── Aliran icon mapping ──────────────────────────────────────────
function rowIconName(r: AliranRow): string {
  const t = r.type ?? '';
  if (t === 'announcement' || t === 'announcement_posted') return 'megaphone';
  if (t === 'note' || t === 'new_submission') return 'book';
  if (t === 'score') return 'check-circle';
  return 'school';
}

function rowIconStyle(r: AliranRow): Record<string, string> {
  const t = r.type ?? '';
  if (t === 'announcement' || t === 'announcement_posted') {
    return { background: 'var(--tutoring-accent-dim, rgba(12,68,124,.12))', color: 'var(--tutoring-hero, #0c447c)' };
  }
  if (t === 'note' || t === 'new_submission') {
    return { background: 'var(--tutoring-amber-dim, rgba(217,119,6,.15))', color: '#b45309' };
  }
  if (t === 'score') {
    return { background: 'var(--tutoring-green-dim, rgba(22,163,74,.15))', color: '#15803d' };
  }
  // attendance / session / default
  return { background: 'var(--tutoring-green-dim, rgba(22,163,74,.15))', color: '#15803d' };
}

function initials(name: string): string {
  if (!name) return '';
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? '')
    .join('');
}

// ── Hero subtitle pieces ─────────────────────────────────────────
const heroSubtitle = computed(() => {
  const m = meta.value;
  const tutor = m?.tutor_name ?? '—';
  const sched = (m as { schedule_label?: string | null } | null)?.schedule_label ?? '';
  const count = (m as { students_count?: number | null } | null)?.students_count
    ?? m?.attendance?.total_recorded ?? 0;
  return `${tutor}${sched ? ` · ${sched}` : ''} · ${t('wali.bimbel.class_detail.students_count', { count })}`;
});

const heroTitle = computed(() => {
  const m = meta.value;
  const subj = (m as { subject?: string | null } | null)?.subject ?? m?.program_name ?? t('wali.bimbel.class_detail.default_program');
  const grp = m?.group_name ?? '';
  return `${subj}${grp ? ` · ${grp}` : ''}`;
});
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentHomeHero
      :kicker="t('wali.bimbel.class_detail.kicker')"
      :title="heroTitle"
      :subtitle="heroSubtitle"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentHomeHero>

    <!-- Tabs (4) -->
    <div
      class="flex gap-1 px-3.5 -mt-1 border-b border-tutoring-border-soft bg-tutoring-bg rounded-t-lg overflow-x-auto"
      role="tablist"
    >
      <button
        v-for="t in tabs"
        :key="t.id"
        type="button"
        role="tab"
        :aria-selected="activeTab === t.id"
        class="px-3 py-2 text-[13px] border-b-2 -mb-px transition-colors whitespace-nowrap"
        :class="
          activeTab === t.id
            ? 'text-tutoring-hero border-tutoring-hero font-bold bg-tutoring-panel'
            : 'text-tutoring-text-mid border-transparent'
        "
        @click="activeTab = t.id"
      >{{ t.label }}</button>
    </div>

    <!-- Aliran tab -->
    <div
      v-if="activeTab === 'aliran'"
      class="rounded-b-lg bg-tutoring-panel border border-tutoring-border-soft border-t-0 p-3.5"
    >
      <div
        v-for="(r, i) in aliran"
        :key="r.id || i"
        class="flex gap-2.5 py-2 border-b border-tutoring-border-soft last:border-b-0 items-start"
      >
        <div
          class="w-[30px] h-[30px] rounded-lg grid place-items-center flex-shrink-0"
          :style="rowIconStyle(r)"
        >
          <NavIcon :name="rowIconName(r)" :size="13" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-bold text-tutoring-text-hi">{{ r.title }}</p>
          <p class="text-[12px] text-tutoring-text-mid">
            {{ r.subtitle }}
            <span v-if="r.pill" :class="r.pill.cls">{{ r.pill.label }}</span>
          </p>
        </div>
        <span class="text-[12px] text-tutoring-text-lo flex-shrink-0">{{ r.time_label }}</span>
      </div>
      <p v-if="!aliran.length && !loading" class="text-center text-[13px] text-tutoring-text-mid py-6">
        {{ t('wali.bimbel.class_detail.empty_stream') }}
      </p>
      <p v-if="loading" class="text-center text-[13px] text-tutoring-text-mid py-6">{{ t('wali.bimbel.class_detail.loading') }}</p>
    </div>

    <!-- Tugas tab -->
    <div
      v-if="activeTab === 'tugas'"
      class="rounded-b-lg bg-tutoring-panel border border-tutoring-border-soft border-t-0 p-3.5"
    >
      <div
        v-for="(r, i) in tugas"
        :key="r.id || i"
        class="flex gap-2.5 py-2 border-b border-tutoring-border-soft last:border-b-0 items-start"
      >
        <div class="w-[30px] h-[30px] rounded-lg bg-tutoring-amber-dim text-amber-700 grid place-items-center flex-shrink-0">
          <NavIcon name="book" :size="13" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-bold text-tutoring-text-hi">{{ r.title }}</p>
          <p class="text-[12px] text-tutoring-text-mid">{{ r.subtitle }}</p>
        </div>
        <span :class="r.pillCls">{{ r.pillLabel }}</span>
      </div>
      <p v-if="!loading && !tugas.length" class="text-center text-[13px] text-tutoring-text-mid py-6">
        {{ t('wali.bimbel.class_detail.empty_tasks') }}
      </p>
    </div>

    <!-- Grade tab -->
    <div
      v-if="activeTab === 'nilai'"
      class="rounded-b-lg bg-tutoring-panel border border-tutoring-border-soft border-t-0 p-3.5"
    >
      <div
        v-for="(r, i) in nilai"
        :key="i"
        class="flex gap-2.5 py-2 border-b border-tutoring-border-soft last:border-b-0 items-center"
      >
        <div class="w-[30px] h-[30px] rounded-lg bg-tutoring-green-dim text-green-700 grid place-items-center flex-shrink-0">
          <NavIcon name="check-circle" :size="13" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-bold text-tutoring-text-hi">{{ r.title }}</p>
          <p class="text-[12px] text-tutoring-text-mid">{{ r.subtitle }}</p>
        </div>
        <span class="text-[16px] font-extrabold text-tutoring-text-hi">{{ r.score }}</span>
      </div>
      <p v-if="!loading && !nilai.length" class="text-center text-[13px] text-tutoring-text-mid py-6">
        {{ t('wali.bimbel.class_detail.empty_grades') }}
      </p>
    </div>

    <!-- Student tab -->
    <div
      v-if="activeTab === 'siswa'"
      class="rounded-b-lg bg-tutoring-panel border border-tutoring-border-soft border-t-0 p-3.5"
    >
      <div
        v-for="(s, i) in siswa"
        :key="s.id || i"
        class="flex gap-2.5 py-2 border-b border-tutoring-border-soft last:border-b-0 items-center"
      >
        <div class="w-8 h-8 rounded-full bg-tutoring-accent-dim text-tutoring-hero grid place-items-center text-[12px] font-bold">
          {{ initials(s.name) }}
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-bold text-tutoring-text-hi">{{ s.name }}</p>
          <p class="text-[12px] text-tutoring-text-mid">
            {{ t('wali.bimbel.class_detail.subtitle_attendance', { rate: s.attendance_rate ?? 0 }) }}
          </p>
        </div>
      </div>
      <p v-if="!loading && !siswa.length" class="text-center text-[13px] text-tutoring-text-mid py-6">
        {{ t('wali.bimbel.class_detail.empty_students') }}
      </p>
    </div>
  </div>
</template>
