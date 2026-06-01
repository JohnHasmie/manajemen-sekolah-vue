<!--
  ParentGradeView.vue — Nilai anak (read-only) untuk wali murid.

  Web port of Flutter's `parent_grade_screen.dart`. Layout shape:
    1. ParentPageHeader (built-in child chip pair)
    2. 3-column KPI strip — Penilaian / Rata-rata / Rentang
    3. Tipe Nilai filter chip (single-select bottom sheet)
    4. Per-subject sections — each with an UPPERCASE subject header +
       letter+avg pill, then one card per assessment row showing
       letter badge · title · type · date · score · KKM.

  Auto-marks visible un-read grades as read via IntersectionObserver
  (debounced into one batched POST).

  Refetches on academic-year change.
-->
<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useChildPicker } from '@/composables/useChildPicker';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { ParentService } from '@/services/parent.service';
import type { ParentGradeEntry } from '@/types/parent';
import { PARENT_GRADE_TYPE_OPTIONS } from '@/types/parent';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';

const { activeChildId, activeChild } = useChildPicker();

// Semester defaults to 2 (Genap) — matches the mobile-app default.
const semester = ref<'1' | '2'>('2');

// Tipe Nilai — single-select.
const typeFilter = ref<string | null>(null);
const showTypePicker = ref(false);
const activeTypeLabel = computed(() => {
  if (!typeFilter.value) return 'Semua tipe';
  return (
    PARENT_GRADE_TYPE_OPTIONS.find((o) => o.value === typeFilter.value)?.label ??
    typeFilter.value
  );
});
const hasActiveFilter = computed(() => typeFilter.value !== null);

// ── Data ──
const entries = ref<ParentGradeEntry[]>([]);
const isLoading = ref(true);
const isFirstLoad = ref(true);
const error = ref<string | null>(null);

async function reload() {
  if (!activeChildId.value) {
    isLoading.value = false;
    isFirstLoad.value = false;
    entries.value = [];
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    entries.value = await ParentService.gradesFlat(
      activeChildId.value,
      semester.value,
    );
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
    isFirstLoad.value = false;
  }
}

onMounted(reload);
watch([activeChildId, semester], () => {
  isFirstLoad.value = true;
  reload();
});
useAcademicYearWatcher(() => {
  isFirstLoad.value = true;
  reload();
});

// ── Client-side filter ──
const filteredEntries = computed<ParentGradeEntry[]>(() => {
  if (!typeFilter.value) return entries.value;
  const want = typeFilter.value.toLowerCase();
  return entries.value.filter(
    (e) => normalizeType(e.type).toLowerCase() === want,
  );
});

// Normalise legacy backend spellings (UTS/UAS) to the mobile vocabulary
// (PTS/PAS) so the filter chip and the row label stay aligned.
function normalizeType(raw: string): string {
  const t = (raw || '').trim();
  const upper = t.toUpperCase();
  if (upper === 'UTS') return 'PTS';
  if (upper === 'UAS') return 'PAS';
  if (upper === 'UH' || upper === 'PTS' || upper === 'PAS') return upper;
  // Capitalised label otherwise (Tugas/Praktek/Portofolio/Proyek).
  return t.charAt(0).toUpperCase() + t.slice(1).toLowerCase();
}

// ── Grouping by subject ──
interface SubjectGroup {
  subject_id: string;
  subject_name: string;
  rows: ParentGradeEntry[];
  average: number;
}
const groups = computed<SubjectGroup[]>(() => {
  const map = new Map<string, SubjectGroup>();
  for (const e of filteredEntries.value) {
    const key = e.subject_id || e.subject_name;
    const g = map.get(key) ?? {
      subject_id: e.subject_id,
      subject_name: e.subject_name,
      rows: [],
      average: 0,
    };
    g.rows.push(e);
    map.set(key, g);
  }
  for (const g of map.values()) {
    const nums = g.rows
      .map((r) => r.score)
      .filter((n): n is number => typeof n === 'number');
    g.average = nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : 0;
  }
  // Sort alphabetically.
  return Array.from(map.values()).sort((a, b) =>
    a.subject_name.localeCompare(b.subject_name),
  );
});

