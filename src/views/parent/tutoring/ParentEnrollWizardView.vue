<!--
  ParentEnrollWizardView — wali 4-step enrollment wizard.
  Steps: 1) Program  2) Paket  3) Mode bayar  4) Konfirmasi.
  Mockup-exact stepper + per-step option list with bimbel border-2 +
  offset-pad active style. Keeps the existing service calls
  (getPrograms/getPackages/getGroups/createEnrollment).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringGroup,
  TutoringPackage,
  TutoringProgram,
} from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const { children, activeChildId } = useChildPicker();

interface StepOption {
  id: string;
  title: string;
  subtitle: string;
  priceLabel?: string;
  icon: string;
  iconCls: string;
}

interface StepMeta {
  id: number;
  label: string;
  state: 'done' | 'on' | 'pending';
}

const currentStep = ref<1 | 2 | 3 | 4>(1);

const programs = ref<TutoringProgram[]>([]);
const programId = ref('');
const packages = ref<TutoringPackage[]>([]);
const packageId = ref('');
const billingMode = ref<string>('');
const groups = ref<TutoringGroup[]>([]);
const groupId = ref('');
const saving = ref(false);
const successId = ref<string | null>(null);
const errorMsg = ref<string | null>(null);

onMounted(async () => {
  try { programs.value = await TutoringService.getPrograms(); }
  catch {/* non-fatal */}
});

watch(programId, async (id) => {
  packageId.value = '';
  billingMode.value = '';
  if (!id) { packages.value = []; groups.value = []; return; }
  try {
    [packages.value, groups.value] = await Promise.all([
      TutoringService.getPackages(id),
      TutoringService.getGroups(id),
    ]);
  } catch {/* non-fatal */}
});

const selectedProgram = computed(() => programs.value.find((p) => p.id === programId.value) ?? null);
const selectedPackage = computed(() => packages.value.find((p) => p.id === packageId.value) ?? null);
const selectedGroup = computed(() => groups.value.find((g) => g.id === groupId.value) ?? null);
const selectedChild = computed(() =>
  children.value.find((c) => c.student_id === activeChildId.value) ?? children.value[0] ?? null,
);

const childFirstName = computed(
  () => (selectedChild.value?.name ?? t('wali.bimbel.enroll_wizard.default_child_name')).split(' ')[0] ?? t('wali.bimbel.enroll_wizard.default_child_name'),
);

const steps = computed<StepMeta[]>(() => {
  const labels = [
    t('wali.bimbel.enroll_wizard.step_label_program'),
    t('wali.bimbel.enroll_wizard.step_label_package'),
    t('wali.bimbel.enroll_wizard.step_label_mode'),
    t('wali.bimbel.enroll_wizard.step_label_confirm'),
  ];
  return labels.map((label, idx) => {
    const id = (idx + 1) as 1 | 2 | 3 | 4;
    const state: StepMeta['state'] =
      currentStep.value > id ? 'done' : currentStep.value === id ? 'on' : 'pending';
    return { id, label, state };
  });
});

const stepHeader = computed(() => {
  const ctx = selectedProgram.value?.name ?? '';
  if (currentStep.value === 1) return t('wali.bimbel.enroll_wizard.step_header_program');
  if (currentStep.value === 2) return ctx
    ? t('wali.bimbel.enroll_wizard.step_header_package_with_program', { program: ctx })
    : t('wali.bimbel.enroll_wizard.step_header_package');
  if (currentStep.value === 3) return t('wali.bimbel.enroll_wizard.step_header_mode');
  return t('wali.bimbel.enroll_wizard.step_header_confirm');
});

