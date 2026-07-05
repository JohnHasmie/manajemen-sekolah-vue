<!--
  LessonPlanAdminSendBackSheet.vue — admin "Kembalikan untuk revisi".

  Mirrors Flutter's `lesson_plan_admin_send_back_sheet.dart`. Always
  single-plan (no bulk equivalent — revision areas are per-RPP). The
  multi-select chip grid lists the section keys for the plan's format
  (from FORMAT_SECTION_KEYS) so the admin can flag exactly which
  parts the teacher should rework. The teacher sees these chips in
  the red/violet banner on the detail page.

  Backend contract: PUT /rpp/:id/send-back with { catatan, revision_areas }.
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
  sentBack: [];
}>();

const note = ref<string>('');
const selectedAreas = ref<Set<string>>(new Set());
const isSaving = ref(false);
const error = ref<string | null>(null);

// File-format rows have no sections — fall through to an empty grid;
// admin can still send back with just a note.
const sectionKeys = computed<string[]>(() => FORMAT_SECTION_KEYS[props.plan.format] ?? []);

function toggleArea(key: string) {
  const next = new Set(selectedAreas.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  selectedAreas.value = next;
}

function selectAll() {
  selectedAreas.value = new Set(sectionKeys.value);
}

function clearAreas() {
  selectedAreas.value = new Set();
}

async function confirm() {
  error.value = null;
  if (!note.value.trim()) {
    error.value = 'Catatan revisi wajib diisi.';
    return;
  }
  isSaving.value = true;
  try {
    await LessonPlanService.sendBack(props.plan.id, {
      note: note.value.trim(),
      revision_areas: Array.from(selectedAreas.value),
    });
    emit('sentBack');
    emit('close');
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <Modal
    title="Kembalikan untuk Revisi"
    :subtitle="`Catatan + bagian yang perlu diperbaiki akan dikirim ke ${plan.teacher_name || 'guru'}.`"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Identity -->
      <div class="bg-violet-50 border border-violet-200 rounded-xl px-3 py-3 flex items-center gap-3">
        <span class="w-10 h-10 rounded-xl bg-violet-600 text-white grid place-items-center flex-shrink-0">
          <NavIcon name="edit" :size="18" />
        </span>
        <div class="flex-1 min-w-0">
          <p class="text-[12.5px] font-bold text-slate-900 truncate">
            {{ plan.title || 'Tanpa judul' }}
          </p>
          <p class="text-2xs text-slate-600 truncate">
            {{ plan.subject_name }} · {{ plan.class_name }} · {{ plan.teacher_name }}
          </p>
        </div>
      </div>

      <!-- Revision areas (multi-select) -->
      <div v-if="sectionKeys.length > 0">
        <div class="flex items-center gap-2 mb-1.5">
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest">
            Bagian yang perlu diperbaiki
          </label>
          <span class="flex-1"></span>
          <button
            type="button"
            class="text-3xs font-bold text-violet-700 hover:text-violet-900"
            :disabled="isSaving"
            @click="selectAll"
          >
            Pilih semua
          </button>
          <button
            v-if="selectedAreas.size > 0"
            type="button"
            class="text-3xs font-bold text-slate-500 hover:text-slate-900"
            :disabled="isSaving"
            @click="clearAreas"
          >
            Bersihkan
          </button>
        </div>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="key in sectionKeys"
            :key="key"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold transition border inline-flex items-center gap-1.5"
            :class="
              selectedAreas.has(key)
                ? 'bg-violet-600 text-white border-violet-600'
                : 'bg-white text-slate-600 border-slate-200 hover:border-violet-400'
            "
            :disabled="isSaving"
            @click="toggleArea(key)"
          >
            <NavIcon
              v-if="selectedAreas.has(key)"
              name="check"
              :size="10"
            />
            {{ sectionLabel(key) }}
          </button>
        </div>
        <p class="text-3xs text-slate-400 mt-1.5">
          Opsional — kosongkan untuk minta revisi tanpa menandai bagian tertentu.
        </p>
      </div>

      <!-- Note (required) -->
      <div>
        <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1">
          Catatan revisi <span class="text-violet-700">*</span>
        </label>
        <textarea
          v-model="note"
          rows="4"
          placeholder="Jelaskan apa yang harus diperbaiki — guru bisa langsung edit dan kirim ulang."
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-violet-500 focus:ring-2 focus:ring-violet-500/15 focus:outline-none bg-white resize-none"
          :disabled="isSaving"
        />
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
        <Button variant="secondary" block :disabled="isSaving" @click="emit('close')">
          Batal
        </Button>
        <Button variant="primary" block :loading="isSaving" @click="confirm">
          <NavIcon name="send" :size="14" />
          Kembalikan
        </Button>
      </div>
    </div>
  </Modal>
</template>
