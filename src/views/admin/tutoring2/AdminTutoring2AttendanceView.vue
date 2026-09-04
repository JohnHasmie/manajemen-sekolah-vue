<!--
  AdminTutoring2KehadiranView.vue — greenfield "Kehadiran" monitor.

  Sibling to AdminTutoring2ProgramsView (the WEB-3 exemplar); same
  composition contract top→bottom, but the floating slot is a
  "Ekspor rekap" action instead of a "+" CTA (this is a monitor view).

  ── What this replaces ──

  Three of the four tiles were wrong, two of them literals:

      Sesi selesai   real
      Total presensi ALWAYS 0   — `index` never counted attendances, so
                                  `attendances_count` was absent from
                                  every row and `?? 0` swallowed it
      % Presensi     `const pctPresensi = 92`
      Belum diambil  `const belumDiambil = 0`

  So an admin whose whole reason for opening this screen is to see
  whether registers are being taken was told 92% and "nothing
  outstanding", permanently, on top of a total that could not move off
  zero.

  BE !786 makes `index` count attendances and, separately, how many
  were `hadir`. Both KPIs now come from exactly the sessions in the
  list — filters included. The tempting alternative,
  `/admin/reports/attendance`, aggregates by enrollment over a date
  range with no group or tutor filter, so its percentage would
  contradict the table beneath it as soon as an admin filtered.

  ── Two columns, two numbers ──

  The table renders exactly the pair the KPI strip aggregates and the
  CSV exports, under the same two headers the CSV already uses:
  `attendances_count` = marks recorded ("Presensi tercatat"),
  `attendances_present_count` = how many of those were hadir ("Hadir").

  Both cells used to read `attendances_count`. So the column headed
  "Hadir" showed the MARKS total, and the column beside it showed that
  same number a second time as `${n} rows` — English, and "rows" is
  developer vocabulary for what the product calls presensi. An admin who
  read "Hadir 10" on screen and exported that very session got "Hadir 9",
  because `exportCsv` below has always mapped the two fields correctly.
  `attendances_present_count` reached the KPIs and the CSV but never the
  table.

  ── Absent is not zero ──

  Both counts are optional on the wire. A row that carries neither is
  "not counted", which is why the rate renders "—" rather than 0%
  when nothing countable came back, and why "Belum diambil" only
  counts rows that actually reported a zero.

  ── The filters ──

  The Kelompok / Tutor chips each open a <FilterFacetPickerModal>, the
  same per-facet picker the Manajemen Data screens use. They previously
  only ever CLEARED their filter (`@click="x = ''"`) with no menu behind
  them, so both were inert on prod ("semua button/filter tdk berfungsi")
  even though `listSessions` already forwarded learning_group_id /
  tutor_id and the watcher already reloaded. Same fix as
  AdminTutoring2GroupsView (!1191).

  ── The "Ekspor rekap" action ──

  It rendered with no `@click` at all, so the one thing this monitor
  view offers beyond looking at it did nothing — the same defect !1211
  fixed on the Kelompok and Program CTAs, in export shape.

  It now writes a CSV client-side through `csvFrom` + `downloadCsv`,
  the helpers `services/tutoring2/reports.ts` already exports and that
  all three admin report views (Aktivitas / Kehadiran / Keuangan) use.
  No new export machinery, and no `/reports/attendance` call: that
  endpoint aggregates by enrollment over a date range with no group or
  tutor filter, so its rows would contradict the table this button sits
  under as soon as an admin filtered. The export is exactly the rows on
  screen, filters included — what "Ekspor rekap" claims.

  Absent stays absent, matching the KPIs above: a session that reported
  no count exports an empty cell, never a 0, because no register taken
  is not the same as nobody attending. With nothing loaded there is
  nothing to export, so the button disables itself with a reason rather
  than handing over a header-only file.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
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
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';
import { csvFrom, downloadCsv } from '@/services/tutoring2/reports';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import { toLocalYmd } from '@/lib/local-date';
import type { Tutor } from '@/types/tutoring2/tutor';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

const search = ref('');
const dateFilter = ref<'all' | 'today' | 'week' | 'month'>('all'); // nominal, UI-only
const groupFilter = ref<string>(''); // '' | learning_group_id
const tutorFilter = ref<string>(''); // '' | tutor_id

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({
    per_page: 100,
    status: 'done',
    learning_group_id: groupFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, dateFilter, groupFilter, tutorFilter], () => reload());

