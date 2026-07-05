<!--
  AdminReportCardDetailView.vue — admin view student report card detail.

  Web port of parent_report_card_detail_screen.dart (with userRole = 'admin').
  Route entry:
    /admin/report-cards/class/:classId/student/:studentClassId
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAcademicYearStore } from '@/stores/academic-year';
import { ReportCardService } from '@/services/report-card.service';
import {
  STATUS_LABELS,
  STATUS_TONES,
  type ReportCardDetail,
  type ReportCardStatus,
} from '@/types/report-card';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import BackButton from '@/components/ui/BackButton.vue';

const route = useRoute();
const router = useRouter();
const academic = useAcademicYearStore();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));
const studentClassId = computed(() => String(route.params.studentClassId ?? ''));

const detail = ref<ReportCardDetail | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isPrinting = ref(false);
const showPrintModal = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

async function load() {
  isLoading.value = true;
  loadError.value = null;
  const ayId = academic.selectedYearId ?? '';
  if (!studentClassId.value || !ayId) {
    loadError.value = t('admin.sekolah.report_card_detail.err_context');
    isLoading.value = false;
    return;
  }
  try {
    const [detailRes, seedRes] = await Promise.all([
      ReportCardService.getDetail({
        student_class_id: studentClassId.value,
        academic_year_id: ayId,
      }),
      ReportCardService.getInitialData({
        student_class_id: studentClassId.value,
        academic_year_id: ayId,
      }),
    ]);
    
    let res = detailRes;
    if (!res) {
      if (seedRes) {
        // No saved raport yet — build the preview template from seed.
        res = {
          student_class_id: seedRes.student_class_id,
          student_id: seedRes.student_id,
          student_name: seedRes.student_name,
          class_name: seedRes.class_name,
          academic_year: seedRes.academic_year,
          semester: seedRes.semester,
          status: 'draft',
          subjects: seedRes.subjects,
          extras: [],
          achievements: [],
          attendance_sick: seedRes.attendance_sick ?? 0,
          attendance_permit: seedRes.attendance_permit ?? 0,
          attendance_absent: seedRes.attendance_absent ?? 0,
          spiritual_predicate: 'good',
          social_predicate: 'good',
          promotion_decision: 'promoted',
          summary: seedRes.summary,
        };
      }
    } else if (seedRes) {
      // Merge values
      res = {
        ...res,
        student_name: res.student_name || seedRes.student_name,
        class_name: res.class_name || seedRes.class_name,
        academic_year: res.academic_year || seedRes.academic_year || null,
        semester: res.semester || seedRes.semester || null,
        subjects: res.subjects.length > 0 ? res.subjects : seedRes.subjects,
        summary: res.summary ?? seedRes.summary,
      };
    }
    
    if (!res) {
      loadError.value = t('admin.sekolah.report_card_detail.err_no_data');
      return;
    }
    detail.value = res;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
watch(() => academic.selectedYearId, () => load());

// ── Derived ──
const studentName = computed(() => detail.value?.student_name ?? t('admin.sekolah.report_card_detail.fallback_student'));
const className = computed(() => detail.value?.class_name ?? '—');
const kicker = computed(() => t('admin.sekolah.report_card_detail.kicker', { className: className.value }));
const status = computed<ReportCardStatus>(() => detail.value?.status ?? 'draft');
const isPublished = computed(() => status.value === 'published' || status.value === 'distributed');
const statusTone = computed(() => STATUS_TONES[status.value]);
const statusLabel = computed(() => STATUS_LABELS[status.value]);

const headerMeta = computed(() => {
  const sem = detail.value?.semester ?? '';
  const tp = detail.value?.academic_year ?? '';
  const parts: string[] = [];
  if (tp) parts.push(t('admin.sekolah.report_card_detail.tp_label', { tp }));
  if (sem) parts.push(t('admin.sekolah.report_card_detail.sem_label', { sem }));
  return parts.join(' · ');
});

const averageScore = computed(() => {
  return detail.value?.summary?.rerata ?? detail.value?.avg_grade ?? '—';
});

const classRank = computed(() => {
  return detail.value?.summary?.class_rank ?? null;
});

const totalInClass = computed(() => {
  return detail.value?.summary?.class_total ?? null;
});

const attendancePct = computed(() => {
  const absent = detail.value?.attendance_absent ?? 0;
  const schoolDays = 80;
  return Math.max(0, Math.round(((schoolDays - absent) / schoolDays) * 100));
});

// Canonical `semesters.name` is `even` post-migration; defensive read
// for legacy `genap` rows still in the wild.
const isGenap = computed(() => {
  const raw = (detail.value?.semester ?? '').toLowerCase();
  return raw === 'even' || raw.includes('genap');
});
const isNaikKelas = computed(() => (detail.value?.promotion_decision ?? '').toLowerCase().includes('naik'));

const totalAttendance = computed(() => {
  const sick = detail.value?.attendance_sick ?? 0;
  const permit = detail.value?.attendance_permit ?? 0;
  const absent = detail.value?.attendance_absent ?? 0;
  return sick + permit + absent;
});

function goBack() {
  router.push({
    name: 'admin.report-cards.class',
    params: { classId: classId.value },
  });
}

// ── PDF Cetak actions ──
async function downloadFormatGuru() {
  if (!detail.value) return;
  showPrintModal.value = false;
  isPrinting.value = true;
  try {
    await ReportCardService.exportSinglePdf({
      student_class_id: studentClassId.value,
      filename: `rapor-${studentName.value}.pdf`
    });
    toast.value = { message: t('admin.sekolah.report_card_detail.toast_pdf_teacher'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isPrinting.value = false;
  }
}

async function downloadFormatWali() {
  if (!detail.value) return;
  showPrintModal.value = false;
  isPrinting.value = true;
  try {
    await ReportCardService.exportCertificatePdf({
      student_class_id: studentClassId.value,
      filename: `sertifikat-${studentName.value}.pdf`
    });
    toast.value = { message: t('admin.sekolah.report_card_detail.toast_pdf_parent'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isPrinting.value = false;
  }
}

function handlePrintAction() {
  if (!isPublished.value) {
    toast.value = { message: t('admin.sekolah.report_card_detail.toast_draft_unavailable'), tone: 'error' };
    return;
  }
  showPrintModal.value = true;
}

const state = computed<AsyncState<ReportCardDetail>>(() => {
  if (isLoading.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (!detail.value) return { status: 'empty' };
  return { status: 'content', data: detail.value };
});
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- BACK -->
    <div class="flex items-center gap-2">
      <BackButton :label="t('admin.sekolah.report_card_detail.back_to_list')" @click="goBack" />
    </div>

    <AsyncView :state="state" :empty-title="t('admin.sekolah.report_card_detail.empty_title')" @retry="load">
      <template #default>
        <div v-if="detail" class="space-y-4">
          <!-- HEADER -->
          <BrandPageHeader
            role="admin"
            :kicker="kicker"
            :title="t('admin.sekolah.report_card_detail.header_title', { name: studentName })"
            :meta="detail.student_id ? t('admin.sekolah.report_card_detail.nis_label', { nis: detail.student_id }) : t('admin.sekolah.report_card_detail.no_nis')"
            :live-dot="false"
          >
            <span
              class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider border"
              :class="[
                statusTone.bg,
                statusTone.text,
                statusTone.border,
              ]"
            >
              <span class="w-1.5 h-1.5 rounded-full animate-pulse" :class="statusTone.dot" />
              {{ statusLabel }}
            </span>

            <button
              type="button"
              class="w-9 h-9 rounded-full flex items-center justify-center bg-white/10 border border-white/20 text-white hover:bg-white/20 transition flex-shrink-0"
              :class="{ 'opacity-50 cursor-not-allowed': !isPublished }"
              @click="handlePrintAction"
            >
              <NavIcon name="download" :size="15" />
            </button>
          </BrandPageHeader>

          <!-- HERO KPI OVERLAP -->
          <section class="bg-white border border-slate-200 rounded-2xl shadow-sm grid grid-cols-3 divide-x divide-slate-100">
            <div class="px-3 py-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                {{ t('admin.sekolah.report_card_detail.kpi_average') }}
              </p>
              <p class="text-lg font-black mt-1 text-[#143068] tabular-nums">
                {{ averageScore }}
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                Peringkat
              </p>
              <p class="text-lg font-black mt-1 text-violet-700 tabular-nums">
                <template v-if="classRank !== null && totalInClass !== null">
                  {{ classRank }}<span class="text-slate-400 text-[12px]">/{{ totalInClass }}</span>
                </template>
                <template v-else>—</template>
              </p>
            </div>
            <div class="px-3 py-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                Kehadiran
              </p>
              <p class="text-lg font-black mt-1 text-emerald-700 tabular-nums">
                {{ attendancePct }}<span class="text-slate-400 text-[12px]">%</span>
              </p>
            </div>
          </section>

          <!-- SIKAP -->
          <section class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
            <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Sikap
            </p>
            <div class="space-y-2">
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <span class="text-[11.5px] font-bold text-slate-700">
                    Spiritual
                  </span>
                  <span
                    v-if="detail.spiritual_predicate"
                    class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#143068]/10 text-[#143068]"
                  >
                    {{ detail.spiritual_predicate }}
                  </span>
                </div>
                <p class="text-[12.5px] text-slate-600 leading-relaxed whitespace-pre-wrap">
                  {{ detail.spiritual_description || '—' }}
                </p>
              </div>
              <div class="border-t border-slate-100 pt-2">
                <div class="flex items-center gap-2 mb-1">
                  <span class="text-[11.5px] font-bold text-slate-700">
                    Sosial
                  </span>
                  <span
                    v-if="detail.social_predicate"
                    class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#143068]/10 text-[#143068]"
                  >
                    {{ detail.social_predicate }}
                  </span>
                </div>
                <p class="text-[12.5px] text-slate-600 leading-relaxed whitespace-pre-wrap">
                  {{ detail.social_description || '—' }}
                </p>
              </div>
            </div>
          </section>

          <!-- PER-SUBJECT NILAI -->
          <section v-if="detail.subjects.length > 0" class="space-y-2">
            <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest px-1">
              Nilai Per Mata Pelajaran
            </p>
            <article
              v-for="s in detail.subjects"
              :key="s.subject_id"
              class="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm"
            >
              <div class="flex items-center gap-2">
                <p class="text-[13px] font-bold text-slate-900 flex-1 min-w-0 truncate">
                  {{ s.subject_name }}
                </p>
                <span
                  class="text-[14px] font-black tabular-nums"
                  :class="
                    Number(s.knowledge_score ?? 0) >= (s.kkm ?? 75)
                      ? 'text-emerald-700'
                      : 'text-red-700'
                  "
                >
                  {{ s.knowledge_score ?? '—' }}
                </span>
                <span class="text-[10px] text-slate-400 tabular-nums">
                  / KKM {{ s.kkm ?? 75 }}
                </span>
              </div>
              <p
                v-if="s.knowledge_description"
                class="text-[12px] text-slate-600 leading-relaxed mt-1.5"
              >
                {{ s.knowledge_description }}
              </p>
              <div class="mt-1.5 flex items-center gap-2 flex-wrap">
                <span
                  v-if="s.knowledge_predicate"
                  class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-600"
                >
                  Predikat {{ s.knowledge_predicate }}
                </span>
                <span
                  v-if="Number(s.knowledge_score ?? 0) < (s.kkm ?? 75) && Number(s.knowledge_score ?? 0) > 0"
                  class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-700"
                >
                  Belum tuntas
                </span>
                <span
                  v-else-if="Number(s.knowledge_score ?? 0) >= (s.kkm ?? 75)"
                  class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700"
                >
                  Tuntas
                </span>
              </div>
            </article>
          </section>

          <!-- EKSTRAKURIKULER -->
          <section
            v-if="detail.extras.length > 0"
            class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2"
          >
            <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Ekstrakurikuler
            </p>
            <div
              v-for="(e, idx) in detail.extras"
              :key="idx"
              class="flex items-center gap-2 text-[12.5px]"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-slate-400 flex-shrink-0" />
              <span class="font-semibold text-slate-900 flex-1 min-w-0 truncate">
                {{ e.name }}
              </span>
              <span
                v-if="e.score"
                class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#143068]/10 text-[#143068]"
              >
                {{ e.score }}
              </span>
            </div>
          </section>

          <!-- PRESTASI -->
          <section
            v-if="detail.achievements.length > 0"
            class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2"
          >
            <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Prestasi
            </p>
            <div
              v-for="(a, idx) in detail.achievements"
              :key="idx"
              class="flex items-start gap-2 text-[12.5px]"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0 mt-2" />
              <div class="flex-1 min-w-0">
                <p class="font-semibold text-slate-900">{{ a.name }}</p>
                <p
                  v-if="a.type || a.description"
                  class="text-[11px] text-slate-500 mt-0.5"
                >
                  <template v-if="a.type">{{ a.type }}</template>
                  <template v-if="a.type && a.description"> · </template>
                  <template v-if="a.description">{{ a.description }}</template>
                </p>
              </div>
            </div>
          </section>

          <!-- KEHADIRAN 4-cell -->
          <section class="grid grid-cols-4 gap-2">
            <div class="bg-white border border-slate-200 rounded-2xl p-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                Sakit
              </p>
              <p class="text-base font-black mt-1 tabular-nums text-slate-700">
                {{ detail.attendance_sick ?? 0 }}
              </p>
            </div>
            <div class="bg-white border border-slate-200 rounded-2xl p-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                Izin
              </p>
              <p class="text-base font-black mt-1 tabular-nums text-slate-700">
                {{ detail.attendance_permit ?? 0 }}
              </p>
            </div>
            <div class="bg-white border border-slate-200 rounded-2xl p-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                Alpa
              </p>
              <p class="text-base font-black mt-1 tabular-nums text-red-700">
                {{ detail.attendance_absent ?? 0 }}
              </p>
            </div>
            <div class="bg-white border border-slate-200 rounded-2xl p-3 text-center">
              <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest">
                Total
              </p>
              <p class="text-base font-black mt-1 tabular-nums text-slate-900">
                {{ totalAttendance }}
              </p>
            </div>
          </section>

          <!-- CATATAN WALI -->
          <section
            v-if="detail.homeroom_notes"
            class="bg-white border border-slate-200 rounded-2xl p-4 space-y-1.5"
          >
            <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Catatan Wali Kelas
            </p>
            <p class="text-[12.5px] text-slate-700 leading-relaxed whitespace-pre-wrap">
              {{ detail.homeroom_notes }}
            </p>
          </section>

          <!-- PROMOTION BANNER -->
          <section
            v-if="isGenap"
            class="rounded-2xl p-4 border-l-4 shadow-sm"
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
              Keputusan Kenaikan Kelas
            </p>
            <p
              class="text-[14px] font-black"
              :class="isNaikKelas ? 'text-emerald-900' : 'text-red-900'"
            >
              {{ detail.promotion_decision }}
            </p>
          </section>
          <section
            v-else
            class="rounded-2xl p-4 bg-slate-50 border border-slate-200"
          >
            <p class="text-[11.5px] text-slate-600 leading-relaxed">
              Keputusan kenaikan kelas akan ditentukan di akhir
              <strong>Semester Genap</strong>.
            </p>
          </section>

          <!-- STICKY FOOTER -->
          <div class="grid grid-cols-2 gap-2 sticky bottom-2 bg-white/95 backdrop-blur rounded-2xl border border-slate-200 px-3 py-2 shadow-lg">
            <Button variant="secondary" block @click="goBack">
              <NavIcon name="chevron-left" :size="13" />
              {{ t('admin.sekolah.report_card_detail.back') }}
            </Button>
            <Button
              variant="primary"
              block
              :loading="isPrinting"
              :disabled="isPrinting || !isPublished"
              class="bg-[#143068] text-white hover:bg-[#143068]/95"
              @click="handlePrintAction"
            >
              <NavIcon name="download" :size="13" />
              {{ isPublished ? t('admin.sekolah.report_card_detail.print_pdf') : t('admin.sekolah.report_card_detail.not_published') }}
            </Button>
          </div>
        </div>
      </template>
    </AsyncView>

    <!-- PDF FORMAT CHOOSER SHEET/MODAL (Matches Flutter) -->
    <Modal
      v-slot:default
      v-if="showPrintModal"
      :title="t('admin.sekolah.report_card_detail.pick_pdf_title')"
      :subtitle="t('admin.sekolah.report_card_detail.pick_pdf_subtitle')"
      size="sm"
      @close="showPrintModal = false"
    >
      <div class="space-y-3">
        <!-- Choice 1: Format Teacher -->
        <button
          type="button"
          class="w-full text-left p-3 rounded-2xl border border-blue-200 bg-blue-50/20 hover:bg-blue-50/40 transition flex items-center gap-3"
          @click="downloadFormatGuru"
        >
          <div class="w-10 h-10 rounded-xl bg-blue-100 flex items-center justify-center text-[#143068] flex-shrink-0">
            <NavIcon name="file-text" :size="20" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[13.5px] font-black text-slate-900">{{ t('admin.sekolah.report_card_detail.format_teacher_title') }}</p>
            <p class="text-[11px] text-slate-500 mt-1 leading-normal">
              {{ t('admin.sekolah.report_card_detail.format_teacher_desc') }}
            </p>
          </div>
          <NavIcon name="chevron-right" :size="18" class="text-slate-400" />
        </button>

        <!-- Choice 2: Format Parent -->
        <button
          type="button"
          class="w-full text-left p-3 rounded-2xl border border-purple-200 bg-purple-50/20 hover:bg-purple-50/40 transition flex items-center gap-3"
          @click="downloadFormatWali"
        >
          <div class="w-10 h-10 rounded-xl bg-purple-100 flex items-center justify-center text-purple-700 flex-shrink-0">
            <NavIcon name="sparkles" :size="20" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[13.5px] font-black text-slate-900">{{ t('admin.sekolah.report_card_detail.format_parent_title') }}</p>
            <p class="text-[11px] text-slate-500 mt-1 leading-normal">
              {{ t('admin.sekolah.report_card_detail.format_parent_desc') }}
            </p>
          </div>
          <NavIcon name="chevron-right" :size="18" class="text-slate-400" />
        </button>
      </div>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
