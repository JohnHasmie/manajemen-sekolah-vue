<!--
  AdminStudentManagementView.vue — admin student management.

  Uses the same chrome pattern as Admin Schedule / Keuangan:
    - BrandPageHeader admin (gradient)
    - KpiStripCards (4-up)
    - PageFilterToolbar with per-facet AppFilterChip buttons
    - FilterFacetPickerModal per facet
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { StudentService } from '@/services/students.service';
import { ClassroomService } from '@/services/classrooms.service';
import { AttendanceQrService } from '@/services/attendance-qr.service';
import { useMe } from '@/composables/useMe';
import { useRoleHex } from '@/composables/useRoleHex';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useAcademicYearStore } from '@/stores/academic-year';
import { storage } from '@/lib/storage';
import type { Student, Classroom } from '@/types/entities';
import type { Pagination } from '@/types/api';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import PaginationView from '@/components/data/Pagination.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import StudentEditSheet from './widgets/StudentEditSheet.vue';
import StudentStructuredCard from './widgets/StudentStructuredCard.vue';
import StudentCompactRow from './widgets/StudentCompactRow.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import AdminExcelToolbar from '@/components/feature/AdminExcelToolbar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminEntityDetailSheet, {
  type DetailSection,
} from '@/components/feature/AdminEntityDetailSheet.vue';
import ResetPasswordModal from '@/components/feature/ResetPasswordModal.vue';
import SubscriptionUsageBanner from '@/components/billing/SubscriptionUsageBanner.vue';
import Toast from '@/components/ui/Toast.vue';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';

const route = useRoute();
const { t } = useI18n();
const primaryColor = useRoleHex();
const ayStore = useAcademicYearStore();
const ayReadOnly = computed(() => ayStore.isReadOnly);
const { can } = useMe();

/** True when the current admin can issue/print QR cards. Gates the
 *  header + detail-sheet + bulk "Cetak Kartu QR" entries so a member
 *  who can browse siswa but not print cards doesn't see dead buttons. */
const canPrintCards = computed(() => can('attendance.cards.issue'));

/**
 * Per-row + bulk "Cetak Kartu QR" — inline blob download, no
 * navigation. Backend auto-issues any missing cards before rendering
 * the PDF (idempotent), so the button label stays honest whether the
 * siswa already has a card or not.
 *
 * Discoverability hook: admins looked for "print card" here on the
 * roster before the Kartu QR manager tab, so we surface it inline
 * even though the full manager is only one click away.
 */
const printingBulk = ref(false);
const printingRow = ref(false);

async function printCardsForStudents(studentIds: string[], label: string) {
  if (studentIds.length === 0) return;
  const single = studentIds.length === 1;
  if (single) printingRow.value = true;
  else printingBulk.value = true;
  try {
    const ts = new Date().toISOString().slice(0, 10);
    const filename = single
      ? `kartu-qr-${label
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/^-|-$/g, '')
          .slice(0, 40) || 'siswa'}.pdf`
      : `kartu-qr-siswa-${ts}.pdf`;
    await AttendanceQrService.exportStudentCardsPdf(studentIds, filename);
    toast.value = {
      message: single
        ? 'Kartu QR siswa terunduh.'
        : `PDF ${studentIds.length} kartu siswa terunduh.`,
      tone: 'success',
    };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    if (single) printingRow.value = false;
    else printingBulk.value = false;
  }
}

function printCardForCurrentDetail() {
  if (!detailTarget.value || !canPrintCards.value) return;
  void printCardsForStudents(
    [detailTarget.value.id],
    detailTarget.value.name || 'siswa',
  );
}

function printCardsForSelection() {
  if (selectedIds.value.size === 0 || !canPrintCards.value) return;
  void printCardsForStudents(Array.from(selectedIds.value), 'siswa');
}

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
   * Free-text search by guardian (parent) name. Matches the mobile UX:
   * admin types the parent's name and the list filters by case-insensitive
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

// ── Parent (guardian) type-ahead state ───────────────────────────────
// As the admin types in the "Cari Parent" modal we query
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

