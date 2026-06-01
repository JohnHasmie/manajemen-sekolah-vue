<!--
  LessonPlanSectionEditorModal.vue — single-section editor for RPP.

  Mirrors Flutter's `lesson_plan_section_editor_sheet.dart` minus the
  Quill rich-text editor (Phase 8 enhancement). Each section gets its
  own scoped editor sheet with a textarea + single Save action.

  On save:
    PUT /rpp/:id  with  { format_data: { [fieldKey]: newValue } }

  The backend merges partial JSONB so other sections are untouched —
  see `LessonPlanService.update` for the contract.

  Result emitted: { fieldKey, newValue } so the parent can swap the
  local copy without refetching the full detail.
-->
<script setup lang="ts">
import { ref } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AppRichTextEditor from '@/components/ui/AppRichTextEditor.vue';
import { LessonPlanService } from '@/services/lesson-plans.service';

const props = withDefaults(
  defineProps<{
    lessonPlanId: string;
    fieldKey: string;
    fieldLabel: string;
    currentValue: string;
    /** Optional format label shown in the subtitle (e.g. "K13"). */
    formatLabel?: string;
    /**
     * When set, also offer a violet "Generate ulang" affordance that
     * regenerates this single section via the AI backend. Returns a
     * job_id the parent screen can poll.
     */
    canRegenerate?: boolean;
  }>(),
  { formatLabel: '', canRegenerate: false },
);

const emit = defineEmits<{
  close: [];
  saved: [payload: { fieldKey: string; newValue: string }];
  regenerate: [fieldKey: string];
}>();

const draft = ref<string>(props.currentValue);
const isSaving = ref(false);
const error = ref<string | null>(null);

async function save() {
  error.value = null;
  isSaving.value = true;
  try {
    await LessonPlanService.update(props.lessonPlanId, {
      format_data: { [props.fieldKey]: draft.value },
    });
    emit('saved', { fieldKey: props.fieldKey, newValue: draft.value });
    emit('close');
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

function regen() {
  emit('regenerate', props.fieldKey);
}
</script>

<template>
  <Modal
    :title="`Edit ${fieldLabel}`"
    :subtitle="formatLabel ? `Format ${formatLabel} · perubahan disimpan ke bagian ini saja` : 'Perubahan disimpan ke bagian ini saja'"
    size="xl"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Editor — Quill rich text (parity with Flutter flutter_quill). -->
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          Isi {{ fieldLabel }}
        </label>
        <AppRichTextEditor
          v-model:html="draft"
          :placeholder="`Tulis ${fieldLabel.toLowerCase()}…`"
          :readonly="isSaving"
          :min-height="440"
        />
        <p class="text-[10px] text-slate-400 mt-1.5">
          Gunakan toolbar di atas untuk heading, list, dan penekanan. Format tersimpan persis seperti di mobile.
        </p>
      </div>

      <!-- Error -->
      <div
        v-if="error"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-[12px] text-red-700"
      >
        {{ error }}
      </div>

      <!-- Footer -->
      <div class="flex items-center gap-2 pt-2 border-t border-slate-100">
        <button
          v-if="canRegenerate"
          type="button"
          class="inline-flex items-center gap-1.5 text-[11px] font-bold text-violet-700 hover:text-violet-900"
          :disabled="isSaving"
          @click="regen"
        >
          <NavIcon name="sparkles" :size="12" />
          Generate ulang
        </button>
        <span class="flex-1"></span>
        <Button variant="secondary" size="sm" :disabled="isSaving" @click="emit('close')">
          Batal
        </Button>
        <Button variant="primary" size="sm" :loading="isSaving" @click="save">
          Simpan
        </Button>
      </div>
    </div>
  </Modal>
</template>
