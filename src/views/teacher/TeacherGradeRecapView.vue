<!--
  TeacherGradeRecapView.vue — Rekap Grade overview (teacher).

  Web port of Flutter's `teacher_grade_recap_overview.dart`. Same
  shape as Gradebook's summary landing but with recap-specific KPIs
  (progress %, Bab count, avg final) and a per-card "Buka Rekap" CTA
  that drills into the editable matrix (Phase 3).

  Layout:
    1. <BrandPageHeader> (teacher) + <RoleToggleChipRow> (Mengajar / Parent)
    2. <KpiStripCards> — Mapel·Kelas / Bab / Rerata / Kelengkapan%
    3. <PageFilterToolbar> — Kelas + Mapel chips + search
    4. Cards (one per class+subject) with:
       avg badge · class+subject name · teacher chip (parent view) ·
       progress bar · Bab count · Rerata · "Buka ›"
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { GradeRecapService } from '@/services/grade-recap.service';
import type { Classroom, Subject } from '@/types/entities';
import type {
  TeacherGradeRecapClass,
  TeacherGradeRecapSubject,
  TeacherGradeRecapSummary,
} from '@/types/grade-recap';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import RoleToggleChipRow, {
  type RoleOption,
} from '@/components/feature/RoleToggleChipRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const router = useRouter();
const auth = useAuthStore();
const { t } = useI18n();

