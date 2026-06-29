<!--
  TutorWithdrawalDialog — modal dialog the tutor uses to file an honor
  withdrawal request. Mirrors the mobile bottom-sheet shipped under
  feat/tutor-payout-withdrawal-mobile, but renders as a desktop modal
  via the shared `ui/Modal.vue` primitive.

  Two period modes:
    - "month"  → picks one calendar month (default = current). The
                 computed amount preview tracks the picked month.
    - "range"  → arbitrary from/to date pickers. The eligible amount
                 has to be computed server-side (no client mirror of
                 ComputeTutorPayoutAction's logic), so the preview is a
                 best-effort hint only — the server is authoritative.

  Amount input:
    - Locked to the computed amount when allow_partial = false.
    - Editable + quick chips ("Semua / ½ / Rp 1jt") when
      allow_partial = true.
    - Min amount comes from settings.min_withdrawal_amount.

  Bank account: shows the tutor's default bank details (from the
  TutorPayoutRate, served on the payout-summary response) as a
  read-only summary. An "Ubah" toggle reveals a 3-input override form
  for one-off transfers. Leaving the override blank keeps the default;
  the backend uses the persisted rate's bank details (set on
  AdminTutoringPayoutsView). When no default exists yet the read-only
  block becomes a "Belum diatur" empty state and the user must fill
  the override form to proceed.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutorPayoutSettings, TutorPayoutSummary } from '@/types/tutoring';

import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Default eligible amount for the period the parent view is showing
   *  — usually the tutor's current month earnings. Used to seed the
   *  "Per bulan" preview without an extra summary fetch. */
  initialEligible?: number;
  /** YYYY-MM string for the month the parent view is showing. */
  initialMonth?: string;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  /** Fires after a successful POST; parent reloads its lists. */
  (e: 'submitted'): void;
}>();

const { t } = useI18n();
const toast = useToast();

// ── Settings + summary (loaded on mount) ─────────────────────────
const loading = ref(true);
const submitting = ref(false);
const settings = ref<TutorPayoutSettings | null>(null);
const monthSummary = ref<TutorPayoutSummary | null>(null);

// ── Form state ────────────────────────────────────────────────────
type TabKey = 'month' | 'range';
const tab = ref<TabKey>('month');

// Month tab — defaults to `initialMonth` or current calendar month.
const month = ref<string>(props.initialMonth ?? currentMonthIso());
// Range tab — defaults to last 30 days ending today.
const rangeFrom = ref<string>(daysAgoIso(30));
const rangeTo = ref<string>(todayIso());

const amount = ref<number>(props.initialEligible ?? 0);
// Default bank details from the tutor's TutorPayoutRate, surfaced by
// the payout-summary response. Null when the admin hasn't filled
// them yet — in that case the read-only block becomes an empty
// state and the override form is the only way forward.
const defaultBankName = ref<string | null>(null);
const defaultBankAccountNumber = ref<string | null>(null);
const defaultBankAccountHolder = ref<string | null>(null);
const bankExpanded = ref(false);
const bankName = ref('');
const bankAccountNumber = ref('');
const bankAccountHolder = ref('');
const notes = ref('');
const errMsg = ref<string | null>(null);

// True when no default bank details exist yet. Drives the "Belum
// diatur" empty state and auto-opens the override form so the tutor
// can't accidentally submit without a destination.
const hasDefaultBank = computed(
  () =>
    !!(defaultBankName.value && defaultBankName.value.trim().length > 0),
);

function currentMonthIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}
function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function daysAgoIso(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** YYYY-MM → { from: YYYY-MM-01, to: YYYY-MM-(lastDay) }. */
function monthBounds(yyyyMm: string): { from: string; to: string } {
  const [y, m] = yyyyMm.split('-').map(Number);
  const last = new Date(y, m, 0).getDate();
  const mm = String(m).padStart(2, '0');
  return {
    from: `${y}-${mm}-01`,
    to: `${y}-${mm}-${String(last).padStart(2, '0')}`,
  };
}

// Eligible amount the UI shows as the "computed" hint:
//   - month tab → monthSummary.earnings (server truth for that month).
//   - range tab → null (no client compute; server decides on submit).
const eligibleAmount = computed<number | null>(() => {
  if (tab.value === 'month') return monthSummary.value?.earnings ?? null;
  return null;
});

const allowPartial = computed<boolean>(
  () => settings.value?.allow_partial_withdrawal ?? false,
);
const minAmount = computed<number>(
  () => settings.value?.min_withdrawal_amount ?? 0,
);

// Last 6 months for the month picker.
const monthOptions = computed(() => {
  const out: { value: string; label: string }[] = [];
  const now = new Date();
  for (let i = 0; i < 6; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    out.push({
      value,
      label: d.toLocaleString('id-ID', { month: 'long', year: 'numeric' }),
    });
  }
  return out;
});

async function loadInit() {
  loading.value = true;
  try {
    // Both endpoints are open to any tenant member (backend !223
    // dropped the admin-only restriction on /payouts/settings), so a
    // plain Promise.all is enough — no per-call fallback needed.
    const [settingsResp, summaryResp] = await Promise.all([
      TutoringService.getPayoutSettings(),
      TutoringService.getPayoutSummary({ month: month.value }),
    ]);
    settings.value = settingsResp;
    monthSummary.value = summaryResp;
    // Seed amount to the eligible for that month — tutor can adjust
    // later if partial is allowed.
    if (amount.value <= 0 || !Number.isFinite(amount.value)) {
      amount.value = Math.floor(summaryResp.earnings ?? 0);
    }
    // Prefill default bank details from the summary response (added
    // with backend !223). Any of these may be null when the admin
    // hasn't filled the tutor's rate bank fields — we render the
    // "Belum diatur" empty state in that case.
    defaultBankName.value = summaryResp.bank_name ?? null;
    defaultBankAccountNumber.value = summaryResp.bank_account_number ?? null;
    defaultBankAccountHolder.value = summaryResp.bank_account_holder ?? null;
    // When there's no default on file, auto-open the override form so
    // the tutor can't submit a request that has no destination.
    if (!hasDefaultBank.value) {
      bankExpanded.value = true;
    }
  } catch {
    /* non-fatal — fall through with safe defaults */
  } finally {
    loading.value = false;
  }
}

onMounted(loadInit);

// Re-fetch summary when the month changes.
watch(month, async (next) => {
  if (tab.value !== 'month') return;
  try {
    monthSummary.value = await TutoringService.getPayoutSummary({ month: next });
    if (!allowPartial.value) {
      amount.value = Math.floor(monthSummary.value?.earnings ?? 0);
    }
  } catch {
    /* keep last summary */
  }
});

// When partial isn't allowed, lock amount to the eligible amount.
watch([eligibleAmount, allowPartial], ([eligible, partial]) => {
  if (!partial && eligible != null) {
    amount.value = Math.floor(eligible);
  }
});

function setAmount(v: number) {
  amount.value = Math.max(0, Math.floor(v));
}

function applyQuick(kind: 'all' | 'half' | '1m') {
  if (!allowPartial.value) return;
  if (kind === 'all') {
    setAmount(eligibleAmount.value ?? 0);
  } else if (kind === 'half') {
    setAmount(Math.floor((eligibleAmount.value ?? 0) / 2));
  } else if (kind === '1m') {
    setAmount(1_000_000);
  }
}

async function submit() {
  errMsg.value = null;

  // Resolve the period from the active tab.
  let periodFrom: string;
  let periodTo: string;
  if (tab.value === 'month') {
    const b = monthBounds(month.value);
    periodFrom = b.from;
    periodTo = b.to;
  } else {
    if (!rangeFrom.value || !rangeTo.value) {
      errMsg.value = t('tutor.bimbel.withdrawal.err_range_required');
      return;
    }
    if (rangeFrom.value > rangeTo.value) {
      errMsg.value = t('tutor.bimbel.withdrawal.err_range_inverted');
      return;
    }
    periodFrom = rangeFrom.value;
    periodTo = rangeTo.value;
  }

  if (amount.value <= 0) {
    errMsg.value = t('tutor.bimbel.withdrawal.err_amount_zero');
    return;
  }
  if (minAmount.value > 0 && amount.value < minAmount.value) {
    errMsg.value = t('tutor.bimbel.withdrawal.err_below_min', {
      amount: formatRupiah(minAmount.value),
    });
    return;
  }

  submitting.value = true;
  try {
    await TutoringService.createPayoutRequest({
      period_from: periodFrom,
      period_to: periodTo,
      amount_requested: amount.value,
      bank_name: bankExpanded.value && bankName.value.trim() ? bankName.value.trim() : null,
      bank_account_number:
        bankExpanded.value && bankAccountNumber.value.trim()
          ? bankAccountNumber.value.trim()
          : null,
      bank_account_holder:
        bankExpanded.value && bankAccountHolder.value.trim()
          ? bankAccountHolder.value.trim()
          : null,
      notes: notes.value.trim() || null,
    });
    toast.success(t('tutor.bimbel.withdrawal.submit_ok'));
    emit('submitted');
  } catch (e) {
    errMsg.value = e instanceof Error ? e.message : String(e);
  } finally {
    submitting.value = false;
  }
}

const eligibleLabel = computed(() => {
  if (tab.value === 'range') return t('tutor.bimbel.withdrawal.eligible_range_unknown');
  if (eligibleAmount.value == null) return '—';
  return formatRupiah(eligibleAmount.value);
});

const submitDisabled = computed(() => submitting.value || loading.value || amount.value <= 0);
</script>

<template>
  <Modal
    :title="t('tutor.bimbel.withdrawal.title')"
    :subtitle="t('tutor.bimbel.withdrawal.subtitle')"
    size="lg"
    @close="emit('close')"
  >
    <div v-if="loading" class="py-8 text-center text-tutoring-text-mid text-sm">
      {{ t('tutoring.common.loading') }}
    </div>

    <div v-else class="space-y-4">
      <!-- Tab toggle: Per bulan / Custom range -->
      <div class="inline-flex rounded-xl bg-tutoring-border-soft p-1 text-[13px] font-bold">
        <button
          type="button"
          class="px-3 py-1.5 rounded-lg transition"
          :class="
            tab === 'month'
              ? 'bg-tutoring-panel text-tutoring-text-hi shadow-sm'
              : 'text-tutoring-text-mid hover:text-tutoring-text-hi'
          "
          @click="tab = 'month'"
        >
          {{ t('tutor.bimbel.withdrawal.tab_month') }}
        </button>
        <button
          type="button"
          class="px-3 py-1.5 rounded-lg transition"
          :class="
            tab === 'range'
              ? 'bg-tutoring-panel text-tutoring-text-hi shadow-sm'
              : 'text-tutoring-text-mid hover:text-tutoring-text-hi'
          "
          @click="tab = 'range'"
        >
          {{ t('tutor.bimbel.withdrawal.tab_range') }}
        </button>
      </div>

      <!-- Period picker -->
      <div
        class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 space-y-3"
      >
        <div v-if="tab === 'month'">
          <label class="block">
            <span
              class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider"
            >
              {{ t('tutor.bimbel.withdrawal.field_month') }}
            </span>
            <select
              v-model="month"
              class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            >
              <option v-for="o in monthOptions" :key="o.value" :value="o.value">
                {{ o.label }}
              </option>
            </select>
          </label>
        </div>
        <div v-else class="grid grid-cols-2 gap-3">
          <label class="block">
            <span
              class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider"
            >
              {{ t('tutor.bimbel.withdrawal.field_from') }}
            </span>
            <input
              v-model="rangeFrom"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            />
          </label>
          <label class="block">
            <span
              class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider"
            >
              {{ t('tutor.bimbel.withdrawal.field_to') }}
            </span>
            <input
              v-model="rangeTo"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            />
          </label>
        </div>

        <div class="flex justify-between items-baseline pt-1 border-t border-tutoring-border-soft">
          <p class="text-[11px] font-bold uppercase tracking-widest text-tutoring-text-mid">
            {{ t('tutor.bimbel.withdrawal.eligible_label') }}
          </p>
          <p class="text-[15px] font-bold text-tutoring-text-hi">{{ eligibleLabel }}</p>
        </div>
      </div>

      <!-- Amount input -->
      <div
        class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 space-y-2"
      >
        <label class="block">
          <span
            class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider"
          >
            {{ t('tutor.bimbel.withdrawal.field_amount') }}
          </span>
          <input
            v-model.number="amount"
            type="number"
            min="0"
            :disabled="!allowPartial"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher disabled:bg-tutoring-bg disabled:text-tutoring-text-mid"
          />
        </label>

        <!-- Quick chips (only when partial allowed) -->
        <div v-if="allowPartial" class="flex gap-2 flex-wrap">
          <button
            type="button"
            class="rounded-full bg-tutoring-accent/10 text-tutoring-accent text-[12px] font-bold px-3 py-1 hover:bg-tutoring-accent/20"
            :disabled="(eligibleAmount ?? 0) <= 0"
            @click="applyQuick('all')"
          >
            {{ t('tutor.bimbel.withdrawal.chip_all') }}
          </button>
          <button
            type="button"
            class="rounded-full bg-tutoring-accent/10 text-tutoring-accent text-[12px] font-bold px-3 py-1 hover:bg-tutoring-accent/20"
            :disabled="(eligibleAmount ?? 0) <= 0"
            @click="applyQuick('half')"
          >
            {{ t('tutor.bimbel.withdrawal.chip_half') }}
          </button>
          <button
            type="button"
            class="rounded-full bg-tutoring-accent/10 text-tutoring-accent text-[12px] font-bold px-3 py-1 hover:bg-tutoring-accent/20"
            @click="applyQuick('1m')"
          >
            {{ t('tutor.bimbel.withdrawal.chip_1m') }}
          </button>
        </div>

        <!-- Hint -->
        <p class="text-[11.5px] text-tutoring-text-mid">
          <template v-if="allowPartial">
            {{ t('tutor.bimbel.withdrawal.hint_partial') }}
            <span v-if="minAmount > 0">
              · {{ t('tutor.bimbel.withdrawal.hint_min', { amount: formatRupiah(minAmount) }) }}
            </span>
          </template>
          <template v-else>
            {{ t('tutor.bimbel.withdrawal.hint_no_partial') }}
          </template>
        </p>
      </div>

      <!-- Bank account (default summary + collapsible override) -->
      <div
        class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 space-y-2"
      >
        <button
          type="button"
          class="flex w-full items-center justify-between text-left"
          @click="bankExpanded = !bankExpanded"
        >
          <span class="text-sm font-semibold text-tutoring-text-hi">
            {{ t('tutor.bimbel.withdrawal.bank_section') }}
          </span>
          <span class="text-[12px] font-bold text-tutoring-accent flex items-center gap-0.5">
            {{ bankExpanded ? t('tutor.bimbel.withdrawal.bank_collapse') : t('tutor.bimbel.withdrawal.bank_change') }}
            <NavIcon :name="bankExpanded ? 'chevron-up' : 'chevron-down'" :size="14" />
          </span>
        </button>

        <!--
          Default summary — shows the persisted TutorPayoutRate bank
          details (served on the payout-summary response). Renders as
          a read-only block so the tutor knows where the money will
          land if they leave the override empty. Falls back to a
          "Belum diatur" empty state when no default is on file; in
          that case the override form is auto-opened on mount.
        -->
        <div
          v-if="hasDefaultBank"
          class="rounded-lg border border-tutoring-border-soft bg-tutoring-bg/60 p-3 space-y-1"
        >
          <p class="text-[10.5px] font-bold uppercase tracking-widest text-tutoring-text-mid">
            {{ t('tutor.bimbel.withdrawal.bank_default_label') }}
          </p>
          <p class="text-sm font-semibold text-tutoring-text-hi">
            {{ defaultBankName }}
            <span v-if="defaultBankAccountNumber" class="font-mono font-normal text-tutoring-text-mid">
              · {{ defaultBankAccountNumber }}
            </span>
          </p>
          <p v-if="defaultBankAccountHolder" class="text-[12px] text-tutoring-text-mid">
            {{ t('tutor.bimbel.withdrawal.bank_holder_prefix') }} {{ defaultBankAccountHolder }}
          </p>
        </div>
        <div
          v-else
          class="rounded-lg border border-dashed border-tutoring-border-soft bg-tutoring-bg/60 p-3"
        >
          <p class="text-[10.5px] font-bold uppercase tracking-widest text-tutoring-text-mid">
            {{ t('tutor.bimbel.withdrawal.bank_default_label') }}
          </p>
          <p class="text-[12.5px] text-tutoring-text-mid mt-1">
            {{ t('tutor.bimbel.withdrawal.bank_default_empty') }}
          </p>
        </div>

        <p class="text-[11.5px] text-tutoring-text-mid">
          {{
            hasDefaultBank
              ? t('tutor.bimbel.withdrawal.bank_hint')
              : t('tutor.bimbel.withdrawal.bank_hint_no_default')
          }}
        </p>
        <div v-if="bankExpanded" class="space-y-2 pt-1">
          <div class="grid grid-cols-2 gap-2">
            <input
              v-model="bankName"
              type="text"
              maxlength="80"
              :placeholder="t('tutor.bimbel.withdrawal.bank_name_ph')"
              class="rounded-lg border border-tutoring-border px-3 py-2 text-sm"
            />
            <input
              v-model="bankAccountNumber"
              type="text"
              maxlength="40"
              :placeholder="t('tutor.bimbel.withdrawal.bank_number_ph')"
              class="rounded-lg border border-tutoring-border px-3 py-2 text-sm font-mono"
            />
          </div>
          <input
            v-model="bankAccountHolder"
            type="text"
            maxlength="120"
            :placeholder="t('tutor.bimbel.withdrawal.bank_holder_ph')"
            class="w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm"
          />
        </div>
      </div>

      <!-- Notes -->
      <label class="block">
        <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
          {{ t('tutor.bimbel.withdrawal.field_notes') }}
        </span>
        <textarea
          v-model="notes"
          rows="3"
          maxlength="1000"
          :placeholder="t('tutor.bimbel.withdrawal.notes_ph')"
          class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher resize-none"
        />
      </label>

      <p v-if="errMsg" class="text-xs text-tutoring-red">{{ errMsg }}</p>

      <div class="flex items-center gap-2 justify-end pt-1">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
          @click="emit('close')"
        >
          {{ t('tutoring.common.close') }}
        </button>
        <button
          type="button"
          :disabled="submitDisabled"
          class="rounded-lg bg-tutoring-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submit"
        >
          {{ submitting ? t('tutor.bimbel.withdrawal.submitting') : t('tutor.bimbel.withdrawal.submit') }}
        </button>
      </div>
    </div>
  </Modal>
</template>
