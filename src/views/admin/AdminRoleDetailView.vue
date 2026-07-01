<script setup lang="ts">
/**
 * Frame B + Anggota tab · /admin/roles/:roleId
 *
 * Hosts three tabs: Detail (read-only summary), Permission
 * (accordion + sticky save bar), Anggota (members list + add modal).
 *
 * Visual contract: web-vue/_design/rbac/AdminWeb_RBAC_School_v1.svg
 * (frames B + C).
 */
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import PermissionModuleAccordion from '@/components/feature/rbac/PermissionModuleAccordion.vue';
import MemberAvatar from '@/components/feature/rbac/MemberAvatar.vue';
import AddMembersModal from '@/views/admin/rbac/AddMembersModal.vue';

import { useAuthStore } from '@/stores/auth';
import { useRbacStore } from '@/stores/rbac';
import { useMe } from '@/composables/useMe';
import { useTenant } from '@/composables/useTenant';

type TabKey = 'detail' | 'permission' | 'anggota';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const rbac = useRbacStore();
const { can } = useMe();
const { isTutoringCenter } = useTenant();
const canManageRoles = () => can('rbac.role.manage');
const canManageMembers = () => can('rbac.member.assign');

const {
  role,
  catalogByModule,
  stagedPermissionKeys,
  expandedModules,
  pendingDiffCount,
  hasUnsavedChanges,
  roleSaving,
  roleError,
  members,
  filteredMembers,
  memberSearch,
} = storeToRefs(rbac);

const schoolId = computed(() => auth.schoolId ?? '');
const roleId = computed(() => Number(route.params.roleId));
const activeTab = ref<TabKey>('permission');
const showAddMembers = ref(false);
const removalError = ref<string | null>(null);

onMounted(load);
watch([schoolId, roleId], load);

async function load() {
  if (!schoolId.value || !roleId.value) return;
  await rbac.loadRole(schoolId.value, roleId.value);
  // Lazy-load members only when the user opens that tab — but pre-fetch
  // when the user lands on the page so the count badge is accurate.
  await rbac.loadMembers(schoolId.value, roleId.value);
}

const modulesInOrder = computed(() => Object.keys(catalogByModule.value));
const totalCatalogCount = computed(
  () =>
    Object.values(catalogByModule.value).reduce(
      (sum, list) => sum + list.length,
      0,
    ),
);

const memberCount = computed(() => members.value.length);

const systemRoleCopySources = computed(() =>
  rbac.roles.filter((r) => r.is_system && r.id !== role.value?.id).slice(0, 3),
);

function toggleModule(module: string) {
  rbac.toggleModule(module);
}

function copyFrom(sourceId: number) {
  const src = rbac.roles.find((r) => r.id === sourceId);
  if (src?.permission_keys) rbac.copyPermissionsFrom(src.permission_keys);
}

async function save() {
  const updated = await rbac.saveRole(schoolId.value);
  if (updated) {
    // Reload list cache so member counts and permission counts on the
    // index page stay accurate when the user navigates back.
    void rbac.loadRoles(schoolId.value);
  }
}

async function removeMember(userId: string) {
  removalError.value = null;
  const err = await rbac.removeMember(schoolId.value, roleId.value, userId);
  if (err) removalError.value = err;
}

function backToList() {
  void router.push({ name: 'admin-roles' });
}
</script>

