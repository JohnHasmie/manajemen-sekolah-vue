<!--
  AdminTutoringPayoutsView — admin sets the honorarium rate per tutor.

  Loads the tenant's tutor list (TutoringService.getAdminTutors) and
  merges with the rates table so admins can see every tutor (even
  those without a rate yet) and inline-edit their basis + amount.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringTutorRow,
  TutorPayoutRate,
} from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

interface Row {
  userId: string;
  name: string;
  email: string;
  basis: 'PER_SESSION' | 'PER_HOUR';
  amount: number;
  configured: boolean;
  bankName: string;
  bankAccountNumber: string;
  bankAccountHolder: string;
}

const loading = ref(true);
const rows = ref<Row[]>([]);
const editing = ref<Row | null>(null);
const editBasis = ref<'PER_SESSION' | 'PER_HOUR'>('PER_SESSION');
const editAmount = ref<number>(0);
const editBankName = ref('');
const editBankNumber = ref('');
const editBankHolder = ref('');
const saving = ref(false);

async function load() {
  loading.value = true;
  try {
    const [tutors, rates] = await Promise.all([
      TutoringService.getAdminTutors(),
      TutoringService.getPayoutRates(),
    ]);
    const byUser = new Map<string, TutorPayoutRate>();
    for (const r of rates) byUser.set(r.user_id, r);
    rows.value = tutors.map((tt: TutoringTutorRow) => {
      const r = byUser.get(tt.user_id);
      return {
        userId: tt.user_id,
        name: tt.name,
        email: tt.email,
        basis: (r?.basis ?? 'PER_SESSION') as 'PER_SESSION' | 'PER_HOUR',
        amount: r?.amount ?? 0,
        configured: r !== undefined,
        bankName: r?.bank_name ?? '',
        bankAccountNumber: r?.bank_account_number ?? '',
        bankAccountHolder: r?.bank_account_holder ?? '',
      };
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.payouts.load_fail'));
  } finally {
    loading.value = false;
  }
}
onMounted(load);

function openEdit(r: Row) {
  editing.value = r;
  editBasis.value = r.basis;
  editAmount.value = r.amount;
  editBankName.value = r.bankName;
  editBankNumber.value = r.bankAccountNumber;
  editBankHolder.value = r.bankAccountHolder;
}

async function saveEdit() {
  if (!editing.value) return;
  saving.value = true;
  try {
    await TutoringService.upsertPayoutRate(editing.value.userId, {
      basis: editBasis.value,
      amount: Math.max(0, Math.floor(editAmount.value)),
      bank_name: editBankName.value.trim() || null,
      bank_account_number: editBankNumber.value.trim() || null,
      bank_account_holder: editBankHolder.value.trim() || null,
    });
    toast.success(t('admin.bimbel.payouts.saved'));
    editing.value = null;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.payouts.save_fail'));
  } finally {
    saving.value = false;
  }
}

const configuredCount = computed(
  () => rows.value.filter((r) => r.configured).length,
);
const totalAmount = computed(
  () => rows.value.reduce((s, r) => s + (r.configured ? r.amount : 0), 0),
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: t('admin.bimbel.payouts.kpi_registered'),
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: t('admin.bimbel.payouts.kpi_configured'),
    value: configuredCount.value,
    suffix:
      rows.value.length > 0
        ? t('admin.bimbel.payouts.kpi_configured_suffix', { total: rows.value.length })
        : undefined,
    tone: 'green',
  },
  {
    icon: 'alert-circle',
    label: t('admin.bimbel.payouts.kpi_not_set'),
    value: rows.value.length - configuredCount.value,
    tone:
      rows.value.length - configuredCount.value > 0 ? 'amber' : 'slate',
  },
  {
    icon: 'wallet',
    label: t('admin.bimbel.payouts.kpi_avg_rate'),
    value:
      configuredCount.value > 0
        ? formatRupiah(Math.round(totalAmount.value / configuredCount.value))
        : '–',
    tone: 'violet',
  },
]);

