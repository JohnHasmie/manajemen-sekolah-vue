<!--
  TutorTutoring2MaterialsView.vue — greenfield tutor "Materi" list.

  Mirrors the WEB-3 admin screen shape (BrandPageHeader → KpiStripCards
  → PageFilterToolbar → AsyncView → floating CTA), but rendered against
  the tutor role palette. Each row is a `TutoringMaterialRow`, which
  already provides its own card surface — so the list is a plain
  vertical stack, NOT a table inside an outer rounded surface.

  Static-sample MVP: `TutoringBimbelService` has no materi CRUD yet
  (BE-8). We render 3-4 realistic rows so downstream reviewers can see
  the composition without waiting on the backend, and wrap the (fake)
  load through `useDataRefresh` so the state-machine path already
  matches what the real fetch will slot into.
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
import type { TutoringMaterial } from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

// Static sample so the shape reads before BE-8 lands. Kept realistic so
// KPI counts and filter chips exercise every branch.
const sampleMaterials: TutoringMaterial[] = [
  {
    id: 'sample-1',
    title: 'Ringkasan Vektor.pdf',
    description: 'Rangkuman materi vektor untuk kelas 10 IPA.',
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
    title: 'Pembahasan TO#3.mp4',
    description: 'Rekaman pembahasan tryout ke-3.',
    file_url: 'https://example.invalid/materials/to3.mp4',
    file_name: 'pembahasan-to-3.mp4',
    file_size_mb: 128,
    file_mime: 'video/mp4',
    kind: 'VIDEO',
    program_label: 'Bimbel SMA · Intensif UTBK',
    created_at: '2026-07-14T05:40:00Z',
  },
  {
    id: 'sample-3',
    title: 'Latihan Listening.pdf',
    description: 'Latihan listening + tautan audio drive.',
    file_url: 'https://example.invalid/materials/listening.pdf',
    file_name: 'latihan-listening.pdf',
    file_size_mb: 0.6,
    file_mime: 'application/pdf',
    kind: 'PDF',
    program_label: 'Bimbel SMP · Bahasa Inggris',
    created_at: '2026-07-16T09:00:00Z',
  },
  {
    id: 'sample-4',
    title: 'Panduan Belajar Mandiri.docx',
    description: 'Panduan belajar mandiri untuk siswa.',
    file_url: 'https://example.invalid/materials/panduan.docx',
    file_name: 'panduan-belajar.docx',
    file_size_mb: 0.3,
    file_mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    kind: 'DOC',
    program_label: 'Bimbel SD · Umum',
    created_at: '2026-07-18T04:10:00Z',
  },
];

// Filters — nominal MVP toggles. Once the real API lands these will
// funnel into query params like the admin screens do.
const programFilter = ref<string>(''); // '' = Semua
const kindFilter = ref<'' | 'pdf' | 'video' | 'doc'>('');

const { state, reload } = useDataRefresh<TutoringMaterial[]>(async () => {
  // Simulated latency so the loading skeleton reads on cold nav.
  await new Promise((r) => setTimeout(r, 150));
  return sampleMaterials;
});

watch([programFilter, kindFilter], () => reload());

const contentItems = computed<TutoringMaterial[]>(() =>
  state.value.status === 'content' ? (state.value.data as TutoringMaterial[]) : [],
);

const filtered = computed<TutoringMaterial[]>(() => {
  return contentItems.value.filter((m) => {
    if (programFilter.value && m.program_label !== programFilter.value) return false;
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
  const first = contentItems.value[0]?.program_label ?? '';
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

function onDownload(_material: TutoringMaterial) {
  toast.info(t('tutoring2.common.notAvailable'));
}
function onOpen(_material: TutoringMaterial) {
  toast.info(t('tutoring2.common.notAvailable'));
}
function onDelete(_material: TutoringMaterial) {
  toast.info(t('tutoring2.common.notAvailable'));
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
