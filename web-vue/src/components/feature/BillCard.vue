<!--
  BillCard.vue — single tagihan row card used by parent + admin lists.

  Layout:
    [icon-square] [title / subtitle / due-label]  [amount / status pill]

  Variants via tone (auto-derived from status). Click whole row.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  BILL_STATUS_TONES,
  type Bill,
  type BillStatus,
} from '@/types/billing';
import { formatRupiah, formatDateLong } from '@/lib/format';

const props = defineProps<{
  bill: Bill;
  /** Show student name in subtitle (parent multi-child view). */
  showStudentName?: boolean;
  /** Hide click affordance. */
  readonly?: boolean;
}>();

defineEmits<{ click: [Bill] }>();

const { t } = useI18n();

// Localised status badge labels — the static BILL_STATUS_LABELS export
// stays Indonesian for any data-layer code that switches on it.
const LOCALIZED_BILL_LABELS = computed<Record<BillStatus, string>>(() => ({
  paid: t('parent.billing.statusLunas'),
  overdue: t('parent.billing.statusTelat'),
  soon: t('parent.billing.statusSegera'),
  pending: t('parent.billing.statusBelumLunas'),
}));

const status = computed(() => props.bill.status);
const labels = computed(() => LOCALIZED_BILL_LABELS.value[status.value]);
const tones = computed(() => BILL_STATUS_TONES[status.value]);

const iconBg = computed(() => {
  switch (status.value) {
    case 'paid':
      return 'bg-emerald-100 text-emerald-700';
    case 'overdue':
      return 'bg-red-100 text-red-700';
    case 'soon':
      return 'bg-amber-100 text-amber-700';
    default:
      return 'bg-slate-100 text-slate-600';
  }
});

const iconName = computed(() => {
  switch (status.value) {
    case 'paid':
      return 'check-circle';
    case 'overdue':
      return 'alert-triangle';
    case 'soon':
      return 'clock';
    default:
      return 'credit-card';
  }
});

const dueLabel = computed(() => {
  const b = props.bill;
  if (b.status === 'paid' && b.latest_payment?.payment_date) {
    return t('parent.billing.paidOn', { date: formatDateLong(b.latest_payment.payment_date) });
  }
  if (typeof b.due_in_days === 'number') {
    if (b.due_in_days < 0) return t('parent.billing.lateBy', { days: Math.abs(b.due_in_days) });
    if (b.due_in_days === 0) return t('parent.billing.dueToday');
    if (b.due_in_days === 1) return t('parent.billing.dueTomorrow');
    return t('parent.billing.dueIn', { days: b.due_in_days });
  }
  return b.due_date
    ? t('parent.billing.dueOn', { date: formatDateLong(b.due_date) })
    : t('parent.billing.noDueDate');
});

// Pattern-translate the backend-supplied subtitle ("Tahunan · 7A",
// "Bulanan · 7A · …") so the period prefix flips to English when the
// locale is English. Backend ships the raw Indonesian word; we
// rewrite the first token via this small dictionary.
const PERIOD_PREFIX_MAP: Record<string, string> = {
  Bulanan: 'parent.billing.periodMonthly',
  Tahunan: 'parent.billing.periodYearly',
  Sekali: 'parent.billing.periodOnce',
};

function translatePeriodPrefix(s: string): string {
  // Subtitle shape: "{PeriodWord} · rest…". Split on the first " · "
  // so the rest of the backend-supplied tokens (class name etc.) pass
  // through untouched.
  const idx = s.indexOf(' · ');
  const head = idx >= 0 ? s.slice(0, idx) : s;
  const tail = idx >= 0 ? s.slice(idx) : '';
  const key = PERIOD_PREFIX_MAP[head];
  return key ? `${t(key)}${tail}` : s;
}

const subtitle = computed(() => {
  const parts: string[] = [];
  if (props.showStudentName && props.bill.student?.name) {
    parts.push(props.bill.student.name);
  } else if (props.bill.subtitle) {
    parts.push(translatePeriodPrefix(props.bill.subtitle));
  }
  parts.push(dueLabel.value);
  return parts.join(' · ');
});
</script>

<template>
  <component
    :is="readonly ? 'div' : 'button'"
    :type="readonly ? undefined : 'button'"
    class="w-full text-left px-3 py-3 flex items-center gap-3 rounded-2xl transition-all border border-transparent"
    :class="readonly ? '' : 'hover:bg-slate-50 hover:border-slate-200'"
    @click="readonly ? undefined : $emit('click', bill)"
  >
    <div
      class="w-11 h-11 rounded-2xl grid place-items-center flex-shrink-0"
      :class="iconBg"
    >
      <NavIcon :name="iconName" :size="18" />
    </div>
    <div class="flex-1 min-w-0">
      <p class="text-[13px] font-bold text-slate-900 truncate">{{ bill.title }}</p>
      <p class="text-[11px] text-slate-500 truncate mt-0.5">{{ subtitle }}</p>
    </div>
    <div class="text-right flex-shrink-0">
      <p
        class="text-[13px] font-bold tabular-nums"
        :class="status === 'paid' ? 'text-emerald-700' : 'text-slate-900'"
      >
        {{ formatRupiah(bill.amount) }}
      </p>
      <span
        class="inline-block text-[9px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full mt-1"
        :class="`${tones.bg} ${tones.text}`"
      >{{ labels }}</span>
      <p
        v-if="bill.reminder_count > 0 && status !== 'paid'"
        class="text-[9px] text-amber-700 font-bold mt-1 uppercase tracking-wider"
      >
        {{ t('parent.billing.reminderNth', { n: bill.reminder_count }) }}
      </p>
    </div>
  </component>
</template>
