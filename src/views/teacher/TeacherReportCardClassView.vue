<!--
  TeacherReportCardClassView.vue — per-class roster (Rapor Frame B).

  Web port of `teacher_report_card_screen.dart`. Route entry:
    /teacher/report-cards/class/:classId

  Layout:
    1. Back chevron row + Export Excel action
    2. BrandPageHeader (teacher) — kicker "Kelas X · Rapor",
       title "List Student", meta `N student · M sudah Terbit`
    3. KpiStripCards — Student / Terbit / Diperiksa / Draft
    4. Status chip strip (Semua / Belum / Draf / Diperiksa / Terbit)
    5. Student rows — avatar + NIS + status pill + chevron

  Tap row → detail (Phase 3 continuation).

  Endpoints:
    GET /raports?class_id=…        — roster + per-student status
    GET /raports/export?class_id=… — class Excel blob
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { ReportCardService } from '@/services/report-card.service';
import { ClassroomService } from '@/services/classrooms.service';
import {
  STATUS_LABELS,
  STATUS_TONES,
  type RaportSummaryRow,
  type ReportCardStatus,
} from '@/types/report-card';
import type { Classroom } from '@/types/entities';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));

// ── Filter ──
type StatusChip = 'all' | 'belum' | ReportCardStatus;
const statusFilter = ref<StatusChip>('all');

