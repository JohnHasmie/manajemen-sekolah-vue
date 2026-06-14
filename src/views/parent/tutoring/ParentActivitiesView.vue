<!--
  ParentActivitiesView — wali tugas/ulangan list. Redesign: hero + type
  filter chips + single-column rows (icon | title/subtitle | pill).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type {
  TutoringActivity,
  TutoringActivitySubmission,
  TutoringWaliClassMeta,
} from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

// Backend ActivityType enum: ASSIGNMENT / EXAM / MATERIAL.
// Filter chips map to those values (plus "all" / "pending").
type FilterId = 'all' | 'pending' | 'ASSIGNMENT' | 'EXAM' | 'MATERIAL';

// Web previously showed only submission rows — but mobile shows every
// activity assigned to the student's groups, regardless of whether a
// submission exists yet. Mirror that here: fetch BOTH activities +
// submissions, then merge on activity_id so a row exists for every
// activity (submission overlays only if present).
//
// Activities are also scoped to groups the student is enrolled in
// (via getWaliClassMeta) — otherwise the tenant-wide /activities
// endpoint would leak rows from siblings' or other students' groups.
type Row = {
  id: string;
  activity: TutoringActivity;
  submission: TutoringActivitySubmission | null;
};

const loading = ref(true);
const activitiesAll = ref<TutoringActivity[]>([]);
const submissions = ref<TutoringActivitySubmission[]>([]);
const groupMeta = ref<TutoringWaliClassMeta[]>([]);
const typeFilter = ref<FilterId>('all');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try {
    const [acts, subs, groups] = await Promise.all([
      TutoringService.getActivities().catch(() => [] as TutoringActivity[]),
      TutoringService.getStudentActivitySubmissions(sid).catch(() => [] as TutoringActivitySubmission[]),
      TutoringService.getWaliClassMeta(sid).catch(() => [] as TutoringWaliClassMeta[]),
    ]);
    activitiesAll.value = acts;
    submissions.value = subs;
    groupMeta.value = groups;
  } finally {
    loading.value = false;
  }
}
onMounted(load);
watch(studentId, load);

// ── Merge: activities scoped to student's groups + matching submission ──
const rows = computed<Row[]>(() => {
  const groupIds = new Set(groupMeta.value.map((g) => g.group_id).filter(Boolean));
  // Pre-build submission lookup by activity id (handles backend's two
  // field names: tutoring_activity_id is canonical, activity_id is the
  // alias on some shapes).
  const subByAct = new Map<string, TutoringActivitySubmission>();
  for (const s of submissions.value) {
    const k = s.tutoring_activity_id ?? s.activity_id;
    if (k) subByAct.set(String(k), s);
  }
  const list: Row[] = [];
  for (const a of activitiesAll.value) {
    // Only activities for groups the student is actually enrolled in.
    if (groupIds.size > 0 && !groupIds.has(a.tutoring_group_id)) continue;
    list.push({ id: a.id, activity: a, submission: subByAct.get(a.id) ?? null });
  }
  // Sort by due_at: overdue first (closest-past at top), then upcoming
  // (closest-future at top), then no-due last.
  list.sort((x, y) => {
    const ax = x.activity.due_at ? new Date(x.activity.due_at).valueOf() : null;
    const by = y.activity.due_at ? new Date(y.activity.due_at).valueOf() : null;
    if (ax == null && by == null) return 0;
    if (ax == null) return 1;
    if (by == null) return -1;
    const now = Date.now();
    const xPast = ax < now, yPast = by < now;
    if (xPast && !yPast) return -1;
    if (!xPast && yPast) return 1;
    return Math.abs(ax - now) - Math.abs(by - now);
  });
  return list;
});

function isPending(r: Row): boolean {
  if (!r.submission) return true; // no submission row → not done
  const s = r.submission.status;
  return s === 'ASSIGNED' || s === 'LATE' || s === 'MISSED';
}
function isDone(r: Row): boolean {
  const s = r.submission?.status;
  return s === 'GRADED' || s === 'SUBMITTED';
}

