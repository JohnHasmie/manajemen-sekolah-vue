<!--
  RecommendationCard.vue — shared per-rec card (Frame C + G).

  Web port of `lib/features/recommendations/presentation/widgets/
  recommendation_card.dart`. Used by both teacher result view and
  parent inbox detail (parent variant hides the share/edit/toggle
  affordances).

  Layout, top to bottom:
    ┌─────────────────────────────────────────────────────────┐
    │ ▌ [TINGGI] [REMEDIATION] [MENUNGGU] [DIBACA WALI · 3/5] │
    │                                                          │
    │ Latih ulang SPLDV bab 4               [✎]               │
    │ Catatan AI berbentuk HTML rendered…                      │
    │                                                          │
    │ ┃ AI REASONING                                           │
    │ ┃ Why this matters paragraph…                            │
    │                                                          │
    │ ▤ Materi terkait                                        │
    │   • LKS Bab 4 SPLDV                                      │
    │   • Video Bab 4                                          │
    │                                                          │
    │ 👁 3 dari 5 wali sudah baca (terkirim 2 jam lalu)        │
    │ ─────────────────────────────────────────                │
    │ ⏰ Jatuh tempo: Jumat 30 Mei                              │
    │ [Riwayat]                  [✓ Tandai Diterapkan]         │
    └─────────────────────────────────────────────────────────┘

  Priority accent strip:
    - high   → red (Prioritas Tinggi)
    - medium → amber (Prioritas Sedang)
    - low    → indigo (Prioritas Rendah)
    - completed status overrides → emerald

  Share-state pill:
    - !shared_with_parent_at → "BELUM DIKIRIM" slate
    - shared, no read        → "TERKIRIM" cobalt
    - shared, ≥1 read        → "DIBACA WALI · n/m" emerald
-->
<script setup lang="ts">
import { computed } from 'vue';
import {
  PRIORITY_LABELS,
  PRIORITY_TONES,
  STATUS_LABELS,
  STATUS_TONES,
  type LearningRecommendation,
} from '@/types/recommendations';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import { formatRelative } from '@/lib/format';

const props = withDefaults(
  defineProps<{
    rec: LearningRecommendation;
    /** Disable the status toggle while a save is in flight. */
    isUpdatingStatus?: boolean;
    /** Hide teacher-only affordances (edit/share/toggle). */
    readonly?: boolean;
  }>(),
  { isUpdatingStatus: false, readonly: false },
);

const emit = defineEmits<{
  toggleStatus: [rec: LearningRecommendation];
  edit: [rec: LearningRecommendation];
  share: [rec: LearningRecommendation];
  viewHistory: [rec: LearningRecommendation];
}>();

// ── Derived ─────────────────────────────────────────────────────────

const isCompleted = computed(() => props.rec.status === 'completed');

const accentColor = computed(() => {
  if (isCompleted.value) return '#059669'; // emerald-600
  return PRIORITY_TONES[props.rec.priority].accent;
});

const accentStripStyle = computed(() => ({
  backgroundColor: accentColor.value,
}));

const priorityPillClass = computed(() => PRIORITY_TONES[props.rec.priority].pill);

const typePillLabel = computed(() => props.rec.type.toUpperCase().replace(/_/g, ' '));

// ── Share state ─────────────────────────────────────────────────────

const hasBeenShared = computed(() => {
  const ts = props.rec.shared_with_parent_at;
  if (!ts) return false;
  const total = props.rec.share_recipient_count ?? 0;
  return total > 0;
});

const shareTotal = computed(() => props.rec.share_recipient_count ?? 0);
const shareReadCount = computed(() => props.rec.share_read_count ?? 0);

const sharePillKind = computed<'none' | 'sent' | 'read'>(() => {
  if (!hasBeenShared.value) return 'none';
  if (shareReadCount.value > 0) return 'read';
  return 'sent';
});

const sharePillLabel = computed(() => {
  switch (sharePillKind.value) {
    case 'read':
      return `DIBACA · ${shareReadCount.value}/${shareTotal.value}`;
    case 'sent':
      return `TERKIRIM · ${shareTotal.value}`;
    default:
      return 'BELUM DIKIRIM';
  }
});

