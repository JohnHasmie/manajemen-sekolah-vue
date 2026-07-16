<!--
  LessonPlanGenerateModal.vue — AI generate setup sheet (Frame B + C).

  Mirrors Flutter's `lesson_plan_format_chooser_sheet.dart` +
  `lesson_plan_setup_sheet.dart` collapsed into one modal:

    1. Format chooser row — k13 / 1 halaman / modul ajar
       (file routes to a separate upload sheet in Phase 5).
    2. Setup form — Kelas + Mapel pickers, Bab dropdown + optional
       Sub-bab dropdown, Durasi (JP × menit), Pendekatan / fokus.
    3. Submit → emits `generate` with the validated payload.

  The Bab dropdown loads the chapter tree for the picked subject via
  `MaterialService.getTree` (same source the Flutter setup sheet uses)
  so the emitted payload carries a real `chapter_id` (uuid) — the AI
  backend requires it, unlike the old free-text "Bab" field.

  The parent owns the polling overlay + navigation to detail on done.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  FORMAT_COLORS,
  FORMAT_ICONS,
  FORMAT_LABELS,
  FORMAT_LONG_LABELS,
  type LessonPlanFormat,
} from '@/types/lesson-plans';
import type { Classroom, Subject } from '@/types/entities';
import type { Chapter } from '@/types/materials';
import { MaterialService } from '@/services/materials.service';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { subjectLabel } from '@/lib/labels';

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
  chapter_id: string;
  sub_chapter_id?: string;
  /** Human label ("Bab 3 — Energi") for the polling overlay subtitle. */
  chapter_label?: string;
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
const chapterId = ref<string>('');
const subChapterId = ref<string>('');
const durationMinutes = ref<number>(90);
const approach = ref<string>('Project-based learning · diskusi kelompok');

const error = ref<string | null>(null);

// ── Chapter tree (loaded per selected subject) ──
// The AI backend keys generation off a real `chapter_id`, so we load
// the same chapter tree the Materi page / Flutter setup sheet uses and
// let the teacher pick one. Reload whenever the subject changes; the
// previous chapter / sub-chapter selection is cleared so we never send
// a chapter that belongs to a different subject.
const chapters = ref<Chapter[]>([]);
const chaptersLoading = ref(false);

const activeChapter = computed(
  () => chapters.value.find((c) => c.id === chapterId.value) ?? null,
);
const subChapters = computed(() => activeChapter.value?.sub_chapters ?? []);

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

/**
 * Load the chapter tree for the currently-selected subject. Clears any
 * stale chapter / sub-chapter choice first so the dropdown never points
 * at a chapter from a different subject while the fetch is in flight.
 */
async function loadChapters(subId: string) {
  chapterId.value = '';
  subChapterId.value = '';
  if (!subId) {
    chapters.value = [];
    return;
  }
  chaptersLoading.value = true;
  try {
    // Scope by the picked class' grade_level when known so kelas-7 RPP
    // doesn't surface kelas-8 chapters. Backend also folds in legacy
    // universal (grade IS NULL) rows so nothing goes missing during
    // the per-grade migration.
    const gl = activeClass.value?.grade_level ?? null;
    const tree = await MaterialService.getTree({
      subject_id: subId,
      grade_level: gl,
    });
    chapters.value = tree.chapters;
  } catch {
    chapters.value = [];
  } finally {
    chaptersLoading.value = false;
  }
}

// React to subject changes (manual pick OR seeded initialSubjectId).
watch(subjectId, (id) => loadChapters(id), { immediate: true });

// React to class changes so switching kelas re-scopes the bab list to
// the new grade — the picker was previously fixed on the subject only.
watch(classId, () => {
  if (subjectId.value) loadChapters(subjectId.value);
});

// Reset the sub-bab choice whenever the chapter changes.
watch(chapterId, () => {
  subChapterId.value = '';
});

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
  if (!chapterId.value) {
    error.value = 'Pilih bab terlebih dahulu.';
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
  const chapter = activeChapter.value;
  const chapterLabel = chapter
    ? [chapter.label, chapter.name].filter((p) => p && p.length > 0).join(' — ')
    : undefined;
  emit('generate', {
    format: format.value,
    class_id: classId.value,
    subject_id: subjectId.value,
    chapter_id: chapterId.value,
    sub_chapter_id: subChapterId.value || undefined,
    chapter_label: chapterLabel,
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
        <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-2">
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
        <p class="text-3xs text-slate-400 mt-2 leading-relaxed">
          Format <strong>{{ FORMAT_LONG_LABELS[format] }}</strong> akan menentukan bagian yang dibuat AI.
        </p>
      </div>

      <!-- KELAS + MAPEL -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
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
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
            Mata Pelajaran
          </label>
          <select
            v-model="subjectId"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
            :disabled="busy"
          >
            <option value="">Pilih mapel…</option>
            <option v-for="s in subjects" :key="s.id" :value="s.id">
              {{ subjectLabel(s) }}
            </option>
          </select>
        </div>
      </div>

      <!-- BAB (chapter dropdown) + optional SUB-BAB -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
            Bab
          </label>
          <select
            v-model="chapterId"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50 disabled:text-slate-400"
            :disabled="busy || chaptersLoading || !subjectId || chapters.length === 0"
          >
            <option value="">
              {{
                !subjectId
                  ? 'Pilih mapel dulu…'
                  : chaptersLoading
                    ? 'Memuat bab…'
                    : chapters.length === 0
                      ? 'Belum ada bab'
                      : 'Pilih bab…'
              }}
            </option>
            <option v-for="ch in chapters" :key="ch.id" :value="ch.id">
              {{ ch.label }} — {{ ch.name }}
            </option>
          </select>
          <p
            v-if="subjectId && !chaptersLoading && chapters.length === 0"
            class="text-3xs text-amber-600 mt-1 leading-snug"
          >
            Mapel ini belum punya bab. Tambahkan materi di menu Materi
            terlebih dahulu, atau pilih mapel lain.
          </p>
        </div>
        <div>
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
            Sub-bab <span class="text-slate-400 normal-case font-medium">(opsional)</span>
          </label>
          <select
            v-model="subChapterId"
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] font-medium focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white disabled:bg-slate-50 disabled:text-slate-400"
            :disabled="busy || !chapterId || subChapters.length === 0"
          >
            <option value="">Semua / tanpa sub-bab</option>
            <option v-for="sub in subChapters" :key="sub.id" :value="sub.id">
              {{ sub.name }}
            </option>
          </select>
          <p class="text-3xs text-slate-400 mt-1 leading-snug">
            Kosongkan untuk membuat RPP untuk seluruh bab.
          </p>
        </div>
      </div>

      <!-- DURASI + PENDEKATAN -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div>
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
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
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
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
        class="bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 text-2xs text-slate-600 inline-flex items-center gap-2"
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
