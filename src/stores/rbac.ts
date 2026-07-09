/**
 * RBAC store — Pinia equivalent of Flutter's RbacBootstrap + the four
 * Notifiers (rolesList / roleDetail / roleMembers / memberPicker).
 *
 * One store per app instance is fine because every list lives under a
 * single active school. Switching schools triggers `reset()` from the
 * auth store so the cache doesn't leak across tenants.
 *
 * State shape — kept flat so views can `storeToRefs(store)` and the
 * template stays declarative.
 */
import { defineStore } from 'pinia';
import { computed, ref, shallowRef } from 'vue';

import { RbacService } from '@/services/rbac.service';
import type {
  RbacAssignResult,
  RbacMemberSummary,
  RbacPermission,
  RbacRole,
  RbacRoleMember,
  RbacRoleType,
  RoleTypeFilter,
} from '@/types/rbac';

export const useRbacStore = defineStore('rbac', () => {
  // ── Catalog ────────────────────────────────────────────────────────
  const catalog = shallowRef<RbacPermission[]>([]);
  const catalogLoaded = ref(false);

  // ── Roles list ─────────────────────────────────────────────────────
  const roles = shallowRef<RbacRole[]>([]);
  const rolesLoading = ref(false);
  const rolesError = ref<string | null>(null);
  const filter = ref<RoleTypeFilter>('all');
  const search = ref('');

  // ── Single role detail (current edit target) ──────────────────────
  const role = shallowRef<RbacRole | null>(null);
  const stagedPermissionKeys = ref<Set<string>>(new Set());
  const initialPermissionKeys = ref<Set<string>>(new Set());
  const expandedModules = ref<Set<string>>(new Set());
  const roleSaving = ref(false);
  const roleError = ref<string | null>(null);

  // ── Members tab ────────────────────────────────────────────────────
  const members = shallowRef<RbacRoleMember[]>([]);
  const membersLoading = ref(false);
  const memberSearch = ref('');

  // ── Picker (Tambah anggota modal) ──────────────────────────────────
  const pickerQuery = ref('');
  const pickerResults = shallowRef<RbacMemberSummary[]>([]);
  const pickerSelected = ref<RbacMemberSummary[]>([]);
  const pickerLoading = ref(false);
  const pickerTotal = ref(0);
  let pickerSearchSeq = 0;
  let pickerDebounceTimer: ReturnType<typeof setTimeout> | null = null;

  // ── Derived ────────────────────────────────────────────────────────
  const filteredRoles = computed<RbacRole[]>(() => {
    // Yahya 2026-07-09 (Slack 1783574909): hide the student role from
    // the admin roles list — students don't have any actionable
    // permissions in the current app and their presence in the picker
    // was confusing admins. Filter by role_type (server enum) and key
    // prefix so the guard survives a rename of the display label.
    let source = roles.value.filter(
      (r) => r.role_type !== 'student' && !r.key.startsWith('siswa'),
    );
    if (filter.value === 'system') source = source.filter((r) => r.is_system);
    if (filter.value === 'custom') source = source.filter((r) => !r.is_system);
    const q = search.value.trim().toLowerCase();
    if (q) {
      source = source.filter(
        (r) =>
          r.label.toLowerCase().includes(q) ||
          r.key.toLowerCase().includes(q),
      );
    }
    return source;
  });

  const systemRoles = computed(() =>
    filteredRoles.value.filter((r) => r.is_system),
  );
  const customRoles = computed(() =>
    filteredRoles.value.filter((r) => !r.is_system),
  );

  const pendingDiffCount = computed(() => {
    const added = [...stagedPermissionKeys.value].filter(
      (k) => !initialPermissionKeys.value.has(k),
    );
    const removed = [...initialPermissionKeys.value].filter(
      (k) => !stagedPermissionKeys.value.has(k),
    );
    return added.length + removed.length;
  });

  const hasUnsavedChanges = computed(() => pendingDiffCount.value > 0);

  /**
   * Catalog grouped by module. Excludes platform.* and tutoring.*
   * for the school admin UI — they only appear on the super-admin
   * console / tutoring tenant respectively.
   */
  const catalogByModule = computed<Record<string, RbacPermission[]>>(() => {
    const out: Record<string, RbacPermission[]> = {};
    for (const p of catalog.value) {
      if (p.key.startsWith('platform.')) continue;
      if (p.key.startsWith('tutoring.')) continue;
      (out[p.module] ??= []).push(p);
    }
    return out;
  });

  // ── Actions ────────────────────────────────────────────────────────

  async function ensureCatalog(): Promise<void> {
    if (catalogLoaded.value) return;
    catalog.value = await RbacService.fetchCatalog();
    catalogLoaded.value = true;
  }

  async function loadRoles(schoolId: string): Promise<void> {
    rolesLoading.value = true;
    rolesError.value = null;
    try {
      roles.value = await RbacService.listRoles(schoolId);
    } catch (e) {
      rolesError.value = (e as Error).message ?? String(e);
    } finally {
      rolesLoading.value = false;
    }
  }

  function setFilter(next: RoleTypeFilter) {
    filter.value = next;
  }

  function setSearch(next: string) {
    search.value = next;
  }

  async function loadRole(schoolId: string, roleId: number): Promise<void> {
    roleSaving.value = false;
    roleError.value = null;
    const [loaded] = await Promise.all([
      RbacService.showRole(schoolId, roleId),
      ensureCatalog(),
    ]);
    role.value = loaded;
    const keys = new Set(loaded.permission_keys ?? []);
    stagedPermissionKeys.value = new Set(keys);
    initialPermissionKeys.value = keys;
    expandedModules.value = new Set();
  }

  function togglePermission(key: string) {
    const next = new Set(stagedPermissionKeys.value);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    stagedPermissionKeys.value = next;
  }

  function toggleModule(module: string) {
    const next = new Set(expandedModules.value);
    if (next.has(module)) next.delete(module);
    else next.add(module);
    expandedModules.value = next;
  }

  function copyPermissionsFrom(otherKeys: Iterable<string>) {
    stagedPermissionKeys.value = new Set(otherKeys);
  }

  function resetPermissionChanges() {
    stagedPermissionKeys.value = new Set(initialPermissionKeys.value);
  }

  async function saveRole(schoolId: string): Promise<RbacRole | null> {
    if (!role.value) return null;
    roleSaving.value = true;
    roleError.value = null;
    try {
      const updated = await RbacService.updateRole(
        schoolId,
        role.value.id,
        {
          // Send label only for custom roles — keeps the wire honest.
          ...(role.value.is_system ? {} : { label: role.value.label }),
          permission_keys: [...stagedPermissionKeys.value],
        },
      );
      role.value = updated;
      initialPermissionKeys.value = new Set(stagedPermissionKeys.value);
      return updated;
    } catch (e) {
      roleError.value = (e as Error).message ?? String(e);
      return null;
    } finally {
      roleSaving.value = false;
    }
  }

  async function createRole(
    schoolId: string,
    payload: {
      key: string;
      label: string;
      role_type: RbacRoleType;
      permission_keys: string[];
    },
  ): Promise<RbacRole | null> {
    try {
      const created = await RbacService.createRole(schoolId, payload);
      // Refresh the cached list so the new row appears without a manual
      // reload.
      await loadRoles(schoolId);
      return created;
    } catch (e) {
      rolesError.value = (e as Error).message ?? String(e);
      return null;
    }
  }

  async function deleteRole(
    schoolId: string,
    roleId: number,
  ): Promise<boolean> {
    try {
      await RbacService.deleteRole(schoolId, roleId);
      roles.value = roles.value.filter((r) => r.id !== roleId);
      return true;
    } catch (e) {
      rolesError.value = (e as Error).message ?? String(e);
      return false;
    }
  }

  async function loadMembers(
    schoolId: string,
    roleId: number,
  ): Promise<void> {
    membersLoading.value = true;
    try {
      members.value = await RbacService.listMembers(schoolId, roleId);
    } finally {
      membersLoading.value = false;
    }
  }

  function setMemberSearch(next: string) {
    memberSearch.value = next;
  }

  const filteredMembers = computed<RbacRoleMember[]>(() => {
    const q = memberSearch.value.trim().toLowerCase();
    if (!q) return members.value;
    return members.value.filter(
      (m) =>
        m.name.toLowerCase().includes(q) ||
        m.email.toLowerCase().includes(q),
    );
  });

  /**
   * Optimistic remove. Rolls back if the server rejects (e.g. last-admin
   * guard at the backend trips a 422).
   */
  async function removeMember(
    schoolId: string,
    roleId: number,
    userId: string,
  ): Promise<string | null> {
    const before = members.value;
    members.value = before.filter((m) => m.user_id !== userId);
    try {
      await RbacService.removeMember(schoolId, roleId, userId);
      return null;
    } catch (e) {
      members.value = before;
      return (e as Error).message ?? String(e);
    }
  }

  function setPickerQuery(next: string, schoolId: string, roleId: number) {
    pickerQuery.value = next;
    if (pickerDebounceTimer) clearTimeout(pickerDebounceTimer);
    pickerDebounceTimer = setTimeout(() => {
      void runPickerSearch(schoolId, roleId);
    }, 300);
  }

  async function runPickerSearch(
    schoolId: string,
    roleId: number,
  ): Promise<void> {
    const mySeq = ++pickerSearchSeq;
    pickerLoading.value = true;
    try {
      const page = await RbacService.searchMembers(schoolId, {
        search: pickerQuery.value,
        exclude_role_id: roleId,
      });
      if (mySeq !== pickerSearchSeq) return; // newer query in flight
      pickerResults.value = page.data;
      pickerTotal.value = page.total;
    } finally {
      if (mySeq === pickerSearchSeq) pickerLoading.value = false;
    }
  }

  function togglePickerSelection(user: RbacMemberSummary) {
    if (user.already_in_excluded_role) return;
    const exists = pickerSelected.value.some((m) => m.user_id === user.user_id);
    pickerSelected.value = exists
      ? pickerSelected.value.filter((m) => m.user_id !== user.user_id)
      : [...pickerSelected.value, user];
  }

  function unselectPicker(userId: string) {
    pickerSelected.value = pickerSelected.value.filter(
      (m) => m.user_id !== userId,
    );
  }

  function resetPicker() {
    pickerQuery.value = '';
    pickerResults.value = [];
    pickerSelected.value = [];
    pickerTotal.value = 0;
  }

  async function submitPicker(
    schoolId: string,
    roleId: number,
  ): Promise<RbacAssignResult | null> {
    if (pickerSelected.value.length === 0) return null;
    const result = await RbacService.assignMembers(
      schoolId,
      roleId,
      pickerSelected.value.map((m) => m.user_id),
    );
    // Refresh the members list — counts changed.
    await loadMembers(schoolId, roleId);
    resetPicker();
    return result;
  }

  /**
   * Wipe everything — called by the auth store after `switchSchool`
   * so cached roles/members from the old tenant never leak into the
   * new one.
   */
  function reset() {
    catalog.value = [];
    catalogLoaded.value = false;
    roles.value = [];
    rolesError.value = null;
    role.value = null;
    stagedPermissionKeys.value = new Set();
    initialPermissionKeys.value = new Set();
    members.value = [];
    resetPicker();
  }

  return {
    // state
    catalog,
    roles,
    rolesLoading,
    rolesError,
    filter,
    search,
    role,
    stagedPermissionKeys,
    initialPermissionKeys,
    expandedModules,
    roleSaving,
    roleError,
    members,
    membersLoading,
    memberSearch,
    pickerQuery,
    pickerResults,
    pickerSelected,
    pickerLoading,
    pickerTotal,
    // derived
    filteredRoles,
    systemRoles,
    customRoles,
    pendingDiffCount,
    hasUnsavedChanges,
    catalogByModule,
    filteredMembers,
    // actions
    ensureCatalog,
    loadRoles,
    setFilter,
    setSearch,
    loadRole,
    togglePermission,
    toggleModule,
    copyPermissionsFrom,
    resetPermissionChanges,
    saveRole,
    createRole,
    deleteRole,
    loadMembers,
    setMemberSearch,
    removeMember,
    setPickerQuery,
    togglePickerSelection,
    unselectPicker,
    resetPicker,
    submitPicker,
    reset,
  };
});
