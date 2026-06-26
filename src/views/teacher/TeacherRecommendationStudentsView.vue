<!--
  TeacherRecommendationStudentsView.vue — student list (Frame B).

  Web port of `recommendation_student_screen.dart`. Route entry:
    /teacher/recommendations/class/:classId?scope=parent

  Layout:
    1. Back chevron row → kembali ke class hub
    2. BrandPageHeader (teacher) — kicker `Kelas <name> · Rekomendasi`,
       title `List Student`, meta line
    3. KpiStripCards — SISWA / REKOMENDASI / PENDING / SELESAI
    4. PageFilterToolbar — search input + status chip strip
    5. List of student rows:
         [avatar] Name        [status pills] [REC count] [chevron]
                  NIS · No N
       — `n REC` pill red-tinted when ≥3 pending
       — Avatar red-tinted when student has zero recs (attention flag)

  Tap row → result view (Phase 4 — falls back to placeholder toast
  for now).

  Endpoints:
    GET /api/students?class_ids=…       — student roster
    GET /recommendations + paginate     — driven by
                                         RecommendationService.getStudentStatusCounts
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import {
  RecommendationService,
  RateLimitError,
} from '@/services/recommendations.service';
import { StudentService } from '@/services/students.service';
import { ClassroomService } from '@/services/classrooms.service';
import {
  TONE_LABELS,
  type RecTone,
  type ShareAllResult,
  type StudentStatusCounts,
} from '@/types/recommendations';
import type { Classroom, Student } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));
const isHomeroomMode = computed(() => route.query.scope === 'wali');

// ── Filter state ──
type StatusFilter = 'all' | 'has_recs' | 'has_pending' | 'all_completed';
const statusFilter = ref<StatusFilter>('all');
const searchQuery = ref<string>('');

// ── Data state ──
const cls = ref<Classroom | null>(null);
const students = ref<Student[]>([]);
const counts = ref<StudentStatusCounts>({});
const isLoadingStudents = ref(true);
const isLoadingCounts = ref(false);
const loadError = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const teacherId = computed(() => auth.teacherId ?? auth.user?.id ?? '');

// ── Loaders ──
async function loadClass() {
  if (!classId.value) return;
  try {
    // Lightweight: classroom list filtered to single id — backend
    // doesn't expose `/classrooms/{id}` with student_count separately,
    // so we go through the list endpoint and pick.
    const res = await ClassroomService.list({ per_page: 200 });
    cls.value = res.items.find((c) => c.id === classId.value) ?? null;
  } catch {
    cls.value = null;
  }
}

async function loadStudents() {
  if (!classId.value) {
    isLoadingStudents.value = false;
    return;
  }
  isLoadingStudents.value = true;
  loadError.value = null;
  try {
    // Flutter parity — use `/student/class/{id}` (StudentService.byClass).
    // The generic `/student?class_ids=` endpoint sometimes returns rows
    // keyed on a different `id` field (e.g. the linked user_id rather
    // than the canonical `students.id` primary key), which breaks the
    // counts lookup in `countsFor(s.id)` — the recommendation rows are
    // keyed on `students.id` server-side, so the lookup would silently
    // miss and the "Ada Pending" filter would show 0 students even when
    // pending recs existed.
    students.value = await StudentService.byClass(classId.value);
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoadingStudents.value = false;
  }
}

async function loadCounts() {
  if (!classId.value) return;
  isLoadingCounts.value = true;
  try {
    const next = await RecommendationService.getStudentStatusCounts({
      class_id: classId.value,
      // Mengajar mode → teacher_id. Parent mode → homeroom_class_id
      // (cross-teacher scope across the homeroom).
      teacher_id: isHomeroomMode.value
        ? undefined
        : teacherId.value || undefined,
      homeroom_class_id: isHomeroomMode.value ? classId.value : undefined,
    });
    counts.value = next;
  } catch {
    counts.value = {};
  } finally {
    isLoadingCounts.value = false;
  }
}

