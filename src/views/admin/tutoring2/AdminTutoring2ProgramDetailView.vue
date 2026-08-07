<!--
  AdminTutoring2ProgramDetailView.vue — one program's packages,
  learning groups and assessments, with the two inline create forms
  (CLEAN-2 Phase 2 · greenfield replacement for
  `admin/tutoring/AdminTutoringProgramDetailView.vue`).

  The list side is the pre-existing `AdminTutoring2ProgramsView.vue`;
  this is its drill-in.

  Route: /admin/tutoring2/programs/:programId
  Endpoints:
    GET  /tutoring-v2/programs/{id}                    (BE-2)
    GET  /tutoring-v2/programs/{id}/packages           (BE-2)
    POST /tutoring-v2/programs/{id}/packages           (BE-2)
    GET  /tutoring-v2/learning-groups?program_id=      (BE-3)
    POST /tutoring-v2/learning-groups                  (BE-3)
    GET  /tutoring-v2/assessments?program_id=          (BE-5)

  ── CONTRACT DIFFERENCES vs the legacy view ──────────────────────────

  1. THE PROGRAM NAME IS FETCHED, NOT READ OFF THE URL. Legacy took the
     title from `route.query.name` — so a pasted/bookmarked link with
     no `?name=` rendered the literal string "Program", and an outdated
     link rendered a stale name. v2 has `GET /programs/{id}`, so the
     title comes from the server and a bare `/programs/{uuid}` link
     works.

  2. PACKAGES ARE NESTED UNDER THE PROGRAM. v1 posted a flat
     `POST /packages` with `program_id` in the BODY. v2's route is
     `POST /programs/{program}/packages` — the program is in the PATH.

  3. `price` IS REQUIRED NOW. v1's `StorePackage` accepted a package
     with no price; v2's `StorePackageRequest` marks
     `price` required|integer|min:0. The form therefore validates it
     client-side before the round-trip instead of letting the server
     422.

  4. BILLING-MODE VALUES ARE LOWERCASE. v1 sent
     `billing_modes_allowed: ['PREPAID', …]`; v2's field is
     `allowed_billing_modes` and its values are `prepaid | monthly |
     per_session` (validated against `TenantProfile::BILLING_*`).
     Both the key AND the casing changed.

  5. ASSESSMENTS HAVE NO `questions_count`. Legacy made a row
     clickable only when `questions_count > 0` and passed `?name=`.
     v2's `AssessmentResource` exposes `scores_count` instead (there is
     no question bank on the greenfield assessment), so the row links
     out when it has scores to show.

  ── DROPPED ──────────────────────────────────────────────────────────
  Two cross-screen PRE-FILTERS, both of which were already dead on
  arrival in the legacy view and are deliberately not re-shipped:

    a. "Daftarkan siswa" pushed `admin.tutoring2.enrollments` with
       `?programId=&name=`.
    b. An assessment row pushed `admin.tutoring2.assessments` with
       `?assessmentId=&name=`.

  Both TARGETS are greenfield views that read no route query at all
  (grep `route.query` in either — nothing), so the params have never
  done anything. Re-emitting them would only re-create the illusion of
  a filter. Both CTAs still navigate — to the unfiltered screen — and
  restoring the pre-filter is pure frontend work (teach
  AdminTutoring2EnrollmentsView to seed `program_id`, and
  AdminTutoring2AssessmentsView to seed the selected assessment, from
  their query). No backend route is missing.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import {
  TutoringBimbelService,
  type BimbelAssessment,
  type BimbelLearningGroup,
  type BimbelPackage,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const programId = computed(() => String(route.params.programId ?? ''));

/** v2 wire values — lowercase, and the field is `allowed_billing_modes`. */
type BillingMode = BimbelPackage['allowed_billing_modes'][number];
const BILLING_MODES: BillingMode[] = ['prepaid', 'monthly', 'per_session'];

interface ProgramDetailPayload {
  program: BimbelProgram;
  packages: BimbelPackage[];
  groups: BimbelLearningGroup[];
  assessments: BimbelAssessment[];
}

/** Scoped soft-fail for the ability-gated child lists. */
function optional<T>(p: Promise<T>, fallback: T): Promise<T> {
  return p.catch(() => fallback);
}

const { state, reload } = useDataRefresh<ProgramDetailPayload | null>(async () => {
  const id = programId.value;
  if (!id) return null;

  const [program, packages, groups, assessments] = await Promise.all([
    TutoringBimbelService.getProgram(id),
    optional(TutoringBimbelService.listPackages(id, { per_page: 50 }), {
      items: [],
      pagination: undefined,
    }),
    optional(TutoringBimbelService.listGroups({ program_id: id, per_page: 50 }), {
      items: [],
      pagination: undefined,
    }),
    optional(TutoringBimbelService.listAssessments({ program_id: id, per_page: 50 }), {
      items: [],
      pagination: undefined,
    }),
  ]);

  return {
    program,
    packages: packages.items,
    groups: groups.items,
    assessments: assessments.items,
  };
});

watch(programId, () => void reload());

const payload = computed<ProgramDetailPayload | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? (state.value.data ?? null)
    : null,
);

