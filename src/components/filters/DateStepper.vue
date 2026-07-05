<!--
  DateStepper.vue - prev / today-button / next pattern.
  Mirrors the date stepper from the Presensi mockup.

  v-model:date is a YYYY-MM-DD string. Click on the middle button opens
  a native date picker via the hidden <input type="date">.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';

const props = withDefaults(
  defineProps<{
    modelValue: string;
    label?: string;
    minDate?: string;
    maxDate?: string;
  }>(),
  { label: 'Tanggal', minDate: '', maxDate: '' },
);

const emit = defineEmits<{ 'update:modelValue': [string] }>();

const datePicker = ref<HTMLInputElement | null>(null);

const display = computed(() => {
  const d = new Date(props.modelValue);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  });
});

function shift(days: number) {
  const d = new Date(props.modelValue);
  if (Number.isNaN(d.getTime())) return;
  d.setDate(d.getDate() + days);
  emit('update:modelValue', toIso(d));
}

function toIso(d: Date): string {
  const yr = d.getFullYear();
  const mo = String(d.getMonth() + 1).padStart(2, '0');
  const dy = String(d.getDate()).padStart(2, '0');
  return `${yr}-${mo}-${dy}`;
}

function openPicker() {
  datePicker.value?.showPicker?.();
  datePicker.value?.focus();
}

function onPick(e: Event) {
  const v = (e.target as HTMLInputElement).value;
  if (v) emit('update:modelValue', v);
}
</script>

<template>
  <div class="inline-flex items-stretch rounded-xl border border-slate-200 bg-white overflow-hidden">
    <button
      type="button"
      class="w-9 bg-slate-50 hover:bg-brand-cobalt/10 hover:text-brand-cobalt text-slate-500 grid place-items-center transition-colors"
      :aria-label="`${label} sebelumnya`"
      @click="shift(-1)"
    >
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-3.5 h-3.5">
        <polyline points="15 18 9 12 15 6" />
      </svg>
    </button>
    <button
      type="button"
      class="flex flex-col items-center justify-center px-4 py-1 hover:bg-slate-50 transition-colors relative min-w-[130px]"
      @click="openPicker"
    >
      <span class="text-4xs font-bold text-slate-400 uppercase tracking-widest leading-none">{{ label }}</span>
      <span class="text-[13px] font-bold text-slate-900 mt-0.5">{{ display }}</span>
      <input
        ref="datePicker"
        type="date"
        :value="modelValue"
        :min="minDate || undefined"
        :max="maxDate || undefined"
        class="sr-only"
        @change="onPick"
      />
    </button>
    <button
      type="button"
      class="w-9 bg-slate-50 hover:bg-brand-cobalt/10 hover:text-brand-cobalt text-slate-500 grid place-items-center transition-colors"
      :aria-label="`${label} berikutnya`"
      @click="shift(1)"
    >
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-3.5 h-3.5">
        <polyline points="9 18 15 12 9 6" />
      </svg>
    </button>
  </div>
</template>
