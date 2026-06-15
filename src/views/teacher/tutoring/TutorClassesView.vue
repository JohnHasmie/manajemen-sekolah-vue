<!--
  TutorClassesView — list of all kelompok where the current user is
  the assigned tutor. Mirrors mobile `TutorClassesScreen`.

  Header: navy hero with class count + a search box. Body: responsive
  grid of TutorClassCard. Tap → /teacher/tutoring/kelas/:groupId.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import type { TutoringGroup } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import TutorClassCard from '@/components/feature/tutoring/TutorClassCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();

const loading = ref(true);
const groups = ref<TutoringGroup[]>([]);
const query = ref('');

async function load() {
  loading.value = true;
  try {
    groups.value = await TutoringService.getAllGroups();
  } catch {/* non-fatal */}
  finally {
    loading.value = false;
  }
}
onMounted(load);

const myGroups = computed(() =>
  groups.value.filter((g) => g.tutor_user_id === auth.user?.id),
);

const filteredGroups = computed(() => {
  const q = query.value.trim().toLowerCase();
  if (!q) return myGroups.value;
  return myGroups.value.filter((g) => g.name.toLowerCase().includes(q));
});

function goToClass(g: TutoringGroup) {
  router.push({ name: 'teacher.tutoring.class-detail', params: { groupId: g.id } });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      :greeting="t('tutor.bimbel.classes.greeting')"
      :title="t('tutor.bimbel.classes.title_count', { count: myGroups.length })"
      :subtitle="t('tutor.bimbel.classes.subtitle')"
      :stats="[]"
    />

    <div class="relative">
      <NavIcon
        name="search"
        :size="16"
        class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-bimbel-text-lo"
      />
      <input
        v-model="query"
        type="text"
        :placeholder="t('tutor.bimbel.classes.search_placeholder')"
        class="w-full rounded-xl border border-bimbel-border bg-bimbel-panel px-9 py-2.5 text-sm text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-bimbel-accent focus:outline-none"
      />
    </div>

    <div v-if="loading" class="py-16 text-center text-bimbel-text-mid">
      {{ t('tutor.bimbel.classes.loading') }}
    </div>

    <div
      v-else-if="filteredGroups.length"
      class="grid gap-3 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
    >
      <TutorClassCard
        v-for="g in filteredGroups"
        :key="g.id"
        :identity-key="g.id"
        :name="g.name"
        :program="g.tutor?.name ? `${t('tutor.bimbel.classes.tutor_prefix')}: ${g.tutor.name}` : undefined"
        :meta="g.enrollments_count != null ? `${g.enrollments_count} ${t('tutor.bimbel.classes.meta_students_suffix')}` : undefined"
        @click="goToClass(g)"
      />
    </div>

    <p
      v-else
      class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid"
    >
      <template v-if="query">{{ t('tutor.bimbel.classes.no_match', { query }) }}</template>
      <template v-else>{{ t('tutor.bimbel.classes.no_classes') }}</template>
    </p>
  </div>
</template>
