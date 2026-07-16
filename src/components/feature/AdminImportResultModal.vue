<!--
  AdminImportResultModal.vue — shared post-import result dialog for the
  4 admin Manajemen Data pages (Guru / Siswa / Kelas / Mapel).

  After an Excel import the backend now returns a `details[]` array with
  EVERY processed row (not just the ones that failed). This dialog groups
  those rows by status so the admin sees exactly what happened to each
  entry — added, already there, needs review, or failed — instead of a
  bare toast count. Modelled on the old bespoke teacher "Perlu ditinjau"
  review dialog, generalised to cover all four statuses + entities.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type {
  ImportDetailRow,
  ImportWarningRow,
} from '@/services/admin-data-excel.service';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';

const props = withDefaults(
  defineProps<{
    /** Singular entity noun for the header, e.g. "guru" / "siswa" / "kelas" / "mapel". */
    entityLabel: string;
    /** Every processed row, already normalised by the service. */
    details: ImportDetailRow[];
    /** Summary counts (some importers only set a subset — missing = 0). */
    counts: {
      imported?: number;
      skipped?: number;
      conflicts?: number;
      failed?: number;
    };
    /**
     * Non-blocking per-row annotations attached to rows that DID
     * import (post-!453 subject import: unresolved Master name). Empty
     * for importers that don't emit warnings.
     */
    warnings?: ImportWarningRow[];
  }>(),
  { warnings: () => [] },
);

const emit = defineEmits<{ close: [] }>();

/**
 * Section descriptor — one visual group of rows, keyed by the status(es)
 * it collects. Order + colours are fixed by the spec:
 *   created + restored → Ditambahkan (emerald)
 *   skipped            → Sudah terdaftar / dilewati (slate)
 *   conflict           → Perlu ditinjau (amber)
 *   failed             → Gagal (red)
 */
interface Section {
  key: string;
  title: string;
  statuses: ImportDetailRow['status'][];
  card: string;
  badge: string;
}

const SECTIONS: Section[] = [
  {
    key: 'added',
    title: 'Ditambahkan',
    statuses: ['created', 'restored'],
    card: 'border-emerald-200 bg-emerald-50',
    badge: 'bg-emerald-200 text-emerald-800',
  },
  {
    key: 'skipped',
    title: 'Sudah terdaftar / dilewati',
    statuses: ['skipped'],
    card: 'border-slate-200 bg-slate-50',
    badge: 'bg-slate-200 text-slate-700',
  },
  {
    key: 'conflict',
    title: 'Perlu ditinjau',
    statuses: ['conflict'],
    card: 'border-amber-200 bg-amber-50',
    badge: 'bg-amber-200 text-amber-800',
  },
  {
    key: 'failed',
    title: 'Gagal',
    statuses: ['failed'],
    card: 'border-red-200 bg-red-50',
    badge: 'bg-red-200 text-red-800',
  },
];

/** Non-empty sections, each carrying its matched rows. */
const groups = computed(() =>
  SECTIONS.map((s) => ({
    ...s,
    rows: props.details.filter((d) => s.statuses.includes(d.status)),
  })).filter((s) => s.rows.length > 0),
);

/** Whether any conflict row is present — drives the bottom hint. */
const hasConflicts = computed(() =>
  props.details.some((d) => d.status === 'conflict'),
);

/**
 * Header summary line, e.g. "3 ditambahkan · 18 sudah terdaftar · 1 perlu
 * ditinjau". Zero parts are omitted. Falls back to counting `details` per
 * status when a given count wasn't supplied by the importer.
 */
const summary = computed(() => {
  const countBy = (statuses: ImportDetailRow['status'][]) =>
    props.details.filter((d) => statuses.includes(d.status)).length;

  const imported = props.counts.imported ?? countBy(['created', 'restored']);
  const skipped = props.counts.skipped ?? countBy(['skipped']);
  const conflicts = props.counts.conflicts ?? countBy(['conflict']);
  const failed = props.counts.failed ?? countBy(['failed']);
  const warningsCount = props.warnings?.length ?? 0;

  const parts: string[] = [];
  if (imported > 0) parts.push(`${imported} ditambahkan`);
  if (skipped > 0) parts.push(`${skipped} sudah terdaftar`);
  if (conflicts > 0) parts.push(`${conflicts} perlu ditinjau`);
  if (failed > 0) parts.push(`${failed} gagal`);
  if (warningsCount > 0) parts.push(`${warningsCount} perlu perhatian`);
  return parts.join(' · ');
});
</script>

<template>
  <Modal
    :title="`Hasil impor ${entityLabel}`"
    :subtitle="summary || undefined"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <section v-for="g in groups" :key="g.key" class="space-y-2">
        <h3 class="text-2xs font-black uppercase tracking-wider text-slate-500">
          {{ g.title }} ({{ g.rows.length }})
        </h3>
        <div
          v-for="r in g.rows"
          :key="`${g.key}-${r.row}`"
          class="rounded-xl border p-3"
          :class="g.card"
        >
          <div class="flex items-center justify-between gap-2">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ r.label || '—' }}
            </p>
            <span
              class="text-4xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full flex-shrink-0"
              :class="g.badge"
            >
              {{ g.title }}
            </span>
          </div>
          <p v-if="r.sublabel" class="text-2xs text-slate-500 mt-0.5">
            {{ r.sublabel }}
          </p>
          <p v-if="r.reason" class="text-2xs text-slate-700 mt-1.5 leading-relaxed">
            {{ r.reason }}
          </p>
        </div>
      </section>

      <!--
        Non-blocking warnings — rows below imported successfully but need
        follow-up (subject import: unresolved Master name). Kept in its
        own section so it doesn't visually compete with successes.
      -->
      <section v-if="warnings && warnings.length > 0" class="space-y-2">
        <h3 class="text-2xs font-black uppercase tracking-wider text-amber-700">
          Peringatan ({{ warnings.length }})
        </h3>
        <p class="text-2xs text-slate-500 leading-relaxed">
          Baris berikut berhasil diimpor, tapi perlu tindak lanjut manual.
        </p>
        <div
          v-for="w in warnings"
          :key="`warn-${w.row}`"
          class="rounded-xl border p-3 border-amber-200 bg-amber-50"
        >
          <div class="flex items-center justify-between gap-2">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ w.label || '—' }}
            </p>
            <span
              class="text-4xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full flex-shrink-0 bg-amber-200 text-amber-800"
            >
              Baris {{ w.row }}
            </span>
          </div>
          <p v-if="w.sublabel" class="text-2xs text-slate-500 mt-0.5">
            {{ w.sublabel }}
          </p>
          <p class="text-2xs text-amber-900 mt-1.5 leading-relaxed">
            {{ w.message }}
          </p>
        </div>
      </section>

      <p
        v-if="hasConflicts"
        class="text-2xs text-slate-500 leading-relaxed"
      >
        "Perlu ditinjau" biasanya karena email sudah dipakai akun lain.
        Tambahkan {{ entityLabel }} tersebut secara manual lalu konfirmasi
        saat diminta.
      </p>

      <Button variant="primary" block @click="emit('close')">Mengerti</Button>
    </div>
  </Modal>
</template>
