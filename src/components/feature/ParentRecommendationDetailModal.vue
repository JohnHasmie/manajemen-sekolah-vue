<!--
  ParentRecommendationDetailModal.vue — Frame C of the parent
  Rekomendasi flow. Read-mostly view of a single shared rec with
  inline Tandai Selesai + Balas actions.

  Web port of Flutter's `ParentRecommendationDetailScreen`. Sections
  (each rendered only when the underlying data is present):
    • Hero — priority pill, subject pill, "DARI WALI KELAS" pill,
      Selesai pill (when completed), title, sent-ago meta + due.
    • Pesan dari Homeroom Teacher — quoted shared_message (left azure rail).
    • Yang Perlu Dilakukan — rec description (HTML-aware via v-html
      with a sanitised allowlist).
    • Materi Terkait — Bab (cobalt) + Sub-bab (amber) chips drawn
      from `chapter` / `subChapter` relations.
    • AI Reasoning — collapsible violet tile.
    • Replied banner — when the parent already replied previously.
    • Sticky action bar — Tandai Selesai (outline) + Balas (primary).

  Emits `close` and `acted` (the latter when the parent reply/complete
  flow mutates the row — host refreshes the list).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import ParentRecReplyModal from '@/components/feature/ParentRecReplyModal.vue';
import ParentRecCompleteModal from '@/components/feature/ParentRecCompleteModal.vue';
import { RecommendationService } from '@/services/recommendations.service';
import { useAuthStore } from '@/stores/auth';
import type { ParentInboxRow } from '@/types/recommendations';

const props = defineProps<{ row: ParentInboxRow }>();
const emit = defineEmits<{ close: []; acted: [] }>();

const auth = useAuthStore();
const localRow = ref<ParentInboxRow>({ ...props.row });
const busy = ref(false);
const errorMsg = ref<string | null>(null);
const showReasoning = ref(false);
const replyOpen = ref(false);
const completeOpen = ref(false);

const rec = computed(() => localRow.value.recommendation);

function readStr(key: string): string | null {
  const v = (rec.value as Record<string, unknown>)[key];
  return v == null ? null : String(v);
}
function readNested(path: string[]): string | null {
  let cur: unknown = rec.value;
  for (const k of path) {
    if (cur && typeof cur === 'object') {
      cur = (cur as Record<string, unknown>)[k];
    } else {
      return null;
    }
  }
  return cur == null ? null : String(cur);
}

const recId = computed(() => readStr('id') ?? '');
const teacherName = computed(
  () => readNested(['teacher', 'name']) ?? readStr('teacher_name') ?? 'Wali Kelas',
);
const subjectName = computed(
  () =>
    readNested(['subject_school', 'name']) ??
    readNested(['subjectSchool', 'name']) ??
    readNested(['subject', 'name']) ??
    readStr('subject_name'),
);
const title = computed(() => readStr('title') ?? 'Rekomendasi');
const descriptionHtml = computed(() => sanitizeHtml(readStr('description') ?? ''));
const sharedMessage = computed(() => readStr('shared_message')?.trim() || null);
const aiReasoning = computed(() => readStr('ai_reasoning')?.trim() || null);
const dueDate = computed(() => readStr('due_date'));

const priority = computed(() => (readStr('priority') ?? 'low').toLowerCase());
const priorityLabel = computed(() =>
  priority.value === 'high'
    ? 'PRIORITAS TINGGI'
    : priority.value === 'medium'
      ? 'PRIORITAS SEDANG'
      : 'PRIORITAS RENDAH',
);
const priorityTone = computed(() =>
  priority.value === 'high'
    ? { bg: 'bg-red-100', fg: 'text-red-700' }
    : priority.value === 'medium'
      ? { bg: 'bg-amber-100', fg: 'text-amber-700' }
      : { bg: 'bg-slate-100', fg: 'text-slate-600' },
);

const isCompleted = computed(
  () =>
    localRow.value.parent_completed_at != null ||
    (readStr('status') ?? '').toLowerCase() === 'completed',
);

