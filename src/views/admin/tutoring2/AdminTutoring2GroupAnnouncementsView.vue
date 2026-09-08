<!--
  AdminTutoring2GroupAnnouncementsView.vue — greenfield "Announcement
  Kelompok" admin surface (WEB-12 / BE-22).

  Same skeleton as the other admin tutoring2 views (BrandPageHeader →
  KpiStripCards → PageFilterToolbar → AsyncView → table → floating "+
  Compose" CTA).

  ── The fan-out is gone ──

  This header used to promise that when BE exposed a flat
  `/tutoring-v2/announcements`, the loader would collapse from "load ALL
  groups, then one nested GET per group" to one call. BE !856 shipped it,
  and this is that collapse.

  It was never only a performance change. A tutor-addressed announcement
  has NO `learning_group_id`, and the nested route filters
  `where('learning_group_id', {groupId})` — so a group-less row could not
  appear in the fan-out whatever ids we iterated. The fan-out was a
  reader that structurally could not see half the table.

  One `listGroups` call survives, and only to resolve group NAMES: the
  flat resource emits `learning_group_id` but no group name (the
  controller eager-loads `learningGroup:id,name`, but
  GroupAnnouncementResource never serialises it).

  ── Two audiences ──

  Rows now carry `audience` + `audience_label`. `learning_group_id` is
  NULLABLE and null on every `audience: "tutor"` row, so nothing here may
  push it into a URL segment or a name lookup without checking first.
  Publish/delete therefore go through the FLAT `publishById`/`destroyById`
  rather than the nested twins, which would build
  `/learning-groups/null/announcements/…`.

  ── The filter chips ──

  Both chips now open a <FilterFacetPickerModal>, the same per-facet
  picker the Manajemen Data screens use. Before, both handlers were
  `@click="xFilter = ''"`, which only ever CLEARS:

    - Status was therefore INERT. Nothing on the page could put a value
      into it, so an admin could never narrow to Draft or Terbit.
    - Kelompok was reachable, but only through a strip of round buttons
      below the toolbar that was `v-if="!groupFilter"` — it VANISHED the
      moment you used it, so the chip that looked like the control was a
      clear button and the real control disappeared after one click.

  Part of the "semua button/filter tdk berfungsi" report a bimbel admin
  filed on prod. Same fix as AdminTutoring2GroupsView (!1191).
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
  isTutorAudience,
  type AnnouncementAudience,
  type GroupAnnouncement,
  type GroupAnnouncementStatus,
} from '@/types/tutoring2/announcement';
import type { StatusBadgeTone } from '@/types/status-badge';

/** The three states an announcement can be in. Fixed vocabulary — the
 *  status picker needs no fetch, which is why its chip is never
 *  disabled. */
const ANNOUNCEMENT_STATUSES: GroupAnnouncementStatus[] = ['draft', 'published', 'archived'];

const { t } = useI18n();
const toast = useToast();
const { confirm } = useConfirm();
const auth = useAuthStore();

const canWrite = computed(() => auth.hasAbility('tutoring.announcement.create'));

/**
 * May this admin address a broadcast to EVERY tutor on the tenant?
 *
 * Mirrors the server's gate exactly, which is two keys, not one:
 * `AnnouncementController::store` calls
 * `authorize('tutoring.announcement.create')` and THEN
 * `abort_unless(seesEveryTutoringRow(...), 403)`, and
 * `seesEveryTutoringRow` resolves to `tutoring.tutor.view`.
 *
 * The second key is the load-bearing one: `tutoring.announcement.create`
 * is held by tutors too (for their own groups), so gating this
 * affordance on it alone would show every tutor a compose control the
 * server answers with a 403.
 *
 * Read off /me abilities — never `roles[].permission_keys`, which is
 * unscoped and exists only for the role switcher.
 */
const canComposeTutorAudience = computed(
  () => canWrite.value && auth.hasAbility('tutoring.tutor.view'),
);

/**
 * May this caller publish/delete THIS row?
 *
 * A tutor-addressed row is admin-only to act on — the server pins a
 * non-admin to `audience = 'learning_group'` in
 * `writableAnnouncementOrFail` and answers anything else with a 404. A
 * button that 404s is exactly the "control that advertises an action it
 * cannot perform" this repo keeps shipping, so the row-level check has
 * to be per-audience rather than a single page-level `canWrite`.
 */
