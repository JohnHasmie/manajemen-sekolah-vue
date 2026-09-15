<!--
  ParentTutoring2MaterialsView.vue — Wali "Bahan Ajar".

  ── What this closes ──

  Tutors gained "Kirim ke wali" (`POST /materials/{id}/publish`), but a
  wali had nowhere to read what was sent. The material existed, it was
  published, and no screen in this app listed it. This is that screen.

  ── Why it is FLAT and not `/:studentId` like its siblings ──

  Most per-child wali screens are `parent/tutoring2/<thing>/:studentId`.
  This one deliberately is not, for two reasons that are properties of
  the endpoint rather than preferences:

   1. `/tutoring-v2/materials` has NO student dimension. Its filters are
      `learning_group_id`, `program_id` and `kind` (see
      `MaterialListParams`) — there is no `student_id` to send. A
      `:studentId` in the path would be a parameter the request could
      not carry, which is the shape of a control that lies.

   2. The wali read scope is a UNION, not a per-child narrowing.
      `MaterialController::applyReadScope` resolves to
      `learning_group_id IN (children's groups) OR program_id IN
      (children's programmes)`. A material pinned to a PROGRAMME has
      `learning_group_id = null` — `StoreMaterialRequest` requires one
      of the pair, not both — so it belongs to no single child's group.
      Filtering this screen down to one child's group would silently
      drop every programme-level material: a whole legitimate category,
      gone, with nothing on screen to say so.

  That matches what the wali menu already does for the same reason:
  Tagihan and Riwayat are param-free because "routing it through the
  child picker would NARROW a screen that is meant to be consolidated",
  and the announcements feed is child-agnostic because the server
  derives the children itself.

  ── Telling two children apart anyway ──

  A consolidated list is not an undifferentiated one. Rows are bucketed
  by where the material is pinned — the child's learning group, or the
  programme — using `learning_group_name` / `program_name`, which the
  index already eager-loads (`learningGroup:id,name`, `program:id,name`)
  and denormalises onto every row. So a wali with two children in
  different groups reads two labelled sections, at no extra request.
  Same idiom as `ParentTutoring2GroupAnnouncementsView`.

  ── What a wali can and cannot see ──

  `MaterialController@index` applies `whereNotNull('published_at')` to
  any caller without `tutoring.material.manage`. A wali holds only
  `tutoring.material.view`, so unsent drafts never reach this list. That
  filter is the SERVER'S, and it is not re-implemented here — re-deriving
  it client-side would be a second opinion about a decision that is not
  ours to make.

  For the same reason `TutoringMaterialRow` gets `role="parent"` and its
  "Terkirim ke wali" pill stays gated to `role === 'tutor'`: every row a
  wali can see is by construction one that was sent, so the badge would
  be a constant rather than information.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import TutoringMaterialRow from '@/components/tutoring/TutoringMaterialRow.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { materialIsExternalLink } from '@/lib/material-kind';
import { downloadMaterialFile, openMaterialInNewTab } from '@/lib/material-open';
import { MaterialsService } from '@/services/tutoring2/materials';
import type { Material } from '@/types/tutoring2/material';

const { t } = useI18n();
const toast = useToast();

/** One labelled section: the group or programme the rows are pinned to. */
interface MaterialBucket {
  key: string;
  label: string;
  items: Material[];
}

const { state, reload } = useDataRefresh<Material[]>(async () => {
  // No `learning_group_id` filter is sent on purpose. The server already
  // scopes the list to this wali's children; adding a client filter on
  // top would narrow it to ONE group and hide the programme-pinned rows
  // (see the header docblock).
  const { items } = await MaterialsService.list({ per_page: 100 });
  return items;
});

const contentItems = computed<Material[]>(() =>
  state.value.status === 'content' ? (state.value.data as Material[]) : [],
);

const headerMeta = computed(() =>
  state.value.status === 'content'
    ? t('tutoring2.parent.materials.meta', { count: contentItems.value.length })
    : t('tutoring2.common.loading'),
);

