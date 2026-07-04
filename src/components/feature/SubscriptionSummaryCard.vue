<!--
  SubscriptionSummaryCard — compact one-row admin dashboard card that
  surfaces the tenant's current subscription snapshot with a single
  "Kelola →" CTA to the full ManageModulesView.

  Fetches `GET /billing/modules/mine` on mount, keeps its own error
  handling so a temporary API blip doesn't tank the whole dashboard.
  Renders three stats horizontally:
    · MODUL AKTIF     — count of subscription_modules rows minus
                        cancel_at_period_end
    · TAGIHAN / BULAN — sum of monthly_amount across active rows
    · PERPANJANGAN    — expires_at + days_remaining

  When the tenant has NO subscription (never signed up, or landed on
  demo) we render a compact upsell strip instead — same footprint,
  no separate empty state.
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
const { t: _t } = useI18n();

const data = ref<MyModules | null>(null);
const loading = ref(true);
const errorMessage = ref<string | null>(null);

async function load() {
  loading.value = true;
  errorMessage.value = null;
  try {
    data.value = await SubscriptionBillingService.getMyModules();
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(load);

const activeRows = computed(() =>
  (data.value?.modules ?? []).filter((r) => !r.cancel_at_period_end),
);

const activeCount = computed(() => activeRows.value.length);
const cancelledCount = computed(
  () => (data.value?.modules ?? []).length - activeCount.value,
);

const monthlyAmount = computed(() =>
  activeRows.value.reduce((sum, r) => sum + r.monthly_amount, 0),
);

const expiresDate = computed<string>(() => {
  const raw = data.value?.subscription?.expires_at;
  if (!raw) return '—';
  const d = new Date(raw);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('id-ID', {
    day: 'numeric', month: 'short', year: 'numeric',
  });
});

const daysRemaining = computed<number>(
  () => data.value?.subscription?.days_remaining ?? 0,
);

const hasSubscription = computed<boolean>(
  () => data.value?.subscription !== null && data.value?.subscription !== undefined,
);

function open(): void {
  router.push('/subscribe/manage-modules');
}

function subscribe(): void {
  router.push('/subscribe');
}
</script>

<template>
  <!-- No-sub upsell strip: same footprint, prompts the admin to
       start a paid subscription instead. Never renders while data
       is loading — we don't want to flash "Belum berlangganan" on
       an admin who IS subscribed. -->
  <div
    v-if="!loading && !hasSubscription && !errorMessage"
    class="ssc-upsell"
  >
    <div class="ssc-upsell-icon" aria-hidden="true">
      <NavIcon name="sparkles" :size="16" />
    </div>
    <div class="ssc-upsell-body">
      <div class="ssc-upsell-title">Belum berlangganan</div>
      <div class="ssc-upsell-sub">
        Aktifkan langganan untuk buka semua modul (Nilai, Raport, Absensi,
        Keuangan, Komunikasi, RPP, dst).
      </div>
    </div>
    <button type="button" class="ssc-upsell-btn" @click="subscribe">
      Berlangganan →
    </button>
  </div>

  <!-- Compact subscription card. Left = 3 stat columns, right = CTA. -->
  <div v-else-if="!errorMessage" class="ssc">
    <div class="ssc-lead" aria-hidden="true">
      <div class="ssc-lead-icon">
        <NavIcon name="package" :size="16" />
      </div>
      <div class="ssc-lead-label">Langganan Anda</div>
    </div>

    <div class="ssc-stats">
      <div class="ssc-stat">
        <span class="ssc-stat-lbl">Modul aktif</span>
        <span class="ssc-stat-val">
          <template v-if="loading">—</template>
          <template v-else>{{ activeCount }}</template>
        </span>
        <span
          v-if="cancelledCount > 0"
          class="ssc-stat-sub"
        >{{ cancelledCount }} akan berakhir</span>
      </div>

      <div class="ssc-stat">
        <span class="ssc-stat-lbl">Tagihan / bulan</span>
        <span class="ssc-stat-val">
          <template v-if="loading">—</template>
          <template v-else>{{ formatRupiah(monthlyAmount) }}</template>
        </span>
      </div>

      <div class="ssc-stat">
        <span class="ssc-stat-lbl">Perpanjangan</span>
        <span class="ssc-stat-val ssc-stat-val-sm">
          <template v-if="loading">—</template>
          <template v-else>{{ expiresDate }}</template>
        </span>
        <span
          v-if="!loading && daysRemaining > 0"
          class="ssc-stat-sub"
        >{{ daysRemaining }} hari lagi</span>
      </div>
    </div>

    <button type="button" class="ssc-cta" @click="open">
      Kelola
      <NavIcon name="arrow-right" :size="14" />
    </button>
  </div>

  <!-- Graceful error: kept intentionally quiet — admin can retry from
       the dedicated page. We don't want a red banner on the dashboard
       from a transient billing-service blip. -->
  <div v-else class="ssc ssc-err">
    <span class="ssc-lead-label">Status langganan tidak tersedia</span>
    <button type="button" class="ssc-cta ssc-cta-ghost" @click="load">
      Coba lagi
    </button>
  </div>
</template>

<style scoped>
/* Base card — one row, three stat columns, right-aligned CTA.
   Emerald accent on the icon + label mirrors the subscription /
   savings language elsewhere in the app (BundleStrip, ManageModules). */
.ssc {
  background: #FFFFFF;
  border: 1px solid #E2E8F0;
  border-radius: 14px;
  padding: 14px 16px;
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 20px;
  align-items: center;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
}

.ssc-lead {
  display: flex; align-items: center; gap: 10px;
  flex-shrink: 0;
}
.ssc-lead-icon {
  width: 32px; height: 32px; border-radius: 10px;
  background: #ECFDF5;
  color: #0F6E56;
  display: grid; place-items: center;
}
.ssc-lead-label {
  font-size: 11.5px;
  font-weight: 700;
  color: #0F6E56;
  text-transform: uppercase;
  letter-spacing: 0.4px;
}

.ssc-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 20px;
  align-items: baseline;
}
.ssc-stat {
  display: flex; flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.ssc-stat-lbl {
  font-size: 10.5px;
  color: #64748B;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.4px;
}
.ssc-stat-val {
  font-size: 18px;
  font-weight: 700;
  color: #0F172A;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.2px;
  line-height: 1.1;
}
.ssc-stat-val-sm { font-size: 14px; font-weight: 600; }
.ssc-stat-sub {
  font-size: 10.5px;
  color: #64748B;
  font-weight: 500;
  font-variant-numeric: tabular-nums;
}

.ssc-cta {
  flex-shrink: 0;
  background: #0F6E56;
  color: #FFFFFF;
  border: none;
  padding: 9px 14px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex; align-items: center; gap: 5px;
  letter-spacing: -0.1px;
  transition: background 0.15s;
}
.ssc-cta:hover { background: #0A5744; }
.ssc-cta-ghost {
  background: transparent;
  color: #64748B;
  border: 1px solid #E2E8F0;
}
.ssc-cta-ghost:hover { background: #F8FAFC; color: #0F172A; }

.ssc-err {
  grid-template-columns: 1fr auto;
}

/* Upsell strip: brand-blue variant since the user is being pushed
   toward a paid conversion, not surveying an existing subscription. */
.ssc-upsell {
  background: linear-gradient(180deg, #EFF4FF 0%, #DBE9FE 100%);
  border: 1px solid #B5D4F4;
  border-radius: 14px;
  padding: 12px 14px;
  display: flex; align-items: center; gap: 12px;
}
.ssc-upsell-icon {
  width: 32px; height: 32px; border-radius: 10px;
  background: #1B6FB8;
  color: #FFFFFF;
  display: grid; place-items: center;
  flex-shrink: 0;
}
.ssc-upsell-body { flex: 1; min-width: 0; }
.ssc-upsell-title {
  font-size: 13px;
  font-weight: 700;
  color: #113E75;
  letter-spacing: -0.1px;
}
.ssc-upsell-sub {
  font-size: 11.5px;
  color: #185FA5;
  margin-top: 1px;
  line-height: 1.4;
}
.ssc-upsell-btn {
  flex-shrink: 0;
  background: #1B6FB8;
  color: #FFFFFF;
  border: none;
  padding: 8px 14px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  letter-spacing: -0.1px;
}
.ssc-upsell-btn:hover { background: #185FA5; }

@media (max-width: 720px) {
  .ssc {
    grid-template-columns: 1fr;
    gap: 12px;
  }
  .ssc-cta { justify-self: end; }
  .ssc-upsell { flex-direction: column; align-items: flex-start; }
  .ssc-upsell-btn { align-self: stretch; text-align: center; }
}
</style>
