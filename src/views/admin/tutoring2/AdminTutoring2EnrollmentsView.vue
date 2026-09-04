<!--
  AdminTutoring2PendaftaranView.vue — greenfield "Pendaftaran" list.

  Mirrors AdminTutoring2ProgramsView.vue exactly: BrandPageHeader →
  KpiStripCards → PageFilterToolbar (+ AppFilterChip trio) → AsyncView
  wrapping the table → floating "+ Daftarkan siswa" CTA. Data loads
  via `useDataRefresh(loader)` and re-runs when the debounced search,
  any filter chip, or the active academic year changes.

  The Program chip opens a <FilterFacetPickerModal> — the same per-facet
  picker the Manajemen Data screens use. It previously only ever CLEARED
  its filter (`@click="programFilter = ''"`) with no menu behind it, so
  it was inert on prod ("semua button/filter tdk berfungsi") even though
  the query + watcher below had been wired correctly all along. Same fix
  as AdminTutoring2GroupsView (!1191).

  ── THE "+ Daftarkan siswa" CTA IS DISABLED ON PURPOSE ───────────────

  It shipped with no `@click` and no handler, so it joined the prod
  reports of "tombol diklik tidak terjadi apa-apa". It is NOT wired,
  because there is nothing admin-shaped to wire it to.

  `TutoringBimbelService.createEnrollment` has exactly ONE call site in
  the whole app: ParentTutoring2EnrollWizardView, the WALI's
  self-service wizard. That is not this flow wearing a different hat:

    - its subject comes from a `:studentId` route param, so the wali
      never chooses a student — an admin starting from this list has no
      student yet, and no student picker exists on this screen (it
      loads `programs` for the filter chip and nothing else);
    - it walks program → package → confirm, fetching each program's
      packages as you go;
    - it carries a documented authorization gap of its own (the wali
      role holds none of the three keys it needs) and renders a
      "not permitted yet" panel for it.

  Reusing it would mean adding a student-search step and re-shelling
  583 lines of wizard — that is building the admin enrollment flow, and
  which students an admin may enrol on whose behalf is a product
  question, not a bug fix. The backend is ready (`admin` holds
  `tutoring.enrollment.manage` in `PermissionCatalog::
  adminTutoringDefaults()` and `POST /tutoring-v2/enrollments` is
  live) — only the surface is missing.

  So the button states plainly that it is unavailable instead of
  silently swallowing the click, and `enrollments.emptyDesc` — which
  read "Klik + untuk mendaftarkan siswa baru." — no longer tells admins
  to press it.

  To finish this: build the create sheet (mirror
  <AdminTutoring2GroupCreateSheet>, with a student picker over
  `/tutoring-v2/students` and a package picker over the chosen
  program), call `createEnrollment`, gate on
  `tutoring.enrollment.manage`, then drop `disabled` + the `title`
  below and restore the empty-state copy.
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
  type BimbelEnrollment,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const search = ref('');
const statusFilter = ref<string>(''); // '' | 'trial' | 'active' | 'paused' | 'graduated' | 'withdrawn'
const programFilter = ref<string>(''); // '' | program uuid
const billingModeFilter = ref<string>(''); // '' | 'prepaid' | 'monthly' | 'per_session'

const { t } = useI18n();

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({
    per_page: 100,
    status: statusFilter.value || undefined,
    program_id: programFilter.value || undefined,
    billing_mode: billingModeFilter.value || undefined,
  });
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return items;
  return items.filter(
    (e) =>
      (e.student_name ?? e.student_id).toLowerCase().includes(q) ||
      (e.student_number ?? '').toLowerCase().includes(q) ||
      (e.program_name ?? e.program_id).toLowerCase().includes(q),
  );
});

watch([debouncedSearch, statusFilter, programFilter, billingModeFilter], () => {
  reload();
});

// ── Facet option list ──────────────────────────────────────────────
// The Program chip filters on an id, so it needs the id→name list its
// picker renders. Status and Billing mode are enum toggles and need no
// fetch.
const programs = ref<BimbelProgram[]>([]);
const showProgramPicker = ref(false);

const programOptions = computed<FacetOption[]>(() =>
  programs.value.map((p) => ({
    key: p.id,
    label: p.name,
    meta: p.grade_level
      ? `${t('tutoring2.common.gradeLevel')} ${p.grade_level}`
      : undefined,
  })),
);

/**
 * Load the option list once, tolerantly: a failing or ability-gated
 * endpoint must leave the chip disabled with a hover reason rather than
 * opening a picker with nothing to pick — that would be the same lie in
 * a new shape.
 */
