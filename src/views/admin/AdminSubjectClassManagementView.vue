<!--
  AdminSubjectClassManagementView.vue — admin subject↔class management.

  Drill-in page from AdminSubjectManagementView. Lists classes attached
  to one subject, with:
    - Bulk attach (multi-select from unattached classes)
    - Detach (single or bulk)

  Route: /admin/subjects/:subjectId/classes
-->
<script setup lang="ts">
import { computed, onMounted, ref, shallowRef } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { SubjectService } from '@/services/subjects.service';
import { ClassroomService } from '@/services/classrooms.service';
import type { Subject, Classroom } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

interface AttachedClassRow {
  id: string;
  name: string;
  grade_level?: string | null;
  homeroom_teacher_name?: string | null;
  student_count?: number;
}

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const subjectId = computed(() => String(route.params.subjectId ?? ''));

const subject = shallowRef<Subject | null>(null);
const attached = shallowRef<AttachedClassRow[]>([]);
const allClasses = shallowRef<Classroom[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const selectedIds = ref<Set<string>>(new Set());

const showBulkAttach = ref(false);
const bulkAttachIds = ref<Set<string>>(new Set());
const bulkAttachSearch = ref('');
const isAttaching = ref(false);

const detachConfirmId = ref<string | null>(null);
const isDetaching = ref(false);

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const [s, list, cls] = await Promise.all([
      SubjectService.get(subjectId.value),
      SubjectService.getAttachedClasses(subjectId.value),
      ClassroomService.list({ per_page: 200 }),
    ]);
    subject.value = s;
    attached.value = list;
    allClasses.value = cls.items;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

const listState = computed<AsyncState<AttachedClassRow[]>>(() => {
  if (isLoading.value && attached.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (attached.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: attached.value };
});

// Unattached candidates for bulk-attach picker.
const unattached = computed(() => {
  const attachedIds = new Set(attached.value.map((c) => c.id));
  let list = allClasses.value.filter((c) => !attachedIds.has(c.id));
  const q = bulkAttachSearch.value.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        (c.grade_level ?? '').toLowerCase().includes(q),
    );
  }
  return list.sort((a, b) => a.name.localeCompare(b.name, 'id'));
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'layers',
    label: t('admin.sekolah.subject_class.kpi_attached'),
    value: attached.value.length,
    tone: 'brand',
  },
  {
    icon: 'users',
    label: t('admin.sekolah.subject_class.kpi_total_students'),
    value: attached.value.reduce((s, c) => s + (c.student_count ?? 0), 0),
    tone: 'violet',
  },
  {
    icon: 'plus',
    label: t('admin.sekolah.subject_class.kpi_unattached'),
    value: unattached.value.length,
    tone: unattached.value.length > 0 ? 'amber' : 'slate',
  },
]);

