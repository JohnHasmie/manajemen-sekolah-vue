<!--
  AdminAnnouncementView.vue — school-wide announcement broadcaster.

  Web port of Flutter's `admin_announcement_screen.dart`. Same flow
  shape as Schedule/Presensi for consistency:
    1. <BrandPageHeader> (admin) with "+ Buat announcement" action
    2. <KpiStripCards> — Total / Terkirim / Terjadwal / Draft
    3. <PageFilterToolbar> with Status + Prioritas + Audiens chips + search
    4. Lifecycle-grouped list: Disematkan / Terjadwal / Terkirim / Draft
       — uses shared <AnnouncementCard>
    5. Compose modal (Priority + Audience matrix + Schedule + Pin)
    6. Detail modal (shared) with Edit + Delete actions
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
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
import AppRichTextEditor from '@/components/ui/AppRichTextEditor.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const appToast = useToast();

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

const STATUS_OPTIONS = computed<{ key: StatusFilter; label: string }[]>(() => [
  { key: 'all', label: t('admin.announcement.allStatuses') },
  { key: 'draft', label: t('status.Draft') },
  { key: 'scheduled', label: t('admin.announcement.scheduled') },
  { key: 'published', label: t('admin.announcement.sent') },
  { key: 'expired', label: t('admin.announcement.expired') },
  { key: 'archived', label: t('admin.announcement.archive') },
]);
const PRIORITY_OPTIONS = computed<{ key: PriorityFilter; label: string }[]>(() => [
  { key: 'all', label: t('admin.announcement.allPriorities') },
  { key: 'urgent', label: t('admin.announcement.urgent') },
  { key: 'high', label: t('admin.announcement.important') },
  { key: 'normal', label: t('admin.announcement.normal') },
  { key: 'low', label: t('admin.announcement.low') },
]);
const AUDIENCE_OPTIONS = computed<{ key: AudienceFilter; label: string }[]>(() => [
  { key: 'all', label: t('admin.announcement.allAudiences') },
  { key: 'teacher', label: t('role.teacher') },
  { key: 'student', label: t('role.student') },
  { key: 'parent', label: t('role.parent') },
]);

const activeStatus = computed(
  () =>
    STATUS_OPTIONS.value.find((s) => s.key === statusFilter.value) ??
    STATUS_OPTIONS.value[0],
);
const activePriority = computed(
  () =>
    PRIORITY_OPTIONS.value.find((p) => p.key === priorityFilter.value) ??
    PRIORITY_OPTIONS.value[0],
);
const activeAudience = computed(
  () =>
    AUDIENCE_OPTIONS.value.find((a) => a.key === audienceFilter.value) ??
    AUDIENCE_OPTIONS.value[0],
);

// ── Compose / detail state ──
const showCompose = ref(false);
const editingId = ref<string | null>(null);
const detail = ref<Announcement | null>(null);
const deleteTarget = ref<Announcement | null>(null);
const isSaving = ref(false);
const previewReach = ref<number | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// Audience matrix (mobile parity): roles teacher / homeroom_teacher /
// parent, each targeting 'all' or specific class ids — replaces the
// old single dropdown. Keys mirror the backend's canonical English
// audience_matrix shape; legacy Indonesian aliases are still accepted
// server-side during the rollout window.
type MatrixRole = 'teacher' | 'homeroom_teacher' | 'parent';
const MATRIX_ROLES: { key: MatrixRole; label: string; perClass: boolean }[] = [
  { key: 'teacher', label: 'Guru', perClass: false },
  { key: 'homeroom_teacher', label: 'Wali Kelas', perClass: true },
  { key: 'parent', label: 'Wali Murid', perClass: true },
];
const emptyMatrix = (): Record<MatrixRole, string[]> => ({
  teacher: [],
  homeroom_teacher: [],
  parent: [],
});

