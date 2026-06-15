<!--
  AdminStudentManagementView.vue — admin student management.

  Uses the same chrome pattern as Admin Jadwal / Keuangan:
    - BrandPageHeader admin (gradient)
    - KpiStripCards (4-up)
    - PageFilterToolbar with per-facet AppFilterChip buttons
    - FilterFacetPickerModal per facet
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { StudentService } from '@/services/students.service';
import { ClassroomService } from '@/services/classrooms.service';
import { AdminDataExcelService } from '@/services/admin-data-excel.service';
import { useRoleHex } from '@/composables/useRoleHex';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import type { Student, Classroom } from '@/types/entities';
import type { Pagination } from '@/types/api';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import BrandListRow from '@/components/feature/BrandListRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import PaginationView from '@/components/data/Pagination.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import StudentEditSheet from './widgets/StudentEditSheet.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import AdminDataMenu from '@/components/feature/AdminDataMenu.vue';
import AdminEntityDetailSheet, {
  type DetailSection,
} from '@/components/feature/AdminEntityDetailSheet.vue';
import AdminImportExcelModal from '@/components/feature/AdminImportExcelModal.vue';
import Toast from '@/components/ui/Toast.vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';

const route = useRoute();
const { t } = useI18n();
const primaryColor = useRoleHex();
const ayStore = useAcademicYearStore();
const ayReadOnly = computed(() => ayStore.isReadOnly);

// ── Data state ─────────────────────────────────────────────────────
const students = shallowRef<Student[]>([]);
const classes = shallowRef<Classroom[]>([]);
const pagination = ref<Pagination | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Filter + search state ──────────────────────────────────────────
const search = ref('');
const filters = reactive<{
  status: 'active' | 'inactive' | 'unverified' | null;
  class_ids: string[];
  gender: 'L' | 'P' | null;
  /**
   * Free-text search by guardian (wali) name. Matches the mobile UX:
   * admin types the wali's name and the list filters by case-insensitive
   * LIKE. Replaces the prior with/without dropdown.
   */
  guardian_name: string | null;
}>({
  status: null,
  class_ids: [],
  gender: null,
  guardian_name: null,
});

// Buffer for the guardian-name search modal (so reload() doesn't fire
// on every keystroke until the user confirms / closes the modal).
const guardianNameDraft = ref('');

// ── Wali (guardian) type-ahead state ───────────────────────────────
// As the admin types in the "Cari Wali" modal we query
// `GET /student/guardians?search=` (debounced) and surface matching
// names in a dropdown — same UX as the Flutter app's
// `Autocomplete<String>` in the student filter sheet. Selecting a
// suggestion fills the input; the list still filters by the typed text
// even if the admin types a name not yet in the suggestion list.
const guardianSuggestions = ref<string[]>([]);
const guardianSearching = ref(false);
const showGuardianSuggestions = ref(false);
let guardianSearchSeq = 0;
let guardianSearchTimer: ReturnType<typeof setTimeout> | null = null;

function onGuardianInput() {
  showGuardianSuggestions.value = true;
  if (guardianSearchTimer) clearTimeout(guardianSearchTimer);
  const q = guardianNameDraft.value.trim();
  // Mirror mobile: only query once there are >= 2 characters, otherwise
  // clear any stale suggestions.
  if (q.length < 2) {
    guardianSuggestions.value = [];
    guardianSearching.value = false;
    return;
  }
  guardianSearching.value = true;
  guardianSearchTimer = setTimeout(async () => {
    const seq = ++guardianSearchSeq;
    const results = await StudentService.searchGuardians(q);
    // Ignore out-of-order responses from earlier keystrokes.
    if (seq !== guardianSearchSeq) return;
    guardianSuggestions.value = results;
    guardianSearching.value = false;
  }, 250);
}

function pickGuardianSuggestion(name: string) {
  guardianNameDraft.value = name;
  showGuardianSuggestions.value = false;
  applyGuardianFilter();
}

// ── Selection ──────────────────────────────────────────────────────
const selectedIds = ref<Set<string>>(new Set());

// ── Sheet visibility ───────────────────────────────────────────────
const editTarget = ref<Student | null | undefined>(undefined);
const detailTarget = ref<Student | null>(null);
const deleteTarget = ref<Student | null>(null);
const bulkDeleteOpen = ref(false);
const showImport = ref(false);
const isSaving = ref(false);

// Per-facet picker visibility
const showStatusPicker = ref(false);
const showClassPicker = ref(false);
const showGenderPicker = ref(false);
const showGuardianPicker = ref(false);

