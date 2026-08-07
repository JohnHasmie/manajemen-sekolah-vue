<!--
  TutorTutoring2WithdrawalDialog.vue — modal a tutor uses to file a
  payout (honor) withdrawal request (CLEAN-2 Phase 2 · greenfield
  replacement for `components/tutoring/TutorWithdrawalDialog.vue`).

  Opened from TutorTutoring2EarningsView; renders on the shared
  `ui/Modal.vue` primitive.

  Endpoints:
    GET  /tutoring-v2/payouts/settings  — minimum_payout floor
    GET  /tutoring-v2/payouts/summary   — self-scoped eligible amount
    POST /tutoring-v2/payouts/requests  — file the request

  CONTRACT DIFFERENCES vs the legacy v1 dialog — read before touching:

  1. DROPPED: THE BANK-ACCOUNT BLOCK. v1 read the tutor's default bank
     details off the v1 payout-summary response and let them override
     `bank_name` / `bank_account_number` / `bank_account_holder` per
     request (backed by v1 `GET /tutoring/payment-account`). v2 has NO
     payment-account route, `SelfPayoutSummary` carries no bank fields,
     and `SubmitPayoutRequestRequest` accepts ONLY
     `{period_month, amount, note}` — any bank keys posted would be
     dropped on the floor. Shipping the inputs would tell the tutor
     their transfer destination was saved when nothing was saved, so
     the whole section is gone. The `note` field is where a tutor can
     state a destination in free text until a backend account route
     exists. See V2_GAPS.

  2. DROPPED: THE CUSTOM DATE-RANGE TAB. v1 offered "Per bulan" vs an
     arbitrary from/to range and posted `period_from` + `period_to`.
     v2's period is a single strict `period_month` (`YYYY-MM`, backed
     by a varchar(7) column that downstream aggregation relies on), so
     an arbitrary range is not expressible. The tab strip is gone
     rather than kept with a dead half.

  3. NO `allow_partial_withdrawal` FLAG. v1 locked the amount input
     when the tenant disallowed partial withdrawals. v2's
     PayoutSettings has no such flag — only `minimum_payout` — so the
     amount is always editable and validated against that floor.
     Do not re-add a lock keyed off a field that does not exist.

  4. WIRE KEY: the month is `period_month`, not `month`. See the note
     on CreatePayoutRequestPayload in `@/types/tutoring2/payout`.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import { PayoutsService } from '@/services/tutoring2/payouts';
import type { PayoutSettings } from '@/types/tutoring2/payout';

const props = defineProps<{
  /**
   * `YYYY-MM` the parent view is currently showing. Seeds the month
   * picker so the dialog opens on the period the tutor was reading.
   */
  initialMonth?: string;
  /**
   * Net eligible amount the parent already fetched for `initialMonth`,
   * used to seed the amount input without waiting for our own summary
   * round-trip. Refreshed from the server on mount / month change.
   */
  initialEligible?: number;
}>();

const emit = defineEmits<{
  close: [];
  /** Fires after a successful POST so the parent reloads its lists. */
  submitted: [];
}>();

const { t } = useI18n();
const toast = useToast();

/** Current calendar month from LOCAL parts — `toISOString().slice(0,7)`
 *  is UTC and rolls a WIB tutor back a month for the first 7 hours of
 *  every 1st. Same helper shape as TutorTutoring2EarningsView. */
