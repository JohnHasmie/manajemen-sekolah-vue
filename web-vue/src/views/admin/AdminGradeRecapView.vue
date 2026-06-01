<!--
  AdminGradeRecapView.vue — Admin Rekap Nilai (school-wide).

  Mirrors Flutter `admin_grade_recap_overview_screen.dart` Frame C.
  One per-slice card per (class × subject) row, summarising how
  much of the recap the responsible teacher has filled.

    1. BrandPageHeader (admin) + embedded search bar
    2. KPI strip (3 cells) — SLICE / PROGRESS / FINAL ✓
    3. Filter chip row: "Belum lengkap" toggle + Sort selector
       (+ web-bonus Export CSV + Reload buttons)
    4. "PER SLICE · N SLICE" section header with hairline
    5. Per-slice cards — class pill, subject + chevron, teacher subline,
       3-stat row (PROGRESS / RATA-RATA / LULUS), slim progress bar,
       status chips (N/N bab, UTS ✓|belum, UAS ✓|belum)
    Tap a card → drills into the teacher matrix view scoped to that
    (class × subject); same governance gate as the responsible teacher.

  Endpoint: GET /grades/admin-recap-overview?academic_year_id=…
  Re-fetches on AY change.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { GradeRecapService } from '@/services/grade-recap.service';
import type {
  AdminRecapOverviewRow,
  AdminRecapOverviewSummary,
} from '@/types/grade-recap';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const router = useRouter();

// ── State ──
const rows = ref<AdminRecapOverviewRow[]>([]);
const summary = ref<AdminRecapOverviewSummary | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

const searchQuery = ref('');
const onlyIncomplete = ref(false);
type SortKey = 'progress' | 'class' | 'subject' | 'teacher' | 'avg';
const sortKey = ref<SortKey>('progress');
const sortDir = ref<'asc' | 'desc'>('asc');

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const resp = await GradeRecapService.getAdminOverview({});
    rows.value = resp.rows;
    summary.value = resp.summary;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

