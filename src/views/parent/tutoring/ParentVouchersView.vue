<!--
  ParentVouchersView — parent voucher list. Mockup parent_web_pages_extra
  frame 2: hero + 2-col voucher grid with dashed border / urgent flag /
  used-out opacity.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { formatRupiah } from '@/lib/format';
import type { TutoringVoucher } from '@/types/tutoring';

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();

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
    valueCls = used ? 'text-tutoring-text-mid' : 'text-orange-700';
  } else {
    valueLabel = formatRupiah(v.value);
    valueCls = used ? 'text-tutoring-text-mid' : 'text-tutoring-hero';
  }
  // "Gratis 1 session" — backend never ships a free-session voucher type
  // yet, but if value === 0 and it's PERCENTAGE 100, show the friendlier
  // label per spec.
  if (v.type === 'PERCENTAGE' && v.value === 100) {
    valueLabel = t('wali.bimbel.vouchers.free_label');
    valueCls = used ? 'text-tutoring-text-mid' : 'text-green-700';
  }

  // Footer line — urgency / validity / usage.
  let footerText = '';
  let footerCls = 'text-tutoring-text-lo';
  if (used) {
    footerText = isExpired(v)
      ? t('wali.bimbel.vouchers.expired_on', { date: dateShort(v.valid_until) })
      : t('wali.bimbel.vouchers.used_count', { count: v.used_count });
  } else if (urgent && v.valid_until) {
    footerText = t('wali.bimbel.vouchers.expires_on', { date: dateShort(v.valid_until) });
    footerCls = 'text-red-800 font-semibold';
  } else if (v.valid_until) {
    footerText = t('wali.bimbel.vouchers.valid_until', { date: dateShort(v.valid_until) });
  } else {
    footerText = t('wali.bimbel.vouchers.no_expiry');
  }

  return {
    id: v.id,
    valueLabel,
    valueCls,
    description: v.notes || t('wali.bimbel.vouchers.default_description'),
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
    <ParentHomeHero
      :kicker="t('wali.bimbel.vouchers.kicker')"
      :title="t('wali.bimbel.vouchers.title')"
      :subtitle="t('wali.bimbel.vouchers.subtitle', { active: activeCount, expiring: expiringCount })"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-tutoring-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="view = view === 'history' ? 'active' : 'history'"
        >{{ view === 'history' ? t('wali.bimbel.vouchers.toggle_active') : t('wali.bimbel.vouchers.toggle_history') }}</button>
      </template>
    </ParentHomeHero>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('wali.bimbel.vouchers.loading') }}</div>

    <template v-else>
      <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
        {{ view === 'history' ? t('wali.bimbel.vouchers.heading_history') : t('wali.bimbel.vouchers.heading_active') }}
      </p>

      <div class="grid sm:grid-cols-2 gap-2">
        <div
          v-for="v in visible"
          :key="v.id"
          class="rounded-lg bg-tutoring-panel border border-dashed border-tutoring-border-soft p-3 relative overflow-hidden"
          :class="[
            v.urgent ? 'border-solid border-orange-600' : '',
            v.used ? 'opacity-60 border-solid' : '',
          ]"
        >
          <p class="text-[24px] font-extrabold leading-none" :class="v.valueCls">{{ v.valueLabel }}</p>
          <p class="text-[12px] text-tutoring-text-mid my-1">{{ v.description }}</p>
          <span class="font-mono text-[12px] bg-tutoring-bg px-2 py-1 rounded inline-block tracking-wider mt-2">{{ v.code }}</span>
          <p class="text-[10px] mt-1.5" :class="v.footerCls">
            <NavIcon name="clock" :size="11" class="inline align-text-bottom" />{{ ' ' }}{{ v.footerText }}
          </p>
        </div>

        <p
          v-if="!visible.length"
          class="col-span-full text-center text-[13px] text-tutoring-text-mid py-6"
        >{{ view === 'history' ? t('wali.bimbel.vouchers.empty_history') : t('wali.bimbel.vouchers.empty_active') }}</p>
      </div>
    </template>
  </div>
</template>
