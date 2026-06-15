<!--
  AdminLessonPlanReviewView.vue — RPP approval hub (Flutter parity).

  Mirrors `lib/features/lesson_plans/presentation/screens/
  admin_rpp_review_hub_screen.dart`. Tier-grouped queue using the
  `/api/lesson-plans/admin-queue` endpoint:

    1. <BrandPageHeader role="admin"> — kicker + meta line
    2. <KpiStripCards> — Total / Perlu Review / Disetujui / Ditolak
    3. <PageFilterToolbar> — Format + Mapel + Kelas chips + search
    4. Tier sections (Perlu Review · Disetujui · Ditolak) rendered as
       <LessonPlanCard role="admin"> rows. Card click → admin detail.
    5. Inline per-row actions in the "Perlu Review" tier (Setujui /
       Kembalikan / Tolak) so admins can rule on simple cases without
       opening detail.
    6. 3 admin sheets (Approve / Reject / SendBack) reused from
       AdminLessonPlanDetailView.

  Bulk-select carries over: select multiple "Perlu Review" rows then
  hit "Setujui terpilih" → bulk approve sheet.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { LessonPlanService } from '@/services/lesson-plans.service';
import { SubjectService } from '@/services/subjects.service';
import { ClassroomService } from '@/services/classrooms.service';
import {
  FORMAT_LABELS,
  type AdminQueueResponse,
  type AdminQueueTier,
  type LessonPlan,
  type LessonPlanFormat,
} from '@/types/lesson-plans';
import type { Classroom, Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import LessonPlanCard from '@/components/feature/LessonPlanCard.vue';
import LessonPlanAdminApproveSheet from '@/components/feature/LessonPlanAdminApproveSheet.vue';
import LessonPlanAdminRejectSheet from '@/components/feature/LessonPlanAdminRejectSheet.vue';
import LessonPlanAdminSendBackSheet from '@/components/feature/LessonPlanAdminSendBackSheet.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const router = useRouter();
const { t } = useI18n();

// ── Filter state ──
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const classId = ref<string>('');
const subjectId = ref<string>('');
const formatFilter = ref<LessonPlanFormat | ''>('');
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);
const showFormatPicker = ref(false);

const activeClass = computed(
  () => classes.value.find((c) => c.id === classId.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectId.value) ?? null,
);

// ── Queue state ──
const queue = ref<AdminQueueResponse | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// ── Selection (only meaningful for "Perlu Review" tier) ──
const selectedIds = ref<Set<string>>(new Set());
const selectedCount = computed(() => selectedIds.value.size);

// ── Sheet state ──
const approveTarget = ref<LessonPlan | null>(null);
const rejectTarget = ref<LessonPlan | null>(null);
const sendBackTarget = ref<LessonPlan | null>(null);
const bulkApproveOpen = ref(false);
const bulkRejectOpen = ref(false);

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Loaders ──
async function loadReferences() {
  try {
    const [c, s] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
    ]);
    classes.value = c.items;
    subjects.value = s.items;
  } catch {
    // pickers degrade to empty
  }
}

async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await LessonPlanService.getAdminQueue({
      format: formatFilter.value || undefined,
      class_id: classId.value || undefined,
      subject_id: subjectId.value || undefined,
      search: searchQuery.value || undefined,
    });
    queue.value = res;
    // Drop stale selections — only keep ids still in the Perlu Review tier.
    const pending = res.tiers.find((t) => t.key === 'perlu_review');
    const present = new Set(pending?.items.map((i) => i.id) ?? []);
    selectedIds.value = new Set(
      Array.from(selectedIds.value).filter((id) => present.has(id)),
    );
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await reload();
});

let searchTimer: ReturnType<typeof setTimeout> | null = null;
import { watch } from 'vue';
watch([classId, subjectId, formatFilter], () => reload());
watch(searchQuery, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => reload(), 350);
});
useAcademicYearWatcher(() => reload());

