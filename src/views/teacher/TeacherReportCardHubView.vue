<!--
  TeacherReportCardHubView.vue — Rapor hub (Frame A).

  Web port of `teacher_report_card_overview.dart`. Lands the parent
  kelas on a per-class grid:

    1. BrandPageHeader (teacher) — kicker "Academic · Rapor", title
       "Homeroom Teacher", meta `N kelas · M student`
    2. KpiStripCards — Student total / Terbit / Diperiksa / Draft
    3. PageFilterToolbar — search input (filter class name)
    4. List of <ReportCardClassCard> — drill into per-class roster

  Endpoints:
    GET /raports/teacher-summary?teacher_id=  — per-class stats
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { ReportCardService } from '@/services/report-card.service';
import type { RaportClassSummary } from '@/types/report-card';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import ReportCardClassCard from '@/components/feature/ReportCardClassCard.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const auth = useAuthStore();
const router = useRouter();
const { t } = useI18n();

// ── Data state ──
const classes = ref<RaportClassSummary[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const searchQuery = ref<string>('');
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const teacherId = computed(() => auth.teacherId ?? auth.user?.id ?? '');

// ── Loader ──
async function reload() {
  if (!teacherId.value) {
    loadError.value = t('tutor.sekolah.reportCardHub.errorProfile');
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    classes.value = await ReportCardService.getTeacherClassSummary({
      teacher_id: teacherId.value,
    });
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(reload);
useAcademicYearWatcher(reload);

// ── Derived ──
const visibleClasses = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return classes.value;
  return classes.value.filter((c) =>
    c.class_name.toLowerCase().includes(q),
  );
});

const kpiCards = computed<KpiCard[]>(() => {
  let students = 0;
  let terbit = 0;
  let diperiksa = 0;
  let draf = 0;
  for (const c of classes.value) {
    students += c.student_count;
    terbit += c.published_count;
    diperiksa += c.final_count;
    draf += c.draft_count;
  }
  return [
    {
      icon: 'users',
      label: t('tutor.sekolah.reportCardHub.kpiStudents'),
      value: students,
      tone: 'brand',
    },
    {
      icon: 'check-circle',
      label: t('tutor.sekolah.reportCardHub.kpiPublished'),
      value: terbit,
      tone: 'green',
    },
    {
      icon: 'edit',
      label: t('tutor.sekolah.reportCardHub.kpiReviewed'),
      value: diperiksa,
      tone: diperiksa > 0 ? 'amber' : 'slate',
      accented: diperiksa > 0,
    },
    {
      icon: 'file-text',
      label: t('tutor.sekolah.reportCardHub.kpiDraft'),
      value: draf,
      tone: 'slate',
    },
  ];
});

const listState = computed<AsyncState<RaportClassSummary[]>>(() => {
  if (isLoading.value && classes.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleClasses.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleClasses.value };
});

// ── Actions ──
function openClass(cls: RaportClassSummary) {
  // Phase 3 will register `teacher.report-cards.class` for the per-
  // class roster. Until then, surface a friendly placeholder so the
  // tap doesn't 404.
  const target = router.resolve({
    name: 'teacher.report-cards.class',
    params: { classId: cls.class_id },
  });
  if (target.matched.length === 0) {
    toast.value = {
      message: t('tutor.sekolah.reportCardHub.classListSoon', { className: cls.class_name }),
      tone: 'success',
    };
    return;
  }
  router.push(target);
}

// Avoid lint warning while `auth` is only consumed via teacherId.
void auth;
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      :kicker="t('tutor.sekolah.reportCardHub.kicker')"
      :title="t('tutor.sekolah.reportCardHub.title')"
      :meta="
        classes.length > 0
          ? t('tutor.sekolah.reportCardHub.meta', { classes: classes.length, students: classes.reduce((a, c) => a + c.student_count, 0) })
          : t('tutor.sekolah.reportCardHub.metaLoading')
      "
      :live-dot="false"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      :search-placeholder="t('tutor.sekolah.reportCardHub.searchPlaceholder')"
    >
      <template #chips>
        <span class="text-2xs font-bold text-slate-500 px-1">
          {{ t('tutor.sekolah.reportCardHub.classCount', { count: visibleClasses.length }) }}
        </span>
      </template>
    </PageFilterToolbar>

    <!-- CLASS LIST -->
    <AsyncView
      :state="listState"
      :empty-title="
        searchQuery
          ? t('tutor.sekolah.reportCardHub.emptyTitleSearch')
          : t('tutor.sekolah.reportCardHub.emptyTitle')
      "
      :empty-description="t('tutor.sekolah.reportCardHub.emptyDescription')"
      empty-icon="users"
      @retry="reload"
    >
      <div class="space-y-2.5">
        <ReportCardClassCard
          v-for="cls in visibleClasses"
          :key="cls.class_id"
          :cls="cls"
          @click="openClass"
        />
      </div>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