// ── KPI aggregates (matches mobile _gradeAggregates) ──
const aggregates = computed(() => {
  const scores = entries.value
    .map((g) => g.score)
    .filter((s): s is number => typeof s === 'number');
  const sum = scores.reduce((a, b) => a + b, 0);
  return {
    total: entries.value.length,
    scored: scores.length,
    pending: entries.value.length - scores.length,
    avg: scores.length ? sum / scores.length : 0,
    min: scores.length ? Math.min(...scores) : 0,
    max: scores.length ? Math.max(...scores) : 0,
  };
});

function avgLabel(avg: number): string {
  if (avg >= 85) return 'Sangat Baik';
  if (avg >= 75) return 'Baik';
  if (avg >= 65) return 'Cukup';
  return 'Perlu perbaikan';
}
function avgTone(avg: number): string {
  if (avg >= 85) return 'bg-emerald-100 text-emerald-700';
  if (avg >= 75) return 'bg-blue-100 text-blue-700';
  if (avg >= 65) return 'bg-amber-100 text-amber-700';
  return 'bg-red-100 text-red-700';
}
function fmtScore(v: number): string {
  if (v === Math.trunc(v)) return v.toFixed(0);
  return v.toFixed(1).replace('.', ',');
}

// ── Letter grade helpers (shared between section header + row card) ──
function letterFor(score: number): string {
  if (score >= 85) return 'A';
  if (score >= 75) return 'B';
  if (score >= 65) return 'C';
  if (score >= 55) return 'D';
  return 'E';
}
function letterBg(score: number): string {
  if (score >= 85) return 'bg-emerald-100';
  if (score >= 75) return 'bg-blue-100';
  if (score >= 65) return 'bg-amber-100';
  return 'bg-red-100';
}
function letterFg(score: number): string {
  if (score >= 85) return 'text-emerald-700';
  if (score >= 75) return 'text-blue-700';
  if (score >= 65) return 'text-amber-700';
  return 'text-red-700';
}

// ── Date formatter (mobile parity: "5 Mei 2026") ──
const MONTHS = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
function fmtDate(iso: string): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return iso;
  return `${d.getDate()} ${MONTHS[d.getMonth() + 1]} ${d.getFullYear()}`;
}

// ── IntersectionObserver mark-as-read ──
const observerRoot = ref<HTMLElement | null>(null);
let observer: IntersectionObserver | null = null;
const pendingUnread = new Set<string>();
const processedIds = new Set<string>();
let flushTimer: number | null = null;

function flushMarkRead() {
  if (pendingUnread.size === 0) return;
  const ids = Array.from(pendingUnread);
  pendingUnread.clear();
  ParentService.markGradeRead(ids).then(() => {
    const idSet = new Set(ids);
    entries.value = entries.value.map((e) =>
      idSet.has(e.id) ? { ...e, is_read: true } : e,
    );
  });
}

function scheduleFlush() {
  if (flushTimer != null) window.clearTimeout(flushTimer);
  flushTimer = window.setTimeout(flushMarkRead, 600);
}

function setupObserver() {
  if (observer) return;
  if (typeof IntersectionObserver === 'undefined') return;
  observer = new IntersectionObserver(
    (records) => {
      for (const r of records) {
        if (!r.isIntersecting) continue;
        const id = (r.target as HTMLElement).dataset.gradeId;
        if (id && !processedIds.has(id)) {
          processedIds.add(id);
          pendingUnread.add(id);
        }
      }
      if (pendingUnread.size > 0) scheduleFlush();
    },
    { threshold: 0.6 },
  );
}

function attachUnreadObservers() {
  if (!observer || !observerRoot.value) return;
  const nodes = observerRoot.value.querySelectorAll<HTMLElement>(
    '[data-unread="1"]',
  );
  nodes.forEach((n) => observer!.observe(n));
}

