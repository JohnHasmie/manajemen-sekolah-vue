<!--
  TeacherRecommendationView.vue — Rekomendasi AI hub (Frame A).

  Web port of `recommendation_class_screen.dart`. Lands the teacher
  on a class-hub grid:

    1. <BrandPageHeader role="guru"> — kicker + title + meta
    2. <RoleToggleChipRow> — Mengajar ↔ Wali Kelas (auto-hidden when
       teacher has no homeroom)
    3. <KpiStripCards> — Total RPP rec / Pending / Selesai / Hari Ini
       (aggregate across visible classes)
    4. <PageFilterToolbar> — search (filters class name client-side)
    5. <RecommendationClassCard> per class — drill into student list,
       or fire "Buat Baru" which opens the generate sheet (Phase 5).

  Per-rec list lives one drill-down deeper — see Phase 3's
  TeacherRecommendationStudentsView.

  Endpoints:
    GET /classrooms                                — class roster
    GET /recommendations/class/{id}/summary        — per-card KPI
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import {
  RateLimitError,
  RecommendationService,
} from '@/services/recommendations.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import type {
  GenerateConfig,
  RecommendationClassSummary,
} from '@/types/recommendations';
import type { Classroom, Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import RoleToggleChipRow, {
  type RoleOption,
} from '@/components/feature/RoleToggleChipRow.vue';
import RecommendationClassCard from '@/components/feature/RecommendationClassCard.vue';
import RecommendationGenerateSheet from '@/components/feature/RecommendationGenerateSheet.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';

const auth = useAuthStore();
const academicYear = useAcademicYearStore();
const router = useRouter();
const { t } = useI18n();

// ── Mode toggle (Mengajar ↔ Wali Kelas) ──
// `mengajar` = teacher_id scope; `wali:<classId>` = homeroom scope
// for the picked class. We pick the first role on mount and let
// RoleToggleChipRow drive the change.
const selectedRoleId = ref<string>('mengajar');

const roleOptions = computed<RoleOption[]>(() => {
  const opts: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: t('tutor.sekolah.recommendationHub.roleTeachingShort'),
      subLabel: t('tutor.sekolah.recommendationHub.roleTeachingSub'),
      avatarInitials: 'MG',
    },
  ];
  for (const h of auth.homeroomClasses ?? []) {
    opts.push({
      id: `wali:${h.id}`,
      shortName: t('tutor.sekolah.recommendationHub.roleHomeroomShort', { name: h.name }),
      subLabel: t('tutor.sekolah.recommendationHub.roleHomeroomSub'),
      avatarInitials: h.name.slice(0, 2).toUpperCase(),
    });
  }
  return opts;
});

const isHomeroomMode = computed(() => selectedRoleId.value.startsWith('wali:'));
const activeHomeroomId = computed(() =>
  isHomeroomMode.value ? selectedRoleId.value.slice('wali:'.length) : null,
);

// ── Data state ──
const classes = ref<Classroom[]>([]);
const summaryByClass = ref<Record<string, RecommendationClassSummary | null>>(
  {},
);
const loadingSummaryFor = ref<Set<string>>(new Set());

const isLoading = ref(true);
const loadError = ref<string | null>(null);
const searchQuery = ref<string>('');
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Subjects cache (drives the Generate sheet) ──
const subjects = ref<Subject[]>([]);
// Load the subject options for the Generate sheet, scoped to the active
// context for the picked class:
//  - Mengajar mode → ONLY the subjects the logged-in teacher teaches in
//    this class (GET /teacher/{id}/subjects?scope=teaching&class_id=…).
//  - Wali mode → all school subjects (homeroom oversight is cross-teacher).
// Previously this always loaded every school subject, so the Mengajar tab
// listed subjects the teacher doesn't teach.
async function loadSheetSubjects(classId: string) {
  try {
    if (isHomeroomMode.value) {
      const res = await SubjectService.list({ per_page: 100 });
      subjects.value = res.items;
    } else if (teacherId.value) {
      subjects.value = await SubjectService.listForTeacher(
        teacherId.value,
        'teaching',
        classId,
      );
    } else {
      subjects.value = [];
    }
  } catch {
    subjects.value = [];
  }
}

