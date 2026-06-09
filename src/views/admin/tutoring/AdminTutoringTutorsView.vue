<!--
  AdminTutoringTutorsView — list tutors (users carrying TEACHER role
  on this tenant) with their groups + load. Header CTA opens the
  invite modal.
-->
<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringTutorRow } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringChipsRow from '@/components/feature/tutoring/TutoringChipsRow.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import InviteTutorModal from './InviteTutorModal.vue';

type Filter = 'all' | 'active' | 'pending';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const filter = ref<Filter>('all');
const rows = ref<TutoringTutorRow[]>([]);
const showInvite = ref(false);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getAdminTutors({
      status: filter.value === 'all' ? undefined : filter.value,
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.tutors.empty'));
  } finally {
    loading.value = false;
  }
}
onMounted(load);
watch(filter, load);

function onInvited() {
  showInvite.value = false;
  load();
}

function openDetail(r: TutoringTutorRow) {
  router.push({
    name: 'admin.tutoring.tutor-detail',
    params: { userId: r.user_id },
    query: { name: r.name, email: r.email },
  });
}
</script>

<template>
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.tutors.title')"
      crumbs="Bimbel · Tutor"
    >
      <template #right>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-role-admin hover:bg-role-admin/90 text-white rounded-xl px-3.5 py-2 text-sm font-semibold"
          @click="showInvite = true"
        >
          <NavIcon name="user-plus" :size="14" />
          {{ t('tutoring.tutors.inviteCta') }}
        </button>
      </template>
    </TutoringPageHeader>

    <TutoringChipsRow
      v-model="filter"
      :options="[
        { value: 'all', label: t('tutoring.tutors.filterAll') },
        { value: 'active', label: t('tutoring.tutors.filterActive') },
        { value: 'pending', label: t('tutoring.tutors.filterPending') },
      ]"
      class="mb-3"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('tutoring.tutors.empty')"
      icon="user"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="r in rows"
        :key="r.user_id"
        icon="user"
        :title="r.name"
        :subtitle="[
          r.group_count > 0
            ? r.group_count + ' kelompok'
            : t('tutoring.tutors.filterPending'),
          r.sessions_30d + ' ' + t('tutoring.tutors.sessions30d'),
          r.attendance_rate == null ? null : r.attendance_rate + '% ' + t('tutoring.tutors.attendance'),
        ].filter(Boolean).join(' · ')"
        :to="() => openDetail(r)"
      >
        <template #trailing>
          <TutoringStatusPill
            :label="r.status === 'ACTIVE' ? t('tutoring.tutors.statusActive') : t('tutoring.tutors.statusPending')"
            :tone="r.status === 'ACTIVE' ? 'ok' : 'warn'"
          />
        </template>
      </TutoringListTile>
    </div>

    <InviteTutorModal
      v-if="showInvite"
      @close="showInvite = false"
      @done="onInvited"
    />
  </div>
</template>
