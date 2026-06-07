<!--
  AdminClassroomManagementView.vue — admin classroom management.

  Uses the shared Jadwal/Keuangan chrome pattern.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { ClassroomService } from '@/services/classrooms.service';
import { SettingsService } from '@/services/settings.service';
import { TeacherService } from '@/services/teachers.service';
import { AdminDataExcelService } from '@/services/admin-data-excel.service';
import { useRoleHex } from '@/composables/useRoleHex';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import type { Classroom, Teacher } from '@/types/entities';
import type { Pagination } from '@/types/api';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import BrandListRow from '@/components/feature/BrandListRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import PaginationView from '@/components/data/Pagination.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import ClassroomEditSheet from './widgets/ClassroomEditSheet.vue';
import ClassPromotionWizard from './widgets/ClassPromotionWizard.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import AdminDataMenu from '@/components/feature/AdminDataMenu.vue';
import AdminEntityDetailSheet, {
  type DetailSection,
} from '@/components/feature/AdminEntityDetailSheet.vue';
import AdminImportExcelModal from '@/components/feature/AdminImportExcelModal.vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';

// Aliased to `$t` to avoid collision with `v-for="c in classes"` style
// iterators in the template — though here the v-for variable is `c`,
// keeping the alias is consistent with the other admin management views.
const { t: $t } = useI18n();
const primaryColor = useRoleHex();
const ayStore = useAcademicYearStore();
const ayReadOnly = computed(() => ayStore.isReadOnly);

const classrooms = shallowRef<Classroom[]>([]);
const teachers = shallowRef<Teacher[]>([]);
/**
 * Active school's jenjang (`schools.education_level`), loaded once from
 * GET /school/settings. Drives the tingkat dropdown in the edit sheet
 * (SD→1-6, SMP→7-9, SMA/SMK→10-12). Mirrors Flutter's
 * `_loadSchoolSettings()` in `admin_classroom_management_screen.dart`.
 */
const educationLevel = ref<string | null>(null);
const pagination = ref<Pagination | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const search = ref('');
const filters = reactive<{
  grade_level: string | null;
  has_homeroom: 'yes' | 'no' | null;
}>({
  grade_level: null,
  has_homeroom: null,
});
const selectedIds = ref<Set<string>>(new Set());

const editTarget = ref<Classroom | null | undefined>(undefined);
const detailTarget = ref<Classroom | null>(null);
const showFab = ref(false);
const showImport = ref(false);
const showWizard = ref(false);
const deleteTarget = ref<Classroom | null>(null);
const bulkDeleteOpen = ref(false);
const isSaving = ref(false);

const showGradePicker = ref(false);
const showHomeroomPicker = ref(false);

