<!--
  TeacherLessonPlanDetailView.vue — RPP detail page (Flutter parity).

  Mirrors `lib/features/lesson_plans/presentation/screens/ai/
  ai_rpp_detail_screen.dart` + `manual/manual_rpp_detail_screen.dart`
  unified into one component (the file/structured branch happens in
  the section list).

  Layout:
    1. BrandPageHeader (teacher) — title + format kicker + back chevron
    2. 3-cell KPI overlap — Section count · Alokasi · Status
    3. Revision banner — when status=Rejected/SentBack with admin_notes
    4. File preview card — when format=file
    5. Section cards (per format) — tap to open SectionEditorModal
    6. Notes / Reflection panel
    7. Status action bar — context-aware sticky footer

  Route: /teacher/lesson-plans/:id
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { LessonPlanService } from '@/services/lesson-plans.service';
import {
  FORMAT_COLORS,
  FORMAT_LABELS,
  FORMAT_SECTION_KEYS,
  FORMAT_SHORT_LABELS,
  STATUS_LABELS,
  STATUS_TONES,
  isStructuredFormat,
  readLessonPlanSection,
  sectionLabel,
  type LessonPlan,
} from '@/types/lesson-plans';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import LessonPlanSectionEditorModal from '@/components/feature/LessonPlanSectionEditorModal.vue';
import LessonPlanStatusActionBar from '@/components/feature/LessonPlanStatusActionBar.vue';
import LessonPlanReviewHistoryModal from '@/components/feature/LessonPlanReviewHistoryModal.vue';
import LessonPlanRegenSheet from '@/components/feature/LessonPlanRegenSheet.vue';
import LessonPlanAiPollingOverlay from '@/components/feature/LessonPlanAiPollingOverlay.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRelative } from '@/lib/format';
import { semesterLabel } from '@/lib/labels';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const plan = ref<LessonPlan | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isMutating = ref(false);
const editTarget = ref<{ key: string; label: string; value: string } | null>(
  null,
);
const showHistory = ref(false);
const showRegen = ref(false);
const regenJob = ref<{ id: string; subtitle: string } | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// Polling timer for AI regen. Same cadence + safety timeout as the
// list-view AI generate flow so the UX is consistent.
let regenTimer: ReturnType<typeof setInterval> | null = null;
let regenStartMs = 0;
const REGEN_INTERVAL_MS = 2500;
const REGEN_TIMEOUT_MS = 90_000;

function stopRegen() {
  if (regenTimer) {
    clearInterval(regenTimer);
    regenTimer = null;
  }
}

function onRegenStarted(payload: { jobId: string; sectionKeys: string[]; subtitle: string }) {
  regenJob.value = { id: payload.jobId, subtitle: payload.subtitle };
  pollRegen(payload.jobId);
}

function pollRegen(jobId: string) {
  stopRegen();
  regenStartMs = Date.now();
  regenTimer = setInterval(async () => {
    if (Date.now() - regenStartMs > REGEN_TIMEOUT_MS) {
      stopRegen();
      regenJob.value = null;
      toast.value = {
        message: t('tutor.sekolah.lessonPlanDetail.regenTimeoutToast'),
        tone: 'error',
      };
      await load();
      return;
    }
    try {
      const res = await LessonPlanService.getAiJob(jobId);
      if (res.status === 'done') {
        stopRegen();
        regenJob.value = null;
        toast.value = { message: t('tutor.sekolah.lessonPlanDetail.regenSuccessToast'), tone: 'success' };
        await load();
      } else if (res.status === 'error') {
        stopRegen();
        regenJob.value = null;
        toast.value = {
          message: res.error ?? t('tutor.sekolah.lessonPlanDetail.regenErrorToast'),
          tone: 'error',
        };
      }
    } catch {
      // Keep polling silently on transient errors.
    }
  }, REGEN_INTERVAL_MS);
}

function cancelRegen() {
  stopRegen();
  regenJob.value = null;
  toast.value = {
    message: t('tutor.sekolah.lessonPlanDetail.regenPollingStoppedToast'),
    tone: 'success',
  };
}

// Stop the regen poll when the user leaves the page.
import { onBeforeUnmount } from 'vue';
onBeforeUnmount(stopRegen);

