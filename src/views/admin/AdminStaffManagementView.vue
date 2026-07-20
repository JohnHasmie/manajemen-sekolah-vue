<script setup lang="ts">
import { computed, onMounted, reactive, ref, shallowRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { StaffService } from '@/services/staff.service';
import { RbacService } from '@/services/rbac.service';
import { AdminDataExcelService, type ImportDetailRow } from '@/services/admin-data-excel.service';
import { useAuthStore } from '@/stores/auth';
import { useRoleHex } from '@/composables/useRoleHex';
import type { StaffMember, StaffRole } from '@/types/staff';
import type { Pagination } from '@/types/api';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import PaginationView from '@/components/data/Pagination.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import StaffEditSheet from './widgets/StaffEditSheet.vue';
import StaffRbacCard from './widgets/StaffRbacCard.vue';
import SubscriptionUsageBanner from '@/components/billing/SubscriptionUsageBanner.vue';
import AdminEntityDetailSheet, { type DetailSection } from '@/components/feature/AdminEntityDetailSheet.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import AdminDataMenu from '@/components/feature/AdminDataMenu.vue';
import AdminImportExcelModal from '@/components/feature/AdminImportExcelModal.vue';
import AdminImportResultModal from '@/components/feature/AdminImportResultModal.vue';
import ResetPasswordModal from '@/components/feature/ResetPasswordModal.vue';

const { t: $t } = useI18n();
const primaryColor = useRoleHex();
const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

// When opened from the RBAC "Tambah anggota" picker's "+ Tambah staf baru"
// shortcut (?create=1&role_id=&role_label=), pre-select that role so the new
// staff lands in it automatically.
const createRoleId = ref<number | null>(null);
const createRoleLabel = ref('');

const staff = shallowRef<StaffMember[]>([]);
const roles = shallowRef<StaffRole[]>([]);
const pagination = ref<Pagination | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);

const search = ref('');
const filters = reactive<{ role_id: string; gender: string; employment_status: string; position: string }>({
  role_id: '',
  gender: '',
  employment_status: '',
  position: '',
});

const kpis = ref({ total: 0, with_access: 0, unique_positions: 0, female: 0 });
const facets = ref<{ positions: string[] }>({ positions: [] });
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);
const isSaving = ref(false);

const editTarget = ref<StaffMember | null | undefined>(undefined);
const deleteTarget = ref<StaffMember | null>(null);
const detailTarget = ref<StaffMember | null>(null);
const resetTarget = ref<StaffMember | null>(null);

const showImport = ref(false);
const importDetails = ref<ImportDetailRow[]>([]);
const importCounts = ref<{ imported?: number; skipped?: number; conflicts?: number; failed?: number }>({});

const showRolePicker = ref(false);
const showGenderPicker = ref(false);
const showEmploymentPicker = ref(false);
const showPositionPicker = ref(false);

const credential = ref<{ name: string; email: string; password: string } | null>(null);
const copied = ref(false);

const state = computed<AsyncState<StaffMember[]>>(() => {
  if (isLoading.value && staff.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (staff.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: staff.value };
});

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'users', label: $t('admin.staff.kpiTotal'), value: kpis.value.total, tone: 'brand' },
  { icon: 'shield-check', label: $t('admin.staff.kpiWithAccess', 'PUNYA ROLE'), value: kpis.value.with_access, suffix: `/${kpis.value.total}`, tone: 'green' },
  { icon: 'briefcase', label: 'JABATAN', value: kpis.value.unique_positions, tone: 'indigo' },
  { icon: 'user', label: 'PEREMPUAN', value: kpis.value.female, tone: 'pink' },
]);