const billingModeOptions = computed<StepOption[]>(() => [
  { id: 'PREPAID', title: t('wali.bimbel.enroll_wizard.billing_prepaid_title'), subtitle: t('wali.bimbel.enroll_wizard.billing_prepaid_sub'), icon: 'wallet', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero' },
  { id: 'MONTHLY', title: t('wali.bimbel.enroll_wizard.billing_monthly_title'), subtitle: t('wali.bimbel.enroll_wizard.billing_monthly_sub'), icon: 'wallet', iconCls: 'bg-bimbel-green-dim text-green-700' },
  { id: 'PER_SESSION', title: t('wali.bimbel.enroll_wizard.billing_per_session_title'), subtitle: t('wali.bimbel.enroll_wizard.billing_per_session_sub'), icon: 'wallet', iconCls: 'bg-bimbel-amber-dim text-amber-700' },
]);

const stepOptions = computed<StepOption[]>(() => {
  if (currentStep.value === 1) {
    return programs.value.map((p, idx) => ({
      id: p.id,
      title: p.name,
      subtitle: p.description ?? '—',
      icon: 'school',
      iconCls: ['bg-bimbel-accent-dim text-bimbel-hero', 'bg-bimbel-green-dim text-green-700', 'bg-bimbel-amber-dim text-amber-700'][idx % 3] ?? 'bg-bimbel-accent-dim text-bimbel-hero',
    }));
  }
  if (currentStep.value === 2) {
    return packages.value.map((p, idx) => ({
      id: p.id,
      title: p.name,
      subtitle: t('wali.bimbel.enroll_wizard.package_sessions', { count: p.total_sessions ?? '–' }),
      priceLabel: p.price != null ? formatRupiah(p.price) : undefined,
      icon: 'package',
      iconCls: ['bg-bimbel-accent-dim text-bimbel-hero', 'bg-bimbel-green-dim text-green-700', 'bg-bimbel-amber-dim text-amber-700'][idx % 3] ?? 'bg-bimbel-accent-dim text-bimbel-hero',
    }));
  }
  if (currentStep.value === 3) {
    const allowed = selectedPackage.value?.billing_modes_allowed ?? ['PREPAID', 'MONTHLY'];
    return billingModeOptions.value.filter((m) => allowed.includes(m.id));
  }
  // Step 4 — confirmation rows surfaced as readonly option-style cards.
  return [
    { id: 'child', title: selectedChild.value?.name ?? '—', subtitle: t('wali.bimbel.enroll_wizard.confirmation_label_child'), icon: 'user', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero' },
    { id: 'program', title: selectedProgram.value?.name ?? '—', subtitle: t('wali.bimbel.enroll_wizard.confirmation_label_program'), icon: 'school', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero' },
    { id: 'package', title: selectedPackage.value?.name ?? '—', subtitle: t('wali.bimbel.enroll_wizard.confirmation_label_package'), priceLabel: selectedPackage.value?.price != null ? formatRupiah(selectedPackage.value.price) : undefined, icon: 'package', iconCls: 'bg-bimbel-green-dim text-green-700' },
    { id: 'mode', title: billingMode.value || '—', subtitle: t('wali.bimbel.enroll_wizard.confirmation_label_mode'), icon: 'wallet', iconCls: 'bg-bimbel-amber-dim text-amber-700' },
  ];
});

function isSelected(opt: StepOption): boolean {
  if (currentStep.value === 1) return programId.value === opt.id;
  if (currentStep.value === 2) return packageId.value === opt.id;
  if (currentStep.value === 3) return billingMode.value === opt.id;
  return false;
}

function selectOption(opt: StepOption) {
  if (currentStep.value === 1) programId.value = opt.id;
  else if (currentStep.value === 2) packageId.value = opt.id;
  else if (currentStep.value === 3) billingMode.value = opt.id;
}

const canAdvance = computed(() => {
  if (currentStep.value === 1) return !!programId.value;
  if (currentStep.value === 2) return !!packageId.value;
  if (currentStep.value === 3) return !!billingMode.value;
  return !saving.value;
});

const nextLabel = computed(() => {
  if (currentStep.value === 4) return saving.value ? t('wali.bimbel.enroll_wizard.submitting') : t('wali.bimbel.enroll_wizard.submit');
  return t('wali.bimbel.enroll_wizard.next');
});

function prev() {
  if (currentStep.value > 1) {
    currentStep.value = (currentStep.value - 1) as 1 | 2 | 3;
  }
}

async function next() {
  if (!canAdvance.value) return;
  if (currentStep.value < 4) {
    currentStep.value = (currentStep.value + 1) as 2 | 3 | 4;
    return;
  }
  // Final submit.
  if (!packageId.value || !selectedChild.value) return;
  saving.value = true;
  errorMsg.value = null;
  try {
    const id = await TutoringService.createEnrollment({
      student_id: selectedChild.value.student_id,
      package_id: packageId.value,
      billing_mode: billingMode.value || 'PREPAID',
      group_id: groupId.value || undefined,
    });
    successId.value = id;
  } catch (e) {
    errorMsg.value = e instanceof Error ? e.message : t('wali.bimbel.enroll_wizard.error_default');
  } finally {
    saving.value = false;
  }
}

function cancel() {
  router.back();
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      :kicker="t('wali.bimbel.enroll_wizard.kicker')"
      :title="t('wali.bimbel.enroll_wizard.title', { name: childFirstName })"
      :subtitle="t('wali.bimbel.enroll_wizard.subtitle_step', { current: currentStep, total: 4 })"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="cancel"
        >
          <NavIcon name="x" :size="12" />
          {{ t('wali.bimbel.enroll_wizard.cancel') }}
        </button>
      </template>
    </ParentBerandaHero>

    <div
      v-if="successId"
      class="rounded-lg bg-bimbel-green-dim p-6 text-center"
    >
      <div class="mx-auto mb-2 grid h-10 w-10 place-items-center rounded-full bg-green-700 text-white">
        <NavIcon name="check" :size="18" />
      </div>
      <h3 class="text-[14px] font-bold text-bimbel-text-hi">{{ t('wali.bimbel.enroll_wizard.success_title') }}</h3>
      <p class="mt-1 text-[13px] text-bimbel-text-mid">{{ t('wali.bimbel.enroll_wizard.enrollment_id', { id: successId }) }}</p>
      <button
        type="button"
        class="mt-4 rounded-lg bg-bimbel-hero text-white text-[14px] font-bold px-4 py-2"
        @click="router.push({ name: 'parent.tutoring.bills' })"
      >{{ t('wali.bimbel.enroll_wizard.success_button') }}</button>
    </div>

    <template v-else>
      <!-- Stepper -->
      <div class="flex items-center gap-0">
        <template v-for="(s, i) in steps" :key="s.id">
          <div class="flex items-center gap-1.5">
            <div
              :class="[
                'w-[22px] h-[22px] rounded-full grid place-items-center text-[12px] font-bold',
                s.state === 'done'
                  ? 'bg-green-700 text-white'
                  : s.state === 'on'
                  ? 'bg-bimbel-hero text-white'
                  : 'bg-bimbel-bg text-bimbel-text-mid',
              ]"
            >
              <NavIcon v-if="s.state === 'done'" name="check" :size="12" />
              <span v-else>{{ i + 1 }}</span>
            </div>
            <span
              :class="[
                'text-[12px]',
                s.state === 'on'
                  ? 'text-bimbel-text-hi font-bold'
                  : s.state === 'done'
                  ? 'text-bimbel-text-hi'
                  : 'text-bimbel-text-mid',
              ]"
            >{{ s.label }}</span>
          </div>
          <div
            v-if="i < steps.length - 1"
            :class="[
              'flex-1 h-px mx-1.5',
              s.state === 'done' ? 'bg-green-700' : 'bg-bimbel-border-soft',
            ]"
          ></div>
        </template>
      </div>

      <!-- Step header + body -->
      <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
        {{ stepHeader }}
      </p>

      <div
        v-if="!stepOptions.length"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-6 text-center text-[13px] text-bimbel-text-mid"
      >
        {{ t('wali.bimbel.enroll_wizard.empty_options') }}
      </div>

      <button
        v-for="opt in stepOptions"
        :key="opt.id"
        type="button"
        :class="[
          'w-full rounded-md bg-bimbel-panel border flex gap-2.5 items-center mb-1.5 text-left transition-colors',
          isSelected(opt) ? 'border-2 border-bimbel-hero p-[11px]' : 'border-bimbel-border-soft p-3',
          currentStep === 4 ? 'cursor-default' : '',
        ]"
        :disabled="currentStep === 4"
        @click="selectOption(opt)"
      >
        <div class="w-10 h-10 rounded-lg grid place-items-center flex-shrink-0" :class="opt.iconCls">
          <NavIcon :name="opt.icon || 'package'" :size="18" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[14px] font-bold text-bimbel-text-hi">{{ opt.title }}</p>
          <p class="text-[12px] text-bimbel-text-mid">{{ opt.subtitle }}</p>
        </div>
        <p v-if="opt.priceLabel" class="text-[14px] font-bold text-bimbel-hero flex-shrink-0">
          {{ opt.priceLabel }}
        </p>
      </button>

      <div
        v-if="errorMsg"
        class="rounded-md mt-3 bg-bimbel-red-dim text-red-700 px-3 py-2 text-[13px]"
      >{{ errorMsg }}</div>

      <div class="flex gap-2 mt-3">
        <button
          v-if="currentStep > 1"
          type="button"
          class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft text-[14px] px-3.5 py-2.5"
          @click="prev"
        >{{ t('wali.bimbel.enroll_wizard.prev') }}</button>
        <button
          type="button"
          :disabled="!canAdvance"
          class="flex-1 rounded-lg bg-bimbel-hero text-white text-[14px] font-bold px-3.5 py-2.5 disabled:opacity-50"
          @click="next"
        >{{ nextLabel }}</button>
      </div>
    </template>
  </div>
</template>
