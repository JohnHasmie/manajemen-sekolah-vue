<!--
  TeacherAnnouncementView.vue — Announcement untuk homeroom teacher / teacher.

  Web port of Flutter's `teacher_announcement_screen.dart`. Layout
  mirrors Schedule / Presensi for consistency:
    1. <BrandPageHeader> (teacher) with "+ Tulis announcement" action
    2. <KpiStripCards> — Total / Pekan ini / Total dibaca / Belum dibaca
    3. <PageFilterToolbar> with Priority + Status filter chips + search
    4. <AsyncView> wrapping a vertical list of <AnnouncementCard>s
    5. Compose modal + delete confirmation + detail modal (shared)
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { AnnouncementService } from '@/services/announcements.service';
import { ClassroomService } from '@/services/classrooms.service';
import type {
  Announcement,
  AnnouncementCategory,
  AnnouncementPriority,
  AnnouncementStatus,
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

const { t } = useI18n();

const items = ref<Announcement[]>([]);
const classes = ref<Classroom[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);

// ── Filters (Flutter parity, canonical English post-rename) ──
type PriorityFilter = 'all' | AnnouncementPriority;
type StatusFilter = 'all' | 'active' | 'scheduled' | 'expired';
const priorityFilter = ref<PriorityFilter>('all');
const statusFilter = ref<StatusFilter>('all');
const searchQuery = ref('');

const showPriorityPicker = ref(false);
const showStatusPicker = ref(false);

const PRIORITY_OPTIONS = computed<{ key: PriorityFilter; label: string }[]>(() => [
  { key: 'all', label: t('common.all') },
  { key: 'urgent', label: t('teacher.announcement.urgent') },
  { key: 'high', label: t('teacher.announcement.important') },
  { key: 'normal', label: t('teacher.announcement.normal') },
  { key: 'low', label: t('teacher.announcement.low') },
]);
const STATUS_OPTIONS = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('common.all') },
  { key: 'active', label: t('common.active') },
  { key: 'scheduled', label: t('teacher.announcement.scheduled') },
  { key: 'expired', label: t('teacher.announcement.expired') },
]);

const activePriority = computed(
  () =>
    PRIORITY_OPTIONS.value.find((p) => p.key === priorityFilter.value) ??
    PRIORITY_OPTIONS.value[0],
);
const activeStatus = computed(
  () =>
    STATUS_OPTIONS.value.find((s) => s.key === statusFilter.value) ??
    STATUS_OPTIONS.value[0],
);

// ── Compose modal state ──
const showCompose = ref(false);
const editingId = ref<string | null>(null);
const detail = ref<Announcement | null>(null);
const deleteTarget = ref<Announcement | null>(null);
const isSaving = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const form = reactive({
  title: '',
  body: '',
  category: 'announcement' as AnnouncementCategory,
  /**
   * Target class IDs — multi-select. Mobile parity: an empty selection
   * is rejected on publish, and the teacher can pick "Semua kelas saya"
   * (all classes the form has loaded) as a shortcut.
   */
  class_ids: [] as string[],
});

// ── Derived (client-side filter on top of server-side fetch) ──
const filtered = computed<Announcement[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return items.value.filter((a) => {
    if (priorityFilter.value !== 'all') {
      const ap = a.priority ?? 'normal';
      if (ap !== priorityFilter.value) return false;
    }
    if (statusFilter.value !== 'all') {
      const mapped = lifecycleOf(a);
      if (mapped !== statusFilter.value) return false;
    }
    if (q) {
      const blob = `${a.title} ${a.body}`.toLowerCase();
      if (!blob.includes(q)) return false;
    }
    return true;
  });
});

function lifecycleOf(a: Announcement): StatusFilter {
  if (a.status === 'scheduled') return 'scheduled';
  if (a.status === 'expired') return 'expired';
  const now = Date.now();
  const sched = a.scheduled_at ? Date.parse(a.scheduled_at) : NaN;
  const expires = a.expires_at ? Date.parse(a.expires_at) : NaN;
  if (!Number.isNaN(sched) && sched > now) return 'scheduled';
  if (!Number.isNaN(expires) && expires < now) return 'expired';
  return 'active';
}

const state = computed<AsyncState<Announcement[]>>(() => {
  if (isLoading.value && items.value.length === 0)
    return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filtered.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filtered.value };
});

