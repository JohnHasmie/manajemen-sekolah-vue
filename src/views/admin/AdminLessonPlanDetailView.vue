<!--
  AdminLessonPlanDetailView.vue — read-only RPP preview + admin
  actions (Approve / Reject / SendBack).

  Web port of `lib/features/lesson_plans/presentation/screens/
  lesson_plan_admin_detail_page.dart`. Same layout as the teacher
  detail (header, KPI overlap, section list) but:
    • Sections are read-only — no per-section editor opens on tap
    • Sticky bottom bar exposes 3 admin actions instead of the
      teacher's submit/edit/history bar
    • Each action opens its dedicated sheet
      (Approve / Reject / SendBack)

  Route: /admin/lesson-plans/:id
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
import LessonPlanAdminApproveSheet from '@/components/feature/LessonPlanAdminApproveSheet.vue';
import LessonPlanAdminRejectSheet from '@/components/feature/LessonPlanAdminRejectSheet.vue';
import LessonPlanAdminSendBackSheet from '@/components/feature/LessonPlanAdminSendBackSheet.vue';
import LessonPlanReviewHistoryModal from '@/components/feature/LessonPlanReviewHistoryModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRelative } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const plan = ref<LessonPlan | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const showApprove = ref(false);
const showReject = ref(false);
const showSendBack = ref(false);
const showHistory = ref(false);

const planId = computed(() => String(route.params.id ?? ''));

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await LessonPlanService.getById(planId.value);
    if (!res) {
      loadError.value = t('admin.sekolah.lesson_plan_detail.err_not_found');
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
    loadError.value = t('admin.sekolah.lesson_plan_detail.err_invalid_id');
    isLoading.value = false;
    return;
  }
  load();
});

// ── Derived ──
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

const kicker = computed(() => {
  if (!plan.value) return t('admin.sekolah.lesson_plan_detail.kicker_default');
  const parts = [
    `${t('admin.sekolah.lesson_plan_detail.kicker_format', { format: FORMAT_SHORT_LABELS[plan.value.format] })}`,
    plan.value.class_name?.trim().toUpperCase(),
    plan.value.subject_name?.trim().toUpperCase(),
  ].filter((p) => p && p.length > 0);
  return parts.join(' · ');
});

const metaLine = computed(() => {
  if (!plan.value) return '';
  const parts: string[] = [];
  parts.push(t('admin.sekolah.lesson_plan_detail.meta_author', { name: plan.value.teacher_name || t('admin.sekolah.lesson_plan_detail.fallback_teacher') }));
  if (plan.value.academic_year) parts.push(t('admin.sekolah.lesson_plan_detail.meta_year', { year: plan.value.academic_year }));
  if (plan.value.revision > 1) parts.push(t('admin.sekolah.lesson_plan_detail.meta_revision', { rev: plan.value.revision }));
  if (plan.value.submitted_at) {
    parts.push(t('admin.sekolah.lesson_plan_detail.meta_submitted', { time: formatRelative(plan.value.submitted_at) }));
  }
  return parts.join(' · ');
});

// ── Action callbacks ──
function onApproved() {
  toast.value = { message: t('admin.sekolah.lesson_plan_detail.toast_approved'), tone: 'success' };
  load();
}
function onRejected() {
  toast.value = { message: t('admin.sekolah.lesson_plan_detail.toast_rejected'), tone: 'success' };
  load();
}
function onSentBack() {
  toast.value = {
    message: t('admin.sekolah.lesson_plan_detail.toast_sent_back'),
    tone: 'success',
  };
  load();
}

function goBack() {
  router.push({ name: 'admin.lesson-plans' });
}

function openFileUrl(url: string) {
  if (typeof window !== 'undefined') window.open(url, '_blank');
}

// Status decides which action buttons make sense:
//   - Pending  → Setujui / Tolak / Kembalikan
//   - Approved → readonly (admin can re-open by SendBack)
//   - Rejected / SentBack → readonly until teacher resubmits
const canApprove = computed(() => plan.value?.status === 'Pending');
const canReject = computed(() => plan.value?.status === 'Pending');
const canSendBack = computed(
  () => plan.value?.status === 'Pending' || plan.value?.status === 'Approved',
);
</script>

