<!--
  TutorTutoring2AssessmentsView.vue — greenfield "Penilaian" list for
  the tutor-mobile Vue shell (bimbel rebuild). Mirrors the admin
  AdminTutoring2AssessmentsView composition (BrandPageHeader →
  KpiStripCards → PageFilterToolbar → AsyncView → rounded-3xl surface
  → floating CTA) but renders a mobile-first divide-y list with
  per-row "Input skor" + "Hasil" actions instead of a wide desktop
  table.

  Route: teacher/tutoring2/assessments

  ── The two filter chips ──

  Jenis and Status were both blind cycles inlined in the template —
  press once, land on the next value, with nothing ever listing what
  the values were. Same defect a tutor reported on the Jadwal screen;
  <AppFilterChip> has no menu of its own, so each now opens a
  <FilterFacetPickerModal>.

  The chips also printed the RAW WIRE TOKEN as their value ("tryout",
  "published"), because the old `:value` was the ref itself. Options
  and chip alike now read through the same labelled list.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
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
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import {
  TutoringBimbelService,
  type BimbelAssessment,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';
import { isCounted } from '@/lib/absent-vs-zero';

const { t } = useI18n();
const router = useRouter();

// ─── Filter state ─────────────────────────────────────────────────
type AssessmentKind = BimbelAssessment['kind'];
type PublishFilter = '' | 'published' | 'draft';

/**
 * Every kind the `kind` parameter accepts. Typed as the wire union so a
 * kind added to `BimbelAssessment` without being added here fails the
 * type-check rather than quietly becoming unreachable.
 */
const ASSESSMENT_KINDS: AssessmentKind[] = ['tryout', 'latihan', 'kuis'];

const search = ref('');
const kindFilter = ref<'' | AssessmentKind>('');
const statusFilter = ref<PublishFilter>('');

const showKindPicker = ref(false);
const showStatusPicker = ref(false);

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

// ─── Loader ───────────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const publishedFlag =
    statusFilter.value === 'published' ? true
    : statusFilter.value === 'draft' ? false
    : undefined;
  const { items } = await TutoringBimbelService.listAssessments({
    per_page: 50,
    kind: kindFilter.value || undefined,
    published: publishedFlag,
  });
  return items;
});

watch([debouncedSearch, kindFilter, statusFilter], () => reload());

// ─── KPIs ─────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelAssessment[];
  const total = items.length;
  const tryout = items.filter((a) => a.kind === 'tryout').length;
  const latihan = items.filter((a) => a.kind === 'latihan').length;
  const draft = items.filter((a) => a.published_at == null).length;
  return [
    { icon: 'clipboard-list', label: t('tutoring2.common.total'), value: String(total) },
    { icon: 'award', label: t('tutoring2.admin.assessments.kpiTryout'), value: String(tryout), tone: 'violet' },
    { icon: 'edit', label: t('tutoring2.admin.assessments.kpiLatihan'), value: String(latihan), tone: 'brand' },
    {
      icon: 'file-text',
      label: t('tutoring2.status.draft'),
      value: String(draft),
      tone: draft > 0 ? 'amber' : 'slate',
    },
  ];
});

// ─── Helpers ──────────────────────────────────────────────────────
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
  return publishedAt ? t('tutoring2.status.published') : t('tutoring2.status.draft');
}

const metaLabel = computed(() => {
  if (state.value.status === 'content') {
    return t('tutoring2.tutor.assessments.meta', { count: (state.value.data as BimbelAssessment[]).length });
  }
  return t('tutoring2.common.loading');
});

// Client-side name filter — the backend contract for assessments
// doesn't expose a `search` param yet, so we narrow the loaded page.
const filteredItems = computed(() => {
  if (state.value.status !== 'content') return [] as BimbelAssessment[];
  const items = state.value.data as BimbelAssessment[];
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return items;
  return items.filter((a) => a.title.toLowerCase().includes(q));
});

// ─── Navigation ───────────────────────────────────────────────────
function goScores(id: string) {
  router.push({ name: 'teacher.tutoring2.scores', params: { id } });
}

function goResult(id: string) {
  router.push({ name: 'teacher.tutoring2.assessment-result', params: { id } });
}

// ── Participant count ─────────────────────────────────────────────
/**
 * "N peserta" — or nothing at all when the server did not say.
 *
 * `AssessmentController::index` (what `listAssessments()` calls) runs no
 * `withCount('scores')`; only `show()` does. `AssessmentResource` emits
 * `scores_count` through `when(isset(...))`, which OMITS the key rather
 * than sending null, so EVERY row on this screen arrives without it and
 * the old `?? 0` rendered a confident "0 peserta" for assessments that
 * may well have plenty. Same defect the admin screens carried; see
 * `@/lib/absent-vs-zero`.
 *
 * Unknown drops the segment (the separator is inside the same `v-if`)
 * rather than printing "—" mid-sentence; a reported 0 is a real answer
 * and still reads "0 peserta".
 */
