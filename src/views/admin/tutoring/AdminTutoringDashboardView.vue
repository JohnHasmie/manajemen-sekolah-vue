<!--
  AdminTutoringDashboardView — admin home for a tutoring-center tenant.
  Web mirror of the Flutter TutoringAdminDashboard. The school admin
  dashboard reads zero for a bimbel (no classes; students/tutors live in
  the tutoring tables), so this pulls bimbel-native KPIs from
  GET /tutoring/admin-stats and links to the management surfaces.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutoringAdminStats } from '@/types/tutoring';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const stats = ref<TutoringAdminStats | null>(null);

async function load() {
  loading.value = true;
  try {
    stats.value = await TutoringService.getAdminStats();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.dashboard.loadError'));
  } finally {
    loading.value = false;
  }
}

onMounted(load);

const actions = [
  { key: 'quickPrograms', icon: 'layers', to: 'admin.tutoring.programs' },
  { key: 'quickSessions', icon: 'calendar', to: 'admin.tutoring.sessions' },
  { key: 'quickBills', icon: 'wallet', to: 'admin.tutoring.bills' },
  {
    key: 'quickBilling',
    icon: 'settings',
    to: 'admin.tutoring.billing-settings',
  },
] as const;
</script>

<template>
  <div class="mx-auto max-w-4xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">
      {{ t('tutoring.dashboard.title') }}
    </h1>

    <div v-if="loading" class="py-16 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <div v-else-if="stats" class="space-y-6">
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <div class="rounded-2xl border border-slate-200 p-4">
          <div class="text-2xl font-extrabold text-violet-700">{{ stats.students }}</div>
          <div class="text-xs text-slate-500">{{ t('tutoring.dashboard.students') }}</div>
        </div>
        <div class="rounded-2xl border border-slate-200 p-4">
          <div class="text-2xl font-extrabold text-violet-700">{{ stats.active_programs }}</div>
          <div class="text-xs text-slate-500">{{ t('tutoring.dashboard.programs') }}</div>
        </div>
        <div class="rounded-2xl border border-slate-200 p-4">
          <div class="text-2xl font-extrabold text-violet-700">{{ stats.groups }}</div>
          <div class="text-xs text-slate-500">{{ t('tutoring.dashboard.groups') }}</div>
        </div>
        <div class="rounded-2xl border border-slate-200 p-4">
          <div class="text-2xl font-extrabold text-violet-700">{{ stats.upcoming_sessions }}</div>
          <div class="text-xs text-slate-500">{{ t('tutoring.dashboard.upcoming') }}</div>
        </div>
        <div class="rounded-2xl border border-slate-200 p-4">
          <div class="text-2xl font-extrabold text-violet-700">
            {{ stats.attendance_rate == null ? '–' : stats.attendance_rate + '%' }}
          </div>
          <div class="text-xs text-slate-500">{{ t('tutoring.dashboard.attendance') }}</div>
        </div>
        <div class="rounded-2xl border border-slate-200 p-4">
          <div class="text-2xl font-extrabold text-violet-700">{{ stats.unpaid_bills }}</div>
          <div class="text-xs text-slate-500">{{ t('tutoring.dashboard.unpaid') }}</div>
          <div v-if="stats.unpaid_total > 0" class="text-[11px] font-semibold text-amber-700">
            {{ formatRupiah(stats.unpaid_total) }}
          </div>
        </div>
      </div>

      <div>
        <h2 class="mb-2 font-bold text-slate-800">{{ t('tutoring.dashboard.manage') }}</h2>
        <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
          <button
            v-for="a in actions"
            :key="a.key"
            class="flex items-center gap-3 rounded-xl border border-slate-200 p-3 text-left hover:bg-slate-50"
            @click="router.push({ name: a.to })"
          >
            <span class="grid h-9 w-9 place-items-center rounded-lg bg-violet-100 text-violet-700">▸</span>
            <span class="font-semibold text-slate-800">
              {{ t('tutoring.dashboard.' + a.key) }}
            </span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
