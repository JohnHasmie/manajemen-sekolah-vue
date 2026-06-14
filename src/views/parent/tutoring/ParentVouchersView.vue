<!--
  ParentVouchersView — wali voucher list. Mockup parent_web_pages_extra
  frame 2: hero + 2-col voucher grid with dashed border / urgent flag /
  used-out opacity.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { formatRupiah } from '@/lib/format';
import type { TutoringVoucher } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const loading = ref(true);
const vouchers = ref<TutoringVoucher[]>([]);
const view = ref<'active' | 'history'>('active');

async function load() {
  loading.value = true;
  try { vouchers.value = await TutoringService.getVouchers(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

// ── Active / used predicates ──────────────────────────────────────
function isExpired(v: TutoringVoucher): boolean {
  if (!v.valid_until) return false;
  return new Date(v.valid_until).valueOf() < Date.now();
}
function isMaxUsed(v: TutoringVoucher): boolean {
  return v.max_uses != null && v.used_count >= v.max_uses;
}
function isActive(v: TutoringVoucher): boolean {
  return v.is_active && !isExpired(v) && !isMaxUsed(v);
}

const activeList = computed(() => vouchers.value.filter(isActive));
const historyList = computed(() => vouchers.value.filter((v) => !isActive(v)));

const activeCount = computed(() => activeList.value.length);
const expiringCount = computed(() => {
  const sevenDays = 7 * 24 * 60 * 60 * 1000;
  return activeList.value.filter((v) => {
    if (!v.valid_until) return false;
    return new Date(v.valid_until).valueOf() - Date.now() <= sevenDays;
  }).length;
});

function isUrgent(v: TutoringVoucher): boolean {
  if (!v.valid_until) return false;
  const sevenDays = 7 * 24 * 60 * 60 * 1000;
  return new Date(v.valid_until).valueOf() - Date.now() <= sevenDays;
}

// ── Display shape ─────────────────────────────────────────────────
interface VoucherView {
  id: string;
  valueLabel: string;
  valueCls: string;
  description: string;
  code: string;
  urgent: boolean;
  used: boolean;
  footerText: string;
  footerCls: string;
}

function dateShort(iso?: string | null): string {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
}

function mapVoucher(v: TutoringVoucher): VoucherView {
  const active = isActive(v);
  const urgent = active && isUrgent(v);
  const used = !active;

  // Big amount label + color.
  let valueLabel = '';
  let valueCls = '';
  if (v.type === 'PERCENTAGE') {
    valueLabel = `${v.value}%`;
    valueCls = used ? 'text-bimbel-text-mid' : 'text-orange-700';
  } else {
    valueLabel = formatRupiah(v.value);
    valueCls = used ? 'text-bimbel-text-mid' : 'text-bimbel-hero';
  }
  // "Gratis 1 sesi" — backend never ships a free-session voucher type
  // yet, but if value === 0 and it's PERCENTAGE 100, show the friendlier
  // label per spec.
  if (v.type === 'PERCENTAGE' && v.value === 100) {
    valueLabel = 'Gratis';
    valueCls = used ? 'text-bimbel-text-mid' : 'text-green-700';
  }

  // Footer line — urgency / validity / usage.
  let footerText = '';
  let footerCls = 'text-bimbel-text-lo';
  if (used) {
    footerText = isExpired(v)
      ? `Kedaluwarsa ${dateShort(v.valid_until)}`
      : `Dipakai ${v.used_count}×`;
  } else if (urgent && v.valid_until) {
    footerText = `Berakhir ${dateShort(v.valid_until)}`;
    footerCls = 'text-red-800 font-semibold';
  } else if (v.valid_until) {
    footerText = `Berlaku sampai ${dateShort(v.valid_until)}`;
  } else {
    footerText = 'Tanpa batas waktu';
  }

  return {
    id: v.id,
    valueLabel,
    valueCls,
    description: v.notes || 'Diskon biaya bimbel',
    code: v.code,
    urgent,
    used,
    footerText,
    footerCls,
  };
}

const visible = computed<VoucherView[]>(() => {
  const src = view.value === 'history' ? historyList.value : activeList.value;
  return src.map(mapVoucher);
});
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · VOUCHER"
      title="Voucher & promo aktif"
      :subtitle="`${activeCount} aktif · ${expiringCount} segera kedaluwarsa`"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[13px] font-bold hover:bg-white/95"
          @click="view = view === 'history' ? 'active' : 'history'"
        >{{ view === 'history' ? 'Aktif' : 'Riwayat' }}</button>
      </template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <template v-else>
      <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
        {{ view === 'history' ? 'VOUCHER TERPAKAI' : 'VOUCHER TERSEDIA' }}
      </p>

      <div class="grid sm:grid-cols-2 gap-2">
        <div
          v-for="v in visible"
          :key="v.id"
          class="rounded-lg bg-bimbel-panel border border-dashed border-bimbel-border-soft p-3 relative overflow-hidden"
          :class="[
            v.urgent ? 'border-solid border-orange-600' : '',
            v.used ? 'opacity-60 border-solid' : '',
          ]"
        >
          <p class="text-[24px] font-extrabold leading-none" :class="v.valueCls">{{ v.valueLabel }}</p>
          <p class="text-[11px] text-bimbel-text-mid my-1">{{ v.description }}</p>
          <span class="font-mono text-[11px] bg-bimbel-bg px-2 py-1 rounded inline-block tracking-wider mt-2">{{ v.code }}</span>
          <p class="text-[10px] mt-1.5" :class="v.footerCls">
            <NavIcon name="clock" :size="11" class="inline align-text-bottom" />{{ ' ' }}{{ v.footerText }}
          </p>
        </div>

        <p
          v-if="!visible.length"
          class="col-span-full text-center text-[12px] text-bimbel-text-mid py-6"
        >{{ view === 'history' ? 'Belum ada voucher terpakai.' : 'Tidak ada voucher aktif.' }}</p>
      </div>
    </template>
  </div>
</template>
