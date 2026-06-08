<!--
  TeacherReportCardDetailView.vue — Rapor edit (Frame C).

  Web port of `report_card_detail_screen.dart`. Route entry:
    /teacher/report-cards/kelas/:classId/siswa/:studentClassId

  Layout:
    1. Back chevron row + sticky Simpan/Finalisasi actions
    2. BrandPageHeader (guru) — kicker class+student NIS,
       title student name, meta status pill + class context
    3. 4-tab segmented switcher: Sikap / Nilai / Tambahan / Info
       - Sikap     — spiritual + social: predicate chips + desc
       - Nilai     — per-subject score + predicate + description
       - Tambahan  — ekstrakurikuler + prestasi (add/remove rows)
       - Info      — attendance + homeroom notes + promotion
    4. Sticky footer (Simpan Draf / Finalisasi)
       Edit locked when status is final / published / distributed

  Endpoints:
    GET  /raport/show          — hydrated detail
    GET  /raport/initial-data  — seed when no raport yet
    POST /raport               — upsert (canonical attendance keys)
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAcademicYearStore } from '@/stores/academic-year';
import { ReportCardService } from '@/services/report-card.service';
import {
  DECISION_OPTIONS,
  PREDICATE_OPTIONS,
  STATUS_LABELS,
  STATUS_TONES,
  type RaportAchievement,
  type RaportExtra,
  type RaportSubject,
  type ReportCardDetail,
  type ReportCardStatus,
} from '@/types/report-card';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';

const route = useRoute();
const router = useRouter();
const academic = useAcademicYearStore();

const classId = computed(() => String(route.params.classId ?? ''));
const studentClassId = computed(() => String(route.params.studentClassId ?? ''));

// Map canonical English predicate values to Indonesian display labels.
function predicateLabel(p: string): string {
  switch (p) {
    case 'very_good': return 'Sangat Baik';
    case 'good':      return 'Baik';
    case 'fair':      return 'Cukup';
    case 'poor':      return 'Kurang';
    default:          return p;
  }
}

// ── Tab state ──
type TabKey = 'sikap' | 'nilai' | 'tambahan' | 'info';
const activeTab = ref<TabKey>('sikap');
const tabs: { key: TabKey; label: string }[] = [
  { key: 'sikap', label: 'Sikap' },
  { key: 'nilai', label: 'Nilai' },
  { key: 'tambahan', label: 'Tambahan' },
  { key: 'info', label: 'Info' },
];

// ── Data state ──
const original = ref<ReportCardDetail | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isSaving = ref(false);
const confirmFinalize = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Editable form ──
const form = reactive<{
  spiritual_predicate: string;
  spiritual_description: string;
  social_predicate: string;
  social_description: string;
  subjects: RaportSubject[];
  extras: RaportExtra[];
  achievements: RaportAchievement[];
  attendance_sick: number;
  attendance_permit: number;
  attendance_absent: number;
  homeroom_notes: string;
  promotion_decision: string;
}>({
  spiritual_predicate: 'good',
  spiritual_description: '',
  social_predicate: 'good',
  social_description: '',
  subjects: [],
  extras: [],
  achievements: [],
  attendance_sick: 0,
  attendance_permit: 0,
  attendance_absent: 0,
  homeroom_notes: '',
  promotion_decision: 'promoted',
});

