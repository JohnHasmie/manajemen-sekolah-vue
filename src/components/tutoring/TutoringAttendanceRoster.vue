<!--
  TutoringAttendanceRoster.vue — bulk attendance-marking list for a
  single bimbel session.

  Wraps the existing `AttendancePicker` per row (NOT rebuilt — this
  matches the school-side `TeacherAttendanceInputView` inline pattern).
  Keyed by `enrollment_id` because bimbel session_attendances FK to
  `bimbel_enrollments`, not `student_classes`.

  Two-way binding:
    - `rows` is the source of truth (parent-controlled).
    - `update:row` fires per-cell for optimistic updates.
    - `save` fires once for the "Simpan" CTA — parent debounces if needed.

  Search + filterMode are decoupled from `rows` so the parent can keep
  a stable master list and pass a filtered view (matches how
  TeacherAttendanceInputView splits `filteredReports` from `reports`).
-->
<script setup lang="ts">
import { computed } from 'vue';
import AttendancePicker from '@/components/feature/AttendancePicker.vue';
import type { AttendanceStatus } from '@/types/attendance';
import type { TutoringAttendanceRow } from '@/types/tutoring-bimbel';

const props = withDefaults(
  defineProps<{
    rows: TutoringAttendanceRow[];
    sessionId: string;
    loading?: boolean;
    saving?: boolean;
    search?: string;
    filterMode?: 'all' | 'unmarked';
    /** Whether to render the "Simpan" footer button. Off for read-only viewers. */
    canSave?: boolean;
  }>(),
  { loading: false, saving: false, search: '', filterMode: 'all', canSave: true },
);

const emit = defineEmits<{
  'update:row': [{ enrollment_id: string; status: AttendanceStatus; notes?: string }];
  save: [];
  'update:search': [string];
  'update:filterMode': ['all' | 'unmarked'];
}>();

const visibleRows = computed(() => {
  const needle = props.search.trim().toLowerCase();
  return props.rows.filter((row) => {
    if (props.filterMode === 'unmarked' && row.status !== null) return false;
    if (!needle) return true;
    return (
      row.student_name.toLowerCase().includes(needle) ||
      (row.student_number ?? '').toLowerCase().includes(needle)
    );
  });
});

function updateStatus(row: TutoringAttendanceRow, status: AttendanceStatus) {
  emit('update:row', { enrollment_id: row.enrollment_id, status, notes: row.notes });
}

function alertToneClass(tone: TutoringAttendanceRow['alert_tone']): string {
  return tone === 'danger'
    ? 'bg-danger-soft text-danger'
    : 'bg-warning-soft text-warning';
}
</script>

<template>
  <section
    class="rounded-card border-0.5 border-tutoring-border-soft bg-tutoring-panel"
    :aria-busy="loading || saving"
  >
    <header class="flex flex-wrap items-center gap-3 border-b-0.5 border-tutoring-border-soft px-4 py-3">
      <input
        type="search"
        :value="search"
        :placeholder="`Cari nama / NIS (${rows.length})`"
        class="min-w-[160px] flex-1 rounded-lg border-0.5 border-tutoring-border-soft bg-tutoring-panel px-3 py-1.5 text-sm text-tutoring-text-hi placeholder:text-tutoring-text-lo focus:outline-none focus:ring-2 focus:ring-[#21afe6]/60"
        @input="(e) => emit('update:search', (e.target as HTMLInputElement).value)"
      >
      <div class="inline-flex rounded-lg border-0.5 border-tutoring-border-soft bg-tutoring-panel p-0.5 text-xs font-bold">
        <button
          type="button"
          class="rounded-md px-3 py-1 transition"
          :class="filterMode === 'all' ? 'bg-[#21afe6] text-white' : 'text-tutoring-text-mid'"
          @click="emit('update:filterMode', 'all')"
        >Semua</button>
        <button
          type="button"
          class="rounded-md px-3 py-1 transition"
          :class="filterMode === 'unmarked' ? 'bg-[#21afe6] text-white' : 'text-tutoring-text-mid'"
          @click="emit('update:filterMode', 'unmarked')"
        >Belum diisi</button>
      </div>
    </header>

    <ul
      v-if="visibleRows.length"
      class="divide-y-0.5 divide-tutoring-border-soft"
      role="list"
    >
      <li
        v-for="row in visibleRows"
        :key="row.enrollment_id"
        class="flex flex-wrap items-center gap-3 px-4 py-3"
      >
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-bold text-tutoring-text-hi">{{ row.student_name }}</p>
          <p v-if="row.student_number" class="text-2xs text-tutoring-text-mid">NIS {{ row.student_number }}</p>
          <p
            v-if="row.alert"
            class="mt-1 inline-block rounded-md px-2 py-0.5 text-2xs font-bold"
            :class="alertToneClass(row.alert_tone)"
          >{{ row.alert }}</p>
        </div>
        <AttendancePicker
          :model-value="row.status"
          :disabled="loading || saving"
          @update:model-value="(v) => updateStatus(row, v)"
        />
      </li>
    </ul>

    <div v-else class="px-4 py-8 text-center text-sm text-tutoring-text-mid">
      Tidak ada siswa untuk filter ini.
    </div>

    <footer
      v-if="canSave"
      class="flex items-center justify-end gap-2 border-t-0.5 border-tutoring-border-soft px-4 py-3"
    >
      <button
        type="button"
        class="rounded-lg bg-[#21afe6] px-4 py-1.5 text-sm font-bold text-white transition hover:bg-[#1a8fbe] disabled:opacity-60"
        :disabled="loading || saving"
        @click="emit('save')"
      >{{ saving ? 'Menyimpan…' : 'Simpan & tandai selesai' }}</button>
    </footer>
  </section>
</template>
