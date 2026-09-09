<!--
  AdminTutoring2JadwalView.vue — greenfield "Jadwal sesi" list.

  Sibling to AdminTutoring2ProgramsView (the WEB-3 exemplar); same
  composition contract top→bottom:

    1. `BrandPageHeader` — role="admin", gradient tier header.
    2. `KpiStripCards` — 4 tiles.
    3. `PageFilterToolbar` — search + `AppFilterChip`s.
    4. `AsyncView` state machine over `TutoringBimbelService.listSessions`.
    5. Floating "+ Buat sesi" CTA.

  The Status / Kelompok / Tutor chips each open a
  <FilterFacetPickerModal>, the same per-facet picker the Manajemen Data
  screens use. They previously only ever CLEARED their filter
  (`@click="x = ''"`) with no menu behind them, so they were inert on
  prod ("semua button/filter tdk berfungsi") even though the query +
  watcher below were wired correctly all along. Same fix as
  AdminTutoring2GroupsView (!1191).

  Status was left behind by that pass and stayed broken after the screen
  was reported fixed: its handler was
  `statusFilter = statusFilter ? '' : 'scheduled'` — a TWO-value toggle
  over a FOUR-value lifecycle, so "Berlangsung", "Selesai" and
  "Dibatalkan" were unreachable no matter how often the chip was
  pressed — and the chip printed the raw enum (`scheduled`) rather than
  a label. It now renders BIMBEL_SESSION_STATUSES, the runtime spelling
  of the canonical `BimbelSession['status']` union, through the same
  picker and the same `chipValue()` label resolver as its siblings.

  The floating "+ Buat sesi" CTA in slot 5 was the SAME bug one layer
  down: the docblock above advertised it, the i18n label existed, and
  the button rendered — but it carried no `@click` whatsoever, so prod
  reported "tombol diklik tidak terjadi apa-apa". It now navigates to
  `admin.tutoring2.session-create`.

  That route renders <Tutoring2CreateSessionView>, the create surface
  that already existed and already worked — it was simply parked behind
  `meta: { role: 'teacher' }` where no admin could reach it. It was
  lifted to `views/tutoring2/` and given a second, admin-scoped route
  rather than copied, so both roles POST through one component. See its
  docblock for why nothing in that form is tutor-specific.

  (That tutor route has no entry point of its own either — nothing
  navigates to it — so this CTA is the form's first real doorway in the
  UI. Whether the tutor screen should get its own button was left open
  here; it has since been decided AGAINST — `tutorTutoringDefaults()`
  withholds `tutoring.session.manage`, so a tutor's submit would 403.
  The tutor route carries this same ability gate now instead. See
  Tutoring2CreateSessionView's docblock for the full argument.)

  Gate: `tutoring.session.manage`, read off the /me snapshot via
  `useMe().can` (NEVER `roles[].permission_keys`). Missing ability
  hides the CTA outright, matching AdminTutoring2GroupsView — an admin
  never sees a button that would refuse them.

  ── `?date=YYYY-MM-DD` — the Laporan Aktivitas drill-in ──────────────

  This screen is the destination of a row click on
  AdminTutoring2ActivityReportView. A report row is a calendar DAY (the
  rollup groups by `starts_at::date` and the row carries no id), so
  "open the row" can only mean "the sessions on that day" — which is
  this list, narrowed.

  Nothing new was built for it. `SessionController::index` has always
  supported the narrowing:

      ->when($request->filled('from'), … where('starts_at', '>=', from))
      ->when($request->filled('to'),   … where('starts_at', '<',  to))

  and `TutoringBimbelService.listSessions` has always declared
  `from?: string; to?: string`. Both were simply unused — this screen
  passed neither. All that was missing was a caller.

  Note `to` is EXCLUSIVE (`<`, not `<=`). One day D is therefore
  `[D, D+1)`, and `D+1` comes from `addDays()` — the local-calendar
  helper — never from `new Date(D)` + `toISOString().slice(0, 10)`,
  which round-trips through UTC and hands a WIB reader the wrong day.
  That bound matches the report's `starts_at::date = D` bucketing
  exactly, so the two screens cannot disagree about which sessions
  belong to the day.

  A malformed `?date=` is dropped rather than forwarded: an unparseable
  value would otherwise reach the API as a filter nothing can match and
  render as "no sessions" — a lie about the data instead of a visibly
  ignored parameter.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { addDays, formatYmdLabel, isValidYmd } from '@/lib/local-date';
import {
  BIMBEL_SESSION_STATUSES,
  TutoringBimbelService,
  type BimbelLearningGroup,
  type BimbelSession,
  type BimbelSessionStatus,
} from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { Tutor } from '@/types/tutoring2/tutor';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

const { can } = useMe();
const canManage = computed(() => can('tutoring.session.manage'));

/** Opens the shared create surface — see the docblock above. */
function openCreate() {
  router.push({ name: 'admin.tutoring2.session-create' });
}

/**
 * Opens one session's detail.
 *
 * Deliberately NOT gated on `tutoring.session.manage`: the detail is a
 * read surface (`SessionController::show` authorizes on
 * `tutoring.session.view`), and only the edit control inside it is a
 * write. Gating the row would hide a session's room, tutor and notes
 * from a staff tier that is entitled to read them.
 */
function openDetail(id: string) {
  router.push({ name: 'admin.tutoring2.session.detail', params: { id } });
}

/**
 * The day this list is narrowed to, or '' for "every day".
 *
 * Seeded from `?date=` so the Laporan Aktivitas drill-in survives a
 * refresh and a shared link, and validated on the way in — see the
 * docblock on why a malformed value is dropped rather than forwarded.
 */
function readDateQuery(): string {
  const raw = route.query.date;
  const value = Array.isArray(raw) ? raw[0] : raw;
  return typeof value === 'string' && isValidYmd(value) ? value : '';
}

const dateFilter = ref<string>(readDateQuery());

/** Human label for the context bar — "9 September 2026", built locally. */
const dateFilterLabel = computed(() => formatYmdLabel(dateFilter.value));

/**
 * Back to every day.
 *
 * Also strips `date` off the URL, so a refresh (or the browser Back
 * button landing here again) does not silently re-apply a filter the
 * reader just dismissed. `replace`, not `push`: dismissing a filter is
 * not a place in history worth returning to.
 */
function clearDateFilter() {
  dateFilter.value = '';
  const { date: _dropped, ...rest } = route.query;
  router.replace({ name: 'admin.tutoring2.schedule', query: rest });
}

/**
 * Follow the URL when it changes underneath us — a second drill-in from
 * the report, or Back/Forward between two days, reuses this same mounted
 * component and would otherwise keep showing the first day's sessions.
 */
watch(
  () => route.query.date,
  () => {
    dateFilter.value = readDateQuery();
  },
);

const search = ref('');
// '' = "Semua". Typed against the canonical union rather than a bare
// string, so a value the API has no status for cannot be assigned here.
const statusFilter = ref<'' | BimbelSessionStatus>('');
const groupFilter = ref<string>('');  // '' | learning_group_id
const tutorFilter = ref<string>('');  // '' | tutor_id
const periodFilter = ref<'all' | 'week' | 'month'>('all'); // nominal, UI-only

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 100,
    status: statusFilter.value || undefined,
    learning_group_id: groupFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
    // [D, D+1) — `to` is exclusive server-side (`starts_at < to`).
    from: dateFilter.value || undefined,
    to: dateFilter.value ? addDays(dateFilter.value, 1) : undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter, groupFilter, tutorFilter, periodFilter, dateFilter], () => reload());

