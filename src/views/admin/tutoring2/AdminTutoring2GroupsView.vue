<!--
  AdminTutoring2KelompokView.vue — greenfield "Kelompok Belajar" list.

  Mirrors AdminTutoring2ProgramsView.vue shape 1:1:
  BrandPageHeader → KpiStripCards → PageFilterToolbar + AppFilterChip
  → AsyncView → table → floating "+ Kelompok baru" CTA.

  Data path: `useDataRefresh(loader)` → `{ state, reload }`.
  Filters + academic-year change trigger reload.

  The Program / Term / Tutor chips each open a <FilterFacetPickerModal>
  — the same per-facet picker the Manajemen Data screens use. They
  previously only ever CLEARED their filter (`@click="x = ''"`) with no
  menu behind them, so the whole toolbar was inert on prod ("semua
  button/filter tdk berfungsi") even though the query + watcher below
  had been wired correctly all along.
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
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';
import { TutoringTermsService } from '@/services/tutoring2/terms';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { BimbelTerm } from '@/types/tutoring2/term';
import type { Tutor } from '@/types/tutoring2/tutor';
import type { StatusBadgeTone } from '@/types/status-badge';

const search = ref('');
const programFilter = ref<string>(''); // '' = Semua
const termFilter = ref<string>(''); // '' = Semua
const tutorFilter = ref<string>(''); // '' = Semua

const { t } = useI18n();

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listGroups({
    per_page: 50,
    status: undefined,
    program_id: programFilter.value || undefined,
    term_id: termFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  // Client-side search — listGroups has no `search` param yet.
  const q = debouncedSearch.value.trim().toLowerCase();
  return q ? items.filter((g) => g.name.toLowerCase().includes(q)) : items;
});

watch([debouncedSearch, programFilter, termFilter, tutorFilter], () => reload());
useAcademicYearWatcher(reload);

// ── Facet option lists ─────────────────────────────────────────────
// The three chips filter on ids, so each one needs the id→name list its
// picker renders. Programs come off the service this view already uses;
// terms and tutors have their own WEB-8 wrappers.
const programs = ref<BimbelProgram[]>([]);
const terms = ref<BimbelTerm[]>([]);
const tutors = ref<Tutor[]>([]);

// Per-facet picker visibility
const showProgramPicker = ref(false);
const showTermPicker = ref(false);
const showTutorPicker = ref(false);

const programOptions = computed<FacetOption[]>(() =>
  programs.value.map((p) => ({
    key: p.id,
    label: p.name,
    meta: p.grade_level
      ? `${t('tutoring2.common.gradeLevel')} ${p.grade_level}`
      : undefined,
  })),
);
// `tm` / `tu`, not `t` — the i18n `t` is in scope and must not be shadowed.
const termOptions = computed<FacetOption[]>(() =>
  terms.value.map((tm) => ({ key: tm.id, label: tm.name, meta: tm.status_label })),
);
const tutorOptions = computed<FacetOption[]>(() =>
  tutors.value.map((tu) => ({ key: tu.id, label: tu.name })),
);

/**
 * Load the three option lists once, tolerantly: they are independent, so
 * one endpoint failing (or being ability-gated off) must not blank the
 * other two chips. A list that stays empty leaves its own chip disabled
 * rather than opening a picker with nothing to pick.
 */
async function loadFacetOptions() {
  const [programRes, termRes, tutorRes] = await Promise.allSettled([
    TutoringBimbelService.listPrograms({ per_page: 200 }),
    TutoringTermsService.list({ per_page: 200 }),
    TutoringTutorsService.list({ per_page: 200 }),
  ]);
  if (programRes.status === 'fulfilled') programs.value = programRes.value.items;
  if (termRes.status === 'fulfilled') terms.value = termRes.value.items;
  if (tutorRes.status === 'fulfilled') tutors.value = tutorRes.value.items;
}

onMounted(loadFacetOptions);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelLearningGroup[];
  const privateCount = items.filter((g) => g.kind === 'private').length;
  const totalUtil = items.reduce((sum, g) => {
    if (!g.capacity || g.capacity <= 0) return sum;
    return sum + ((g.seated_count ?? 0) / g.capacity);
  }, 0);
  const withCapacity = items.filter((g) => g.capacity && g.capacity > 0).length;
  const avgUtil = withCapacity > 0 ? Math.round((totalUtil / withCapacity) * 100) : 0;
  const fullCount = items.filter((g) => (g.seated_count ?? 0) >= (g.capacity ?? 0) && (g.capacity ?? 0) > 0).length;
  return [
    { icon: 'users', label: t('tutoring2.admin.groups.kpiGroups'), value: String(items.length) },
    { icon: 'user', label: t('tutoring2.admin.groups.kpiPrivates'), value: String(privateCount) },
    { icon: 'chart-bar', label: t('tutoring2.admin.groups.kpiAvgUtilization'), value: `${avgUtil}%` },
    { icon: 'circle-check', label: t('tutoring2.admin.groups.kpiFull'), value: String(fullCount), tone: fullCount > 0 ? 'amber' : undefined },
  ];
});

