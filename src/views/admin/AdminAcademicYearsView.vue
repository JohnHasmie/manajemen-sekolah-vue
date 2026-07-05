<!--
  AdminAcademicYearsView.vue — admin Kelola Tahun Ajaran.

  Mirrors Flutter's `KelolaTahunAjaranScreen`. Chrome:

    1. Back chevron → admin.settings.school
    2. BrandPageHeader (admin) — title + meta
    3. KpiStripCards — Total / Aktif / Arsip
    4. Add button — opens create modal
    5. List grouped by status: Current → Active → Inactive → Archived
       Each row exposes: set-current, archive/unarchive, edit, delete.

  Endpoints:
    GET    /academic-years
    GET    /academic-years/kpi-summary
    POST   /academic-years
    PUT    /academic-years/{id}
    PUT    /academic-years/{id}/set-current
    POST   /academic-years/{id}/archive
    POST   /academic-years/{id}/unarchive
    DELETE /academic-years/{id}
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import {
  AcademicYearService,
  type AcademicYearKpiSummary,
  type AcademicYearPayload,
} from '@/services/academic-year.service';
import type {
  AcademicYear,
  AcademicYearSemester,
  AcademicYearStatus,
} from '@/types/academic-year';
import { useAcademicYearStore } from '@/stores/academic-year';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const ayStore = useAcademicYearStore();
const { t } = useI18n();

// ── Data ──────────────────────────────────────────────────────────
const items = ref<AcademicYear[]>([]);
const kpi = ref<AcademicYearKpiSummary | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const [list, summary] = await Promise.all([
      AcademicYearService.list(),
      AcademicYearService.getKpiSummary(),
    ]);
    items.value = list;
    kpi.value = summary;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

// ── Grouping ──────────────────────────────────────────────────────
const groups = computed(() => {
  const current = items.value.filter((y) => y.current);
  const active = items.value.filter((y) => !y.current && y.status === 'active');
  const inactive = items.value.filter((y) => !y.current && y.status === 'inactive');
  const archived = items.value.filter((y) => y.status === 'archived');
  return [
    { title: t('admin.sekolah.academic_year.group_current'), tone: 'emerald' as const, rows: current },
    { title: t('admin.sekolah.academic_year.group_active'), tone: 'blue' as const, rows: active },
    { title: t('admin.sekolah.academic_year.group_inactive'), tone: 'slate' as const, rows: inactive },
    { title: t('admin.sekolah.academic_year.group_archived'), tone: 'amber' as const, rows: archived },
  ].filter((g) => g.rows.length > 0);
});

// ── KPI cards ─────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'calendar',
    label: t('admin.sekolah.academic_year.kpi_total'),
    value: kpi.value?.total ?? items.value.length,
    tone: 'brand',
  },
  {
    icon: 'check-circle',
    label: t('admin.sekolah.academic_year.kpi_active'),
    value:
      (kpi.value?.active_count ?? 0) + (kpi.value?.current_count ?? 0),
    tone: 'green',
  },
  {
    icon: 'file-text',
    label: t('admin.sekolah.academic_year.kpi_archived'),
    value: kpi.value?.archived_count ?? 0,
    tone: 'amber',
  },
]);