// ── Role toggle (Mengajar / Homeroom Teacher) ──
const selectedRoleId = ref<string>('mengajar');
const roleOptions = computed<RoleOption[]>(() => {
  const out: RoleOption[] = [
    {
      id: 'mengajar',
      shortName: t('tutor.sekolah.gradeRecap.roleTeachingShort'),
      subLabel: t('tutor.sekolah.gradeRecap.roleTeachingSub'),
      avatarInitials: 'M',
    },
  ];
  for (const hc of auth.homeroomClasses) {
    const name = hc.name || hc.id;
    out.push({
      id: `wali:${hc.id}`,
      shortName: t('tutor.sekolah.gradeRecap.roleHomeroomShort', { name }),
      subLabel: t('tutor.sekolah.gradeRecap.roleHomeroomSub'),
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
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);

// ── Summary state ──
const summary = ref<TeacherGradeRecapClass[]>([]);
const serverSummary = ref<TeacherGradeRecapSummary | null>(null);
const isSummaryLoading = ref(true);
const summaryError = ref<string | null>(null);

const activeClass = computed(
  () => classes.value.find((c) => c.id === classFilter.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectFilter.value) ?? null,
);

// ── Derived cards ──
//
// One card per (class, subject) pair. Backend `/grade-recaps/
// teacher-summary` already scopes to active school via the school-
// aware Teacher::resolveId — no client-side cross-school guard
// needed.
interface RecapCardRow {
  class_id: string;
  class_name: string;
  student_count: number;
  subject: TeacherGradeRecapSubject;
}

const flatCards = computed<RecapCardRow[]>(() => {
  const out: RecapCardRow[] = [];
  for (const c of summary.value) {
    for (const s of c.subjects) {
      out.push({
        class_id: c.class_id,
        class_name: c.class_name,
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
      const teacherName = row.subject.teacher_name ?? '';
      const blob =
        `${row.class_name} ${row.subject.name} ${row.subject.code ?? ''} ${teacherName}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

const summaryState = computed<AsyncState<RecapCardRow[]>>(() => {
  if (isSummaryLoading.value && summary.value.length === 0)
    return { status: 'loading' };
  if (summaryError.value)
    return { status: 'error', error: summaryError.value };
  if (filteredCards.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredCards.value };
});

// KPI prefers server-computed summary (weighted, accurate across
// pagination) and falls back to derived counts on first paint.
const summaryKpi = computed<KpiCard[]>(() => {
  const s = serverSummary.value;
  const totalCards = flatCards.value.length;
  let totalBab = 0;
  for (const r of flatCards.value) totalBab += r.subject.chapter_count;

  const completionPct = s?.overall_completion_pct ?? 0;
  const avg = s?.overall_avg_score;

  return [
    {
      icon: 'layers',
      label: t('tutor.sekolah.gradeRecap.kpiSubjectClass'),
      value: totalCards,
      tone: 'brand',
    },
    {
      icon: 'book-open',
      label: t('tutor.sekolah.gradeRecap.kpiTotalChapters'),
      value: totalBab,
      tone: 'violet',
    },
    {
      icon: 'bar-chart',
      label: t('tutor.sekolah.gradeRecap.kpiAverage'),
      value: typeof avg === 'number' ? Math.round(avg * 10) / 10 : '—',
      suffix: t('tutor.sekolah.gradeRecap.kpiAverageSuffix'),
      tone: 'green',
      accented: true,
    },
    {
      icon: 'check-circle',
      label: t('tutor.sekolah.gradeRecap.kpiCompleteness'),
      value: completionPct,
      suffix: '%',
      tone:
        completionPct >= 80
          ? 'green'
          : completionPct >= 40
            ? 'amber'
            : 'red',
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
  } catch (e) {
    summaryError.value = (e as Error).message;
  }
}

async function loadSummary() {
  const teacherId = auth.teacherId ?? auth.user?.id ?? '';
  if (!teacherId) {
    isSummaryLoading.value = false;
    summaryError.value = t('tutor.sekolah.gradeRecap.teacherProfileMissing');
    return;
  }
  isSummaryLoading.value = true;
  summaryError.value = null;
  try {
    // academic_year_id auto-injected by the axios interceptor.
    const resp = await GradeRecapService.getTeacherSummary({
      teacher_id: teacherId,
      view: isWaliMode.value ? 'homeroom_teacher' : 'teaching',
      class_id: activeHomeroomId.value || undefined,
    });
    summary.value = resp.data;
    serverSummary.value = resp.summary;
  } catch (e) {
    summaryError.value = (e as Error).message;
  } finally {
    isSummaryLoading.value = false;
  }
}

watch(selectedRoleId, () => {
  if (isWaliMode.value && activeHomeroomId.value) {
    classFilter.value = activeHomeroomId.value;
  } else {
    classFilter.value = '';
  }
  loadSummary();
});

onMounted(async () => {
  await Promise.all([loadReferences(), loadSummary()]);
});

useAcademicYearWatcher(() => loadSummary());

// ── Navigation ──
function openMatrix(card: RecapCardRow) {
  router.push({
    name: 'teacher.grade-recap.detail',
    params: { classId: card.class_id, subjectId: card.subject.id },
    query: {
      className: card.class_name,
      subjectName: card.subject.name,
    },
  });
}

// ── Card visual helpers ──
function avgTone(score: number | null) {
  if (score === null) return { bg: 'bg-slate-100', text: 'text-slate-500' };
  if (score >= 80) return { bg: 'bg-emerald-50', text: 'text-emerald-700' };
  if (score >= 60) return { bg: 'bg-amber-50', text: 'text-amber-700' };
  return { bg: 'bg-red-50', text: 'text-red-700' };
}

function progressBarTone(pct: number) {
  if (pct >= 80) return 'bg-emerald-500';
  if (pct >= 40) return 'bg-amber-500';
  return 'bg-red-500';
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      :kicker="t('tutor.sekolah.gradeRecap.kicker')"
      :title="t('tutor.sekolah.gradeRecap.title')"
      :meta="t('tutor.sekolah.gradeRecap.meta')"
      :live-dot="false"
    >
      <template v-if="roleOptions.length > 1" #role-toggle>
        <RoleToggleChipRow
          :selected-role-id="selectedRoleId"
          :roles="roleOptions"
          @update:selected-role-id="selectedRoleId = $event"
        />
      </template>
    </BrandPageHeader>

    <!-- KPI -->
    <KpiStripCards :cards="summaryKpi" />

    <!-- FILTERS -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      :search-placeholder="t('tutor.sekolah.gradeRecap.searchPlaceholder')"
    >
      <template #chips>
        <AppFilterChip
          v-if="!isWaliMode"
          :label="t('tutor.sekolah.gradeRecap.chipClass')"
          :value="activeClass?.name ?? t('tutor.sekolah.gradeRecap.allClasses')"
          :is-active="!!classFilter"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          :label="t('tutor.sekolah.gradeRecap.chipSubject')"
          :value="activeSubject?.name ?? t('tutor.sekolah.gradeRecap.allSubjects')"
          :is-active="!!subjectFilter"
          @click="showSubjectPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- CARD LIST -->
    <AsyncView
      :state="summaryState"
      :empty-title="t('tutor.sekolah.gradeRecap.emptyTitle')"
      :empty-description="t('tutor.sekolah.gradeRecap.emptyDescription')"
      empty-icon="layers"
    >
      <div class="space-y-3">
        <article
          v-for="row in filteredCards"
          :key="`${row.class_id}__${row.subject.id}`"
          class="group bg-white border border-slate-200 rounded-2xl px-4 py-3 hover:border-brand-cobalt/40 hover:shadow-sm transition cursor-pointer"
          @click="openMatrix(row)"
        >
          <!-- Top row: avg badge + class+subject + open chevron -->
          <div class="flex items-start gap-3">
            <div
              class="w-12 h-12 rounded-2xl border grid place-items-center text-[13px] font-black flex-shrink-0"
              :class="[
                avgTone(row.subject.avg_final_score).bg,
                avgTone(row.subject.avg_final_score).text,
                'border-current/20',
              ]"
            >
              <span v-if="row.subject.avg_final_score !== null">
                {{ Math.round(row.subject.avg_final_score) }}
              </span>
              <span v-else>—</span>
            </div>
            <div class="flex-1 min-w-0">
              <p
                class="text-[10px] font-bold uppercase tracking-widest text-brand-cobalt/80"
              >
                {{ t('tutor.sekolah.gradeRecap.classLabel', { name: row.class_name }) }}
              </p>
              <h3 class="text-[15px] font-extrabold text-slate-900 mt-0.5 leading-tight truncate">
                {{ row.subject.name }}
              </h3>
              <p
                v-if="row.subject.code || row.subject.teacher_name"
                class="text-[11px] text-slate-500 mt-0.5 truncate"
              >
                <template v-if="row.subject.code">{{ row.subject.code }}</template>
                <template v-if="row.subject.code && row.subject.teacher_name"> · </template>
                <template v-if="row.subject.teacher_name && isWaliMode">
                  {{ t('tutor.sekolah.gradeRecap.byTeacher', { name: row.subject.teacher_name }) }}
                </template>
              </p>
            </div>
            <div class="text-brand-cobalt/70 font-bold text-[12px] flex-shrink-0 inline-flex items-center gap-1">
              {{ t('tutor.sekolah.gradeRecap.open') }}
              <NavIcon name="chevron-right" :size="14" />
            </div>
          </div>

          <!-- Meta cells -->
          <div class="grid grid-cols-3 gap-2 mt-3">
            <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
              <p
                class="text-[9px] font-bold uppercase tracking-widest text-slate-500"
              >
                {{ t('tutor.sekolah.gradeRecap.cellStudents') }}
              </p>
              <p class="text-[12px] font-black text-slate-900 mt-0.5">
                {{ row.subject.recap_count }} / {{ row.subject.total_students }}
              </p>
            </div>
            <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
              <p
                class="text-[9px] font-bold uppercase tracking-widest text-slate-500"
              >
                {{ t('tutor.sekolah.gradeRecap.cellChapters') }}
              </p>
              <p class="text-[12px] font-black text-slate-900 mt-0.5">
                {{ row.subject.chapter_count }}
              </p>
            </div>
            <div class="bg-slate-50 rounded-lg px-2 py-1.5 text-center">
              <p
                class="text-[9px] font-bold uppercase tracking-widest text-slate-500"
              >
                {{ t('tutor.sekolah.gradeRecap.cellAverage') }}
              </p>
              <p class="text-[12px] font-black text-slate-900 mt-0.5">
                {{ row.subject.avg_final_score !== null
                  ? Math.round(row.subject.avg_final_score * 10) / 10
                  : '—' }}
              </p>
            </div>
          </div>

          <!-- Progress strip -->
          <div class="mt-3">
            <div class="flex items-center justify-between mb-1">
              <span
                class="text-[10px] font-bold uppercase tracking-widest text-slate-500"
              >
                {{ t('tutor.sekolah.gradeRecap.completeness') }}
              </span>
              <span class="text-[11px] font-extrabold text-slate-700">
                {{ row.subject.completion_pct }}%
              </span>
            </div>
            <div class="h-1.5 rounded-full overflow-hidden bg-slate-100">
              <div
                class="h-full rounded-full transition-all"
                :class="progressBarTone(row.subject.completion_pct)"
                :style="{ width: `${Math.min(100, row.subject.completion_pct)}%` }"
              />
            </div>
          </div>
        </article>
      </div>
    </AsyncView>

    <!-- CLASS PICKER MODAL -->
    <Modal
      v-if="showClassPicker"
      :title="t('tutor.sekolah.gradeRecap.pickClassTitle')"
      @close="showClassPicker = false"
    >
      <div class="space-y-1.5 max-h-[60vh] overflow-y-auto">
        <button
          class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl border text-left transition"
          :class="
            classFilter === ''
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-200 hover:bg-slate-50'
          "
          @click="
            classFilter = '';
            showClassPicker = false;
          "
        >
          <span class="text-sm font-semibold text-slate-900">
            {{ t('tutor.sekolah.gradeRecap.allClasses') }}
          </span>
        </button>
        <button
          v-for="c in classes"
          :key="c.id"
          class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl border text-left transition"
          :class="
            classFilter === c.id
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-200 hover:bg-slate-50'
          "
          @click="
            classFilter = c.id;
            showClassPicker = false;
          "
        >
          <InitialsAvatar :name="c.name" :size="32" />
          <span class="text-sm font-semibold text-slate-900">{{ c.name }}</span>
        </button>
      </div>
    </Modal>

    <!-- SUBJECT PICKER MODAL -->
    <Modal
      v-if="showSubjectPicker"
      :title="t('tutor.sekolah.gradeRecap.pickSubjectTitle')"
      @close="showSubjectPicker = false"
    >
      <div class="space-y-1.5 max-h-[60vh] overflow-y-auto">
        <button
          class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl border text-left transition"
          :class="
            subjectFilter === ''
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-200 hover:bg-slate-50'
          "
          @click="
            subjectFilter = '';
            showSubjectPicker = false;
          "
        >
          <span class="text-sm font-semibold text-slate-900">
            {{ t('tutor.sekolah.gradeRecap.allSubjects') }}
          </span>
        </button>
        <button
          v-for="s in subjects"
          :key="s.id"
          class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl border text-left transition"
          :class="
            subjectFilter === s.id
              ? 'border-brand-cobalt bg-brand-cobalt/5'
              : 'border-slate-200 hover:bg-slate-50'
          "
          @click="
            subjectFilter = s.id;
            showSubjectPicker = false;
          "
        >
          <span class="text-sm font-semibold text-slate-900">{{ s.name }}</span>
        </button>
      </div>
    </Modal>
  </div>
</template>
