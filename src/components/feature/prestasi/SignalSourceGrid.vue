<!--
  SignalSourceGrid.vue — 8 sumber poin tiles with open/locked state.

  Locked tiles are grayscale with a lock icon and the reason
  (`need_class_assignment` etc.) mapped to bahasa presentasi. Open
  tiles show the source label + point value in bright cobalt.

  The i18n happens right here: the reason keys come from the API in
  English (matches the enum), and we translate to Indonesian for
  display without polluting the resource layer.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { SumberTerbukaEntry } from '@/services/teacher-progress.service';

const props = defineProps<{
  sources: Record<string, SumberTerbukaEntry>;
}>();

// Static copy for each source — matches config('gamification.labels')
// on the backend so we can render even before the FE fetches those
// labels. Backend remains source of truth for tuning; this is a
// safe default.
const SOURCE_META: Record<string, { label: string; points: number; icon: string }> = {
  check_in_on_time: { label: 'Absen tepat waktu', points: 10, icon: 'clock' },
  check_in_early: { label: 'Datang lebih awal', points: 5, icon: 'sunrise' },
  student_attendance_session: { label: 'Absen sesi murid', points: 5, icon: 'users' },
  grade_assessment: { label: 'Input penilaian', points: 15, icon: 'edit-3' },
  submission_graded: { label: 'Nilai kumpulan tugas', points: 2, icon: 'check-circle' },
  lesson_plan_submitted: { label: 'Kumpul RPP', points: 20, icon: 'file-text' },
  class_activity_created: { label: 'Buat aktivitas kelas', points: 8, icon: 'plus-circle' },
  announcement_posted: { label: 'Post pengumuman', points: 3, icon: 'megaphone' },
};

const REASON_COPY: Record<string, string> = {
  need_class_assignment: 'Terbuka setelah kamu ditugaskan kelas',
  need_subject_assignment: 'Terbuka setelah kamu ditugaskan mapel',
  need_schedule_assignment: 'Terbuka setelah admin mengatur jadwal',
  staff_only: 'Sumber ini untuk guru dengan penugasan kelas',
};

// Preserve the natural order from SOURCE_META keys so the grid layout
// is stable across renders — Object.entries on `props.sources` would
// respect backend response order which shouldn't drive UI order.
const ordered = computed(() =>
  Object.keys(SOURCE_META)
    .filter((k) => k in props.sources)
    .map((k) => ({
      key: k,
      meta: SOURCE_META[k],
      state: props.sources[k],
      reason: props.sources[k].unlocked ? null : (REASON_COPY[props.sources[k].reason ?? ''] ?? 'Belum tersedia'),
    })),
);
</script>

<template>
  <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
    <div
      v-for="entry in ordered"
      :key="entry.key"
      class="rounded-2xl p-3 border transition"
      :class="entry.state.unlocked
        ? 'bg-white border-slate-200 shadow-sm'
        : 'bg-slate-50 border-slate-200'"
    >
      <div class="flex items-center gap-2">
        <div
          class="w-8 h-8 rounded-lg grid place-items-center flex-shrink-0"
          :class="entry.state.unlocked
            ? 'bg-brand-cobalt/10 text-brand-cobalt'
            : 'bg-slate-200 text-slate-400'"
        >
          <NavIcon :name="entry.state.unlocked ? entry.meta.icon : 'lock'" :size="16" />
        </div>
        <div class="min-w-0">
          <p
            class="text-2xs font-bold leading-tight truncate"
            :class="entry.state.unlocked ? 'text-slate-900' : 'text-slate-400'"
          >
            {{ entry.meta.label }}
          </p>
          <p
            class="text-3xs font-bold uppercase tracking-widest mt-0.5"
            :class="entry.state.unlocked ? 'text-brand-cobalt' : 'text-slate-400'"
          >
            +{{ entry.meta.points }} XP
          </p>
        </div>
      </div>
      <p
        v-if="!entry.state.unlocked"
        class="mt-2 text-3xs text-slate-500 leading-tight"
      >
        {{ entry.reason }}
      </p>
    </div>
  </div>
</template>
