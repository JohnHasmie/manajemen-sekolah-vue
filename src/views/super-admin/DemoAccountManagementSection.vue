<!--
  DemoAccountManagementSection.vue — "Kelola Akun Demo".

  Drop-in section for the super-admin demo-request detail page. Shows the
  account counts of an ACTIVATED demo school grouped by role, with four
  destructive actions:
    • Hapus semua akun
    • Hapus akun guru
    • Hapus akun admin
    • Hapus akun orang tua

  SAFETY
  ------
  Every delete is IRREVERSIBLE and double-guarded:
    1. Server-side: the `super_admin` middleware + DeleteDemoSchoolAccounts
       Action re-asserts schools.is_demo=true (a real tenant can NEVER be
       wiped — a non-demo target returns 422).
    2. Client-side: a confirmation modal that requires the operator to
       TYPE the exact confirmation word ("HAPUS") before the button
       unlocks, and clearly states the action cannot be undone.

  Beyond the per-account actions, a clearly-separated DANGER ZONE offers
  "Hapus Sekolah Demo (beserta semua data)" — deleting the ENTIRE demo
  school (the school row + every piece of provisioned data). That action
  requires a STRONGER confirmation: the operator must type the exact
  school name OR the literal "HAPUS". On success the parent navigates
  back to the demo-requests list (the school no longer exists).

  Props:
    schoolId   — the activated demo school's UUID (from the demo
                 request's `activated_school_id`).
    schoolName — the demo school's name, shown in the danger-zone copy
                 and accepted as a strong confirmation token.

  Emits:
    deleted       — fired after a successful ACCOUNT delete so the parent
                    can refresh / show a toast.
    schoolDeleted — fired after the WHOLE school is deleted so the parent
                    can toast + navigate back to the list.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { DemoAccountService } from '@/services/demo-account.service';
import type {
  DeleteDemoSchoolResult,
  DemoAccountCounts,
  DemoAccountDeleteMode,
  DemoAccountDeleteResult,
} from '@/types/demo-account';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';

const props = defineProps<{ schoolId: string; schoolName?: string | null }>();
const emit = defineEmits<{
  deleted: [result: DemoAccountDeleteResult];
  schoolDeleted: [result: DeleteDemoSchoolResult];
}>();

const { t } = useI18n();

// The word the operator must type to unlock a delete. Locale-agnostic
// (same in id + en) so it stays unambiguous.
const CONFIRM_WORD = 'HAPUS';

// ── Counts state ────────────────────────────────────────────────────
const counts = ref<DemoAccountCounts | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

