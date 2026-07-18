<!--
  StudentCardsPanel.vue — Siswa tab body for the Kartu QR Personal hub.
  The account-less student flow (backend MR !484): students never have
  a `users` account, so the roster reads directly from `students` +
  `student_classes`, keyed on `student_id`.

  Shape:

    ┌── KpiStripCards ────────────────────────────────────────────┐
    │  Total siswa │ Sudah ada kartu │ Belum ada kartu           │
    └──────────────────────────────────────────────────────────────┘
    ┌── PageFilterToolbar ────────────────────────────────────────┐
    │  [Class chip] [Status chip] ────────────  [🔎 search]       │
    └──────────────────────────────────────────────────────────────┘
    ┌── List (EntityRow per siswa) ───────────────────────────────┐
    │  ☐ [avatar] Name                    [pill] [Cetak]         │
    │            Class · NIS number                              │
    └──────────────────────────────────────────────────────────────┘
    ┌── Bulk footer (sticky when >0 selected) ────────────────────┐
    │  N dipilih   [Batal]   [Terbitkan & Cetak Kartu (N)]        │
    └──────────────────────────────────────────────────────────────┘

  When the `issue_student_cards` opt-in is OFF, the whole body is
  replaced by a warm, actionable empty state with a one-click enable
  button — that's the "sudah menginput siswa tapi tab kosong" fix.
  Because the setting also gates gate-scanning of student cards, we
  DON'T let admins issue/print cards while the flag is off — the printed
  QR would still be rejected at the gate. Enable-first is the honest
  ordering.

  "Terbitkan & Cetak" is a single button: the backend PDF export auto-
  issues any missing cards for the listed students BEFORE rendering
  (idempotent) so one click covers both mint + print. That's the whole
  point of the redesign — no separate issue-then-print two-step.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { AttendanceQrService } from '@/services/attendance-qr.service';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import { ClassroomService } from '@/services/classrooms.service';
import { useAcademicYearStore } from '@/stores/academic-year';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useToast } from '@/composables/useToast';
import type {
  StudentCardIssueResult,
  StudentCardListRow,
  StudentCardStatus,
} from '@/types/attendance-qr';
import type { TeacherAttendanceSettings } from '@/types/teacher-attendance';
import type { Classroom } from '@/types/entities';
import type { Pagination } from '@/types/api';
import Spinner from '@/components/ui/Spinner.vue';
import SkeletonList from '@/components/data/SkeletonList.vue';
import PaginationWidget from '@/components/data/Pagination.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import EntityRow from '@/components/feature/EntityRow.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';

const toast = useToast();
const ayStore = useAcademicYearStore();

// ── State ──────────────────────────────────────────────────────────
const loading = ref(true);
const rows = ref<StudentCardListRow[]>([]);
const pagination = ref<Pagination | null>(null);
const meta = ref<{ total_students: number; issued_count: number; missing_count: number }>({
  total_students: 0,
  issued_count: 0,
  missing_count: 0,
});

/** Set of selected student_id values — the backend keys on student_id. */
const selected = ref<Set<string>>(new Set());
const searchQuery = ref('');
/** Class filter — null = all classes. */
const classFilter = ref<string | null>(null);
/** card_status filter — 'all' shows every student regardless of card state. */
const statusFilter = ref<'all' | StudentCardStatus>('all');
const currentPage = ref(1);
const perPage = 25;

const classes = ref<Classroom[]>([]);

// ── Settings gate (`issue_student_cards` opt-in) ────────────────────
// Fetched from GET /teacher-attendance/settings on mount; the entire
// body flips between "empty-state-with-enable-button" (off) and the
// full list (on). Loading is a separate flag from the roster load so
// the two spinners don't fight over the layout.
const settings = ref<TeacherAttendanceSettings | null>(null);
const settingsLoading = ref(true);
const settingEnabling = ref(false);

const featureEnabled = computed(
  () => settings.value?.issue_student_cards === true,
);

// ── Action spinners ─────────────────────────────────────────────────
const exporting = ref(false);
/** Per-row export spinner state, keyed by student_id. */
const rowExporting = ref<Set<string>>(new Set());
/** Per-row revoke spinner state, keyed by card_id. */
const revoking = ref<Set<string>>(new Set());
/** Bulk "select all in class" spinner state. */
const selectingAll = ref(false);

