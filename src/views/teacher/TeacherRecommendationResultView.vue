<!--
  TeacherRecommendationResultView.vue — per-student rec list (Frame C).

  Web port of `recommendation_result_screen.dart`. Route entry:
    /teacher/recommendations/class/:classId/student/:studentId?scope=parent

  Layout:
    1. Back chevron row → kembali ke student list
    2. BrandPageHeader (teacher) — kicker `Kelas X · <Mode>`, title with
       student name, meta line with NIS / counts
    3. Hero card — 56dp avatar + name + meta + violet `n REC` pill +
       status mini-pills + DIBACA WALI pill when any rec has reads
    4. Status filter chip strip (Semua / Pending / Proses / Selesai /
       Ditolak)
    5. Vertical list of <RecommendationCard role="teacher">
       — inline status toggle (Tandai Diterapkan) via updateRecStatus
       — pencil edit → Phase 7 (placeholder toast for now)
       — share / history buttons → Phase 6 (placeholder toast)

  Auto-fires markRecommendationSharesSeenByTeacher on mount so the
  dashboard's "parent reply unread" signal silences correctly.

  Endpoints:
    GET   /recommendations                — paginated list
    PATCH /recommendations/{id}/status    — toggle Diterapkan
    POST  /recommendations/{id}/mark-shares-seen  — fire-and-forget
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { RecommendationService } from '@/services/recommendations.service';
import { StudentService } from '@/services/students.service';
import { ClassroomService } from '@/services/classrooms.service';
import type {
  LearningRecommendation,
  RecStatus,
} from '@/types/recommendations';
import { STATUS_LABELS } from '@/types/recommendations';
import type { Classroom, Student } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import RecommendationCard from '@/components/feature/RecommendationCard.vue';
import RecommendationShareSheet from '@/components/feature/RecommendationShareSheet.vue';
import RecommendationShareHistorySheet from '@/components/feature/RecommendationShareHistorySheet.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));
const studentId = computed(() => String(route.params.studentId ?? ''));
const isHomeroomMode = computed(() => route.query.scope === 'wali');

// ── Filter ──
type StatusChip = 'all' | RecStatus;
const statusFilter = ref<StatusChip>('all');

