<!--
  AdminTeacherManagementView.vue — admin teacher management.

  Uses the shared Jadwal/Keuangan chrome pattern: gradient
  BrandPageHeader + KpiStripCards + PageFilterToolbar with per-facet
  AppFilterChip buttons.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef } from 'vue';
import { TeacherService, type TeacherFilterOptions } from '@/services/teachers.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { AdminDataExcelService } from '@/services/admin-data-excel.service';
import { useRoleHex } from '@/composables/useRoleHex';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import type { Teacher, Classroom, Subject } from '@/types/entities';
import type { Pagination } from '@/types/api';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import BrandListRow from '@/components/feature/BrandListRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import PaginationView from '@/components/data/Pagination.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import TeacherEditSheet from './widgets/TeacherEditSheet.vue';
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

const primaryColor = useRoleHex();
const ayStore = useAcademicYearStore();
const ayReadOnly = computed(() => ayStore.isReadOnly);

const teachers = shallowRef<Teacher[]>([]);
const classes = shallowRef<Classroom[]>([]);
const subjects = shallowRef<Subject[]>([]);
const filterOptions = shallowRef<TeacherFilterOptions>({
  roles: [{ key: 'guru', label: 'Guru' }, { key: 'wali_kelas', label: 'Wali Kelas' }],
  genders: [{ key: 'L', label: 'Laki-laki' }, { key: 'P', label: 'Perempuan' }],
  employment_statuses: [
    { key: 'tetap', label: 'Tetap' },
    { key: 'tidak_tetap', label: 'Tidak Tetap' },
    { key: 'kontrak', label: 'Kontrak' },
    { key: 'honorer', label: 'Honorer' },
  ],
  classes: [],
  subjects: [],
});
const pagination = ref<Pagination | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const search = ref('');
const filters = reactive<{
  role: 'guru' | 'wali_kelas' | null;
  class_id: string | null;
  gender: 'L' | 'P' | null;
  employment_status: string | null;
  show_all: boolean;
}>({
  role: null,
  class_id: null,
  gender: null,
  employment_status: null,
  show_all: false,
});
const selectedIds = ref<Set<string>>(new Set());

const editTarget = ref<Teacher | null | undefined>(undefined);
const detailTarget = ref<Teacher | null>(null);
const showImport = ref(false);
const deleteTarget = ref<Teacher | null>(null);
const bulkDeleteOpen = ref(false);
const isSaving = ref(false);

// Picker visibility
const showRolePicker = ref(false);
const showClassPicker = ref(false);
const showGenderPicker = ref(false);
const showEmploymentPicker = ref(false);

