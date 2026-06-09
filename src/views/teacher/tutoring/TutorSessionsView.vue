<!--
  TutorSessionsView — the tutor's own bimbel sessions (−7d..+14d). Tap a
  session to record attendance. Rebuilt on the tutoring shared
  components with the teacher (cobalt) accent.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import { formatDateShort } from '@/lib/format';
import type { TutoringSession } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();
const loading = ref(true);
const error = ref<string | null>(null);
const sessions = ref<TutoringSession[]>([]);

async function load() {
  const tutorId = auth.user?.id;
  if (!tutorId) {
    error.value = t('tutoring.sessions.cannotIdentify');
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
    error.value =
      e instanceof Error ? e.message : t('tutoring.sessions.loadFailed');
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
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.sessions.title')"
      crumbs="Bimbel · Sesi Saya"
    >
      <template #right>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-role-teacher hover:bg-role-teacher/90 text-white rounded-xl px-3.5 py-2 text-sm font-semibold"
          @click="router.push({ name: 'teacher.tutoring.session-create' })"
        >
          <NavIcon name="plus" :size="14" />
          {{ t('tutoring.sessions.addBtn') }}
        </button>
      </template>
    </TutoringPageHeader>

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="error"
      :text="error"
      icon="alert-circle"
    />
    <TutoringEmpty
      v-else-if="sessions.length === 0"
      :text="t('tutoring.sessions.empty')"
      icon="calendar"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="s in sessions"
        :key="s.id"
        icon="calendar"
        accent="tutor"
        :title="s.scheduled_at ? formatDateShort(s.scheduled_at) : '—'"
        :subtitle="
          [
            s.group?.name,
            s.topic,
            s.room ? t('tutoring.sessions.room') + ' ' + s.room : null,
          ]
            .filter(Boolean)
            .join(' · ')
        "
        :to="s.status === 'CANCELLED' ? null : () => openAttendance(s)"
      >
        <template #trailing>
          <TutoringStatusPill :session="s.status" />
        </template>
      </TutoringListTile>
    </div>
  </div>
</template>
