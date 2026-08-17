<!--
  AdminTutoring2NilaiView.vue — greenfield "Nilai" (assessments) list.

  Sibling of AdminTutoring2ProgramsView; same composition contract:
  BrandPageHeader → KpiStripCards → PageFilterToolbar → AsyncView →
  white rounded-3xl table surface → floating "+" CTA.

  This is the LIST view — the score matrix opens on assessment detail.

  The Program chip opens a <FilterFacetPickerModal> — the same per-facet
  picker the Manajemen Data screens use. It previously only ever CLEARED
  its filter (`@click="programFilter = ''"`) with no menu behind it, so
  it was inert on prod ("semua button/filter tdk berfungsi") even though
  the query + watcher below had been wired correctly all along. Same fix
  as AdminTutoring2GroupsView (!1191).
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
  type BimbelAssessment,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

const search = ref('');
const kindFilter = ref<string>(''); // '' | 'tryout' | 'latihan' | 'kuis'
const programFilter = ref<string>(''); // '' | program uuid
const statusFilter = ref<string>(''); // '' | 'published' | 'draft'

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const publishedFlag =
    statusFilter.value === 'published' ? true
    : statusFilter.value === 'draft' ? false
    : undefined;
  const { items } = await TutoringBimbelService.listAssessments({
    per_page: 50,
    kind: kindFilter.value || undefined,
    program_id: programFilter.value || undefined,
    published: publishedFlag,
  });
  return items;
});

watch([debouncedSearch, kindFilter, programFilter, statusFilter], () => reload());
useAcademicYearWatcher(reload);

// ── Facet option list ──────────────────────────────────────────────
// The Program chip filters on an id, so it needs the id→name list its
// picker renders. Jenis and Status are enum toggles and need no fetch.
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
 * opening a picker with nothing to pick.
 */
async function loadFacetOptions() {
  const [programRes] = await Promise.allSettled([
    TutoringBimbelService.listPrograms({ per_page: 200 }),
  ]);
  if (programRes.status === 'fulfilled') programs.value = programRes.value.items;
}

onMounted(loadFacetOptions);

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelAssessment[];
  const tryout = items.filter((a) => a.kind === 'tryout').length;
  const latihan = items.filter((a) => a.kind === 'latihan').length;
  const kuis = items.filter((a) => a.kind === 'kuis').length;
  const draft = items.filter((a) => a.published_at == null).length;
  return [
    { icon: 'clipboard-list', label: t('tutoring2.admin.assessments.kpiTryout'), value: String(tryout) },
    { icon: 'pencil', label: t('tutoring2.admin.assessments.kpiLatihan'), value: String(latihan) },
    { icon: 'help-circle', label: t('tutoring2.admin.assessments.kpiKuis'), value: String(kuis) },
    { icon: 'file-pencil', label: t('tutoring2.admin.assessments.kpiDrafts'), value: String(draft), tone: draft > 0 ? 'amber' : undefined },
  ];
});

function truncateId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.length > 8 ? id.slice(0, 8) : id;
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

/**
 * The table's Program cell. `program_name` rides along on every row
 * (AssessmentResource exposes it; `index` eager-loads `program:id,name`),
 * so the name is free. The loaded option list is the second chance for a
 * row that arrived without one, and an id fragment is the last resort.
 */
function programLabel(a: BimbelAssessment): string {
  return (
    a.program_name
    ?? programOptions.value.find((o) => o.key === a.program_id)?.label
    ?? truncateId(a.program_id)
  );
}

function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

function publishedTone(publishedAt: string | null | undefined): StatusBadgeTone {
  return publishedAt ? 'success' : 'warning';
}

function publishedLabel(publishedAt: string | null | undefined): string {
  return publishedAt
    ? `${t('tutoring2.status.published')} ${formatShortDate(publishedAt)}`
    : t('tutoring2.status.draft');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.assessments.title')"
      :meta="state.status === 'content' ? t('tutoring2.common.metaAssessments', { count: (state.data as BimbelAssessment[]).length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.assessments.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.kind')"
          :value="kindFilter || t('tutoring2.common.all')"
          icon-name="clipboard-list"
          :active="!!kindFilter"
          @click="kindFilter = kindFilter ? '' : 'tryout'"
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
          :label="t('tutoring2.common.status')"
          :value="statusFilter || t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'published'"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.assessments.emptyTitle')"
      :empty-description="t('tutoring2.admin.assessments.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.title') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.kind') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.program') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.date') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.participants') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.max') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.publication') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="a in (data as BimbelAssessment[])"
                :key="a.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ a.title }}</td>
                <td class="px-4 py-3 text-slate-600">{{ a.kind_label ?? a.kind }}</td>
                <!-- Name, not id. Was `truncateId(a.program_id)` in a
                     font-mono cell — a UUID fragment styled as if hex
                     were the intended content. -->
                <td class="px-4 py-3 text-slate-600">{{ programLabel(a) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ formatShortDate(a.assessment_date) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ a.scores_count ?? 0 }}</td>
                <td class="px-4 py-3 text-slate-600">{{ a.max_score }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="publishedLabel(a.published_at)" :tone="publishedTone(a.published_at)" uppercase />
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
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.assessments.newCta') }}
    </button>

    <!-- Per-facet picker. It writes its ref; the existing watcher on
         [kind, program, status] does the reload, so nothing calls it
         here. -->
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