onMounted(setupObserver);
onBeforeUnmount(() => {
  observer?.disconnect();
  observer = null;
  if (flushTimer != null) window.clearTimeout(flushTimer);
});
watch(filteredEntries, async () => {
  await nextTick();
  attachUnreadObservers();
});

// ── Async state ──
const state = computed<AsyncState<ParentGradeEntry[]>>(() => {
  if (isLoading.value && isFirstLoad.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filteredEntries.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredEntries.value };
});

const emptyTitle = computed(() =>
  entries.value.length > 0 && filteredEntries.value.length === 0
    ? 'Tidak ada nilai untuk filter ini'
    : 'Belum ada nilai',
);
const emptyDescription = computed(() => {
  if (entries.value.length > 0 && filteredEntries.value.length === 0) {
    return 'Coba reset filter tipe nilai.';
  }
  return `${activeChild()?.name ?? 'Anak ini'} belum punya nilai pada semester ini.`;
});

function pickType(value: string | null) {
  typeFilter.value = value;
  showTypePicker.value = false;
}
function resetFilter() {
  typeFilter.value = null;
}

// Header semester segmented (Genap default, Ganjil alternative).
const semesterOptions = [
  { key: '2' as const, label: 'Semester 2 · Genap' },
  { key: '1' as const, label: 'Semester 1 · Ganjil' },
];
const showSemesterPicker = ref(false);
const activeSemesterLabel = computed(
  () => semesterOptions.find((o) => o.key === semester.value)?.label ?? '',
);
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- 1. Header -->
    <ParentPageHeader
      kicker="Akademik · Anak"
      title="Nilai"
      :meta="`${activeChild()?.class_name ?? '—'} · ${semester === '1' ? 'Semester 1' : 'Semester 2'} · ${entries.length} penilaian`"
    />

    <!-- 2. KPI strip (3 columns — Penilaian / Rata-rata / Rentang) -->
    <section
      class="bg-white border border-slate-200 rounded-2xl px-4 py-3 grid grid-cols-3 divide-x divide-slate-100"
    >
      <div class="pr-3">
        <p class="text-[10px] font-bold uppercase tracking-widest text-slate-400">
          Penilaian
        </p>
        <p class="text-xl font-black text-slate-900 mt-1">
          {{ aggregates.total }}
        </p>
        <p class="text-[10px] font-bold text-slate-500 mt-0.5 truncate">
          {{ aggregates.scored }} sudah · {{ aggregates.pending }} menunggu
        </p>
      </div>
      <div class="px-3">
        <p class="text-[10px] font-bold uppercase tracking-widest text-slate-400">
          Rata-rata
        </p>
        <p class="text-xl font-black text-slate-900 mt-1">
          {{ fmtScore(aggregates.avg) }}
        </p>
        <span
          v-if="aggregates.scored > 0"
          class="inline-block text-[9px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded-full mt-0.5"
          :class="avgTone(aggregates.avg)"
        >
          {{ avgLabel(aggregates.avg) }}
        </span>
      </div>
      <div class="pl-3">
        <p class="text-[10px] font-bold uppercase tracking-widest text-slate-400">
          Rentang
        </p>
        <p class="text-xl font-black text-slate-900 mt-1">
          {{ aggregates.scored > 0
            ? `${fmtScore(aggregates.min)} — ${fmtScore(aggregates.max)}`
            : '—' }}
        </p>
        <p class="text-[10px] font-bold text-slate-500 mt-0.5">
          Min / Maks
        </p>
      </div>
    </section>

    <!-- 3. Filter toolbar -->
    <PageFilterToolbar hide-search>
      <template #chips>
        <div class="flex items-center gap-2 flex-wrap">
          <AppFilterChip
            label="Periode"
            :value="activeSemesterLabel"
            icon-name="calendar"
            tone="cobalt"
            @click="showSemesterPicker = true"
          />
          <AppFilterChip
            label="Tipe Nilai"
            :value="activeTypeLabel"
            icon-name="book"
            tone="amber"
            @click="showTypePicker = true"
          />
          <button
            v-if="hasActiveFilter"
            type="button"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-xl border border-slate-200 text-[10px] font-bold uppercase tracking-widest text-slate-500 hover:bg-slate-50"
            @click="resetFilter"
          >
            <NavIcon name="x" :size="10" />
            Reset
          </button>
        </div>
      </template>
    </PageFilterToolbar>

    <!-- 4. Content -->
    <AsyncView
      :state="state"
      :empty-title="emptyTitle"
      :empty-description="emptyDescription"
      empty-icon="book"
      @retry="reload"
    >
      <template #default>
        <div ref="observerRoot" class="space-y-6">
          <section
            v-for="g in groups"
            :key="g.subject_id || g.subject_name"
            class="space-y-2"
          >
            <!-- Subject section header — UPPERCASE name + letter+avg pill -->
            <header class="flex items-center justify-between px-1">
              <h3
                class="text-[11px] font-bold uppercase tracking-widest text-slate-600 truncate"
              >
                {{ g.subject_name }}
              </h3>
              <span
                v-if="g.average > 0"
                class="inline-flex items-center text-[11px] font-bold px-2.5 py-0.5 rounded-lg"
                :class="`${letterBg(g.average)} ${letterFg(g.average)}`"
              >
                {{ letterFor(g.average) }} · {{ Math.round(g.average) }}
              </span>
            </header>

            <!-- Grade rows -->
            <div class="space-y-2">
              <div
                v-for="row in g.rows"
                :key="row.id"
                :data-grade-id="row.id"
                :data-unread="row.is_read ? '0' : '1'"
                class="flex items-center gap-3 px-3 py-3 bg-white border border-slate-200 rounded-2xl hover:border-slate-300 transition-colors"
              >
                <!-- Letter-grade badge -->
                <div
                  class="w-11 h-9 rounded-xl grid place-items-center flex-shrink-0"
                  :class="
                    row.score != null
                      ? `${letterBg(row.score)} ${letterFg(row.score)}`
                      : 'bg-slate-100 text-slate-400'
                  "
                >
                  <span class="text-sm font-black">
                    {{ row.score != null ? letterFor(row.score) : '—' }}
                  </span>
                </div>

                <!-- Title + type · date -->
                <div class="flex-1 min-w-0">
                  <p class="text-[13px] font-bold text-slate-900 truncate">
                    {{ row.title || normalizeType(row.type) }}
                  </p>
                  <p class="text-[11px] text-slate-500 truncate mt-0.5">
                    {{ normalizeType(row.type) }} ·
                    {{ row.date ? fmtDate(row.date) : '—' }}
                  </p>
                </div>

                <!-- Score + KKM -->
                <div class="text-right flex-shrink-0">
                  <p class="text-xl font-black text-slate-900 leading-none">
                    {{ row.score != null ? row.score.toFixed(0) : '—' }}
                  </p>
                  <p class="text-[10px] font-medium text-slate-500 mt-1">
                    KKM {{ row.kkm }}
                  </p>
                </div>
              </div>
            </div>
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- Tipe Nilai picker -->
    <Modal
      v-if="showTypePicker"
      title="Filter Tipe Nilai"
      @close="showTypePicker = false"
    >
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors"
            :class="{
              'bg-role-wali/5 text-role-wali font-bold': typeFilter === null,
            }"
            @click="pickType(null)"
          >
            Semua tipe
          </button>
        </li>
        <li v-for="opt in PARENT_GRADE_TYPE_OPTIONS" :key="opt.value">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors"
            :class="{
              'bg-role-wali/5 text-role-wali font-bold':
                opt.value === typeFilter,
            }"
            @click="pickType(opt.value)"
          >
            {{ opt.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- Semester picker -->
    <Modal
      v-if="showSemesterPicker"
      title="Pilih Periode"
      @close="showSemesterPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="opt in semesterOptions" :key="opt.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors"
            :class="{
              'bg-role-wali/5 text-role-wali font-bold':
                opt.key === semester,
            }"
            @click="
              semester = opt.key;
              showSemesterPicker = false;
            "
          >
            {{ opt.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
