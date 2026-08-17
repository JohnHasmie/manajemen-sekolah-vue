<!--
  AdminTutoring2PayoutRatesView.vue — WEB-16 (BE-24 rates).

  Admin view: honorarium catalogue per tutor. One row per rate; a
  tutor's LIVE rate is the highest `effective_from ≤ today` where
  `effective_until` is null OR future-dated. "Akhiri rate" stamps
  today's date on `effective_until` (POST /rates/{id}/end) so the row
  drops out of the LIVE set without deleting historical rows — payout
  history keeps referencing the exact rate that was in force at the
  time (see PayoutRateKind::PerSession semantics).

  All writes gate on `tutoring.payout.rates.manage`; reads gate on
  `tutoring.payout.view_all`. The controller also enforces these but
  hiding the FAB / disable actions in the UI keeps the affordance
  honest for non-admin managers.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import FormField from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { toLocalYmd } from '@/lib/local-date';
import { PayoutsService } from '@/services/tutoring2/payouts';
import type { StatusBadgeTone } from '@/types/status-badge';
import type {
  PayoutRate,
  PayoutRateKind,
  UpsertPayoutRatePayload,
} from '@/types/tutoring2/payout';
import { PAYOUT_RATE_KINDS } from '@/types/tutoring2/payout';

const { t } = useI18n();
const toast = useToast();
const { can } = useMe();

const canManage = computed(() => can('tutoring.payout.rates.manage'));

// ─── Filters ────────────────────────────────────────────────────────

const search = ref('');
const kindFilter = ref<string>(''); // '' | PayoutRateKind
const activeOnly = ref(false);

const { state, reload } = useDataRefresh(async () => {
  const { items } = await PayoutsService.listRates({
    per_page: 100,
    active_only: activeOnly.value || undefined,
  });
  return items;
});
watch([kindFilter, activeOnly], () => reload());

const filteredRates = computed<PayoutRate[]>(() => {
  const rates = state.value.status === 'content' ? (state.value.data as PayoutRate[]) : [];
  const q = search.value.trim().toLowerCase();
  return rates.filter((r) => {
    if (kindFilter.value && r.kind !== kindFilter.value) return false;
    if (q && !(r.tutor_name ?? r.tutor_id).toLowerCase().includes(q)) return false;
    return true;
  });
});

// A rate is "live" if effective_from ≤ today and effective_until is
// null or strictly future — matches the backend's LIVE set logic on
// PayoutRate::pickForSession.
function isRateLive(r: PayoutRate): boolean {
  const today = toLocalYmd();
  if (r.effective_from > today) return false;
  if (r.effective_until && r.effective_until <= today) return false;
  return true;
}

// ─── KPI ────────────────────────────────────────────────────────────

const kpiCards = computed<KpiCard[]>(() => {
  const rows = filteredRates.value;
  const live = rows.filter(isRateLive).length;
  const perSession = rows.filter((r) => r.kind === 'per_session').length;
  const monthly = rows.filter((r) => r.kind === 'monthly_salary').length;
  return [
    { icon: 'wallet', label: t('tutoring2.admin.payoutRates.kpiLive'), value: String(live) },
    { icon: 'calendar-check', label: t('tutoring2.admin.payoutRates.kpiPerSession'), value: String(perSession) },
    { icon: 'file-text', label: t('tutoring2.admin.payoutRates.kpiMonthly'), value: String(monthly) },
    { icon: 'clock', label: t('tutoring2.admin.payoutRates.kpiTotal'), value: String(rows.length), tone: 'slate' },
  ];
});

// ─── Sheet + confirm state ──────────────────────────────────────────

const showSheet = ref(false);
const isSaving = ref(false);
const form = ref<UpsertPayoutRatePayload>({
  tutor_id: '',
  kind: 'per_session',
  value: 0,
  effective_from: toLocalYmd(),
  effective_until: null,
  notes: '',
});
const formError = ref<string | null>(null);

