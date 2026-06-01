<!--
  TeacherClassActivityView.vue — Kegiatan Kelas (Catat Kegiatan).

  Web port of Flutter's `teacher_class_activity_screen.dart`.

  Layout (matches Buku Nilai / Presensi / Jadwal chrome):
    1. <BrandPageHeader> (guru tint) — kicker + title + meta
    2. <KpiStripCards> — Total / Minggu ini / Perlu Catat / Dengan Refleksi
    3. <PageFilterToolbar> — Kelas + Mapel chips + Type tabs + search
    4. Date-grouped timeline (Hari Ini / Kemarin / Minggu Lalu / dst)
       - Each card is <ActivityCard role="teacher">
       - Tap card → <ActivityDetailModal>
       - Detail's "Catat Submit" CTA → <ActivitySubmissionPickerModal>
    5. Floating FAB "+ Tambah" → edit form modal

  Endpoints used (mirrors Flutter):
    GET  /class-activities/teacher-summary    list + KPI block
    GET  /class-activity/{id}                  full detail on open
    POST /class-activity                       create
    PUT  /class-activity/{id}                  update
    DELETE /class-activity/{id}                delete
    GET  /class-activity/{id}/submissions      seed Catat Submit roster
    POST /class-activity/{id}/submissions      bulk-upsert submissions
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { ClassActivityService } from '@/services/class-activity.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import type {
  ActivitySubmissionRow,
  ActivityType,
  ClassActivity,
} from '@/types/class-activity';
import { ACTIVITY_TYPE_LABELS } from '@/types/class-activity';
import type { Classroom, Subject } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import ActivityCard from '@/components/feature/ActivityCard.vue';
import ActivityDetailModal from '@/components/feature/ActivityDetailModal.vue';
import ActivitySubmissionPickerModal from '@/components/feature/ActivitySubmissionPickerModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';
import { useQuickAction } from '@/composables/useQuickAction';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const auth = useAuthStore();
const { fromQuickAction, queryString } = useQuickAction();

// ── Filter state ──
const classes = ref<Classroom[]>([]);
const subjects = ref<Subject[]>([]);
const classFilter = ref<string>('');
const subjectFilter = ref<string>('');
const typeFilter = ref<ActivityType | 'all'>('all');
const rangeKey = ref<string>('30');
const searchQuery = ref<string>('');

const showClassPicker = ref(false);
const showSubjectPicker = ref(false);

const activeClass = computed(
  () => classes.value.find((c) => c.id === classFilter.value) ?? null,
);
const activeSubject = computed(
  () => subjects.value.find((s) => s.id === subjectFilter.value) ?? null,
);

// ── List state ──
const items = ref<ClassActivity[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// Server-computed KPI (preferred); falls back to derived stats on
// first paint or when the summary endpoint isn't available.
const serverKpi = ref<{
  total: number;
  this_week: number;
  pending_action: number;
} | null>(null);

// ── Detail / form / submission modals ──
const detailTarget = ref<ClassActivity | null>(null);
const detailSubmissions = ref<ActivitySubmissionRow[]>([]);
const isDetailLoading = ref(false);

const editTarget = ref<ClassActivity | null | undefined>(undefined);
const deleteTarget = ref<ClassActivity | null>(null);
const submissionPickerFor = ref<ClassActivity | null>(null);
const submissionPickerRows = ref<ActivitySubmissionRow[]>([]);
const isSaving = ref(false);

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const rangeOptions = [
  { key: '7', label: '7 hari' },
  { key: '30', label: '30 hari' },
  { key: '90', label: '90 hari' },
];

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
      classFilter.value = queryString('class_id') ?? '';
      subjectFilter.value = queryString('subject_id') ?? '';
    }
  } catch {
    // ignore — pickers degrade to empty list
  }
}

function mapPeriod(key: string): 'today' | '7d' | '30d' | 'semester' | 'year' {
  if (key === '7') return '7d';
  if (key === '30') return '30d';
  if (key === '90') return 'semester';
  return '30d';
}

