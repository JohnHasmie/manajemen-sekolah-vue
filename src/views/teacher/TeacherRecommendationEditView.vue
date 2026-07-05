<!--
  TeacherRecommendationEditView.vue — Edit rekomendasi (Frame E).

  Web port of `recommendation_edit_screen.dart`. Route entry:
    /teacher/recommendations/edit/:recId

  Layout:
    1. Back chevron row + Simpan action
    2. BrandPageHeader (teacher) — kicker + title with rec title preview
    3. Body cards:
       a. Judul       (text input)
       b. Prioritas   (chip strip: high / medium / low)
       c. Deskripsi   (Quill rich-text via AppRichTextEditor)
       d. Materi Terkait (chip strip — tap chip to remove; add via
                          inline composer below)
       e. Catatan Homeroom Teacher (textarea)
    4. Sticky footer (Batal / Simpan)

  Endpoints:
    GET   /recommendations/{id}                        — hydrate
    PATCH /recommendations/{id}                        — save edits
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from '@/stores/auth';
import { RecommendationService } from '@/services/recommendations.service';
import {
  PRIORITY_LABELS,
  PRIORITY_TONES,
  type LearningRecommendation,
  type RecMaterial,
  type RecPriority,
} from '@/types/recommendations';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import AppRichTextEditor from '@/components/ui/AppRichTextEditor.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const { t } = useI18n();

const recId = computed(() => String(route.params.recId ?? ''));

// ── Data state ──
const original = ref<LearningRecommendation | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const isSaving = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Editable fields ──
const titleField = ref<string>('');
const descriptionHtml = ref<string>('');
const priority = ref<RecPriority>('medium');
const materials = ref<RecMaterial[]>([]);
const notes = ref<string>('');

// ── Add-material composer (inline) ──
const newMaterialTitle = ref<string>('');
const newMaterialUrl = ref<string>('');

const teacherId = computed(() => auth.teacherId ?? auth.user?.id ?? '');

// ── Loaders ──
async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const rec = await RecommendationService.getLearningRec(recId.value);
    if (!rec) {
      loadError.value = t('tutor.sekolah.recommendationEdit.notFound');
      return;
    }
    original.value = rec;
    // Seed editable fields.
    titleField.value = rec.title;
    descriptionHtml.value = rec.description ?? '';
    priority.value = rec.priority;
    materials.value = rec.materials ? rec.materials.map((m) => ({ ...m })) : [];
    notes.value = rec.teacher_notes ?? '';
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => {
  if (!recId.value) {
    loadError.value = t('tutor.sekolah.recommendationEdit.invalidId');
    isLoading.value = false;
    return;
  }
  load();
});

// ── Material ops ──
function addMaterial() {
  const matTitle = newMaterialTitle.value.trim();
  if (!matTitle) return;
  materials.value = [
    ...materials.value,
    {
      title: matTitle,
      url: newMaterialUrl.value.trim() || null,
      source: 'manual',
    },
  ];
  newMaterialTitle.value = '';
  newMaterialUrl.value = '';
}

function removeMaterial(idx: number) {
  materials.value = materials.value.filter((_, i) => i !== idx);
}

// ── Dirty check (gate Simpan) ──
const isDirty = computed(() => {
  const o = original.value;
  if (!o) return false;
  if (titleField.value.trim() !== o.title) return true;
  if ((descriptionHtml.value ?? '') !== (o.description ?? '')) return true;
  if (priority.value !== o.priority) return true;
  if (notes.value !== (o.teacher_notes ?? '')) return true;
  const om = o.materials ?? [];
  if (materials.value.length !== om.length) return true;
  for (let i = 0; i < materials.value.length; i++) {
    if (
      materials.value[i].title !== om[i].title ||
      (materials.value[i].url ?? null) !== (om[i].url ?? null)
    ) {
      return true;
    }
  }
  return false;
});

