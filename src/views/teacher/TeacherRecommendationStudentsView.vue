<!--
  TeacherRecommendationStudentsView.vue — student list (Frame B).

  Web port of `recommendation_student_screen.dart`. Route entry:
    /teacher/recommendations/kelas/:classId?scope=wali

  Layout:
    1. Back chevron row → kembali ke class hub
    2. BrandPageHeader (guru) — kicker `Kelas <name> · Rekomendasi`,
       title `Daftar Siswa`, meta line
    3. KpiStripCards — SISWA / REKOMENDASI / PENDING / SELESAI
    4. PageFilterToolbar — search input + status chip strip
    5. List of student rows:
         [avatar] Name        [status pills] [REC count] [chevron]
                  NIS · No N
       — `n REC` pill red-tinted when ≥3 pending
       — Avatar red-tinted when student has zero recs (attention flag)

  Tap row → result view (Phase 4 — falls back to placeholder toast
  for now).

  Endpoints:
    GET /api/students?class_ids=…       — student roster
    GET /recommendations + paginate     — driven by
                                         RecommendationService.getStudentStatusCounts
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { RecommendationService } from '@/services/recommendations.service';
import { StudentService } from '@/services/students.service';
import { ClassroomService } from '@/services/classrooms.service';
import type { StudentStatusCounts } from '@/types/recommendations';
import type { Classroom, Student } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();

const classId = computed(() => String(route.params.classId ?? ''));
const isHomeroomMode = computed(() => route.query.scope === 'wali');

// ── Filter state ──
type StatusFilter = 'all' | 'has_recs' | 'has_pending' | 'all_completed';
const statusFilter = ref<StatusFilter>('all');
const searchQuery = ref<string>('');

// ── Data state ──
const cls = ref<Classroom | null>(null);
const students = ref<Student[]>([]);
const counts = ref<StudentStatusCounts>({});
const isLoadingStudents = ref(true);
const isLoadingCounts = ref(false);
const loadError = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const teacherId = computed(() => auth.teacherId ?? auth.user?.id ?? '');

// ── Loaders ──
async function loadClass() {
  if (!classId.value) return;
  try {
    // Lightweight: classroom list filtered to single id — backend
    // doesn't expose `/classrooms/{id}` with student_count separately,
    // so we go through the list endpoint and pick.
    const res = await ClassroomService.list({ per_page: 200 });
    cls.value = res.items.find((c) => c.id === classId.value) ?? null;
  } catch {
    cls.value = null;
  }
}

async function loadStudents() {
  if (!classId.value) {
    isLoadingStudents.value = false;
    return;
  }
  isLoadingStudents.value = true;
  loadError.value = null;
  try {
    // Flutter parity — use `/student/class/{id}` (StudentService.byClass).
    // The generic `/student?class_ids=` endpoint sometimes returns rows
    // keyed on a different `id` field (e.g. the linked user_id rather
    // than the canonical `students.id` primary key), which breaks the
    // counts lookup in `countsFor(s.id)` — the recommendation rows are
    // keyed on `students.id` server-side, so the lookup would silently
    // miss and the "Ada Pending" filter would show 0 students even when
    // pending recs existed.
    students.value = await StudentService.byClass(classId.value);
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoadingStudents.value = false;
  }
}

async function loadCounts() {
  if (!classId.value) return;
  isLoadingCounts.value = true;
  try {
    const next = await RecommendationService.getStudentStatusCounts({
      class_id: classId.value,
      // Mengajar mode → teacher_id. Wali mode → homeroom_class_id
      // (cross-teacher scope across the homeroom).
      teacher_id: isHomeroomMode.value ? undefined : teacherId.value || undefined,
      homeroom_class_id: isHomeroomMode.value ? classId.value : undefined,
    });
    counts.value = next;
  } catch {
    counts.value = {};
  } finally {
    isLoadingCounts.value = false;
  }
}

onMounted(async () => {
  await Promise.all([loadClass(), loadStudents(), loadCounts()]);
});