// ── Bulk share-to-parent ("Kirim semua ke parent") ──
//
// Only available in Mengajar mode: the bulk endpoint requires the
// authoring teacher (auth:sanctum + role.teacher + teacher.owner) and
// shares THIS teacher's not-yet-shared recs. In parent-kelas mode the
// recs span multiple authoring teachers, so the single owner check
// doesn't apply — we hide the button there.
const unsharedCount = ref(0);
const isLoadingUnshared = ref(false);

async function loadUnsharedCount() {
  if (!classId.value || isHomeroomMode.value || !teacherId.value) {
    unsharedCount.value = 0;
    return;
  }
  isLoadingUnshared.value = true;
  try {
    unsharedCount.value = await RecommendationService.countUnsharedRecs({
      class_id: classId.value,
      teacher_id: teacherId.value,
    });
  } catch {
    unsharedCount.value = 0;
  } finally {
    isLoadingUnshared.value = false;
  }
}

// The button shows only in Mengajar mode and only once we know there's
// at least one shareable, not-yet-shared rec to send.
const canBulkShare = computed(
  () => !isHomeroomMode.value && !!teacherId.value && unsharedCount.value > 0,
);

// Options dialog (cover message + tone + channels) state.
const showShareDialog = ref(false);
const bulkMessage = ref('');
const bulkTone = ref<RecTone>('warm');
const bulkChannelPush = ref(true);
const bulkChannelWhatsapp = ref(false);
const bulkError = ref<string | null>(null);
const isSharing = ref(false);

// Result summary dialog state (populated after the batch completes).
const shareResult = ref<ShareAllResult | null>(null);

const TONE_OPTIONS = computed<{ key: RecTone; emoji: string; label: string }[]>(() => [
  { key: 'warm', emoji: '😊', label: TONE_LABELS.warm },
  { key: 'formal', emoji: '📋', label: TONE_LABELS.formal },
  { key: 'concise', emoji: '⚡', label: TONE_LABELS.concise },
  { key: 'detailed', emoji: '🎯', label: TONE_LABELS.detailed },
]);

function openShareDialog() {
  if (!canBulkShare.value) return;
  bulkError.value = null;
  bulkMessage.value = '';
  bulkTone.value = 'warm';
  bulkChannelPush.value = true;
  bulkChannelWhatsapp.value = false;
  showShareDialog.value = true;
}

async function submitBulkShare() {
  if (isSharing.value) return;
  bulkError.value = null;
  if (!bulkChannelPush.value && !bulkChannelWhatsapp.value) {
    bulkError.value = t('tutor.sekolah.recommendationStudents.channelRequired');
    return;
  }
  if (bulkMessage.value.length > 2000) {
    bulkError.value = t('tutor.sekolah.recommendationStudents.messageTooLong');
    return;
  }
  isSharing.value = true;
  try {
    const result = await RecommendationService.shareAllToParents({
      teacher_id: teacherId.value,
      class_id: classId.value,
      message: bulkMessage.value.trim() || undefined,
      tone: bulkTone.value,
      channel_push: bulkChannelPush.value,
      channel_whatsapp: bulkChannelWhatsapp.value,
    });
    showShareDialog.value = false;
    shareResult.value = result;
    // Refresh so the now-shared recs drop out of the unsent count and
    // the per-student rollup reflects the new share state.
    await Promise.all([loadCounts(), loadUnsharedCount()]);
  } catch (e) {
    if (e instanceof RateLimitError) {
      bulkError.value =
        e.dailyLimit && e.dailyUsage !== undefined
          ? t('tutor.sekolah.recommendationStudents.rateLimitReachedUsage', { usage: e.dailyUsage, limit: e.dailyLimit })
          : t('tutor.sekolah.recommendationStudents.rateLimitReached');
    } else {
      bulkError.value =
        (e as Error).message || t('tutor.sekolah.recommendationStudents.sendFailed');
    }
  } finally {
    isSharing.value = false;
  }
}

