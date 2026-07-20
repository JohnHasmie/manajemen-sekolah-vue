<!--
  TutorTutoring2SessionsView.vue — Tutor bimbel session list (WEB-4).

  Mirrors TutorTutoring2HomeView.vue composition:
    1. BrandPageHeader        — role="teacher".
    2. KpiStripCards          — 4 tiles (Total, Hari ini, Selesai, Akan datang).
    3. PageFilterToolbar      — status + periode chips (periode is UI-only
                                until the backend gains a `period` param).
    4. AsyncView              — day-grouped list of the tutor's sessions.

  Backend filtering: `TutoringBimbelService.listSessions` infers the
  tutor from the active-role token, so no explicit `tutor_id` param is
  passed. Status filter is server-side; periode is client-side today.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();

// ── Filters ───────────────────────────────────────────────────────
const search = ref('');
const statusFilter = ref<'' | 'scheduled' | 'done' | 'cancelled'>('');
const periodeFilter = ref<'' | 'week' | 'month'>('');

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

// ── Data ──────────────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 100,
    status: statusFilter.value || undefined,
  });
  return items;
});

watch([statusFilter], () => reload());
useAcademicYearWatcher(reload);

// ── Derived (client-side filters) ─────────────────────────────────
const allSessions = computed<BimbelSession[]>(() => {
  return state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as BimbelSession[] | undefined) ?? [])
    : [];
});

const filteredSessions = computed<BimbelSession[]>(() => {
  const q = debouncedSearch.value.trim().toLowerCase();
  const now = new Date();
  const windowMs =
    periodeFilter.value === 'week'
      ? 7 * 24 * 3600 * 1000
      : periodeFilter.value === 'month'
      ? 30 * 24 * 3600 * 1000
      : null;
  return allSessions.value.filter((s) => {
    if (q) {
      const hay = `${s.learning_group_id} ${s.room ?? ''} ${s.tutor_note ?? ''}`.toLowerCase();
      if (!hay.includes(q)) return false;
    }
    if (windowMs != null) {
      const ts = new Date(s.starts_at).getTime();
      if (ts < now.getTime() || ts > now.getTime() + windowMs) return false;
    }
    return true;
  });
});

// ── KPIs ─────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const items = allSessions.value;
  const todayKey = new Date().toLocaleDateString('en-CA');
  const todayCount = items.filter((s) => sessionDateKey(s.starts_at) === todayKey).length;
  const doneCount = items.filter((s) => s.status === 'done').length;
  const upcomingCount = items.filter((s) => s.status === 'scheduled').length;
  return [
    { icon: 'calendar', label: t('tutoring2.tutor.sessions.kpiTotal'), value: String(items.length) },
    { icon: 'sun', label: t('tutoring2.tutor.sessions.kpiToday'), value: String(todayCount), tone: 'brand' },
    { icon: 'check-circle', label: t('tutoring2.tutor.sessions.kpiDone'), value: String(doneCount), tone: 'green' },
    { icon: 'clock', label: t('tutoring2.tutor.sessions.kpiUpcoming'), value: String(upcomingCount), tone: 'amber' },
  ];
});

// ── Day grouping ─────────────────────────────────────────────────
interface DayGroup {
  key: string;
  label: string;
  sessions: BimbelSession[];
}

function sessionDateKey(iso: string): string {
  const d = new Date(iso);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function formatDayHeader(iso: string): string {
  return new Date(iso).toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
  });
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

const grouped = computed<DayGroup[]>(() => {
  const map = new Map<string, DayGroup>();
  for (const s of filteredSessions.value) {
    const key = sessionDateKey(s.starts_at);
    let g = map.get(key);
    if (!g) {
      g = { key, label: formatDayHeader(s.starts_at), sessions: [] };
      map.set(key, g);
    }
    g.sessions.push(s);
  }
  return Array.from(map.values())
    .sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0))
    .map((g) => ({
      ...g,
      sessions: g.sessions.sort((a, b) => a.starts_at.localeCompare(b.starts_at)),
    }));
});

function sessionTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'done':
      return 'success';
    case 'in_progress':
      return 'info';
    case 'scheduled':
      return 'neutral';
    case 'cancelled':
      return 'danger';
  }
}

