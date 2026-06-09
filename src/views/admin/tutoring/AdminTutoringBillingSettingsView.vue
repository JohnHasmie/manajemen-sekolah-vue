<!--
  AdminTutoringBillingSettingsView — toggle which billing modes the
  tenant offers + a default mode. Rebuilt on the tutoring shared
  components.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringSectionHeader from '@/components/feature/tutoring/TutoringSectionHeader.vue';

const { t } = useI18n();
const toast = useToast();
const loading = ref(true);
const saving = ref(false);

const allowPrepaid = ref(true);
const allowMonthly = ref(true);
const allowPerSession = ref(true);
const defaultMode = ref<string | null>(null);

const enabledModes = computed(() => {
  const m: string[] = [];
  if (allowPrepaid.value) m.push('PREPAID');
  if (allowMonthly.value) m.push('MONTHLY');
  if (allowPerSession.value) m.push('PER_SESSION');
  return m;
});

const MODE_KEYS: Record<string, string> = {
  PREPAID: 'tutoring.billing.prepaid',
  MONTHLY: 'tutoring.billing.monthly',
  PER_SESSION: 'tutoring.billing.perSession',
};
const modeLabel = (m: string) => (MODE_KEYS[m] ? t(MODE_KEYS[m]) : m);

async function load() {
  loading.value = true;
  try {
    const s = await TutoringService.getBillingSettings();
    allowPrepaid.value = s.allow_prepaid;
    allowMonthly.value = s.allow_monthly;
    allowPerSession.value = s.allow_per_session;
    defaultMode.value = s.default_mode ?? null;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.billing.loadFailed'),
    );
  } finally {
    loading.value = false;
  }
}

async function save() {
  if (defaultMode.value && !enabledModes.value.includes(defaultMode.value)) {
    defaultMode.value = null;
  }
  saving.value = true;
  try {
    await TutoringService.updateBillingSettings({
      allow_prepaid: allowPrepaid.value,
      allow_monthly: allowMonthly.value,
      allow_per_session: allowPerSession.value,
      default_mode: defaultMode.value,
    });
    toast.success(t('tutoring.billing.saved'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.billing.saveFailed'),
    );
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Pengaturan Billing"
      :title="t('tutoring.billing.title')"
      :meta="t('tutoring.billing.hint')"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <div v-else>

      <label
        v-for="cfg in [
          {
            v: allowPrepaid,
            set: (b: boolean) => (allowPrepaid = b),
            t: t('tutoring.billing.prepaid'),
            s: t('tutoring.billing.prepaidDesc'),
          },
          {
            v: allowMonthly,
            set: (b: boolean) => (allowMonthly = b),
            t: t('tutoring.billing.monthly'),
            s: t('tutoring.billing.monthlyDesc'),
          },
          {
            v: allowPerSession,
            set: (b: boolean) => (allowPerSession = b),
            t: t('tutoring.billing.perSession'),
            s: t('tutoring.billing.perSessionDesc'),
          },
        ]"
        :key="cfg.t"
        class="flex items-center justify-between gap-3 bg-white border border-slate-100 rounded-2xl px-4 py-3 mb-2 cursor-pointer"
      >
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-slate-900">{{ cfg.t }}</span>
          <span class="block text-xs text-slate-500 mt-0.5">{{ cfg.s }}</span>
        </span>
        <input
          :checked="cfg.v"
          type="checkbox"
          class="h-5 w-5 accent-role-admin"
          @change="cfg.set(($event.target as HTMLInputElement).checked)"
        />
      </label>

      <TutoringSectionHeader :title="t('tutoring.billing.defaultMode')" />
      <select
        v-model="defaultMode"
        class="w-full rounded-lg border border-slate-200 px-3 py-2.5 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
      >
        <option :value="null">{{ t('tutoring.billing.none') }}</option>
        <option v-for="m in enabledModes" :key="m" :value="m">
          {{ modeLabel(m) }}
        </option>
      </select>

      <button
        :disabled="saving"
        class="mt-4 w-full rounded-lg bg-role-admin hover:bg-role-admin/90 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="save"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.common.save') }}
      </button>
    </div>
  </div>
</template>
