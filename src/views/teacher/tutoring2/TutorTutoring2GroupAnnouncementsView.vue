<!--
  TutorTutoring2GroupAnnouncementsView.vue — Tutor "Announcement"
  surface (WEB-12 / BE-22). Tutor sees only the groups they teach —
  the backend already scopes /tutoring-v2/learning-groups by tutor when
  the active role is tutor, so listGroups() returns their groups only.

  Same compose flow as the admin view; the group picker defaults to
  the first of the tutor's active groups so the modal is one-tap-away
  from typing.

  ── The filter chip ──

  The Kelompok chip opens a <FilterFacetPickerModal>, the same per-facet
  picker the Manajemen Data screens use. Its handler used to be
  `@click="groupFilter = ''"`, which only ever CLEARS. Setting a group was
  possible, but only through a strip of round buttons below the toolbar
  that was `v-if="!groupFilter"` — it VANISHED the moment you used it, so
  the chip that looked like the control was a clear button and the real
  control disappeared after one click. Same fix as
  AdminTutoring2GroupsView (!1191).
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
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
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Modal from '@/components/ui/Modal.vue';
import AppRichTextEditor from '@/components/ui/AppRichTextEditor.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import { useAuthStore } from '@/stores/auth';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
} from '@/services/tutoring-bimbel.service';
import { TutoringAnnouncementsService } from '@/services/tutoring2/announcements';
import {
  announcementStatus,
  type GroupAnnouncement,
  type GroupAnnouncementStatus,
} from '@/types/tutoring2/announcement';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const toast = useToast();
const { confirm } = useConfirm();
const auth = useAuthStore();

const canWrite = computed(() => auth.hasAbility('tutoring.announcement.create'));

const groupFilter = ref<string>(''); // '' = All of tutor's groups
const search = ref('');
const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => { debouncedSearch.value = v; }, 300);
watch(search, (v) => applyDebounced(v));

interface AnnouncementRow extends GroupAnnouncement {
  group_name: string;
}

const groups = ref<BimbelLearningGroup[]>([]);
async function loadGroups() {
  // Tutor scope: BE filters listGroups by tutor when the active role is tutor.
  const { items } = await TutoringBimbelService.listGroups({ per_page: 100 });
  groups.value = items;
}
// Mount-time warm-up so the Kelompok chip has its option list. Swallowed
// on purpose HERE only: the loader below awaits loadGroups() again and a
// real failure still reaches AsyncView through that path, so this call
// must not turn into an unhandled rejection — and must not convert a
// fetch error into a silent "no announcements".
loadGroups().catch(() => {
  /* chip stays disabled; the loader reports the failure */
});

// ── Per-facet picker ───────────────────────────────────────────────
const showGroupPicker = ref(false);

const groupOptions = computed<FacetOption[]>(() =>
  groups.value.map((g) => ({
    key: g.id,
    label: g.name,
    meta: g.program_name ?? undefined,
  })),
);

/**
 * What the chip reads: the picked group's NAME, or "Semua" when unset.
 *
 * Falls back to an id fragment only when the id is genuinely not in the
 * loaded list. A fragment is ugly but honest there — "—" on a chip
 * rendered ACTIVE would read as "no filter applied".
 */
function chipValue(id: string, options: FacetOption[]): string {
  if (!id) return t('tutoring2.common.all');
  return options.find((o) => o.key === id)?.label ?? id.slice(0, 8);
}

const { state, reload } = useDataRefresh<AnnouncementRow[]>(async () => {
  if (groups.value.length === 0) await loadGroups();
  const targets = groupFilter.value
    ? groups.value.filter((g) => g.id === groupFilter.value)
    : groups.value;
  const all: AnnouncementRow[] = [];
  for (const g of targets) {
    const { items } = await TutoringAnnouncementsService.list(g.id, { per_page: 100 });
    for (const ann of items) all.push({ ...ann, group_name: g.name });
  }
  const q = debouncedSearch.value.trim().toLowerCase();
  return all
    .filter((a) => (q ? a.title.toLowerCase().includes(q) : true))
    .sort((a, b) => {
      const bt = b.published_at ?? b.created_at ?? '';
      const at = a.published_at ?? a.created_at ?? '';
      return bt.localeCompare(at);
    });
});
watch([debouncedSearch, groupFilter], () => reload());

