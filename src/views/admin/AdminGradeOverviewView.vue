<!--
  AdminGradeOverviewView.vue — admin Gradebook (school-wide).

  Port of Flutter's `admin_grade_overview_screen.dart`. The page is a
  school-wide overview, not a per-class drill:

    1. BrandPageHeader (admin) — kicker "AKADEMIK" + title "Gradebook"
    2. KPI strip (3 cells): NILAI / RATA-RATA / LULUS ≥75
    3. Sebaran Grade card — distribution bar (Tuntas/Perlu/Remedial)
       + 3 tinted pills + meta chips (N teacher · N student)
    4. Search bar — filter the per-teacher cards by name
    5. "PER GURU · N ORANG" section header
    6. Per-teacher cards: 4px score edge, initial avatar, name +
       meta line, avg pill, pass-rate progress bar, subject mini-chips
       (max 5 + overflow)
       Tap → opens teacher's grade book scoped to that teacher's
       assessments (admin view of the grade book).

  Endpoint: GET /grades/admin-overview?academic_year_id=…
  Refetches on AY change.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { GradeService } from '@/services/grades.service';
import type {
  AdminGradeOverview,
  AdminOverviewTeacher,
} from '@/types/grades';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useDataRefresh } from '@/composables/useDataRefresh';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import SectionHeader from '@/components/ui/SectionHeader.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const ayStore = useAcademicYearStore();
const { t } = useI18n();

const searchQuery = ref('');

// Load lifecycle (mount + academic-year refetch) via the shared
// composable. `watchLocale: false` preserves the prior behaviour — this
// view only re-fetched on academic-year change, not on locale switch.
const { state: loadState, reload: load } = useDataRefresh<AdminGradeOverview>(
  () =>
    GradeService.getAdminOverview({
      academic_year_id: ayStore.selectedYearId ?? undefined,
    }),
  { watchLocale: false },
);

const overview = computed(() => loadState.value.data ?? null);

// ── Derived state ─────────────────────────────────────────────────
const schoolStats = computed(() => overview.value?.school_stats);
const teachers = computed(() => overview.value?.teachers ?? []);

const filteredTeachers = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return teachers.value;
  return teachers.value.filter((t) =>
    t.teacher_name.toLowerCase().includes(q),
  );
});

const distTotal = computed(() => {
  const d = schoolStats.value?.distribution;
  if (!d) return 0;
  return d.high + d.mid + d.low;
});

function distPct(n: number): string {
  if (distTotal.value === 0) return '0%';
  return `${Math.round((n / distTotal.value) * 100)}%`;
}

// ── State for AsyncView ────────────────────────────────────────────
// Derived from the shared loader's state, but with this view's own
// "empty" rule (no teachers to show even if the overview object exists).
const state = computed<AsyncState<AdminGradeOverview>>(() => {
  if (loadState.value.status === 'loading') return { status: 'loading' };
  if (loadState.value.status === 'error') {
    return { status: 'error', error: loadState.value.error };
  }
  if (!overview.value || teachers.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: overview.value };
});

// ── Score color helpers — mirror mobile's _scoreColor + AvgPill ────
function scoreEdgeCls(score: number | null): string {
  if (score === null) return 'bg-slate-300';
  if (score >= 80) return 'bg-emerald-600';
  if (score >= 60) return 'bg-amber-600';
  return 'bg-red-600';
}
function avgPillCls(score: number): {
  bg: string;
  text: string;
  textMuted: string;
} {
  if (score >= 80) {
    return { bg: 'bg-emerald-50', text: 'text-emerald-700', textMuted: 'text-emerald-600' };
  }
  if (score >= 60) {
    return { bg: 'bg-amber-50', text: 'text-amber-700', textMuted: 'text-amber-600' };
  }
  return { bg: 'bg-red-50', text: 'text-red-700', textMuted: 'text-red-600' };
}
function passRateBarCls(rate: number): string {
  if (rate >= 75) return 'bg-emerald-600';
  if (rate >= 50) return 'bg-amber-600';
  return 'bg-red-600';
}
function subjectChipScoreCls(avg: number | null): string {
  if (avg === null) return 'text-slate-500';
  if (avg >= 80) return 'text-emerald-700';
  if (avg >= 60) return 'text-amber-700';
  return 'text-red-700';
}

