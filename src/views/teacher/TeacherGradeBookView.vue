<!--
  TeacherGradeBookView.vue — Grade Student (Gradebook).

  Web port of Flutter's `teacher_grade_input_screen.dart`. Same flow
  shape as Presensi:

    Default landing (no specific filter):
      1. <BrandPageHeader> (teacher) + <RoleToggleChipRow> (Mengajar/Parent)
      2. <KpiStripCards> — Total mapel / Asesmen / Rerata / Belum
      3. <PageFilterToolbar> — Kelas + Mapel chips + search
      4. Day-style summary cards: one per (class, subject) combo, with
         avg badge + meta cells + assessment type pills + progress bar
         + "Buka ›" CTA. Click → drills into the matrix mode.

    Matrix mode (after a card is opened):
      • Header gets a back chip; sub-meta shows class+subject names
      • Type tabs (Semua/Tugas/UH/UTS/UAS) + KKM summary strip
      • Editable matrix with Tab/Arrow/Enter nav + autosave-on-blur
        + Ctrl+S save + bulk-fill-column
      • Sticky save bar with dirty counter
-->
<script setup lang="ts">
import {
  computed,
  nextTick,
  onMounted,
  onUnmounted,
  ref,
  watch,
} from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { GradeService } from '@/services/grades.service';
import { localISODate } from '@/lib/format';
import type { Classroom, Subject } from '@/types/entities';
import type {
  Assessment,
  AssessmentType,
  GradeMatrix,
  TeacherGradeSummaryClass,
  TeacherGradeSummarySubject,
} from '@/types/grades';
import { ASSESSMENT_LABELS } from '@/types/grades';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import RoleToggleChipRow, {
  type RoleOption,
} from '@/components/feature/RoleToggleChipRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import GradeSubjectCard from '@/components/feature/GradeSubjectCard.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { fromQuickAction, queryString } = useQuickAction();
const auth = useAuthStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

// ── Admin-view support ──
// Admins can drill into a teacher's gradebook from
// AdminGradeOverviewView. The route is /admin/grades/teacher/:teacherId
// (with `?teacher_id=...` query alias). When that param is present,
// every API call here must use it instead of the logged-in user's id
// — otherwise the page loads the admin's own (empty) gradebook and
// renders "Belum ada mapel terdaftar".
const routeTeacherId = computed<string>(() => {
  const fromParam = route.params.teacherId;
  if (typeof fromParam === 'string' && fromParam.length > 0) return fromParam;
  const fromQuery = route.query.teacher_id;
  if (typeof fromQuery === 'string' && fromQuery.length > 0) return fromQuery;
  return '';
});
const isAdminView = computed(() => routeTeacherId.value.length > 0);
const effectiveTeacherId = computed<string>(
  () => routeTeacherId.value || auth.teacherId || auth.user?.id || '',
);

// ── Role toggle (Mengajar / Parent) ──
const selectedRoleId = ref<string>('mengajar');
const roleOptions = computed<RoleOption[]>(() => {
  const out: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: t('tutor.sekolah.gradebook.roleTeachingShort'),
      subLabel: t('tutor.sekolah.gradebook.roleTeachingSub'),
      avatarInitials: 'M',
    },
  ];
  for (const hc of auth.homeroomClasses) {
    const name = hc.name || hc.id;
    out.push({
      id: `wali:${hc.id}`,
      shortName: t('tutor.sekolah.gradebook.roleHomeroomShort', { name }),
      subLabel: t('tutor.sekolah.gradebook.roleHomeroomSub'),
      avatarInitials:
        name.length <= 2
          ? name.toUpperCase()
          : name.slice(0, 2).toUpperCase(),
    });
  }
  return out;
});
const isWaliMode = computed(() => selectedRoleId.value.startsWith('wali:'));
const activeHomeroomId = computed(() =>
  isWaliMode.value ? selectedRoleId.value.slice(5) : null,
);

// ── Filter state ──
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const classFilter = ref<string>('');
const subjectFilter = ref<string>('');
const semester = ref<string>('genap'); // kept internal; not surfaced
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);

// ── Summary state (default landing) ──
const summary = ref<TeacherGradeSummaryClass[]>([]);
const isSummaryLoading = ref(true);
const summaryError = ref<string | null>(null);

// Matrix state, computeds, and helpers live in the sibling
// TeacherGradeMatrixView.vue — this view is list-only now.

const activeClass = computed(
  () => classes.value.find((c) => c.id === classFilter.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectFilter.value) ?? null,
);

