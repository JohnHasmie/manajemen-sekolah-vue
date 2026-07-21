<!--
  AdminImportExcelModal.vue — shared Excel import modal for admin
  Manajemen Data pages.

  Two-step, verify-first flow:
    1. Upload — pick the .xlsx/.xls/.csv, then "Verifikasi".
    2. Preview — a dry-run (server runs the importer in a rolled-back
       transaction) shows exactly what WOULD happen per row — akan
       ditambahkan / diperbarui / dilewati / perlu ditinjau / gagal —
       WITHOUT persisting. "Konfirmasi & Impor" then commits.

  So an admin can never be surprised by a bulk import: they always see
  the outcome before anything is written.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import {
  AdminDataExcelService,
  type AdminEntity,
  type AdminImportResult,
  type ImportDetailRow,
} from '@/services/admin-data-excel.service';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  entity: AdminEntity;
  /** Title shown — defaults to "Import Data". */
  title?: string;
}>();

const emit = defineEmits<{
  close: [];
  // The committed import result — the same shape the service resolves to.
  done: [AdminImportResult];
}>();

const entityGuidance = computed<string | null>(() => {
  switch (props.entity) {
    case 'subject':
      return (
        'Template mapel sekarang punya 2 kolom opsional: ' +
        'Kelas (1–12) untuk membedakan mapel per tingkat, dan ' +
        'Master untuk menautkan ke master data (opsional, ' +
        'membantu sinkron rekap nilai antar sekolah).'
      );
    default:
      return null;
  }
});

const step = ref<'upload' | 'preview'>('upload');
const file = ref<File | null>(null);
const preview = ref<AdminImportResult | null>(null);
const isVerifying = ref(false);
const isCommitting = ref(false);
const isDownloadingTpl = ref(false);
const err = ref<string | null>(null);

function onFileChange(e: Event) {
  const target = e.target as HTMLInputElement;
  const picked = target.files?.[0] ?? null;
  if (!picked) {
    file.value = null;
    return;
  }
  if (!/\.(xlsx|xls|csv)$/i.test(picked.name)) {
    err.value = 'Format file harus .xlsx / .xls / .csv.';
    target.value = '';
    return;
  }
  if (picked.size > 10 * 1024 * 1024) {
    err.value = 'Ukuran file maks 10 MB.';
    target.value = '';
    return;
  }
  err.value = null;
  file.value = picked;
}

async function downloadTemplate() {
  isDownloadingTpl.value = true;
  try {
    await AdminDataExcelService.downloadTemplate(props.entity);
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isDownloadingTpl.value = false;
  }
}

/** Step 1 → 2: dry-run preview, nothing is written yet. */
async function verify() {
  if (!file.value) return;
  isVerifying.value = true;
  err.value = null;
  try {
    preview.value = await AdminDataExcelService.importExcel(props.entity, file.value, {
      dryRun: true,
    });
    step.value = 'preview';
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isVerifying.value = false;
  }
}

/** Step 2: commit for real. */
async function commit() {
  if (!file.value) return;
  isCommitting.value = true;
  err.value = null;
  try {
    const res = await AdminDataExcelService.importExcel(props.entity, file.value);
    emit('done', res);
    emit('close');
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isCommitting.value = false;
  }
}

function back() {
  step.value = 'upload';
  preview.value = null;
  err.value = null;
}

// ── Preview grouping (mirrors the post-import result dialog, phrased as
// "akan …" since nothing is committed yet). ──────────────────────────────
interface Section {
  key: string;
  title: string;
  statuses: ImportDetailRow['status'][];
  card: string;
  badge: string;
}
const SECTIONS: Section[] = [
  { key: 'added', title: 'Akan ditambahkan', statuses: ['created', 'restored'], card: 'border-emerald-200 bg-emerald-50', badge: 'bg-emerald-200 text-emerald-800' },
  { key: 'updated', title: 'Akan diperbarui', statuses: ['updated'], card: 'border-sky-200 bg-sky-50', badge: 'bg-sky-200 text-sky-800' },
  { key: 'skipped', title: 'Dilewati', statuses: ['skipped'], card: 'border-slate-200 bg-slate-50', badge: 'bg-slate-200 text-slate-700' },
  { key: 'conflict', title: 'Perlu ditinjau', statuses: ['conflict'], card: 'border-amber-200 bg-amber-50', badge: 'bg-amber-200 text-amber-800' },
  { key: 'failed', title: 'Gagal', statuses: ['failed'], card: 'border-red-200 bg-red-50', badge: 'bg-red-200 text-red-800' },
];

const groups = computed(() => {
  const details = preview.value?.details ?? [];
  return SECTIONS.map((s) => ({
    ...s,
    rows: details.filter((d) => s.statuses.includes(d.status)),
  })).filter((s) => s.rows.length > 0);
});

