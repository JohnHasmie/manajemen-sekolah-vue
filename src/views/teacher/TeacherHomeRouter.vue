<!--
  TeacherHomeRouter — picks the right "home" view for the teacher role
  based on the active tenant. Mounted on the `teacher.home` route so
  switching tenants between SCHOOL and TUTORING_CENTER swaps the body
  without changing the URL.

  - SCHOOL tenant → the original TeacherDashboardView (Jadwal /
    Kehadiran / Aktivitas / Draft RPP / E-Rapor — all school modules).
  - TUTORING_CENTER → TutorTutoringHomeView (bimbel-native KPI strip
    + quick actions: Sesi Saya / Buat Sesi / Generator Soal AI).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { tenantKindFromRaw } from '@/composables/useTenant';

import TeacherDashboardView from '@/views/teacher/TeacherDashboardView.vue';
import TutorTutoringHomeView from '@/views/teacher/tutoring/TutorTutoringHomeView.vue';

const auth = useAuthStore();

const isTutoringTenant = computed(() => {
  const raw =
    auth.user?.tenant_type ??
    auth.schools.find((s) => (s.id ?? s.school_id) === auth.schoolId)
      ?.tenant_type;
  return tenantKindFromRaw(raw) === 'TUTORING_CENTER';
});
</script>

<template>
  <TutorTutoringHomeView v-if="isTutoringTenant" />
  <TeacherDashboardView v-else />
</template>