function currentLocalMonth(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

const loading = ref(true);
const submitting = ref(false);
const settings = ref<PayoutSettings | null>(null);
const eligibleAmount = ref<number | null>(props.initialEligible ?? null);
const errorMessage = ref<string | null>(null);

const month = ref<string>(props.initialMonth ?? currentLocalMonth());
const amount = ref<number>(props.initialEligible ?? 0);
const note = ref('');

/** Last 6 months, newest first — all built from LOCAL date parts. */
const monthOptions = computed<Array<{ value: string; label: string }>>(() => {
  const out: Array<{ value: string; label: string }> = [];
  const now = new Date();
  for (let i = 0; i < 6; i += 1) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    out.push({
      value: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`,
      label: d.toLocaleDateString('id-ID', { month: 'long', year: 'numeric' }),
    });
  }
  return out;
});

const minimumPayout = computed<number>(() => settings.value?.minimum_payout ?? 0);

async function loadEligible(forMonth: string) {
  const summary = await PayoutsService.getSelfSummary({ month: forMonth });
  eligibleAmount.value = summary.net_amount ?? 0;
  if (amount.value <= 0) {
    amount.value = Math.floor(eligibleAmount.value);
  }
}

onMounted(async () => {
  loading.value = true;
  try {
    // Settings is a separate try/catch: `tutoring.payout.settings.view`
    // is in the tutor role defaults, but a tenant with a hand-edited
    // role could 403 here and that must not block the whole form —
    // the backend re-checks `minimum_payout` on submit regardless.
    try {
      settings.value = await PayoutsService.getSettings();
    } catch {
      settings.value = null;
    }
    await loadEligible(month.value);
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
});

// Re-fetch the eligible amount when the tutor picks another month.
watch(month, async (next) => {
  try {
    const summary = await PayoutsService.getSelfSummary({ month: next });
    eligibleAmount.value = summary.net_amount ?? 0;
  } catch {
    // Keep the previous figure — it is only a hint; the server is
    // authoritative on submit.
  }
});

function setAmount(value: number) {
  amount.value = Math.max(0, Math.floor(value));
}

function applyQuick(kind: 'all' | 'half') {
  const eligible = eligibleAmount.value ?? 0;
  setAmount(kind === 'all' ? eligible : eligible / 2);
}

const eligibleLabel = computed(() =>
  eligibleAmount.value == null ? '—' : formatRupiah(eligibleAmount.value),
);

const submitDisabled = computed(
  () => submitting.value || loading.value || amount.value <= 0,
);

async function submit() {
  if (submitting.value) return;
  errorMessage.value = null;

  // `amount` is `integer|min:1` server-side — mirror it here so the
  // tutor gets an inline message instead of a raw 422.
  const value = Math.floor(amount.value);
  if (!Number.isFinite(value) || value <= 0) {
    errorMessage.value = t('tutoring2.tutor.withdrawal.errAmountZero');
    return;
  }
  if (minimumPayout.value > 0 && value < minimumPayout.value) {
    errorMessage.value = t('tutoring2.tutor.withdrawal.errBelowMin', {
      amount: formatRupiah(minimumPayout.value),
    });
    return;
  }

  submitting.value = true;
  try {
    await PayoutsService.createRequest({
      period_month: month.value,
      amount: value,
      note: note.value.trim() || undefined,
    });
    toast.success(t('tutoring2.tutor.withdrawal.submitOk'));
    emit('submitted');
    emit('close');
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    submitting.value = false;
  }
}

const fieldLabelCls = 'text-xs font-bold text-slate-600 uppercase tracking-wider';
const inputCls =
  'w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20';
</script>

<template>
  <Modal
    :title="t('tutoring2.tutor.withdrawal.title')"
    :subtitle="t('tutoring2.tutor.withdrawal.subtitle')"
    size="lg"
    testid="tutoring2-withdrawal-dialog"
    @close="emit('close')"
  >
    <p v-if="loading" class="py-8 text-center text-sm text-slate-500">
      {{ t('tutoring2.common.loading') }}
    </p>

    <div v-else class="space-y-4">
      <!-- Period + eligible amount -->
      <div class="rounded-2xl border border-slate-100 bg-white p-4 space-y-3">
        <div class="space-y-1.5">
          <label for="withdrawal-month" :class="fieldLabelCls">
            {{ t('tutoring2.tutor.withdrawal.fieldMonth') }}
          </label>
          <select id="withdrawal-month" v-model="month" :class="inputCls">
            <option v-for="o in monthOptions" :key="o.value" :value="o.value">
              {{ o.label }}
            </option>
          </select>
        </div>

        <div class="flex items-baseline justify-between border-t border-slate-100 pt-2">
          <p class="text-2xs font-bold uppercase tracking-widest text-slate-500">
            {{ t('tutoring2.tutor.withdrawal.eligibleLabel') }}
          </p>
          <p class="text-sm font-bold text-slate-900 tabular-nums">{{ eligibleLabel }}</p>
        </div>
      </div>

      <!-- Amount -->
      <div class="rounded-2xl border border-slate-100 bg-white p-4 space-y-2">
        <div class="space-y-1.5">
          <label for="withdrawal-amount" :class="fieldLabelCls">
            {{ t('tutoring2.common.amount') }}
          </label>
          <input
            id="withdrawal-amount"
            v-model.number="amount"
            type="number"
            min="1"
            step="1"
            :class="inputCls"
          />
        </div>

        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            class="rounded-full bg-brand-cobalt/10 px-3 py-1 text-2xs font-bold text-brand-cobalt hover:bg-brand-cobalt/20 disabled:opacity-40"
            :disabled="(eligibleAmount ?? 0) <= 0"
            @click="applyQuick('all')"
          >
            {{ t('tutoring2.tutor.withdrawal.chipAll') }}
          </button>
          <button
            type="button"
            class="rounded-full bg-brand-cobalt/10 px-3 py-1 text-2xs font-bold text-brand-cobalt hover:bg-brand-cobalt/20 disabled:opacity-40"
            :disabled="(eligibleAmount ?? 0) <= 0"
            @click="applyQuick('half')"
          >
            {{ t('tutoring2.tutor.withdrawal.chipHalf') }}
          </button>
        </div>

        <p class="text-2xs text-slate-500">
          <template v-if="minimumPayout > 0">
            {{
              t('tutoring2.tutor.withdrawal.hintMin', {
                amount: formatRupiah(minimumPayout),
              })
            }}
          </template>
          <template v-else>
            {{ t('tutoring2.tutor.withdrawal.hintAmount') }}
          </template>
        </p>
      </div>

      <!-- Notes. Also the only place a transfer destination can be
           stated, because v2 has no payment-account route (see the
           file header). -->
      <div class="space-y-1.5">
        <label for="withdrawal-note" :class="fieldLabelCls">
          {{ t('tutoring2.common.notes') }}
        </label>
        <textarea
          id="withdrawal-note"
          v-model="note"
          rows="3"
          maxlength="2000"
          :placeholder="t('tutoring2.tutor.withdrawal.notePlaceholder')"
          :class="inputCls"
        />
        <p class="text-2xs text-slate-500">
          {{ t('tutoring2.tutor.withdrawal.noBankAccountHint') }}
        </p>
      </div>

      <p v-if="errorMessage" class="text-xs text-rose-600">{{ errorMessage }}</p>

      <div class="flex items-center justify-end gap-2 border-t border-slate-100 pt-3">
        <Button variant="secondary" size="md" type="button" @click="emit('close')">
          {{ t('tutoring2.common.cancel') }}
        </Button>
        <Button
          variant="primary"
          size="md"
          type="button"
          :disabled="submitDisabled"
          :loading="submitting"
          @click="submit"
        >
          {{ t('tutoring2.tutor.withdrawal.submit') }}
        </Button>
      </div>
    </div>
  </Modal>
</template>
