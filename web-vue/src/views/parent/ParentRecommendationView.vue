<!--
  ParentRecommendationView.vue — Rekomendasi belajar untuk wali murid.

  Web port of Flutter's `parent_recommendation_screen.dart`. Three
  modes share one screen, swapped by the active child chip:

    • Frame A — Multi-child hub: shown when the parent has >1 child
      AND "Semua" is selected. Renders one ChildSummaryCard per anak.
    • Frame B — Per-child list: shown for single-child parents OR
      after the parent taps into one child. Hero card + status chip
      strip + flat list of ParentRecommendationCards.
    • Frame G — Empty state (AsyncView handles the chrome).

  Header carries the filter button (badge = active filter count).
  Tapping a card opens ParentRecommendationDetailModal (Frame C),
  which spawns the Reply / Tandai Selesai sheets (Frames D / E).
  Both action sheets auto-refresh the list on completion.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useChildPicker } from '@/composables/useChildPicker';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { RecommendationService } from '@/services/recommendations.service';
import type {
  ParentInboxRow,
  ParentRecFilter,
  ParentSummaryChild,
} from '@/types/recommendations';
import {
  DEFAULT_PARENT_REC_FILTER,
  parentRecFilterActiveCount,
} from '@/types/recommendations';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import ParentRecommendationCard from '@/components/feature/ParentRecommendationCard.vue';
import ParentRecommendationDetailModal from '@/components/feature/ParentRecommendationDetailModal.vue';
import ParentRecFilterModal from '@/components/feature/ParentRecFilterModal.vue';

const auth = useAuthStore();
const { children, activeChildId } = useChildPicker();

const ALL_KEY = '__all__';

// ── Data ──
const inbox = ref<ParentInboxRow[]>([]);
const summaryChildren = ref<ParentSummaryChild[]>([]);
const isLoading = ref(true);
const isFirstLoad = ref(true);
const error = ref<string | null>(null);

// ── Selection ──
// `'__all__'` means multi-child hub (Frame A); otherwise one student id.
// Single-child parents skip the hub entirely.
const selectedChildKey = ref<string>(ALL_KEY);

// ── Filter ──
const filter = ref<ParentRecFilter>({ ...DEFAULT_PARENT_REC_FILTER });
const filterOpen = ref(false);
const detailRow = ref<ParentInboxRow | null>(null);

const activeFilterCount = computed(() => parentRecFilterActiveCount(filter.value));

async function reload() {
  if (!auth.user?.id) {
    isLoading.value = false;
    isFirstLoad.value = false;
    return;
  }
  isLoading.value = true;
  error.value = null;

  // Settle both endpoints independently — if the inbox 500s but the
  // summary succeeds, we still render the multi-child hub from the
  // summary (and vice versa). Only surface an error plaque when
  // *both* fail. Matches Flutter `_ParentRecommendationScreenState._load`.
  const [rowsResult, summaryResult] = await Promise.allSettled([
    RecommendationService.getParentInbox({ parent_user_id: auth.user.id }),
    RecommendationService.getParentSummary({ parent_user_id: auth.user.id }),
  ]);

  isLoading.value = false;
  isFirstLoad.value = false;

  if (rowsResult.status === 'rejected' && summaryResult.status === 'rejected') {
    error.value = friendlyError(rowsResult.reason);
    return;
  }

  const rows = rowsResult.status === 'fulfilled' ? rowsResult.value : [];
  const summary =
    summaryResult.status === 'fulfilled'
      ? summaryResult.value
      : { children: [], totals: {} };

  inbox.value = rows;
  summaryChildren.value =
    summary.children.length > 0
      ? summary.children
      : deriveChildrenFromInbox(rows);

  if (summaryChildren.value.length === 1) {
    selectedChildKey.value = summaryChildren.value[0].student_id;
  } else if (
    selectedChildKey.value !== ALL_KEY &&
    !summaryChildren.value.find((c) => c.student_id === selectedChildKey.value)
  ) {
    selectedChildKey.value = ALL_KEY;
  }
}

