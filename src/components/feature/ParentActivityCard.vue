<!--
  ParentActivityCard.vue — single Activity Kelas card for the parent
  feed. Web port of Flutter's `_ActivityCard` (parent_activity_list_
  builder_mixin.dart). Layout:

    ┌────────────────────────────────────────────────────┐
    │ ⊙   Mata Pelajaran · Kelas 7A · Bu Sari   2 jam ⬤  │  ← caption + ago + unread dot
    │     Praktikum IPA — Sistem Pernapasan              │  ← title
    │     [Tugas]                                        │  ← jenis pill
    │     Anak-anak melakukan eksperimen pernapasan      │  ← description (clamp 2)
    │     📚 Bab 4 · Sistem Pernapasan                   │  ← optional chapter
    │     ────────────────────────────                   │  ← divider (only when chips below)
    │     🛡 Khusus  ⭐ Untuk anak ini  🕐 Batas: 5 Mei   │  ← footer chips
    └────────────────────────────────────────────────────┘

  Avatar palette routes by `kind`:
    • tugas  → amber bg / amber-700 fg
    • materi → emerald bg / emerald-700 fg
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ClassActivity } from '@/types/class-activity';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{ activity: ClassActivity }>();
defineEmits<{ click: [ClassActivity] }>();

const { t } = useI18n();

// Three-letter month abbreviations driven by the active locale —
// switches between Jan/Feb/Mar… and Mei/Agu/Okt/Des etc.
const SHORT_MONTHS = computed<string[]>(() => [
  t('parent.activity.month.jan'),
  t('parent.activity.month.feb'),
  t('parent.activity.month.mar'),
  t('parent.activity.month.apr'),
  t('parent.activity.month.may'),
  t('parent.activity.month.jun'),
  t('parent.activity.month.jul'),
  t('parent.activity.month.aug'),
  t('parent.activity.month.sep'),
  t('parent.activity.month.oct'),
  t('parent.activity.month.nov'),
  t('parent.activity.month.dec'),
]);

const isAssignment = computed(() => parentKind(props.activity) === 'tugas');

const palette = computed(() =>
  isAssignment.value
    ? { bg: 'bg-amber-100', fg: 'text-amber-700' }
    : { bg: 'bg-emerald-100', fg: 'text-emerald-700' },
);

// Caption: "Subject · Class X · Teacher" (skip blanks).
const caption = computed(() => {
  const parts: string[] = [];
  if (props.activity.subject_name) parts.push(props.activity.subject_name);
  if (props.activity.class_name)
    parts.push(t('parent.activity.classPrefix', { name: props.activity.class_name }));
  if (props.activity.teacher_name) parts.push(props.activity.teacher_name);
  if (parts.length === 0)
    return isAssignment.value
      ? t('parent.activity.typeTask')
      : t('parent.activity.typeMaterial');
  return parts.join(' · ');
});