// ── Facet option lists ─────────────────────────────────────────────
// Both id-valued chips need the id→name list their picker renders.
const groups = ref<BimbelLearningGroup[]>([]);
const tutors = ref<Tutor[]>([]);

const showGroupPicker = ref(false);
const showTutorPicker = ref(false);

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
 * opening a picker with nothing to pick.
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

  // Only rows that actually reported a count take part. A row without
  // one is unknown, and unknown must not be averaged in as zero.
  const counted = items.filter((s) => typeof s.attendances_count === 'number');
  const totalMarks = counted.reduce((sum, s) => sum + (s.attendances_count ?? 0), 0);
  const totalPresent = counted.reduce(
    (sum, s) => sum + (s.attendances_present_count ?? 0),
    0,
  );

  // Hadir over every mark recorded across these sessions. Null when
  // nothing countable came back — "—", never 0%, because no register
  // taken is not the same as nobody attending.
  const rate =
    counted.length === 0 || totalMarks === 0
      ? null
      : Math.round((totalPresent / totalMarks) * 100);

  // A DONE session with zero attendance rows is a register nobody
  // took. Rows that reported no count at all are excluded: we cannot
  // tell an untaken register from an uncounted one.
  const belumDiambil = counted.filter((s) => (s.attendances_count ?? 0) === 0).length;

  return [
    {
      icon: 'circle-check',
      label: t('tutoring2.admin.attendance.kpiCompleted'),
      value: String(items.length),
    },
    {
      icon: 'users',
      label: t('tutoring2.admin.attendance.kpiTotal'),
      value: counted.length === 0 ? '—' : String(totalMarks),
    },
    {
      icon: 'chart-bar',
      label: t('tutoring2.admin.attendance.kpiRate'),
      value: rate == null ? '—' : `${rate}%`,
    },
    {
      icon: 'clock',
      label: t('tutoring2.admin.attendance.kpiUnrecorded'),
      value: counted.length === 0 ? '—' : String(belumDiambil),
      tone: belumDiambil > 0 ? 'amber' : undefined,
    },
  ];
});

// ── Per-row attendance cells ───────────────────────────────────────
// Same absent-vs-zero doctrine as the KPI strip above, applied per row.

/**
 * Marks recorded on this row.
 *
 * A row that reported no count at all is unknown — "—", never 0. A DONE
 * session that reported exactly 0 is a register nobody took, so it reads
 * with the same string the "Belum diambil" tile counts: the rows an
 * admin can point at in the table now add up to that KPI.
 */
function marksCell(s: BimbelSession): string {
  const marks = s.attendances_count;
  if (typeof marks !== 'number') return '—';
  return marks === 0
    ? t('tutoring2.admin.attendance.kpiUnrecorded')
    : String(marks);
}

/**
 * How many of those marks were hadir.
 *
 * Meaningful only once a register exists: with no marks at all (absent
 * or 0) a "0" here would claim nobody attended, the conflation this
 * screen refuses everywhere else. A 0 against a register that WAS taken
 * still renders 0 — that one really does mean nobody came.
 */
function presentCell(s: BimbelSession): string {
  const marks = s.attendances_count;
  const present = s.attendances_present_count;
  if (typeof marks !== 'number' || marks === 0) return '—';
  return typeof present === 'number' ? String(present) : '—';
}

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