const state = computed<AsyncState<Teacher[]>>(() => {
  if (isLoading.value && teachers.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (teachers.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: teachers.value };
});

// ── Facet options ──────────────────────────────────────────────────
const roleOptions = computed<FacetOption[]>(() =>
  filterOptions.value.roles.map((r) => ({ key: r.key, label: r.label })),
);
const classOptions = computed<FacetOption[]>(() =>
  (filterOptions.value.classes.length > 0
    ? filterOptions.value.classes
    : classes.value
  ).map((c) => ({ key: c.id, label: c.name })),
);
const genderOptions = computed<FacetOption[]>(() =>
  filterOptions.value.genders.map((g) => ({ key: g.key, label: g.label })),
);
const employmentOptions = computed<FacetOption[]>(() =>
  filterOptions.value.employment_statuses.map((es) => ({
    key: es.key,
    label: es.label,
  })),
);

// ── Chip display values ────────────────────────────────────────────
const roleChipValue = computed(() => {
  if (!filters.role) return 'Semua';
  return filterOptions.value.roles.find((r) => r.key === filters.role)?.label ?? '—';
});
const classChipValue = computed(() => {
  if (!filters.class_id) return 'Semua';
  const fromFilterOpts = filterOptions.value.classes.find((c) => c.id === filters.class_id);
  if (fromFilterOpts) return fromFilterOpts.name;
  return classes.value.find((c) => c.id === filters.class_id)?.name ?? '—';
});
const genderChipValue = computed(() => {
  if (!filters.gender) return 'Semua';
  return filters.gender === 'L' ? 'Laki-laki' : 'Perempuan';
});
const employmentChipValue = computed(() => {
  if (!filters.employment_status) return 'Semua';
  return (
    filterOptions.value.employment_statuses.find((es) => es.key === filters.employment_status)
      ?.label ?? '—'
  );
});

const activeFilterCount = computed(() => {
  let n = 0;
  if (filters.role) n++;
  if (filters.class_id) n++;
  if (filters.gender) n++;
  if (filters.employment_status) n++;
  if (filters.show_all) n++;
  return n;
});

async function reload(page = 1) {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await TeacherService.list({
      page,
      per_page: 10,
      search: search.value || undefined,
      role: filters.role ?? undefined,
      class_id: filters.class_id ?? undefined,
      gender: filters.gender ?? undefined,
      employment_status: filters.employment_status ?? undefined,
      show_all: filters.show_all || undefined,
    });
    teachers.value = res.items;
    pagination.value = res.pagination ?? null;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadReferences() {
  try {
    const [c, s, opts] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
      TeacherService.getFilterOptions(),
    ]);
    classes.value = c.items;
    subjects.value = s.items;
    if (opts.classes.length === 0) {
      opts.classes = c.items.map((x) => ({ id: x.id, name: x.name }));
    }
    filterOptions.value = opts;
  } catch {
    // sheets handle empty refs gracefully
  }
}

onMounted(() => {
  loadReferences();
  reload();
});

useAcademicYearWatcher(async () => {
  await loadReferences();
  await reload(1);
});

function onSearch(q: string) {
  search.value = q;
  reload(1);
}

function clearAll() {
  filters.role = null;
  filters.class_id = null;
  filters.gender = null;
  filters.employment_status = null;
  filters.show_all = false;
  search.value = '';
  reload(1);
}

// ── KPI cards ──────────────────────────────────────────────────────
const totalTeachers = computed(
  () => pagination.value?.total_items ?? teachers.value.length,
);
const pageWaliCount = computed(
  () => teachers.value.filter((t) => Boolean(t.homeroom_class_name)).length,
);
const pageWithSubjectsCount = computed(
  () => teachers.value.filter((t) => (t.subject_names?.length ?? 0) > 0).length,
);
const pageFemaleCount = computed(
  () => teachers.value.filter((t) => t.gender === 'P').length,
);

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'users', label: 'Total Guru', value: totalTeachers.value, tone: 'brand' },
  {
    icon: 'shield',
    label: 'Wali Kelas',
    value: pageWaliCount.value,
    suffix: '/halaman',
    tone: 'violet',
  },
  {
    icon: 'book-open',
    label: 'Punya Mapel',
    value: pageWithSubjectsCount.value,
    suffix: '/halaman',
    tone: 'green',
  },
  {
    icon: 'user',
    label: 'Perempuan',
    value: pageFemaleCount.value,
    suffix: '/halaman',
    tone: 'amber',
  },
]);

const headerMeta = computed(() => {
  return `${totalTeachers.value.toLocaleString('id-ID')} guru terdaftar · TP ${ayStore.yearLabel}`;
});

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
    const res = await TeacherService.bulkRemove(ids);
    clearSelection();
    bulkDeleteOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.deleted} guru terhapus · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = { message: `${res.deleted} guru terhapus.`, tone: 'success' };
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

// ── Detail ──
async function openDetail(t: Teacher) {
  detailTarget.value = t;
  const fresh = await TeacherService.get(t.id);
  if (fresh && detailTarget.value?.id === t.id) {
    detailTarget.value = fresh;
  }
}

