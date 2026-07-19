<!--
  AdminSubjectManagementView.vue — admin subject management.

  Uses the shared Schedule/Keuangan chrome pattern.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { SubjectService } from '@/services/subjects.service';
import { AdminDataExcelService } from '@/services/admin-data-excel.service';
import { useRoleHex } from '@/composables/useRoleHex';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import type { Subject } from '@/types/entities';
import type { Pagination } from '@/types/api';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import PaginationView from '@/components/data/Pagination.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import LinkMasterPickerModal from '@/components/feature/LinkMasterPickerModal.vue';
import SubjectEditSheet from './widgets/SubjectEditSheet.vue';
import SubjectCurriculumCard from './widgets/SubjectCurriculumCard.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import AdminDataMenu from '@/components/feature/AdminDataMenu.vue';
import AdminImportExcelModal from '@/components/feature/AdminImportExcelModal.vue';
import AdminImportResultModal from '@/components/feature/AdminImportResultModal.vue';
import type {
  ImportDetailRow,
  ImportWarningRow,
} from '@/services/admin-data-excel.service';
import Modal from '@/components/ui/Modal.vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';

// Aliased to `$t` so v-for over `subjects` (any name) won't shadow it.
const { t: $t } = useI18n();
const primaryColor = useRoleHex();
const ayStore = useAcademicYearStore();
const ayReadOnly = computed(() => ayStore.isReadOnly);
const router = useRouter();

const subjects = shallowRef<Subject[]>([]);
const pagination = ref<Pagination | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const search = ref('');
const filters = reactive<{
  status: 'active' | 'inactive' | null;
  grade_level: string | null;
  classes_status: 'with' | 'without' | null;
}>({
  status: null,
  grade_level: null,
  classes_status: null,
});
const selectedIds = ref<Set<string>>(new Set());

const editTarget = ref<Subject | null | undefined>(undefined);
const deleteTarget = ref<Subject | null>(null);
const linkMasterTarget = ref<Subject | null>(null);
const bulkDeleteOpen = ref(false);
const showImport = ref(false);
const isSaving = ref(false);

// Per-row import result — feeds the shared result dialog when non-empty.
const importDetails = ref<ImportDetailRow[]>([]);
const importCounts = ref<{
  imported?: number;
  skipped?: number;
  conflicts?: number;
  failed?: number;
}>({});
// Non-blocking per-row warnings (post-!453: unresolved Master link).
const importWarnings = ref<ImportWarningRow[]>([]);

const showStatusPicker = ref(false);
const showGradePicker = ref(false);
const showClassesPicker = ref(false);

const state = computed<AsyncState<Subject[]>>(() => {
  if (isLoading.value && subjects.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filteredSubjects.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredSubjects.value };
});

const filteredSubjects = computed(() => {
  if (filters.classes_status === null) return subjects.value;
  if (filters.classes_status === 'with') {
    return subjects.value.filter((s) => (s.class_count ?? 0) > 0);
  }
  return subjects.value.filter((s) => (s.class_count ?? 0) === 0);
});

const gradeLevelOptions = computed<FacetOption[]>(() => {
  const set = new Set<string>();
  for (const s of subjects.value) {
    if (s.grade_level) set.add(String(s.grade_level));
  }
  return Array.from(set)
    .sort()
    .map((g) => ({ key: g, label: $t('admin.sekolah.subject_management.tingkat', { grade: g }) }));
});

const STATUS_OPTIONS = computed<FacetOption[]>(() => [
  { key: 'active', label: $t('admin.sekolah.subject_management.status_active') },
  { key: 'inactive', label: $t('admin.sekolah.subject_management.status_inactive') },
]);
const CLASSES_OPTIONS = computed<FacetOption[]>(() => [
  { key: 'with', label: $t('admin.sekolah.subject_management.classes_with') },
  { key: 'without', label: $t('admin.sekolah.subject_management.classes_without') },
]);

const statusChipValue = computed(() => {
  if (!filters.status) return $t('admin.shared.allFilter');
  return filters.status === 'active'
    ? $t('admin.subjects.statusActive')
    : $t('admin.subjects.statusInactive');
});
const gradeChipValue = computed(() => {
  if (!filters.grade_level) return $t('admin.shared.allFilter');
  return $t('admin.classes.gradePrefix', { grade: filters.grade_level });
});
const classesChipValue = computed(() => {
  if (!filters.classes_status) return $t('admin.shared.allFilter');
  return filters.classes_status === 'with'
    ? $t('admin.subjects.hasLinked')
    : $t('admin.subjects.notLinked');
});

