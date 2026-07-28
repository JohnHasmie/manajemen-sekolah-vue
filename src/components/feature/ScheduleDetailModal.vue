<!--
  ScheduleDetailModal.vue — admin schedule row detail sheet.

  Mirrors Flutter's `admin_schedule_detail_sheet.dart`. Shows full
  metadata of a single schedule slot + a 2×2 quick-action grid:
    Edit        · Pindah Slot
    Ganti Teacher  · Hapus

  Emits action events; the parent view handles the actual modals
  (form, reschedule, change-teacher, confirm-delete).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { ScheduleRow } from '@/types/schedule';
import { DAY_LABELS } from '@/types/schedule';
import { semesterLabel } from '@/lib/labels';

const { t } = useI18n();

const props = defineProps<{
  row: ScheduleRow;
}>();

const emit = defineEmits<{
  close: [];
  edit: [];
  reschedule: [];
  changeTeacher: [];
  duplicate: [];
  delete: [];
  /** "Gabung dengan JP berikutnya" — merge this slot into a block. */
  mergeNext: [];
  /** "Pisahkan blok" — undo the multi-hour block. */
  splitBlock: [];
}>();

/** "JP2–3" for a block, plain "JP2" otherwise. */
const blockHourLabel = computed(() => {
  const hours = props.row.block_hour_numbers ?? [];
  if (hours.length < 2) return null;
  return `${t('admin.schedule.jpAbbrev')}${hours[0]}–${hours[hours.length - 1]}`;
});

/** Clock span of the whole block, e.g. "07:40–09:00". */
const blockTimeLabel = computed(() => {
  if (!props.row.is_block) return null;
  const s = props.row.block_start_time ?? props.row.start_time;
  const e = props.row.block_end_time ?? props.row.end_time;
  return `${s}–${e}`;
});
</script>

