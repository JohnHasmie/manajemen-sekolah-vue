<!--
  TutorTutoring2MaterialsView.vue — greenfield tutor "Materi" list.

  Composition mirrors the WEB-3 admin screen (BrandPageHeader →
  KpiStripCards → PageFilterToolbar → AsyncView → floating CTA) on the
  tutor palette. Each row is a `TutoringMaterialRow`, which brings its
  own card surface, so the list is a plain vertical stack rather than a
  table inside an outer rounded surface.

  ── History ──

  This screen shipped rendering FOUR HARDCODED SAMPLE MATERIALS, with a
  note saying the backend had no materi CRUD. `/tutoring-v2/materials`
  had in fact existed for some time; what was missing was a file-upload
  route, which arrived separately. A tutor opening this page saw
  materials that did not exist and could not act on any of them.

  It now reads the real index. `file_url` is a SHORT-LIVED signed link
  for anything uploaded through the app (the bucket rejects unsigned
  reads) — open it, never cache or store it.
-->
<script setup lang="ts">
// TODO WEB-4+ add TutoringBimbelService.{listMaterials,createMaterial,deleteMaterial}
// once BE-8 exposes /tutoring-v2/materials. MVP renders a static sample.
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
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
const router = useRouter();
const toast = useToast();

// Static sample so the shape reads before BE-8 lands. Kept realistic so
// KPI counts and filter chips exercise every branch.

// Filters — nominal MVP toggles. Once the real API lands these will
// funnel into query params like the admin screens do.
const programFilter = ref<string>(''); // '' = Semua
const kindFilter = ref<'' | 'pdf' | 'video' | 'doc'>('');

const { state, reload } = useDataRefresh<Material[]>(async () => {
  // Filters are sent to the server rather than applied to a page of
  // results, so a chip narrows the whole set and not just what happens
  // to be loaded.
  const { items } = await MaterialsService.list({
    program_id: programFilter.value || undefined,
    kind: kindFilter.value ? kindFilter.value.toUpperCase() : undefined,
    per_page: 100,
  });
  return items;
});

watch([programFilter, kindFilter], () => reload());

const contentItems = computed<Material[]>(() =>
  state.value.status === 'content' ? (state.value.data as Material[]) : [],
);

const filtered = computed<Material[]>(() => {
  return contentItems.value.filter((m) => {
    if (programFilter.value && m.program_name !== programFilter.value) return false;
    if (kindFilter.value === 'pdf') {
      const isPdf = (m.file_mime ?? '').toLowerCase().includes('pdf')
        || (m.kind ?? '').toUpperCase() === 'PDF';
      if (!isPdf) return false;
    } else if (kindFilter.value === 'video') {
      const isVideo = (m.file_mime ?? '').toLowerCase().startsWith('video/')
        || (m.kind ?? '').toUpperCase() === 'VIDEO';
      if (!isVideo) return false;
    } else if (kindFilter.value === 'doc') {
      const mime = (m.file_mime ?? '').toLowerCase();
      const kind = (m.kind ?? '').toUpperCase();
      const isDoc = mime.includes('word') || mime.includes('officedocument.word')
        || kind === 'DOC' || kind === 'DOCX';
      if (!isDoc) return false;
    }
    return true;
  });
});

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
  t('tutoring2.tutor.materials.meta', { count: contentItems.value.length }),
);

function nextProgramFilter(): string {
  // Cycle: '' → first program in the sample → '' again.
  if (programFilter.value) return '';
  const first = contentItems.value[0]?.program_name ?? '';
  return first;
}

function nextKindFilter(): '' | 'pdf' | 'video' | 'doc' {
  switch (kindFilter.value) {
    case '': return 'pdf';
    case 'pdf': return 'video';
    case 'video': return 'doc';
    default: return '';
  }
}

/**
 * Open in a new tab rather than navigating away: `file_url` is a signed,
 * expiring link, so a back-navigation to a stale one would 403 and read
 * as the file being gone.
 */
function openFile(material: Material) {
  if (!material.file_url) {
    toast.error(t('tutoring2.tutor.materials.noFile'));
    return;
  }
  window.open(material.file_url, '_blank', 'noopener');
}

const onDownload = openFile;
const onOpen = openFile;

async function onDelete(material: Material) {
  try {
    await MaterialsService.destroy(material.id);
    toast.success(t('tutoring2.tutor.materials.deleted'));
    await reload();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring2.common.error'));
  }
}

function goUpload() {
  router.push({ name: 'teacher.tutoring2.material-upload' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.materials.title')"
      :meta="headerMeta"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar>
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.program')"
          :value="programFilter || t('tutoring2.common.all')"
          icon-name="book"
          :active="!!programFilter"
          @click="programFilter = nextProgramFilter()"
        />
        <AppFilterChip
          :label="t('tutoring2.common.type')"
          :value="kindFilter ? kindFilter.toUpperCase() : t('tutoring2.common.all')"
          icon-name="filter"
          :active="!!kindFilter"
          @click="kindFilter = nextKindFilter()"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="4"
      :empty-title="t('tutoring2.tutor.materials.emptyTitle')"
      empty-description="Unggah materi pertama lewat tombol di kanan bawah."
      @retry="reload"
    >
      <!-- TODO i18n key: empty-description for tutor materials -->
      <template #default>
        <!-- TutoringMaterialRow already carries its own rounded surface,
             so the list is a plain stack — no outer wrapper card. -->
        <div class="space-y-2">
          <TutoringMaterialRow
            v-for="m in filtered"
            :key="m.id"
            :material="m"
            role="tutor"
            :can-delete="true"
            @download="onDownload"
            @delete="onDelete"
            @open="onOpen"
          />
        </div>
      </template>
    </AsyncView>

    <button
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="goUpload"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.tutor.materials.uploadCta') }}
    </button>
  </div>
</template>