// ── Facet option lists ─────────────────────────────────────────────
// Both id-valued chips need the id→name list their picker renders.
const groups = ref<BimbelLearningGroup[]>([]);
const tutors = ref<Tutor[]>([]);

const showStatusPicker = ref(false);
const showGroupPicker = ref(false);
const showTutorPicker = ref(false);

/**
 * Every lifecycle state, labelled. Built from BIMBEL_SESSION_STATUSES so
 * the list cannot drift from the union the API actually returns: a
 * status added server-side appears here the moment the type is updated,
 * instead of silently becoming unfilterable the way `in_progress`,
 * `done` and `cancelled` already were.
 *
 * `statusLabel` is a hoisted function declaration further down; this
 * getter only runs once the chip renders.
 */
const statusOptions = computed<FacetOption[]>(() =>
  BIMBEL_SESSION_STATUSES.map((s) => ({ key: s, label: statusLabel(s) })),
);

const groupOptions = computed<FacetOption[]>(() =>
  groups.value.map((g) => ({
    key: g.id,
    label: g.name,
    meta: g.program_name ?? undefined,
  })),
);
// `tu`, not `t` — the i18n `t` is in scope and must not be shadowed.
const tutorOptions = computed<FacetOption[]>(() =>
  tutors.value.map((tu) => ({ key: tu.id, label: tu.name })),
);

