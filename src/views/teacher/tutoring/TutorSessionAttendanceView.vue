<!--
  TutorSessionAttendanceView — record attendance for one bimbel session.
  Merges the group's active enrollees with any saved roster (saved status
  wins, else PRESENT), one bulk save. Web mirror of
  `tutor_session_attendance_screen.dart`. The save is idempotent
  server-side and fires the PER_SESSION billing hook.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import {
  ATTENDANCE_STATUS_LABELS,
  type AttendanceStatusKey,
} from '@/types/tutoring';

const route = useRoute();
const router = useRouter();
const toast = useToast();

const sessionId = String(route.params.sessionId ?? '');
const groupId = String(route.query.groupId ?? '');
const title = String(route.query.title ?? 'Absensi');

const loading = ref(true);
const saving = ref(false);
const error = ref<string | null>(null);

/** student_id → name */
const names = ref<Record<string, string>>({});
/** student_id → chosen status */
const chosen = ref<Record<string, string>>({});

const statusKeys = Object.keys(
  ATTENDANCE_STATUS_LABELS,
) as AttendanceStatusKey[];

async function load() {
  loading.value = true;
  error.value = null;
  try {
    const [enrollees, saved] = await Promise.all([
      TutoringService.getGroupEnrollees(groupId),
      TutoringService.getSessionRoster(sessionId),
    ]);
    const savedByStudent: Record<string, string> = {};
    for (const r of saved) savedByStudent[r.student_id] = r.status;

    const n: Record<string, string> = {};
    const c: Record<string, string> = {};
    for (const e of enrollees) {
      n[e.student_id] = e.student?.name ?? '—';
      c[e.student_id] = savedByStudent[e.student_id] ?? 'PRESENT';
    }
    // Include saved rows whose student is no longer an active enrollee.
    for (const r of saved) {
      if (!(r.student_id in n)) {
        n[r.student_id] = r.student?.name ?? '—';
        c[r.student_id] = r.status;
      }
    }
    names.value = n;
    chosen.value = c;
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Gagal memuat daftar siswa.';
  } finally {
    loading.value = false;
  }
}

async function save() {
  saving.value = true;
  try {
    const items = Object.entries(chosen.value).map(([student_id, status]) => ({
      student_id,
      status,
    }));
    await TutoringService.recordAttendance(sessionId, items);
    toast.success('Absensi tersimpan.');
    router.back();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan absensi.');
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-2xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">Absensi · {{ title }}</h1>

    <div v-if="loading" class="py-16 text-center text-slate-500">Memuat…</div>
    <div v-else-if="error" class="rounded-xl border border-red-200 bg-red-50 p-6 text-center">
      <p class="text-red-700">{{ error }}</p>
      <button class="mt-3 text-sm font-semibold text-red-700 underline" @click="load">
        Coba lagi
      </button>
    </div>
    <p
      v-else-if="Object.keys(names).length === 0"
      class="py-12 text-center text-slate-500"
    >
      Belum ada siswa terdaftar di kelompok ini.
    </p>
    <div v-else class="space-y-2.5">
      <div
        v-for="(name, studentId) in names"
        :key="studentId"
        class="flex items-center justify-between rounded-xl border border-slate-200 px-3 py-2"
      >
        <span class="font-medium text-slate-800">{{ name }}</span>
        <select
          v-model="chosen[studentId]"
          class="rounded-lg border border-slate-300 px-2 py-1.5 text-sm"
        >
          <option v-for="k in statusKeys" :key="k" :value="k">
            {{ ATTENDANCE_STATUS_LABELS[k] }}
          </option>
        </select>
      </div>

      <button
        :disabled="saving"
        class="mt-3 w-full rounded-lg bg-teal-700 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="save"
      >
        {{ saving ? 'Menyimpan…' : 'Simpan Absensi' }}
      </button>
    </div>
  </div>
</template>
