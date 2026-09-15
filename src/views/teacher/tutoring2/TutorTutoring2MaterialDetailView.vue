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

  ── "Kirim ke wali" ──

  Materials are created as DRAFTS — `CreateMaterialAction` does not set
  `published_at` — and `MaterialController@index` hides drafts from
  anyone without `tutoring.material.manage`. That default is on purpose:
  a tutor's own lesson prep should not land in a parent's app the moment
  it is uploaded.

  What was missing was the other half. With no publish route and no
  control, the draft default was permanent, so no wali and no siswa had
  ever seen a single teaching material. This screen now carries the
  send/withdraw pair, and — just as importantly — says in words which of
  the two states a material is in, because a tutor relying on the
  privacy of an unsent material has to be able to see that it is unsent.

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
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import {
  MATERIAL_KINDS,
  materialIsExternalLink,
  materialKindLabel,
  normalizeMaterialKind,
} from '@/lib/material-kind';
import { MaterialsService } from '@/services/tutoring2/materials';
import type { Material } from '@/types/tutoring2/material';

const { t } = useI18n();
const route = useRoute();
const toast = useToast();
const { can } = useMe();

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
 * Has this material been sent to the families?
 *
 * Read from the `is_published` BOOLEAN the resource sends, never
 * re-derived as `Boolean(published_at)`. The two can disagree — the
 * server owns what "sent" means, and a client that recomputes it from a
 * nullable timestamp is one backend change away from showing a tutor
 * the wrong answer about who can see their material. That is not a
 * cosmetic drift: it is the difference between "only I can see this"
 * and "every parent in the group can".
 *
 * The state matters because it decides whether this material exists for
 * anyone but its author. `MaterialController@index` filters
 * `->when(! $canManage, …whereNotNull('published_at'))` and `@show`
 * refuses an unsent row to anyone without `tutoring.material.manage`,
 * so an unsent material is genuinely private to the tutor.
 */
const isPublished = computed(() => material.value?.is_published === true);

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
function openInNewTab(url: string): boolean {
  // Returns whether a tab actually opened. A blocked popup returns null,
  // and the caller must NOT then claim a tab was opened — the tutor would
  // go hunting for a tab that does not exist while the toast says the
  // file is waiting in it. Saying "nothing happened" is worse news and
  // better information.
  return window.open(url, '_blank', 'noopener') != null;
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
    // This is the path almost every real download takes: the bucket is a
    // foreign origin with no CORS configured, so `fetch` refuses. Tell the
    // truth about which of the two outcomes actually happened.
    if (openInNewTab(url)) {
      toast.info(t('tutoring2.tutor.materialDetail.downloadFallback'));
    } else {
      toast.error(t('tutoring2.tutor.materialDetail.downloadBlocked'));
    }
  } finally {
    if (objectUrl) {
      const done = objectUrl;
      setTimeout(() => URL.revokeObjectURL(done), 1000);
    }
    downloading.value = false;
  }
}

/**
 * ── Who may change a material ──
 *
 * `MaterialController@update`, `@destroy`, `@publish` and `@unpublish`
 * all open with `authorize('tutoring.material.manage')`, and that key is
 * read off the /me snapshot through `useMe().can`, which the backend
 * scopes to the ACTIVE ROLE via `X-Active-Role` — never
 * `roles[].permission_keys`, which is unscoped and exists only for the
 * role switcher.
 *
 * The same key therefore gates BOTH the edit affordance and "Kirim ke
 * wali" below.
 *
 * Hidden rather than disabled-with-a-reason, which is the opposite of
 * what the session detail does two files over, and the difference is
 * deliberate. There, `tutoring.session.manage` is absent from the tutor
 * DEFAULTS, so every tutor on a stock tenant sees the control and the
 * explanation is the useful part. Here `tutoring.material.manage` IS in
 * `tutorTutoringDefaults()`: a tutor missing it is one whose centre took
 * it away on purpose, and a permanently dead button explaining a
 * deliberate revocation is just noise on every visit.
 *
 * The ability alone is not the whole gate either way. `update` re-applies
 * the read scope before `findOrFail`, so a material outside this tutor's
 * groups and programmes answers 404 — never 403 — and the catch below
 * surfaces that message as-is rather than guessing at it.
 */
const canManageMaterial = computed(() => can('tutoring.material.manage'));

/**
 * ── "Kirim ke wali" ──
 *
 * The control this screen shipped without, and the reason no wali or
 * siswa had ever seen a teaching material: materials are created as
 * drafts on purpose (lesson prep is not for parents), and until
 * `POST /materials/{id}/publish` existed nothing could lift that.
 *
 * Deliberately NOT behind a confirm dialog. The action is reversible in
 * one press — "Tarik dari wali" clears the column again — and a
 * confirmation on every send would tax the common, correct action to
 * guard against a mistake that costs one more press to undo.
 *
 * Both directions re-read through `reload()` rather than splicing the
 * response in. The response is renderable (the controller re-`load()`s
 * the three relations, unlike `update`), but `file_url` is re-signed per
 * read and the badge must never be able to disagree with the server
 * about who can see this material.
 */
