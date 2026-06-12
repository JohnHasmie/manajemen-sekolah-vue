<!--
  AdminTutoringTutorsView — list tutors (users carrying TEACHER role
  on this tenant). Same chrome as the rest of admin pages
  (BrandPageHeader + KpiStripCards + PageFilterToolbar). Header CTA
  opens the invite modal.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringTutorRow } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
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
const showStatusPicker = ref(false);

const STATUS_OPTIONS: { key: Filter; label: string }[] = [
  { key: 'all', label: 'Semua' },
  { key: 'active', label: 'Aktif' },
  { key: 'pending', label: 'Belum punya kelompok' },
];

const activeStatusLabel = computed(
  () => STATUS_OPTIONS.find((o) => o.key === filter.value)?.label ?? 'Semua',
);

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

function pickStatus(k: Filter) {
  filter.value = k;
  showStatusPicker.value = false;
}

const activeCount = computed(
  () => rows.value.filter((r) => r.status === 'ACTIVE').length,
);
const totalSessions30d = computed(
  () => rows.value.reduce((s, r) => s + (r.sessions_30d ?? 0), 0),
);
const avgAttendance = computed(() => {
  const withRate = rows.value.filter((r) => r.attendance_rate != null);
  if (withRate.length === 0) return null;
  return Math.round(
    withRate.reduce((s, r) => s + (r.attendance_rate ?? 0), 0) / withRate.length,
  );
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'user-check',
    label: t('tutoring.tutors.title'),
    value: rows.value.length,
    suffix: 'tutor',
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: 'Aktif',
    value: activeCount.value,
    suffix:
      rows.value.length > 0
        ? `dari ${rows.value.length}`
        : undefined,
    tone: 'green',
  },
  {
    icon: 'calendar',
    label: 'Sesi 30h',
    value: totalSessions30d.value,
    tone: 'violet',
  },
  {
    icon: 'bar-chart-2',
    label: t('tutoring.tutors.attendance'),
    value: avgAttendance.value == null ? '–' : `${avgAttendance.value}%`,
    tone: 'amber',
  },
]);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Tutor"
      :title="t('tutoring.tutors.title')"
      :meta="`${rows.length} tutor · ${activeCount} aktif`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-panel text-bimbel-accent text-[12px] font-bold hover:bg-bimbel-panel/90"
        @click="showInvite = true"
      >
        <NavIcon name="user-plus" :size="13" />
        {{ t('tutoring.tutors.inviteCta') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          label="Status"
          :value="activeStatusLabel"
          icon-name="check-circle"
          tone="green"
          @click="showStatusPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
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

    <Modal
      v-if="showStatusPicker"
      title="Filter Status"
      @close="showStatusPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in STATUS_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-bimbel-bg"
            :class="{ 'bg-bimbel-accent/5 text-bimbel-accent font-bold': filter === o.key }"
            @click="pickStatus(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <InviteTutorModal
      v-if="showInvite"
      @close="showInvite = false"
      @done="onInvited"
    />
  </div>
</template>