const kpiCards = computed<KpiCard[]>(() => {
  const rows = state.value.status === 'content' ? (state.value.data as AnnouncementRow[]) : [];
  const drafts = rows.filter((r) => announcementStatus(r) === 'draft').length;
  const published = rows.filter((r) => announcementStatus(r) === 'published').length;
  return [
    { icon: 'megaphone', label: t('tutoring2.tutor.groupAnnouncements.kpiTotal'), value: String(rows.length) },
    { icon: 'send', label: t('tutoring2.tutor.groupAnnouncements.kpiPublished'), value: String(published) },
    { icon: 'file-pencil', label: t('tutoring2.tutor.groupAnnouncements.kpiDrafts'), value: String(drafts), tone: drafts > 0 ? 'amber' : undefined },
    { icon: 'users', label: t('tutoring2.tutor.groupAnnouncements.kpiGroups'), value: String(groups.value.length) },
  ];
});

function statusTone(s: GroupAnnouncementStatus): StatusBadgeTone {
  switch (s) {
    case 'published': return 'success';
    case 'draft': return 'neutral';
    case 'archived': return 'neutral';
  }
}

function statusLabel(s: GroupAnnouncementStatus): string {
  return t(`tutoring2.status.${s}`);
}

function shortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

// ── Compose modal ─────────────────────────────────────────────────
const showCompose = ref(false);
const composeForm = ref<{ groupId: string; title: string; body: string; publish: boolean }>({
  groupId: '',
  title: '',
  body: '',
  publish: false,
});
const composing = ref(false);

function openCompose() {
  const defaultGroupId = groupFilter.value || groups.value[0]?.id || '';
  composeForm.value = { groupId: defaultGroupId, title: '', body: '', publish: false };
  showCompose.value = true;
}

async function submitCompose() {
  const f = composeForm.value;
  if (!f.groupId) {
    toast.error(t('tutoring2.tutor.groupAnnouncements.pickGroupFirst'));
    return;
  }
  if (f.title.trim().length < 3 || f.body.trim().length < 3) {
    toast.error(t('tutoring2.tutor.groupAnnouncements.validationLen'));
    return;
  }
  if (f.publish) {
    const ok = await confirm({
      title: t('tutoring2.tutor.groupAnnouncements.confirmPublishTitle'),
      message: t('tutoring2.tutor.groupAnnouncements.confirmPublishMsg'),
      confirmLabel: t('tutoring2.tutor.groupAnnouncements.publishCta'),
    });
    if (!ok) return;
  }
  composing.value = true;
  try {
    await TutoringAnnouncementsService.create(f.groupId, {
      title: f.title.trim(),
      body: f.body,
      publish: f.publish,
    });
    toast.success(t('tutoring2.common.saved'));
    showCompose.value = false;
    reload();
  } catch {
    toast.error(t('tutoring2.tutor.groupAnnouncements.saveFailed'));
  } finally {
    composing.value = false;
  }
}

async function publishRow(row: AnnouncementRow) {
  const ok = await confirm({
    title: t('tutoring2.tutor.groupAnnouncements.confirmPublishTitle'),
    message: t('tutoring2.tutor.groupAnnouncements.confirmPublishMsg'),
    confirmLabel: t('tutoring2.tutor.groupAnnouncements.publishCta'),
  });
  if (!ok) return;
  try {
    await TutoringAnnouncementsService.publish(row.learning_group_id, row.id);
    toast.success(t('tutoring2.tutor.groupAnnouncements.publishedToast'));
    reload();
  } catch {
    toast.error(t('tutoring2.tutor.groupAnnouncements.publishFailed'));
  }
}

async function deleteRow(row: AnnouncementRow) {
  const ok = await confirm({
    title: t('tutoring2.tutor.groupAnnouncements.confirmDeleteTitle'),
    message: t('tutoring2.tutor.groupAnnouncements.confirmDeleteMsg'),
    confirmLabel: t('tutoring2.common.delete'),
    danger: true,
  });
  if (!ok) return;
  try {
    await TutoringAnnouncementsService.destroy(row.learning_group_id, row.id);
    toast.success(t('tutoring2.tutor.groupAnnouncements.deletedToast'));
    reload();
  } catch {
    toast.error(t('tutoring2.tutor.groupAnnouncements.deleteFailed'));
  }
}

const previewRow = ref<AnnouncementRow | null>(null);
function openPreview(row: AnnouncementRow) { previewRow.value = row; }

