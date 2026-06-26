<!--
  LessonPlanRegenSheet.vue — per-section AI regeneration picker.

  Web port of `lesson_plan_regen_sheet.dart`. Multi-select chip grid
  of section keys, optional context/instructions, single primary
  "Generate ulang" CTA. Submit fires
  `LessonPlanService.regenerateSections(id, sectionKeys[])` and
  returns the `job_id` so the parent can hand off to the polling
  overlay.

  Why a sheet instead of inline buttons per section:
    - Teacher usually wants to redo 2-3 sections at once (e.g. all
      "activity" fields after changing the approach), not one at a
      time — clicking 3 separate regen buttons fires 3 separate jobs
      and racks up the AI quota.
    - The optional context box lets the teacher tell the model "make
      this more student-centered" once instead of editing the original
      generate payload.

  The parent flips to LessonPlanAiPollingOverlay when this sheet
  emits `started(job_id)`.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { LessonPlanService } from '@/services/lesson-plans.service';
import {
  FORMAT_SECTION_KEYS,
  sectionLabel,
  type LessonPlan,
} from '@/types/lesson-plans';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  plan: LessonPlan;
}>();

const emit = defineEmits<{
  close: [];
  /** Fires once the AI backend returns a job_id. Parent owns polling. */
  started: [
    payload: { jobId: string; sectionKeys: string[]; subtitle: string },
  ];
}>();

const sectionKeys = computed<string[]>(
  () => FORMAT_SECTION_KEYS[props.plan.format] ?? [],
);

const selectedKeys = ref<Set<string>>(new Set());
const isSubmitting = ref(false);
const error = ref<string | null>(null);

function toggle(key: string) {
  const next = new Set(selectedKeys.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  selectedKeys.value = next;
}

function selectAll() {
  selectedKeys.value = new Set(sectionKeys.value);
}

function clearAll() {
  selectedKeys.value = new Set();
}

async function submit() {
  error.value = null;
  if (selectedKeys.value.size === 0) {
    error.value = 'Pilih minimal satu bagian untuk diregenerasi.';
    return;
  }
  isSubmitting.value = true;
  try {
    const keys = Array.from(selectedKeys.value);
    const { job_id } = await LessonPlanService.regenerateSections(
      props.plan.id,
      keys,
    );
    if (!job_id) throw new Error('Server tidak mengembalikan job_id.');
    emit('started', {
      jobId: job_id,
      sectionKeys: keys,
      subtitle: `${keys.length} bagian · ${keys.map(sectionLabel).join(' · ')}`,
    });
    emit('close');
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSubmitting.value = false;
  }
}

const canSubmit = computed(
  () => selectedKeys.value.size > 0 && !isSubmitting.value,
);
</script>

<template>
  <Modal
    title="Regenerasi Bagian"
    subtitle="Pilih bagian yang ingin ditulis ulang oleh AI. Bagian lain tidak diubah."
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Format context strip -->
      <div
        v-if="sectionKeys.length === 0"
        class="bg-amber-50 border border-amber-200 rounded-lg px-3 py-2.5 text-[12px] text-amber-800"
      >
        Format <strong>{{ plan.format }}</strong> tidak memiliki bagian terstruktur — regenerasi AI tidak tersedia.
      </div>

      <!-- Selection toolbar -->
      <div v-if="sectionKeys.length > 0" class="flex items-center gap-2">
        <span class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
          Pilih bagian
        </span>
        <span class="text-[10px] text-slate-400 tabular-nums">
          · {{ selectedKeys.size }}/{{ sectionKeys.length }} dipilih
        </span>
        <span class="flex-1"></span>
        <button
          type="button"
          class="text-[10.5px] font-bold text-violet-700 hover:text-violet-900"
          :disabled="isSubmitting"
          @click="selectAll"
        >
          Pilih semua
        </button>
        <button
          v-if="selectedKeys.size > 0"
          type="button"
          class="text-[10.5px] font-bold text-slate-500 hover:text-slate-900"
          :disabled="isSubmitting"
          @click="clearAll"
        >
          Bersihkan
        </button>
      </div>

      <!-- Section chip grid -->
      <div v-if="sectionKeys.length > 0" class="flex flex-wrap gap-1.5">
        <button
          v-for="key in sectionKeys"
          :key="key"
          type="button"
          class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border inline-flex items-center gap-1.5"
          :class="
            selectedKeys.has(key)
              ? 'bg-violet-600 text-white border-violet-600'
              : 'bg-white text-slate-600 border-slate-200 hover:border-violet-400'
          "
          :disabled="isSubmitting"
          @click="toggle(key)"
        >
          <NavIcon
            v-if="selectedKeys.has(key)"
            name="check"
            :size="10"
          />
          {{ sectionLabel(key) }}
        </button>
      </div>

      <!-- Warning -->
      <div
        v-if="selectedKeys.size > 0"
        class="rounded-xl bg-violet-50 border border-violet-200 px-3 py-2.5 text-[12px] text-violet-900 inline-flex items-start gap-2"
      >
        <NavIcon name="info" :size="13" class="mt-0.5 flex-shrink-0 text-violet-700" />
        <span>
          {{ selectedKeys.size }} bagian akan <strong>ditulis ulang</strong> oleh AI.
          Isi yang ada akan diganti — pastikan sudah disimpan jika perlu.
        </span>
      </div>

      <!-- Error -->
      <div
        v-if="error"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-[12px] text-red-700"
      >
        {{ error }}
      </div>

      <!-- Footer -->
      <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" block :disabled="isSubmitting" @click="emit('close')">
          Batal
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSubmitting"
          :disabled="!canSubmit"
          @click="submit"
        >
          <NavIcon name="sparkles" :size="14" />
          {{
            selectedKeys.size === 0
              ? 'Pilih bagian'
              : `Generate ulang ${selectedKeys.size}`
          }}
        </Button>
      </div>
    </div>
  </Modal>
</template>
