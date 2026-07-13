<!--
  AdminStaffManagementView.vue — "Data Staf".

  Manages non-teaching personnel (TU, bendahara, musyrifah, satpam, dst.)
  alongside Data Guru / Siswa / Kelas. The "Tambah Staf" flow creates a
  brand-new user account from scratch (Feature A) — no need to import them
  as a teacher first — and can grant an RBAC role + hand over an initial
  password in the same step.

  Reuses the shared AdminCrudScaffold chrome + BrandListRow, matching the
  other admin management pages.
-->
<script setup lang="ts">
import { computed, onMounted, ref, shallowRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { StaffService } from '@/services/staff.service';
import { RbacService } from '@/services/rbac.service';
import { useAuthStore } from '@/stores/auth';
import { useRoleHex } from '@/composables/useRoleHex';
import type { StaffMember, StaffRole } from '@/types/staff';
import type { Pagination } from '@/types/api';
import type { AsyncState } from '@/components/data/AsyncView.vue';
import type { KpiCard } from '@/components/feature/KpiStripCards.vue';
import AdminCrudScaffold from '@/components/feature/AdminCrudScaffold.vue';
import BrandListRow from '@/components/feature/BrandListRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import PaginationView from '@/components/data/Pagination.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import StaffEditSheet from './widgets/StaffEditSheet.vue';

const { t: $t } = useI18n();
const primaryColor = useRoleHex();
const authStore = useAuthStore();

const staff = shallowRef<StaffMember[]>([]);
const roles = shallowRef<StaffRole[]>([]);
const pagination = ref<Pagination | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const search = ref('');
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const isSaving = ref(false);
// undefined = sheet closed; null = create mode; a member = edit mode.
const editTarget = ref<StaffMember | null | undefined>(undefined);
const deleteTarget = ref<StaffMember | null>(null);

// Credential reveal after a successful create — shown ONCE.
const credential = ref<{ name: string; email: string; password: string } | null>(null);
const copied = ref(false);

const state = computed<AsyncState<StaffMember[]>>(() => {
  if (isLoading.value && staff.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (staff.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: staff.value };
});

const totalStaff = computed(() => pagination.value?.total_items ?? staff.value.length);
const withAccessCount = computed(() => staff.value.filter((s) => s.roles.length > 0).length);

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'users', label: $t('admin.staff.kpiTotal'), value: totalStaff.value, tone: 'brand' },
  {
    icon: 'shield',
    label: $t('admin.staff.kpiWithAccess'),
    value: withAccessCount.value,
    suffix: $t('admin.shared.perPage'),
    tone: 'green',
  },
]);

async function reload(page = 1) {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await StaffService.list({
      page,
      per_page: 20,
      search: search.value || undefined,
    });
    staff.value = res.items;
    pagination.value = res.pagination ?? null;
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
    // Offer non-system roles first (custom staff roles like Musyrifah/TU are
    // the common case); the raw shape is compatible with StaffRole.
    roles.value = all.map((r) => ({
      id: r.id,
      key: r.key,
      label: r.label,
      role_type: r.role_type,
    }));
  } catch {
    // The picker degrades to "Tanpa akses" if roles can't load.
  }
}

onMounted(() => {
  reload();
  loadRoles();
});

function onSearch(q: string) {
  search.value = q;
  reload(1);
}

function rowMeta(s: StaffMember): string {
  return s.employee_number ? `${s.position} · ${s.employee_number}` : s.position;
}

function rowStatus(s: StaffMember) {
  if (s.roles.length > 0) {
    return { tone: 'info' as const, label: s.roles[0].label };
  }
  return { tone: 'neutral' as const, label: $t('admin.staff.noAccess') };
}

