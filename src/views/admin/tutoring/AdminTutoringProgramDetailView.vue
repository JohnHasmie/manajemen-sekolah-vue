<!--
  AdminTutoringProgramDetailView — a program's packages + groups +
  assessments with inline create forms. Rebuilt on the tutoring shared
  components.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringAssessment,
  TutoringGroup,
  TutoringPackage,
} from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { computed } from 'vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();
const programId = String(route.params.programId ?? '');
const programName = String(route.query.name ?? 'Program');

function goEnroll() {
  router.push({
    name: 'admin.tutoring.enroll',
    params: { programId },
    query: { name: programName },
  });
}

const packages = ref<TutoringPackage[]>([]);
const groups = ref<TutoringGroup[]>([]);
const assessments = ref<TutoringAssessment[]>([]);
const loading = ref(true);

function openAssessment(a: TutoringAssessment) {
  if (!a.questions_count) return;
  router.push({
    name: 'admin.tutoring.assessment-detail',
    params: { assessmentId: a.id },
    query: { name: a.title },
  });
}

const showPkgForm = ref(false);
const showGrpForm = ref(false);
const savingPkg = ref(false);
const savingGrp = ref(false);

const pkgForm = ref({
  name: '',
  total_sessions: '' as string | number,
  price: '' as string | number,
  modes: ['PREPAID'] as string[],
});
const grpForm = ref({ name: '', capacity: 10 });

const allModes: { key: string; label: string }[] = [
  { key: 'PREPAID', label: t('tutoring.modes.prepaid') },
  { key: 'MONTHLY', label: t('tutoring.modes.monthly') },
  { key: 'PER_SESSION', label: t('tutoring.modes.perSession') },
];

async function load() {
  loading.value = true;
  try {
    [packages.value, groups.value, assessments.value] = await Promise.all([
      TutoringService.getPackages(programId),
      TutoringService.getGroups(programId),
      TutoringService.getAssessments(programId),
    ]);
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.programDetail.loadFailed'),
    );
  } finally {
    loading.value = false;
  }
}

function toggleMode(key: string) {
  const arr = pkgForm.value.modes;
  const i = arr.indexOf(key);
  if (i >= 0) arr.splice(i, 1);
  else arr.push(key);
}

async function createPackage() {
  if (pkgForm.value.name.trim().length < 3) {
    toast.error(t('tutoring.programDetail.pkgNameTooShort'));
    return;
  }
  if (pkgForm.value.modes.length === 0) {
    toast.error(t('tutoring.programDetail.pickMode'));
    return;
  }
  savingPkg.value = true;
  try {
    await TutoringService.createPackage({
      program_id: programId,
      name: pkgForm.value.name.trim(),
      billing_modes_allowed: pkgForm.value.modes,
      total_sessions: pkgForm.value.total_sessions
        ? Number(pkgForm.value.total_sessions)
        : undefined,
      price: pkgForm.value.price ? Number(pkgForm.value.price) : undefined,
    });
    toast.success(t('tutoring.programDetail.pkgCreated'));
    showPkgForm.value = false;
    pkgForm.value = { name: '', total_sessions: '', price: '', modes: ['PREPAID'] };
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.programDetail.pkgCreateFailed'),
    );
  } finally {
    savingPkg.value = false;
  }
}

async function createGroup() {
  if (grpForm.value.name.trim().length < 3) {
    toast.error(t('tutoring.programDetail.grpNameTooShort'));
    return;
  }
  savingGrp.value = true;
  try {
    await TutoringService.createGroup({
      program_id: programId,
      name: grpForm.value.name.trim(),
      capacity: grpForm.value.capacity,
    });
    toast.success(t('tutoring.programDetail.grpCreated'));
    showGrpForm.value = false;
    grpForm.value = { name: '', capacity: 10 };
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.programDetail.grpCreateFailed'),
    );
  } finally {
    savingGrp.value = false;
  }
}

onMounted(load);

const totalEnrollments = computed(
  () => groups.value.reduce((s, g) => s + (g.enrollments_count ?? 0), 0),
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'package',
    label: t('tutoring.programDetail.packages'),
    value: packages.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'users',
    label: t('tutoring.programDetail.groups'),
    value: groups.value.length,
    suffix: totalEnrollments.value > 0
      ? `${totalEnrollments.value} siswa`
      : undefined,
    tone: 'violet',
  },
  {
    icon: 'file-text',
    label: t('tutoring.programDetail.assessments'),
    value: assessments.value.length,
    tone: 'green',
  },
]);

const inputCls =
  'w-full rounded-lg border border-tutoring-border px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent';
