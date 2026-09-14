<!--
  TutorTutoring2SessionsView.vue — Tutor bimbel session list (WEB-4).

  Mirrors TutorTutoring2HomeView.vue composition:
    1. BrandPageHeader        — role="teacher".
    2. KpiStripCards          — 4 tiles (Total, Hari ini, Selesai, Akan datang).
    3. PageFilterToolbar      — Status + Periode chips, each opening a
                                <FilterFacetPickerModal>.
    4. AsyncView              — day-grouped list of the tutor's sessions.

  Backend filtering: `TutoringBimbelService.listSessions` infers the
  tutor from the active-role token, so no explicit `tutor_id` param is
  passed. Status filter is server-side; periode is a client-side window
  over `starts_at`.

  ── Why the chips open a picker ──

  Both chips shipped wired straight to a `cycle*()` handler: one press
  advanced the filter to the NEXT value in a hardcoded order. Nothing
  ever listed what the filter COULD be set to, which is what a tutor
  reported from prod — "filter status dan periodenya tidak memunculkan
  dropdown list pilihan filter yang dapat dipilih". <AppFilterChip> has
  no menu of its own; where a page wants a real choice the chip must
  open a <FilterFacetPickerModal>, the same per-facet picker the
  Manajemen Data screens and the admin twin of this screen already use.

  Cycling also hid a genuinely unreachable value. The old `statusFilter`
  union was `'' | 'scheduled' | 'done' | 'cancelled'` — it simply left
  out `in_progress`, which IS one of the four `BimbelSession['status']`
  states the API returns and the `status` parameter accepts. No number
  of presses could ask for it. The list is now built from
  `BIMBEL_SESSION_STATUSES`, the runtime spelling of that union, so it
  cannot drift out of step again.
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
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import {
  bimbelSessionStatusLabel,
  bimbelSessionStatusTone,
  bimbelStatusLabel,
} from '@/lib/bimbel-session-status';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  BIMBEL_SESSION_STATUSES,
  TutoringBimbelService,
  type BimbelSession,
  type BimbelSessionStatus,
} from '@/services/tutoring-bimbel.service';
import { bimbelGroupLabel } from '@/lib/bimbel-session-label';

const { t } = useI18n();
const router = useRouter();

// ── Filters ───────────────────────────────────────────────────────
type PeriodeFilter = '' | 'week' | 'month';

const search = ref('');
const statusFilter = ref<'' | BimbelSessionStatus>('');
const periodeFilter = ref<PeriodeFilter>('');

const showStatusPicker = ref(false);
const showPeriodePicker = ref(false);

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
      // The group NAME belongs in the haystack: the toolbar invites
      // "Cari grup…", and a tutor types the name they can see, not the
      // UUID they cannot. Searching "UTBK" used to match nothing.
      //
      // The id STAYS alongside it, deliberately. Admins and support do
      // paste a session/group id out of a ticket to find one row, and
      // dropping the id would turn today's silent miss into a different
      // silent miss. An 8-char hex fragment cannot realistically collide
      // with a typed group name, so keeping both costs nothing.
      const hay = `${s.learning_group_name ?? ''} ${s.learning_group_id} ${s.room ?? ''} ${s.tutor_note ?? ''}`.toLowerCase();
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

function sessionTone(s: BimbelSession): StatusBadgeTone {
  return bimbelSessionStatusTone(s);
}

function statusLabel(s: BimbelSession): string {
  return bimbelSessionStatusLabel(s, t);
}

function openDetail(id: string) {
  router.push({ name: 'teacher.tutoring2.session-detail', params: { id } });
}

// ── Filter facets ───────────────────────────────────────
/**
 * Every status the `status` query parameter accepts, labelled.
 *
 * Derived from BIMBEL_SESSION_STATUSES rather than hand-listed, so it
 * cannot drift from `BimbelSession['status']` — which is exactly how
 * `in_progress` came to be missing from the old cycle order.
 *
 * `bimbelStatusLabel` is the right helper here, not
 * `bimbelSessionStatusLabel`: a picker lists STATUSES, not sessions, so
 * there is no `ends_at` to derive "Terlewat" from. Terlewat is
 * deliberately absent — it is a display-only state the wire cannot be
 * asked for, and offering it would build a filter that returns nothing.
 */
const statusOptions = computed<FacetOption[]>(() =>
  BIMBEL_SESSION_STATUSES.map((value) => ({
    key: value,
    label: bimbelStatusLabel(value, t),
  })),
);

/**
 * The periode window, worded the way `filteredSessions` applies it:
 * from now FORWARD, not a calendar week or month.
 */
const periodeOptions = computed<FacetOption[]>(() => [
  { key: 'week', label: t('tutoring2.common.next7Days') },
  { key: 'month', label: t('tutoring2.common.next30Days') },
]);

/** Label for the current selection — never the raw wire enum. */
function chipValue(selected: string, options: FacetOption[]): string {
  if (!selected) return t('tutoring2.common.all');
  return options.find((o) => o.key === selected)?.label ?? selected;
}

const statusChipValue = computed(() =>
  chipValue(statusFilter.value, statusOptions.value),
);

const periodeChipValue = computed(() =>
  chipValue(periodeFilter.value, periodeOptions.value),
);

/**
 * The picker emits a bare string; these refs hold narrower unions.
 * Narrowing here rather than casting in the template means a key that
 * stops being valid fails the type-check instead of reaching the query.
 */
function applyStatusFilter(value: string) {
  statusFilter.value = (BIMBEL_SESSION_STATUSES as string[]).includes(value)
    ? (value as BimbelSessionStatus)
    : '';
}

function applyPeriodeFilter(value: string) {
  periodeFilter.value = value === 'week' || value === 'month' ? value : '';
}
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
          @click="showStatusPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.period')"
          :value="periodeChipValue"
          icon-name="calendar"
          :active="!!periodeFilter"
          @click="showPeriodePicker = true"
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
                    <!-- Name, not id. `learning_group_name` is already on
                         this very row; the old expression had no `??` in
                         it and printed the UUID unconditionally. -->
                    <p class="truncate text-sm font-bold text-slate-900">
                      {{ bimbelGroupLabel(s, t('tutoring2.common.group')) }}
                    </p>
                    <p class="truncate text-2xs text-slate-500">
                      {{ s.room ?? t('tutoring2.common.noRoom') }}
                    </p>
                  </div>
                  <StatusBadge
                    :label="statusLabel(s)"
                    :tone="sessionTone(s)"
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

  <!-- Per-facet pickers. Each writes its ref; the `watch` above does the
       reload for status, and `filteredSessions` recomputes for periode,
       so neither handler calls anything itself. -->
  <FilterFacetPickerModal
    v-if="showStatusPicker"
    :title="t('tutoring2.common.status')"
    :options="statusOptions"
    :selected="statusFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showStatusPicker = false"
    @apply="applyStatusFilter"
  />
  <FilterFacetPickerModal
    v-if="showPeriodePicker"
    :title="t('tutoring2.common.period')"
    :options="periodeOptions"
    :selected="periodeFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showPeriodePicker = false"
    @apply="applyPeriodeFilter"
  />
</template>