// ── Derived ──
const filteredRows = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  const list = rows.value.filter((r) => {
    if (onlyIncomplete.value && r.is_complete) return false;
    if (q) {
      const blob =
        `${r.class_name} ${r.subject_name} ${r.teacher_name ?? ''}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
  // Multi-key sort. Tertiary tiebreak on class+subject keeps order
  // deterministic when primary keys tie.
  const dir = sortDir.value === 'asc' ? 1 : -1;
  const cmp = (a: AdminRecapOverviewRow, b: AdminRecapOverviewRow) => {
    switch (sortKey.value) {
      case 'class':
        return dir * a.class_name.localeCompare(b.class_name);
      case 'subject':
        return dir * a.subject_name.localeCompare(b.subject_name);
      case 'teacher':
        return (
          dir *
          (a.teacher_name ?? 'zzz').localeCompare(b.teacher_name ?? 'zzz')
        );
      case 'progress':
        return dir * (a.progress_pct - b.progress_pct);
      case 'avg': {
        const av = a.avg_final_score ?? -1;
        const bv = b.avg_final_score ?? -1;
        return dir * (av - bv);
      }
    }
  };
  return [...list].sort(
    (a, b) =>
      cmp(a, b) ||
      a.class_name.localeCompare(b.class_name) ||
      a.subject_name.localeCompare(b.subject_name),
  );
});

const listState = computed<AsyncState<AdminRecapOverviewRow[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (filteredRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredRows.value };
});

// ── KPI (3 cells, mobile parity) ──
const kpiCells = computed(() => {
  const totalSlice = summary.value?.total_slice ?? rows.value.length;
  const completed =
    summary.value?.completed_slice ??
    rows.value.filter((r) => r.is_complete).length;
  const avgProgress = summary.value?.avg_progress ?? 0;
  return { totalSlice, completed, avgProgress };
});

function setSort(key: SortKey) {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortKey.value = key;
    // Sensible defaults: incomplete-first for progress, alphabetic
    // for class/subject/teacher, high-first for avg.
    sortDir.value =
      key === 'progress' ? 'asc' : key === 'avg' ? 'desc' : 'asc';
  }
}

function openRow(r: AdminRecapOverviewRow) {
  // Admin-side drill — mounts TeacherGradeRecapDetailView via the
  // admin-gated route so the role guard doesn't bounce us home.
  //
  // IMPORTANT: the matrix endpoint (`/grade-recaps`) validates
  // `subject_id` as a UUID, so we must hand it the per-school
  // `subject_school_id` and not the master subject id we get back
  // from the recap overview (bigint, e.g. "3"). When the backend
  // can't resolve a school subject (`subject_school_id` is null)
  // we fall back to the master id — the matrix screen will surface
  // an error rather than 400-ing silently.
  router.push({
    name: 'admin.grade-recap.detail',
    params: {
      classId: r.class_id,
      subjectId: r.subject_school_id ?? r.subject_id,
    },
    query: {
      className: r.class_name,
      subjectName: r.subject_name,
    },
  });
}

// ── Per-card helpers (mobile-parity colour rules) ──

function bucketColorCls(pct: number): {
  bg: string;
  text: string;
  bar: string;
  pillBg: string;
  pillText: string;
} {
  if (pct >= 80)
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-700',
      bar: 'bg-emerald-600',
      pillBg: 'bg-emerald-50',
      pillText: 'text-emerald-700',
    };
  if (pct >= 40)
    return {
      bg: 'bg-blue-50',
      text: 'text-role-admin',
      bar: 'bg-role-admin',
      pillBg: 'bg-blue-50',
      pillText: 'text-role-admin',
    };
  if (pct >= 1)
    return {
      bg: 'bg-amber-50',
      text: 'text-amber-700',
      bar: 'bg-amber-600',
      pillBg: 'bg-amber-50',
      pillText: 'text-amber-700',
    };
  return {
    bg: 'bg-slate-50',
    text: 'text-slate-500',
    bar: 'bg-slate-400',
    pillBg: 'bg-slate-100',
    pillText: 'text-slate-600',
  };
}

function passColorCls(pct: number, hasFinal: boolean): string {
  if (!hasFinal) return 'text-slate-400';
  if (pct >= 80) return 'text-emerald-700';
  if (pct >= 60) return 'text-amber-700';
  return 'text-red-700';
}

function avgColorCls(score: number | null): string {
  if (score === null) return 'text-slate-400';
  if (score >= 80) return 'text-emerald-700';
  if (score >= 60) return 'text-amber-700';
  return 'text-red-700';
}

// Bab/UTS/UAS status chip helpers.
function babDone(r: AdminRecapOverviewRow): {
  filled: number;
  expected: number;
  done: boolean;
} {
  const expected = r.students_total * r.bab_total;
  const filled = r.bab_filled;
  return {
    filled,
    expected,
    done: expected > 0 && filled >= expected,
  };
}
function utsDone(r: AdminRecapOverviewRow): boolean {
  return r.students_total > 0 && r.uts_done >= r.students_total;
}
function uasDone(r: AdminRecapOverviewRow): boolean {
  return r.students_total > 0 && r.uas_done >= r.students_total;
}

// ── Sort selector options ──
const SORT_OPTIONS: { key: SortKey; label: string }[] = [
  { key: 'progress', label: 'Progress' },
  { key: 'class', label: 'Kelas' },
  { key: 'subject', label: 'Mapel' },
  { key: 'teacher', label: 'Guru' },
  { key: 'avg', label: 'Rerata' },
];

// ── Export visible rows as CSV (web bonus) ──
function csvEscape(v: unknown): string {
  const s = v === null || v === undefined ? '' : String(v);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function exportCsv() {
  const header = [
    'Kelas',
    'Mapel',
    'Guru',
    'Siswa (terisi/total)',
    'Progress %',
    'Rerata Final',
    'Lulus %',
    'Bab',
    'Bab terisi',
    'UTS done',
    'UAS done',
    'Lengkap',
  ];
  const rowsCsv = filteredRows.value.map((r) =>
    [
      r.class_name,
      r.subject_name,
      r.teacher_name ?? '-',
      `${r.students_with_recap}/${r.students_total}`,
      Math.round(r.progress_pct * 10) / 10,
      r.avg_final_score ?? '',
      r.avg_final_score !== null ? Math.round(r.pass_rate * 10) / 10 : '',
      r.bab_total,
      r.bab_filled,
      r.uts_done,
      r.uas_done,
      r.is_complete ? 'Ya' : 'Tidak',
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
  a.download = `rekap_nilai_overview_${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- 1. Header with embedded search (mobile parity — search lives
         inside the gradient hero via the default slot). -->
    <BrandPageHeader
      role="admin"
      kicker="AKADEMIK"
      title="Rekap Nilai"
      :meta="`${kpiCells.totalSlice} slice · ${kpiCells.completed} final ✓ · rerata ${Math.round(kpiCells.avgProgress)}%`"
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
            placeholder="Cari kelas, mapel, atau guru..."
            class="flex-1 text-[13px] text-slate-900 outline-none placeholder-slate-400 bg-transparent"
          />
        </div>
      </template>
    </BrandPageHeader>

    <!-- 2. KPI strip — 3 cells (SLICE / PROGRESS / FINAL ✓), mobile parity -->
    <section
      class="bg-white border border-slate-200 rounded-2xl px-1 py-3 shadow-sm grid grid-cols-3 divide-x divide-slate-100"
    >
      <div class="text-center px-2">
        <p class="text-[22px] font-black text-role-admin leading-none tracking-tight">
          {{ kpiCells.totalSlice }}
        </p>
        <p class="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-1.5">
          Slice
        </p>
      </div>
      <div class="text-center px-2">
        <p class="text-[22px] font-black text-slate-800 leading-none tracking-tight">
          {{ Math.round(kpiCells.avgProgress) }}%
        </p>
        <p class="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-1.5">
          Progress
        </p>
      </div>
      <div class="text-center px-2">
        <p class="text-[22px] font-black text-emerald-600 leading-none tracking-tight">
          {{ kpiCells.completed }}
        </p>
        <p class="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-1.5">
          Final ✓
        </p>
      </div>
    </section>

    <!-- 3. Filter chip row -->
    <div class="flex items-center gap-2 flex-wrap">
      <!-- "Belum lengkap" toggle (mobile parity) -->
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
        :class="
          onlyIncomplete
            ? 'bg-role-admin/10 text-role-admin border-role-admin/30'
            : 'bg-white text-slate-700 border-slate-200 hover:border-slate-300'
        "
        @click="onlyIncomplete = !onlyIncomplete"
      >
        <NavIcon
          v-if="onlyIncomplete"
          name="check-circle"
          :size="12"
        />
        Belum lengkap
      </button>

      <!-- Sort selector (replaces table column chevrons since cards
           have no column headers). -->
      <div class="inline-flex items-center gap-1 bg-white border border-slate-200 rounded-full p-0.5">
        <span class="text-[10px] font-black text-slate-400 uppercase tracking-widest px-2">
          Urut:
        </span>
        <button
          v-for="opt in SORT_OPTIONS"
          :key="opt.key"
          type="button"
          class="px-2.5 py-1 rounded-full text-[11px] font-bold transition inline-flex items-center gap-0.5"
          :class="
            sortKey === opt.key
              ? 'bg-role-admin text-white'
              : 'text-slate-600 hover:bg-slate-100'
          "
          @click="setSort(opt.key)"
        >
          {{ opt.label }}
          <NavIcon
            v-if="sortKey === opt.key"
            :name="sortDir === 'asc' ? 'chevron-up' : 'chevron-down'"
            :size="10"
          />
        </button>
      </div>

      <!-- Spacer pushes web-only buttons to the right. -->
      <span class="flex-1" />

      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-slate-200 text-slate-700 text-[11px] font-bold hover:bg-slate-50"
        :disabled="filteredRows.length === 0"
        @click="exportCsv"
      >
        <NavIcon name="download" :size="12" />
        Ekspor CSV
      </button>
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-slate-200 text-slate-700 text-[11px] font-bold hover:bg-slate-50"
        @click="load"
      >
        <NavIcon name="refresh-cw" :size="12" />
        Muat ulang
      </button>
    </div>

    <!-- 4. Section header — kicker style -->
    <header class="flex items-center gap-2 px-1 pt-1">
      <NavIcon name="layers" :size="12" class="text-slate-500" />
      <span class="text-[9.5px] font-black text-slate-500 uppercase tracking-widest">
        Per Slice
      </span>
      <span class="text-[9.5px] font-black text-slate-300 uppercase tracking-widest">
        · {{ filteredRows.length }} slice
      </span>
      <span class="flex-1 h-px bg-slate-100" />
    </header>

    <!-- 5. Per-slice cards -->
    <AsyncView
      :state="listState"
      empty-title="Belum ada data rekap"
      empty-description="Rekap muncul saat guru mulai mengisi tabel bab/UTS/UAS untuk kelas + mapel."
      empty-icon="layers"
      @retry="load"
    >
      <template #default>
        <!-- The AsyncView default slot has no inherent gap between
             siblings, so wrap the card list in space-y-* to keep each
             slice separated. -->
        <div class="space-y-md">
        <article
          v-for="r in filteredRows"
          :key="`${r.class_id}__${r.subject_id}`"
          class="bg-white rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow cursor-pointer p-3.5 space-y-2.5"
          @click="openRow(r)"
        >
          <!-- Title row: class pill + subject name + chevron -->
          <div class="flex items-center gap-2.5">
            <span
              class="px-2.5 py-1 rounded-full text-[11px] font-black tracking-wider flex-shrink-0"
              :class="[
                bucketColorCls(r.progress_pct).pillBg,
                bucketColorCls(r.progress_pct).pillText,
              ]"
            >
              {{ r.class_name }}
            </span>
            <p class="text-[13px] font-extrabold text-slate-900 truncate flex-1">
              {{ r.subject_name }}
            </p>
            <NavIcon name="chevron-right" :size="16" class="text-slate-400 flex-shrink-0" />
          </div>

          <!-- Teacher subline (indented under class pill) -->
          <div
            v-if="r.teacher_name"
            class="flex items-center gap-1.5 pl-1 -mt-1"
          >
            <NavIcon name="user" :size="11" class="text-slate-500" />
            <span class="text-[11px] font-bold text-slate-600 truncate">
              {{ r.teacher_name }}
            </span>
          </div>

          <!-- 3-stat row: PROGRESS / RATA-RATA / LULUS (mobile parity) -->
          <div class="flex items-stretch border-y border-slate-100 py-2.5">
            <div class="flex-1 pr-2">
              <p class="text-[9px] font-black text-slate-500 uppercase tracking-widest">
                Progress
              </p>
              <p
                class="text-[16px] font-black leading-none mt-1 tracking-tight"
                :class="bucketColorCls(r.progress_pct).text"
              >
                {{ Math.round(r.progress_pct) }}%
              </p>
            </div>
            <div class="w-px bg-slate-100 mx-2" />
            <div class="flex-1 px-2">
              <p class="text-[9px] font-black text-slate-500 uppercase tracking-widest">
                Rata-rata
              </p>
              <p
                class="text-[16px] font-black leading-none mt-1 tracking-tight"
                :class="avgColorCls(r.avg_final_score)"
              >
                {{
                  r.avg_final_score !== null
                    ? (Math.round(r.avg_final_score * 10) / 10).toFixed(1)
                    : '—'
                }}
              </p>
            </div>
            <div class="w-px bg-slate-100 mx-2" />
            <div class="flex-1 pl-2">
              <p class="text-[9px] font-black text-slate-500 uppercase tracking-widest">
                Lulus
              </p>
              <p
                class="text-[16px] font-black leading-none mt-1 tracking-tight"
                :class="passColorCls(r.pass_rate, r.avg_final_score !== null)"
              >
                {{
                  r.avg_final_score !== null
                    ? `${Math.round(r.pass_rate)}%`
                    : '—'
                }}
              </p>
            </div>
          </div>

          <!-- Slim progress bar -->
          <div class="h-1.5 rounded-full overflow-hidden bg-slate-100">
            <div
              class="h-full transition-all"
              :class="bucketColorCls(r.progress_pct).bar"
              :style="{ width: `${Math.min(100, r.progress_pct)}%` }"
            />
          </div>

          <!-- Status chips: bab / UTS / UAS -->
          <div class="flex flex-wrap gap-1.5 pt-0.5">
            <span
              v-for="chip in [
                {
                  done: babDone(r).done,
                  label:
                    r.students_total > 0 && r.bab_total > 0
                      ? `${Math.floor(r.bab_filled / r.students_total)}/${r.bab_total} bab`
                      : `0/${r.bab_total} bab`,
                  title: `${babDone(r).filled} / ${babDone(r).expected} sel terisi`,
                },
                {
                  done: utsDone(r),
                  label: utsDone(r) ? 'UTS ✓' : 'UTS belum',
                  title: `UTS ${r.uts_done}/${r.students_total} siswa`,
                },
                {
                  done: uasDone(r),
                  label: uasDone(r) ? 'UAS ✓' : 'UAS belum',
                  title: `UAS ${r.uas_done}/${r.students_total} siswa`,
                },
              ]"
              :key="chip.label"
              :title="chip.title"
              class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full border text-[10.5px] font-bold"
              :class="
                chip.done
                  ? 'bg-emerald-50 border-emerald-200 text-emerald-700'
                  : 'bg-amber-50 border-amber-200 text-amber-700'
              "
            >
              <span
                class="w-1.5 h-1.5 rounded-full"
                :class="chip.done ? 'bg-emerald-600' : 'bg-amber-600'"
              />
              {{ chip.label }}
            </span>
          </div>

          <!-- Roster fill — N siswa punya rekap dari M total -->
          <p class="text-[10px] text-slate-500 pt-0.5">
            {{ r.students_with_recap }} / {{ r.students_total }} siswa punya rekap
          </p>
        </article>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
