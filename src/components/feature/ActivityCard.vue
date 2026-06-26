<!--
  ActivityCard.vue — shared Activity Kelas card used by teacher /
  admin / parent overview lists.

  Mirrors Flutter's `activity_card.dart` + `admin_activity_card.dart`
  in one component, role-toggled via props:

    ┌─────────────────────────────────────────────────────────────┐
    │ ▌ Title.................................. [Buka ›]          │
    │   📅 14 Apr · 09:30  [Tugas]  [Khusus]  · 8A · IPA          │
    │   Description preview (admin) / teacher name chip (parent)  │
    │   ▰▰▰▰▰▱▱▱  14/30 submit · Rerata 82.5                      │
    │   [Refleksi] [3 lampiran]                                    │
    └─────────────────────────────────────────────────────────────┘

  Layout pieces (all optional):
    - Type accent bar (left, 4px) — color-coded per ACTIVITY_TYPE_COLORS
    - Title + chevron CTA
    - Meta row (date · time · type pill · "Khusus" pill · class·subject)
    - Description preview (2 lines, optional)
    - Teacher name chip (parent view: surface owner; admin view: shows under meta)
    - Submission progress bar (only when activity has tracking)
    - Tags row (Refleksi / lampiran)
    - Unread dot (parent only)
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  ACTIVITY_TYPE_COLORS,
  ACTIVITY_TYPE_LABELS,
  submissionHasTracking,
  submissionProgress,
  type ClassActivity,
} from '@/types/class-activity';
import { formatRelative } from '@/lib/format';

interface Props {
  activity: ClassActivity;
  /**
   * Role drives what extra meta to show:
   *   - teacher: hides teacher name (it's always the viewer); shows
   *     submission progress + Catat Submit affordance
   *   - admin:   shows teacher name; shows submission progress
   *   - parent:  shows teacher name; hides submission progress; shows
   *     unread dot when `activity.is_read === false`
   */
  role?: 'teacher' | 'admin' | 'parent';
  /**
   * When true, render a 1-line truncated description preview.
   * Admin hub uses this; teacher list opts for tighter cards.
   */
  showDescription?: boolean;
  /** Show small "Buka ›" CTA on the right. Defaults to true. */
  showOpenCta?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  role: 'teacher',
  showDescription: false,
  showOpenCta: true,
});

defineEmits<{
  /** Card body click — drill into detail. */
  click: [activity: ClassActivity];
}>();

const accent = computed(() => ACTIVITY_TYPE_COLORS[props.activity.type]);
const typeLabel = computed(() => ACTIVITY_TYPE_LABELS[props.activity.type]);

const hasTracking = computed(() =>
  submissionHasTracking(props.activity.submissions),
);
const progress = computed(() => submissionProgress(props.activity.submissions));

const progressBarTone = computed(() => {
  const p = progress.value;
  if (p >= 0.8) return 'bg-emerald-500';
  if (p >= 0.4) return 'bg-amber-500';
  return 'bg-red-500';
});

