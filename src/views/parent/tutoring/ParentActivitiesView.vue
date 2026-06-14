<!--
  ParentActivitiesView — wali kegiatan/tugas list. Mockup parent_web_pages_browse
  frame 3: hero + type filter + table.
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

const loading = ref(true);
const submissions = ref<TutoringActivitySubmission[]>([]);
const typeFilter = ref<'all' | 'PENDING' | 'HOMEWORK' | 'QUIZ' | 'EXAM' | 'PROJECT'>('all');
const query = ref('');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try {
    submissions.value = await TutoringService.getStudentActivitySubmissions(sid);
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

const filtered = computed(() => {
  let list = submissions.value;
  if (typeFilter.value === 'PENDING') {
    list = list.filter((s) => s.status === 'ASSIGNED' || s.status === 'LATE' || s.status === 'MISSED');
  } else if (typeFilter.value !== 'all') {
    list = list.filter((s) => {
      const t = (s as TutoringActivitySubmission & { activity_type?: string }).activity_type;
      return (t ?? '').toUpperCase() === typeFilter.value;
    });
  }
  const q = query.value.trim().toLowerCase();
  if (q) {
    list = list.filter((s) => {
      const title = (s as TutoringActivitySubmission & { activity_title?: string }).activity_title;
      return (title ?? '').toLowerCase().includes(q);
    });
  }
  return list;
});

// ── Redesigned template helpers ──────────────────────────────────
const childFirstName = computed(() => {
  const name = activeChild()?.name ?? 'anak';
  return name.trim().split(' ')[0] ?? name;
});

function isPending(s: TutoringActivitySubmission): boolean {
  return s.status === 'ASSIGNED' || s.status === 'LATE' || s.status === 'MISSED';
}

const pendingCount = computed(() => submissions.value.filter(isPending).length);

const completedThisMonth = computed(() => {
  const now = new Date();
  return submissions.value.filter((s) => {
    if (s.status !== 'GRADED' && s.status !== 'SUBMITTED') return false;
    if (!s.submitted_at) return false;
    const d = new Date(s.submitted_at);
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }).length;
});

const countByType = (t: string) =>
  submissions.value.filter((s) =>
    ((s as TutoringActivitySubmission & { activity_type?: string }).activity_type ?? '').toUpperCase() === t,
  ).length;

const filterOptions = computed(() => [
  { id: 'all' as const, label: `Semua (${submissions.value.length})` },
  { id: 'PENDING' as const, label: `Belum (${pendingCount.value})` },
  { id: 'EXAM' as const, label: `Ulangan (${countByType('EXAM')})` },
  { id: 'HOMEWORK' as const, label: `Tugas (${countByType('HOMEWORK')})` },
  { id: 'QUIZ' as const, label: `Kuis (${countByType('QUIZ')})` },
]);

function iconMeta(s: TutoringActivitySubmission): { icon: string; cls: string } {
  const t = ((s as TutoringActivitySubmission & { activity_type?: string }).activity_type ?? '').toUpperCase();
  if (t === 'EXAM') {
    return s.status === 'GRADED' || s.status === 'SUBMITTED'
      ? { icon: 'check-circle', cls: 'bg-bimbel-green-dim text-green-700' }
      : { icon: 'clipboard', cls: 'bg-bimbel-amber-dim text-amber-700' };
  }
  if (t === 'QUIZ') return { icon: 'help-circle', cls: 'bg-bimbel-accent-dim text-bimbel-hero' };
  if (t === 'PROJECT') return { icon: 'edit', cls: 'bg-bimbel-red-dim text-red-700' };
  return { icon: 'book', cls: 'bg-bimbel-amber-dim text-amber-700' };
}

function daysUntilDue(s: TutoringActivitySubmission): number | null {
  const due = (s as TutoringActivitySubmission & { due_at?: string }).due_at;
  if (!due) return null;
  const d = new Date(due);
  if (Number.isNaN(d.valueOf())) return null;
  return Math.ceil((d.valueOf() - Date.now()) / 86_400_000);
}

function rowSubtitle(s: TutoringActivitySubmission): string {
  const subj = (s as TutoringActivitySubmission & { subject_name?: string; group_name?: string }).subject_name
    ?? (s as TutoringActivitySubmission & { group_name?: string }).group_name;
  const tutor = (s as TutoringActivitySubmission & { tutor_name?: string }).tutor_name;
  const parts: string[] = [];
  if (subj) parts.push(subj);
  if (tutor) parts.push(tutor);
  if (s.status === 'GRADED' && s.score != null) {
    parts.push(`nilai ${s.score}${s.max_score ? `/${s.max_score}` : '/100'}`);
  } else {
    const days = daysUntilDue(s);
    if (days != null) {
      parts.push(days < 0 ? `lewat ${Math.abs(days)} hari` : `deadline ${days} hari`);
    } else if (s.submitted_at) {
      parts.push(`dikumpul ${new Date(s.submitted_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}`);
    }
  }
  return parts.join(' · ');
}

function pillMeta(s: TutoringActivitySubmission): { cls: string; label: string } {
  if (s.status === 'GRADED') {
    return {
      cls: 'bg-bimbel-green-dim text-green-700',
      label: `Selesai · ${s.score ?? '–'}`,
    };
  }
  if (s.status === 'SUBMITTED') {
    return { cls: 'bg-bimbel-accent-dim text-bimbel-hero', label: 'Dikumpul' };
  }
  if (s.status === 'LATE' || s.status === 'MISSED') {
    const days = daysUntilDue(s);
    const tail = days != null && days < 0 ? ` · ${Math.abs(days)} hari` : '';
    return { cls: 'bg-bimbel-red-dim text-red-700', label: `Telat${tail}` };
  }
  // ASSIGNED / pending
  const days = daysUntilDue(s);
  if (days != null && days <= 3) {
    return { cls: 'bg-bimbel-red-dim text-red-700', label: `Belum · ${days} hari` };
  }
  if (days != null) {
    return { cls: 'bg-bimbel-amber-dim text-amber-700', label: `Belum · ${days} hari` };
  }
  return { cls: 'bg-bimbel-amber-dim text-amber-700', label: 'Belum' };
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · AKTIVITAS"
      :title="`Tugas & ulangan ${childFirstName}`"
      :subtitle="`${pendingCount} menunggu · ${completedThisMonth} selesai bulan ini`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <!-- Filter chips -->
    <div class="flex gap-1.5 mb-2.5 flex-wrap">
      <button
        v-for="opt in filterOptions"
        :key="opt.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          typeFilter === opt.id
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="typeFilter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <!-- Search -->
    <div class="relative">
      <NavIcon
        name="search"
        :size="13"
        class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-bimbel-text-lo"
      />
      <input
        v-model="query"
        type="text"
        placeholder="Cari tugas…"
        class="w-full rounded-lg border border-bimbel-border-soft bg-bimbel-panel pl-8 pr-3 py-1.5 text-[12px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-bimbel-hero focus:outline-none"
      />
    </div>

    <div v-if="loading" class="py-12 text-center text-[12px] text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="rounded-lg border border-bimbel-border-soft bg-bimbel-panel p-3">
      <div
        v-for="s in filtered"
        :key="s.id"
        class="grid grid-cols-[32px_1fr_auto] gap-2.5 items-center p-2.5 rounded-lg bg-bimbel-bg mb-1.5"
      >
        <span
          class="grid h-8 w-8 place-items-center rounded-md"
          :class="iconMeta(s).cls"
        >
          <NavIcon :name="iconMeta(s).icon" :size="14" />
        </span>
        <div class="min-w-0">
          <p class="text-[13px] font-bold text-bimbel-text-hi truncate">
            {{ (s as any).activity_title ?? 'Tugas' }}
          </p>
          <p class="text-[11px] text-bimbel-text-mid truncate">
            {{ rowSubtitle(s) }}
          </p>
        </div>
        <span
          class="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide"
          :class="pillMeta(s).cls"
        >
          {{ pillMeta(s).label }}
        </span>
      </div>
    </div>

    <div
      v-else
      class="rounded-lg border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-[12px] text-bimbel-text-mid"
    >Belum ada kegiatan.</div>
  </div>
</template>
