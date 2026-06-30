<script setup lang="ts">
/**
 * One row in the multi-select members picker (AddMembersModal).
 *
 * Disabled state for users that already hold the target role —
 * `already_in_excluded_role: true` flips the checkbox to a
 * success-green tick on a frosted background and stops onClick from
 * firing.
 */
import { computed } from 'vue';
import type { RbacMemberSummary } from '@/types/rbac';
import MemberAvatar from './MemberAvatar.vue';

const props = defineProps<{
  user: RbacMemberSummary;
  selected: boolean;
}>();

defineEmits<{
  (e: 'toggle'): void;
}>();

const initials = computed(() => {
  const parts = props.user.name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
});

const subtitle = computed(() => {
  if (props.user.already_in_excluded_role) {
    return `${props.user.email} · sudah anggota role ini`;
  }
  if (props.user.roles.length === 0) {
    return `${props.user.email} · belum ada role lain`;
  }
  return `${props.user.email} · sudah ${props.user.roles[0].label}`;
});
</script>

<template>
  <button
    type="button"
    class="m-row"
    :class="{
      'm-row--selected': selected,
      'm-row--disabled': user.already_in_excluded_role,
    }"
    :disabled="user.already_in_excluded_role"
    @click="$emit('toggle')"
  >
    <span
      class="m-row__box"
      :class="{
        'm-row__box--checked': selected || user.already_in_excluded_role,
        'm-row__box--done': user.already_in_excluded_role,
      }"
      aria-hidden="true"
    >
      <svg
        v-if="selected || user.already_in_excluded_role"
        width="12"
        height="12"
        viewBox="0 0 14 14"
        fill="none"
      >
        <path
          d="M2 7 L6 11 L12 4"
          :stroke="user.already_in_excluded_role ? '#15803D' : '#ffffff'"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </span>
    <MemberAvatar
      :seed="user.user_id"
      :initials="initials"
      :photo-url="user.photo_url"
      :size="32"
    />
    <span class="m-row__body">
      <span class="m-row__title">{{ user.name }}</span>
      <span class="m-row__subtitle">{{ subtitle }}</span>
    </span>
  </button>
</template>

<style scoped>
.m-row {
  display: grid;
  grid-template-columns: 18px 32px 1fr;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 12px 14px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  cursor: pointer;
  text-align: left;
}
.m-row:hover {
  border-color: #cbd5e1;
}
.m-row--selected {
  background: #f1f5f9;
  border-color: #143068;
  border-width: 1.4px;
}
.m-row--disabled {
  background: #f8fafc;
  cursor: not-allowed;
  opacity: 0.75;
}
.m-row__box {
  width: 18px;
  height: 18px;
  border-radius: 5px;
  border: 1.4px solid #e2e8f0;
  display: grid;
  place-items: center;
  background: #ffffff;
}
.m-row__box--checked {
  background: #143068;
  border-color: #143068;
}
.m-row__box--done {
  background: #d1fae5;
  border-color: #15803d;
}
.m-row__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.m-row__title {
  font-size: 13px;
  font-weight: 800;
  color: #0f172a;
}
.m-row__subtitle {
  font-size: 11px;
  color: #64748b;
}
</style>