const childFirstName = computed(() => {
  const name = activeChild()?.name ?? 'anak';
  return name.trim().split(' ')[0] || name;
});

const pendingCount = computed(() => rows.value.filter(isPending).length);

const doneThisMonth = computed(() => {
  const now = new Date();
  return rows.value.filter((r) => {
    if (!isDone(r)) return false;
    const subAt = r.submission?.submitted_at;
    if (!subAt) return false;
    const d = new Date(subAt);
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }).length;
});

const counts = computed(() => ({
  ASSIGNMENT: rows.value.filter((r) => r.activity.type === 'ASSIGNMENT').length,
  EXAM: rows.value.filter((r) => r.activity.type === 'EXAM').length,
  MATERIAL: rows.value.filter((r) => r.activity.type === 'MATERIAL').length,
}));

const filters = computed(() => [
  { id: 'all' as FilterId, label: `Semua (${rows.value.length})` },
  { id: 'pending' as FilterId, label: `Belum (${pendingCount.value})` },
  { id: 'ASSIGNMENT' as FilterId, label: `Tugas (${counts.value.ASSIGNMENT})` },
  { id: 'EXAM' as FilterId, label: `Ujian (${counts.value.EXAM})` },
  { id: 'MATERIAL' as FilterId, label: `Materi (${counts.value.MATERIAL})` },
]);

const visible = computed(() => {
  if (typeFilter.value === 'all') return rows.value;
  if (typeFilter.value === 'pending') return rows.value.filter(isPending);
  return rows.value.filter((r) => r.activity.type === typeFilter.value);
});

// ── Icon + colour by activity type ─────────────────────────────
function iconName(r: Row): string {
  switch (r.activity.type) {
    case 'EXAM': return 'check-circle';
    case 'MATERIAL': return 'book-open';
    default: return 'clipboard';
  }
}
function iconStyle(r: Row): Record<string, string> {
  // Done-state always reads green regardless of type.
  if (isDone(r)) return { background: 'var(--bimbel-green-dim, rgba(22,163,74,.15))', color: '#15803d' };
  switch (r.activity.type) {
    case 'EXAM':
      return { background: 'var(--bimbel-red-dim, rgba(220,38,38,.12))', color: '#b91c1c' };
    case 'MATERIAL':
      return { background: 'var(--bimbel-accent-dim, rgba(12,68,124,.12))', color: 'var(--bimbel-hero, #0c447c)' };
    default:
      return { background: 'var(--bimbel-accent-dim, rgba(12,68,124,.12))', color: 'var(--bimbel-hero, #0c447c)' };
  }
}

// ── Subtitle / pill ────────────────────────────────────────────
function fmtDate(iso?: string | null): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return null;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function daysUntilDue(r: Row): number | null {
  const due = r.activity.due_at;
  if (!due) return null;
  const d = new Date(due);
  if (Number.isNaN(d.valueOf())) return null;
  return Math.ceil((d.valueOf() - Date.now()) / 86_400_000);
}

function title(r: Row): string {
  return r.activity.title || '—';
}

// Subtitle: "Type · Kelompok · trailing fact"
//   GRADED   → "Nilai X/Y"
//   SUBMITTED→ "Dikumpul DD MMM"
//   No sub + due → "Lewat N hari · DD MMM" or "N hari lagi · DD MMM"
//   No sub + no due → "Tanpa tenggat"
function subtitle(r: Row): string {
  const parts: string[] = [];
  const typeLabel = r.activity.type_label || r.activity.type;
  if (typeLabel) parts.push(typeLabel);
  const group = r.activity.group?.name;
  if (group) parts.push(group);

  const s = r.submission;
  if (s?.status === 'GRADED' && s.score != null) {
    parts.push(`Nilai ${s.score}${s.max_score ? `/${s.max_score}` : ''}`);
  } else if (s?.status === 'SUBMITTED' && s.submitted_at) {
    parts.push(`Dikumpul ${fmtDate(s.submitted_at)}`);
  } else {
    const due = r.activity.due_at;
    if (due) {
      const days = daysUntilDue(r);
      const dueLabel = fmtDate(due);
      if (days != null && days < 0) parts.push(`Lewat ${Math.abs(days)} hari · ${dueLabel}`);
      else if (days != null) parts.push(`${days} hari lagi · ${dueLabel}`);
    } else if (r.activity.type === 'MATERIAL') {
      parts.push('Tanpa tenggat');
    }
  }
  return parts.join(' · ');
}