const sharing = ref(false);

async function setSharedWithGuardians(next: boolean) {
  const m = material.value;
  if (!m || sharing.value || !canManageMaterial.value) return;

  sharing.value = true;
  try {
    if (next) {
      await MaterialsService.publish(m.id);
    } else {
      await MaterialsService.unpublish(m.id);
    }
    toast.success(
      t(
        next
          ? 'tutoring2.tutor.materialDetail.sendSuccess'
          : 'tutoring2.tutor.materialDetail.withdrawSuccess',
      ),
    );
    await reload();
  } catch (e) {
    // `writableMaterialOrFail` re-applies the read scope before
    // findOrFail, so a material outside this tutor's groups and
    // programmes answers 404, never 403. The server's message beats a
    // guess, and nothing on screen claims the send landed.
    toast.error((e as Error).message || t('tutoring2.common.saveFailed'));
  } finally {
    sharing.value = false;
  }
}

const editOpen = ref(false);
const saving = ref(false);
const editForm = ref<{ title: string; description: string; kind: string }>({
  title: '',
  description: '',
  kind: 'PDF',
});

/**
 * The kind picker offers the canonical vocabulary. A row already
 * carrying a drifted value (the upload form writes `IMG` where the wire
 * value is `IMAGE`) is shown as an extra option labelled with its raw
 * value, so opening the form does not silently re-file the material
 * under something else the moment it is saved.
 */
const editKindOptions = computed<Array<{ value: string; label: string }>>(() => {
  const options = MATERIAL_KINDS.map((value) => ({
    value: value as string,
    label: materialKindLabel(value, t),
  }));
  const current = editForm.value.kind;
  if (current && !options.some((o) => o.value === current)) {
    options.push({ value: current, label: materialKindLabel(current, t) });
  }
  return options;
});

/** Mirrors `'title' => [..., 'min:3', 'max:200']` so the 422 never happens. */
const canSave = computed(() => {
  const title = editForm.value.title.trim();
  return (
    !saving.value &&
    title.length >= 3 &&
    title.length <= 200 &&
    editForm.value.description.length <= 4000
  );
});

function openEdit() {
  const m = material.value;
  if (!m || !canManageMaterial.value) return;
  editForm.value = {
    title: m.title,
    description: m.description ?? '',
    // Keep the stored value when it is outside the vocabulary rather
    // than normalising it to something the tutor never chose.
    kind: normalizeMaterialKind(m.kind) ?? String(m.kind ?? ''),
  };
  editOpen.value = true;
}

/**
 * Save the three fields this form owns — and only those.
 *
 * `UpdateMaterialRequest::rules()` also accepts `file_url`, `file_name`,
 * `file_size` and `file_mime`, and they are left out ON PURPOSE. The
 * `file_url` a GET hands back is a URL signed against the storage bucket
 * for thirty minutes; writing it back would store the expiring URL
 * permanently and throw away the disk key behind it, leaving a dead link
 * half an hour later. Replacing a file means a real upload
 * (`POST /materials/upload`) and the fresh PATH it returns, which is the
 * upload screen's job, not this dialog's.
 *
 * `learning_group_id` and `program_id` are not in `rules()` at all, so
 * they are not offered either: sending them would answer 200 and change
 * nothing, which is the worst possible outcome for a form.
 *
 * The reload afterwards is not a formality. `update` returns the
 * Action's `fresh()` with no eager loads, and the three `*_name` fields
 * are `whenLoaded` — they are ABSENT from that response, so splicing it
 * into the rendered material would blank the group, programme and
 * uploader lines. `show()` loads them.
 */
async function submitEdit() {
  const m = material.value;
  if (!m || !canSave.value) return;

  saving.value = true;
  try {
    await MaterialsService.update(m.id, {
      title: editForm.value.title.trim(),
      description: editForm.value.description.trim() || null,
      kind: editForm.value.kind,
    });
    editOpen.value = false;
    toast.success(t('tutoring2.tutor.materialDetail.saved'));
    await reload();
  } catch (e) {
    // The server owns the rules and answers 404 for a material outside
    // this tutor's scope. Surfacing its message beats inventing one.
    toast.error((e as Error).message || t('tutoring2.common.saveFailed'));
  } finally {
    saving.value = false;
  }
}

/**
 * The list row's "Ubah" arrives as `?edit=1`, so that button really does
 * edit rather than merely navigating to a screen with an edit button on
 * it. Read once, after the first load resolves — `openEdit()` needs the
 * material to prefill from.
 */
