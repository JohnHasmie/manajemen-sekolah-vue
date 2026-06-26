<!--
  ParentReportCardView.vue — parent rapor list (Frame parent).

  Web port of `parent_report_card_screen.dart`. Lists the parent's
  children that have a *published* raport, with:

    1. BrandPageHeader (parent) + child segmented control
    2. KpiStripCards (active child) — Rata-rata / Ranking /
       Kehadiran / Status
    3. Semester chip strip (display-only — backend already scopes
       via X-Academic-Year header)
    4. Per-child card with hero strip + status pills + Cetak PDF
       (tap card → detail route)

  Backend `/parent/raports` only ships rows with `status='published'`,
  so empty state copy reflects "Sekolah belum menerbitkan rapor"
  instead of suggesting the parent has no children.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useChildPicker } from '@/composables/useChildPicker';
import { ReportCardService } from '@/services/report-card.service';
import {
  STATUS_LABELS,
  STATUS_TONES,
  type ParentRaportRow,
} from '@/types/report-card';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { t } = useI18n();
const router = useRouter();
const { activeChildId } = useChildPicker();

// Semester filter (drives the API fetch). Backend convention: '1' =
// Ganjil, '2' = Genap. Default to current semester via month heuristic
// (Jul-Dec = Ganjil, Jan-Jun = Genap) — same as the mobile screen.
type SemesterId = '1' | '2';
const semester = ref<SemesterId>(
  (new Date().getMonth() + 1) >= 7 ? '1' : '2',
);
const semesterLabel = (id: SemesterId): string =>
  id === '1'
    ? t('parent.reportCards.semester1Full')
    : t('parent.reportCards.semester2Full');

const filterOpen = ref(false);

