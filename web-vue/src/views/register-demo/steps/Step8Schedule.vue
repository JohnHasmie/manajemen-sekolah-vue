<!--
  Step 8 — Schedule. Auto vs manual; active-day chip row + time range.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();

const mode = computed({
  get: () => wizard.payload.schedule.mode,
  set: (v: 'auto' | 'manual') => wizard.patchPayload('schedule', { mode: v }),
});

const activeDays = computed({
  get: () => wizard.payload.schedule.active_days,
  set: (v: number[]) => wizard.patchPayload('schedule', { active_days: v }),
});

const start = computed({
  get: () => wizard.payload.schedule.start_time,
  set: (v: string) => wizard.patchPayload('schedule', { start_time: v }),
});
const end = computed({
  get: () => wizard.payload.schedule.end_time,
  set: (v: string) => wizard.patchPayload('schedule', { end_time: v }),
});

const DAYS = [
  { idx: 1, label: 'Sen' },
  { idx: 2, label: 'Sel' },
  { idx: 3, label: 'Rab' },
  { idx: 4, label: 'Kam' },
  { idx: 5, label: 'Jum' },
  { idx: 6, label: 'Sab' },
];

function toggleDay(idx: number) {
  const set = new Set(activeDays.value);
  if (set.has(idx)) set.delete(idx);
  else set.add(idx);
  activeDays.value = Array.from(set).sort((a, b) => a - b);
}
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.stepCounter', { current: wizard.stepNumber, total: wizard.stepTotal }) }} · {{ t('registerDemo.step9Label') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.step9Title') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">
      {{ t('registerDemo.step9Subtitle') }}
    </p>

    <div class="grid grid-cols-2 gap-3 mb-5">
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="mode === 'auto' ? 'border-2 border-role-admin bg-role-admin/10' : 'border-slate-300 bg-white hover:border-slate-400'"
        @click="mode = 'auto'"
      >
        <NavIcon name="calendar" :size="22" :class="mode === 'auto' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">{{ t('registerDemo.step9AutoMode') }}</div>
        <div class="text-[11px]" :class="mode === 'auto' ? 'text-role-admin' : 'text-slate-500'">
          {{ t('registerDemo.step9AutoHint') }}
        </div>
      </button>
      <button
        type="button"
        class="border rounded-xl p-3 text-center transition"
        :class="mode === 'manual' ? 'border-2 border-role-admin bg-role-admin/10' : 'border-slate-300 bg-white hover:border-slate-400'"
        @click="mode = 'manual'"
      >
        <NavIcon name="clock" :size="22" :class="mode === 'manual' ? 'text-role-admin' : 'text-slate-500'" class="mx-auto mb-1" />
        <div class="text-[13px] font-bold">{{ t('registerDemo.step9ManualMode') }}</div>
        <div class="text-[11px]" :class="mode === 'manual' ? 'text-role-admin' : 'text-slate-500'">
          {{ t('registerDemo.step9ManualHint') }}
        </div>
      </button>
    </div>

    <template v-if="mode === 'auto'">
      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
        {{ t('registerDemo.step9ActiveDaysLabel') }}
      </p>
      <div class="flex flex-wrap gap-1.5 mb-5">
        <button
          v-for="d in DAYS"
          :key="d.idx"
          type="button"
          class="px-3 py-1.5 rounded-full text-[12px] font-bold transition border"
          :class="
            activeDays.includes(d.idx)
              ? 'bg-role-admin text-white border-role-admin'
              : 'bg-white text-slate-700 border-slate-300 hover:border-slate-400'
          "
          @click="toggleDay(d.idx)"
        >
          {{ d.label }}
        </button>
      </div>

      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
        {{ t('registerDemo.step9TimeRangeLabel') }}
      </p>
      <div class="flex items-center gap-3">
        <input
          v-model="start"
          type="time"
          class="border border-slate-300 rounded-lg px-3 py-2 text-[13px] outline-none focus:border-role-admin"
        />
        <span class="text-slate-500">–</span>
        <input
          v-model="end"
          type="time"
          class="border border-slate-300 rounded-lg px-3 py-2 text-[13px] outline-none focus:border-role-admin"
        />
      </div>
    </template>
  </div>
</template>
