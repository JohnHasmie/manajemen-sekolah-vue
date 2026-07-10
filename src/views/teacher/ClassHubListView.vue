<!--
  The "Kelas" list (teacher web) — SUBJECT-LEVEL. One card per (class × subject)
  the guru teaches, plus a general all-subjects card for a wali kelas. Grouped
  Kelas wali / Kelas ajar with a Semua / Wali / Mengajar filter; a card opens
  the hub scoped to that card. Mirrors the mobile ClassHubListScreen.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import ClassHeroCard from '@/components/feature/ClassHeroCard.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { ClassHubService } from '@/services/class-hub.service';
import {
  classCardKey,
  isGeneralCard,
  type ClassCard,
} from '@/types/class-hub';
import { classHubAccent, classHubGradientCss } from '@/utils/classHubTheme';

const { t } = useI18n();
const router = useRouter();

type Filter = 'all' | 'wali' | 'mengajar';

const loading = ref(true);
const error = ref<string | null>(null);
const classes = ref<ClassCard[]>([]);
const filter = ref<Filter>('all');
const query = ref('');

async function load() {
  loading.value = true;
  error.value = null;
  try {
    classes.value = await ClassHubService.myClasses();
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e);
  } finally {
    loading.value = false;
  }
}
onMounted(load);

function matchesQuery(c: ClassCard): boolean {
  const q = query.value.trim().toLowerCase();
  if (!q) return true;
  return (
    c.name.toLowerCase().includes(q) ||
    (c.subjectName?.toLowerCase().includes(q) ?? false)
  );
}

const filtered = computed(() =>
  classes.value.filter((c) => {
    if (!matchesQuery(c)) return false;
    if (filter.value === 'wali') return c.isHomeroom;
    if (filter.value === 'mengajar') return c.scope === 'subject';
    return true;
  }),
);

// Kelas wali = every card of a homeroom class (general + subjects); Kelas ajar
// = subject cards of non-homeroom classes.
const sections = computed(() => {
  const out: { label: string; cards: ClassCard[] }[] = [];
  const wali = filtered.value.filter((c) => c.isHomeroom);
  const ajar = filtered.value.filter((c) => !c.isHomeroom);
  if (wali.length) out.push({ label: t('classHub.groupHomeroom'), cards: wali });
  if (ajar.length) out.push({ label: t('classHub.groupTeaching'), cards: ajar });
  return out;
});

const state = computed(() => {
  if (loading.value) return { status: 'loading' as const };
  if (error.value) return { status: 'error' as const, error: error.value };
  if (filtered.value.length === 0) return { status: 'empty' as const };
  return { status: 'content' as const };
});

const filters: { key: Filter; labelKey: string }[] = [
  { key: 'all', labelKey: 'classHub.filterAll' },
  { key: 'wali', labelKey: 'classHub.filterHomeroom' },
  { key: 'mengajar', labelKey: 'classHub.filterTeaching' },
];
const filterOptions = computed(() =>
  filters.map((f) => ({ key: f.key, label: t(f.labelKey) })),
);

// Subject key → deterministic colour, shared with the hub header so the card
// and the class you open read as the same "place".
function subjectKey(c: ClassCard): string {
  return c.subjectName ?? c.subjectId ?? c.id;
}
function gradientFor(c: ClassCard): string {
  return classHubGradientCss(isGeneralCard(c) ? null : subjectKey(c));
}
function accentFor(c: ClassCard): string {
  return classHubAccent(isGeneralCard(c) ? null : subjectKey(c));
}
function badgeText(c: ClassCard): string {
  return isGeneralCard(c) ? t('classHub.allSubjects') : c.subjectName ?? c.name;
}
function statusLine(c: ClassCard): string {
  const parts = [`${c.studentCount} ${t('classHub.kpiStudents')}`];
  if (c.activeTugas > 0) {
    parts.push(`${c.activeTugas} ${t('classHub.kpiActiveAssignments')}`);
  }
  if (c.needsGrading > 0) {
    parts.push(`${c.needsGrading} ${t('classHub.kpiNeedsGrading')}`);
  }
  return parts.join(' · ');
}
function whoLine(c: ClassCard): string {
  if (isGeneralCard(c)) {
    return `${t('classHub.roleHomeroom')} · ${t('classHub.viewOnly')}`;
  }
  return `${t('classHub.roleSubject')} · ${t('classHub.youTeach')}`;
}

function openClass(c: ClassCard) {
  router.push({
    name: 'teacher.classes.detail',
    params: { id: c.id },
    query: c.subjectId ? { subject_id: c.subjectId } : {},
  });
}
</script>

<template>
  <div class="p-4 md:p-6">
    <BrandPageHeader
      role="teacher"
      :title="t('classHub.title')"
      :meta="t('classHub.listSubtitle')"
      class="mb-4"
    />

    <PageFilterToolbar
      v-model:search="query"
      :search-placeholder="t('classHub.search')"
      class="mb-4"
    >
      <template #chips>
        <SegmentedControl
          :model-value="filter"
          :options="filterOptions"
          @update:model-value="filter = $event as Filter"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      :empty-title="t('classHub.emptyListTitle')"
      :empty-description="t('classHub.emptyListMsg')"
    >
      <div class="space-y-6">
        <section v-for="s in sections" :key="s.label">
          <h2 class="text-xs font-medium text-slate-500 mb-2">{{ s.label }}</h2>
          <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            <ClassHeroCard
              v-for="c in s.cards"
              :key="classCardKey(c)"
              :identity-key="subjectKey(c)"
              :badge="badgeText(c)"
              :name="c.name"
              :subline="statusLine(c)"
              :gradient="gradientFor(c)"
              @click="openClass(c)"
            >
              <template #footer>
                <div class="flex items-center gap-2 bg-white px-4 py-3">
                  <span class="min-w-0 flex-1 truncate text-sm text-slate-600">
                    {{ whoLine(c) }}
                  </span>
                  <span
                    class="text-sm font-semibold"
                    :style="{ color: accentFor(c) }"
                  >
                    {{ t('classHub.open') }}
                  </span>
                  <span :style="{ color: accentFor(c) }">›</span>
                </div>
              </template>
            </ClassHeroCard>
          </div>
        </section>
      </div>
    </AsyncView>
  </div>
</template>