// ── Data state ──
const cls = ref<Classroom | null>(null);
const students = ref<RaportSummaryRow[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isExporting = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Loaders ──
async function loadClass() {
  if (!classId.value) return;
  try {
    const res = await ClassroomService.list({ per_page: 200 });
    cls.value = res.items.find((c) => c.id === classId.value) ?? null;
  } catch {
    cls.value = null;
  }
}

async function loadRoster() {
  if (!classId.value) {
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    students.value = await ReportCardService.getClassRoster({
      class_id: classId.value,
    });
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(async () => {
  await Promise.all([loadClass(), loadRoster()]);
});

useAcademicYearWatcher(loadRoster);

// ── Derived ──
const counts = computed(() => {
  const all = students.value;
  return {
    total: all.length,
    draft: all.filter((r) => r.raport_status === 'draft').length,
    final: all.filter((r) => r.raport_status === 'final').length,
    published: all.filter((r) => r.raport_status === 'published').length,
    distributed: all.filter((r) => r.raport_status === 'distributed').length,
    belum: all.filter((r) => !r.raport_status).length,
  };
});

const visibleStudents = computed(() => {
  if (statusFilter.value === 'all') return students.value;
  if (statusFilter.value === 'belum') {
    return students.value.filter((r) => !r.raport_status);
  }
  return students.value.filter((r) => r.raport_status === statusFilter.value);
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: t('tutor.sekolah.reportCardClass.kpiStudents'),
    value: counts.value.total,
    tone: 'brand',
  },
  {
    icon: 'check-circle',
    label: t('tutor.sekolah.reportCardClass.kpiPublished'),
    value: counts.value.published + counts.value.distributed,
    tone: 'green',
  },
  {
    icon: 'edit',
    label: t('tutor.sekolah.reportCardClass.kpiReviewed'),
    value: counts.value.final,
    tone: counts.value.final > 0 ? 'amber' : 'slate',
    accented: counts.value.final > 0,
  },
  {
    icon: 'file-text',
    label: t('tutor.sekolah.reportCardClass.kpiDraft'),
    value: counts.value.draft + counts.value.belum,
    tone: counts.value.belum > 0 ? 'red' : 'slate',
  },
]);

const statusOptions = computed<{ key: StatusChip; label: string }[]>(() => [
  { key: 'all', label: t('tutor.sekolah.reportCardClass.filterAll') },
  { key: 'belum', label: t('tutor.sekolah.reportCardClass.filterPending') },
  { key: 'draft', label: STATUS_LABELS.draft },
  { key: 'final', label: STATUS_LABELS.final },
  { key: 'published', label: STATUS_LABELS.published },
]);

const listState = computed<AsyncState<RaportSummaryRow[]>>(() => {
  if (isLoading.value && students.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleStudents.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleStudents.value };
});

// ── Header copy ──
const headerKicker = computed(() => {
  const name = cls.value?.name ?? '—';
  return t('tutor.sekolah.reportCardClass.kicker', { name: name.toUpperCase() });
});

const headerMeta = computed(() => {
  const total = counts.value.total;
  const done = counts.value.published + counts.value.distributed;
  return t('tutor.sekolah.reportCardClass.meta', { total, done });
});

// ── Actions ──
function goBack() {
  router.push({ name: 'teacher.report-cards' });
}

function openStudent(s: RaportSummaryRow) {
  const target = router.resolve({
    name: 'teacher.report-cards.detail',
    params: { classId: classId.value, studentClassId: s.student_class_id },
  });
  if (target.matched.length === 0) {
    toast.value = {
      message: t('tutor.sekolah.reportCardClass.detailSoon', { name: s.student_name }),
      tone: 'success',
    };
    return;
  }
  router.push(target);
}

async function exportClassExcel() {
  if (!classId.value) return;
  isExporting.value = true;
  try {
    await ReportCardService.exportClassExcel({
      class_id: classId.value,
      filename: cls.value
        ? `rapor-kelas-${cls.value.name}.xlsx`
        : undefined,
    });
    toast.value = { message: t('tutor.sekolah.reportCardClass.excelDownloaded'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isExporting.value = false;
  }
}

function statusPillFor(s: RaportSummaryRow): { label: string; class: string } {
  if (!s.raport_status) {
    return { label: t('tutor.sekolah.reportCardClass.pillEmpty'), class: 'bg-slate-100 text-slate-500' };
  }
  const tone = STATUS_TONES[s.raport_status];
  return {
    label: STATUS_LABELS[s.raport_status],
    class: `${tone.bg} ${tone.text}`,
  };
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- BACK + EXPORT -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('tutor.sekolah.reportCardClass.backAllClasses') }}
      </button>
      <span class="flex-1"></span>
      <Button
        variant="secondary"
        size="sm"
        :loading="isExporting"
        :disabled="isExporting || students.length === 0"
        @click="exportClassExcel"
      >
        <NavIcon name="download" :size="13" />
        {{ t('tutor.sekolah.reportCardClass.excelButton') }}
      </Button>
    </div>

    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      :kicker="headerKicker"
      :title="t('tutor.sekolah.reportCardClass.title')"
      :meta="headerMeta"
      :live-dot="false"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- STATUS CHIPS -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="opt in statusOptions"
        :key="opt.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border inline-flex items-center gap-1.5"
        :class="
          statusFilter === opt.key
            ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
        "
        @click="statusFilter = opt.key"
      >
        {{ opt.label }}
        <span
          v-if="opt.key !== 'all'"
          class="text-[9.5px] font-bold tabular-nums px-1.5 py-0.5 rounded-full"
          :class="
            statusFilter === opt.key
              ? 'bg-white/20 text-white'
              : 'bg-slate-100 text-slate-500'
          "
        >
          {{
            opt.key === 'belum'
              ? counts.belum
              : opt.key === 'draft'
                ? counts.draft
                : opt.key === 'final'
                  ? counts.final
                  : opt.key === 'published'
                    ? counts.published
                    : 0
          }}
        </span>
      </button>
    </div>

    <!-- STUDENT LIST -->
    <AsyncView
      :state="listState"
      :empty-title="
        statusFilter === 'all'
          ? t('tutor.sekolah.reportCardClass.emptyClass')
          : t('tutor.sekolah.reportCardClass.emptyFilter')
      "
      :empty-description="t('tutor.sekolah.reportCardClass.emptyDescription')"
      empty-icon="users"
      @retry="loadRoster"
    >
      <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <button
          v-for="(s, idx) in visibleStudents"
          :key="s.student_class_id"
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 transition hover:bg-slate-50"
          :class="idx > 0 ? 'border-t border-slate-100' : ''"
          @click="openStudent(s)"
        >
          <InitialsAvatar
            :name="s.student_name || '?'"
            :size="40"
            :border-radius="12"
            :color="s.raport_status ? '#1B6FB8' : '#DC2626'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ s.student_name }}
            </p>
            <p class="text-[11px] text-slate-500 truncate">
              <template v-if="s.student_number">
                {{ t('tutor.sekolah.reportCardClass.nis', { nis: s.student_number }) }}
              </template>
              <template v-else>{{ t('tutor.sekolah.reportCardClass.noNis') }}</template>
              · {{ t('tutor.sekolah.reportCardClass.rowNumber', { n: idx + 1 }) }}
            </p>
          </div>
          <span
            class="text-[10px] font-bold px-2 py-1 rounded-full uppercase tracking-wider flex-shrink-0"
            :class="statusPillFor(s).class"
          >
            {{ statusPillFor(s).label }}
          </span>
          <NavIcon
            name="chevron-right"
            :size="13"
            class="text-slate-400 flex-shrink-0"
          />
        </button>
      </div>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