function participantsLabel(a: BimbelAssessment): string | null {
  return isCounted(a.scores_count)
    ? t('tutoring2.common.metaParticipants', { count: a.scores_count })
    : null;
}
// ─── Filter facets ────────────────────────────────────────────────
const kindOptions = computed<FacetOption[]>(() => [
  { key: 'tryout', label: t('tutoring2.common.kindTryout') },
  { key: 'latihan', label: t('tutoring2.common.kindLatihan') },
  { key: 'kuis', label: t('tutoring2.common.kindKuis') },
]);

/**
 * `published` is a BOOLEAN on the wire, so these two keys are the
 * client's spelling of `published: true` and `published: false` — the
 * loader above maps them. "Semua" is neither, and drops the parameter.
 */
const statusOptions = computed<FacetOption[]>(() => [
  { key: 'published', label: t('tutoring2.status.published') },
  { key: 'draft', label: t('tutoring2.status.draft') },
]);

/** Label for the current selection — never the raw wire token. */
function chipValue(selected: string, options: FacetOption[]): string {
  if (!selected) return t('tutoring2.common.all');
  return options.find((o) => o.key === selected)?.label ?? selected;
}

const kindChipValue = computed(() => chipValue(kindFilter.value, kindOptions.value));
const statusChipValue = computed(() =>
  chipValue(statusFilter.value, statusOptions.value),
);

/** The picker emits a bare string; both refs are narrower unions. */
function applyKindFilter(value: string) {
  kindFilter.value = (ASSESSMENT_KINDS as string[]).includes(value)
    ? (value as AssessmentKind)
    : '';
}

function applyStatusFilter(value: string) {
  statusFilter.value = value === 'published' || value === 'draft' ? value : '';
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.assessments.title')"
      :meta="metaLabel"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.tutor.assessments.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.kind')"
          :value="kindChipValue"
          icon-name="clipboard-list"
          :active="!!kindFilter"
          @click="showKindPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusChipValue"
          icon-name="check-circle"
          :active="!!statusFilter"
          @click="showStatusPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.admin.assessments.emptyTitle')"
      :empty-description="t('tutoring2.tutor.assessments.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm divide-y divide-slate-100">
          <div
            v-for="a in filteredItems"
            :key="a.id"
            class="p-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="min-w-0 flex-1 space-y-1.5">
              <div class="flex items-center gap-2 flex-wrap">
                <p class="font-bold text-slate-900 truncate">{{ a.title }}</p>
                <StatusBadge
                  :label="a.kind_label ?? a.kind"
                  tone="info"
                  uppercase
                />
                <StatusBadge
                  :label="publishedLabel(a.published_at)"
                  :tone="publishedTone(a.published_at)"
                  uppercase
                />
              </div>
              <p class="text-2xs text-slate-500">
                {{ formatShortDate(a.assessment_date) }}
                <template v-if="participantsLabel(a)">
                  <span class="mx-1 text-slate-300">•</span>
                  {{ participantsLabel(a) }}
                </template>
              </p>
            </div>

            <div class="flex items-center gap-2 shrink-0">
              <Button variant="ghost" size="sm" @click="goResult(a.id)">{{ t('tutoring2.tutor.assessments.actionResult') }}</Button>
              <Button variant="secondary" size="sm" @click="goScores(a.id)">{{ t('tutoring2.tutor.assessments.actionScores') }}</Button>
            </div>
          </div>
        </div>
      </template>
    </AsyncView>

    <router-link
      :to="{ name: 'teacher.tutoring2.assessment-create' }"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.tutor.assessments.newCta') }}
    </router-link>
  </div>

  <!-- Per-facet pickers. Each writes its ref; the existing watcher on
       [search, kind, status] does the reload. -->
  <FilterFacetPickerModal
    v-if="showKindPicker"
    :title="t('tutoring2.common.kind')"
    :options="kindOptions"
    :selected="kindFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showKindPicker = false"
    @apply="applyKindFilter"
  />
  <FilterFacetPickerModal
    v-if="showStatusPicker"
    :title="t('tutoring2.common.status')"
    :options="statusOptions"
    :selected="statusFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showStatusPicker = false"
    @apply="applyStatusFilter"
  />
</template>
