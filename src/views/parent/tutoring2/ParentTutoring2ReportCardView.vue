<!--
  ParentTutoring2ReportCardView.vue — Wali bimbel report card (WEB-5).

  MVP scaffold: the backend does not yet expose a rapor endpoint, so
  the view hardcodes a nominal report layout (school + program header,
  a Mapel/Aspek/Nilai/Predikat table, and a tutor note). The download
  button stubs a toast so the CTA is discoverable without lying about
  a real PDF.

  Route: /parent/tutoring2/report-card/:studentId
-->
<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';

const { t } = useI18n();
const route = useRoute();
const toast = useToast();

// Route param threaded via a computed so the studentId is still
// available to the (soon-to-arrive) BE-6 /rapor endpoint without
// tripping TS6133 for an unread local.
const studentId = String(route.params.studentId ?? '');
// eslint-disable-next-line @typescript-eslint/no-unused-expressions
void studentId;

// TODO WEB-5+ swap to /tutoring2/parent/report-card/:studentId once BE-6 ships.
// For now the state resolves to a nominal payload so AsyncView renders
// the hardcoded slot and never flips to "empty".
interface ReportRow {
  subject: string;
  aspect: string;
  score: number;
  grade: string;
}

const { state, reload } = useDataRefresh(async () => {
  // MVP: static seed — 3 sample rows.
  return [
    { subject: 'Matematika', aspect: 'Konsep', score: 85, grade: 'A' },
    { subject: 'Fisika', aspect: 'Aplikasi', score: 78, grade: 'B+' },
    { subject: 'Kimia', aspect: 'Konsep', score: 72, grade: 'B' },
  ] as ReportRow[];
});

function download() {
  toast.info(t('tutoring2.common.notAvailable'));
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.reportCard.title')"
      :meta="t('tutoring2.parent.reportCard.meta', { term: 'Jan–Jun 2026' })"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="2"
      :empty-title="t('tutoring2.parent.reportCard.emptyTitle')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <!-- School/program header — TODO wire to real tenant + program once BE-6 exposes it -->
          <header class="flex items-start justify-between gap-3 border-b border-slate-100 px-4 py-3">
            <div class="min-w-0">
              <!-- TODO i18n key -->
              <p class="text-2xs font-bold uppercase tracking-widest text-slate-500">Bimbel Cendekia</p>
              <!-- TODO i18n key -->
              <h3 class="mt-0.5 truncate text-sm font-bold text-slate-900">SBMPTN Saintek</h3>
            </div>
            <StatusBadge :label="t('tutoring2.status.published')" tone="success" uppercase />
          </header>

          <!-- Report table — Mapel / Aspek / Nilai / Predikat -->
          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm">
              <thead class="bg-slate-50 text-2xs uppercase tracking-widest text-slate-500">
                <tr>
                  <!-- TODO i18n key -->
                  <th class="px-4 py-2 font-bold">Mapel</th>
                  <!-- TODO i18n key -->
                  <th class="px-4 py-2 font-bold">Aspek</th>
                  <!-- TODO i18n key -->
                  <th class="px-4 py-2 font-bold">Nilai</th>
                  <!-- TODO i18n key -->
                  <th class="px-4 py-2 font-bold">Predikat</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr v-for="(row, idx) in (data as ReportRow[])" :key="idx">
                  <td class="px-4 py-3 font-semibold text-slate-900">{{ row.subject }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ row.aspect }}</td>
                  <td class="px-4 py-3 font-bold text-slate-900">{{ row.score }}</td>
                  <td class="px-4 py-3">
                    <span class="inline-flex items-center justify-center rounded-lg bg-emerald-50 px-2 py-0.5 text-xs font-bold text-emerald-700">
                      {{ row.grade }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Catatan tutor -->
          <section class="border-t border-slate-100 px-4 py-3">
            <p class="text-2xs font-bold uppercase tracking-widest text-slate-500">
              {{ t('tutoring2.parent.reportCard.tutorNote') }}
            </p>
            <!-- TODO i18n key: real note comes from BE -->
            <p class="mt-1 text-sm text-slate-700">
              Anak Ibu/Bapak menunjukkan progres yang stabil pada matematika dan fisika. Perlu latihan tambahan untuk soal aplikasi kimia sebelum try-out berikutnya.
            </p>
          </section>

          <footer class="border-t border-slate-100 px-4 py-3">
            <Button variant="primary" block @click="download">
              {{ t('tutoring2.parent.reportCard.downloadPdf') }}
            </Button>
          </footer>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