const detailSections = computed<DetailSection[]>(() => {
  const t = detailTarget.value;
  if (!t) return [];
  const employmentLabel =
    filterOptions.value.employment_statuses.find(
      (es) => es.key === t.employment_status,
    )?.label ?? t.employment_status ?? null;
  return [
    {
      title: 'Identitas',
      rows: [
        { label: 'Nama lengkap', value: t.name },
        { label: 'Email', value: t.email },
        { label: 'NIP', value: t.employee_number ?? null },
        {
          label: 'Jenis kelamin',
          value: t.gender === 'L' ? 'Laki-laki' : t.gender === 'P' ? 'Perempuan' : null,
        },
        { label: 'No. HP', value: t.phone_number ?? null },
        { label: 'Alamat', value: t.address ?? null },
      ],
    },
    {
      title: 'Penugasan',
      rows: [
        { label: 'Peran', value: t.role === 'wali_kelas' ? 'Wali Kelas' : 'Guru' },
        { label: 'Status kepegawaian', value: employmentLabel },
        { label: 'Mata pelajaran', value: t.subject_names?.join(', ') || null },
        {
          label: 'Wali kelas',
          value:
            t.homeroom_class_names?.join(', ') ||
            t.homeroom_class_name ||
            null,
        },
      ],
    },
  ];
});

function detailEdit() {
  if (!detailTarget.value) return;
  const t = detailTarget.value;
  detailTarget.value = null;
  editTarget.value = t;
}
function detailDelete() {
  if (!detailTarget.value) return;
  deleteTarget.value = detailTarget.value;
  detailTarget.value = null;
}