const state = computed<AsyncState<Student[]>>(() => {
  if (isLoading.value && students.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (students.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: students.value };
});

// ── Facet option lists ─────────────────────────────────────────────
const STATUS_OPTIONS = computed<FacetOption[]>(() => [
  { key: 'active', label: t('status.Active') },
  { key: 'inactive', label: t('status.Inactive') },
  { key: 'unverified', label: t('admin.student.unverified') },
]);
const GENDER_OPTIONS = computed<FacetOption[]>(() => [
  { key: 'L', label: t('admin.gender.male') },
  { key: 'P', label: t('admin.gender.female') },
]);
const classOptions = computed<FacetOption[]>(() =>
  classes.value.map((c) => ({
    key: c.id,
    label: c.name,
    meta: c.grade_level ? `Tingkat ${c.grade_level}` : undefined,
  })),
);

// ── Chip values ─────────────────────────────────────────────────────
const statusChipValue = computed(() => {
  if (!filters.status) return t('common.all');
  return STATUS_OPTIONS.value.find((o) => o.key === filters.status)?.label ?? '—';
});

/**
 * Status chip tone — mirrors mobile, where "Belum verifikasi" gets
 * an amber accent so admins notice the unverified bucket at a
 * glance instead of treating it like another inactive state.
 */
const statusChipTone = computed<
  'green' | 'amber' | 'slate' | 'brand'
>(() => {
  switch (filters.status) {
    case 'unverified': return 'amber';
    case 'inactive':   return 'slate';
    case 'active':     return 'green';
    default:           return 'brand';
  }
});
const classChipValue = computed(() => {
  if (filters.class_ids.length === 0) return t('common.all');
  if (filters.class_ids.length === 1) {
    return classes.value.find((c) => c.id === filters.class_ids[0])?.name ?? '—';
  }
  return `${filters.class_ids.length} ${t('admin.student.classCount')}`;
});
const genderChipValue = computed(() => {
  if (!filters.gender) return t('common.all');
  return filters.gender === 'L' ? t('admin.gender.male') : t('admin.gender.female');
});
const guardianChipValue = computed(() => {
  const v = filters.guardian_name?.trim();
  return v ? v : t('common.all');
});

const activeFilterCount = computed(() => {
  let n = 0;
  if (filters.status) n++;
  if (filters.class_ids.length > 0) n++;
  if (filters.gender) n++;
  if (filters.guardian_name?.trim()) n++;
  return n;
});

// Modal open/close helpers for the guardian-name search input.
function openGuardianPicker() {
  guardianNameDraft.value = filters.guardian_name ?? '';
  guardianSuggestions.value = [];
  guardianSearching.value = false;
  showGuardianSuggestions.value = false;
  showGuardianPicker.value = true;
}
function applyGuardianFilter() {
  const v = guardianNameDraft.value.trim();
  filters.guardian_name = v.length > 0 ? v : null;
  showGuardianSuggestions.value = false;
  showGuardianPicker.value = false;
  reload(1);
}
function clearGuardianFilter() {
  guardianNameDraft.value = '';
  filters.guardian_name = null;
  guardianSuggestions.value = [];
  showGuardianSuggestions.value = false;
  showGuardianPicker.value = false;
  reload(1);
}

// ── Loaders ────────────────────────────────────────────────────────
async function reload(page = 1) {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await StudentService.list({
      page,
      per_page: 10,
      search: search.value || undefined,
      status: filters.status,
      class_ids: filters.class_ids,
      gender: filters.gender,
      guardian_name: filters.guardian_name,
    });
    students.value = res.items;
    pagination.value = res.pagination ?? null;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadClasses() {
  try {
    const res = await ClassroomService.list({ per_page: 200 });
    classes.value = res.items;
  } catch {
    // facet picker handles empty list gracefully
  }
}

onMounted(() => {
  const initialClassId = route.query.class_id;
  if (typeof initialClassId === 'string' && initialClassId) {
    filters.class_ids = [initialClassId];
  }
  loadClasses();
  reload();
});

useAcademicYearWatcher(async () => {
  await loadClasses();
  await reload(1);
});

function onSearch(q: string) {
  search.value = q;
  reload(1);
}

function clearAll() {
  filters.status = null;
  filters.class_ids = [];
  filters.gender = null;
  filters.guardian_name = null;
  guardianNameDraft.value = '';
  search.value = '';
  reload(1);
}

// ── KPI cards ──────────────────────────────────────────────────────
const totalStudents = computed(
  () => pagination.value?.total_items ?? students.value.length,
);

const pageWithGuardian = computed(
  () => students.value.filter((s) => Boolean(s.guardian_name)).length,
);

const pageWithoutGuardian = computed(
  () => students.value.filter((s) => !s.guardian_name).length,
);

const pageFemaleCount = computed(
  () => students.value.filter((s) => s.gender === 'P').length,
);

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'users', label: t('admin.student.totalStudents'), value: totalStudents.value, tone: 'brand' },
  {
    icon: 'check-circle',
    label: t('admin.student.haveGuardian'),
    value: pageWithGuardian.value,
    suffix: t('admin.pagination.perPage'),
    tone: 'green',
  },
  {
    icon: 'alert-triangle',
    label: t('admin.student.noGuardian'),
    value: pageWithoutGuardian.value,
    suffix: t('admin.pagination.perPage'),
    tone: pageWithoutGuardian.value > 0 ? 'amber' : 'slate',
    accented: pageWithoutGuardian.value > 0,
  },
  {
    icon: 'user',
    label: t('admin.gender.female'),
    value: pageFemaleCount.value,
    suffix: t('admin.pagination.perPage'),
    tone: 'violet',
  },
]);