const program = computed<BimbelProgram | null>(() => payload.value?.program ?? null);
const packages = computed<BimbelPackage[]>(() => payload.value?.packages ?? []);
const groups = computed<BimbelLearningGroup[]>(() => payload.value?.groups ?? []);
const assessments = computed<BimbelAssessment[]>(() => payload.value?.assessments ?? []);

const seatedTotal = computed(() =>
  groups.value.reduce((sum, g) => sum + (g.seated_count ?? 0), 0),
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'package',
    label: t('tutoring2.admin.programDetail.kpiPackages'),
    value: String(packages.value.length),
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'users',
    label: t('tutoring2.admin.programDetail.kpiGroups'),
    value: String(groups.value.length),
    suffix:
      seatedTotal.value > 0
        ? t('tutoring2.common.metaStudents', { count: seatedTotal.value })
        : undefined,
    tone: 'violet',
  },
  {
    icon: 'file-text',
    label: t('tutoring2.admin.programDetail.kpiAssessments'),
    value: String(assessments.value.length),
    tone: 'green',
  },
]);

const headerMeta = computed(() => {
  if (state.value.status === 'loading') return t('tutoring2.common.loading');
  const p = program.value;
  if (!p) return t('tutoring2.admin.programDetail.notFound');
  return [p.grade_level, p.status_label ?? t(`tutoring2.status.${p.status}`)]
    .filter(Boolean)
    .join(' · ');
});

// ── Package create form ────────────────────────────────────────────

const showPackageForm = ref(false);
const savingPackage = ref(false);
const packageForm = ref({
  name: '',
  price: '' as string,
  totalSessions: '' as string,
  modes: ['prepaid'] as BillingMode[],
});

function resetPackageForm(): void {
  packageForm.value = {
    name: '',
    price: '',
    totalSessions: '',
    modes: ['prepaid'] as BillingMode[],
  };
}

function toggleMode(mode: BillingMode): void {
  const current = packageForm.value.modes;
  const idx = current.indexOf(mode);
  if (idx >= 0) packageForm.value.modes = current.filter((m) => m !== mode);
  else packageForm.value.modes = [...current, mode];
}

async function createPackage(): Promise<void> {
  const name = packageForm.value.name.trim();
  if (name.length < 3) {
    toast.error(t('tutoring2.admin.programDetail.errPackageName'));
    return;
  }
  if (packageForm.value.modes.length === 0) {
    toast.error(t('tutoring2.admin.programDetail.errPickMode'));
    return;
  }
  // v2 made `price` required (v1 allowed a priceless package) — catch
  // it here rather than eating a 422.
  const price = Number(packageForm.value.price);
  if (!packageForm.value.price.trim() || !Number.isFinite(price) || price < 0) {
    toast.error(t('tutoring2.admin.programDetail.errPackagePrice'));
    return;
  }
  const totalSessionsRaw = packageForm.value.totalSessions.trim();
  const totalSessions = totalSessionsRaw ? Number(totalSessionsRaw) : null;

  savingPackage.value = true;
  try {
    await TutoringBimbelService.createPackage(programId.value, {
      name,
      price,
      total_sessions: totalSessions,
      allowed_billing_modes: [...packageForm.value.modes],
    });
    toast.success(t('tutoring2.admin.programDetail.packageCreated'));
    showPackageForm.value = false;
    resetPackageForm();
    await reload();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring2.admin.programDetail.saveFailed'));
  } finally {
    savingPackage.value = false;
  }
}