const sharePillClass = computed(() => {
  switch (sharePillKind.value) {
    case 'read':
      return 'bg-emerald-100 text-emerald-700';
    case 'sent':
      return 'bg-brand-cobalt/15 text-brand-cobalt';
    default:
      return 'bg-slate-100 text-slate-500';
  }
});

// Backend allows sharing any non-dismissed rec — pending too (the AI
// generates them already "approved" at write time, mirroring Flutter).
const isShareable = computed(() => props.rec.status !== 'dismissed');

// ── Status pill ─────────────────────────────────────────────────────
const statusTone = computed(() => STATUS_TONES[props.rec.status]);
const statusLabel = computed(() => STATUS_LABELS[props.rec.status]);

// ── Time helpers ────────────────────────────────────────────────────
const sharedRelative = computed(() => {
  const ts = props.rec.shared_with_parent_at;
  if (!ts) return '';
  return formatRelative(ts);
});

const dueRelative = computed(() => {
  const d = props.rec.due_date;
  if (!d) return null;
  try {
    const dt = new Date(d);
    return {
      relative: formatRelative(d),
      display: dt.toLocaleDateString('id-ID', {
        weekday: 'short',
        day: '2-digit',
        month: 'short',
      }),
    };
  } catch {
    return null;
  }
});
</script>