const activeFilterCount = computed(() => {
  let n = 0;
  if (filters.status) n++;
  if (filters.grade_level) n++;
  if (filters.classes_status) n++;
  return n;
});

async function reload(page = 1) {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await SubjectService.list({
      page,
      per_page: 20,
      search: search.value || undefined,
      status: filters.status ?? undefined,
      grade_level: filters.grade_level ?? undefined,
    });
    subjects.value = res.items;
    pagination.value = res.pagination ?? null;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(reload);
useAcademicYearWatcher(async () => {
  await reload(1);
});

function onSearch(q: string) {
  search.value = q;
  reload(1);
}

function clearAll() {
  filters.status = null;
  filters.grade_level = null;
  filters.classes_status = null;
  search.value = '';
  reload(1);
}

// ── KPI ──
const totalSubjects = computed(
  () => pagination.value?.total_items ?? subjects.value.length,
);
const pageActiveCount = computed(
  () => subjects.value.filter((s) => s.is_active !== false).length,
);
const pageInactiveCount = computed(
  () => subjects.value.filter((s) => s.is_active === false).length,
);
const pageWithClassesCount = computed(
  () => subjects.value.filter((s) => (s.class_count ?? 0) > 0).length,
);

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'book-open', label: $t('admin.subjects.kpiTotal'), value: totalSubjects.value, tone: 'brand' },
  {
    icon: 'check-circle',
    label: $t('admin.subjects.kpiActive'),
    value: pageActiveCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'green',
  },
  {
    icon: 'archive',
    label: $t('admin.subjects.kpiInactive'),
    value: pageInactiveCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: pageInactiveCount.value > 0 ? 'amber' : 'slate',
  },
  {
    icon: 'layers',
    label: $t('admin.subjects.kpiLinkedClasses'),
    value: pageWithClassesCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'violet',
  },
]);

const headerMeta = computed(() =>
  $t('admin.subjects.meta', {
    count: totalSubjects.value.toLocaleString(),
    year: ayStore.yearLabel,
  }),
);

// ── Delete impact preview — concrete cascade consequences ──
// Subjects (mata pelajaran) are the axis for grades + schedule + RPP
// + materi — so their cascade is heavier than kelas. Assessment
// columns / nilai per this mapel are unrecoverable once dropped.
const SUBJECT_DELETE_IMPACT = computed<string[]>(() => [
  $t('admin.sekolah.subject_management.impact.grades'),
  $t('admin.sekolah.subject_management.impact.schedule'),
  $t('admin.sekolah.subject_management.impact.teacherAssign'),
  $t('admin.sekolah.subject_management.impact.materials'),
  $t('admin.sekolah.subject_management.impact.reportCardKept'),
]);
const subjectDeleteImpact = SUBJECT_DELETE_IMPACT;
const subjectBulkDeleteImpact = computed<string[]>(() => [
  $t('admin.sekolah.subject_management.impact.bulkPrefix', {
    count: selectedIds.value.size,
  }),
  ...SUBJECT_DELETE_IMPACT.value,
]);