function statusPillTone(status: BimbelLearningGroup['status']): StatusBadgeTone {
  switch (status) {
    case 'active': return 'success';
    case 'draft': return 'neutral';
    case 'closed': return 'neutral';
  }
}

function statusLabel(status: BimbelLearningGroup['status']): string {
  return t(`tutoring2.status.${status}`);
}

/**
 * Last-resort label for a row whose name the server did not send.
 * The Program and Tutor columns used this for EVERY row even though
 * `program_name` and `tutor_name` are eager-loaded by
 * `LearningGroupController::index` and have been on the wire all
 * along — so both columns read as hex under a human heading.
 */
function shortId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
}

/**
 * What a filter chip reads: the picked option's NAME, or "Semua" when the
 * facet is unset.
 *
 * Falls back to `shortId` only when the id is genuinely not in the loaded
 * list (options still in flight, or the option was archived away). An id
 * fragment is ugly but honest there — "—" on a chip that is visibly
 * ACTIVE would read as "no filter applied", which is the failure this
 * screen just came out of.
 */
function chipValue(id: string, options: FacetOption[]): string {
  if (!id) return t('tutoring2.common.all');
  return options.find((o) => o.key === id)?.label ?? shortId(id);
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.groups.title')"
      :meta="state.status === 'content'
        ? `${(state.data as BimbelLearningGroup[]).length} ${t('tutoring2.common.group').toLowerCase()} · ${(state.data as BimbelLearningGroup[]).filter((g) => g.kind === 'private').length} ${t('tutoring2.admin.groups.kpiPrivates').toLowerCase()}`
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.groups.searchPh')">
      <template #chips>
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
          :label="t('tutoring2.common.term')"
          :value="chipValue(termFilter, termOptions)"
          icon-name="calendar"
          :active="!!termFilter"
          :disabled="termOptions.length === 0"
          :title="termOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showTermPicker = true"
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
      :empty-title="t('tutoring2.admin.groups.emptyTitle')"
      :empty-description="t('tutoring2.admin.groups.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.group') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.classLabel') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.capacity') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="g in (data as BimbelLearningGroup[])"
                :key="g.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ g.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ g.kind_label ?? (g.kind === 'private' ? t('tutoring2.admin.groups.kindPrivate') : t('tutoring2.admin.groups.kindGroup')) }}</td>
                <td class="px-4 py-3 text-slate-600">
                  <span v-if="g.program_name">{{ g.program_name }}</span>
                  <span v-else class="font-mono text-2xs text-slate-500">{{ shortId(g.program_id) }}</span>
                </td>
                <td class="px-4 py-3 text-slate-600">
                  <!-- `seated_count` is optional; absent means the server
                       did not count, not that the group is empty. -->
                  {{ g.seated_count == null ? '—' : g.seated_count }} / {{ g.capacity }}
                </td>
                <td class="px-4 py-3 text-slate-600">
                  <span v-if="g.tutor_name">{{ g.tutor_name }}</span>
                  <span v-else-if="g.tutor_id" class="font-mono text-2xs text-slate-500">{{ shortId(g.tutor_id) }}</span>
                  <span v-else class="text-slate-400">—</span>
                </td>
                <td class="px-4 py-3">
                  <StatusBadge :label="g.status_label ?? statusLabel(g.status)" :tone="statusPillTone(g.status)" uppercase />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.groups.newCta') }}
    </button>
  </div>

  <!-- Per-facet pickers. Each writes its ref; the existing watcher on
       [program, term, tutor] does the reload, so nothing calls it here. -->
  <FilterFacetPickerModal
    v-if="showProgramPicker"
    :title="t('tutoring2.common.program')"
    :options="programOptions"
    :selected="programFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showProgramPicker = false"
    @apply="(v) => { programFilter = v; }"
  />
  <FilterFacetPickerModal
    v-if="showTermPicker"
    :title="t('tutoring2.common.term')"
    :options="termOptions"
    :selected="termFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showTermPicker = false"
    @apply="(v) => { termFilter = v; }"
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
</template>
