<!--
  BulkDayPickerModal.vue — admin bulk "Pindah Hari" sheet.

  Moves N selected schedules to a single target_day_id. Backend
  re-resolves each row's lesson_hour_days_id by matching the current
  hour_number against the target day's lesson_hour matrix.

  Surfaces a `skipped[]` row list when conflicts or missing hour-number
  cells prevent some rows from being moved; the admin can opt-in to
  Paksa Pindah which retries with `force: true`.
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
import { formatDayName } from '@/lib/day-name';

const props = defineProps<{
  rows: ScheduleRow[];
  filterOptions?: ScheduleFilterOptions | null;
}>();

const emit = defineEmits<{
  close: [];
  done: [{ moved: number; skipped: number }];
}>();

const targetDayId = ref<string>('');
const lastResult = ref<BulkOpResult | null>(null);
const isSaving = ref(false);
const isForcing = ref(false);
const err = ref<string | null>(null);

const days = computed(() => props.filterOptions?.days ?? []);

async function send(force = false) {
  if (!targetDayId.value) {
    err.value = 'Pilih hari tujuan.';
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
    const res = await ScheduleService.bulkMove({
      ids,
      target_day_id: targetDayId.value,
      force: force || undefined,
    });
    lastResult.value = res;
    const movedCount = res.moved_count ?? res.moved?.length ?? 0;
    const skippedCount = res.skipped.length;
    if (force || skippedCount === 0) {
      emit('done', { moved: movedCount, skipped: skippedCount });
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
    title="Pindah Hari"
    :subtitle="`${rows.length} jadwal akan dipindahkan ke hari yang dipilih`"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <div class="bg-slate-50 rounded-xl p-3">
        <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Jadwal terpilih
        </p>
        <p class="text-[13px] font-bold text-slate-900 mt-1">
          {{ rows.length }} sesi
        </p>
      </div>

      <div>
        <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          Hari tujuan
        </label>
        <div class="mt-1 flex flex-wrap gap-1.5">
          <button
            v-for="d in days"
            :key="d.id"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold border transition-colors"
            :class="
              targetDayId === d.id
                ? 'bg-role-admin text-white border-role-admin'
                : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
            "
            @click="targetDayId = d.id"
          >
            {{ formatDayName(d.name) }}
          </button>
        </div>
      </div>

      <p class="text-2xs text-slate-500 leading-relaxed">
        Setiap sesi akan dipindah ke hari tujuan pada <strong>jam ke-</strong> yang
        sama. Sesi tanpa kecocokan jam akan dilewati.
      </p>

      <section
        v-if="lastResult && lastResult.skipped.length > 0"
        class="bg-amber-50 border border-amber-200 rounded-xl p-3 space-y-2"
      >
        <p class="text-2xs font-bold text-amber-700 uppercase tracking-widest flex items-center gap-1.5">
          <NavIcon name="alert-triangle" :size="12" />
          {{ lastResult.skipped.length }} sesi dilewati
        </p>
        <ul class="text-2xs text-amber-800 space-y-1 max-h-32 overflow-y-auto">
          <li v-for="s in lastResult.skipped" :key="s.id">{{ s.reason }}</li>
        </ul>
        <Button variant="danger" block :loading="isForcing" @click="send(true)">
          Paksa Pindah ({{ lastResult.skipped.length }})
        </Button>
      </section>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="!targetDayId || isSaving"
          @click="send(false)"
        >
          Pindahkan
        </Button>
      </div>
    </div>
  </Modal>
</template>