// ── Loader ──
async function load() {
  isLoading.value = true;
  loadError.value = null;
  const ayId = academic.selectedYearId ?? '';
  // Backend needs a semester id too — fall back to the active year's
  // active semester when available.
  const semId = academic.activeYear?.id ?? '';
  if (!studentClassId.value || !ayId) {
    loadError.value = 'Konteks rapor (siswa / TP) belum lengkap.';
    isLoading.value = false;
    return;
  }
  try {
    // Fetch BOTH the saved raport AND the initial-data scaffold in
    // parallel. Reasoning:
    //  1. `/raport/show` may return a saved draft with empty
    //     `raportSubjects` (teacher saved without filling the Nilai
    //     tab). Falling back ONLY when detail is null would miss
    //     this case — the form would render "0 mata pelajaran"
    //     forever. Always pull initial-data so we can seed the
    //     curriculum subject list when the saved row has none.
    //  2. `/raport/show` doesn't eager-load student/class names, so
    //     we lift those from initial-data either way.
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
    let detail = detailRes;
    if (!detail) {
      if (seedRes) {
        // No saved raport yet — build the form from the seed.
        detail = {
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
      // Merge — saved values win, seed fills the gaps:
      //  - identity (student_name, class_name) when /raport/show
      //    didn't ship them
      //  - subjects when the saved draft has none yet (curriculum
      //    list comes from seed.subjects)
      detail = {
        ...detail,
        student_name: detail.student_name || seedRes.student_name,
        class_name: detail.class_name || seedRes.class_name,
        academic_year: detail.academic_year || seedRes.academic_year || null,
        semester: detail.semester || seedRes.semester || null,
        subjects:
          detail.subjects.length > 0 ? detail.subjects : seedRes.subjects,
        summary: detail.summary ?? seedRes.summary,
      };
    }
    if (!detail) {
      loadError.value = 'Rapor tidak ditemukan dan tidak ada data awal.';
      return;
    }
    original.value = detail;
    // Seed editable form. Canonical English values post-rename — the
    // service already normalises legacy Indonesian inputs on read.
    form.spiritual_predicate = detail.spiritual_predicate ?? 'good';
    form.spiritual_description = detail.spiritual_description ?? '';
    form.social_predicate = detail.social_predicate ?? 'good';
    form.social_description = detail.social_description ?? '';
    form.subjects = detail.subjects.map((s) => ({ ...s }));
    form.extras = detail.extras.map((e) => ({ ...e }));
    form.achievements = detail.achievements.map((a) => ({ ...a }));
    form.attendance_sick = detail.attendance_sick ?? 0;
    form.attendance_permit = detail.attendance_permit ?? 0;
    form.attendance_absent = detail.attendance_absent ?? 0;
    form.homeroom_notes = detail.homeroom_notes ?? '';
    form.promotion_decision = detail.promotion_decision ?? 'promoted';
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

// Re-fetch when TP / semester switches.
import { watch } from 'vue';
watch(
  () => academic.selectedYearId,
  () => load(),
);

// ── Derived ──
const status = computed<ReportCardStatus>(
  () => original.value?.status ?? 'draft',
);

const isLocked = computed(
  () =>
    status.value === 'final' ||
    status.value === 'published' ||
    status.value === 'distributed',
);

const statusTone = computed(() => STATUS_TONES[status.value]);
const statusLabel = computed(() => STATUS_LABELS[status.value]);

const headerKicker = computed(() => {
  const cls = original.value?.class_name ?? '—';
  const nis = original.value?.student_id ? '' : '';
  void nis;
  return `Kelas ${cls} · Rapor`;
});

const headerMeta = computed(() => {
  const sem = original.value?.semester ?? '';
  const tp = original.value?.academic_year ?? '';
  const parts: string[] = [];
  if (tp) parts.push(`TP ${tp}`);
  if (sem) parts.push(`Sem ${sem}`);
  return parts.join(' · ');
});

const totalAttendance = computed(
  () =>
    form.attendance_sick +
    form.attendance_permit +
    form.attendance_absent,
);

// ── Save ──
async function save(targetStatus: ReportCardStatus) {
  if (!original.value) return;
  const ayId = academic.selectedYearId ?? '';
  const semId = academic.activeYear?.id ?? '';
  if (!ayId) {
    toast.value = {
      message: 'Tahun pelajaran aktif belum dipilih.',
      tone: 'error',
    };
    return;
  }
  isSaving.value = true;
  try {
    const updated = await ReportCardService.save({
      student_class_id: studentClassId.value,
      academic_year_id: ayId,
      semester_id: semId,
      status: targetStatus,
      spiritual_predicate: form.spiritual_predicate,
      spiritual_description: form.spiritual_description,
      social_predicate: form.social_predicate,
      social_description: form.social_description,
      attendance_sick: form.attendance_sick,
      attendance_permit: form.attendance_permit,
      attendance_absent: form.attendance_absent,
      homeroom_notes: form.homeroom_notes,
      promotion_decision: form.promotion_decision,
      subjects: form.subjects,
      extras: form.extras,
      achievements: form.achievements,
    });
    if (updated) {
      original.value = updated;
      toast.value = {
        message:
          targetStatus === 'final'
            ? 'Rapor difinalisasi. Admin akan memeriksa & menerbitkan.'
            : 'Draf rapor tersimpan.',
        tone: 'success',
      };
    } else {
      toast.value = {
        message: 'Tersimpan, tapi server tidak mengembalikan data terbaru.',
        tone: 'success',
      };
    }
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
    confirmFinalize.value = false;
  }
}

function goBack() {
  router.push({
    name: 'teacher.report-cards.class',
    params: { classId: classId.value },
  });
}

// ── Subject / extra / achievement helpers ──
function addExtra() {
  form.extras.push({ name: '', score: '', description: '' });
}
function removeExtra(idx: number) {
  form.extras.splice(idx, 1);
}
function addAchievement() {
  form.achievements.push({ name: '', type: '', description: '' });
}
function removeAchievement(idx: number) {
  form.achievements.splice(idx, 1);
}

const viewState = computed<AsyncState<ReportCardDetail>>(() => {
  if (isLoading.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (!original.value) return { status: 'empty' };
  return { status: 'content', data: original.value };
});
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- BACK + ACTIONS -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        Daftar Siswa
      </button>
    </div>

    <AsyncView :state="viewState" empty-title="Rapor tidak ditemukan" @retry="load">
      <template #default>
        <div v-if="original" class="space-y-4">
          <!-- HEADER -->
          <BrandPageHeader
            role="guru"
            :kicker="headerKicker"
            :title="original.student_name ?? 'Siswa'"
            :meta="headerMeta"
            :live-dot="false"
          >
            <span
              class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider"
              :class="[statusTone.bg, statusTone.text, statusTone.border, 'border']"
            >
              <span class="w-1.5 h-1.5 rounded-full" :class="statusTone.dot" />
              {{ statusLabel }}
            </span>
          </BrandPageHeader>

          <!-- LOCKED NOTICE -->
          <div
            v-if="isLocked"
            class="rounded-xl bg-amber-50 border border-amber-200 px-3 py-2.5 text-[12px] text-amber-900 flex items-center gap-2"
          >
            <NavIcon name="check-circle" :size="14" class="text-amber-700 flex-shrink-0" />
            <span>
              Rapor sudah <strong>{{ statusLabel }}</strong> — perubahan dinonaktifkan.
              Hubungi admin sekolah jika perlu revisi.
            </span>
          </div>

          <!-- TAB STRIP -->
          <div class="bg-slate-100 rounded-2xl p-1 flex gap-1">
            <button
              v-for="t in tabs"
              :key="t.key"
              type="button"
              class="flex-1 px-3 py-2 rounded-xl text-[11.5px] font-bold transition"
              :class="
                activeTab === t.key
                  ? 'bg-white text-brand-cobalt shadow-sm'
                  : 'text-slate-600 hover:text-slate-900'
              "
              @click="activeTab = t.key"
            >
              {{ t.label }}
            </button>
          </div>

          <!-- TAB BODY: SIKAP -->
          <section
            v-if="activeTab === 'sikap'"
            class="space-y-3"
          >
            <article class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
              <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                Sikap Spiritual
              </p>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="p in PREDICATE_OPTIONS"
                  :key="p"
                  type="button"
                  class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
                  :class="
                    form.spiritual_predicate === p
                      ? 'bg-brand-cobalt text-white border-brand-cobalt'
                      : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
                  "
                  :disabled="isLocked || isSaving"
                  @click="form.spiritual_predicate = p"
                >
                  {{ predicateLabel(p) }}
                </button>
              </div>
              <textarea
                v-model="form.spiritual_description"
                rows="3"
                placeholder="Catatan sikap spiritual (rajin beribadah, dst.)"
                class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-y disabled:bg-slate-50 disabled:text-slate-500"
                :disabled="isLocked || isSaving"
              />
            </article>
            <article class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
              <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                Sikap Sosial
              </p>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="p in PREDICATE_OPTIONS"
                  :key="p"
                  type="button"
                  class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
                  :class="
                    form.social_predicate === p
                      ? 'bg-brand-cobalt text-white border-brand-cobalt'
                      : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
                  "
                  :disabled="isLocked || isSaving"
                  @click="form.social_predicate = p"
                >
                  {{ predicateLabel(p) }}
                </button>
              </div>
              <textarea
                v-model="form.social_description"
                rows="3"
                placeholder="Catatan sikap sosial (sopan, kerjasama, dst.)"
                class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-y disabled:bg-slate-50 disabled:text-slate-500"
                :disabled="isLocked || isSaving"
              />
            </article>
          </section>

          <!-- TAB BODY: NILAI -->
          <section v-if="activeTab === 'nilai'" class="space-y-2.5">
            <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest px-1">
              {{ form.subjects.length }} Mata Pelajaran
            </p>
            <article
              v-for="(s, idx) in form.subjects"
              :key="s.subject_id || idx"
              class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2"
            >
              <div class="flex items-center gap-2">
                <p class="text-[13px] font-bold text-slate-900 flex-1 min-w-0 truncate">
                  {{ s.subject_name }}
                </p>
                <span
                  v-if="s.kkm"
                  class="text-[10px] font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded-full"
                >
                  KKM {{ s.kkm }}
                </span>
                <span
                  v-if="s.teacher_name"
                  class="text-[10px] text-slate-400"
                >
                  · {{ s.teacher_name }}
                </span>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-[100px_140px_1fr] gap-2">
                <input
                  v-model.number="s.knowledge_score"
                  type="number"
                  min="0"
                  max="100"
                  placeholder="Nilai"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] tabular-nums focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
                <select
                  v-model="s.knowledge_predicate"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                >
                  <option v-for="p in ['A', 'B', 'C', 'D']" :key="p" :value="p">
                    {{ p }}
                  </option>
                </select>
                <input
                  v-model="s.knowledge_description"
                  type="text"
                  placeholder="Deskripsi (mis. menguasai SPLDV)"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
              </div>
              <p
                v-if="s.recap_uh_avg !== null || s.recap_uts !== null || s.recap_uas !== null"
                class="text-[10.5px] text-slate-500"
              >
                Recap:
                <template v-if="s.recap_uh_avg !== null"> UH {{ s.recap_uh_avg }}</template>
                <template v-if="s.recap_uts !== null"> · UTS {{ s.recap_uts }}</template>
                <template v-if="s.recap_uas !== null"> · UAS {{ s.recap_uas }}</template>
                <template v-if="s.recap_final_score !== null"> · Akhir <strong>{{ s.recap_final_score }}</strong></template>
              </p>
            </article>
            <div
              v-if="form.subjects.length === 0"
              class="bg-amber-50 border border-amber-200 rounded-xl px-3 py-3 text-[12px] text-amber-800"
            >
              Belum ada mata pelajaran terdaftar untuk siswa ini. Pastikan kurikulum kelas sudah diisi.
            </div>
          </section>

          <!-- TAB BODY: TAMBAHAN -->
          <section v-if="activeTab === 'tambahan'" class="space-y-3">
            <!-- Ekstrakurikuler -->
            <article class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
              <div class="flex items-center gap-2">
                <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest flex-1">
                  Ekstrakurikuler
                </p>
                <Button
                  variant="secondary"
                  size="sm"
                  :disabled="isLocked || isSaving"
                  @click="addExtra"
                >
                  <NavIcon name="plus" :size="11" />
                  Tambah
                </Button>
              </div>
              <div
                v-if="form.extras.length === 0"
                class="text-[11.5px] text-slate-400 italic"
              >
                Belum ada ekstrakurikuler.
              </div>
              <div
                v-for="(e, idx) in form.extras"
                :key="idx"
                class="grid grid-cols-1 sm:grid-cols-[1fr_120px_1fr_auto] gap-2"
              >
                <input
                  v-model="e.name"
                  type="text"
                  placeholder="Nama (Pramuka)"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
                <input
                  v-model="e.score"
                  type="text"
                  placeholder="A / 85"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] tabular-nums focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
                <input
                  v-model="e.description"
                  type="text"
                  placeholder="Deskripsi opsional"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
                <button
                  type="button"
                  class="w-9 h-9 rounded-full grid place-items-center text-slate-500 hover:bg-red-50 hover:text-red-700 disabled:opacity-40"
                  :aria-label="`Hapus ${e.name}`"
                  :disabled="isLocked || isSaving"
                  @click="removeExtra(idx)"
                >
                  <NavIcon name="x" :size="13" />
                </button>
              </div>
            </article>

            <!-- Prestasi -->
            <article class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
              <div class="flex items-center gap-2">
                <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest flex-1">
                  Prestasi
                </p>
                <Button
                  variant="secondary"
                  size="sm"
                  :disabled="isLocked || isSaving"
                  @click="addAchievement"
                >
                  <NavIcon name="plus" :size="11" />
                  Tambah
                </Button>
              </div>
              <div
                v-if="form.achievements.length === 0"
                class="text-[11.5px] text-slate-400 italic"
              >
                Belum ada prestasi.
              </div>
              <div
                v-for="(a, idx) in form.achievements"
                :key="idx"
                class="grid grid-cols-1 sm:grid-cols-[1fr_140px_1fr_auto] gap-2"
              >
                <input
                  v-model="a.name"
                  type="text"
                  placeholder="Nama prestasi"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
                <input
                  v-model="a.type"
                  type="text"
                  placeholder="Akademik / Non"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
                <input
                  v-model="a.description"
                  type="text"
                  placeholder="Deskripsi opsional"
                  class="rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                  :disabled="isLocked || isSaving"
                />
                <button
                  type="button"
                  class="w-9 h-9 rounded-full grid place-items-center text-slate-500 hover:bg-red-50 hover:text-red-700 disabled:opacity-40"
                  :aria-label="`Hapus ${a.name}`"
                  :disabled="isLocked || isSaving"
                  @click="removeAchievement(idx)"
                >
                  <NavIcon name="x" :size="13" />
                </button>
              </div>
            </article>
          </section>

          <!-- TAB BODY: INFO -->
          <section v-if="activeTab === 'info'" class="space-y-3">
            <article class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
              <p class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                Kehadiran
              </p>
              <div class="grid grid-cols-3 gap-2">
                <div>
                  <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
                    Sakit
                  </label>
                  <input
                    v-model.number="form.attendance_sick"
                    type="number"
                    min="0"
                    class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] tabular-nums focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                    :disabled="isLocked || isSaving"
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
                    Izin
                  </label>
                  <input
                    v-model.number="form.attendance_permit"
                    type="number"
                    min="0"
                    class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] tabular-nums focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                    :disabled="isLocked || isSaving"
                  />
                </div>
                <div>
                  <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
                    Alpa
                  </label>
                  <input
                    v-model.number="form.attendance_absent"
                    type="number"
                    min="0"
                    class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[12.5px] tabular-nums focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50"
                    :disabled="isLocked || isSaving"
                  />
                </div>
              </div>
              <p class="text-[10.5px] text-slate-400 tabular-nums">
                Total ketidakhadiran: {{ totalAttendance }} hari
              </p>
            </article>

            <article class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
              <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                Catatan Wali Kelas
              </label>
              <textarea
                v-model="form.homeroom_notes"
                rows="4"
                placeholder="Catatan untuk siswa/wali murid"
                class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-y disabled:bg-slate-50"
                :disabled="isLocked || isSaving"
              />
            </article>

            <article class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
              <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                Keputusan Kenaikan
              </label>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="d in DECISION_OPTIONS"
                  :key="d"
                  type="button"
                  class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
                  :class="
                    form.promotion_decision === d
                      ? d === 'promoted' || d === 'graduated'
                        ? 'bg-emerald-600 text-white border-emerald-600'
                        : 'bg-red-600 text-white border-red-600'
                      : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
                  "
                  :disabled="isLocked || isSaving"
                  @click="form.promotion_decision = d"
                >
                  {{
                    d === 'promoted'
                      ? 'Naik Kelas'
                      : d === 'not_promoted'
                        ? 'Tinggal di Kelas'
                        : d === 'graduated'
                          ? 'Lulus'
                          : d === 'not_graduated'
                            ? 'Tidak Lulus'
                            : d
                  }}
                </button>
              </div>
            </article>
          </section>

          <!-- STICKY FOOTER -->
          <div
            v-if="!isLocked"
            class="grid grid-cols-2 gap-2 sticky bottom-2 bg-white/95 backdrop-blur rounded-2xl border border-slate-200 px-3 py-2 shadow-lg"
          >
            <Button
              variant="secondary"
              block
              :loading="isSaving"
              :disabled="isSaving"
              @click="save('draft')"
            >
              <NavIcon name="file-text" :size="13" />
              Simpan Draf
            </Button>
            <Button
              variant="primary"
              block
              :disabled="isSaving"
              @click="confirmFinalize = true"
            >
              <NavIcon name="check" :size="13" />
              Finalisasi
            </Button>
          </div>
        </div>
      </template>
    </AsyncView>

    <!-- FINALIZE CONFIRM -->
    <ConfirmationDialog
      v-if="confirmFinalize"
      title="Finalisasi Rapor"
      :message="`Setelah difinalisasi, rapor tidak bisa diedit lagi. Admin akan memeriksa & menerbitkan. Lanjutkan untuk ${original?.student_name ?? 'siswa ini'}?`"
      confirm-label="Finalisasi"
      :loading="isSaving"
      @close="confirmFinalize = false"
      @confirm="save('final')"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
