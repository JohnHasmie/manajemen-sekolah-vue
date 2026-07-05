<!--
  ParentRecommendationCard.vue — single rec row in the parent inbox.

  Web port of Flutter's `_ParentRecommendationCard`
  (parent_recommendation_screen.dart). Each card shows:

    ┌─────────────────────────────────────────────────────┐
    │ 🟢  Bu Sari              [WALI KELAS]              │  ← teacher row
    │     Matematika · Homeroom Teacher · 2 jam lalu           │
    │  [PRIORITAS TINGGI] [MATEMATIKA] [SELESAI]         │  ← status pills
    │  Rekomendasi judul                                 │  ← bold title
    │  Deskripsi (HTML stripped) …                       │
    │  ⏰ Tenggat 5 Mei                                   │  ← due chip (optional)
    │  ┌─────────────┬─────────────────┐                 │
    │  │ Lihat Detail│       Buka      │  → both open the same detail
    │  └─────────────┴─────────────────┘                 │
    └─────────────────────────────────────────────────────┘

  Unread state adds an azure ring + small dot in the top-right corner.
  Completed state strikes through the title and tints it slate.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { ParentInboxRow } from '@/types/recommendations';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{ row: ParentInboxRow }>();
defineEmits<{ click: [ParentInboxRow] }>();

const rec = computed(() => props.row.recommendation);

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
const description = computed(() => stripHtml(readStr('description') ?? ''));
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

const isUnread = computed(() => props.row.read_at == null);
const isCompleted = computed(
  () =>
    props.row.parent_completed_at != null ||
    (readStr('status') ?? '').toLowerCase() === 'completed',
);

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 0 || parts[0].length === 0) return '?';
  if (parts.length === 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function stripHtml(html: string): string {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

function fmtAgo(iso: string | null): string {
  if (!iso) return 'baru saja';
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

const captionLine = computed(() => {
  const parts: string[] = [];
  if (subjectName.value) parts.push(subjectName.value);
  parts.push('Wali Kelas');
  const ago = fmtAgo(props.row.sent_at);
  if (ago) parts.push(ago);
  return parts.join(' · ');
});
</script>

<template>
  <button
    type="button"
    class="relative w-full text-left bg-white rounded-2xl p-3.5 transition-all border"
    :class="
      isUnread
        ? 'border-role-wali/30 shadow-md shadow-role-wali/10'
        : 'border-slate-200 hover:border-slate-300'
    "
    @click="$emit('click', row)"
  >
    <!-- Unread dot -->
    <span
      v-if="isUnread"
      class="absolute top-3 right-3 w-2 h-2 rounded-full bg-role-wali"
    />

    <!-- Teacher row -->
    <div class="flex items-center gap-2.5">
      <div
        class="w-9 h-9 rounded-full bg-role-wali/10 grid place-items-center text-role-wali text-2xs font-bold flex-shrink-0"
      >
        {{ initialsOf(teacherName) }}
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-[12.5px] font-bold text-slate-900 truncate">
          {{ teacherName }}
        </p>
        <p class="text-[10.5px] font-medium text-slate-500 truncate mt-0.5">
          {{ captionLine }}
        </p>
      </div>
      <span
        class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-role-wali/10 text-role-wali flex-shrink-0"
      >
        Wali Kelas
      </span>
    </div>

    <!-- Status pills -->
    <div class="flex flex-wrap gap-1.5 mt-2.5">
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
        v-if="isCompleted"
        class="text-[9.5px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700"
      >
        Selesai
      </span>
    </div>

    <!-- Title -->
    <h4
      class="text-[14px] font-black mt-2 leading-snug"
      :class="
        isCompleted ? 'text-slate-500 line-through' : 'text-slate-900'
      "
    >
      {{ title }}
    </h4>

    <!-- Description -->
    <p
      v-if="description"
      class="text-[12px] text-slate-600 mt-1.5 leading-relaxed line-clamp-2"
    >
      {{ description }}
    </p>

    <!-- Due date chip -->
    <div
      v-if="dueDate && !isCompleted"
      class="inline-flex items-center gap-1.5 mt-2.5 px-2.5 py-1 rounded-lg text-2xs font-bold bg-amber-50 text-amber-700 border border-amber-200"
    >
      <NavIcon name="clock" :size="12" />
      Tenggat {{ fmtDateShort(dueDate) }}
    </div>

    <!-- Action buttons -->
    <div class="flex gap-2 mt-3">
      <span
        class="flex-1 text-center text-[11.5px] font-bold py-2 rounded-lg bg-role-wali/10 text-role-wali"
      >
        Lihat Detail
      </span>
      <span
        class="flex-1 text-center text-[11.5px] font-bold py-2 rounded-lg bg-role-wali text-white shadow-sm shadow-role-wali/30"
      >
        Buka
      </span>
    </div>
  </button>
</template>
