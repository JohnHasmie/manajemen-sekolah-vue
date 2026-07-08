<!--
  RolePicker.vue — shown when the user has multiple roles in the chosen school.
  Mirrors `selection_helper.dart`'s role-list step (Frame E).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { storage, StorageKeys } from '@/lib/storage';
import type { Role } from '@/types/auth';

// Local mirror of auth.ts's normalizeRole. Kept as a small inline
// helper — the picker only needs the enough-to-compare form and
// exporting the store-local one would leak an internal contract.
function normalizeRoleForCompare(r: string | null | undefined): string {
  if (!r || typeof r !== 'string') return '';
  const low = r.toLowerCase();
  if (low === 'admin' || low === 'administrator') return 'admin';
  if (low === 'guru' || low === 'teacher' || low === 'wali_kelas') return 'guru';
  if (
    low === 'wali' ||
    low === 'parent' ||
    low === 'orang_tua' ||
    low === 'wali_murid' ||
    low === 'walimurid'
  )
    return 'wali';
  if (low === 'staff' || low === 'staf') return 'staff';
  return low;
}

const { t } = useI18n();
const auth = useAuthStore();

const candidateRole = ref<Role | null>(null);

// Fast-path for returning users. The auth store used to auto-submit
// the picker when a cached role from a previous session matched one
// of the current options — Yahya (2026-07-08) reported the picker
// flashing on-screen for a fraction of a second before vanishing.
// Now the picker always mounts; the cached role just pre-highlights
// so "Lanjutkan" is one click for the common case.
onMounted(() => {
  const stored = storage.get<Role>(StorageKeys.role);
  if (!stored) return;
  const normStored = normalizeRoleForCompare(stored);
  const match = (auth.roles as string[]).find(
    (r) => normalizeRoleForCompare(r) === normStored,
  );
  if (match) candidateRole.value = match as Role;
});

const schoolName = computed(() => 
  auth.lastResponse?.selectedSchool?.school_name || 
  auth.lastResponse?.selectedSchool?.name || 
  auth.lastResponse?.school?.school_name || 
  auth.lastResponse?.school?.name || 
  auth.lastResponse?.sekolah?.school_name || 
  auth.lastResponse?.sekolah?.name || 
  auth.user?.school_name ||
  '-'
);

const roles = computed(() => auth.roles || []);
const activeRole = computed(() => candidateRole.value || roles.value[0]);

const labels = computed<Record<string, string>>(() => ({
  admin: t('auth.role.adminLabel'),
  administrator: t('auth.role.adminLabel'),
  guru: t('auth.role.teacherLabel'),
  teacher: t('auth.role.teacherLabel'),
  wali: t('auth.role.parentLabel'),
  parent: t('auth.role.parentLabel'),
  orang_tua: t('auth.role.parentLabel'),
  staff: t('auth.role.staffLabel'),
}));

const shortLabels: Record<string, string> = {
  admin: 'ADMIN',
  administrator: 'ADMIN',
  guru: 'GURU',
  teacher: 'GURU',
  wali: 'WALI',
  parent: 'WALI',
  orang_tua: 'WALI',
  staff: 'STAF',
};

const descriptions = computed<Record<string, string>>(() => ({
  admin: t('auth.role.adminDescription'),
  administrator: t('auth.role.adminDescription'),
  guru: t('auth.role.teacherDescription'),
  teacher: t('auth.role.teacherDescription'),
  wali: t('auth.role.parentDescription'),
  parent: t('auth.role.parentDescription'),
  orang_tua: t('auth.role.parentDescription'),
  staff: t('auth.role.staffDescription'),
}));

const stats = computed<Record<string, string[]>>(() => ({
  admin: [t('auth.role.adminStat1'), t('auth.role.adminStat2')],
  guru: [t('auth.role.teacherStat1'), t('auth.role.teacherStat2')],
  wali: [t('auth.role.parentStat1'), t('auth.role.parentStat2')],
  staff: [t('auth.role.staffStat1')],
}));

function getRoleColor(role: string) {
  const r = role.toLowerCase();
  if (r.includes('admin')) return {
    border: 'border-brand-dark-blue',
    bg: 'bg-brand-dark-blue',
    shadow: 'shadow-brand-dark-blue/30',
    text: 'text-brand-dark-blue'
  };
  if (r.includes('guru') || r.includes('teacher') || r.includes('staff')) return {
    border: 'border-brand-cobalt',
    bg: 'bg-brand-cobalt',
    shadow: 'shadow-brand-cobalt/30',
    text: 'text-brand-cobalt'
  };
  if (r.includes('wali') || r.includes('parent')) return {
    border: 'border-brand-azure',
    bg: 'bg-brand-azure',
    shadow: 'shadow-brand-azure/30',
    text: 'text-brand-azure'
  };
  return {
    border: 'border-brand-cobalt',
    bg: 'bg-brand-cobalt',
    shadow: 'shadow-brand-cobalt/30',
    text: 'text-brand-cobalt'
  };
}