// ── Summary derived ──
//
// Backend (`GradeController::teacherSummary` + school-aware
// `Teacher::resolveId`) now scopes (class, subject) combos to the
// active school, so this just flattens (no client-side cross-school
// filter needed).
const flatCards = computed<
  Array<{
    class_id: string;
    class_name: string;
    grade_level: string;
    student_count: number;
    subject: TeacherGradeSummarySubject;
  }>
>(() => {
  const out: Array<{
    class_id: string;
    class_name: string;
    grade_level: string;
    student_count: number;
    subject: TeacherGradeSummarySubject;
  }> = [];
  for (const c of summary.value) {
    for (const s of c.subjects) {
      out.push({
        class_id: c.class_id,
        class_name: c.class_name,
        grade_level: c.grade_level,
        student_count: c.student_count,
        subject: s,
      });
    }
  }
  return out;
});

const filteredCards = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return flatCards.value.filter((row) => {
    if (classFilter.value && row.class_id !== classFilter.value) return false;
    if (subjectFilter.value && row.subject.id !== subjectFilter.value)
      return false;
    if (q) {
      const blob =
        `${row.class_name} ${row.subject.name} ${row.subject.code}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

const summaryState = computed<AsyncState<typeof flatCards.value>>(() => {
  if (isSummaryLoading.value && summary.value.length === 0)
    return { status: 'loading' };
  if (summaryError.value)
    return { status: 'error', error: summaryError.value };
  if (filteredCards.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredCards.value };
});

const summaryKpi = computed<KpiCard[]>(() => {
  let totalCards = 0,
    totalAssessments = 0,
    sumAvg = 0,
    cardsWithAvg = 0,
    cardsBelumNilai = 0;
  for (const row of flatCards.value) {
    totalCards++;
    totalAssessments += row.subject.assessments.length;
    if (typeof row.subject.avg_score === 'number') {
      sumAvg += row.subject.avg_score;
      cardsWithAvg++;
    } else {
      cardsBelumNilai++;
    }
  }
  return [
    {
      icon: 'layers',
      label: t('tutor.sekolah.gradebook.kpiMapelKelas'),
      value: totalCards,
      tone: 'brand',
    },
    {
      icon: 'edit-3',
      label: t('tutor.sekolah.gradebook.kpiAsesmen'),
      value: totalAssessments,
      tone: 'violet',
    },
    {
      icon: 'bar-chart',
      label: t('tutor.sekolah.gradebook.kpiRerata'),
      value: cardsWithAvg
        ? Math.round((sumAvg / cardsWithAvg) * 10) / 10
        : '—',
      suffix: t('tutor.sekolah.gradebook.kpiRerataSuffix'),
      tone: 'green',
      accented: true,
    },
    {
      icon: 'bell',
      label: t('tutor.sekolah.gradebook.kpiBelumDinilai'),
      value: cardsBelumNilai,
      suffix: t('tutor.sekolah.gradebook.kpiBelumSuffix'),
      tone: cardsBelumNilai > 0 ? 'amber' : 'green',
    },
  ];
});


// ── Loaders ──
async function loadReferences() {
  try {
    const [c, s] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
    ]);
    classes.value = c.items;
    subjects.value = s.items;
    if (fromQuickAction.value) {
      classFilter.value = queryString('class_id') ?? '';
      subjectFilter.value = queryString('subject_id') ?? '';
    }
  } catch (e) {
    summaryError.value = (e as Error).message;
  }
}

async function loadSummary() {
  const teacherId = effectiveTeacherId.value;
  if (!teacherId) {
    isSummaryLoading.value = false;
    return;
  }
  isSummaryLoading.value = true;
  summaryError.value = null;
  try {
    summary.value = await GradeService.getTeacherSummary({
      teacher_id: teacherId,
      view: isWaliMode.value ? 'homeroom_teacher' : 'teaching',
      class_id: activeHomeroomId.value || undefined,
    });
  } catch (e) {
    summaryError.value = (e as Error).message;
  } finally {
    isSummaryLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await loadSummary();
});

useAcademicYearWatcher(() => loadSummary());

watch(selectedRoleId, () => {
  if (isWaliMode.value && activeHomeroomId.value) {
    classFilter.value = activeHomeroomId.value;
  } else if (!isWaliMode.value && fromQuickAction.value === false) {
    classFilter.value = '';
  }
  loadSummary();
});

// ── Navigate to the matrix view ──
// Split matrix (TeacherGradeMatrixView.vue) is behind
// `teacher.grades.matrix` (guru) and `admin.grades.teacher.matrix`
// (admin). Route-detect on `isAdminView` so an admin click doesn't
// try to push to the teacher-only route and bounce at the role
// guard. Query params (`?ay=` academic-year override, admin flags)
// follow the user through the drill.
function openMatrix(card: (typeof flatCards.value)[number]) {
  if (isAdminView.value) {
    router.push({
      name: 'admin.grades.teacher.matrix',
      params: {
        teacherId: routeTeacherId.value,
        classId: card.class_id,
        subjectId: card.subject.id,
      },
      query: route.query,
    });
    return;
  }
  router.push({
    name: 'teacher.grades.matrix',
    params: { classId: card.class_id, subjectId: card.subject.id },
    query: route.query,
  });
}

function pickClass(id: string) {
  classFilter.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectFilter.value = id;
  showSubjectPicker.value = false;
}

// ── Card helpers ──
function avgTone(avg: number | null, kkm = 75): {
  bg: string;
  text: string;
  border: string;
} {
  if (avg === null)
    return {
      bg: 'bg-slate-50',
      text: 'text-slate-400',
      border: 'border-slate-200',
    };
  if (avg >= 85)
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-700',
      border: 'border-emerald-200',
    };
  if (avg >= kkm)
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-700',
      border: 'border-emerald-200',
    };
  if (avg >= kkm - 10)
    return {
      bg: 'bg-amber-50',
      text: 'text-amber-700',
      border: 'border-amber-200',
    };
  return { bg: 'bg-red-50', text: 'text-red-700', border: 'border-red-200' };
}

function typePillClass(type: AssessmentType): string {
  switch (type) {
    case 'daily_test':
      return 'bg-violet-50 text-violet-700 border-violet-200';
    case 'midterm':
      return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'final_exam':
      return 'bg-red-50 text-red-700 border-red-200';
    case 'assignment':
      return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    default:
      return 'bg-slate-50 text-slate-600 border-slate-200';
  }
}

function typeCountsFor(s: TeacherGradeSummarySubject) {
  const m: Partial<Record<AssessmentType, number>> = {};
  for (const a of s.assessments) {
    m[a.type] = (m[a.type] ?? 0) + 1;
  }
  return Object.entries(m).map(([k, v]) => ({
    type: k as AssessmentType,
    count: v ?? 0,
  }));
}

// Localized label for an assessment type. Mirrors `ASSESSMENT_LABELS`
// from `@/types/grades` but routes through i18n so the headers,
// modals, and toasts in this view follow the active locale instead of
// surfacing the canonical Indonesian fallbacks.
function typeLabel(type: AssessmentType): string {
  switch (type) {
    case 'assignment':
      return t('tutor.sekolah.gradebook.typeAssignment');
    case 'daily_test':
      return t('tutor.sekolah.gradebook.typeDailyTest');
    case 'midterm':
      return t('tutor.sekolah.gradebook.typeMidterm');
    case 'final_exam':
      return t('tutor.sekolah.gradebook.typeFinalExam');
    case 'quiz':
      return t('tutor.sekolah.gradebook.typeQuiz');
    case 'other':
      return t('tutor.sekolah.gradebook.typeOther');
    default:
      return ASSESSMENT_LABELS[type];
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <!-- ── 1. Header ──────────────────────────────────────────
         List view — matrix has its own file
         (TeacherGradeMatrixView.vue) with its own header. -->
    <BrandPageHeader
      role="guru"
      :kicker="isWaliMode
        ? t('tutor.sekolah.gradebook.kickerHomeroom')
        : t('tutor.sekolah.gradebook.kickerDefault')"
      :title="t('tutor.sekolah.gradebook.titleSummary')"
      :meta="t('tutor.sekolah.gradebook.metaSummary', { count: flatCards.length })"
      :live-dot="false"
    >
      <template #role-toggle>
        <RoleToggleChipRow
          :roles="roleOptions"
          :selected-role-id="selectedRoleId"
          accent-color="#1B6FB8"
          @update:selected-role-id="(v) => (selectedRoleId = v)"
        />
      </template>
    </BrandPageHeader>

    <!-- ════════════════════════════════════════════════════════
         List — summary cards
         ════════════════════════════════════════════════════════ -->
      <KpiStripCards :cards="summaryKpi" />

      <PageFilterToolbar
        :search="searchQuery"
        :search-placeholder="t('tutor.sekolah.gradebook.searchSummaryPlaceholder')"
        @update:search="(v) => (searchQuery = v)"
      >
        <template #chips>
          <AppFilterChip
            v-if="!isWaliMode"
            :label="t('tutor.sekolah.gradebook.chipClass')"
            :value="activeClass?.name ?? t('tutor.sekolah.gradebook.allClasses')"
            icon-name="layers"
            tone="brand"
            @click="showClassPicker = true"
          />
          <AppFilterChip
            :label="t('tutor.sekolah.gradebook.chipSubject')"
            :value="activeSubject?.name ?? t('tutor.sekolah.gradebook.allSubjects')"
            icon-name="book"
            tone="amber"
            @click="showSubjectPicker = true"
          />
        </template>
      </PageFilterToolbar>

      <AsyncView
        :state="summaryState"
        :empty-title="t('tutor.sekolah.gradebook.emptyTitle')"
        :empty-description="t('tutor.sekolah.gradebook.emptyDescription')"
        @retry="loadSummary"
      >
        <template #default>
          <section
            class="grid grid-cols-1 lg:grid-cols-2 gap-3"
          >
            <!-- Round-11: extracted shared GradeSubjectCard so the
                 rekap main grid can adopt the same tile shape without
                 duplicating markup. Nilai keeps its type-pill +
                 progress-bar footer via the #footer slot; rekap
                 leaves the slot empty. -->
            <GradeSubjectCard
              v-for="row in filteredCards"
              :key="`${row.class_id}__${row.subject.id}`"
              :avg-score="row.subject.avg_score"
              :avg-tone="avgTone(row.subject.avg_score)"
              :class-label="t('tutor.sekolah.gradebook.cardClassPrefix', { name: row.class_name })"
              :subject-name="row.subject.name"
              :subject-detail="row.subject.code"
              :open-label="t('tutor.sekolah.gradebook.cardOpen')"
              :meta-cells="[
                { label: t('tutor.sekolah.gradebook.cardSiswa'), value: row.student_count },
                { label: t('tutor.sekolah.gradebook.cardAsesmen'), value: row.subject.assessments.length },
                { label: t('tutor.sekolah.gradebook.cardNilai'), value: row.subject.total_nilai },
              ]"
              @click="openMatrix(row)"
            >
              <template #footer>
                <!-- Type pills -->
                <div
                  v-if="row.subject.assessments.length > 0"
                  class="flex flex-wrap items-center gap-1.5"
                >
                  <span
                    v-for="tc in typeCountsFor(row.subject)"
                    :key="tc.type"
                    class="text-3xs font-bold uppercase tracking-widest px-2 py-0.5 rounded-full border"
                    :class="typePillClass(tc.type)"
                  >
                    {{ typeLabel(tc.type) }} × {{ tc.count }}
                  </span>
                </div>

                <!-- Progress strip (1 bar per assessment) -->
                <div
                  v-if="row.subject.assessments.length > 0"
                  class="flex items-center gap-1 mt-3 h-1 rounded-full overflow-hidden bg-slate-100"
                >
                  <span
                    v-for="a in row.subject.assessments"
                    :key="a.id"
                    class="h-full flex-1 transition-colors"
                    :class="
                      a.avg !== null
                        ? a.avg >= 75
                          ? 'bg-emerald-500'
                          : 'bg-amber-500'
                        : 'bg-slate-200'
                    "
                    :title="`${a.label}: ${a.avg ?? t('tutor.sekolah.gradebook.cardProgressNoScore')}`"
                  ></span>
                </div>

                <!-- Empty assessment hint -->
                <p
                  v-else
                  class="text-2xs text-slate-400 inline-flex items-center gap-1.5"
                >
                  <NavIcon name="bell" :size="11" />
                  {{ t('tutor.sekolah.gradebook.cardEmptyAssessment') }}
                </p>
              </template>
            </GradeSubjectCard>
          </section>
        </template>
      </AsyncView>

    <Modal
      v-if="showClassPicker"
      :title="t('tutor.sekolah.gradebook.pickClassTitle')"
      @close="showClassPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold': !classFilter,
            }"
            @click="pickClass('')"
          >
            {{ t('tutor.sekolah.gradebook.allClasses') }}
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                c.id === classFilter,
            }"
            @click="pickClass(c.id)"
          >
            <span>{{ c.name }}</span>
            <span class="text-3xs text-slate-400">
              {{ t('tutor.sekolah.gradebook.pickClassStudents', { count: c.student_count }) }}
            </span>
          </button>
        </li>
      </ul>
    </Modal>

    <Modal
      v-if="showSubjectPicker"
      :title="t('tutor.sekolah.gradebook.pickSubjectTitle')"
      @close="showSubjectPicker = false"
    >
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold': !subjectFilter,
            }"
            @click="pickSubject('')"
          >
            {{ t('tutor.sekolah.gradebook.allSubjects') }}
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 flex items-center justify-between"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                s.id === subjectFilter,
            }"
            @click="pickSubject(s.id)"
          >
            <span>{{ s.name }}</span>
            <span v-if="s.code" class="text-3xs text-slate-400">{{
              s.code
            }}</span>
          </button>
        </li>
      </ul>
    </Modal>

  </div>
</template>
