<!--
  ParentActivitiesView — wali tugas/ulangan list. Redesign: hero + type
  filter chips + single-column rows (icon | title/subtitle | pill).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringActivitySubmission } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

type FilterId = 'all' | 'pending' | 'ULANGAN' | 'TUGAS' | 'KUIS';

// Backend resource (TutoringActivitySubmissionResource) eager-loads
// `activity` + `activity.group`. The TS type for the submission only
// declares scalar fields, so we extend it locally with the nested
// shape returned by the API. Pulling activity.title / type_label /
// due_at / group.name out of here is what gives each row real content
// instead of just "Tugas · dikumpul X".
type Activity = {
  title?: string | null;
  type?: string | null;
  type_label?: string | null;
  due_at?: string | null;
  description?: string | null;
  group?: { id?: string; name?: string | null } | null;
};
type RichSubmission = TutoringActivitySubmission & {
  activity?: Activity | null;
  // Legacy flat fields kept as fallbacks in case some endpoint
  // variant ships them at the root.
  activity_title?: string;
  activity_type?: string;
  subject_name?: string;
  group_name?: string;
  tutor_name?: string;
  due_at?: string;
};

// ── Field accessors (nested-first, flat-fallback) ──────────────
function actTitle(a: RichSubmission): string {
  return a.activity?.title ?? a.activity_title ?? 'Tugas';
}
function actType(a: RichSubmission): string {
  return (a.activity?.type ?? a.activity_type ?? '').toUpperCase();
}
function actTypeLabel(a: RichSubmission): string {
  return a.activity?.type_label ?? actType(a) ?? '';
}
function actGroup(a: RichSubmission): string | null {
  return a.activity?.group?.name ?? a.group_name ?? null;
}
function actDueAt(a: RichSubmission): string | null {
  return a.activity?.due_at ?? a.due_at ?? null;
}

