<!--
  ParentReportCardDetailView.vue — full E-Raport for one child.

  Web port of Flutter's `parent_report_card_detail_screen.dart`.
  Route: /parent/report-cards/:studentClassId

  Sections (per the mobile Frame):
    1. Back chevron + sticky header download icon
    2. ParentPageHeader (wali) — kicker, title "Rapor {nama}",
       status pill in #actions
    3. Hero chip row (Kelas · Sem · UTS/UAS toggles)
    4. KPI overlap card (Rata-rata · Peringkat · Kehadiran)
    5. Sikap (Spiritual + Sosial) with "Wali kelas" trailing
    6. Nilai per mata pelajaran — per-subject ParentRaporSubjectCard
       (tap → Deskripsi sheet)
    7. Ekstrakurikuler (auto-hidden when empty)
    8. Prestasi (auto-hidden when empty)
    9. Kehadiran 4-cell (Hadir / Sakit / Izin / Alpa)
   10. Catatan Wali Kelas (auto-hidden when empty)
   11. Promotion banner — Genap only; Ganjil shows a soft slate note
   12. Export note ("File PDF akan tersimpan…")
   13. Sticky bottom: Bagikan + Cetak E-Raport (wali → certificate)
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { ReportCardService } from '@/services/report-card.service';
import {
  STATUS_LABELS,
  type ParentRaportRow,
  type RaportSubject,
} from '@/types/report-card';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import ParentRaporSubjectCard from '@/components/feature/ParentRaporSubjectCard.vue';
import ParentRaporDeskripsiSheet from '@/components/feature/ParentRaporDeskripsiSheet.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const studentClassId = computed(() => String(route.params.studentClassId ?? ''));

const row = ref<ParentRaportRow | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isPrinting = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' | 'info' } | null>(null);
const detailSubject = ref<RaportSubject | null>(null);
// Visual-only filter chip — rapor payload is already UTS+UAS, so this
// just nudges a snackbar reminder. Matches mobile parity.
const assessmentFilter = ref<'uts' | 'uas' | null>(null);

// Semester carried from the list view's query string ('1' = Ganjil,
// '2' = Genap). When absent we default to the current half-year so a
// deep-link still resolves. If the first fetch returns no matching row
// we fall back to the other semester before giving up — the same
// student_class_id can live in either window.
type SemesterId = '1' | '2';
const initialSemester: SemesterId =
  String(route.query.semester ?? '') === '1' ||
  String(route.query.semester ?? '') === '2'
    ? (String(route.query.semester) as SemesterId)
    : new Date().getMonth() + 1 >= 7
      ? '1'
      : '2';

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    // Try the scoped semester first.
    let rows = await ReportCardService.parentRaports({
      semester_id: initialSemester,
    });
    let found = rows.find((r) => r.student_class_id === studentClassId.value);
    if (!found) {
      // Fall back to the other semester — handles cross-link deep-
      // links and the rare case where the URL was bookmarked under
      // the wrong window.
      const other: SemesterId = initialSemester === '1' ? '2' : '1';
      rows = await ReportCardService.parentRaports({ semester_id: other });
      found = rows.find((r) => r.student_class_id === studentClassId.value);
    }
    row.value = found ?? null;
    if (!row.value) {
      loadError.value = t('wali.sekolah.reportCardDetail.notFoundOrUnpublished');
    }
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

const isPublished = computed(
  () =>
    row.value?.reportCard.status === 'published' ||
    row.value?.reportCard.status === 'distributed',
);

const isGenap = computed(() => {
  // Canonical `semesters.name` value is `even` post-migration; we still
  // accept the legacy `genap` substring and the numeric `2` form fed in
  // from the list view's query string for back-compat.
  const raw = (row.value?.reportCard.semester ?? '').toLowerCase();
  return raw === 'even' || raw === '2' || raw.includes('genap');
});

const isNaikKelas = computed(() =>
  (row.value?.reportCard.promotion_decision ?? '')
    .toLowerCase()
    .includes('naik'),
);