/**
 * Load both option lists once, tolerantly: they are independent, so one
 * endpoint failing (or being ability-gated off) must not blank the other
 * chip. A list that stays empty leaves its own chip disabled rather than
 * opening a picker with nothing to pick — that would be the same lie in
 * a new shape.
 */
async function loadFacetOptions() {
  const [groupRes, tutorRes] = await Promise.allSettled([
    TutoringBimbelService.listGroups({ per_page: 200 }),
    TutoringTutorsService.list({ per_page: 200 }),
  ]);
  if (groupRes.status === 'fulfilled') groups.value = groupRes.value.items;
  if (tutorRes.status === 'fulfilled') tutors.value = tutorRes.value.items;
}

onMounted(loadFacetOptions);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelSession[];
  const scheduled = items.filter((s) => s.status === 'scheduled').length;
  const inProgress = items.filter((s) => s.status === 'in_progress').length;
  const done = items.filter((s) => s.status === 'done').length;
  const cancelled = items.filter((s) => s.status === 'cancelled').length;
  return [
    { icon: 'calendar', label: t('tutoring2.admin.schedule.kpiScheduled'), value: String(scheduled) },
    { icon: 'play', label: t('tutoring2.admin.schedule.kpiInProgress'), value: String(inProgress), tone: inProgress > 0 ? 'amber' : undefined },
    { icon: 'circle-check', label: t('tutoring2.admin.schedule.kpiDone'), value: String(done) },
    { icon: 'x', label: t('tutoring2.admin.schedule.kpiCancelled'), value: String(cancelled), tone: cancelled > 0 ? 'amber' : undefined },
  ];
});

function statusLabel(status: BimbelSession['status']): string {
  const key = status === 'in_progress' ? 'inProgress' : status;
  return t(`tutoring2.status.${key}`);
}

function statusPillTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'scheduled': return 'neutral';
    case 'in_progress': return 'info';
    case 'done': return 'success';
    case 'cancelled': return 'danger';
  }
}

function formatWaktu(iso: string): string {
  return new Date(iso).toLocaleString('id-ID', { weekday: 'short', hour: '2-digit', minute: '2-digit' });
}

function truncateId(id: string | null | undefined, len = 8): string {
  if (!id) return '—';
  return id.length > len ? id.slice(0, len) : id;
}

/**
 * What a filter chip reads: the picked option's NAME, or "Semua" when the
 * facet is unset.
 *
 * Falls back to `truncateId` only when the id is genuinely not in the
 * loaded list (options still in flight, or the row was archived away). An
 * id fragment is ugly but honest there — "—" on a chip that is visibly
 * ACTIVE would read as "no filter applied", which is the failure this
 * screen just came out of.
 */
function chipValue(id: string, options: FacetOption[]): string {
  if (!id) return t('tutoring2.common.all');
  return options.find((o) => o.key === id)?.label ?? truncateId(id);
}

/**
 * The picker emits a bare string; `statusFilter` is the narrower
 * `'' | BimbelSessionStatus`. Narrow here rather than casting in the
 * template, so an option key that stops being a valid status fails
 * closed to "Semua" instead of pinning the list to a value the backend
 * can never match.
 */
