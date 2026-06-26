<!--
  SchoolPicker.vue — shown when the user belongs to >1 school.
  Mirrors `selection_helper.dart`'s school-list step (Frame D).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import TenantBadge from '@/components/feature/TenantBadge.vue';

const { t } = useI18n();
const auth = useAuthStore();

const query = ref('');
const candidateSchoolId = ref<string | null>(null);

const userName = computed(() => 
  auth.lastResponse?.user?.nama || 
  auth.lastResponse?.user?.name || 
  'User'
);

const schools = computed(() => auth.schools || []);

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase();
  if (!q) return schools.value;
  return schools.value.filter(s => {
    const name = (s.school_name || s.name || '').toLowerCase();
    const addr = (s.address || '').toLowerCase();
    return name.includes(q) || addr.includes(q);
  });
});

const activeId = computed(() => candidateSchoolId.value || schools.value[0]?.school_id || schools.value[0]?.id);

const utama = computed(() => filtered.value.filter(s => (s.school_id || s.id) === activeId.value));
const lainnya = computed(() => filtered.value.filter(s => (s.school_id || s.id) !== activeId.value));

const candidateName = computed(() => {
  const s = schools.value.find(x => (x.school_id || x.id) === activeId.value);
  return s?.school_name || s?.name || '';
});

function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function getGradient(name: string): string {
  const c = name.charAt(0).toUpperCase();
  const idx = c.charCodeAt(0) % 4;
  switch (idx) {
    case 0: return 'from-brand-dark-blue to-brand-cobalt';
    case 1: return 'from-teal-600 to-teal-400';
    case 2: return 'from-amber-700 to-amber-500';
    default: return 'from-brand-cobalt to-brand-azure';
  }
}

async function handleConfirm() {
  if (!activeId.value) return;
  try {
    await auth.selectSchool(activeId.value);
  } catch {
    // toast in LoginView
  }
}
</script>