const PILL_BASE = 'rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide';

function pillCls(r: Row): string {
  const s = r.submission?.status;
  if (s === 'GRADED') return `${PILL_BASE} bg-bimbel-green-dim text-green-700`;
  if (s === 'SUBMITTED') return `${PILL_BASE} bg-bimbel-accent-dim text-bimbel-hero`;
  if (s === 'LATE' || s === 'MISSED') return `${PILL_BASE} bg-bimbel-red-dim text-red-700`;
  // No submission yet — pill colour follows urgency.
  if (r.activity.type === 'MATERIAL' && !r.activity.due_at) {
    return `${PILL_BASE} bg-bimbel-bg text-bimbel-text-mid`;
  }
  const days = daysUntilDue(r);
  if (days != null && days < 0) return `${PILL_BASE} bg-bimbel-red-dim text-red-700`;
  if (days != null && days <= 3) return `${PILL_BASE} bg-bimbel-amber-dim text-amber-700`;
  return `${PILL_BASE} bg-bimbel-accent-dim text-bimbel-hero`;
}

function pillLabel(r: Row): string {
  const s = r.submission?.status;
  if (s === 'GRADED') return `Selesai · ${r.submission?.score ?? '–'}`;
  if (s === 'SUBMITTED') return 'Dikumpul';
  if (s === 'LATE' || s === 'MISSED') {
    const days = daysUntilDue(r);
    return days != null && days < 0 ? `Telat · ${Math.abs(days)} hari` : 'Telat';
  }
  if (r.activity.type === 'MATERIAL' && !r.activity.due_at) return 'Materi';
  const days = daysUntilDue(r);
  if (days != null && days < 0) return `Lewat · ${Math.abs(days)} hari`;
  if (days != null) return `${days} hari lagi`;
  return 'Belum';
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · AKTIVITAS"
      :title="`Tugas & ulangan ${childFirstName}`"
      :subtitle="`${pendingCount} menunggu · ${doneThisMonth} selesai bulan ini`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <!-- Filter chips -->
    <div class="flex gap-1.5 flex-wrap">
      <button
        v-for="opt in filters"
        :key="opt.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          typeFilter === opt.id
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid'
        "
        @click="typeFilter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div class="space-y-1.5">
      <div
        v-for="r in visible"
        :key="r.id"
        class="grid items-center gap-2.5 p-2.5 rounded-lg bg-bimbel-bg"
        style="grid-template-columns: 32px 1fr auto;"
      >
        <div class="w-8 h-8 rounded-lg grid place-items-center" :style="iconStyle(r)">
          <NavIcon :name="iconName(r)" :size="14" />
        </div>
        <div class="min-w-0">
          <p class="text-[13px] font-bold text-bimbel-text-hi">
            {{ title(r) }}
          </p>
          <p class="text-[11px] text-bimbel-text-mid">{{ subtitle(r) }}</p>
        </div>
        <span :class="pillCls(r)">{{ pillLabel(r) }}</span>
      </div>
      <p v-if="!visible.length && !loading" class="text-center text-[12px] text-bimbel-text-mid py-6">
        Tidak ada aktivitas di kategori ini.
      </p>
      <p v-if="loading" class="text-center text-[12px] text-bimbel-text-mid py-6">Memuat…</p>
    </div>
  </div>
</template>