function initialsFor(text: string): string {
  if (!text) return isAssignment.value ? 'TG' : 'MT';
  const parts = text.split(/\s+/).filter((p) => p.length > 0);
  if (parts.length === 0) return isAssignment.value ? 'TG' : 'MT';
  if (parts.length === 1) {
    return parts[0].substring(0, Math.min(2, parts[0].length)).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

const initials = computed(() =>
  initialsFor(props.activity.subject_name || props.activity.teacher_name || ''),
);

const chapterLabel = computed(() => {
  const bab = props.activity.chapter_title ?? '';
  const sub = props.activity.sub_chapter_title ?? '';
  if (bab && sub) return `${bab} · ${sub}`;
  if (bab) return bab;
  if (sub) return sub;
  if (props.activity.chapter_label) return props.activity.chapter_label;
  return null;
});

const timeAgo = computed(() => {
  // Prefer the activity date; fall back to created-at (not exposed
  // separately on ClassActivity — use date alone).
  const iso = props.activity.date;
  if (!iso) return '';
  const parsed = new Date(iso);
  if (!Number.isFinite(parsed.getTime())) return iso;
  const now = new Date();
  const diffMs = now.getTime() - parsed.getTime();
  const diffMin = Math.floor(diffMs / 60_000);
  if (diffMin < 1) return t('parent.activity.timeJustNow');
  if (diffMin < 60) return t('parent.activity.timeMinutesAgo', { n: diffMin });
  const diffHr = Math.floor(diffMs / 3_600_000);
  if (diffHr < 24) {
    const sameDay =
      now.getFullYear() === parsed.getFullYear() &&
      now.getMonth() === parsed.getMonth() &&
      now.getDate() === parsed.getDate();
    if (sameDay) {
      const hh = String(parsed.getHours()).padStart(2, '0');
      const mm = String(parsed.getMinutes()).padStart(2, '0');
      return t('parent.activity.timeTodayAt', { time: `${hh}:${mm}` });
    }
    return t('parent.activity.timeHoursAgo', { n: diffHr });
  }
  const diffDays = Math.floor(diffMs / 86_400_000);
  if (diffDays === 1) return t('parent.activity.timeYesterday');
  if (diffDays < 7) return t('parent.activity.timeDaysAgo', { n: diffDays });
  return `${parsed.getDate()} ${SHORT_MONTHS.value[parsed.getMonth()]}`;
});

const hasDescription = computed(() => {
  const d = (props.activity.description ?? '').trim();
  return d.length > 0 && d !== 'null';
});

const hasFooterChips = computed(() => {
  const hasDue = isAssignment.value && Boolean(props.activity.deadline);
  return props.activity.is_specific_target || hasDue;
});

const isForThisChild = computed(
  () => props.activity.for_this_student === true,
);

function fmtDeadlineShort(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return iso;
  return `${d.getDate()} ${SHORT_MONTHS.value[d.getMonth()]}`;
}

// `kind` = mobile-app `jenis`. Returns 'tugas' for the submission-
// trackable types (tugas / ujian — plus legacy raws like 'pr' /
// 'ulangan' / 'assignment' / 'test' that normalize onto them) and
// 'materi' for everything else (activity / catatan / materi). Matches
// the mobile filter semantics so a "Materi" filter shows just material
// rows.
function parentKind(a: ClassActivity): 'tugas' | 'materi' {
  const raw = (a.raw_type ?? '').toLowerCase().trim();
  if (raw === 'materi' || raw === 'material' || raw === 'info') return 'materi';
  if (a.type === 'tugas' || a.type === 'ujian') {
    return 'tugas';
  }
  // activity / catatan default to materi (no submission tracking).
  return 'materi';
}
</script>

<template>
  <button
    type="button"
    class="relative w-full text-left bg-white border border-slate-200 rounded-2xl p-3.5 hover:border-slate-300 transition-colors shadow-sm"
    @click="$emit('click', activity)"
  >
    <!-- Unread dot -->
    <span
      v-if="activity.is_read === false"
      class="absolute top-3 right-3 w-2.5 h-2.5 rounded-full bg-role-wali ring-2 ring-white shadow"
    />

    <div class="flex gap-3">
      <!-- Avatar -->
      <div
        class="w-9 h-9 rounded-full grid place-items-center flex-shrink-0"
        :class="`${palette.bg} ${palette.fg}`"
      >
        <span class="text-[12px] font-bold tracking-wide">{{ initials }}</span>
      </div>

      <div class="flex-1 min-w-0">
        <!-- Caption + time ago -->
        <div class="flex items-center gap-2">
          <p
            class="text-2xs font-medium text-slate-500 truncate flex-1 min-w-0"
          >
            {{ caption }}
          </p>
          <span
            class="text-2xs font-medium text-slate-400 flex-shrink-0 pr-3"
          >
            {{ timeAgo }}
          </span>
        </div>

        <!-- Title -->
        <p
          class="text-[14px] font-bold text-slate-900 leading-snug mt-1 line-clamp-2"
        >
          {{ activity.title }}
        </p>

        <!-- Jenis pill -->
        <span
          class="inline-block mt-1.5 px-2 py-0.5 rounded-md text-3xs font-bold tracking-wide"
          :class="`${palette.bg} ${palette.fg}`"
        >
          {{ isAssignment ? t('parent.activity.typeTask') : t('parent.activity.typeMaterial') }}
        </span>

        <!-- Description -->
        <p
          v-if="hasDescription"
          class="text-[12px] text-slate-600 mt-2 line-clamp-2 leading-snug"
        >
          {{ activity.description }}
        </p>

        <!-- Chapter -->
        <div
          v-if="chapterLabel"
          class="flex items-center gap-1.5 mt-1.5 text-2xs text-slate-500 truncate"
        >
          <NavIcon name="book" :size="12" class="flex-shrink-0 text-slate-400" />
          <span class="truncate">{{ chapterLabel }}</span>
        </div>

        <!-- Footer chips -->
        <template v-if="hasFooterChips">
          <div class="h-px bg-slate-100 mt-2.5 mb-2.5" />
          <div class="flex flex-wrap gap-1.5">
            <span
              v-if="activity.is_specific_target"
              class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-3xs font-bold bg-sky-100 text-sky-700"
            >
              <NavIcon name="shield" :size="11" />
              {{ t('parent.activity.badgeSpecial') }}
            </span>
            <span
              v-if="activity.is_specific_target && isForThisChild"
              class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-3xs font-bold bg-blue-100 text-blue-700"
            >
              <NavIcon name="star" :size="11" />
              {{ t('parent.activity.badgeForThisChild') }}
            </span>
            <span
              v-if="isAssignment && activity.deadline"
              class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-3xs font-bold bg-red-100 text-red-700"
            >
              <NavIcon name="clock" :size="11" />
              {{ t('parent.activity.deadline', { date: fmtDeadlineShort(activity.deadline) }) }}
            </span>
          </div>
        </template>
      </div>
    </div>
  </button>
</template>