useAcademicYearWatcher(() => {
  // Re-fetch counts (and roster — academic year flip can swap
  // enrolments) when the active TP changes.
  loadStudents();
  loadCounts();
});

// React to scope flip (back+forward with ?scope=wali toggled).
watch(
  () => route.fullPath,
  () => {
    if (!classId.value) return;
    loadStudents();
    loadCounts();
  },
);

// ── Derived ──
function countsFor(studentId: string) {
  return counts.value[studentId] ?? { total: 0, pending: 0, completed: 0 };
}

const visibleStudents = computed(() => {
  let list = students.value;
  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        (s.student_number ?? '').toLowerCase().includes(q),
    );
  }
  if (statusFilter.value === 'has_recs') {
    list = list.filter((s) => countsFor(s.id).total > 0);
  } else if (statusFilter.value === 'has_pending') {
    list = list.filter((s) => countsFor(s.id).pending > 0);
  } else if (statusFilter.value === 'all_completed') {
    list = list.filter((s) => {
      const c = countsFor(s.id);
      return c.total > 0 && c.pending === 0;
    });
  }
  // Sort: most-pending first, then most-total, then name
  return [...list].sort((a, b) => {
    const ca = countsFor(a.id);
    const cb = countsFor(b.id);
    if (cb.pending !== ca.pending) return cb.pending - ca.pending;
    if (cb.total !== ca.total) return cb.total - ca.total;
    return a.name.localeCompare(b.name, 'id');
  });
});

// ── KPI ──
const kpiCards = computed<KpiCard[]>(() => {
  const total = Object.values(counts.value).reduce(
    (acc, c) => acc + c.total,
    0,
  );
  const pending = Object.values(counts.value).reduce(
    (acc, c) => acc + c.pending,
    0,
  );
  const completed = Object.values(counts.value).reduce(
    (acc, c) => acc + c.completed,
    0,
  );
  return [
    {
      icon: 'users',
      label: 'Siswa',
      value: students.value.length,
      tone: 'brand',
    },
    {
      icon: 'sparkles',
      label: 'Rekomendasi',
      value: total,
      tone: 'violet',
    },
    {
      icon: 'bell',
      label: 'Pending',
      value: pending,
      tone: pending > 0 ? 'amber' : 'slate',
      accented: pending > 0,
    },
    {
      icon: 'check-circle',
      label: 'Selesai',
      value: completed,
      tone: 'green',
    },
  ];
});

// ── Status chip strip ──
const statusOptions: { key: StatusFilter; label: string }[] = [
  { key: 'all', label: 'Semua' },
  { key: 'has_recs', label: 'Punya Rekomendasi' },
  { key: 'has_pending', label: 'Ada Pending' },
  { key: 'all_completed', label: 'Semua Selesai' },
];

// ── List state ──
const listState = computed<AsyncState<Student[]>>(() => {
  if (isLoadingStudents.value && students.value.length === 0)
    return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleStudents.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleStudents.value };
});

// ── Header copy ──
const headerKicker = computed(() => {
  if (!cls.value) return 'Akademik · Rekomendasi AI';
  return `Kelas ${cls.value.name} · ${isHomeroomMode.value ? 'Wali Kelas' : 'Mengajar'}`;
});

const headerMeta = computed(() => {
  const studentCount = students.value.length;
  return `${studentCount} siswa · ${Object.keys(counts.value).length} dengan rekomendasi`;
});

// ── Actions ──
function goBack() {
  router.push({ name: 'teacher.recommendations' });
}

function openStudent(s: Student) {
  // Phase 4 will register the `teacher.recommendations.result` route.
  // Until then, surface a placeholder so taps don't 404.
  const target = router.resolve({
    name: 'teacher.recommendations.result',
    params: { classId: classId.value, studentId: s.id },
    query: isHomeroomMode.value ? { scope: 'wali' } : undefined,
  });
  if (target.matched.length === 0) {
    toast.value = {
      message: `Hasil rekomendasi ${s.name} — tersedia di pembaruan berikutnya.`,
      tone: 'success',
    };
    return;
  }
  router.push(target);
}