<template>
  <div class="space-y-4 pb-2">
    <!-- BACK CHEVRON + HISTORY -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('admin.sekolah.lesson_plan_detail.back_to_review') }}
      </button>
      <span class="flex-1"></span>
      <button
        v-if="plan"
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt px-2 py-1 rounded-lg hover:bg-slate-100"
        @click="showHistory = true"
      >
        <NavIcon name="list" :size="13" />
        {{ t('admin.sekolah.lesson_plan_detail.history') }}
      </button>
    </div>

    <AsyncView :state="state" :empty-title="t('admin.sekolah.lesson_plan_detail.empty_title')" @retry="load">
      <template #default>
        <div v-if="plan" class="space-y-4">
          <!-- HEADER -->
          <BrandPageHeader
            role="admin"
            :kicker="kicker"
            :title="plan.title || t('admin.sekolah.lesson_plan_detail.no_title')"
            :meta="metaLine"
            :live-dot="false"
          >
            <span
              v-if="plan.ai_generated"
              class="inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-white/15 text-white text-[10px] font-bold uppercase tracking-wider"
            >
              <NavIcon name="sparkles" :size="10" />
              AI
            </span>
          </BrandPageHeader>

          <!-- 3-cell KPI -->
          <section
            class="bg-white border border-slate-200 rounded-2xl shadow-sm grid grid-cols-3 divide-x divide-slate-100"
          >
            <div class="px-3 py-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                {{ t('admin.sekolah.lesson_plan_detail.kpi_sections') }}
              </p>
              <p
                class="text-lg font-black mt-1"
                :style="{ color: accent }"
              >
                {{ totalSections === 0 ? '—' : `${filledSections}/${totalSections}` }}
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                {{ t('admin.sekolah.lesson_plan_detail.kpi_format') }}
              </p>
              <p
                class="text-[12px] font-black mt-1"
                :style="{ color: accent }"
              >
                {{ FORMAT_LABELS[plan.format] }}
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                {{ t('admin.sekolah.lesson_plan_detail.kpi_status') }}
              </p>
              <span
                class="inline-flex items-center gap-1 mt-1 px-2 py-1 rounded-md border text-[11px] font-bold"
                :class="[tone.bg, tone.text, tone.border]"
              >
                <span class="w-1.5 h-1.5 rounded-full" :class="tone.dot" />
                {{ statusLabel }}
              </span>
            </div>
          </section>

          <!-- Previous decision banner (echoes the last admin verdict
               so the reviewer has context before re-acting). -->
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
              class="text-[10px] font-bold uppercase tracking-widest mb-1.5"
              :class="plan.status === 'Rejected' ? 'text-red-700' : 'text-violet-700'"
            >
              {{ plan.status === 'Rejected' ? t('admin.sekolah.lesson_plan_detail.last_reject_note') : t('admin.sekolah.lesson_plan_detail.last_revision_note') }}
            </p>
            <p
              class="text-[12.5px] leading-relaxed whitespace-pre-wrap"
              :class="plan.status === 'Rejected' ? 'text-red-900' : 'text-violet-900'"
            >
              {{ plan.admin_notes }}
            </p>
          </div>

          <!-- FILE preview -->
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
                {{ plan.file_name ?? t('admin.sekolah.lesson_plan_detail.file_default') }}
              </p>
              <p class="text-[11px] text-slate-500 mt-0.5">
                {{ plan.file_mime ?? t('admin.sekolah.lesson_plan_detail.document') }}
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
              {{ t('admin.sekolah.lesson_plan_detail.download') }}
            </Button>
          </div>

          <!-- SECTIONS (read-only) -->
          <section v-if="isStructuredFormat(plan.format)" class="space-y-2.5">
            <header class="flex items-center gap-2 px-1">
              <span
                class="text-[10px] font-bold uppercase tracking-widest"
                :style="{ color: accent }"
              >
                {{ t('admin.sekolah.lesson_plan_detail.sections_label') }}
              </span>
              <span class="text-[10px] text-slate-400 tabular-nums">
                {{ t('admin.sekolah.lesson_plan_detail.sections_filled', { filled: filledSections, total: totalSections }) }}
              </span>
              <span class="flex-1 border-t border-dashed border-slate-200 ml-2"></span>
            </header>

            <article
              v-for="(s, idx) in sections"
              :key="s.key"
              class="bg-white border border-slate-200 rounded-2xl p-4"
            >
              <p
                class="text-[10px] font-bold uppercase tracking-widest"
                :style="{ color: accent }"
              >
                {{ String(idx + 1).padStart(2, '0') }} · {{ s.label }}
              </p>
              <!-- Stored Quill HTML — render via v-html with rpp-prose
                   so tables/lists/headings come out styled. -->
              <div
                v-if="s.value"
                class="rpp-prose mt-2"
                v-html="s.value"
              />
              <p v-else class="text-[11.5px] text-slate-400 italic mt-2">
                {{ t('admin.sekolah.lesson_plan_detail.section_empty') }}
              </p>
            </article>
          </section>

          <!-- Notes -->
          <section v-if="plan.notes" class="bg-white border border-slate-200 rounded-2xl p-4">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">
              {{ t('admin.sekolah.lesson_plan_detail.teacher_notes') }}
            </p>
            <p class="text-[12.5px] text-slate-700 leading-relaxed whitespace-pre-wrap">
              {{ plan.notes }}
            </p>
          </section>

          <!-- ADMIN ACTION BAR -->
          <div
            class="sticky bottom-0 z-30 bg-white/95 backdrop-blur border-t border-slate-200 px-4 py-3 -mx-4"
          >
            <div
              v-if="plan.status === 'Pending'"
              class="grid grid-cols-3 gap-2 max-w-2xl mx-auto"
            >
              <Button variant="secondary" block @click="showSendBack = true">
                <NavIcon name="edit" :size="14" />
                {{ t('admin.sekolah.lesson_plan_detail.send_back') }}
              </Button>
              <Button variant="danger" block @click="showReject = true">
                <NavIcon name="x" :size="14" />
                {{ t('admin.sekolah.lesson_plan_detail.reject') }}
              </Button>
              <Button variant="success" block @click="showApprove = true">
                <NavIcon name="check" :size="14" />
                {{ t('admin.sekolah.lesson_plan_detail.approve') }}
              </Button>
            </div>
            <div
              v-else-if="canSendBack"
              class="text-center max-w-md mx-auto"
            >
              <p class="text-[11px] text-slate-500 mb-2">
                {{ t('admin.sekolah.lesson_plan_detail.current_status') }} <strong class="text-slate-900">{{ statusLabel }}</strong>
              </p>
              <Button variant="secondary" block @click="showSendBack = true">
                <NavIcon name="edit" :size="14" />
                {{ t('admin.sekolah.lesson_plan_detail.request_revision') }}
              </Button>
            </div>
            <p v-else class="text-center text-[12px] text-slate-500 font-medium">
              {{ t('admin.sekolah.lesson_plan_detail.current_status') }} <strong class="text-slate-900">{{ statusLabel }}</strong>
            </p>
            <!-- Hidden helper to keep canApprove/canReject referenced -->
            <span class="hidden">{{ canApprove }}{{ canReject }}</span>
          </div>
        </div>
      </template>
    </AsyncView>

    <!-- ACTION SHEETS -->
    <LessonPlanAdminApproveSheet
      v-if="showApprove && plan"
      :plan="plan"
      @close="showApprove = false"
      @approved="onApproved"
    />
    <LessonPlanAdminRejectSheet
      v-if="showReject && plan"
      :plan="plan"
      @close="showReject = false"
      @rejected="onRejected"
    />
    <LessonPlanAdminSendBackSheet
      v-if="showSendBack && plan"
      :plan="plan"
      @close="showSendBack = false"
      @sent-back="onSentBack"
    />

    <!-- REVIEW HISTORY MODAL -->
    <LessonPlanReviewHistoryModal
      v-if="showHistory && plan"
      :plan-id="plan.id"
      :plan-title="plan.title"
      @close="showHistory = false"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
