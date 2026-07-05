<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import type { DemoRegistrationItem, ActiveSchoolItem } from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';

// Canonical tenant_type value is English per project convention
// ("indonesia hanya untuk translate" — Yahya, 2026-06-24). After the
// 2026-06-26 English-enum cutover the backend emits canonical
// `'school' | 'tutoring'` on `demo_requests.tenant_type` and uppercase
// `'SCHOOL' | 'TUTORING_CENTER'` on the schools table; legacy rows
// pre-cutover may still carry `'bimbel' | 'sekolah'`. Delegate the
// tri-form normalisation to `normalizeTenantType` so this view never
// has to know the transition is in flight.
import { normalizeTenantType } from '@/lib/labels';
import { tenantLabel } from '@/lib/tenantTokens';

function isTutoring(tt: string | null | undefined): boolean {
  return normalizeTenantType(tt) === 'tutoring';
}

const props = defineProps<{
  demoRequests: DemoRegistrationItem[];
  activeSchools: ActiveSchoolItem[];
}>();

defineEmits(['daftar-baru']);

const router = useRouter();
const authStore = useAuthStore();

const hasData = computed(() => {
  return props.demoRequests.length > 0 || props.activeSchools.length > 0;
});

async function enterSchool(schoolId: string) {
  try {
    await authStore.selectSchool(schoolId);
    router.push('/');
  } catch (err) {
    console.error('Failed to enter school:', err);
  }
}

function formatDate(dateStr: string | null) {
  if (!dateStr) return '';
  return new Date(dateStr).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  });
}
</script>

<template>
  <div v-if="hasData" class="w-full bg-white border border-slate-200 rounded-2xl p-6 shadow-sm mb-8 transition-all hover:shadow-md">
    <div class="flex items-start gap-4">
      <div class="w-10 h-10 rounded-xl bg-amber-50 text-amber-600 grid place-items-center shrink-0">
        <NavIcon name="alert-circle" :size="20" />
      </div>
      <div class="flex-1 min-w-0">
        <h3 class="text-base font-bold text-slate-900 mb-1">
          Lembaga Terdaftar Anda
        </h3>
        <p class="text-xs sm:text-sm text-slate-500 mb-4 leading-relaxed">
          Akun Anda sudah terdaftar di beberapa lembaga di bawah ini. Anda tetap dapat melanjutkan pendaftaran sekolah atau bimbel baru.
        </p>

        <!-- List of active schools -->
        <div class="space-y-3">
          <div v-for="school in activeSchools" :key="school.id" class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3.5 bg-slate-50 border border-slate-100 rounded-xl hover:bg-slate-100/70 transition">
            <div class="flex items-center gap-3">
              <span class="text-lg">
                {{ isTutoring(school.tenant_type) ? '📚' : '🏫' }}
              </span>
              <div>
                <h4 class="text-sm font-bold text-slate-800 leading-tight">
                  {{ school.name }}
                </h4>
                <div class="flex items-center gap-2 mt-1">
                  <span class="text-3xs uppercase tracking-wider font-extrabold text-slate-400">
                    {{ tenantLabel('tenantType', school.tenant_type) }}
                  </span>
                  <span class="w-1 h-1 rounded-full bg-slate-300"></span>
                  <span class="text-3xs px-1.5 py-0.5 rounded bg-emerald-50 text-emerald-700 font-semibold uppercase tracking-wider">
                    Aktif
                  </span>
                </div>
              </div>
            </div>
            
            <button
              type="button"
              class="inline-flex items-center justify-center gap-1.5 px-4 py-1.5 text-xs font-semibold text-white bg-brand-cobalt hover:bg-brand-cobalt-dark active:scale-[0.98] rounded-lg shadow-sm transition"
              @click="enterSchool(school.id)"
            >
              Masuk
              <NavIcon name="arrow-right" :size="12" />
            </button>
          </div>

          <!-- List of demo requests -->
          <div v-for="req in demoRequests" :key="req.id" class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3.5 bg-slate-50/50 border border-slate-100/50 rounded-xl hover:bg-slate-100/50 transition">
            <div class="flex items-center gap-3">
              <span class="text-lg">
                {{ isTutoring(req.tenant_type) ? '📚' : '🏫' }}
              </span>
              <div>
                <h4 class="text-sm font-semibold text-slate-700 leading-tight">
                  {{ req.school_name || 'Institusi Tanpa Nama' }}
                </h4>
                <div class="flex items-center gap-2 mt-1">
                  <span class="text-3xs uppercase tracking-wider font-bold text-slate-400">
                    {{ tenantLabel('tenantType', req.tenant_type) }}
                  </span>
                  <span class="w-1 h-1 rounded-full bg-slate-300"></span>
                  <span v-if="req.status === 'pending'" class="text-3xs px-1.5 py-0.5 rounded bg-amber-50 text-amber-700 font-semibold uppercase tracking-wider">
                    Menunggu Persetujuan
                  </span>
                  <span v-else-if="req.status === 'rejected'" class="text-3xs px-1.5 py-0.5 rounded bg-rose-50 text-rose-700 font-semibold uppercase tracking-wider">
                    Ditolak
                  </span>
                  <span v-else-if="req.status === 'expired'" class="text-3xs px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 font-semibold uppercase tracking-wider">
                    Kedaluwarsa
                  </span>
                  <span v-else class="text-3xs px-1.5 py-0.5 rounded bg-emerald-50 text-emerald-700 font-semibold uppercase tracking-wider">
                    Disetujui
                  </span>
                </div>
              </div>
            </div>

            <span class="text-2xs text-slate-400 font-medium">
              Terdaftar: {{ formatDate(req.created_at) }}
            </span>
          </div>
        </div>

        <div class="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between">
          <p class="text-xs text-slate-500 font-medium">
            Ingin mendaftarkan lembaga yang berbeda?
          </p>
          <button
            type="button"
            class="inline-flex items-center justify-center gap-1.5 px-4 py-2 text-[13px] font-bold text-brand-cobalt bg-brand-cobalt/10 hover:bg-brand-cobalt/20 active:scale-[0.98] rounded-lg transition"
            @click="$emit('daftar-baru')"
          >
            Daftar Lembaga Baru
            <NavIcon name="plus" :size="14" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
