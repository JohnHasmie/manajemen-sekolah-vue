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

const filtered = computed(() =>
  classes.value.filter((c) => {
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
function eyebrow(c: ClassCard): string {
  return (isGeneralCard(c) ? t('classHub.allSubjects') : c.subjectName ?? c.name)
    .toUpperCase();
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

    <div class="mb-4">
      <SegmentedControl
        :model-value="filter"
        :options="filterOptions"
        @update:model-value="filter = $event as Filter"
      />
    </div>

    <AsyncView
      :state="state"
      :empty-title="t('classHub.emptyListTitle')"
      :empty-description="t('classHub.emptyListMsg')"
    >
      <div class="space-y-6">
        <section v-for="s in sections" :key="s.label">
          <h2 class="text-xs font-medium text-slate-500 mb-2">{{ s.label }}</h2>
          <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            <button
              v-for="c in s.cards"
              :key="classCardKey(c)"
              type="button"
              class="text-left rounded-2xl overflow-hidden ring-1 ring-slate-900/5 shadow-sm hover:shadow-md transition-shadow"
              @click="openClass(c)"
            >
              <!-- Gradient hero -->
              <div class="px-4 py-4 text-white" :style="{ background: gradientFor(c) }">
                <p class="text-[11px] font-extrabold tracking-wide uppercase text-white/70 truncate m-0">
                  {{ eyebrow(c) }}
                </p>
                <p class="mt-1 text-lg font-black leading-tight truncate m-0">
                  {{ c.name }}
                </p>
                <p class="mt-1.5 text-sm text-white/80 m-0">{{ statusLine(c) }}</p>
              </div>
              <!-- White footer -->
              <div class="flex items-center gap-2 px-4 py-3 bg-white">
                <span class="flex-1 min-w-0 text-sm text-slate-600 truncate">
                  {{ whoLine(c) }}
                </span>
                <span class="text-sm font-semibold" :style="{ color: accentFor(c) }">
                  {{ t('classHub.open') }}
                </span>
                <span :style="{ color: accentFor(c) }">›</span>
              </div>
            </button>
          </div>
        </section>
      </div>
    </AsyncView>
  </div>
</template>
