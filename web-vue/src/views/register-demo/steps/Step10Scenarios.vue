<!--
  Step 10 — Skenario seeding.

  Final config step before provision. The user picks which "scenarios"
  the backend should populate so each module has data to test:

    - Kehadiran        → backfill 5 days of absensi
    - RPP              → seed lesson_plans across mix of statuses
    - Pengumuman       → seed school-wide + per-class announcements
    - Progress sub-bab → seed chapters/sub-chapters with ~30% done
    - Kegiatan kelas   → seed class_activities + submissions
    - Tagihan          → run the billing seed (overrides skip)

  All are default-on so the very first demo has data everywhere. The
  next button on this step (not the billing step) triggers provision.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import {
  SCENARIO_DEFINITIONS,
  type DemoScenarioKey,
} from '@/types/demo';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const wizard = useDemoWizardStore();

const enabled = computed(() => wizard.payload.scenarios.enabled);

function isOn(key: DemoScenarioKey): boolean {
  return enabled.value.includes(key);
}

function toggle(key: DemoScenarioKey) {
  const set = new Set(enabled.value);
  if (set.has(key)) set.delete(key);
  else set.add(key);
  wizard.patchPayload('scenarios', { enabled: Array.from(set) });
}

function selectAll() {
  wizard.patchPayload('scenarios', {
    enabled: SCENARIO_DEFINITIONS.map((s) => s.key),
  });
}

function selectNone() {
  wizard.patchPayload('scenarios', { enabled: [] });
}

const allOn = computed(
  () => enabled.value.length === SCENARIO_DEFINITIONS.length,
);
</script>

<template>
  <div>
    <p class="text-[11px] font-bold tracking-widest text-slate-500 uppercase mb-2">
      {{ t('registerDemo.stepCounter', { current: wizard.stepNumber, total: wizard.stepTotal }) }} · {{ t('registerDemo.step12Label') }}
    </p>
    <h2 class="text-[20px] font-black text-slate-900 mb-1 leading-tight">
      {{ t('registerDemo.step12Title') }}
    </h2>
    <p class="text-[13px] text-slate-600 mb-4">
      {{ t('registerDemo.step12Subtitle') }}
    </p>

    <div class="flex items-center justify-between mb-3">
      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase">
        {{ enabled.length }} {{ t('registerDemo.step12CountLabel', { count: SCENARIO_DEFINITIONS.length }) }}
      </p>
      <div class="flex gap-1.5">
        <button
          type="button"
          class="text-[11.5px] font-bold px-2.5 py-1 rounded-md border border-slate-300 text-slate-700 hover:bg-slate-50 disabled:opacity-50"
          :disabled="allOn"
          @click="selectAll"
        >
          {{ t('registerDemo.step12SelectAll') }}
        </button>
        <button
          type="button"
          class="text-[11.5px] font-bold px-2.5 py-1 rounded-md border border-slate-300 text-slate-700 hover:bg-slate-50 disabled:opacity-50"
          :disabled="enabled.length === 0"
          @click="selectNone"
        >
          {{ t('registerDemo.step12ClearAll') }}
        </button>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-2.5">
      <button
        v-for="s in SCENARIO_DEFINITIONS"
        :key="s.key"
        type="button"
        class="text-left border rounded-xl px-3.5 py-3 transition flex items-start gap-3"
        :class="
          isOn(s.key)
            ? 'border-2 border-role-admin bg-role-admin/5'
            : 'border-slate-200 bg-white hover:border-slate-300'
        "
        @click="toggle(s.key)"
      >
        <span
          class="w-9 h-9 rounded-lg flex-shrink-0 flex items-center justify-center transition"
          :class="
            isOn(s.key)
              ? 'bg-role-admin text-white'
              : 'bg-slate-100 text-slate-500'
          "
        >
          <NavIcon :name="s.icon" :size="16" />
        </span>
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <span class="text-[13.5px] font-bold text-slate-900 leading-tight">
              {{ s.label }}
            </span>
            <span
              v-if="isOn(s.key)"
              class="text-[10px] font-bold uppercase tracking-wider text-role-admin bg-role-admin/10 px-1.5 py-0.5 rounded"
            >
              {{ t('registerDemo.step12ActiveBadge') }}
            </span>
          </div>
          <p class="text-[12px] text-slate-600 leading-snug mt-0.5">
            {{ s.description }}
          </p>
        </div>
        <span
          class="w-5 h-5 rounded-md border-2 flex-shrink-0 flex items-center justify-center transition mt-0.5"
          :class="
            isOn(s.key)
              ? 'bg-role-admin border-role-admin'
              : 'bg-white border-slate-300'
          "
        >
          <NavIcon v-if="isOn(s.key)" name="check" :size="12" class="text-white" />
        </span>
      </button>
    </div>

    <p class="text-[11.5px] text-slate-500 mt-4 leading-snug">
      {{ t('registerDemo.step12FinalNote') }}
    </p>
  </div>
</template>
