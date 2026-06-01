<!--
  BillCard.vue — single tagihan row card used by parent + admin lists.

  Layout:
    [icon-square] [title / subtitle / due-label]  [amount / status pill]

  Variants via tone (auto-derived from status). Click whole row.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import {
  BILL_STATUS_LABELS,
  BILL_STATUS_TONES,
  type Bill,
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

const status = computed(() => props.bill.status);
const labels = computed(() => BILL_STATUS_LABELS[status.value]);
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
    return `Lunas · ${formatDateLong(b.latest_payment.payment_date)}`;
  }
  if (typeof b.due_in_days === 'number') {
    if (b.due_in_days < 0) return `Telat ${Math.abs(b.due_in_days)} hari`;
    if (b.due_in_days === 0) return 'Jatuh tempo hari ini';
    if (b.due_in_days === 1) return 'Jatuh tempo besok';
    return `Jatuh tempo ${b.due_in_days} hari lagi`;
  }
  return b.due_date ? `Jatuh tempo ${formatDateLong(b.due_date)}` : 'Tanpa jatuh tempo';
});

const subtitle = computed(() => {
  const parts: string[] = [];
  if (props.showStudentName && props.bill.student?.name) {
    parts.push(props.bill.student.name);
  } else if (props.bill.subtitle) {
    parts.push(props.bill.subtitle);
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
        Reminder ke-{{ bill.reminder_count }}
      </p>
    </div>
  </component>
</template>