function statusLabel(status: BimbelSession['status']): string {
  return t(`tutoring2.status.${status === 'in_progress' ? 'inProgress' : status}`);
}

function openDetail(id: string) {
  router.push({ name: 'teacher.tutoring2.session-detail', params: { id } });
}

function cycleStatus() {
  const order: Array<'' | 'scheduled' | 'done' | 'cancelled'> = [
    '',
    'scheduled',
    'done',
    'cancelled',
  ];
  const i = order.indexOf(statusFilter.value);
  statusFilter.value = order[(i + 1) % order.length];
}

function cyclePeriode() {
  const order: Array<'' | 'week' | 'month'> = ['', 'week', 'month'];
  const i = order.indexOf(periodeFilter.value);
  periodeFilter.value = order[(i + 1) % order.length];
}

const statusChipValue = computed(() => {
  switch (statusFilter.value) {
    case 'scheduled':
      return t('tutoring2.status.scheduled');
    case 'done':
      return t('tutoring2.status.done');
    case 'cancelled':
      return t('tutoring2.status.cancelled');
    default:
      return t('tutoring2.common.all');
  }
});

// TODO i18n key: periode chip values "7 hari" / "30 hari"
const periodeChipValue = computed(() => {
  switch (periodeFilter.value) {
    case 'week':
      return '7 hari';
    case 'month':
      return '30 hari';
    default:
      return t('tutoring2.common.all');
  }
});
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.sessions.title')"
      :meta="state.status === 'loading' ? t('tutoring2.common.loading') : t('tutoring2.tutor.sessions.meta', { count: filteredSessions.length })"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <!-- TODO i18n key: search placeholder "Cari grup, ruang, catatan…" -->
    <PageFilterToolbar v-model:search="search" search-placeholder="Cari grup, ruang, catatan…">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusChipValue"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="cycleStatus"
        />
        <!-- TODO i18n key: chip label "Periode" -->
        <AppFilterChip
          label="Periode"
          :value="periodeChipValue"
          icon-name="calendar"
          :active="!!periodeFilter"
          @click="cyclePeriode"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="4"
      :empty-title="t('tutoring2.tutor.sessions.emptyTitle')"
      empty-description="Sesi untuk Anda belum dijadwalkan. Hubungi admin bimbel."
      @retry="reload"
    >
      <!-- TODO i18n key: sessions empty-description -->
      <template #default>
        <!-- TODO i18n key: "Tidak ada sesi yang cocok dengan filter." -->
        <div v-if="grouped.length === 0" class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-sm text-slate-500 shadow-sm">
          Tidak ada sesi yang cocok dengan filter.
        </div>
        <div v-else class="space-y-md">
          <section v-for="group in grouped" :key="group.key" class="space-y-sm">
            <h3 class="px-1 text-2xs font-bold uppercase tracking-wide text-slate-500">
              {{ group.label }}
            </h3>
            <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
              <ul class="divide-y divide-slate-100">
                <li
                  v-for="s in group.sessions"
                  :key="s.id"
                  class="flex items-center gap-3 px-4 py-3 hover:bg-slate-50"
                >
                  <div class="w-14 shrink-0 text-center">
                    <span class="text-sm font-bold text-brand-cobalt">{{ formatTime(s.starts_at) }}</span>
                  </div>
                  <div class="min-w-0 flex-1">
                    <!-- TODO i18n key: "Grup {short-id}" prefix noun -->
                    <p class="truncate text-sm font-bold text-slate-900">
                      {{ t('tutoring2.common.group') }} {{ s.learning_group_id.slice(0, 8) }}
                    </p>
                    <!-- TODO i18n key: "Tanpa ruang" fallback -->
                    <p class="truncate text-2xs text-slate-500">
                      {{ s.room ?? 'Tanpa ruang' }}
                    </p>
                  </div>
                  <StatusBadge
                    :label="s.status_label ?? statusLabel(s.status)"
                    :tone="sessionTone(s.status)"
                    uppercase
                  />
                  <Button variant="secondary" size="sm" @click="openDetail(s.id)">
                    {{ t('tutoring2.common.detail') }}
                  </Button>
                </li>
              </ul>
            </div>
          </section>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