// ── KPI strip ───────────────────────────────────────────────────────
// Icons + tones follow the semantic reading (brand = neutral count,
// green = good, amber = needs action). "Belum ada kartu" gets an
// accented card when non-zero so the admin's eye is drawn to it.
const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: 'Total siswa',
    value: meta.value.total_students,
    tone: 'brand',
  },
  {
    icon: 'id-card',
    label: 'Sudah ada kartu',
    value: meta.value.issued_count,
    tone: 'green',
  },
  {
    icon: 'alert-circle',
    label: 'Belum ada kartu',
    value: meta.value.missing_count,
    tone: meta.value.missing_count > 0 ? 'amber' : 'slate',
    accented: meta.value.missing_count > 0,
  },
]);

// ── Fetch functions ─────────────────────────────────────────────────
async function loadSettings() {
  settingsLoading.value = true;
  try {
    settings.value = await TeacherAttendanceService.getSettings();
  } catch (e) {
    toast.error(
      e instanceof Error
        ? e.message
        : 'Gagal memuat pengaturan penerbitan kartu siswa.',
    );
  } finally {
    settingsLoading.value = false;
  }
}

async function loadClasses() {
  try {
    // per_page 500 — same guardrail the student-list uses. A school with
    // more than 500 rombels doesn't exist in practice; the dropdown
    // would be unusable long before that.
    const res = await ClassroomService.list({ per_page: 500 });
    classes.value = res.items;
  } catch {
    // Non-fatal — the dropdown falls back to "Semua kelas" only.
  }
}

async function load() {
  const yearId = ayStore.selectedYearId;
  if (!yearId) {
    // Guard against the very first paint before the AY store resolves.
    // The AY watcher below re-triggers load() as soon as it does.
    rows.value = [];
    pagination.value = null;
    return;
  }
  loading.value = true;
  try {
    const res = await AttendanceQrService.listStudentCards({
      academic_year_id: yearId,
      class_id: classFilter.value ?? undefined,
      search: searchQuery.value.trim() || undefined,
      card_status:
        statusFilter.value === 'all' ? undefined : statusFilter.value,
      page: currentPage.value,
      per_page: perPage,
    });
    rows.value = res.items;
    pagination.value = res.pagination;
    meta.value = res.meta;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : 'Gagal memuat daftar siswa.',
    );
  } finally {
    loading.value = false;
  }
}

// ── Reactivity ──────────────────────────────────────────────────────
let searchTimer: number | null = null;
watch(searchQuery, () => {
  if (searchTimer !== null) window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => {
    currentPage.value = 1;
    void load();
  }, 250);
});
watch([classFilter, statusFilter], () => {
  currentPage.value = 1;
  // Changing scope resets selection — a selection carrying across the
  // class change would let admins accidentally print cards for siswa
  // they can't even see anymore.
  selected.value = new Set();
  void load();
});

// Re-fetch when AY changes (the admin picked a different tahun ajaran).
useAcademicYearWatcher(async () => {
  currentPage.value = 1;
  selected.value = new Set();
  await load();
});

function onPageChange(page: number) {
  currentPage.value = page;
  void load();
}

// ── Selection helpers ───────────────────────────────────────────────
function toggleRow(row: StudentCardListRow) {
  const next = new Set(selected.value);
  if (next.has(row.student_id)) next.delete(row.student_id);
  else next.add(row.student_id);
  selected.value = next;
}

function toggleAllOnPage() {
  const next = new Set(selected.value);
  const allSelected = rows.value.every((r) => next.has(r.student_id));
  for (const r of rows.value) {
    if (allSelected) next.delete(r.student_id);
    else next.add(r.student_id);
  }
  selected.value = next;
}

const selectedCount = computed(() => selected.value.size);
const allOnPageSelected = computed(
  () =>
    rows.value.length > 0 &&
    rows.value.every((r) => selected.value.has(r.student_id)),
);

