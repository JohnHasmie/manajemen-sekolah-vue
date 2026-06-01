<!--
  ScheduleDetailModal.vue — admin schedule row detail sheet.

  Mirrors Flutter's `admin_schedule_detail_sheet.dart`. Shows full
  metadata of a single schedule slot + a 2×2 quick-action grid:
    Edit        · Pindah Slot
    Ganti Guru  · Hapus

  Emits action events; the parent view handles the actual modals
  (form, reschedule, change-teacher, confirm-delete).
-->
<script setup lang="ts">
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { ScheduleRow } from '@/types/schedule';
import { DAY_LABELS } from '@/types/schedule';

defineProps<{
  row: ScheduleRow;
}>();

const emit = defineEmits<{
  close: [];
  edit: [];
  reschedule: [];
  changeTeacher: [];
  duplicate: [];
  delete: [];
}>();
</script>

<template>
  <Modal
    :title="row.subject_name"
    :subtitle="`${row.class_name} · ${DAY_LABELS[row.day]} · Jam ke-${row.hour_number}`"
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
        <p class="text-[10px] font-bold tracking-widest uppercase text-white/70">
          {{ DAY_LABELS[row.day] }} · Jam ke-{{ row.hour_number }}
        </p>
        <p class="text-2xl font-black tracking-tight mt-1">
          {{ row.start_time }}–{{ row.end_time }}
        </p>
        <p class="text-[12px] text-white/80 mt-1">
          {{ row.subject_name }}
          <span v-if="row.room"> · {{ row.room }}</span>
        </p>
        <p
          v-if="row.conflict_with && row.conflict_with.length > 0"
          class="text-[10px] mt-2 bg-white/15 inline-block px-2 py-1 rounded-full font-bold"
        >
          ⚠ Bentrok dengan {{ row.conflict_with.length }} jadwal lain
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
            <dd class="font-bold text-slate-900 text-right">{{ row.semester_name ?? '—' }}</dd>
          </div>
          <div class="flex justify-between gap-2">
            <dt class="text-slate-500">Tahun Ajaran</dt>
            <dd class="font-bold text-slate-900 text-right">{{ row.academic_year ?? '—' }}</dd>
          </div>
        </dl>
      </section>

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
