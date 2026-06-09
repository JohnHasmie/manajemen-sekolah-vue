<!--
  AdminTutoringProgramDetailView — a program's packages + groups with
  inline create forms. Web mirror of the Flutter
  `tutoring_program_detail_screen.dart`. Completes the admin catalog
  flow: Program → Paket → Kelompok.

  programId from the route param; programName from the query.
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
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-bold text-slate-800">{{ programName }}</h1>
      <button
        class="rounded-lg bg-indigo-900 px-3 py-2 text-sm font-semibold text-white"
        @click="goEnroll"
      >
        + {{ t('tutoring.programDetail.enroll') }}
      </button>
    </div>

    <div v-if="loading" class="py-16 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else>
      <!-- Packages -->
      <section class="mb-6">
        <div class="mb-2 flex items-center justify-between">
          <h2 class="font-bold text-slate-800">{{ t('tutoring.programDetail.packages') }}</h2>
          <button
            class="text-sm font-semibold text-indigo-900"
            @click="showPkgForm = !showPkgForm"
          >
            {{ showPkgForm ? t('tutoring.common.close') : '+ ' + t('tutoring.common.add') }}
          </button>
        </div>

        <div
          v-if="showPkgForm"
          class="mb-3 space-y-2 rounded-xl border border-slate-200 p-3"
        >
          <input
            v-model="pkgForm.name"
            :placeholder="t('tutoring.programDetail.pkgNamePh')"
            class="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <div class="flex gap-2">
            <input
              v-model="pkgForm.total_sessions"
              type="number"
              :placeholder="t('tutoring.programDetail.totalSessionsPh')"
              class="w-full rounded-lg border border-slate-300 px-3 py-2"
            />
            <input
              v-model="pkgForm.price"
              type="number"
              :placeholder="t('tutoring.programDetail.pricePh')"
              class="w-full rounded-lg border border-slate-300 px-3 py-2"
            />
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="m in allModes"
              :key="m.key"
              type="button"
              class="rounded-full px-3 py-1 text-sm"
              :class="
                pkgForm.modes.includes(m.key)
                  ? 'bg-indigo-900 text-white'
                  : 'bg-slate-100 text-slate-700'
              "
              @click="toggleMode(m.key)"
            >
              {{ m.label }}
            </button>
          </div>
          <button
            :disabled="savingPkg"
            class="rounded-lg bg-indigo-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="createPackage"
          >
            {{ savingPkg ? t('tutoring.common.saving') : t('tutoring.common.save') }}
          </button>
        </div>

        <p v-if="packages.length === 0" class="text-sm text-slate-500">
          {{ t('tutoring.programDetail.noPackages') }}
        </p>
        <ul v-else class="space-y-2">
          <li
            v-for="p in packages"
            :key="p.id"
            class="rounded-xl border border-slate-200 p-3"
          >
            <div class="font-semibold text-slate-800">{{ p.name }}</div>
            <div class="text-sm text-slate-500">
              {{
                [
                  p.total_sessions
                    ? p.total_sessions + ' ' + t('tutoring.programDetail.sessions')
                    : null,
                  p.price != null ? formatRupiah(p.price) : null,
                  p.billing_modes_allowed.join(', '),
                ]
                  .filter(Boolean)
                  .join(' · ')
              }}
            </div>
          </li>
        </ul>
      </section>

      <!-- Groups -->
      <section>
        <div class="mb-2 flex items-center justify-between">
          <h2 class="font-bold text-slate-800">{{ t('tutoring.programDetail.groups') }}</h2>
          <button
            class="text-sm font-semibold text-indigo-900"
            @click="showGrpForm = !showGrpForm"
          >
            {{ showGrpForm ? t('tutoring.common.close') : '+ ' + t('tutoring.common.add') }}
          </button>
        </div>

        <div
          v-if="showGrpForm"
          class="mb-3 space-y-2 rounded-xl border border-slate-200 p-3"
        >
          <input
            v-model="grpForm.name"
            :placeholder="t('tutoring.programDetail.grpNamePh')"
            class="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <input
            v-model.number="grpForm.capacity"
            type="number"
            :placeholder="t('tutoring.programDetail.capacityPh')"
            class="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <button
            :disabled="savingGrp"
            class="rounded-lg bg-indigo-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="createGroup"
          >
            {{ savingGrp ? t('tutoring.common.saving') : t('tutoring.common.save') }}
          </button>
        </div>

        <p v-if="groups.length === 0" class="text-sm text-slate-500">
          {{ t('tutoring.programDetail.noGroups') }}
        </p>
        <ul v-else class="space-y-2">
          <li
            v-for="g in groups"
            :key="g.id"
            class="rounded-xl border border-slate-200 p-3"
          >
            <div class="font-semibold text-slate-800">{{ g.name }}</div>
            <div class="text-sm text-slate-500">
              {{
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
              }}
            </div>
          </li>
        </ul>
      </section>

      <!-- Assessments (try-out / post-test) -->
      <section class="mt-6">
        <h2 class="mb-2 font-bold text-slate-800">{{ t('tutoring.programDetail.assessments') }}</h2>
        <p v-if="assessments.length === 0" class="text-sm text-slate-500">
          {{ t('tutoring.programDetail.noAssessments') }}
        </p>
        <ul v-else class="space-y-2">
          <li
            v-for="a in assessments"
            :key="a.id"
            class="flex items-center justify-between rounded-xl border border-slate-200 p-3"
            :class="
              a.questions_count
                ? 'cursor-pointer hover:bg-slate-50'
                : 'opacity-70'
            "
            @click="openAssessment(a)"
          >
            <div>
              <div class="font-semibold text-slate-800">{{ a.title }}</div>
              <div class="text-sm text-slate-500">
                {{
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
                }}
              </div>
            </div>
            <span v-if="a.questions_count" class="text-slate-400">›</span>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