// ── Generate sheet state ──
interface GenerateTarget {
  classId: string;
  className: string;
  totalStudents: number;
  atRiskCount: number;
}
const generateTarget = ref<GenerateTarget | null>(null);
const isGenerating = ref<Set<string>>(new Set()); // classIds in flight
// Inline progress banner shown while a generate batch is running.
const progressMessage = ref<string | null>(null);

// ── Loaders ──
async function loadClasses() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await ClassroomService.list({ per_page: 100 });
    classes.value = res.items;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

/**
 * Fetch every visible class's summary in parallel. Throttled implicitly
 * by `loadingSummaryFor` so a fast user-driven re-trigger doesn't
 * double-fire. Each cell renders its own loading skeleton.
 */
async function loadSummariesForVisible() {
  const list = visibleClasses.value;
  if (list.length === 0) return;
  // Skip classes we already have a summary for unless the academic
  // year just changed — the watcher resets the cache before calling
  // this, so we don't have to detect ay changes here.
  const todo = list.filter((c) => summaryByClass.value[c.id] === undefined);
  if (todo.length === 0) return;
  for (const c of todo) loadingSummaryFor.value.add(c.id);
  // Promise.all so all cards reveal numbers near-simultaneously;
  // failures degrade to an empty stat strip per card. Pass the active
  // academic year EXPLICITLY: the AI client (aiApi) doesn't carry the
  // year-injecting interceptor the core client does, so without this the
  // summary counted ALL years (incl. recs with a null/old year) — that's
  // why the web showed 62 pending vs mobile's 38 (mobile forwards the year).
  const academicYearId = academicYear.selectedYearId ?? undefined;
  await Promise.all(
    todo.map(async (c) => {
      try {
        const summary = await RecommendationService.getClassSummary(c.id, {
          academic_year_id: academicYearId,
        });
        summaryByClass.value[c.id] = summary;
      } catch {
        summaryByClass.value[c.id] = null;
      } finally {
        loadingSummaryFor.value.delete(c.id);
      }
    }),
  );
}

onMounted(async () => {
  // Subjects are loaded per-class when the Generate sheet opens (scoped to
  // teacher + class), so no school-wide preload here.
  await loadClasses();
  await loadSummariesForVisible();
});

// Drop cached summaries when the academic year flips so the cards
// re-fetch against the new year scope.
useAcademicYearWatcher(() => {
  summaryByClass.value = {};
  loadSummariesForVisible();
});

// ── Visible class list ──
const visibleClasses = computed(() => {
  let list = classes.value;
  if (isHomeroomMode.value && activeHomeroomId.value) {
    // Wali mode → only the picked homeroom class is in scope.
    list = list.filter((c) => c.id === activeHomeroomId.value);
  }
  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    list = list.filter((c) => c.name.toLowerCase().includes(q));
  }
  return list;
});

// Re-fetch summaries when role mode flips (different scope).
watch(selectedRoleId, () => {
  loadSummariesForVisible();
});

// ── KPI strip (aggregate across visible classes) ──
const kpiCards = computed<KpiCard[]>(() => {
  let pending = 0;
  let in_progress = 0;
  let completed = 0;
  let total = 0;
  for (const c of visibleClasses.value) {
    const s = summaryByClass.value[c.id];
    if (!s) continue;
    pending += s.by_status.pending ?? 0;
    in_progress += s.by_status.in_progress ?? 0;
    completed += s.by_status.completed ?? 0;
    total += s.total_recommendations ?? 0;
  }
  return [
    {
      icon: 'sparkles',
      label: t('tutor.sekolah.recommendationHub.kpiTotal'),
      value: total,
      tone: 'brand',
    },
    {
      icon: 'bell',
      label: t('tutor.sekolah.recommendationHub.kpiPending'),
      value: pending,
      tone: pending > 0 ? 'amber' : 'slate',
      accented: pending > 0,
    },
    {
      icon: 'edit',
      label: t('tutor.sekolah.recommendationHub.kpiInProgress'),
      value: in_progress,
      tone: 'violet',
    },
    {
      icon: 'check-circle',
      label: t('tutor.sekolah.recommendationHub.kpiCompleted'),
      value: completed,
      tone: 'green',
    },
  ];
});