// Per-row tone classes for the result breakdown list.
function resultRowTone(status: 'sent' | 'failed' | 'skipped'): {
  icon: string;
  cls: string;
  badge: string;
  label: string;
} {
  if (status === 'sent') {
    return {
      icon: 'check-circle',
      cls: 'text-emerald-600',
      badge: 'bg-emerald-100 text-emerald-700',
      label: t('tutor.sekolah.recommendationStudents.resultSent'),
    };
  }
  if (status === 'skipped') {
    return {
      icon: 'alert-triangle',
      cls: 'text-amber-600',
      badge: 'bg-amber-100 text-amber-700',
      label: t('tutor.sekolah.recommendationStudents.resultSkipped'),
    };
  }
  return {
    icon: 'alert-circle',
    cls: 'text-red-600',
    badge: 'bg-red-100 text-red-700',
    label: t('tutor.sekolah.recommendationStudents.resultFailed'),
  };
}

onMounted(async () => {
  await Promise.all([
    loadClass(),
    loadStudents(),
    loadCounts(),
    loadUnsharedCount(),
  ]);
});

useAcademicYearWatcher(() => {
  // Re-fetch counts (and roster — academic year flip can swap
  // enrolments) when the active TP changes.
  loadStudents();
  loadCounts();
  loadUnsharedCount();
});

// React to scope flip (back+forward with ?scope=parent toggled).
watch(
  () => route.fullPath,
  () => {
    if (!classId.value) return;
    loadStudents();
    loadCounts();
    loadUnsharedCount();
  },
);

// ── Derived ──
function countsFor(studentId: string) {
  return counts.value[studentId] ?? { total: 0, pending: 0, completed: 0 };
}

const visibleStudents = computed(() => {
  let list = students.value;
  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        (s.student_number ?? '').toLowerCase().includes(q),
    );
  }
  if (statusFilter.value === 'has_recs') {
    list = list.filter((s) => countsFor(s.id).total > 0);
  } else if (statusFilter.value === 'has_pending') {
    list = list.filter((s) => countsFor(s.id).pending > 0);
  } else if (statusFilter.value === 'all_completed') {
    list = list.filter((s) => {
      const c = countsFor(s.id);
      return c.total > 0 && c.pending === 0;
    });
  }
  // Sort: most-pending first, then most-total, then name
  return [...list].sort((a, b) => {
    const ca = countsFor(a.id);
    const cb = countsFor(b.id);
    if (cb.pending !== ca.pending) return cb.pending - ca.pending;
    if (cb.total !== ca.total) return cb.total - ca.total;
    return a.name.localeCompare(b.name, 'id');
  });
});

// ── KPI ──
const kpiCards = computed<KpiCard[]>(() => {
  const total = Object.values(counts.value).reduce(
    (acc, c) => acc + c.total,
    0,
  );
  const pending = Object.values(counts.value).reduce(
    (acc, c) => acc + c.pending,
    0,
  );
  const completed = Object.values(counts.value).reduce(
    (acc, c) => acc + c.completed,
    0,
  );
  return [
    {
      icon: 'users',
      label: t('tutor.sekolah.recommendationStudents.kpiStudents'),
      value: students.value.length,
      tone: 'brand',
    },
    {
      icon: 'sparkles',
      label: t('tutor.sekolah.recommendationStudents.kpiRecommendations'),
      value: total,
      tone: 'violet',
    },
    {
      icon: 'bell',
      label: t('tutor.sekolah.recommendationStudents.kpiPending'),
      value: pending,
      tone: pending > 0 ? 'amber' : 'slate',
      accented: pending > 0,
    },
    {
      icon: 'check-circle',
      label: t('tutor.sekolah.recommendationStudents.kpiCompleted'),
      value: completed,
      tone: 'green',
    },
  ];
});

// ── Status chip strip ──
const statusOptions = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('tutor.sekolah.recommendationStudents.filterAll') },
  { key: 'has_recs', label: t('tutor.sekolah.recommendationStudents.filterHasRecs') },
  { key: 'has_pending', label: t('tutor.sekolah.recommendationStudents.filterHasPending') },
  { key: 'all_completed', label: t('tutor.sekolah.recommendationStudents.filterAllCompleted') },
]);

