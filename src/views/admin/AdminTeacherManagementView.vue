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
import { useRoleHex } from '@/composables/useRoleHex';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import { normalizeGender } from '@/types/entities';
import type { Teacher, Classroom, Subject } from '@/types/entities';
import type { Pagination } from '@/types/api';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import TeacherStructuredCard from './widgets/TeacherStructuredCard.vue';
import PaginationView from '@/components/data/Pagination.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import TeacherEditSheet from './widgets/TeacherEditSheet.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import AdminExcelToolbar from '@/components/feature/AdminExcelToolbar.vue';
import AdminEntityDetailSheet, {
  type DetailSection,
} from '@/components/feature/AdminEntityDetailSheet.vue';
import ResetPasswordModal from '@/components/feature/ResetPasswordModal.vue';
import SubscriptionUsageBanner from '@/components/billing/SubscriptionUsageBanner.vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';

// Aliased to `$t` because the template iterates `t in teachers` (`t`
// would shadow the i18n helper inside the v-for scope).
const { t: $t } = useI18n();
const primaryColor = useRoleHex();
const ayStore = useAcademicYearStore();

const teachers = shallowRef<Teacher[]>([]);
const classes = shallowRef<Classroom[]>([]);
const subjects = shallowRef<Subject[]>([]);
const filterOptions = shallowRef<TeacherFilterOptions>({
  roles: [
    { key: 'guru', label: $t('admin.sekolah.teacher_management.role_teacher') },
    { key: 'wali_kelas', label: $t('admin.sekolah.teacher_management.role_homeroom') },
  ],
  genders: [
    { key: 'male', label: $t('admin.sekolah.teacher_management.gender_male') },
    { key: 'female', label: $t('admin.sekolah.teacher_management.gender_female') },
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
const forceSkeleton = ref(false);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const search = ref('');
const filters = reactive<{
  role: 'guru' | 'wali_kelas' | null;
  class_id: string | null;
  gender: 'male' | 'female' | null;
  employment_status: string | null;
  activity_status: 'active' | 'inactive' | null;
}>({
  role: null,
  class_id: null,
  gender: null,
  employment_status: null,
  activity_status: null,
});
const selectedIds = ref<Set<string>>(new Set());

const editTarget = ref<Teacher | null | undefined>(undefined);
const detailTarget = ref<Teacher | null>(null);
const resetTarget = ref<Teacher | null>(null);

function openResetPassword() {
  // Open the reset modal on the teacher currently in the detail sheet.
  resetTarget.value = detailTarget.value;
  detailTarget.value = null;
}

function onResetDone() {
  toast.value = {
    message: 'Password guru berhasil direset.',
    tone: 'success',
  };
}
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
const showActivityPicker = ref(false);

const state = computed<AsyncState<Teacher[]>>(() => {
  if (isLoading.value && (teachers.value.length === 0 || forceSkeleton.value)) return { status: 'loading' };
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
const activityOptions = computed<FacetOption[]>(() => [
  { key: 'active', label: $t('admin.teachers.activityActive') },
  { key: 'inactive', label: $t('admin.teachers.activityInactive') },
]);

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
  return filters.gender === 'male'
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
const activityStatusChipValue = computed(() => {
  if (!filters.activity_status) return $t('admin.shared.allFilter');
  return filters.activity_status === 'active'
    ? $t('admin.teachers.activityActive')
    : $t('admin.teachers.activityInactive');
});

const activeFilterCount = computed(() => {
  let n = 0;
  if (filters.role) n++;
  if (filters.class_id) n++;
  if (filters.gender) n++;
  if (filters.employment_status) n++;
  if (filters.activity_status) n++;
  return n;
});

async function reload(page = 1, opts: { skeleton?: boolean } = {}) {
  isLoading.value = true;
  forceSkeleton.value = opts.skeleton ?? false;
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
      activity_status: filters.activity_status ?? undefined,
      academic_year_id: ayStore.activeYearId || undefined,
    });
    teachers.value = res.items;
    pagination.value = res.pagination ?? null;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
    forceSkeleton.value = false;
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
  filters.activity_status = null;
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
  // Normalise so both legacy 'P' and canonical 'female' count. Without
  // this, rows stored as 'female' fell through and the KPI card
  // undercounted teachers on schools past the English-naming rollout.
  () => teachers.value.filter((t) => normalizeGender(t.gender) === 'female').length,
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

// ── Delete impact preview — concrete cascade consequences ──
// Hand-written honest warnings for the teacher delete cascade. RPP +
// kegiatan kelas rows attribute to the teacher but stay on file so
// historical records aren't lost; the user account itself survives
// because it may already carry other roles at a different school.
const TEACHER_DELETE_IMPACT = computed<string[]>(() => [
  $t('admin.sekolah.teacher_management.impact.homeroom'),
  $t('admin.sekolah.teacher_management.impact.schedule'),
  $t('admin.sekolah.teacher_management.impact.selfAttendance'),
  $t('admin.sekolah.teacher_management.impact.authoredRowsKept'),
  $t('admin.sekolah.teacher_management.impact.userAccountKept'),
]);
const teacherDeleteImpact = TEACHER_DELETE_IMPACT;
const teacherBulkDeleteImpact = computed<string[]>(() => [
  $t('admin.sekolah.teacher_management.impact.bulkPrefix', {
    count: selectedIds.value.size,
  }),
  ...TEACHER_DELETE_IMPACT.value,
]);

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

// ── Bulk edit — employment status only ─────────────────────────────
// employment_status is 4-tier (tetap / tidak_tetap / kontrak /
// honorer) and applying the same value to N teachers is a real HR
// operation. Personal fields (name/email/subjects/homeroom) stay OUT.
const bulkStatusOpen = ref(false);
const bulkTargetEmploymentStatus = ref<string>('');
const EMPLOYMENT_STATUS_LABELS: Record<string, string> = {
  tetap: 'Tetap',
  tidak_tetap: 'Tidak Tetap',
  kontrak: 'Kontrak',
  honorer: 'Honorer',
};
const bulkTargetEmploymentLabel = computed(() =>
  bulkTargetEmploymentStatus.value
    ? EMPLOYMENT_STATUS_LABELS[bulkTargetEmploymentStatus.value] ?? ''
    : '',
);
function openBulkStatus(): void {
  bulkTargetEmploymentStatus.value = '';
  bulkStatusOpen.value = true;
}

async function performBulkStatus(): Promise<void> {
  if (!bulkTargetEmploymentStatus.value) return;
  try {
    isSaving.value = true;
    const ids = Array.from(selectedIds.value);
    const target = bulkTargetEmploymentStatus.value;
    const res = await TeacherService.bulkUpdate(ids, {
      employment_status: target,
    });
    const targetLabel = bulkTargetEmploymentLabel.value;
    clearSelection();
    bulkStatusOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.updated} guru diubah ke ${targetLabel} · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = {
        message: `${res.updated} guru diubah ke ${targetLabel}.`,
        tone: 'success',
      };
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
          // Backend now emits canonical `male`/`female` (post English-
          // naming migration) but this view was hard-coded to `L`/`P`,
          // so the detail modal rendered null until the row was edited
          // + saved (which re-wrote it as L/P via the edit sheet).
          // Luay reported 2026-07-06: "di mobile sudah sesuai, di
          // website belum, diedit dulu baru muncul". Normalise via
          // the shared helper so both legacy L/P and canonical
          // male/female resolve here.
          value: (() => {
            const g = normalizeGender(teacher.gender);
            if (g === 'male') return $t('admin.sekolah.teacher_management.gender_male');
            if (g === 'female') return $t('admin.sekolah.teacher_management.gender_female');
            return null;
          })(),
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

// Add-mode reuse confirm ("Email sudah dipakai — tetap gunakan?"). Holds the
// pending payload so we can resubmit it with use_another_user on confirm.
const emailReuseConfirm = ref<{
  payload: Record<string, unknown>;
  email: string;
} | null>(null);

async function confirmEmailReuse() {
  const pending = emailReuseConfirm.value;
  emailReuseConfirm.value = null;
  if (!pending) return;
  await handleSave({ ...pending.payload, use_another_user: true });
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
    if (code === 'already_teacher_here') {
      // The email's account already teaches at THIS school — a real duplicate,
      // no reuse path. Tell the admin plainly.
      error.value = $t('admin.sekolah.teacher_management.err_already_teacher_here');
      toast.value = {
        message: $t('admin.sekolah.teacher_management.err_already_teacher_here'),
        tone: 'error',
      };
    } else if (looksLikeConflict && editTarget.value) {
      // Edit mode — keep the sheet open + flip the hint so the user can
      // retry with the "Ganti akun terkait" toggle on (migrate to the
      // existing user). The sheet's amber callout is the better surface.
      teacherEmailConflict.value = true;
      toast.value = {
        message: $t('admin.sekolah.teacher_management.toast_email_conflict_edit'),
        tone: 'error',
      };
    } else if (code === 'email_conflict') {
      // Add mode (Opsi 1) — the email belongs to another account that does NOT
      // yet teach here, so offer to reuse it. Stash the payload + open the
      // confirm; on OK we resubmit with use_another_user: true.
      emailReuseConfirm.value = { payload, email: String(payload.email ?? '') };
    } else if (looksLikeConflict) {
      // Add mode against an OLD backend (plain unique 422, no reuse path) —
      // fall back to the previous "use a different email" guidance.
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

// Excel export / import / template are handled by <AdminExcelToolbar>.

// The pre-redesign card rendered a compact `topMeta` string + a status
// chip. Those are now handled inside TeacherStructuredCard (identity
// column shows role/NIP; assignment grid shows homeroom + teaching
// state), so no helper is needed here.
</script>

<template>
  <!-- Teachers aren't AY-scoped (no academic_year_id on teachers) — the
       add-FAB should be available even when the tenant has no active
       academic year. Fixes the attendance_staff-only trial where "Tambah
       Guru" was hidden just because the school hadn't set up an AY yet. -->
  <AdminCrudScaffold
    :title="$t('admin.teachers.title')"
    :kicker="$t('admin.shared.kicker')"
    :meta="headerMeta"
    :kpi-cards="kpiCards"
    :state="state"
    :selected-count="selectedIds.size"
    :active-filter-count="activeFilterCount"
    :hide-add-fab="false"
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
      <!-- Teachers aren't scoped to an academic year (the teachers table has
           no academic_year_id) — so we don't gate Import/Export on
           ayReadOnly like AY-scoped entities (students, classes) do.
           Fixes the attendance_staff-only tenant seeing Import disabled
           just because they hadn't created an AY yet. -->
      <AdminExcelToolbar
        entity="teacher"
        entity-label="guru"
        :import-title="$t('admin.sekolah.teacher_management.import_title')"
        @refresh="reload(pagination?.current_page ?? 1, { skeleton: true })"
        @imported="reload(1)"
      />
    </template>

    <template #banner>
      <SubscriptionUsageBanner dimension="staff" />
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
      <AppFilterChip
        icon-name="activity"
        :label="$t('admin.teachers.filterActivity')"
        :value="activityStatusChipValue"
        tone="rose"
        @click="showActivityPicker = true"
      />
    </template>

    <ul class="space-y-3">
      <li v-for="t in teachers" :key="t.id">
        <TeacherStructuredCard
          :teacher="t"
          :accent-color="primaryColor"
          :selected="selectedIds.has(t.id)"
          bulk-selectable
          @click="selectedIds.size > 0 ? toggleSelect(t.id) : openDetail(t)"
          @long-press="toggleSelect(t.id)"
          @detail="openDetail(t)"
          @delete="deleteTarget = t"
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
        {{ $t('admin.sekolah.teacher_management.bulk_status_action') }}
      </Button>
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
    @apply="(v) => { filters.gender = (v as 'male' | 'female' | '') || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showEmploymentPicker"
    :title="$t('admin.sekolah.teacher_management.filter_employment_title')"
    :options="employmentOptions"
    :selected="filters.employment_status ?? ''"
    @close="showEmploymentPicker = false"
    @apply="(v) => { filters.employment_status = v || null; reload(1); }"
  />
  <FilterFacetPickerModal
    v-if="showActivityPicker"
    :title="$t('admin.teachers.filterActivity')"
    :options="activityOptions"
    :selected="filters.activity_status ?? ''"
    @close="showActivityPicker = false"
    @apply="(v) => { filters.activity_status = (v as 'active' | 'inactive' | '') || null; reload(1); }"
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
    :read-only="false"
    reset-password-label="Reset Password Guru"
    @close="detailTarget = null"
    @edit="detailEdit"
    @delete="detailDelete"
    @reset-password="openResetPassword"
  />

  <ResetPasswordModal
    v-if="resetTarget"
    title="Reset Password Guru"
    :subject-name="resetTarget.name"
    :reset-fn="(pwd?: string) => TeacherService.resetPassword(resetTarget!.id, pwd)"
    @close="resetTarget = null"
    @done="onResetDone"
  />

  <ConfirmationDialog
    v-if="deleteTarget"
    :title="$t('admin.sekolah.teacher_management.delete_one_title', { name: deleteTarget.name })"
    :message="$t('admin.sekolah.teacher_management.delete_one_message')"
    :confirm-label="$t('admin.sekolah.teacher_management.delete')"
    :impact="teacherDeleteImpact"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <!-- Add-mode: email belongs to another account — reuse it as a teacher here? -->
  <ConfirmationDialog
    v-if="emailReuseConfirm"
    :title="$t('admin.sekolah.teacher_management.email_reuse_confirm_title')"
    :message="$t('admin.sekolah.teacher_management.email_reuse_confirm_message', { email: emailReuseConfirm.email })"
    :confirm-label="$t('admin.sekolah.teacher_management.email_reuse_confirm_ok')"
    :loading="isSaving"
    @confirm="confirmEmailReuse"
    @close="emailReuseConfirm = null"
  />

  <ConfirmationDialog
    v-if="bulkDeleteOpen"
    :title="$t('admin.sekolah.teacher_management.delete_bulk_title', { count: selectedIds.size })"
    :message="$t('admin.sekolah.teacher_management.delete_bulk_message')"
    :confirm-label="$t('admin.sekolah.teacher_management.delete_all')"
    :impact="teacherBulkDeleteImpact"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <!-- Bulk-status-kepegawaian modal — 4 radios (tetap / tidak_tetap /
       kontrak / honorer), applied to N selected teachers. -->
  <Modal
    v-if="bulkStatusOpen"
    :title="$t('admin.sekolah.teacher_management.bulk_status_title', { count: selectedIds.size })"
    :subtitle="$t('admin.sekolah.teacher_management.bulk_status_subtitle')"
    @close="bulkStatusOpen = false"
  >
    <div class="space-y-2">
      <label
        v-for="opt in [
          { key: 'tetap', label: 'Tetap' },
          { key: 'tidak_tetap', label: 'Tidak Tetap' },
          { key: 'kontrak', label: 'Kontrak' },
          { key: 'honorer', label: 'Honorer' },
        ]"
        :key="opt.key"
        class="flex items-center gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer"
      >
        <input
          v-model="bulkTargetEmploymentStatus"
          type="radio"
          :value="opt.key"
          class="accent-role-admin"
        />
        <span class="text-[13px] font-black text-slate-900">{{ opt.label }}</span>
      </label>
      <p
        v-if="bulkTargetEmploymentStatus"
        class="text-2xs text-slate-500 leading-relaxed pt-1"
      >
        {{ $t('admin.sekolah.teacher_management.bulk_status_hint', { count: selectedIds.size, name: bulkTargetEmploymentLabel }) }}
      </p>
      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="bulkStatusOpen = false">
          {{ $t('common.cancel') }}
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!bulkTargetEmploymentStatus"
          @click="performBulkStatus"
        >
          {{ $t('admin.sekolah.teacher_management.bulk_status_confirm') }}
        </Button>
      </div>
    </div>
  </Modal>

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
