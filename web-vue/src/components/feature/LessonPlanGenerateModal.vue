<!--
  LessonPlanGenerateModal.vue — AI generate setup sheet (Frame B + C).

  Mirrors Flutter's `lesson_plan_format_chooser_sheet.dart` +
  `lesson_plan_setup_sheet.dart` collapsed into one modal:

    1. Format chooser row — k13 / 1 halaman / modul ajar
       (file routes to a separate upload sheet in Phase 5).
    2. Setup form — Kelas + Mapel pickers, Bab / Sub-bab text,
       Durasi (JP × menit), Pendekatan / fokus.
    3. Submit → emits `generate` with the validated payload.

  The parent owns the polling overlay + navigation to detail on done.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import {
  FORMAT_COLORS,
  FORMAT_ICONS,
  FORMAT_LABELS,
  FORMAT_LONG_LABELS,
  type LessonPlanFormat,
} from '@/types/lesson-plans';
import type { Classroom, Subject } from '@/types/entities';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

interface Props {
  classes: Classroom[];
  subjects: Subject[];
  /** Seed values (e.g. pre-selected kelas/mapel from the filter chip). */
  initialClassId?: string;
  initialSubjectId?: string;
  initialFormat?: Exclude<LessonPlanFormat, 'file'>;
  /** Disables the form while parent kicks off the job. */
  busy?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  initialClassId: '',
  initialSubjectId: '',
  initialFormat: 'k13',
  busy: false,
});

interface GeneratePayload {
  format: Exclude<LessonPlanFormat, 'file'>;
  class_id: string;
  subject_id: string;
  chapter_label: string;
  duration_minutes: number;
  approach?: string;
}

const emit = defineEmits<{
  close: [];
  generate: [payload: GeneratePayload];
}>();

// ── Form state ──
const format = ref<Exclude<LessonPlanFormat, 'file'>>(props.initialFormat);
const classId = ref<string>(props.initialClassId);
const subjectId = ref<string>(props.initialSubjectId);
const chapterLabel = ref<string>('');
const durationMinutes = ref<number>(90);
const approach = ref<string>('Project-based learning · diskusi kelompok');

const error = ref<string | null>(null);

const FORMAT_OPTIONS: { key: Exclude<LessonPlanFormat, 'file'>; tagline: string }[] =
  [
    { key: 'k13', tagline: 'Identitas · KD · Tujuan · Kegiatan · Penilaian' },
    { key: 'rpp_1_halaman', tagline: 'Tujuan · Kegiatan · Asesmen — singkat' },
    { key: 'modul_ajar', tagline: 'Format Kurikulum Merdeka — 6 bagian' },
  ];

const activeClass = computed(
  () => props.classes.find((c) => c.id === classId.value) ?? null,
);
const activeSubject = computed(
  () => props.subjects.find((s) => s.id === subjectId.value) ?? null,
);

function pickFormat(f: Exclude<LessonPlanFormat, 'file'>) {
  format.value = f;
}

function submit() {
  error.value = null;
  if (!classId.value) {
    error.value = 'Pilih kelas terlebih dahulu.';
    return;
  }
  if (!subjectId.value) {
    error.value = 'Pilih mata pelajaran terlebih dahulu.';
    return;
  }
  if (!chapterLabel.value.trim()) {
    error.value = 'Isi bab / sub-bab yang akan dibuatkan RPP.';
    return;
  }
  if (
    !Number.isFinite(durationMinutes.value) ||
    durationMinutes.value < 30 ||
    durationMinutes.value > 180
  ) {
    error.value = 'Durasi harus antara 30 sampai 180 menit.';
    return;
  }
  emit('generate', {
    format: format.value,
    class_id: classId.value,
    subject_id: subjectId.value,
    chapter_label: chapterLabel.value.trim(),
    duration_minutes: durationMinutes.value,
    approach: approach.value.trim() || undefined,
  });
}
</script>