watch(material, (m, previous) => {
  if (!m || previous || String(route.query.edit ?? '') !== '1') return;
  openEdit();
});

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
              <!-- The label names the AUDIENCE, not a publishing
                   state. "Terbit"/"Draf" told a tutor which lifecycle
                   bucket a row sat in; what they actually need to know
                   is whether a parent can open it.

                   `uppercase` is dropped with the rename: it suited a
                   one-word status, but "TERKIRIM KE WALI" set in
                   text-3xs tracking-wider is markedly harder to read
                   than the sentence-case phrase. -->
              <StatusBadge
                data-testid="material-publication"
                :label="isPublished
                  ? t('tutoring2.tutor.materialDetail.shared')
                  : t('tutoring2.tutor.materialDetail.notShared')"
                :tone="isPublished ? 'success' : 'neutral'"
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

              <!-- Only once it has actually been sent. `published_at` is
                   the instant, which is precisely what the resource
                   keeps it around for — `is_published` above decides
                   WHETHER, this says WHEN. -->
              <div v-if="isPublished" class="flex items-start gap-3 py-2">
                <dt class="w-28 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">
                  {{ t('tutoring2.tutor.materialDetail.sentAt') }}
                </dt>
                <dd data-testid="material-sent-at" class="flex-1 text-slate-900">
                  {{ formatDateTime(material.published_at) }}
                </dd>
              </div>
            </dl>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <!-- Hidden, not disabled, for a tutor whose centre revoked
                 `tutoring.material.manage` — see `canManageMaterial`. -->
            <!-- "Kirim ke wali" leads the row: it is the action that
                 decides whether this material exists for anyone but its
                 author, and it outranks editing a title. Only the
                 direction that is actually available is rendered —
                 offering both would leave a tutor guessing which one
                 they are currently in. -->
            <button
              v-if="canManageMaterial && !isPublished"
              type="button"
              data-testid="material-send-to-guardian"
              :class="ACTION_PRIMARY"
              :disabled="sharing"
              @click="setSharedWithGuardians(true)"
            >{{ t('tutoring2.tutor.materialDetail.sendToGuardian') }}</button>
            <button
              v-if="canManageMaterial && isPublished"
              type="button"
              data-testid="material-withdraw-from-guardian"
              :class="ACTION_SECONDARY"
              :disabled="sharing"
              @click="setSharedWithGuardians(false)"
            >{{ t('tutoring2.tutor.materialDetail.withdrawFromGuardian') }}</button>

            <Button
              v-if="canManageMaterial"
              variant="secondary"
              data-testid="material-edit"
              @click="openEdit"
            >{{ t('tutoring2.common.edit') }}</Button>

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

          <!-- Both states get a sentence, because "nothing is shown"
               is not a state a tutor can read. The draft notice is the
               important one: the privacy it describes is the entire
               reason materials are created unsent, and a tutor who does
               not know their prep is private cannot rely on it. -->
          <div
            v-if="!isPublished"
            data-testid="material-draft-notice"
            class="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-xs text-amber-800"
          >
            <span aria-hidden="true">&#9432;</span>
            <p>{{ t('tutoring2.tutor.materialDetail.draftHint') }}</p>
          </div>
          <div
            v-else
            data-testid="material-shared-notice"
            class="flex items-start gap-2 rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2.5 text-xs text-emerald-800"
          >
            <span aria-hidden="true">&#9432;</span>
            <p>{{ t('tutoring2.tutor.materialDetail.sharedHint') }}</p>
          </div>
        </template>
      </template>
    </AsyncView>

    <!-- Title, description and kind — the whole of what the form owns.
         The file, the group and the programme are shown read-only in the
         card above because the API either refuses them or would accept
         them and quietly do the wrong thing; `submitEdit()` carries the
         reasoning. -->
    <Modal
      v-if="editOpen"
      size="md"
      testid="material-edit-modal"
      :title="t('tutoring2.tutor.materialDetail.editTitle')"
      @close="editOpen = false"
    >
      <div class="space-y-md">
        <label class="block space-y-1.5">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.common.title') }}
          </span>
          <input
            v-model="editForm.title"
            data-testid="material-edit-title"
            type="text"
            maxlength="200"
            class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          />
        </label>

        <label class="block space-y-1.5">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.common.description') }}
          </span>
          <textarea
            v-model="editForm.description"
            data-testid="material-edit-description"
            rows="4"
            maxlength="4000"
            class="w-full resize-none rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          />
        </label>

        <label class="block space-y-1.5">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.common.kind') }}
          </span>
          <select
            v-model="editForm.kind"
            data-testid="material-edit-kind"
            class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          >
            <option v-for="opt in editKindOptions" :key="opt.value" :value="opt.value">
              {{ opt.label }}
            </option>
          </select>
        </label>

        <p
          data-testid="material-edit-readonly-note"
          class="rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-2xs text-slate-600"
        >{{ t('tutoring2.tutor.materialDetail.editReadOnlyNote') }}</p>
      </div>

      <BottomSheetFooter
        :primary-label="t('tutoring2.common.save')"
        :secondary-label="t('tutoring2.common.cancel')"
        :primary-loading="saving"
        :primary-disabled="!canSave"
        @primary="submitEdit"
        @secondary="editOpen = false"
      />
    </Modal>
  </div>
</template>
