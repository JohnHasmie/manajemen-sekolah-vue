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
import { useRouter } from 'vue-router';

import MemberPickerRow from '@/components/feature/rbac/MemberPickerRow.vue';
import MemberAvatar from '@/components/feature/rbac/MemberAvatar.vue';
import AssignConfirmationModal from '@/components/feature/rbac/AssignConfirmationModal.vue';
import { useRbacStore } from '@/stores/rbac';
import { useMe } from '@/composables/useMe';

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
const router = useRouter();
const { can } = useMe();
const {
  pickerQuery,
  pickerResults,
  pickerSelected,
  pickerLoading,
  pickerTotal,
  pickerPage,
  pickerLastPage,
} = storeToRefs(rbac);

// Whether we've rendered the tail — used to hide the "Muat lebih banyak"
// button once the last page has been fetched. Fla report 2026-07-17:
// modal said "255 USER" total but only page-1 (~20 rows) was scrollable
// because the picker had no pagination affordance.
const hasMore = computed(
  () => pickerPage.value < pickerLastPage.value && !pickerLoading.value,
);

function loadMore() {
  void rbac.loadMorePicker(props.schoolId, props.roleId);
}

// "+ Tambah staf baru" shortcut — jumps to Data Staf's create form with this
// role pre-selected, for people who aren't in the system yet. Only shown to
// admins who can actually manage staff (the Data Staf page needs it too).
const canCreateStaff = computed(() => can('school.staff.manage'));

function createNewStaff() {
  emit('close');
  void router.push({
    name: 'admin.staff',
    query: {
      create: '1',
      role_id: String(props.roleId),
      role_label: props.roleLabel,
    },
  });
}

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

      <button
        v-if="canCreateStaff"
        type="button"
        class="amm__newstaff"
        @click="createNewStaff"
      >
        <span class="amm__newstaff-plus" aria-hidden="true">＋</span>
        <span class="amm__newstaff-body">
          <span class="amm__newstaff-title">Tambah staf baru</span>
          <span class="amm__newstaff-sub">
            Orang belum ada di sistem → buat &amp; beri role ini
          </span>
        </span>
        <span class="amm__newstaff-go" aria-hidden="true">›</span>
      </button>

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
          <li v-if="hasMore" class="amm__load-more-wrap">
            <button
              type="button"
              class="amm__load-more"
              :disabled="pickerLoading"
              @click="loadMore"
            >
              Muat lebih banyak
              <span class="amm__load-more-count">({{ pickerResults.length }} / {{ pickerTotal }})</span>
            </button>
          </li>
          <li v-else-if="pickerLoading" class="amm__load-more-wrap amm__load-more-wrap--busy">
            Memuat…
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
.amm__newstaff {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 12px 24px 0;
  padding: 11px 14px;
  background: #ffffff;
  border: 1.5px dashed #fcd9a1;
  border-radius: 12px;
  cursor: pointer;
  text-align: left;
  width: calc(100% - 48px);
}
.amm__newstaff:hover {
  background: #fffbeb;
  border-color: #f59e0b;
}
.amm__newstaff-plus {
  width: 34px;
  height: 34px;
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  border-radius: 10px;
  background: #fef3c7;
  color: #b45309;
  font-size: 18px;
  font-weight: 700;
}
.amm__newstaff-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.amm__newstaff-title {
  font-size: 13px;
  font-weight: 800;
  color: #12203b;
}
.amm__newstaff-sub {
  font-size: 11px;
  color: #7688a4;
}
.amm__newstaff-go {
  color: #94a3b8;
  font-size: 18px;
  flex: 0 0 auto;
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
.amm__load-more-wrap {
  padding: 8px 0 4px;
  display: flex;
  justify-content: center;
}
.amm__load-more-wrap--busy {
  color: #64748b;
  font-size: 12px;
  font-weight: 600;
}
.amm__load-more {
  background: white;
  border: 1px solid #cbd5e1;
  border-radius: 10px;
  padding: 8px 14px;
  font-size: 12px;
  font-weight: 700;
  color: #334155;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.amm__load-more:hover:not(:disabled) {
  background: #f8fafc;
  border-color: #94a3b8;
}
.amm__load-more:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.amm__load-more-count {
  color: #94a3b8;
  font-weight: 500;
  margin-left: 6px;
  font-variant-numeric: tabular-nums;
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
