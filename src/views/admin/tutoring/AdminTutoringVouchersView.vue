<!--
  AdminTutoringVouchersView — generate / manage promo codes.

  Admin sets discount type (% or rupiah), value, optional max uses +
  validity window, and toggles activation. Used count is read-only.

  Parents apply a voucher in the enroll flow (separate view); this
  screen is the source-of-truth for codes themselves.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type { TutoringVoucher } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const rows = ref<TutoringVoucher[]>([]);

const showCreate = ref(false);
const fCode = ref('');
const fType = ref<'PERCENTAGE' | 'AMOUNT'>('PERCENTAGE');
const fValue = ref<number>(10);
const fMaxUses = ref<string>('');
const fValidFrom = ref('');
const fValidUntil = ref('');
const fNotes = ref('');
const saving = ref(false);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getVouchers();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.vouchers.load_fail'));
  } finally {
    loading.value = false;
  }
}
onMounted(load);

function openCreate() {
  fCode.value = '';
  fType.value = 'PERCENTAGE';
  fValue.value = 10;
  fMaxUses.value = '';
  fValidFrom.value = '';
  fValidUntil.value = '';
  fNotes.value = '';
  showCreate.value = true;
}

async function submit() {
  const code = fCode.value.trim().toUpperCase();
  if (!/^[A-Z0-9_-]{3,40}$/.test(code)) {
    toast.error(t('admin.bimbel.vouchers.code_invalid'));
    return;
  }
  if (fValue.value < 1) {
    toast.error(t('admin.bimbel.vouchers.value_min'));
    return;
  }
  if (fType.value === 'PERCENTAGE' && fValue.value > 100) {
    toast.error(t('admin.bimbel.vouchers.pct_max'));
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createVoucher({
      code,
      type: fType.value,
      value: fValue.value,
      max_uses: fMaxUses.value ? Number(fMaxUses.value) : null,
      valid_from: fValidFrom.value || null,
      valid_until: fValidUntil.value || null,
      notes: fNotes.value.trim() || undefined,
    });
    showCreate.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.vouchers.save_fail'));
  } finally {
    saving.value = false;
  }
}

async function toggleActive(v: TutoringVoucher) {
  try {
    await TutoringService.updateVoucher(v.id, { is_active: !v.is_active });
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.vouchers.toggle_fail'));
  }
}

async function remove(v: TutoringVoucher) {
  if (!window.confirm(t('admin.bimbel.vouchers.delete_confirm', { code: v.code }))) return;
  try {
    await TutoringService.deleteVoucher(v.id);
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.vouchers.delete_fail'));
  }
}

function copyCode(code: string) {
  navigator.clipboard.writeText(code);
  toast.success(t('admin.bimbel.vouchers.code_copied', { code }));
}

function valueLabel(v: TutoringVoucher): string {
  if (v.type === 'PERCENTAGE') return `${v.value}%`;
  return formatRupiah(v.value);
}