<template>
  <div
    class="rd rbac-shell"
    :class="{ 'rbac-shell--tutoring': isTutoringCenter }"
  >
    <BrandPageHeader
      role="admin"
      :kicker="
        role
          ? `${(role.role_type || 'staff').toUpperCase()} · ${
              role.is_system ? 'SISTEM' : 'KUSTOM'
            }`
          : 'ROLE'
      "
      :title="role?.label ?? 'Memuat…'"
      :meta="
        role
          ? `${memberCount} anggota · ${stagedPermissionKeys.size} dari ${totalCatalogCount} permission`
          : ''
      "
      :live-dot="false"
    >
      <template #default>
        <button class="rd__back" @click="backToList">← Kembali</button>
      </template>
    </BrandPageHeader>

    <div class="rd__tabs" role="tablist">
      <button
        v-for="tab in [
          { key: 'detail', label: 'Detail' },
          { key: 'permission', label: 'Permission' },
          { key: 'anggota', label: 'Anggota' },
        ]"
        :key="tab.key"
        type="button"
        class="rd__tab"
        :class="{ 'rd__tab--active': activeTab === tab.key }"
        role="tab"
        :aria-selected="activeTab === tab.key"
        @click="activeTab = tab.key as TabKey"
      >
        {{ tab.label }}
        <span
          v-if="tab.key === 'permission' && pendingDiffCount > 0"
          class="rd__tab-dot"
        />
      </button>
    </div>

    <!-- DETAIL TAB -->
    <section v-if="activeTab === 'detail'" class="rd__panel">
      <div v-if="role" class="rd__detail">
        <div class="rd__field">
          <span class="rd__field-label">Key</span>
          <code class="rd__field-mono">{{ role.key }}</code>
        </div>
        <div class="rd__field">
          <span class="rd__field-label">Tipe</span>
          <span>{{ role.role_type }}</span>
        </div>
        <div class="rd__field">
          <span class="rd__field-label">Status</span>
          <span>{{ role.is_system ? 'Sistem (bawaan)' : 'Kustom' }}</span>
        </div>
        <div v-if="role.is_system" class="rd__warn">
          Role sistem: nama dan key tidak bisa diubah. Hanya permission yang
          dapat dikustomisasi per sekolah.
        </div>
      </div>
    </section>

    <!-- PERMISSION TAB -->
    <section v-else-if="activeTab === 'permission'" class="rd__panel">
      <div v-if="systemRoleCopySources.length" class="rd__copy-bar">
        <span class="rd__copy-label">Salin permission dari role lain</span>
        <button
          v-for="src in systemRoleCopySources"
          :key="src.id"
          type="button"
          class="rd__copy-btn"
          @click="copyFrom(src.id)"
        >
          {{ src.label }}
        </button>
      </div>

      <PermissionModuleAccordion
        v-for="module in modulesInOrder"
        :key="module"
        :module="module"
        :permissions="catalogByModule[module]"
        :selected-keys="stagedPermissionKeys"
        :is-open="expandedModules.has(module) || module === modulesInOrder[0]"
        @toggle-open="toggleModule(module)"
        @toggle-permission="(k) => rbac.togglePermission(k)"
      />

      <div v-if="roleError" class="rd__error">{{ roleError }}</div>
    </section>

    <!-- ANGGOTA TAB -->
    <section v-else class="rd__panel">
      <div class="rd__members-head">
        <div class="rd__members-search">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <circle
              cx="6"
              cy="6"
              r="4"
              fill="none"
              stroke="#94a3b8"
              stroke-width="1.4"
            />
            <path d="M9 9 L12 12" stroke="#94a3b8" stroke-width="1.6" />
          </svg>
          <input
            type="search"
            placeholder="Cari nama atau email…"
            :value="memberSearch"
            @input="
              rbac.setMemberSearch(
                ($event.target as HTMLInputElement).value,
              )
            "
          />
        </div>
        <button
          v-if="canManageMembers()"
          type="button"
          class="rd__add"
          @click="showAddMembers = true"
        >
          + Tambah anggota
        </button>
      </div>

      <div v-if="removalError" class="rd__error">{{ removalError }}</div>

      <ul v-if="filteredMembers.length" class="rd__members">
        <li
          v-for="m in filteredMembers"
          :key="m.user_id"
          class="rd__member"
        >
          <MemberAvatar
            :seed="m.user_id"
            :initials="
              m.name
                .split(/\s+/)
                .map((p) => p[0])
                .join('')
                .slice(0, 2)
                .toUpperCase()
            "
            :photo-url="m.photo_url"
            :size="44"
          />
          <div class="rd__member-body">
            <div class="rd__member-name">{{ m.name }}</div>
            <div class="rd__member-meta">
              {{ m.email }}
              <span v-if="m.joined_at">· sejak {{ m.joined_at }}</span>
            </div>
            <div class="rd__member-tags">
              <span v-if="m.is_active" class="rd__pill rd__pill--success">
                AKTIF
              </span>
              <span
                v-if="m.other_roles.length"
                class="rd__pill rd__pill--info"
              >
                + {{ m.other_roles[0].label
                }}{{
                  m.other_roles.length > 1
                    ? ` +${m.other_roles.length - 1}`
                    : ''
                }}
              </span>
            </div>
          </div>
          <button
            v-if="canManageMembers()"
            type="button"
            class="rd__member-remove"
            @click="removeMember(m.user_id)"
          >
            Lepas
          </button>
        </li>
      </ul>
      <div v-else class="rd__empty">
        Belum ada anggota. Klik <strong>Tambah anggota</strong>.
      </div>
    </section>

    <!-- Sticky save bar (Permission tab only, manage-only) -->
    <div
      v-if="activeTab === 'permission' && role && canManageRoles()"
      class="rd__save-bar"
    >
      <span class="rd__save-hint">
        <template v-if="hasUnsavedChanges"
          >{{ pendingDiffCount }} perubahan belum disimpan</template
        >
        <template v-else>Belum ada perubahan</template>
      </span>
      <button
        type="button"
        class="rd__btn rd__btn--ghost"
        :disabled="!hasUnsavedChanges || roleSaving"
        @click="rbac.resetPermissionChanges()"
      >
        Batal
      </button>
      <button
        type="button"
        class="rd__btn rd__btn--primary"
        :disabled="!hasUnsavedChanges || roleSaving"
        @click="save"
      >
        <span v-if="roleSaving">Menyimpan…</span>
        <span v-else>Simpan perubahan</span>
      </button>
    </div>

    <AddMembersModal
      v-if="role"
      :open="showAddMembers"
      :school-id="schoolId"
      :role-id="roleId"
      :role-label="role.label"
      :role-type="role.role_type"
      :permission-count="stagedPermissionKeys.size"
      @close="showAddMembers = false"
      @done="showAddMembers = false"
    />
  </div>