<template>
  <div class="space-y-5">
    <header>
      <div class="text-[10px] font-black text-slate-400 tracking-[1px] uppercase mb-1">
        HALO, {{ userName.toUpperCase() }}
      </div>
      <h2 class="text-[17px] font-black text-slate-900 tracking-[-0.3px]">
        {{ t('auth.school.title') }}
      </h2>
      <p class="text-[12px] text-slate-500 font-semibold mt-0.5 leading-relaxed">
        {{ schools.length <= 1 ? t('auth.school.subtitleSingle') : t('auth.school.subtitleMultiple', { count: schools.length }) }}
      </p>
      
      <!-- Step Dots -->
      <div class="flex gap-1.5 mt-3">
        <div class="w-1.5 h-1.5 rounded-full bg-brand-cobalt"></div>
        <div class="w-1.5 h-1.5 rounded-full bg-slate-200"></div>
        <div class="w-1.5 h-1.5 rounded-full bg-slate-200"></div>
      </div>
    </header>

    <!-- Search Bar -->
    <div class="relative">
      <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
      </div>
      <input
        v-model="query"
        type="text"
        :placeholder="t('auth.searchSchool')"
        class="w-full rounded-xl border border-slate-200 bg-slate-50 pl-10 pr-4 py-3 text-[13px] font-semibold text-slate-900 placeholder:text-slate-400 focus:border-brand-cobalt focus:ring-0 focus:outline-none transition-all"
      />
    </div>

    <div class="max-h-[320px] overflow-y-auto pr-1 -mr-1 space-y-4">
      <!-- Utama -->
      <div v-if="utama.length > 0">
        <div class="text-[10px] font-extrabold text-slate-400 tracking-[0.8px] mb-2 uppercase">{{ t('auth.school.primary') }}</div>
        <div v-for="s in utama" :key="s.id || s.school_id" class="space-y-2">
          <button
            type="button"
            class="w-full text-left rounded-2xl border-[1.5px] border-brand-cobalt bg-white p-3 flex items-center gap-3.5 shadow-lg shadow-brand-cobalt/10 transition-all"
            @click="candidateSchoolId = (s.school_id || s.id)"
          >
            <div :class="['w-11 h-11 rounded-xl bg-gradient-to-br flex-shrink-0 flex items-center justify-center text-white text-[14px] font-black tracking-wider', getGradient(s.school_name || s.name)]">
              {{ getInitials(s.school_name || s.name) }}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-1.5">
                <h3 class="text-[13.5px] font-black text-slate-900 truncate leading-tight">{{ s.school_name || s.name }}</h3>
                <TenantBadge
                  v-if="s.tenant_type === 'TUTORING_CENTER'"
                  :type="s.tenant_type"
                />
              </div>
              <p class="text-[10.5px] font-semibold text-slate-500 mt-0.5 truncate">
                {{ s.city || s.address }} {{ s.academic_year ? `· TP ${s.academic_year}` : '' }}
              </p>
              <!-- Role Pills -->
              <div v-if="s.roles && s.roles.length" class="flex flex-wrap gap-1 mt-1.5">
                <span 
                  v-for="r in s.roles" :key="r"
                  class="px-1.5 py-0.5 rounded-full bg-brand-cobalt/10 text-brand-cobalt text-[8px] font-black tracking-[0.3px] uppercase"
                >
                  {{ r === 'administrator' ? t('role.admin') : r === 'teacher' ? t('role.guru') : r === 'parent' ? t('role.wali') : r.toUpperCase() }}
                </span>
              </div>
            </div>
            <div class="w-5 h-5 rounded-full bg-brand-cobalt flex items-center justify-center flex-shrink-0">
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
            </div>
          </button>
        </div>
      </div>

      <!-- More -->
      <div v-if="lainnya.length > 0">
        <div class="text-[10px] font-extrabold text-slate-400 tracking-[0.8px] mb-2 uppercase">
          {{ utama.length === 0 ? t('auth.school.chooseLabel') : t('auth.school.othersLabel') }}
        </div>
        <div class="space-y-2">
          <button
            v-for="s in lainnya" :key="s.id || s.school_id"
            type="button"
            class="w-full text-left rounded-2xl border border-slate-200 bg-white p-3 flex items-center gap-3.5 hover:border-brand-cobalt/50 transition-all"
            @click="candidateSchoolId = (s.school_id || s.id)"
          >
            <div :class="['w-11 h-11 rounded-xl bg-gradient-to-br flex-shrink-0 flex items-center justify-center text-white text-[14px] font-black tracking-wider opacity-80', getGradient(s.school_name || s.name)]">
              {{ getInitials(s.school_name || s.name) }}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-1.5">
                <h3 class="text-[13.5px] font-black text-slate-800 truncate leading-tight">{{ s.school_name || s.name }}</h3>
                <TenantBadge
                  v-if="s.tenant_type === 'TUTORING_CENTER'"
                  :type="s.tenant_type"
                />
              </div>
              <p class="text-[10.5px] font-semibold text-slate-400 mt-0.5 truncate">
                {{ s.city || s.address }} {{ s.academic_year ? `· TP ${s.academic_year}` : '' }}
              </p>
            </div>
            <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-slate-300"><path d="m9 18 6-6-6-6"/></svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Footer CTA -->
    <div class="space-y-3 pt-2">
      <button
        type="button"
        :disabled="!activeId || auth.isLoading"
        class="w-full rounded-xl bg-gradient-to-br from-brand-dark-blue to-brand-cobalt hover:opacity-90 disabled:from-slate-300 disabled:to-slate-300 text-white font-black py-[14px] shadow-lg shadow-brand-dark-blue/30 disabled:shadow-none transition-all flex items-center justify-center gap-2"
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
          <span class="text-[13.5px] tracking-wide uppercase truncate">
            {{ candidateName ? t('auth.school.continueButton', { candidateName: candidateName.length > 20 ? candidateName.substring(0, 18) + '...' : candidateName }) : 'LANJUTKAN' }}
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
