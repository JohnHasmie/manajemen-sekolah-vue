<!--
  TeacherLessonPlanView.vue — daftar RPP guru (Flutter parity).

  Web port of `lib/features/lesson_plans/presentation/screens/
  teacher_lesson_plan_screen.dart`. Chrome mirrors Buku Nilai / Presensi
  / Jadwal / Kegiatan Kelas (guru tint):

    1. <BrandPageHeader role="guru"> — kicker + title + meta + action
       cluster (Upload File · Generate AI)
    2. <KpiStripCards> — Total / Menunggu / Disetujui / AI (counts from
       /rpp/summary)
    3. <PageFilterToolbar> — Kelas + Mapel + Format chips + search
    4. Status tabs (Semua / Draf / Menunggu / Disetujui / Revisi)
    5. Date-grouped <LessonPlanCard role="teacher"> sections
       (Hari Ini / Kemarin / Minggu Ini / Bulan Ini / Lebih Lama)
    6. <LessonPlanGenerateModal> — format picker + setup form (k13 /
       1 halaman / modul ajar)
    7. <LessonPlanAiPollingOverlay> — fullscreen overlay while the job
       is polled. On done → router push to the new RPP's detail page.

  Endpoints (mirrors Flutter):
    GET    /rpp/summary             list + counts envelope
    POST   /rpp/{id}/submit         teacher submits Draft → Pending
    POST   /rpp/generate            AI generation (returns job_id)
    GET    /ai-jobs/{id}            AI job polling
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { LessonPlanService } from '@/services/lesson-plans.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import type {
  LessonPlan,
  LessonPlanCounts,
  LessonPlanFormat,
  LessonPlanStatus,
} from '@/types/lesson-plans';
import { FORMAT_LABELS } from '@/types/lesson-plans';
import type { Classroom, Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import LessonPlanCard from '@/components/feature/LessonPlanCard.vue';
import LessonPlanGenerateModal from '@/components/feature/LessonPlanGenerateModal.vue';
import LessonPlanAiPollingOverlay from '@/components/feature/LessonPlanAiPollingOverlay.vue';
import LessonPlanUploadModal from '@/components/feature/LessonPlanUploadModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { fromQuickAction, queryString } = useQuickAction();
const router = useRouter();

type TabKey = 'all' | 'Draft' | 'Pending' | 'Approved' | 'SentBack' | 'Rejected';

const auth = useAuthStore();

// ── Filter state ──
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const classId = ref<string>('');
const subjectId = ref<string>('');
const formatFilter = ref<LessonPlanFormat | ''>('');
const tabKey = ref<TabKey>('all');
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);
const showFormatPicker = ref(false);

const activeClass = computed(
  () => classes.value.find((c) => c.id === classId.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectId.value) ?? null,
);

// ── Data state ──
const items = ref<LessonPlan[]>([]);
const counts = ref<LessonPlanCounts>({ pending: 0, approved: 0, rejected: 0 });
const isLoading = ref(true);
const error = ref<string | null>(null);

const showAiSheet = ref(false);
const showUploadSheet = ref(false);
// `isGenerating` covers the POST /rpp/generate roundtrip (modal stays
// open until the server returns a job_id). After that we flip to the
// polling overlay via `activeJob`.
const isGenerating = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

/**
 * Polling overlay state. `subtitle` shows the context line ("K13 ·
 * Bab 3 · Energi") so the user knows what's brewing. Once the job
 * resolves, we navigate to detail with the new `result_id`.
 */
const activeJob = ref<{
  id: string;
  format: string;
  subtitle: string;
} | null>(null);
let pollTimer: ReturnType<typeof setInterval> | null = null;
let pollStartMs = 0;
const POLL_INTERVAL_MS = 2500;
const POLL_TIMEOUT_MS = 90_000;

// ── Loaders ──
async function loadReferences() {
  try {
    const [c, s] = await Promise.all([
      ClassroomService.list({ per_page: 100 }),
      SubjectService.list({ per_page: 100 }),
    ]);
    classes.value = c.items;
    subjects.value = s.items;

    if (fromQuickAction.value) {
      classId.value = queryString('class_id') ?? '';
      subjectId.value = queryString('subject_id') ?? '';
    }
  } catch {
    // pickers degrade to empty list
  }
}

/**
 * Translate the local tab key to the backend `status` param.
 * "all" + "Draft" both pull all rows; Draft is filtered client-side
 * (it's a virtual bucket = Pending without a submitted_at).
 */
function tabKeyToStatus(k: TabKey): LessonPlanStatus | 'all' {
  if (k === 'all' || k === 'Draft') return 'all';
  return k;
}