function applyStatusFilter(v: string) {
  statusFilter.value = (BIMBEL_SESSION_STATUSES as string[]).includes(v)
    ? (v as BimbelSessionStatus)
    : '';
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.schedule.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaSessionsWeek', { count: (state.data as BimbelSession[]).length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.schedule.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="chipValue(statusFilter, statusOptions)"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="showStatusPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.group')"
          :value="chipValue(groupFilter, groupOptions)"
          icon-name="users"
          :active="!!groupFilter"
          :disabled="groupOptions.length === 0"
          :title="groupOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showGroupPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.tutor')"
          :value="chipValue(tutorFilter, tutorOptions)"
          icon-name="user"
          :active="!!tutorFilter"
          :disabled="tutorOptions.length === 0"
          :title="tutorOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showTutorPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.period')"
          :value="periodFilter === 'all' ? t('tutoring2.common.all') : periodFilter === 'week' ? t('tutoring2.common.thisWeek') : t('tutoring2.common.thisMonth')"
          icon-name="calendar"
          :active="periodFilter !== 'all'"
          @click="periodFilter = periodFilter === 'all' ? 'week' : periodFilter === 'week' ? 'month' : 'all'"
        />
      </template>
    </PageFilterToolbar>

    <!--
      Context bar for the drill-in, rendered only while a day is
      actually applied. Deliberately NOT an <AppFilterChip>: that chip
      has no menu of its own, and a chip whose only behaviour is to
      clear itself is the exact dead-control pattern !1191 spent four
      MRs removing from these screens. This states what is filtered and
      offers the one action that makes sense — undo it.
    -->
    <section
      v-if="dateFilter"
      data-testid="schedule-date-filter"
      class="flex items-center gap-3 flex-wrap rounded-2xl border border-brand-cobalt/30 bg-role-admin-soft px-4 py-3"
    >
      <span class="text-sm font-bold text-slate-900">
        {{ t('tutoring2.admin.schedule.dateFilterActive', { date: dateFilterLabel }) }}
      </span>
      <span class="flex-1"></span>
      <button
        type="button"
        data-testid="schedule-date-filter-clear"
        class="inline-flex items-center rounded-xl border border-brand-cobalt bg-white px-3 py-1.5 text-sm font-bold text-brand-cobalt transition-colors hover:bg-brand-cobalt hover:text-white"
        @click="clearDateFilter"
      >
        {{ t('tutoring2.admin.schedule.dateFilterClear') }}
      </button>
    </section>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.schedule.emptyTitle')"
      :empty-description="t('tutoring2.admin.schedule.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.time') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.group') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.room') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <!-- Row click opens the detail. This table had no way into
                   one at all, which is the defect reported from prod:
                   "list sesinya belum ada detail sesi dan edit sesi".
                   Keyboard-reachable (`tabindex` + Enter) because a
                   `<tr>` is not focusable on its own, and the row is the
                   only affordance here. -->
              <tr
                v-for="s in (data as BimbelSession[])"
                :key="s.id"
                data-testid="schedule-row"
                tabindex="0"
                role="link"
                :aria-label="t('tutoring2.admin.schedule.openDetail')"
                class="cursor-pointer border-b border-slate-100 last:border-0 hover:bg-slate-50 focus:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-cobalt"
                @click="openDetail(s.id)"
                @keydown.enter.prevent="openDetail(s.id)"
                @keydown.space.prevent="openDetail(s.id)"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ formatWaktu(s.starts_at) }}</td>
                <!-- Names, not ids: SessionController::index eager-loads
                     `learningGroup:id,name` + `tutor:id,name` and
                     SessionResource exposes both, so the name is already
                     in this row. truncateId stays only as the fallback
                     for a row that arrived without one. -->
                <td class="px-4 py-3 text-slate-600">{{ s.learning_group_name ?? truncateId(s.learning_group_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ s.tutor_name ?? truncateId(s.tutor_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ s.room ?? '—' }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="s.status_label ?? statusLabel(s.status)" :tone="statusPillTone(s.status)" uppercase />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      v-if="canManage"
      type="button"
      data-testid="schedule-new-cta"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openCreate"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.schedule.newCta') }}
    </button>

    <!-- Per-facet pickers. Each writes its ref; the existing watcher on
         [status, group, tutor, period] does the reload, so nothing calls
         it here. -->
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
      v-if="showGroupPicker"
      :title="t('tutoring2.common.group')"
      :options="groupOptions"
      :selected="groupFilter"
      :all-label="t('tutoring2.common.all')"
      @close="showGroupPicker = false"
      @apply="(v) => { groupFilter = v; }"
    />
    <FilterFacetPickerModal
      v-if="showTutorPicker"
      :title="t('tutoring2.common.tutor')"
      :options="tutorOptions"
      :selected="tutorFilter"
      :all-label="t('tutoring2.common.all')"
      @close="showTutorPicker = false"
      @apply="(v) => { tutorFilter = v; }"
    />
  </div>
</template>