/**
 * "Pilih semua siswa di kelas ini" — visible only when a class is
 * chosen. Fetches the full class (up to 500, backend cap) and unions
 * those ids into the current selection. Server round-trip so the
 * selection covers rows on other pages, not just the current one.
 */
async function selectAllInClass() {
  const yearId = ayStore.selectedYearId;
  if (!yearId || !classFilter.value) return;
  selectingAll.value = true;
  try {
    const res = await AttendanceQrService.listStudentCards({
      academic_year_id: yearId,
      class_id: classFilter.value,
      per_page: 500,
      page: 1,
    });
    const next = new Set(selected.value);
    for (const r of res.items) next.add(r.student_id);
    selected.value = next;
  } catch (e) {
    toast.error(
      e instanceof Error
        ? e.message
        : 'Gagal memuat semua siswa di kelas ini.',
    );
  } finally {
    selectingAll.value = false;
  }
}

function clearSelection() {
  selected.value = new Set();
}

// ── Copy helpers ────────────────────────────────────────────────────
/**
 * Class label + NIS composed into one subtitle line. Handles missing
 * pieces so an unenrolled student (no class row for the current AY)
 * still shows their NIS without the leading dot separator.
 */
function subtitleFor(row: StudentCardListRow): string {
  const cls = row.class_label ?? 'Belum ada kelas';
  const nis = row.student_number;
  return nis ? `${cls} · NIS ${nis}` : cls;
}

/**
 * Summary toast phrasing for a bulk issue-and-export. Reads honestly:
 * "3 kartu diterbitkan" vs "5 kartu sudah aktif · 2 dilewati" so the
 * admin sees why not every selected row got a fresh card.
 */
function summariseIssue(results: StudentCardIssueResult[]): string {
  const issued = results.filter((r) => r.status === 'issued').length;
  const exists = results.filter((r) => r.status === 'exists').length;
  const skipped = results.filter((r) => r.status === 'skipped').length;
  const parts: string[] = [];
  if (issued > 0) parts.push(`${issued} kartu diterbitkan`);
  if (exists > 0) parts.push(`${exists} sudah aktif`);
  if (skipped > 0) parts.push(`${skipped} dilewati`);
  return parts.length > 0 ? parts.join(' · ') : 'Tidak ada perubahan.';
}

// ── Actions ─────────────────────────────────────────────────────────

/**
 * Per-row Cetak — one-shot single-card print. Backend auto-issues if
 * the row doesn't have a card yet, so the button label stays "Cetak"
 * regardless of card state. The row-level spinner keeps concurrent
 * clicks from stacking.
 */
async function printOne(row: StudentCardListRow) {
  const id = row.student_id;
  if (rowExporting.value.has(id)) return;
  const next = new Set(rowExporting.value);
  next.add(id);
  rowExporting.value = next;
  try {
    const slug = row.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 40);
    await AttendanceQrService.exportStudentCardsPdf(
      [id],
      `kartu-qr-${slug || 'siswa'}.pdf`,
    );
    toast.success('Kartu tercetak.');
    // Refresh so the "Sudah ada kartu" pill reflects the auto-issue.
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : 'Gagal mengunduh PDF kartu QR.',
    );
  } finally {
    const after = new Set(rowExporting.value);
    after.delete(id);
    rowExporting.value = after;
  }
}

/**
 * Bulk "Terbitkan & Cetak" — one call does both. The backend export
 * endpoint auto-issues any missing cards first (idempotent, so already-
 * carded rows are a no-op) and then streams the combined PDF. The
 * toast surfaces the issue-summary separately because the export blob
 * alone doesn't tell the admin how many were new.
 */
async function exportSelected() {
  if (selected.value.size === 0) return;
  exporting.value = true;
  try {
    const ids = Array.from(selected.value);
    // Fire an explicit issue pre-flight so we can show an accurate
    // toast — the export endpoint auto-issues too, but its response is
    // the PDF blob (opaque). This costs one extra round-trip; the
    // admin gets an honest "5 new, 3 already active" summary in
    // exchange. Both calls are idempotent.
    let summary = '';
    try {
      const results = await AttendanceQrService.issueStudentCards(ids);
      summary = summariseIssue(results);
    } catch {
      // Non-fatal: the export call auto-issues anyway. Fall back to a
      // simpler toast instead of blocking the print.
      summary = '';
    }
    const ts = new Date().toISOString().slice(0, 10);
    await AttendanceQrService.exportStudentCardsPdf(
      ids,
      `kartu-qr-siswa-${ts}.pdf`,
    );
    toast.success(summary ? `${summary} · PDF terunduh.` : 'PDF terunduh.');
    clearSelection();
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : 'Gagal mengunduh PDF kartu QR.',
    );
  } finally {
    exporting.value = false;
  }
}