// ── List state (for AsyncView) ──
const listState = computed<AsyncState<Classroom[]>>(() => {
  if (isLoading.value && classes.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleClasses.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleClasses.value };
});

// ── Card actions ──
function openStudents(cls: { id: string; name: string }) {
  // Phase 3 will register the `teacher.recommendations.students`
  // route. Until then, surface a friendly placeholder so the card
  // tap doesn't navigate to a 404.
  const target = router.resolve({
    name: 'teacher.recommendations.students',
    params: { classId: cls.id },
    query: isHomeroomMode.value ? { scope: 'wali' } : undefined,
  });
  if (target.matched.length === 0) {
    toast.value = {
      message: t('tutor.sekolah.recommendationHub.placeholderStudentsToast', { name: cls.name }),
      tone: 'success',
    };
    return;
  }
  router.push(target);
}

async function openGenerate(cls: {
  id: string;
  name: string;
  student_count?: number;
}) {
  // Load the per-class subject options BEFORE opening the sheet so it mounts
  // with the correct list (and so Mengajar mode is scoped to this teacher's
  // subjects in this class).
  await loadSheetSubjects(cls.id);

  const summary = summaryByClass.value[cls.id];
  generateTarget.value = {
    classId: cls.id,
    className: cls.name,
    totalStudents: cls.student_count ?? 0,
    // at_risk fallback chain matches Flutter: backend value → high
    // priority count → 30% of enrolment as a sane guess.
    atRiskCount:
      summary?.at_risk_count ??
      summary?.by_priority?.high ??
      Math.round((cls.student_count ?? 0) * 0.3),
  };
}

const teacherId = computed(() => auth.teacherId ?? auth.user?.id ?? '');

async function runGenerate(cfg: GenerateConfig) {
  if (!generateTarget.value) return;
  if (!teacherId.value) {
    toast.value = {
      message: t('tutor.sekolah.recommendationHub.teacherProfileMissing'),
      tone: 'error',
    };
    return;
  }
  const tgt = generateTarget.value;
  isGenerating.value.add(tgt.classId);
  progressMessage.value = t('tutor.sekolah.recommendationHub.progressSending', {
    count: cfg.subject_ids.length,
    className: tgt.className,
  });
  try {
    const results = await RecommendationService.dispatchGenerate({
      cfg,
      teacher_id: teacherId.value,
      class_id: tgt.classId,
    });
    // Collect async job_ids and poll them in parallel. Sync responses
    // (no job_id) are done already — count them as successful.
    const asyncJobs = results.filter(
      (r) => !r.error && r.response?.async && r.response.job_id,
    );
    const syncDone = results.filter(
      (r) => !r.error && !r.response?.async,
    ).length;
    const failed = results.filter((r) => !!r.error);

    let polledDone = 0;
    const total = asyncJobs.length;
    if (total > 0) {
      progressMessage.value = t('tutor.sekolah.recommendationHub.progressProcessing', {
        total,
        done: syncDone,
      });
      await Promise.all(
        asyncJobs.map(async (r) => {
          try {
            await RecommendationService.pollJobUntilComplete(
              r.response!.job_id!,
              { intervalMs: 3000, maxAttempts: 40 },
            );
            polledDone += 1;
            progressMessage.value = t('tutor.sekolah.recommendationHub.progressProcessingProgress', {
              total,
              done: polledDone + syncDone,
              grandTotal: total + syncDone,
            });
          } catch (e) {
            failed.push({
              subject_id: r.subject_id,
              student_id: r.student_id,
              error: e instanceof Error ? e : new Error(String(e)),
            });
          }
        }),
      );
    }

    // Final toast surfaces partial-failure transparently (Flutter pattern).
    const okCount = syncDone + polledDone;
    if (failed.length === 0) {
      toast.value = {
        message: t('tutor.sekolah.recommendationHub.successAllToast', { count: okCount, className: tgt.className }),
        tone: 'success',
      };
    } else if (okCount > 0) {
      toast.value = {
        message: t('tutor.sekolah.recommendationHub.partialToast', { ok: okCount, failed: failed.length }),
        tone: 'error',
      };
    } else {
      // Show the (already friendly) error message directly — no technical
      // prefix or raw "AI error" fallback.
      toast.value = {
        message:
          failed[0].error?.message ??
          t('tutor.sekolah.recommendationHub.aiUnavailableToast'),
        tone: 'error',
      };
    }
    // Refresh summary so the card stats reflect the new recs.
    summaryByClass.value[tgt.classId] = undefined as unknown as null;
    await loadSummariesForVisible();
  } catch (e) {
    if (e instanceof RateLimitError) {
      toast.value = {
        message:
          e.dailyLimit && e.dailyUsage !== undefined
            ? t('tutor.sekolah.recommendationHub.rateLimitUsageToast', { usage: e.dailyUsage, limit: e.dailyLimit })
            : t('tutor.sekolah.recommendationHub.rateLimitToast'),
        tone: 'error',
      };
    } else {
      toast.value = { message: (e as Error).message, tone: 'error' };
    }
  } finally {
    isGenerating.value.delete(tgt.classId);
    progressMessage.value = null;
    generateTarget.value = null;
  }
}