const state = computed<AsyncState<Classroom[]>>(() => {
  if (isLoading.value && classrooms.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (classrooms.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: classrooms.value };
});

const gradeLevelOptions = computed<FacetOption[]>(() => {
  const set = new Set<string>();
  for (const c of classrooms.value) {
    if (c.grade_level) set.add(String(c.grade_level));
  }
  return Array.from(set)
    .sort((a, b) => {
      const na = Number(a); const nb = Number(b);
      if (Number.isFinite(na) && Number.isFinite(nb)) return na - nb;
      return a.localeCompare(b);
    })
    .map((g) => ({ key: g, label: `Tingkat ${g}` }));
});

const HOMEROOM_OPTIONS: FacetOption[] = [
  { key: 'yes', label: 'Sudah ada wali' },
  { key: 'no', label: 'Belum ada wali' },
];

const gradeChipValue = computed(() => {
  if (!filters.grade_level) return $t('admin.shared.allFilter');
  return $t('admin.classes.gradePrefix', { grade: filters.grade_level });
});
const homeroomChipValue = computed(() => {
  if (!filters.has_homeroom) return $t('admin.shared.allFilter');
  return filters.has_homeroom === 'yes'
    ? $t('admin.classes.hasHomeroom')
    : $t('admin.classes.noHomeroomFilter');
});

const activeFilterCount = computed(() => {
  let n = 0;
  if (filters.grade_level) n++;
  if (filters.has_homeroom) n++;
  return n;
});

async function reload(page = 1) {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await ClassroomService.list({
      page,
      per_page: 10,
      search: search.value || undefined,
      grade_level: filters.grade_level ?? undefined,
      has_homeroom: filters.has_homeroom ?? undefined,
    });
    classrooms.value = res.items;
    pagination.value = res.pagination ?? null;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadTeachers() {
  try {
    const res = await TeacherService.list({ per_page: 100 });
    teachers.value = res.items;
  } catch {
    // sheets handle empty refs gracefully
  }
}

async function loadSchoolSettings() {
  try {
    const school = await SettingsService.getSchool();
    educationLevel.value = school.education_level || null;
  } catch {
    // edit sheet falls back to the full 1-12 range if this fails
  }
}

onMounted(() => {
  loadSchoolSettings();
  loadTeachers();
  reload();
});

useAcademicYearWatcher(async () => {
  await loadTeachers();
  await reload(1);
});

function onSearch(q: string) {
  search.value = q;
  reload(1);
}

function clearAll() {
  filters.grade_level = null;
  filters.has_homeroom = null;
  search.value = '';
  reload(1);
}

// ── KPI ──
const totalClasses = computed(
  () => pagination.value?.total_items ?? classrooms.value.length,
);
const pageWithWali = computed(
  () => classrooms.value.filter((c) => Boolean(c.homeroom_teacher_name)).length,
);
const pageWithoutWali = computed(
  () => classrooms.value.filter((c) => !c.homeroom_teacher_name).length,
);
const pageStudentCount = computed(
  () => classrooms.value.reduce((s, c) => s + (c.student_count ?? 0), 0),
);

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'layers', label: $t('admin.classes.kpiTotal'), value: totalClasses.value, tone: 'brand' },
  {
    icon: 'check-circle',
    label: $t('admin.classes.kpiHasHomeroom'),
    value: pageWithWali.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'green',
  },
  {
    icon: 'alert-triangle',
    label: $t('admin.classes.kpiNoHomeroom'),
    value: pageWithoutWali.value,
    suffix: $t('admin.shared.perPage'),
    tone: pageWithoutWali.value > 0 ? 'amber' : 'slate',
    accented: pageWithoutWali.value > 0,
  },
  {
    icon: 'users',
    label: $t('admin.classes.kpiTotalStudents'),
    value: pageStudentCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'violet',
  },
]);

