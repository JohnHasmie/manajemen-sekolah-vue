<!--
  AdminTutoringTutorDetailView — per-tutor detail. Re-uses the tutors
  list endpoint and finds the row by user_id. Uses the BrandPageHeader
  + KpiStripCards chrome.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringTutorRow } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';

const { t } = useI18n();
const route = useRoute();
const userId = String(route.params.userId ?? '');
const fallbackName = String(route.query.name ?? 'Tutor');
const fallbackEmail = String(route.query.email ?? '');

const loading = ref(true);
const row = ref<TutoringTutorRow | null>(null);

const display = computed(() => row.value ?? {
  user_id: userId,
  name: fallbackName,
  email: fallbackEmail,
  status: 'PENDING' as const,
  group_count: 0,
  groups: [],
  sessions_30d: 0,
  attendance_rate: null,
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: t('tutoring.programDetail.groups'),
    value: display.value.group_count,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'calendar',
    label: 'Sesi 30h',
    value: display.value.sessions_30d,
    tone: 'violet',
  },
  {
    icon: 'check-circle',
    label: t('tutoring.tutors.attendance'),
    value:
      display.value.attendance_rate == null
        ? '–'
        : `${display.value.attendance_rate}%`,
    tone: 'green',
  },
  {
    icon: 'shield',
    label: 'Status',
    value:
      display.value.status === 'ACTIVE'
        ? t('tutoring.tutors.statusActive')
        : t('tutoring.tutors.statusPending'),
    tone: display.value.status === 'ACTIVE' ? 'green' : 'amber',
  },
]);

onMounted(async () => {
  loading.value = true;
  try {
    const all = await TutoringService.getAdminTutors();
    row.value = all.find((r) => r.user_id === userId) ?? null;
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="'Bimbel · ' + display.name"
      :title="display.name"
      :meta="display.email"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else>
      <KpiStripCards :cards="kpiCards" />

      <TutoringSectionHeader :title="t('tutoring.tutorDetail.groupsAssigned')" />
      <TutoringEmpty
        v-if="display.groups.length === 0"
        :text="t('tutoring.tutorDetail.noGroups')"
        icon="users"
      />
      <div v-else class="space-y-2">
        <TutoringListTile
          v-for="g in display.groups"
          :key="g.id"
          icon="users"
          :title="g.name"
          :subtitle="g.program ?? undefined"
        />
      </div>
    </template>
  </div>
</template>
