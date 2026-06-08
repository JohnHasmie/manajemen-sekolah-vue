<!--
  AdminReportCardClassView.vue — admin drill into one class
  (Mockup #08 continuation).

  Web port of `admin_report_card_screen.dart`. Route entry:
    /admin/report-cards/kelas/:classId

  Layout:
    1. Back chevron + sticky actions (Export Excel + Kirim ke Wali)
    2. BrandPageHeader (admin) — kicker class+TP, title roster
    3. KpiStripCards — Total / Terbit / Diperiksa / Draf
    4. Student rows — name + NIS + status pill
    5. Sticky bottom-bar with Export Excel + Kirim ke Wali (publish)

  Endpoints:
    GET  /raports?class_id=…
    GET  /raports/export?class_id=…   (Excel blob)
    POST /raports/publish              (bulk publish per class)
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
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
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const route = useRoute();
const router = useRouter();

const classId = computed(() => String(route.params.classId ?? ''));

const cls = ref<Classroom | null>(null);
const students = ref<RaportSummaryRow[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
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
  { icon: 'users', label: 'Total Siswa', value: counts.value.total, tone: 'brand' },
  {
    icon: 'check-circle',
    label: 'Terbit',
    value: counts.value.published + counts.value.distributed,
    tone: 'green',
  },
  {
    icon: 'edit',
    label: 'Diperiksa',
    value: counts.value.final,
    tone: counts.value.final > 0 ? 'amber' : 'slate',
    accented: counts.value.final > 0,
  },
  {
    icon: 'file-text',
    label: 'Draf / Belum',
    value: counts.value.draft + counts.value.belum,
    tone: counts.value.belum > 0 ? 'red' : 'slate',
  },
]);

const listState = computed<AsyncState<RaportSummaryRow[]>>(() => {
  if (isLoading.value && students.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (students.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: students.value };
});

function statusPill(s: ReportCardStatus | null | undefined): {
  label: string;
  class: string;
} {
  if (!s) return { label: 'Belum diisi', class: 'bg-slate-100 text-slate-500' };
  const tone = STATUS_TONES[s];
  return { label: STATUS_LABELS[s], class: `${tone.bg} ${tone.text}` };
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
    toast.value = { message: 'Excel terdownload.', tone: 'success' };
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
      message: `${res.published_count} rapor diterbitkan ke wali murid.`,
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
    toast.value = { message: `PDF rapor ${s.student_name} terdownload.`, tone: 'success' };
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
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        Hub Rapor
      </button>
    </div>

    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="`Kelas ${cls?.name ?? '—'} · Rapor`"
      title="Daftar Rapor Siswa"
      :meta="`${counts.total} siswa · ${counts.published + counts.distributed} terbit · ${counts.final} diperiksa`"
      :live-dot="false"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- LIST -->
    <AsyncView
      :state="listState"
      empty-title="Belum ada siswa di kelas ini"
      empty-description="Tambahkan siswa ke kelas via menu Data Siswa."
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
            <p class="text-[11px] text-slate-500 truncate">
              <template v-if="s.student_number">
                NIS {{ s.student_number }}
              </template>
              <template v-else>Tanpa NIS</template>
              · No {{ idx + 1 }}
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

          <span
            class="text-[10px] font-bold px-2 py-1 rounded-full uppercase tracking-wider flex-shrink-0"
            :class="statusPill(s.raport_status).class"
          >
            {{ statusPill(s.raport_status).label }}
          </span>
          
          <NavIcon name="chevron-right" :size="16" class="text-slate-300 flex-shrink-0" />
        </div>
      </div>
    </AsyncView>

    <!-- STICKY BOTTOM BAR -->
    <section class="sticky bottom-4 z-30 grid grid-cols-2 gap-2 px-4 py-3 bg-white border border-slate-200 rounded-2xl shadow-lg">
      <Button
        variant="secondary"
        block
        :loading="isExporting"
        :disabled="isExporting || students.length === 0"
        @click="exportExcel"
      >
        <NavIcon name="download" :size="13" />
        Export Excel
      </Button>
      <Button
        variant="success"
        block
        :loading="isPublishing"
        :disabled="!hasFinalToPublish || isPublishing"
        @click="confirmPublish = true"
      >
        <NavIcon name="send" :size="13" />
        Kirim ke Wali ({{ counts.final }})
      </Button>
    </section>

    <!-- CONFIRM PUBLISH -->
    <ConfirmationDialog
      v-if="confirmPublish"
      title="Terbitkan Rapor"
      :message="`${counts.final} rapor berstatus Diperiksa di kelas ${cls?.name ?? ''} akan diubah ke status Terbit. Wali murid akan dapat men-download PDF. Lanjut?`"
      confirm-label="Terbitkan"
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