<template>
  <Modal
    :title="row.subject_name"
    :subtitle="`${row.class_name} · ${DAY_LABELS[row.day]} · ${t('common.lessonHour', { n: row.hour_number })}`"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- Hero card -->
      <section
        class="rounded-2xl p-4 text-white"
        :style="{
          background: row.conflict_with && row.conflict_with.length > 0
            ? 'linear-gradient(135deg, #991B1B 0%, #EF4444 100%)'
            : 'linear-gradient(135deg, #0A1F4D 0%, #143068 100%)',
        }"
      >
        <p class="text-3xs font-bold tracking-widest uppercase text-white/70">
          {{ DAY_LABELS[row.day] }} ·
          <template v-if="blockHourLabel">{{ blockHourLabel }}</template>
          <template v-else>{{ t('common.lessonHour', { n: row.hour_number }) }}</template>
        </p>
        <!-- A block's headline time is the OUTER span (07:40–09:00), not
             the anchor hour's own end — that's the whole point of the
             merge, so it has to read that way here too. -->
        <p class="text-2xl font-black tracking-tight mt-1">
          {{ blockTimeLabel ?? `${row.start_time}–${row.end_time}` }}
        </p>
        <p class="text-[12px] text-white/80 mt-1">
          {{ row.subject_name }}
          <span v-if="row.room"> · {{ row.room }}</span>
        </p>
        <div class="flex flex-wrap gap-1.5 mt-2">
          <span
            v-if="row.is_block"
            class="text-3xs bg-white/15 inline-flex items-center gap-1 px-2 py-1 rounded-full font-bold"
          >
            <NavIcon name="link" :size="10" />
            {{ t('admin.schedule.block.spanBadge', { n: row.block_span ?? 0 }) }}
          </span>
          <span
            v-if="row.is_grouped"
            class="text-3xs bg-white/15 inline-flex items-center gap-1 px-2 py-1 rounded-full font-bold"
          >
            <NavIcon name="git-merge" :size="10" />
            {{ t('admin.schedule.combined.classCountBadge', { n: (row.grouped_class_names ?? []).length }) }}
          </span>
        </div>
        <p
          v-if="row.conflict_with && row.conflict_with.length > 0"
          class="text-3xs mt-2 bg-white/15 inline-flex items-center gap-1 px-2 py-1 rounded-full font-bold"
        >
          <NavIcon name="alert-triangle" :size="10" />
          Bentrok dengan {{ row.conflict_with.length }} jadwal lain
        </p>
      </section>

      <!-- Metadata grid -->
      <section class="bg-slate-50 rounded-xl p-3 space-y-1.5">
        <dl class="text-[12px] space-y-1.5">
          <div class="flex justify-between gap-2">
            <dt class="text-slate-500">Guru</dt>
            <dd class="font-bold text-slate-900 text-right">{{ row.teacher_name ?? '—' }}</dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-slate-500">Kelas</dt>
            <dd class="font-bold text-slate-900 text-right">
              {{ row.class_name }}
              <span v-if="row.class_grade_level" class="text-slate-500 font-normal ml-1">
                · Tingkat {{ row.class_grade_level }}
              </span>
            </dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-slate-500">Semester</dt>
            <dd class="font-bold text-slate-900 text-right">{{ semesterLabel(row.semester_name, '—') }}</dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-slate-500">Tahun Ajaran</dt>
            <dd class="font-bold text-slate-900 text-right">{{ row.academic_year ?? '—' }}</dd>
          </div>
        </dl>
      </section>

      <!-- Blok jam — the only action that changes the session's SHAPE
           rather than its content, so it sits above the 2×2 grid with
           its own teal treatment instead of competing for a cell. -->
      <button
        v-if="row.is_block"
        type="button"
        class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl border border-teal-200 bg-teal-50 hover:bg-teal-100 transition-colors text-left"
        @click="emit('splitBlock')"
      >
        <span class="w-7 h-7 rounded-lg bg-teal-100 text-teal-800 grid place-items-center flex-shrink-0">
          <NavIcon name="unlink" :size="14" />
        </span>
        <span class="min-w-0">
          <span class="block text-[12px] font-bold text-teal-800">
            {{ t('admin.schedule.block.splitAction') }}
          </span>
          <span class="block text-3xs text-teal-700/80 mt-0.5">
            {{ t('admin.schedule.block.splitHint', { label: blockHourLabel ?? '' }) }}
          </span>
        </span>
      </button>
      <button
        v-else
        type="button"
        class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl border border-slate-200 bg-white hover:border-teal-300 hover:bg-teal-50/50 transition-colors text-left"
        @click="emit('mergeNext')"
      >
        <span class="w-7 h-7 rounded-lg bg-slate-100 text-slate-600 grid place-items-center flex-shrink-0">
          <NavIcon name="link-down" :size="14" />
        </span>
        <span class="min-w-0">
          <span class="block text-[12px] font-bold text-slate-800">
            {{ t('admin.schedule.block.mergeAction') }}
          </span>
          <span class="block text-3xs text-slate-500 mt-0.5">
            {{ t('admin.schedule.block.mergeHint') }}
          </span>
        </span>
      </button>

      <!-- 2x2 quick actions -->
      <section class="grid grid-cols-2 gap-2">
        <Button variant="secondary" block @click="emit('edit')">
          <NavIcon name="edit" :size="13" />
          Edit
        </Button>
        <Button variant="secondary" block @click="emit('reschedule')">
          <NavIcon name="move" :size="13" />
          Pindah Slot
        </Button>
        <Button variant="secondary" block @click="emit('changeTeacher')">
          <NavIcon name="user" :size="13" />
          Ganti Guru
        </Button>
        <Button variant="secondary" block @click="emit('duplicate')">
          <NavIcon name="copy" :size="13" />
          Duplikat
        </Button>
      </section>

      <Button variant="danger" block @click="emit('delete')">
        <NavIcon name="trash-2" :size="13" />
        Hapus Jadwal
      </Button>
    </div>
  </Modal>
</template>