async function reload() {
  // No early-return when filters are empty — the backend scopes by
  // teacher_id so the list always renders for the signed-in teacher.
  isLoading.value = true;
  error.value = null;
  try {
    const res = await LessonPlanService.getSummary({
      status: tabKeyToStatus(tabKey.value),
      format: formatFilter.value || undefined,
      subject_id: subjectId.value || null,
      class_id: classId.value || null,
      teacher_id: auth.teacherId ?? auth.user?.id ?? null,
      search: searchQuery.value || undefined,
      per_page: 100,
    });
    const sorted = [...res.items].sort((a, b) => {
      const ad = a.submitted_at ?? a.created_at;
      const bd = b.submitted_at ?? b.created_at;
      return String(bd ?? '').localeCompare(String(ad ?? ''));
    });
    // Client-side narrow when the "Draf" tab is active. Draft rows
    // are Pending with no `submitted_at`, OR rows the backend
    // already flags as Draft.
    items.value =
      tabKey.value === 'Draft'
        ? sorted.filter(
            (i) => i.status === 'Draft' || (i.status === 'Pending' && !i.submitted_at),
          )
        : sorted;
    counts.value = res.counts;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await reload();
});

onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer);
});

watch([classId, subjectId, formatFilter, tabKey], () => reload());

// Debounced search refresh (mirrors Kegiatan Kelas pattern).
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(searchQuery, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => reload(), 350);
});

useAcademicYearWatcher(() => reload());

// ── Derived KPI ──
const draftCount = computed(
  () =>
    counts.value.draft ??
    items.value.filter(
      (i) => i.status === 'Draft' || (i.status === 'Pending' && !i.submitted_at),
    ).length,
);

const sentBackCount = computed(
  () => counts.value.sent_back ?? items.value.filter((i) => i.status === 'SentBack').length,
);

const totalCount = computed(
  () =>
    counts.value.total ??
    counts.value.pending +
      counts.value.approved +
      counts.value.rejected +
      draftCount.value +
      sentBackCount.value,
);

const aiCount = computed(
  () =>
    counts.value.ai_generated ??
    items.value.filter((i) => i.ai_generated).length,
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'file-text',
    label: 'Total RPP',
    value: totalCount.value,
    tone: 'brand',
  },
  {
    icon: 'bell',
    label: 'Menunggu',
    value: counts.value.pending,
    tone: counts.value.pending > 0 ? 'amber' : 'slate',
    accented: counts.value.pending > 0,
  },
  {
    icon: 'check-circle',
    label: 'Disetujui',
    value: counts.value.approved,
    tone: 'green',
  },
  {
    icon: 'sparkles',
    label: 'Hasil AI',
    value: aiCount.value,
    tone: 'violet',
  },
]);

// ── Status tabs ──
const tabOptions = computed(() => [
  { key: 'all' as TabKey, label: 'Semua', meta: totalCount.value },
  { key: 'Draft' as TabKey, label: 'Draf', meta: draftCount.value },
  { key: 'Pending' as TabKey, label: 'Menunggu', meta: counts.value.pending },
  { key: 'Approved' as TabKey, label: 'Disetujui', meta: counts.value.approved },
  { key: 'SentBack' as TabKey, label: 'Revisi', meta: sentBackCount.value },
  { key: 'Rejected' as TabKey, label: 'Ditolak', meta: counts.value.rejected },
]);

// ── Date grouping (mirrors Kegiatan Kelas) ──
interface PlanGroup {
  key: string;
  label: string;
  items: LessonPlan[];
}

function daysAgo(dateIso: string | null | undefined): number {
  if (!dateIso) return Infinity;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const d = new Date(dateIso);
  d.setHours(0, 0, 0, 0);
  return Math.round((today.getTime() - d.getTime()) / 86_400_000);
}

const groupedItems = computed<PlanGroup[]>(() => {
  const buckets: Record<string, LessonPlan[]> = {
    today: [],
    yesterday: [],
    thisWeek: [],
    thisMonth: [],
    earlier: [],
  };
  for (const it of items.value) {
    const ref = it.submitted_at ?? it.created_at;
    const d = daysAgo(ref);
    if (d <= 0) buckets.today.push(it);
    else if (d === 1) buckets.yesterday.push(it);
    else if (d <= 7) buckets.thisWeek.push(it);
    else if (d <= 30) buckets.thisMonth.push(it);
    else buckets.earlier.push(it);
  }
  const groups: PlanGroup[] = [
    { key: 'today', label: 'Hari Ini', items: buckets.today },
    { key: 'yesterday', label: 'Kemarin', items: buckets.yesterday },
    { key: 'thisWeek', label: 'Minggu Ini', items: buckets.thisWeek },
    { key: 'thisMonth', label: 'Bulan Ini', items: buckets.thisMonth },
    { key: 'earlier', label: 'Lebih Lama', items: buckets.earlier },
  ];
  return groups.filter((g) => g.items.length > 0);
});

