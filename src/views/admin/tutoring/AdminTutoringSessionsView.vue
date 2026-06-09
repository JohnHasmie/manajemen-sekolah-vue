<!--
  AdminTutoringSessionsView — all tutoring sessions across the tenant.
  Web-side renders as a table (better at scale) with the shared chip
  filter row + status pills.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type { TutoringSession } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringChipsRow from '@/components/feature/tutoring/TutoringChipsRow.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type Filter = 'all' | 'upcoming' | 'past';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const sessions = ref<TutoringSession[]>([]);
const filter = ref<Filter>('all');

const filtered = computed(() => {
  const now = Date.now();
  return sessions.value
    .filter((s) => {
      if (filter.value === 'all') return true;
      const t = s.scheduled_at ? new Date(s.scheduled_at).getTime() : 0;
      return filter.value === 'upcoming' ? t > now : t <= now;
    })
    .sort((a, b) => {
      const ad = a.scheduled_at ? new Date(a.scheduled_at).getTime() : 0;
      const bd = b.scheduled_at ? new Date(b.scheduled_at).getTime() : 0;
      return bd - ad;
    });
});

async function load() {
  loading.value = true;
  try {
    const now = new Date();
    const from = new Date(now.getTime() - 30 * 24 * 3600 * 1000);
    const to = new Date(now.getTime() + 30 * 24 * 3600 * 1000);
    sessions.value = await TutoringService.getAllSessions(from, to);
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.sessions.loadFailed'),
    );
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

const chipOptions: { value: Filter; label: string }[] = [
  { value: 'all', label: 'Semua' },
  { value: 'upcoming', label: 'Mendatang' },
  { value: 'past', label: 'Lampau' },
];
</script>

<template>
  <div class="mx-auto max-w-5xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.adminSessions.title')"
      crumbs="Bimbel · Sesi"
    >
      <template #right>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-white border border-slate-200 hover:border-slate-300 rounded-lg px-3 py-1.5 text-xs font-semibold text-slate-700"
        >
          <NavIcon name="download" :size="14" />
          Export
        </button>
      </template>
    </TutoringPageHeader>

    <TutoringChipsRow
      v-model="filter"
      :options="chipOptions"
      class="mb-3"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="filtered.length === 0"
      :text="t('tutoring.adminSessions.empty')"
      icon="calendar"
    />
    <div
      v-else
      class="bg-white border border-slate-100 rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-slate-500">
          <tr class="border-b border-slate-200">
            <th class="text-left font-bold px-3 py-2.5">Waktu</th>
            <th class="text-left font-bold px-3 py-2.5">Kelompok</th>
            <th class="text-left font-bold px-3 py-2.5">Tutor</th>
            <th class="text-left font-bold px-3 py-2.5">Topik / Ruang</th>
            <th class="text-left font-bold px-3 py-2.5">Status</th>
            <th class="px-3 py-2.5"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="s in filtered"
            :key="s.id"
            class="border-b border-slate-100 last:border-0 hover:bg-slate-50 cursor-pointer"
            :class="s.status === 'CANCELLED' ? 'opacity-60' : ''"
            @click="openAttendance(s)"
          >
            <td class="px-3 py-3 font-semibold text-slate-900">
              {{ s.scheduled_at ? formatDateShort(s.scheduled_at) : '—' }}
            </td>
            <td class="px-3 py-3 text-slate-700">
              {{ s.group?.name ?? s.group?.program?.name ?? '—' }}
            </td>
            <td class="px-3 py-3 text-slate-700">{{ s.tutor?.name ?? '—' }}</td>
            <td class="px-3 py-3 text-slate-700">
              {{
                [s.topic, s.room ? t('tutoring.sessions.room') + ' ' + s.room : null]
                  .filter(Boolean)
                  .join(' · ') || '—'
              }}
            </td>
            <td class="px-3 py-3">
              <TutoringStatusPill :session="s.status" />
            </td>
            <td class="px-3 py-3 text-right">
              <NavIcon name="chevron-right" :size="14" class="text-slate-400" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