// ── KPI ──
const kpiCards = computed<KpiCard[]>(() => {
  const k = queue.value?.kpi ?? {
    total: 0,
    perlu_review: 0,
    disetujui: 0,
    ditolak: 0,
  };
  return [
    {
      icon: 'file-text',
      label: t('admin.sekolah.lesson_plan_review.kpi_total'),
      value: k.total,
      tone: 'brand',
    },
    {
      icon: 'bell',
      label: t('admin.sekolah.lesson_plan_review.kpi_needs_review'),
      value: k.perlu_review,
      tone: k.perlu_review > 0 ? 'amber' : 'slate',
      accented: k.perlu_review > 0,
    },
    {
      icon: 'check-circle',
      label: t('admin.sekolah.lesson_plan_review.kpi_approved'),
      value: k.disetujui,
      tone: 'green',
    },
    {
      icon: 'x-circle',
      label: t('admin.sekolah.lesson_plan_review.kpi_rejected'),
      value: k.ditolak,
      tone: k.ditolak > 0 ? 'red' : 'slate',
    },
  ];
});

// ── List state ──
const visibleTiers = computed<AdminQueueTier[]>(
  () => queue.value?.tiers.filter((t) => t.count > 0) ?? [],
);

const listState = computed<
  AsyncState<AdminQueueTier[]>
>(() => {
  if (isLoading.value && !queue.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleTiers.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleTiers.value };
});

// ── Tier styling ──
function tierTone(tier: AdminQueueTier): { dot: string; text: string } {
  switch (tier.tone) {
    case 'warn':
      return { dot: 'bg-amber-500', text: 'text-amber-700' };
    case 'good':
      return { dot: 'bg-emerald-500', text: 'text-emerald-700' };
    case 'bad':
      return { dot: 'bg-red-500', text: 'text-red-700' };
  }
}