// ── View mode toggle (Kartu / Padat) ───────────────────────────────
// Two layouts on the Data Siswa page:
//   - "card"    → StudentStructuredCard (Opsi A, two-column with
//                 identity block + 2×2 info grid; mirrors the just-
//                 merged Data Guru two-column redesign).
//   - "compact" → StudentCompactRow (Opsi B, single dense row so an
//                 admin can eyeball a full page of ~15 students
//                 without scrolling).
// Persisted per-user in localStorage so a page reload lands the
// admin back on the layout they left. Key is intentionally the
// Indonesian `siswa_view_mode` because it's a wire key set by
// product spec, not an identifier (identifiers stay English).
type StudentViewMode = 'card' | 'compact';
const STUDENT_VIEW_MODE_STORAGE_KEY = 'siswa_view_mode';
const initialViewMode: StudentViewMode = (() => {
  const raw = storage.get<string>(STUDENT_VIEW_MODE_STORAGE_KEY);
  return raw === 'compact' || raw === 'card' ? raw : 'card';
})();
const viewMode = ref<StudentViewMode>(initialViewMode);
watch(viewMode, (v) => storage.set(STUDENT_VIEW_MODE_STORAGE_KEY, v));

// ── Sheet visibility ───────────────────────────────────────────────
const editTarget = ref<Student | null | undefined>(undefined);
const detailTarget = ref<Student | null>(null);
const deleteTarget = ref<Student | null>(null);
const resetTarget = ref<Student | null>(null);

function openResetPassword() {
  // Reset the wali (guardian) password for the student in the detail sheet.
  resetTarget.value = detailTarget.value;
  detailTarget.value = null;
}

function onResetDone() {
  toast.value = {
    message: 'Password wali berhasil direset.',
    tone: 'success',
  };
}
const bulkDeleteOpen = ref(false);
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

// ── Delete impact preview — concrete cascade consequences ──
// The strings are hand-written honest warnings (no fake counts):
// they name each downstream table the delete cascade will remove or
// mark orphaned, so an admin sees the true scope before hitting
// Konfirmasi. Wali murid accounts stay because they can own multiple
// children — only the anak link is severed.
const STUDENT_DELETE_IMPACT = computed<string[]>(() => [
  t('admin.student.impact.grades'),
  t('admin.student.impact.attendance'),
  t('admin.student.impact.bills'),
  t('admin.student.impact.guardianLink'),
]);
const studentDeleteImpact = STUDENT_DELETE_IMPACT;
const studentBulkDeleteImpact = computed<string[]>(() => [
  t('admin.student.impact.bulkPrefix', { count: selectedIds.value.size }),
  ...STUDENT_DELETE_IMPACT.value,
]);

// The pre-redesign row pill (statusFor → BrandListRow.status) is
// gone: the new StudentStructuredCard renders its own status chip in
// the identity column and StudentCompactRow renders a status dot, so
// no wrapper mapping is needed for the list. `statusPillFor` below
// still feeds the AdminEntityDetailSheet's status-pill prop.

/**
 * Detail-sheet variant. AdminEntityDetailSheet uses a different tone
 * enum (green/amber/red/slate) than the retired BrandListRow status
 * shape (success/warning/danger/info/neutral), so we translate the
 * status into the sheet's shape here rather than push both palettes
 * into the sheet.
 */
function statusPillFor(s: Student): { tone: 'green' | 'amber' | 'red' | 'slate'; label: string } {
  switch (s.status) {
    case 'inactive':
      return { tone: 'slate', label: t('status.Inactive') };
    case 'unverified':
      return { tone: 'amber', label: t('admin.student.unverified') };
    case 'active':
    default:
      return { tone: 'green', label: t('status.Active') };
  }
}

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

// ── Bulk edit — move to class & change status ──────────────────────
// Two-and-only-two bulk-edit ops on students: bulk move-to-kelas
// (heavy time-saver at year start / promotion) and bulk activate/
// deactivate. Other fields are per-student truth (name / NIS /
// gender / wali) and are intentionally OUT of scope for bulk —
// applying the same wali email to 30 siswa would be silently wrong.
const bulkMoveOpen = ref(false);
const bulkStatusOpen = ref(false);
const bulkTargetClassId = ref<string>('');
const bulkTargetStatus = ref<'active' | 'inactive' | ''>('');

function openBulkMove(): void {
  bulkTargetClassId.value = '';
  bulkMoveOpen.value = true;
}
function openBulkStatus(): void {
  bulkTargetStatus.value = '';
  bulkStatusOpen.value = true;
}
const bulkTargetClassName = computed(() => {
  if (!bulkTargetClassId.value) return '';
  return classes.value.find((c) => c.id === bulkTargetClassId.value)?.name ?? '';
});

