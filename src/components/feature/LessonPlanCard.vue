<!--
  LessonPlanCard.vue — shared RPP card used by teacher + admin lists.

  Mirrors Flutter's `lesson_plan_card.dart` + `lesson_plan_admin_card.dart`
  collapsed into one role-aware component:

    ┌───────────────────────────────────────────────────────────────┐
    │ ▌ Title.....................................   [Buka ›]       │
    │   📄 K13 · Bab 3   ⬤ Pending   ✨ AI                          │
    │   8A · IPA · Mas Yahya · 12 Apr · Rev. 1                       │
    │   "Belum lengkap di bagian penilaian"   (admin note when set)  │
    └───────────────────────────────────────────────────────────────┘

  Layout pieces:
    - Format accent bar (left, 4px, color from FORMAT_COLORS[format])
    - Title + chevron CTA
    - Meta row: format short pill · status dot+label · AI sparkle (when ai_generated)
    - Sub-meta: class · subject · teacher (admin only) · relative date · revision
    - Admin note quote — shown when status=Rejected or SentBack and admin_notes present
    - File attachment chip when format=file
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  FORMAT_COLORS,
  FORMAT_SHORT_LABELS,
  STATUS_LABELS,
  STATUS_TONES,
  type LessonPlan,
} from '@/types/lesson-plans';
import { formatRelative } from '@/lib/format';

interface Props {
  plan: LessonPlan;
  /**
   * 'teacher' hides the teacher name (the viewer is the owner).
   * 'admin' surfaces teacher name in the sub-meta row.
   */
  role?: 'teacher' | 'admin';
  /** When true, render a 1-line description (notes) preview. */
  showNotes?: boolean;
  showOpenCta?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  role: 'teacher',
  showNotes: false,
  showOpenCta: true,
});

defineEmits<{ click: [plan: LessonPlan] }>();

const accent = computed(() => FORMAT_COLORS[props.plan.format]);
const formatLabel = computed(() => FORMAT_SHORT_LABELS[props.plan.format]);
const statusTone = computed(() => STATUS_TONES[props.plan.status]);
const statusLabel = computed(() => STATUS_LABELS[props.plan.status]);

/** Highlight admin's revision note for SentBack / Rejected rows. */
const showAdminNote = computed(
  () =>
    (props.plan.status === 'Rejected' || props.plan.status === 'SentBack') &&
    !!props.plan.admin_notes,
);

function formatDateShort(iso: string): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleDateString('id-ID', {
      day: '2-digit',
      month: 'short',
    });
  } catch {
    return iso;
  }
}
</script>

<template>
  <article
    class="bg-white border border-slate-200 rounded-2xl p-3.5 hover:border-brand-cobalt/30 hover:shadow-sm transition-all cursor-pointer flex items-start gap-3"
    @click="$emit('click', plan)"
  >
    <!-- Format accent bar -->
    <span
      class="w-1 self-stretch rounded-full flex-shrink-0"
      :style="{ backgroundColor: accent }"
    />

    <div class="flex-1 min-w-0">
      <!-- Title + CTA -->
      <div class="flex items-start gap-2">
        <p class="flex-1 text-[14px] font-bold text-slate-900 leading-tight line-clamp-2">
          {{ plan.title || 'Tanpa judul' }}
        </p>
        <div
          v-if="showOpenCta"
          class="text-brand-cobalt/70 font-bold text-2xs flex-shrink-0 inline-flex items-center gap-0.5"
        >
          Buka
          <NavIcon name="chevron-right" :size="12" />
        </div>
      </div>

      <!-- Meta row: format pill · status · AI -->
      <div class="flex items-center gap-1.5 mt-1.5 flex-wrap text-3xs">
        <span
          class="font-bold px-1.5 py-0.5 rounded uppercase tracking-wider"
          :style="{ backgroundColor: accent + '1a', color: accent }"
        >
          {{ formatLabel }}
        </span>
        <span
          class="font-bold px-1.5 py-0.5 rounded border inline-flex items-center gap-1"
          :class="[statusTone.bg, statusTone.text, statusTone.border]"
        >
          <span class="w-1.5 h-1.5 rounded-full" :class="statusTone.dot" />
          {{ statusLabel }}
        </span>
        <span
          v-if="plan.ai_generated"
          class="font-bold px-1.5 py-0.5 rounded bg-violet-100 text-violet-700 uppercase tracking-wider inline-flex items-center gap-1"
        >
          <NavIcon name="sparkles" :size="9" />
          AI
        </span>
        <span
          v-if="plan.revision > 1"
          class="font-semibold text-slate-500"
        >
          · Rev. {{ plan.revision }}
        </span>
      </div>

      <!-- Sub-meta: class · subject · (teacher) · date -->
      <p class="text-2xs text-slate-500 mt-1.5 truncate">
        {{ plan.class_name || '—' }}
        <template v-if="plan.subject_name"> · {{ plan.subject_name }}</template>
        <template v-if="role === 'admin' && plan.teacher_name">
          · <span class="font-semibold text-slate-700">{{ plan.teacher_name }}</span>
        </template>
        <template v-if="plan.created_at">
          · <span class="tabular-nums">{{ formatDateShort(plan.created_at) }}</span>
          <span class="text-slate-400"> ({{ formatRelative(plan.created_at) }})</span>
        </template>
      </p>

      <!-- Notes preview (optional) -->
      <p
        v-if="showNotes && plan.notes"
        class="text-2xs text-slate-600 leading-relaxed mt-1.5 line-clamp-2"
      >
        {{ plan.notes }}
      </p>

      <!-- Admin revision note (when Rejected / SentBack) -->
      <div
        v-if="showAdminNote"
        class="mt-2 px-2.5 py-1.5 rounded-lg border-l-2 text-2xs leading-relaxed"
        :class="
          plan.status === 'Rejected'
            ? 'bg-red-50 border-red-400 text-red-800'
            : 'bg-violet-50 border-violet-400 text-violet-800'
        "
      >
        <p class="text-4xs font-bold uppercase tracking-widest mb-0.5 opacity-70">
          {{ plan.status === 'Rejected' ? 'Alasan Tolak' : 'Catatan Revisi' }}
        </p>
        <p class="line-clamp-2">{{ plan.admin_notes }}</p>
      </div>

      <!-- File attachment chip -->
      <div
        v-if="plan.format === 'file' && plan.file_name"
        class="mt-2 inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-slate-100 text-3xs text-slate-600 font-medium max-w-full"
      >
        <NavIcon name="file-text" :size="11" />
        <span class="truncate max-w-[200px]">{{ plan.file_name }}</span>
        <span v-if="plan.file_size_mb" class="text-slate-400 flex-shrink-0">
          · {{ plan.file_size_mb }} MB
        </span>
      </div>
    </div>
  </article>
</template>