const totalCount = computed(() =>
  state.value.status === 'content' ? (state.value.data as AnnouncementRow[]).length : 0,
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.groupAnnouncements.title')"
      :meta="state.status === 'content'
        ? t('tutoring2.tutor.groupAnnouncements.meta', { count: totalCount })
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar
      v-model:search="search"
      :search-placeholder="t('tutoring2.tutor.groupAnnouncements.searchPh')"
    >
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.group')"
          :value="chipValue(groupFilter, groupOptions)"
          icon-name="users"
          :active="!!groupFilter"
          :disabled="groupOptions.length === 0"
          :title="groupOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showGroupPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="5"
      :empty-title="t('tutoring2.tutor.groupAnnouncements.emptyTitle')"
      :empty-description="t('tutoring2.tutor.groupAnnouncements.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="row in (data as AnnouncementRow[])"
              :key="row.id"
              class="flex items-start gap-3 px-4 py-3 hover:bg-slate-50"
            >
              <div class="min-w-0 flex-1">
                <div class="flex flex-wrap items-center gap-2">
                  <p class="truncate text-sm font-bold text-slate-900">{{ row.title }}</p>
                  <StatusBadge
                    :label="statusLabel(announcementStatus(row))"
                    :tone="statusTone(announcementStatus(row))"
                    uppercase
                  />
                </div>
                <p class="mt-1 text-2xs text-slate-500">
                  {{ row.group_name }} · {{ shortDate(row.published_at ?? row.created_at) }}
                </p>
              </div>
              <div class="flex shrink-0 flex-col items-end gap-1">
                <button
                  type="button"
                  class="text-2xs font-bold text-brand-cobalt hover:underline"
                  @click="openPreview(row)"
                >
                  {{ t('tutoring2.common.detail') }}
                </button>
                <button
                  v-if="canWrite && announcementStatus(row) === 'draft'"
                  type="button"
                  class="text-2xs font-bold text-emerald-600 hover:underline"
                  @click="publishRow(row)"
                >
                  {{ t('tutoring2.tutor.groupAnnouncements.publishCta') }}
                </button>
                <button
                  v-if="canWrite"
                  type="button"
                  class="text-2xs font-bold text-red-600 hover:underline"
                  @click="deleteRow(row)"
                >
                  {{ t('tutoring2.common.delete') }}
                </button>
              </div>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>

    <button
      v-if="canWrite"
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openCompose"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.tutor.groupAnnouncements.composeCta') }}
    </button>

    <!-- Compose modal -->
    <Modal
      v-if="showCompose"
      size="xl"
      :title="t('tutoring2.tutor.groupAnnouncements.composeTitle')"
      :subtitle="t('tutoring2.tutor.groupAnnouncements.composeSubtitle')"
      @close="showCompose = false"
    >
      <div class="space-y-md">
        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.common.group') }}
          </span>
          <select
            v-model="composeForm.groupId"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          >
            <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
          </select>
        </label>

        <label class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.common.title') }}
          </span>
          <input
            v-model="composeForm.title"
            type="text"
            :placeholder="t('tutoring2.tutor.groupAnnouncements.titlePh')"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>

        <div>
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.tutor.groupAnnouncements.body') }}
          </span>
          <div class="mt-1">
            <AppRichTextEditor
              v-model:html="composeForm.body"
              :placeholder="t('tutoring2.tutor.groupAnnouncements.bodyPh')"
              :min-height="220"
            />
          </div>
        </div>

        <label class="flex items-center gap-2">
          <input v-model="composeForm.publish" type="checkbox" class="rounded border-slate-300" />
          <span class="text-sm text-slate-600">
            {{ t('tutoring2.tutor.groupAnnouncements.publishImmediately') }}
          </span>
        </label>
      </div>

      <BottomSheetFooter
        :primary-label="composeForm.publish
          ? t('tutoring2.tutor.groupAnnouncements.publishCta')
          : t('tutoring2.tutor.groupAnnouncements.saveDraftCta')"
        :secondary-label="t('tutoring2.common.cancel')"
        :primary-loading="composing"
        @primary="submitCompose"
        @secondary="showCompose = false"
      />
    </Modal>

    <!-- Preview modal -->
    <Modal
      v-if="previewRow"
      size="lg"
      :title="previewRow.title"
      :subtitle="previewRow.group_name"
      @close="previewRow = null"
    >
      <article class="prose prose-sm max-w-none text-slate-700" v-html="previewRow.body" />
      <div class="mt-md flex items-center justify-between text-2xs text-slate-500">
        <span>{{ previewRow.author_name ?? '—' }}</span>
        <span>{{ shortDate(previewRow.published_at ?? previewRow.created_at) }}</span>
      </div>
      <BottomSheetFooter
        :primary-label="t('tutoring2.common.back')"
        @primary="previewRow = null"
      />
    </Modal>

    <!-- Per-facet picker. It writes its ref; the existing watcher on
         [search, group] does the reload, so nothing calls it here. -->
    <FilterFacetPickerModal
      v-if="showGroupPicker"
      :title="t('tutoring2.common.group')"
      :options="groupOptions"
      :selected="groupFilter"
      :all-label="t('tutoring2.common.all')"
      @close="showGroupPicker = false"
      @apply="(v) => { groupFilter = v; }"
    />
  </div>
</template>