async function performBulkMove(): Promise<void> {
  if (!bulkTargetClassId.value) return;
  try {
    isSaving.value = true;
    const ids = Array.from(selectedIds.value);
    const res = await StudentService.bulkUpdate(ids, {
      class_id: bulkTargetClassId.value,
    });
    const targetName = bulkTargetClassName.value;
    clearSelection();
    bulkMoveOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.updated} siswa dipindah ke ${targetName} · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = {
        message: `${res.updated} siswa dipindah ke ${targetName}.`,
        tone: 'success',
      };
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

async function performBulkStatus(): Promise<void> {
  if (!bulkTargetStatus.value) return;
  try {
    isSaving.value = true;
    const ids = Array.from(selectedIds.value);
    const target = bulkTargetStatus.value;
    const res = await StudentService.bulkUpdate(ids, { status: target });
    const targetLabel =
      target === 'active' ? t('status.Active') : t('status.Inactive');
    clearSelection();
    bulkStatusOpen.value = false;
    await reload(pagination.value?.current_page ?? 1);
    if (res.failed > 0) {
      toast.value = {
        message: `${res.updated} siswa diubah ke ${targetLabel} · ${res.failed} gagal.`,
        tone: 'error',
      };
    } else {
      toast.value = {
        message: `${res.updated} siswa diubah ke ${targetLabel}.`,
        tone: 'success',
      };
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

// Excel export / import / template are handled by <AdminExcelToolbar>.

// The pre-redesign list rendered a compact `topMeta` string
// ("<kelas> · NIS ...") inside BrandListRow. The card view now
// composes identity in StudentStructuredCard and the compact view in
// StudentCompactRow, so this helper is retired.
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
      <!-- View mode toggle: Kartu (Opsi A structured 2-column card) /
           Padat (Opsi B dense row). Persisted in localStorage under
           `siswa_view_mode`. Sits next to the other header actions
           so it feels like a first-class layout switch, not a filter. -->
      <SegmentedControl
        v-model="viewMode"
        :options="[
          { key: 'card', label: 'Kartu' },
          { key: 'compact', label: 'Padat' },
        ]"
        size="sm"
      />
      <!-- Kelola Kartu QR — deep-link to the Kartu QR manager pre-
           selected on the Siswa tab. Admins looked for the print-card
           entry here on Data Siswa before the manager tab; we surface
           it as a discreet on-hero button so they don't miss it. Gated
           on the same ability that guards the manager route. -->
      <RouterLink
        v-if="canPrintCards"
        :to="{ name: 'admin.attendance.cards', query: { tab: 'siswa' } }"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white px-md py-sm text-sm font-semibold border border-white/30 transition-colors"
      >
        <NavIcon name="id-card" :size="14" />
        Kelola Kartu QR
      </RouterLink>
      <AdminExcelToolbar
        entity="student"
        entity-label="siswa"
        :import-title="t('admin.student.importTitle')"
        :read-only="ayReadOnly"
        @refresh="reload(pagination?.current_page ?? 1)"
        @imported="reload(1)"
      />
    </template>

    <template #banner>
      <SubscriptionUsageBanner dimension="student" />
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

    <ul :class="viewMode === 'card' ? 'space-y-3' : 'space-y-2'">
      <li v-for="s in students" :key="s.id">
        <StudentStructuredCard
          v-if="viewMode === 'card'"
          :student="s"
          :accent-color="primaryColor"
          :selected="selectedIds.has(s.id)"
          bulk-selectable
          @click="selectedIds.size > 0 ? toggleSelect(s.id) : openDetail(s)"
          @long-press="toggleSelect(s.id)"
          @detail="openDetail(s)"
          @delete="deleteTarget = s"
        />
        <StudentCompactRow
          v-else
          :student="s"
          :accent-color="primaryColor"
          :selected="selectedIds.has(s.id)"
          bulk-selectable
          @click="selectedIds.size > 0 ? toggleSelect(s.id) : openDetail(s)"
          @long-press="toggleSelect(s.id)"
          @detail="openDetail(s)"
          @delete="deleteTarget = s"
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
      <!-- Bulk-safe edits: pindah kelas + ubah status. Per-student
           truth fields (name/NIS/gender/wali) are intentionally NOT
           bulk-editable because forcing the same value on N siswa is
           either silently wrong or has to be applied one row at a
           time anyway. -->
      <Button variant="secondary" size="sm" @click="openBulkMove">
        {{ t('admin.student.bulkMoveAction') }}
      </Button>
      <Button variant="secondary" size="sm" @click="openBulkStatus">
        {{ t('admin.student.bulkStatusAction') }}
      </Button>
      <!-- Cetak Kartu QR — one-shot bulk print for the selected siswa.
           Backend auto-issues any missing cards, so this stays a single
           button (no separate "Terbitkan" step). -->
      <Button
        v-if="canPrintCards"
        variant="secondary"
        size="sm"
        :loading="printingBulk"
        @click="printCardsForSelection"
      >
        Cetak Kartu QR ({{ selectedIds.size }})
      </Button>
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
    Guardian (parent) name search modal. A type-ahead: the admin types a
    parent's name and matching names are surfaced in a dropdown
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
          class="text-2xs font-black uppercase tracking-wider text-slate-500 hover:text-slate-900"
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
    :impact="studentDeleteImpact"
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
    :impact="studentBulkDeleteImpact"
    danger
    :loading="isSaving"
    @confirm="performBulkDelete"
    @close="bulkDeleteOpen = false"
  />

  <!-- Bulk-move-to-class modal — single dropdown + summary. -->
  <Modal
    v-if="bulkMoveOpen"
    :title="t('admin.student.bulkMoveTitle', { count: selectedIds.size })"
    :subtitle="t('admin.student.bulkMoveSubtitle')"
    @close="bulkMoveOpen = false"
  >
    <div class="space-y-3">
      <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
        {{ t('admin.student.bulkMoveTargetLabel') }}
      </label>
      <select
        v-model="bulkTargetClassId"
        class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
      >
        <option value="" disabled>{{ t('admin.student.bulkMovePickPlaceholder') }}</option>
        <option v-for="c in classes" :key="c.id" :value="c.id">
          {{ c.name }}{{ c.grade_level ? ` · Tingkat ${c.grade_level}` : '' }}
        </option>
      </select>
      <p
        v-if="bulkTargetClassId"
        class="text-2xs text-slate-500 leading-relaxed"
      >
        {{ t('admin.student.bulkMoveHint', { count: selectedIds.size, name: bulkTargetClassName }) }}
      </p>
      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="bulkMoveOpen = false">
          {{ t('common.cancel') }}
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!bulkTargetClassId"
          @click="performBulkMove"
        >
          {{ t('admin.student.bulkMoveConfirm') }}
        </Button>
      </div>
    </div>
  </Modal>

  <!-- Bulk-status modal — two radios (active/inactive). -->
  <Modal
    v-if="bulkStatusOpen"
    :title="t('admin.student.bulkStatusTitle', { count: selectedIds.size })"
    :subtitle="t('admin.student.bulkStatusSubtitle')"
    @close="bulkStatusOpen = false"
  >
    <div class="space-y-3">
      <label class="flex items-start gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer">
        <input
          v-model="bulkTargetStatus"
          type="radio"
          value="active"
          class="mt-1 accent-role-admin"
        />
        <div>
          <p class="text-[13px] font-black text-slate-900">
            {{ t('status.Active') }}
          </p>
          <p class="text-[11.5px] text-slate-500 mt-0.5">
            {{ t('admin.student.bulkStatusActiveHint') }}
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
            {{ t('status.Inactive') }}
          </p>
          <p class="text-[11.5px] text-slate-500 mt-0.5">
            {{ t('admin.student.bulkStatusInactiveHint') }}
          </p>
        </div>
      </label>
      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="bulkStatusOpen = false">
          {{ t('common.cancel') }}
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!bulkTargetStatus"
          @click="performBulkStatus"
        >
          {{ t('admin.student.bulkStatusConfirm') }}
        </Button>
      </div>
    </div>
  </Modal>

  <AdminEntityDetailSheet
    v-if="detailTarget"
    :title="detailTarget.name || t('admin.student.fallbackTitle')"
    :subtitle="detailTarget.class_name ?? null"
    :avatar-name="detailTarget.name"
    :avatar-color="primaryColor"
    :sections="detailSections"
    :status-pill="statusPillFor(detailTarget)"
    :read-only="ayReadOnly"
    :reset-password-label="detailTarget.guardian_email ? 'Reset Password Wali' : undefined"
    :print-card-label="canPrintCards ? 'Cetak Kartu QR' : undefined"
    :print-card-loading="printingRow"
    @close="detailTarget = null"
    @edit="detailEdit"
    @delete="detailDelete"
    @reset-password="openResetPassword"
    @print-card="printCardForCurrentDetail"
  />

  <ResetPasswordModal
    v-if="resetTarget"
    title="Reset Password Wali"
    :subject-name="resetTarget.guardian_name || resetTarget.name"
    :reset-fn="(pwd?: string) => StudentService.resetGuardianPassword(resetTarget!.id, pwd)"
    @close="resetTarget = null"
    @done="onResetDone"
  />

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
