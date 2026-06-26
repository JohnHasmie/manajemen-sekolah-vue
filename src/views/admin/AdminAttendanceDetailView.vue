<!--
  AdminAttendanceDetailView.vue — admin presensi detail / edit screen.

  Web port of Flutter's `AdminAttendanceDetailPage`. Route:
  `/admin/attendance/detail?class_id=…&subject_id=…&date=YYYY-MM-DD&lesson_hour_id=…`.

  Layout:
    1. Back chevron → Laporan
    2. BrandPageHeader (admin) — title "Detail Presensi" + class/subject/date meta
    3. KpiStripCards — Hadir / Izin / Sakit / Alpa
    4. Action bar — Edit toggle + Excel export + Hapus session
    5. Roster — student rows with current status pill + tap to edit (when edit mode)
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { AttendanceService } from '@/services/attendance.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { useAuthStore } from '@/stores/auth';
import type {
  AttendanceRow,
  AttendanceStatus,
} from '@/types/attendance';
import { ATTENDANCE_LABELS } from '@/types/attendance';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import AttendanceStatusPickerModal from '@/components/feature/AttendanceStatusPickerModal.vue';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const { t } = useI18n();

const classId = computed(() => String(route.query.class_id ?? ''));
const subjectId = computed(() => String(route.query.subject_id ?? ''));
const date = computed(() => String(route.query.date ?? ''));
const lessonHourId = computed(() => {
  const v = route.query.lesson_hour_id;
  return typeof v === 'string' && v ? v : undefined;
});
/** Optional teacher_id override (admin impersonating a teacher). */
const teacherIdOverride = computed(() => {
  const v = route.query.teacher_id;
  return typeof v === 'string' && v ? v : undefined;
});
const teacherNameOverride = computed(() => {
  const v = route.query.teacher_name;
  return typeof v === 'string' && v ? v : undefined;
});

const rows = ref<AttendanceRow[]>([]);
const className = ref('');
const subjectName = ref('');
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const editMode = ref(false);
const dirty = ref<Set<string>>(new Set());
const editTarget = ref<AttendanceRow | null>(null);
const isSaving = ref(false);
const isExporting = ref(false);
const showDeleteConfirm = ref(false);
const isDeleting = ref(false);

async function load() {
  if (!classId.value || !subjectId.value || !date.value) {
    error.value = 'Parameter sesi tidak lengkap.';
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    const [roster, cls, sub] = await Promise.all([
      AttendanceService.getRoster({
        class_id: classId.value,
        subject_id: subjectId.value,
        date: date.value,
        lesson_hour_id: lessonHourId.value,
      }),
      ClassroomService.get(classId.value),
      SubjectService.get(subjectId.value),
    ]);
    rows.value = roster;
    className.value = cls?.name ?? '';
    subjectName.value = sub?.name ?? '';
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

const counts = computed(() => {
  let hadir = 0;
  let izin = 0;
  let sakit = 0;
  let alpa = 0;
  let unmarked = 0;
  for (const r of rows.value) {
    switch (r.status) {
      case 'hadir':
        hadir++;
        break;
      case 'izin':
        izin++;
        break;
      case 'sakit':
        sakit++;
        break;
      case 'alpa':
        alpa++;
        break;
      default:
        unmarked++;
    }
  }
  return { hadir, izin, sakit, alpa, unmarked };
});

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'check-circle', label: 'Hadir', value: counts.value.hadir, tone: 'green', accented: true },
  { icon: 'file-text', label: 'Izin', value: counts.value.izin, tone: 'brand' },
  { icon: 'thermometer', label: 'Sakit', value: counts.value.sakit, tone: 'amber' },
  {
    icon: 'x-circle',
    label: 'Alpa',
    value: counts.value.alpa,
    tone: counts.value.alpa > 0 ? 'red' : 'slate',
    accented: counts.value.alpa > 0,
  },
]);

function statusToneClass(s: AttendanceStatus): string {
  switch (s) {
    case 'hadir':
      return 'bg-emerald-100 text-emerald-700';
    case 'izin':
      return 'bg-brand-cobalt/15 text-brand-cobalt';
    case 'sakit':
      return 'bg-amber-100 text-amber-700';
    case 'alpa':
      return 'bg-red-100 text-red-700';
    default:
      return 'bg-slate-100 text-slate-500';
  }
}

function statusLabel(s: AttendanceStatus): string {
  if (!s) return 'Belum';
  return ATTENDANCE_LABELS[s];
}

function onRowClick(r: AttendanceRow) {
  if (!editMode.value) return;
  editTarget.value = r;
}

