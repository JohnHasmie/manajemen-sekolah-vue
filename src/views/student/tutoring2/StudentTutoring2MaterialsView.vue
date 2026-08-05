<!--
  StudentTutoring2MaterialsView.vue — Siswa "Materi" list (WEB-5 MVP).

  Composition contract (mirrors WEB-5 exemplar):
    1. BrandPageHeader        — role="student".
    2. KpiStripCards          — 4 tiles (Total / PDF / Video / Lainnya).
    3. AsyncView              — state machine (fake-loads sample so the
                                state contract already matches BE-8).
       Default slot renders a plain space-y-2 stack of TutoringMaterialRow.

  Read-only — no upload CTA, no delete button. Downloads/opens are
  stubbed to `notAvailable` toast until BE-8 exposes the endpoint.
-->
<script setup lang="ts">
// TODO WEB-5+ swap sample materials to TutoringBimbelService.listMaterials({ student })
// once BE-8 ships /tutoring-v2/materials.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringMaterialRow from '@/components/tutoring/TutoringMaterialRow.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import type { TutoringMaterial } from '@/types/tutoring-bimbel';

const { t } = useI18n();
const toast = useToast();

// Static sample so the shape reads before BE-8 lands. Kept realistic so
// the KPI counts exercise the PDF / Video / Other branches.
const sampleMaterials: TutoringMaterial[] = [
  {
    id: 'sample-1',
    title: 'Ringkasan Vektor.pdf',
    file_url: 'https://example.invalid/materials/vektor.pdf',
    file_name: 'ringkasan-vektor.pdf',
    file_size_mb: 1.4,
    file_mime: 'application/pdf',
    kind: 'PDF',
    program_label: 'Bimbel SMA · Fisika',
    created_at: '2026-07-10T02:15:00Z',
  },
  {
    id: 'sample-2',
    title: 'Rumus Cepat.pdf',
    file_url: 'https://example.invalid/materials/rumus-cepat.pdf',
    file_name: 'rumus-cepat.pdf',
    file_size_mb: 0.8,
    file_mime: 'application/pdf',
    kind: 'PDF',
    program_label: 'Bimbel SMA · Matematika',
    created_at: '2026-07-12T04:00:00Z',
  },
  {
    id: 'sample-3',
    title: 'Latihan Listening.pdf',
    file_url: 'https://example.invalid/materials/listening.pdf',
    file_name: 'latihan-listening.pdf',
    file_size_mb: 0.6,
    file_mime: 'application/pdf',
    kind: 'PDF',
    program_label: 'Bimbel SMP · Bahasa Inggris',
    created_at: '2026-07-16T09:00:00Z',
  },
];

const { state, reload } = useDataRefresh<TutoringMaterial[]>(async () => {
  // Simulated latency so the loading skeleton reads on cold nav.
  await new Promise((r) => setTimeout(r, 150));
  return sampleMaterials;
});

const contentItems = computed<TutoringMaterial[]>(() =>
  state.value.status === 'content' ? (state.value.data as TutoringMaterial[]) : [],
);

const kpiCards = computed<KpiCard[]>(() => {
  const items = contentItems.value;
  const pdfCount = items.filter((m) => {
    const mime = (m.file_mime ?? '').toLowerCase();
    const kind = (m.kind ?? '').toUpperCase();
    return kind === 'PDF' || mime.includes('pdf');
  }).length;
  const videoCount = items.filter((m) => {
    const mime = (m.file_mime ?? '').toLowerCase();
    const kind = (m.kind ?? '').toUpperCase();
    return kind === 'VIDEO' || mime.startsWith('video/');
  }).length;
  const otherCount = items.length - pdfCount - videoCount;
  return [
    { icon: 'folder', label: t('tutoring2.tutor.materials.kpiTotal'), value: String(items.length) },
    { icon: 'file-text', label: t('tutoring2.tutor.materials.kpiPdf'), value: String(pdfCount), tone: 'brand' },
    { icon: 'video', label: t('tutoring2.tutor.materials.kpiVideo'), value: String(videoCount), tone: 'violet' },
    { icon: 'file', label: t('tutoring2.tutor.materials.kpiOther'), value: String(otherCount), tone: 'slate' },
  ];
});

const headerMeta = computed(() =>
  t('tutoring2.student.materials.meta', { count: sampleMaterials.length }),
);

function onOpen(_material: TutoringMaterial) {
  toast.info(t('tutoring2.common.notAvailable'));
}
function onDownload(_material: TutoringMaterial) {
  toast.info(t('tutoring2.common.notAvailable'));
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.materials.title')"
      :meta="headerMeta"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="4"
      :empty-title="t('tutoring2.student.materials.emptyTitle')"
      :empty-description="t('tutoring2.student.materials.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <!-- TutoringMaterialRow already carries its own rounded surface,
             so the list is a plain stack — no outer wrapper card. -->
        <div class="space-y-2">
          <TutoringMaterialRow
            v-for="m in contentItems"
            :key="m.id"
            :material="m"
            role="student"
            :can-delete="false"
            @open="onOpen"
            @download="onDownload"
          />
        </div>
      </template>
    </AsyncView>
  </div>
</template>
