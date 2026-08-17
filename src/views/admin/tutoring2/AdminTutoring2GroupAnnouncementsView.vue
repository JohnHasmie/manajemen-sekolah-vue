<!--
  AdminTutoring2GroupAnnouncementsView.vue — greenfield "Announcement
  Kelompok" admin surface (WEB-12 / BE-22).

  Same skeleton as the other admin tutoring2 views (BrandPageHeader →
  KpiStripCards → PageFilterToolbar → AsyncView → table → floating "+
  Compose" CTA). Data comes from the nested endpoint, so admin loads
  ALL groups first and then fans out one list() per group. That's fine
  for the MVP tenant sizes; when it becomes a hot path, BE can expose
  a flat `/tutoring-v2/announcements?school_id` and this loader
  collapses to one call.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
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

// ── Filters (chip dropdown + status) ───────────────────────────────
const search = ref('');
const groupFilter = ref<string>(''); // '' = All groups
const statusFilter = ref<'' | GroupAnnouncementStatus>('');

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

interface AnnouncementRow extends GroupAnnouncement {
  group_name: string;
}

// ── Loader: groups first, then announcements per group ─────────────
const { state, reload } = useDataRefresh<AnnouncementRow[]>(async () => {
  const { items: groups } = await TutoringBimbelService.listGroups({ per_page: 100 });
  const targets: BimbelLearningGroup[] = groupFilter.value
    ? groups.filter((g) => g.id === groupFilter.value)
    : groups;

  const all: AnnouncementRow[] = [];
  for (const g of targets) {
    // Fetch drafts+published for admin (no `published` filter).
    const { items } = await TutoringAnnouncementsService.list(g.id, { per_page: 100 });
    for (const ann of items) {
      all.push({ ...ann, group_name: g.name });
    }
  }

  // Client-side filters: status + search-in-title.
  const q = debouncedSearch.value.trim().toLowerCase();
  return all
    .filter((a) => (statusFilter.value ? announcementStatus(a) === statusFilter.value : true))
    .filter((a) => (q ? a.title.toLowerCase().includes(q) : true))
    .sort((a, b) => {
      const bt = b.published_at ?? b.created_at ?? '';
      const at = a.published_at ?? a.created_at ?? '';
      return bt.localeCompare(at);
    });
});

watch([debouncedSearch, groupFilter, statusFilter], () => reload());

// ── Groups for the compose form + filter dropdown ──────────────────
const groups = ref<BimbelLearningGroup[]>([]);
async function loadGroups() {
  const { items } = await TutoringBimbelService.listGroups({ per_page: 100, status: 'active' });
  groups.value = items;
}
loadGroups();

// ── KPI strip ──────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const rows = state.value.status === 'content' ? (state.value.data as AnnouncementRow[]) : [];
  const drafts = rows.filter((r) => announcementStatus(r) === 'draft').length;
  const published = rows.filter((r) => announcementStatus(r) === 'published').length;
  const uniqueGroups = new Set(rows.map((r) => r.learning_group_id)).size;
  return [
    { icon: 'megaphone', label: t('tutoring2.admin.groupAnnouncements.kpiTotal'), value: String(rows.length) },
    { icon: 'send', label: t('tutoring2.admin.groupAnnouncements.kpiPublished'), value: String(published) },
    { icon: 'file-pencil', label: t('tutoring2.admin.groupAnnouncements.kpiDrafts'), value: String(drafts), tone: drafts > 0 ? 'amber' : undefined },
    { icon: 'users', label: t('tutoring2.admin.groupAnnouncements.kpiGroupsCovered'), value: String(uniqueGroups) },
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

// ── Compose modal ──────────────────────────────────────────────────
const showCompose = ref(false);
const composeForm = ref<{ groupId: string; title: string; body: string; publish: boolean }>({
  groupId: '',
  title: '',
  body: '',
  publish: false,
});
const composing = ref(false);

function openCompose() {
  composeForm.value = { groupId: groups.value[0]?.id ?? '', title: '', body: '', publish: false };
  showCompose.value = true;
}

async function submitCompose() {
  const f = composeForm.value;
  if (!f.groupId) {
    toast.error(t('tutoring2.admin.groupAnnouncements.pickGroupFirst'));
    return;
  }
  if (f.title.trim().length < 3 || f.body.trim().length < 3) {
    toast.error(t('tutoring2.admin.groupAnnouncements.validationLen'));
    return;
  }
  if (f.publish) {
    const ok = await confirm({
      title: t('tutoring2.admin.groupAnnouncements.confirmPublishTitle'),
      message: t('tutoring2.admin.groupAnnouncements.confirmPublishMsg'),
      confirmLabel: t('tutoring2.admin.groupAnnouncements.publishCta'),
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
  } catch (e) {
    toast.error(t('tutoring2.admin.groupAnnouncements.saveFailed'));
  } finally {
    composing.value = false;
  }
}

// ── Publish existing draft ─────────────────────────────────────────
async function publishRow(row: AnnouncementRow) {
  const ok = await confirm({
    title: t('tutoring2.admin.groupAnnouncements.confirmPublishTitle'),
    message: t('tutoring2.admin.groupAnnouncements.confirmPublishMsg'),
    confirmLabel: t('tutoring2.admin.groupAnnouncements.publishCta'),
  });
  if (!ok) return;
  try {
    await TutoringAnnouncementsService.publish(row.learning_group_id, row.id);
    toast.success(t('tutoring2.admin.groupAnnouncements.publishedToast'));
    reload();
  } catch (e) {
    toast.error(t('tutoring2.admin.groupAnnouncements.publishFailed'));
  }
}

// ── Delete ─────────────────────────────────────────────────────────
async function deleteRow(row: AnnouncementRow) {
  const ok = await confirm({
    title: t('tutoring2.admin.groupAnnouncements.confirmDeleteTitle'),
    message: t('tutoring2.admin.groupAnnouncements.confirmDeleteMsg'),
    confirmLabel: t('tutoring2.common.delete'),
    danger: true,
  });
  if (!ok) return;
  try {
    await TutoringAnnouncementsService.destroy(row.learning_group_id, row.id);
    toast.success(t('tutoring2.admin.groupAnnouncements.deletedToast'));
    reload();
  } catch (e) {
    toast.error(t('tutoring2.admin.groupAnnouncements.deleteFailed'));
  }
}

// ── Preview modal ──────────────────────────────────────────────────
const previewRow = ref<AnnouncementRow | null>(null);
function openPreview(row: AnnouncementRow) {
  previewRow.value = row;
}

const totalCount = computed(() =>
  state.value.status === 'content' ? (state.value.data as AnnouncementRow[]).length : 0,
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.groupAnnouncements.title')"
      :meta="state.status === 'content'
        ? t('tutoring2.admin.groupAnnouncements.meta', { count: totalCount })
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar
      v-model:search="search"
      :search-placeholder="t('tutoring2.admin.groupAnnouncements.searchPh')"
    >
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.group')"
          :value="groupFilter
            ? (groups.find((g) => g.id === groupFilter)?.name ?? groupFilter.slice(0, 8))
            : t('tutoring2.common.all')"
          icon-name="users"
          :active="!!groupFilter"
          @click="groupFilter = ''"
        />
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter ? statusLabel(statusFilter) : t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = ''"
        />
      </template>
    </PageFilterToolbar>

    <!-- Group quick-pick strip when the dropdown chip isn't set -->
    <div v-if="!groupFilter && groups.length > 0" class="flex flex-wrap gap-2">
      <button
        v-for="g in groups"
        :key="g.id"
        type="button"
        class="rounded-full border border-slate-200 px-3 py-1 text-2xs font-bold text-slate-600 hover:border-brand-cobalt hover:text-brand-cobalt"
        @click="groupFilter = g.id"
      >
        {{ g.name }}
      </button>
    </div>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.groupAnnouncements.emptyTitle')"
      :empty-description="t('tutoring2.admin.groupAnnouncements.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.title') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.group') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.groupAnnouncements.author') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.groupAnnouncements.publishedAt') }}</th>
                <th class="px-4 py-3 font-bold text-right">{{ t('tutoring2.admin.groupAnnouncements.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in (data as AnnouncementRow[])"
                :key="row.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ row.title }}</td>
                <td class="px-4 py-3 text-slate-600">{{ row.group_name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ row.author_name ?? '—' }}</td>
                <td class="px-4 py-3">
                  <StatusBadge
                    :label="statusLabel(announcementStatus(row))"
                    :tone="statusTone(announcementStatus(row))"
                    uppercase
                  />
                </td>
                <td class="px-4 py-3 text-slate-500 text-2xs">{{ shortDate(row.published_at) }}</td>
                <td class="px-4 py-3 text-right whitespace-nowrap">
                  <button
                    type="button"
                    class="text-2xs font-bold text-brand-cobalt hover:underline mr-3"
                    @click="openPreview(row)"
                  >
                    {{ t('tutoring2.common.detail') }}
                  </button>
                  <button
                    v-if="canWrite && announcementStatus(row) === 'draft'"
                    type="button"
                    class="text-2xs font-bold text-emerald-600 hover:underline mr-3"
                    @click="publishRow(row)"
                  >
                    {{ t('tutoring2.admin.groupAnnouncements.publishCta') }}
                  </button>
                  <button
                    v-if="canWrite"
                    type="button"
                    class="text-2xs font-bold text-red-600 hover:underline"
                    @click="deleteRow(row)"
                  >
                    {{ t('tutoring2.common.delete') }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      v-if="canWrite"
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openCompose"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.groupAnnouncements.composeCta') }}
    </button>

    <!-- ── Compose modal ────────────────────────────────────────── -->
    <Modal
      v-if="showCompose"
      size="xl"
      :title="t('tutoring2.admin.groupAnnouncements.composeTitle')"
      :subtitle="t('tutoring2.admin.groupAnnouncements.composeSubtitle')"
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
            :placeholder="t('tutoring2.admin.groupAnnouncements.titlePh')"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          />
        </label>

        <div>
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.admin.groupAnnouncements.body') }}
          </span>
          <div class="mt-1">
            <AppRichTextEditor
              v-model:html="composeForm.body"
              :placeholder="t('tutoring2.admin.groupAnnouncements.bodyPh')"
              :min-height="220"
            />
          </div>
        </div>

        <label class="flex items-center gap-2">
          <input v-model="composeForm.publish" type="checkbox" class="rounded border-slate-300" />
          <span class="text-sm text-slate-600">
            {{ t('tutoring2.admin.groupAnnouncements.publishImmediately') }}
          </span>
        </label>
      </div>

      <BottomSheetFooter
        :primary-label="composeForm.publish
          ? t('tutoring2.admin.groupAnnouncements.publishCta')
          : t('tutoring2.admin.groupAnnouncements.saveDraftCta')"
        :secondary-label="t('tutoring2.common.cancel')"
        :primary-loading="composing"
        @primary="submitCompose"
        @secondary="showCompose = false"
      />
    </Modal>

    <!-- ── Preview modal ────────────────────────────────────────── -->
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
  </div>
</template>
