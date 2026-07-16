<!--
  AdminFinanceView.vue — admin · Operasional Keuangan hub (Mockup #13).

  Layout:
    1. BrandPageHeader (admin) — kicker + title + AcademicYearChip
    2. MoneyFlowStrip — pendapatan / outstanding / overdue + FlowBar
    3. Tab nav — Bill · Pembayaran · Jenis (router-linked)
    4. <router-view /> for the active tab

  Sub-routes:
    /admin/finance/bills     → AdminFinanceBillsView (Phase 6)
    /admin/finance/payments  → AdminFinancePaymentsView (Phase 7)
    /admin/finance/types       → AdminFinanceJenisView (Phase 8)

  Endpoint:
    GET /finance/money-flow    → MoneyFlowSummary
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { FinanceService } from '@/services/finance.service';
import type { MoneyFlowSummary } from '@/types/billing';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import MoneyFlowStrip from '@/components/feature/MoneyFlowStrip.vue';
import AcademicYearChip from '@/components/feature/AcademicYearChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const flow = ref<MoneyFlowSummary | null>(null);
const isLoadingFlow = ref(true);
const flowError = ref<string | null>(null);

async function loadFlow() {
  isLoadingFlow.value = true;
  flowError.value = null;
  try {
    flow.value = await FinanceService.moneyFlow();
  } catch (e) {
    flowError.value = (e as Error).message;
  } finally {
    isLoadingFlow.value = false;
  }
}

onMounted(loadFlow);
useAcademicYearWatcher(loadFlow);

interface Tab {
  key: 'tagihan' | 'pembayaran' | 'jenis';
  label: string;
  icon: string;
  route: string;
}

const TABS = computed<Tab[]>(() => [
  { key: 'tagihan', label: t('admin.sekolah.finance.tab_bills'), icon: 'credit-card', route: 'admin.finance.bills' },
  { key: 'pembayaran', label: t('admin.sekolah.finance.tab_payments'), icon: 'check-circle', route: 'admin.finance.payments' },
  { key: 'jenis', label: t('admin.sekolah.finance.tab_types'), icon: 'layers', route: 'admin.finance.types' },
]);

const activeTab = computed<Tab['key']>(() => {
  // Match on the ACTUAL router-name suffix — the child routes use
  // English keys (`admin.finance.payments`, `admin.finance.types`),
  // not the Indonesian tab labels this composable used to look for
  // (`pembayaran`, `jenis`). Pre-fix the two `if`s never matched, so
  // regardless of which sub-tab was open the active-pill stayed on
  // Tagihan (Slack 1783563140, Yahya 2026-07-09).
  const name = String(route.name ?? '');
  if (name.endsWith('.payments')) return 'pembayaran';
  if (name.endsWith('.types')) return 'jenis';
  return 'tagihan';
});

function goTab(tab: Tab) {
  router.push({ name: tab.route });
}

const headerMeta = computed(() => {
  if (!flow.value) return t('admin.sekolah.finance.header_meta_loading');
  return t('admin.sekolah.finance.header_meta', {
    month: flow.value.period.month,
    count: flow.value.outstanding.count,
  });
});
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.finance.header_kicker')"
      :title="t('admin.sekolah.finance.header_title')"
      :meta="headerMeta"
    >
      <AcademicYearChip />
    </BrandPageHeader>

    <!-- Money flow strip — skeleton mimics the 3-KPI shape (In/Out/Balance). -->
    <div
      v-if="isLoadingFlow && !flow"
      class="grid gap-3 grid-cols-1 sm:grid-cols-3"
      aria-hidden="true"
    >
      <div
        v-for="i in 3"
        :key="i"
        class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3"
      >
        <div class="h-3 w-24 rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
        <div class="h-6 w-32 rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
      </div>
    </div>
    <div
      v-else-if="flowError"
      class="bg-red-50 border border-red-200 rounded-2xl p-4 text-[12px] text-red-700"
    >
      {{ flowError }}
      <button class="ml-2 font-bold underline" @click="loadFlow">{{ t('admin.sekolah.finance.retry') }}</button>
    </div>
    <MoneyFlowStrip v-else-if="flow" :summary="flow" />

    <!-- Tab nav -->
    <nav
      class="bg-white border border-slate-200 rounded-2xl p-1.5 flex items-center gap-1 overflow-x-auto"
      role="tablist"
    >
      <button
        v-for="tab in TABS"
        :key="tab.key"
        type="button"
        role="tab"
        :aria-selected="activeTab === tab.key"
        class="flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-xl text-[12px] font-bold transition-all"
        :class="
          activeTab === tab.key
            ? 'bg-role-admin text-white shadow'
            : 'text-slate-500 hover:text-slate-900 hover:bg-slate-50'
        "
        @click="goTab(tab)"
      >
        <NavIcon :name="tab.icon" :size="13" />
        {{ tab.label }}
      </button>
    </nav>

    <!-- Active tab body -->
    <router-view :money-flow="flow" />
  </div>
</template>