async function loadFacetOptions() {
  const [programRes] = await Promise.allSettled([
    TutoringBimbelService.listPrograms({ per_page: 200 }),
  ]);
  if (programRes.status === 'fulfilled') programs.value = programRes.value.items;
}

onMounted(loadFacetOptions);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  const active = items.filter((e) => e.status === 'active').length;
  const trial = items.filter((e) => e.status === 'trial').length;
  const exited = items.filter((e) => e.status === 'graduated' || e.status === 'withdrawn').length;
  return [
    { icon: 'circle-check', label: t('tutoring2.admin.enrollments.kpiActive'), value: String(active), tone: 'green' },
    { icon: 'sparkles', label: t('tutoring2.admin.enrollments.kpiTrial'), value: String(trial), tone: trial > 0 ? 'amber' : undefined },
    { icon: 'log-out', label: t('tutoring2.admin.enrollments.kpiGraduated'), value: String(exited) },
    { icon: 'calendar', label: t('tutoring2.admin.enrollments.kpiThisMonth'), value: '+23' },
  ];
});

function statusPillTone(status: BimbelEnrollment['status']): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'trial': return 'warning';
    case 'paused': return 'neutral';
    case 'graduated': return 'neutral';
    case 'withdrawn': return 'neutral';
    default: return 'neutral';
  }
}

function statusLabel(status: BimbelEnrollment['status']): string {
  return t(`tutoring2.status.${status}`);
}

function truncateId(id: string, len = 8): string {
  return id.length > len ? `${id.slice(0, len)}…` : id;
}

/**
 * What the Program chip reads: the picked program's NAME, or "Semua" when
 * unset.
 *
 * Falls back to `truncateId` only when the id is genuinely not in the
 * loaded list (options still in flight, or the program was archived
 * away). An id fragment is ugly but honest there — "—" on a chip that is
 * visibly ACTIVE would read as "no filter applied", which is the failure
 * this screen just came out of.
 */
function chipValue(id: string, options: FacetOption[]): string {
  if (!id) return t('tutoring2.common.all');
  return options.find((o) => o.key === id)?.label ?? truncateId(id);
}

function remainingQuota(e: BimbelEnrollment): string {
  if (e.billing_mode !== 'prepaid') return '—';
  const total = e.total_sessions_snapshot;
  const rem = e.remaining_sessions;
  if (total == null || rem == null) return '—';
  return `${rem} / ${total}`;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.enrollments.title')"
      :meta="state.status === 'content'
        ? `${(state.data as BimbelEnrollment[]).length} ${t('tutoring2.admin.enrollments.title').toLowerCase()}`
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.enrollments.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'active'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="chipValue(programFilter, programOptions)"
          icon-name="book"
          :active="!!programFilter"
          :disabled="programOptions.length === 0"
          :title="programOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showProgramPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.billingMode')"
          :value="billingModeFilter || t('tutoring2.common.all')"
          icon-name="wallet"
          :active="!!billingModeFilter"
          @click="billingModeFilter = billingModeFilter ? '' : 'prepaid'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.enrollments.emptyTitle')"
      :empty-description="t('tutoring2.admin.enrollments.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.student') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.billingMode') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.remainingQuota') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="e in (data as BimbelEnrollment[])"
                :key="e.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ e.student_name ?? truncateId(e.student_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ e.program_name ?? truncateId(e.program_id) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ e.billing_mode_label ?? e.billing_mode }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="e.status_label ?? statusLabel(e.status)" :tone="statusPillTone(e.status)" uppercase />
                </td>
                <td class="px-4 py-3 text-slate-600">{{ remainingQuota(e) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <!-- Disabled, with the reason on the control itself — see docblock.
         `title` carries it for a pointer, and the aria-describedby'd
         line carries it for a screen reader, which never sees a
         tooltip. -->
    <button
      type="button"
      data-testid="enrollments-new-cta"
      disabled
      aria-describedby="enrollments-new-cta-reason"
      :title="t('tutoring2.admin.enrollments.newCtaUnavailable')"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-slate-300 text-white font-bold shadow-xl cursor-not-allowed"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.enrollments.newCta') }}
    </button>
    <span id="enrollments-new-cta-reason" class="sr-only">
      {{ t('tutoring2.admin.enrollments.newCtaUnavailable') }}
    </span>

    <!-- Per-facet picker. It writes its ref; the existing watcher on
         [status, program, billingMode] does the reload, so nothing calls
         it here. -->
    <FilterFacetPickerModal
      v-if="showProgramPicker"
      :title="t('tutoring2.common.program')"
      :options="programOptions"
      :selected="programFilter"
      :all-label="t('tutoring2.common.all')"
      @close="showProgramPicker = false"
      @apply="(v) => { programFilter = v; }"
    />
  </div>
</template>
