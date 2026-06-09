<!--
  AdminTutoringBillsView — all tutoring bills across the tenant, with a
  status filter chip row + a link to billing settings. Rebuilt on the
  tutoring shared components.
-->
<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type { TutoringBill } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringChipsRow from '@/components/feature/tutoring/TutoringChipsRow.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type Filter = 'all' | 'unpaid' | 'pending' | 'paid';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const filter = ref<Filter>('all');
const bills = ref<TutoringBill[]>([]);

async function load() {
  loading.value = true;
  try {
    bills.value = await TutoringService.getAllBills(
      filter.value === 'all' ? undefined : filter.value,
    );
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.adminBills.empty'),
    );
  } finally {
    loading.value = false;
  }
}

watch(filter, load);
onMounted(load);

const chipOptions: { value: Filter; label: string }[] = [
  { value: 'all', label: 'Semua' },
  { value: 'unpaid', label: t('tutoring.adminBills.unpaid') },
  { value: 'pending', label: t('tutoring.adminBills.pending') },
  { value: 'paid', label: t('tutoring.adminBills.paid') },
];
</script>

<template>
  <div class="mx-auto max-w-5xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.adminBills.title')"
      crumbs="Bimbel · Tagihan"
    >
      <template #right>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-white border border-slate-200 hover:border-slate-300 rounded-lg px-3 py-1.5 text-xs font-semibold text-slate-700"
          @click="router.push({ name: 'admin.tutoring.billing-settings' })"
        >
          <NavIcon name="settings" :size="14" />
          {{ t('tutoring.nav.billingSettings') }}
        </button>
      </template>
    </TutoringPageHeader>

    <TutoringChipsRow v-model="filter" :options="chipOptions" class="mb-3" />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="bills.length === 0"
      :text="t('tutoring.adminBills.empty')"
      icon="wallet"
    />
    <div
      v-else
      class="bg-white border border-slate-100 rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-slate-500">
          <tr class="border-b border-slate-200">
            <th class="text-left font-bold px-3 py-2.5">Siswa</th>
            <th class="text-left font-bold px-3 py-2.5">Sumber</th>
            <th class="text-left font-bold px-3 py-2.5">Periode</th>
            <th class="text-right font-bold px-3 py-2.5">Nominal</th>
            <th class="text-left font-bold px-3 py-2.5">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="b in bills"
            :key="b.id"
            class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
          >
            <td class="px-3 py-3 font-semibold text-slate-900">{{ b.student_name ?? '—' }}</td>
            <td class="px-3 py-3 text-slate-700">{{ b.source_label ?? '—' }}</td>
            <td class="px-3 py-3 text-slate-700">
              {{ b.month ?? (b.due_date ? formatDateShort(b.due_date) : '—') }}
            </td>
            <td class="px-3 py-3 text-right font-semibold text-slate-900">
              {{ formatRupiah(b.amount ?? 0) }}
            </td>
            <td class="px-3 py-3">
              <TutoringStatusPill :bill="b.status" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
