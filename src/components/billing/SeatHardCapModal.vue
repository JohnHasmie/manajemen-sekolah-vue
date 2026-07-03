<!--
  Global 402 modal — surfaces the hard-cap error the http interceptor
  wrote into billing-ui.hardCapError. Mounted once in App.vue so any
  page can trip it. Offers one primary CTA ("Top up sekarang") that
  navigates to /subscribe/addon with the parent subscription id,
  plus a dismiss link.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useBillingUiStore } from '@/stores/billing-ui';

const { t } = useI18n();
const store = useBillingUiStore();
const router = useRouter();

const payload = computed(() => store.hardCapError);

function dismiss() {
  store.dismiss();
}

function goToTopUp() {
  const p = payload.value;
  if (!p) return;
  const url = new URL(p.top_up_url_web);
  // Preserve host but route via internal router if the path is on
  // our own origin — avoids a full page reload.
  if (url.origin === window.location.origin) {
    router.push({ path: url.pathname, query: Object.fromEntries(url.searchParams) });
  } else {
    window.location.href = p.top_up_url_web;
  }
  dismiss();
}
</script>

<template>
  <div
    v-if="payload"
    class="fixed inset-0 z-50 flex items-center justify-center px-4"
    style="background: rgba(15, 23, 42, 0.55);"
  >
    <div class="max-w-md w-full bg-white rounded-xl border border-slate-200 p-5 shadow-xl">
      <div class="flex items-start gap-3">
        <div class="w-10 h-10 rounded-full bg-rose-100 text-rose-700 flex items-center justify-center flex-shrink-0">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="11" width="18" height="10" rx="2" />
            <path d="M7 11V7a5 5 0 0110 0v4" />
          </svg>
        </div>
        <div class="min-w-0 flex-1">
          <h3 class="text-[15px] font-semibold text-slate-900">
            {{ payload.is_demo
                ? t('billing.hardCap.demoTitle')
                : t('billing.hardCap.title') }}
          </h3>
          <p class="mt-1 text-[12.5px] text-slate-600 leading-relaxed">
            {{ payload.message }}
          </p>
        </div>
      </div>

      <div class="mt-4 space-y-1.5 text-[12px]">
        <div class="flex justify-between">
          <span class="text-slate-500">{{ t('billing.hardCap.paid') }}</span>
          <span class="font-semibold text-slate-900">{{ payload.seats_paid }} seat</span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-500">{{ t('billing.hardCap.live') }}</span>
          <span class="font-semibold text-rose-700">{{ payload.seats_live }} seat</span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-500">{{ t('billing.hardCap.hard') }}</span>
          <span class="font-semibold text-slate-900">{{ payload.seats_hard }} seat</span>
        </div>
        <div v-if="payload.days_remaining !== null" class="flex justify-between">
          <span class="text-slate-500">{{ t('billing.hardCap.daysRemaining') }}</span>
          <span class="font-semibold text-slate-900">{{ payload.days_remaining }} hari</span>
        </div>
      </div>

      <div class="mt-5 flex flex-col gap-2">
        <button
          v-if="!payload.is_demo"
          type="button"
          class="w-full inline-flex items-center justify-center rounded-lg bg-rose-600 hover:bg-rose-700 text-white font-semibold px-4 py-2.5 text-sm transition-colors"
          @click="goToTopUp"
        >
          {{ t('billing.hardCap.topUpCta') }}
        </button>
        <button
          type="button"
          class="w-full inline-flex items-center justify-center rounded-lg border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 font-semibold px-4 py-2 text-sm transition-colors"
          @click="dismiss"
        >
          {{ t('common.close') }}
        </button>
      </div>
    </div>
  </div>
</template>