// ── KPI ──
const publishedThisWeek = computed(() => {
  const cutoff = Date.now() - 7 * 86_400_000;
  return items.value.filter(
    (a) => Date.parse(a.published_at ?? a.created_at) >= cutoff,
  ).length;
});
const totalReads = computed(() =>
  items.value.reduce((s, a) => s + (a.read_count ?? 0), 0),
);
const totalRecipients = computed(() =>
  items.value.reduce((s, a) => s + (a.total_recipients ?? 0), 0),
);
const readPct = computed(() =>
  totalRecipients.value > 0
    ? Math.round((totalReads.value / totalRecipients.value) * 100)
    : 0,
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'megaphone',
    label: 'Total Terbit',
    value: items.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'calendar',
    label: 'Pekan Ini',
    value: publishedThisWeek.value,
    suffix: 'sesi',
    tone: 'violet',
  },
  {
    icon: 'eye',
    label: 'Total Dibaca',
    value: totalReads.value,
    suffix: `· ${readPct.value}%`,
    tone: 'green',
  },
  {
    icon: 'bell',
    label: 'Belum Dibaca',
    value: Math.max(0, totalRecipients.value - totalReads.value),
    suffix: 'wali',
    tone:
      totalRecipients.value - totalReads.value > 0 ? 'amber' : 'green',
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
      status:
        statusFilter.value === 'all'
          ? null
          : statusFilter.value === 'active'
            ? 'published'
            : (statusFilter.value as AnnouncementStatus),
      search: searchQuery.value || undefined,
    });
    // Newest first.
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

async function loadClasses() {
  try {
    classes.value = (await ClassroomService.list({ per_page: 100 })).items;
    if (form.class_ids.length === 0 && classes.value[0])
      form.class_ids = [classes.value[0].id];
  } catch {
    // ignore
  }
}

onMounted(async () => {
  await Promise.all([reload(), loadClasses()]);
});

useAcademicYearWatcher(() => reload());

// Light search debounce — refetch after typing pauses.
let searchTimer: ReturnType<typeof setTimeout> | null = null;
function onSearchInput(v: string) {
  searchQuery.value = v;
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => reload(), 300);
}

// ── Compose / delete actions ──
function resetForm() {
  form.title = '';
  form.body = '';
  form.category = 'announcement';
  form.class_ids = classes.value[0] ? [classes.value[0].id] : [];
  editingId.value = null;
}

function toggleClassId(id: string) {
  const i = form.class_ids.indexOf(id);
  if (i >= 0) form.class_ids.splice(i, 1);
  else form.class_ids.push(id);
}

function selectAllClasses() {
  form.class_ids = classes.value.map((c) => c.id);
}

function clearClassSelection() {
  form.class_ids = [];
}

function openCompose() {
  resetForm();
  showCompose.value = true;
}

