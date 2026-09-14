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

  ── The two filter chips ──

  Both were blind toggles with no menu behind them, the same defect a
  tutor reported on the Jadwal screen. They now open a
  <FilterFacetPickerModal>, and each also had a real bug underneath:

  • PROGRAM sent a NAME where the API wants an ID. `nextProgramFilter()`
    set the ref to `contentItems[0].program_name` and the query passed
    that straight into `program_id`, so the server was asked to match a
    uuid column against "Intensif UTBK" — no row could ever come back.
    The client-side predicate then compared the same ref against
    `program_name`, so the two layers disagreed about what the value
    even was. It is a program_id now, end to end, and the options carry
    the NAME as their label. Only the first loaded material's program
    was reachable before; every program is now.

  • TYPE offered three of the five `MaterialKind` values. LINK and IMAGE
    are values the API returns and accepts, and no number of presses
    could ask for either. The list is built from MATERIAL_KINDS.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringMaterialRow from '@/components/tutoring/TutoringMaterialRow.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { MATERIAL_KINDS, materialKindLabel } from '@/lib/material-kind';
import { MaterialsService } from '@/services/tutoring2/materials';
import type { Material, MaterialKind } from '@/types/tutoring2/material';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

// '' = Semua. `programFilter` holds a program_id, NOT a program name.
const programFilter = ref<string>('');
const kindFilter = ref<'' | MaterialKind>('');

const showProgramPicker = ref(false);
const showKindPicker = ref(false);

const { state, reload } = useDataRefresh<Material[]>(async () => {
  // Filters are sent to the server rather than applied to a page of
  // results, so a chip narrows the whole set and not just what happens
  // to be loaded.
  const { items } = await MaterialsService.list({
    program_id: programFilter.value || undefined,
    kind: kindFilter.value || undefined,
    per_page: 100,
  });
  return items;
});

watch([programFilter, kindFilter], () => reload());

const contentItems = computed<Material[]>(() =>
  state.value.status === 'content' ? (state.value.data as Material[]) : [],
);

/**
 * True when a material belongs to `kind`.
 *
 * `m.kind` is the answer whenever the server sent one. The mime sniff
 * stays as a FALLBACK for the three kinds a mime type can attest to,
 * because rows uploaded before `kind` was stored carry an empty one —
 * dropping the sniff would hide those rows from every filter. It is a
 * fallback and not an additional test: a row that already declares
 * `kind: 'LINK'` is a link, whatever its mime says.
 */
function materialIsKind(m: Material, kind: MaterialKind): boolean {
  const declared = String(m.kind ?? '').toUpperCase();
  if (declared) return declared === kind || (kind === 'DOC' && declared === 'DOCX');
  const mime = String(m.file_mime ?? '').toLowerCase();
  if (kind === 'PDF') return mime.includes('pdf');
  if (kind === 'VIDEO') return mime.startsWith('video/');
  if (kind === 'IMAGE') return mime.startsWith('image/');
  if (kind === 'DOC') return mime.includes('word') || mime.includes('officedocument.word');
  // LINK has no mime to sniff — an externally hosted URL carries none.
  return false;
}

const filtered = computed<Material[]>(() => {
  return contentItems.value.filter((m) => {
    // program_id, not program_name: `programFilter` is an id and the
    // server already filtered on it — this only keeps the client honest
    // if a stale page is still on screen.
    if (programFilter.value && m.program_id !== programFilter.value) return false;
    if (kindFilter.value && !materialIsKind(m, kindFilter.value)) return false;
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

// ── Filter facets ───────────────────────────────────────
/**
 * Program options, from ONE unfiltered fetch.
 *
 * Not derived from `contentItems`: once a program is picked the list
 * holds only that program, so the picker would collapse to one row and
 * the tutor could never switch — which is precisely what the old
 * `contentItems[0]` cycle did. Failures leave the list empty and the
 * chip disabled rather than taking the screen down.
 */
const programOptions = ref<FacetOption[]>([]);

async function loadProgramOptions() {
  try {
    const { items } = await MaterialsService.list({ per_page: 100 });
    const byId = new Map<string, string>();
    for (const m of items) {
      if (!m.program_id) continue;
      const existing = byId.get(m.program_id);
      if (!existing || !existing.trim()) {
        byId.set(m.program_id, String(m.program_name ?? '').trim());
      }
    }
    programOptions.value = Array.from(byId.entries())
      .map(([key, label]) => ({ key, label: label || key.slice(0, 8) }))
      .sort((a, b) => a.label.localeCompare(b.label));
  } catch {
    programOptions.value = [];
  }
}

onMounted(loadProgramOptions);

const kindOptions = computed<FacetOption[]>(() =>
  MATERIAL_KINDS.map((value) => ({
    key: value,
    label: materialKindLabel(value, t),
  })),
);

/** Label for the current selection — never a raw uuid. */
function chipValue(selected: string, options: FacetOption[]): string {
  if (!selected) return t('tutoring2.common.all');
  return options.find((o) => o.key === selected)?.label ?? selected.slice(0, 8);
}

const programChipValue = computed(() =>
  chipValue(programFilter.value, programOptions.value),
);

const kindChipValue = computed(() =>
  chipValue(kindFilter.value, kindOptions.value),
);

/** The picker emits a bare string; `kindFilter` is a narrower union. */
function applyKindFilter(value: string) {
  kindFilter.value = (MATERIAL_KINDS as string[]).includes(value)
    ? (value as MaterialKind)
    : '';
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

/** The row's explicit "Unduh" shortcut still goes straight to the file. */
const onDownload = openFile;

/**
 * A row press opens the DETAIL, not the file.
 *
 * `onOpen` used to be `openFile` — the two were literally the same
 * function — so pressing a material's title threw the tutor out of the
 * app into a storage-bucket URL, with no way to read the description,
 * see which group it belongs to, or notice a typo in the title. The
 * detail screen comes first; the file is one press further in, where it
 * can be labelled for what it actually is.
 */
function onOpen(material: Material) {
  router.push({
    name: 'teacher.tutoring2.material-detail',
    params: { id: material.id },
  });
}

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
          :value="programChipValue"
          icon-name="book"
          :active="!!programFilter"
          :disabled="programOptions.length === 0"
          :title="programOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showProgramPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.type')"
          :value="kindChipValue"
          icon-name="filter"
          :active="!!kindFilter"
          @click="showKindPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="4"
      :empty-title="t('tutoring2.tutor.materials.emptyTitle')"
      :empty-description="t('tutoring2.tutor.materials.emptyDescription')"
      @retry="reload"
    >
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

  <!-- Per-facet pickers. Each writes its ref; the existing watcher on
       [program, kind] does the reload, so nothing calls it here. -->
  <FilterFacetPickerModal
    v-if="showProgramPicker"
    :title="t('tutoring2.common.program')"
    :options="programOptions"
    :selected="programFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showProgramPicker = false"
    @apply="(v) => { programFilter = v; }"
  />
  <FilterFacetPickerModal
    v-if="showKindPicker"
    :title="t('tutoring2.common.type')"
    :options="kindOptions"
    :selected="kindFilter"
    :all-label="t('tutoring2.common.all')"
    @close="showKindPicker = false"
    @apply="applyKindFilter"
  />
</template>
