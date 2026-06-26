<!--
  BulkTeacherPickerModal.vue — admin bulk "Ganti Teacher" sheet.

  Reassigns N selected schedules to a single teacher. Backend enforces
  per-row teacher-slot uniqueness; collisions surface as `skipped[]`
  with Paksa Ganti retry.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { ScheduleService } from '@/services/schedule.service';
import type {
  BulkOpResult,
  ScheduleFilterOptions,
  ScheduleRow,
} from '@/types/schedule';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  rows: ScheduleRow[];
  filterOptions?: ScheduleFilterOptions | null;
}>();

const emit = defineEmits<{
  close: [];
  done: [{ changed: number; skipped: number }];
}>();

const teacherId = ref<string>('');
const lastResult = ref<BulkOpResult | null>(null);
const isSaving = ref(false);
const isForcing = ref(false);
const err = ref<string | null>(null);

const teachers = computed(() => props.filterOptions?.teachers ?? []);

async function send(force = false) {
  if (!teacherId.value) {
    err.value = 'Pilih guru baru.';
    return;
  }
  if (force) {
    isForcing.value = true;
  } else {
    isSaving.value = true;
  }
  err.value = null;
  try {
    const ids = force && lastResult.value
      ? lastResult.value.skipped.map((s) => s.id)
      : props.rows.map((r) => r.id);
    const res = await ScheduleService.bulkChangeTeacher({
      ids,
      teacher_id: teacherId.value,
      force: force || undefined,
    });
    lastResult.value = res;
    const changedCount = res.changed_count ?? res.changed?.length ?? 0;
    const skippedCount = res.skipped.length;
    if (force || skippedCount === 0) {
      emit('done', { changed: changedCount, skipped: skippedCount });
      emit('close');
    }
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    isSaving.value = false;
    isForcing.value = false;
  }
}
</script>

<template>
  <Modal
    title="Ganti Guru (Bulk)"
    :subtitle="`${rows.length} jadwal akan diberikan ke guru baru`"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <div class="bg-slate-50 rounded-xl p-3">
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
          Jadwal terpilih
        </p>
        <p class="text-[13px] font-bold text-slate-900 mt-1">{{ rows.length }} sesi</p>
      </div>

      <div>
        <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Guru baru</label>
        <select
          v-model="teacherId"
          class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
        >
          <option value="">— pilih guru —</option>
          <option v-for="t in teachers" :key="t.id" :value="t.id">{{ t.name }}</option>
        </select>
      </div>

      <section
        v-if="lastResult && lastResult.skipped.length > 0"
        class="bg-amber-50 border border-amber-200 rounded-xl p-3 space-y-2"
      >
        <p class="text-[11px] font-bold text-amber-700 uppercase tracking-widest flex items-center gap-1.5">
          <NavIcon name="alert-triangle" :size="12" />
          {{ lastResult.skipped.length }} sesi dilewati
        </p>
        <ul class="text-[11px] text-amber-800 space-y-1 max-h-32 overflow-y-auto">
          <li v-for="s in lastResult.skipped" :key="s.id">{{ s.reason }}</li>
        </ul>
        <Button variant="danger" block :loading="isForcing" @click="send(true)">
          Paksa Ganti ({{ lastResult.skipped.length }})
        </Button>
      </section>

      <p v-if="err" class="text-[11px] text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!teacherId || isSaving"
          @click="send(false)"
        >
          Ganti Guru
        </Button>
      </div>
    </div>
  </Modal>
</template>
