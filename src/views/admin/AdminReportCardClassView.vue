<!--
  AdminReportCardClassView.vue — admin drill into one class
  (Mockup #08 continuation).

  Web port of `admin_report_card_screen.dart`. Route entry:
    /admin/report-cards/class/:classId

  Layout:
    1. Back chevron + sticky actions (Export Excel + Kirim ke Parent)
    2. BrandPageHeader (admin) — kicker class+TP, title roster
    3. KpiStripCards — Total / Terbit / Diperiksa / Draf
    4. Student rows — name + NIS + status pill
    5. Sticky bottom-bar with Export Excel + Kirim ke Parent (publish)

  Endpoints:
    GET  /raports?class_id=…
    GET  /raports/export?class_id=…   (Excel blob)
    POST /raports/publish              (bulk publish per class)
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
// (onMounted retained — still used to kick off the reference-data load.)
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
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import StickyActionBar from '@/components/ui/StickyActionBar.vue';
import BackButton from '@/components/ui/BackButton.vue';
import type { StatusBadgeTone } from '@/types/report-card';
import { useDataRefresh } from '@/composables/useDataRefresh';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const classId = computed(() => String(route.params.classId ?? ''));

const cls = ref<Classroom | null>(null);
const isExporting = ref(false);
const isPublishing = ref(false);
const confirmPublish = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

async function loadClass() {
  try {
    const res = await ClassroomService.list({ per_page: 200 });
    cls.value = res.items.find((c) => c.id === classId.value) ?? null;
  } catch {
    cls.value = null;
  }
}

// Roster load lifecycle (mount + academic-year refetch) via the shared
// composable. Returning [] when there's no classId yields the same
// 'empty' state the old early-return produced. `watchLocale: false`
// keeps the prior academic-year-only refetch behaviour.
const { state: listState, reload: loadRoster } = useDataRefresh<
  RaportSummaryRow[]
>(
  async () => {
    if (!classId.value) return [];
    return ReportCardService.getClassRoster({ class_id: classId.value });
  },
  { watchLocale: false },
);

const students = computed(() => listState.value.data ?? []);

// Reference data (class meta) loads once on mount, independent of the
// roster's AsyncState.
onMounted(loadClass);

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

const kpiCards = computed<KpiCard[]>(() => [
  { icon: 'users', label: t('admin.sekolah.report_card_class.kpi_total_students'), value: counts.value.total, tone: 'brand' },
  {
    icon: 'check-circle',
    label: t('admin.sekolah.report_card_class.kpi_published'),
    value: counts.value.published + counts.value.distributed,
    tone: 'green',
  },
  {
    icon: 'edit',
    label: t('admin.sekolah.report_card_class.kpi_reviewed'),
    value: counts.value.final,
    tone: counts.value.final > 0 ? 'amber' : 'slate',
    accented: counts.value.final > 0,
  },
  {
    icon: 'file-text',
    label: t('admin.sekolah.report_card_class.kpi_draft'),
    value: counts.value.draft + counts.value.belum,
    tone: counts.value.belum > 0 ? 'red' : 'slate',
  },
]);

// `listState` comes from useDataRefresh — its generic empty rule (empty
// array → 'empty') matches this view's `students.length === 0` exactly.

function statusPill(s: ReportCardStatus | null | undefined): {
  label: string;
  tone: StatusBadgeTone;
} {
  if (!s) return { label: t('admin.sekolah.report_card_class.status_not_filled'), tone: 'neutral' };
  return { label: STATUS_LABELS[s], tone: STATUS_TONES[s].tone };
}

const hasFinalToPublish = computed(() => counts.value.final > 0);

async function exportExcel() {
  if (!classId.value) return;
  isExporting.value = true;
  try {
    await ReportCardService.exportClassExcel({
      class_id: classId.value,
      filename: cls.value
        ? `rapor-kelas-${cls.value.name}.xlsx`
        : undefined,
    });
    toast.value = { message: t('admin.sekolah.report_card_class.toast_excel_downloaded'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isExporting.value = false;
  }
}

async function publishClass() {
  if (!classId.value) return;
  isPublishing.value = true;
  try {
    const res = await ReportCardService.publishClass({
      class_id: classId.value,
    });
    toast.value = {
      message: t('admin.sekolah.report_card_class.toast_published', { count: res.published_count }),
      tone: 'success',
    };
    await loadRoster();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isPublishing.value = false;
    confirmPublish.value = false;
  }
}

function goBack() {
  router.push({ name: 'admin.report-cards' });
}

function viewStudentDetail(s: RaportSummaryRow) {
  router.push({
    name: 'admin.report-cards.detail',
    params: {
      classId: classId.value,
      studentClassId: s.student_class_id,
    },
  });
}

const isDownloadingPdf = ref<Record<string, boolean>>({});

async function downloadStudentPdf(s: RaportSummaryRow) {
  if (isDownloadingPdf.value[s.student_class_id]) return;
  isDownloadingPdf.value[s.student_class_id] = true;
  try {
    await ReportCardService.exportSinglePdf({
      student_class_id: s.student_class_id,
      filename: `rapor-${s.student_name}.pdf`
    });
    toast.value = { message: t('admin.sekolah.report_card_class.toast_pdf_downloaded', { name: s.student_name }), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDownloadingPdf.value[s.student_class_id] = false;
  }
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- BACK -->
    <div class="flex items-center gap-2">
      <BackButton :label="t('admin.sekolah.report_card_class.back_to_hub')" @click="goBack" />
    </div>

    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.report_card_class.header_kicker', { className: cls?.name ?? '—' })"
      :title="t('admin.sekolah.report_card_class.header_title')"
      :meta="t('admin.sekolah.report_card_class.header_meta', { total: counts.total, published: counts.published + counts.distributed, reviewed: counts.final })"
      :live-dot="false"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- LIST -->
    <AsyncView
      :state="listState"
      :empty-title="t('admin.sekolah.report_card_class.empty_title')"
      :empty-description="t('admin.sekolah.report_card_class.empty_description')"
      empty-icon="users"
      @retry="loadRoster"
    >
      <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-sm">
        <div
          v-for="(s, idx) in students"
          :key="s.student_class_id"
          class="px-4 py-3 flex items-center gap-3 cursor-pointer hover:bg-slate-50 transition-colors"
          :class="idx > 0 ? 'border-t border-slate-100' : ''"
          @click="viewStudentDetail(s)"
        >
          <InitialsAvatar
            :name="s.student_name || '?'"
            :size="40"
            :border-radius="12"
            :color="s.raport_status ? '#143068' : '#DC2626'"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ s.student_name }}
            </p>
            <p class="text-2xs text-slate-500 truncate">
              <template v-if="s.student_number">
                {{ t('admin.sekolah.report_card_class.nis_label', { nis: s.student_number }) }}
              </template>
              <template v-else>{{ t('admin.sekolah.report_card_class.no_nis') }}</template>
              {{ t('admin.sekolah.report_card_class.row_number', { index: idx + 1 }) }}
            </p>
          </div>
          
          <button
            v-if="s.raport_status && s.raport_status !== 'draft'"
            type="button"
            class="w-9 h-9 rounded-full bg-red-50 hover:bg-red-100 flex items-center justify-center text-red-600 flex-shrink-0 transition-colors"
            @click.stop="downloadStudentPdf(s)"
          >
            <NavIcon name="download" :size="15" />
          </button>

          <StatusBadge
            :label="statusPill(s.raport_status).label"
            :tone="statusPill(s.raport_status).tone"
            uppercase
          />
          
          <NavIcon name="chevron-right" :size="16" class="text-slate-300 flex-shrink-0" />
        </div>
      </div>
    </AsyncView>

    <!-- STICKY BOTTOM BAR -->
    <StickyActionBar :cols="2">
      <Button
        variant="secondary"
        block
        :loading="isExporting"
        :disabled="isExporting || students.length === 0"
        @click="exportExcel"
      >
        <NavIcon name="download" :size="13" />
        {{ t('admin.sekolah.report_card_class.export_excel') }}
      </Button>
      <Button
        variant="success"
        block
        :loading="isPublishing"
        :disabled="!hasFinalToPublish || isPublishing"
        @click="confirmPublish = true"
      >
        <NavIcon name="send" :size="13" />
        {{ t('admin.sekolah.report_card_class.send_to_parents', { count: counts.final }) }}
      </Button>
    </StickyActionBar>

    <!-- CONFIRM PUBLISH -->
    <ConfirmationDialog
      v-if="confirmPublish"
      :title="t('admin.sekolah.report_card_class.publish_title')"
      :message="t('admin.sekolah.report_card_class.publish_message', { count: counts.final, className: cls?.name ?? '' })"
      :confirm-label="t('admin.sekolah.report_card_class.publish_confirm')"
      :loading="isPublishing"
      @close="confirmPublish = false"
      @confirm="publishClass"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