async function reload() {
  const teacherId = auth.teacherId ?? auth.user?.id;
  if (!teacherId) {
    isLoading.value = false;
    loadError.value = 'Profil guru belum termuat';
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    // Prefer the dedicated teacher-summary endpoint (KPI + scoped
    // list). Falls back to the legacy /class-activity list on 404 /
    // backend-not-yet-deployed.
    try {
      const resp = await ClassActivityService.getTeacherSummary({
        teacher_id: teacherId,
        period: mapPeriod(rangeKey.value),
        class_id: classFilter.value || undefined,
        subject_id: subjectFilter.value || undefined,
        type: typeFilter.value === 'all' ? undefined : typeFilter.value,
        search: searchQuery.value || undefined,
        per_page: 100,
      });
      items.value = resp.items;
      serverKpi.value = resp.kpi;
    } catch {
      // Legacy fallback
      const res = await ClassActivityService.list({
        teacher_id: teacherId,
        class_id: classFilter.value || undefined,
        subject_id: subjectFilter.value || undefined,
        range_days: Number(rangeKey.value),
        type: typeFilter.value === 'all' ? undefined : typeFilter.value,
        search: searchQuery.value || undefined,
        per_page: 100,
      });
      items.value = res.items;
      serverKpi.value = null;
    }
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await loadReferences();
  await reload();
});

watch([classFilter, subjectFilter, rangeKey, typeFilter], () => reload());
let searchTimer: ReturnType<typeof setTimeout> | null = null;
watch(searchQuery, () => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => reload(), 350);
});

useAcademicYearWatcher(() => reload());

// ── Date-grouped timeline ──
//
// Buckets: today / yesterday / thisWeek / earlier — same vocabulary
// as Flutter's `teacher_class_activity_screen.dart` group headers.
interface ActivityGroup {
  key: string;
  label: string;
  items: ClassActivity[];
}

function daysAgo(dateIso: string): number {
  if (!dateIso) return Infinity;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const d = new Date(dateIso);
  d.setHours(0, 0, 0, 0);
  return Math.round((today.getTime() - d.getTime()) / 86_400_000);
}

const groupedItems = computed<ActivityGroup[]>(() => {
  const sorted = [...items.value].sort((a, b) =>
    String(b.date ?? '').localeCompare(String(a.date ?? '')),
  );
  const buckets: Record<string, ClassActivity[]> = {
    today: [],
    yesterday: [],
    thisWeek: [],
    thisMonth: [],
    earlier: [],
  };
  for (const it of sorted) {
    const d = daysAgo(it.date);
    if (d <= 0) buckets.today.push(it);
    else if (d === 1) buckets.yesterday.push(it);
    else if (d <= 7) buckets.thisWeek.push(it);
    else if (d <= 30) buckets.thisMonth.push(it);
    else buckets.earlier.push(it);
  }
  const groups: ActivityGroup[] = [
    { key: 'today', label: 'Hari Ini', items: buckets.today },
    { key: 'yesterday', label: 'Kemarin', items: buckets.yesterday },
    { key: 'thisWeek', label: 'Minggu Ini', items: buckets.thisWeek },
    { key: 'thisMonth', label: 'Bulan Ini', items: buckets.thisMonth },
    { key: 'earlier', label: 'Lebih Lama', items: buckets.earlier },
  ];
  return groups.filter((g) => g.items.length > 0);
});