async function reload(page = 1) {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await StaffService.list({
      page,
      per_page: 20,
      search: search.value || undefined,
      role_id: filters.role_id || undefined,
      gender: filters.gender || undefined,
      employment_status: filters.employment_status || undefined,
      position: filters.position || undefined,
    });
    staff.value = res.items;
    pagination.value = res.pagination ?? null;
    if (res.kpis) kpis.value = res.kpis;
    if (res.facets) facets.value = res.facets;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadRoles() {
  const schoolId = authStore.schoolId;
  if (!schoolId) return;
  try {
    const all = await RbacService.listRoles(schoolId);
    roles.value = all
      .filter((r) => r.role_type === 'staff' || r.role_type === 'admin')
      .map((r) => ({ id: r.id, key: r.key, label: r.label, role_type: r.role_type }));
  } catch {}
}

// Roles offered in the create form — the loaded list, plus a synthetic entry
// for a deep-linked role that hasn't loaded yet (so the dropdown can show it
// immediately without waiting on loadRoles).
const formRoles = computed<StaffRole[]>(() => {
  const list = roles.value;
  const id = createRoleId.value;
  if (id == null || list.some((r) => r.id === id)) return list;
  return [
    { id, key: '', label: createRoleLabel.value || `Role #${id}`, role_type: '' },
    ...list,
  ];
});

function openCreate() {
  createRoleId.value = null;
  createRoleLabel.value = '';
  editTarget.value = null;
}

function closeSheet() {
  editTarget.value = undefined;
  createRoleId.value = null;
  createRoleLabel.value = '';
}

onMounted(() => {
  reload();
  loadRoles();

  // Deep-link from the RBAC picker: open the create form pre-scoped to a role.
  if (route.query.create === '1') {
    const rid = Number(route.query.role_id);
    if (Number.isFinite(rid) && rid > 0) {
      createRoleId.value = rid;
      createRoleLabel.value = String(route.query.role_label ?? '');
    }
    editTarget.value = null; // open the create sheet
    // Strip the query so a refresh / back-nav doesn't reopen the form.
    router.replace({ query: {} });
  }
});

function onSearch(q: string) { search.value = q; reload(1); }
function clearAllFilters() {
  filters.role_id = '';
  filters.gender = '';
  filters.employment_status = '';
  filters.position = '';
  reload(1);
}

const roleOptions = computed(() => roles.value.map(r => ({ key: String(r.id), label: r.label })));
const genderOptions = [ { key: 'male', label: 'Laki-laki' }, { key: 'female', label: 'Perempuan' } ];
const employmentOptions = [ { key: 'permanent', label: 'Tetap' }, { key: 'contract', label: 'Kontrak' }, { key: 'temporary', label: 'Honorer / Tidak Tetap' } ];
const positionOptions = computed(() => facets.value.positions.map(p => ({ key: p, label: p })));

const roleChipValue = computed(() => filters.role_id ? roles.value.find(r => String(r.id) === filters.role_id)?.label ?? '—' : $t('admin.shared.allFilter'));
const genderChipValue = computed(() => filters.gender ? genderOptions.find(o => o.key === filters.gender)?.label ?? '—' : $t('admin.shared.allFilter'));
const employmentChipValue = computed(() => filters.employment_status ? employmentOptions.find(o => o.key === filters.employment_status)?.label ?? '—' : $t('admin.shared.allFilter'));
const positionChipValue = computed(() => filters.position ? positionOptions.value.find(o => o.key === filters.position)?.label ?? '—' : $t('admin.shared.allFilter'));

const detailSections = computed<DetailSection[]>(() => {
  const s = detailTarget.value;
  if (!s) return [];

  const employmentLabel =
    employmentOptions.find((es) => es.key === s.employment_status)?.label ??
    s.employment_status ?? null;

  const roleLabel = s.roles.length > 0 ? s.roles[0].label : 'Belum ada akses';

  return [
    {
      title: 'Identitas',
      rows: [
        { label: 'Nama Lengkap', value: s.name },
        { label: 'Email', value: s.email },
        { label: 'NIP', value: s.employee_number ?? null },
        {
          label: 'Jenis Kelamin',
          value: (() => {
            if (s.gender === 'male') return 'Laki-laki';
            if (s.gender === 'female') return 'Perempuan';
            return null;
          })(),
        },
        { label: 'No. Telepon', value: s.phone ?? null },
        { label: 'Alamat', value: s.address ?? null },
      ],
    },
    {
      title: 'Penugasan',
      rows: [
        { label: 'Jabatan / Posisi', value: s.position },
        { label: 'Status Kepegawaian', value: employmentLabel },
        { label: 'Hak Akses Sistem', value: roleLabel },
      ],
    },
  ];
});

const activeFilterCount = computed(() => {
  let n = 0;
  if (filters.role_id) n++;
  if (filters.gender) n++;
  if (filters.employment_status) n++;
  if (filters.position) n++;
  return n;
});

async function handleSave(payload: Record<string, unknown>) {
  isSaving.value = true;
  try {
    if (editTarget.value) {
      await StaffService.update(editTarget.value.id, payload);
      if (detailTarget.value?.id === editTarget.value.id) {
        detailTarget.value = { ...detailTarget.value, ...payload } as StaffMember;
      }
      editTarget.value = undefined;
      toast.value = { message: $t('admin.staff.toastUpdated'), tone: 'success' };
      await reload(pagination.value?.current_page ?? 1);
    } else {
      const res = await StaffService.create(payload as never);
      editTarget.value = undefined;
      await reload(1);
      if (res.user_created && res.initial_password) {
        credential.value = { name: res.data.name, email: res.data.email ?? '', password: res.initial_password };
      } else {
        toast.value = { message: $t('admin.staff.toastLinked'), tone: 'success' };
      }
    }
  } catch (e) {
    const err = e as any;
    const msg = err?.response?.data?.errors?.email?.[0] ?? err?.response?.data?.message ?? err?.message ?? $t('admin.staff.toastError');
    toast.value = { message: msg, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

async function confirmDelete() {
  if (!deleteTarget.value) return;
  isSaving.value = true;
  try {
    await StaffService.remove(deleteTarget.value.id);
    if (detailTarget.value?.id === deleteTarget.value.id) detailTarget.value = null;
    deleteTarget.value = null;
    toast.value = { message: $t('admin.staff.toastDeleted'), tone: 'success' };
    await reload(pagination.value?.current_page ?? 1);
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

function openResetPassword() {
  resetTarget.value = detailTarget.value;
  detailTarget.value = null;
}

function onResetDone() { toast.value = { message: 'Password staf berhasil direset.', tone: 'success' }; }

async function exportExcel() {
  try {
    await AdminDataExcelService.exportExcel('staff');
    toast.value = { message: 'Excel terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}

async function downloadTemplate() {
  try {
    await AdminDataExcelService.downloadTemplate('staff');
    toast.value = { message: 'Template terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  }
}

function onImportDone(res: { imported: number; failed: number; skipped?: number; conflicts?: number; message?: string; details?: ImportDetailRow[] }) {
  importDetails.value = res.details ?? [];
  importCounts.value = { imported: res.imported, skipped: res.skipped ?? 0, conflicts: res.conflicts ?? 0, failed: res.failed };
  const skipped = res.skipped ?? 0;
  const conflicts = res.conflicts ?? 0;
  const parts = [`${res.imported} staf ditambahkan`];
  if (skipped > 0) parts.push(`${skipped} sudah terdaftar`);
  if (conflicts > 0) parts.push(`${conflicts} perlu ditinjau`);
  if (res.failed > 0) parts.push(`${res.failed} gagal`);

  const needsAttention = res.failed > 0 || conflicts > 0;
  toast.value = { message: `${parts.join(' · ')}.`, tone: needsAttention ? 'error' : 'success' };
  reload(1);
}

async function copyPassword() {
  if (!credential.value) return;
  try {
    await navigator.clipboard.writeText(credential.value.password);
    copied.value = true;
    setTimeout(() => (copied.value = false), 1800);
  } catch {}
}

const staffDeleteImpact = computed<string[]>(() => [ $t('admin.staff.deleteImpactRecord'), $t('admin.staff.deleteImpactAccountKept') ]);
</script>

<template>
  <AdminCrudScaffold
    :title="$t('admin.staff.title')"
    :kicker="$t('admin.shared.kicker')"
    :meta="$t('admin.staff.meta', { count: kpis.total.toLocaleString() })"
    :kpi-cards="kpiCards"
    :state="state"
    :active-filter-count="activeFilterCount"
    :search-placeholder="$t('admin.staff.searchPlaceholder')"
    :empty-title="$t('admin.staff.emptyTitle')"
    :empty-description="$t('admin.staff.emptyDesc')"
    :fab-label="$t('admin.staff.addFab')"
    @search="onSearch"
    @clear-all-filters="clearAllFilters"
    @add-click="openCreate"
    @retry="reload()"
  >
    <template #header-actions>
      <AdminDataMenu
        @refresh="reload(pagination?.current_page ?? 1)"
        @export-excel="exportExcel"
        @import-excel="showImport = true"
        @download-template="downloadTemplate"
      />
    </template>

    <template #banner>
      <SubscriptionUsageBanner dimension="staff" />
    </template>

    <template #filter-chips>
      <AppFilterChip
        icon-name="briefcase"
        label="Jabatan"
        :value="positionChipValue"
        tone="indigo"
        @click="showPositionPicker = true"
      />
      <AppFilterChip
        icon-name="shield"
        label="Role"
        :value="roleChipValue"
        tone="violet"
        @click="showRolePicker = true"
      />
      <AppFilterChip
        icon-name="user"
        label="Gender"
        :value="genderChipValue"
        tone="pink"
        @click="showGenderPicker = true"
      />
      <AppFilterChip
        icon-name="id-card"
        label="Kepegawaian"
        :value="employmentChipValue"
        tone="sky"
        @click="showEmploymentPicker = true"
      />
    </template>

    <ul class="space-y-2">
      <li v-for="s in staff" :key="s.id">
        <StaffRbacCard
          :staff="s"
          :primary-color="primaryColor"
          @click="detailTarget = s"
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
  </AdminCrudScaffold>

  <StaffEditSheet
    v-if="editTarget !== undefined"
    :staff="editTarget"
    :roles="formRoles"
    :initial-role-id="createRoleId"
    :is-saving="isSaving"
    @close="closeSheet"
    @save="handleSave"
  />

  <AdminEntityDetailSheet
    v-if="detailTarget"
    :title="detailTarget.name || 'Staf'"
    :subtitle="detailTarget.position || ''"
    :avatar-name="detailTarget.name"
    :avatar-color="primaryColor"
    :sections="detailSections"
    :read-only="false"
    reset-password-label="Reset Password Staf"
    @close="detailTarget = null"
    @edit="editTarget = detailTarget; detailTarget = null"
    @delete="deleteTarget = detailTarget"
    @reset-password="openResetPassword"
  />

  <ConfirmationDialog
    v-if="deleteTarget"
    :title="$t('admin.staff.deleteTitle', { name: deleteTarget.name })"
    :message="$t('admin.staff.deleteMessage')"
    :confirm-label="$t('admin.staff.delete')"
    :impact="staffDeleteImpact"
    danger
    :loading="isSaving"
    @confirm="confirmDelete"
    @close="deleteTarget = null"
  />

  <ResetPasswordModal
    v-if="resetTarget"
    :target-id="resetTarget.id"
    :target-name="resetTarget.name"
    entity-type="staff"
    @close="resetTarget = null"
    @done="onResetDone"
  />

  <AdminImportExcelModal
    v-if="showImport"
    entity-type="staff"
    @close="showImport = false"
    @done="onImportDone"
  />
  <AdminImportResultModal
    v-if="importDetails.length > 0"
    :details="importDetails"
    :counts="importCounts"
    @close="importDetails = []"
  />

  <Modal v-if="showRolePicker" title="Filter Role" size="sm" @close="showRolePicker = false">
    <div class="space-y-1">
      <button v-for="opt in roleOptions" :key="opt.key" class="w-full text-left px-3 py-2 rounded hover:bg-slate-50" :class="{ 'bg-slate-100 font-bold': filters.role_id === opt.key }" @click="filters.role_id = opt.key; showRolePicker = false; reload(1)">{{ opt.label }}</button>
      <button class="w-full text-left px-3 py-2 text-slate-500 hover:bg-slate-50 rounded" @click="filters.role_id = ''; showRolePicker = false; reload(1)">Semua</button>
    </div>
  </Modal>
  <Modal v-if="showGenderPicker" title="Filter Gender" size="sm" @close="showGenderPicker = false">
    <div class="space-y-1">
      <button v-for="opt in genderOptions" :key="opt.key" class="w-full text-left px-3 py-2 rounded hover:bg-slate-50" :class="{ 'bg-slate-100 font-bold': filters.gender === opt.key }" @click="filters.gender = opt.key; showGenderPicker = false; reload(1)">{{ opt.label }}</button>
      <button class="w-full text-left px-3 py-2 text-slate-500 hover:bg-slate-50 rounded" @click="filters.gender = ''; showGenderPicker = false; reload(1)">Semua</button>
    </div>
  </Modal>
  <Modal v-if="showEmploymentPicker" title="Filter Kepegawaian" size="sm" @close="showEmploymentPicker = false">
    <div class="space-y-1">
      <button v-for="opt in employmentOptions" :key="opt.key" class="w-full text-left px-3 py-2 rounded hover:bg-slate-50" :class="{ 'bg-slate-100 font-bold': filters.employment_status === opt.key }" @click="filters.employment_status = opt.key; showEmploymentPicker = false; reload(1)">{{ opt.label }}</button>
      <button class="w-full text-left px-3 py-2 text-slate-500 hover:bg-slate-50 rounded" @click="filters.employment_status = ''; showEmploymentPicker = false; reload(1)">Semua</button>
    </div>
  </Modal>
  <Modal v-if="showPositionPicker" title="Filter Jabatan" size="sm" @close="showPositionPicker = false">
    <div class="space-y-1">
      <button v-for="opt in positionOptions" :key="opt.key" class="w-full text-left px-3 py-2 rounded hover:bg-slate-50" :class="{ 'bg-slate-100 font-bold': filters.position === opt.key }" @click="filters.position = opt.key; showPositionPicker = false; reload(1)">{{ opt.label }}</button>
      <button class="w-full text-left px-3 py-2 text-slate-500 hover:bg-slate-50 rounded" @click="filters.position = ''; showPositionPicker = false; reload(1)">Semua</button>
    </div>
  </Modal>

  <Modal v-if="credential" :title="$t('admin.staff.createdTitle')" size="md" @close="credential = null">
    <div class="space-y-4">
      <div class="flex items-center gap-2 text-emerald-700">
        <NavIcon name="check-circle" :size="18" />
        <p class="text-[14px] font-bold">{{ $t('admin.staff.createdSubtitle', { name: credential.name }) }}</p>
      </div>
      <div class="rounded-xl bg-slate-50 border border-slate-200 p-3 space-y-1">
        <p class="text-3xs font-bold text-slate-500 uppercase tracking-wider">{{ $t('admin.staff.fieldEmail') }}</p>
        <p class="text-[13px] font-semibold text-slate-800 break-all">{{ credential.email }}</p>
      </div>
      <div class="rounded-xl bg-amber-50 border border-amber-200 p-3">
        <p class="text-3xs font-bold text-amber-700 uppercase tracking-wider">{{ $t('admin.staff.credentialLabel') }}</p>
        <div class="mt-1.5 flex items-center justify-between gap-3">
          <span class="font-mono font-black text-[16px] text-slate-900 select-all break-all">{{ credential.password }}</span>
          <button type="button" class="flex-shrink-0 inline-flex items-center gap-1 rounded-lg bg-white border border-amber-300 px-2.5 py-1.5 text-2xs font-bold text-amber-800 hover:bg-amber-100" @click="copyPassword">
            <NavIcon :name="copied ? 'check' : 'copy'" :size="12" />
            {{ copied ? $t('admin.staff.copied') : $t('admin.staff.copy') }}
          </button>
        </div>
      </div>
      <p class="text-3xs text-slate-500 leading-relaxed">{{ $t('admin.staff.credentialHint') }}</p>
      <Button variant="primary" block @click="credential = null">{{ $t('admin.staff.done') }}</Button>
    </div>
  </Modal>
  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
