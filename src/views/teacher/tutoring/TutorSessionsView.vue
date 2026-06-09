<!--
  TutorSessionsView — the tutor's own bimbel sessions (−7d..+14d). Tap a
  session to record attendance. Web mirror of `tutor_sessions_screen.dart`.

  The tutor's user id comes from the auth store (the backend filters the
  schedule by tutor_user_id).
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import { formatDateShort } from '@/lib/format';
import type { TutoringSession } from '@/types/tutoring';

const router = useRouter();
const auth = useAuthStore();
const loading = ref(true);
const error = ref<string | null>(null);
const sessions = ref<TutoringSession[]>([]);

async function load() {
  const tutorId = auth.user?.id;
  if (!tutorId) {
    error.value = 'Tidak dapat mengenali akun tutor.';
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = null;
  try {
    const now = new Date();
    const from = new Date(now.getTime() - 7 * 24 * 3600 * 1000);
    const to = new Date(now.getTime() + 14 * 24 * 3600 * 1000);
    const list = await TutoringService.getTutorSessions(tutorId, from, to);
    sessions.value = list.sort((a, b) => {
      const ad = a.scheduled_at ? new Date(a.scheduled_at).getTime() : 0;
      const bd = b.scheduled_at ? new Date(b.scheduled_at).getTime() : 0;
      return ad - bd;
    });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Gagal memuat sesi.';
  } finally {
    loading.value = false;
  }
}

function statusClass(status: string): string {
  if (status === 'DONE') return 'bg-emerald-100 text-emerald-800';
  if (status === 'CANCELLED') return 'bg-red-100 text-red-800';
  return 'bg-indigo-100 text-indigo-800';
}

function openAttendance(s: TutoringSession) {
  if (s.status === 'CANCELLED') return;
  router.push({
    name: 'teacher.tutoring.attendance',
    params: { sessionId: s.id },
    query: {
      groupId: s.group_id,
      title: s.scheduled_at ? formatDateShort(s.scheduled_at) : 'Absensi',
    },
  });
}

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-bold text-slate-800">Sesi Mengajar</h1>
      <button
        class="rounded-lg bg-teal-700 px-3 py-2 text-sm font-semibold text-white"
        @click="
          router.push({ name: 'teacher.tutoring.session-create' })
        "
      >
        + Sesi
      </button>
    </div>

    <div v-if="loading" class="py-16 text-center text-slate-500">Memuat…</div>
    <div v-else-if="error" class="rounded-xl border border-red-200 bg-red-50 p-6 text-center">
      <p class="text-red-700">{{ error }}</p>
      <button class="mt-3 text-sm font-semibold text-red-700 underline" @click="load">
        Coba lagi
      </button>
    </div>
    <p v-else-if="sessions.length === 0" class="py-12 text-center text-slate-500">
      Tidak ada sesi dalam rentang ini.
    </p>
    <ul v-else class="space-y-2.5">
      <li
        v-for="s in sessions"
        :key="s.id"
        class="flex items-center justify-between rounded-2xl border border-slate-200 p-4"
        :class="s.status === 'CANCELLED' ? 'opacity-60' : 'cursor-pointer hover:bg-slate-50'"
        @click="openAttendance(s)"
      >
        <div>
          <div class="font-bold text-slate-800">
            {{ s.scheduled_at ? formatDateShort(s.scheduled_at) : '—' }}
          </div>
          <div class="text-sm text-slate-500">
            {{
              [s.group?.name, s.topic, s.room ? 'Ruang ' + s.room : null]
                .filter(Boolean)
                .join(' · ')
            }}
          </div>
        </div>
        <span
          class="rounded-full px-2.5 py-1 text-[11px] font-bold"
          :class="statusClass(s.status)"
        >
          {{ s.status_label ?? s.status }}
        </span>
      </li>
    </ul>
  </div>
</template>
