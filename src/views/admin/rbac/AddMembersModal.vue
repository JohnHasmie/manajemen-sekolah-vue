<script setup lang="ts">
/**
 * Frame C · Tambah anggota (modal).
 *
 * Multi-select search picker + confirmation modal in one flow. Submit
 * goes through AssignConfirmationModal before the network call lands.
 *
 * Visual contract: web-vue/_design/rbac/AdminWeb_RBAC_School_v1.svg
 * (frame C).
 */
import { computed, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';

import MemberPickerRow from '@/components/feature/rbac/MemberPickerRow.vue';
import MemberAvatar from '@/components/feature/rbac/MemberAvatar.vue';
import AssignConfirmationModal from '@/components/feature/rbac/AssignConfirmationModal.vue';
import { useRbacStore } from '@/stores/rbac';

const props = defineProps<{
  open: boolean;
  schoolId: string;
  roleId: number;
  roleLabel: string;
  roleType: string;
  permissionCount: number;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done'): void;
}>();

const rbac = useRbacStore();
const {
  pickerQuery,
  pickerResults,
  pickerSelected,
  pickerLoading,
  pickerTotal,
} = storeToRefs(rbac);

const confirmOpen = ref(false);
const submitting = ref(false);
const toastMessage = ref<string | null>(null);

watch(
  () => props.open,
  (next) => {
    if (next) {
      rbac.resetPicker();
      // Initial search with empty query loads the first page.
      void rbac.runPickerSearch(props.schoolId, props.roleId);
    }
  },
);

function onSearch(e: Event) {
  const value = (e.target as HTMLInputElement).value;
  rbac.setPickerQuery(value, props.schoolId, props.roleId);
}

function initialsFor(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

async function confirmAssign() {
  submitting.value = true;
  const result = await rbac.submitPicker(props.schoolId, props.roleId);
  submitting.value = false;
  confirmOpen.value = false;
  if (result) {
    const assigned = result.assigned.length;
    const skipped =
      result.already_member.length + result.not_in_school.length;
    toastMessage.value =
      skipped === 0
        ? `${assigned} user ditugaskan`
        : `${assigned} user ditugaskan · ${skipped} dilewati`;
    emit('done');
  }
}

const canSubmit = computed(() => pickerSelected.value.length > 0);
</script>

<template>
  <div v-if="open" class="amm-overlay" @click.self="emit('close')">
    <div class="amm" role="dialog" aria-modal="true">
      <header class="amm__head">
        <div>
          <h3 class="amm__title">Tambah anggota</h3>
          <p class="amm__sub">
            ke role <strong>{{ roleLabel }}</strong>
          </p>
        </div>
        <button
          type="button"
          class="amm__close"
          aria-label="Tutup"
          @click="emit('close')"
        >
          ×
        </button>
      </header>

      <div class="amm__search">
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
          :value="pickerQuery"
          @input="onSearch"
          autofocus
        />
      </div>

      <div v-if="pickerSelected.length" class="amm__chips">
        <span class="amm__chips-label">DIPILIH · {{ pickerSelected.length }}</span>
        <div class="amm__chips-row">
          <button
            v-for="m in pickerSelected"
            :key="m.user_id"
            type="button"
            class="amm__chip"
            @click="rbac.unselectPicker(m.user_id)"
          >
            <MemberAvatar
              :seed="m.user_id"
              :initials="initialsFor(m.name)"
              :photo-url="m.photo_url"
              :size="22"
            />
            <span>{{ m.name }}</span>
            <span class="amm__chip-x" aria-hidden="true">×</span>
          </button>
        </div>
      </div>

      <div class="amm__results">
        <div class="amm__results-head">
          HASIL · {{ pickerTotal }} USER
        </div>
        <div v-if="pickerLoading && !pickerResults.length" class="amm__loading">
          Mencari…
        </div>
        <ul v-else-if="pickerResults.length" class="amm__list">
          <li v-for="u in pickerResults" :key="u.user_id">
            <MemberPickerRow
              :user="u"
              :selected="pickerSelected.some((s) => s.user_id === u.user_id)"
              @toggle="rbac.togglePickerSelection(u)"
            />
          </li>
        </ul>
        <div v-else class="amm__empty">Tidak ada user yang cocok.</div>
      </div>

      <footer class="amm__foot">
        <button
          type="button"
          class="amm__btn amm__btn--ghost"
          @click="emit('close')"
        >
          Batal
        </button>
        <button
          type="button"
          class="amm__btn amm__btn--primary"
          :disabled="!canSubmit"
          @click="confirmOpen = true"
        >
          Tambahkan {{ pickerSelected.length }} user
        </button>
      </footer>
    </div>

    <AssignConfirmationModal
      :open="confirmOpen"
      :role-label="roleLabel"
      :role-type="roleType"
      :permission-count="permissionCount"
      :selected="pickerSelected"
      :submitting="submitting"
      @cancel="confirmOpen = false"
      @confirm="confirmAssign"
    />

    <div v-if="toastMessage" class="amm__toast" @animationend="toastMessage = null">
      {{ toastMessage }}
    </div>
  </div>
</template>

<style scoped>
.amm-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
  display: grid;
  place-items: center;
  z-index: 50;
  padding: 24px;
}
.amm {
  background: #ffffff;
  border-radius: 20px;
  width: min(660px, 100%);
  max-height: calc(100vh - 48px);
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 40px rgba(15, 23, 42, 0.25);
}
.amm__head {
  display: flex;
  justify-content: space-between;
  align-items: start;
  padding: 24px 24px 12px;
}
.amm__title {
  margin: 0 0 4px;
  font-size: 20px;
  font-weight: 900;
  color: #0f172a;
}
.amm__sub {
  margin: 0;
  font-size: 12px;
  color: #64748b;
}
.amm__close {
  background: #f1f5f9;
  border: 0;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  font-size: 18px;
  cursor: pointer;
  color: #64748b;
}
.amm__close:hover {
  background: #e2e8f0;
}
.amm__search {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0 24px;
  padding: 10px 12px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
}
.amm__search input {
  flex: 1;
  border: 0;
  background: transparent;
  outline: none;
  font-size: 13px;
  font-weight: 500;
  color: #0f172a;
}
.amm__chips {
  margin: 16px 24px 0;
}
.amm__chips-label {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  color: #64748b;
}
.amm__chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 8px;
}
.amm__chip {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 4px 8px;
  background: #143068;
  color: #ffffff;
  border: 0;
  border-radius: 16px;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
}
.amm__chip-x {
  font-size: 14px;
}
.amm__results {
  margin: 16px 24px 0;
  flex: 1;
  overflow-y: auto;
}
.amm__results-head {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  color: #64748b;
  margin-bottom: 8px;
}
.amm__loading,
.amm__empty {
  padding: 24px;
  text-align: center;
  color: #64748b;
  background: #f8fafc;
  border-radius: 12px;
  font-size: 13px;
}
.amm__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.amm__foot {
  display: grid;
  grid-template-columns: 120px 1fr;
  gap: 12px;
  padding: 20px 24px;
  border-top: 1px solid #e2e8f0;
  margin-top: 16px;
}
.amm__btn {
  padding: 12px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  border: 0;
}
.amm__btn--ghost {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  color: #0f172a;
}
.amm__btn--primary {
  background: #143068;
  color: #ffffff;
  font-weight: 800;
}
.amm__btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.amm__toast {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  padding: 12px 24px;
  background: #0f172a;
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.3);
  animation: amm-toast 3s ease forwards;
  z-index: 70;
}
@keyframes amm-toast {
  0% {
    opacity: 0;
    transform: translate(-50%, 20px);
  }
  10%,
  85% {
    opacity: 1;
    transform: translate(-50%, 0);
  }
  100% {
    opacity: 0;
    transform: translate(-50%, 20px);
  }
}
</style>