function openNewSheet() {
  form.value = {
    tutor_id: '',
    kind: 'per_session',
    value: 0,
    effective_from: toLocalYmd(),
    effective_until: null,
    notes: '',
  };
  formError.value = null;
  showSheet.value = true;
}

async function submitSheet() {
  formError.value = null;
  if (!form.value.tutor_id || form.value.value <= 0) {
    formError.value = t('tutoring2.admin.payoutRates.errFill');
    return;
  }
  if (form.value.kind === 'percent_revenue' && form.value.value > 100) {
    formError.value = t('tutoring2.admin.payoutRates.errPercentBounds');
    return;
  }
  isSaving.value = true;
  try {
    await PayoutsService.upsertRate(form.value);
    toast.success(t('tutoring2.admin.payoutRates.saved'));
    showSheet.value = false;
    await reload();
  } catch (e) {
    formError.value = extractError(e) ?? t('tutoring2.common.saveFailed');
  } finally {
    isSaving.value = false;
  }
}

const endTarget = ref<PayoutRate | null>(null);
const isEnding = ref(false);
async function confirmEnd() {
  if (!endTarget.value) return;
  isEnding.value = true;
  try {
    await PayoutsService.endRate(endTarget.value.id);
    toast.success(t('tutoring2.admin.payoutRates.ended'));
    endTarget.value = null;
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.actionFailed'));
  } finally {
    isEnding.value = false;
  }
}

// ─── Helpers ────────────────────────────────────────────────────────

function extractError(e: unknown): string | null {
  const err = e as { response?: { data?: { message?: string; errors?: Record<string, string[]> } } };
  const msg = err?.response?.data?.message;
  if (msg) return msg;
  const errors = err?.response?.data?.errors;
  if (errors) {
    const first = Object.values(errors)[0];
    if (Array.isArray(first) && first.length > 0) return first[0];
  }
  return null;
}

function kindLabel(kind: PayoutRateKind): string {
  return t(`tutoring2.admin.payoutRates.kind.${kind}`);
}

function kindTone(kind: PayoutRateKind): StatusBadgeTone {
  switch (kind) {
    case 'per_session': return 'info';
    case 'monthly_salary': return 'success';
    case 'percent_revenue': return 'warning';
  }
}

function formatValue(r: PayoutRate): string {
  if (r.kind === 'percent_revenue') return `${r.value}%`;
  return `Rp ${r.value.toLocaleString('id-ID')}`;
}

function truncateId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

function rateStatusLabel(r: PayoutRate): string {
  if (isRateLive(r)) return t('tutoring2.admin.payoutRates.status.live');
  if (r.effective_from > toLocalYmd()) return t('tutoring2.admin.payoutRates.status.future');
  return t('tutoring2.admin.payoutRates.status.ended');
}

function rateStatusTone(r: PayoutRate): StatusBadgeTone {
  if (isRateLive(r)) return 'success';
  if (r.effective_from > toLocalYmd()) return 'info';
  return 'neutral';
}

const kindOptions = PAYOUT_RATE_KINDS.map((k) => ({ value: k, label: kindLabel(k) }));

