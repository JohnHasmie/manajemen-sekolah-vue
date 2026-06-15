<!--
  AdminClassActivityView.vue — Admin school-wide Kegiatan Kelas hub.

  Web port of Flutter's `admin_class_activity_screen.dart` (Fix-FF
  Frame A). Consumes `GET /class-activities/admin-summary` which
  returns one row per activity school-wide + KPI block + per-card
  submission progress summary.

  Layout:
    1. <BrandPageHeader> (admin navy)
    2. <KpiStripCards> — Total / Minggu Ini / Pending Submit
    3. <PageFilterToolbar> — Kelas / Mapel / Guru chips + search
    4. Type tabs — Semua / Tugas / PR / Ulangan / Lainnya
    5. Period chips — Hari Ini / 7H / 30H / Semester / Tahun
    6. <ActivityCard role="admin"> recent-first list (with submission
       progress bar + teacher name)
    7. Tap card → <ActivityDetailModal role="admin"> read-only
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { ClassActivityService } from '@/services/class-activity.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { TeacherService } from '@/services/teachers.service';
import type {
  ActivityPeriod,
  ActivitySubmissionRow,
  ActivityType,
  AdminActivityKpi,
  ClassActivity,
} from '@/types/class-activity';
import { ACTIVITY_PERIOD_LABELS } from '@/types/class-activity';
import type { Classroom, Subject, Teacher } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import ActivityCard from '@/components/feature/ActivityCard.vue';
import ActivityDetailModal from '@/components/feature/ActivityDetailModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

// ── Reference data (filter pickers) ──
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const teachers = ref<Teacher[]>([]);

// ── Filter state ──
const classFilter = ref<string>('');
const subjectFilter = ref<string>('');
const teacherFilter = ref<string>('');
const typeFilter = ref<ActivityType | 'all'>('all');
const periodFilter = ref<ActivityPeriod>('30d');
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);
const showTeacherPicker = ref(false);

const activeClass = computed(
  () => classes.value.find((c) => c.id === classFilter.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectFilter.value) ?? null,
);
const activeTeacher = computed(
  () => teachers.value.find((t) => t.id === teacherFilter.value) ?? null,
);

const { t: $t } = useI18n();

// ── Data state ──
const items = ref<ClassActivity[]>([]);
const kpi = ref<AdminActivityKpi>({
  total: 0,
  this_week: 0,
  pending_submissions: 0,
});
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// ── Detail modal ──
const detailTarget = ref<ClassActivity | null>(null);
const detailSubmissions = ref<ActivitySubmissionRow[]>([]);
const isDetailLoading = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Loaders ──
async function loadReferences() {
  try {
    const [c, s, t] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
      TeacherService.list({ per_page: 200 }),
    ]);
    classes.value = c.items;
    subjects.value = s.items;
    teachers.value = t.items;
  } catch {
    // ignore — pickers degrade
  }
}

async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const resp = await ClassActivityService.getAdminSummary({
      period: periodFilter.value,
      class_id: classFilter.value || undefined,
      subject_id: subjectFilter.value || undefined,
      teacher_id: teacherFilter.value || undefined,
      type: typeFilter.value === 'all' ? undefined : typeFilter.value,
      search: searchQuery.value || undefined,
      per_page: 100,
    });
    items.value = resp.items;
    kpi.value = resp.kpi;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await reload();
});

watch(
  [classFilter, subjectFilter, teacherFilter, typeFilter, periodFilter],
  () => reload(),
);
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(searchQuery, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => reload(), 350);
});

useAcademicYearWatcher(() => reload());