// ── Data state ──
const allRows = ref<ParentRaportRow[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isPrintingFor = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// Per-semester row count, so the chip strip can dim a semester that
// has nothing published yet (mobile parity — Flutter greys the chip
// instead of letting the parent tap into an empty list).
const semesterCounts = ref<Record<SemesterId, number | null>>({
  '1': null,
  '2': null,
});

// ── Loader ──
async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    allRows.value = await ReportCardService.parentRaports({
      semester_id: semester.value,
    });
    // Cache the count for this semester chip.
    semesterCounts.value[semester.value] = allRows.value.length;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

/**
 * One-off probe of the other semester's row count so both chips can
 * render their data-availability state immediately. Doesn't touch
 * `allRows`/`isLoading` — purely a side count fetch.
 */
async function probeOtherSemester() {
  const other: SemesterId = semester.value === '1' ? '2' : '1';
  if (semesterCounts.value[other] !== null) return;
  try {
    const rows = await ReportCardService.parentRaports({ semester_id: other });
    semesterCounts.value[other] = rows.length;
  } catch {
    // Failure is non-fatal — chip just stays in "unknown" state.
  }
}

onMounted(async () => {
  await reload();
  probeOtherSemester();
});
useAcademicYearWatcher(async () => {
  // Reset cached counts so chip availability re-resolves under the
  // new academic year.
  semesterCounts.value = { '1': null, '2': null };
  await reload();
  probeOtherSemester();
});
watch(semester, () => reload());

// ── Derived ──
const activeChildRow = computed(() => {
  if (!activeChildId.value) return allRows.value[0] ?? null;
  return (
    allRows.value.find((r) => r.student.id === activeChildId.value) ??
    allRows.value[0] ??
    null
  );
});

const kpiCards = computed<KpiCard[]>(() => {
  const r = activeChildRow.value;
  if (!r) {
    return [
      { icon: 'check-circle', label: t('parent.reportCards.kpiAverage'), value: '—', tone: 'brand' },
      { icon: 'users', label: t('parent.reportCards.kpiRank'), value: '—', tone: 'violet' },
      { icon: 'bell', label: t('parent.reportCards.kpiAttendance'), value: '—', tone: 'green' },
      { icon: 'file-text', label: t('parent.reportCards.kpiStatus'), value: '—', tone: 'slate' },
    ];
  }
  const avg = r.average_score !== null ? r.average_score : null;
  const rank =
    r.rank !== null && r.total_in_class !== null
      ? `${r.rank}/${r.total_in_class}`
      : '—';
  const attPct =
    r.attendance_pct !== null ? `${Math.round(r.attendance_pct)}%` : '—';
  return [
    {
      icon: 'check-circle',
      label: t('parent.reportCards.kpiAverage'),
      value: avg !== null ? avg : '—',
      tone: avg !== null && avg >= 75 ? 'green' : 'brand',
    },
    { icon: 'users', label: t('parent.reportCards.kpiRank'), value: rank, tone: 'violet' },
    {
      icon: 'bell',
      label: t('parent.reportCards.kpiAttendance'),
      value: attPct,
      tone:
        r.attendance_pct !== null && r.attendance_pct >= 90
          ? 'green'
          : 'amber',
    },
    {
      icon: 'file-text',
      label: t('parent.reportCards.kpiStatus'),
      value: STATUS_LABELS[r.reportCard.status],
      tone:
        r.reportCard.status === 'distributed' ||
        r.reportCard.status === 'published'
          ? 'green'
          : 'slate',
    },
  ];
});

const listState = computed<AsyncState<ParentRaportRow[]>>(() => {
  if (isLoading.value && allRows.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (allRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: allRows.value };
});

// ── Actions ──
function openDetail(row: ParentRaportRow) {
  router.push({
    name: 'parent.report-cards.detail',
    params: { studentClassId: row.student_class_id },
    // Carry the active semester so the detail view can scope its
    // fetch the same way — the same student_class_id can appear in
    // two different semester windows and a default fetch would miss it.
    query: { semester: semester.value },
  });
}

async function downloadPdf(row: ParentRaportRow) {
  if (
    row.reportCard.status !== 'published' &&
    row.reportCard.status !== 'distributed'
  ) {
    toast.value = {
      message: t('parent.reportCards.toastNotPublished'),
      tone: 'error',
    };
    return;
  }
  isPrintingFor.value = row.student_class_id;
  try {
    // Parent default = certificate-style PDF (mobile parity).
    await ReportCardService.exportCertificatePdf({
      student_class_id: row.student_class_id,
      academic_year_id: '',
      semester_id: semester.value,
      filename: `e-rapor-${row.student.name}.pdf`,
    });
    toast.value = { message: t('parent.reportCards.toastDownloaded'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isPrintingFor.value = null;
  }
}

function pickSemester(id: SemesterId) {
  semester.value = id;
  filterOpen.value = false;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentPageHeader
      :kicker="t('parent.reportCards.kicker')"
      :title="t('parent.reportCards.title')"
      :meta="
        activeChildRow
          ? `${activeChildRow.student.class_name ?? '—'} · ${semesterLabel(semester)}`
          : semesterLabel(semester)
      "
    >
      <template #actions>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-[12px] font-bold transition"
          @click="filterOpen = true"
        >
          <NavIcon name="filter" :size="12" />
          {{ t('parent.reportCards.filter') }}
        </button>
      </template>
    </ParentPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <!--
      Semester filter chips (Ganjil / Genap) — drive the API fetch.
      Empty semesters are dimmed (mobile parity) but still clickable
      so the parent can confirm "nothing here yet" for themselves.
    -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="opt in [
          { id: '1' as SemesterId, label: t('parent.reportCards.semesterShort1') },
          { id: '2' as SemesterId, label: t('parent.reportCards.semesterShort2') },
        ]"
        :key="opt.id"
        type="button"
        class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border inline-flex items-center gap-1.5"
        :class="[
          semester === opt.id
            ? 'bg-role-wali text-white border-role-wali shadow-sm'
            : semesterCounts[opt.id] === 0
              ? 'bg-slate-50 text-slate-400 border-slate-200'
              : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40',
        ]"
        @click="semester = opt.id"
      >
        {{ opt.label }}
        <span
          v-if="semesterCounts[opt.id] !== null"
          class="text-[9.5px] font-black px-1.5 py-0.5 rounded-md"
          :class="[
            semester === opt.id
              ? 'bg-white/20 text-white'
              : semesterCounts[opt.id] === 0
                ? 'bg-slate-200 text-slate-500'
                : 'bg-slate-100 text-slate-500',
          ]"
        >
          {{ semesterCounts[opt.id] === 0 ? t('parent.reportCards.chipEmpty') : semesterCounts[opt.id] }}
        </span>
      </button>
    </div>

    <AsyncView
      :state="listState"
      :empty-title="t('parent.reportCards.emptyState')"
      :empty-description="t('parent.reportCards.emptyDesc')"
      empty-icon="file-text"
      @retry="reload"
    >
      <div class="space-y-3">
        <article
          v-for="row in allRows"
          :key="row.student_class_id"
          class="bg-white border border-slate-200 rounded-2xl p-4 hover:border-role-wali/30 hover:shadow-sm transition cursor-pointer"
          @click="openDetail(row)"
        >
          <div class="flex items-center gap-3">
            <InitialsAvatar
              :name="row.student.name || '?'"
              :size="48"
              :border-radius="14"
              color="#7C3AED"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[14px] font-black text-slate-900 truncate">
                {{ row.student.name }}
              </p>
              <p class="text-[12px] text-slate-500 mt-0.5">
                <template v-if="row.student.student_number">
                  {{ t('wali.sekolah.reportCard.studentId') }} {{ row.student.student_number }}
                </template>
                <template v-if="row.student.class_name">
                  · {{ row.student.class_name }}
                </template>
              </p>
              <div class="flex items-center gap-1 flex-wrap mt-1.5">
                <span
                  class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full border uppercase tracking-wider"
                  :class="[
                    STATUS_TONES[row.reportCard.status].bg,
                    STATUS_TONES[row.reportCard.status].text,
                    STATUS_TONES[row.reportCard.status].border,
                  ]"
                >
                  {{ STATUS_LABELS[row.reportCard.status] }}
                </span>
                <span
                  v-if="row.rank !== null && row.total_in_class !== null"
                  class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full bg-violet-100 text-violet-700 uppercase tracking-wider"
                >
                  {{ t('parent.reportCards.badgeRank', { rank: row.rank, total: row.total_in_class }) }}
                </span>
                <span
                  v-if="row.average_score !== null"
                  class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700 uppercase tracking-wider"
                >
                  {{ t('parent.reportCards.badgeAvg', { avg: row.average_score }) }}
                </span>
              </div>
            </div>
            <NavIcon
              name="chevron-right"
              :size="14"
              class="text-slate-400 flex-shrink-0"
            />
          </div>
          <div class="grid grid-cols-2 gap-2 mt-3 pt-3 border-t border-slate-100">
            <Button
              variant="secondary"
              size="sm"
              block
              @click.stop="openDetail(row)"
            >
              <NavIcon name="file-text" :size="12" />
              {{ t('parent.reportCards.btnViewDetail') }}
            </Button>
            <Button
              variant="primary"
              size="sm"
              block
              :loading="isPrintingFor === row.student_class_id"
              :disabled="isPrintingFor === row.student_class_id"
              @click.stop="downloadPdf(row)"
            >
              <NavIcon name="download" :size="12" />
              {{ t('parent.reportCards.btnPrintPdf') }}
            </Button>
          </div>
        </article>
      </div>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />

    <!-- Filter sheet (Semester picker — mirrors mobile ShowFilterSheet) -->
    <Modal v-if="filterOpen" :title="t('parent.reportCards.modalTitle')" @close="filterOpen = false">
      <div class="space-y-3">
        <p class="text-[12px] font-bold uppercase tracking-widest text-slate-500">
          {{ t('parent.reportCards.semesterLabel') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in [
              { id: '1' as SemesterId, label: t('parent.reportCards.semester1Full') },
              { id: '2' as SemesterId, label: t('parent.reportCards.semester2Full') },
            ]"
            :key="opt.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border"
            :class="
              semester === opt.id
                ? 'bg-role-wali text-white border-role-wali'
                : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40'
            "
            @click="pickSemester(opt.id)"
          >
            {{ opt.label }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
