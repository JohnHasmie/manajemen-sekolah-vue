<!--
  TutorTutoring2MaterialDetailView.vue — one bimbel material, read side.

  Composition follows TutorTutoring2SessionDetailView, the nearest tutor
  detail screen: BrandPageHeader → AsyncView over one fetch by id → a
  single rounded-3xl card holding a <dl> → a flat action row.

  ── Why this screen exists ──

  Tapping a material in the Materi list did not open anything belonging
  to this app. The list mapped BOTH of its row events to one function:

      const onDownload = openFile;
      const onOpen = openFile;

  so a title press threw the tutor straight out to a storage-bucket URL.
  There was no way to read a description, see which group or programme a
  material hangs off, check whether it is published, or notice that the
  title has a typo. The product owner asked for the detail FIRST; the
  file is one press further in, where it can be labelled honestly.

  ── Opening the thing, honestly ──

  A LINK and an uploaded FILE are indistinguishable by `file_url`:
  `MaterialResource` signs a stored path into an absolute URL and passes
  an external link through untouched, so both arrive as `https://…`.
  `materialIsExternalLink()` carries the real rule and the reasoning.

  A link gets ONE control — an anchor to the target. A file gets two:
  open, and a download that genuinely tries to save. `<a download>` is
  not an option for the second and it is worth being exact about why,
  because shipping one would be a control that lies: for anything
  uploaded through the app the URL is signed against the storage bucket
  (R2 in production, MinIO in dev), a DIFFERENT ORIGIN from this app, and
  browsers ignore the `download` attribute on a cross-origin href. The
  anchor would navigate instead of saving, silently. See `downloadFile()`.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import {
  materialIsExternalLink,
  materialKindLabel,
} from '@/lib/material-kind';
import { MaterialsService } from '@/services/tutoring2/materials';
import type { Material } from '@/types/tutoring2/material';

const { t } = useI18n();
const route = useRoute();
const toast = useToast();

const materialId = computed<string>(() => String(route.params.id));

/**
 * One row, by id.
 *
 * `useDataRefresh` already registers the academic-year and locale
 * watchers, so nothing here adds its own. A 404 — a deleted material, or
 * one outside this tutor's read scope — REJECTS, which lands on
 * AsyncView's `error` branch rather than a blank panel. The `empty-*`
 * labels below stay for the envelope-without-data case, the same wiring
 * the session detail uses.
 */
const { state, reload } = useDataRefresh(() =>
  MaterialsService.show(materialId.value),
);

const material = computed<Material | null>(() =>
  state.value.status === 'content' ? (state.value.data as Material) : null,
);

const kindText = computed(() =>
  material.value ? materialKindLabel(material.value.kind, t) : '—',
);

const isLink = computed(() =>
  material.value ? materialIsExternalLink(material.value) : false,
);

const fileUrl = computed<string | null>(() => material.value?.file_url ?? null);

