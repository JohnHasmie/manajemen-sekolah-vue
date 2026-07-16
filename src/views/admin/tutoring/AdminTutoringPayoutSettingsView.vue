<!--
  AdminTutoringPayoutSettingsView — tenant-level toggles that gate the
  tutor self-service honor-withdrawal flow.

  Three rows mirror the backend TutorPayoutSettings model:
    1. allow_partial_withdrawal   — let the tutor request less than the
                                     full eligible amount.
    2. min_withdrawal_amount      — block requests below this floor.
    3. auto_approve_full_amount   — auto-flip PENDING → APPROVED on
                                     create when the request matches
                                     the computed eligible amount (and
                                     equals the full month).

  Save is manual (no debounced auto-save). The "Save" button stays
  visible only when the local state diverges from the loaded server
  copy — matches the BillingSettings view's pattern.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutorPayoutSettings } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const saving = ref(false);
const allowPartial = ref(false);
const minAmount = ref<number>(0);
const autoApproveFull = ref(false);
/** The last successful server copy — used for the dirty-check. */
const persisted = ref<TutorPayoutSettings | null>(null);

const dirty = computed(() => {
  const p = persisted.value;
  if (!p) return false;
  return (
    p.allow_partial_withdrawal !== allowPartial.value ||
    Number(p.min_withdrawal_amount ?? 0) !== Number(minAmount.value || 0) ||
    p.auto_approve_full_amount !== autoApproveFull.value
  );
});

async function load() {
  loading.value = true;
  try {
    const s = await TutoringService.getPayoutSettings();
    allowPartial.value = !!s.allow_partial_withdrawal;
    minAmount.value = Number(s.min_withdrawal_amount ?? 0);
    autoApproveFull.value = !!s.auto_approve_full_amount;
    persisted.value = s;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.bimbel.payout_settings.load_fail'),
    );
  } finally {
    loading.value = false;
  }
}
onMounted(load);

async function save() {
  if (!dirty.value) return;
  saving.value = true;
  try {
    const updated = await TutoringService.updatePayoutSettings({
      allow_partial_withdrawal: allowPartial.value,
      min_withdrawal_amount: Math.max(0, Math.floor(minAmount.value || 0)),
      auto_approve_full_amount: autoApproveFull.value,
    });
    persisted.value = updated;
    allowPartial.value = !!updated.allow_partial_withdrawal;
    minAmount.value = Number(updated.min_withdrawal_amount ?? 0);
    autoApproveFull.value = !!updated.auto_approve_full_amount;
    toast.success(t('admin.bimbel.payout_settings.saved'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.bimbel.payout_settings.save_fail'),
    );
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.payout_settings.kicker')"
      :title="t('admin.bimbel.payout_settings.title')"
      :meta="t('admin.bimbel.payout_settings.meta')"
    />

    <div v-if="loading" class="space-y-2 py-4" aria-hidden="true">
      <div v-for="i in 3" :key="i" class="flex items-center gap-3 rounded-xl bg-tutoring-panel border border-tutoring-border-soft p-3">
        <div class="h-8 w-8 rounded-lg bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        <div class="flex-1 space-y-2">
          <div class="h-3 w-2/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
          <div class="h-2 w-3/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        </div>
      </div>
    </div>

    <div v-else class="space-y-3">
      <!-- Row 1: allow_partial_withdrawal -->
      <label
        class="flex items-center justify-between gap-3 bg-tutoring-panel border border-tutoring-border-soft rounded-2xl px-4 py-3 cursor-pointer"
      >
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-tutoring-text-hi">
            {{ t('admin.bimbel.payout_settings.allow_partial_title') }}
          </span>
          <span class="block text-xs text-tutoring-text-mid mt-0.5">
            {{ t('admin.bimbel.payout_settings.allow_partial_sub') }}
          </span>
        </span>
        <input
          v-model="allowPartial"
          type="checkbox"
          class="h-5 w-5 accent-role-admin"
        />
      </label>

      <!-- Row 2: min_withdrawal_amount -->
      <div
        class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4"
      >
        <p class="text-sm font-semibold text-tutoring-text-hi">
          {{ t('admin.bimbel.payout_settings.min_amount_title') }}
        </p>
        <p class="text-xs text-tutoring-text-mid mt-0.5">
          {{ t('admin.bimbel.payout_settings.min_amount_sub') }}
        </p>
        <div class="mt-2 flex items-center gap-2">
          <span class="text-sm text-tutoring-text-mid">Rp</span>
          <input
            v-model.number="minAmount"
            type="number"
            min="0"
            step="10000"
            class="w-40 rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
          />
          <span
            v-if="(minAmount ?? 0) > 0"
            class="text-xs text-tutoring-text-lo"
          >· {{ formatRupiah(minAmount) }}</span>
        </div>
      </div>

      <!-- Row 3: auto_approve_full_amount -->
      <label
        class="flex items-center justify-between gap-3 bg-tutoring-panel border border-tutoring-border-soft rounded-2xl px-4 py-3 cursor-pointer"
      >
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-tutoring-text-hi">
            {{ t('admin.bimbel.payout_settings.auto_approve_title') }}
          </span>
          <span class="block text-xs text-tutoring-text-mid mt-0.5">
            {{ t('admin.bimbel.payout_settings.auto_approve_sub') }}
          </span>
        </span>
        <input
          v-model="autoApproveFull"
          type="checkbox"
          class="h-5 w-5 accent-role-admin"
        />
      </label>

      <button
        :disabled="!dirty || saving"
        class="mt-2 w-full rounded-lg bg-tutoring-accent hover:opacity-90 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="save"
      >
        {{ saving
          ? t('tutoring.common.saving')
          : dirty
            ? t('tutoring.common.save')
            : t('admin.bimbel.payout_settings.no_changes') }}
      </button>
    </div>
  </div>
</template>
