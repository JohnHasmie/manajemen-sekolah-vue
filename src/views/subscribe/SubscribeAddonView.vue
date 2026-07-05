<!--
  SubscribeAddonView — mid-cycle seat top-up.

  Small standalone view (no AppShell chrome — mirrors SubscribeView).
  Reads ?subscription_id=… from the query string, quotes the prorata
  charge for the requested seat delta, then commits via
  POST /billing/addon and shows the manual bank transfer instructions.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { SubscriptionBillingService } from '@/services/billing.service';
import type { AddonCreated, AddonQuote } from '@/types/subscription-billing';
import Button from '@/components/ui/Button.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const subscriptionId = computed<string>(
  () => (route.query.subscription_id as string) ?? '',
);

const form = reactive({
  seats_delta_student: 0,
  seats_delta_staff: 0,
});
const quote = ref<AddonQuote | null>(null);
const quoteLoading = ref(false);
const quoteError = ref<string | null>(null);

const submitting = ref(false);
const result = ref<AddonCreated | null>(null);
const errorMessage = ref<string | null>(null);

const totalDelta = computed(
  () => form.seats_delta_student + form.seats_delta_staff,
);

function money(v: number): string {
  const n = Math.max(0, Math.round(v));
  return 'Rp ' + new Intl.NumberFormat('id-ID').format(n);
}

async function fetchQuote() {
  if (!subscriptionId.value || totalDelta.value <= 0) {
    quote.value = null;
    return;
  }
  quoteLoading.value = true;
  quoteError.value = null;
  try {
    quote.value = await SubscriptionBillingService.quoteAddon({
      parent_subscription_id: subscriptionId.value,
      seats_delta_student: form.seats_delta_student,
      seats_delta_staff: form.seats_delta_staff,
    });
  } catch (e) {
    quoteError.value = (e as Error).message;
    quote.value = null;
  } finally {
    quoteLoading.value = false;
  }
}

let quoteTimer: number | null = null;
watch([() => form.seats_delta_student, () => form.seats_delta_staff], () => {
  if (quoteTimer !== null) window.clearTimeout(quoteTimer);
  quoteTimer = window.setTimeout(() => fetchQuote(), 300) as unknown as number;
});

onMounted(() => {
  if (!subscriptionId.value) {
    errorMessage.value = t('addon.errors.missingSubscription');
  }
});

async function onSubmit() {
  if (!subscriptionId.value) return;
  if (totalDelta.value <= 0) {
    errorMessage.value = t('addon.errors.minSeat');
    return;
  }
  submitting.value = true;
  errorMessage.value = null;
  try {
    result.value = await SubscriptionBillingService.createAddon({
      parent_subscription_id: subscriptionId.value,
      seats_delta_student: form.seats_delta_student,
      seats_delta_staff: form.seats_delta_staff,
    });
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    submitting.value = false;
  }
}

function goHome() {
  router.push('/');
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 py-8 px-4">
    <div class="max-w-lg mx-auto">
      <header class="mb-6 text-center">
        <p class="text-2xs font-black uppercase tracking-widest text-brand-cobalt">
          {{ t('addon.kicker') }}
        </p>
        <h1 class="text-2xl font-bold text-slate-900 mt-1">
          {{ t('addon.title') }}
        </h1>
        <p class="text-sm text-slate-500 mt-1.5">
          {{ t('addon.subtitle') }}
        </p>
      </header>

      <!-- Result state -->
      <section
        v-if="result"
        class="rounded-2xl border border-emerald-200 bg-white p-6"
      >
        <div class="text-center">
          <div class="w-12 h-12 rounded-full bg-emerald-100 text-emerald-700 grid place-items-center mx-auto">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
          </div>
          <h2 class="mt-3 text-lg font-bold text-slate-900">
            {{ t('addon.success.title') }}
          </h2>
          <p class="mt-1 text-sm text-slate-600 leading-relaxed">
            {{ t('addon.success.subtitle') }}
          </p>
        </div>

        <div class="mt-5 rounded-lg bg-slate-50 p-4 space-y-2 text-[13px]">
          <div class="flex justify-between">
            <span class="text-slate-500">{{ t('addon.success.orderCode') }}</span>
            <span class="font-mono font-semibold text-slate-900">{{ result.order_id }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">{{ t('addon.success.amount') }}</span>
            <span class="font-semibold text-slate-900">{{ money(result.amount) }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">{{ t('addon.success.bank') }}</span>
            <span class="font-semibold text-slate-900">{{ result.bank_transfer_info.bank_name }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">{{ t('addon.success.account') }}</span>
            <span class="font-mono font-semibold text-slate-900">{{ result.bank_transfer_info.account_number }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">{{ t('addon.success.holder') }}</span>
            <span class="font-semibold text-slate-900">{{ result.bank_transfer_info.account_holder }}</span>
          </div>
        </div>

        <p class="mt-4 text-[12px] text-slate-500 leading-relaxed">
          {{ t('addon.success.instruction') }}
        </p>

        <Button
          variant="primary"
          size="lg"
          block
          class="mt-4"
          @click="goHome"
        >
          {{ t('addon.success.backToDashboard') }}
        </Button>
      </section>

      <!-- Form state -->
      <section
        v-else
        class="rounded-2xl border border-slate-200 bg-white p-6"
      >
        <div class="space-y-4">
          <div>
            <label class="block text-2xs font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('addon.form.studentLabel') }}
            </label>
            <input
              type="number"
              min="0"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
              v-model.number="form.seats_delta_student"
            />
          </div>
          <div>
            <label class="block text-2xs font-semibold uppercase tracking-wider text-slate-500 mb-1">
              {{ t('addon.form.staffLabel') }}
            </label>
            <input
              type="number"
              min="0"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/20 focus:outline-none"
              v-model.number="form.seats_delta_staff"
            />
          </div>
        </div>

        <div
          v-if="quote && totalDelta > 0"
          class="mt-5 rounded-lg bg-slate-50 p-4 space-y-2 text-[13px]"
        >
          <div class="flex justify-between">
            <span class="text-slate-500">{{ t('addon.form.dailyRate') }}</span>
            <span class="font-semibold text-slate-900">{{ money(quote.daily_rate) }} / seat / hari</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">{{ t('addon.form.daysRemaining') }}</span>
            <span class="font-semibold text-slate-900">{{ quote.days_remaining }} hari</span>
          </div>
          <div class="pt-2 border-t border-slate-200 flex justify-between text-base">
            <span class="text-slate-700 font-semibold">{{ t('addon.form.total') }}</span>
            <span class="font-bold text-brand-cobalt">{{ money(quote.amount) }}</span>
          </div>
        </div>

        <p v-if="quoteError" class="mt-3 text-[12px] text-rose-600">{{ quoteError }}</p>
        <p v-if="errorMessage" class="mt-3 text-[12px] text-rose-600">{{ errorMessage }}</p>

        <Button
          variant="primary"
          size="lg"
          block
          :loading="submitting"
          :disabled="submitting || totalDelta <= 0 || !subscriptionId"
          class="mt-5"
          @click="onSubmit"
        >
          {{ t('addon.form.submit') }}
        </Button>
      </section>
    </div>
  </div>
</template>