// ── Actions ────────────────────────────────────────────────────────
function openTeacher(t: AdminOverviewTeacher) {
  // Admin-side drill — mounts TeacherGradeBookView via the
  // admin-gated route (mirrors mobile's GradePage(teacher=admin-view)).
  router.push({
    name: 'admin.grades.teacher',
    params: { teacherId: t.teacher_id },
    query: { teacher_id: t.teacher_id, admin_view: '1' },
  });
}

function passRate(row: AdminOverviewTeacher): number {
  if (row.total_grades === 0) return 0;
  return Math.round((row.passed / row.total_grades) * 100);
}

const headerMeta = computed(() =>
  schoolStats.value
    ? t('admin.sekolah.grade_overview.header_meta', {
        teachers: schoolStats.value.total_teachers,
        students: schoolStats.value.total_students,
        grades: schoolStats.value.total_grades,
      })
    : t('admin.sekolah.grade_overview.header_meta_fallback'),
);
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- 1. Header with embedded search (mobile parity: search lives
         inside the gradient hero via bottomSlot). -->
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.grade_overview.header_kicker')"
      :title="t('admin.sekolah.grade_overview.header_title')"
      :meta="headerMeta"
      :live-dot="false"
    >
      <template #default>
        <div
          class="mt-3 flex items-center gap-2 bg-white rounded-xl px-3 py-2 shadow-md"
        >
          <NavIcon name="search" :size="14" class="text-slate-400" />
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="t('admin.sekolah.grade_overview.search_placeholder')"
            class="flex-1 text-[13px] text-slate-900 outline-none placeholder-slate-400 bg-transparent"
          />
        </div>
      </template>
    </BrandPageHeader>

    <AsyncView
      :state="state"
      :empty-title="t('admin.sekolah.grade_overview.empty_title')"
      :empty-description="t('admin.sekolah.grade_overview.empty_description')"
      empty-icon="edit"
      @retry="load"
    >
      <template #default>
        <!-- AsyncView's default slot has no inherent gap between
             siblings — wrap in space-y-* so KPI strip, distribution
             card, section header, and per-teacher cards each get
             16px of breathing room. -->
        <div class="space-y-md">
        <!-- 2. KPI strip (3 cells) — mobile-parity: NILAI / RATA-RATA / LULUS ≥75 -->
        <section
          class="bg-white border border-slate-200 rounded-2xl px-1 py-3 shadow-sm grid grid-cols-3 divide-x divide-slate-100"
        >
          <div class="text-center px-2">
            <p class="text-[22px] font-black text-role-admin leading-none tracking-tight">
              {{ schoolStats?.total_grades ?? 0 }}
            </p>
            <p class="text-3xs font-black text-slate-500 uppercase tracking-widest mt-1.5">
              {{ t('admin.sekolah.grade_overview.kpi_grades') }}
            </p>
          </div>
          <div class="text-center px-2">
            <p class="text-[22px] font-black text-slate-800 leading-none tracking-tight">
              {{ (schoolStats?.avg_score ?? 0).toFixed(1) }}
            </p>
            <p class="text-3xs font-black text-slate-500 uppercase tracking-widest mt-1.5">
              {{ t('admin.sekolah.grade_overview.kpi_average') }}
            </p>
          </div>
          <div class="text-center px-2">
            <p class="text-[22px] font-black text-emerald-600 leading-none tracking-tight">
              {{ Math.round(schoolStats?.pass_rate ?? 0) }}%
            </p>
            <p class="text-3xs font-black text-slate-500 uppercase tracking-widest mt-1.5">
              {{ t('admin.sekolah.grade_overview.kpi_pass_rate') }}
            </p>
          </div>
        </section>

        <!-- 3. Sebaran Grade card -->
        <section class="bg-white border border-slate-200 rounded-2xl p-3.5">
          <SectionHeader :title="t('admin.sekolah.grade_overview.distribution_title')">
            <template #action>
              <span class="text-3xs font-bold text-slate-500 tracking-wider">
                {{ t('admin.sekolah.grade_overview.distribution_meta', { count: schoolStats?.total_grades ?? 0 }) }}
              </span>
            </template>
          </SectionHeader>

          <!-- Stacked distribution bar -->
          <div class="h-2.5 rounded-md overflow-hidden bg-slate-100 flex">
            <template v-if="distTotal > 0">
              <div
                v-if="schoolStats!.distribution.high > 0"
                class="bg-emerald-600 transition-all"
                :style="{ flex: schoolStats!.distribution.high }"
              />
              <div
                v-if="schoolStats!.distribution.mid > 0"
                class="bg-amber-600 transition-all"
                :style="{ flex: schoolStats!.distribution.mid }"
              />
              <div
                v-if="schoolStats!.distribution.low > 0"
                class="bg-red-600 transition-all"
                :style="{ flex: schoolStats!.distribution.low }"
              />
            </template>
          </div>

          <!-- 3 tinted pills -->
          <div class="grid grid-cols-3 gap-2 mt-3">
            <div class="rounded-xl bg-emerald-50 border border-emerald-200 p-2.5">
              <div class="flex items-center justify-between">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-600" />
                <span class="text-3xs font-bold text-slate-500">
                  {{ distPct(schoolStats?.distribution.high ?? 0) }}
                </span>
              </div>
              <p class="text-4xs font-bold text-slate-600 tracking-widest mt-1.5">
                {{ t('admin.sekolah.grade_overview.dist_high') }}
              </p>
              <p class="text-[18px] font-black text-emerald-700 leading-none tracking-tight mt-1">
                {{ schoolStats?.distribution.high ?? 0 }}
              </p>
            </div>

            <div class="rounded-xl bg-amber-50 border border-amber-200 p-2.5">
              <div class="flex items-center justify-between">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-600" />
                <span class="text-3xs font-bold text-slate-500">
                  {{ distPct(schoolStats?.distribution.mid ?? 0) }}
                </span>
              </div>
              <p class="text-4xs font-bold text-slate-600 tracking-widest mt-1.5">
                {{ t('admin.sekolah.grade_overview.dist_mid') }}
              </p>
              <p class="text-[18px] font-black text-amber-700 leading-none tracking-tight mt-1">
                {{ schoolStats?.distribution.mid ?? 0 }}
              </p>
            </div>

            <div class="rounded-xl bg-red-50 border border-red-200 p-2.5">
              <div class="flex items-center justify-between">
                <span class="w-1.5 h-1.5 rounded-full bg-red-600" />
                <span class="text-3xs font-bold text-slate-500">
                  {{ distPct(schoolStats?.distribution.low ?? 0) }}
                </span>
              </div>
              <p class="text-4xs font-bold text-slate-600 tracking-widest mt-1.5">
                {{ t('admin.sekolah.grade_overview.dist_low') }}
              </p>
              <p class="text-[18px] font-black text-red-700 leading-none tracking-tight mt-1">
                {{ schoolStats?.distribution.low ?? 0 }}
              </p>
            </div>
          </div>

          <!-- Footer meta chips -->
          <div class="flex flex-wrap items-center gap-2 mt-3">
            <span
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-50 border border-slate-200 text-2xs font-bold text-slate-700"
            >
              <NavIcon name="user" :size="11" class="text-slate-500" />
              {{ t('admin.sekolah.grade_overview.teachers_count', { count: schoolStats?.total_teachers ?? 0 }) }}
            </span>
            <span
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-50 border border-slate-200 text-2xs font-bold text-slate-700"
            >
              <NavIcon name="users" :size="11" class="text-slate-500" />
              {{ t('admin.sekolah.grade_overview.students_count', { count: schoolStats?.total_students ?? 0 }) }}
            </span>
          </div>
        </section>

        <!-- 4. Per-teacher section header -->
        <header class="flex items-center gap-2 px-1 pt-2">
          <NavIcon name="user" :size="12" class="text-slate-500" />
          <span class="text-[9.5px] font-black text-slate-500 uppercase tracking-widest">
            {{ t('admin.sekolah.grade_overview.per_teacher_label') }}
          </span>
          <span class="text-[9.5px] font-black text-slate-300 uppercase tracking-widest">
            {{ t('admin.sekolah.grade_overview.per_teacher_count', { count: filteredTeachers.length }) }}
          </span>
          <span class="flex-1 h-px bg-slate-100" />
        </header>

        <!-- 5. Empty when search has no match -->
        <div
          v-if="filteredTeachers.length === 0"
          class="text-center py-8 text-[12px] text-slate-400 bg-white border border-slate-200 rounded-2xl"
        >
          {{ t('admin.sekolah.grade_overview.no_matching_teachers') }}
        </div>

        <!-- 6. Per-teacher cards -->
        <article
          v-for="row in filteredTeachers"
          :key="row.teacher_id"
          class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden hover:shadow-md transition-shadow cursor-pointer flex"
          @click="openTeacher(row)"
        >
          <!-- 4px colored score edge -->
          <div
            class="w-1 flex-shrink-0"
            :class="scoreEdgeCls(row.total_grades > 0 ? row.avg_score : null)"
          />
          <div class="flex-1 p-3 space-y-2.5">
            <!-- Row 1: avatar + name/meta + avg pill + chevron -->
            <div class="flex items-start gap-3">
              <InitialsAvatar
                :name="row.teacher_name"
                :size="38"
                :border-radius="11"
                color="#1B6FB8"
              />
              <div class="flex-1 min-w-0">
                <p class="text-[13.5px] font-black text-slate-900 truncate">
                  {{ row.teacher_name }}
                </p>
                <p class="text-[10.5px] font-bold text-slate-500 mt-0.5 truncate">
                  {{ t('admin.sekolah.grade_overview.teacher_meta', { subjects: row.subject_count, classes: row.class_count, grades: row.total_grades }) }}
                </p>
              </div>
              <div
                v-if="row.total_grades > 0"
                class="px-2 py-1 rounded-lg flex-shrink-0 text-center"
                :class="avgPillCls(row.avg_score).bg"
              >
                <p
                  class="text-[13.5px] font-black leading-none"
                  :class="avgPillCls(row.avg_score).text"
                >
                  {{ row.avg_score.toFixed(1) }}
                </p>
                <p
                  class="text-[8.5px] font-black tracking-widest mt-0.5"
                  :class="avgPillCls(row.avg_score).textMuted"
                >
                  {{ t('admin.sekolah.grade_overview.avg') }}
                </p>
              </div>
              <NavIcon name="chevron-right" :size="14" class="text-slate-400 mt-2" />
            </div>

            <!-- Row 2: pass-rate progress bar -->
            <div v-if="row.total_grades > 0" class="flex items-center gap-2">
              <div class="flex-1 h-1.5 rounded-md overflow-hidden bg-slate-100">
                <div
                  class="h-full transition-all"
                  :class="passRateBarCls(passRate(row))"
                  :style="{ width: `${passRate(row)}%` }"
                />
              </div>
              <span class="text-[10.5px] font-black text-slate-600 tabular-nums">
                {{ t('admin.sekolah.grade_overview.pass_rate_label', { rate: passRate(row) }) }}
              </span>
            </div>

            <!-- Row 3: subject mini-chips (max 5 + overflow) -->
            <div
              v-if="row.subjects.length > 0"
              class="flex flex-wrap gap-1.5 items-center"
            >
              <span
                v-for="s in row.subjects.slice(0, 5)"
                :key="s.subject_id"
                class="inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-white border border-slate-200 text-[10.5px] font-bold text-slate-700"
              >
                {{ s.subject_name }}
                <template v-if="s.avg_score !== null">
                  <span class="w-px h-2.5 bg-slate-200" />
                  <span :class="subjectChipScoreCls(s.avg_score)">
                    {{ s.avg_score.toFixed(0) }}
                  </span>
                </template>
              </span>
              <span
                v-if="row.subjects.length > 5"
                class="inline-flex items-center px-2 py-1 rounded-md bg-slate-100 text-[10.5px] font-bold text-slate-600"
              >
                {{ t('admin.sekolah.grade_overview.more_subjects', { count: row.subjects.length - 5 }) }}
              </span>
            </div>
          </div>
        </article>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
