<script setup lang="ts">
/**
 * Confirmation modal shown before the picker's batch POST lands.
 *
 * Surfaces per-user impact (which other roles the picked user already
 * holds) and warns when ≥ 1 user will end up with multiple active
 * roles. Mirrors the mobile AssignConfirmationSheet from MR !391.
 */
import { computed } from 'vue';
import type { RbacMemberSummary } from '@/types/rbac';
import MemberAvatar from './MemberAvatar.vue';

const props = defineProps<{
  open: boolean;
  roleLabel: string;
  roleType: string;
  permissionCount: number;
  selected: RbacMemberSummary[];
  submitting?: boolean;
}>();

const emit = defineEmits<{
  (e: 'cancel'): void;
  (e: 'confirm'): void;
}>();

const multiRoleCount = computed(
  () => props.selected.filter((s) => s.roles.length > 0).length,
);

function initialsFor(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
</script>

<template>
  <div v-if="open" class="acm-overlay" @click.self="emit('cancel')">
    <div class="acm" role="dialog" aria-modal="true">
      <header class="acm__head">
        <h3 class="acm__title">Konfirmasi penugasan</h3>
        <p class="acm__sub">
          {{ selected.length }} user akan mendapat role
          <strong>{{ roleLabel }}</strong>
        </p>
      </header>

      <div class="acm__body">
        <div class="acm__role">
          <div class="acm__role-icon" aria-hidden="true">
            <span>R</span>
          </div>
          <div>
            <div class="acm__role-label">{{ roleLabel }}</div>
            <div class="acm__role-meta">
              {{ roleType }} · {{ permissionCount }} permissions
            </div>
          </div>
        </div>

        <h4 class="acm__subhead">USER YANG DIPILIH</h4>
        <ul class="acm__users">
          <li v-for="u in selected" :key="u.user_id" class="acm__user">
            <MemberAvatar
              :seed="u.user_id"
              :initials="initialsFor(u.name)"
              :photo-url="u.photo_url"
              :size="28"
            />
            <div>
              <div class="acm__user-name">{{ u.name }}</div>
              <div class="acm__user-meta">
                <template v-if="u.roles.length">
                  sudah punya:
                  {{ u.roles.map((r) => r.label).join(', ') }}
                </template>
                <template v-else>belum punya role lain</template>
              </div>
            </div>
          </li>
        </ul>

        <div v-if="multiRoleCount > 0" class="acm__warn">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path
              d="M9 2 L17 16 L1 16 Z"
              fill="none"
              stroke="#A2660D"
              stroke-width="1.4"
              stroke-linejoin="round"
            />
            <path d="M9 7 V11" stroke="#A2660D" stroke-width="1.4" />
            <circle cx="9" cy="13.5" r="0.8" fill="#A2660D" />
          </svg>
          <span
            >{{ multiRoleCount }} user akan punya 2+ role aktif. Permission
            digabung.</span
          >
        </div>
      </div>

      <footer class="acm__foot">
        <button
          type="button"
          class="acm__btn acm__btn--ghost"
          :disabled="submitting"
          @click="emit('cancel')"
        >
          Batal
        </button>
        <button
          type="button"
          class="acm__btn acm__btn--primary"
          :disabled="submitting"
          @click="emit('confirm')"
        >
          <span v-if="submitting">…</span>
          <span v-else>Ya, tugaskan</span>
        </button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.acm-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
  display: grid;
  place-items: center;
  z-index: 60;
  padding: 24px;
}
.acm {
  background: #ffffff;
  border-radius: 20px;
  width: min(540px, 100%);
  max-height: calc(100vh - 48px);
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 40px rgba(15, 23, 42, 0.25);
}
.acm__head {
  padding: 24px 24px 12px;
}
.acm__title {
  margin: 0 0 4px;
  font-size: 18px;
  font-weight: 900;
  color: #0f172a;
}
.acm__sub {
  margin: 0;
  font-size: 12px;
  color: #64748b;
}
.acm__body {
  padding: 0 24px 16px;
  overflow-y: auto;
}
.acm__role {
  display: grid;
  grid-template-columns: 36px 1fr;
  gap: 12px;
  align-items: center;
  padding: 12px;
  background: #f1f5f9;
  border-radius: 12px;
  margin-bottom: 16px;
}
.acm__role-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: #e8eef7;
  display: grid;
  place-items: center;
  color: #143068;
  font-weight: 800;
}
.acm__role-label {
  font-size: 13px;
  font-weight: 800;
  color: #0f172a;
}
.acm__role-meta {
  font-size: 10px;
  color: #64748b;
}
.acm__subhead {
  margin: 0 0 8px;
  font-size: 10px;
  font-weight: 700;
  color: #64748b;
  letter-spacing: 1.4px;
}
.acm__users {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.acm__user {
  display: grid;
  grid-template-columns: 28px 1fr;
  gap: 12px;
  align-items: center;
}
.acm__user-name {
  font-size: 12px;
  font-weight: 700;
  color: #0f172a;
}
.acm__user-meta {
  font-size: 10px;
  color: #64748b;
}
.acm__warn {
  margin-top: 14px;
  display: grid;
  grid-template-columns: 18px 1fr;
  gap: 10px;
  align-items: center;
  padding: 12px;
  background: #fef3c7;
  color: #a2660d;
  border-radius: 12px;
  font-size: 11px;
}
.acm__foot {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  padding: 16px 24px;
  border-top: 1px solid #e2e8f0;
}
.acm__btn {
  padding: 10px 16px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  border: 0;
}
.acm__btn--ghost {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  color: #0f172a;
}
.acm__btn--primary {
  background: #143068;
  color: #ffffff;
  font-weight: 800;
}
.acm__btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
