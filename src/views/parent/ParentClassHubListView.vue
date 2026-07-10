<!--
  Parent "Kelas" list (web) — the active child's classes as a flat, read-only
  list, with a child selector when there's more than one child. Mirrors the
  mobile parent list. Tapping a card opens the read-only per-class hub.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
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
const { children, activeChildId, setActive } = useChildPicker();

const loading = ref(true);
const error = ref<string | null>(null);
const classes = ref<ClassCard[]>([]);

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

const childOptions = computed(() =>
  children.value.map((c) => ({ key: c.student_id, label: c.name })),
);

const state = computed(() => {
  if (loading.value) return { status: 'loading' as const };
  if (error.value) return { status: 'error' as const, error: error.value };
  if (classes.value.length === 0) return { status: 'empty' as const };
  return { status: 'content' as const };
});

// Semua mapel (general overview) + Per mata pelajaran (per-subject cards).
const sections = computed(() => {
  const out: { label: string; cards: ClassCard[] }[] = [];
  const general = classes.value.filter((c) => isGeneralCard(c));
  const subjects = classes.value.filter((c) => isSubjectScoped(c));
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
function eyebrow(c: ClassCard): string {
  return (isGeneralCard(c) ? t('classHub.allSubjects') : c.subjectName ?? c.name)
    .toUpperCase();
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
    <BrandPageHeader
      role="wali"
      :title="t('classHub.title')"
      :meta="t('classHub.listSubtitle')"
      class="mb-4"
    />

    <div v-if="childOptions.length > 1" class="mb-4">
      <SegmentedControl
        :model-value="activeChildId"
        :options="childOptions"
        @update:model-value="setActive(String($event))"
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