function friendlyError(e: unknown): string {
  const raw = String(e ?? '');
  if (raw.includes('Network') || raw.includes('ECONNREFUSED')) {
    return 'Tidak dapat terhubung ke server AI rekomendasi.';
  }
  if (raw.includes('500')) {
    return 'Server rekomendasi sedang bermasalah. Coba lagi sebentar.';
  }
  if (raw.includes('401') || raw.includes('403')) {
    return 'Sesi Anda telah berakhir. Silakan masuk ulang.';
  }
  if (raw.includes('404')) {
    return 'Layanan rekomendasi tidak ditemukan pada akun ini.';
  }
  return 'Gagal memuat rekomendasi. Coba lagi.';
}

onMounted(reload);
// Refetch the multi-child hub when the global academic year changes.
useAcademicYearWatcher(() => reload());

// Re-derive selection when the global child picker changes (so the
// header chip in ParentPageHeader stays in sync with the in-page hub).
watch(activeChildId, (id) => {
  if (id && summaryChildren.value.find((c) => c.student_id === id)) {
    selectedChildKey.value = id;
  }
});

function deriveChildrenFromInbox(rows: ParentInboxRow[]): ParentSummaryChild[] {
  const byId = new Map<string, ParentSummaryChild>();
  for (const row of rows) {
    const rec = row.recommendation as Record<string, unknown>;
    const sid = String(rec.student_id ?? '');
    if (!sid) continue;
    const student = rec.student as Record<string, unknown> | undefined;
    const klass = (rec.class_ ?? rec.class) as Record<string, unknown> | undefined;
    let entry = byId.get(sid);
    if (!entry) {
      entry = {
        student_id: sid,
        student_name: String(student?.name ?? 'Siswa'),
        class_name: String(klass?.name ?? '-'),
        total_count: 0,
        unread_count: 0,
        completed_count: 0,
        high_priority_count: 0,
      };
      byId.set(sid, entry);
    }
    entry.total_count++;
    if (!row.read_at) entry.unread_count++;
    const completed =
      row.parent_completed_at != null ||
      String(rec.status ?? '').toLowerCase() === 'completed';
    if (completed) entry.completed_count++;
    if (String(rec.priority ?? '').toLowerCase() === 'high') {
      entry.high_priority_count++;
    }
  }
  return Array.from(byId.values());
}

// ── Frame routing ──
const isMultiChildHub = computed(
  () => summaryChildren.value.length > 1 && selectedChildKey.value === ALL_KEY,
);

// ── Filtering for Frame B ──
function passesFilter(row: ParentInboxRow): boolean {
  const rec = row.recommendation as Record<string, unknown>;
  // Child filter (when Frame B is active).
  if (
    selectedChildKey.value !== ALL_KEY &&
    String(rec.student_id ?? '') !== selectedChildKey.value
  ) {
    return false;
  }
  // Status.
  const completed =
    row.parent_completed_at != null ||
    String(rec.status ?? '').toLowerCase() === 'completed';
  switch (filter.value.status) {
    case 'unread':
      if (row.read_at) return false;
      break;
    case 'active':
      if (completed) return false;
      break;
    case 'completed':
      if (!completed) return false;
      break;
    case 'all':
    default:
      break;
  }
  // Priority.
  if (filter.value.priority !== 'all') {
    if (
      String(rec.priority ?? '').toLowerCase() !==
      filter.value.priority
    ) {
      return false;
    }
  }
  // Subjects (multi).
  if (filter.value.subjects.length > 0) {
    const name = readSubjectName(rec);
    if (!name || !filter.value.subjects.includes(name)) return false;
  }
  // Period.
  if (filter.value.period !== 'all') {
    const cutoff =
      filter.value.period === 'last7'
        ? Date.now() - 7 * 86_400_000
        : Date.now() - 30 * 86_400_000;
    const sent = row.sent_at ? new Date(row.sent_at).getTime() : NaN;
    if (!Number.isFinite(sent) || sent < cutoff) return false;
  }
  return true;
}

