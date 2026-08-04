<!--
  ParentTutoring2GroupAnnouncementsView.vue — Wali read-only feed of
  announcements from every group their enrolled child(ren) belong to
  (WEB-12 / BE-22).

  Data flow:
    1. `listEnrollments()` → the backend already scopes by wali when
       the active role is parent, so we get one row per (child × group).
    2. For each unique learning_group_id, fetch published announcements
       via `list(groupId, { published: true })`.
    3. Merge, sort by published_at desc, group by learning group name
       for the render — matching the mockup ("newest first, grouped by
       group name").
  Empty state copy per task brief: "Belum ada pengumuman untuk anak Anda."
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Modal from '@/components/ui/Modal.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { ref } from 'vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringAnnouncementsService } from '@/services/tutoring2/announcements';
import type { GroupAnnouncement } from '@/types/tutoring2/announcement';

const { t } = useI18n();

interface AnnouncementRow extends GroupAnnouncement {
  group_name: string;
}

interface GroupBucket {
  group_id: string;
  group_name: string;
  items: AnnouncementRow[];
}

const { state, reload } = useDataRefresh<GroupBucket[]>(async () => {
  // Enrollments: BE scopes by wali when active role is parent, so we
  // don't send an explicit student_id filter — that would risk hiding
  // rows for a wali with multiple anak.
  const { items: enrollments } = await TutoringBimbelService.listEnrollments({ per_page: 100 });

  // Unique group_id → group_name map (skip enrollments without a group).
  const uniqueGroups = new Map<string, string>();
  for (const e of enrollments) {
    if (e.learning_group_id && !uniqueGroups.has(e.learning_group_id)) {
      uniqueGroups.set(
        e.learning_group_id,
        e.learning_group_name ?? e.learning_group_id.slice(0, 8),
      );
    }
  }

  // Fan-out: fetch published announcements per group. Small N (a wali
  // typically has 1–3 anak × 1–2 groups each), so serial-await is fine
  // and keeps the failure semantics obvious.
  const buckets: GroupBucket[] = [];
  for (const [gid, gname] of uniqueGroups) {
    try {
      const { items } = await TutoringAnnouncementsService.list(gid, {
        published: true,
        per_page: 50,
      });
      const rows: AnnouncementRow[] = items.map((a) => ({ ...a, group_name: gname }));
      rows.sort((a, b) => (b.published_at ?? '').localeCompare(a.published_at ?? ''));
      if (rows.length > 0) {
        buckets.push({ group_id: gid, group_name: gname, items: rows });
      }
    } catch {
      // Non-fatal: one group's list failing shouldn't wipe the feed.
    }
  }

  // Buckets ordered by the newest announcement in each, so the group
  // with fresh news floats to the top.
  buckets.sort((a, b) => {
    const at = a.items[0]?.published_at ?? '';
    const bt = b.items[0]?.published_at ?? '';
    return bt.localeCompare(at);
  });
  return buckets;
});

const totalCount = computed<number>(() => {
  const bs = state.value.status === 'content' ? (state.value.data as GroupBucket[]) : [];
  return bs.reduce((n, b) => n + b.items.length, 0);
});

function shortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

// ── Preview modal ────────────────────────────────────────────────
const previewRow = ref<AnnouncementRow | null>(null);
function openPreview(row: AnnouncementRow) { previewRow.value = row; }
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.common.roleParent')"
      :title="t('tutoring2.parent.groupAnnouncements.title')"
      :meta="state.status === 'content'
        ? t('tutoring2.parent.groupAnnouncements.meta', { count: totalCount })
        : t('tutoring2.common.loading')"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="4"
      :empty-title="t('tutoring2.parent.groupAnnouncements.emptyTitle')"
      :empty-description="t('tutoring2.parent.groupAnnouncements.emptyDesc')"
      @retry="reload"
    >
      <template #default="{ data }">
        <div v-for="bucket in (data as GroupBucket[])" :key="bucket.group_id" class="space-y-sm">
          <header class="flex items-center gap-2 px-1">
            <span class="flex h-8 w-8 items-center justify-center rounded-full bg-brand-azure/10 text-brand-azure">
              <NavIcon name="users" />
            </span>
            <h3 class="text-sm font-bold text-slate-900">{{ bucket.group_name }}</h3>
            <span class="text-2xs text-slate-500">
              {{ t('tutoring2.parent.groupAnnouncements.countLabel', { count: bucket.items.length }) }}
            </span>
          </header>

          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
            <ul class="divide-y divide-slate-100">
              <li
                v-for="row in bucket.items"
                :key="row.id"
                class="flex items-start gap-3 px-4 py-3 hover:bg-slate-50 cursor-pointer"
                @click="openPreview(row)"
              >
                <span class="mt-1 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-cobalt/10 text-brand-cobalt">
                  <NavIcon name="megaphone" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-bold text-slate-900">{{ row.title }}</p>
                  <p class="mt-0.5 line-clamp-2 text-2xs text-slate-500">
                    <span v-html="row.body" />
                  </p>
                  <p class="mt-1 text-2xs text-slate-400">
                    {{ row.author_name ?? '—' }} · {{ shortDate(row.published_at) }}
                  </p>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </template>
    </AsyncView>

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
        <span>{{ shortDate(previewRow.published_at) }}</span>
      </div>
      <BottomSheetFooter
        :primary-label="t('tutoring2.common.back')"
        @primary="previewRow = null"
      />
    </Modal>
  </div>
</template>
