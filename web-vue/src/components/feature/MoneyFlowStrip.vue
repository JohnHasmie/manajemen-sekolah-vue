<!--
  MoneyFlowStrip.vue — admin Keuangan hub hero (Mockup #13).

  Three tiles + a FlowBar:
    1. Pendapatan (this month) — emerald gradient, delta-vs-last-month
    2. Belum lunas             — amber, count + nominal
    3. Lewat jatuh tempo       — red, count + wali count

  Below the tiles, a horizontal FlowBar shows paid/outstanding/overdue
  percent split, mirroring Flutter's `MoneyFlowStrip + FlowBar`.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { MoneyFlowSummary } from '@/types/billing';
import { formatRupiah } from '@/lib/format';

const props = defineProps<{ summary: MoneyFlowSummary }>();

const deltaTone = computed(() => {
  const d = props.summary.income.delta_pct_vs_last_month;
  if (d === null || d === undefined) return 'text-white/70';
  if (d >= 0) return 'text-emerald-100';
  return 'text-red-100';
});

const deltaLabel = computed(() => {
  const d = props.summary.income.delta_pct_vs_last_month;
  if (d === null || d === undefined) return 'Tanpa pembanding';
  if (d === 0) return 'Stagnan vs bulan lalu';
  const arrow = d >= 0 ? '↑' : '↓';
  return `${arrow} ${Math.abs(d).toFixed(1)}% vs bulan lalu`;
});

const flow = computed(() => props.summary.flow_bar);
</script>

<template>
  <section class="space-y-3">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <!-- Pendapatan -->
      <div
        class="rounded-2xl p-4 text-white relative overflow-hidden shadow-lg shadow-emerald-500/15"
        style="background: linear-gradient(135deg, #047857 0%, #10B981 100%);"
      >
        <div class="absolute -top-8 -right-8 w-28 h-28 bg-white/15 rounded-full blur-2xl"></div>
        <div class="relative z-10 flex items-start gap-3">
          <div class="w-9 h-9 rounded-xl bg-white/20 grid place-items-center">
            <NavIcon name="trending-up" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold tracking-widest uppercase text-white/70">
              Pendapatan bulan ini
            </p>
            <p class="text-xl font-black tracking-tight mt-0.5">
              {{ formatRupiah(summary.income.amount) }}
            </p>
            <p class="text-[10px] mt-1" :class="deltaTone">
              {{ summary.income.transaction_count }} transaksi · {{ deltaLabel }}
            </p>
          </div>
        </div>
      </div>

      <!-- Belum lunas -->
      <div class="rounded-2xl p-4 bg-amber-50 border border-amber-200">
        <div class="flex items-start gap-3">
          <div class="w-9 h-9 rounded-xl bg-amber-200 text-amber-800 grid place-items-center">
            <NavIcon name="credit-card" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold tracking-widest uppercase text-amber-700/80">
              Belum lunas
            </p>
            <p class="text-xl font-black tracking-tight text-amber-900 mt-0.5">
              {{ formatRupiah(summary.outstanding.amount) }}
            </p>
            <p class="text-[10px] text-amber-700 mt-1">
              {{ summary.outstanding.count }} tagihan menunggu
            </p>
          </div>
        </div>
      </div>

      <!-- Overdue -->
      <div class="rounded-2xl p-4 bg-red-50 border border-red-200">
        <div class="flex items-start gap-3">
          <div class="w-9 h-9 rounded-xl bg-red-200 text-red-800 grid place-items-center">
            <NavIcon name="alert-triangle" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold tracking-widest uppercase text-red-700/80">
              Lewat jatuh tempo
            </p>
            <p class="text-xl font-black tracking-tight text-red-900 mt-0.5">
              {{ formatRupiah(summary.overdue.amount) }}
            </p>
            <p class="text-[10px] text-red-700 mt-1">
              {{ summary.overdue.count }} tagihan · {{ summary.overdue.guardians_count }} wali murid
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- FlowBar -->
    <div class="bg-white border border-slate-200 rounded-2xl p-4">
      <div class="flex items-center justify-between mb-2">
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
          Komposisi tagihan {{ summary.period.month }}
        </p>
        <div class="flex items-center gap-3 text-[10px] font-bold">
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
            <span class="text-slate-600">Lunas {{ flow.paid_pct.toFixed(1) }}%</span>
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-amber-500"></span>
            <span class="text-slate-600">Berjalan {{ flow.outstanding_pct.toFixed(1) }}%</span>
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-red-500"></span>
            <span class="text-slate-600">Telat {{ flow.overdue_pct.toFixed(1) }}%</span>
          </span>
        </div>
      </div>
      <div class="h-3 bg-slate-100 rounded-full overflow-hidden flex">
        <div
          class="h-full bg-emerald-500 transition-all"
          :style="{ width: `${flow.paid_pct}%` }"
        ></div>
        <div
          class="h-full bg-amber-500 transition-all"
          :style="{ width: `${flow.outstanding_pct}%` }"
        ></div>
        <div
          class="h-full bg-red-500 transition-all"
          :style="{ width: `${flow.overdue_pct}%` }"
        ></div>
      </div>
    </div>
  </section>
</template>