// Regen button shows only when the plan has structured sections AND
// the status allows editing — Approved / Pending lock out edits so
// the regen button would be misleading.
const canRegen = computed(
  () =>
    !!plan.value &&
    isStructuredFormat(plan.value.format) &&
    (plan.value.status === 'Draft' ||
      plan.value.status === 'Rejected' ||
      plan.value.status === 'SentBack'),
);

const planId = computed(() => String(route.params.id ?? ''));

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await LessonPlanService.getById(planId.value);
    if (!res) {
      loadError.value = t('tutor.sekolah.lessonPlanDetail.notFound');
    } else {
      plan.value = res;
    }
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => {
  if (!planId.value) {
    loadError.value = t('tutor.sekolah.lessonPlanDetail.invalidId');
    isLoading.value = false;
    return;
  }
  load();
});

// ── Section list (format-aware) ──
const sections = computed<
  { key: string; label: string; value: string }[]
>(() => {
  if (!plan.value) return [];
  const keys = FORMAT_SECTION_KEYS[plan.value.format];
  return keys.map((key) => ({
    key,
    label: sectionLabel(key),
    value: readLessonPlanSection(
      plan.value as LessonPlan & { [k: string]: unknown },
      key,
    ),
  }));
});

const filledSections = computed(
  () => sections.value.filter((s) => s.value.trim().length > 0).length,
);

const totalSections = computed(() => sections.value.length);

