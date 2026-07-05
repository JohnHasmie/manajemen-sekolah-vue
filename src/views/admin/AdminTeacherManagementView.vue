<!--
  AdminTeacherManagementView.vue — admin teacher management.

  Uses the shared Schedule/Keuangan chrome pattern: gradient
  BrandPageHeader + KpiStripCards + PageFilterToolbar with per-facet
  AppFilterChip buttons.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef } from 'vue';
import { useI18n } from 'vue-i18n';
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
import SubscriptionUsageBanner from '@/components/billing/SubscriptionUsageBanner.vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';

// Aliased to `$t` because the template iterates `t in teachers` (`t`
// would shadow the i18n helper inside the v-for scope).
const { t: $t } = useI18n();
const primaryColor = useRoleHex();
const ayStore = useAcademicYearStore();
const ayReadOnly = computed(() => ayStore.isReadOnly);

const teachers = shallowRef<Teacher[]>([]);
const classes = shallowRef<Classroom[]>([]);
const subjects = shallowRef<Subject[]>([]);
const filterOptions = shallowRef<TeacherFilterOptions>({
  roles: [
    { key: 'guru', label: $t('admin.sekolah.teacher_management.role_teacher') },
    { key: 'wali_kelas', label: $t('admin.sekolah.teacher_management.role_homeroom') },
  ],
  genders: [
    { key: 'L', label: $t('admin.sekolah.teacher_management.gender_male') },
    { key: 'P', label: $t('admin.sekolah.teacher_management.gender_female') },
  ],
  employment_statuses: [
    { key: 'tetap', label: $t('admin.sekolah.teacher_management.employ_permanent') },
    { key: 'tidak_tetap', label: $t('admin.sekolah.teacher_management.employ_temporary') },
    { key: 'kontrak', label: $t('admin.sekolah.teacher_management.employ_contract') },
    { key: 'honorer', label: $t('admin.sekolah.teacher_management.employ_honorary') },
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
/**
 * Flipped to `true` when the backend rejects a teacher save because
 * the new email already belongs to another user. Passed down to
 * <TeacherEditSheet> so it can auto-enable the "Ganti akun terkait"
 * toggle + show a callout telling the admin to click Save again to
 * complete the migration. Cleared every time the sheet opens or the
 * admin retries.
 */
const teacherEmailConflict = ref(false);

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
  if (!filters.role) return $t('admin.shared.allFilter');
  return filterOptions.value.roles.find((r) => r.key === filters.role)?.label ?? '—';
});
const classChipValue = computed(() => {
  if (!filters.class_id) return $t('admin.shared.allFilter');
  const fromFilterOpts = filterOptions.value.classes.find((c) => c.id === filters.class_id);
  if (fromFilterOpts) return fromFilterOpts.name;
  return classes.value.find((c) => c.id === filters.class_id)?.name ?? '—';
});
const genderChipValue = computed(() => {
  if (!filters.gender) return $t('admin.shared.allFilter');
  return filters.gender === 'L'
    ? $t('admin.studentFilter.genderMale')
    : $t('admin.studentFilter.genderFemale');
});
const employmentChipValue = computed(() => {
  if (!filters.employment_status) return $t('admin.shared.allFilter');
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
  { icon: 'users', label: $t('admin.teachers.kpiTotal'), value: totalTeachers.value, tone: 'brand' },
  {
    icon: 'shield',
    label: $t('admin.teachers.kpiHomeroom'),
    value: pageWaliCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'violet',
  },
  {
    icon: 'book-open',
    label: $t('admin.teachers.kpiHasSubject'),
    value: pageWithSubjectsCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'green',
  },
  {
    icon: 'user',
    label: $t('admin.teachers.kpiFemale'),
    value: pageFemaleCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'amber',
  },
]);

const headerMeta = computed(() =>
  $t('admin.teachers.meta', {
    count: totalTeachers.value.toLocaleString(),
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
  const teacher = detailTarget.value;
  if (!teacher) return [];
  const employmentLabel =
    filterOptions.value.employment_statuses.find(
      (es) => es.key === teacher.employment_status,
    )?.label ?? teacher.employment_status ?? null;
  return [
    {
      title: $t('admin.sekolah.teacher_management.section_identity'),
      rows: [
        { label: $t('admin.sekolah.teacher_management.field_name'), value: teacher.name },
        { label: $t('admin.sekolah.teacher_management.field_email'), value: teacher.email },
        { label: $t('admin.sekolah.teacher_management.field_nip'), value: teacher.employee_number ?? null },
        {
          label: $t('admin.sekolah.teacher_management.field_gender'),
          value: teacher.gender === 'L' ? $t('admin.sekolah.teacher_management.gender_male') : teacher.gender === 'P' ? $t('admin.sekolah.teacher_management.gender_female') : null,
        },
        { label: $t('admin.sekolah.teacher_management.field_phone'), value: teacher.phone_number ?? null },
        { label: $t('admin.sekolah.teacher_management.field_address'), value: teacher.address ?? null },
      ],
    },
    {
      title: $t('admin.sekolah.teacher_management.section_assignment'),
      rows: [
        { label: $t('admin.sekolah.teacher_management.field_role'), value: teacher.role === 'wali_kelas' ? $t('admin.sekolah.teacher_management.role_homeroom') : $t('admin.sekolah.teacher_management.role_teacher') },
        { label: $t('admin.sekolah.teacher_management.field_employment'), value: employmentLabel },
        { label: $t('admin.sekolah.teacher_management.field_subjects'), value: teacher.subject_names?.join(', ') || null },
        {
          label: $t('admin.sekolah.teacher_management.field_homeroom_class'),
          value:
            teacher.homeroom_class_names?.join(', ') ||
            teacher.homeroom_class_name ||
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
  // Clear any previous conflict hint so the sheet's callout
  // doesn't linger across retries — it'll be re-set below only
  // if the backend rejects this attempt with email_conflict.
  teacherEmailConflict.value = false;
  try {
    if (editTarget.value && editTarget.value.id) {
      await TeacherService.update(editTarget.value.id, payload);
    } else {
      await TeacherService.create(payload);
    }
    editTarget.value = undefined;
    await reload(pagination.value?.current_page ?? 1);
  } catch (e) {
    // Detect the backend's "email already used by another user" signal.
    // The backend may return { code: 'email_conflict' } OR an Indonesian
    // "sudah terdaftar"/"Ganti Akun" message — but the common case is the
    // plain Laravel unique-validation 422, whose field error reads
    // "The email has already been taken." (English, no code). Match all
    // three so a duplicate email is recognised on both add and edit.
    const err = e as {
      message?: string;
      response?: {
        data?: {
          code?: string;
          message?: string;
          errors?: Record<string, string[]>;
        };
      };
    };
    const code = err?.response?.data?.code;
    const msg = String(err?.response?.data?.message ?? err?.message ?? '');
    const emailFieldErr = err?.response?.data?.errors?.email?.[0] ?? '';
    const looksLikeConflict =
      code === 'email_conflict' ||
      /sudah terdaftar/i.test(msg) ||
      /ganti akun/i.test(msg) ||
      /already been taken|has already|sudah (di)?pakai/i.test(
        `${emailFieldErr} ${msg}`,
      );
    if (looksLikeConflict && editTarget.value) {
      // Edit mode — keep the sheet open + flip the hint so the user can
      // retry with the "Ganti akun terkait" toggle on (migrate to the
      // existing user). The sheet's amber callout is the better surface.
      teacherEmailConflict.value = true;
      toast.value = {
        message: $t('admin.sekolah.teacher_management.toast_email_conflict_edit'),
        tone: 'error',
      };
    } else if (looksLikeConflict) {
      // Add mode — there's no migration path, so tell the admin plainly
      // to use a different email instead of the bare 422 / English text.
      error.value = $t('admin.sekolah.teacher_management.err_email_conflict_add');
      toast.value = {
        message: $t('admin.sekolah.teacher_management.toast_email_conflict_add'),
        tone: 'error',
      };
    } else {
      error.value = msg || 'Gagal menyimpan guru.';
    }
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
  const role = t.role === 'wali_kelas'
    ? $t('role.wali_kelas')
    : $t('role.guru');
  const nip = t.employee_number;
  return nip ? `${role} · ${$t('admin.teachers.rowPrefix', { nip })}` : role;
}

function statusFor(t: Teacher) {
  if (t.homeroom_class_name) {
    return {
      tone: 'info' as const,
      label: $t('admin.teachers.homeroomPrefix', { class: t.homeroom_class_name }),
    };
  }
  return { tone: 'success' as const, label: $t('admin.subjects.statusActive') };
}
</script>

<template>
  <AdminCrudScaffold
    :title="$t('admin.teachers.title')"
    :kicker="$t('admin.shared.kicker')"
    :meta="headerMeta"
    :kpi-cards="kpiCards"
    :state="state"
    :selected-count="selectedIds.size"
    :active-filter-count="activeFilterCount"
    :hide-add-fab="ayReadOnly"
    :search-placeholder="$t('admin.teachers.searchPlaceholder')"
    :empty-title="$t('admin.teachers.emptyTitle')"
    :empty-description="$t('admin.teachers.emptyDesc')"
    :fab-label="$t('admin.teachers.addFab')"
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

    <template #banner>
      <SubscriptionUsageBanner />
    </template>

    <template #filter-chips>
      <AppFilterChip
        icon-name="shield"
        :label="$t('admin.teachers.filterRole')"
        :value="roleChipValue"
        tone="violet"
        @click="showRolePicker = true"
      />
      <AppFilterChip
        icon-name="layers"
        :label="$t('admin.teachers.filterClass')"
        :value="classChipValue"
        tone="brand"
        @click="showClassPicker = true"
      />
      <AppFilterChip
        icon-name="user"
        :label="$t('admin.teachers.filterGender')"
        :value="genderChipValue"
        tone="amber"
        @click="showGenderPicker = true"
      />
      <AppFilterChip
        icon-name="briefcase"
        :label="$t('admin.teachers.filterEmployment')"
        :value="employmentChipValue"
        tone="green"
        @click="showEmploymentPicker = true"
      />
      <button
        type="button"
        class="text-2xs font-bold px-3 py-1.5 rounded-lg border transition-colors"
        :class="
          filters.show_all
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
        "
        @click="filters.show_all = !filters.show_all; reload(1)"
      >
        {{ $t('admin.teachers.semuaGuru') }}
      </button>
    </template>

    <ul class="space-y-2">
      <li v-for="t in teachers" :key="t.id">
        <BrandListRow
          :title="t.name || $t('admin.shared.noName')"
          :top-meta="topMeta(t)"
          :status="statusFor(t)"
          :trailing-action-label="selectedIds.has(t.id) ? '' : $t('admin.shared.detail')"
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
        {{ $t('admin.sekolah.teacher_management.bulk_delete', { count: selectedIds.size }) }}
      </Button>
    </template>
  </AdminCrudScaffold>

  <!-- Per-facet pickers -->
  <FilterFacetPickerModal
    v-if="showRolePicker"
    :title="$t('admin.sekolah.teacher_management.filter_role_title')"
    :options="roleOptions"
    :selected="filters.role ?? ''"
    @close="showRolePicker = false"
    @apply="(v) => { filters.role = (v as 'guru' | 'wali_kelas' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showClassPicker"
    :title="$t('admin.sekolah.teacher_management.filter_class_title')"
    :options="classOptions"
    :selected="filters.class_id ?? ''"
    @close="showClassPicker = false"
    @apply="(v) => { filters.class_id = v || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showGenderPicker"
    :title="$t('admin.sekolah.teacher_management.filter_gender_title')"
    :options="genderOptions"
    :selected="filters.gender ?? ''"
    @close="showGenderPicker = false"
    @apply="(v) => { filters.gender = (v as 'L' | 'P' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showEmploymentPicker"
    :title="$t('admin.sekolah.teacher_management.filter_employment_title')"
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
    :email-conflict-hint="teacherEmailConflict"
    @close="() => { editTarget = undefined; teacherEmailConflict = false; }"
    @save="handleSave"
  />

  <AdminEntityDetailSheet
    v-if="detailTarget"
    :title="detailTarget.name || $t('admin.sekolah.teacher_management.fallback_name')"
    :subtitle="detailTarget.role === 'wali_kelas' ? $t('admin.sekolah.teacher_management.role_homeroom') : $t('admin.sekolah.teacher_management.role_teacher')"
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
    :title="$t('admin.sekolah.teacher_management.delete_one_title', { name: deleteTarget.name })"
    :message="$t('admin.sekolah.teacher_management.delete_one_message')"
    :confirm-label="$t('admin.sekolah.teacher_management.delete')"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <ConfirmationDialog
    v-if="bulkDeleteOpen"
    :title="$t('admin.sekolah.teacher_management.delete_bulk_title', { count: selectedIds.size })"
    :message="$t('admin.sekolah.teacher_management.delete_bulk_message')"
    :confirm-label="$t('admin.sekolah.teacher_management.delete_all')"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <AdminImportExcelModal
    v-if="showImport"
    entity="teacher"
    :title="$t('admin.sekolah.teacher_management.import_title')"
    @close="showImport = false"
    @done="onImportDone"
  />

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
