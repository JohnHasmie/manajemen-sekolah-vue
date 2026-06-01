<!--
  AdminSubjectManagementView.vue — admin subject management.

  Uses the shared Jadwal/Keuangan chrome pattern.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef } from 'vue';
import { useRouter } from 'vue-router';
import { SubjectService } from '@/services/subjects.service';
import { AdminDataExcelService } from '@/services/admin-data-excel.service';
import { useRoleHex } from '@/composables/useRoleHex';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import type { Subject } from '@/types/entities';
import type { Pagination } from '@/types/api';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import BrandListRow from '@/components/feature/BrandListRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import PaginationView from '@/components/data/Pagination.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import SubjectEditSheet from './widgets/SubjectEditSheet.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import AdminDataMenu from '@/components/feature/AdminDataMenu.vue';
import AdminImportExcelModal from '@/components/feature/AdminImportExcelModal.vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';

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
const bulkDeleteOpen = ref(false);
const showImport = ref(false);
const isSaving = ref(false);

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
    .map((g) => ({ key: g, label: `Tingkat ${g}` }));
});

const STATUS_OPTIONS: FacetOption[] = [
  { key: 'active', label: 'Aktif' },
  { key: 'inactive', label: 'Nonaktif' },
];
const CLASSES_OPTIONS: FacetOption[] = [
  { key: 'with', label: 'Sudah tertaut' },
  { key: 'without', label: 'Belum tertaut' },
];

const statusChipValue = computed(() => {
  if (!filters.status) return 'Semua';
  return filters.status === 'active' ? 'Aktif' : 'Nonaktif';
});
const gradeChipValue = computed(() => {
  if (!filters.grade_level) return 'Semua';
  return `Tingkat ${filters.grade_level}`;
});
const classesChipValue = computed(() => {
  if (!filters.classes_status) return 'Semua';
  return filters.classes_status === 'with' ? 'Sudah tertaut' : 'Belum tertaut';
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
  { icon: 'book-open', label: 'Total Mapel', value: totalSubjects.value, tone: 'brand' },
  {
    icon: 'check-circle',
    label: 'Aktif',
    value: pageActiveCount.value,
    suffix: '/halaman',
    tone: 'green',
  },
  {
    icon: 'archive',
    label: 'Nonaktif',
    value: pageInactiveCount.value,
    suffix: '/halaman',
    tone: pageInactiveCount.value > 0 ? 'amber' : 'slate',
  },
  {
    icon: 'layers',
    label: 'Tertaut Kelas',
    value: pageWithClassesCount.value,
    suffix: '/halaman',
    tone: 'violet',
  },
]);

const headerMeta = computed(
  () => `${totalSubjects.value.toLocaleString('id-ID')} mata pelajaran · TP ${ayStore.yearLabel}`,
);

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
    toast.value = { message: 'Template terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
function onImportDone(res: { imported: number; failed: number }) {
  const note = res.failed > 0 ? ` · ${res.failed} gagal` : '';
  toast.value = {
    message: `${res.imported} mapel diimpor${note}.`,
    tone: 'success',
  };
  reload(1);
}

function statusFor(s: Subject) {
  if (s.is_active === false) {
    return { tone: 'warning' as const, label: 'Nonaktif' };
  }
  if (s.kkm !== null && s.kkm !== undefined) {
    return { tone: 'info' as const, label: `KKM: ${s.kkm}` };
  }
  return { tone: 'success' as const, label: 'Aktif' };
}

function topMeta(s: Subject): string {
  const parts: string[] = [];
  if (s.code) parts.push(`Kode ${s.code}`);
  if (s.class_count !== undefined && s.class_count > 0) parts.push(`${s.class_count} kelas`);
  return parts.join(' · ') || '—';
}
</script>

<template>
  <AdminCrudScaffold
    title="Mata Pelajaran"
    kicker="Admin · Manajemen Data"
    :meta="headerMeta"
    :kpi-cards="kpiCards"
    :state="state"
    :selected-count="selectedIds.size"
    :active-filter-count="activeFilterCount"
    :hide-add-fab="ayReadOnly"
    search-placeholder="Cari mata pelajaran..."
    empty-title="Belum ada mata pelajaran"
    empty-description="Tap tombol + untuk menambahkan mata pelajaran baru."
    fab-label="Tambah Mapel"
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
        label="Status"
        :value="statusChipValue"
        tone="green"
        @click="showStatusPicker = true"
      />
      <AppFilterChip
        v-if="gradeLevelOptions.length > 0"
        icon-name="bar-chart"
        label="Tingkat"
        :value="gradeChipValue"
        tone="brand"
        @click="showGradePicker = true"
      />
      <AppFilterChip
        icon-name="layers"
        label="Tertaut Kelas"
        :value="classesChipValue"
        tone="violet"
        @click="showClassesPicker = true"
      />
    </template>

    <ul class="grid grid-cols-1 sm:grid-cols-2 gap-2">
      <li v-for="s in filteredSubjects" :key="s.id">
        <BrandListRow
          :title="s.name"
          :top-meta="topMeta(s)"
          :status="statusFor(s)"
          :trailing-action-label="selectedIds.has(s.id) ? '' : 'Kelas'"
          :trailing-action-color="primaryColor"
          :selected="selectedIds.has(s.id)"
          bulk-selectable
          @click="selectedIds.size > 0 ? toggleSelect(s.id) : openSubjectClasses(s)"
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
            class="mt-2 flex justify-end gap-2 text-xs"
          >
            <button
              type="button"
              class="text-slate-500 hover:text-role-admin"
              @click.stop="editTarget = s"
            >
              Edit
            </button>
            <button
              type="button"
              class="text-status-danger hover:underline"
              @click.stop="deleteTarget = s"
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

  <!-- Per-facet pickers -->
  <FilterFacetPickerModal
    v-if="showStatusPicker"
    title="Filter Status"
    :options="STATUS_OPTIONS"
    :selected="filters.status ?? ''"
    @close="showStatusPicker = false"
    @apply="(v) => { filters.status = (v as 'active' | 'inactive' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showGradePicker"
    title="Filter Tingkat"
    :options="gradeLevelOptions"
    :selected="filters.grade_level ?? ''"
    @close="showGradePicker = false"
    @apply="(v) => { filters.grade_level = v || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showClassesPicker"
    title="Filter Status Tertaut"
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
    :title="`Hapus ${deleteTarget.name}?`"
    message="Tindakan ini akan menonaktifkan mata pelajaran. Pastikan tidak ada jadwal atau nilai yang masih merujuk ke mata pelajaran ini."
    confirm-label="Hapus"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <ConfirmationDialog
    v-if="bulkDeleteOpen"
    :title="`Hapus ${selectedIds.size} mata pelajaran?`"
    message="Tindakan ini akan menonaktifkan mapel terpilih. Tidak dapat dibatalkan."
    confirm-label="Hapus semua"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <AdminImportExcelModal
    v-if="showImport"
    entity="subject"
    title="Import Mata Pelajaran dari Excel"
    @close="showImport = false"
    @done="onImportDone"
  />

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