const sizeLabel = computed<string | null>(() => {
  const bytes = material.value?.file_size;
  if (bytes == null || bytes <= 0) return null;
  const mb = bytes / 1024 / 1024;
  if (mb >= 0.1) return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`;
  return `${Math.round(bytes / 1024)} KB`;
});

/**
 * `published_at` is surfaced because it decides whether this material
 * exists for anyone but its author: `MaterialController@index` and
 * `@show` hide unpublished rows from students and parents. Read-only —
 * the API has no writer for the column on any endpoint.
 */
const isPublished = computed(() => Boolean(material.value?.published_at));

function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * Open in a NEW TAB rather than navigating away — `file_url` is a
 * short-lived signed link, so a back-navigation to a stale one 403s and
 * reads to the tutor as the file having been deleted.
 *
 * `noopener` is not optional here: the href is a foreign origin (the
 * storage bucket, or whatever host a tutor pasted), and without it that
 * page gets a handle on `window.opener`.
 */
function openInNewTab(url: string) {
  window.open(url, '_blank', 'noopener');
}

const downloading = ref(false);

/**
 * Unduh — a real save where the browser permits one, an open where it
 * does not, and never nothing.
 *
 * The bytes are fetched and saved from a blob, the same shape as
 * `reports.ts#downloadCsv` and `attendance.service.ts#downloadXlsx`.
 * That path needs CORS on the storage bucket, which nothing in the stack
 * configures today, and it cannot work at all for a third-party host. So
 * it is written to FAIL LOUDLY and fall back: `fetch` rejects on a
 * cross-origin read it is not allowed to make, the catch opens the URL
 * in a tab instead, and the toast says so rather than leaving the tutor
 * wondering where the file went.
 *
 * That fallback is the whole point. A download button that quietly does
 * nothing is the defect this screen was written to remove; one that
 * saves when saving is possible and opens when it is not is honest at
 * both ends.
 */
async function downloadFile() {
  const url = fileUrl.value;
  const m = material.value;
  if (!url || !m || downloading.value) return;

  downloading.value = true;
  let objectUrl: string | null = null;
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const blob = await res.blob();
    objectUrl = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = objectUrl;
    a.download = m.file_name ?? m.title;
    document.body.appendChild(a);
    a.click();
    a.remove();
  } catch {
    // Cross-origin refusal, an expired signature, or a host that will
    // not be read programmatically. Opening it still works.
    openInNewTab(url);
    toast.info(t('tutoring2.tutor.materialDetail.downloadFallback'));
  } finally {
    if (objectUrl) {
      const done = objectUrl;
      setTimeout(() => URL.revokeObjectURL(done), 1000);
    }
    downloading.value = false;
  }
}

const headerMeta = computed(() =>
  material.value ? kindText.value : t('tutoring2.common.loading'),
);

/** Shared look for the two anchor-shaped actions — Button renders a <button>. */
const ACTION_BASE =
  'inline-flex items-center justify-center gap-2 rounded-xl px-md py-sm text-sm font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-offset-1';
const ACTION_PRIMARY = `${ACTION_BASE} bg-brand-cobalt text-white hover:opacity-90 focus:ring-brand-cobalt`;
const ACTION_SECONDARY = `${ACTION_BASE} border border-slate-300 text-slate-700 hover:bg-slate-50 focus:ring-slate-400 disabled:opacity-60`;
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.materialDetail.title')"
      :meta="headerMeta"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="1"
      :empty-title="t('tutoring2.tutor.materialDetail.notFound')"
      :empty-description="t('tutoring2.tutor.materialDetail.notFoundHint')"
      :error-title="t('tutoring2.tutor.materialDetail.notFound')"
      @retry="reload"
    >
      <template #default>
        <template v-if="material">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-3">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.title') }}
                </p>
                <h2
                  data-testid="material-title"
                  class="mt-1 text-base font-bold text-slate-900 break-words"
                >{{ material.title }}</h2>
              </div>
              <StatusBadge
                data-testid="material-publication"
                :label="isPublished
                  ? t('tutoring2.tutor.materialDetail.published')
                  : t('tutoring2.tutor.materialDetail.draft')"
                :tone="isPublished ? 'success' : 'neutral'"
                uppercase
              />
            </div>

            <dl class="divide-y divide-slate-100 border-t border-slate-100 pt-3 text-sm">
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.kind') }}
                </dt>
                <dd data-testid="material-kind" class="flex-1 text-slate-900">{{ kindText }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.program') }}
                </dt>
                <dd class="flex-1 text-slate-900">{{ material.program_name || '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.group') }}
                </dt>
                <dd class="flex-1 text-slate-900">{{ material.learning_group_name || '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.common.description') }}
                </dt>
                <dd
                  data-testid="material-description"
                  class="flex-1 whitespace-pre-line text-slate-900"
                >{{ material.description || '—' }}</dd>
              </div>

              <!-- Berkas vs Tautan: the label follows what the row
                   actually is, so an external link is never described as
                   a file the centre holds. -->
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ isLink ? t('tutoring2.tutor.materialDetail.linkLabel') : t('tutoring2.common.file') }}
                </dt>
                <dd data-testid="material-source" class="min-w-0 flex-1 text-slate-900">
                  <span v-if="isLink" class="break-all">{{ fileUrl || '—' }}</span>
                  <template v-else-if="material.file_name || sizeLabel || material.file_mime">
                    <span class="block break-words">{{ material.file_name || '—' }}</span>
                    <span class="block text-2xs text-slate-500">
                      <span v-if="material.file_mime">{{ material.file_mime }}</span>
                      <span v-if="material.file_mime && sizeLabel"> · </span>
                      <span v-if="sizeLabel">{{ sizeLabel }}</span>
                    </span>
                  </template>
                  <span v-else>—</span>
                </dd>
              </div>

              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.tutor.materialDetail.uploadedBy') }}
                </dt>
                <dd class="flex-1 text-slate-900">{{ material.uploaded_by_name || '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.tutor.materialDetail.createdAt') }}
                </dt>
                <dd class="flex-1 text-slate-900">{{ formatDateTime(material.created_at) }}</dd>
              </div>
            </dl>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <!-- LINK: one control, and it is an anchor so the target is
                 visible in the status bar before the press. `noopener
                 noreferrer` because the host is a stranger. -->
            <a
              v-if="isLink && fileUrl"
              data-testid="material-open-link"
              :href="fileUrl"
              target="_blank"
              rel="noopener noreferrer"
              :class="ACTION_PRIMARY"
            >{{ t('tutoring2.tutor.materialDetail.openLink') }}</a>

            <!-- FILE: open, and a download that really tries to save. -->
            <a
              v-if="!isLink && fileUrl"
              data-testid="material-open-file"
              :href="fileUrl"
              target="_blank"
              rel="noopener noreferrer"
              :class="ACTION_PRIMARY"
            >{{ t('tutoring2.tutor.materialDetail.openFile') }}</a>
            <button
              v-if="!isLink && fileUrl"
              type="button"
              data-testid="material-download"
              :class="ACTION_SECONDARY"
              :disabled="downloading"
              @click="downloadFile"
            >{{ t('tutoring2.tutor.materialDetail.download') }}</button>

            <p
              v-if="!fileUrl"
              data-testid="material-no-source"
              class="text-xs text-slate-500"
            >{{ t('tutoring2.tutor.materialDetail.noSource') }}</p>
          </div>

          <div
            v-if="!isPublished"
            data-testid="material-draft-notice"
            class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-xs text-amber-800"
          >
            <span aria-hidden="true">&#9432;</span>
            <p>{{ t('tutoring2.tutor.materialDetail.draftHint') }}</p>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
