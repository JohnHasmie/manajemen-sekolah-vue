<!--
  TutorTutoring2AssessmentCreateView.vue — greenfield "Buat try-out"
  form for the tutor-mobile Vue shell (bimbel rebuild).

  This is a full route view (not a modal), so we do NOT reuse
  FormSheet (which wraps <Modal>). Instead we mirror its
  Batal / Simpan footer inside a plain rounded-3xl surface — same
  visual language, view-shaped instead of sheet-shaped.

  On success calls TutoringBimbelService.createAssessment, fires
  a success toast, and routes back to the list.

  Route: teacher/tutoring2/assessments/new
-->
<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useToast } from '@/composables/useToast';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

const router = useRouter();
const toast = useToast();

// ─── Form state ───────────────────────────────────────────────────
const title = ref('');
const programId = ref('');
const learningGroupId = ref('');
const kind = ref<'tryout' | 'latihan' | 'kuis'>('tryout');
const assessmentDate = ref('');
const maxScore = ref<number>(100);
const kkm = ref<number | null>(null);
const description = ref('');
const saving = ref(false);

const KIND_OPTIONS: Array<{ value: 'tryout' | 'latihan' | 'kuis'; label: string }> = [
  { value: 'tryout', label: 'Try-out' },
  { value: 'latihan', label: 'Latihan' },
  { value: 'kuis', label: 'Kuis' },
];

// ─── Submit ───────────────────────────────────────────────────────
async function submit() {
  if (saving.value) return;
  if (!title.value.trim() || !programId.value.trim() || !learningGroupId.value.trim()) {
    toast.error('Judul, program, dan kelompok wajib diisi');
    return;
  }
  saving.value = true;
  try {
    await TutoringBimbelService.createAssessment({
      title: title.value.trim(),
      program_id: programId.value.trim(),
      learning_group_id: learningGroupId.value.trim(),
      kind: kind.value,
      assessment_date: assessmentDate.value || undefined,
      max_score: maxScore.value,
      kkm: kkm.value,
      description: description.value.trim() || undefined,
    });
    toast.success('Try-out dibuat');
    router.push({ name: 'teacher.tutoring2.assessments' });
  } catch (e) {
    toast.error((e as Error).message || 'Gagal membuat try-out');
  } finally {
    saving.value = false;
  }
}

function onAiClick() {
  toast.info('AI belum aktif');
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      kicker="Tutor Bimbel"
      title="Buat try-out"
    />

    <!-- AI generate soal placeholder — tinted brand-cobalt panel -->
    <button
      type="button"
      class="w-full flex items-center gap-3 rounded-lg bg-brand-cobalt/5 text-brand-cobalt px-4 py-3 hover:bg-brand-cobalt/10 transition-colors"
      @click="onAiClick"
    >
      <span class="w-8 h-8 rounded-lg grid place-items-center bg-brand-cobalt/10">
        <NavIcon name="sparkles" :size="16" />
      </span>
      <span class="flex-1 text-left">
        <span class="block text-sm font-bold">AI generate soal</span>
        <span class="block text-2xs text-brand-cobalt/70">Buat draft soal otomatis dari topik</span>
      </span>
      <NavIcon name="chevron-right" :size="18" />
    </button>

    <form class="rounded-3xl border border-slate-100 bg-white shadow-sm p-5 space-y-4" @submit.prevent="submit">
      <div class="space-y-1.5">
        <label for="assessment-title" class="text-xs font-bold text-slate-600 uppercase tracking-wider">Judul</label>
        <input
          id="assessment-title"
          v-model="title"
          type="text"
          placeholder="Misal: Try-out UTBK #3"
          class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div class="space-y-1.5">
          <label for="assessment-program" class="text-xs font-bold text-slate-600 uppercase tracking-wider">Program ID</label>
          <input
            id="assessment-program"
            v-model="programId"
            type="text"
            placeholder="UUID program"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm font-mono focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
          />
        </div>
        <div class="space-y-1.5">
          <label for="assessment-group" class="text-xs font-bold text-slate-600 uppercase tracking-wider">Kelompok ID</label>
          <input
            id="assessment-group"
            v-model="learningGroupId"
            type="text"
            placeholder="UUID learning group"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm font-mono focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
          />
        </div>
      </div>

      <div class="space-y-1.5">
        <p class="text-xs font-bold text-slate-600 uppercase tracking-wider">Jenis</p>
        <div class="inline-flex rounded-xl border border-slate-200 bg-slate-50 p-1">
          <button
            v-for="opt in KIND_OPTIONS"
            :key="opt.value"
            type="button"
            class="px-4 py-1.5 text-xs font-bold rounded-lg transition-colors"
            :class="kind === opt.value ? 'bg-white text-brand-cobalt shadow-sm' : 'text-slate-500 hover:text-slate-700'"
            @click="kind = opt.value"
          >
            {{ opt.label }}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div class="space-y-1.5">
          <label for="assessment-date" class="text-xs font-bold text-slate-600 uppercase tracking-wider">Tanggal</label>
          <input
            id="assessment-date"
            v-model="assessmentDate"
            type="date"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
          />
        </div>
        <div class="space-y-1.5">
          <label for="assessment-max" class="text-xs font-bold text-slate-600 uppercase tracking-wider">Skor maks</label>
          <input
            id="assessment-max"
            v-model.number="maxScore"
            type="number"
            min="1"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
          />
        </div>
        <div class="space-y-1.5">
          <label for="assessment-kkm" class="text-xs font-bold text-slate-600 uppercase tracking-wider">KKM (opsional)</label>
          <input
            id="assessment-kkm"
            v-model.number="kkm"
            type="number"
            min="0"
            placeholder="—"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
          />
        </div>
      </div>

      <div class="space-y-1.5">
        <label for="assessment-desc" class="text-xs font-bold text-slate-600 uppercase tracking-wider">Deskripsi</label>
        <textarea
          id="assessment-desc"
          v-model="description"
          rows="3"
          placeholder="Catatan singkat untuk peserta"
          class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
        />
      </div>

      <div class="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" size="md" type="button" @click="router.back()">Batal</Button>
        <Button variant="primary" size="md" type="submit" :loading="saving">Simpan try-out</Button>
      </div>
    </form>
  </div>
</template>
