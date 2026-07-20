<!--
  SubscriptionMiniRow — compact one-liner subscription strip that lives
  UNDER the Pusat Kendali hero card so the "Langganan aktif · N modul ·
  Rp X/bln" signal stays visible without eating the hero real estate the
  new AdminControlCenterCard now owns.

  Layout: emerald pill = chip icon 📦 + inline summary + "Kelola →" CTA.

  Data source: same `GET /billing/modules/mine` endpoint the full
  `SubscriptionSummaryCard` uses. Silent-drops on error/no-sub so an
  API blip never spawns a red banner under the hero. The full detail +
  add/cancel actions live at /admin/settings/modules; this row is the
  one-glance breadcrumb.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { SubscriptionBillingService } from '@/services/billing.service';
import { formatRupiah } from '@/lib/format';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { MyModules } from '@/types/subscription-billing';

const router = useRouter();
const { t } = useI18n();

const data = ref<MyModules | null>(null);
const loading = ref(true);
const errored = ref(false);

async function load() {
  loading.value = true;
  errored.value = false;
  try {
    data.value = await SubscriptionBillingService.getMyModules();
  } catch {
    // Silent — the whole row self-hides via `v-if` on the error state
    // so a transient billing-service blip never surfaces a red banner
    // beneath the hero. Admin can retry from /admin/settings/modules.
    errored.value = true;
    data.value = null;
  } finally {
    loading.value = false;
  }
}

onMounted(load);

const activeRows = computed(() =>
  (data.value?.modules ?? []).filter((r) => !r.cancel_at_period_end),
);
const activeCount = computed(() => activeRows.value.length);
const hasSubscription = computed(
  () => !!data.value?.subscription,
);

/** Discount-aware monthly bill from the server-computed `subscription.amount`. */
const billedMonthlyAmount = computed(() => {
  const serverAmount = data.value?.subscription?.amount;
  if (typeof serverAmount === 'number') return serverAmount;
  return activeRows.value.reduce((sum, r) => sum + r.monthly_amount, 0);
});

const appliedDiscount = computed(
  () => data.value?.subscription?.applied_discount ?? null,
);

/**
 * Compact discount fragment, e.g. "· Diskon 50% s/d 12 Sep 2026" — only
 * rendered when a discount is active. Keeps the row to one visual line
 * on desktop.
 */
const discountFragment = computed<string>(() => {
  const d = appliedDiscount.value;
  if (!d) return '';
  const parts: string[] = [];
  if (d.type === 'percent' && typeof d.value === 'number' && d.value > 0) {
    parts.push(t('admin.subscription.miniDiscountPercent', { pct: d.value }));
  } else if (d.discount_amount > 0) {
    parts.push(t('admin.subscription.miniDiscountAmount', { amount: formatRupiah(d.discount_amount) }));
  }
  if (d.valid_until) {
    const when = new Date(d.valid_until);
    if (!isNaN(when.getTime())) {
      const iso = when.toLocaleDateString(undefined, {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      });
      parts.push(t('admin.subscription.miniDiscountUntil', { date: iso }));
    }
  }
  return parts.join(' ');
});

function open() {
  router.push('/admin/settings/modules');
}

function subscribe() {
  router.push('/subscribe');
}
</script>

<template>
  <!-- Loading placeholder — same footprint so we don't shift layout. -->
  <div v-if="loading" class="sub-mini sub-mini--muted">
    <span class="sub-mini-icon" aria-hidden="true">
      <NavIcon name="package" :size="14" />
    </span>
    <span class="sub-mini-body">
      <span class="sub-mini-skeleton"></span>
    </span>
  </div>

  <!-- No subscription: keep the row but flip to a compact upsell. -->
  <div
    v-else-if="!hasSubscription && !errored"
    class="sub-mini sub-mini--upsell"
  >
    <span class="sub-mini-icon" aria-hidden="true">
      <NavIcon name="sparkles" :size="14" />
    </span>
    <span class="sub-mini-body">
      <b>{{ t('admin.subscription.miniUpsellTitle') }}</b>
      <span class="sub-mini-sub">{{ t('admin.subscription.miniUpsellSub') }}</span>
    </span>
    <button type="button" class="sub-mini-cta sub-mini-cta--blue" @click="subscribe">
      {{ t('admin.subscription.subscribe') }}
      <NavIcon name="arrow-right" :size="12" />
    </button>
  </div>

  <!-- Happy path: emerald pill with the one-line summary. -->
  <div v-else-if="hasSubscription" class="sub-mini">
    <span class="sub-mini-icon" aria-hidden="true">
      <NavIcon name="package" :size="14" />
    </span>
    <span class="sub-mini-body">
      {{ t('admin.subscription.miniActive', {
        n: activeCount,
        amount: formatRupiah(billedMonthlyAmount),
      }) }}
      <span
        v-if="discountFragment"
        class="sub-mini-discount"
      > · {{ discountFragment }}</span>
    </span>
    <button type="button" class="sub-mini-cta" @click="open">
      {{ t('admin.subscription.manage') }}
      <NavIcon name="arrow-right" :size="12" />
    </button>
  </div>

  <!-- Error path: silent-drop. Nothing renders. -->
</template>

<style scoped>
.sub-mini {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 12px;
  background: #ECFDF5;
  border: 1px solid #A7F3D0;
  color: #065F46;
  font-size: 12px;
  line-height: 1.35;
}
.sub-mini--muted {
  background: #F8FAFC;
  border-color: #E2E8F0;
  color: #64748B;
}
.sub-mini--upsell {
  background: linear-gradient(180deg, #EFF4FF 0%, #DBE9FE 100%);
  border-color: #B5D4F4;
  color: #113E75;
}

.sub-mini-icon {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  background: rgba(6, 95, 70, 0.10);
  color: #065F46;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.sub-mini--muted .sub-mini-icon {
  background: #E2E8F0;
  color: #64748B;
}
.sub-mini--upsell .sub-mini-icon {
  background: #1B6FB8;
  color: #FFFFFF;
}

.sub-mini-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px;
  font-weight: 600;
}
.sub-mini-body b { font-weight: 700; margin-right: 4px; }
.sub-mini-sub {
  color: rgba(24, 95, 165, 0.85);
  font-weight: 500;
  font-size: 11.5px;
}
.sub-mini-discount {
  color: #047857;
  font-weight: 500;
}

.sub-mini-skeleton {
  display: inline-block;
  width: min(220px, 60%);
  height: 12px;
  border-radius: 6px;
  background: linear-gradient(90deg, #E2E8F0 0%, #F1F5F9 50%, #E2E8F0 100%);
  background-size: 200% 100%;
  animation: sub-mini-shimmer 1.4s infinite;
}
@keyframes sub-mini-shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.sub-mini-cta {
  flex-shrink: 0;
  background: #059669;
  color: #FFFFFF;
  border: none;
  padding: 6px 12px;
  border-radius: 8px;
  font-size: 11.5px;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  transition: background 0.15s;
  letter-spacing: -0.1px;
}
.sub-mini-cta:hover { background: #047857; }
.sub-mini-cta--blue { background: #1B6FB8; }
.sub-mini-cta--blue:hover { background: #185FA5; }

@media (max-width: 640px) {
  .sub-mini {
    flex-wrap: wrap;
  }
  .sub-mini-cta {
    margin-left: auto;
  }
}
</style>