// ── Save ──
async function save() {
  if (!original.value || !isDirty.value) return;
  if (!teacherId.value) {
    toast.value = {
      message: t('tutor.sekolah.recommendationEdit.teacherProfileMissing'),
      tone: 'error',
    };
    return;
  }
  if (!titleField.value.trim()) {
    toast.value = { message: t('tutor.sekolah.recommendationEdit.titleRequired'), tone: 'error' };
    return;
  }
  isSaving.value = true;
  try {
    const updated = await RecommendationService.updateRec({
      rec_id: original.value.id,
      teacher_id: teacherId.value,
      title: titleField.value.trim(),
      description: descriptionHtml.value || undefined,
      priority: priority.value,
      teacher_notes: notes.value.trim() || undefined,
      materials: materials.value,
    });
    if (updated) {
      toast.value = { message: t('tutor.sekolah.recommendationEdit.savedToast'), tone: 'success' };
      // Bounce back to result so the homeroom teacher sees the patched row.
      goBack();
    } else {
      toast.value = {
        message: t('tutor.sekolah.recommendationEdit.savedNoDataToast'),
        tone: 'success',
      };
    }
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// ── State for AsyncView ──
const viewState = computed<AsyncState<LearningRecommendation>>(() => {
  if (isLoading.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (!original.value) return { status: 'empty' };
  return { status: 'content', data: original.value };
});

const PRIORITY_OPTIONS: RecPriority[] = ['high', 'medium', 'low'];

function goBack() {
  // Best-effort: return to the result screen for this student. The
  // hydrated rec carries class_id + student_id so we can reconstruct
  // the path without keeping the query stack in state.
  const o = original.value;
  if (o?.class_id && o?.student_id) {
    router.push({
      name: 'teacher.recommendations.result',
      params: { classId: o.class_id, studentId: o.student_id },
    });
    return;
  }
  router.back();
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- BACK + SAVE -->
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-brand-cobalt"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('tutor.sekolah.recommendationEdit.backToResult') }}
      </button>
      <span class="flex-1"></span>
      <Button
        v-if="original"
        variant="primary"
        size="sm"
        :loading="isSaving"
        :disabled="!isDirty || isSaving"
        @click="save"
      >
        <NavIcon name="check" :size="13" />
        {{ t('tutor.sekolah.recommendationEdit.save') }}
      </Button>
    </div>

    <AsyncView :state="viewState" :empty-title="t('tutor.sekolah.recommendationEdit.notFound')" @retry="load">
      <template #default>
        <div v-if="original" class="space-y-4">
          <!-- HEADER -->
          <BrandPageHeader
            role="guru"
            :kicker="t('tutor.sekolah.recommendationEdit.kicker')"
            :title="titleField || original.title || t('tutor.sekolah.recommendationEdit.titleFallback')"
            :meta="t('tutor.sekolah.recommendationEdit.meta', {
              student: original.student_name ?? t('tutor.sekolah.recommendationEdit.studentFallback'),
              subject: original.subject_name ?? t('tutor.sekolah.recommendationEdit.subjectFallback'),
              className: original.class_name ?? t('tutor.sekolah.recommendationEdit.classFallback')
            })"
            :live-dot="false"
          />

          <!-- JUDUL -->
          <section class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
            <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest">
              {{ t('tutor.sekolah.recommendationEdit.fieldTitle') }}
            </label>
            <input
              v-model="titleField"
              type="text"
              :placeholder="t('tutor.sekolah.recommendationEdit.titlePlaceholder')"
              class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[13px] font-bold focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
              :disabled="isSaving"
            />
          </section>

          <!-- PRIORITAS -->
          <section class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
            <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest">
              {{ t('tutor.sekolah.recommendationEdit.fieldPriority') }}
            </label>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="p in PRIORITY_OPTIONS"
                :key="p"
                type="button"
                class="px-3 py-1.5 rounded-full text-2xs font-bold transition border inline-flex items-center gap-1.5"
                :class="
                  priority === p
                    ? PRIORITY_TONES[p].pill + ' border-transparent ring-2 ring-current/30'
                    : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
                "
                :disabled="isSaving"
                @click="priority = p"
              >
                <NavIcon v-if="priority === p" name="check" :size="10" />
                {{ PRIORITY_LABELS[p] }}
              </button>
            </div>
          </section>

          <!-- DESKRIPSI (Quill) -->
          <section class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
            <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest">
              {{ t('tutor.sekolah.recommendationEdit.fieldDescription') }}
            </label>
            <AppRichTextEditor
              v-model:html="descriptionHtml"
              :placeholder="t('tutor.sekolah.recommendationEdit.descriptionPlaceholder')"
              :readonly="isSaving"
              :min-height="220"
            />
            <p class="text-3xs text-slate-400">
              {{ t('tutor.sekolah.recommendationEdit.formatHint') }}
            </p>
          </section>

          <!-- MATERI TERKAIT -->
          <section class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3">
            <div class="flex items-center gap-2">
              <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest">
                {{ t('tutor.sekolah.recommendationEdit.fieldMaterials') }}
              </label>
              <span class="text-3xs text-slate-400 tabular-nums">
                · {{ t('tutor.sekolah.recommendationEdit.materialCount', { count: materials.length }) }}
              </span>
            </div>

            <!-- Chips of existing materials -->
            <div v-if="materials.length > 0" class="flex flex-wrap gap-1.5">
              <span
                v-for="(m, idx) in materials"
                :key="idx"
                class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-100 text-slate-700 text-[11.5px] font-bold"
              >
                <NavIcon name="book" :size="10" />
                {{ m.title }}
                <button
                  type="button"
                  class="ml-1 text-slate-500 hover:text-red-700"
                  :aria-label="t('tutor.sekolah.recommendationEdit.removeMaterialAria', { title: m.title })"
                  :disabled="isSaving"
                  @click="removeMaterial(idx)"
                >
                  <NavIcon name="x" :size="10" />
                </button>
              </span>
            </div>

            <!-- Inline composer -->
            <div class="grid grid-cols-1 sm:grid-cols-[1fr_1fr_auto] gap-2 items-stretch pt-1">
              <input
                v-model="newMaterialTitle"
                type="text"
                :placeholder="t('tutor.sekolah.recommendationEdit.materialTitlePlaceholder')"
                class="rounded-lg border border-slate-200 px-3 py-2 text-[12px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
                :disabled="isSaving"
                @keyup.enter="addMaterial"
              />
              <input
                v-model="newMaterialUrl"
                type="url"
                :placeholder="t('tutor.sekolah.recommendationEdit.materialUrlPlaceholder')"
                class="rounded-lg border border-slate-200 px-3 py-2 text-[12px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white"
                :disabled="isSaving"
                @keyup.enter="addMaterial"
              />
              <Button
                variant="secondary"
                size="sm"
                :disabled="!newMaterialTitle.trim() || isSaving"
                @click="addMaterial"
              >
                <NavIcon name="plus" :size="12" />
                {{ t('tutor.sekolah.recommendationEdit.addMaterial') }}
              </Button>
            </div>
          </section>

          <!-- CATATAN -->
          <section class="bg-white border border-slate-200 rounded-2xl p-4 space-y-2">
            <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest">
              {{ t('tutor.sekolah.recommendationEdit.fieldNotes') }}
            </label>
            <textarea
              v-model="notes"
              rows="3"
              :placeholder="t('tutor.sekolah.recommendationEdit.notesPlaceholder')"
              class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-y"
              :disabled="isSaving"
            />
          </section>

          <!-- FOOTER -->
          <div class="grid grid-cols-2 gap-2 sticky bottom-2 bg-white/90 backdrop-blur rounded-2xl border border-slate-200 px-3 py-2 shadow-lg">
            <Button
              variant="secondary"
              block
              :disabled="isSaving"
              @click="goBack"
            >
              {{ t('tutor.sekolah.recommendationEdit.cancel') }}
            </Button>
            <Button
              variant="primary"
              block
              :loading="isSaving"
              :disabled="!isDirty || isSaving"
              @click="save"
            >
              <NavIcon name="check" :size="13" />
              {{ t('tutor.sekolah.recommendationEdit.saveChanges') }}
            </Button>
          </div>
        </div>
      </template>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