function readSubjectName(rec: Record<string, unknown>): string | null {
  const sub =
    (rec.subject_school as Record<string, unknown> | undefined) ??
    (rec.subjectSchool as Record<string, unknown> | undefined) ??
    (rec.subject as Record<string, unknown> | undefined);
  if (sub && typeof sub.name === 'string') return sub.name;
  if (typeof rec.subject_name === 'string') return rec.subject_name;
  return null;
}

const filteredRows = computed<ParentInboxRow[]>(() =>
  inbox.value.filter(passesFilter),
);

const availableSubjects = computed<string[]>(() => {
  const seen = new Map<string, string>();
  for (const row of inbox.value) {
    const name = readSubjectName(row.recommendation as Record<string, unknown>);
    if (name && name.trim()) seen.set(name.toLowerCase(), name);
  }
  return Array.from(seen.values()).sort();
});

// KPI counts scoped to the visible slice.
const kpi = computed(() => {
  let unread = 0;
  let active = 0;
  let completed = 0;
  for (const row of filteredRows.value) {
    const rec = row.recommendation as Record<string, unknown>;
    const isDone =
      row.parent_completed_at != null ||
      String(rec.status ?? '').toLowerCase() === 'completed';
    if (isDone) completed++;
    else active++;
    if (!row.read_at) unread++;
  }
  return { unread, active, completed };
});

// Status chip strip (Frame B).
type StatusKey = ParentRecFilter['status'];
interface StatusChipEntry {
  key: StatusKey;
  label: string;
  count: number;
}
const statusChipEntries = computed<StatusChipEntry[]>(() => {
  const rowsForChild = inbox.value.filter((row) => {
    const rec = row.recommendation as Record<string, unknown>;
    return (
      selectedChildKey.value === ALL_KEY ||
      String(rec.student_id ?? '') === selectedChildKey.value
    );
  });
  let unread = 0;
  let active = 0;
  let completed = 0;
  for (const row of rowsForChild) {
    const rec = row.recommendation as Record<string, unknown>;
    const isDone =
      row.parent_completed_at != null ||
      String(rec.status ?? '').toLowerCase() === 'completed';
    if (isDone) completed++;
    else active++;
    if (!row.read_at) unread++;
  }
  return [
    { key: 'all', label: 'Semua', count: rowsForChild.length },
    { key: 'unread', label: 'Belum Dibaca', count: unread },
    { key: 'active', label: 'Aktif', count: active },
    { key: 'completed', label: 'Selesai', count: completed },
  ];
});

const selectedChild = computed<ParentSummaryChild | null>(() => {
  if (selectedChildKey.value === ALL_KEY) return null;
  return (
    summaryChildren.value.find(
      (c) => c.student_id === selectedChildKey.value,
    ) ?? null
  );
});