const listState = computed<AsyncState<PlanGroup[]>>(() => {
  if (isLoading.value && items.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (groupedItems.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: groupedItems.value };
});

// ── AI generate flow ──
//
// Payload comes from <LessonPlanGenerateModal> which has already
// validated kelas / mapel / bab. We POST, capture job_id, close the
// modal, and switch to the polling overlay until the job resolves.
async function startAi(payload: {
  format: 'k13' | 'rpp_1_halaman' | 'modul_ajar';
  class_id: string;
  subject_id: string;
  chapter_label: string;
  duration_minutes: number;
  approach?: string;
}) {
  isGenerating.value = true;
  try {
    const { job_id } = await LessonPlanService.generateWithAi(payload);
    if (!job_id) throw new Error('Server tidak mengembalikan job_id.');
    const cls = classes.value.find((c) => c.id === payload.class_id)?.name ?? '';
    const sub =
      subjects.value.find((s) => s.id === payload.subject_id)?.name ?? '';
    activeJob.value = {
      id: job_id,
      format: payload.format,
      subtitle: [FORMAT_LABELS[payload.format], cls, sub, payload.chapter_label]
        .filter((p) => p && p.length > 0)
        .join(' · '),
    };
    showAiSheet.value = false;
    pollJob(job_id);
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isGenerating.value = false;
  }
}

function stopPoll() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

function pollJob(jobId: string) {
  stopPoll();
  pollStartMs = Date.now();
  pollTimer = setInterval(async () => {
    // Hard timeout to avoid runaway polling — surface a graceful
    // error after 90s so the teacher can retry or check later.
    if (Date.now() - pollStartMs > POLL_TIMEOUT_MS) {
      stopPoll();
      activeJob.value = null;
      toast.value = {
        message: 'AI butuh waktu lebih lama dari biasanya. Cek daftar Draf nanti.',
        tone: 'error',
      };
      await reload();
      return;
    }
    try {
      const res = await LessonPlanService.getAiJob(jobId);
      if (res.status === 'done') {
        stopPoll();
        activeJob.value = null;
        toast.value = { message: 'RPP berhasil dibuat AI.', tone: 'success' };
        await reload();
        if (res.result_id) {
          // Jump straight to the new draft so the teacher can review +
          // edit before sending to admin.
          router.push({
            name: 'teacher.lesson-plans.detail',
            params: { id: res.result_id },
          });
        }
      } else if (res.status === 'error') {
        stopPoll();
        activeJob.value = null;
        toast.value = {
          message: res.error ?? 'AI gagal — coba lagi.',
          tone: 'error',
        };
      }
    } catch {
      // Keep polling silently on transient errors.
    }
  }, POLL_INTERVAL_MS);
}

function cancelPolling() {
  // User pressed "Tutup & lanjut nanti" — stop the timer locally but
  // leave the backend job running. When it finishes the row shows up
  // in the Draf tab on next reload.
  stopPoll();
  activeJob.value = null;
  toast.value = {
    message: 'Polling dihentikan. RPP akan muncul di Draf saat selesai.',
    tone: 'success',
  };
}

// ── Helpers ──
function pickClass(id: string) {
  classId.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectId.value = id;
  showSubjectPicker.value = false;
}
function pickFormat(f: LessonPlanFormat | '') {
  formatFilter.value = f;
  showFormatPicker.value = false;
}

function openDetail(plan: LessonPlan) {
  router.push({ name: 'teacher.lesson-plans.detail', params: { id: plan.id } });
}

// ── Upload flow (file-format RPP) ──
function onUploaded(plan: LessonPlan) {
  toast.value = {
    message: `"${plan.title}" tersimpan sebagai Draf.`,
    tone: 'success',
  };
  // Refetch in the background so the list reflects the new row when
  // the teacher backs out of detail.
  reload();
  router.push({
    name: 'teacher.lesson-plans.detail',
    params: { id: plan.id },
  });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      kicker="Akademik · Rencana Pembelajaran"
      title="Rencana Pelaksanaan Pembelajaran"
      :meta="`${totalCount} RPP · ${counts.pending} menunggu review`"
    >
      <Button variant="secondary" size="sm" @click="showUploadSheet = true">
        <NavIcon name="upload" :size="14" />
        Upload File
      </Button>
      <Button variant="primary" size="sm" @click="showAiSheet = true">
        <NavIcon name="sparkles" :size="14" />
        Generate AI
      </Button>
    </BrandPageHeader>

    <!-- KPI strip -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      search-placeholder="Cari judul RPP…"
    >
      <template #chips>
        <AppFilterChip
          label="Kelas"
          :value="activeClass?.name ?? 'Semua kelas'"
          icon-name="layers"
          tone="brand"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          label="Mapel"
          :value="activeSubject?.name ?? 'Semua mapel'"
          icon-name="book"
          tone="amber"
          @click="showSubjectPicker = true"
        />
        <AppFilterChip
          label="Format"
          :value="formatFilter ? FORMAT_LABELS[formatFilter] : 'Semua format'"
          icon-name="file-text"
          tone="violet"
          @click="showFormatPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- STATUS TABS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="tab in tabOptions"
        :key="tab.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border inline-flex items-center gap-1.5"
        :class="
          tabKey === tab.key
            ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
        "
        @click="tabKey = tab.key"
      >
        {{ tab.label }}
        <span
          class="text-[9.5px] font-bold tabular-nums px-1.5 py-0.5 rounded-full"
          :class="
            tabKey === tab.key
              ? 'bg-white/20 text-white'
              : 'bg-slate-100 text-slate-500'
          "
        >
          {{ tab.meta }}
        </span>
      </button>
    </div>

    <!-- TIMELINE -->
    <AsyncView
      :state="listState"
      :empty-title="
        tabKey === 'Draft'
          ? 'Belum ada draf RPP'
          : tabKey === 'all'
            ? 'Belum ada RPP'
            : 'Tidak ada RPP di filter ini'
      "
      empty-description="Mulai dari Generate AI atau tambah manual."
      empty-icon="file-text"
      @retry="reload"
    >
      <div class="space-y-5">
        <section
          v-for="group in groupedItems"
          :key="group.key"
          class="space-y-2"
        >
          <div class="flex items-center gap-2 px-1">
            <span class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              {{ group.label }}
            </span>
            <span class="text-[10px] text-slate-400 tabular-nums">
              · {{ group.items.length }}
            </span>
            <span class="flex-1 border-t border-dashed border-slate-200 ml-2"></span>
          </div>
          <div class="space-y-2">
            <LessonPlanCard
              v-for="it in group.items"
              :key="it.id"
              :plan="it"
              role="teacher"
              @click="openDetail"
            />
          </div>
        </section>
      </div>
    </AsyncView>

    <!-- CLASS PICKER -->
    <Modal v-if="showClassPicker" title="Pilih Kelas" @close="showClassPicker = false">
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': !classId }"
            @click="pickClass('')"
          >
            Semua kelas
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': c.id === classId }"
            @click="pickClass(c.id)"
          >
            {{ c.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- SUBJECT PICKER -->
    <Modal v-if="showSubjectPicker" title="Pilih Mata Pelajaran" @close="showSubjectPicker = false">
      <ul class="space-y-1 max-h-[400px] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': !subjectId }"
            @click="pickSubject('')"
          >
            Semua mapel
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': s.id === subjectId }"
            @click="pickSubject(s.id)"
          >
            {{ s.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- FORMAT PICKER -->
    <Modal v-if="showFormatPicker" title="Pilih Format RPP" @close="showFormatPicker = false">
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': !formatFilter }"
            @click="pickFormat('')"
          >
            Semua format
          </button>
        </li>
        <li v-for="f in (['k13', 'rpp_1_halaman', 'modul_ajar', 'file'] as LessonPlanFormat[])" :key="f">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-brand-cobalt/5 text-brand-cobalt font-bold': formatFilter === f }"
            @click="pickFormat(f)"
          >
            {{ FORMAT_LABELS[f] }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- AI GENERATE MODAL -->
    <LessonPlanGenerateModal
      v-if="showAiSheet"
      :classes="classes"
      :subjects="subjects"
      :initial-class-id="classId"
      :initial-subject-id="subjectId"
      :busy="isGenerating"
      @close="showAiSheet = false"
      @generate="startAi"
    />

    <!-- AI POLLING OVERLAY -->
    <LessonPlanAiPollingOverlay
      :visible="activeJob !== null"
      title="Memproses RPP AI"
      :subtitle="activeJob?.subtitle ?? ''"
      :estimated-seconds="45"
      @cancel="cancelPolling"
    />

    <!-- UPLOAD MODAL -->
    <LessonPlanUploadModal
      v-if="showUploadSheet"
      :teacher-id="auth.teacherId ?? auth.user?.id ?? ''"
      :classes="classes"
      :subjects="subjects"
      :initial-class-id="classId"
      :initial-subject-id="subjectId"
      @close="showUploadSheet = false"
      @created="onUploaded"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