</template>

<style scoped>
.rd {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding-bottom: 96px;
}
.rd__back {
  padding: 8px 14px;
  background: rgba(255, 255, 255, 0.16);
  color: #ffffff;
  font-size: 12px;
  font-weight: 700;
  border-radius: 10px;
  border: 0;
  cursor: pointer;
}
.rd__back:hover {
  background: rgba(255, 255, 255, 0.24);
}
.rd__tabs {
  display: flex;
  gap: 4px;
  padding: 4px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  width: max-content;
}
.rd__tab {
  position: relative;
  padding: 10px 18px;
  background: transparent;
  border: 0;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 700;
  color: #64748b;
  cursor: pointer;
}
.rd__tab--active {
  background: #143068;
  color: #ffffff;
}
.rd__tab-dot {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 6px;
  height: 6px;
  background: #f59e0b;
  border-radius: 50%;
}
.rd__panel {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.rd__copy-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 14px;
  background: #f1f5f9;
  border-radius: 12px;
}
.rd__copy-label {
  font-size: 12px;
  font-weight: 700;
  color: #0f172a;
  margin-right: auto;
}
.rd__copy-btn {
  padding: 6px 14px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 11px;
  font-weight: 700;
  color: #143068;
  cursor: pointer;
}
.rd__copy-btn:hover {
  border-color: #143068;
}
.rd__detail {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 16px;
}
.rd__field {
  display: grid;
  grid-template-columns: 100px 1fr;
  gap: 12px;
  padding: 10px 0;
  font-size: 13px;
  color: #0f172a;
  border-bottom: 1px solid #f1f5f9;
}
.rd__field:last-child {
  border-bottom: 0;
}
.rd__field-label {
  font-size: 11px;
  color: #64748b;
}
.rd__field-mono {
  font-family: ui-monospace, Menlo, monospace;
  font-size: 12px;
  background: #f1f5f9;
  padding: 4px 8px;
  border-radius: 6px;
  width: max-content;
}
.rd__warn {
  margin-top: 12px;
  padding: 12px;
  background: #fef3c7;
  color: #a2660d;
  border-radius: 10px;
  font-size: 11px;
}
.rd__error {
  padding: 12px;
  background: #fee2e2;
  color: #991b1b;
  border-radius: 10px;
  font-size: 12px;
}
.rd__members-head {
  display: flex;
  align-items: center;
  gap: 12px;
}
.rd__members-search {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
}
.rd__members-search input {
  border: 0;
  background: transparent;
  outline: none;
  font-size: 12px;
  width: 100%;
}
.rd__add {
  padding: 10px 16px;
  background: #143068;
  color: #ffffff;
  font-size: 12px;
  font-weight: 800;
  border: 0;
  border-radius: 10px;
  cursor: pointer;
}
.rd__add:hover {
  background: #0a1f4d;
}
.rd__members {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.rd__member {
  display: grid;
  grid-template-columns: 44px 1fr auto;
  gap: 14px;
  align-items: center;
  padding: 14px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
}
.rd__member-name {
  font-size: 14px;
  font-weight: 800;
  color: #0f172a;
}
.rd__member-meta {
  font-size: 11px;
  color: #64748b;
}
.rd__member-tags {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}
.rd__pill {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.4px;
  padding: 3px 6px;
  border-radius: 6px;
}
.rd__pill--success {
  background: #d1fae5;
  color: #15803d;
}
.rd__pill--info {
  background: #e2f4fd;
  color: #0e7cb5;
}
.rd__member-remove {
  padding: 6px 12px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  color: #b91c1c;
  font-size: 11px;
  font-weight: 700;
  border-radius: 8px;
  cursor: pointer;
}
.rd__member-remove:hover {
  background: #fee2e2;
  border-color: #fecaca;
}
.rd__empty {
  padding: 32px;
  text-align: center;
  color: #64748b;
  background: #f8fafc;
  border: 1px dashed #e2e8f0;
  border-radius: 14px;
  font-size: 13px;
}
.rd__save-bar {
  position: sticky;
  bottom: 16px;
  display: grid;
  grid-template-columns: 1fr auto auto;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.08);
}
.rd__save-hint {
  font-size: 11px;
  color: #64748b;
}
.rd__btn {
  padding: 10px 18px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  border: 0;
}
.rd__btn--ghost {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  color: #0f172a;
}
.rd__btn--primary {
  background: #143068;
  color: #ffffff;
  font-weight: 800;
}
.rd__btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Tutoring tenant (dark). */
:global(.rbac-shell--tutoring) .rd__tabs,
:global(.rbac-shell--tutoring) .rd__detail,
:global(.rbac-shell--tutoring) .rd__save-bar {
  background: #10162a;
  border-color: #1b2235;
}
:global(.rbac-shell--tutoring) .rd__tab--active {
  background: #21afe6;
  color: #0b0e1a;
}
:global(.rbac-shell--tutoring) .rd__tab {
  color: #94a3b8;
}
:global(.rbac-shell--tutoring) .rd__field {
  color: #f1f5f9;
  border-bottom-color: #1b2235;
}
:global(.rbac-shell--tutoring) .rd__field-label,
:global(.rbac-shell--tutoring) .rd__save-hint,
:global(.rbac-shell--tutoring) .rd__member-meta,
:global(.rbac-shell--tutoring) .rd__member-tags .rd__pill--info,
:global(.rbac-shell--tutoring) .rd__members-search input,
:global(.rbac-shell--tutoring) .rd__members-search {
  color: #94a3b8;
}
:global(.rbac-shell--tutoring) .rd__field-mono {
  background: #1b2235;
  color: #f1f5f9;
}
:global(.rbac-shell--tutoring) .rd__copy-bar {
  background: rgba(33, 175, 230, 0.08);
}
:global(.rbac-shell--tutoring) .rd__copy-label {
  color: #a8e1f7;
}
:global(.rbac-shell--tutoring) .rd__copy-btn {
  background: #0b1227;
  border-color: rgba(33, 175, 230, 0.3);
  color: #21afe6;
}
:global(.rbac-shell--tutoring) .rd__members-search,
:global(.rbac-shell--tutoring) .rd__member {
  background: #10162a;
  border-color: #1b2235;
}
:global(.rbac-shell--tutoring) .rd__member-name {
  color: #f1f5f9;
}
:global(.rbac-shell--tutoring) .rd__add,
:global(.rbac-shell--tutoring) .rd__btn--primary {
  background: #21afe6;
  color: #0b0e1a;
}
:global(.rbac-shell--tutoring) .rd__btn--ghost {
  background: #0b1227;
  border-color: #1b2235;
  color: #f1f5f9;
}
:global(.rbac-shell--tutoring) .rd__member-remove {
  background: #0b1227;
  border-color: #1b2235;
  color: #fca5a5;
}
:global(.rbac-shell--tutoring) .rd__empty {
  background: #0b1227;
  border-color: #1b2235;
  color: #94a3b8;
}
</style>
