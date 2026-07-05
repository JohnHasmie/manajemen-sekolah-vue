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
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import type {
  ParentRecFilter,
  ParentRecStatus,
  ParentRecPriority,
  ParentRecPeriod,
} from '@/types/recommendations';
import { DEFAULT_PARENT_REC_FILTER } from '@/types/recommendations';

const { t } = useI18n();

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

const STATUS_OPTIONS = computed<{ value: ParentRecStatus; label: string }[]>(() => [
  { value: 'all', label: t('parent.recommendations.statusAll') },
  { value: 'unread', label: t('parent.recommendations.statusUnread') },
  { value: 'active', label: t('parent.recommendations.statusActive') },
  { value: 'completed', label: t('parent.recommendations.statusCompleted') },
]);
const PRIORITY_OPTIONS = computed<{ value: ParentRecPriority; label: string }[]>(() => [
  { value: 'all', label: t('parent.recommendations.priorityAll') },
  { value: 'high', label: t('parent.recommendations.priorityHigh') },
  { value: 'medium', label: t('parent.recommendations.priorityMedium') },
  { value: 'low', label: t('parent.recommendations.priorityLow') },
]);
const PERIOD_OPTIONS = computed<{ value: ParentRecPeriod; label: string }[]>(() => [
  { value: 'last7', label: t('parent.recommendations.period7d') },
  { value: 'last30', label: t('parent.recommendations.period30d') },
  { value: 'all', label: t('parent.recommendations.periodAll') },
]);
</script>

<template>
  <Modal :title="t('parent.recommendations.filterModalTitle')" size="lg" @close="emit('close')">
    <div class="space-y-5">
      <!-- Status -->
      <section>
        <p class="text-2xs font-bold uppercase tracking-widest text-slate-500 mb-2">
          {{ t('parent.recommendations.sectionStatus') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in STATUS_OPTIONS"
            :key="opt.value"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold transition border"
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
        <p class="text-2xs font-bold uppercase tracking-widest text-slate-500 mb-2">
          {{ t('parent.recommendations.sectionPriority') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in PRIORITY_OPTIONS"
            :key="opt.value"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold transition border"
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
        <p class="text-2xs font-bold uppercase tracking-widest text-slate-500 mb-2">
          {{ t('parent.recommendations.sectionSubjects') }}
          <span class="text-slate-400 normal-case font-medium tracking-normal">
            {{ t('parent.recommendations.sectionSubjectsHint') }}
          </span>
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="name in availableSubjects"
            :key="name"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold transition border"
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
        <p class="text-2xs font-bold uppercase tracking-widest text-slate-500 mb-2">
          {{ t('parent.recommendations.sectionPeriod') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in PERIOD_OPTIONS"
            :key="opt.value"
            type="button"
            class="px-3 py-1.5 rounded-full text-2xs font-bold transition border"
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
        <Button variant="secondary" @click="reset">{{ t('parent.recommendations.resetButton') }}</Button>
        <Button block @click="apply">{{ t('parent.recommendations.applyButton') }}</Button>
      </div>
    </div>
  </Modal>
</template>
