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
    toast.error(e instanceof Error ? e.message : 'Gagal memuat data.');
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
    toast.success('Rate tersimpan.');
    editing.value = null;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.');
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
    label: 'Tutor terdaftar',
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: 'Rate sudah diset',
    value: configuredCount.value,
    suffix:
      rows.value.length > 0
        ? `dari ${rows.value.length}`
        : undefined,
    tone: 'green',
  },
  {
    icon: 'alert-circle',
    label: 'Belum diset',
    value: rows.value.length - configuredCount.value,
    tone:
      rows.value.length - configuredCount.value > 0 ? 'amber' : 'slate',
  },
  {
    icon: 'wallet',
    label: 'Rata-rata rate',
    value:
      configuredCount.value > 0
        ? formatRupiah(Math.round(totalAmount.value / configuredCount.value))
        : '–',
    tone: 'violet',
  },
]);

function basisLabel(b: string) {
  return b === 'PER_HOUR' ? 'per jam' : 'per sesi';
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Penggajian"
      title="Honor Tutor"
      :meta="`${configuredCount} / ${rows.length} tutor sudah punya rate`"
    />

    <KpiStripCards :cards="kpiCards" />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      text="Belum ada tutor terdaftar."
      icon="users"
    />
    <div
      v-else
      class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-bimbel-text-mid">
          <tr class="border-b border-bimbel-border">
            <th class="text-left font-bold px-3 py-2.5">Tutor</th>
            <th class="text-left font-bold px-3 py-2.5">Basis</th>
            <th class="text-right font-bold px-3 py-2.5">Rate</th>
            <th class="px-3 py-2.5"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="r in rows"
            :key="r.userId"
            class="border-b border-bimbel-border-soft last:border-0 hover:bg-bimbel-bg cursor-pointer"
            @click="openEdit(r)"
          >
            <td class="px-3 py-3">
              <div class="font-semibold text-bimbel-text-hi">{{ r.name }}</div>
              <div class="text-xs text-bimbel-text-mid">{{ r.email }}</div>
            </td>
            <td class="px-3 py-3 text-bimbel-text-mid">{{ basisLabel(r.basis) }}</td>
            <td class="px-3 py-3 text-right">
              <span
                v-if="!r.configured"
                class="text-bimbel-amber text-xs font-bold"
              >Belum diset</span>
              <span v-else class="font-semibold text-bimbel-text-hi">
                {{ formatRupiah(r.amount) }}
              </span>
            </td>
            <td class="px-3 py-3 text-right">
              <NavIcon name="chevron-right" :size="14" class="text-bimbel-text-lo" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal
      v-if="editing"
      :title="`Atur Rate · ${editing.name}`"
      @close="editing = null"
    >
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Basis
          </span>
          <select
            v-model="editBasis"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          >
            <option value="PER_SESSION">Per Sesi</option>
            <option value="PER_HOUR">Per Jam</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Rate (Rp)
          </span>
          <input
            v-model.number="editAmount"
            type="number"
            min="0"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            placeholder="cth. 150000"
          />
          <p class="text-xs text-bimbel-text-mid mt-1">
            Honor {{ basisLabel(editBasis) }}, dalam rupiah.
          </p>
        </label>

        <!-- Rekening tujuan transfer honor — tampil di payslip PDF -->
        <div class="border-t border-bimbel-border-soft pt-3 mt-2">
          <div class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider mb-1.5">
            Rekening Tutor (opsional)
          </div>
          <p class="text-[11px] text-bimbel-text-mid mb-2">
            Tampil di slip honor PDF sebagai tujuan transfer dari bimbel.
          </p>
          <div class="grid grid-cols-2 gap-2">
            <input
              v-model="editBankName"
              type="text"
              maxlength="80"
              placeholder="Nama Bank"
              class="rounded-lg border border-bimbel-border px-3 py-2 text-sm"
            />
            <input
              v-model="editBankNumber"
              type="text"
              maxlength="40"
              placeholder="Nomor Rekening"
              class="rounded-lg border border-bimbel-border px-3 py-2 text-sm font-mono"
            />
          </div>
          <input
            v-model="editBankHolder"
            type="text"
            maxlength="120"
            placeholder="Atas Nama"
            class="mt-2 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm"
          />
        </div>
        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-bimbel-text-mid hover:bg-bimbel-border-soft"
            @click="editing = null"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-bimbel-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="saveEdit"
          >
            {{ saving ? t('tutoring.common.saving') : 'Simpan' }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