const valueHint = computed(() => {
  switch (form.value.kind) {
    case 'per_session': return t('tutoring2.admin.payoutRates.hintPerSession');
    case 'monthly_salary': return t('tutoring2.admin.payoutRates.hintMonthly');
    case 'percent_revenue': return t('tutoring2.admin.payoutRates.hintPercent');
  }
});
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.payoutRates.title')"
      :meta="state.status === 'content' ? t('tutoring2.admin.payoutRates.meta', { count: filteredRates.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.payoutRates.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.kind')"
          :value="kindFilter ? kindLabel(kindFilter as PayoutRateKind) : t('tutoring2.common.all')"
          icon-name="tag"
          :active="!!kindFilter"
          @click="kindFilter = kindFilter ? '' : 'per_session'"
        />
        <AppFilterChip
          :label="t('tutoring2.admin.payoutRates.filterActiveOnly')"
          :value="activeOnly ? t('tutoring2.common.on') : t('tutoring2.common.off')"
          icon-name="circle-check"
          :active="activeOnly"
          @click="activeOnly = !activeOnly"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.payoutRates.emptyTitle')"
      :empty-description="t('tutoring2.admin.payoutRates.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.kind') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutRates.value') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutRates.effectiveFrom') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutRates.effectiveUntil') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold text-right">{{ t('tutoring2.common.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in filteredRates"
                :key="r.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-semibold text-slate-900">{{ r.tutor_name ?? truncateId(r.tutor_id) }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="kindLabel(r.kind)" :tone="kindTone(r.kind)" uppercase />
                </td>
                <td class="px-4 py-3 font-semibold text-slate-900">{{ formatValue(r) }}</td>
                <td class="px-4 py-3 text-slate-600">{{ r.effective_from }}</td>
                <td class="px-4 py-3 text-slate-600">{{ r.effective_until ?? '—' }}</td>
                <td class="px-4 py-3">
                  <StatusBadge :label="rateStatusLabel(r)" :tone="rateStatusTone(r)" uppercase />
                </td>
                <td class="px-4 py-3 text-right">
                  <Button
                    v-if="canManage && isRateLive(r)"
                    variant="secondary"
                    size="sm"
                    @click="endTarget = r"
                  >
                    {{ t('tutoring2.admin.payoutRates.endCta') }}
                  </Button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      v-if="canManage"
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openNewSheet"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.payoutRates.newCta') }}
    </button>

    <FormSheet
      v-if="showSheet"
      :title="t('tutoring2.admin.payoutRates.sheetTitle')"
      :subtitle="t('tutoring2.admin.payoutRates.sheetSubtitle')"
      :saving="isSaving"
      :save-label="t('tutoring2.common.save')"
      @save="submitSheet"
      @cancel="showSheet = false"
      @close="showSheet = false"
    >
      <div class="space-y-3">
        <FormField
          v-model="form.tutor_id"
          :label="t('tutoring2.common.tutor')"
          type="text"
          required
          :placeholder="t('tutoring2.admin.payoutRates.tutorIdPh')"
        />
        <FormField
          v-model="form.kind"
          :label="t('tutoring2.common.kind')"
          type="select"
          required
          :options="kindOptions"
        />
        <FormField
          v-model.number="form.value"
          :label="t('tutoring2.admin.payoutRates.value')"
          type="number"
          required
          :min="1"
          number-model
          :placeholder="valueHint"
        />
        <p class="text-2xs text-slate-500">{{ valueHint }}</p>
        <FormField
          v-model="form.effective_from"
          :label="t('tutoring2.admin.payoutRates.effectiveFrom')"
          type="text"
          required
          placeholder="YYYY-MM-DD"
        />
        <FormField
          v-model="form.effective_until"
          :label="t('tutoring2.admin.payoutRates.effectiveUntil') + ' (' + t('tutoring2.common.optional') + ')'"
          type="text"
          placeholder="YYYY-MM-DD"
        />
        <FormField
          v-model="form.notes"
          :label="t('tutoring2.common.notes') + ' (' + t('tutoring2.common.optional') + ')'"
          type="textarea"
          :rows="2"
        />
        <p v-if="formError" class="text-xs text-status-danger">{{ formError }}</p>
      </div>
    </FormSheet>

    <ConfirmationDialog
      v-if="endTarget"
      :title="t('tutoring2.admin.payoutRates.endConfirmTitle')"
      :message="t('tutoring2.admin.payoutRates.endConfirmMsg', { name: endTarget.tutor_name ?? truncateId(endTarget.tutor_id) })"
      :confirm-label="t('tutoring2.admin.payoutRates.endCta')"
      :cancel-label="t('tutoring2.common.cancel')"
      :loading="isEnding"
      danger
      :impact="[
        t('tutoring2.admin.payoutRates.impactStopFuture'),
        t('tutoring2.admin.payoutRates.impactKeepHistory'),
      ]"
      @confirm="confirmEnd"
      @close="endTarget = null"
    />
  </div>
</template>