// ── State (loading wrapper) ──
const state = computed<AsyncState<LessonPlan>>(() => {
  if (isLoading.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (!plan.value) return { status: 'empty' };
  return { status: 'content', data: plan.value };
});

const accent = computed(() =>
  plan.value ? FORMAT_COLORS[plan.value.format] : '#1B6FB8',
);
const tone = computed(() =>
  plan.value ? STATUS_TONES[plan.value.status] : STATUS_TONES.Draft,
);
const statusLabel = computed(() =>
  plan.value ? STATUS_LABELS[plan.value.status] : '—',
);

/**
 * Coaching sub-label for the status badge — mobile parity. Tells the
 * teacher what the next step is (or who they're waiting on) so the
 * badge doesn't just label the state, it explains what to do next.
 */
const statusContext = computed<string | null>(() => {
  if (!plan.value) return null;
  switch (plan.value.status) {
    case 'Draft':
      return t('tutor.sekolah.lessonPlanDetail.statusContextDraft');
    case 'Pending':
      return t('tutor.sekolah.lessonPlanDetail.statusContextPending');
    case 'SentBack':
      return t('tutor.sekolah.lessonPlanDetail.statusContextSentBack');
    case 'Rejected':
      return t('tutor.sekolah.lessonPlanDetail.statusContextRejected');
    case 'Approved':
      return t('tutor.sekolah.lessonPlanDetail.statusContextApproved');
    default:
      return null;
  }
});

const kicker = computed(() => {
  if (!plan.value) return t('tutor.sekolah.lessonPlanDetail.kickerFallback');
  const parts = [
    `${t('tutor.sekolah.lessonPlanDetail.kickerPrefix')} · ${FORMAT_SHORT_LABELS[plan.value.format]}`,
    plan.value.class_name?.trim().toUpperCase(),
    plan.value.subject_name?.trim().toUpperCase(),
  ].filter((p) => p && p.length > 0);
  return parts.join(' · ');
});

const metaLine = computed(() => {
  if (!plan.value) return '';
  const parts: string[] = [];
  if (plan.value.academic_year) parts.push(t('tutor.sekolah.lessonPlanDetail.academicYear', { year: plan.value.academic_year }));
  if (plan.value.semester) parts.push(t('tutor.sekolah.lessonPlanDetail.semester', { sem: semesterLabel(plan.value.semester) }));
  if (plan.value.revision > 1) parts.push(t('tutor.sekolah.lessonPlanDetail.revision', { n: plan.value.revision }));
  if (plan.value.submitted_at) {
    parts.push(t('tutor.sekolah.lessonPlanDetail.submittedRel', { rel: formatRelative(plan.value.submitted_at) }));
  } else if (plan.value.created_at) {
    parts.push(t('tutor.sekolah.lessonPlanDetail.createdRel', { rel: formatRelative(plan.value.created_at) }));
  }
  return parts.join(' · ');
});

// ── Helpers ──
function openFileUrl(url: string) {
  if (typeof window !== 'undefined') window.open(url, '_blank');
}

function goBack() {
  router.push({ name: 'teacher.lesson-plans' });
}

function openSectionEditor(s: { key: string; label: string; value: string }) {
  if (!plan.value) return;
  // Only editable when status allows changes (Draft / SentBack / Rejected).
  const status = plan.value.status;
  if (status === 'Approved' || status === 'Pending') {
    toast.value = {
      message:
        status === 'Approved'
          ? t('tutor.sekolah.lessonPlanDetail.approvedLockedToast')
          : t('tutor.sekolah.lessonPlanDetail.pendingLockedToast'),
      tone: 'error',
    };
    return;
  }
  editTarget.value = { key: s.key, label: s.label, value: s.value };
}

function onSectionSaved(payload: { fieldKey: string; newValue: string }) {
  // Local optimistic update — backend already persisted via the modal's
  // service call, so we just patch the local plan object.
  if (!plan.value) return;
  const fd = { ...(plan.value.format_data ?? {}) };
  fd[payload.fieldKey] = payload.newValue;
  plan.value = { ...plan.value, format_data: fd };
  toast.value = { message: t('tutor.sekolah.lessonPlanDetail.sectionSavedToast'), tone: 'success' };
}

// ── Status actions (from action bar) ──
async function submitForReview() {
  if (!plan.value) return;
  isMutating.value = true;
  try {
    await LessonPlanService.submitForReview(plan.value.id);
    toast.value = {
      message: t('tutor.sekolah.lessonPlanDetail.submittedForReviewToast'),
      tone: 'success',
    };
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isMutating.value = false;
  }
}

function onEditIntent() {
  // For now: scroll the first empty (or first) section into view and
  // open its editor. Dedicated identity-edit sheet arrives later.
  const first = sections.value.find((s) => !s.value) ?? sections.value[0];
  if (first) openSectionEditor(first);
}

function onHistoryIntent() {
  showHistory.value = true;
}
</script>

<template>
  <div class="space-y-4 pb-2">
    <!-- BACK CHEVRON ROW -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('tutor.sekolah.lessonPlanDetail.backToList') }}
      </button>
    </div>

    <AsyncView :state="state" :empty-title="t('tutor.sekolah.lessonPlanDetail.notFound')" @retry="load">
      <template #default>
        <div v-if="plan" class="space-y-4">
          <!-- HEADER -->
          <BrandPageHeader
            role="guru"
            :kicker="kicker"
            :title="plan.title || t('tutor.sekolah.lessonPlanDetail.untitled')"
            :meta="metaLine"
            :live-dot="false"
          >
            <button
              v-if="canRegen"
              type="button"
              class="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-white/15 hover:bg-white/25 text-white text-2xs font-bold uppercase tracking-wider transition"
              @click="showRegen = true"
            >
              <NavIcon name="sparkles" :size="11" />
              {{ t('tutor.sekolah.lessonPlanDetail.regenerate') }}
            </button>
            <span
              v-if="plan.ai_generated"
              class="inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-white/15 text-white text-3xs font-bold uppercase tracking-wider"
            >
              <NavIcon name="sparkles" :size="10" />
              {{ t('tutor.sekolah.lessonPlanDetail.aiBadge') }}
            </span>
          </BrandPageHeader>

          <!-- 3-cell KPI overlap -->
          <section
            class="bg-white border border-slate-200 rounded-2xl shadow-sm grid grid-cols-3 divide-x divide-slate-100"
          >
            <div class="px-3 py-3 text-center">
              <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">
                {{ t('tutor.sekolah.lessonPlanDetail.kpiSections') }}
              </p>
              <p
                class="text-lg font-black mt-1"
                :style="{ color: accent }"
              >
                {{ totalSections === 0 ? '—' : `${filledSections}/${totalSections}` }}
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">
                {{ t('tutor.sekolah.lessonPlanDetail.kpiFormat') }}
              </p>
              <p
                class="text-[12px] font-black mt-1"
                :style="{ color: accent }"
              >
                {{ FORMAT_LABELS[plan.format] }}
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p class="text-4xs font-bold text-slate-400 uppercase tracking-widest">
                {{ t('tutor.sekolah.lessonPlanDetail.kpiStatus') }}
              </p>
              <span
                class="inline-flex items-center gap-1 mt-1 px-2 py-1 rounded-md border text-2xs font-bold"
                :class="[tone.bg, tone.text, tone.border]"
              >
                <span class="w-1.5 h-1.5 rounded-full" :class="tone.dot" />
                {{ statusLabel }}
              </span>
              <p
                v-if="statusContext"
                class="text-3xs text-slate-500 mt-1.5 leading-snug px-1"
              >
                {{ statusContext }}
              </p>
            </div>
          </section>

          <!-- ADMIN NOTE BANNER -->
          <div
            v-if="
              (plan.status === 'Rejected' || plan.status === 'SentBack') &&
              plan.admin_notes
            "
            class="rounded-2xl border-l-4 px-4 py-3"
            :class="
              plan.status === 'Rejected'
                ? 'bg-red-50 border-red-500'
                : 'bg-violet-50 border-violet-500'
            "
          >
            <p
              class="text-3xs font-bold uppercase tracking-widest mb-1.5 inline-flex items-center gap-1.5"
              :class="plan.status === 'Rejected' ? 'text-red-700' : 'text-violet-700'"
            >
              <NavIcon
                :name="plan.status === 'Rejected' ? 'x-circle' : 'edit'"
                :size="12"
              />
              {{
                plan.status === 'Rejected'
                  ? t('tutor.sekolah.lessonPlanDetail.adminRejectReason')
                  : t('tutor.sekolah.lessonPlanDetail.adminRevisionNote')
              }}
            </p>
            <p
              class="text-[12.5px] leading-relaxed whitespace-pre-wrap"
              :class="plan.status === 'Rejected' ? 'text-red-900' : 'text-violet-900'"
            >
              {{ plan.admin_notes }}
            </p>
            <p
              v-if="plan.revision_areas && plan.revision_areas.length > 0"
              class="mt-2 text-3xs font-semibold inline-flex items-center gap-1.5 flex-wrap"
              :class="plan.status === 'Rejected' ? 'text-red-800' : 'text-violet-800'"
            >
              <span class="opacity-70">{{ t('tutor.sekolah.lessonPlanDetail.areasToFix') }}</span>
              <span
                v-for="key in plan.revision_areas"
                :key="key"
                class="px-2 py-0.5 rounded-full bg-white/70 border"
                :class="plan.status === 'Rejected' ? 'border-red-200' : 'border-violet-200'"
              >
                {{ sectionLabel(key) }}
              </span>
            </p>
          </div>

          <!-- FILE PREVIEW (file format) -->
          <div
            v-if="plan.format === 'file' && (plan.file_url || plan.file_name)"
            class="bg-white border border-slate-200 rounded-2xl p-4 flex items-center gap-3"
          >
            <span
              class="w-12 h-12 rounded-xl bg-slate-100 grid place-items-center flex-shrink-0"
              :style="{ color: accent }"
            >
              <NavIcon name="file-text" :size="22" />
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">
                {{ plan.file_name ?? t('tutor.sekolah.lessonPlanDetail.fileFallback') }}
              </p>
              <p class="text-2xs text-slate-500 mt-0.5">
                {{ plan.file_mime ?? 'document' }}
                <template v-if="plan.file_size_mb"> · {{ plan.file_size_mb }} MB</template>
              </p>
            </div>
            <Button
              v-if="plan.file_url"
              variant="secondary"
              size="sm"
              @click="openFileUrl(plan.file_url!)"
            >
              <NavIcon name="download" :size="12" />
              {{ t('tutor.sekolah.lessonPlanDetail.download') }}
            </Button>
          </div>

          <!-- SECTION LIST (structured formats) -->
          <section v-if="isStructuredFormat(plan.format)" class="space-y-2.5">
            <header class="flex items-center gap-2 px-1">
              <span
                class="text-3xs font-bold uppercase tracking-widest"
                :style="{ color: accent }"
              >
                {{ t('tutor.sekolah.lessonPlanDetail.sectionsHeader') }}
              </span>
              <span class="text-3xs text-slate-400 tabular-nums">
                · {{ t('tutor.sekolah.lessonPlanDetail.sectionsFilled', { filled: filledSections, total: totalSections }) }}
              </span>
              <span class="flex-1 border-t border-dashed border-slate-200 ml-2"></span>
            </header>

            <article
              v-for="(s, idx) in sections"
              :key="s.key"
              class="bg-white border border-slate-200 rounded-2xl p-4 hover:border-brand-cobalt/30 transition-all cursor-pointer"
              @click="openSectionEditor(s)"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <p
                    class="text-3xs font-bold uppercase tracking-widest"
                    :style="{ color: accent }"
                  >
                    {{ String(idx + 1).padStart(2, '0') }} · {{ s.label }}
                  </p>
                  <!--
                    Render stored HTML via v-html — value originates
                    from Quill (mobile or web) and is XSS-sanitized at
                    the backend (LessonPlanController's UpdateLessonPlan
                    action runs strip_tags whitelist). `.rpp-prose`
                    gives it heading/list/table styling.
                  -->
                  <div
                    v-if="s.value"
                    class="rpp-prose mt-2"
                    v-html="s.value"
                  />
                  <p
                    v-else
                    class="text-[11.5px] text-slate-400 italic mt-2"
                  >
                    {{ t('tutor.sekolah.lessonPlanDetail.sectionEmptyHint') }}
                  </p>
                </div>
                <span
                  v-if="s.value"
                  class="w-6 h-6 rounded-full grid place-items-center flex-shrink-0 bg-emerald-100 text-emerald-700"
                  :title="t('tutor.sekolah.lessonPlanDetail.sectionFilledTooltip')"
                >
                  <NavIcon name="check" :size="12" />
                </span>
                <span
                  v-else
                  class="w-6 h-6 rounded-full grid place-items-center flex-shrink-0 bg-slate-100 text-slate-400"
                  :title="t('tutor.sekolah.lessonPlanDetail.sectionEmptyTooltip')"
                >
                  <NavIcon name="plus" :size="12" />
                </span>
              </div>
            </article>
          </section>

          <!-- NOTES PANEL -->
          <section v-if="plan.notes" class="bg-white border border-slate-200 rounded-2xl p-4">
            <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-1.5">
              {{ t('tutor.sekolah.lessonPlanDetail.notesHeader') }}
            </p>
            <p class="text-[12.5px] text-slate-700 leading-relaxed whitespace-pre-wrap">
              {{ plan.notes }}
            </p>
          </section>

          <!-- STATUS ACTION BAR -->
          <LessonPlanStatusActionBar
            :status="plan.status"
            :busy="isMutating"
            @submit="submitForReview"
            @edit="onEditIntent"
            @history="onHistoryIntent"
          />
        </div>
      </template>
    </AsyncView>

    <!-- SECTION EDITOR MODAL -->
    <LessonPlanSectionEditorModal
      v-if="editTarget && plan"
      :lesson-plan-id="plan.id"
      :field-key="editTarget.key"
      :field-label="editTarget.label"
      :current-value="editTarget.value"
      :format-label="FORMAT_LABELS[plan.format]"
      @close="editTarget = null"
      @saved="onSectionSaved"
    />

    <!-- REVIEW HISTORY MODAL -->
    <LessonPlanReviewHistoryModal
      v-if="showHistory && plan"
      :plan-id="plan.id"
      :plan-title="plan.title"
      @close="showHistory = false"
    />

    <!-- REGEN SHEET (per-section AI) -->
    <LessonPlanRegenSheet
      v-if="showRegen && plan"
      :plan="plan"
      @close="showRegen = false"
      @started="onRegenStarted"
    />

    <!-- REGEN POLLING OVERLAY (reused from list-view AI generate) -->
    <LessonPlanAiPollingOverlay
      :visible="regenJob !== null"
      :title="t('tutor.sekolah.lessonPlanDetail.regenOverlayTitle')"
      :subtitle="regenJob?.subtitle ?? ''"
      :estimated-seconds="35"
      @cancel="cancelRegen"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
