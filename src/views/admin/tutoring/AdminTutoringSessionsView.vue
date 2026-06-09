<!--
  AdminTutoringSessionsView — all tutoring sessions across the tenant
  (−30d..+30d). Web mirror of the Flutter TutoringAdminSessionsScreen.
  Tapping a session opens the attendance roster.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type { TutoringSession } from '@/types/tutoring';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const sessions = ref<TutoringSession[]>([]);

function statusClass(status: string): string {
  if (status === 'DONE') return 'bg-emerald-100 text-emerald-800';
  if (status === 'CANCELLED') return 'bg-red-100 text-red-800';
  return 'bg-indigo-100 text-indigo-800';
}

async function load() {
  loading.value = true;
  try {
    const now = new Date();
    const from = new Date(now.getTime() - 30 * 24 * 3600 * 1000);
    const to = new Date(now.getTime() + 30 * 24 * 3600 * 1000);
    const list = await TutoringService.getAllSessions(from, to);
    sessions.value = list.sort((a, b) => {
      const ad = a.scheduled_at ? new Date(a.scheduled_at).getTime() : 0;
      const bd = b.scheduled_at ? new Date(b.scheduled_at).getTime() : 0;
      return bd - ad;
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.sessions.loadFailed'));
  } finally {
    loading.value = false;
  }
}

function openAttendance(s: TutoringSession) {
  if (s.status === 'CANCELLED') return;
  router.push({
    name: 'teacher.tutoring.attendance',
    params: { sessionId: s.id },
    query: {
      groupId: s.group_id,
      title: s.scheduled_at
        ? formatDateShort(s.scheduled_at)
        : t('tutoring.attendance.title'),
    },
  });
}

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">
      {{ t('tutoring.adminSessions.title') }}
    </h1>

    <div v-if="loading" class="py-16 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <p v-else-if="sessions.length === 0" class="py-12 text-center text-slate-500">
      {{ t('tutoring.adminSessions.empty') }}
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
              [
                s.group?.name ?? s.group?.program?.name,
                s.tutor?.name,
                s.topic,
                s.room ? t('tutoring.sessions.room') + ' ' + s.room : null,
              ]
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