// ── List state ──
const listState = computed<AsyncState<Student[]>>(() => {
  if (isLoadingStudents.value && students.value.length === 0)
    return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleStudents.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleStudents.value };
});

// ── Header copy ──
const headerKicker = computed(() => {
  if (!cls.value) return t('tutor.sekolah.recommendationStudents.kickerFallback');
  return t('tutor.sekolah.recommendationStudents.headerKicker', {
    className: cls.value.name,
    mode: isHomeroomMode.value
      ? t('tutor.sekolah.recommendationStudents.modeHomeroom')
      : t('tutor.sekolah.recommendationStudents.modeTeaching'),
  });
});

const headerMeta = computed(() => {
  return t('tutor.sekolah.recommendationStudents.meta', {
    students: students.value.length,
    withRecs: Object.keys(counts.value).length,
  });
});

// ── Actions ──
function goBack() {
  router.push({ name: 'teacher.recommendations' });
}

function openStudent(s: Student) {
  // Phase 4 will register the `teacher.recommendations.result` route.
  // Until then, surface a placeholder so taps don't 404.
  const target = router.resolve({
    name: 'teacher.recommendations.result',
    params: { classId: classId.value, studentId: s.id },
    query: isHomeroomMode.value ? { scope: 'wali' } : undefined,
  });
  if (target.matched.length === 0) {
    toast.value = {
      message: t('tutor.sekolah.recommendationStudents.placeholderResultToast', { name: s.name }),
      tone: 'success',
    };
    return;
  }
  router.push(target);
}