// Tag chip helper — produces a tiny pill describing the dominant
// rec status for a student. Shown inline next to the count badge.
function studentStatusPills(
  studentId: string,
): { label: string; cls: string }[] {
  const c = countsFor(studentId);
  if (c.total === 0) {
    return [
      { label: 'Belum ada rec', cls: 'bg-slate-100 text-slate-500' },
    ];
  }
  const out: { label: string; cls: string }[] = [];
  if (c.pending > 0) {
    out.push({
      label: `${c.pending} Pending`,
      cls: 'bg-amber-100 text-amber-700',
    });
  }
  if (c.completed > 0) {
    out.push({
      label: `${c.completed} Selesai`,
      cls: 'bg-emerald-100 text-emerald-700',
    });
  }
  return out;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- BACK CHEVRON -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        Semua Kelas
      </button>
    </div>

    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      :kicker="headerKicker"
      title="Daftar Siswa"
      :meta="headerMeta"
      :live-dot="false"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      search-placeholder="Cari nama atau NIS…"
    >
      <template #chips>
        <span class="text-[11px] font-bold text-slate-500 px-1">
          {{ visibleStudents.length }} siswa
        </span>
      </template>
    </PageFilterToolbar>

    <!-- STATUS CHIPS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="opt in statusOptions"
        :key="opt.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
        :class="
          statusFilter === opt.key
            ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
        "
        @click="statusFilter = opt.key"
      >
        {{ opt.label }}
      </button>
    </div>

    <!-- STUDENT LIST -->
    <AsyncView
      :state="listState"
      :empty-title="
        searchQuery
          ? 'Tidak ada siswa cocok'
          : statusFilter === 'all'
            ? 'Belum ada siswa di kelas ini'
            : 'Tidak ada siswa di filter ini'
      "
      empty-description="Coba longgarkan filter atau bersihkan kotak cari."
      empty-icon="users"
      @retry="loadStudents"
    >
      <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <button
          v-for="(s, idx) in visibleStudents"
          :key="s.id"
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 transition hover:bg-slate-50"
          :class="idx > 0 ? 'border-t border-slate-100' : ''"
          @click="openStudent(s)"
        >
          <!-- Avatar — red tint when zero recs to flag attention -->
          <InitialsAvatar
            :name="s.name || '?'"
            :size="40"
            :border-radius="12"
            :color="countsFor(s.id).total === 0 ? '#DC2626' : '#1B6FB8'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ s.name }}
            </p>
            <p class="text-[11px] text-slate-500 truncate">
              <template v-if="s.student_number">
                {{ s.student_number }}
              </template>
              <template v-else>
                Tanpa NIS
              </template>
              · No {{ idx + 1 }}
            </p>
            <!-- Status pills row -->
            <div class="flex items-center gap-1 flex-wrap mt-1.5">
              <span
                v-for="pill in studentStatusPills(s.id)"
                :key="pill.label"
                class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full uppercase tracking-wider"
                :class="pill.cls"
              >
                {{ pill.label }}
              </span>
            </div>
          </div>
          <!-- N REC count pill -->
          <div class="flex flex-col items-end gap-1 flex-shrink-0">
            <span
              v-if="countsFor(s.id).total > 0"
              class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-black"
              :class="
                countsFor(s.id).pending >= 3
                  ? 'bg-red-100 text-red-700'
                  : 'bg-violet-100 text-violet-700'
              "
            >
              {{ countsFor(s.id).total }}
              <span class="text-[9px] uppercase tracking-wider opacity-80">
                REC
              </span>
            </span>
            <NavIcon
              name="chevron-right"
              :size="13"
              class="text-slate-400"
            />
          </div>
        </button>
      </div>
      <p
        v-if="isLoadingCounts"
        class="text-center text-[11px] text-slate-400 mt-3 italic"
      >
        Memuat jumlah rekomendasi…
      </p>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
