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

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringHero from '@/components/feature/tutoring/TutoringHero.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

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

const inputCls =
  'w-full rounded-lg border border-slate-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin';
const saveBtnCls =
  'rounded-lg bg-role-admin hover:bg-role-admin/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50';
</script>

<template>
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.programs.title')"
      :crumbs="'Bimbel · Program · ' + programName"
    />

    <TutoringHero
      icon="layers"
      greet="PROGRAM"
      :title="programName"
      subtitle="Atur paket & kelompok lalu daftarkan siswa"
      accent="admin"
    >
      <template #trailing>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-role-admin hover:bg-role-admin/90 text-white rounded-xl px-3 py-2 text-xs font-semibold"
          @click="goEnroll"
        >
          <NavIcon name="user-plus" :size="14" />
          {{ t('tutoring.programDetail.enroll') }}
        </button>
      </template>
    </TutoringHero>

    <div v-if="loading" class="py-12 text-center text-slate-500 mt-3">
      {{ t('tutoring.common.loading') }}
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
        class="mb-3 space-y-2 bg-white border border-slate-100 rounded-2xl p-4"
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
                ? 'bg-role-admin border-role-admin text-white'
                : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300'
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
        class="mb-3 space-y-2 bg-white border border-slate-100 rounded-2xl p-4"
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