<template>
  <article class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
    <div class="flex">
      <!-- LEFT ACCENT STRIP -->
      <span class="w-1 flex-shrink-0" :style="accentStripStyle" />

      <div class="flex-1 min-w-0 p-3.5 space-y-3">
        <!-- PILL ROW -->
        <div class="flex items-center gap-1.5 flex-wrap">
          <span
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[9.5px] font-bold uppercase tracking-wider"
            :class="priorityPillClass"
          >
            {{ PRIORITY_LABELS[rec.priority] }}
          </span>
          <span
            class="inline-flex items-center px-2 py-0.5 rounded-full text-[9.5px] font-bold bg-slate-100 text-slate-600 uppercase tracking-wider"
          >
            {{ typePillLabel }}
          </span>
          <span
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[9.5px] font-bold border uppercase tracking-wider"
            :class="[statusTone.bg, statusTone.text, statusTone.border]"
          >
            <span class="w-1.5 h-1.5 rounded-full" :class="statusTone.dot" />
            {{ statusLabel }}
          </span>
          <span
            class="inline-flex items-center px-2 py-0.5 rounded-full text-[9.5px] font-bold uppercase tracking-wider"
            :class="sharePillClass"
          >
            {{ sharePillLabel }}
          </span>
        </div>

        <!-- TITLE + EDIT PENCIL -->
        <div class="flex items-start gap-2">
          <h3 class="text-[14px] font-black text-slate-900 leading-tight flex-1 min-w-0">
            {{ rec.title || 'Rekomendasi' }}
          </h3>
          <button
            v-if="!readonly && rec.status !== 'completed'"
            type="button"
            class="w-7 h-7 rounded-full grid place-items-center text-slate-500 hover:bg-slate-100 hover:text-brand-cobalt flex-shrink-0"
            :aria-label="`Edit ${rec.title}`"
            @click="emit('edit', rec)"
          >
            <NavIcon name="edit" :size="13" />
          </button>
        </div>

        <!-- DESCRIPTION (HTML) -->
        <div
          v-if="rec.description"
          class="rpp-prose"
          v-html="rec.description"
        />

        <!-- AI REASONING -->
        <div
          v-if="rec.ai_reasoning"
          class="bg-violet-50 border-l-4 border-violet-500 rounded-r-lg px-3 py-2.5"
        >
          <p class="text-[9.5px] font-black text-violet-700 uppercase tracking-widest mb-1 inline-flex items-center gap-1.5">
            <NavIcon name="sparkles" :size="11" />
            AI Reasoning
          </p>
          <p class="text-[12px] text-violet-900 leading-relaxed whitespace-pre-wrap">
            {{ rec.ai_reasoning }}
          </p>
        </div>

        <!-- MATERIALS -->
        <div v-if="rec.materials && rec.materials.length > 0">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5 inline-flex items-center gap-1.5">
            <NavIcon name="book" :size="11" />
            Materi Terkait
          </p>
          <ul class="space-y-1">
            <li
              v-for="(m, i) in rec.materials"
              :key="m.id ?? `${m.title}-${i}`"
              class="flex items-start gap-2 text-[12px] text-slate-700"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-slate-400 mt-2 flex-shrink-0" />
              <div class="flex-1 min-w-0">
                <p class="font-semibold text-slate-900">{{ m.title }}</p>
                <p
                  v-if="m.description"
                  class="text-[11px] text-slate-500 mt-0.5"
                >
                  {{ m.description }}
                </p>
                <a
                  v-if="m.url"
                  :href="m.url"
                  target="_blank"
                  rel="noopener"
                  class="inline-flex items-center gap-1 text-[10.5px] font-bold text-brand-cobalt hover:underline mt-0.5"
                >
                  <NavIcon name="external-link" :size="10" />
                  Buka
                </a>
              </div>
            </li>
          </ul>
        </div>

        <!-- TEACHER NOTES -->
        <div
          v-if="rec.teacher_notes"
          class="bg-slate-50 rounded-lg px-3 py-2"
        >
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-0.5">
            Catatan Wali Kelas
          </p>
          <p class="text-[12px] text-slate-700 leading-relaxed whitespace-pre-wrap">
            {{ rec.teacher_notes }}
          </p>
        </div>

        <!-- PARENT RECEIPT STRIP (when shared) -->
        <div
          v-if="hasBeenShared"
          class="flex items-center gap-2 text-[11px] text-slate-600 px-2.5 py-2 rounded-lg"
          :class="
            sharePillKind === 'read'
              ? 'bg-emerald-50 text-emerald-800'
              : 'bg-brand-cobalt/5 text-brand-cobalt'
          "
        >
          <NavIcon
            :name="sharePillKind === 'read' ? 'check-circle' : 'send'"
            :size="13"
            class="flex-shrink-0"
          />
          <p class="flex-1 min-w-0 font-medium">
            <template v-if="sharePillKind === 'read'">
              {{ shareReadCount }} dari {{ shareTotal }} wali sudah baca
            </template>
            <template v-else>
              Terkirim ke {{ shareTotal }} wali
            </template>
            <span class="opacity-75"> · {{ sharedRelative }}</span>
          </p>
        </div>

        <!-- DUE DATE STRIP -->
        <div
          v-if="dueRelative"
          class="flex items-center gap-2 text-[11px] text-slate-600 border-t border-dashed border-slate-200 pt-2"
        >
          <NavIcon name="bell" :size="12" class="text-slate-400" />
          <span>
            Jatuh tempo: <strong class="text-slate-900">{{ dueRelative.display }}</strong>
            <span class="text-slate-400"> · {{ dueRelative.relative }}</span>
          </span>
        </div>

        <!-- FOOTER ACTIONS -->
        <div
          v-if="!readonly"
          class="grid gap-2 pt-2 border-t border-slate-100"
          :class="
            isShareable
              ? hasBeenShared
                ? 'grid-cols-[auto_1fr]'
                : 'grid-cols-[auto_1fr]'
              : 'grid-cols-1'
          "
        >
          <!-- Riwayat (only when already shared) OR Bagikan (when shareable + not yet) -->
          <button
            v-if="hasBeenShared"
            type="button"
            class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-[11.5px] font-bold bg-brand-cobalt/10 text-brand-cobalt hover:bg-brand-cobalt/15 transition"
            @click="emit('viewHistory', rec)"
          >
            <NavIcon name="list" :size="13" />
            Riwayat
          </button>
          <button
            v-else-if="isShareable"
            type="button"
            class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-[11.5px] font-bold bg-white text-violet-700 border-2 border-dashed border-violet-300 hover:bg-violet-50 transition"
            @click="emit('share', rec)"
          >
            <NavIcon name="send" :size="13" />
            Bagikan ke Wali
          </button>

          <!-- Tandai Diterapkan / Sudah Diterapkan -->
          <Button
            :variant="isCompleted ? 'secondary' : 'success'"
            size="sm"
            block
            :loading="isUpdatingStatus"
            :disabled="isUpdatingStatus"
            @click="emit('toggleStatus', rec)"
          >
            <NavIcon
              :name="isCompleted ? 'check' : 'check-circle'"
              :size="13"
            />
            {{ isCompleted ? 'Sudah Diterapkan' : 'Tandai Diterapkan' }}
          </Button>
        </div>
      </div>
    </div>
  </article>
</template>