const isUnread = computed(
  () => props.role === 'parent' && props.activity.is_read === false,
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
    class="bg-white border rounded-2xl p-3.5 hover:shadow-sm transition-all cursor-pointer flex items-start gap-3 relative"
    :class="
      isUnread
        ? 'border-brand-cobalt/40 ring-1 ring-brand-cobalt/10'
        : 'border-slate-200 hover:border-brand-cobalt/30'
    "
    @click="$emit('click', activity)"
  >
    <!-- Unread dot (parent only) -->
    <span
      v-if="isUnread"
      class="absolute top-3 right-3 w-2 h-2 rounded-full bg-brand-cobalt"
      aria-label="Belum dibaca"
    />

    <!-- Type accent bar (left, 4px) -->
    <span
      class="w-1 self-stretch rounded-full flex-shrink-0"
      :style="{ backgroundColor: accent }"
    />

    <div class="flex-1 min-w-0">
      <!-- Title + CTA -->
      <div class="flex items-start gap-2">
        <p
          class="flex-1 text-[14px] font-bold text-slate-900 leading-tight line-clamp-2"
          :class="{ 'pr-4': isUnread }"
        >
          {{ activity.title }}
        </p>
        <div
          v-if="showOpenCta && !isUnread"
          class="text-brand-cobalt/70 font-bold text-[11px] flex-shrink-0 inline-flex items-center gap-0.5"
        >
          Buka
          <NavIcon name="chevron-right" :size="12" />
        </div>
      </div>

      <!-- Meta row -->
      <div class="flex items-center gap-2 mt-1.5 flex-wrap text-[11px] text-slate-500">
        <span class="inline-flex items-center gap-1">
          <NavIcon name="calendar" :size="11" />
          <span class="tabular-nums">{{ formatDateShort(activity.date) }}</span>
          <span v-if="activity.time" class="text-slate-400 ml-0.5">· {{ activity.time }}</span>
        </span>
        <span class="text-slate-300">·</span>
        <span class="text-slate-500">{{ formatRelative(activity.date) }}</span>

        <!-- Type pill -->
        <span
          class="text-[10px] font-bold px-1.5 py-0.5 rounded ml-1"
          :style="{
            backgroundColor: accent + '1a',
            color: accent,
          }"
        >
          {{ typeLabel }}
        </span>

        <!-- "Khusus" pill -->
        <span
          v-if="activity.is_specific_target"
          class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-violet-100 text-violet-700"
        >
          Khusus
        </span>

        <span class="ml-auto text-[10px] text-slate-400 truncate max-w-[180px]">
          {{ activity.class_name }}
          <template v-if="activity.subject_name"> · {{ activity.subject_name }}</template>
        </span>
      </div>

      <!-- Description preview (admin/optional) -->
      <p
        v-if="showDescription && activity.description"
        class="text-[11px] text-slate-600 leading-relaxed mt-1.5 line-clamp-2"
      >
        {{ activity.description }}
      </p>

      <!-- Teacher chip (admin + parent — teacher name yang punya activity) -->
      <p
        v-if="role !== 'teacher' && activity.teacher_name"
        class="text-[10px] text-slate-500 mt-1 truncate"
      >
        Oleh <span class="font-semibold">{{ activity.teacher_name }}</span>
      </p>

      <!-- Submission progress (teacher + admin only — parent doesn't track) -->
      <div v-if="role !== 'parent' && hasTracking" class="mt-2.5">
        <div class="flex items-center justify-between mb-1 text-[10px] font-bold text-slate-500">
          <span>
            <span class="text-slate-900 font-extrabold tabular-nums">{{ activity.submissions.submitted + activity.submissions.late }}</span>
            <span class="text-slate-400 tabular-nums"> / {{ activity.submissions.total_students }}</span>
            submit
            <span
              v-if="activity.submissions.avg_score !== null"
              class="text-slate-300 ml-1"
            >
              · Rerata
              <span class="tabular-nums font-extrabold text-slate-700">
                {{ Math.round(activity.submissions.avg_score * 10) / 10 }}
              </span>
            </span>
          </span>
          <span class="tabular-nums">{{ Math.round(progress * 100) }}%</span>
        </div>
        <div class="h-1 rounded-full overflow-hidden bg-slate-100">
          <div
            class="h-full rounded-full transition-all"
            :class="progressBarTone"
            :style="{ width: `${progress * 100}%` }"
          />
        </div>
      </div>

      <!-- Tag row -->
      <div
        v-if="activity.has_reflection || activity.attachment_count > 0"
        class="flex gap-1.5 mt-2 flex-wrap"
      >
        <span
          v-if="activity.has_reflection"
          class="text-[9px] font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 uppercase tracking-wider"
        >
          Refleksi
        </span>
        <span
          v-if="activity.attachment_count > 0"
          class="text-[9px] font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 uppercase tracking-wider"
        >
          {{ activity.attachment_count }} lampiran
        </span>
      </div>
    </div>
  </article>
</template>