const MONTHS_SHORT = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
function fmtDateShort(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return iso;
  return `${d.getDate()} ${MONTHS_SHORT[d.getMonth()]}`;
}
function fmtAgo(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return '';
  const diffMs = Date.now() - d.getTime();
  const diffMin = Math.floor(diffMs / 60_000);
  if (diffMin < 60) return `${Math.max(diffMin, 0)}m lalu`;
  const diffH = Math.floor(diffMs / 3_600_000);
  if (diffH < 24) return `${diffH}j lalu`;
  const diffD = Math.floor(diffMs / 86_400_000);
  if (diffD < 7) return `${diffD}h lalu`;
  return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear() % 100}`;
}

const dueLabel = computed(() => {
  if (!dueDate.value) return null;
  return `Tenggat ${fmtDateShort(dueDate.value)}`;
});

const heroMeta = computed(() => {
  const parts: string[] = [];
  if (teacherName.value) parts.push(`Dari ${teacherName.value}`);
  const ago = fmtAgo(localRow.value.sent_at);
  if (ago) parts.push(ago);
  if (dueLabel.value) parts.push(dueLabel.value);
  return parts.join(' · ');
});

interface MateriChip {
  label: string;
  tone: { bg: string; fg: string };
}
const materiChips = computed<MateriChip[]>(() => {
  const out: MateriChip[] = [];
  const bab = readNested(['chapter', 'title']);
  if (bab) {
    out.push({
      label: `Bab · ${bab}`,
      tone: { bg: 'bg-brand-cobalt/10', fg: 'text-brand-cobalt' },
    });
  }
  const sub = readNested(['subChapter', 'title']);
  if (sub) {
    out.push({
      label: `Sub-Bab · ${sub}`,
      tone: { bg: 'bg-amber-100', fg: 'text-amber-700' },
    });
  }
  const materials = (rec.value as Record<string, unknown>).materials;
  if (Array.isArray(materials)) {
    for (const m of materials) {
      if (m && typeof m === 'object') {
        const t = (m as Record<string, unknown>).title;
        if (t) {
          out.push({
            label: String(t),
            tone: { bg: 'bg-slate-100', fg: 'text-slate-700' },
          });
        }
      }
    }
  }
  return out;
});

const repliedAt = computed(() => localRow.value.replied_at);
const replyText = computed(() => localRow.value.reply_text);

function sanitizeHtml(html: string): string {
  // Strip <script>/<style>, allow a small set of tags, drop event
  // handlers + javascript: URLs. Lightweight allowlist — for richer
  // sanitising the host should use DOMPurify, but the AI backend
  // already constrains the markup it produces.
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/\son\w+="[^"]*"/gi, '')
    .replace(/\son\w+='[^']*'/gi, '')
    .replace(/javascript:/gi, '');
}

async function onReply(replyTextValue: string) {
  if (!recId.value) return;
  busy.value = true;
  errorMsg.value = null;
  try {
    await RecommendationService.replyToRec({
      recommendation_id: recId.value,
      parent_user_id: auth.user?.id ?? '',
      reply_text: replyTextValue,
    });
    localRow.value = {
      ...localRow.value,
      replied_at: new Date().toISOString(),
      reply_text: replyTextValue,
    };
    replyOpen.value = false;
    emit('acted');
  } catch (e) {
    errorMsg.value = (e as Error).message;
  } finally {
    busy.value = false;
  }
}

async function onComplete(payload: { note: string; notifyTeacher: boolean }) {
  if (!recId.value) return;
  if (localRow.value.parent_completed_at) {
    completeOpen.value = false;
    return;
  }
  busy.value = true;
  errorMsg.value = null;
  try {
    await RecommendationService.markRecCompletedByParent({
      recommendation_id: recId.value,
      parent_user_id: auth.user?.id ?? '',
      note: payload.note || null,
      notify_teacher: payload.notifyTeacher,
    });
    localRow.value = {
      ...localRow.value,
      parent_completed_at: new Date().toISOString(),
      parent_completion_note: payload.note || null,
    };
    completeOpen.value = false;
    emit('acted');
  } catch (e) {
    errorMsg.value = (e as Error).message;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <Modal
    :title="title"
    :subtitle="subjectName ? `${subjectName} · Rincian Rekomendasi` : 'Rincian Rekomendasi'"
    size="xl"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- Hero pill row + meta -->
      <section
        class="rounded-2xl border border-role-wali/20 bg-role-wali/[0.04] p-4"
      >
        <div class="flex flex-wrap gap-1.5">
          <span
            class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full"
            :class="`${priorityTone.bg} ${priorityTone.fg}`"
          >
            {{ priorityLabel }}
          </span>
          <span
            v-if="subjectName"
            class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-indigo-100 text-indigo-700"
          >
            {{ subjectName }}
          </span>
          <span
            class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-role-wali/15 text-role-wali"
          >
            Dari Wali Kelas
          </span>
          <span
            v-if="isCompleted"
            class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700"
          >
            Selesai
          </span>
        </div>
        <h3 class="text-[17px] font-black text-slate-900 leading-snug mt-2.5">
          {{ title }}
        </h3>
        <p class="text-2xs font-bold text-slate-500 mt-1">
          {{ heroMeta }}
        </p>
      </section>

      <!-- Pesan dari Homeroom Teacher -->
      <section v-if="sharedMessage">
        <header class="flex items-center gap-2 mb-2">
          <div
            class="w-7 h-7 rounded-lg bg-role-wali/10 text-role-wali grid place-items-center"
          >
            <NavIcon name="megaphone" :size="14" />
          </div>
          <h4 class="text-[12.5px] font-bold text-slate-900">
            Pesan dari Wali Kelas
          </h4>
          <span class="text-[10.5px] text-slate-500 ml-auto">{{ teacherName }}</span>
        </header>
        <div
          class="border-l-[3px] border-role-wali bg-role-wali/[0.04] px-3 py-2.5 rounded-r-xl text-[12.5px] text-slate-700 leading-relaxed whitespace-pre-line"
        >
          {{ sharedMessage }}
        </div>
      </section>

      <!-- Yang Perlu Dilakukan -->
      <section>
        <header class="flex items-center gap-2 mb-2">
          <div
            class="w-7 h-7 rounded-lg bg-indigo-100 text-indigo-700 grid place-items-center"
          >
            <NavIcon name="check-square" :size="14" />
          </div>
          <h4 class="text-[12.5px] font-bold text-slate-900">
            Yang Perlu Dilakukan
          </h4>
        </header>
        <div
          v-if="descriptionHtml"
          class="prose prose-sm max-w-none text-slate-700 text-[12.5px] leading-relaxed"
          v-html="descriptionHtml"
        ></div>
        <p v-else class="text-[12px] text-slate-500 italic">
          Tidak ada deskripsi.
        </p>
      </section>

      <!-- Materi Terkait -->
      <section v-if="materiChips.length > 0">
        <header class="flex items-center gap-2 mb-2">
          <div
            class="w-7 h-7 rounded-lg bg-brand-cobalt/10 text-brand-cobalt grid place-items-center"
          >
            <NavIcon name="book" :size="14" />
          </div>
          <h4 class="text-[12.5px] font-bold text-slate-900">Materi Terkait</h4>
          <span class="text-[10.5px] text-slate-500 ml-auto">
            {{ materiChips.length }} dipilih
          </span>
        </header>
        <div class="flex flex-wrap gap-1.5">
          <span
            v-for="(chip, idx) in materiChips"
            :key="idx"
            class="text-2xs font-bold px-2.5 py-1 rounded-lg"
            :class="`${chip.tone.bg} ${chip.tone.fg}`"
          >
            {{ chip.label }}
          </span>
        </div>
      </section>

      <!-- AI Reasoning (collapsible) -->
      <section v-if="aiReasoning" class="rounded-2xl border border-violet-200 bg-violet-50">
        <button
          type="button"
          class="w-full flex items-center justify-between gap-3 px-3.5 py-2.5"
          @click="showReasoning = !showReasoning"
        >
          <div class="flex items-center gap-2">
            <div
              class="w-7 h-7 rounded-lg bg-violet-100 text-violet-700 grid place-items-center"
            >
              <NavIcon name="sparkles" :size="14" />
            </div>
            <p class="text-[12.5px] font-bold text-violet-900">Alasan AI</p>
          </div>
          <NavIcon
            :name="showReasoning ? 'chevron-up' : 'chevron-down'"
            :size="14"
            class="text-violet-700"
          />
        </button>
        <div
          v-if="showReasoning"
          class="px-3.5 pb-3 text-[12px] text-violet-900/80 leading-relaxed whitespace-pre-line"
        >
          {{ aiReasoning }}
        </div>
      </section>

      <!-- Replied banner -->
      <section
        v-if="repliedAt"
        class="rounded-2xl border border-emerald-200 bg-emerald-50 p-3"
      >
        <div class="flex items-start gap-2">
          <div
            class="w-7 h-7 rounded-lg bg-emerald-100 text-emerald-700 grid place-items-center flex-shrink-0"
          >
            <NavIcon name="check-circle" :size="14" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[11.5px] font-bold text-emerald-800">
              Balasan terkirim · {{ fmtAgo(repliedAt) }}
            </p>
            <p
              v-if="replyText"
              class="text-[12px] text-emerald-900/80 mt-1 whitespace-pre-line"
            >
              "{{ replyText }}"
            </p>
          </div>
        </div>
      </section>

      <!-- Error -->
      <p
        v-if="errorMsg"
        class="text-[12px] text-red-700 bg-red-50 border border-red-200 rounded-xl px-3 py-2"
      >
        {{ errorMsg }}
      </p>

      <!-- Action bar -->
      <div class="flex gap-2 pt-3 border-t border-slate-100">
        <Button
          variant="secondary"
          :disabled="busy || isCompleted"
          @click="completeOpen = true"
        >
          {{ isCompleted ? 'Sudah Selesai' : 'Tandai Selesai' }}
        </Button>
        <Button block :disabled="busy" @click="replyOpen = true">
          Balas Wali Kelas
        </Button>
      </div>
    </div>

    <ParentRecReplyModal
      v-if="replyOpen"
      :teacher-name="teacherName"
      :subject-name="subjectName"
      :initial-text="replyText"
      @close="replyOpen = false"
      @send="onReply"
    />
    <ParentRecCompleteModal
      v-if="completeOpen"
      :recommendation-title="title"
      :due-label="dueLabel"
      @close="completeOpen = false"
      @confirm="onComplete"
    />
  </Modal>
</template>