// ── Selection ──
function toggleSelect(id: string) {
  const set = new Set(selectedIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  selectedIds.value = set;
}
function selectAll() {
  if (selectedIds.value.size === attached.value.length) {
    selectedIds.value = new Set();
  } else {
    selectedIds.value = new Set(attached.value.map((c) => c.id));
  }
}
function clearSelection() {
  selectedIds.value = new Set();
}

async function detachOne(id: string) {
  isDetaching.value = true;
  try {
    await SubjectService.detachClass(subjectId.value, id);
    toast.value = { message: t('admin.sekolah.subject_class.toast_detached_single'), tone: 'success' };
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDetaching.value = false;
    detachConfirmId.value = null;
  }
}

async function detachSelected() {
  const ids = Array.from(selectedIds.value);
  if (ids.length === 0) return;
  isDetaching.value = true;
  try {
    const res = await SubjectService.bulkDetach(subjectId.value, ids);
    toast.value = {
      message: res.failed > 0
        ? t('admin.sekolah.subject_class.toast_detached_with_failed', { detached: res.detached, failed: res.failed })
        : t('admin.sekolah.subject_class.toast_detached', { detached: res.detached }),
      tone: 'success',
    };
    clearSelection();
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDetaching.value = false;
  }
}

// ── Bulk attach ──
function toggleBulkAttach(id: string) {
  const set = new Set(bulkAttachIds.value);
  if (set.has(id)) set.delete(id);
  else set.add(id);
  bulkAttachIds.value = set;
}

function openBulkAttach() {
  bulkAttachIds.value = new Set();
  bulkAttachSearch.value = '';
  showBulkAttach.value = true;
}

async function submitBulkAttach() {
  const ids = Array.from(bulkAttachIds.value);
  if (ids.length === 0) return;
  isAttaching.value = true;
  try {
    const res = await SubjectService.bulkAttach(subjectId.value, ids);
    toast.value = {
      message: res.failed > 0
        ? t('admin.sekolah.subject_class.toast_attached_with_failed', { attached: res.attached, failed: res.failed })
        : t('admin.sekolah.subject_class.toast_attached', { attached: res.attached }),
      tone: 'success',
    };
    showBulkAttach.value = false;
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isAttaching.value = false;
  }
}

function goBack() {
  router.push({ name: 'admin.subjects' });
}

const headerMeta = computed(() => {
  if (!subject.value) return '';
  return subject.value.code
    ? t('admin.sekolah.subject_class.header_meta_with_code', { count: attached.value.length, code: subject.value.code })
    : t('admin.sekolah.subject_class.header_meta', { count: attached.value.length });
});

const detachMessage = computed(() =>
  t('admin.sekolah.subject_class.detach_message', { name: subject.value?.name ?? t('admin.sekolah.subject_class.fallback_subject') }),
);

const bulkAttachSubtitle = computed(() =>
  t('admin.sekolah.subject_class.bulk_attach_subtitle', { name: subject.value?.name ?? '' }),
);
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('admin.sekolah.subject_class.back_to_subjects') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.subject_class.header_kicker')"
      :title="subject?.name ?? t('admin.sekolah.subject_class.loading')"
      :meta="headerMeta"
    >
      <Button variant="primary" size="sm" @click="openBulkAttach">
        <NavIcon name="plus" :size="12" />
        {{ t('admin.sekolah.subject_class.add_class') }}
      </Button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.subject_class.empty_title')"
      :empty-description="t('admin.sekolah.subject_class.empty_description')"
      empty-icon="layers"
      @retry="load"
    >
      <template #default>
        <div v-if="selectedIds.size > 0" class="flex items-center justify-between gap-2 bg-role-admin/5 border border-role-admin/20 rounded-2xl px-3 py-2">
          <button
            type="button"
            class="text-[11px] font-bold text-role-admin hover:underline"
            @click="selectAll"
          >
            {{ selectedIds.size === attached.length ? t('admin.sekolah.subject_class.unselect_all') : t('admin.sekolah.subject_class.select_all') }}
          </button>
          <span class="text-[11px] font-bold text-slate-700">{{ t('admin.sekolah.subject_class.selected_count', { count: selectedIds.size }) }}</span>
          <div class="flex items-center gap-1">
            <Button variant="secondary" size="sm" @click="clearSelection">{{ t('admin.sekolah.subject_class.cancel') }}</Button>
            <Button variant="danger" size="sm" :loading="isDetaching" @click="detachSelected">
              {{ t('admin.sekolah.subject_class.detach_bulk', { count: selectedIds.size }) }}
            </Button>
          </div>
        </div>

        <ul class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
          <li
            v-for="(c, idx) in attached"
            :key="c.id"
            class="px-4 py-3 flex items-center gap-3 hover:bg-slate-50 transition-colors cursor-pointer"
            :class="[
              idx > 0 ? 'border-t border-slate-100' : '',
              selectedIds.has(c.id) ? 'bg-role-admin/5' : '',
            ]"
            @click="toggleSelect(c.id)"
          >
            <input
              type="checkbox"
              class="w-4 h-4 accent-role-admin flex-shrink-0"
              :checked="selectedIds.has(c.id)"
              @click.stop="toggleSelect(c.id)"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">{{ c.name }}</p>
              <p class="text-[11px] text-slate-500 truncate">
                <span v-if="c.grade_level">{{ t('admin.sekolah.subject_class.tingkat_label', { level: c.grade_level }) }} · </span>
                <span>{{ t('admin.sekolah.subject_class.student_count', { count: c.student_count ?? 0 }) }}</span>
                <span v-if="c.homeroom_teacher_name"> · {{ t('admin.sekolah.subject_class.homeroom_label', { name: c.homeroom_teacher_name }) }}</span>
              </p>
            </div>
            <button
              type="button"
              class="text-[11px] font-bold text-status-danger hover:underline px-2 py-1"
              @click.stop="detachConfirmId = c.id"
            >
              {{ t('admin.sekolah.subject_class.detach') }}
            </button>
          </li>
        </ul>
      </template>
    </AsyncView>

    <!-- Bulk attach modal -->
    <Modal
      v-if="showBulkAttach"
      :title="t('admin.sekolah.subject_class.bulk_attach_title')"
      :subtitle="bulkAttachSubtitle"
      size="lg"
      @close="showBulkAttach = false"
    >
      <div class="space-y-3">
        <input
          v-model="bulkAttachSearch"
          type="search"
          :placeholder="t('admin.sekolah.subject_class.bulk_search_placeholder')"
          class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        />

        <p class="text-[11px] font-bold text-slate-500">
          {{ t('admin.sekolah.subject_class.bulk_selected_label', { selected: bulkAttachIds.size, total: unattached.length }) }}
        </p>

        <div
          v-if="unattached.length === 0"
          class="text-center text-[12px] text-slate-500 py-8"
        >
          {{ t('admin.sekolah.subject_class.all_attached') }}
        </div>
        <div
          v-else
          class="max-h-72 overflow-y-auto bg-slate-50 rounded-xl divide-y divide-slate-100"
        >
          <label
            v-for="c in unattached"
            :key="c.id"
            class="flex items-center gap-2 px-3 py-2 cursor-pointer hover:bg-white"
          >
            <input
              type="checkbox"
              class="w-4 h-4 accent-role-admin"
              :checked="bulkAttachIds.has(c.id)"
              @change="toggleBulkAttach(c.id)"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">{{ c.name }}</p>
              <p v-if="c.grade_level" class="text-[10px] text-slate-500">
                {{ t('admin.sekolah.subject_class.tingkat_with_count', { level: c.grade_level, count: c.student_count }) }}
              </p>
            </div>
          </label>
        </div>

        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="showBulkAttach = false">{{ t('admin.sekolah.subject_class.cancel') }}</Button>
          <Button
            variant="primary"
            block
            :loading="isAttaching"
            :disabled="bulkAttachIds.size === 0 || isAttaching"
            @click="submitBulkAttach"
          >
            {{ t('admin.sekolah.subject_class.add_count', { count: bulkAttachIds.size }) }}
          </Button>
        </div>
      </div>
    </Modal>

    <ConfirmationDialog
      v-if="detachConfirmId"
      :title="t('admin.sekolah.subject_class.detach_title')"
      :message="detachMessage"
      :confirm-label="t('admin.sekolah.subject_class.detach')"
      danger
      :loading="isDetaching"
      @close="detachConfirmId = null"
      @confirm="detachConfirmId && detachOne(detachConfirmId)"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
