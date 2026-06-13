<!--
  TutorEarningsView — tutor's "Penghasilan Saya" page.

  Loads GET /tutoring/payouts/summary for the calling user with
  optional ?month=YYYY-MM. Displays KPI strip (earnings/sesi/jam/rate)
  + month picker.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutorPayoutSummary } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const summary = ref<TutorPayoutSummary | null>(null);
const month = ref<string>(''); // YYYY-MM; '' = current

// Payslip PDF URL — same query the page is currently viewing.
// Browser opens / downloads via the <a> in the header.
const payslipUrl = computed(() => {
  const base = '/api/tutoring/payouts/summary/pdf';
  return month.value ? `${base}?month=${month.value}` : base;
});

async function load() {
  loading.value = true;
  try {
    summary.value = await TutoringService.getPayoutSummary({
      month: month.value || undefined,
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat penghasilan.');
  } finally {
    loading.value = false;
  }
}
onMounted(load);
watch(month, load);

function basisLabel(b: string) {
  return b === 'PER_HOUR' ? 'per jam' : 'per sesi';
}

const kpiCards = computed<KpiCard[]>(() => {
  const s = summary.value;
  if (!s) return [];
  return [
    {
      icon: 'wallet',
      label: 'Penghasilan',
      value: formatRupiah(s.earnings),
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'calendar',
      label: 'Sesi selesai',
      value: s.sessions_count,
      tone: 'violet',
    },
    {
      icon: 'clock',
      label: 'Jam mengajar',
      value: `${s.hours}h`,
      tone: 'amber',
    },
    {
      icon: 'tag',
      label: 'Rate',
      value: s.rate.configured ? formatRupiah(s.rate.amount) : '–',
      suffix: s.rate.configured ? basisLabel(s.rate.basis) : 'belum diset',
      tone: s.rate.configured ? 'green' : 'slate',
    },
  ];
});

// Build a small picker — last 6 months including current.
const monthOptions = computed(() => {
  const out: { value: string; label: string }[] = [
    { value: '', label: 'Bulan ini' },
  ];
  const now = new Date();
  for (let i = 1; i <= 5; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    out.push({
      value: `${yyyy}-${mm}`,
      label: d.toLocaleString('id-ID', { month: 'long', year: 'numeric' }),
    });
  }
  return out;
});
</script>

<template>
  <div class="space-y-md pb-12">
    <TutorBerandaHero
      greeting="Honor Saya"
      title="Penghasilan"
      :subtitle="summary ? `Periode ${summary.period.label}` : undefined"
      :stats="[]"
    />
    <div v-if="summary" class="flex justify-end -mt-2">
      <a
        :href="payslipUrl"
        target="_blank"
        rel="noopener"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-accent text-white text-[12px] font-bold hover:opacity-90"
      >
        Slip Honor (PDF)
      </a>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else-if="summary">
      <KpiStripCards :cards="kpiCards" />

      <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl p-4 sm:p-5">
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Pilih bulan
          </span>
          <select
            v-model="month"
            class="mt-1.5 w-full sm:w-64 rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option
              v-for="o in monthOptions"
              :key="o.value || 'now'"
              :value="o.value"
            >
              {{ o.label }}
            </option>
          </select>
        </label>

        <div
          v-if="!summary.rate.configured"
          class="mt-4 rounded-xl bg-bimbel-amber-soft border border-status-warning/30 p-3 text-sm text-bimbel-amber"
        >
          Rate honor Anda belum diset oleh admin. Hubungi admin bimbel
          untuk konfirmasi tarif per-sesi / per-jam yang berlaku.
        </div>

        <div v-else class="mt-4 text-sm text-bimbel-text-mid leading-relaxed">
          <p>
            Honor:
            <span class="font-bold text-bimbel-text-hi">
              {{ formatRupiah(summary.rate.amount) }}
            </span>
            {{ basisLabel(summary.rate.basis) }}
          </p>
          <p class="mt-1">
            Dihitung dari {{ summary.sessions_count }} sesi yang sudah
            <strong>selesai</strong> pada periode
            <strong>{{ summary.period.label }}</strong>
            ({{ summary.hours }} jam total).
          </p>
          <p
            v-if="summary.rate.note"
            class="mt-2 text-xs text-bimbel-text-mid"
          >
            Catatan admin: {{ summary.rate.note }}
          </p>
        </div>
      </div>
    </template>

    <TutoringEmpty
      v-else
      text="Gagal memuat penghasilan."
      icon="alert-circle"
    />
  </div>
</template>
