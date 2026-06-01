<!--
  AdminAnnouncementView.vue — school-wide announcement broadcaster.

  Web port of Flutter's `admin_announcement_screen.dart`. Same flow
  shape as Jadwal/Presensi for consistency:
    1. <BrandPageHeader> (admin) with "+ Buat pengumuman" action
    2. <KpiStripCards> — Total / Terkirim / Terjadwal / Draft
    3. <PageFilterToolbar> with Status + Prioritas + Audiens chips + search
    4. Lifecycle-grouped list: Disematkan / Terjadwal / Terkirim / Draft
       — uses shared <AnnouncementCard>
    5. Compose modal (Priority + Audience matrix + Schedule + Pin)
    6. Detail modal (shared) with Edit + Delete actions
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { AnnouncementService } from '@/services/announcements.service';
import { ClassroomService } from '@/services/classrooms.service';
import {
  bucketByLifecycle,
  type Announcement,
  type AnnouncementAudience,
  type AnnouncementCategory,
  type AnnouncementFilterOptions,
  type AnnouncementPriority,
  type AnnouncementStatus,
} from '@/types/announcements';
import type { Classroom } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import AnnouncementCard from '@/components/feature/AnnouncementCard.vue';
import AnnouncementDetailModal from '@/components/feature/AnnouncementDetailModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const items = ref<Announcement[]>([]);
const classes = ref<Classroom[]>([]);
const filterOptions = ref<AnnouncementFilterOptions>({
  priority_options: [],
  target_options: [],
  status_options: [],
});
const isLoading = ref(true);
const error = ref<string | null>(null);

// ── Filters (Flutter parity: Status + Priority + Audience + search) ──
type StatusFilter = 'all' | AnnouncementStatus;
type PriorityFilter = 'all' | AnnouncementPriority;
type AudienceFilter = 'all' | 'teacher' | 'student' | 'parent';

const statusFilter = ref<StatusFilter>('all');
const priorityFilter = ref<PriorityFilter>('all');
const audienceFilter = ref<AudienceFilter>('all');
const searchQuery = ref('');

const showStatusPicker = ref(false);
const showPriorityPicker = ref(false);
const showAudiencePicker = ref(false);

const STATUS_OPTIONS: { key: StatusFilter; label: string }[] = [
  { key: 'all', label: 'Semua status' },
  { key: 'draft', label: 'Draft' },
  { key: 'terjadwal', label: 'Terjadwal' },
  { key: 'terkirim', label: 'Terkirim' },
  { key: 'kedaluwarsa', label: 'Kedaluwarsa' },
  { key: 'archived', label: 'Arsip' },
];
const PRIORITY_OPTIONS: { key: PriorityFilter; label: string }[] = [
  { key: 'all', label: 'Semua prioritas' },
  { key: 'penting', label: 'Penting' },
  { key: 'biasa', label: 'Biasa' },
];
const AUDIENCE_OPTIONS: { key: AudienceFilter; label: string }[] = [
  { key: 'all', label: 'Semua audiens' },
  { key: 'teacher', label: 'Guru' },
  { key: 'student', label: 'Siswa' },
  { key: 'parent', label: 'Wali murid' },
];

const activeStatus = computed(
  () =>
    STATUS_OPTIONS.find((s) => s.key === statusFilter.value) ??
    STATUS_OPTIONS[0],
);
const activePriority = computed(
  () =>
    PRIORITY_OPTIONS.find((p) => p.key === priorityFilter.value) ??
    PRIORITY_OPTIONS[0],
);
const activeAudience = computed(
  () =>
    AUDIENCE_OPTIONS.find((a) => a.key === audienceFilter.value) ??
    AUDIENCE_OPTIONS[0],
);

// ── Compose / detail state ──
const showCompose = ref(false);
const editingId = ref<string | null>(null);
const detail = ref<Announcement | null>(null);
const deleteTarget = ref<Announcement | null>(null);
const isSaving = ref(false);
const previewReach = ref<number | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const form = reactive({
  title: '',
  body: '',
  category: 'pengumuman' as AnnouncementCategory,
  priority: 'biasa' as AnnouncementPriority,
  audience: 'all' as AnnouncementAudience,
  target_ids: [] as string[],
  scheduled_at: '' as string,
  is_pinned: false,
});