// ── Bulk ──
function toggleSelect(id: string) {
  const set = new Set(selectedIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  selectedIds.value = set;
}
function clearSelection() {
  selectedIds.value = new Set();
}

async function performBulkDelete() {
  try {
    isSaving.value = true;
    const ids = Array.from(selectedIds.value);
    const res = await SubjectService.bulkRemove(ids);
    clearSelection();
    bulkDeleteOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.deleted} mapel terhapus · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = { message: `${res.deleted} mapel terhapus.`, tone: 'success' };
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Bulk edit — status (active/inactive) + KKM ─────────────────────
// Two operations shipped: bulk activate/deactivate + school-wide KKM
// change. Other fields (name / code / description / master_subject_id
// / grade_level) are per-mapel truth and stay OUT of the bulk surface.
// KKM is a real workflow — schools often align KKM across a batch of
// mapel (e.g. all tingkat-7 exact sciences → KKM 75). Send both
// `status` + `is_active` on the status flip to match the edit sheet
// (belt-and-suspenders for legacy backends).
const bulkStatusOpen = ref(false);
const bulkKkmOpen = ref(false);
const bulkTargetStatus = ref<'active' | 'inactive' | ''>('');
const bulkTargetKkm = ref<number>(75);

function openBulkStatus(): void {
  bulkTargetStatus.value = '';
  bulkStatusOpen.value = true;
}
function openBulkKkm(): void {
  bulkTargetKkm.value = 75;
  bulkKkmOpen.value = true;
}

async function performBulkStatus(): Promise<void> {
  if (!bulkTargetStatus.value) return;
  try {
    isSaving.value = true;
    const ids = Array.from(selectedIds.value);
    const target = bulkTargetStatus.value;
    const isActive = target === 'active';
    const res = await SubjectService.bulkUpdate(ids, {
      status: target,
      is_active: isActive,
    });
    const targetLabel = isActive ? $t('status.Active') : $t('status.Inactive');
    clearSelection();
    bulkStatusOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.updated} mapel diubah ke ${targetLabel} · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = {
        message: `${res.updated} mapel diubah ke ${targetLabel}.`,
        tone: 'success',
      };
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

async function performBulkKkm(): Promise<void> {
  const val = Number(bulkTargetKkm.value);
  if (!Number.isFinite(val) || val < 0 || val > 100) {
    toast.value = { message: 'KKM harus antara 0–100.', tone: 'error' };
    return;
  }
  try {
    isSaving.value = true;
    const ids = Array.from(selectedIds.value);
    const res = await SubjectService.bulkUpdate(ids, { kkm: val });
    clearSelection();
    bulkKkmOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `KKM ${val} diterapkan ke ${res.updated} mapel · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = {
        message: `KKM ${val} diterapkan ke ${res.updated} mapel.`,
        tone: 'success',
      };
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── CRUD ──
async function handleSave(payload: Record<string, unknown>) {
  isSaving.value = true;
  try {
    if (editTarget.value && editTarget.value.id) {
      await SubjectService.update(editTarget.value.id, payload);
    } else {
      await SubjectService.create(payload);
    }
    editTarget.value = undefined;
    await reload(pagination.value?.current_page ?? 1);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

async function confirmDelete() {
  if (!deleteTarget.value) return;
  isSaving.value = true;
  try {
    await SubjectService.remove(deleteTarget.value.id);
    deleteTarget.value = null;
    await reload(pagination.value?.current_page ?? 1);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Drill-in ──
function openSubjectClasses(s: Subject) {
  router.push({
    name: 'admin.subjects.classes',
    params: { subjectId: s.id },
  });
}

// ── Link-master (ORPHAN card CTA) ─────────────────────────────────
// The card emits `link-master` when the admin taps "Tautkan sekarang"
// on the amber body. We open the shared LinkMasterPickerModal here so
// the modal instance is owned by the view (matches CRUD modals) and a
// successful link can trigger a full page reload.
function onLinkMasterOpen(s: Subject) {
  linkMasterTarget.value = s;
}
async function onMasterLinked() {
  linkMasterTarget.value = null;
  toast.value = {
    message: $t('admin.subjects.linkMaster.success'),
    tone: 'success',
  };
  await reload(pagination.value?.current_page ?? 1);
}

// ── Excel ──
async function exportExcel() {
  try {
    await AdminDataExcelService.exportExcel('subject');
    toast.value = { message: 'Excel terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
async function downloadTemplate() {
  try {
    await AdminDataExcelService.downloadTemplate('subject');
    toast.value = {
      // Post-!453 template gained 2 optional columns — call them out
      // in the download-success toast so an admin who never opens the
      // Petunjuk tab still knows what they are.
      message: 'Template terdownload. Kolom baru: Kelas (1–12) & Master (opsional).',
      tone: 'success',
    };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
function onImportDone(res: {
  imported: number;
  failed: number;
  skipped?: number;
  conflicts?: number;
  details?: ImportDetailRow[];
  warnings?: ImportWarningRow[];
}) {
  // Surface EVERY processed row grouped by status in the shared dialog.
  importDetails.value = res.details ?? [];
  importWarnings.value = res.warnings ?? [];
  importCounts.value = {
    imported: res.imported,
    skipped: res.skipped ?? 0,
    conflicts: res.conflicts ?? 0,
    failed: res.failed,
  };
  const failPart = res.failed > 0 ? ` · ${res.failed} gagal` : '';
  const warnPart =
    importWarnings.value.length > 0
      ? ` · ${importWarnings.value.length} perlu perhatian`
      : '';
  toast.value = {
    message: `${res.imported} mapel diimpor${failPart}${warnPart}.`,
    tone: res.failed > 0 ? 'error' : 'success',
  };
  reload(1);
}

</script>

<template>
  <AdminCrudScaffold
    :title="$t('admin.subjects.title')"
    :kicker="$t('admin.shared.kicker')"
    :meta="headerMeta"
    :kpi-cards="kpiCards"
    :state="state"
    :selected-count="selectedIds.size"
    :active-filter-count="activeFilterCount"
    :hide-add-fab="ayReadOnly"
    :search-placeholder="$t('admin.subjects.searchPlaceholder')"
    :empty-title="$t('admin.subjects.emptyTitle')"
    :empty-description="$t('admin.subjects.emptyDesc')"
    :fab-label="$t('admin.subjects.addFab')"
    @search="onSearch"
    @clear-all-filters="clearAll"
    @add-click="editTarget = null"
    @bulk-clear="clearSelection"
    @retry="reload()"
  >
    <template #header-actions>
      <AdminDataMenu
        :read-only="ayReadOnly"
        @refresh="reload(pagination?.current_page ?? 1)"
        @export-excel="exportExcel"
        @import-excel="showImport = true"
        @download-template="downloadTemplate"
      />
    </template>

    <template #filter-chips>
      <AppFilterChip
        icon-name="check-circle"
        :label="$t('admin.subjects.filterStatus')"
        :value="statusChipValue"
        tone="green"
        @click="showStatusPicker = true"
      />
      <AppFilterChip
        v-if="gradeLevelOptions.length > 0"
        icon-name="bar-chart"
        :label="$t('admin.classes.filterGrade')"
        :value="gradeChipValue"
        tone="brand"
        @click="showGradePicker = true"
      />
      <AppFilterChip
        icon-name="layers"
        :label="$t('admin.subjects.filterLinked')"
        :value="classesChipValue"
        tone="violet"
        @click="showClassesPicker = true"
      />
    </template>

    <ul class="grid grid-cols-1 sm:grid-cols-2 gap-2">
      <li v-for="s in filteredSubjects" :key="s.id">
        <SubjectCurriculumCard
          :subject="s"
          :primary-color="primaryColor"
          :selected="selectedIds.has(s.id)"
          :read-only="ayReadOnly"
          @select="toggleSelect(s.id)"
          @open="selectedIds.size > 0 ? toggleSelect(s.id) : openSubjectClasses(s)"
          @edit="editTarget = s"
          @delete="deleteTarget = s"
          @link-master="onLinkMasterOpen(s)"
        />
      </li>
    </ul>

    <PaginationView
      v-if="pagination && pagination.total_pages > 1"
      :pagination="pagination"
      class="mt-md"
      @change="reload($event)"
    />

    <template #bulk-actions>
      <Button variant="secondary" size="sm" @click="openBulkStatus">
        {{ $t('admin.sekolah.subject_management.bulk_status_action') }}
      </Button>
      <Button variant="secondary" size="sm" @click="openBulkKkm">
        {{ $t('admin.sekolah.subject_management.bulk_kkm_action') }}
      </Button>
      <Button variant="danger" size="sm" @click="bulkDeleteOpen = true">
        Hapus ({{ selectedIds.size }})
      </Button>
    </template>
  </AdminCrudScaffold>

  <!-- Per-facet pickers -->
  <FilterFacetPickerModal
    v-if="showStatusPicker"
    :title="$t('admin.sekolah.subject_management.filter_status_title')"
    :options="STATUS_OPTIONS"
    :selected="filters.status ?? ''"
    @close="showStatusPicker = false"
    @apply="(v) => { filters.status = (v as 'active' | 'inactive' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showGradePicker"
    :title="$t('admin.sekolah.subject_management.filter_tingkat_title')"
    :options="gradeLevelOptions"
    :selected="filters.grade_level ?? ''"
    @close="showGradePicker = false"
    @apply="(v) => { filters.grade_level = v || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showClassesPicker"
    :title="$t('admin.sekolah.subject_management.filter_classes_title')"
    :options="CLASSES_OPTIONS"
    :selected="filters.classes_status ?? ''"
    @close="showClassesPicker = false"
    @apply="(v) => { filters.classes_status = (v as 'with' | 'without' | '') || null; }"
  />

  <SubjectEditSheet
    v-if="editTarget !== undefined"
    :subject="editTarget"
    :is-saving="isSaving"
    @close="editTarget = undefined"
    @save="handleSave"
  />

  <ConfirmationDialog
    v-if="deleteTarget"
    :title="$t('admin.sekolah.subject_management.delete_one_title', { name: deleteTarget.name })"
    :message="$t('admin.sekolah.subject_management.delete_one_message')"
    :confirm-label="$t('admin.sekolah.subject_management.delete')"
    :impact="subjectDeleteImpact"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <ConfirmationDialog
    v-if="bulkDeleteOpen"
    :title="$t('admin.sekolah.subject_management.delete_bulk_title', { count: selectedIds.size })"
    :message="$t('admin.sekolah.subject_management.delete_bulk_message')"
    :confirm-label="$t('admin.sekolah.subject_management.delete_all')"
    :impact="subjectBulkDeleteImpact"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <!-- Bulk-status modal — 2 radios (active/inactive). -->
  <Modal
    v-if="bulkStatusOpen"
    :title="$t('admin.sekolah.subject_management.bulk_status_title', { count: selectedIds.size })"
    :subtitle="$t('admin.sekolah.subject_management.bulk_status_subtitle')"
    @close="bulkStatusOpen = false"
  >
    <div class="space-y-2">
      <label class="flex items-start gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer">
        <input
          v-model="bulkTargetStatus"
          type="radio"
          value="active"
          class="mt-1 accent-role-admin"
        />
        <div>
          <p class="text-[13px] font-black text-slate-900">
            {{ $t('status.Active') }}
          </p>
          <p class="text-[11.5px] text-slate-500 mt-0.5">
            {{ $t('admin.sekolah.subject_management.bulk_status_active_hint') }}
          </p>
        </div>
      </label>
      <label class="flex items-start gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer">
        <input
          v-model="bulkTargetStatus"
          type="radio"
          value="inactive"
          class="mt-1 accent-role-admin"
        />
        <div>
          <p class="text-[13px] font-black text-slate-900">
            {{ $t('status.Inactive') }}
          </p>
          <p class="text-[11.5px] text-slate-500 mt-0.5">
            {{ $t('admin.sekolah.subject_management.bulk_status_inactive_hint') }}
          </p>
        </div>
      </label>
      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="bulkStatusOpen = false">
          {{ $t('common.cancel') }}
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!bulkTargetStatus"
          @click="performBulkStatus"
        >
          {{ $t('admin.sekolah.subject_management.bulk_status_confirm') }}
        </Button>
      </div>
    </div>
  </Modal>

  <!-- Bulk-KKM modal — number 0-100 applied to N mapel. -->
  <Modal
    v-if="bulkKkmOpen"
    :title="$t('admin.sekolah.subject_management.bulk_kkm_title', { count: selectedIds.size })"
    :subtitle="$t('admin.sekolah.subject_management.bulk_kkm_subtitle')"
    @close="bulkKkmOpen = false"
  >
    <div class="space-y-3">
      <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
        {{ $t('admin.sekolah.subject_management.bulk_kkm_label') }}
      </label>
      <input
        v-model.number="bulkTargetKkm"
        type="number"
        min="0"
        max="100"
        class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[14px] font-bold text-slate-900 outline-none focus:border-role-admin tabular-nums"
      />
      <p class="text-2xs text-slate-500 leading-relaxed">
        {{ $t('admin.sekolah.subject_management.bulk_kkm_hint', { count: selectedIds.size, kkm: bulkTargetKkm }) }}
      </p>
      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="bulkKkmOpen = false">
          {{ $t('common.cancel') }}
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          @click="performBulkKkm"
        >
          {{ $t('admin.sekolah.subject_management.bulk_kkm_confirm') }}
        </Button>
      </div>
    </div>
  </Modal>

  <AdminImportExcelModal
    v-if="showImport"
    entity="subject"
    :title="$t('admin.sekolah.subject_management.import_title')"
    @close="showImport = false"
    @done="onImportDone"
  />

  <!--
    Post-import result: EVERY processed mapel grouped by status, plus
    the amber Peringatan section for non-blocking master-not-found
    warnings (post-!453).
  -->
  <AdminImportResultModal
    v-if="importDetails.length > 0 || importWarnings.length > 0"
    entity-label="mapel"
    :details="importDetails"
    :counts="importCounts"
    :warnings="importWarnings"
    @close="
      importDetails = [];
      importWarnings = [];
    "
  />

  <!--
    Link-master picker — opened when the SubjectCurriculumCard emits
    `link-master` from its ORPHAN body ("Tautkan sekarang" CTA). The
    modal is a shared component with the LMS banner; on success we
    close the modal and reload the current page so the card flips
    LINKED (violet body) on the next paint.
  -->
  <LinkMasterPickerModal
    v-if="linkMasterTarget"
    :subject-id="linkMasterTarget.id"
    :subject-name="linkMasterTarget.name"
    :suggested-master-id="null"
    @close="linkMasterTarget = null"
    @linked="onMasterLinked"
  />

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