const form = reactive({
  title: '',
  body: '',
  // Canonical column: `announcements.type` (was `category`).
  category: 'announcement' as AnnouncementCategory,
  priority: 'normal' as AnnouncementPriority,
  audience: 'all' as AnnouncementAudience,
  target_ids: [] as string[],
  // Mobile-parity audience matrix. Each role holds 'all' or specific class ids.
  audienceMatrix: { teacher: [], homeroom_teacher: [], parent: [] } as Record<
    MatrixRole,
    (string)[]
  >,
  scheduled_at: '' as string,
  event_at: '' as string,
  event_location: '' as string,
  is_pinned: false,
  pinned_until: '' as string,
});

// ── Filtered + grouped ──
const filtered = computed<Announcement[]>(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return items.value.filter((a) => {
    if (priorityFilter.value !== 'all') {
      const ap = a.priority ?? 'normal';
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
      if (a.status === 'scheduled') return true;
      const ts = a.scheduled_at ? Date.parse(a.scheduled_at) : NaN;
      return !Number.isNaN(ts) && ts > Date.now();
    }).length,
);
const publishedCount = computed(
  () =>
    items.value.length -
    draftCount.value -
    scheduledCount.value -
    items.value.filter((a) => a.status === 'expired').length,
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'megaphone',
    label: t('common.total'),
    value: items.value.length,
    tone: 'slate',
  },
  {
    icon: 'check-circle',
    label: t('admin.announcement.sent'),
    value: Math.max(0, publishedCount.value),
    tone: 'green',
    accented: true,
  },
  {
    icon: 'calendar',
    label: t('admin.announcement.scheduled'),
    value: scheduledCount.value,
    tone: 'amber',
  },
  {
    icon: 'file-text',
    label: t('status.Draft'),
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
  form.category = 'announcement';
  form.priority = 'normal';
  form.audience = 'all';
  form.target_ids = [];
  form.audienceMatrix = emptyMatrix();
  form.scheduled_at = '';
  form.event_at = '';
  form.event_location = '';
  form.is_pinned = false;
  form.pinned_until = '';
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
  form.priority = a.priority ?? 'normal';
  form.audience = a.audience ?? 'all';
  form.target_ids = a.target_ids ? [...a.target_ids] : [];
  // Rehydrate the audience matrix from the stored value, normalising each
  // cell to string[] (the API may send numbers/ints for tingkat/class).
  const m = (a.audience_matrix ?? {}) as Record<string, unknown>;
  const cell = (k: string): string[] =>
    Array.isArray(m[k]) ? (m[k] as unknown[]).map((v) => String(v)) : [];
  // Backend canonical is English; tolerate legacy Indonesian keys on
  // older payloads so existing drafts still load correctly.
  form.audienceMatrix = {
    teacher: cell('teacher').length ? cell('teacher') : cell('guru'),
    homeroom_teacher: cell('homeroom_teacher').length
      ? cell('homeroom_teacher')
      : cell('wali_kelas'),
    parent: cell('parent').length ? cell('parent') : cell('wali_murid'),
  };
  // Both bind to `datetime-local` inputs (YYYY-MM-DDTHH:mm), so trim the
  // ISO value from the API — otherwise the picker stays empty on edit.
  form.scheduled_at = (a.scheduled_at ?? '').slice(0, 16);
  form.event_at = (a.event_at ?? '').slice(0, 16);
  form.event_location = a.event_location ?? '';
  form.is_pinned = !!a.is_pinned;
  form.pinned_until = (a.pinned_until ?? '').slice(0, 16);
  showCompose.value = true;
  refreshPreviewReach();
}

// ── Audience matrix helpers ──
function cellHasAll(role: MatrixRole): boolean {
  return form.audienceMatrix[role].includes('all');
}
function cellHasClass(role: MatrixRole, id: string): boolean {
  return form.audienceMatrix[role].includes(id);
}
function toggleAll(role: MatrixRole) {
  form.audienceMatrix[role] = cellHasAll(role) ? [] : ['all'];
  refreshPreviewReach();
}
function toggleClass(role: MatrixRole, id: string) {
  const cell = form.audienceMatrix[role].filter((v) => v !== 'all');
  const i = cell.indexOf(id);
  if (i >= 0) cell.splice(i, 1);
  else cell.push(id);
  form.audienceMatrix[role] = cell;
  refreshPreviewReach();
}
const hasAudience = computed(() =>
  MATRIX_ROLES.some((r) => form.audienceMatrix[r.key].length > 0),
);

let reachTimer: ReturnType<typeof setTimeout> | null = null;
function refreshPreviewReach() {
  if (reachTimer) clearTimeout(reachTimer);
  reachTimer = setTimeout(async () => {
    const res = await AnnouncementService.previewReach({
      audience_matrix: form.audienceMatrix,
    });
    previewReach.value = res.reach;
  }, 250);
}

async function publish() {
  if (!form.title.trim() || !form.body.trim()) {
    toast.value = { message: t('admin.announcement.titleContentRequired'), tone: 'error' };
    return;
  }
  if (!hasAudience.value) {
    toast.value = {
      message: t('admin.announcement.selectMinOneAudience'),
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
      audience_matrix: form.audienceMatrix,
      is_pinned: form.is_pinned,
      pinned_until: form.is_pinned ? form.pinned_until || null : null,
      scheduled_at: form.scheduled_at || null,
      event_at: form.event_at || null,
      event_location: form.event_location.trim() || null,
    };
    if (editingId.value) {
      await AnnouncementService.update(editingId.value, payload);
    } else {
      await AnnouncementService.create(payload);
    }
    showCompose.value = false;
    toast.value = {
      message: editingId.value
        ? t('admin.announcement.updated')
        : t('admin.announcement.published'),
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
  // Snapshot the announcement BEFORE deleting so undo can re-post the
  // same fields as a fresh row. Announcement restore is safe because
  // there's no cascade — read-state per-recipient regenerates on
  // create, and the row that comes back has a new id that no other
  // resource references yet.
  const snapshot = { ...deleteTarget.value };
  isSaving.value = true;
  try {
    await AnnouncementService.remove(snapshot.id);
    deleteTarget.value = null;
    await reload();
    appToast.undoable(t('admin.announcement.deleted'), async () => {
      try {
        await AnnouncementService.create({
          title: snapshot.title,
          body: snapshot.body,
          type: snapshot.type,
          priority: snapshot.priority,
          status: snapshot.status,
          audience: snapshot.audience,
          role_target: snapshot.role_target,
          target_ids: snapshot.target_ids,
          audience_matrix: snapshot.audience_matrix,
          is_pinned: snapshot.is_pinned,
          scheduled_at: snapshot.scheduled_at ?? null,
          event_at: snapshot.event_at ?? null,
          event_location: snapshot.event_location ?? null,
          expires_at: snapshot.expires_at ?? null,
        });
        await reload();
        toast.value = {
          message: t('admin.announcement.restored'),
          tone: 'success',
        };
      } catch (e) {
        toast.value = {
          message: `${t('admin.announcement.restoreFailed')}: ${(e as Error).message}`,
          tone: 'error',
        };
      }
    });
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
      :kicker="t('admin.sekolah.announcement.kicker')"
      :title="t('admin.announcement.schoolAnnouncements')"
      :meta="t('admin.announcement.meta')"
      :live-dot="false"
    >
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-[12px] font-bold transition-colors"
          @click="$router.push({ name: 'admin.announcements.calendar' })"
        >
          <NavIcon name="calendar" :size="13" />
          {{ t('common.calendar') }}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white text-role-admin text-[12px] font-bold hover:bg-white/90"
          @click="openCompose"
        >
          <NavIcon name="plus" :size="13" />
          {{ t('admin.announcement.create') }}
        </button>
      </div>
    </BrandPageHeader>

    <!-- ── 2. KPI strip ─────────────────────────────────────── -->
    <KpiStripCards :cards="kpiCards" :loading="isLoading" />

    <!-- ── 3. Filter toolbar ────────────────────────────────── -->
    <PageFilterToolbar
      :search="searchQuery"
      :search-placeholder="t('admin.announcement.searchTitleContent')"
      @update:search="onSearchInput"
    >
      <template #chips>
        <AppFilterChip
          :label="t('admin.sekolah.announcement.chip_status')"
          :value="activeStatus.label"
          icon-name="check-circle"
          tone="green"
          @click="showStatusPicker = true"
        />
        <AppFilterChip
          :label="t('admin.sekolah.announcement.chip_priority')"
          :value="activePriority.label"
          icon-name="bell"
          tone="amber"
          @click="showPriorityPicker = true"
        />
        <AppFilterChip
          :label="t('admin.sekolah.announcement.chip_audience')"
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
      :empty-title="t('admin.announcement.empty')"
      :empty-description="t('admin.announcement.emptyDescription')"
      @retry="reload"
    >
      <template #default>
        <div class="space-y-md">
          <!-- Pinned -->
          <section v-if="grouped.pinned.length > 0" class="space-y-2.5">
            <header class="flex items-center gap-2 px-1">
              <NavIcon name="star" :size="13" class="text-amber-600" />
              <span class="text-2xs font-bold uppercase tracking-widest text-amber-700">{{ t('admin.announcement.pinned') }}</span>
              <div class="flex-1 h-px bg-amber-200/60"></div>
              <span class="text-3xs font-bold text-amber-700">{{ grouped.pinned.length }}</span>
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
              <span class="text-2xs font-bold uppercase tracking-widest text-tutoring-text-mid">{{ t('admin.announcement.scheduled') }}</span>
              <div class="flex-1 h-px bg-tutoring-border"></div>
              <span class="text-3xs font-bold text-tutoring-text-mid">{{ grouped.scheduled.length }}</span>
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
              <span class="text-2xs font-bold uppercase tracking-widest text-tutoring-text-mid">{{ t('admin.announcement.sent') }}</span>
              <div class="flex-1 h-px bg-tutoring-border"></div>
              <span class="text-3xs font-bold text-tutoring-text-mid">{{ grouped.published.length }}</span>
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
              <NavIcon name="file-text" :size="13" class="text-tutoring-text-mid" />
              <span class="text-2xs font-bold uppercase tracking-widest text-tutoring-text-mid">{{ t('status.Draft') }}</span>
              <div class="flex-1 h-px bg-tutoring-border"></div>
              <span class="text-3xs font-bold text-tutoring-text-mid">{{ grouped.draft.length }}</span>
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
    <Modal v-if="showStatusPicker" :title="t('admin.announcement.filterStatus')" @close="showStatusPicker = false">
      <ul class="space-y-1">
        <li v-for="s in STATUS_OPTIONS" :key="s.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-border-soft/60"
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
    <Modal v-if="showPriorityPicker" :title="t('admin.announcement.filterPriority')" @close="showPriorityPicker = false">
      <ul class="space-y-1">
        <li v-for="p in PRIORITY_OPTIONS" :key="p.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-border-soft/60"
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
    <Modal v-if="showAudiencePicker" :title="t('admin.announcement.filterAudience')" @close="showAudiencePicker = false">
      <ul class="space-y-1">
        <li v-for="a in AUDIENCE_OPTIONS" :key="a.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-border-soft/60"
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
    <!-- xl (56rem). The default md (28rem) wrapped the rich-editor toolbar onto
         two rows and squeezed the audience matrix + writing area into a narrow
         column — this form is the densest in the app and needs the width. -->
    <Modal
      v-if="showCompose"
      size="xl"
      :title="editingId ? t('admin.announcement.editTitle') : t('admin.announcement.createTitle')"
      :subtitle="t('admin.announcement.sendToAudience')"
      @close="showCompose = false"
    >
      <form class="space-y-md" @submit.prevent="publish">
        <div>
          <label class="block text-sm font-medium text-tutoring-text-hi mb-1">{{ t('common.category') }}</label>
          <SegmentedControl
            :model-value="form.category"
            :options="[
              { key: 'announcement', label: t('admin.announcement.category') },
              { key: 'general', label: t('admin.announcement.categoryGeneral') },
              { key: 'event', label: t('admin.announcement.categoryEvent') },
              { key: 'info', label: t('admin.announcement.categoryInfo') },
            ]"
            @update:model-value="(v) => (form.category = v as AnnouncementCategory)"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-tutoring-text-hi mb-1">{{ t('common.priority') }}</label>
          <SegmentedControl
            :model-value="form.priority"
            :options="[
              { key: 'low', label: t('admin.announcement.low') },
              { key: 'normal', label: t('admin.announcement.normal') },
              { key: 'high', label: t('admin.announcement.important') },
              { key: 'urgent', label: t('admin.announcement.urgent') },
            ]"
            @update:model-value="(v) => (form.priority = v as AnnouncementPriority)"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-tutoring-text-hi mb-1">{{ t('common.audience') }}</label>
          <p class="text-2xs text-tutoring-text-mid mb-2">
            {{ t('admin.announcement.audienceHelp') }}
          </p>
          <div class="space-y-3 border border-tutoring-border-soft rounded-xl p-3">
            <div
              v-for="role in MATRIX_ROLES"
              :key="role.key"
              class="border-b border-tutoring-border-soft last:border-0 pb-3 last:pb-0"
            >
              <div class="flex items-center justify-between gap-2">
                <span class="text-sm font-semibold text-tutoring-text-hi">{{ role.label }}</span>
                <button
                  type="button"
                  class="text-2xs font-bold px-2.5 py-1 rounded-full border"
                  :class="
                    cellHasAll(role.key)
                      ? 'bg-role-admin text-white border-role-admin'
                      : 'bg-tutoring-panel text-tutoring-text-mid border-tutoring-border-soft'
                  "
                  @click="toggleAll(role.key)"
                >
                  {{ role.perClass ? t('admin.announcement.allClasses') : t('admin.announcement.allTeachers') }}
                </button>
              </div>
              <div
                v-if="role.perClass && !cellHasAll(role.key)"
                class="flex flex-wrap gap-2 max-h-28 overflow-y-auto mt-2"
              >
                <button
                  v-for="c in classes"
                  :key="c.id"
                  type="button"
                  class="text-2xs font-bold px-2.5 py-1 rounded-full border"
                  :class="
                    cellHasClass(role.key, c.id)
                      ? 'bg-role-admin text-white border-role-admin'
                      : 'bg-tutoring-panel text-tutoring-text-mid border-tutoring-border-soft'
                  "
                  @click="toggleClass(role.key, c.id)"
                >
                  {{ c.name }}
                </button>
                <span v-if="classes.length === 0" class="text-2xs text-tutoring-text-lo">
                  {{ t('admin.announcement.noClassesYet') }}
                </span>
              </div>
            </div>
          </div>
          <p
            v-if="previewReach !== null"
            class="text-2xs text-tutoring-text-mid mt-2 inline-flex items-center gap-1.5"
          >
            <NavIcon name="users" :size="12" />
            {{ t('admin.announcement.estimatedReach') }} <b class="text-tutoring-text-hi">{{ previewReach }}</b> {{ t('admin.announcement.recipients') }}
          </p>
        </div>

        <div>
          <label class="block text-sm font-medium text-tutoring-text-hi mb-1">{{ t('common.title') }}</label>
          <input
            v-model="form.title"
            type="text"
            :placeholder="t('admin.announcement.titleExample')"
            class="w-full rounded-xl border border-tutoring-border px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :disabled="isSaving"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-tutoring-text-hi mb-1">{{ t('common.content') }}</label>
          <!-- Rich text (Quill → HTML). Same engine as the mobile
               flutter_quill editor, so content round-trips between the two
               platforms. -->
          <AppRichTextEditor
            v-model:html="form.body"
            :placeholder="t('admin.announcement.contentPlaceholder')"
            :readonly="isSaving"
            :min-height="280"
          />
        </div>

        <!-- Acara (opsional) — tanggal kejadian + lokasi. Sejajar dengan
             form aplikasi (section "Acara"); backend sudah menerima
             event_at / event_location. -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
          <div>
            <label class="block text-sm font-medium text-tutoring-text-hi mb-1">
              Tanggal &amp; jam acara (opsional)
            </label>
            <input
              v-model="form.event_at"
              type="datetime-local"
              class="w-full rounded-xl border border-tutoring-border px-md py-sm text-sm text-tutoring-text-hi focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-tutoring-bg"
              :disabled="isSaving"
            />
            <p class="text-[10.5px] text-tutoring-text-lo mt-1">
              Isi kalau ini pengumuman acara (mis. rapat 25 Des) — biar muncul di
              kalender + reminder.
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-tutoring-text-hi mb-1">
              Lokasi acara (opsional)
            </label>
            <input
              v-model="form.event_location"
              type="text"
              maxlength="160"
              placeholder="mis. Aula Lt. 2"
              class="w-full rounded-xl border border-tutoring-border px-md py-sm text-sm text-tutoring-text-hi focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-tutoring-bg"
              :disabled="isSaving"
            />
          </div>
        </div>

        <!-- Schedule + Pin row -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
          <div>
            <label class="block text-sm font-medium text-tutoring-text-hi mb-1">
              {{ t('admin.announcement.scheduleSend') }}
            </label>
            <input
              v-model="form.scheduled_at"
              type="datetime-local"
              class="w-full rounded-xl border border-tutoring-border px-md py-sm text-sm text-tutoring-text-hi focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none bg-tutoring-bg"
              :disabled="isSaving"
            />
            <p class="text-[10.5px] text-tutoring-text-lo mt-1">
              {{ t('admin.announcement.sendImmediately') }}
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-tutoring-text-hi mb-1">{{ t('admin.announcement.pinLabel') }}</label>
            <button
              type="button"
              class="w-full inline-flex items-center justify-between gap-2 px-3 py-2.5 rounded-xl border text-sm font-bold transition-colors"
              :class="
                form.is_pinned
                  ? 'bg-amber-50 border-amber-300 text-amber-700'
                  : 'bg-tutoring-panel border-tutoring-border-soft text-tutoring-text-mid'
              "
              @click="form.is_pinned = !form.is_pinned"
            >
              <span class="inline-flex items-center gap-2">
                <NavIcon name="star" :size="14" />
                {{ form.is_pinned ? t('admin.announcement.pinnedToTop') : t('admin.announcement.notPinned') }}
              </span>
              <span
                class="w-9 h-5 rounded-full p-0.5 transition-colors"
                :class="form.is_pinned ? 'bg-amber-500' : 'bg-tutoring-border'"
              >
                <span
                  class="block w-4 h-4 rounded-full bg-white transition-transform"
                  :class="form.is_pinned ? 'translate-x-4' : ''"
                />
              </span>
            </button>
            <template v-if="form.is_pinned">
              <label
                class="block text-2xs font-semibold text-tutoring-text-mid mt-2 mb-1"
              >
                {{ t('admin.announcement.pinnedUntilLabel') }}
              </label>
              <input
                v-model="form.pinned_until"
                type="datetime-local"
                class="w-full px-3 py-2 rounded-xl border border-tutoring-border-soft bg-tutoring-panel text-sm text-tutoring-text-hi"
              />
              <p
                v-if="!form.pinned_until"
                class="mt-1 text-2xs text-tutoring-text-mid"
              >
                {{ t('admin.announcement.pinnedIndefinite') }}
              </p>
            </template>
          </div>
        </div>

        <BottomSheetFooter
          :primary-label="
            editingId
              ? t('common.saveChanges')
              : form.scheduled_at
                ? t('admin.announcement.scheduleButton')
                : t('admin.announcement.publishButton')
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
      :confirm-label="t('common.delete')"
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