async function handleSave(payload: Record<string, unknown>) {
  isSaving.value = true;
  try {
    if (editTarget.value) {
      await StaffService.update(editTarget.value.id, payload);
      editTarget.value = undefined;
      toast.value = { message: $t('admin.staff.toastUpdated'), tone: 'success' };
      await reload(pagination.value?.current_page ?? 1);
    } else {
      const res = await StaffService.create(payload as never);
      editTarget.value = undefined;
      await reload(1);
      if (res.user_created && res.initial_password) {
        credential.value = {
          name: res.data.name,
          email: res.data.email ?? '',
          password: res.initial_password,
        };
      } else {
        // Linked an existing account — no password to show.
        toast.value = { message: $t('admin.staff.toastLinked'), tone: 'success' };
      }
    }
  } catch (e) {
    const err = e as {
      message?: string;
      response?: { data?: { message?: string; errors?: Record<string, string[]> } };
    };
    const msg =
      err?.response?.data?.errors?.email?.[0] ??
      err?.response?.data?.message ??
      err?.message ??
      $t('admin.staff.toastError');
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
    deleteTarget.value = null;
    toast.value = { message: $t('admin.staff.toastDeleted'), tone: 'success' };
    await reload(pagination.value?.current_page ?? 1);
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

async function copyPassword() {
  if (!credential.value) return;
  try {
    await navigator.clipboard.writeText(credential.value.password);
    copied.value = true;
    setTimeout(() => (copied.value = false), 1800);
  } catch {
    // Non-fatal: the value is select-all-able in the box.
  }
}

const staffDeleteImpact = computed<string[]>(() => [
  $t('admin.staff.deleteImpactRecord'),
  $t('admin.staff.deleteImpactAccountKept'),
]);
</script>

<template>
  <AdminCrudScaffold
    :title="$t('admin.staff.title')"
    :kicker="$t('admin.shared.kicker')"
    :meta="$t('admin.staff.meta', { count: totalStaff.toLocaleString() })"
    :kpi-cards="kpiCards"
    :state="state"
    :search-placeholder="$t('admin.staff.searchPlaceholder')"
    :empty-title="$t('admin.staff.emptyTitle')"
    :empty-description="$t('admin.staff.emptyDesc')"
    :fab-label="$t('admin.staff.addFab')"
    @search="onSearch"
    @add-click="editTarget = null"
    @retry="reload()"
  >
    <ul class="space-y-2">
      <li v-for="s in staff" :key="s.id">
        <BrandListRow
          :title="s.name || $t('admin.shared.noName')"
          :top-meta="rowMeta(s)"
          :status="rowStatus(s)"
          :trailing-action-label="$t('admin.shared.detail')"
          :trailing-action-color="primaryColor"
          @click="editTarget = s"
        >
          <template #leading>
            <InitialsAvatar
              :name="s.name || '?'"
              :size="44"
              :color="primaryColor"
              :border-radius="12"
            />
          </template>
          <div class="mt-2 flex items-center gap-2 text-xs text-slate-500">
            <span class="truncate flex-1">{{ s.email || '—' }}</span>
            <button
              type="button"
              class="text-status-danger hover:underline"
              @click.stop="deleteTarget = s"
            >
              {{ $t('admin.staff.delete') }}
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
  </AdminCrudScaffold>

  <StaffEditSheet
    v-if="editTarget !== undefined"
    :staff="editTarget"
    :roles="roles"
    :is-saving="isSaving"
    @close="editTarget = undefined"
    @save="handleSave"
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

  <!-- Credential reveal — shown once after creating a new account. -->
  <Modal
    v-if="credential"
    :title="$t('admin.staff.createdTitle')"
    size="md"
    @close="credential = null"
  >
    <div class="space-y-4">
      <div class="flex items-center gap-2 text-emerald-700">
        <NavIcon name="check-circle" :size="18" />
        <p class="text-[14px] font-bold">
          {{ $t('admin.staff.createdSubtitle', { name: credential.name }) }}
        </p>
      </div>

      <div class="rounded-xl bg-slate-50 border border-slate-200 p-3 space-y-1">
        <p class="text-3xs font-bold text-slate-500 uppercase tracking-wider">
          {{ $t('admin.staff.fieldEmail') }}
        </p>
        <p class="text-[13px] font-semibold text-slate-800 break-all">{{ credential.email }}</p>
      </div>

      <div class="rounded-xl bg-amber-50 border border-amber-200 p-3">
        <p class="text-3xs font-bold text-amber-700 uppercase tracking-wider">
          {{ $t('admin.staff.credentialLabel') }}
        </p>
        <div class="mt-1.5 flex items-center justify-between gap-3">
          <span class="font-mono font-black text-[16px] text-slate-900 select-all break-all">
            {{ credential.password }}
          </span>
          <button
            type="button"
            class="flex-shrink-0 inline-flex items-center gap-1 rounded-lg bg-white border border-amber-300 px-2.5 py-1.5 text-2xs font-bold text-amber-800 hover:bg-amber-100"
            @click="copyPassword"
          >
            <NavIcon :name="copied ? 'check' : 'copy'" :size="12" />
            {{ copied ? $t('admin.staff.copied') : $t('admin.staff.copy') }}
          </button>
        </div>
      </div>

      <p class="text-3xs text-slate-500 leading-relaxed">
        {{ $t('admin.staff.credentialHint') }}
      </p>

      <Button variant="primary" block @click="credential = null">
        {{ $t('admin.staff.done') }}
      </Button>
    </div>
  </Modal>

  <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
</template>
