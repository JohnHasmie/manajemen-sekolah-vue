<!--
  DemoResetForm.vue — inline mini-wizard inside the "Reset Data Demo"
  confirmation flow.

  Why a mini form (not the full 11-step wizard):
    - The full wizard at /register-demo/wizard collects 30+ fields
      across school identity, classes, teachers, students, parents,
      schedule, billing, scenarios. Most of those answers do NOT
      change when a user just wants a "clean restart" — they want
      the same school with the same roster, just wiped.
    - Two things people genuinely want to tweak at reset time are:
        1. The set of seeded scenarios (e.g. "this time include
           progress sub-bab so I can demo it").
        2. The visible school name (when they tested with a
           placeholder).
    - Anything beyond that is a "re-do the wizard" task and is better
      served by the existing full-wizard flow. This form is deliberately
      narrow so the modal stays a modal.

  Output contract: the form ALWAYS emits a complete payload by
  shallow-merging the user's edits on top of `:base-payload`. The
  caller passes the original `school_payload` (from the demo_request
  or DemoWizardState) so the backend's ResetDemoSchoolAction sees a
  valid full-shape payload, not a partial one that would fail
  ProvisionDemoSchoolAction's downstream validation.

  When the user toggles back to "Konfigurasi sama" the parent
  ignores any in-progress overrides and calls reset() with no payload
  — the backend then reuses the original payload itself.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { SCENARIO_DEFINITIONS, type DemoScenarioKey } from '@/types/demo';

const props = defineProps<{
  basePayload: Record<string, unknown> | null;
}>();

const emit = defineEmits<{
  /** Emitted on every change; null = "use base unchanged". */
  change: [payload: Record<string, unknown> | null];
}>();

/**
 * Mode toggle:
 *   'same'   → emit null → caller calls reset() with no payload →
 *              backend reuses the original payload.
 *   'tweak'  → emit a merged payload with the user's overrides on
 *              top of base.
 */
const mode = ref<'same' | 'tweak'>('same');

// ── User-editable overrides ─────────────────────────────────────────
// School name is shallow-merged into payload.school.name. Empty input
// means "no override on name" (we keep the base value).
const overrideName = ref('');

// Scenarios are an enum array. We default to whatever the base payload
// has enabled; the user toggles individual checkboxes from there. We
// keep the user's selection in a Set for cheap has/toggle.
const baseScenarios = computed<Set<DemoScenarioKey>>(() => {
  const list = ((props.basePayload as { scenarios?: { enabled?: string[] } })
    ?.scenarios?.enabled ?? []) as DemoScenarioKey[];
  return new Set(list);
});
const overrideScenarios = ref<Set<DemoScenarioKey>>(new Set());

// Hydrate the override set from the base whenever base changes
// (the parent might pass it asynchronously after fetching).
watch(
  () => props.basePayload,
  () => {
    overrideScenarios.value = new Set(baseScenarios.value);
    const baseName =
      (props.basePayload as { school?: { name?: string } })?.school?.name ?? '';
    overrideName.value = String(baseName);
  },
  { immediate: true },
);

function toggleScenario(key: DemoScenarioKey) {
  const next = new Set(overrideScenarios.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  overrideScenarios.value = next;
}

// ── Emit on every edit ──────────────────────────────────────────────
// "Same" mode → null. "Tweak" mode → merged payload. Both emit on
// every dependency change so the parent's submit button is always in
// sync with the form state.
watch(
  [mode, overrideName, overrideScenarios],
  () => {
    if (mode.value === 'same') {
      emit('change', null);
      return;
    }
    if (!props.basePayload) {
      // No base to merge into — caller cannot proceed in tweak mode.
      // Emit null so the parent doesn't accidentally send a hollow
      // payload that fails backend validation.
      emit('change', null);
      return;
    }
    const merged: Record<string, unknown> = JSON.parse(
      JSON.stringify(props.basePayload),
    );
    // School name override (only when non-empty).
    const trimmedName = overrideName.value.trim();
    if (trimmedName.length > 0) {
      const school = (merged.school ?? {}) as Record<string, unknown>;
      school.name = trimmedName;
      merged.school = school;
    }
    // Scenarios override — always write back so unchecking is honored.
    const scenarios = (merged.scenarios ?? {}) as Record<string, unknown>;
    scenarios.enabled = Array.from(overrideScenarios.value);
    merged.scenarios = scenarios;
    emit('change', merged);
  },
  { deep: true, immediate: true },
);

const hasBase = computed(() => props.basePayload != null);
</script>

<template>
  <div class="space-y-3">
    <!-- Mode toggle pills -->
    <div role="tablist" class="grid grid-cols-2 gap-1.5 rounded-xl bg-slate-100 p-1">
      <button
        type="button"
        role="tab"
        :aria-selected="mode === 'same'"
        class="px-3 py-1.5 rounded-lg text-[11.5px] font-bold transition"
        :class="
          mode === 'same'
            ? 'bg-white text-slate-900 shadow-sm'
            : 'text-slate-500 hover:text-slate-700'
        "
        @click="mode = 'same'"
      >
        Konfigurasi sama
      </button>
      <button
        type="button"
        role="tab"
        :aria-selected="mode === 'tweak'"
        class="px-3 py-1.5 rounded-lg text-[11.5px] font-bold transition"
        :class="
          mode === 'tweak'
            ? 'bg-white text-slate-900 shadow-sm'
            : 'text-slate-500 hover:text-slate-700'
        "
        :disabled="!hasBase"
        :title="!hasBase ? 'Konfigurasi asli belum termuat' : ''"
        @click="hasBase && (mode = 'tweak')"
      >
        Ubah konfigurasi
      </button>
    </div>

    <!-- SAME — short explainer, nothing to edit. -->
    <p
      v-if="mode === 'same'"
      class="text-[11.5px] text-slate-500 leading-relaxed"
    >
      Demo akan dibangun ulang persis seperti pertama kali diisi pada wizard pendaftaran. Tidak ada perubahan setup.
    </p>

    <!-- TWEAK — narrow override form. -->
    <div v-else class="space-y-3">
      <!-- School name override -->
      <div>
        <label class="block text-[11px] font-bold text-slate-500 mb-1">
          Nama sekolah (opsional)
        </label>
        <input
          v-model="overrideName"
          type="text"
          autocomplete="off"
          placeholder="Nama sekolah baru…"
          class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-role-admin/30"
        />
        <p class="mt-1 text-[10.5px] text-slate-400">
          Kosongkan untuk pakai nama yang sama.
        </p>
      </div>

      <!-- Scenarios toggles -->
      <div>
        <label class="block text-[11px] font-bold text-slate-500 mb-1.5">
          Skenario yang diisi ulang
        </label>
        <div class="max-h-56 overflow-y-auto pr-1 space-y-1.5">
          <label
            v-for="s in SCENARIO_DEFINITIONS"
            :key="s.key"
            class="flex items-start gap-2.5 rounded-lg border border-slate-100 hover:border-slate-200 hover:bg-slate-50 px-2.5 py-2 cursor-pointer transition"
          >
            <input
              type="checkbox"
              class="mt-0.5 accent-role-admin"
              :checked="overrideScenarios.has(s.key)"
              @change="toggleScenario(s.key)"
            />
            <span class="flex-1 min-w-0">
              <span class="block text-[12px] font-bold text-slate-900">{{ s.label }}</span>
              <span class="block text-[10.5px] text-slate-500 leading-snug">{{ s.description }}</span>
            </span>
          </label>
        </div>
        <p class="mt-1.5 text-[10.5px] text-slate-400">
          Skenario yang tidak dicentang akan dilewati pada seeding ulang.
        </p>
      </div>
    </div>
  </div>
</template>
