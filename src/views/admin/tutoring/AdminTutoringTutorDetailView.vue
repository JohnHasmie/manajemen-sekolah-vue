<!--
  AdminTutoringTutorDetailView — per-tutor detail. Re-uses the tutors
  list endpoint and finds the row by user_id (saves a dedicated detail
  endpoint; the list rows already contain the per-row aggregates +
  assigned groups).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringTutorRow } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringHero from '@/components/feature/tutoring/TutoringHero.vue';
import TutoringKpiCard from '@/components/feature/tutoring/TutoringKpiCard.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
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
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.tutorDetail.title')"
      :crumbs="'Bimbel · ' + display.name"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else>
      <TutoringHero
        icon="user"
        greet="TUTOR"
        :title="display.name"
        :subtitle="display.email"
      >
        <template #trailing>
          <TutoringStatusPill
            :label="display.status === 'ACTIVE' ? t('tutoring.tutors.statusActive') : t('tutoring.tutors.statusPending')"
            :tone="display.status === 'ACTIVE' ? 'ok' : 'warn'"
          />
        </template>
      </TutoringHero>

      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4">
        <TutoringKpiCard
          icon="users"
          :value="display.group_count"
          :label="t('tutoring.programDetail.groups')"
        />
        <TutoringKpiCard
          icon="calendar"
          :value="display.sessions_30d"
          label="Sesi 30h"
        />
        <TutoringKpiCard
          icon="check-circle"
          :value="display.attendance_rate == null ? '–' : display.attendance_rate + '%'"
          :label="t('tutoring.tutors.attendance')"
          tone="ok"
        />
        <TutoringKpiCard
          icon="mail"
          :value="display.status === 'ACTIVE' ? t('tutoring.tutors.statusActive') : t('tutoring.tutors.statusPending')"
          label="Status"
        />
      </div>

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