/**
 * Revoke one card. Only clickable when `card_id` is present (which
 * mirrors `has_card=true`). After a successful revoke the row-list is
 * refreshed so the pill flips back to muted.
 */
async function revokeRow(row: StudentCardListRow) {
  if (!row.card_id) return;
  const cardId = row.card_id;
  if (revoking.value.has(cardId)) return;
  const next = new Set(revoking.value);
  next.add(cardId);
  revoking.value = next;
  try {
    await AttendanceQrService.revokeStudentCard(cardId);
    toast.success(`Kartu ${row.name} dicabut.`);
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : 'Gagal mencabut kartu QR siswa.',
    );
  } finally {
    const after = new Set(revoking.value);
    after.delete(cardId);
    revoking.value = after;
  }
}

/**
 * One-click enable of the `issue_student_cards` setting from the empty
 * state. On success we flip the local settings ref, load the roster,
 * and the empty state disappears — no page refresh needed.
 */
async function enableFeature() {
  if (settingEnabling.value) return;
  settingEnabling.value = true;
  try {
    const saved = await TeacherAttendanceService.updateSettings({
      issue_student_cards: true,
    });
    settings.value = saved;
    toast.success('Penerbitan kartu siswa diaktifkan.');
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error
        ? e.message
        : 'Gagal mengaktifkan penerbitan kartu siswa.',
    );
  } finally {
    settingEnabling.value = false;
  }
}

// ── Mount ───────────────────────────────────────────────────────────
onMounted(async () => {
  await loadSettings();
  await Promise.all([loadClasses(), featureEnabled.value ? load() : Promise.resolve()]);
  // If the feature is off, the load() call is deferred until the admin
  // clicks Aktifkan; setting the roster loading flag off explicitly so
  // the skeleton doesn't linger under the empty state.
  if (!featureEnabled.value) loading.value = false;
});
</script>