// ── Async state ──
const state = computed<AsyncState<ParentInboxRow[]>>(() => {
  if (isLoading.value && isFirstLoad.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (isMultiChildHub.value) {
    if (summaryChildren.value.length === 0) return { status: 'empty' };
    return { status: 'content', data: [] };
  }
  if (filteredRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredRows.value };
});

const emptyTitle = computed(() =>
  isMultiChildHub.value
    ? 'Belum ada rekomendasi'
    : inbox.value.length > 0 && filteredRows.value.length === 0
      ? 'Tidak ada rekomendasi untuk filter ini'
      : 'Belum ada rekomendasi untuk anak ini',
);
const emptyDescription = computed(() =>
  isMultiChildHub.value
    ? 'Wali kelas akan mengirim rekomendasi belajar di sini.'
    : inbox.value.length > 0 && filteredRows.value.length === 0
      ? 'Coba reset filter di atas.'
      : 'Coba periksa lagi nanti.',
);

// ── Initials helper for hero ──
function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 0 || parts[0].length === 0) return '?';
  if (parts.length === 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

// ── Header meta ──
const headerMeta = computed(() => {
  if (isMultiChildHub.value) {
    return `Wali · ${summaryChildren.value.length} anak`;
  }
  if (selectedChild.value) {
    return `${selectedChild.value.class_name} · ${selectedChild.value.total_count} rekomendasi`;
  }
  return 'Saran tindakan dari wali kelas';
});

// ── Detail handlers ──
function openDetail(row: ParentInboxRow) {
  detailRow.value = row;
  // Optimistic local read flag — mirrors mobile's _autoMarkRead.
  if (!row.read_at && auth.user?.id) {
    row.read_at = new Date().toISOString();
    RecommendationService.markRecAsRead({
      recommendation_id: String(row.recommendation.id ?? ''),
      parent_user_id: auth.user.id,
    });
  }
}

function onDetailActed() {
  // Force a refetch so the list + KPI + chip counts reflect the
  // mutation (reply / mark-completed) on the next paint.
  reload();
}

function applyFilter(next: ParentRecFilter) {
  filter.value = next;
  filterOpen.value = false;
}

// ── Skeleton rows ──
const SKELETON_ROWS = Array.from({ length: 4 });
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- HEADER -->
    <ParentPageHeader
      kicker="Akademik · Anak"
      title="Rekomendasi"
      :interpolate-child="false"
      :meta="headerMeta"
    >
      <template #actions>
        <button
          type="button"
          class="relative inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-[11px] font-bold transition"
          @click="filterOpen = true"
        >
          <NavIcon name="filter" :size="12" />
          Filter
          <span
            v-if="activeFilterCount > 0"
            class="ml-1 px-1.5 py-0.5 rounded-full bg-white text-role-wali text-[9px] font-black"
          >
            {{ activeFilterCount }}
          </span>
        </button>
      </template>
    </ParentPageHeader>

    <!-- KPI strip (3 columns) — same numbers in both frames -->
    <section
      v-if="!(isLoading && isFirstLoad)"
      class="bg-white border border-slate-200 rounded-2xl px-2 py-3 grid grid-cols-3 divide-x divide-slate-100"
    >
      <div class="text-center px-2">
        <p class="text-xl font-black text-role-wali leading-none">{{ kpi.unread }}</p>
        <p class="text-[9.5px] font-bold uppercase tracking-widest text-slate-500 mt-1.5">
          Belum dibaca
        </p>
      </div>
      <div class="text-center px-2">
        <p class="text-xl font-black text-amber-600 leading-none">{{ kpi.active }}</p>
        <p class="text-[9.5px] font-bold uppercase tracking-widest text-slate-500 mt-1.5">
          Aktif
        </p>
      </div>
      <div class="text-center px-2">
        <p class="text-xl font-black text-emerald-600 leading-none">
          {{ kpi.completed }}
        </p>
        <p class="text-[9.5px] font-bold uppercase tracking-widest text-slate-500 mt-1.5">
          Selesai
        </p>
      </div>
    </section>

    <!-- "Semua / per-child" segmented for multi-child parents -->
    <section
      v-if="!(isLoading && isFirstLoad) && summaryChildren.length > 1"
      class="flex flex-wrap items-center gap-1.5"
    >
      <button
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
        :class="
          selectedChildKey === ALL_KEY
            ? 'bg-role-wali text-white border-role-wali shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40'
        "
        @click="selectedChildKey = ALL_KEY"
      >
        Semua
        <span
          class="ml-1 px-1.5 py-0.5 rounded-full text-[9px] font-black"
          :class="
            selectedChildKey === ALL_KEY
              ? 'bg-white/25 text-white'
              : 'bg-slate-100 text-slate-600'
          "
        >
          {{ summaryChildren.length }}
        </span>
      </button>
      <button
        v-for="c in summaryChildren"
        :key="c.student_id"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border whitespace-nowrap"
        :class="
          selectedChildKey === c.student_id
            ? 'bg-role-wali text-white border-role-wali shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40'
        "
        @click="selectedChildKey = c.student_id"
      >
        {{ c.student_name.split(' ')[0] }} · {{ c.class_name }}
        <span
          v-if="c.unread_count > 0"
          class="ml-1 px-1.5 py-0.5 rounded-full text-[9px] font-black"
          :class="
            selectedChildKey === c.student_id
              ? 'bg-white text-role-wali'
              : 'bg-role-wali/15 text-role-wali'
          "
        >
          {{ c.unread_count }}
        </span>
      </button>
    </section>

    <!-- Skeleton loader on first load -->
    <div v-if="isLoading && isFirstLoad" class="space-y-2.5">
      <div
        v-for="(_, i) in SKELETON_ROWS"
        :key="i"
        class="flex items-start gap-3 p-3.5 bg-white border border-slate-100 rounded-2xl"
      >
        <div class="w-9 h-9 rounded-full bg-slate-100 animate-pulse flex-shrink-0"></div>
        <div class="flex-1 space-y-2">
          <div class="h-3 w-1/3 bg-slate-100 rounded animate-pulse"></div>
          <div class="h-3 w-3/4 bg-slate-100 rounded animate-pulse"></div>
          <div class="h-2.5 w-2/3 bg-slate-100 rounded animate-pulse"></div>
        </div>
      </div>
    </div>

    <!-- Async content -->
    <AsyncView
      v-else
      :state="state"
      :empty-title="emptyTitle"
      :empty-description="emptyDescription"
      empty-icon="sparkles"
      @retry="reload"
    >
      <template #default>
        <!-- Frame A — multi-child hub -->
        <section v-if="isMultiChildHub" class="space-y-2.5">
          <p class="text-[10px] font-bold uppercase tracking-widest text-slate-500 px-1">
            Anak Saya · {{ summaryChildren.length }} anak
          </p>
          <button
            v-for="c in summaryChildren"
            :key="c.student_id"
            type="button"
            class="relative w-full text-left rounded-2xl border bg-white p-3.5 transition hover:border-role-wali/30"
            :class="
              c.unread_count > 0 ? 'border-role-wali/30 shadow-sm' : 'border-slate-200'
            "
            @click="selectedChildKey = c.student_id"
          >
            <span
              v-if="c.unread_count > 0"
              class="absolute top-0 bottom-0 left-0 w-[3px] bg-role-wali rounded-l-2xl"
            />
            <div class="flex items-center gap-3">
              <div
                class="w-11 h-11 rounded-full bg-role-wali/10 text-role-wali grid place-items-center text-[13px] font-black flex-shrink-0"
              >
                {{ initialsOf(c.student_name) }}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-[14px] font-black text-slate-900 truncate">
                  {{ c.student_name }}
                </p>
                <p class="text-[11px] font-bold text-slate-500 truncate mt-0.5">
                  {{ c.class_name }}
                </p>
              </div>
              <span
                v-if="c.unread_count > 0"
                class="px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider bg-role-wali text-white shadow shadow-role-wali/30"
              >
                {{ c.unread_count }} baru
              </span>
            </div>

            <div class="grid grid-cols-3 gap-2 mt-3">
              <div
                class="rounded-lg border border-slate-200 bg-slate-50 px-2 py-2 text-center"
              >
                <p class="text-[15px] font-black text-role-wali leading-none">
                  {{ c.total_count }}
                </p>
                <p class="text-[9px] font-bold uppercase tracking-widest text-slate-500 mt-1.5">
                  Total
                </p>
              </div>
              <div
                class="rounded-lg border border-slate-200 bg-slate-50 px-2 py-2 text-center"
              >
                <p class="text-[15px] font-black text-amber-600 leading-none">
                  {{ Math.max(c.total_count - c.completed_count, 0) }}
                </p>
                <p class="text-[9px] font-bold uppercase tracking-widest text-slate-500 mt-1.5">
                  Aktif
                </p>
              </div>
              <div
                class="rounded-lg border border-slate-200 bg-slate-50 px-2 py-2 text-center"
              >
                <p class="text-[15px] font-black text-emerald-600 leading-none">
                  {{ c.completed_count }}
                </p>
                <p class="text-[9px] font-bold uppercase tracking-widest text-slate-500 mt-1.5">
                  Selesai
                </p>
              </div>
            </div>

            <div class="flex items-center gap-2 mt-3">
              <div
                class="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden"
              >
                <div
                  class="h-full bg-role-wali transition-all"
                  :style="{
                    width: c.total_count === 0
                      ? '0%'
                      : `${Math.round((c.completed_count / c.total_count) * 100)}%`,
                  }"
                />
              </div>
              <span class="text-[10.5px] font-black text-role-wali">
                {{ c.total_count === 0
                  ? '0%'
                  : `${Math.round((c.completed_count / c.total_count) * 100)}%` }}
              </span>
            </div>

            <div class="mt-3 inline-flex items-center gap-1 text-[11px] font-bold text-role-wali">
              Lihat rekomendasi
              <NavIcon name="chevron-right" :size="13" />
            </div>
          </button>
        </section>

        <!-- Frame B — per-child list -->
        <section v-else class="space-y-3">
          <!-- Hero card -->
          <div
            v-if="selectedChild"
            class="bg-white border border-slate-200 rounded-2xl p-3.5 shadow-sm"
          >
            <div class="flex items-center gap-3">
              <div
                class="w-12 h-12 rounded-full bg-role-wali/10 text-role-wali grid place-items-center text-[13px] font-black flex-shrink-0"
              >
                {{ initialsOf(selectedChild.student_name) }}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-[15px] font-black text-slate-900 truncate">
                  {{ selectedChild.student_name }}
                </p>
                <p class="text-[11px] font-bold text-slate-500 truncate mt-0.5">
                  {{ selectedChild.class_name }} ·
                  <span class="text-role-wali">
                    {{ selectedChild.total_count }} rekomendasi
                  </span>
                </p>
              </div>
              <span
                v-if="selectedChild.unread_count > 0"
                class="px-2.5 py-1.5 rounded-xl bg-role-wali/10 text-role-wali text-center min-w-[58px]"
              >
                <span class="block text-[15px] font-black leading-none">
                  {{ selectedChild.unread_count }}
                </span>
                <span class="block text-[8.5px] font-bold uppercase tracking-widest mt-1">
                  Baru
                </span>
              </span>
            </div>
            <div
              v-if="
                selectedChild.unread_count > 0 ||
                selectedChild.high_priority_count > 0 ||
                selectedChild.completed_count > 0
              "
              class="flex flex-wrap gap-1.5 mt-3"
            >
              <span
                v-if="selectedChild.unread_count > 0"
                class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-role-wali/10 text-role-wali"
              >
                {{ selectedChild.unread_count }} belum dibaca
              </span>
              <span
                v-if="selectedChild.high_priority_count > 0"
                class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-amber-100 text-amber-700"
              >
                {{ selectedChild.high_priority_count }} prioritas tinggi
              </span>
              <span
                v-if="selectedChild.completed_count > 0"
                class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700"
              >
                {{ selectedChild.completed_count }} selesai
              </span>
            </div>
          </div>

          <!-- Status chip strip -->
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="entry in statusChipEntries"
              :key="entry.key"
              type="button"
              class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
              :class="
                filter.status === entry.key
                  ? 'bg-role-wali text-white border-role-wali shadow-sm'
                  : 'bg-white text-slate-700 border-slate-200 hover:border-role-wali/40'
              "
              @click="filter = { ...filter, status: entry.key }"
            >
              {{ entry.label }}
              <span
                class="ml-1 px-1.5 py-0.5 rounded-full text-[9px] font-black"
                :class="
                  filter.status === entry.key
                    ? 'bg-white/25 text-white'
                    : 'bg-slate-100 text-slate-600'
                "
              >
                {{ entry.count }}
              </span>
            </button>
          </div>

          <!-- Rec cards -->
          <div class="space-y-2.5">
            <ParentRecommendationCard
              v-for="row in filteredRows"
              :key="row.recipient_id"
              :row="row"
              @click="openDetail"
            />
          </div>
        </section>
      </template>
    </AsyncView>

    <!-- Detail modal -->
    <ParentRecommendationDetailModal
      v-if="detailRow"
      :row="detailRow"
      @close="detailRow = null"
      @acted="onDetailActed"
    />

    <!-- Filter modal -->
    <ParentRecFilterModal
      v-if="filterOpen"
      :current="filter"
      :available-subjects="availableSubjects"
      @close="filterOpen = false"
      @apply="applyFilter"
    />
  </div>
</template>