/**
 * Bucket by where the material is pinned.
 *
 * No sorting happens here, and none is needed: the server already orders
 * `published_at desc, created_at desc`, a `Map` preserves insertion
 * order, and a bucket is created at the first row that belongs to it. So
 * rows stay newest-first inside each section, and the sections
 * themselves come out ordered by their own newest row — both properties
 * inherited from the server's ORDER BY rather than re-imposed here.
 *
 * The fallback label matters: a material can legitimately carry neither
 * name — a programme-pinned row whose programme relation did not load —
 * and dropping those rows to make the grouping tidy would hide a
 * material a tutor actually sent. They go in a clearly-named section
 * instead.
 */
const buckets = computed<MaterialBucket[]>(() => {
  const byKey = new Map<string, MaterialBucket>();
  for (const m of contentItems.value) {
    const label =
      m.learning_group_name?.trim() ||
      m.program_name?.trim() ||
      t('tutoring2.parent.materials.ungroupedLabel');
    const existing = byKey.get(label);
    if (existing) existing.items.push(m);
    else byKey.set(label, { key: label, label, items: [m] });
  }
  return [...byKey.values()];
});

/** A single section needs no section header — the page title already says it. */
const showBucketHeaders = computed(() => buckets.value.length > 1);

/**
 * Open — a new TAB, never a navigation. `file_url` is a short-lived
 * signed link (30 minutes), so a back-navigation to a stale one 403s and
 * reads to a wali as the material having been removed.
 *
 * A blocked popup is reported as such. Claiming a tab opened when none
 * did sends a wali hunting for a tab that does not exist.
 */
function onOpen(material: Material) {
  if (!material.file_url) {
    toast.error(t('tutoring2.parent.materials.noFile'));
    return;
  }
  if (!openMaterialInNewTab(material.file_url)) {
    toast.error(t('tutoring2.parent.materials.openBlocked'));
  }
}

/**
 * Unduh — a real save where the browser permits one, an open where it
 * does not, and never nothing.
 *
 * An externally-hosted link has nothing to save, so it goes straight to
 * open; `materialIsExternalLink` owns that rule (and why `file_url`
 * alone cannot answer it). For an uploaded file the blob path is tried
 * first and falls back to opening when the bucket refuses the
 * cross-origin read — which, with no CORS configured anywhere in this
 * stack, is the path nearly every real download takes.
 */
async function onDownload(material: Material) {
  const url = material.file_url;
  if (!url) {
    toast.error(t('tutoring2.parent.materials.noFile'));
    return;
  }

  if (materialIsExternalLink(material)) {
    if (!openMaterialInNewTab(url)) {
      toast.error(t('tutoring2.parent.materials.openBlocked'));
    }
    return;
  }

  const outcome = await downloadMaterialFile(url, material.file_name);
  if (outcome === 'opened') {
    toast.info(t('tutoring2.parent.materials.downloadFallback'));
  } else if (outcome === 'blocked') {
    toast.error(t('tutoring2.parent.materials.downloadBlocked'));
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.common.roleParent')"
      :title="t('tutoring2.parent.materials.title')"
      :meta="headerMeta"
    />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="4"
      :empty-title="t('tutoring2.parent.materials.emptyTitle')"
      :empty-description="t('tutoring2.parent.materials.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="space-y-md">
          <section
            v-for="bucket in buckets"
            :key="bucket.key"
            class="space-y-2"
            data-testid="material-bucket"
          >
            <header
              v-if="showBucketHeaders"
              class="flex items-center gap-2 px-1"
            >
              <span
                class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-azure/10 text-brand-azure"
              >
                <NavIcon name="users" />
              </span>
              <h3 class="text-sm font-bold text-tutoring-text-hi">{{ bucket.label }}</h3>
              <span class="text-2xs text-tutoring-text-mid">
                {{ t('tutoring2.parent.materials.countLabel', { count: bucket.items.length }) }}
              </span>
            </header>

            <!-- TutoringMaterialRow carries its own rounded surface, so
                 the list is a plain stack — no outer wrapper card. -->
            <div class="space-y-2">
              <TutoringMaterialRow
                v-for="m in bucket.items"
                :key="m.id"
                :material="m"
                role="parent"
                :can-delete="false"
                :can-edit="false"
                @open="onOpen"
                @download="onDownload"
              />
            </div>
          </section>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
