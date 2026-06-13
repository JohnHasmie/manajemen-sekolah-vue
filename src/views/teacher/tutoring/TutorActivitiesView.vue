<!--
  TutorActivitiesView — list of activities (tugas / quiz / ujian /
  proyek) the tutor has shipped to their kelompok. Header CTA opens
  the create modal; row click routes to the submissions screen.

  Backend Phase 5 (tutoring_activities + activity_submissions) already
  exists; this is the first Vue surface for it on the tutor side.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type { TutoringActivity } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import CreateActivityModal from './CreateActivityModal.vue';

type TypeKey = 'all' | 'HOMEWORK' | 'EXAM' | 'QUIZ' | 'PROJECT';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const rows = ref<TutoringActivity[]>([]);
const type = ref<TypeKey>('all');
const showCreate = ref(false);
const showTypePicker = ref(false);

const TYPE_OPTIONS: { key: TypeKey; label: string; icon: string }[] = [
  { key: 'all', label: 'Semua', icon: 'list' },
  { key: 'HOMEWORK', label: 'PR', icon: 'book' },
  { key: 'EXAM', label: 'Ujian', icon: 'file-text' },
  { key: 'QUIZ', label: 'Quiz', icon: 'sparkles' },
  { key: 'PROJECT', label: 'Proyek', icon: 'briefcase' },
];

const activeTypeLabel = computed(
  () => TYPE_OPTIONS.find((o) => o.key === type.value)?.label ?? 'Semua',
);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getActivities({
      type: type.value === 'all' ? undefined : type.value,
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat aktivitas.');
  } finally {
    loading.value = false;
  }
}
onMounted(load);
watch(type, load);

function pickType(k: TypeKey) {
  type.value = k;
  showTypePicker.value = false;
}

function openSubmissions(a: TutoringActivity) {
  router.push({
    name: 'teacher.tutoring.activity-submissions',
    params: { activityId: a.id },
    query: {
      title: a.title,
      groupId: a.tutoring_group_id,
      groupName: a.group?.name ?? '',
    },
  });
}

function onCreated() {
  showCreate.value = false;
  load();
}

// KPI strip — client-side aggregates over the loaded list.
const totalSubmissions = computed(
  () => rows.value.reduce((s, r) => s + (r.submissions_count ?? 0), 0),
);
const pendingDue = computed(() => {
  const now = Date.now();
  return rows.value.filter((r) => {
    if (!r.due_at) return false;
    return Date.parse(r.due_at) >= now;
  }).length;
});
const overdueCount = computed(() => {
  const now = Date.now();
  return rows.value.filter((r) => {
    if (!r.due_at) return false;
    return Date.parse(r.due_at) < now;
  }).length;
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'book',
    label: 'Aktivitas aktif',
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'clock',
    label: 'Belum lewat tenggat',
    value: pendingDue.value,
    tone: 'violet',
  },
  {
    icon: 'alert-circle',
    label: 'Lewat tenggat',
    value: overdueCount.value,
    tone: overdueCount.value > 0 ? 'amber' : 'slate',
  },
  {
    icon: 'check-circle',
    label: 'Total pengumpulan',
    value: totalSubmissions.value,
    tone: 'green',
  },
]);

function iconFor(t: string): string {
  const o = TYPE_OPTIONS.find((x) => x.key === t);
  return o?.icon ?? 'book';
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="guru"
      kicker="Bimbel · Aktivitas"
      title="Aktivitas & Tugas"
      :meta="`${rows.length} aktivitas aktif`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-panel text-bimbel-accent text-[13px] font-bold hover:bg-bimbel-panel/90"
        @click="showCreate = true"
      >
        <NavIcon name="plus" :size="13" />
        Aktivitas
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          label="Tipe"
          :value="activeTypeLabel"
          icon-name="book"
          tone="violet"
          @click="showTypePicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      text="Belum ada aktivitas. Klik &quot;+ Aktivitas&quot; untuk membuat tugas baru."
      icon="book"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="a in rows"
        :key="a.id"
        :icon="iconFor(a.type)"
        accent="tutor"
        :title="a.title"
        :subtitle="[
          a.type_label ?? a.type,
          a.group?.name,
          a.subject?.name,
          a.due_at ? 'Tenggat ' + formatDateShort(a.due_at) : null,
          (a.submissions_count ?? 0) + ' pengumpulan',
        ].filter(Boolean).join(' · ')"
        :to="() => openSubmissions(a)"
      />
    </div>

    <Modal
      v-if="showTypePicker"
      title="Filter Tipe"
      @close="showTypePicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in TYPE_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-bimbel-bg"
            :class="{ 'bg-role-teacher/5 text-bimbel-accent font-bold': type === o.key }"
            @click="pickType(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <CreateActivityModal
      v-if="showCreate"
      @close="showCreate = false"
      @done="onCreated"
    />
  </div>
</template>