function canManageRow(row: GroupAnnouncement): boolean {
  return isTutorAudience(row) ? canComposeTutorAudience.value : canWrite.value;
}

/**
 * The row's audience, as text.
 *
 * Prefers the SERVER's `audience_label` over anything derived here, so
 * the day the backend gains a third audience this screen names it
 * correctly without a FE change. The local fallback covers only a
 * response that predates BE !856 and carries neither key.
 */
function audienceLabel(row: GroupAnnouncement): string {
  if (row.audience_label) return row.audience_label;
  return isTutorAudience(row)
    ? t('tutoring2.admin.groupAnnouncements.audienceTutor')
    : t('tutoring2.admin.groupAnnouncements.audienceGroup');
}

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
  /**
   * Resolved group name, or null. Null for BOTH a tutor-addressed row
   * (no group exists) and a group whose name we could not resolve (it
   * fell outside the 100 we loaded, or was deleted after the
   * announcement was posted). The template must not assume a string.
   */
  group_name: string | null;
}

// ── Loader: ONE flat list + one group call for names ───────────────
const { state, reload } = useDataRefresh<AnnouncementRow[]>(async () => {
  const [groupsRes, annRes] = await Promise.all([
    // Names only — NOT a fetch plan. Deliberately unfiltered by status so
    // an announcement posted to a group that has since been archived
    // still renders its name instead of a dash.
    TutoringBimbelService.listGroups({ per_page: 100 }),
    TutoringAnnouncementsService.listAll({
      per_page: 100,
      // Pushed to the server rather than filtered here. Note this
      // correctly EXCLUDES tutor-addressed rows: they belong to no
      // group, so "show me group X" cannot mean "and also the
      // tenant-wide broadcasts".
      ...(groupFilter.value ? { learning_group_id: groupFilter.value } : {}),
      // No `published` filter: an admin manages drafts here.
    }),
  ]);

  const names = new Map<string, string>(
    groupsRes.items.map((g: BimbelLearningGroup) => [g.id, g.name]),
  );

  const all: AnnouncementRow[] = annRes.items.map((ann) => ({
    ...ann,
    // Null-safe on BOTH sides: a tutor row has no id to look up, and a
    // group id may not be in the loaded page.
    group_name: ann.learning_group_id ? (names.get(ann.learning_group_id) ?? null) : null,
  }));

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

// ── Groups for the compose form + filter picker ────────────────────
// One list serves both. Tolerant on purpose: this list decides whether
// the Kelompok chip is usable, so a failing or ability-gated endpoint
// must leave a disabled chip with a hover reason, not an unhandled
// rejection and a chip that opens an empty menu.
const groups = ref<BimbelLearningGroup[]>([]);
async function loadGroups() {
  const [res] = await Promise.allSettled([
    TutoringBimbelService.listGroups({ per_page: 100, status: 'active' }),
  ]);
  if (res.status === 'fulfilled') groups.value = res.value.items;
}
loadGroups();

// ── Per-facet pickers ──────────────────────────────────────────────
const showGroupPicker = ref(false);
const showStatusPicker = ref(false);

const groupOptions = computed<FacetOption[]>(() =>
  groups.value.map((g) => ({
    key: g.id,
    label: g.name,
    meta: g.program_name ?? undefined,
  })),
);
const statusOptions = computed<FacetOption[]>(() =>
  ANNOUNCEMENT_STATUSES.map((s) => ({ key: s, label: statusLabel(s) })),
);

/**
 * What a filter chip reads: the picked option's NAME, or "Semua" when the
 * facet is unset.
 *
 * Falls back to an id fragment only when the id is genuinely not in the
 * loaded list (options still in flight, or the group was closed after the
 * announcement was posted). A fragment is ugly but honest there — "—" on
 * a chip rendered ACTIVE would read as "no filter applied", which is the
 * failure this screen just came out of.
 */
function chipValue(id: string, options: FacetOption[]): string {
  if (!id) return t('tutoring2.common.all');
  return options.find((o) => o.key === id)?.label ?? id.slice(0, 8);
}

/**
 * The picker emits a bare string; `statusFilter` is the narrower
 * `'' | GroupAnnouncementStatus`. Narrow here rather than casting in the
 * template, so an option key that stops being a valid status fails
 * closed to "Semua" instead of poisoning the filter.
 */
function applyStatusFilter(v: string) {
  statusFilter.value = ANNOUNCEMENT_STATUSES.includes(v as GroupAnnouncementStatus)
    ? (v as GroupAnnouncementStatus)
    : '';
}

// ── KPI strip ──────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const rows = state.value.status === 'content' ? (state.value.data as AnnouncementRow[]) : [];
  const drafts = rows.filter((r) => announcementStatus(r) === 'draft').length;
  const published = rows.filter((r) => announcementStatus(r) === 'published').length;
  // Group-less (tutor-addressed) rows must not be counted as a group —
  // without the filter, every tutor broadcast would inflate "Kelompok
  // terjangkau" by one phantom group named `null`.
  const uniqueGroups = new Set(
    rows.map((r) => r.learning_group_id).filter((id): id is string => id != null),
  ).size;
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
const composeForm = ref<{
  audience: AnnouncementAudience;
  groupId: string;
  title: string;
  body: string;
  publish: boolean;
}>({
  audience: 'learning_group',
  groupId: '',
  title: '',
  body: '',
  publish: false,
});
const composing = ref(false);

/** Is the sheet currently addressing every tutor rather than a group? */
const composingTutorBroadcast = computed(
  () => composeForm.value.audience === 'tutor',
);

function openCompose() {
  composeForm.value = {
    // Always opens on the group audience, whatever was picked last time.
    // The tenant-wide broadcast is the louder act of the two and should
    // be chosen deliberately, never inherited from a previous sheet.
    audience: 'learning_group',
    groupId: groups.value[0]?.id ?? '',
    title: '',
    body: '',
    publish: false,
  };
  showCompose.value = true;
}

async function submitCompose() {
  const f = composeForm.value;
  const toTutors = f.audience === 'tutor';

  // Defensive: the selector that can set this is itself gated, so
  // reaching here without the ability means the form was driven some
  // other way. Fail closed rather than fire a request the server 403s.
  if (toTutors && !canComposeTutorAudience.value) return;
  if (!toTutors && !f.groupId) {
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
      // The blast radius differs, so the warning has to: one group's
      // students+wali, versus every tutor on the tenant.
      message: toTutors
        ? t('tutoring2.admin.groupAnnouncements.confirmPublishTutorMsg')
        : t('tutoring2.admin.groupAnnouncements.confirmPublishMsg'),
      confirmLabel: t('tutoring2.admin.groupAnnouncements.publishCta'),
    });
    if (!ok) return;
  }
  composing.value = true;
  try {
    // Two doors on purpose. The flat POST refuses
    // `audience: 'learning_group'` with a 422 — a group announcement is
    // created through the nested route, where the group id comes from
    // the URL and is scope-checked there.
    if (toTutors) {
      await TutoringAnnouncementsService.createForTutors({
        title: f.title.trim(),
        body: f.body,
        publish: f.publish,
      });
    } else {
      await TutoringAnnouncementsService.create(f.groupId, {
        title: f.title.trim(),
        body: f.body,
        publish: f.publish,
      });
    }
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
  if (!canManageRow(row)) return;
  const ok = await confirm({
    title: t('tutoring2.admin.groupAnnouncements.confirmPublishTitle'),
    message: isTutorAudience(row)
      ? t('tutoring2.admin.groupAnnouncements.confirmPublishTutorMsg')
      : t('tutoring2.admin.groupAnnouncements.confirmPublishMsg'),
    confirmLabel: t('tutoring2.admin.groupAnnouncements.publishCta'),
  });
  if (!ok) return;
  try {
    // Flat, id-only. `row.learning_group_id` is null on a tutor row and
    // the nested URL would read `/learning-groups/null/announcements/…`.
    await TutoringAnnouncementsService.publishById(row.id);
    toast.success(t('tutoring2.admin.groupAnnouncements.publishedToast'));
    reload();
  } catch (e) {
    toast.error(t('tutoring2.admin.groupAnnouncements.publishFailed'));
  }
}

// ── Delete ─────────────────────────────────────────────────────────
async function deleteRow(row: AnnouncementRow) {
  if (!canManageRow(row)) return;
  const ok = await confirm({
    title: t('tutoring2.admin.groupAnnouncements.confirmDeleteTitle'),
    message: isTutorAudience(row)
      ? t('tutoring2.admin.groupAnnouncements.confirmDeleteTutorMsg')
      : t('tutoring2.admin.groupAnnouncements.confirmDeleteMsg'),
    confirmLabel: t('tutoring2.common.delete'),
    danger: true,
  });
  if (!ok) return;
  try {
    await TutoringAnnouncementsService.destroyById(row.id);
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
          :value="chipValue(groupFilter, groupOptions)"
          icon-name="users"
          :active="!!groupFilter"
          :disabled="groupOptions.length === 0"
          :title="groupOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showGroupPicker = true"
        />
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="chipValue(statusFilter, statusOptions)"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="showStatusPicker = true"
        />
      </template>
    </PageFilterToolbar>

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
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.groupAnnouncements.audience') }}</th>
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
                <td class="px-4 py-3 text-slate-600">{{ audienceLabel(row) }}</td>
                <!-- Null on a tutor-addressed row: it belongs to no group,
                     so a dash is the honest cell, not a blank. -->
                <td class="px-4 py-3 text-slate-600">{{ row.group_name ?? '—' }}</td>
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
                  <!-- Per-ROW, not per-page: only a caller who could
                       compose a tenant-wide broadcast may act on one. For
                       anyone else the server answers 404, so rendering
                       these would advertise an action that cannot run. -->
                  <button
                    v-if="canManageRow(row) && announcementStatus(row) === 'draft'"
                    type="button"
                    class="text-2xs font-bold text-emerald-600 hover:underline mr-3"
                    @click="publishRow(row)"
                  >
                    {{ t('tutoring2.admin.groupAnnouncements.publishCta') }}
                  </button>
                  <button
                    v-if="canManageRow(row)"
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
      :subtitle="composingTutorBroadcast
        ? t('tutoring2.admin.groupAnnouncements.composeSubtitleTutor')
        : t('tutoring2.admin.groupAnnouncements.composeSubtitle')"
      @close="showCompose = false"
    >
      <div class="space-y-md">
        <!-- Rendered ONLY for an admin who holds both gates the server
             checks. Without `tutoring.tutor.view` there is exactly one
             audience available, and a one-option selector would imply a
             choice that does not exist. -->
        <label v-if="canComposeTutorAudience" class="block">
          <span class="text-2xs font-bold uppercase tracking-wide text-slate-500">
            {{ t('tutoring2.admin.groupAnnouncements.audience') }}
          </span>
          <select
            v-model="composeForm.audience"
            data-testid="compose-audience"
            class="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
          >
            <option value="learning_group">
              {{ t('tutoring2.admin.groupAnnouncements.audienceGroup') }}
            </option>
            <option value="tutor">
              {{ t('tutoring2.admin.groupAnnouncements.audienceTutor') }}
            </option>
          </select>
          <span class="mt-1 block text-2xs text-slate-400">
            {{ t('tutoring2.admin.groupAnnouncements.audienceHelp') }}
          </span>
        </label>

        <!-- A tutor broadcast has no group, so the picker is not merely
             ignored — it is hidden, and `groupId` is never read. -->
        <label v-if="!composingTutorBroadcast" class="block">
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
      :subtitle="previewRow.group_name ?? audienceLabel(previewRow)"
      @close="previewRow = null"
    >
      <article class="prose prose-sm max-w-none text-slate-700" v-html="previewRow.body" />
      <div class="mt-md flex items-center justify-between text-2xs text-slate-500">
        <span>{{ previewRow.author_name ?? '—' }}</span>
        <span>{{ shortDate(previewRow.published_at ?? previewRow.created_at) }}</span>
      </div>
      <BottomSheetFooter
        hide-secondary
        :primary-label="t('tutoring2.common.back')"
        @primary="previewRow = null"
      />
    </Modal>

    <!-- Per-facet pickers. Each writes its ref; the existing watcher on
         [search, group, status] does the reload, so nothing calls it
         here. -->
    <FilterFacetPickerModal
      v-if="showGroupPicker"
      :title="t('tutoring2.common.group')"
      :options="groupOptions"
      :selected="groupFilter"
      :all-label="t('tutoring2.common.all')"
      @close="showGroupPicker = false"
      @apply="(v) => { groupFilter = v; }"
    />
    <FilterFacetPickerModal
      v-if="showStatusPicker"
      :title="t('tutoring2.common.status')"
      :options="statusOptions"
      :selected="statusFilter"
      :all-label="t('tutoring2.common.all')"
      @close="showStatusPicker = false"
      @apply="applyStatusFilter"
    />
  </div>
</template>