const activeCount = computed(() => rows.value.filter((v) => v.is_active).length);
const totalRedemptions = computed(
  () => rows.value.reduce((s, v) => s + v.used_count, 0),
);
const expiredOrCapped = computed(() => {
  const now = Date.now();
  return rows.value.filter((v) => {
    if (v.max_uses != null && v.used_count >= v.max_uses) return true;
    if (v.valid_until && Date.parse(v.valid_until) < now) return true;
    return false;
  }).length;
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'wallet',
    label: t('admin.bimbel.vouchers.kpi_total'),
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: t('admin.bimbel.vouchers.kpi_active'),
    value: activeCount.value,
    tone: 'green',
  },
  {
    icon: 'sparkles',
    label: t('admin.bimbel.vouchers.kpi_redemptions'),
    value: totalRedemptions.value,
    tone: 'violet',
  },
  {
    icon: 'x-circle',
    label: t('admin.bimbel.vouchers.kpi_expired'),
    value: expiredOrCapped.value,
    tone: expiredOrCapped.value > 0 ? 'amber' : 'slate',
  },
]);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.vouchers.kicker')"
      :title="t('admin.bimbel.vouchers.title')"
      :meta="t('admin.bimbel.vouchers.meta', { total: rows.length, active: activeCount })"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-panel text-bimbel-accent text-[13px] font-bold hover:bg-bimbel-panel/90"
        @click="openCreate"
      >
        <NavIcon name="plus" :size="13" />
        {{ t('admin.bimbel.vouchers.new_voucher') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('admin.bimbel.vouchers.empty')"
      icon="wallet"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="v in rows"
        :key="v.id"
        icon="wallet"
        :title="v.code"
        :subtitle="[
          v.type === 'PERCENTAGE' ? t('admin.bimbel.vouchers.discount_pct', { value: v.value }) : t('admin.bimbel.vouchers.discount_amount', { value: formatRupiah(v.value) }),
          v.max_uses != null
            ? t('admin.bimbel.vouchers.uses_capped', { used: v.used_count, max: v.max_uses })
            : t('admin.bimbel.vouchers.uses_unbounded', { used: v.used_count }),
          v.valid_until ? t('admin.bimbel.vouchers.valid_until', { date: formatDateShort(v.valid_until) }) : null,
          v.notes,
        ].filter(Boolean).join(' · ')"
      >
        <template #trailing>
          <span class="inline-flex items-center gap-1.5">
            <button
              type="button"
              class="p-1.5 rounded-lg text-bimbel-text-mid hover:text-bimbel-accent hover:bg-bimbel-accent/5"
              :title="t('admin.bimbel.vouchers.copy_code')"
              @click.stop="copyCode(v.code)"
            >
              <NavIcon name="external-link" :size="14" />
            </button>
            <button
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider px-1.5 hover:underline"
              :class="v.is_active ? 'text-bimbel-amber' : 'text-bimbel-green'"
              @click.stop="toggleActive(v)"
            >
              {{ v.is_active ? t('admin.bimbel.vouchers.set_inactive') : t('admin.bimbel.vouchers.set_active') }}
            </button>
            <TutoringStatusPill
              :label="v.is_active ? t('admin.bimbel.vouchers.pill_active') : t('admin.bimbel.vouchers.pill_inactive')"
              :tone="v.is_active ? 'ok' : 'neutral'"
            />
            <button
              type="button"
              class="p-1.5 rounded-lg text-bimbel-text-lo hover:text-bimbel-red hover:bg-bimbel-red-soft"
              :title="t('admin.bimbel.vouchers.delete_title')"
              @click.stop="remove(v)"
            >
              <NavIcon name="trash-2" :size="14" />
            </button>
          </span>
        </template>
      </TutoringListTile>
    </div>

    <Modal v-if="showCreate" :title="t('admin.bimbel.vouchers.modal_title')" @close="showCreate = false">
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.vouchers.field_code') }}
          </span>
          <input
            v-model="fCode"
            :placeholder="t('admin.bimbel.vouchers.code_ph')"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm font-mono uppercase tracking-wider focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          />
          <p class="text-[12px] text-bimbel-text-mid mt-1">
            {{ t('admin.bimbel.vouchers.code_hint') }}
          </p>
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              {{ t('admin.bimbel.vouchers.field_type') }}
            </span>
            <select
              v-model="fType"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            >
              <option value="PERCENTAGE">{{ t('admin.bimbel.vouchers.type_percentage') }}</option>
              <option value="AMOUNT">{{ t('admin.bimbel.vouchers.type_amount') }}</option>
            </select>
          </label>
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              {{ t('admin.bimbel.vouchers.field_value') }}
            </span>
            <input
              v-model.number="fValue"
              type="number"
              :min="1"
              :max="fType === 'PERCENTAGE' ? 100 : undefined"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
        </div>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.vouchers.field_max_uses') }}
          </span>
          <input
            v-model="fMaxUses"
            type="number"
            min="1"
            :placeholder="t('admin.bimbel.vouchers.max_uses_ph')"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          />
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              {{ t('admin.bimbel.vouchers.field_valid_from') }}
            </span>
            <input
              v-model="fValidFrom"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              {{ t('admin.bimbel.vouchers.field_valid_until') }}
            </span>
            <input
              v-model="fValidUntil"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
        </div>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.vouchers.field_notes') }}
          </span>
          <textarea
            v-model="fNotes"
            rows="2"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent resize-none"
          />
        </label>

        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-bimbel-text-mid hover:bg-bimbel-border-soft"
            @click="showCreate = false"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-bimbel-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="submit"
          >
            {{ saving ? t('tutoring.common.saving') : t('admin.bimbel.vouchers.save') }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