const className = computed(() => row.value?.student.class_name ?? '');
const semesterLabel = computed(() => {
  // Backend may ship the canonical slug (`odd`/`even`), the legacy
  // Indonesian label (`Ganjil`/`Gasal`/`Genap`), or — when carried from
  // the list view's filter — a numeric id (`1`/`2`). Accept all three.
  const raw = (row.value?.reportCard.semester ?? '').toLowerCase();
  if (raw === 'even' || raw === '2' || raw.includes('genap')) return t('wali.sekolah.reportCardDetail.semGenapShort');
  if (raw === 'odd' || raw === '1' || raw.includes('ganjil') || raw.includes('gasal')) return t('wali.sekolah.reportCardDetail.semGanjilShort');
  return row.value?.reportCard.semester || t('wali.sekolah.reportCardDetail.semesterFallback');
});
const academicYear = computed(() => row.value?.reportCard.academic_year ?? '');

const publishedAt = computed(() => row.value?.reportCard.published_at ?? null);
const publishedLabel = computed(() => {
  if (!publishedAt.value) return null;
  const d = new Date(publishedAt.value);
  if (!Number.isFinite(d.getTime())) return null;
  const MONTHS = [
    t('wali.sekolah.reportCardDetail.monthShortJan'),
    t('wali.sekolah.reportCardDetail.monthShortFeb'),
    t('wali.sekolah.reportCardDetail.monthShortMar'),
    t('wali.sekolah.reportCardDetail.monthShortApr'),
    t('wali.sekolah.reportCardDetail.monthShortMay'),
    t('wali.sekolah.reportCardDetail.monthShortJun'),
    t('wali.sekolah.reportCardDetail.monthShortJul'),
    t('wali.sekolah.reportCardDetail.monthShortAug'),
    t('wali.sekolah.reportCardDetail.monthShortSep'),
    t('wali.sekolah.reportCardDetail.monthShortOct'),
    t('wali.sekolah.reportCardDetail.monthShortNov'),
    t('wali.sekolah.reportCardDetail.monthShortDec'),
  ];
  return `${t('wali.sekolah.reportCardDetail.publishedPrefix')} · ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
});

const attendanceTotal = computed(() => {
  if (!row.value) return 0;
  const r = row.value.reportCard;
  const present = Number(r.attendance_present ?? 0);
  const sick = Number(r.attendance_sick ?? 0);
  const permit = Number(r.attendance_permit ?? 0);
  const absent = Number(r.attendance_absent ?? 0);
  return present + sick + permit + absent;
});

async function downloadPdf(variant: 'certificate' | 'raport' = 'certificate') {
  if (!row.value || !isPublished.value) {
    toast.value = {
      message: t('reportCard.stillDraftNoPrint'),
      tone: 'info',
    };
    return;
  }
  isPrinting.value = true;
  try {
    // Scope the PDF render to the same semester the row was loaded
    // from. Falling back to '' would let the backend pick "current"
    // and could mismatch the visible rapor.
    const args = {
      student_class_id: row.value.student_class_id,
      academic_year_id: '',
      semester_id: initialSemester,
      filename: `${variant === 'certificate' ? 'e-rapor' : 'rapor'}-${row.value.student.name}.pdf`,
    };
    if (variant === 'certificate') {
      await ReportCardService.exportCertificatePdf(args);
    } else {
      await ReportCardService.exportSinglePdf(args);
    }
    toast.value = { message: t('common.pdfDownloaded'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isPrinting.value = false;
  }
}

function share() {
  if (typeof window !== 'undefined' && row.value) {
    const url = window.location.href;
    if (navigator.clipboard) {
      navigator.clipboard.writeText(url).then(() => {
        toast.value = {
          message: t('reportCard.linkCopied'),
          tone: 'success',
        };
      });
    } else {
      toast.value = { message: url, tone: 'success' };
    }
  }
}

function toggleAssessment(which: 'uts' | 'uas') {
  assessmentFilter.value = assessmentFilter.value === which ? null : which;
  const label = which === 'uts' ? 'UTS' : 'UAS';
  toast.value = {
    message: t('reportCard.assessmentFilterHint', { label }),
    tone: 'info',
  };
}

function goBack() {
  router.push({ name: 'parent.report-cards' });
}

const semesterSheetOpen = ref(false);

function returnToList() {
  semesterSheetOpen.value = false;
  router.push({ name: 'parent.report-cards' });
}

const state = computed<AsyncState<ParentRaportRow>>(() => {
  if (isLoading.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (!row.value) return { status: 'empty' };
  return { status: 'content', data: row.value };
});

const heroChipLabel = computed(() => {
  if (!row.value) return semesterLabel.value;
  return className.value
    ? `${t('wali.sekolah.common.kelasPrefix')} ${className.value} · ${semesterLabel.value}${academicYear.value ? ' ' + academicYear.value : ''}`
    : semesterLabel.value;
});
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- Back -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[13px] font-bold text-slate-600 hover:text-role-wali"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('reportCard.list') }}
      </button>
    </div>

    <AsyncView :state="state" :empty-title="t('reportCard.notFound')" @retry="load">
      <template #default>
        <div v-if="row" class="space-y-4">
          <!-- HEADER -->
          <ParentPageHeader
            :kicker="t('wali.sekolah.reportCardDetail.kicker')"
            :title="t('wali.sekolah.reportCardDetail.titleWithName', { name: row.student.name })"
            :interpolate-child="false"
            :meta="
              publishedLabel ?? (row.student.student_number
                ? `${t('wali.sekolah.common.nisPrefix')} ${row.student.student_number}`
                : t('wali.sekolah.reportCardDetail.metaFallback'))
            "
          >
            <template #actions>
              <span
                class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider bg-white/15 text-white"
              >
                <span
                  class="w-1.5 h-1.5 rounded-full"
                  :class="isPublished ? 'bg-emerald-300' : 'bg-amber-300'"
                />
                {{ STATUS_LABELS[row.reportCard.status] }}
              </span>
              <button
                type="button"
                class="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-[12px] font-bold transition disabled:opacity-60"
                :disabled="!isPublished || isPrinting"
                :title="isPublished ? t('wali.sekolah.reportCardDetail.tooltipPrintPdf') : t('wali.sekolah.reportCardDetail.tooltipNotPublished')"
                @click="downloadPdf('certificate')"
              >
                <NavIcon name="download" :size="12" />
                PDF
              </button>
            </template>
          </ParentPageHeader>

          <!-- HERO CHIP ROW (Kelas · Sem + UTS/UAS toggles) -->
          <div class="flex items-center gap-2">
            <button
              type="button"
              class="flex-1 inline-flex items-center justify-between gap-1.5 px-3 py-2 rounded-xl bg-role-wali text-white text-[12px] font-bold shadow-sm shadow-role-wali/30"
              @click="semesterSheetOpen = true"
            >
              <span class="truncate">{{ heroChipLabel }}</span>
              <NavIcon name="chevron-down" :size="12" />
            </button>
            <button
              type="button"
              class="px-3 py-2 rounded-xl text-[12px] font-bold border transition"
              :class="
                assessmentFilter === 'uts'
                  ? 'bg-role-wali text-white border-role-wali shadow-sm'
                  : 'bg-white text-slate-700 border-slate-200 hover:border-role-wali/40'
              "
              @click="toggleAssessment('uts')"
            >
              UTS
            </button>
            <button
              type="button"
              class="px-3 py-2 rounded-xl text-[12px] font-bold border transition"
              :class="
                assessmentFilter === 'uas'
                  ? 'bg-role-wali text-white border-role-wali shadow-sm'
                  : 'bg-white text-slate-700 border-slate-200 hover:border-role-wali/40'
              "
              @click="toggleAssessment('uas')"
            >
              UAS
            </button>
          </div>

          <!-- HERO KPI OVERLAP -->
          <section
            class="bg-white border border-slate-200 rounded-2xl shadow-sm grid grid-cols-3 divide-x divide-slate-100"
          >
            <div class="px-3 py-3 text-center">
              <p
                class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
              >
                {{ t('wali.sekolah.reportCardDetail.kpiAverage') }}
              </p>
              <p class="text-lg font-black mt-1 text-role-wali tabular-nums">
                {{ row.average_score ?? '—' }}
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p
                class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
              >
                {{ t('wali.sekolah.reportCardDetail.kpiRank') }}
              </p>
              <p class="text-lg font-black mt-1 text-violet-700 tabular-nums">
                <template
                  v-if="row.rank !== null && row.total_in_class !== null"
                >
                  {{ row.rank
                  }}<span class="text-slate-400 text-[13px]"
                    >/{{ row.total_in_class }}</span
                  >
                </template>
                <template v-else>—</template>
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p
                class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
              >
                {{ t('wali.sekolah.reportCardDetail.kpiAttendance') }}
              </p>
              <p class="text-lg font-black mt-1 text-emerald-700 tabular-nums">
                <template v-if="row.attendance_pct !== null">
                  {{ Math.round(row.attendance_pct)
                  }}<span class="text-slate-400 text-[13px]">%</span>
                </template>
                <template v-else>—</template>
              </p>
            </div>
          </section>

          <!-- SIKAP -->
          <section>
            <header class="flex items-baseline justify-between mb-2 px-1">
              <p
                class="text-[10px] font-bold text-slate-500 uppercase tracking-widest"
              >
                {{ t('wali.sekolah.reportCardDetail.sectionAttitude') }}
              </p>
              <p class="text-[10px] font-bold text-slate-400">{{ t('wali.sekolah.reportCardDetail.homeroomTeacher') }}</p>
            </header>
            <div
              class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3"
            >
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <span class="text-[11.5px] font-bold text-slate-700">
                    {{ t('reportCard.spiritual') }}
                  </span>
                  <span
                    v-if="row.reportCard.spiritual_predicate"
                    class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-role-wali/10 text-role-wali"
                  >
                    {{ row.reportCard.spiritual_predicate }}
                  </span>
                </div>
                <p
                  class="text-[12.5px] text-slate-600 leading-relaxed whitespace-pre-wrap"
                >
                  {{ row.reportCard.spiritual_description || '—' }}
                </p>
              </div>
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <span class="text-[11.5px] font-bold text-slate-700">
                    {{ t('reportCard.social') }}
                  </span>
                  <span
                    v-if="row.reportCard.social_predicate"
                    class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-role-wali/10 text-role-wali"
                  >
                    {{ row.reportCard.social_predicate }}
                  </span>
                </div>
                <p
                  class="text-[12.5px] text-slate-600 leading-relaxed whitespace-pre-wrap"
                >
                  {{ row.reportCard.social_description || '—' }}
                </p>
              </div>
            </div>
          </section>

          <!-- NILAI PER MATA PELAJARAN -->
          <section>
            <header class="flex items-baseline justify-between mb-2 px-1">
              <p
                class="text-[10px] font-bold text-slate-500 uppercase tracking-widest"
              >
                {{ t('reportCard.gradesBySubject') }}
              </p>
              <p class="text-[10px] font-bold text-slate-400">
                {{ row.reportCard.subjects.length }} {{ t('common.subjects') }}
              </p>
            </header>
            <div class="space-y-2">
              <ParentRaporSubjectCard
                v-for="s in row.reportCard.subjects"
                :key="s.subject_id"
                :subject="s"
                @open="detailSubject = $event"
              />
              <p
                v-if="row.reportCard.subjects.length === 0"
                class="text-[13px] text-slate-500 italic text-center py-4"
              >
                {{ t('reportCard.noSubjectGrades') }}
              </p>
            </div>
          </section>

          <!-- EKSTRAKURIKULER -->
          <section v-if="row.reportCard.extras.length > 0">
            <header class="flex items-baseline justify-between mb-2 px-1">
              <p
                class="text-[10px] font-bold text-slate-500 uppercase tracking-widest"
              >
                {{ t('reportCard.extracurricular') }}
              </p>
              <p class="text-[10px] font-bold text-slate-400">
                {{ row.reportCard.extras.length }} {{ t('common.activities') }}
              </p>
            </header>
            <div class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
              <div
                v-for="(e, idx) in row.reportCard.extras"
                :key="idx"
                class="flex items-center gap-2 text-[12.5px]"
              >
                <span
                  class="w-1.5 h-1.5 rounded-full bg-slate-400 flex-shrink-0"
                />
                <span class="font-semibold text-slate-900 flex-1 min-w-0 truncate">
                  {{ e.name }}
                </span>
                <span
                  v-if="e.score"
                  class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-role-wali/10 text-role-wali"
                >
                  {{ e.score }}
                </span>
              </div>
            </div>
          </section>

          <!-- PRESTASI -->
          <section v-if="row.reportCard.achievements.length > 0">
            <header class="flex items-baseline justify-between mb-2 px-1">
              <p
                class="text-[10px] font-bold text-slate-500 uppercase tracking-widest"
              >
                {{ t('reportCard.achievements') }}
              </p>
              <p class="text-[10px] font-bold text-slate-400">
                {{ row.reportCard.achievements.length }} {{ t('reportCard.achievementsPlural') }}
              </p>
            </header>
            <div class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
              <div
                v-for="(a, idx) in row.reportCard.achievements"
                :key="idx"
                class="flex items-start gap-2 text-[12.5px]"
              >
                <span
                  class="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0 mt-2"
                />
                <div class="flex-1 min-w-0">
                  <p class="font-semibold text-slate-900">{{ a.name }}</p>
                  <p
                    v-if="a.type || a.description"
                    class="text-[12px] text-slate-500 mt-0.5"
                  >
                    <template v-if="a.type">{{ a.type }}</template>
                    <template v-if="a.type && a.description"> · </template>
                    <template v-if="a.description">{{ a.description }}</template>
                  </p>
                </div>
              </div>
            </div>
          </section>

          <!-- KEHADIRAN 4-cell -->
          <section>
            <header class="flex items-baseline justify-between mb-2 px-1">
              <p
                class="text-[10px] font-bold text-slate-500 uppercase tracking-widest"
              >
                {{ t('nav.attendance') }}
              </p>
              <p class="text-[10px] font-bold text-slate-400">
                {{ attendanceTotal > 0 ? `${attendanceTotal} ${t('attendance.effectiveDays')}` : t('common.notCalculated') }}
              </p>
            </header>
            <div class="grid grid-cols-4 gap-2">
              <div
                class="bg-white border border-slate-200 rounded-2xl p-3 text-center"
              >
                <p
                  class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
                >
                  {{ t('attendance.present') }}
                </p>
                <p class="text-base font-black mt-1 tabular-nums text-emerald-700">
                  {{ row.reportCard.attendance_present ?? 0 }}
                </p>
              </div>
              <div
                class="bg-white border border-slate-200 rounded-2xl p-3 text-center"
              >
                <p
                  class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
                >
                  {{ t('attendance.sick') }}
                </p>
                <p class="text-base font-black mt-1 tabular-nums text-orange-700">
                  {{ row.reportCard.attendance_sick ?? 0 }}
                </p>
              </div>
              <div
                class="bg-white border border-slate-200 rounded-2xl p-3 text-center"
              >
                <p
                  class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
                >
                  {{ t('attendance.permitted') }}
                </p>
                <p class="text-base font-black mt-1 tabular-nums text-blue-700">
                  {{ row.reportCard.attendance_permit ?? 0 }}
                </p>
              </div>
              <div
                class="bg-white border border-slate-200 rounded-2xl p-3 text-center"
              >
                <p
                  class="text-[9px] font-bold text-slate-400 uppercase tracking-widest"
                >
                  {{ t('attendance.absent') }}
                </p>
                <p class="text-base font-black mt-1 tabular-nums text-red-700">
                  {{ row.reportCard.attendance_absent ?? 0 }}
                </p>
              </div>
            </div>
          </section>

          <!-- CATATAN WALI KELAS -->
          <section v-if="row.reportCard.homeroom_notes">
            <header class="flex items-baseline justify-between mb-2 px-1">
              <p
                class="text-[10px] font-bold text-slate-500 uppercase tracking-widest"
              >
                {{ t('reportCard.homeRoomNotes') }}
              </p>
              <p
                v-if="row.reportCard.homeroom_teacher"
                class="text-[10px] font-bold text-slate-400 truncate max-w-[50%]"
              >
                {{ row.reportCard.homeroom_teacher }}
              </p>
            </header>
            <div
              class="bg-white border border-slate-200 rounded-2xl p-4 border-l-[3px] border-l-role-wali"
            >
              <p
                class="text-[12.5px] text-slate-700 leading-relaxed whitespace-pre-wrap"
              >
                {{ row.reportCard.homeroom_notes }}
              </p>
            </div>
          </section>

          <!-- PROMOTION BANNER (Genap only) -->
          <section
            v-if="isGenap && row.reportCard.promotion_decision"
            class="rounded-2xl p-4 border-l-4"
            :class="
              isNaikKelas
                ? 'bg-emerald-50 border-emerald-500'
                : 'bg-red-50 border-red-500'
            "
          >
            <p
              class="text-[10px] font-bold uppercase tracking-widest mb-1"
              :class="isNaikKelas ? 'text-emerald-700' : 'text-red-700'"
            >
              {{ t('reportCard.promotionDecision') }}
            </p>
            <p
              class="text-[14px] font-black"
              :class="isNaikKelas ? 'text-emerald-900' : 'text-red-900'"
            >
              {{ row.reportCard.promotion_decision }}
            </p>
          </section>
          <section
            v-else-if="!isGenap"
            class="rounded-2xl p-4 bg-slate-50 border border-slate-200"
          >
            <p class="text-[11.5px] text-slate-600 leading-relaxed">
              {{ t('reportCard.promotionAnnouncementLater') }}
              <strong>{{ t('common.semesterGenap') }}</strong>.
            </p>
          </section>

          <!-- EXPORT NOTE -->
          <p class="text-[10.5px] text-slate-400 italic px-1 leading-relaxed">
            {{ t('reportCard.pdfExportNote') }}
            <em>{{ t('common.published') }}</em> {{ t('wali.sekolah.reportCardDetail.exportNoteSuffix') }}
          </p>

          <!-- STICKY FOOTER -->
          <div
            class="grid grid-cols-2 gap-2 sticky bottom-2 bg-white/95 backdrop-blur rounded-2xl border border-slate-200 px-3 py-2 shadow-lg"
          >
            <Button variant="secondary" block @click="share">
              <NavIcon name="send" :size="13" />
              {{ t('common.share') }}
            </Button>
            <Button
              variant="primary"
              block
              :loading="isPrinting"
              :disabled="isPrinting || !isPublished"
              @click="downloadPdf('certificate')"
            >
              <NavIcon name="download" :size="13" />
              {{ isPublished ? t('reportCard.printEReport') : t('common.notPublished') }}
            </Button>
          </div>
        </div>
      </template>
    </AsyncView>

    <!-- Per-subject deskripsi sheet -->
    <ParentRaporDeskripsiSheet
      v-if="detailSubject"
      :subject="detailSubject"
      @close="detailSubject = null"
    />

    <!-- Semester sheet (mirrors mobile — confirms back to list to change sem) -->
    <Modal v-if="semesterSheetOpen" :title="t('common.chooseSemester')" @close="semesterSheetOpen = false">
      <div class="space-y-3">
        <p class="text-[13px] text-slate-600 leading-relaxed">
          {{ t('reportCard.chooseOtherSemesterNote') }}
          <strong>{{ t('reportCard.eReportList') }}</strong> {{ t('wali.sekolah.reportCardDetail.chooseSemesterNoteSuffix') }}
        </p>
        <Button block @click="returnToList">{{ t('reportCard.backToList') }}</Button>
      </div>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone === 'info' ? 'success' : toast.tone"
      @close="toast = null"
    />
  </div>
</template>