const headerMeta = computed(() =>
  t('admin.student.meta', {
    count: totalStudents.value.toLocaleString(),
    year: ayStore.yearLabel,
  }),
);

// ── Bulk select ──
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
    const res = await StudentService.bulkRemove(ids);
    clearSelection();
    bulkDeleteOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.deleted} siswa terhapus · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = { message: `${res.deleted} siswa terhapus.`, tone: 'success' };
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Detail sheet ──
async function openDetail(s: Student) {
  detailTarget.value = s;
  const fresh = await StudentService.get(s.id);
  if (fresh && detailTarget.value?.id === s.id) {
    detailTarget.value = fresh;
  }
}

const detailSections = computed<DetailSection[]>(() => {
  const s = detailTarget.value;
  if (!s) return [];
  return [
    {
      title: t('admin.sekolah.student_management.section_identity'),
      rows: [
        { label: t('admin.sekolah.student_management.field_name'), value: s.name },
        { label: t('admin.sekolah.student_management.field_nis'), value: s.student_number ?? null },
        {
          label: t('admin.sekolah.student_management.field_gender'),
          value: s.gender === 'L' ? t('admin.sekolah.student_management.gender_male') : s.gender === 'P' ? t('admin.sekolah.student_management.gender_female') : null,
        },
        { label: t('admin.sekolah.student_management.field_dob'), value: s.date_of_birth ?? null },
      ],
    },
    {
      title: t('admin.sekolah.student_management.section_academic'),
      rows: [{ label: t('admin.sekolah.student_management.field_class'), value: s.class_name ?? null }],
    },
    {
      title: t('admin.sekolah.student_management.section_guardian'),
      rows: [
        { label: t('admin.sekolah.student_management.field_guardian_name'), value: s.guardian_name ?? null },
        { label: t('admin.sekolah.student_management.field_guardian_email'), value: s.guardian_email ?? null },
        { label: t('admin.sekolah.student_management.field_phone'), value: s.phone_number ?? null },
        { label: t('admin.sekolah.student_management.field_address'), value: s.address ?? null },
      ],
    },
  ];
});

function detailEdit() {
  if (!detailTarget.value) return;
  const t = detailTarget.value;
  detailTarget.value = null;
  openEdit(t);
}
function detailDelete() {
  if (!detailTarget.value) return;
  deleteTarget.value = detailTarget.value;
  detailTarget.value = null;
}

// ── CRUD ──
function openAdd() {
  editTarget.value = null;
}
function openEdit(s: Student) {
  editTarget.value = s;
}