const listState = computed<AsyncState<AcademicYear[]>>(() => {
  if (isLoading.value && items.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (items.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: items.value };
});

// ── CRUD modal ────────────────────────────────────────────────────
const showFormModal = ref(false);
const editingId = ref<string | null>(null);
const formYear = ref('');
const formSemester = ref<'ganjil' | 'genap' | ''>('');
const formStart = ref('');
const formEnd = ref('');
const isSaving = ref(false);

function openCreate() {
  editingId.value = null;
  // Default to "{year}/{year+1}" of the current calendar year
  const now = new Date();
  const mo = now.getMonth() + 1;
  const baseYear = mo >= 7 ? now.getFullYear() : now.getFullYear() - 1;
  formYear.value = `${baseYear}/${baseYear + 1}`;
  formSemester.value = mo >= 7 || mo === 12 ? 'ganjil' : 'genap';
  formStart.value = '';
  formEnd.value = '';
  showFormModal.value = true;
}

function openEdit(y: AcademicYear) {
  editingId.value = y.id;
  formYear.value = y.year;
  formSemester.value = (y.semester ?? '') as 'ganjil' | 'genap' | '';
  formStart.value = y.start_date ?? '';
  formEnd.value = y.end_date ?? '';
  showFormModal.value = true;
}

async function saveForm() {
  if (!formYear.value.trim()) {
    toast.value = { message: t('admin.sekolah.academic_year.err_year_required'), tone: 'error' };
    return;
  }
  isSaving.value = true;
  try {
    const payload: AcademicYearPayload = {
      year: formYear.value.trim(),
      semester: (formSemester.value || null) as AcademicYearSemester,
      start_date: formStart.value || null,
      end_date: formEnd.value || null,
    };
    if (editingId.value) {
      await AcademicYearService.update(editingId.value, payload);
    } else {
      await AcademicYearService.create(payload);
    }
    showFormModal.value = false;
    toast.value = {
      message: editingId.value
        ? t('admin.sekolah.academic_year.toast_updated')
        : t('admin.sekolah.academic_year.toast_created'),
      tone: 'success',
    };
    await load();
    await ayStore.fetchAll({ force: true });
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// ── Row actions ───────────────────────────────────────────────────
const setCurrentTarget = ref<AcademicYear | null>(null);
const archiveTarget = ref<AcademicYear | null>(null);
const unarchiveTarget = ref<AcademicYear | null>(null);
const deleteTarget = ref<AcademicYear | null>(null);
const isMutating = ref(false);

async function confirmSetCurrent() {
  const y = setCurrentTarget.value;
  setCurrentTarget.value = null;
  if (!y) return;
  isMutating.value = true;
  try {
    await AcademicYearService.setCurrent(y.id);
    toast.value = { message: t('admin.sekolah.academic_year.toast_set_current', { year: y.year }), tone: 'success' };
    await load();
    await ayStore.fetchAll({ force: true });
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isMutating.value = false;
  }
}

async function confirmArchive() {
  const y = archiveTarget.value;
  archiveTarget.value = null;
  if (!y) return;
  isMutating.value = true;
  try {
    await AcademicYearService.archive(y.id);
    toast.value = { message: t('admin.sekolah.academic_year.toast_archived'), tone: 'success' };
    await load();
    await ayStore.fetchAll({ force: true });
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isMutating.value = false;
  }
}

async function confirmUnarchive() {
  const y = unarchiveTarget.value;
  unarchiveTarget.value = null;
  if (!y) return;
  isMutating.value = true;
  try {
    await AcademicYearService.unarchive(y.id);
    toast.value = { message: t('admin.sekolah.academic_year.toast_unarchived'), tone: 'success' };
    await load();
    await ayStore.fetchAll({ force: true });
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isMutating.value = false;
  }
}

async function confirmDelete() {
  const y = deleteTarget.value;
  deleteTarget.value = null;
  if (!y) return;
  isMutating.value = true;
  try {
    await AcademicYearService.destroy(y.id);
    toast.value = { message: t('admin.sekolah.academic_year.toast_deleted'), tone: 'success' };
    await load();
    await ayStore.fetchAll({ force: true });
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isMutating.value = false;
  }
}

function goBack() {
  router.push({ name: 'admin.settings.school' });
}

function semesterLabel(s: AcademicYearSemester): string {
  if (s === 'ganjil') return t('admin.sekolah.academic_year.semester_odd');
  if (s === 'genap') return t('admin.sekolah.academic_year.semester_even');
  return '—';
}

function statusBadge(y: AcademicYear): { label: string; class: string } {
  if (y.current) return { label: t('admin.sekolah.academic_year.badge_active'), class: 'bg-emerald-100 text-emerald-700' };
  if (y.status === 'active') return { label: t('admin.sekolah.academic_year.badge_active'), class: 'bg-blue-100 text-blue-700' };
  if (y.status === 'archived') return { label: t('admin.sekolah.academic_year.badge_archived'), class: 'bg-amber-100 text-amber-700' };
  return { label: t('admin.sekolah.academic_year.badge_inactive'), class: 'bg-slate-100 text-slate-600' };
}
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('admin.sekolah.academic_year.back_to_general') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.academic_year.header_kicker')"
      :title="t('admin.sekolah.academic_year.header_title')"
      :meta="t('admin.sekolah.academic_year.header_meta', { count: items.length })"
      :live-dot="false"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white text-[12px] font-bold px-3 py-1.5 transition-colors"
        @click="openCreate"
      >
        <NavIcon name="plus" :size="13" />
        {{ t('admin.sekolah.academic_year.add') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.academic_year.empty_title')"
      :empty-description="t('admin.sekolah.academic_year.empty_description')"
      empty-icon="calendar"
      @retry="load"
    >
      <template #default>
        <div v-for="g in groups" :key="g.title" class="space-y-2">
          <h3
            class="text-3xs font-bold uppercase tracking-widest px-1"
            :class="{
              'text-emerald-700': g.tone === 'emerald',
              'text-blue-700': g.tone === 'blue',
              'text-amber-700': g.tone === 'amber',
              'text-slate-500': g.tone === 'slate',
            }"
          >
            {{ g.title }} · {{ g.rows.length }}
          </h3>

          <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
            <article
              v-for="(y, idx) in g.rows"
              :key="y.id"
              class="px-4 py-3.5 flex items-center gap-3"
              :class="[idx > 0 ? 'border-t border-slate-100' : '']"
            >
              <div
                class="w-11 h-11 rounded-xl grid place-items-center flex-shrink-0"
                :class="y.current ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'"
              >
                <NavIcon name="calendar" :size="18" />
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <p class="text-[14px] font-black text-slate-900 tracking-tight">
                    {{ y.year }}
                  </p>
                  <span
                    class="px-2 py-0.5 rounded-md text-4xs font-bold tracking-widest"
                    :class="statusBadge(y).class"
                  >
                    {{ statusBadge(y).label }}
                  </span>
                </div>
                <p class="text-2xs text-slate-500 mt-0.5">
                  {{ t('admin.sekolah.academic_year.semester_label', { label: semesterLabel(y.semester) }) }}
                  <span v-if="y.start_date || y.end_date">
                    · {{ y.start_date || '?' }} → {{ y.end_date || '?' }}
                  </span>
                </p>
              </div>

              <!-- Actions -->
              <div class="flex items-center gap-1 flex-shrink-0">
                <button
                  v-if="!y.current && y.status !== 'archived'"
                  type="button"
                  :title="t('admin.sekolah.academic_year.action_set_active')"
                  class="w-8 h-8 rounded-full grid place-items-center text-emerald-700 hover:bg-emerald-50"
                  :disabled="isMutating"
                  @click="setCurrentTarget = y"
                >
                  <NavIcon name="check-circle" :size="15" />
                </button>
                <button
                  v-if="y.status !== 'archived'"
                  type="button"
                  :title="t('admin.sekolah.academic_year.action_edit')"
                  class="w-8 h-8 rounded-full grid place-items-center text-slate-600 hover:bg-slate-100"
                  :disabled="isMutating"
                  @click="openEdit(y)"
                >
                  <NavIcon name="edit" :size="14" />
                </button>
                <button
                  v-if="!y.current && y.status !== 'archived'"
                  type="button"
                  :title="t('admin.sekolah.academic_year.action_archive')"
                  class="w-8 h-8 rounded-full grid place-items-center text-amber-700 hover:bg-amber-50"
                  :disabled="isMutating"
                  @click="archiveTarget = y"
                >
                  <NavIcon name="file-text" :size="14" />
                </button>
                <button
                  v-if="y.status === 'archived'"
                  type="button"
                  :title="t('admin.sekolah.academic_year.action_unarchive')"
                  class="w-8 h-8 rounded-full grid place-items-center text-blue-700 hover:bg-blue-50"
                  :disabled="isMutating"
                  @click="unarchiveTarget = y"
                >
                  <NavIcon name="refresh-cw" :size="14" />
                </button>
                <button
                  v-if="!y.current"
                  type="button"
                  :title="t('admin.sekolah.academic_year.action_delete')"
                  class="w-8 h-8 rounded-full grid place-items-center text-red-600 hover:bg-red-50"
                  :disabled="isMutating"
                  @click="deleteTarget = y"
                >
                  <NavIcon name="trash" :size="14" />
                </button>
              </div>
            </article>
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- Create / Edit form -->
    <Modal
      v-if="showFormModal"
      :title="editingId ? t('admin.sekolah.academic_year.modal_edit_title') : t('admin.sekolah.academic_year.modal_new_title')"
      :subtitle="t('admin.sekolah.academic_year.modal_subtitle')"
      size="sm"
      @close="showFormModal = false"
    >
      <div class="space-y-3">
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.sekolah.academic_year.field_year') }}
          </label>
          <input
            v-model="formYear"
            type="text"
            placeholder="2025/2026"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin tabular-nums"
          />
          <p class="text-[10.5px] text-slate-400 mt-1">{{ t('admin.sekolah.academic_year.year_hint') }}</p>
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            {{ t('admin.sekolah.academic_year.field_semester') }}
          </label>
          <div class="mt-1 grid grid-cols-3 gap-2">
            <button
              v-for="opt in [
                { v: '', l: '—' },
                { v: 'ganjil', l: t('admin.sekolah.academic_year.semester_odd') },
                { v: 'genap', l: t('admin.sekolah.academic_year.semester_even') },
              ]"
              :key="opt.v"
              type="button"
              class="rounded-xl border px-2 py-2 text-[12px] font-bold transition-colors"
              :class="formSemester === opt.v
                ? 'border-role-admin bg-role-admin/10 text-role-admin'
                : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'"
              @click="formSemester = opt.v as 'ganjil' | 'genap' | ''"
            >
              {{ opt.l }}
            </button>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.academic_year.field_start') }}</label>
            <input
              v-model="formStart"
              type="date"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            />
          </div>
          <div>
            <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.academic_year.field_end') }}</label>
            <input
              v-model="formEnd"
              type="date"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block :disabled="isSaving" @click="showFormModal = false">
            {{ t('admin.sekolah.academic_year.cancel') }}
          </Button>
          <Button variant="primary" block :disabled="isSaving" @click="saveForm">
            {{ isSaving ? t('admin.sekolah.academic_year.saving') : t('admin.sekolah.academic_year.save') }}
          </Button>
        </div>
      </div>
    </Modal>

    <ConfirmationDialog
      v-if="setCurrentTarget"
      :title="t('admin.sekolah.academic_year.confirm_set_current_title')"
      :message="t('admin.sekolah.academic_year.confirm_set_current_msg', { year: setCurrentTarget.year })"
      :confirm-label="t('admin.sekolah.academic_year.confirm_set_current_ok')"
      @close="setCurrentTarget = null"
      @confirm="confirmSetCurrent"
    />
    <ConfirmationDialog
      v-if="archiveTarget"
      :title="t('admin.sekolah.academic_year.confirm_archive_title')"
      :message="t('admin.sekolah.academic_year.confirm_archive_msg', { year: archiveTarget.year })"
      :confirm-label="t('admin.sekolah.academic_year.confirm_archive_ok')"
      danger
      @close="archiveTarget = null"
      @confirm="confirmArchive"
    />
    <ConfirmationDialog
      v-if="unarchiveTarget"
      :title="t('admin.sekolah.academic_year.confirm_unarchive_title')"
      :message="t('admin.sekolah.academic_year.confirm_unarchive_msg', { year: unarchiveTarget.year })"
      :confirm-label="t('admin.sekolah.academic_year.confirm_unarchive_ok')"
      @close="unarchiveTarget = null"
      @confirm="confirmUnarchive"
    />
    <ConfirmationDialog
      v-if="deleteTarget"
      :title="t('admin.sekolah.academic_year.confirm_delete_title')"
      :message="t('admin.sekolah.academic_year.confirm_delete_msg', { year: deleteTarget.year })"
      :confirm-label="t('admin.sekolah.academic_year.confirm_delete_ok')"
      danger
      @close="deleteTarget = null"
      @confirm="confirmDelete"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
