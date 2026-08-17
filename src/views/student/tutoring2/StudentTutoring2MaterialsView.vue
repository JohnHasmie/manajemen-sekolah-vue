<!--
  StudentTutoring2MaterialsView.vue — Siswa "Materi" list (WEB-5 MVP).

  Composition contract (mirrors WEB-5 exemplar):
    1. BrandPageHeader        — role="student".
    2. KpiStripCards          — 4 tiles (Total / PDF / Video / Lainnya).
    3. AsyncView              — state machine over MaterialsService.list().
       Default slot renders a plain space-y-2 stack of TutoringMaterialRow.

  Read-only — no upload CTA, no delete button. Open and download both
  work: `file_url` is a short-lived signed link, so the row opens it in
  a new tab rather than navigating.
-->
<script setup lang="ts">
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
import { MaterialsService } from '@/services/tutoring2/materials';
import type { Material } from '@/types/tutoring2/material';

const { t } = useI18n();
const toast = useToast();


const { state, reload } = useDataRefresh<Material[]>(async () => {
  // Simulated latency so the loading skeleton reads on cold nav.
  await new Promise((r) => setTimeout(r, 150));
  const { items } = await MaterialsService.list({ per_page: 100 });
  return items;
});

const contentItems = computed<Material[]>(() =>
  state.value.status === 'content' ? (state.value.data as Material[]) : [],
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
  t('tutoring2.student.materials.meta', { count: contentItems.value.length }),
);

/**
 * New tab, not a navigation: `file_url` is a signed, expiring link, so
 * going back to a stale one would 403 and read to a student as the
 * material having been removed.
 */
function onOpen(material: Material) {
  if (!material.file_url) {
    toast.error(t('tutoring2.student.materials.noFile'));
    return;
  }
  window.open(material.file_url, '_blank', 'noopener');
}
/**
 * Download is the same act as open for a signed bucket URL: the browser
 * decides whether to render or save it, and the `download` attribute is
 * ignored cross-origin anyway.
 *
 * This was a `notAvailable` toast sitting next to a working Open button
 * on the same row. The TUTOR materials view had already resolved it the
 * same way — `const onDownload = openFile` — so this was the odd one
 * out rather than a missing capability.
 */
const onDownload = onOpen;
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
