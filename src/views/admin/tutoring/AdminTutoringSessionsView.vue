<!--
  AdminTutoringSessionsView — all tutoring sessions across the tenant.
  Adopts the BrandPageHeader + KpiStripCards + PageFilterToolbar chrome.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type { TutoringSession } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import SessionsCalendar from '@/components/feature/tutoring/SessionsCalendar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type Filter = 'all' | 'upcoming' | 'past';
type ViewMode = 'list' | 'calendar';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const sessions = ref<TutoringSession[]>([]);
const filter = ref<Filter>('all');
const view = ref<ViewMode>('list');
const showFilterPicker = ref(false);

const FILTER_OPTIONS: { key: Filter; label: string }[] = [
  { key: 'all', label: 'Semua' },
  { key: 'upcoming', label: 'Mendatang' },
  { key: 'past', label: 'Lampau' },
];

const activeFilterLabel = computed(
  () => FILTER_OPTIONS.find((o) => o.key === filter.value)?.label ?? 'Semua',
);

const filtered = computed(() => {
  const now = Date.now();
  return sessions.value
    .filter((s) => {
      if (filter.value === 'all') return true;
      const tt = s.scheduled_at ? new Date(s.scheduled_at).getTime() : 0;
      return filter.value === 'upcoming' ? tt > now : tt <= now;
    })
    .sort((a, b) => {
      const ad = a.scheduled_at ? new Date(a.scheduled_at).getTime() : 0;
      const bd = b.scheduled_at ? new Date(b.scheduled_at).getTime() : 0;
      return bd - ad;
    });
});

const upcomingCount = computed(() => {
  const now = Date.now();
  return sessions.value.filter((s) => {
    const tt = s.scheduled_at ? new Date(s.scheduled_at).getTime() : 0;
    return tt > now && s.status !== 'CANCELLED';
  }).length;
});
const doneCount = computed(
  () => sessions.value.filter((s) => s.status === 'DONE').length,
);
const cancelledCount = computed(
  () => sessions.value.filter((s) => s.status === 'CANCELLED').length,
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'calendar',
    label: 'Total sesi 60h',
    value: sessions.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'clock',
    label: 'Mendatang',
    value: upcomingCount.value,
    tone: 'violet',
  },
  {
    icon: 'check-circle',
    label: 'Selesai',
    value: doneCount.value,
    tone: 'green',
  },
  {
    icon: 'x-circle',
    label: 'Batal',
    value: cancelledCount.value,
    tone: cancelledCount.value > 0 ? 'red' : 'slate',
  },
]);

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
    // Admin-scoped route — same component as the tutor view, but the
    // router guard on `teacher.tutoring.attendance` is 'guru'-only.
    name: 'admin.tutoring.session-attendance',
    params: { sessionId: s.id },
    query: {
      groupId: s.group_id,
      title: s.scheduled_at
        ? formatDateShort(s.scheduled_at)
        : t('tutoring.attendance.title'),
    },
  });
}

function pickFilter(k: Filter) {
  filter.value = k;
  showFilterPicker.value = false;
}

onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Sesi"
      :title="t('tutoring.adminSessions.title')"
      :meta="`${sessions.length} sesi (60 hari) · ${upcomingCount} mendatang`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-panel text-bimbel-accent text-[13px] font-bold hover:bg-bimbel-panel/90"
      >
        <NavIcon name="download" :size="13" />
        Export
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          label="Rentang"
          :value="activeFilterLabel"
          icon-name="calendar"
          tone="violet"
          @click="showFilterPicker = true"
        />
      </template>
      <template #segmented>
        <div class="inline-flex p-1 bg-bimbel-bg border border-bimbel-border rounded-xl">
          <button
            type="button"
            class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition"
            :class="view === 'list'
              ? 'bg-bimbel-accent text-bimbel-ring'
              : 'text-bimbel-text-mid hover:text-bimbel-text-hi'"
            @click="view = 'list'"
          >
            <NavIcon name="list" :size="14" />
            List
          </button>
          <button
            type="button"
            class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition"
            :class="view === 'calendar'
              ? 'bg-bimbel-accent text-bimbel-ring'
              : 'text-bimbel-text-mid hover:text-bimbel-text-hi'"
            @click="view = 'calendar'"
          >
            <NavIcon name="calendar" :size="14" />
            Kalender
          </button>
        </div>
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>

    <!-- Calendar view ─ entire tenant's sessions on a month grid -->
    <SessionsCalendar
      v-else-if="view === 'calendar'"
      :sessions="sessions"
      accent="admin"
      :on-open="openAttendance"
    />

    <TutoringEmpty
      v-else-if="filtered.length === 0"
      :text="t('tutoring.adminSessions.empty')"
      icon="calendar"
    />
    <div
      v-else
      class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-bimbel-text-mid">
          <tr class="border-b border-bimbel-border">
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
            class="border-b border-bimbel-border-soft last:border-0 hover:bg-bimbel-bg cursor-pointer"
            :class="s.status === 'CANCELLED' ? 'opacity-60' : ''"
            @click="openAttendance(s)"
          >
            <td class="px-3 py-3 font-semibold text-bimbel-text-hi">
              {{ s.scheduled_at ? formatDateShort(s.scheduled_at) : '—' }}
            </td>
            <td class="px-3 py-3 text-bimbel-text-mid">
              {{ s.group?.name ?? s.group?.program?.name ?? '—' }}
            </td>
            <td class="px-3 py-3 text-bimbel-text-mid">{{ s.tutor?.name ?? '—' }}</td>
            <td class="px-3 py-3 text-bimbel-text-mid">
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
              <button
                type="button"
                class="inline-flex items-center gap-1 rounded-md border border-bimbel-border px-2 py-1 text-[12px] font-bold text-bimbel-accent hover:bg-bimbel-accent/5 disabled:opacity-40 disabled:cursor-not-allowed"
                :disabled="s.status === 'CANCELLED'"
                :title="s.status === 'CANCELLED' ? 'Sesi dibatalkan' : 'Lihat / catat kehadiran'"
                @click.stop="openAttendance(s)"
              >
                <NavIcon name="check-circle" :size="12" />
                Kehadiran
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal
      v-if="showFilterPicker"
      title="Filter Rentang"
      @close="showFilterPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in FILTER_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-bimbel-bg"
            :class="{ 'bg-bimbel-accent/5 text-bimbel-accent font-bold': filter === o.key }"
            @click="pickFilter(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