function applyStatus(payload: { status: NonNullable<AttendanceStatus>; note: string | null }) {
  const target = editTarget.value;
  if (!target) return;
  const idx = rows.value.findIndex((x) => x.student_id === target.student_id);
  if (idx < 0) return;
  rows.value = rows.value.map((r, i) =>
    i === idx ? { ...r, status: payload.status, notes: payload.note ?? '' } : r,
  );
  dirty.value.add(target.student_id);
  editTarget.value = null;
}

const listState = computed<AsyncState<AttendanceRow[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

async function saveChanges() {
  if (dirty.value.size === 0) {
    toast.value = { message: 'Tidak ada perubahan.', tone: 'success' };
    editMode.value = false;
    return;
  }
  const teacherId = teacherIdOverride.value ?? auth.teacherId ?? auth.user?.id ?? '';
  if (!teacherId) {
    toast.value = { message: 'ID guru tidak ditemukan.', tone: 'error' };
    return;
  }
  isSaving.value = true;
  try {
    // Only push changed rows (and only rows with a non-null status).
    const attendances = rows.value
      .filter((r) => dirty.value.has(r.student_id) && r.status)
      .map((r) => ({
        student_id: r.student_id,
        status: r.status as NonNullable<AttendanceStatus>,
        notes: r.notes || undefined,
      }));
    await AttendanceService.saveBulk({
      teacher_id: teacherId,
      class_id: classId.value,
      subject_id: subjectId.value,
      date: date.value,
      lesson_hour_id: lessonHourId.value,
      attendances,
    });
    toast.value = {
      message: `${attendances.length} perubahan disimpan.`,
      tone: 'success',
    };
    dirty.value = new Set();
    editMode.value = false;
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

function discardChanges() {
  dirty.value = new Set();
  editMode.value = false;
  void load();
}

async function deleteSession() {
  isDeleting.value = true;
  try {
    await AttendanceService.deleteSession({
      class_id: classId.value,
      subject_id: subjectId.value,
      date: date.value,
      lesson_hour_id: lessonHourId.value,
    });
    toast.value = { message: 'Sesi presensi dihapus.', tone: 'success' };
    setTimeout(() => router.push({ name: 'admin.attendance.laporan' }), 600);
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDeleting.value = false;
    showDeleteConfirm.value = false;
  }
}

async function exportXlsx() {
  if (rows.value.length === 0) return;
  isExporting.value = true;
  try {
    const presence = rows.value
      .filter((r) => r.status)
      .map((r) => ({
        student_id: r.student_id,
        student_name: r.student_name,
        student_number: r.student_number,
        status: r.status as NonNullable<AttendanceStatus>,
        notes: r.notes ?? null,
      }));
    const name = `presensi-${className.value}-${subjectName.value}-${date.value}.xlsx`
      .replace(/\s+/g, '-')
      .toLowerCase();
    await AttendanceService.downloadXlsx(
      {
        presenceData: presence,
        class_id: classId.value,
        class_name: className.value,
        subject_id: subjectId.value,
        subject_name: subjectName.value,
        date: date.value,
        teacher_id: teacherIdOverride.value ?? auth.teacherId ?? undefined,
        teacher_name: teacherNameOverride.value ?? auth.user?.name,
        lesson_hour_id: lessonHourId.value,
      },
      name,
    );
    toast.value = { message: 'Excel terdownload.', tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isExporting.value = false;
  }
}

// Unsaved-changes confirm modal — fires when goBack is called with
// pending dirty edits. Captures the post-confirm action so the modal
// can fire it once the admin clicks "Lanjut keluar".
const unsavedConfirm = ref<{ open: boolean; onConfirm: () => void }>({
  open: false,
  onConfirm: () => {},
});

function goBack() {
  if (editMode.value && dirty.value.size > 0) {
    unsavedConfirm.value = {
      open: true,
      onConfirm: () => router.push({ name: 'admin.attendance.laporan' }),
    };
    return;
  }
  router.push({ name: 'admin.attendance.laporan' });
}

const headerMeta = computed(() => {
  const parts = [date.value];
  if (className.value) parts.push(className.value);
  if (subjectName.value) parts.push(subjectName.value);
  if (teacherNameOverride.value) parts.push(`as ${teacherNameOverride.value}`);
  return parts.filter(Boolean).join(' · ');
});
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('admin.sekolah.attendance_detail.back_to_report') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.attendance_detail.header_kicker')"
      :title="t('admin.sekolah.attendance_detail.header_title')"
      :meta="headerMeta"
      :live-dot="false"
    >
      <div class="flex items-center gap-2 flex-wrap">
        <button
          v-if="!editMode"
          type="button"
          class="text-[11px] font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
          @click="editMode = true"
        >
          <NavIcon name="edit" :size="11" class="inline" />
          {{ t('admin.sekolah.attendance_detail.edit') }}
        </button>
        <template v-else>
          <button
            type="button"
            class="text-[11px] font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
            @click="discardChanges"
          >
            {{ t('admin.sekolah.attendance_detail.cancel') }}
          </button>
          <Button
            variant="primary"
            size="sm"
            :loading="isSaving"
            :disabled="dirty.size === 0"
            @click="saveChanges"
          >
            <NavIcon name="check" :size="12" />
            {{ t('admin.sekolah.attendance_detail.save_count', { count: dirty.size }) }}
          </Button>
        </template>
      </div>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.attendance_detail.empty_title')"
      :empty-description="t('admin.sekolah.attendance_detail.empty_description')"
      empty-icon="users"
      @retry="load"
    >
      <template #default>
        <ul class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
          <li
            v-for="(r, idx) in rows"
            :key="r.student_id"
            class="px-4 py-3 flex items-center gap-3 transition-colors"
            :class="[
              idx > 0 ? 'border-t border-slate-100' : '',
              editMode ? 'hover:bg-slate-50 cursor-pointer' : '',
              dirty.has(r.student_id) ? 'bg-role-admin/5' : '',
            ]"
            @click="onRowClick(r)"
          >
            <InitialsAvatar
              :name="r.student_name || '?'"
              :size="40"
              :color="r.alert_tone === 'danger' ? '#DC2626' : r.alert_tone === 'warning' ? '#F59E0B' : '#143068'"
              :border-radius="12"
            />
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate">{{ r.student_name }}</p>
              <p class="text-[10px] text-slate-500 truncate">
                <template v-if="r.student_number">{{ t('admin.sekolah.attendance_detail.nis_label', { nis: r.student_number }) }}</template>
                <template v-else>{{ t('admin.sekolah.attendance_detail.no_nis') }}</template>
                {{ t('admin.sekolah.attendance_detail.row_number', { index: idx + 1 }) }}
              </p>
              <p v-if="r.alert" class="text-[10px] font-bold text-amber-700 mt-0.5">
                {{ r.alert }}
              </p>
              <p v-if="r.notes" class="text-[10px] text-slate-500 mt-0.5 italic">
                "{{ r.notes }}"
              </p>
            </div>
            <span
              class="text-[10px] font-bold uppercase tracking-widest px-2.5 py-1 rounded-full flex-shrink-0"
              :class="statusToneClass(r.status)"
            >
              {{ statusLabel(r.status) }}
            </span>
            <NavIcon
              v-if="editMode"
              name="edit"
              :size="13"
              class="text-slate-300"
            />
          </li>
        </ul>

        <!-- Footer actions -->
        <section class="grid grid-cols-2 gap-2">
          <Button
            variant="secondary"
            block
            :loading="isExporting"
            :disabled="rows.length === 0 || isExporting"
            @click="exportXlsx"
          >
            <NavIcon name="download" :size="13" />
            {{ t('admin.sekolah.attendance_detail.export_excel') }}
          </Button>
          <Button
            variant="danger"
            block
            :disabled="rows.length === 0"
            @click="showDeleteConfirm = true"
          >
            <NavIcon name="trash-2" :size="13" />
            {{ t('admin.sekolah.attendance_detail.delete_session') }}
          </Button>
        </section>
      </template>
    </AsyncView>

    <AttendanceStatusPickerModal
      v-if="editTarget"
      :student="editTarget"
      :initial-status="editTarget.status"
      :initial-note="editTarget.notes ?? ''"
      :is-saving="isSaving"
      @close="editTarget = null"
      @apply="applyStatus"
    />

    <ConfirmationDialog
      v-if="showDeleteConfirm"
      :title="t('admin.sekolah.attendance_detail.delete_title')"
      :message="t('admin.sekolah.attendance_detail.delete_message', { meta: headerMeta })"
      :confirm-label="t('admin.sekolah.attendance_detail.delete')"
      danger
      :loading="isDeleting"
      @close="showDeleteConfirm = false"
      @confirm="deleteSession"
    />

    <ConfirmationDialog
      v-if="unsavedConfirm.open"
      :title="t('admin.sekolah.attendance_detail.unsaved_title')"
      :message="t('admin.sekolah.attendance_detail.unsaved_message')"
      :confirm-label="t('admin.sekolah.attendance_detail.unsaved_confirm')"
      danger
      @close="unsavedConfirm.open = false"
      @confirm="() => { const cb = unsavedConfirm.onConfirm; unsavedConfirm.open = false; cb(); }"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