</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      :kicker="t('tutor.sekolah.recommendationHub.kicker')"
      :title="t('tutor.sekolah.recommendationHub.title')"
      :meta="
        isHomeroomMode
          ? t('tutor.sekolah.recommendationHub.metaHomeroom')
          : t('tutor.sekolah.recommendationHub.metaTeaching')
      "
      :live-dot="false"
    >
      <template
        v-if="roleOptions.length > 1"
        #role-toggle
      >
        <RoleToggleChipRow
          :roles="roleOptions"
          :selected-role-id="selectedRoleId"
          @update:selected-role-id="selectedRoleId = $event"
        />
      </template>
    </BrandPageHeader>

    <!-- KPI strip -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      :search-placeholder="t('tutor.sekolah.recommendationHub.searchPlaceholder')"
    >
      <template #chips>
        <span class="text-[11px] font-bold text-slate-500 px-1">
          {{ t('tutor.sekolah.recommendationHub.classCount', { count: visibleClasses.length }) }}
        </span>
      </template>
    </PageFilterToolbar>

    <!-- CLASS HUB LIST -->
    <AsyncView
      :state="listState"
      :empty-title="
        isHomeroomMode
          ? t('tutor.sekolah.recommendationHub.emptyHomeroom')
          : searchQuery
            ? t('tutor.sekolah.recommendationHub.emptySearch')
            : t('tutor.sekolah.recommendationHub.emptyClasses')
      "
      :empty-description="t('tutor.sekolah.recommendationHub.emptyDescription')"
      empty-icon="users"
      @retry="loadClasses"
    >
      <div class="space-y-2.5">
        <RecommendationClassCard
          v-for="cls in visibleClasses"
          :key="cls.id"
          :cls="{
            id: cls.id,
            name: cls.name,
            student_count: cls.student_count,
          }"
          :summary="summaryByClass[cls.id] ?? null"
          :is-loading="loadingSummaryFor.has(cls.id)"
          :is-generating="isGenerating.has(cls.id)"
          :is-homeroom="isHomeroomMode"
          @view-students="openStudents"
          @generate="openGenerate"
        />
      </div>
    </AsyncView>

    <!-- AI progress banner — non-blocking, sticks above the toast -->
    <div
      v-if="progressMessage"
      class="fixed bottom-4 right-4 z-40 max-w-sm bg-violet-600 text-white rounded-2xl shadow-xl px-4 py-3 flex items-center gap-3"
    >
      <NavIcon name="loader" :size="16" class="animate-spin flex-shrink-0" />
      <p class="text-[12px] font-medium leading-snug">{{ progressMessage }}</p>
    </div>

    <!-- GENERATE SHEET -->
    <RecommendationGenerateSheet
      v-if="generateTarget"
      :class-name="generateTarget.className"
      :total-students="generateTarget.totalStudents"
      :at-risk-count="generateTarget.atRiskCount"
      :subjects="subjects.map((s) => ({ id: s.id, name: s.name }))"
      :busy="isGenerating.has(generateTarget.classId)"
      @close="generateTarget = null"
      @generate="runGenerate"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