const headerMeta = computed(() =>
  $t('admin.classes.meta', {
    count: totalClasses.value.toLocaleString(),
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
    const res = await ClassroomService.bulkRemove(ids);
    clearSelection();
    bulkDeleteOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.deleted} kelas terhapus · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = { message: `${res.deleted} kelas terhapus.`, tone: 'success' };
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Detail ──
async function openDetail(c: Classroom) {
  detailTarget.value = c;
  const fresh = await ClassroomService.get(c.id);
  if (fresh && detailTarget.value?.id === c.id) {
    detailTarget.value = fresh;
  }
}

const detailSections = computed<DetailSection[]>(() => {
  const c = detailTarget.value;
  if (!c) return [];
  return [
    {
      title: 'Identitas',
      rows: [
        { label: 'Nama kelas', value: c.name },
        { label: 'Tingkat', value: c.grade_level ?? null },
        { label: 'Jumlah siswa', value: `${c.student_count} siswa` },
      ],
    },
    {
      title: 'Wali Kelas',
      rows: [
        { label: 'Nama wali', value: c.homeroom_teacher_name ?? null },
      ],
    },
  ];
});

function detailEdit() {
  if (!detailTarget.value) return;
  openEdit(detailTarget.value);
}
function detailDelete() {
  if (!detailTarget.value) return;
  deleteTarget.value = detailTarget.value;
  detailTarget.value = null;
}

async function openEdit(c: Classroom) {
  detailTarget.value = null;
  const fresh = await ClassroomService.get(c.id);
  editTarget.value = fresh ?? c;
}

async function handleSave(payload: Record<string, unknown>) {
  isSaving.value = true;
  try {
    if (editTarget.value && editTarget.value.id) {
      await ClassroomService.update(editTarget.value.id, payload);
    } else {
      await ClassroomService.create(payload);
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
    await ClassroomService.remove(deleteTarget.value.id);
    deleteTarget.value = null;
    await reload(pagination.value?.current_page ?? 1);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Wizard ──
function onPromoted(res: { promoted: number; failed: number }) {
  const note = res.failed > 0 ? ` · ${res.failed} gagal` : '';
  toast.value = {
    message: `${res.promoted} siswa dipromosikan${note}.`,
    tone: 'success',
  };
  reload(pagination.value?.current_page ?? 1);
}

// ── Excel ──
async function exportExcel() {
  try {
    await AdminDataExcelService.exportExcel('class');
    toast.value = { message: 'Excel terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
async function downloadTemplate() {
  try {
    await AdminDataExcelService.downloadTemplate('class');
    toast.value = { message: 'Template terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
function onImportDone(res: { imported: number; failed: number }) {
  const note = res.failed > 0 ? ` · ${res.failed} gagal` : '';
  toast.value = {
    message: `${res.imported} kelas diimpor${note}.`,
    tone: 'success',
  };
  reload(1);
}

function topMeta(c: Classroom): string {
  const level = $t('admin.classes.gradePrefix', { grade: c.grade_level ?? '-' });
  return `${level} · ${$t('admin.classes.studentCount', { count: c.student_count })}`;
}

function statusFor(c: Classroom) {
  if (c.homeroom_teacher_name) {
    return {
      tone: 'success' as const,
      label: `${$t('admin.classes.waliPrefix')} ${c.homeroom_teacher_name}`,
    };
  }
  return { tone: 'warning' as const, label: $t('admin.classes.statusNoHomeroom') };
}
</script>

<template>
  <AdminCrudScaffold
    :title="$t('admin.classes.title')"
    :kicker="$t('admin.shared.kicker')"
    :meta="headerMeta"
    :kpi-cards="kpiCards"
    :state="state"
    :selected-count="selectedIds.size"
    :active-filter-count="activeFilterCount"
    :hide-add-fab="true"
    :search-placeholder="$t('admin.classes.searchPlaceholder')"
    :empty-title="$t('admin.classes.emptyTitle')"
    :empty-description="$t('admin.classes.emptyDesc')"
    :fab-label="$t('admin.classes.addFab')"
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
        icon-name="bar-chart"
        :label="$t('admin.classes.filterGrade')"
        :value="gradeChipValue"
        tone="brand"
        @click="showGradePicker = true"
      />
      <AppFilterChip
        icon-name="shield"
        :label="$t('admin.classes.filterHomeroom')"
        :value="homeroomChipValue"
        tone="amber"
        @click="showHomeroomPicker = true"
      />
    </template>

    <ul class="space-y-2">
      <li v-for="c in classrooms" :key="c.id">
        <BrandListRow
          :title="c.name"
          :top-meta="topMeta(c)"
          :status="statusFor(c)"
          :trailing-action-label="selectedIds.has(c.id) ? '' : $t('admin.shared.detail')"
          :trailing-action-color="primaryColor"
          :selected="selectedIds.has(c.id)"
          bulk-selectable
          @click="selectedIds.size > 0 ? toggleSelect(c.id) : openDetail(c)"
          @long-press="toggleSelect(c.id)"
        >
          <template #leading>
            <InitialsAvatar
              :name="c.name || '?'"
              :size="44"
              :color="primaryColor"
              :border-radius="12"
            />
          </template>
          <div
            v-if="selectedIds.size === 0"
            class="mt-2 flex justify-end gap-2 text-xs"
          >
            <button
              type="button"
              class="text-status-danger hover:underline"
              @click.stop="deleteTarget = c"
            >
              Hapus
            </button>
          </div>
        </BrandListRow>
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
        Hapus ({{ selectedIds.size }})
      </Button>
    </template>
  </AdminCrudScaffold>

  <!-- Speed-dial FAB (Tambah / Promosi) — replaces default + FAB -->
  <div
    v-if="!ayReadOnly"
    class="fixed bottom-6 right-6 z-30 flex flex-col items-end gap-2"
  >
    <Transition name="fade">
      <div v-if="showFab" class="flex flex-col gap-2 mb-1">
        <button
          type="button"
          class="inline-flex items-center gap-2 px-3 py-2 rounded-full bg-white border border-slate-200 shadow-md text-[11px] font-bold text-slate-700 hover:border-role-admin/40"
          @click="showWizard = true; showFab = false"
        >
          <NavIcon name="users" :size="12" class="text-role-admin" />
          Promosi Kelas
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-2 px-3 py-2 rounded-full bg-white border border-slate-200 shadow-md text-[11px] font-bold text-slate-700 hover:border-role-admin/40"
          @click="editTarget = null; showFab = false"
        >
          <NavIcon name="plus" :size="12" class="text-role-admin" />
          Tambah Kelas
        </button>
      </div>
    </Transition>
    <button
      type="button"
      class="rounded-full text-white shadow-card flex items-center justify-center w-12 h-12 transition-transform hover:scale-105"
      :style="{ backgroundColor: primaryColor }"
      @click="showFab = !showFab"
    >
      <NavIcon :name="showFab ? 'x' : 'plus'" :size="18" />
    </button>
  </div>

  <!-- Per-facet pickers -->
  <FilterFacetPickerModal
    v-if="showGradePicker"
    title="Filter Tingkat"
    :options="gradeLevelOptions"
    :selected="filters.grade_level ?? ''"
    @close="showGradePicker = false"
    @apply="(v) => { filters.grade_level = v || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showHomeroomPicker"
    title="Filter Status Wali Kelas"
    :options="HOMEROOM_OPTIONS"
    :selected="filters.has_homeroom ?? ''"
    @close="showHomeroomPicker = false"
    @apply="(v) => { filters.has_homeroom = (v as 'yes' | 'no' | '') || null; reload(1); }"
  />

  <ClassroomEditSheet
    v-if="editTarget !== undefined"
    :classroom="editTarget"
    :teachers="teachers"
    :is-saving="isSaving"
    :education-level="educationLevel"
    @close="editTarget = undefined"
    @save="handleSave"
  />

  <AdminEntityDetailSheet
    v-if="detailTarget"
    :title="detailTarget.name"
    :subtitle="detailTarget.grade_level ? `Tingkat ${detailTarget.grade_level}` : null"
    :avatar-name="detailTarget.name"
    :avatar-color="primaryColor"
    :sections="detailSections"
    :status-pill="
      detailTarget.homeroom_teacher_name
        ? { label: 'Wali kelas terdaftar', tone: 'green' }
        : { label: 'Belum ada wali', tone: 'amber' }
    "
    :read-only="ayReadOnly"
    @close="detailTarget = null"
    @edit="detailEdit"
    @delete="detailDelete"
  />

  <ClassPromotionWizard
    v-if="showWizard"
    @close="showWizard = false"
    @done="onPromoted"
  />

  <ConfirmationDialog
    v-if="deleteTarget"
    :title="`Hapus kelas ${deleteTarget.name}?`"
    message="Pastikan kelas ini tidak memiliki siswa atau jadwal aktif. Tindakan ini tidak dapat dibatalkan."
    confirm-label="Hapus"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <ConfirmationDialog
    v-if="bulkDeleteOpen"
    :title="`Hapus ${selectedIds.size} kelas?`"
    message="Tindakan ini tidak dapat dibatalkan. Pastikan tidak ada siswa/jadwal aktif."
    confirm-label="Hapus semua"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <AdminImportExcelModal
    v-if="showImport"
    entity="class"
    title="Import Kelas dari Excel"
    @close="showImport = false"
    @done="onImportDone"
  />

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>

<style scoped>
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s, transform 0.2s;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
  transform: translateY(6px);
}
</style>