async function loadCounts() {
  if (!props.schoolId) return;
  isLoading.value = true;
  loadError.value = null;
  try {
    counts.value = await DemoAccountService.counts(props.schoolId);
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(loadCounts);

// ── Delete confirmation modal ───────────────────────────────────────
const pendingMode = ref<DemoAccountDeleteMode | null>(null);
const confirmInput = ref('');
const deleting = ref(false);
const deleteError = ref<string | null>(null);

// Per-mode count + label so the modal can say exactly what will go.
function countFor(mode: DemoAccountDeleteMode): number {
  const c = counts.value;
  if (!c) return 0;
  switch (mode) {
    case 'all':
      return c.total_accounts;
    case 'guru':
      return c.by_role.guru;
    case 'admin':
      return c.by_role.admin;
    case 'wali':
      return c.by_role.wali;
  }
}

function modeLabel(mode: DemoAccountDeleteMode): string {
  return t(`superAdmin.demoAccounts.mode.${mode}`);
}

const pendingCount = computed(() =>
  pendingMode.value ? countFor(pendingMode.value) : 0,
);

const confirmUnlocked = computed(
  () => confirmInput.value.trim().toUpperCase() === CONFIRM_WORD,
);

function startDelete(mode: DemoAccountDeleteMode) {
  pendingMode.value = mode;
  confirmInput.value = '';
  deleteError.value = null;
}

function cancelDelete() {
  pendingMode.value = null;
  confirmInput.value = '';
  deleteError.value = null;
}

async function confirmDelete() {
  if (!pendingMode.value || !confirmUnlocked.value) return;
  deleting.value = true;
  deleteError.value = null;
  try {
    const result = await DemoAccountService.deleteAccounts(
      props.schoolId,
      pendingMode.value,
    );
    emit('deleted', result);
    cancelDelete();
    // Refresh counts so the panel reflects what's left.
    await loadCounts();
  } catch (e) {
    deleteError.value = (e as Error).message;
  } finally {
    deleting.value = false;
  }
}

// ── Delete-ENTIRE-school flow ───────────────────────────────────────
// Stronger confirmation: type the exact school name OR "HAPUS".
const schoolDeleteOpen = ref(false);
const schoolConfirmInput = ref('');
const deletingSchool = ref(false);
const schoolDeleteError = ref<string | null>(null);

// Trimmed school name (may be empty if the parent didn't pass one).
const schoolNameTrimmed = computed(() => (props.schoolName ?? '').trim());

// Unlock when the operator typed "HAPUS" OR the exact school name
// (case-insensitive, trimmed) — same contract the backend enforces.
const schoolConfirmUnlocked = computed(() => {
  const v = schoolConfirmInput.value.trim();
  if (v.toUpperCase() === CONFIRM_WORD) return true;
  const name = schoolNameTrimmed.value;
  return name.length > 0 && v.toLowerCase() === name.toLowerCase();
});

function startSchoolDelete() {
  schoolDeleteOpen.value = true;
  schoolConfirmInput.value = '';
  schoolDeleteError.value = null;
}

function cancelSchoolDelete() {
  schoolDeleteOpen.value = false;
  schoolConfirmInput.value = '';
  schoolDeleteError.value = null;
}

async function confirmSchoolDelete() {
  if (!schoolConfirmUnlocked.value) return;
  deletingSchool.value = true;
  schoolDeleteError.value = null;
  try {
    const result = await DemoAccountService.deleteSchool(
      props.schoolId,
      schoolConfirmInput.value.trim(),
    );
    // Parent handles the toast + navigation back to the list (the
    // school is gone, so there's nothing left to refresh here).
    emit('schoolDeleted', result);
    cancelSchoolDelete();
  } catch (e) {
    schoolDeleteError.value = (e as Error).message;
  } finally {
    deletingSchool.value = false;
  }
}

// ── Display rows ────────────────────────────────────────────────────
const roleRows = computed<
  { mode: DemoAccountDeleteMode; icon: string; count: number }[]
>(() => {
  const c = counts.value;
  return [
    { mode: 'guru', icon: 'user-check', count: c?.by_role.guru ?? 0 },
    { mode: 'admin', icon: 'shield', count: c?.by_role.admin ?? 0 },
    { mode: 'wali', icon: 'users', count: c?.by_role.wali ?? 0 },
  ];
});

const hasAnyAccounts = computed(() => (counts.value?.total_accounts ?? 0) > 0);
</script>

<template>
  <section class="bg-white border border-slate-200 rounded-2xl p-4">
    <div class="flex items-center justify-between mb-3">
      <h2
        class="text-[11px] font-black uppercase tracking-widest text-role-admin flex items-center gap-2"
      >
        <NavIcon name="trash-2" :size="14" />
        {{ t('superAdmin.demoAccounts.title') }}
      </h2>
      <button
        type="button"
        class="inline-flex items-center gap-1 text-[11px] font-semibold text-slate-400 hover:text-slate-600 transition"
        :disabled="isLoading"
        @click="loadCounts"
      >
        <NavIcon name="refresh-cw" :size="12" />
        {{ t('common.refresh') }}
      </button>
    </div>

    <!-- Irreversibility warning. -->
    <div
      class="flex items-start gap-2 rounded-xl border border-red-200 bg-red-50/60 px-3 py-2 mb-3"
    >
      <span class="text-red-500 mt-0.5 flex-shrink-0">
        <NavIcon name="alert-triangle" :size="16" />
      </span>
      <p class="text-[11px] text-red-700 leading-relaxed">
        {{ t('superAdmin.demoAccounts.warning') }}
      </p>
    </div>

    <!-- LOADING -->
    <div v-if="isLoading" class="py-6 text-center text-xs text-slate-400">
      <NavIcon name="loader" :size="18" class="animate-spin mx-auto mb-2" />
      {{ t('superAdmin.demoAccounts.loading') }}
    </div>

    <!-- ERROR -->
    <div
      v-else-if="loadError"
      class="py-4 px-3 rounded-xl bg-amber-50 border border-amber-200 text-xs text-amber-700"
    >
      {{ loadError }}
      <button
        type="button"
        class="ml-1 font-bold underline"
        @click="loadCounts"
      >
        {{ t('common.retry') }}
      </button>
    </div>

    <!-- CONTENT -->
    <template v-else-if="counts">
      <!-- Per-role count grid -->
      <div class="grid grid-cols-3 gap-2 mb-3">
        <div
          v-for="row in roleRows"
          :key="row.mode"
          class="rounded-xl border border-slate-100 bg-slate-50/60 px-3 py-2.5 text-center"
        >
          <div
            class="w-7 h-7 mx-auto rounded-lg bg-white border border-slate-200 grid place-items-center text-slate-500 mb-1"
          >
            <NavIcon :name="row.icon" :size="14" />
          </div>
          <p
            class="text-lg font-black text-slate-900 tabular-nums leading-none"
          >
            {{ row.count }}
          </p>
          <p class="text-[10px] text-slate-400 mt-0.5">
            {{ modeLabel(row.mode) }}
          </p>
        </div>
      </div>

      <p class="text-[11px] text-slate-400 mb-3">
        {{
          t('superAdmin.demoAccounts.totalAccounts', {
            count: counts.total_accounts,
          })
        }}
      </p>

      <!-- Empty (nothing to delete) -->
      <p v-if="!hasAnyAccounts" class="text-xs text-slate-400 italic py-2">
        {{ t('superAdmin.demoAccounts.empty') }}
      </p>

      <!-- Delete actions -->
      <div v-else class="flex flex-col gap-2">
        <Button
          variant="secondary"
          size="sm"
          block
          :disabled="(counts.by_role.guru ?? 0) === 0"
          @click="startDelete('guru')"
        >
          <NavIcon name="user-check" :size="14" />
          {{ t('superAdmin.demoAccounts.deleteGuru') }}
        </Button>
        <Button
          variant="secondary"
          size="sm"
          block
          :disabled="(counts.by_role.admin ?? 0) === 0"
          @click="startDelete('admin')"
        >
          <NavIcon name="shield" :size="14" />
          {{ t('superAdmin.demoAccounts.deleteAdmin') }}
        </Button>
        <Button
          variant="secondary"
          size="sm"
          block
          :disabled="(counts.by_role.wali ?? 0) === 0"
          @click="startDelete('wali')"
        >
          <NavIcon name="users" :size="14" />
          {{ t('superAdmin.demoAccounts.deleteWali') }}
        </Button>
        <Button variant="danger" size="sm" block @click="startDelete('all')">
          <NavIcon name="trash-2" :size="14" />
          {{ t('superAdmin.demoAccounts.deleteAll') }}
        </Button>
      </div>
    </template>

    <!-- DANGER ZONE · DELETE THE ENTIRE DEMO SCHOOL ───────────────────
         Always available (even with zero accounts) for an activated
         demo school. Clearly separated + stronger confirmation. -->
    <div
      v-if="!isLoading && !loadError"
      class="mt-4 rounded-2xl border-2 border-red-300 bg-red-50/40 p-3.5"
    >
      <h3
        class="text-[11px] font-black uppercase tracking-widest text-red-600 flex items-center gap-2 mb-1.5"
      >
        <NavIcon name="alert-triangle" :size="14" />
        {{ t('superAdmin.demoAccounts.dangerZoneTitle') }}
      </h3>
      <p class="text-[11px] text-red-700/90 leading-relaxed mb-3">
        {{ t('superAdmin.demoAccounts.deleteSchoolWarning') }}
      </p>
      <Button variant="danger" size="sm" block @click="startSchoolDelete">
        <NavIcon name="trash-2" :size="14" />
        {{ t('superAdmin.demoAccounts.deleteSchool') }}
      </Button>
    </div>

    <!-- CONFIRMATION MODAL (typed confirmation, irreversible) -->
    <Modal
      v-if="pendingMode"
      size="sm"
      :title="t('superAdmin.demoAccounts.confirmTitle')"
      @close="cancelDelete"
    >
      <div class="space-y-3">
        <div
          class="flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2.5"
        >
          <span class="text-red-500 mt-0.5 flex-shrink-0">
            <NavIcon name="alert-triangle" :size="18" />
          </span>
          <p class="text-xs text-red-700 leading-relaxed">
            {{
              t('superAdmin.demoAccounts.confirmBody', {
                action: modeLabel(pendingMode).toLowerCase(),
                count: pendingCount,
              })
            }}
          </p>
        </div>

        <div>
          <label class="block text-[11px] font-semibold text-slate-500 mb-1">
            {{
              t('superAdmin.demoAccounts.confirmTypeLabel', {
                word: CONFIRM_WORD,
              })
            }}
          </label>
          <input
            v-model="confirmInput"
            type="text"
            autocomplete="off"
            spellcheck="false"
            :placeholder="CONFIRM_WORD"
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm font-bold tracking-widest uppercase focus:outline-none focus:ring-2 focus:ring-red-300"
            @keyup.enter="confirmUnlocked && confirmDelete()"
          />
        </div>

        <p v-if="deleteError" class="text-xs text-red-600">
          {{ deleteError }}
        </p>

        <div class="flex items-center justify-end gap-2 pt-1">
          <Button variant="ghost" size="sm" @click="cancelDelete">
            {{ t('superAdmin.demoAccounts.cancel') }}
          </Button>
          <Button
            variant="danger"
            size="sm"
            :loading="deleting"
            :disabled="!confirmUnlocked"
            @click="confirmDelete"
          >
            <NavIcon name="trash-2" :size="14" />
            {{ t('superAdmin.demoAccounts.confirmDelete') }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- DELETE-WHOLE-SCHOOL MODAL (strong typed confirmation) -->
    <Modal
      v-if="schoolDeleteOpen"
      size="sm"
      :title="t('superAdmin.demoAccounts.deleteSchoolConfirmTitle')"
      @close="cancelSchoolDelete"
    >
      <div class="space-y-3">
        <div
          class="flex items-start gap-2 rounded-xl border border-red-300 bg-red-50 px-3 py-2.5"
        >
          <span class="text-red-500 mt-0.5 flex-shrink-0">
            <NavIcon name="alert-triangle" :size="18" />
          </span>
          <p class="text-xs text-red-700 leading-relaxed">
            {{
              t('superAdmin.demoAccounts.deleteSchoolConfirmBody', {
                name:
                  schoolNameTrimmed || t('superAdmin.demoAccounts.thisSchool'),
              })
            }}
          </p>
        </div>

        <div>
          <label class="block text-[11px] font-semibold text-slate-500 mb-1">
            <template v-if="schoolNameTrimmed">
              {{
                t('superAdmin.demoAccounts.deleteSchoolTypeLabel', {
                  name: schoolNameTrimmed,
                  word: CONFIRM_WORD,
                })
              }}
            </template>
            <template v-else>
              {{
                t('superAdmin.demoAccounts.confirmTypeLabel', {
                  word: CONFIRM_WORD,
                })
              }}
            </template>
          </label>
          <input
            v-model="schoolConfirmInput"
            type="text"
            autocomplete="off"
            spellcheck="false"
            :placeholder="schoolNameTrimmed || CONFIRM_WORD"
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm font-bold focus:outline-none focus:ring-2 focus:ring-red-300"
            @keyup.enter="schoolConfirmUnlocked && confirmSchoolDelete()"
          />
        </div>

        <p v-if="schoolDeleteError" class="text-xs text-red-600">
          {{ schoolDeleteError }}
        </p>

        <div class="flex items-center justify-end gap-2 pt-1">
          <Button variant="ghost" size="sm" @click="cancelSchoolDelete">
            {{ t('superAdmin.demoAccounts.cancel') }}
          </Button>
          <Button
            variant="danger"
            size="sm"
            :loading="deletingSchool"
            :disabled="!schoolConfirmUnlocked"
            @click="confirmSchoolDelete"
          >
            <NavIcon name="trash-2" :size="14" />
            {{ t('superAdmin.demoAccounts.deleteSchoolConfirm') }}
          </Button>
        </div>
      </div>
    </Modal>
  </section>
</template>