// Tag chip helper — produces a tiny pill describing the dominant
// rec status for a student. Shown inline next to the count badge.
function studentStatusPills(
  studentId: string,
): { label: string; cls: string }[] {
  const c = countsFor(studentId);
  if (c.total === 0) {
    return [{ label: t('tutor.sekolah.recommendationStudents.pillNoRec'), cls: 'bg-slate-100 text-slate-500' }];
  }
  const out: { label: string; cls: string }[] = [];
  if (c.pending > 0) {
    out.push({
      label: t('tutor.sekolah.recommendationStudents.pillPending', { count: c.pending }),
      cls: 'bg-amber-100 text-amber-700',
    });
  }
  if (c.completed > 0) {
    out.push({
      label: t('tutor.sekolah.recommendationStudents.pillCompleted', { count: c.completed }),
      cls: 'bg-emerald-100 text-emerald-700',
    });
  }
  return out;
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
        {{ t('tutor.sekolah.recommendationStudents.backToClasses') }}
      </button>
    </div>

    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      :kicker="headerKicker"
      :title="t('tutor.sekolah.recommendationStudents.title')"
      :meta="headerMeta"
      :live-dot="false"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      :search-placeholder="t('tutor.sekolah.recommendationStudents.searchPlaceholder')"
    >
      <template #chips>
        <span class="text-[11px] font-bold text-slate-500 px-1">
          {{ t('tutor.sekolah.recommendationStudents.visibleCount', { count: visibleStudents.length }) }}
        </span>
      </template>
    </PageFilterToolbar>

    <!-- STATUS CHIPS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="opt in statusOptions"
        :key="opt.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
        :class="
          statusFilter === opt.key
            ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
        "
        @click="statusFilter = opt.key"
      >
        {{ opt.label }}
      </button>
    </div>

    <!-- BULK SHARE TOOLBAR (Mengajar mode only, when unsent recs exist) -->
    <div
      v-if="canBulkShare"
      class="flex items-center gap-3 rounded-2xl border border-brand-cobalt/20 bg-brand-cobalt/5 px-3.5 py-3"
    >
      <span
        class="w-9 h-9 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0"
      >
        <NavIcon name="send" :size="16" />
      </span>
      <div class="flex-1 min-w-0">
        <p class="text-[12.5px] font-black text-slate-900 leading-tight">
          {{ t('tutor.sekolah.recommendationStudents.unsharedCount', { count: unsharedCount }) }}
        </p>
        <p class="text-[11px] text-slate-500 mt-0.5">
          {{ t('tutor.sekolah.recommendationStudents.bulkSubtitle') }}
        </p>
      </div>
      <Button
        variant="primary"
        size="sm"
        :loading="isSharing"
        :disabled="isSharing"
        @click="openShareDialog"
      >
        <NavIcon v-if="!isSharing" name="send" :size="13" />
        {{ t('tutor.sekolah.recommendationStudents.sendAllToParents') }}
      </Button>
    </div>

    <!-- STUDENT LIST -->
    <AsyncView
      :state="listState"
      :empty-title="
        searchQuery
          ? t('tutor.sekolah.recommendationStudents.emptySearch')
          : statusFilter === 'all'
            ? t('tutor.sekolah.recommendationStudents.emptyClass')
            : t('tutor.sekolah.recommendationStudents.emptyFilter')
      "
      :empty-description="t('tutor.sekolah.recommendationStudents.emptyDescription')"
      empty-icon="users"
      @retry="loadStudents"
    >
      <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <button
          v-for="(s, idx) in visibleStudents"
          :key="s.id"
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 transition hover:bg-slate-50"
          :class="idx > 0 ? 'border-t border-slate-100' : ''"
          @click="openStudent(s)"
        >
          <!-- Avatar — red tint when zero recs to flag attention -->
          <InitialsAvatar
            :name="s.name || '?'"
            :size="40"
            :border-radius="12"
            :color="countsFor(s.id).total === 0 ? '#DC2626' : '#1B6FB8'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ s.name }}
            </p>
            <p class="text-[11px] text-slate-500 truncate">
              <template v-if="s.student_number">
                {{ s.student_number }}
              </template>
              <template v-else> {{ t('tutor.sekolah.recommendationStudents.noNis') }} </template>
              · {{ t('tutor.sekolah.recommendationStudents.rowNumber', { n: idx + 1 }) }}
            </p>
            <!-- Status pills row -->
            <div class="flex items-center gap-1 flex-wrap mt-1.5">
              <span
                v-for="pill in studentStatusPills(s.id)"
                :key="pill.label"
                class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full uppercase tracking-wider"
                :class="pill.cls"
              >
                {{ pill.label }}
              </span>
            </div>
          </div>
          <!-- N REC count pill -->
          <div class="flex flex-col items-end gap-1 flex-shrink-0">
            <span
              v-if="countsFor(s.id).total > 0"
              class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-black"
              :class="
                countsFor(s.id).pending >= 3
                  ? 'bg-red-100 text-red-700'
                  : 'bg-violet-100 text-violet-700'
              "
            >
              {{ countsFor(s.id).total }}
              <span class="text-[9px] uppercase tracking-wider opacity-80">
                {{ t('tutor.sekolah.recommendationStudents.recBadge') }}
              </span>
            </span>
            <NavIcon name="chevron-right" :size="13" class="text-slate-400" />
          </div>
        </button>
      </div>
      <p
        v-if="isLoadingCounts"
        class="text-center text-[11px] text-slate-400 mt-3 italic"
      >
        {{ t('tutor.sekolah.recommendationStudents.loadingCounts') }}
      </p>
    </AsyncView>

    <!-- BULK SHARE OPTIONS DIALOG -->
    <Modal
      v-if="showShareDialog"
      :title="t('tutor.sekolah.recommendationStudents.sendAllToParents')"
      :subtitle="cls
        ? t('tutor.sekolah.recommendationStudents.bulkSubtitleWithClass', { count: unsharedCount, className: cls.name })
        : t('tutor.sekolah.recommendationStudents.unsharedCount', { count: unsharedCount })"
      size="lg"
      @close="showShareDialog = false"
    >
      <div class="space-y-4">
        <!-- Intro plaque -->
        <div
          class="bg-brand-cobalt/5 border border-brand-cobalt/20 rounded-xl px-3 py-3 text-[12px] text-slate-700"
        >
          {{ t('tutor.sekolah.recommendationStudents.intro') }}
        </div>

        <!-- NADA PESAN -->
        <div>
          <label
            class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.recommendationStudents.toneLabel') }}
          </label>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-1.5">
            <button
              v-for="opt in TONE_OPTIONS"
              :key="opt.key"
              type="button"
              class="px-3 py-2 rounded-xl border transition inline-flex items-center justify-center gap-1.5 text-[11.5px] font-bold"
              :class="
                bulkTone === opt.key
                  ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
                  : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
              "
              :disabled="isSharing"
              @click="bulkTone = opt.key"
            >
              <span>{{ opt.emoji }}</span>
              {{ opt.label }}
            </button>
          </div>
        </div>

        <!-- CATATAN (cover message) -->
        <div>
          <label
            class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.recommendationStudents.coverMessageLabel') }}
            <span class="text-slate-400 normal-case font-normal"
              >· {{ t('tutor.sekolah.recommendationStudents.optional') }}</span
            >
          </label>
          <textarea
            v-model="bulkMessage"
            rows="3"
            maxlength="2000"
            :placeholder="t('tutor.sekolah.recommendationStudents.coverMessagePlaceholder')"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-y"
            :disabled="isSharing"
          />
          <p class="text-[10px] text-slate-400 mt-1 text-right tabular-nums">
            {{ bulkMessage.length }}/2000
          </p>
        </div>

        <!-- KANAL -->
        <div>
          <label
            class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5"
          >
            {{ t('tutor.sekolah.recommendationStudents.channelLabel') }}
          </label>
          <div class="grid grid-cols-2 gap-2">
            <label
              class="rounded-xl border px-3 py-2.5 flex items-center gap-2.5 cursor-pointer transition"
              :class="
                bulkChannelPush
                  ? 'bg-brand-cobalt/5 border-brand-cobalt'
                  : 'bg-white border-slate-200 hover:border-brand-cobalt/40'
              "
            >
              <input
                v-model="bulkChannelPush"
                type="checkbox"
                class="w-4 h-4 accent-brand-cobalt flex-shrink-0"
                :disabled="isSharing"
              />
              <span class="text-[14px]">📱</span>
              <div class="flex-1 min-w-0">
                <p class="text-[12px] font-bold text-slate-900 leading-tight">
                  {{ t('tutor.sekolah.recommendationStudents.channelPushTitle') }}
                </p>
                <p class="text-[10px] text-slate-500 mt-0.5">{{ t('tutor.sekolah.recommendationStudents.channelPushSubtitle') }}</p>
              </div>
            </label>
            <label
              class="rounded-xl border px-3 py-2.5 flex items-center gap-2.5 cursor-pointer transition"
              :class="
                bulkChannelWhatsapp
                  ? 'bg-emerald-50 border-emerald-500'
                  : 'bg-white border-slate-200 hover:border-emerald-300'
              "
            >
              <input
                v-model="bulkChannelWhatsapp"
                type="checkbox"
                class="w-4 h-4 accent-emerald-600 flex-shrink-0"
                :disabled="isSharing"
              />
              <span class="text-[14px]">💬</span>
              <div class="flex-1 min-w-0">
                <p class="text-[12px] font-bold text-slate-900 leading-tight">
                  {{ t('tutor.sekolah.recommendationStudents.channelWhatsappTitle') }}
                </p>
                <p class="text-[10px] text-slate-500 mt-0.5">{{ t('tutor.sekolah.recommendationStudents.channelWhatsappSubtitle') }}</p>
              </div>
            </label>
          </div>
        </div>

        <!-- ERROR -->
        <div
          v-if="bulkError"
          class="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-[12px] text-red-700"
        >
          {{ bulkError }}
        </div>

        <!-- FOOTER -->
        <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
          <Button
            variant="secondary"
            block
            :disabled="isSharing"
            @click="showShareDialog = false"
          >
            {{ t('tutor.sekolah.recommendationStudents.cancel') }}
          </Button>
          <Button
            variant="primary"
            block
            :loading="isSharing"
            :disabled="isSharing"
            @click="submitBulkShare"
          >
            <NavIcon v-if="!isSharing" name="send" :size="14" />
            {{ t('tutor.sekolah.recommendationStudents.sendToNParents', { count: unsharedCount }) }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- BULK SHARE RESULT SUMMARY DIALOG -->
    <Modal
      v-if="shareResult"
      :title="t('tutor.sekolah.recommendationStudents.summaryTitle')"
      :subtitle="t('tutor.sekolah.recommendationStudents.summarySubtitle', { sent: shareResult.sent, failed: shareResult.failed, skipped: shareResult.skipped_no_wali })"
      size="lg"
      @close="shareResult = null"
    >
      <div class="space-y-4">
        <!-- Tally chips -->
        <div class="grid grid-cols-3 gap-2">
          <div class="rounded-xl bg-emerald-50 px-2 py-3 text-center">
            <p
              class="text-xl font-black leading-none tabular-nums text-emerald-700"
            >
              {{ shareResult.sent }}
            </p>
            <p
              class="text-[9px] font-bold uppercase tracking-widest mt-1 text-slate-500"
            >
              {{ t('tutor.sekolah.recommendationStudents.resultSent') }}
            </p>
          </div>
          <div class="rounded-xl bg-amber-50 px-2 py-3 text-center">
            <p
              class="text-xl font-black leading-none tabular-nums text-amber-700"
            >
              {{ shareResult.skipped_no_wali }}
            </p>
            <p
              class="text-[9px] font-bold uppercase tracking-widest mt-1 text-slate-500"
            >
              {{ t('tutor.sekolah.recommendationStudents.resultSkipped') }}
            </p>
          </div>
          <div class="rounded-xl bg-red-50 px-2 py-3 text-center">
            <p
              class="text-xl font-black leading-none tabular-nums text-red-700"
            >
              {{ shareResult.failed }}
            </p>
            <p
              class="text-[9px] font-bold uppercase tracking-widest mt-1 text-slate-500"
            >
              {{ t('tutor.sekolah.recommendationStudents.resultFailed') }}
            </p>
          </div>
        </div>

        <p class="text-[11.5px] text-slate-500">
          {{ t('tutor.sekolah.recommendationStudents.outOfTotal', { count: shareResult.total }) }}
        </p>

        <!-- Per-rec breakdown -->
        <div
          v-if="shareResult.results.length > 0"
          class="border border-slate-200 rounded-xl overflow-hidden max-h-72 overflow-y-auto"
        >
          <div
            v-for="(row, idx) in shareResult.results"
            :key="row.recommendation_id || idx"
            class="px-3 py-2.5 flex items-start gap-2.5"
            :class="idx > 0 ? 'border-t border-slate-100' : ''"
          >
            <NavIcon
              :name="resultRowTone(row.status).icon"
              :size="15"
              :class="resultRowTone(row.status).cls"
              class="flex-shrink-0 mt-0.5"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[12.5px] font-bold text-slate-900 truncate">
                {{ row.student_name }}
              </p>
              <p
                v-if="row.error"
                class="text-[11px] text-slate-500 mt-0.5 leading-snug"
              >
                {{ row.error }}
              </p>
            </div>
            <span
              class="text-[9px] font-bold px-1.5 py-0.5 rounded-full uppercase tracking-wider flex-shrink-0"
              :class="resultRowTone(row.status).badge"
            >
              {{ resultRowTone(row.status).label }}
            </span>
          </div>
        </div>

        <!-- FOOTER -->
        <div class="pt-2 border-t border-slate-100">
          <Button variant="primary" block @click="shareResult = null">
            {{ t('tutor.sekolah.recommendationStudents.done') }}
          </Button>
        </div>
      </div>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