// ── Group create form ──────────────────────────────────────────────

const showGroupForm = ref(false);
const savingGroup = ref(false);
const groupForm = ref({ name: '', capacity: 10 });

async function createGroup(): Promise<void> {
  const name = groupForm.value.name.trim();
  if (name.length < 3) {
    toast.error(t('tutoring2.admin.programDetail.errGroupName'));
    return;
  }
  savingGroup.value = true;
  try {
    await TutoringBimbelService.createGroup({
      program_id: programId.value,
      name,
      capacity: groupForm.value.capacity,
    });
    toast.success(t('tutoring2.admin.programDetail.groupCreated'));
    showGroupForm.value = false;
    groupForm.value = { name: '', capacity: 10 };
    await reload();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring2.admin.programDetail.saveFailed'));
  } finally {
    savingGroup.value = false;
  }
}

// ── Display helpers ────────────────────────────────────────────────

/** ⇄ AdminTutoring2GroupsView.statusPillTone — keep in lockstep. */
function groupStatusTone(status: BimbelLearningGroup['status']): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'draft':
      return 'neutral';
    case 'closed':
      return 'neutral';
  }
}

/**
 * Package status shares the program's three-value enum, so it reuses
 * AdminTutoring2ProgramsView.statusPillTone verbatim.
 */
function packageStatusTone(status: BimbelPackage['status']): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'draft':
      return 'neutral';
    case 'archived':
      return 'neutral';
  }
}

function modeLabel(mode: BillingMode): string {
  return t(`tutoring2.admin.programDetail.mode_${mode}`);
}

function packageSubtitle(pkg: BimbelPackage): string {
  return [
    pkg.total_sessions
      ? t('tutoring2.common.metaSessions', { count: pkg.total_sessions })
      : null,
    formatRupiah(pkg.price),
    pkg.allowed_billing_modes.map(modeLabel).join(', '),
  ]
    .filter(Boolean)
    .join(' · ');
}

function groupSubtitle(g: BimbelLearningGroup): string {
  return [
    `${g.seated_count ?? 0} / ${g.capacity}`,
    g.tutor_name ?? t('tutoring2.admin.programDetail.noTutor'),
    g.term_name,
  ]
    .filter(Boolean)
    .join(' · ');
}

function assessmentSubtitle(a: BimbelAssessment): string {
  return [
    a.kind_label ?? a.kind,
    a.assessment_date,
    t('tutoring2.admin.programDetail.scoresCount', { count: a.scores_count ?? 0 }),
  ]
    .filter(Boolean)
    .join(' · ');
}

function goEnrollments(): void {
  void router.push({ name: 'admin.tutoring2.enrollments' });
}

function goGroupDetail(group: BimbelLearningGroup): void {
  void router.push({
    name: 'admin.tutoring2.group-detail',
    params: { groupId: group.id },
  });
}

function goAssessments(): void {
  void router.push({ name: 'admin.tutoring2.assessments' });
}