// ── Derived ──
const listState = computed<AsyncState<ClassActivity[]>>(() => {
  if (isLoading.value && items.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (items.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: items.value };
});

const kpiCards = computed<KpiCard[]>(() => {
  const pending = kpi.value.pending_submissions;
  return [
    {
      icon: 'activity',
      label: $t('admin.classActivity.kpiTotal'),
      value: kpi.value.total,
      suffix: $t('admin.classActivity.kpiTotalSuffix'),
      tone: 'brand',
    },
    {
      icon: 'calendar',
      label: $t('admin.classActivity.kpiThisWeek'),
      value: kpi.value.this_week,
      tone: 'violet',
    },
    {
      icon: 'alert-triangle',
      label: $t('admin.classActivity.kpiNoSubmit'),
      value: pending,
      suffix: $t('admin.classActivity.kpiNoSubmitSuffix'),
      tone: pending > 0 ? 'amber' : 'green',
      accented: pending > 0,
    },
    {
      icon: 'users',
      label: $t('admin.classActivity.kpiActiveTeachers'),
      value: new Set(
        items.value.map((i) => i.teacher_id).filter((id): id is string => !!id),
      ).size,
      suffix: $t('admin.classActivity.kpiActiveTeachersSuffix'),
      tone: 'green',
    },
  ];
});

const typeTabs = computed<{ key: ActivityType | 'all'; label: string }[]>(() => [
  { key: 'all', label: $t('admin.classActivity.typeAll') },
  { key: 'tugas', label: $t('admin.classActivity.typeTask') },
  { key: 'aktivitas', label: $t('admin.classActivity.typeActivity') },
  { key: 'ujian', label: $t('admin.classActivity.typeExam') },
  { key: 'catatan', label: $t('admin.classActivity.typeNote') },
]);

// Local labels so the period chips track the active locale; the static
// ACTIVITY_PERIOD_LABELS export stays Indonesian for the data layer.
const PERIOD_LABELS_LOCAL = computed<Record<ActivityPeriod, string>>(() => ({
  today: $t('admin.classActivity.periodToday'),
  '7d': $t('admin.classActivity.period7d'),
  '30d': $t('admin.classActivity.period30d'),
  semester: $t('admin.classActivity.periodSemester'),
  year: $t('admin.classActivity.periodYear'),
}));
const periodTabs = computed<{ key: ActivityPeriod; label: string }[]>(() =>
  (['today', '7d', '30d', 'semester', 'year'] as ActivityPeriod[]).map((k) => ({
    key: k,
    label: PERIOD_LABELS_LOCAL.value[k],
  })),
);

// ── Detail flow ──
async function openDetail(a: ClassActivity) {
  detailTarget.value = a;
  detailSubmissions.value = [];
  isDetailLoading.value = true;
  try {
    const [full, rows] = await Promise.all([
      ClassActivityService.getDetail(a.id),
      ClassActivityService.listSubmissions(a.id),
    ]);
    if (full) detailTarget.value = full;
    detailSubmissions.value = rows;
  } catch {
    // graceful — modal still shows summary
  } finally {
    isDetailLoading.value = false;
  }
}

function pickClass(id: string) {
  classFilter.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectFilter.value = id;
  showSubjectPicker.value = false;
}
function pickTeacher(id: string) {
  teacherFilter.value = id;
  showTeacherPicker.value = false;
}

function resetFilters() {
  classFilter.value = '';
  subjectFilter.value = '';
  teacherFilter.value = '';
  typeFilter.value = 'all';
  periodFilter.value = '30d';
  searchQuery.value = '';
}

const hasAnyFilter = computed(
  () =>
    !!classFilter.value ||
    !!subjectFilter.value ||
    !!teacherFilter.value ||
    typeFilter.value !== 'all' ||
    periodFilter.value !== '30d' ||
    !!searchQuery.value.trim(),
);

// ── CSV export (visible rows) ──
//
// Admin's view is a flat school-wide list — easier to export
// client-side than to call a per-slice xlsx endpoint. Respects
// whatever filter + sort the admin is currently seeing.
function csvEscape(v: unknown): string {
  const s = v === null || v === undefined ? '' : String(v);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function exportCsv() {
  const header = [
    'Tanggal',
    'Jam',
    'Kelas',
    'Mapel',
    'Guru',
    'Tipe',
    'Judul',
    'Deskripsi',
    'Siswa',
    'Submit',
    'Belum',
    'Telat',
    'Izin',
    'Rerata',
  ];
  const rowsCsv = items.value.map((it) =>
    [
      it.date,
      it.time ?? '',
      it.class_name,
      it.subject_name,
      it.teacher_name ?? '-',
      it.type,
      it.title,
      it.description ?? '',
      it.submissions.total_students,
      it.submissions.submitted,
      it.submissions.pending,
      it.submissions.late,
      it.submissions.excused,
      it.submissions.avg_score ?? '',
    ]
      .map(csvEscape)
      .join(','),
  );
  const csv = [header.map(csvEscape).join(','), ...rowsCsv].join('\n');
  const blob = new Blob(['﻿' + csv], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `kegiatan_kelas_${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  toast.value = { message: $t('admin.sekolah.class_activity.toast_csv_downloaded'), tone: 'success' };
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="$t('admin.classActivity.kicker')"
      :title="$t('admin.classActivity.title')"
      :meta="$t('admin.classActivity.subtitle')"
      :live-dot="false"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-full bg-white/15 hover:bg-white/25 text-white px-3 py-1.5 text-[12px] font-bold"
        :disabled="items.length === 0"
        @click="exportCsv"
      >
        <NavIcon name="download" :size="14" />
        {{ $t('admin.classActivity.exportCsv') }}
      </button>
    </BrandPageHeader>

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      :search-placeholder="$t('admin.classActivity.searchPlaceholder')"
    >
      <template #chips>
        <AppFilterChip
          :label="$t('admin.classActivity.filterClass')"
          :value="activeClass?.name ?? $t('admin.classActivity.allClasses')"
          :is-active="!!classFilter"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          :label="$t('admin.classActivity.filterSubject')"
          :value="activeSubject?.name ?? $t('admin.classActivity.allSubjects')"
          :is-active="!!subjectFilter"
          @click="showSubjectPicker = true"
        />
        <AppFilterChip
          :label="$t('admin.classActivity.filterTeacher')"
          :value="activeTeacher?.name ?? $t('admin.classActivity.allTeachers')"
          :is-active="!!teacherFilter"
          @click="showTeacherPicker = true"
        />
        <button
          v-if="hasAnyFilter"
          type="button"
          class="text-[11px] font-bold text-slate-500 hover:text-slate-900 px-2 py-1 inline-flex items-center gap-1"
          @click="resetFilters"
        >
          <NavIcon name="x" :size="12" />
          {{ $t('admin.classActivity.reset') }}
        </button>
      </template>
    </PageFilterToolbar>

    <!-- TYPE TABS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="tab in typeTabs"
        :key="tab.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
        :class="
          typeFilter === tab.key
            ? 'bg-role-admin text-white border-role-admin shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-role-admin/40'
        "
        @click="typeFilter = tab.key"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- PERIOD TABS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
        {{ $t('admin.classActivity.periodLabel') }}
      </span>
      <button
        v-for="p in periodTabs"
        :key="p.key"
        type="button"
        class="px-2.5 py-1 rounded-full text-[11px] font-bold transition border"
        :class="
          periodFilter === p.key
            ? 'bg-slate-900 text-white border-slate-900'
            : 'bg-white text-slate-500 border-slate-200 hover:border-slate-400'
        "
        @click="periodFilter = p.key"
      >
        {{ p.label }}
      </button>
    </div>

    <!-- LIST -->
    <AsyncView
      :state="listState"
      :empty-title="$t('admin.classActivity.emptyTitle')"
      :empty-description="$t('admin.classActivity.emptyDesc')"
      empty-icon="activity"
      @retry="reload"
    >
      <div class="space-y-2">
        <ActivityCard
          v-for="it in items"
          :key="it.id"
          :activity="it"
          role="admin"
          :show-description="true"
          @click="openDetail"
        />
      </div>
    </AsyncView>

    <!-- DETAIL MODAL (read-only) -->
    <ActivityDetailModal
      v-if="detailTarget"
      :activity="detailTarget"
      :submissions="detailSubmissions"
      role="admin"
      :busy="isDetailLoading"
      @close="detailTarget = null"
    />

    <!-- CLASS PICKER -->
    <Modal v-if="showClassPicker" :title="$t('admin.sekolah.class_activity.pick_class')" @close="showClassPicker = false">
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="!classFilter ? 'bg-role-admin/5 font-bold text-role-admin' : ''"
            @click="pickClass('')"
          >
            {{ $t('admin.sekolah.class_activity.all_classes') }}
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="c.id === classFilter ? 'bg-role-admin/5 font-bold text-role-admin' : ''"
            @click="pickClass(c.id)"
          >
            {{ c.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- SUBJECT PICKER -->
    <Modal
      v-if="showSubjectPicker"
      :title="$t('admin.sekolah.class_activity.pick_subject')"
      @close="showSubjectPicker = false"
    >
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="!subjectFilter ? 'bg-role-admin/5 font-bold text-role-admin' : ''"
            @click="pickSubject('')"
          >
            {{ $t('admin.sekolah.class_activity.all_subjects') }}
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="s.id === subjectFilter ? 'bg-role-admin/5 font-bold text-role-admin' : ''"
            @click="pickSubject(s.id)"
          >
            {{ s.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- TEACHER PICKER -->
    <Modal
      v-if="showTeacherPicker"
      :title="$t('admin.sekolah.class_activity.pick_teacher')"
      @close="showTeacherPicker = false"
    >
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="!teacherFilter ? 'bg-role-admin/5 font-bold text-role-admin' : ''"
            @click="pickTeacher('')"
          >
            {{ $t('admin.sekolah.class_activity.all_teachers') }}
          </button>
        </li>
        <li v-for="t in teachers" :key="t.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="t.id === teacherFilter ? 'bg-role-admin/5 font-bold text-role-admin' : ''"
            @click="pickTeacher(t.id)"
          >
            <div class="flex flex-col">
              <span>{{ t.name }}</span>
              <span v-if="t.employee_number" class="text-[10px] text-slate-400">
                NIP {{ t.employee_number }}
              </span>
            </div>
          </button>
        </li>
      </ul>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
