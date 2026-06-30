<script setup lang="ts">
/**
 * One collapsible card per permission module (Finance, Attendance,
 * Communication, dst). Header shows module name + "N of M selected"
 * + chevron; body lists every permission in that module.
 *
 * Two-column rendering on wide screens — keeps long catalogs from
 * forcing the user to scroll for minutes.
 */
import { computed } from 'vue';
import type { RbacPermission } from '@/types/rbac';
import PermissionCheckboxRow from './PermissionCheckboxRow.vue';

const props = defineProps<{
  module: string;
  permissions: RbacPermission[];
  /** Currently-staged keys (controlled). */
  selectedKeys: Set<string>;
  isOpen: boolean;
}>();

const emit = defineEmits<{
  (e: 'toggleOpen'): void;
  (e: 'togglePermission', key: string): void;
}>();

const selectedInModule = computed(
  () => props.permissions.filter((p) => props.selectedKeys.has(p.key)).length,
);

const moduleLabel = computed(() => {
  const map: Record<string, string> = {
    finance: 'Finance',
    attendance: 'Attendance',
    academic: 'Academic',
    communication: 'Communication',
    activity: 'Activity (Kelas)',
    dashboard: 'Dashboard',
    school: 'School data',
    rbac: 'Roles & permissions',
  };
  return map[props.module] ?? props.module;
});

const halfPoint = computed(() => Math.ceil(props.permissions.length / 2));
const leftColumn = computed(() => props.permissions.slice(0, halfPoint.value));
const rightColumn = computed(() => props.permissions.slice(halfPoint.value));

function onToggle(key: string) {
  emit('togglePermission', key);
}
</script>

<template>
  <section class="perm-acc" :class="{ 'perm-acc--open': isOpen }">
    <button
      type="button"
      class="perm-acc__head"
      :aria-expanded="isOpen"
      @click="emit('toggleOpen')"
    >
      <span class="perm-acc__icon" aria-hidden="true">
        <slot name="icon" />
      </span>
      <span class="perm-acc__title">
        <span class="perm-acc__name">{{ moduleLabel }}</span>
        <span class="perm-acc__count">
          {{ selectedInModule }} dari {{ permissions.length }} dipilih
        </span>
      </span>
      <span class="perm-acc__chev" :class="{ 'perm-acc__chev--open': isOpen }">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
          <path
            d="M5 7 L9 11 L13 7"
            stroke="#94a3b8"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </span>
    </button>
    <div v-if="isOpen" class="perm-acc__body">
      <div class="perm-acc__col">
        <PermissionCheckboxRow
          v-for="p in leftColumn"
          :key="p.key"
          :permission="p"
          :checked="selectedKeys.has(p.key)"
          @toggle="onToggle(p.key)"
        />
      </div>
      <div class="perm-acc__col">
        <PermissionCheckboxRow
          v-for="p in rightColumn"
          :key="p.key"
          :permission="p"
          :checked="selectedKeys.has(p.key)"
          @toggle="onToggle(p.key)"
        />
      </div>
    </div>
  </section>
</template>

<style scoped>
.perm-acc {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  overflow: hidden;
}
.perm-acc__head {
  width: 100%;
  display: grid;
  grid-template-columns: 32px 1fr 24px;
  align-items: center;
  gap: 12px;
  padding: 14px 18px;
  background: transparent;
  border: 0;
  cursor: pointer;
  text-align: left;
}
.perm-acc__head:hover {
  background: #f8fafc;
}
.perm-acc__icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: #f1f5f9;
  display: grid;
  place-items: center;
}
.perm-acc__title {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.perm-acc__name {
  font-size: 13px;
  font-weight: 800;
  color: #0f172a;
}
.perm-acc__count {
  font-size: 10px;
  color: #64748b;
}
.perm-acc__chev {
  transition: transform 180ms ease;
}
.perm-acc__chev--open {
  transform: rotate(180deg);
}
.perm-acc__body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  border-top: 1px solid #f1f5f9;
}
.perm-acc__col {
  padding: 8px;
  border-right: 1px solid #f1f5f9;
}
.perm-acc__col:last-child {
  border-right: 0;
}
@media (max-width: 768px) {
  .perm-acc__body {
    grid-template-columns: 1fr;
  }
}
</style>