const inputClass =
  'w-full rounded-xl border border-slate-200 px-3 py-2 text-2xs focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20';
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.admin.programDetail.kicker')"
      :title="program?.name ?? t('tutoring2.common.loading')"
      :meta="headerMeta"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 px-3 py-1.5 text-2xs font-bold text-white ring-1 ring-white/20 transition hover:bg-white/25"
        @click="goEnrollments"
      >
        <NavIcon name="user-plus" :size="13" />
        {{ t('tutoring2.admin.programDetail.enrollCta') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" :lg-cols="3" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="5"
      :empty-title="t('tutoring2.admin.programDetail.notFound')"
      :empty-description="t('tutoring2.admin.programDetail.notFoundDesc')"
      @retry="reload"
    >
      <template #default>
        <!-- ── Paket ──────────────────────────────────────────────── -->
        <section>
          <div class="mb-2 flex items-center justify-between gap-2">
            <h2 class="text-sm font-bold text-slate-900">
              {{ t('tutoring2.admin.programDetail.kpiPackages') }}
            </h2>
            <button
              type="button"
              class="text-2xs font-bold text-brand-cobalt hover:underline"
              @click="showPackageForm = !showPackageForm"
            >
              {{
                showPackageForm
                  ? t('tutoring2.admin.programDetail.close')
                  : t('tutoring2.admin.programDetail.add')
              }}
            </button>
          </div>

          <form
            v-if="showPackageForm"
            class="mb-3 space-y-2 rounded-3xl border border-slate-100 bg-white p-4 shadow-sm"
            @submit.prevent="createPackage"
          >
            <input
              v-model="packageForm.name"
              type="text"
              maxlength="120"
              :placeholder="t('tutoring2.admin.programDetail.packageNamePh')"
              :class="inputClass"
            />
            <div class="flex gap-2">
              <input
                v-model="packageForm.price"
                type="number"
                min="0"
                :placeholder="t('tutoring2.admin.programDetail.pricePh')"
                :class="inputClass"
              />
              <input
                v-model="packageForm.totalSessions"
                type="number"
                min="1"
                :placeholder="t('tutoring2.admin.programDetail.totalSessionsPh')"
                :class="inputClass"
              />
            </div>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="m in BILLING_MODES"
                :key="m"
                type="button"
                class="rounded-xl border px-2.5 py-1.5 text-2xs font-bold transition"
                :class="
                  packageForm.modes.includes(m)
                    ? 'border-brand-cobalt bg-brand-cobalt text-white'
                    : 'border-slate-200 bg-white text-slate-600 hover:border-brand-cobalt/50'
                "
                :aria-pressed="packageForm.modes.includes(m)"
                @click="toggleMode(m)"
              >
                {{ modeLabel(m) }}
              </button>
            </div>
            <button
              type="submit"
              :disabled="savingPackage"
              class="rounded-xl bg-brand-cobalt px-4 py-2 text-2xs font-bold text-white transition hover:bg-brand-cobalt/90 disabled:opacity-50"
            >
              {{
                savingPackage
                  ? t('tutoring2.admin.programDetail.saving')
                  : t('tutoring2.admin.programDetail.save')
              }}
            </button>
          </form>

          <p
            v-if="packages.length === 0"
            class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-2xs text-slate-400"
          >
            {{ t('tutoring2.admin.programDetail.emptyPackages') }}
          </p>
          <ul v-else class="space-y-2">
            <li
              v-for="p in packages"
              :key="p.id"
              class="flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-3.5 shadow-sm"
            >
              <span
                class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-brand-cobalt/10 text-brand-cobalt"
              >
                <NavIcon name="layers" :size="16" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-2xs font-bold text-slate-900">{{ p.name }}</p>
                <p class="truncate text-2xs text-slate-500">{{ packageSubtitle(p) }}</p>
              </div>
              <StatusBadge
                :label="p.status_label ?? t(`tutoring2.status.${p.status}`)"
                :tone="packageStatusTone(p.status)"
                uppercase
              />
            </li>
          </ul>
        </section>

        <!-- ── Kelompok ───────────────────────────────────────────── -->
        <section class="mt-6">
          <div class="mb-2 flex items-center justify-between gap-2">
            <h2 class="text-sm font-bold text-slate-900">
              {{ t('tutoring2.admin.programDetail.kpiGroups') }}
            </h2>
            <button
              type="button"
              class="text-2xs font-bold text-brand-cobalt hover:underline"
              @click="showGroupForm = !showGroupForm"
            >
              {{
                showGroupForm
                  ? t('tutoring2.admin.programDetail.close')
                  : t('tutoring2.admin.programDetail.add')
              }}
            </button>
          </div>

          <form
            v-if="showGroupForm"
            class="mb-3 space-y-2 rounded-3xl border border-slate-100 bg-white p-4 shadow-sm"
            @submit.prevent="createGroup"
          >
            <input
              v-model="groupForm.name"
              type="text"
              maxlength="120"
              :placeholder="t('tutoring2.admin.programDetail.groupNamePh')"
              :class="inputClass"
            />
            <input
              v-model.number="groupForm.capacity"
              type="number"
              min="1"
              max="500"
              :placeholder="t('tutoring2.admin.programDetail.capacityPh')"
              :class="inputClass"
            />
            <button
              type="submit"
              :disabled="savingGroup"
              class="rounded-xl bg-brand-cobalt px-4 py-2 text-2xs font-bold text-white transition hover:bg-brand-cobalt/90 disabled:opacity-50"
            >
              {{
                savingGroup
                  ? t('tutoring2.admin.programDetail.saving')
                  : t('tutoring2.admin.programDetail.save')
              }}
            </button>
          </form>

          <p
            v-if="groups.length === 0"
            class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-2xs text-slate-400"
          >
            {{ t('tutoring2.admin.programDetail.emptyGroups') }}
          </p>
          <ul v-else class="space-y-2">
            <li v-for="g in groups" :key="g.id">
              <button
                type="button"
                class="flex w-full items-center gap-3 rounded-3xl border border-slate-100 bg-white p-3.5 text-left shadow-sm transition hover:border-brand-cobalt hover:shadow-md"
                @click="goGroupDetail(g)"
              >
                <span
                  class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-violet-100 text-violet-700"
                >
                  <NavIcon name="users" :size="16" />
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block truncate text-2xs font-bold text-slate-900">{{ g.name }}</span>
                  <span class="block truncate text-2xs text-slate-500">{{ groupSubtitle(g) }}</span>
                </span>
                <StatusBadge
                  :label="g.status_label ?? t(`tutoring2.status.${g.status}`)"
                  :tone="groupStatusTone(g.status)"
                  uppercase
                />
              </button>
            </li>
          </ul>
        </section>

        <!-- ── Penilaian ──────────────────────────────────────────── -->
        <section class="mt-6">
          <h2 class="mb-2 text-sm font-bold text-slate-900">
            {{ t('tutoring2.admin.programDetail.kpiAssessments') }}
          </h2>
          <p
            v-if="assessments.length === 0"
            class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-2xs text-slate-400"
          >
            {{ t('tutoring2.admin.programDetail.emptyAssessments') }}
          </p>
          <ul v-else class="space-y-2">
            <li
              v-for="a in assessments"
              :key="a.id"
              class="flex items-center gap-3 rounded-3xl border border-slate-100 bg-white p-3.5 shadow-sm"
            >
              <span
                class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-emerald-100 text-emerald-700"
              >
                <NavIcon name="file-text" :size="16" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-2xs font-bold text-slate-900">{{ a.title }}</p>
                <p class="truncate text-2xs text-slate-500">{{ assessmentSubtitle(a) }}</p>
              </div>
              <!-- Only offered when there ARE scores to look at; a row
                   with none would otherwise be a link to an empty page. -->
              <button
                v-if="(a.scores_count ?? 0) > 0"
                type="button"
                class="shrink-0 text-2xs font-bold text-brand-cobalt hover:underline"
                @click="goAssessments"
              >
                {{ t('tutoring2.admin.programDetail.viewScores') }}
              </button>
              <StatusBadge
                :label="
                  a.published_at ? t('tutoring2.status.published') : t('tutoring2.status.draft')
                "
                :tone="a.published_at ? 'success' : 'neutral'"
                uppercase
              />
            </li>
          </ul>
        </section>
      </template>
    </AsyncView>
  </div>
</template>
