<!--
  ParentBillsView — wali Tagihan list.

  Redesigned per mockup: hero + red outstanding banner (when unpaid) +
  3-tab row (Belum lunas / Sudah lunas / Semua) + bill cards. Data
  source (TutoringService.getBills) and routing unchanged.
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

const route = useRoute();
const router = useRouter();
const { activeChildId } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const bills = ref<TutoringBill[]>([]);
// Default active tab is "unpaid" (Belum lunas) per spec — that's the
// most-actionable view when wali lands here.
const activeTab = ref<'unpaid' | 'paid' | 'all'>('unpaid');

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
function isPending(b: TutoringBill): boolean {
  return /pending/i.test(b.status ?? '');
}

const unpaid = computed(() => bills.value.filter(isUnpaid));
const paid = computed(() => bills.value.filter(isPaid));
const unpaidTotal = computed(() =>
  unpaid.value.reduce((s, b) => s + (b.amount ?? 0), 0),
);

const filtered = computed(() => {
  if (activeTab.value === 'unpaid') return unpaid.value;
  if (activeTab.value === 'paid') return paid.value;
  return bills.value;
});

// ── Banner copy ─────────────────────────────────────────────────
function daysUntil(iso?: string | null): number | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return null;
  return Math.ceil((d.valueOf() - Date.now()) / 86_400_000);
}

const dueSoonCount = computed(() => {
  return unpaid.value.filter((b) => {
    const days = daysUntil(b.due_date);
    return days != null && days >= 0 && days <= 7;
  }).length;
});

const bannerSub = computed(() => {
  const list = unpaid.value;
  if (list.length === 0) return '';
  const due = dueSoonCount.value;
  if (due > 0) {
    return `${list.length} tagihan · ${due} jatuh tempo dalam 7 hari`;
  }
  return `${list.length} tagihan tertunggak`;
});

// ── Per-bill rendering helpers ──────────────────────────────────
function dueLabel(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function statusPill(b: TutoringBill): { label: string; cls: string } {
  if (isPaid(b)) {
    return {
      label: 'Lunas',
      cls: 'bg-bimbel-green-dim text-green-700',
    };
  }
  if (isPending(b)) {
    return {
      label: 'Pending',
      cls: 'bg-bimbel-amber-dim text-amber-700',
    };
  }
  if (isUnpaid(b)) {
    const days = daysUntil(b.due_date);
    if (days != null && days < 0) {
      return {
        label: `Telat ${Math.abs(days)}h`,
        cls: 'bg-bimbel-red-dim text-red-700',
      };
    }
    if (days != null && days <= 7) {
      return {
        label: `Jatuh tempo ${days}h`,
        cls: 'bg-bimbel-red-dim text-red-700',
      };
    }
    return {
      label: 'Belum lunas',
      cls: 'bg-bimbel-accent-dim text-bimbel-hero',
    };
  }
  return {
    label: b.status ?? '—',
    cls: 'bg-bimbel-border-soft text-bimbel-text-mid',
  };
}

function goPay(b: TutoringBill) {
  router.push({ name: 'parent.tutoring.pay-bill', params: { billId: b.id } });
}

function payAll() {
  if (unpaid.value[0]) goPay(unpaid.value[0]);
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · WALI"
      title="Tagihan"
      subtitle="SPP, paket prabayar, dan biaya lain"
      :stats="[]"
    >
      <template #actions>
        <ParentChildPickerChip />
      </template>
    </ParentBerandaHero>

    <!-- Outstanding banner -->
    <div
      v-if="unpaid.length > 0"
      class="mb-3.5 flex items-center justify-between gap-3 rounded-xl border border-red-300 bg-bimbel-red-dim p-3.5"
    >
      <div class="min-w-0">
        <p class="text-[11px] font-bold uppercase tracking-wider text-red-800">
          Total belum dibayar
        </p>
        <p class="text-[22px] font-extrabold text-red-900">
          {{ formatRupiah(unpaidTotal) }}
        </p>
        <p class="text-[11px] text-red-800">{{ bannerSub }}</p>
      </div>
      <button
        type="button"
        class="flex-shrink-0 rounded-lg bg-red-900 px-3 py-2 text-[12px] font-bold text-white hover:opacity-90"
        @click="payAll"
      >
        Bayar semua
      </button>
    </div>

    <!-- Tabs -->
    <div class="flex gap-4 border-b border-bimbel-border-soft">
      <button
        v-for="opt in [
          { id: 'unpaid', label: `Belum lunas (${unpaid.length})` },
          { id: 'paid', label: `Sudah lunas (${paid.length})` },
          { id: 'all', label: 'Semua' },
        ] as const"
        :key="opt.id"
        type="button"
        class="-mb-px border-b-2 px-1 py-2 text-[13px] transition"
        :class="
          activeTab === opt.id
            ? 'border-bimbel-hero font-bold text-bimbel-hero'
            : 'border-transparent text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="activeTab = opt.id"
      >
        {{ opt.label }}
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <!-- Bill cards -->
    <div v-else-if="filtered.length" class="space-y-2.5">
      <div
        v-for="b in filtered"
        :key="b.id"
        class="rounded-xl border border-bimbel-border-soft bg-bimbel-panel p-3.5"
        :class="isPaid(b) ? 'opacity-70' : ''"
      >
        <!-- Top row: title + status pill -->
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <p class="text-[13px] font-bold text-bimbel-text-hi">
              {{ b.source_label ?? b.source_type ?? 'Tagihan' }}
            </p>
            <p class="mt-0.5 text-[11px] text-bimbel-text-mid">
              {{ b.month ?? '—' }}
              <template v-if="b.student_name"> · {{ b.student_name }}</template>
            </p>
          </div>
          <span
            class="inline-flex flex-shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide"
            :class="statusPill(b).cls"
          >
            {{ statusPill(b).label }}
          </span>
        </div>

        <!-- Bottom row: amount + CTA -->
        <div
          class="mt-2.5 flex items-center justify-between gap-3 border-t border-bimbel-border-soft pt-2.5"
        >
          <div class="min-w-0">
            <p class="text-[18px] font-extrabold text-bimbel-text-hi">
              {{ b.amount != null ? formatRupiah(b.amount) : '—' }}
            </p>
            <p class="text-[11px] text-bimbel-text-mid">
              Jatuh tempo {{ dueLabel(b.due_date) }}
            </p>
          </div>
          <button
            v-if="isPaid(b)"
            type="button"
            class="rounded-lg bg-bimbel-bg px-3.5 py-2 text-[12px] font-bold text-bimbel-text-mid hover:bg-bimbel-border-soft"
          >
            Unduh bukti
          </button>
          <button
            v-else
            type="button"
            class="rounded-lg bg-bimbel-hero px-3.5 py-2 text-[12px] font-bold text-white hover:opacity-90"
            @click="goPay(b)"
          >
            Bayar
          </button>
        </div>
      </div>
    </div>

    <div
      v-else
      class="rounded-xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-[13px] text-bimbel-text-mid"
    >
      <template v-if="activeTab === 'unpaid'">Tidak ada tagihan yang harus dibayar.</template>
      <template v-else-if="activeTab === 'paid'">Belum ada tagihan yang lunas.</template>
      <template v-else>Belum ada tagihan.</template>
    </div>
  </div>
</template>
