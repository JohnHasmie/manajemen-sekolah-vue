<!--
  ParentRecFilterModal.vue — Frame F of the parent Rekomendasi flow.

  Web port of Flutter's `parent_recommendation_filter_sheet.dart`.
  Four facets:
    • Status — Semua / Belum Dibaca / Aktif / Selesai
    • Prioritas — Semua / Tinggi / Sedang / Rendah
    • Mata Pelajaran — multi-select; chip grid seeded from inbox
    • Periode — 7 Hari / 30 Hari / Semua

  Emits the updated ParentRecFilter on apply; emits nothing on close
  (the parent screen treats no event as "kept previous filter").
-->
<script setup lang="ts">
import { ref, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import type {
  ParentRecFilter,
  ParentRecStatus,
  ParentRecPriority,
  ParentRecPeriod,
} from '@/types/recommendations';
import { DEFAULT_PARENT_REC_FILTER } from '@/types/recommendations';

const props = defineProps<{
  current: ParentRecFilter;
  availableSubjects: string[];
}>();

const emit = defineEmits<{
  close: [];
  apply: [ParentRecFilter];
}>();

const status = ref<ParentRecStatus>(props.current.status);
const priority = ref<ParentRecPriority>(props.current.priority);
const period = ref<ParentRecPeriod>(props.current.period);
const subjects = ref<string[]>([...props.current.subjects]);

// If the parent re-opens the sheet later, seed it from current again.
watch(
  () => props.current,
  (v) => {
    status.value = v.status;
    priority.value = v.priority;
    period.value = v.period;
    subjects.value = [...v.subjects];
  },
);

function toggleSubject(name: string) {
  const i = subjects.value.indexOf(name);
  if (i >= 0) subjects.value.splice(i, 1);
  else subjects.value.push(name);
}

function reset() {
  status.value = DEFAULT_PARENT_REC_FILTER.status;
  priority.value = DEFAULT_PARENT_REC_FILTER.priority;
  period.value = DEFAULT_PARENT_REC_FILTER.period;
  subjects.value = [];
}

function apply() {
  emit('apply', {
    status: status.value,
    priority: priority.value,
    period: period.value,
    subjects: [...subjects.value],
  });
}

const STATUS_OPTIONS: { value: ParentRecStatus; label: string }[] = [
  { value: 'all', label: 'Semua' },
  { value: 'unread', label: 'Belum Dibaca' },
  { value: 'active', label: 'Aktif' },
  { value: 'completed', label: 'Selesai' },
];
const PRIORITY_OPTIONS: { value: ParentRecPriority; label: string }[] = [
  { value: 'all', label: 'Semua' },
  { value: 'high', label: 'Tinggi' },
  { value: 'medium', label: 'Sedang' },
  { value: 'low', label: 'Rendah' },
];
const PERIOD_OPTIONS: { value: ParentRecPeriod; label: string }[] = [
  { value: 'last7', label: '7 Hari' },
  { value: 'last30', label: '30 Hari' },
  { value: 'all', label: 'Semua' },
];
</script>

<template>
  <Modal title="Filter Rekomendasi" size="lg" @close="emit('close')">
    <div class="space-y-5">
      <!-- Status -->
      <section>
        <p class="text-[11px] font-bold uppercase tracking-widest text-slate-500 mb-2">
          Status
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in STATUS_OPTIONS"
            :key="opt.value"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
            :class="
              status === opt.value
                ? 'bg-role-wali text-white border-role-wali'
                : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40'
            "
            @click="status = opt.value"
          >
            {{ opt.label }}
          </button>
        </div>
      </section>

      <!-- Prioritas -->
      <section>
        <p class="text-[11px] font-bold uppercase tracking-widest text-slate-500 mb-2">
          Prioritas
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in PRIORITY_OPTIONS"
            :key="opt.value"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
            :class="
              priority === opt.value
                ? 'bg-role-wali text-white border-role-wali'
                : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40'
            "
            @click="priority = opt.value"
          >
            {{ opt.label }}
          </button>
        </div>
      </section>

      <!-- Mata Pelajaran (multi-select) -->
      <section v-if="availableSubjects.length > 0">
        <p class="text-[11px] font-bold uppercase tracking-widest text-slate-500 mb-2">
          Mata Pelajaran
          <span class="text-slate-400 normal-case font-medium tracking-normal">
            · pilih beberapa
          </span>
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="name in availableSubjects"
            :key="name"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
            :class="
              subjects.includes(name)
                ? 'bg-role-wali text-white border-role-wali'
                : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40'
            "
            @click="toggleSubject(name)"
          >
            {{ name }}
          </button>
        </div>
      </section>

      <!-- Periode -->
      <section>
        <p class="text-[11px] font-bold uppercase tracking-widest text-slate-500 mb-2">
          Periode
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in PERIOD_OPTIONS"
            :key="opt.value"
            type="button"
            class="px-3 py-1.5 rounded-full text-[11px] font-bold transition border"
            :class="
              period === opt.value
                ? 'bg-role-wali text-white border-role-wali'
                : 'bg-white text-slate-600 border-slate-200 hover:border-role-wali/40'
            "
            @click="period = opt.value"
          >
            {{ opt.label }}
          </button>
        </div>
      </section>

      <!-- Footer actions -->
      <div class="flex gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" @click="reset">Reset</Button>
        <Button block @click="apply">Terapkan Filter</Button>
      </div>
    </div>
  </Modal>
</template>
