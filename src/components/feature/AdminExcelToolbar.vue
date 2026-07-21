<!--
  AdminExcelToolbar.vue — shared admin Manajemen-Data Excel action bar.

  Replaces the old kebab `AdminDataMenu` (Menu ▾) and the per-page
  icon-only affordances with ONE row of friendly, LABELLED buttons:
    Refresh · Export Excel · Import Excel (template download lives inside
    the Import dialog, so there's no separate header button for it)

  Self-contained: it owns the import + result dialogs and calls
  `AdminDataExcelService` directly, so a host page only writes

    <AdminExcelToolbar
      entity="teacher" entity-label="guru"
      :read-only="ayReadOnly" @imported="reload" @refresh="reload" />

  instead of re-declaring export/template/import handlers + both modals.

  Sits in the BrandPageHeader `header-actions` slot (on the role-admin
  gradient), so the buttons use the glass-on-banner style shared with
  the Jadwal header + the export-contrast fix (!986).
-->
<script setup lang="ts">
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  AdminDataExcelService,
  type AdminEntity,
  type AdminImportResult,
  type ImportDetailRow,
  type ImportWarningRow,
} from '@/services/admin-data-excel.service';
import { useToast } from '@/composables/useToast';
import AdminImportExcelModal from '@/components/feature/AdminImportExcelModal.vue';
import AdminImportResultModal from '@/components/feature/AdminImportResultModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    /** Which backend entity these actions target. */
    entity: AdminEntity;
    /** Singular Indonesian noun for the result dialog + toasts (e.g. "guru"). */
    entityLabel: string;
    /** Title for the import modal — defaults to the modal's own fallback. */
    importTitle?: string;
    /** Read-only academic year — disables Import (writes), keeps downloads. */
    readOnly?: boolean;
    /** Show Export Excel (Jadwal exports PDF, not Excel → pass false). */
    showExport?: boolean;
    /** Show the Refresh button. */
    showRefresh?: boolean;
    /**
     * Fire the built-in summary toast after import. Pass false when the
     * host builds its own richer toast (e.g. subject import's orphan
     * follow-up) — the result dialog is still shown either way.
     */
    showSummaryToast?: boolean;
  }>(),
  {
    importTitle: undefined,
    readOnly: false,
    showExport: true,
    showRefresh: true,
    showSummaryToast: true,
  },
);

const emit = defineEmits<{
  /** Refresh pressed — the host reloads its list. */
  refresh: [];
  /**
   * A successful import committed — the host reloads to show new rows.
   * Carries the raw result so a host can run extra follow-up (e.g. the
   * subject page's orphan-resync CTA).
   */
  imported: [AdminImportResult];
}>();

const { t } = useI18n();
const toast = useToast();

const isExporting = ref(false);

// Import + result dialog state — owned here so host pages don't repeat it.
const showImport = ref(false);
const importDetails = ref<ImportDetailRow[]>([]);
const importWarnings = ref<ImportWarningRow[]>([]);
const importCounts = ref<{
  imported?: number;
  created?: number;
  updated?: number;
  restored?: number;
  skipped?: number;
  conflicts?: number;
  failed?: number;
}>({});

async function exportExcel() {
  if (isExporting.value) return;
  isExporting.value = true;
  try {
    await AdminDataExcelService.exportExcel(props.entity);
    toast.success(t('common.excel.exported'));
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    isExporting.value = false;
  }
}

function onImportDone(res: AdminImportResult) {
  // Surface EVERY processed row (not just conflicts/failures) in the shared
  // result dialog so the admin sees exactly what happened to each entry.
  importDetails.value = res.details ?? [];
  importWarnings.value = res.warnings ?? [];
  importCounts.value = {
    imported: res.imported,
    created: res.created,
    updated: res.updated,
    restored: res.restored,
    skipped: res.skipped ?? 0,
    conflicts: res.conflicts ?? 0,
    failed: res.failed,
  };

  // Truthful summary toast — "sudah terdaftar" is a harmless no-op, so only
  // genuine failures / conflicts colour it as an error. Hosts that build
  // their own richer toast pass :show-summary-toast="false".
  if (props.showSummaryToast) {
    const skipped = res.skipped ?? 0;
    const conflicts = res.conflicts ?? 0;
    const parts = [
      t('common.excel.importedCount', { count: res.imported, label: props.entityLabel }),
    ];
    if (skipped > 0) parts.push(t('common.excel.skippedCount', { count: skipped }));
    if (conflicts > 0) parts.push(t('common.excel.conflictsCount', { count: conflicts }));
    if (res.failed > 0) parts.push(t('common.excel.failedCount', { count: res.failed }));
    const message = `${parts.join(' · ')}.`;
    if (res.failed > 0 || conflicts > 0) toast.error(message);
    else toast.success(message);
  }

  emit('imported', res);
}

function closeResult() {
  importDetails.value = [];
  importWarnings.value = [];
  importCounts.value = {};
}

// Shared classes for the glass-on-banner secondary buttons.
const btnBase =
  'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-[11.5px] font-bold ' +
  'transition-colors disabled:opacity-60 disabled:cursor-not-allowed';
const btnGlass = `${btnBase} text-white bg-white/15 border border-white/25 hover:bg-white/25`;
// Import is the primary write action — a solid white chip reads as the
// emphasised call-to-action against the gradient.
const btnSolid = `${btnBase} text-role-admin bg-white hover:bg-white/90 border border-transparent`;
</script>

<template>
  <div class="flex items-center gap-2 flex-wrap justify-end">
    <button
      v-if="showRefresh"
      type="button"
      :class="btnGlass"
      @click="emit('refresh')"
    >
      <NavIcon name="refresh-cw" :size="12" />
      {{ t('common.excel.refresh') }}
    </button>

    <button
      v-if="showExport"
      type="button"
      :class="btnGlass"
      :disabled="isExporting"
      @click="exportExcel"
    >
      <NavIcon name="download" :size="12" />
      {{ t('common.excel.exportExcel') }}
    </button>

    <button
      type="button"
      :class="btnSolid"
      :disabled="readOnly"
      @click="showImport = true"
    >
      <NavIcon name="upload" :size="12" />
      {{ t('common.excel.importExcel') }}
    </button>

    <!-- Import + result dialogs teleport to <body>, so their position in
         this flex row is irrelevant. -->
    <AdminImportExcelModal
      v-if="showImport"
      :entity="entity"
      :title="importTitle"
      @close="showImport = false"
      @done="onImportDone"
    />

    <AdminImportResultModal
      v-if="importDetails.length > 0"
      :entity-label="entityLabel"
      :details="importDetails"
      :counts="importCounts"
      :warnings="importWarnings"
      @close="closeResult"
    />
  </div>
</template>