const loading = ref(true);
const activities = ref<RichSubmission[]>([]);
const typeFilter = ref<FilterId>('all');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try {
    activities.value = (await TutoringService.getStudentActivitySubmissions(sid)) as RichSubmission[];
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

// ── Type normalization ─────────────────────────────────────────
function bucketOf(a: RichSubmission): 'ULANGAN' | 'TUGAS' | 'KUIS' | 'OTHER' {
  const t = actType(a);
  if (t === 'EXAM' || t === 'ULANGAN') return 'ULANGAN';
  if (t === 'QUIZ' || t === 'KUIS') return 'KUIS';
  if (t === 'HOMEWORK' || t === 'TUGAS' || t === 'PROJECT' || t === 'ESSAY') return 'TUGAS';
  return 'OTHER';
}

function isPending(a: RichSubmission): boolean {
  return a.status === 'ASSIGNED' || a.status === 'LATE' || a.status === 'MISSED';
}

function isDone(a: RichSubmission): boolean {
  return a.status === 'GRADED' || a.status === 'SUBMITTED';
}

const childFirstName = computed(() => {
  const name = activeChild()?.name ?? 'anak';
  return name.trim().split(' ')[0] || name;
});

const pendingCount = computed(() => activities.value.filter(isPending).length);

const doneThisMonth = computed(() => {
  const now = new Date();
  return activities.value.filter((a) => {
    if (!isDone(a)) return false;
    if (!a.submitted_at) return false;
    const d = new Date(a.submitted_at);
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }).length;
});

const filters = computed(() => [
  { id: 'all' as FilterId, label: `Semua (${activities.value.length})` },
  { id: 'pending' as FilterId, label: `Belum (${pendingCount.value})` },
  { id: 'ULANGAN' as FilterId, label: 'Ulangan' },
  { id: 'TUGAS' as FilterId, label: 'Tugas' },
  { id: 'KUIS' as FilterId, label: 'Kuis' },
]);

const visible = computed(() => {
  if (typeFilter.value === 'all') return activities.value;
  if (typeFilter.value === 'pending') return activities.value.filter(isPending);
  return activities.value.filter((a) => bucketOf(a) === typeFilter.value);
});

// ── Icon mapping ────────────────────────────────────────────────
function iconName(a: RichSubmission): string {
  const b = bucketOf(a);
  const t = actType(a);
  if (b === 'ULANGAN') return 'check-circle';
  if (b === 'KUIS') return 'check-circle';
  if (t === 'ESSAY' || t === 'PROJECT') return 'edit';
  return 'book';
}

function iconStyle(a: RichSubmission): Record<string, string> {
  const b = bucketOf(a);
  const t = actType(a);
  if (b === 'ULANGAN') {
    return isDone(a)
      ? { background: 'var(--bimbel-green-dim, rgba(22,163,74,.15))', color: '#15803d' }
      : { background: 'var(--bimbel-amber-dim, rgba(217,119,6,.15))', color: '#b45309' };
  }
  if (b === 'KUIS') {
    return { background: 'var(--bimbel-accent-dim, rgba(12,68,124,.12))', color: 'var(--bimbel-hero, #0c447c)' };
  }
  if (t === 'ESSAY' || t === 'PROJECT') {
    return { background: 'var(--bimbel-red-dim, rgba(220,38,38,.12))', color: '#b91c1c' };
  }
  return { background: 'var(--bimbel-amber-dim, rgba(217,119,6,.15))', color: '#b45309' };
}

// ── Subtitle / pill ─────────────────────────────────────────────
function fmtDate(iso?: string | null): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return null;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function daysUntilDue(a: RichSubmission): number | null {
  const due = actDueAt(a);
  if (!due) return null;
  const d = new Date(due);
  if (Number.isNaN(d.valueOf())) return null;
  return Math.ceil((d.valueOf() - Date.now()) / 86_400_000);
}

// Build the row subtitle from real backend fields. Always shows
// kelompok if present, plus a status-appropriate trailing fact:
//   - GRADED   → "Nilai X/Y"
//   - SUBMITTED→ "Dikumpul DD MMM"
//   - others   → "Deadline DD MMM" or "Lewat N hari"
function subtitle(a: RichSubmission): string {
  const parts: string[] = [];
  const typeLabel = actTypeLabel(a);
  if (typeLabel) parts.push(typeLabel);
  const group = actGroup(a);
  if (group) parts.push(group);

  if (a.status === 'GRADED' && a.score != null) {
    parts.push(`Nilai ${a.score}${a.max_score ? `/${a.max_score}` : ''}`);
  } else if (a.status === 'SUBMITTED' && a.submitted_at) {
    parts.push(`Dikumpul ${fmtDate(a.submitted_at)}`);
  } else {
    const due = actDueAt(a);
    if (due) {
      const days = daysUntilDue(a);
      const dueLabel = fmtDate(due);
      if (days != null && days < 0) parts.push(`Lewat ${Math.abs(days)} hari · ${dueLabel}`);
      else parts.push(`Deadline ${dueLabel}`);
    }
  }
  return parts.join(' · ');
}

const PILL_BASE = 'rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide';

function pillCls(a: RichSubmission): string {
  if (a.status === 'GRADED') return `${PILL_BASE} bg-bimbel-green-dim text-green-700`;
  if (a.status === 'SUBMITTED') return `${PILL_BASE} bg-bimbel-accent-dim text-bimbel-hero`;
  if (a.status === 'LATE' || a.status === 'MISSED') return `${PILL_BASE} bg-bimbel-red-dim text-red-700`;
  const days = daysUntilDue(a);
  if (days != null && days <= 3) return `${PILL_BASE} bg-bimbel-red-dim text-red-700`;
  return `${PILL_BASE} bg-bimbel-amber-dim text-amber-700`;
}

function pillLabel(a: RichSubmission): string {
  if (a.status === 'GRADED') return `Selesai · ${a.score ?? '–'}`;
  if (a.status === 'SUBMITTED') return 'Dikumpul';
  if (a.status === 'LATE' || a.status === 'MISSED') {
    const days = daysUntilDue(a);
    return days != null && days < 0 ? `Telat · ${Math.abs(days)} hari` : 'Telat';
  }
  const days = daysUntilDue(a);
  if (days != null) return `Belum · ${days} hari`;
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
        v-for="a in visible"
        :key="a.id"
        class="grid items-center gap-2.5 p-2.5 rounded-lg bg-bimbel-bg"
        style="grid-template-columns: 32px 1fr auto;"
      >
        <div class="w-8 h-8 rounded-lg grid place-items-center" :style="iconStyle(a)">
          <NavIcon :name="iconName(a)" :size="14" />
        </div>
        <div class="min-w-0">
          <p class="text-[13px] font-bold text-bimbel-text-hi">
            {{ actTitle(a) }}
          </p>
          <p class="text-[11px] text-bimbel-text-mid">{{ subtitle(a) }}</p>
        </div>
        <span :class="pillCls(a)">{{ pillLabel(a) }}</span>
      </div>
      <p v-if="!visible.length && !loading" class="text-center text-[12px] text-bimbel-text-mid py-6">
        Tidak ada aktivitas di kategori ini.
      </p>
      <p v-if="loading" class="text-center text-[12px] text-bimbel-text-mid py-6">Memuat…</p>
    </div>
  </div>
</template>
