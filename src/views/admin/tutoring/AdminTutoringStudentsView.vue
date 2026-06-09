<!--
  AdminTutoringStudentsView — list of bimbel students (derived from
  active enrollments). Table on web (better at scale); chip filter +
  search to scope.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutoringProgram, TutoringStudentRow } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringFlowTag from '@/components/feature/tutoring/TutoringFlowTag.vue';
import TutoringChipsRow from '@/components/feature/tutoring/TutoringChipsRow.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const rows = ref<TutoringStudentRow[]>([]);
const programs = ref<TutoringProgram[]>([]);
const programId = ref<string>(''); // '' = Semua program
const search = ref('');

const programOptions = computed(() => [
  { value: '', label: t('tutoring.students.filterAll') },
  ...programs.value.map((p) => ({ value: p.id, label: p.name })),
]);

const MODE_KEYS: Record<string, string> = {
  PREPAID: 'tutoring.billing.prepaid',
  MONTHLY: 'tutoring.billing.monthly',
  PER_SESSION: 'tutoring.billing.perSession',
};
const modeLabel = (m: string) => (MODE_KEYS[m] ? t(MODE_KEYS[m]) : m);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getAdminStudents({
      program_id: programId.value || undefined,
      search: search.value.trim() || undefined,
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.students.empty'));
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await load();
  try {
    programs.value = await TutoringService.getPrograms();
  } catch {/* non-fatal */}
});

watch(programId, load);

function openDetail(r: TutoringStudentRow) {
  // Re-use the parent overview view — same data shape, accessible
  // through a different name in the admin context.
  router.push({
    name: 'parent.tutoring.overview',
    params: { studentId: r.student_id },
    query: { name: r.student_name },
  });
}
</script>

<template>
  <div class="mx-auto max-w-5xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.students.title')"
      crumbs="Bimbel · Siswa"
    >
      <template #right>
        <div class="flex items-center gap-2">
          <input
            v-model.lazy="search"
            class="rounded-lg border border-slate-200 px-3 py-1.5 text-sm w-48 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
            :placeholder="t('common.search') || 'Cari…'"
            @change="load"
          />
        </div>
      </template>
    </TutoringPageHeader>

    <TutoringFlowTag
      class="mb-3"
      :text="t('tutoring.students.flow')"
    />

    <TutoringChipsRow
      v-model="programId"
      :options="programOptions"
      class="mb-3"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('tutoring.students.empty')"
      icon="users"
    />
    <div
      v-else
      class="bg-white border border-slate-100 rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-slate-500">
          <tr class="border-b border-slate-200">
            <th class="text-left font-bold px-3 py-2.5">Siswa</th>
            <th class="text-left font-bold px-3 py-2.5">Program · Paket</th>
            <th class="text-left font-bold px-3 py-2.5">Mode</th>
            <th class="text-left font-bold px-3 py-2.5">{{ t('tutoring.students.attendance') }}</th>
            <th class="text-right font-bold px-3 py-2.5">{{ t('tutoring.students.outstanding') }}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="r in rows"
            :key="r.student_id"
            class="border-b border-slate-100 last:border-0 hover:bg-slate-50 cursor-pointer"
            @click="openDetail(r)"
          >
            <td class="px-3 py-3 font-semibold text-slate-900">{{ r.student_name }}</td>
            <td class="px-3 py-3 text-slate-700">
              {{ [r.program_name, r.package_name].filter(Boolean).join(' · ') || '—' }}
            </td>
            <td class="px-3 py-3"><TutoringStatusPill :label="modeLabel(r.billing_mode)" tone="neutral" /></td>
            <td class="px-3 py-3 text-slate-700">
              {{ r.attendance_rate == null ? '—' : r.attendance_rate + '%' }}
            </td>
            <td class="px-3 py-3 text-right">
              <span v-if="r.unpaid_count === 0" class="text-slate-400">—</span>
              <span v-else class="font-semibold text-status-danger">
                {{ formatRupiah(r.unpaid_total) }}
              </span>
            </td>
            <td class="px-3 py-3 text-right">
              <NavIcon name="chevron-right" :size="14" class="text-slate-400" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
