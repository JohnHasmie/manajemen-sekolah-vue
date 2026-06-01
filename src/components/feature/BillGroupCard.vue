<!--
  BillGroupCard.vue — admin Tagihan bucket card.

  One row per (payment_type × class × academic_year) bucket. Shows
  total / paid / unpaid / overdue counts with a completion progress
  bar. Click drills into the per-student detail view.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { BillGroup } from '@/types/billing';
import { formatRupiah } from '@/lib/format';

const props = defineProps<{ group: BillGroup }>();
defineEmits<{ click: [BillGroup] }>();

const title = computed(() => {
  const base = props.group.payment_type_name?.trim() || 'Tagihan';
  const cls = props.group.class_name?.trim() ?? '';
  const year = (props.group.year_label ?? '').trim();
  const head = cls ? `${base} · ${cls}` : base;
  return year ? `${head} (${year})` : head;
});

const pct = computed(() => Math.max(0, Math.min(100, props.group.completion_pct ?? 0)));
const outstanding = computed(() => props.group.outstanding_amount ?? Math.max(0, props.group.total_amount - props.group.paid_amount));

const barColor = computed(() => {
  if (props.group.overdue_count > 0) return 'bg-red-500';
  if (pct.value >= 90) return 'bg-emerald-500';
  if (pct.value >= 50) return 'bg-amber-500';
  return 'bg-slate-300';
});
</script>

<template>
  <button
    type="button"
    class="w-full text-left bg-white border border-slate-200 hover:border-role-admin/40 hover:shadow-md rounded-2xl p-4 transition-all space-y-3"
    @click="$emit('click', group)"
  >
    <header class="flex items-start gap-3">
      <div class="w-10 h-10 rounded-xl bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0">
        <NavIcon name="credit-card" :size="18" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-[13px] font-bold text-slate-900 truncate">{{ title }}</p>
        <p class="text-[11px] text-slate-500 mt-0.5">
          {{ group.total_count }} tagihan ·
          <span class="font-bold text-slate-700">{{ formatRupiah(group.total_amount) }}</span>
        </p>
      </div>
      <NavIcon name="chevron-right" :size="14" class="text-slate-300 mt-2" />
    </header>

    <div class="grid grid-cols-3 gap-2 text-center text-[11px]">
      <div class="bg-emerald-50 rounded-lg py-1.5">
        <p class="text-emerald-700 font-bold">{{ group.paid_count }}</p>
        <p class="text-emerald-700/80 text-[9px] uppercase tracking-widest">Lunas</p>
      </div>
      <div class="bg-amber-50 rounded-lg py-1.5">
        <p class="text-amber-700 font-bold">{{ group.unpaid_count }}</p>
        <p class="text-amber-700/80 text-[9px] uppercase tracking-widest">Berjalan</p>
      </div>
      <div class="bg-red-50 rounded-lg py-1.5">
        <p class="text-red-700 font-bold">{{ group.overdue_count }}</p>
        <p class="text-red-700/80 text-[9px] uppercase tracking-widest">Telat</p>
      </div>
    </div>

    <div>
      <div class="flex items-center justify-between text-[10px] mb-1">
        <span class="font-bold text-slate-500 uppercase tracking-widest">
          {{ pct.toFixed(1) }}% terbayar
        </span>
        <span class="font-bold text-amber-700">
          Sisa {{ formatRupiah(outstanding) }}
        </span>
      </div>
      <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
        <div class="h-full transition-all" :class="barColor" :style="{ width: `${pct}%` }"></div>
      </div>
    </div>
  </button>
</template>