<template>
  <Modal
    title="Generate RPP dengan AI"
    subtitle="Pilih format, isi bab, lalu klik Generate. Hasil tersimpan sebagai Draf untuk diedit."
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- FORMAT CHOOSER -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2">
          Format RPP
        </label>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
          <button
            v-for="opt in FORMAT_OPTIONS"
            :key="opt.key"
            type="button"
            class="text-left rounded-xl border p-3 transition-all bg-white"
            :class="
              format === opt.key
                ? 'border-transparent ring-2'
                : 'border-slate-200 hover:border-slate-300'
            "
            :style="
              format === opt.key
                ? { boxShadow: `inset 0 0 0 2px ${FORMAT_COLORS[opt.key]}`, color: FORMAT_COLORS[opt.key] }
                : {}
            "
            :disabled="busy"
            @click="pickFormat(opt.key)"
          >
            <div class="flex items-center gap-2">
              <span
                class="w-7 h-7 rounded-lg grid place-items-center flex-shrink-0"
                :style="{
                  backgroundColor: FORMAT_COLORS[opt.key] + '1a',
                  color: FORMAT_COLORS[opt.key],
                }"
              >
                <NavIcon :name="FORMAT_ICONS[opt.key]" :size="14" />
              </span>
              <span class="font-black text-[12px] leading-tight">
                {{ FORMAT_LABELS[opt.key] }}
              </span>
            </div>
            <p class="text-[10.5px] text-slate-500 mt-1.5 leading-snug">
              {{ opt.tagline }}
            </p>
          </button>
        </div>
        <p class="text-[10px] text-slate-400 mt-2 leading-relaxed">
          Format <strong>{{ FORMAT_LONG_LABELS[format] }}</strong> akan menentukan bagian yang dibuat AI.
        </p>
      </div>

      <!-- KELAS + MAPEL -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
            Kelas
          </label>
          <select
            v-model="classId"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
            :disabled="busy"
          >
            <option value="">Pilih kelas…</option>
            <option v-for="c in classes" :key="c.id" :value="c.id">
              {{ c.name }}
            </option>
          </select>
        </div>
        <div>
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
            Mata Pelajaran
          </label>
          <select
            v-model="subjectId"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
            :disabled="busy"
          >
            <option value="">Pilih mapel…</option>
            <option v-for="s in subjects" :key="s.id" :value="s.id">
              {{ s.name }}
            </option>
          </select>
        </div>
      </div>

      <!-- BAB / SUB-BAB -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
          Bab / Sub-bab
        </label>
        <input
          v-model="chapterLabel"
          type="text"
          placeholder="Contoh: Bab 3 · Energi & Perubahannya"
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
          :disabled="busy"
        />
        <p class="text-[10px] text-slate-400 mt-1">
          Tulis judul bab / sub-bab persis seperti di buku panduan.
        </p>
      </div>

      <!-- DURASI + PENDEKATAN -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div>
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
            Durasi (menit)
          </label>
          <input
            v-model.number="durationMinutes"
            type="number"
            min="30"
            max="180"
            step="5"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] tabular-nums focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
            :disabled="busy"
          />
        </div>
        <div class="sm:col-span-2">
          <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
            Pendekatan / fokus
          </label>
          <input
            v-model="approach"
            type="text"
            placeholder="Contoh: Project-based learning · diskusi kelompok"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
            :disabled="busy"
          />
        </div>
      </div>

      <!-- CONTEXT PREVIEW -->
      <div
        v-if="activeClass || activeSubject"
        class="bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 text-[11px] text-slate-600 inline-flex items-center gap-2"
      >
        <NavIcon name="info" :size="12" class="text-slate-400 flex-shrink-0" />
        <span class="truncate">
          AI akan membuat RPP {{ FORMAT_LABELS[format] }}
          <template v-if="activeClass">untuk <strong>{{ activeClass.name }}</strong></template>
          <template v-if="activeSubject"> · <strong>{{ activeSubject.name }}</strong></template>.
        </span>
      </div>

      <!-- ERROR -->
      <div
        v-if="error"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-[12px] text-red-700"
      >
        {{ error }}
      </div>

      <!-- FOOTER -->
      <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" block :disabled="busy" @click="emit('close')">
          Batal
        </Button>
        <Button variant="primary" block :loading="busy" @click="submit">
          <NavIcon name="sparkles" :size="14" />
          Generate sekarang
        </Button>
      </div>
    </div>
  </Modal>
</template>