async function handleSave(payload: Record<string, unknown>) {
  isSaving.value = true;
  try {
    if (editTarget.value && editTarget.value.id) {
      await StudentService.update(editTarget.value.id, payload);
    } else {
      await StudentService.create(payload);
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
    await StudentService.remove(deleteTarget.value.id);
    deleteTarget.value = null;
    await reload(pagination.value?.current_page ?? 1);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Excel ──
async function exportExcel() {
  try {
    await AdminDataExcelService.exportExcel('student');
    toast.value = { message: 'Excel terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
async function downloadTemplate() {
  try {
    await AdminDataExcelService.downloadTemplate('student');
    toast.value = { message: 'Template terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
function onImportDone(res: { imported: number; failed: number }) {
  const note = res.failed > 0 ? ` · ${res.failed} gagal` : '';
  toast.value = {
    message: `${res.imported} siswa diimpor${note}.`,
    tone: 'success',
  };
  reload(1);
}

function topMeta(s: Student): string {
  const cls = s.class_name || '-';
  const nis = s.student_number;
  return nis ? t('admin.student.rowPrefix', { class: cls, nis }) : cls;
}
</script>

<template>
  <AdminCrudScaffold
    :title="t('admin.student.title')"
    :kicker="t('admin.breadcrumb.dataManagement')"
    :meta="headerMeta"
    :kpi-cards="kpiCards"
    :state="state"
    :selected-count="selectedIds.size"
    :active-filter-count="activeFilterCount"
    :hide-add-fab="ayReadOnly"
    :search-placeholder="t('admin.student.searchPlaceholder')"
    :empty-title="t('admin.student.empty')"
    :empty-description="t('admin.student.emptyDescription')"
    :fab-label="t('admin.student.add')"
    @search="onSearch"
    @clear-all-filters="clearAll"
    @add-click="openAdd"
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
        :label="t('admin.student.filterStatus')"
        :value="statusChipValue"
        :tone="statusChipTone"
        @click="showStatusPicker = true"
      />
      <AppFilterChip
        icon-name="layers"
        :label="t('admin.student.filterClass')"
        :value="classChipValue"
        tone="brand"
        @click="showClassPicker = true"
      />
      <AppFilterChip
        icon-name="user"
        :label="t('admin.student.filterGender')"
        :value="genderChipValue"
        tone="violet"
        @click="showGenderPicker = true"
      />
      <AppFilterChip
        icon-name="users"
        :label="t('admin.student.filterGuardian')"
        :value="guardianChipValue"
        tone="amber"
        @click="openGuardianPicker"
      />
    </template>

    <ul class="space-y-2">
      <li v-for="(s, idx) in students" :key="s.id">
        <BrandListRow
          :title="s.name || t('admin.student.noName')"
          :top-meta="topMeta(s)"
          :status="{ tone: 'success', label: t('admin.student.statusActive') }"
          :trailing-action-label="selectedIds.has(s.id) ? '' : t('admin.shared.detail')"
          :trailing-action-color="primaryColor"
          :selected="selectedIds.has(s.id)"
          bulk-selectable
          @click="selectedIds.size > 0 ? toggleSelect(s.id) : openDetail(s)"
          @long-press="toggleSelect(s.id)"
        >
          <template #leading>
            <InitialsAvatar
              :name="s.name || '?'"
              :size="44"
              :color="primaryColor"
              :border-radius="12"
            />
          </template>

          <div
            v-if="selectedIds.size === 0"
            class="mt-2 flex items-center gap-2 text-xs text-slate-500"
          >
            <span class="truncate">{{ s.guardian_name || t('admin.student.guardianNotFilled') }}</span>
            <span v-if="s.phone_number" class="text-slate-300">·</span>
            <span v-if="s.phone_number">{{ s.phone_number }}</span>
            <button
              type="button"
              class="ml-auto text-status-danger hover:underline"
              @click.stop="deleteTarget = s"
            >
              {{ t('common.delete') }}
            </button>
          </div>
        </BrandListRow>
        <span class="hidden">{{ idx }}</span>
      </li>
    </ul>

    <PaginationView
      v-if="pagination && pagination.total_pages > 1"
      :pagination="pagination"
      class="mt-md"
      @change="reload($event)"
    />

    <template #bulk-actions>
      <Button variant="danger" size="sm" @click="bulkDeleteOpen = true">
        {{ t('admin.student.bulkDeleteAction', { count: selectedIds.size }) }}
      </Button>
    </template>
  </AdminCrudScaffold>

  <!-- Per-facet pickers -->
  <FilterFacetPickerModal
    v-if="showStatusPicker"
    :title="t('admin.student.filterStatus')"
    :options="STATUS_OPTIONS"
    :selected="filters.status ?? ''"
    :all-label="t('admin.student.allStatuses')"
    @close="showStatusPicker = false"
    @apply="(v) => { filters.status = (v as 'active' | 'inactive' | 'unverified' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showClassPicker"
    :title="t('admin.student.filterClass')"
    multi
    :options="classOptions"
    :selected-keys="filters.class_ids"
    @close="showClassPicker = false"
    @apply-many="(ids) => { filters.class_ids = ids; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showGenderPicker"
    :title="t('admin.student.filterGender')"
    :options="GENDER_OPTIONS"
    :selected="filters.gender ?? ''"
    :all-label="t('common.all')"
    @close="showGenderPicker = false"
    @apply="(v) => { filters.gender = (v as 'L' | 'P' | '') || null; reload(1); }"
  />
  <!--
    Guardian (wali) name search modal. A type-ahead: the admin types a
    wali's name and matching names are surfaced in a dropdown
    (`GET /student/guardians?search=`, debounced). Picking a suggestion
    applies it immediately; submitting the raw text also works for names
    not yet in the suggestion list. Mirrors the Flutter app's
    `Autocomplete<String>` in the student filter sheet.
  -->
  <Modal
    v-if="showGuardianPicker"
    :title="t('admin.student.searchGuardian')"
    :subtitle="t('admin.student.guardianSearchHint')"
    size="sm"
    @close="showGuardianPicker = false"
  >
    <form class="space-y-4" @submit.prevent="applyGuardianFilter">
      <label class="block">
        <span class="sr-only">{{ t('admin.student.guardianName') }}</span>
        <input
          v-model="guardianNameDraft"
          type="search"
          autofocus
          autocomplete="off"
          :placeholder="t('admin.student.guardianExample')"
          role="combobox"
          aria-expanded="true"
          aria-autocomplete="list"
          class="w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
          @input="onGuardianInput"
          @focus="onGuardianInput"
        />
      </label>

      <!--
        Suggestion dropdown. Rendered inline (not absolutely positioned)
        so the modal's own scroll handles overflow without clipping.
      -->
      <div
        v-if="showGuardianSuggestions && guardianNameDraft.trim().length >= 2"
        class="max-h-56 overflow-y-auto rounded-xl border border-slate-200 bg-white"
      >
        <p
          v-if="guardianSearching"
          class="px-4 py-3 text-sm text-slate-400"
        >
          Mencari…
        </p>
        <ul v-else-if="guardianSuggestions.length > 0" class="divide-y divide-slate-100">
          <li v-for="name in guardianSuggestions" :key="name">
            <button
              type="button"
              class="flex w-full items-center gap-2 px-4 py-2.5 text-left text-sm text-slate-700 hover:bg-slate-50"
              @click="pickGuardianSuggestion(name)"
            >
              <span class="truncate">{{ name }}</span>
            </button>
          </li>
        </ul>
        <p v-else class="px-4 py-3 text-sm text-slate-400">
          Tidak ada wali yang cocok.
        </p>
      </div>

      <div class="flex items-center justify-between gap-3">
        <button
          type="button"
          class="text-[11px] font-black uppercase tracking-wider text-slate-500 hover:text-slate-900"
          @click="clearGuardianFilter"
        >
          {{ t('common.clearFilter') }}
        </button>
        <div class="flex items-center gap-2">
          <Button variant="ghost" type="button" @click="showGuardianPicker = false">
            {{ t('common.cancel') }}
          </Button>
          <Button variant="primary" type="submit">{{ t('common.apply') }}</Button>
        </div>
      </div>
    </form>
  </Modal>

  <!-- Sheets / dialogs -->
  <StudentEditSheet
    v-if="editTarget !== undefined"
    :student="editTarget"
    :classes="classes"
    :primary-color="primaryColor"
    :is-saving="isSaving"
    @close="editTarget = undefined"
    @save="handleSave"
  />

  <ConfirmationDialog
    v-if="deleteTarget"
    :title="t('admin.student.deleteConfirm', { name: deleteTarget.name })"
    :message="t('admin.student.deleteWarning')"
    :confirm-label="t('common.delete')"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <ConfirmationDialog
    v-if="bulkDeleteOpen"
    :title="t('admin.student.bulkDeleteTitle', { count: selectedIds.size })"
    :message="t('admin.student.deleteWarning')"
    :confirm-label="t('admin.student.bulkDeleteConfirm')"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <AdminEntityDetailSheet
    v-if="detailTarget"
    :title="detailTarget.name || t('admin.student.fallbackTitle')"
    :subtitle="detailTarget.class_name ?? null"
    :avatar-name="detailTarget.name"
    :avatar-color="primaryColor"
    :sections="detailSections"
    :status-pill="{ label: t('admin.student.statusActive'), tone: 'green' }"
    :read-only="ayReadOnly"
    @close="detailTarget = null"
    @edit="detailEdit"
    @delete="detailDelete"
  />

  <AdminImportExcelModal
    v-if="showImport"
    entity="student"
    :title="t('admin.student.importTitle')"
    @close="showImport = false"
    @done="onImportDone"
  />

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