async function publish() {
  if (!form.title.trim() || !form.body.trim()) {
    toast.value = { message: t('teacher.announcement.titleContentRequired'), tone: 'error' };
    return;
  }
  if (form.class_ids.length === 0) {
    toast.value = { message: t('teacher.announcement.selectClassRequired'), tone: 'error' };
    return;
  }
  isSaving.value = true;
  try {
    if (editingId.value) {
      await AnnouncementService.update(editingId.value, {
        title: form.title.trim(),
        body: form.body.trim(),
        category: form.category,
        audience: 'class',
        target_ids: [...form.class_ids],
      });
    } else {
      await AnnouncementService.create({
        title: form.title.trim(),
        body: form.body.trim(),
        category: form.category,
        priority: form.category === 'announcement' ? 'high' : 'normal',
        audience: 'class',
        target_ids: [...form.class_ids],
      });
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

function openEdit(a: Announcement) {
  detail.value = null;
  editingId.value = a.id;
  form.title = a.title;
  form.body = a.body;
  form.category = a.category;
  form.class_ids =
    a.target_ids && a.target_ids.length > 0
      ? [...a.target_ids]
      : classes.value[0]
        ? [classes.value[0].id]
        : [];
  showCompose.value = true;
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

function pickPriority(k: PriorityFilter) {
  priorityFilter.value = k;
  showPriorityPicker.value = false;
  reload();
}
function pickStatus(k: StatusFilter) {
  statusFilter.value = k;
  showStatusPicker.value = false;
  reload();
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- ── 1. Header ────────────────────────────────────────── -->
    <BrandPageHeader
      role="guru"
      kicker="Komunikasi · Pengumuman"
      title="Pengumuman"
      :meta="`${items.length} pengumuman · ${publishedThisWeek} terbit minggu ini`"
      :live-dot="false"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white text-brand-cobalt text-[12px] font-bold hover:bg-white/90"
        @click="openCompose"
      >
        <NavIcon name="plus" :size="13" />
        Tulis pengumuman
      </button>
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
          label="Prioritas"
          :value="activePriority.label"
          icon-name="bell"
          tone="amber"
          @click="showPriorityPicker = true"
        />
        <AppFilterChip
          label="Status"
          :value="activeStatus.label"
          icon-name="calendar"
          tone="violet"
          @click="showStatusPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- ── 4. Body ──────────────────────────────────────────── -->
    <AsyncView
      :state="state"
      empty-title="Belum ada pengumuman"
      empty-description="Tap 'Tulis pengumuman' untuk membuat yang baru."
      @retry="reload"
    >
      <template #default>
        <section class="space-y-2.5">
          <AnnouncementCard
            v-for="a in filtered"
            :key="a.id"
            :announcement="a"
            viewer-role="guru"
            show-delete
            @tap="detail = $event"
            @delete="deleteTarget = $event"
          />
        </section>
      </template>
    </AsyncView>

    <!-- ── Priority picker ──────────────────────────────────── -->
    <Modal
      v-if="showPriorityPicker"
      title="Filter Prioritas"
      @close="showPriorityPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="p in PRIORITY_OPTIONS" :key="p.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                p.key === priorityFilter,
            }"
            @click="pickPriority(p.key)"
          >
            {{ p.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Status picker ────────────────────────────────────── -->
    <Modal
      v-if="showStatusPicker"
      title="Filter Status"
      @close="showStatusPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="s in STATUS_OPTIONS" :key="s.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{
              'bg-brand-cobalt/5 text-brand-cobalt font-bold':
                s.key === statusFilter,
            }"
            @click="pickStatus(s.key)"
          >
            {{ s.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- ── Compose modal ────────────────────────────────────── -->
    <Modal
      v-if="showCompose"
      :title="editingId ? 'Edit Pengumuman' : 'Tulis Pengumuman'"
      subtitle="Akan dikirim ke wali murid kelas yang Anda pilih."
      @close="showCompose = false"
    >
      <form class="space-y-md" @submit.prevent="publish">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1"
            >Kategori</label
          >
          <SegmentedControl
            :model-value="form.category"
            :options="[
              { key: 'announcement', label: 'Pengumuman' },
              { key: 'general', label: 'Umum' },
              { key: 'event', label: 'Acara' },
              { key: 'info', label: 'Info' },
            ]"
            size="sm"
            @update:model-value="(v) => (form.category = v as AnnouncementCategory)"
          />
        </div>
        <div>
          <div class="flex items-center justify-between mb-1.5">
            <label class="block text-sm font-medium text-slate-700">
              Kelas tujuan
              <span class="text-[10px] font-bold text-slate-400 ml-1">
                ({{ form.class_ids.length }}/{{ classes.length }})
              </span>
            </label>
            <div class="flex items-center gap-2 text-[11px] font-bold">
              <button
                type="button"
                class="text-role-teacher hover:underline"
                :disabled="isSaving || classes.length === 0"
                @click="selectAllClasses"
              >
                Pilih semua
              </button>
              <span class="text-slate-300">·</span>
              <button
                type="button"
                class="text-slate-500 hover:text-slate-800"
                :disabled="isSaving || form.class_ids.length === 0"
                @click="clearClassSelection"
              >
                Bersihkan
              </button>
            </div>
          </div>
          <div
            v-if="classes.length === 0"
            class="text-[12px] text-slate-400 italic py-2"
          >
            Belum ada kelas yang Anda ampu.
          </div>
          <div v-else class="flex flex-wrap gap-1.5 max-h-40 overflow-y-auto pr-1">
            <button
              v-for="c in classes"
              :key="c.id"
              type="button"
              :disabled="isSaving"
              class="px-2.5 py-1 rounded-lg text-[12px] font-bold border transition-colors"
              :class="form.class_ids.includes(c.id)
                ? 'bg-role-teacher text-white border-role-teacher'
                : 'bg-white text-slate-600 border-slate-200 hover:border-slate-300'"
              @click="toggleClassId(c.id)"
            >
              {{ c.name }}
            </button>
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1"
            >Judul</label
          >
          <input
            v-model="form.title"
            type="text"
            placeholder="Contoh: Libur Idul Adha 17-19 Juni"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1"
            >Isi pengumuman</label
          >
          <textarea
            v-model="form.body"
            rows="6"
            placeholder="Tulis isi pengumuman…"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none resize-none"
            :disabled="isSaving"
          ></textarea>
        </div>
        <BottomSheetFooter
          :primary-label="editingId ? 'Simpan perubahan' : 'Terbitkan'"
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
      viewer-role="guru"
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