<template>
  <div class="space-y-md">
    <!-- ─────────── FEATURE OFF: actionable empty state ─────────── -->
    <!-- Warm, not scary. Explains the opt-in in plain Indonesian and
         offers one-click enable. Same tone as the AttendanceConfigView
         copy that already describes this flag, kept inline so we don't
         churn i18n keys mid-rebuild. -->
    <div
      v-if="!settingsLoading && !featureEnabled"
      class="bg-white border border-slate-200 rounded-2xl p-6 sm:p-8 text-center"
    >
      <div
        class="mx-auto w-14 h-14 rounded-2xl bg-role-admin/10 text-role-admin grid place-items-center mb-4"
      >
        <NavIcon name="id-card" :size="26" />
      </div>
      <h3 class="text-base font-black text-slate-900 mb-1">
        Penerbitan kartu siswa belum aktif
      </h3>
      <p class="text-sm text-slate-600 max-w-md mx-auto">
        Aktifkan agar sekolah bisa mencetak kartu QR untuk siswa dan
        staf memindai kartu tersebut di gerbang. Kartu guru dan staf
        tidak terpengaruh.
      </p>
      <button
        type="button"
        class="mt-5 inline-flex items-center gap-2 rounded-xl bg-role-admin hover:opacity-90 text-white px-md py-sm text-sm font-semibold disabled:opacity-60 transition-colors"
        :disabled="settingEnabling"
        @click="enableFeature"
      >
        <Spinner v-if="settingEnabling" size="sm" />
        <NavIcon v-else name="check" :size="15" />
        Aktifkan penerbitan kartu siswa
      </button>
      <p class="mt-3 text-2xs text-slate-400">
        Setelan ini juga tersedia di
        <RouterLink
          :to="{ name: 'admin.settings.attendance' }"
          class="underline hover:text-role-admin"
        >Pengaturan Presensi</RouterLink>.
      </p>
    </div>

    <!-- ─────────── FEATURE ON: full siswa manager ─────────── -->
    <template v-else-if="featureEnabled">
      <!-- 3-up KPI strip — total / issued / missing. -->
      <KpiStripCards :cards="kpiCards" :lg-cols="3" :loading="loading && rows.length === 0" />

      <!-- Filter row — class + status chips on the left, search on the
           right. Canonical shared toolbar so it matches the engagement
           page + every other admin filter row. -->
      <PageFilterToolbar
        v-model:search="searchQuery"
        search-placeholder="Cari nama atau NIS…"
        :search-min-width="240"
      >
        <template #chips>
          <select
            v-model="classFilter"
            class="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:ring-2 focus:ring-brand/20 focus:border-brand"
          >
            <option :value="null">Semua kelas</option>
            <option v-for="c in classes" :key="c.id" :value="c.id">
              {{ c.name }}
            </option>
          </select>
          <select
            v-model="statusFilter"
            class="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:ring-2 focus:ring-brand/20 focus:border-brand"
          >
            <option value="all">Semua status</option>
            <option value="issued">Sudah ada kartu</option>
            <option value="missing">Belum ada kartu</option>
          </select>
        </template>
      </PageFilterToolbar>

      <!-- Row-header strip: master checkbox + "select all in class"
           affordance (only when a class is picked). Sits above the row
           list because the checkbox governs the WHOLE page rather than
           any single row — putting it in the first EntityRow would
           misread as "select this student". -->
      <div
        v-if="!loading && rows.length > 0"
        class="flex flex-wrap items-center gap-3 px-4 py-2.5 bg-white border border-slate-200 rounded-2xl"
      >
        <label class="inline-flex items-center gap-2 text-sm text-slate-700 cursor-pointer">
          <input
            type="checkbox"
            :checked="allOnPageSelected"
            class="h-4 w-4 rounded accent-role-admin"
            aria-label="Pilih semua di halaman ini"
            @change="toggleAllOnPage"
          />
          <span class="font-semibold">Pilih semua di halaman</span>
        </label>
        <button
          v-if="classFilter"
          type="button"
          class="inline-flex items-center gap-1.5 text-xs font-semibold text-role-admin hover:underline disabled:opacity-60"
          :disabled="selectingAll"
          @click="selectAllInClass"
        >
          <Spinner v-if="selectingAll" size="sm" />
          <NavIcon v-else name="users" :size="12" />
          Pilih semua siswa di kelas
        </button>
        <span class="ml-auto text-2xs text-slate-500">
          Menampilkan {{ rows.length }} dari {{ meta.total_students }}
        </span>
      </div>

      <!-- Loading + roster body. -->
      <SkeletonList v-if="loading && rows.length === 0" :rows="6" />

      <div
        v-else-if="rows.length === 0"
        class="bg-white border border-slate-200 rounded-2xl p-8 text-center"
      >
        <div
          class="mx-auto w-12 h-12 rounded-full bg-slate-100 text-slate-400 grid place-items-center mb-3"
        >
          <NavIcon name="search" :size="18" />
        </div>
        <p class="text-sm font-bold text-slate-800">Tidak ada siswa cocok</p>
        <p class="text-2xs text-slate-500 mt-1">
          Ubah filter atau tambah siswa lewat menu Manajemen Data.
        </p>
      </div>

      <div
        v-else
        class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
      >
        <EntityRow
          v-for="(row, idx) in rows"
          :key="row.student_id"
          :title="row.name || '—'"
          :subtitle="subtitleFor(row)"
          :divided="idx > 0"
          :highlighted="selected.has(row.student_id) ? 'bg-role-admin/5' : false"
          @click="toggleRow(row)"
        >
          <!-- Leading: checkbox + avatar. EntityRow's default #leading
               is the avatar; overriding it lets us pack the checkbox
               beside the initials so bulk selection stays one thumb-
               reach away. `@click.stop` on the checkbox so its native
               toggle doesn't fight the row's click handler. -->
          <template #leading>
            <div class="flex items-center gap-2 flex-shrink-0" @click.stop>
              <input
                type="checkbox"
                :checked="selected.has(row.student_id)"
                class="h-4 w-4 rounded accent-role-admin"
                aria-label="Pilih siswa"
                @change="toggleRow(row)"
              />
              <InitialsAvatar
                :name="row.name || '?'"
                :size="40"
                :color="'#143068'"
                :border-radius="12"
              />
            </div>
          </template>

          <!-- Trailing: status pill + row-level actions (Cetak, Cabut). -->
          <template #trailing>
            <div class="flex items-center gap-2 flex-shrink-0" @click.stop>
              <span
                v-if="row.has_card"
                class="hidden sm:inline-flex items-center gap-1 rounded-full bg-emerald-50 text-emerald-700 px-2 py-0.5 text-xs font-semibold"
              >
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                Kartu aktif
              </span>
              <span
                v-else
                class="hidden sm:inline-flex items-center gap-1 rounded-full bg-slate-100 text-slate-500 px-2 py-0.5 text-xs font-semibold"
              >
                <span class="w-1.5 h-1.5 rounded-full bg-slate-300"></span>
                Belum ada kartu
              </span>
              <button
                type="button"
                class="inline-flex items-center gap-1 rounded-lg border border-slate-300 hover:bg-slate-50 text-slate-700 px-2.5 py-1 text-xs font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
                :disabled="rowExporting.has(row.student_id)"
                @click="printOne(row)"
              >
                <Spinner v-if="rowExporting.has(row.student_id)" size="sm" />
                <NavIcon v-else name="printer" :size="12" />
                Cetak
              </button>
              <button
                v-if="row.has_card"
                type="button"
                class="inline-flex items-center gap-1 text-xs font-semibold text-status-danger hover:underline disabled:opacity-50"
                :disabled="row.card_id ? revoking.has(row.card_id) : true"
                @click="revokeRow(row)"
              >
                <Spinner
                  v-if="row.card_id && revoking.has(row.card_id)"
                  size="sm"
                />
                <span v-else>Cabut</span>
              </button>
            </div>
          </template>
        </EntityRow>
      </div>

      <!-- Server-side pagination. /list returns 25 rows per page. -->
      <div v-if="pagination && pagination.total_pages > 1" class="pt-2">
        <PaginationWidget :pagination="pagination" @change="onPageChange" />
      </div>
    </template>

    <!-- ─────────── Loading gate (before settings resolve) ─────────── -->
    <SkeletonList v-else :rows="4" />

    <!-- ─────────── Sticky bulk footer ─────────── -->
    <!-- Appears only when the admin has selected at least one siswa;
         `fixed` at the bottom of the viewport so a long roster doesn't
         hide the primary CTA. Backdrop blur so the text below stays
         legible while the sheet floats. -->
    <Teleport to="body">
      <transition
        enter-active-class="transition-transform duration-200 ease-out"
        leave-active-class="transition-transform duration-150 ease-in"
        enter-from-class="translate-y-full"
        leave-to-class="translate-y-full"
      >
        <div
          v-if="featureEnabled && selectedCount > 0"
          class="fixed inset-x-0 bottom-0 z-30 bg-white/95 backdrop-blur border-t border-slate-200 shadow-2xl"
        >
          <div class="max-w-6xl mx-auto flex items-center gap-3 px-4 py-3">
            <p class="text-sm font-bold text-slate-900">
              {{ selectedCount }} siswa dipilih
            </p>
            <span class="flex-1" />
            <button
              type="button"
              class="text-xs font-semibold text-slate-500 hover:text-slate-900 px-2 py-1"
              @click="clearSelection"
            >
              Batal
            </button>
            <button
              type="button"
              class="inline-flex items-center gap-2 rounded-xl bg-role-admin hover:opacity-90 text-white px-md py-sm text-sm font-semibold disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="exporting"
              @click="exportSelected"
            >
              <Spinner v-if="exporting" size="sm" />
              <NavIcon v-else name="printer" :size="14" />
              Terbitkan &amp; Cetak Kartu ({{ selectedCount }})
            </button>
          </div>
        </div>
      </transition>
    </Teleport>
  </div>
</template>