// ── Filtered + grouped ──
const filtered = computed<Announcement[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return items.value.filter((a) => {
    if (priorityFilter.value !== 'all') {
      const ap = a.priority ?? (a.category === 'penting' ? 'penting' : 'biasa');
      if (ap !== priorityFilter.value) return false;
    }
    if (statusFilter.value !== 'all' && a.status !== statusFilter.value)
      return false;
    if (q) {
      const blob = `${a.title} ${a.body}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

const grouped = computed(() => bucketByLifecycle(filtered.value));

const state = computed<AsyncState<Announcement[]>>(() => {
  if (isLoading.value && items.value.length === 0)
    return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filtered.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filtered.value };
});

// ── KPI ──
const draftCount = computed(
  () => items.value.filter((a) => a.status === 'draft').length,
);
const scheduledCount = computed(
  () =>
    items.value.filter((a) => {
      if (a.status === 'terjadwal') return true;
      const ts = a.scheduled_at ? Date.parse(a.scheduled_at) : NaN;
      return !Number.isNaN(ts) && ts > Date.now();
    }).length,
);
const publishedCount = computed(
  () =>
    items.value.length -
    draftCount.value -
    scheduledCount.value -
    items.value.filter((a) => a.status === 'kedaluwarsa').length,
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'megaphone',
    label: 'Total',
    value: items.value.length,
    tone: 'slate',
  },
  {
    icon: 'check-circle',
    label: 'Terkirim',
    value: Math.max(0, publishedCount.value),
    tone: 'green',
    accented: true,
  },
  {
    icon: 'calendar',
    label: 'Terjadwal',
    value: scheduledCount.value,
    tone: 'amber',
  },
  {
    icon: 'file-text',
    label: 'Draft',
    value: draftCount.value,
    tone: 'violet',
  },
]);

// ── Loaders ──
async function reload() {
  isLoading.value = true;
  error.value = null;
  try {
    const { items: list } = await AnnouncementService.list({
      per_page: 100,
      priority:
        priorityFilter.value === 'all' ? null : priorityFilter.value,
      status: statusFilter.value === 'all' ? null : statusFilter.value,
      audience:
        audienceFilter.value === 'all' ? null : audienceFilter.value,
      search: searchQuery.value || undefined,
    });
    items.value = [...list].sort((a, b) =>
      (b.published_at ?? b.created_at).localeCompare(
        a.published_at ?? a.created_at,
      ),
    );
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await Promise.all([
    reload(),
    ClassroomService.list({ per_page: 100 }).then((r) => {
      classes.value = r.items;
    }),
    AnnouncementService.filterOptions().then((opts) => {
      filterOptions.value = opts;
    }),
  ]);
});

useAcademicYearWatcher(() => reload());

let searchTimer: ReturnType<typeof setTimeout> | null = null;
function onSearchInput(v: string) {
  searchQuery.value = v;
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => reload(), 300);
}

// ── Compose actions ──
function resetForm() {
  form.title = '';
  form.body = '';
  form.category = 'pengumuman';
  form.priority = 'biasa';
  form.audience = 'all';
  form.target_ids = [];
  form.scheduled_at = '';
  form.is_pinned = false;
  previewReach.value = null;
  editingId.value = null;
}

function openCompose() {
  resetForm();
  showCompose.value = true;
  refreshPreviewReach();
}

function openEdit(a: Announcement) {
  detail.value = null;
  editingId.value = a.id;
  form.title = a.title;
  form.body = a.body;
  form.category = a.category;
  form.priority =
    a.priority ?? (a.category === 'penting' ? 'penting' : 'biasa');
  form.audience = a.audience ?? 'all';
  form.target_ids = a.target_ids ? [...a.target_ids] : [];
  form.scheduled_at = a.scheduled_at ?? '';
  form.is_pinned = !!a.is_pinned;
  showCompose.value = true;
  refreshPreviewReach();
}

function toggleClassTarget(id: string) {
  const idx = form.target_ids.indexOf(id);
  if (idx >= 0) form.target_ids.splice(idx, 1);
  else form.target_ids.push(id);
  refreshPreviewReach();
}

let reachTimer: ReturnType<typeof setTimeout> | null = null;
function refreshPreviewReach() {
  if (reachTimer) clearTimeout(reachTimer);
  reachTimer = setTimeout(async () => {
    const res = await AnnouncementService.previewReach({
      audience: form.audience,
      target_ids: form.audience === 'all' ? [] : form.target_ids,
    });
    previewReach.value = res.reach;
  }, 250);
}

async function publish() {
  if (!form.title.trim() || !form.body.trim()) {
    toast.value = { message: 'Judul dan isi wajib diisi.', tone: 'error' };
    return;
  }
  if (form.audience === 'class' && form.target_ids.length === 0) {
    toast.value = {
      message: 'Pilih minimal satu kelas tujuan.',
      tone: 'error',
    };
    return;
  }
  isSaving.value = true;
  try {
    const payload = {
      title: form.title.trim(),
      body: form.body.trim(),
      category: form.category,
      priority: form.priority,
      audience: form.audience,
      target_ids: form.audience === 'all' ? [] : form.target_ids,
      is_pinned: form.is_pinned,
      scheduled_at: form.scheduled_at || null,
    };
    if (editingId.value) {
      await AnnouncementService.update(editingId.value, payload);
    } else {
      await AnnouncementService.create(payload);
    }
    showCompose.value = false;
    toast.value = {
      message: editingId.value
        ? 'Pengumuman diperbarui.'
        : 'Pengumuman terbit.',
      tone: 'success',
    };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

async function confirmDelete() {
  if (!deleteTarget.value) return;
  isSaving.value = true;
  try {
    await AnnouncementService.remove(deleteTarget.value.id);
    deleteTarget.value = null;
    toast.value = { message: 'Pengumuman dihapus.', tone: 'success' };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// Picker handlers
function pickStatus(k: StatusFilter) {
  statusFilter.value = k;
  showStatusPicker.value = false;
  reload();
}
function pickPriority(k: PriorityFilter) {
  priorityFilter.value = k;
  showPriorityPicker.value = false;
  reload();
}
function pickAudience(k: AudienceFilter) {
  audienceFilter.value = k;
  showAudiencePicker.value = false;
  reload();
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- ── 1. Header ────────────────────────────────────────── -->
    <BrandPageHeader
      role="admin"
      kicker="Komunikasi · Broadcast"
      title="Pengumuman Sekolah"
      :meta="`${items.length} pengumuman · ${scheduledCount} terjadwal · ${draftCount} draft`"
      :live-dot="false"
    >
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-[12px] font-bold transition-colors"
          @click="$router.push({ name: 'admin.announcements.calendar' })"
        >
          <NavIcon name="calendar" :size="13" />
          Kalender
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white text-role-admin text-[12px] font-bold hover:bg-white/90"
          @click="openCompose"
        >
          <NavIcon name="plus" :size="13" />
          Buat pengumuman
        </button>
      </div>
    </BrandPageHeader>

    <!-- ── 2. KPI strip ─────────────────────────────────────── -->
    <KpiStripCards :cards="kpiCards" />

    <!-- ── 3. Filter toolbar ────────────────────────────────── -->
    <PageFilterToolbar
      :search="searchQuery"
      search-placeholder="Cari judul atau isi…"
      @update:search="onSearchInput"
    >
      <template #chips>
        <AppFilterChip
          label="Status"
          :value="activeStatus.label"
          icon-name="check-circle"
          tone="green"
          @click="showStatusPicker = true"
        />
        <AppFilterChip
          label="Prioritas"
          :value="activePriority.label"
          icon-name="bell"
          tone="amber"
          @click="showPriorityPicker = true"
        />
        <AppFilterChip
          label="Audiens"
          :value="activeAudience.label"
          icon-name="users"
          tone="violet"
          @click="showAudiencePicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- ── 4. Body — lifecycle-grouped sections ─────────────── -->
    <AsyncView
      :state="state"
      empty-title="Belum ada pengumuman"
      empty-description="Tap 'Buat pengumuman' untuk mengirim broadcast pertama."
      @retry="reload"
    >
      <template #default>
        <div class="space-y-md">
          <!-- Pinned -->
          <section v-if="grouped.pinned.length > 0" class="space-y-2.5">
            <header class="flex items-center gap-2 px-1">
              <NavIcon name="star" :size="13" class="text-amber-600" />
              <span class="text-[11px] font-bold uppercase tracking-widest text-amber-700">Disematkan</span>
              <div class="flex-1 h-px bg-amber-200/60"></div>
              <span class="text-[10px] font-bold text-amber-700">{{ grouped.pinned.length }}</span>
            </header>
            <AnnouncementCard
              v-for="a in grouped.pinned"
              :key="a.id"
              :announcement="a"
              viewer-role="admin"
              show-delete
              @tap="detail = $event"
              @delete="deleteTarget = $event"
            />
          </section>

          <!-- Scheduled -->
          <section v-if="grouped.scheduled.length > 0" class="space-y-2.5">
            <header class="flex items-center gap-2 px-1">
              <NavIcon name="calendar" :size="13" class="text-amber-600" />
              <span class="text-[11px] font-bold uppercase tracking-widest text-slate-500">Terjadwal</span>
              <div class="flex-1 h-px bg-slate-200"></div>
              <span class="text-[10px] font-bold text-slate-500">{{ grouped.scheduled.length }}</span>
            </header>
            <AnnouncementCard
              v-for="a in grouped.scheduled"
              :key="a.id"
              :announcement="a"
              viewer-role="admin"
              show-delete
              @tap="detail = $event"
              @delete="deleteTarget = $event"
            />
          </section>

          <!-- Published -->
          <section v-if="grouped.published.length > 0" class="space-y-2.5">
            <header class="flex items-center gap-2 px-1">
              <NavIcon name="check-circle" :size="13" class="text-emerald-600" />
              <span class="text-[11px] font-bold uppercase tracking-widest text-slate-500">Terkirim</span>
              <div class="flex-1 h-px bg-slate-200"></div>
              <span class="text-[10px] font-bold text-slate-500">{{ grouped.published.length }}</span>
            </header>
            <AnnouncementCard
              v-for="a in grouped.published"
              :key="a.id"
              :announcement="a"
              viewer-role="admin"
              show-delete
              @tap="detail = $event"
              @delete="deleteTarget = $event"
            />
          </section>

          <!-- Draft -->
          <section v-if="grouped.draft.length > 0" class="space-y-2.5">
            <header class="flex items-center gap-2 px-1">
              <NavIcon name="file-text" :size="13" class="text-slate-500" />
              <span class="text-[11px] font-bold uppercase tracking-widest text-slate-500">Draft</span>
              <div class="flex-1 h-px bg-slate-200"></div>
              <span class="text-[10px] font-bold text-slate-500">{{ grouped.draft.length }}</span>
            </header>
            <AnnouncementCard
              v-for="a in grouped.draft"
              :key="a.id"
              :announcement="a"
              viewer-role="admin"
              show-delete
              @tap="detail = $event"
              @delete="deleteTarget = $event"
            />
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- ── Status picker ────────────────────────────────────── -->
    <Modal v-if="showStatusPicker" title="Filter Status" @close="showStatusPicker = false">
      <ul class="space-y-1">
        <li v-for="s in STATUS_OPTIONS" :key="s.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-role-admin/5 text-role-admin font-bold':
                s.key === statusFilter,
            }"
            @click="pickStatus(s.key)"
          >
            {{ s.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Priority picker ──────────────────────────────────── -->
    <Modal v-if="showPriorityPicker" title="Filter Prioritas" @close="showPriorityPicker = false">
      <ul class="space-y-1">
        <li v-for="p in PRIORITY_OPTIONS" :key="p.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-role-admin/5 text-role-admin font-bold':
                p.key === priorityFilter,
            }"
            @click="pickPriority(p.key)"
          >
            {{ p.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Audience picker ──────────────────────────────────── -->
    <Modal v-if="showAudiencePicker" title="Filter Audiens" @close="showAudiencePicker = false">
      <ul class="space-y-1">
        <li v-for="a in AUDIENCE_OPTIONS" :key="a.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-role-admin/5 text-role-admin font-bold':
                a.key === audienceFilter,
            }"
            @click="pickAudience(a.key)"
          >
            {{ a.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Compose modal ────────────────────────────────────── -->
    <Modal
      v-if="showCompose"
      :title="editingId ? 'Edit Pengumuman' : 'Buat Pengumuman'"
      subtitle="Akan terkirim sesuai audiens yang dipilih."
      @close="showCompose = false"
    >
      <form class="space-y-md" @submit.prevent="publish">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Kategori</label>
          <SegmentedControl
            :model-value="form.category"
            :options="[
              { key: 'pengumuman', label: 'Umum' },
              { key: 'penting', label: 'Penting' },
              { key: 'acara', label: 'Acara' },
              { key: 'libur', label: 'Libur' },
            ]"
            size="sm"
            @update:model-value="(v) => (form.category = v as AnnouncementCategory)"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Prioritas</label>
          <SegmentedControl
            :model-value="form.priority"
            :options="[
              { key: 'biasa', label: 'Biasa' },
              { key: 'penting', label: 'Penting' },
            ]"
            size="sm"
            @update:model-value="(v) => (form.priority = v as AnnouncementPriority)"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Audiens</label>
          <SegmentedControl
            :model-value="form.audience"
            :options="[
              { key: 'all', label: 'Semua' },
              { key: 'role', label: 'Per peran' },
              { key: 'class', label: 'Per kelas' },
            ]"
            size="sm"
            @update:model-value="(v) => { form.audience = v as AnnouncementAudience; refreshPreviewReach(); }"
          />
          <p
            v-if="previewReach !== null"
            class="text-[11px] text-slate-500 mt-2 inline-flex items-center gap-1.5"
          >
            <NavIcon name="users" :size="12" />
            Perkiraan jangkauan: <b class="text-slate-900">{{ previewReach }}</b> penerima
          </p>
        </div>

        <div v-if="form.audience === 'class'">
          <label class="block text-sm font-medium text-slate-700 mb-1">
            Pilih kelas ({{ form.target_ids.length }} dipilih)
          </label>
          <div class="flex flex-wrap gap-2 max-h-32 overflow-y-auto p-2 border border-slate-200 rounded-lg">
            <button
              v-for="c in classes"
              :key="c.id"
              type="button"
              class="text-[11px] font-bold px-2.5 py-1 rounded-full border"
              :class="
                form.target_ids.includes(c.id)
                  ? 'bg-role-admin text-white border-role-admin'
                  : 'bg-white text-slate-600 border-slate-200'
              "
              @click="toggleClassTarget(c.id)"
            >
              {{ c.name }}
            </button>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Judul</label>
          <input
            v-model="form.title"
            type="text"
            placeholder="Contoh: Libur Idul Adha 17-19 Juni"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Isi</label>
          <textarea
            v-model="form.body"
            rows="6"
            placeholder="Tulis isi pengumuman…"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none resize-none"
            :disabled="isSaving"
          ></textarea>
        </div>

        <!-- Schedule + Pin row -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">
              Jadwalkan kirim (opsional)
            </label>
            <input
              v-model="form.scheduled_at"
              type="datetime-local"
              class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-white"
              :disabled="isSaving"
            />
            <p class="text-[10.5px] text-slate-400 mt-1">
              Kosongkan untuk kirim segera.
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">Sematkan</label>
            <button
              type="button"
              class="w-full inline-flex items-center justify-between gap-2 px-3 py-2.5 rounded-xl border text-sm font-bold transition-colors"
              :class="
                form.is_pinned
                  ? 'bg-amber-50 border-amber-300 text-amber-700'
                  : 'bg-white border-slate-200 text-slate-600'
              "
              @click="form.is_pinned = !form.is_pinned"
            >
              <span class="inline-flex items-center gap-2">
                <NavIcon name="star" :size="14" />
                {{ form.is_pinned ? 'Disematkan di puncak' : 'Tidak disematkan' }}
              </span>
              <span
                class="w-9 h-5 rounded-full p-0.5 transition-colors"
                :class="form.is_pinned ? 'bg-amber-500' : 'bg-slate-300'"
              >
                <span
                  class="block w-4 h-4 rounded-full bg-white transition-transform"
                  :class="form.is_pinned ? 'translate-x-4' : ''"
                />
              </span>
            </button>
          </div>
        </div>

        <BottomSheetFooter
          :primary-label="
            editingId
              ? 'Simpan perubahan'
              : form.scheduled_at
                ? 'Jadwalkan'
                : 'Terbitkan'
          "
          :primary-loading="isSaving"
          @primary="publish"
          @secondary="showCompose = false"
        />
      </form>
    </Modal>

    <!-- ── Detail modal (shared) ────────────────────────────── -->
    <AnnouncementDetailModal
      v-if="detail"
      :announcement="detail"
      viewer-role="admin"
      can-edit
      can-delete
      :auto-mark-read="false"
      @close="detail = null"
      @edit="openEdit"
      @delete="(a: Announcement) => { deleteTarget = a; detail = null; }"
    />

    <ConfirmationDialog
      v-if="deleteTarget"
      :title="`Hapus '${deleteTarget.title}'?`"
      message="Tindakan ini tidak dapat dibatalkan."
      confirm-label="Hapus"
      danger
      :loading="isSaving"
      @confirm="confirmDelete"
      @close="deleteTarget = null"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