async function handleSave(payload: Record<string, unknown>) {
  isSaving.value = true;
  try {
    if (editTarget.value && editTarget.value.id) {
      await TeacherService.update(editTarget.value.id, payload);
    } else {
      await TeacherService.create(payload);
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
    await TeacherService.remove(deleteTarget.value.id);
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
    await AdminDataExcelService.exportExcel('teacher');
    toast.value = { message: 'Excel terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
async function downloadTemplate() {
  try {
    await AdminDataExcelService.downloadTemplate('teacher');
    toast.value = { message: 'Template terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}
function onImportDone(res: { imported: number; failed: number }) {
  const note = res.failed > 0 ? ` · ${res.failed} gagal` : '';
  toast.value = {
    message: `${res.imported} guru diimpor${note}.`,
    tone: 'success',
  };
  reload(1);
}

function topMeta(t: Teacher): string {
  const role = t.role === 'wali_kelas' ? 'Wali Kelas' : 'Guru';
  const nip = t.employee_number;
  return nip ? `${role} · NIP ${nip}` : role;
}

function statusFor(t: Teacher) {
  if (t.homeroom_class_name) {
    return {
      tone: 'info' as const,
      label: `Wali ${t.homeroom_class_name}`,
    };
  }
  return { tone: 'success' as const, label: 'Aktif' };
}
</script>

<template>
  <AdminCrudScaffold
    title="Manajemen Guru"
    kicker="Admin · Manajemen Data"
    :meta="headerMeta"
    :kpi-cards="kpiCards"
    :state="state"
    :selected-count="selectedIds.size"
    :active-filter-count="activeFilterCount"
    :hide-add-fab="ayReadOnly"
    search-placeholder="Cari nama guru atau NIP..."
    empty-title="Belum ada guru"
    empty-description="Tap tombol + untuk menambahkan guru baru."
    fab-label="Tambah Guru"
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
        icon-name="shield"
        label="Peran"
        :value="roleChipValue"
        tone="violet"
        @click="showRolePicker = true"
      />
      <AppFilterChip
        icon-name="layers"
        label="Kelas"
        :value="classChipValue"
        tone="brand"
        @click="showClassPicker = true"
      />
      <AppFilterChip
        icon-name="user"
        label="Gender"
        :value="genderChipValue"
        tone="amber"
        @click="showGenderPicker = true"
      />
      <AppFilterChip
        icon-name="briefcase"
        label="Kepegawaian"
        :value="employmentChipValue"
        tone="green"
        @click="showEmploymentPicker = true"
      />
      <button
        type="button"
        class="text-[11px] font-bold px-3 py-1.5 rounded-lg border transition-colors"
        :class="
          filters.show_all
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
        "
        @click="filters.show_all = !filters.show_all; reload(1)"
      >
        Semua guru
      </button>
    </template>

    <ul class="space-y-2">
      <li v-for="t in teachers" :key="t.id">
        <BrandListRow
          :title="t.name || 'Tanpa nama'"
          :top-meta="topMeta(t)"
          :status="statusFor(t)"
          :trailing-action-label="selectedIds.has(t.id) ? '' : 'Detail'"
          :trailing-action-color="primaryColor"
          :selected="selectedIds.has(t.id)"
          bulk-selectable
          @click="selectedIds.size > 0 ? toggleSelect(t.id) : openDetail(t)"
          @long-press="toggleSelect(t.id)"
        >
          <template #leading>
            <InitialsAvatar
              :name="t.name || '?'"
              :size="44"
              :color="primaryColor"
              :border-radius="12"
            />
          </template>
          <div
            v-if="selectedIds.size === 0"
            class="mt-2 flex items-center gap-2 text-xs text-slate-500"
          >
            <span class="truncate flex-1">
              {{ t.subject_names?.length ? t.subject_names.join(', ') : 'Belum ada mata pelajaran' }}
            </span>
            <button
              type="button"
              class="text-status-danger hover:underline"
              @click.stop="deleteTarget = t"
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
    v-if="showRolePicker"
    title="Filter Peran"
    :options="roleOptions"
    :selected="filters.role ?? ''"
    @close="showRolePicker = false"
    @apply="(v) => { filters.role = (v as 'guru' | 'wali_kelas' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showClassPicker"
    title="Filter Kelas Mengajar"
    :options="classOptions"
    :selected="filters.class_id ?? ''"
    @close="showClassPicker = false"
    @apply="(v) => { filters.class_id = v || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showGenderPicker"
    title="Filter Jenis Kelamin"
    :options="genderOptions"
    :selected="filters.gender ?? ''"
    @close="showGenderPicker = false"
    @apply="(v) => { filters.gender = (v as 'L' | 'P' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showEmploymentPicker"
    title="Filter Status Kepegawaian"
    :options="employmentOptions"
    :selected="filters.employment_status ?? ''"
    @close="showEmploymentPicker = false"
    @apply="(v) => { filters.employment_status = v || null; reload(1); }"
  />

  <TeacherEditSheet
    v-if="editTarget !== undefined"
    :teacher="editTarget"
    :classes="classes"
    :subjects="subjects"
    :is-saving="isSaving"
    @close="editTarget = undefined"
    @save="handleSave"
  />

  <AdminEntityDetailSheet
    v-if="detailTarget"
    :title="detailTarget.name || 'Guru'"
    :subtitle="detailTarget.role === 'wali_kelas' ? 'Wali Kelas' : 'Guru'"
    :avatar-name="detailTarget.name"
    :avatar-color="primaryColor"
    :sections="detailSections"
    :read-only="ayReadOnly"
    @close="detailTarget = null"
    @edit="detailEdit"
    @delete="detailDelete"
  />

  <ConfirmationDialog
    v-if="deleteTarget"
    :title="`Hapus ${deleteTarget.name}?`"
    message="Tindakan ini tidak dapat dibatalkan. Akun guru akan dinonaktifkan dan tidak bisa masuk lagi."
    confirm-label="Hapus"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <ConfirmationDialog
    v-if="bulkDeleteOpen"
    :title="`Hapus ${selectedIds.size} guru?`"
    message="Tindakan ini tidak dapat dibatalkan. Akun guru terpilih akan dinonaktifkan."
    confirm-label="Hapus semua"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <AdminImportExcelModal
    v-if="showImport"
    entity="teacher"
    title="Import Guru dari Excel"
    @close="showImport = false"
    @done="onImportDone"
  />

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