const summary = computed(() => {
  const details = preview.value?.details ?? [];
  const countBy = (statuses: ImportDetailRow['status'][]) =>
    details.filter((d) => statuses.includes(d.status)).length;
  const parts: string[] = [];
  const added = countBy(['created', 'restored']);
  const updated = countBy(['updated']);
  const skipped = countBy(['skipped']);
  const conflicts = countBy(['conflict']);
  const failed = countBy(['failed']);
  if (added > 0) parts.push(`${added} akan ditambahkan`);
  if (updated > 0) parts.push(`${updated} akan diperbarui`);
  if (skipped > 0) parts.push(`${skipped} dilewati`);
  if (conflicts > 0) parts.push(`${conflicts} perlu ditinjau`);
  if (failed > 0) parts.push(`${failed} gagal`);
  return parts.join(' · ');
});

/** Nothing importable → don't offer a commit that would be a no-op. */
const hasImportable = computed(() => {
  const details = preview.value?.details ?? [];
  return details.some((d) => ['created', 'restored', 'updated'].includes(d.status));
});
</script>

<template>
  <Modal
    :title="title ?? 'Import Data dari Excel'"
    :subtitle="step === 'preview' ? (summary || 'Pratinjau — belum disimpan') : 'Unduh template, isi, lalu verifikasi'"
    size="md"
    @close="emit('close')"
  >
    <!-- ── STEP 1: upload ─────────────────────────────────────────── -->
    <div v-if="step === 'upload'" class="space-y-3">
      <section class="bg-slate-50 rounded-xl p-3 space-y-2">
        <p class="text-2xs text-slate-600 leading-relaxed">
          Template sudah berisi data yang ada sekarang (kolom ID tersembunyi).
          Edit di tempat lalu verifikasi — kamu akan lihat perubahannya sebelum
          disimpan.
        </p>
        <p
          v-if="entityGuidance"
          class="text-2xs text-amber-800 bg-amber-50 border border-amber-200 rounded-lg p-2 leading-relaxed"
        >
          {{ entityGuidance }}
        </p>
        <Button variant="secondary" size="sm" :loading="isDownloadingTpl" @click="downloadTemplate">
          <NavIcon name="download" :size="12" />
          Unduh Template
        </Button>
      </section>

      <label
        class="block border-2 border-dashed border-slate-300 hover:border-role-admin rounded-xl p-4 cursor-pointer transition-colors"
        :class="file ? 'bg-role-admin/5 border-role-admin' : 'bg-slate-50'"
      >
        <input
          type="file"
          accept=".xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          class="sr-only"
          @change="onFileChange"
        />
        <div class="flex items-center gap-3">
          <div
            class="w-10 h-10 rounded-xl grid place-items-center"
            :class="file ? 'bg-role-admin/15 text-role-admin' : 'bg-slate-200 text-slate-500'"
          >
            <NavIcon name="upload" :size="18" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ file ? file.name : 'Pilih file Excel' }}
            </p>
            <p class="text-2xs text-slate-500 mt-0.5">XLSX / XLS / CSV · maks 10 MB</p>
          </div>
        </div>
      </label>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button variant="primary" block :loading="isVerifying" :disabled="!file || isVerifying" @click="verify">
          Verifikasi
        </Button>
      </div>
    </div>

    <!-- ── STEP 2: preview (dry-run) ──────────────────────────────── -->
    <div v-else class="space-y-3">
      <p class="text-2xs text-slate-500 leading-relaxed">
        Ini pratinjau — <span class="font-bold">belum ada yang disimpan</span>.
        Periksa lalu konfirmasi untuk menyimpan.
      </p>

      <div class="max-h-80 overflow-y-auto space-y-3 pr-0.5">
        <section v-for="g in groups" :key="g.key" class="space-y-1.5">
          <h3 class="text-2xs font-black uppercase tracking-wider text-slate-500">
            {{ g.title }} ({{ g.rows.length }})
          </h3>
          <div v-for="r in g.rows" :key="`${g.key}-${r.row}`" class="rounded-lg border p-2.5" :class="g.card">
            <div class="flex items-center justify-between gap-2">
              <p class="text-[12.5px] font-bold text-slate-900 truncate">{{ r.label || '—' }}</p>
              <span class="text-4xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full flex-shrink-0" :class="g.badge">
                {{ g.title }}
              </span>
            </div>
            <p v-if="r.sublabel" class="text-2xs text-slate-500 mt-0.5">{{ r.sublabel }}</p>
            <p v-if="r.reason" class="text-2xs text-slate-700 mt-1 leading-relaxed">{{ r.reason }}</p>
          </div>
        </section>

        <p v-if="groups.length === 0" class="text-2xs text-slate-500 text-center py-4">
          Tidak ada baris yang bisa diproses dari file ini.
        </p>
      </div>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-1">
        <Button variant="secondary" block :disabled="isCommitting" @click="back">Kembali</Button>
        <Button variant="primary" block :loading="isCommitting" :disabled="isCommitting || !hasImportable" @click="commit">
          Konfirmasi & Impor
        </Button>
      </div>
    </div>
  </Modal>
</template>