// ── Selection ──
function toggleSelect(id: string) {
  const next = new Set(selectedIds.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selectedIds.value = next;
}
function clearSelection() {
  selectedIds.value = new Set();
}
function isSelected(id: string): boolean {
  return selectedIds.value.has(id);
}

// ── Pickers ──
function pickClass(id: string) {
  classId.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectId.value = id;
  showSubjectPicker.value = false;
}
function pickFormat(f: LessonPlanFormat | '') {
  formatFilter.value = f;
  showFormatPicker.value = false;
}

// ── Sheet callbacks ──
function onApproved() {
  toast.value = { message: t('admin.sekolah.lesson_plan_review.toast_approved'), tone: 'success' };
  reload();
}
function onRejected() {
  toast.value = { message: t('admin.sekolah.lesson_plan_review.toast_rejected'), tone: 'success' };
  reload();
}
function onSentBack() {
  toast.value = { message: t('admin.sekolah.lesson_plan_review.toast_sent_back'), tone: 'success' };
  reload();
}
function onBulkApproved() {
  toast.value = {
    message: t('admin.sekolah.lesson_plan_review.toast_bulk_approved', { count: selectedCount.value }),
    tone: 'success',
  };
  clearSelection();
  reload();
}
function onBulkRejected() {
  toast.value = {
    message: t('admin.sekolah.lesson_plan_review.toast_bulk_rejected', { count: selectedCount.value }),
    tone: 'success',
  };
  clearSelection();
  reload();
}

function openDetail(plan: LessonPlan) {
  router.push({
    name: 'admin.lesson-plans.detail',
    params: { id: plan.id },
  });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.lesson_plan_review.header_kicker')"
      :title="t('admin.sekolah.lesson_plan_review.header_title')"
      :meta="queue
        ? t('admin.sekolah.lesson_plan_review.header_meta', { total: queue.kpi.total, pending: queue.kpi.perlu_review })
        : t('admin.sekolah.lesson_plan_review.header_meta_loading')"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      :search-placeholder="t('admin.sekolah.lesson_plan_review.search_placeholder')"
    >
      <template #chips>
        <AppFilterChip
          :label="t('admin.sekolah.lesson_plan_review.chip_class')"
          :value="activeClass?.name ?? t('admin.sekolah.lesson_plan_review.all_classes')"
          icon-name="layers"
          tone="brand"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          :label="t('admin.sekolah.lesson_plan_review.chip_subject')"
          :value="activeSubject?.name ?? t('admin.sekolah.lesson_plan_review.all_subjects')"
          icon-name="book"
          tone="amber"
          @click="showSubjectPicker = true"
        />
        <AppFilterChip
          :label="t('admin.sekolah.lesson_plan_review.chip_format')"
          :value="formatFilter ? FORMAT_LABELS[formatFilter] : t('admin.sekolah.lesson_plan_review.all_formats')"
          icon-name="file-text"
          tone="violet"
          @click="showFormatPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- TIER QUEUE -->
    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.lesson_plan_review.empty_title')"
      :empty-description="t('admin.sekolah.lesson_plan_review.empty_description')"
      empty-icon="file-text"
      @retry="reload"
    >
      <div class="space-y-5">
        <section
          v-for="tier in visibleTiers"
          :key="tier.key"
          class="space-y-2"
        >
          <header class="flex items-center gap-2 px-1">
            <span class="w-1.5 h-1.5 rounded-full" :class="tierTone(tier).dot" />
            <span
              class="text-[10px] font-bold uppercase tracking-widest"
              :class="tierTone(tier).text"
            >
              {{ tier.label }}
            </span>
            <span class="text-[10px] text-slate-400 tabular-nums">
              · {{ tier.count }}
            </span>
            <span class="flex-1 border-t border-dashed border-slate-200 ml-2"></span>
          </header>

          <div class="space-y-2">
            <div
              v-for="plan in tier.items"
              :key="plan.id"
              class="flex items-start gap-2"
            >
              <!-- Bulk-select checkbox (only meaningful for Perlu Review) -->
              <button
                v-if="tier.key === 'perlu_review'"
                type="button"
                class="mt-3 w-4 h-4 rounded border border-slate-300 grid place-items-center flex-shrink-0"
                :class="{
                  'bg-role-admin border-role-admin text-white': isSelected(plan.id),
                }"
                :aria-label="t('admin.sekolah.lesson_plan_review.aria_select', { title: plan.title })"
                @click.stop="toggleSelect(plan.id)"
              >
                <NavIcon v-if="isSelected(plan.id)" name="check" :size="10" />
              </button>

              <div class="flex-1 min-w-0">
                <LessonPlanCard
                  :plan="plan"
                  role="admin"
                  show-notes
                  @click="openDetail"
                />

                <!-- Inline quick actions for Perlu Review tier -->
                <div
                  v-if="tier.key === 'perlu_review'"
                  class="flex items-center gap-1.5 mt-1.5 ml-3"
                >
                  <button
                    type="button"
                    class="text-[11px] font-bold px-2.5 py-1 rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 transition inline-flex items-center gap-1"
                    @click="approveTarget = plan"
                  >
                    <NavIcon name="check" :size="11" />
                    {{ t('admin.sekolah.lesson_plan_review.approve') }}
                  </button>
                  <button
                    type="button"
                    class="text-[11px] font-bold px-2.5 py-1 rounded-lg bg-white border border-violet-300 text-violet-700 hover:bg-violet-50 transition inline-flex items-center gap-1"
                    @click="sendBackTarget = plan"
                  >
                    <NavIcon name="edit" :size="11" />
                    {{ t('admin.sekolah.lesson_plan_review.send_back') }}
                  </button>
                  <button
                    type="button"
                    class="text-[11px] font-bold px-2.5 py-1 rounded-lg bg-white border border-red-200 text-red-700 hover:bg-red-50 transition inline-flex items-center gap-1"
                    @click="rejectTarget = plan"
                  >
                    <NavIcon name="x" :size="11" />
                    {{ t('admin.sekolah.lesson_plan_review.reject') }}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </AsyncView>

    <!-- BULK ACTION BAR -->
    <section
      v-if="selectedCount > 0"
      class="sticky bottom-4 z-30 flex items-center gap-3 px-4 py-3 bg-white border border-slate-200 rounded-2xl shadow-lg"
    >
      <span class="text-[11px] text-slate-600">
        <strong class="text-slate-900">{{ selectedCount }}</strong> {{ t('admin.sekolah.lesson_plan_review.selected_suffix') }}
      </span>
      <button
        type="button"
        class="text-[11px] font-bold text-slate-500 hover:text-slate-900"
        @click="clearSelection"
      >
        {{ t('admin.sekolah.lesson_plan_review.cancel') }}
      </button>
      <span class="flex-1"></span>
      <Button variant="danger" size="sm" @click="bulkRejectOpen = true">
        {{ t('admin.sekolah.lesson_plan_review.bulk_reject') }}
      </Button>
      <Button variant="success" size="sm" @click="bulkApproveOpen = true">
        {{ t('admin.sekolah.lesson_plan_review.bulk_approve', { count: selectedCount }) }}
      </Button>
    </section>

    <!-- ── PICKERS ── -->
    <Modal v-if="showClassPicker" :title="t('admin.sekolah.lesson_plan_review.pick_class')" @close="showClassPicker = false">
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': !classId }"
            @click="pickClass('')"
          >
            {{ t('admin.sekolah.lesson_plan_review.all_classes') }}
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': c.id === classId }"
            @click="pickClass(c.id)"
          >
            {{ c.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <Modal v-if="showSubjectPicker" :title="t('admin.sekolah.lesson_plan_review.pick_subject')" @close="showSubjectPicker = false">
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': !subjectId }"
            @click="pickSubject('')"
          >
            {{ t('admin.sekolah.lesson_plan_review.all_subjects') }}
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': s.id === subjectId }"
            @click="pickSubject(s.id)"
          >
            {{ s.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <Modal v-if="showFormatPicker" :title="t('admin.sekolah.lesson_plan_review.pick_format')" @close="showFormatPicker = false">
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': !formatFilter }"
            @click="pickFormat('')"
          >
            {{ t('admin.sekolah.lesson_plan_review.all_formats') }}
          </button>
        </li>
        <li v-for="f in (['k13', 'rpp_1_halaman', 'modul_ajar', 'file'] as LessonPlanFormat[])" :key="f">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': formatFilter === f }"
            @click="pickFormat(f)"
          >
            {{ FORMAT_LABELS[f] }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── ACTION SHEETS ── -->
    <LessonPlanAdminApproveSheet
      v-if="approveTarget"
      :plan="approveTarget"
      @close="approveTarget = null"
      @approved="onApproved"
    />
    <LessonPlanAdminRejectSheet
      v-if="rejectTarget"
      :plan="rejectTarget"
      @close="rejectTarget = null"
      @rejected="onRejected"
    />
    <LessonPlanAdminSendBackSheet
      v-if="sendBackTarget"
      :plan="sendBackTarget"
      @close="sendBackTarget = null"
      @sent-back="onSentBack"
    />

    <!-- Bulk sheets — pass bulkIds, no `plan` -->
    <LessonPlanAdminApproveSheet
      v-if="bulkApproveOpen"
      :plan="null"
      :bulk-ids="Array.from(selectedIds)"
      @close="bulkApproveOpen = false"
      @approved="onBulkApproved"
    />
    <LessonPlanAdminRejectSheet
      v-if="bulkRejectOpen"
      :plan="null"
      :bulk-ids="Array.from(selectedIds)"
      @close="bulkRejectOpen = false"
      @rejected="onBulkRejected"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