const saveBtnCls =
  'rounded-lg bg-tutoring-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50';
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.program_detail.kicker_prefix', { name: programName })"
      :title="programName"
      :meta="t('admin.bimbel.program_detail.meta')"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-tutoring-panel text-tutoring-accent text-[13px] font-bold hover:bg-tutoring-panel/90"
        @click="goEnroll"
      >
        <NavIcon name="user-plus" :size="13" />
        {{ t('tutoring.programDetail.enroll') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards v-if="!loading" :cards="kpiCards" :lg-cols="3" />

    <div v-if="loading" class="space-y-2 py-4" aria-hidden="true">
      <div v-for="i in 3" :key="i" class="flex items-center gap-3 rounded-xl bg-tutoring-panel border border-tutoring-border-soft p-3">
        <div class="h-8 w-8 rounded-lg bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        <div class="flex-1 space-y-2">
          <div class="h-3 w-2/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
          <div class="h-2 w-3/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        </div>
      </div>
    </div>

    <template v-else>
      <!-- Packages -->
      <TutoringSectionHeader
        :title="t('tutoring.programDetail.packages')"
        :action-label="showPkgForm ? t('tutoring.common.close') : t('tutoring.common.add')"
        @action="showPkgForm = !showPkgForm"
      />
      <section
        v-if="showPkgForm"
        class="mb-3 space-y-2 bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4"
      >
        <input
          v-model="pkgForm.name"
          :placeholder="t('tutoring.programDetail.pkgNamePh')"
          :class="inputCls"
        />
        <div class="flex gap-2">
          <input
            v-model="pkgForm.total_sessions"
            type="number"
            :placeholder="t('tutoring.programDetail.totalSessionsPh')"
            :class="inputCls"
          />
          <input
            v-model="pkgForm.price"
            type="number"
            :placeholder="t('tutoring.programDetail.pricePh')"
            :class="inputCls"
          />
        </div>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="m in allModes"
            :key="m.key"
            type="button"
            class="rounded-lg px-2.5 py-1.5 text-xs font-semibold border"
            :class="
              pkgForm.modes.includes(m.key)
                ? 'bg-tutoring-accent border-tutoring-accent text-tutoring-ring'
                : 'bg-tutoring-panel border-tutoring-border text-tutoring-text-mid hover:border-tutoring-accent/50'
            "
            @click="toggleMode(m.key)"
          >
            {{ m.label }}
          </button>
        </div>
        <button
          :disabled="savingPkg"
          :class="saveBtnCls"
          @click="createPackage"
        >
          {{ savingPkg ? t('tutoring.common.saving') : t('tutoring.common.save') }}
        </button>
      </section>

      <TutoringEmpty
        v-if="packages.length === 0"
        :text="t('tutoring.programDetail.noPackages')"
      />
      <div v-else class="space-y-2">
        <TutoringListTile
          v-for="p in packages"
          :key="p.id"
          icon="layers"
          :title="p.name"
          :subtitle="
            [
              p.total_sessions
                ? p.total_sessions + ' ' + t('tutoring.programDetail.sessions')
                : null,
              p.price != null ? formatRupiah(p.price) : null,
              p.billing_modes_allowed.join(', '),
            ]
              .filter(Boolean)
              .join(' · ')
          "
        />
      </div>

      <!-- Groups -->
      <TutoringSectionHeader
        :title="t('tutoring.programDetail.groups')"
        :action-label="showGrpForm ? t('tutoring.common.close') : t('tutoring.common.add')"
        @action="showGrpForm = !showGrpForm"
      />
      <section
        v-if="showGrpForm"
        class="mb-3 space-y-2 bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4"
      >
        <input
          v-model="grpForm.name"
          :placeholder="t('tutoring.programDetail.grpNamePh')"
          :class="inputCls"
        />
        <input
          v-model.number="grpForm.capacity"
          type="number"
          :placeholder="t('tutoring.programDetail.capacityPh')"
          :class="inputCls"
        />
        <button
          :disabled="savingGrp"
          :class="saveBtnCls"
          @click="createGroup"
        >
          {{ savingGrp ? t('tutoring.common.saving') : t('tutoring.common.save') }}
        </button>
      </section>

      <TutoringEmpty
        v-if="groups.length === 0"
        :text="t('tutoring.programDetail.noGroups')"
      />
      <div v-else class="space-y-2">
        <TutoringListTile
          v-for="g in groups"
          :key="g.id"
          icon="users"
          :title="g.name"
          :subtitle="
            [
              t('tutoring.programDetail.capacity') + ' ' + g.capacity,
              (g.enrollments_count ?? 0) +
                ' ' +
                t('tutoring.programDetail.students'),
              g.tutor?.name
                ? t('tutoring.programDetail.tutor') + ': ' + g.tutor.name
                : null,
            ]
              .filter(Boolean)
              .join(' · ')
          "
        />
      </div>

      <!-- Assessments -->
      <TutoringSectionHeader :title="t('tutoring.programDetail.assessments')" />
      <TutoringEmpty
        v-if="assessments.length === 0"
        :text="t('tutoring.programDetail.noAssessments')"
      />
      <div v-else class="space-y-2">
        <TutoringListTile
          v-for="a in assessments"
          :key="a.id"
          icon="file-text"
          :title="a.title"
          :subtitle="
            [
              a.type_label,
              a.held_at,
              (a.questions_count ?? 0) +
                ' ' +
                t('tutoring.programDetail.questions'),
              (a.scores_count ?? 0) +
                ' ' +
                t('tutoring.programDetail.scores'),
            ]
              .filter(Boolean)
              .join(' · ')
          "
          :to="a.questions_count ? () => openAssessment(a) : null"
        />
      </div>
    </template>
  </div>
</template>