function getRoleIcon(role: string) {
  const r = role.toLowerCase();
  if (r.includes('admin')) return 'shield';
  if (r.includes('guru') || r.includes('teacher')) return 'school';
  if (r.includes('wali') || r.includes('parent')) return 'users';
  return 'user';
}

async function handleConfirm() {
  if (!activeRole.value) return;
  try {
    await auth.selectRole(activeRole.value);
  } catch {
    // toast in LoginView
  }
}
</script>

<template>
  <div class="space-y-5">
    <header>
      <div class="text-3xs font-black text-slate-400 tracking-[1px] uppercase mb-1 truncate">
        {{ schoolName.toUpperCase() }}
      </div>
      <h2 class="text-[17px] font-black text-slate-900 tracking-[-0.3px]">
        {{ t('auth.role.title') }}
      </h2>
      <p class="text-[12px] text-slate-500 font-semibold mt-0.5">
        {{ roles.length <= 1 ? t('auth.role.subtitleSingle') : t('auth.role.subtitleMultiple', { count: roles.length }) }}
      </p>
      
      <!-- Step Dots -->
      <div class="flex gap-1.5 mt-3">
        <div class="w-1.5 h-1.5 rounded-full bg-slate-200"></div>
        <div class="w-1.5 h-1.5 rounded-full bg-brand-cobalt"></div>
        <div class="w-1.5 h-1.5 rounded-full bg-slate-200"></div>
      </div>
    </header>

    <div class="space-y-3">
      <button
        v-for="r in roles" :key="r"
        type="button"
        class="relative w-full text-left rounded-2xl border bg-white p-4 transition-all group overflow-hidden"
        :class="activeRole === r 
          ? `${getRoleColor(r).border} shadow-lg ${getRoleColor(r).shadow}` 
          : 'border-slate-200 hover:border-slate-300'"
        @click="candidateRole = r"
      >
        <!-- Left accent bar -->
        <div 
          class="absolute inset-y-0 left-0 w-1.5"
          :class="getRoleColor(r).bg"
        ></div>

        <div class="flex items-start gap-4">
          <!-- Icon Circle -->
          <div 
            class="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 transition-colors"
            :class="activeRole === r ? `${getRoleColor(r).bg} text-white` : 'bg-slate-100 text-slate-400'"
          >
            <svg v-if="getRoleIcon(r) === 'shield'" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            <svg v-else-if="getRoleIcon(r) === 'school'" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 10v6M2 10l10-5 10 5-10 5z"/><path d="M6 12v5c0 1.1.9 2 2 2h8a2 2 0 0 0 2-2v-5"/></svg>
            <svg v-else-if="getRoleIcon(r) === 'users'" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          </div>

          <div class="flex-1 min-w-0">
            <h3 class="text-[14px] font-black text-slate-900 leading-tight">{{ labels[r] || r }}</h3>
            <p class="text-2xs font-semibold text-slate-500 mt-1 leading-relaxed">
              {{ descriptions[r] || '' }}
            </p>

            <!-- Stats Row -->
            <div v-if="stats[r]" class="flex flex-wrap gap-x-3 gap-y-1 mt-2.5">
              <div v-for="s in stats[r]" :key="s" class="flex items-center gap-1">
                <div class="w-1 h-1 rounded-full bg-slate-300"></div>
                <span class="text-3xs font-bold text-slate-400 uppercase tracking-tight">{{ s }}</span>
              </div>
            </div>
          </div>
        </div>
      </button>
    </div>

    <!-- Info Box -->
    <div class="bg-slate-50 border border-slate-200 rounded-xl p-3 flex items-start gap-3">
      <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="text-slate-400 mt-0.5"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
      <p class="text-2xs font-semibold text-slate-600 leading-relaxed">
        {{ t('auth.role.switchInfo') }}
      </p>
    </div>

    <!-- Footer CTA -->
    <div class="space-y-3 pt-2">
      <button
        type="button"
        :disabled="!activeRole || auth.isLoading"
        class="w-full rounded-xl text-white font-black py-[14px] shadow-lg transition-all flex items-center justify-center gap-2 hover:opacity-90 disabled:bg-slate-300 disabled:shadow-none"
        :class="activeRole ? `${getRoleColor(activeRole).bg} ${getRoleColor(activeRole).shadow}` : 'bg-slate-300'"
        @click="handleConfirm"
      >
        <template v-if="auth.isLoading">
          <svg class="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" stroke-opacity="0.25" />
            <path d="M22 12a10 10 0 0 1-10 10" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
          </svg>
          <span class="text-[13.5px] tracking-wide uppercase">{{ t('auth.processing') }}</span>
        </template>
        <template v-else>
          <span class="text-[13.5px] tracking-wide uppercase">
            {{ activeRole ? t('auth.role.continueButton', { role: shortLabels[activeRole] || activeRole.toUpperCase() }) : 'LANJUTKAN' }}
          </span>
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
        </template>
      </button>

      <button
        type="button"
        class="w-full text-center text-[12px] font-extrabold text-slate-500 hover:text-slate-800"
        @click="auth.goBack()"
      >
        {{ t('auth.notYourAccountLogout') }}
      </button>
    </div>
  </div>
</template>
