<!--
  ParentTagihanView — wali Tagihan list. Mockup parent_web_pages_browse
  frame 2: hero + perlu-bayar ribbon + active/history seg + table.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import { formatRupiah } from '@/lib/format';
import type { TutoringBill } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import ParentRibbon from '@/components/feature/tutoring/ParentRibbon.vue';

const route = useRoute();
const router = useRouter();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const bills = ref<TutoringBill[]>([]);
const view = ref<'all' | 'unpaid' | 'paid'>('all');

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try { bills.value = await TutoringService.getBills(sid); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

function isUnpaid(b: TutoringBill): boolean {
  return /unpaid|pending|due|overdue|belum/i.test(b.status ?? '');
}
function isPaid(b: TutoringBill): boolean {
  return /paid|lunas/i.test(b.status ?? '');
}

const unpaid = computed(() => bills.value.filter(isUnpaid));
const unpaidTotal = computed(() => unpaid.value.reduce((s, b) => s + (b.amount ?? 0), 0));
const filtered = computed(() => {
  if (view.value === 'unpaid') return unpaid.value;
  if (view.value === 'paid') return bills.value.filter(isPaid);
  return bills.value;
});

function statusChip(b: TutoringBill) {
  if (isPaid(b))
    return { cls: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300', label: 'Lunas' };
  if (isUnpaid(b))
    return { cls: 'bg-rose-500/15 text-rose-700 dark:text-rose-300', label: 'Belum' };
  return { cls: 'bg-bimbel-border-soft text-bimbel-text-mid', label: b.status ?? '—' };
}

function dueLabel(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
}

function goPay(b: TutoringBill) {
  router.push({ name: 'parent.tutoring.bill-pay', params: { billId: b.id } });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · TAGIHAN"
      title="Tagihan & riwayat"
      :subtitle="`${activeChild()?.name ?? 'Anak'} · ${unpaid.length} aktif · ${bills.length - unpaid.length} lunas`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <ParentRibbon
      v-if="unpaid.length > 0"
      icon="alert-triangle"
      label="PERLU DIBAYAR"
      :value="formatRupiah(unpaidTotal)"
      :hint="`${unpaid.length} tagihan tertunggak`"
      tone="warning"
      action-label="Bayar sekarang"
      @action="goPay(unpaid[0])"
    />

    <div class="flex gap-1">
      <button
        v-for="opt in [
          { id: 'all', label: 'Semua' },
          { id: 'unpaid', label: 'Belum bayar' },
          { id: 'paid', label: 'Lunas' },
        ] as const"
        :key="opt.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[11.5px] font-semibold"
        :class="
          view === opt.id
            ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
            : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
        "
        @click="view = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel overflow-hidden">
      <table class="w-full text-[12px]">
        <thead class="bg-bimbel-bg/40">
          <tr class="text-left text-[10px] font-bold uppercase tracking-wider text-bimbel-text-mid">
            <th class="px-3 py-2">Program</th>
            <th class="px-3 py-2 w-[120px]">Bulan</th>
            <th class="px-3 py-2 w-[140px]">Jatuh tempo</th>
            <th class="px-3 py-2 w-[120px]">Jumlah</th>
            <th class="px-3 py-2 w-[90px]">Status</th>
            <th class="px-3 py-2 w-[110px]"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="b in filtered"
            :key="b.id"
            class="border-t border-bimbel-border-soft hover:bg-bimbel-border-soft/30"
          >
            <td class="px-3 py-2.5">
              <p class="font-bold text-bimbel-text-hi">{{ b.source_label ?? b.source_type ?? 'Tagihan' }}</p>
              <p v-if="b.student_name" class="text-[10.5px] text-bimbel-text-mid">{{ b.student_name }}</p>
            </td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ b.month ?? '—' }}</td>
            <td class="px-3 py-2.5 text-bimbel-text-mid">{{ dueLabel(b.due_date) }}</td>
            <td class="px-3 py-2.5 font-bold text-bimbel-text-hi">{{ b.amount != null ? formatRupiah(b.amount) : '—' }}</td>
            <td class="px-3 py-2.5">
              <span class="inline-flex rounded-full px-2 py-0.5 text-[10px] font-bold" :class="statusChip(b).cls">{{ statusChip(b).label }}</span>
            </td>
            <td class="px-3 py-2.5">
              <button
                v-if="isUnpaid(b)"
                type="button"
                class="rounded-lg bg-[#21afe6] px-3 py-1 text-[11px] font-bold text-white hover:opacity-90"
                @click="goPay(b)"
              >Bayar</button>
              <button
                v-else
                type="button"
                class="text-[11px] font-semibold text-[#1a8fbe] dark:text-[#85d4f4] hover:underline"
              >Detail</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Belum ada tagihan.
    </div>
  </div>
</template>
