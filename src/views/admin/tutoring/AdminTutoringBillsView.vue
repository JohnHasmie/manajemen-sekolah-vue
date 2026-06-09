<!--
  AdminTutoringBillsView — all tutoring bills across the tenant, with an
  unpaid-only filter + a link to billing settings. Web mirror of the
  Flutter TutoringAdminBillsScreen.
-->
<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type { TutoringBill } from '@/types/tutoring';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const unpaidOnly = ref(false);
const bills = ref<TutoringBill[]>([]);

function badgeClass(status: string): string {
  const s = status.toLowerCase();
  if (s === 'paid') return 'bg-emerald-100 text-emerald-800';
  if (s === 'pending') return 'bg-amber-100 text-amber-800';
  return 'bg-red-100 text-red-800';
}

function badgeLabel(status: string): string {
  const s = status.toLowerCase();
  if (s === 'paid') return t('tutoring.adminBills.paid');
  if (s === 'pending') return t('tutoring.adminBills.pending');
  return t('tutoring.adminBills.unpaid');
}

async function load() {
  loading.value = true;
  try {
    bills.value = await TutoringService.getAllBills(
      unpaidOnly.value ? 'unpaid' : undefined,
    );
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring.adminBills.empty'));
  } finally {
    loading.value = false;
  }
}

watch(unpaidOnly, load);
onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-bold text-slate-800">
        {{ t('tutoring.adminBills.title') }}
      </h1>
      <button
        class="text-sm font-semibold text-indigo-900"
        @click="router.push({ name: 'admin.tutoring.billing-settings' })"
      >
        {{ t('tutoring.nav.billingSettings') }}
      </button>
    </div>

    <label class="mb-3 flex items-center gap-2 text-sm text-slate-700">
      <input v-model="unpaidOnly" type="checkbox" class="h-4 w-4" />
      {{ t('tutoring.adminBills.unpaidOnly') }}
    </label>

    <div v-if="loading" class="py-16 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <p v-else-if="bills.length === 0" class="py-12 text-center text-slate-500">
      {{ t('tutoring.adminBills.empty') }}
    </p>
    <ul v-else class="space-y-2">
      <li
        v-for="b in bills"
        :key="b.id"
        class="flex items-center justify-between rounded-xl border border-slate-200 p-3"
      >
        <div>
          <div class="font-semibold text-slate-800">{{ b.student_name ?? '—' }}</div>
          <div class="text-sm text-slate-500">
            {{
              [b.source_label, b.month, b.due_date ? formatDateShort(b.due_date) : null]
                .filter(Boolean)
                .join(' · ')
            }}
          </div>
        </div>
        <div class="text-right">
          <div class="font-bold text-slate-800">{{ formatRupiah(b.amount ?? 0) }}</div>
          <span
            class="rounded-full px-2 py-0.5 text-[10.5px] font-bold"
            :class="badgeClass(b.status)"
          >
            {{ badgeLabel(b.status) }}
          </span>
        </div>
      </li>
    </ul>
  </div>
</template>