const listState = computed<AsyncState<ActivityGroup[]>>(() => {
  if (isLoading.value && items.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (groupedItems.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: groupedItems.value };
});

// ── KPI strip ──
//
// Server values win when present; otherwise derive from the loaded
// items. Pending action = activities of scored types (tugas/ulangan)
// with at least one student still "pending".
const kpiCards = computed<KpiCard[]>(() => {
  const total = serverKpi.value?.total ?? items.value.length;
  const thisWeek =
    serverKpi.value?.this_week ??
    items.value.filter((i) => daysAgo(i.date) <= 7).length;

  let pendingAction =
    serverKpi.value?.pending_action ??
    items.value.filter(
      (i) =>
        (i.type === 'tugas' || i.type === 'ulangan') &&
        i.submissions.total_students > 0 &&
        i.submissions.pending > 0,
    ).length;
  // Clamp to non-negative — backend might ship null
  if (pendingAction < 0) pendingAction = 0;

  const withReflection = items.value.filter((i) => i.has_reflection).length;

  return [
    {
      icon: 'activity',
      label: 'Total',
      value: total,
      suffix: 'kegiatan',
      tone: 'brand',
    },
    {
      icon: 'calendar',
      label: 'Minggu Ini',
      value: thisWeek,
      tone: 'violet',
    },
    {
      icon: 'check-square',
      label: 'Perlu Catat',
      value: pendingAction,
      suffix: 'submit',
      tone: pendingAction > 0 ? 'amber' : 'green',
      accented: pendingAction > 0,
    },
    {
      icon: 'edit',
      label: 'Refleksi',
      value: withReflection,
      suffix: 'catatan',
      tone: 'green',
    },
  ];
});

const typeTabs: { key: ActivityType | 'all'; label: string }[] = [
  { key: 'all', label: 'Semua' },
  { key: 'tugas', label: 'Tugas' },
  { key: 'pr', label: 'PR' },
  { key: 'ulangan', label: 'Ulangan' },
  { key: 'lainnya', label: 'Lainnya' },
];

// ── Edit form state ──
const form = reactive<{
  title: string;
  date: string;
  time: string;
  session: string;
  type: ActivityType;
  description: string;
  material: string;
  reflection: string;
}>({
  title: '',
  date: todayIso(),
  time: '',
  session: '',
  type: 'lainnya',
  description: '',
  material: '',
  reflection: '',
});

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

function resetForm() {
  form.title = '';
  form.date = todayIso();
  form.time = '';
  form.session = '';
  form.type = 'lainnya';
  form.description = '';
  form.material = '';
  form.reflection = '';
}

function openAdd() {
  resetForm();
  editTarget.value = null;
}

function openEdit(a: ClassActivity) {
  form.title = a.title;
  form.date = a.date;
  form.time = a.time ?? '';
  form.session = a.session ?? '';
  form.type = a.type;
  form.description = a.description ?? '';
  form.material = a.material ?? '';
  form.reflection = a.reflection ?? '';
  editTarget.value = a;
  detailTarget.value = null;
}

async function saveActivity() {
  if (!classFilter.value || !subjectFilter.value) {
    toast.value = {
      message: 'Pilih kelas & mata pelajaran dulu sebelum menyimpan.',
      tone: 'error',
    };
    return;
  }
  if (!form.title.trim()) {
    toast.value = { message: 'Judul kegiatan wajib diisi.', tone: 'error' };
    return;
  }
  isSaving.value = true;
  try {
    const payload = {
      class_id: classFilter.value,
      subject_id: subjectFilter.value,
      teacher_id: auth.teacherId ?? auth.user?.id,
      title: form.title.trim(),
      date: form.date,
      time: form.time || null,
      session: form.session.trim() || null,
      type: form.type,
      description: form.description.trim() || null,
      material: form.material.trim() || null,
      reflection: form.reflection.trim() || null,
    };
    if (editTarget.value && editTarget.value.id) {
      await ClassActivityService.update(editTarget.value.id, payload);
    } else {
      await ClassActivityService.create(payload);
    }
    editTarget.value = undefined;
    toast.value = { message: 'Kegiatan tersimpan.', tone: 'success' };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// ── Detail flow ──
async function openDetail(a: ClassActivity) {
  detailTarget.value = a;
  detailSubmissions.value = [];
  isDetailLoading.value = true;
  // Try to enrich with full detail + per-student submissions in
  // parallel. Both endpoints are optional — if backend doesn't ship
  // either, the detail modal still renders the summary from the
  // list payload.
  try {
    const [full, rows] = await Promise.all([
      ClassActivityService.getDetail(a.id),
      ClassActivityService.listSubmissions(a.id),
    ]);
    if (full) detailTarget.value = full;
    detailSubmissions.value = rows;
  } catch {
    // graceful — modal still shows summary
  } finally {
    isDetailLoading.value = false;
  }
}

async function confirmDelete() {
  if (!deleteTarget.value) return;
  isSaving.value = true;
  try {
    await ClassActivityService.remove(deleteTarget.value.id);
    deleteTarget.value = null;
    detailTarget.value = null;
    toast.value = { message: 'Kegiatan dihapus.', tone: 'success' };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// ── Catat Submit flow ──
async function openSubmissionPicker(a: ClassActivity) {
  submissionPickerFor.value = a;
  submissionPickerRows.value = [];
  try {
    const rows = await ClassActivityService.listSubmissions(a.id);
    submissionPickerRows.value = rows;
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
    submissionPickerFor.value = null;
  }
}

async function saveSubmissions(rows: ActivitySubmissionRow[]) {
  if (!submissionPickerFor.value) return;
  isSaving.value = true;
  try {
    const resp = await ClassActivityService.upsertSubmissions(
      submissionPickerFor.value.id,
      rows,
    );
    if (resp.success === false) {
      toast.value = { message: resp.error ?? 'Gagal menyimpan', tone: 'error' };
      return;
    }
    submissionPickerFor.value = null;
    toast.value = {
      message: `${resp.saved ?? rows.length} siswa tersimpan.`,
      tone: 'success',
    };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

function pickClass(id: string) {
  classFilter.value = id;
  showClassPicker.value = false;
}
function pickSubject(id: string) {
  subjectFilter.value = id;
  showSubjectPicker.value = false;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      kicker="Akademik · Kegiatan Kelas"
      title="Catat Kegiatan Kelas"
      meta="Rekap pembelajaran harian, tugas, dan refleksi"
      :live-dot="false"
    >
      <Button variant="primary" size="sm" @click="openAdd">
        <NavIcon name="plus" :size="14" />
        Tambah
      </Button>
    </BrandPageHeader>

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      search-placeholder="Cari judul atau catatan…"
    >
      <template #chips>
        <AppFilterChip
          label="Kelas"
          :value="activeClass?.name ?? 'Semua kelas'"
          :is-active="!!classFilter"
          @click="showClassPicker = true"
        />
        <AppFilterChip
          label="Mapel"
          :value="activeSubject?.name ?? 'Semua mapel'"
          :is-active="!!subjectFilter"
          @click="showSubjectPicker = true"
        />
      </template>
      <template #segmented>
        <div class="flex items-center gap-2">
          <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
            Rentang
          </span>
          <SegmentedControl v-model="rangeKey" :options="rangeOptions" size="sm" />
        </div>
      </template>
    </PageFilterToolbar>

    <!-- TYPE TABS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="tab in typeTabs"
        :key="tab.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
        :class="
          typeFilter === tab.key
            ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
        "
        @click="typeFilter = tab.key"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- TIMELINE -->
    <AsyncView
      :state="listState"
      empty-title="Belum ada catatan kegiatan"
      empty-description="Klik “Tambah” untuk mencatat kegiatan kelas hari ini."
      empty-icon="activity"
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
            <ActivityCard
              v-for="it in group.items"
              :key="it.id"
              :activity="it"
              role="teacher"
              @click="openDetail"
            />
          </div>
        </section>
      </div>
    </AsyncView>

    <!-- DETAIL MODAL -->
    <ActivityDetailModal
      v-if="detailTarget"
      :activity="detailTarget"
      :submissions="detailSubmissions"
      role="teacher"
      :busy="isSaving || isDetailLoading"
      @close="detailTarget = null"
      @edit="openEdit"
      @delete="deleteTarget = $event"
      @record-submissions="openSubmissionPicker"
    />

    <!-- CATAT SUBMIT MODAL -->
    <ActivitySubmissionPickerModal
      v-if="submissionPickerFor"
      :activity="submissionPickerFor"
      :rows="submissionPickerRows"
      :busy="isSaving"
      @close="submissionPickerFor = null"
      @save="saveSubmissions"
    />

    <!-- DELETE CONFIRM -->
    <ConfirmationDialog
      v-if="deleteTarget"
      title="Hapus Kegiatan"
      :message="`Hapus kegiatan “${deleteTarget.title}”? Tindakan ini tidak dapat dibatalkan.`"
      confirm-label="Hapus"
      danger
      :loading="isSaving"
      @close="deleteTarget = null"
      @confirm="confirmDelete"
    />

    <!-- EDIT FORM MODAL -->
    <Modal
      v-if="editTarget !== undefined"
      :title="editTarget ? 'Edit Kegiatan' : 'Tambah Kegiatan'"
      :subtitle="
        activeClass && activeSubject
          ? `${activeClass.name} · ${activeSubject.name}`
          : 'Pilih kelas + mapel di toolbar dulu'
      "
      @close="editTarget = undefined"
    >
      <div class="space-y-3">
        <div>
          <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Judul
          </label>
          <input
            v-model="form.title"
            type="text"
            placeholder="Misal: Praktek bab 3 — Energi"
            class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          />
        </div>
        <div class="grid grid-cols-3 gap-2">
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Tanggal
            </label>
            <input
              v-model="form.date"
              type="date"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
            />
          </div>
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Jam
            </label>
            <input
              v-model="form.time"
              type="time"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
            />
          </div>
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Sesi
            </label>
            <input
              v-model="form.session"
              type="text"
              placeholder="Sesi 1"
              class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
            />
          </div>
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Tipe
          </label>
          <div class="flex gap-1.5 mt-1 flex-wrap">
            <button
              v-for="opt in typeTabs.filter((t) => t.key !== 'all')"
              :key="opt.key"
              type="button"
              class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
              :class="
                form.type === opt.key
                  ? 'bg-brand-cobalt text-white border-brand-cobalt'
                  : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
              "
              @click="form.type = opt.key as ActivityType"
            >
              {{ opt.label }}
            </button>
          </div>
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Materi terkait
          </label>
          <input
            v-model="form.material"
            type="text"
            placeholder="Misal: Bab 3 — Energi & Perubahannya"
            class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          />
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Deskripsi
          </label>
          <textarea
            v-model="form.description"
            rows="3"
            placeholder="Apa yang dipelajari hari ini?"
            class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          />
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            Refleksi (opsional)
          </label>
          <textarea
            v-model="form.reflection"
            rows="2"
            placeholder="Catatan guru: yang berhasil / butuh perbaikan…"
            class="mt-1 w-full text-sm rounded-xl border border-slate-200 focus:border-brand-cobalt focus:outline-none px-3 py-2"
          />
        </div>
        <div class="flex justify-end gap-2 pt-2 border-t border-slate-100">
          <Button variant="ghost" :disabled="isSaving" @click="editTarget = undefined">
            Batal
          </Button>
          <Button variant="primary" :disabled="isSaving" @click="saveActivity">
            {{ isSaving ? 'Menyimpan…' : editTarget ? 'Update' : 'Simpan' }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- CLASS PICKER -->
    <Modal v-if="showClassPicker" title="Pilih Kelas" @close="showClassPicker = false">
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="!classFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickClass('')"
          >
            Semua kelas
          </button>
        </li>
        <li v-for="c in classes" :key="c.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="c.id === classFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickClass(c.id)"
          >
            {{ c.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- SUBJECT PICKER -->
    <Modal v-if="showSubjectPicker" title="Pilih Mapel" @close="showSubjectPicker = false">
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="!subjectFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickSubject('')"
          >
            Semua mapel
          </button>
        </li>
        <li v-for="s in subjects" :key="s.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="s.id === subjectFilter ? 'bg-brand-cobalt/5 font-bold text-brand-cobalt' : ''"
            @click="pickSubject(s.id)"
          >
            {{ s.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />

    <!-- Suppress unused-warning for static label map referenced from
         shared components via prop binding -->
    <span v-if="false">{{ ACTIVITY_TYPE_LABELS }}</span>
  </div>
</template>
