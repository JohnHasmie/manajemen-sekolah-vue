<!--
  AdminTutoringEnrollView — pick package → optional group → student →
  billing mode → config → submit. Rebuilt on the tutoring shared
  components.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringGroup, TutoringPackage } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringFlowTag from '@/components/feature/tutoring/TutoringFlowTag.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const MODE_KEYS: Record<string, string> = {
  PREPAID: 'tutoring.billing.prepaid',
  MONTHLY: 'tutoring.billing.monthly',
  PER_SESSION: 'tutoring.billing.perSession',
};
const modeLabel = (m: string) => (MODE_KEYS[m] ? t(MODE_KEYS[m]) : m);

const programId = String(route.params.programId ?? '');
const programName = String(route.query.name ?? 'Program');

const loading = ref(true);
const saving = ref(false);
const packages = ref<TutoringPackage[]>([]);
const groups = ref<TutoringGroup[]>([]);
const students = ref<{ id: string; name: string }[]>([]);

const packageId = ref<string | null>(null);
const groupId = ref<string | null>(null);
const studentId = ref<string | null>(null);
const mode = ref<string | null>(null);
const amount = ref<number | null>(null);
const sessionsQuota = ref<number | null>(null);
const billingDay = ref<number>(5);

const selectedPackage = computed(() =>
  packages.value.find((p) => p.id === packageId.value),
);
const allowedModes = computed(
  () => selectedPackage.value?.billing_modes_allowed ?? [],
);

async function load() {
  loading.value = true;
  try {
    [packages.value, groups.value, students.value] = await Promise.all([
      TutoringService.getPackages(programId),
      TutoringService.getGroups(programId),
      TutoringService.getTenantStudents(),
    ]);
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.enroll.loadFailed'));
  } finally {
    loading.value = false;
  }
}

async function submit() {
  if (!studentId.value || !packageId.value || !mode.value) {
    toast.error(t('tutoring.enroll.incomplete'));
    return;
  }
  if (amount.value == null || amount.value < 0) {
    toast.error(t('tutoring.enroll.amountInvalid'));
    return;
  }
  saving.value = true;
  try {
    const enrollmentId = await TutoringService.createEnrollment({
      student_id: studentId.value,
      package_id: packageId.value,
      billing_mode: mode.value,
      group_id: groupId.value ?? undefined,
    });
    const config: Record<string, number> = { amount: amount.value };
    if (mode.value === 'PREPAID') config.sessions_quota = sessionsQuota.value ?? 0;
    else if (mode.value === 'MONTHLY') config.billing_day = billingDay.value;

    if (enrollmentId) {
      await TutoringService.createBillingPlan(enrollmentId, mode.value, config);
    }
    toast.success(t('tutoring.enroll.ok'));
    router.back();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.enroll.failed'));
  } finally {
    saving.value = false;
  }
}

onMounted(load);

const fieldLabel =
  'text-[10.5px] font-bold text-slate-500 uppercase tracking-wider';
const inputCls =
  'mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin';
</script>

<template>
  <div class="mx-auto max-w-2xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.enroll.title')"
      :crumbs="'Bimbel · ' + programName"
    />

    <TutoringFlowTag
      class="mb-3"
      text="Pilih paket → kelompok → siswa → mode billing → Simpan"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <div
      v-else
      class="space-y-3 bg-white border border-slate-100 rounded-2xl p-4 sm:p-5"
    >
      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.enroll.package') }}</span>
        <select v-model="packageId" :class="inputCls" @change="mode = null">
          <option :value="null" disabled>{{ t('tutoring.enroll.pickPackage') }}</option>
          <option v-for="p in packages" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
      </label>

      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.enroll.group') }}</span>
        <select v-model="groupId" :class="inputCls">
          <option :value="null">{{ t('tutoring.enroll.noGroup') }}</option>
          <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
        </select>
      </label>

      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.enroll.student') }}</span>
        <select v-model="studentId" :class="inputCls">
          <option :value="null" disabled>{{ t('tutoring.enroll.pickStudent') }}</option>
          <option v-for="s in students" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
      </label>

      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.enroll.mode') }}</span>
        <select v-model="mode" :class="inputCls">
          <option :value="null" disabled>{{ t('tutoring.enroll.pickMode') }}</option>
          <option v-for="m in allowedModes" :key="m" :value="m">{{ modeLabel(m) }}</option>
        </select>
      </label>

      <label class="block">
        <span :class="fieldLabel">{{ t('tutoring.enroll.amount') }}</span>
        <input v-model.number="amount" type="number" :class="inputCls" />
      </label>

      <label v-if="mode === 'PREPAID'" class="block">
        <span :class="fieldLabel">{{ t('tutoring.enroll.sessionsQuota') }}</span>
        <input v-model.number="sessionsQuota" type="number" :class="inputCls" />
      </label>

      <label v-if="mode === 'MONTHLY'" class="block">
        <span :class="fieldLabel">{{ t('tutoring.enroll.billingDay') }}</span>
        <input v-model.number="billingDay" type="number" :class="inputCls" />
      </label>

      <button
        :disabled="saving"
        class="w-full rounded-lg bg-role-admin hover:bg-role-admin/90 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="submit"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.enroll.submit') }}
      </button>
    </div>
  </div>
</template>
