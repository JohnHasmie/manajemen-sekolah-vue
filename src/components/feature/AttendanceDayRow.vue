<!--
  AttendanceDayRow.vue — single attendance record row.

  Mirrors Flutter's `AttendanceDayCard`. Layout:
    [date block — d / EEE-short] [status pill] [headline / secondary] [chevron]

  Headline: "{statusLabel} · {subjectName}"
  Secondary: "{lessonHourName} · EEEE, d MMM yyyy"
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';
import type {
  ParentAttendanceEntry,
  ParentAttendanceStatus,
} from '@/types/parent';

const props = defineProps<{
  entry: ParentAttendanceEntry;
}>();

defineEmits<{ click: [ParentAttendanceEntry] }>();

const { t, locale } = useI18n();

// Locale-aware date formatter — switches BCP-47 tag with the i18n locale
// so "Senin/Sen" becomes "Monday/Mon" when the user picks English.
const intlLocale = computed(() => (locale.value === 'en' ? 'en-US' : 'id-ID'));

// Status labels track the live locale via i18n — must be a computed map
// (not a const lookup) so re-render happens on language switch.
const STATUS_LABELS = computed<Record<ParentAttendanceStatus, string>>(() => ({
  hadir: t('parent.attendance.statusPresent'),
  terlambat: t('parent.attendance.statusLate'),
  izin: t('parent.attendance.statusExcused'),
  sakit: t('parent.attendance.statusSick'),
  alpha: t('parent.attendance.statusAbsent'),
}));

const dt = computed(() => new Date(props.entry.date));

const dayOfMonth = computed(() => (Number.isFinite(dt.value.getTime()) ? dt.value.getDate() : '?'));

const shortDay = computed(() => {
  if (!Number.isFinite(dt.value.getTime())) return '';
  return dt.value.toLocaleDateString(intlLocale.value, { weekday: 'short' });
});

const longDate = computed(() => {
  if (!Number.isFinite(dt.value.getTime())) return props.entry.date;
  return dt.value.toLocaleDateString(intlLocale.value, {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
});

const statusLabel = computed(() => STATUS_LABELS.value[props.entry.status]);

function statusTone(s: ParentAttendanceStatus): {
  bg: string;
  text: string;
  block: string;
} {
  switch (s) {
    case 'hadir':
      return { bg: 'bg-emerald-100', text: 'text-emerald-700', block: 'bg-emerald-50 text-emerald-700' };
    case 'terlambat':
      return { bg: 'bg-amber-100', text: 'text-amber-700', block: 'bg-amber-50 text-amber-700' };
    case 'izin':
      return { bg: 'bg-brand-cobalt/15', text: 'text-brand-cobalt', block: 'bg-brand-cobalt/10 text-brand-cobalt' };
    case 'sakit':
      return { bg: 'bg-orange-100', text: 'text-orange-700', block: 'bg-orange-50 text-orange-700' };
    case 'alpha':
    default:
      return { bg: 'bg-red-100', text: 'text-red-700', block: 'bg-red-50 text-red-700' };
  }
}

const tone = computed(() => statusTone(props.entry.status));

const headline = computed(() => {
  const subject = props.entry.subject_name?.trim();
  return subject ? `${statusLabel.value} · ${subject}` : statusLabel.value;
});

// Backend ships `lesson_hour_name` as "Jam ke-4" (Indonesian only). When
// the user is in English mode, re-format it via the locale key so the
// row reads "Hour 4 · Tuesday, May 12, 2026" instead of mixing
// languages. Falls back to the raw string for any unexpected shape.
function localiseHourName(raw: string): string {
  const m = raw.match(/^Jam\s+ke-(\d+)$/i);
  if (m) return t('common.lessonHour', { n: Number(m[1]) });
  return raw;
}

const secondary = computed(() => {
  const parts: string[] = [];
  if (props.entry.lesson_hour_name)
    parts.push(localiseHourName(props.entry.lesson_hour_name));
  else if (props.entry.session) parts.push(props.entry.session);
  parts.push(longDate.value);
  return parts.filter(Boolean).join(' · ');
});
</script>

<template>
  <button
    type="button"
    class="w-full text-left px-3 py-3 flex items-center gap-3 rounded-2xl border border-transparent hover:bg-slate-50 hover:border-slate-200 transition-all"
    @click="$emit('click', entry)"
  >
    <!-- Date block -->
    <div
      class="w-11 h-12 rounded-xl grid place-items-center flex-shrink-0 text-center"
      :class="tone.block"
    >
      <div>
        <p class="text-[15px] font-black leading-none">{{ dayOfMonth }}</p>
        <p class="text-4xs font-bold uppercase tracking-widest mt-0.5 opacity-80">
          {{ shortDay }}
        </p>
      </div>
    </div>

    <!-- Headline + secondary -->
    <div class="flex-1 min-w-0">
      <p class="text-[13px] font-bold text-slate-900 truncate">{{ headline }}</p>
      <p class="text-2xs text-slate-500 truncate mt-0.5">{{ secondary }}</p>
      <p
        v-if="entry.notes"
        class="text-3xs text-slate-500 italic mt-0.5 truncate"
      >
        "{{ entry.notes }}"
      </p>
    </div>

    <!-- Status pill -->
    <span
      class="text-4xs font-bold uppercase tracking-widest px-2 py-1 rounded-full flex-shrink-0"
      :class="`${tone.bg} ${tone.text}`"
    >
      {{ statusLabel }}
    </span>

    <NavIcon name="chevron-right" :size="13" class="text-slate-300 flex-shrink-0" />
  </button>
</template>
