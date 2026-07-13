<script setup lang="ts">
/**
 * Frame A · Daftar role · /admin/roles
 *
 * Visual contract: web-vue/_design/rbac/AdminWeb_RBAC_School_v1.svg
 * (frame A).
 *
 * Lives inside the existing AppShell — no need to render sidebar /
 * topbar chrome here. Just the BrandPageHeader + KPI strip + filter
 * toolbar + lists.
 */
import { computed, onMounted, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { useRouter } from 'vue-router';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import RoleCard from '@/components/feature/rbac/RoleCard.vue';
import CreateRoleModal from '@/views/admin/rbac/CreateRoleModal.vue';
import { useAuthStore } from '@/stores/auth';
import { useRbacStore } from '@/stores/rbac';
import { useMe } from '@/composables/useMe';
import { useTenant } from '@/composables/useTenant';
import type { RbacRole, RoleTypeFilter } from '@/types/rbac';

const router = useRouter();
const auth = useAuthStore();
const rbac = useRbacStore();
const { can } = useMe();
const { isTutoringCenter } = useTenant();
// Phase D gate: only users holding `rbac.role.create` see the
// +Tambah Role button. Read-only viewers (rbac.role.view) still see
// the list but cannot create. Mirrors the server gate in
// StoreRoleRequest (`rbac.role.create`) so the button never shows when
// the API would 403 — and, crucially, never stays hidden when it would
// allow. (Was gated on `rbac.role.manage`, a key the backend catalog
// never defines, so `can()` always returned false and the button was
// invisible for every admin. Slack 1783914874.)
const canCreateRole = () => can('rbac.role.create');

const {
  rolesLoading,
  rolesError,
  systemRoles,
  customRoles,
  filter,
  search,
} = storeToRefs(rbac);

const showCreateModal = ref(false);

const schoolId = computed(() => auth.schoolId ?? '');

onMounted(() => {
  if (schoolId.value) void rbac.loadRoles(schoolId.value);
});

watch(schoolId, (next) => {
  if (next) void rbac.loadRoles(next);
});

const kpis = computed(() => {
  const total = systemRoles.value.length + customRoles.value.length;
  const members = [...systemRoles.value, ...customRoles.value].reduce(
    (sum, r) => sum + (r.permission_keys?.length ?? 0),
    0,
  );
  return [
    { label: 'TOTAL ROLE', value: total, tint: 'navy' },
    { label: 'ROLE SISTEM', value: systemRoles.value.length, tint: 'cyan' },
    { label: 'ROLE KUSTOM', value: customRoles.value.length, tint: 'amber' },
    { label: 'PERMISSION TER-ASSIGN', value: members, tint: 'green' },
  ];
});

const TINTS: Record<string, { bg: string; fg: string }> = {
  navy: { bg: '#E8EEF7', fg: '#143068' },
  cyan: { bg: '#E2F4FD', fg: '#0E7CB5' },
  amber: { bg: '#FBEEDA', fg: '#A2660D' },
  green: { bg: '#D1FAE5', fg: '#10B981' },
};

function setFilter(next: RoleTypeFilter) {
  rbac.setFilter(next);
}

function openRole(role: RbacRole) {
  void router.push({
    name: 'admin-role-detail',
    params: { roleId: String(role.id) },
  });
}

function onCreated(role: RbacRole) {
  showCreateModal.value = false;
  void router.push({
    name: 'admin-role-detail',
    params: { roleId: String(role.id) },
  });
}
</script>

<template>
  <div
    class="rl rbac-shell"
    :class="{ 'rbac-shell--tutoring': isTutoringCenter }"
  >
    <BrandPageHeader
      role="admin"
      kicker="PENGATURAN"
      title="Role & Permission"
      :meta="`Atur siapa boleh apa di sekolah · ${
        systemRoles.length + customRoles.length
      } role · ${systemRoles.length} sistem + ${customRoles.length} kustom`"
      :live-dot="false"
    >
      <template #default>
        <button
          v-if="canCreateRole()"
          type="button"
          class="rl__add"
          @click="showCreateModal = true"
        >
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
            <path
              d="M3 8 H13 M8 3 V13"
              stroke="#143068"
              stroke-width="2"
              stroke-linecap="round"
            />
          </svg>
          <span>Tambah Role</span>
        </button>
      </template>
    </BrandPageHeader>

    <!-- KPI strip -->
    <div class="rl__kpis">
      <div
        v-for="k in kpis"
        :key="k.label"
        class="rl__kpi"
      >
        <span
          class="rl__kpi-icon"
          :style="{ background: TINTS[k.tint].bg, color: TINTS[k.tint].fg }"
          aria-hidden="true"
        />
        <span class="rl__kpi-label">{{ k.label }}</span>
        <span class="rl__kpi-value">{{ k.value }}</span>
      </div>
    </div>

    <!-- Filter toolbar -->
    <div class="rl__toolbar">
      <div class="rl__segments" role="tablist">
        <button
          v-for="opt in [
            { value: 'all', label: 'Semua' },
            { value: 'system', label: 'Sistem' },
            { value: 'custom', label: 'Kustom' },
          ]"
          :key="opt.value"
          type="button"
          class="rl__seg"
          :class="{ 'rl__seg--active': filter === opt.value }"
          @click="setFilter(opt.value as RoleTypeFilter)"
        >
          {{ opt.label }}
        </button>
      </div>
      <div class="rl__search">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <circle
            cx="6"
            cy="6"
            r="4"
            fill="none"
            stroke="#94a3b8"
            stroke-width="1.4"
          />
          <path
            d="M9 9 L12 12"
            stroke="#94a3b8"
            stroke-width="1.6"
            stroke-linecap="round"
          />
        </svg>
        <input
          type="search"
          placeholder="Cari role…"
          :value="search"
          @input="rbac.setSearch(($event.target as HTMLInputElement).value)"
        />
      </div>
    </div>

    <!-- Error / loading -->
    <div v-if="rolesError" class="rl__error">
      {{ rolesError }}
    </div>
    <div v-else-if="rolesLoading && !systemRoles.length && !customRoles.length" class="rl__loading">
      Memuat role…
    </div>

    <!-- System roles -->
    <template v-if="!rolesLoading || systemRoles.length || customRoles.length">
      <div class="rl__section-head">
        <h3>ROLE SISTEM · {{ systemRoles.length }}</h3>
        <span>PERMISSION · ANGGOTA</span>
      </div>
      <div class="rl__list">
        <RoleCard
          v-for="r in systemRoles"
          :key="r.id"
          :role="r"
          @open="openRole(r)"
          @more="openRole(r)"
        />
        <div v-if="!systemRoles.length" class="rl__empty">
          Tidak ada role sistem yang cocok dengan filter.
        </div>
      </div>

      <h3 class="rl__section-head rl__section-head--solo">
        ROLE KUSTOM · {{ customRoles.length }}
      </h3>
      <div class="rl__list">
        <RoleCard
          v-for="r in customRoles"
          :key="r.id"
          :role="r"
          @open="openRole(r)"
          @more="openRole(r)"
        />
        <div v-if="!customRoles.length" class="rl__empty">
          Belum ada role kustom. Klik <strong>Tambah Role</strong> untuk
          membuat (mis. Bendahara, TU, Penjaga).
        </div>
      </div>
    </template>

    <CreateRoleModal
      :open="showCreateModal"
      :school-id="schoolId"
      @close="showCreateModal = false"
      @created="onCreated"
    />
  </div>
</template>

<style scoped>
.rl {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.rl__add {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  background: #ffffff;
  color: #143068;
  font-size: 13px;
  font-weight: 800;
  border-radius: 10px;
  border: 0;
  cursor: pointer;
}
.rl__add:hover {
  background: #f1f5f9;
}
.rl__kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}
.rl__kpi {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 14px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
}
.rl__kpi-icon {
  width: 28px;
  height: 28px;
  border-radius: 8px;
}
.rl__kpi-label {
  font-size: 10px;
  font-weight: 700;
  color: #94a3b8;
  letter-spacing: 1.2px;
}
.rl__kpi-value {
  font-size: 28px;
  font-weight: 800;
  color: #0f172a;
}
.rl__toolbar {
  display: flex;
  gap: 8px;
  padding: 12px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  align-items: center;
}
.rl__segments {
  display: flex;
  padding: 3px;
  background: #f1f5f9;
  border-radius: 10px;
}
.rl__seg {
  padding: 6px 16px;
  border: 0;
  background: transparent;
  border-radius: 8px;
  font-size: 11px;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
}
.rl__seg--active {
  background: #ffffff;
  color: #143068;
  font-weight: 700;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
}
.rl__search {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  min-width: 200px;
}
.rl__search input {
  border: 0;
  background: transparent;
  outline: none;
  font-size: 11px;
  width: 100%;
  font-weight: 500;
  color: #0f172a;
}
.rl__error {
  padding: 12px 14px;
  background: #fee2e2;
  color: #991b1b;
  border-radius: 10px;
  font-size: 12px;
}
.rl__loading {
  padding: 24px;
  text-align: center;
  color: #64748b;
}
.rl__section-head {
  display: flex;
  justify-content: space-between;
  align-items: end;
  padding: 8px 0;
}
.rl__section-head h3 {
  margin: 0;
  font-size: 11px;
  font-weight: 700;
  color: #64748b;
  letter-spacing: 1.4px;
}
.rl__section-head span {
  font-size: 11px;
  font-weight: 700;
  color: #64748b;
  letter-spacing: 0.6px;
}
.rl__section-head--solo {
  margin-top: 24px;
}
.rl__list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.rl__empty {
  padding: 24px;
  text-align: center;
  color: #64748b;
  background: #f8fafc;
  border: 1px dashed #e2e8f0;
  border-radius: 14px;
  font-size: 13px;
}

/*
 * ── Tutoring tenant (dark) overrides ─────────────────────────────
 * Phase F: reads the same visual delta as the mockup MR !402 —
 * night bg #10162A, cyan accent #21AFE6, light text on dark panels.
 * Everything else stays school-navy. :global() is Vue's escape hatch
 * for reaching a parent-class selector from scoped CSS — the child
 * classes still get the scope hash, so no leaks.
 */
:global(.rbac-shell--tutoring) .rl__kpi,
:global(.rbac-shell--tutoring) .rl__toolbar {
  background: #10162a;
  border-color: #1b2235;
}
:global(.rbac-shell--tutoring) .rl__kpi-label,
:global(.rbac-shell--tutoring) .rl__section-head h3,
:global(.rbac-shell--tutoring) .rl__section-head span {
  color: #94a3b8;
}
:global(.rbac-shell--tutoring) .rl__kpi-value {
  color: #ffffff;
}
:global(.rbac-shell--tutoring) .rl__segments {
  background: #0b1227;
}
:global(.rbac-shell--tutoring) .rl__seg--active {
  background: #21afe6;
  color: #0b0e1a;
}
:global(.rbac-shell--tutoring) .rl__search {
  background: #0b1227;
  border-color: #1b2235;
}
:global(.rbac-shell--tutoring) .rl__search input {
  color: #f1f5f9;
}
:global(.rbac-shell--tutoring) .rl__add {
  background: #21afe6;
  color: #0b0e1a;
}
:global(.rbac-shell--tutoring) .rl__empty {
  background: #0b1227;
  border-color: #1b2235;
  color: #94a3b8;
}
:global(.rbac-shell--tutoring) .rl__loading {
  color: #94a3b8;
}
</style>
