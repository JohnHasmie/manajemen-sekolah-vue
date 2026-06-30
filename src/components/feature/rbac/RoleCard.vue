<script setup lang="ts">
/**
 * One row in the Roles list page (AdminRolesView, Frame A).
 *
 * Visual contract: AdminWeb_RBAC_School_v1.svg — left accent bar tinted
 * by role_type, soft icon tile, label + subtitle, system/custom badge,
 * right-aligned permission count, kebab menu for actions.
 */
import { computed } from 'vue';
import type { RbacRole } from '@/types/rbac';
import { swatchFor } from './RoleTypeSwatch';

const props = defineProps<{
  role: RbacRole;
  memberCount?: number | null;
  /** Hint shown under the title (e.g. "staff · finance + presensi sendiri"). */
  subtitle?: string;
}>();

defineEmits<{
  (e: 'open'): void;
  (e: 'more'): void;
}>();

const swatch = computed(() => swatchFor(props.role.role_type));
const permissionCount = computed(() => props.role.permission_keys?.length ?? 0);
</script>

<template>
  <button
    type="button"
    class="role-card"
    :style="{ '--accent': swatch.accent }"
    @click="$emit('open')"
  >
    <span class="role-card__rail" aria-hidden="true" />
    <span
      class="role-card__icon"
      :style="{ background: swatch.background, color: swatch.iconColor }"
      aria-hidden="true"
    >
      <slot name="icon">●</slot>
    </span>

    <span class="role-card__body">
      <span class="role-card__head">
        <span class="role-card__title">{{ role.label }}</span>
        <span
          v-if="role.is_system"
          class="role-card__badge"
          :style="{ background: swatch.background, color: swatch.iconColor }"
          >SISTEM</span
        >
      </span>
      <span class="role-card__subtitle">
        <template v-if="memberCount != null"
          >{{ memberCount }} anggota</template
        >
        <template v-if="subtitle">
          <span class="role-card__sep" aria-hidden="true">·</span>{{ subtitle }}
        </template>
      </span>
    </span>

    <span class="role-card__count">
      <span class="role-card__count-num">{{ permissionCount }}</span>
      <span class="role-card__count-label">permissions</span>
    </span>

    <button
      type="button"
      class="role-card__more"
      aria-label="More actions"
      @click.stop="$emit('more')"
    >
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
        <circle cx="4" cy="9" r="1.4" fill="#64748B" />
        <circle cx="9" cy="9" r="1.4" fill="#64748B" />
        <circle cx="14" cy="9" r="1.4" fill="#64748B" />
      </svg>
    </button>
  </button>
</template>

<style scoped>
.role-card {
  display: grid;
  grid-template-columns: 4px 32px 1fr auto 40px;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 14px 14px 14px 0;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  cursor: pointer;
  text-align: left;
  transition: box-shadow 120ms ease;
}
.role-card:hover {
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
}
.role-card__rail {
  align-self: stretch;
  width: 4px;
  background: var(--accent);
  border-radius: 0 2px 2px 0;
}
.role-card__icon {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  font-weight: 800;
  margin-left: 18px;
}
.role-card__body {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}
.role-card__head {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.role-card__title {
  font-size: 14px;
  font-weight: 800;
  color: #0f172a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.role-card__badge {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.4px;
  padding: 2px 6px;
  border-radius: 6px;
}
.role-card__subtitle {
  font-size: 12px;
  color: #64748b;
}
.role-card__sep {
  margin: 0 6px;
}
.role-card__count {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}
.role-card__count-num {
  font-size: 22px;
  font-weight: 800;
  color: #0f172a;
  line-height: 1;
}
.role-card__count-label {
  font-size: 10px;
  color: #94a3b8;
  margin-top: 4px;
}
.role-card__more {
  width: 40px;
  height: 32px;
  display: grid;
  place-items: center;
  background: #f1f5f9;
  border: 0;
  border-radius: 8px;
  cursor: pointer;
}
.role-card__more:hover {
  background: #e2e8f0;
}
</style>
