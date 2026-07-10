<!--
  Parent "Kelas" list (web) — the active child's classes as subject-level
  gradient cards, split Semua mapel / Per mata pelajaran, read-only. Uses the
  shared ParentPageHeader (built-in child picker) + ClassHeroCard, mirroring the
  mobile parent list. Tapping a card opens the read-only per-class hub.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import ClassHeroCard from '@/components/feature/ClassHeroCard.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import { useChildPicker } from '@/composables/useChildPicker';
import { ClassHubService } from '@/services/class-hub.service';
import {
  classCardKey,
  isGeneralCard,
  isSubjectScoped,
  type ClassCard,
} from '@/types/class-hub';
import { classHubAccent, classHubGradientCss } from '@/utils/classHubTheme';

const { t } = useI18n();
const router = useRouter();
// ParentPageHeader renders the child-picker chips itself; we only need the
// active child here to load its classes.
const { activeChildId } = useChildPicker();

const loading = ref(true);
const error = ref<string | null>(null);
const classes = ref<ClassCard[]>([]);
const query = ref('');

async function load() {
  if (!activeChildId.value) {
    classes.value = [];
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = null;
  try {
    classes.value = await ClassHubService.myClasses(activeChildId.value);
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e);
  } finally {
    loading.value = false;
  }
}
watch(activeChildId, load, { immediate: true });

function matchesQuery(c: ClassCard): boolean {
  const q = query.value.trim().toLowerCase();
  if (!q) return true;
  return (
    c.name.toLowerCase().includes(q) ||
    (c.subjectName?.toLowerCase().includes(q) ?? false)
  );
}
const visible = computed(() => classes.value.filter(matchesQuery));

const state = computed(() => {
  if (loading.value) return { status: 'loading' as const };
  if (error.value) return { status: 'error' as const, error: error.value };
  if (visible.value.length === 0) return { status: 'empty' as const };
  return { status: 'content' as const };
});

// Semua mapel (general overview) + Per mata pelajaran (per-subject cards).
const sections = computed(() => {
  const out: { label: string; cards: ClassCard[] }[] = [];
  const general = visible.value.filter((c) => isGeneralCard(c));
  const subjects = visible.value.filter((c) => isSubjectScoped(c));
  if (general.length) {
    out.push({ label: t('classHub.allSubjects'), cards: general });
  }
  if (subjects.length) {
    out.push({ label: t('classHub.groupPerSubject'), cards: subjects });
  }
  return out;
});

// Subject key → deterministic colour, shared with the hub header.
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
  return `${c.studentCount} ${t('classHub.kpiStudents')}`;
}
function whoLine(c: ClassCard): string {
  if (isGeneralCard(c)) {
    return `${t('classHub.allSubjects')} · ${t('classHub.viewOnly')}`;
  }
  return c.teacherName
    ? `${t('classHub.teacherLabel')}: ${c.teacherName}`
    : t('classHub.roleSubject');
}

function openClass(c: ClassCard) {
  router.push({
    name: 'parent.classes.detail',
    params: { id: c.id },
    query: c.subjectId ? { subject_id: c.subjectId } : {},
  });
}
</script>

<template>
  <div class="p-4 md:p-6">
    <ParentPageHeader
      :title="t('classHub.title')"
      :meta="t('classHub.listSubtitle')"
      class="mb-4"
    />

    <PageFilterToolbar
      v-model:search="query"
      :search-placeholder="t('classHub.search')"
      class="mb-4"
    />

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
