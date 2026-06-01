<!--
  AttendanceDayRow.vue — single attendance record row.

  Mirrors Flutter's `AttendanceDayCard`. Layout:
    [date block — d / EEE-short] [status pill] [headline / secondary] [chevron]

  Headline: "{statusLabel} · {subjectName}"
  Secondary: "{lessonHourName} · EEEE, d MMM yyyy"
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type {
  ParentAttendanceEntry,
  ParentAttendanceStatus,
} from '@/types/parent';
import { PARENT_ATTENDANCE_LABELS } from '@/types/parent';

const props = defineProps<{
  entry: ParentAttendanceEntry;
}>();

defineEmits<{ click: [ParentAttendanceEntry] }>();

const dt = computed(() => new Date(props.entry.date));

const dayOfMonth = computed(() => (Number.isFinite(dt.value.getTime()) ? dt.value.getDate() : '?'));

const shortDay = computed(() => {
  if (!Number.isFinite(dt.value.getTime())) return '';
  return dt.value.toLocaleDateString('id-ID', { weekday: 'short' });
});

const longDate = computed(() => {
  if (!Number.isFinite(dt.value.getTime())) return props.entry.date;
  return dt.value.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
});

const statusLabel = computed(() => PARENT_ATTENDANCE_LABELS[props.entry.status]);

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

const secondary = computed(() => {
  const parts: string[] = [];
  if (props.entry.lesson_hour_name) parts.push(props.entry.lesson_hour_name);
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
        <p class="text-[9px] font-bold uppercase tracking-widest mt-0.5 opacity-80">
          {{ shortDay }}
        </p>
      </div>
    </div>

    <!-- Headline + secondary -->
    <div class="flex-1 min-w-0">
      <p class="text-[13px] font-bold text-slate-900 truncate">{{ headline }}</p>
      <p class="text-[11px] text-slate-500 truncate mt-0.5">{{ secondary }}</p>
      <p
        v-if="entry.notes"
        class="text-[10px] text-slate-500 italic mt-0.5 truncate"
      >
        "{{ entry.notes }}"
      </p>
    </div>

    <!-- Status pill -->
    <span
      class="text-[9px] font-bold uppercase tracking-widest px-2 py-1 rounded-full flex-shrink-0"
      :class="`${tone.bg} ${tone.text}`"
    >
      {{ statusLabel }}
    </span>

    <NavIcon name="chevron-right" :size="13" class="text-slate-300 flex-shrink-0" />
  </button>
</template>