function formatTanggal(iso: string): string {
  return new Date(iso).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
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

// ── Ekspor rekap ───────────────────────────────────────────────────
// See the docblock: same csvFrom + downloadCsv path the three admin
// report views use, over exactly the rows currently listed.

/** The sessions the table is showing right now — filters applied. */
const exportRows = computed<BimbelSession[]>(() =>
  state.value.status === 'content' ? (state.value.data as BimbelSession[]) : [],
);

/** Nothing loaded → nothing to export, and the button says so. */
const canExport = computed(() => exportRows.value.length > 0);

function exportCsv(): void {
  if (!canExport.value) return;

  const rows = exportRows.value.map((s) => {
    const marks = s.attendances_count;
    const present = s.attendances_present_count;
    return {
      // `starts_at` is an ISO instant; render it the way the table does
      // rather than slicing the string, so the CSV agrees with what the
      // admin just read on screen.
      date: formatTanggal(s.starts_at),
      time: new Date(s.starts_at).toLocaleTimeString('id-ID', {
        hour: '2-digit',
        minute: '2-digit',
      }),
      group_name: s.learning_group_name ?? '',
      tutor_name: s.tutor_name ?? '',
      // Blank, not 0, when the row reported no count at all — the same
      // "absent is not zero" rule the KPI strip above follows.
      attendances_count: marks ?? '',
      attendances_present_count: present ?? '',
      attendance_rate_pct:
        typeof marks === 'number' && marks > 0 && typeof present === 'number'
          ? Math.round((present / marks) * 100)
          : '',
      status: s.status_label ?? statusLabel(s.status),
    };
  });

  const csv = csvFrom(rows, [
    { key: 'date', header: t('tutoring2.common.date') },
    { key: 'time', header: t('tutoring2.common.time') },
    { key: 'group_name', header: t('tutoring2.common.group') },
    { key: 'tutor_name', header: t('tutoring2.common.tutor') },
    { key: 'attendances_count', header: t('tutoring2.admin.attendance.colMarks') },
    { key: 'attendances_present_count', header: t('tutoring2.common.attended') },
    { key: 'attendance_rate_pct', header: t('tutoring2.admin.attendance.colRate') },
    { key: 'status', header: t('tutoring2.common.status') },
  ]);

  // Local date, never toISOString() — that names a WIB export before
  // 07:00 after the previous day.
  downloadCsv(csv, `rekap-kehadiran-${toLocalYmd()}.csv`);
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.attendance.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaSessionsDone', { count: (state.data as BimbelSession[]).length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.attendance.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.date')"
          :value="dateFilter === 'all' ? t('tutoring2.common.all') : dateFilter === 'today' ? t('tutoring2.common.today') : dateFilter === 'week' ? t('tutoring2.common.thisWeek') : t('tutoring2.common.thisMonth')"
          icon-name="calendar"
          :active="dateFilter !== 'all'"
          @click="dateFilter = dateFilter === 'all' ? 'today' : dateFilter === 'today' ? 'week' : dateFilter === 'week' ? 'month' : 'all'"
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
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.attendance.emptyTitle')"
      :empty-description="t('tutoring2.admin.attendance.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.session') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.date') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.attended') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.attendance.colMarks') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="s in (data as BimbelSession[])"
                :key="s.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <!-- Name, not id: SessionResource already exposes
                     `learning_group_name` (index eager-loads it), so the
                     name is in this row. truncateId stays as fallback. -->
                <td class="px-4 py-3 font-bold text-slate-900">
                  {{ formatWaktu(s.starts_at) }} · {{ s.learning_group_name ?? truncateId(s.learning_group_id) }}
                </td>
                <td class="px-4 py-3 text-slate-600">{{ formatTanggal(s.starts_at) }}</td>
                <!-- Each cell renders the field its header names, the same
                     mapping exportCsv uses: Hadir = present, Presensi
                     tercatat = marks. Both used to read the marks count. -->
                <td class="px-4 py-3 text-slate-600">{{ presentCell(s) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ marksCell(s) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="s.status_label ?? statusLabel(s.status)" :tone="statusPillTone(s.status)" uppercase />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <!-- Disabled only when the list is empty, and then with the reason
         on the control itself: `title` for a pointer, the
         aria-describedby'd line for a screen reader, which never sees a
         tooltip. -->
    <button
      type="button"
      data-testid="attendance-export-cta"
      :disabled="!canExport"
      :aria-label="t('tutoring2.admin.attendance.exportCta')"
      :aria-describedby="canExport ? undefined : 'attendance-export-reason'"
      :title="canExport ? undefined : t('tutoring2.admin.attendance.exportEmpty')"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl text-white font-bold shadow-xl transition-colors"
      :class="
        canExport
          ? 'bg-brand-cobalt shadow-brand-cobalt/30 hover:bg-brand-cobalt/90'
          : 'bg-slate-300 cursor-not-allowed'
      "
      @click="exportCsv"
    >
      {{ t('tutoring2.admin.attendance.exportCta') }}
    </button>
    <span v-if="!canExport" id="attendance-export-reason" class="sr-only">
      {{ t('tutoring2.admin.attendance.exportEmpty') }}
    </span>

    <!-- Per-facet pickers. Each writes its ref; the existing watcher on
         [date, group, tutor] does the reload, so nothing calls it here. -->
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