function basisLabel(b: string) {
  return b === 'PER_HOUR' ? t('admin.bimbel.payouts.basis_per_hour_label') : t('admin.bimbel.payouts.basis_per_session_label');
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.payouts.kicker')"
      :title="t('admin.bimbel.payouts.title')"
      :meta="t('admin.bimbel.payouts.meta', { configured: configuredCount, total: rows.length })"
    />

    <KpiStripCards :cards="kpiCards" />

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('admin.bimbel.payouts.empty')"
      icon="users"
    />
    <div
      v-else
      class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-tutoring-text-mid">
          <tr class="border-b border-tutoring-border">
            <th class="text-left font-bold px-3 py-2.5">{{ t('admin.bimbel.payouts.th_tutor') }}</th>
            <th class="text-left font-bold px-3 py-2.5">{{ t('admin.bimbel.payouts.th_basis') }}</th>
            <th class="text-right font-bold px-3 py-2.5">{{ t('admin.bimbel.payouts.th_rate') }}</th>
            <th class="px-3 py-2.5"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="r in rows"
            :key="r.userId"
            class="border-b border-tutoring-border-soft last:border-0 hover:bg-tutoring-bg cursor-pointer"
            @click="openEdit(r)"
          >
            <td class="px-3 py-3">
              <div class="font-semibold text-tutoring-text-hi">{{ r.name }}</div>
              <div class="text-xs text-tutoring-text-mid">{{ r.email }}</div>
            </td>
            <td class="px-3 py-3 text-tutoring-text-mid">{{ basisLabel(r.basis) }}</td>
            <td class="px-3 py-3 text-right">
              <span
                v-if="!r.configured"
                class="text-tutoring-amber text-xs font-bold"
              >{{ t('admin.bimbel.payouts.rate_not_set') }}</span>
              <span v-else class="font-semibold text-tutoring-text-hi">
                {{ formatRupiah(r.amount) }}
              </span>
            </td>
            <td class="px-3 py-3 text-right">
              <NavIcon name="chevron-right" :size="14" class="text-tutoring-text-lo" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal
      v-if="editing"
      :title="t('admin.bimbel.payouts.modal_title', { name: editing.name })"
      @close="editing = null"
    >
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.payouts.field_basis') }}
          </span>
          <select
            v-model="editBasis"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
          >
            <option value="PER_SESSION">{{ t('admin.bimbel.payouts.basis_per_session') }}</option>
            <option value="PER_HOUR">{{ t('admin.bimbel.payouts.basis_per_hour') }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.payouts.field_rate') }}
          </span>
          <input
            v-model.number="editAmount"
            type="number"
            min="0"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
            :placeholder="t('admin.bimbel.payouts.rate_ph')"
          />
          <p class="text-xs text-tutoring-text-mid mt-1">
            {{ t('admin.bimbel.payouts.rate_hint', { basis: basisLabel(editBasis) }) }}
          </p>
        </label>

        <!-- Rekening tujuan transfer honor — tampil di payslip PDF -->
        <div class="border-t border-tutoring-border-soft pt-3 mt-2">
          <div class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider mb-1.5">
            {{ t('admin.bimbel.payouts.bank_section') }}
          </div>
          <p class="text-[12px] text-tutoring-text-mid mb-2">
            {{ t('admin.bimbel.payouts.bank_hint') }}
          </p>
          <div class="grid grid-cols-2 gap-2">
            <input
              v-model="editBankName"
              type="text"
              maxlength="80"
              :placeholder="t('admin.bimbel.payouts.bank_name_ph')"
              class="rounded-lg border border-tutoring-border px-3 py-2 text-sm"
            />
            <input
              v-model="editBankNumber"
              type="text"
              maxlength="40"
              :placeholder="t('admin.bimbel.payouts.bank_number_ph')"
              class="rounded-lg border border-tutoring-border px-3 py-2 text-sm font-mono"
            />
          </div>
          <input
            v-model="editBankHolder"
            type="text"
            maxlength="120"
            :placeholder="t('admin.bimbel.payouts.bank_holder_ph')"
            class="mt-2 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm"
          />
        </div>
        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
            @click="editing = null"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-tutoring-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="saveEdit"
          >
            {{ saving ? t('tutoring.common.saving') : t('admin.bimbel.payouts.save') }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
