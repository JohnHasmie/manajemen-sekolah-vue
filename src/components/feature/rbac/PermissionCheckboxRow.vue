<script setup lang="ts">
/**
 * Single permission row inside a [PermissionModuleAccordion].
 *
 * The human-readable label leads — a principal reads "Lihat tagihan",
 * not `finance.bill.view`. The description sits below it, and the raw
 * catalog key is kept as a small muted technical reference at the end
 * (useful for support, invisible to everyone else).
 */
import type { RbacPermission } from '@/types/rbac';

defineProps<{
  permission: RbacPermission;
  checked: boolean;
  readonly?: boolean;
}>();

defineEmits<{
  (e: 'toggle'): void;
}>();
</script>

<template>
  <label
    class="perm-row"
    :class="{ 'perm-row--readonly': readonly }"
    @click.prevent="!readonly && $emit('toggle')"
  >
    <span
      class="perm-row__box"
      :class="{ 'perm-row__box--checked': checked }"
      aria-hidden="true"
    >
      <svg v-if="checked" width="10" height="10" viewBox="0 0 14 14" fill="none">
        <path
          d="M2 7 L6 11 L12 4"
          stroke="#ffffff"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </span>
    <span class="perm-row__body">
      <span class="perm-row__label">{{ permission.label }}</span>
      <span v-if="permission.description" class="perm-row__desc">{{
        permission.description
      }}</span>
      <span class="perm-row__key">{{ permission.key }}</span>
    </span>
  </label>
</template>

<style scoped>
.perm-row {
  display: grid;
  grid-template-columns: 18px 1fr;
  align-items: start;
  gap: 12px;
  padding: 10px 14px;
  cursor: pointer;
  border-radius: 10px;
}
.perm-row:hover {
  background: #f8fafc;
}
.perm-row--readonly {
  cursor: default;
  opacity: 0.7;
}
.perm-row__box {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  border: 1.4px solid #e2e8f0;
  display: grid;
  place-items: center;
  margin-top: 2px;
  background: #ffffff;
  transition: background 120ms ease, border-color 120ms ease;
}
.perm-row__box--checked {
  background: #143068;
  border-color: #143068;
}
.perm-row__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.perm-row__label {
  font-size: 13px;
  font-weight: 600;
  color: #0f172a;
}
.perm-row__desc {
  font-size: 11px;
  color: #64748b;
}
.perm-row__key {
  font-family: ui-monospace, Menlo, monospace;
  font-size: 10px;
  color: #94a3b8;
}

/* Tutoring tenant (dark). */
:global(.rbac-shell--tutoring) .perm-row:hover {
  background: #14182a;
}
:global(.rbac-shell--tutoring) .perm-row__box {
  background: #0b1227;
  border-color: #1b2235;
}
:global(.rbac-shell--tutoring) .perm-row__box--checked {
  background: #21afe6;
  border-color: #21afe6;
}
:global(.rbac-shell--tutoring) .perm-row__label {
  color: #f1f5f9;
}
:global(.rbac-shell--tutoring) .perm-row__key,
:global(.rbac-shell--tutoring) .perm-row__desc {
  color: #94a3b8;
}
</style>