// ── Data state ──
const cls = ref<Classroom | null>(null);
const student = ref<Student | null>(null);
const items = ref<LearningRecommendation[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const updatingIds = ref<Set<string>>(new Set());
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Share + history sheet state ──
const shareTarget = ref<LearningRecommendation | null>(null);
const historyTarget = ref<LearningRecommendation | null>(null);

const teacherId = computed(() => auth.teacherId ?? auth.user?.id ?? '');

// ── Loaders ──
async function loadContext() {
  // Hydrate class + student name for the header. Best-effort —
  // either one missing falls through to a generic label.
  try {
    const [cRes, sRes] = await Promise.all([
      ClassroomService.list({ per_page: 200 }),
      StudentService.list({ class_ids: [classId.value], per_page: 200 }),
    ]);
    cls.value = cRes.items.find((c) => c.id === classId.value) ?? null;
    student.value = sRes.items.find((s) => s.id === studentId.value) ?? null;
  } catch {
    // graceful — header copy degrades to "Kelas — / Student —"
  }
}

async function loadRecs() {
  if (!classId.value || !studentId.value) {
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await RecommendationService.listLearningRecs({
      class_id: classId.value,
      student_id: studentId.value,
      teacher_id: isHomeroomMode.value ? undefined : teacherId.value || undefined,
      homeroom_class_id: isHomeroomMode.value ? classId.value : undefined,
      per_page: 50,
    });
    items.value = res.items;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await Promise.all([loadContext(), loadRecs()]);
});

// React to scope flip (back+forward).
watch(
  () => route.fullPath,
  () => {
    loadRecs();
  },
);

useAcademicYearWatcher(() => loadRecs());

// Fire-and-forget mark-seen — silences dashboard Signal E once the
// homeroom teacher opens the result view. Wrapped per rec because the
// backend records per-recipient seen flags scoped to the rec id.
watch(items, (list) => {
  for (const rec of list) {
    if ((rec.share_recipient_count ?? 0) > 0) {
      // Fire-and-forget; service swallows failures internally.
      RecommendationService.markRecommendationSharesSeenByTeacher(rec.id);
    }
  }
});

// ── Derived ──
const filteredItems = computed(() => {
  if (statusFilter.value === 'all') return items.value;
  return items.value.filter((r) => r.status === statusFilter.value);
});

const counts = computed(() => {
  const all = items.value;
  return {
    total: all.length,
    pending: all.filter((r) => r.status === 'pending').length,
    in_progress: all.filter((r) => r.status === 'in_progress').length,
    completed: all.filter((r) => r.status === 'completed').length,
    dismissed: all.filter((r) => r.status === 'dismissed').length,
    read_count: all.reduce((acc, r) => acc + (r.share_read_count ?? 0), 0),
    share_count: all.reduce((acc, r) => acc + (r.share_recipient_count ?? 0), 0),
  };
});

const statusOptions = computed<{ key: StatusChip; label: string }[]>(() => [
  { key: 'all', label: t('tutor.sekolah.recommendationResult.filterAll') },
  { key: 'pending', label: STATUS_LABELS.pending },
  { key: 'in_progress', label: STATUS_LABELS.in_progress },
  { key: 'completed', label: STATUS_LABELS.completed },
  { key: 'dismissed', label: STATUS_LABELS.dismissed },
]);

const listState = computed<AsyncState<LearningRecommendation[]>>(() => {
  if (isLoading.value && items.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (filteredItems.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredItems.value };
});

// ── Header copy ──
const headerKicker = computed(() => {
  const className = cls.value?.name ?? '—';
  return t('tutor.sekolah.recommendationResult.headerKicker', {
    className,
    mode: isHomeroomMode.value
      ? t('tutor.sekolah.recommendationResult.modeHomeroom')
      : t('tutor.sekolah.recommendationResult.modeTeaching'),
  });
});

const headerTitle = computed(() => student.value?.name ?? t('tutor.sekolah.recommendationResult.titleFallback'));

const headerMeta = computed(() => {
  const parts: string[] = [];
  if (student.value?.student_number) {
    parts.push(t('tutor.sekolah.recommendationResult.nisLabel', { nis: student.value.student_number }));
  }
  parts.push(t('tutor.sekolah.recommendationResult.totalRecs', { count: counts.value.total }));
  if (counts.value.pending > 0)
    parts.push(t('tutor.sekolah.recommendationResult.pendingCount', { count: counts.value.pending }));
  return parts.join(' · ');
});

// ── Status toggle ──
async function toggleStatus(rec: LearningRecommendation) {
  if (!teacherId.value) {
    toast.value = {
      message: t('tutor.sekolah.recommendationResult.teacherProfileMissing'),
      tone: 'error',
    };
    return;
  }
  const next: RecStatus = rec.status === 'completed' ? 'pending' : 'completed';
  updatingIds.value.add(rec.id);
  try {
    await RecommendationService.updateRecStatus({
      rec_id: rec.id,
      status: next,
      teacher_id: teacherId.value,
    });
    // Optimistic local patch — refetch in the background for canonical
    // counts. The pill row and footer button flip immediately.
    const idx = items.value.findIndex((r) => r.id === rec.id);
    if (idx >= 0) {
      items.value[idx] = { ...items.value[idx], status: next };
    }
    toast.value = {
      message:
        next === 'completed'
          ? t('tutor.sekolah.recommendationResult.markedAppliedToast', { title: rec.title })
          : t('tutor.sekolah.recommendationResult.revertedPendingToast', { title: rec.title }),
      tone: 'success',
    };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    updatingIds.value.delete(rec.id);
  }
}

function onEdit(rec: LearningRecommendation) {
  router.push({
    name: 'teacher.recommendations.edit',
    params: { recId: rec.id },
  });
}

function onShare(rec: LearningRecommendation) {
  // Refetch the rec first so `student_parents` denorm is fresh —
  // the list endpoint may have shipped a stale or empty parents
  // array if the homeroom eager-load didn't fire.
  RecommendationService.getLearningRec(rec.id)
    .then((hydrated) => {
      shareTarget.value = hydrated ?? rec;
    })
    .catch(() => {
      shareTarget.value = rec;
    });
}

function onViewHistory(rec: LearningRecommendation) {
  historyTarget.value = rec;
}

function onShareSucceeded(updated: LearningRecommendation) {
  // Optimistic local patch so the share-state pill flips immediately.
  const idx = items.value.findIndex((r) => r.id === updated.id);
  if (idx >= 0) {
    items.value[idx] = { ...items.value[idx], ...updated };
  }
  toast.value = { message: t('tutor.sekolah.recommendationResult.sharedToast'), tone: 'success' };
}

function onHistoryChanged() {
  // Reload the rec list so counters + pills reflect remind / revoke
  // / edit-resend actions.
  loadRecs();
}

function onHistoryOpenShare() {
  // User pressed "Bagikan Lagi" — close history, open share for the
  // same rec.
  if (historyTarget.value) {
    const tgt = historyTarget.value;
    historyTarget.value = null;
    onShare(tgt);
  }
}

function goBack() {
  router.push({
    name: 'teacher.recommendations.students',
    params: { classId: classId.value },
    query: isHomeroomMode.value ? { scope: 'wali' } : undefined,
  });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- BACK CHEVRON -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('tutor.sekolah.recommendationResult.backToStudents') }}
      </button>
    </div>

    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      :kicker="headerKicker"
      :title="headerTitle"
      :meta="headerMeta"
      :live-dot="false"
    />

    <!-- HERO CARD -->
    <section class="bg-white border border-slate-200 rounded-2xl p-4 flex items-center gap-3">
      <InitialsAvatar
        :name="student?.name || '?'"
        :size="56"
        :border-radius="16"
        color="#1B6FB8"
      />
      <div class="flex-1 min-w-0">
        <p class="text-[14px] font-black text-slate-900 truncate">
          {{ student?.name || t('tutor.sekolah.recommendationResult.loadingStudent') }}
        </p>
        <p class="text-2xs text-slate-500 mt-0.5">
          <template v-if="student?.student_number">
            {{ t('tutor.sekolah.recommendationResult.nisLabel', { nis: student.student_number }) }}
          </template>
          <template v-else>{{ t('tutor.sekolah.recommendationResult.noNis') }}</template>
          <template v-if="cls"> · {{ cls.name }}</template>
        </p>
        <div class="flex items-center gap-1 flex-wrap mt-2">
          <span
            v-if="counts.pending > 0"
            class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full bg-amber-100 text-amber-700 uppercase tracking-wider"
          >
            {{ t('tutor.sekolah.recommendationResult.pillPending', { count: counts.pending }) }}
          </span>
          <span
            v-if="counts.in_progress > 0"
            class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full bg-brand-cobalt/15 text-brand-cobalt uppercase tracking-wider"
          >
            {{ t('tutor.sekolah.recommendationResult.pillInProgress', { count: counts.in_progress }) }}
          </span>
          <span
            v-if="counts.completed > 0"
            class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700 uppercase tracking-wider"
          >
            {{ t('tutor.sekolah.recommendationResult.pillCompleted', { count: counts.completed }) }}
          </span>
          <span
            v-if="counts.read_count > 0"
            class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 uppercase tracking-wider"
          >
            {{ t('tutor.sekolah.recommendationResult.pillReadByParent', { count: counts.read_count }) }}
          </span>
        </div>
      </div>
      <span
        v-if="counts.total > 0"
        class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[12px] font-black bg-violet-100 text-violet-700 flex-shrink-0"
      >
        {{ counts.total }}
        <span class="text-4xs uppercase tracking-wider opacity-80">{{ t('tutor.sekolah.recommendationResult.recBadge') }}</span>
      </span>
    </section>

    <!-- STATUS CHIPS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="opt in statusOptions"
        :key="opt.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-2xs font-bold transition border inline-flex items-center gap-1.5"
        :class="
          statusFilter === opt.key
            ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
        "
        @click="statusFilter = opt.key"
      >
        {{ opt.label }}
        <span
          v-if="opt.key !== 'all'"
          class="text-[9.5px] font-bold tabular-nums px-1.5 py-0.5 rounded-full"
          :class="
            statusFilter === opt.key
              ? 'bg-white/20 text-white'
              : 'bg-slate-100 text-slate-500'
          "
        >
          {{ counts[opt.key] }}
        </span>
      </button>
    </div>

    <!-- LIST -->
    <AsyncView
      :state="listState"
      :empty-title="
        statusFilter === 'all'
          ? t('tutor.sekolah.recommendationResult.emptyAll')
          : t('tutor.sekolah.recommendationResult.emptyFiltered', { status: STATUS_LABELS[statusFilter as RecStatus] ?? '' })
      "
      :empty-description="t('tutor.sekolah.recommendationResult.emptyDescription')"
      empty-icon="sparkles"
      @retry="loadRecs"
    >
      <div class="space-y-3">
        <RecommendationCard
          v-for="rec in filteredItems"
          :key="rec.id"
          :rec="rec"
          :is-updating-status="updatingIds.has(rec.id)"
          @toggle-status="toggleStatus"
          @edit="onEdit"
          @share="onShare"
          @view-history="onViewHistory"
        />
      </div>
    </AsyncView>

    <!-- SHARE SHEET (Frame H) -->
    <RecommendationShareSheet
      v-if="shareTarget"
      :rec="shareTarget"
      :teacher-id="teacherId"
      @close="shareTarget = null"
      @shared="onShareSucceeded"
    />

    <!-- SHARE HISTORY SHEET (Frame J) -->
    <RecommendationShareHistorySheet
      v-if="historyTarget"
      :rec="historyTarget"
      @close="historyTarget = null"
      @changed="onHistoryChanged"
      @open-share="onHistoryOpenShare"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
