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

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';

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

// ── Voucher state — preview-only here; the redeem call fires after
// the enrollment is created so we can pass enrollment_id along.
const voucherCode = ref('');
const voucherPreview = ref<{
  code: string;
  discount_amount: number;
  final_amount: number;
} | null>(null);
const voucherErr = ref<string | null>(null);
const voucherChecking = ref(false);

const effectiveAmount = computed(
  () => voucherPreview.value?.final_amount ?? amount.value ?? 0,
);

async function applyVoucher() {
  const code = voucherCode.value.trim();
  if (!code) {
    voucherErr.value = 'Tempel kode dulu.';
    return;
  }
  if (amount.value == null || amount.value <= 0) {
    voucherErr.value = 'Isi nominal harga dulu sebelum apply.';
    return;
  }
  voucherChecking.value = true;
  voucherErr.value = null;
  try {
    const p = await TutoringService.validateVoucher(code, amount.value);
    voucherPreview.value = {
      code: p.code,
      discount_amount: p.discount_amount,
      final_amount: p.final_amount,
    };
  } catch (e) {
    voucherPreview.value = null;
    voucherErr.value = e instanceof Error ? e.message : 'Kode tidak valid.';
  } finally {
    voucherChecking.value = false;
  }
}
function clearVoucher() {
  voucherCode.value = '';
  voucherPreview.value = null;
  voucherErr.value = null;
}

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
    // If a voucher was applied, redeem now (before saving the plan)
    // so the plan amount reflects the discount + the redemption is
    // pinned to this enrollment.
    let finalAmount = amount.value;
    if (voucherPreview.value && enrollmentId) {
      try {
        const r = await TutoringService.redeemVoucher({
          code: voucherPreview.value.code,
          amount: amount.value,
          enrollment_id: enrollmentId,
        });
        finalAmount = r.final_amount;
      } catch (e) {
        toast.error(
          e instanceof Error
            ? `Voucher gagal: ${e.message}`
            : 'Voucher gagal di-redeem.',
        );
      }
    }

    const config: Record<string, number> = { amount: finalAmount };
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
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="'Bimbel · ' + programName"
      :title="t('tutoring.enroll.title')"
      meta="Pilih paket → kelompok → siswa → mode billing → Simpan"
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

      <!-- Voucher / promo code — apply BEFORE submit to preview the
           discount; the redeem call fires after the enrollment is
           created so we can pin redemption to it. -->
      <div>
        <span :class="fieldLabel">Kode voucher (opsional)</span>
        <div class="mt-1.5 flex gap-2">
          <input
            v-model="voucherCode"
            placeholder="cth. UTBK20OFF"
            class="flex-1 rounded-lg border border-slate-200 px-3 py-2 text-sm font-mono uppercase tracking-wider focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
            :disabled="!!voucherPreview"
          />
          <button
            v-if="!voucherPreview"
            type="button"
            :disabled="voucherChecking"
            class="rounded-lg bg-role-admin hover:bg-role-admin/90 px-3 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="applyVoucher"
          >
            {{ voucherChecking ? 'Cek…' : 'Apply' }}
          </button>
          <button
            v-else
            type="button"
            class="rounded-lg border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
            @click="clearVoucher"
          >
            Hapus
          </button>
        </div>
        <p
          v-if="voucherErr"
          class="text-xs text-status-danger mt-1"
        >
          {{ voucherErr }}
        </p>
        <p
          v-else-if="voucherPreview"
          class="text-xs text-status-success mt-1 font-semibold"
        >
          ✓ Diskon −{{ voucherPreview.discount_amount.toLocaleString('id-ID') }}
          · Total bayar
          <strong>{{ voucherPreview.final_amount.toLocaleString('id-ID') }}</strong>
        </p>
      </div>

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
