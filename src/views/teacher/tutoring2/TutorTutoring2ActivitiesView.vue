<!--
  TutorTutoring2ActivitiesView.vue — greenfield tutor "Aktivitas"
  screen (WEB-13, wires BE-23 ActivityController).

  Composition mirrors the sibling TutorTutoring2Sessions/AssessmentsView:
    1. BrandPageHeader        role="teacher"
    2. KpiStripCards          Total / Terbit / Draf / Total pengumpulan
    3. PageFilterToolbar      group picker (chip) + kind chip + search
    4. AsyncView              list of activities (title, kind badge, due,
                              submissions count, publish/edit/delete)
    5. Compose panel          slides in on FAB tap — kind + title +
                              description (rich editor) + due_at + max_points
    6. Publish confirmation dialog for the draft → published transition

  Group scope: the endpoint is `GET /learning-groups/{groupId}/activities`
  so we need a group id to load anything. The tutor sees only groups
  they can access (via `/learning-groups` scoped by the active-role
  token). The picker defaults to the first group; the toolbar chip
  cycles.

  Ability gates:
    - `tutoring.activity.view`   render list + read a single activity
    - `tutoring.activity.manage` compose / edit / publish / delete
  (Both keys live on tutor bimbel defaults per BE-7.)
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppRichTextEditor from '@/components/ui/AppRichTextEditor.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { useMeStore } from '@/stores/me';
import { toLocalYmd } from '@/lib/local-date';
import { ActivitiesService } from '@/services/tutoring2/activities';
import { TutoringBimbelService, type BimbelLearningGroup } from '@/services/tutoring-bimbel.service';
import type {
  Activity,
  ActivityCreatePayload,
  ActivityKind,
} from '@/types/tutoring2/activity';
import { ACTIVITY_KINDS } from '@/types/tutoring2/activity';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();
const me = useMeStore();

const canManage = computed(() => me.can('tutoring.activity.manage'));

// ── Filters (group picker + kind chip + search) ──────────────────
const groups = ref<BimbelLearningGroup[]>([]);
const activeGroupId = ref<string>('');
const kindFilter = ref<'' | ActivityKind>('');
const search = ref('');

async function loadGroups() {
  try {
    const { items } = await TutoringBimbelService.listGroups({ per_page: 100, status: 'active' });
    groups.value = items;
    if (!activeGroupId.value && items.length > 0) {
      activeGroupId.value = items[0].id;
    }
  } catch (e) {
    toast.error((e as Error).message || t('tutoring2.tutor.activities.loadGroupsError'));
  }
}

// ── Data (per active group) ──────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  if (!activeGroupId.value) return [] as Activity[];
  const { items } = await ActivitiesService.listByGroup(activeGroupId.value, {
    per_page: 100,
    kind: kindFilter.value || undefined,
  });
  return items;
});

watch([activeGroupId, kindFilter], () => reload());

onMounted(async () => {
  await loadGroups();
  await reload();
});

const activities = computed<Activity[]>(() => {
  return state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as Activity[] | undefined) ?? [])
    : [];
});

const filteredActivities = computed<Activity[]>(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return activities.value;
  return activities.value.filter((a) => a.title.toLowerCase().includes(q));
});

// ── KPI ──────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => {
  const items = activities.value;
  const published = items.filter((a) => !!a.published_at).length;
  const drafts = items.length - published;
  const submissions = items.reduce((sum, a) => sum + (a.submissions_count ?? 0), 0);
  return [
    { icon: 'clipboard', label: t('tutoring2.tutor.activities.kpiTotal'), value: String(items.length) },
    { icon: 'check-circle', label: t('tutoring2.tutor.activities.kpiPublished'), value: String(published), tone: 'green' },
    { icon: 'edit', label: t('tutoring2.tutor.activities.kpiDrafts'), value: String(drafts), tone: 'amber' },
    { icon: 'inbox', label: t('tutoring2.tutor.activities.kpiSubmissions'), value: String(submissions), tone: 'brand' },
  ];
});

// ── Kind labelling ───────────────────────────────────────────────
function kindLabel(k: ActivityKind | string): string {
  switch (k) {
    case 'tugas':
      return t('tutoring2.tutor.activities.kindTugas');
    case 'kuis':
      return t('tutoring2.tutor.activities.kindKuis');
    case 'materi_baca':
      return t('tutoring2.tutor.activities.kindMateriBaca');
    default:
      return String(k);
  }
}

// ── Group + kind chip cycles ─────────────────────────────────────
function cycleGroup() {
  if (groups.value.length === 0) return;
  const i = groups.value.findIndex((g) => g.id === activeGroupId.value);
  const next = groups.value[(i + 1) % groups.value.length];
  activeGroupId.value = next.id;
}

function cycleKind() {
  const order: Array<'' | ActivityKind> = ['', ...ACTIVITY_KINDS];
  const i = order.indexOf(kindFilter.value);
  kindFilter.value = order[(i + 1) % order.length];
}

const activeGroupLabel = computed(() => {
  const g = groups.value.find((g) => g.id === activeGroupId.value);
  return g?.name ?? t('tutoring2.common.all');
});

const kindChipValue = computed(() =>
  kindFilter.value ? kindLabel(kindFilter.value) : t('tutoring2.common.all'),
);

// ── Compose panel ────────────────────────────────────────────────
const composeOpen = ref(false);
const editingId = ref<string | null>(null);
const draftKind = ref<ActivityKind>('tugas');
const draftTitle = ref('');
const draftDescription = ref('');
const draftDueAt = ref('');
const draftMaxPoints = ref<number | null>(100);
const saving = ref(false);

function openCompose(activity?: Activity) {
  if (!canManage.value) {
    toast.error(t('tutoring2.tutor.activities.noManageAbility'));
    return;
  }
  editingId.value = activity?.id ?? null;
  draftKind.value = activity?.kind ?? 'tugas';
  draftTitle.value = activity?.title ?? '';
  draftDescription.value = activity?.description ?? '';
  // due_at is ISO from BE; slice to YYYY-MM-DD for <input type="date">.
  // For "today" default on new activities, use toLocalYmd (see
  // reference_web_vue_local_date — never UTC-slice for calendar dates).
  if (activity?.due_at) {
    // ISO-8601 already carries a local-day representation on the client
    // once parsed. Convert via Date so timezone drift is handled.
    draftDueAt.value = toLocalYmd(new Date(activity.due_at));
  } else {
    draftDueAt.value = '';
  }
  draftMaxPoints.value = activity?.max_points ?? 100;
  composeOpen.value = true;
}

function closeCompose() {
  composeOpen.value = false;
  editingId.value = null;
}

async function submitCompose() {
  if (saving.value) return;
  if (!activeGroupId.value) {
    toast.error(t('tutoring2.tutor.activities.noGroupSelected'));
    return;
  }
  if (!draftTitle.value.trim()) {
    toast.error(t('tutoring2.tutor.activities.titleRequired'));
    return;
  }
  saving.value = true;
  try {
    const payload: ActivityCreatePayload = {
      kind: draftKind.value,
      title: draftTitle.value.trim(),
      description: draftDescription.value.trim() || null,
      due_at: draftDueAt.value || null,
      max_points: draftMaxPoints.value ?? null,
    };
    if (editingId.value) {
      await ActivitiesService.update(editingId.value, payload);
      toast.success(t('tutoring2.tutor.activities.updated'));
    } else {
      await ActivitiesService.create(activeGroupId.value, payload);
      toast.success(t('tutoring2.tutor.activities.created'));
    }
    closeCompose();
    await reload();
  } catch (e) {
    toast.error((e as Error).message || t('tutoring2.tutor.activities.saveError'));
  } finally {
    saving.value = false;
  }
}

// ── Publish + delete ─────────────────────────────────────────────
const publishTarget = ref<Activity | null>(null);
const publishing = ref(false);

function askPublish(activity: Activity) {
  if (!canManage.value) {
    toast.error(t('tutoring2.tutor.activities.noManageAbility'));
    return;
  }
  publishTarget.value = activity;
}

async function confirmPublish() {
  if (!publishTarget.value || publishing.value) return;
  publishing.value = true;
  try {
    await ActivitiesService.publish(publishTarget.value.id);
    toast.success(t('tutoring2.tutor.activities.published'));
    publishTarget.value = null;
    await reload();
  } catch (e) {
    toast.error((e as Error).message || t('tutoring2.tutor.activities.publishError'));
  } finally {
    publishing.value = false;
  }
}

async function onDelete(a: Activity) {
  if (!canManage.value) return;
  if (!window.confirm(t('tutoring2.tutor.activities.deleteConfirm', { title: a.title }))) return;
  try {
    await ActivitiesService.delete(a.id);
    toast.success(t('tutoring2.tutor.activities.deleted'));
    await reload();
  } catch (e) {
    toast.error((e as Error).message || t('tutoring2.tutor.activities.deleteError'));
  }
}

function openSubmissions(a: Activity) {
  router.push({ name: 'teacher.tutoring2.submissions', query: { activity_id: a.id } });
}

function formatDue(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.activities.title')"
      :meta="state.status === 'loading'
        ? t('tutoring2.common.loading')
        : t('tutoring2.tutor.activities.meta', { count: filteredActivities.length })"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.tutor.activities.searchPlaceholder')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.group')"
          :value="activeGroupLabel"
          icon-name="layers"
          :active="!!activeGroupId"
          @click="cycleGroup"
        />
        <AppFilterChip
          :label="t('tutoring2.common.kind')"
          :value="kindChipValue"
          icon-name="tag"
          :active="!!kindFilter"
          @click="cycleKind"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.tutor.activities.emptyTitle')"
      :empty-description="t('tutoring2.tutor.activities.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div v-if="filteredActivities.length === 0" class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-sm text-slate-500 shadow-sm">
          {{ t('tutoring2.tutor.activities.noMatch') }}
        </div>
        <div v-else class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li v-for="a in filteredActivities" :key="a.id" class="p-4 space-y-2">
              <div class="flex items-start gap-3">
                <div class="min-w-0 flex-1 space-y-1">
                  <div class="flex items-center gap-2 flex-wrap">
                    <StatusBadge :label="kindLabel(a.kind)" tone="info" uppercase />
                    <StatusBadge
                      :label="a.published_at ? t('tutoring2.status.published') : t('tutoring2.status.draft')"
                      :tone="a.published_at ? 'success' : 'neutral'"
                      uppercase
                    />
                  </div>
                  <p class="text-sm font-bold text-slate-900 truncate">{{ a.title }}</p>
                  <p class="text-2xs text-slate-500">
                    {{ t('tutoring2.tutor.activities.dueLabel') }}: {{ formatDue(a.due_at) }}
                    <span class="mx-1">·</span>
                    {{ t('tutoring2.tutor.activities.submissionsCount', { n: a.submissions_count ?? 0 }) }}
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-2 flex-wrap">
                <Button variant="secondary" size="sm" @click="openSubmissions(a)">
                  <NavIcon name="inbox" :size="14" />
                  <span class="ml-1">{{ t('tutoring2.tutor.activities.gradeCta') }}</span>
                </Button>
                <Button
                  v-if="!a.published_at && canManage"
                  variant="primary"
                  size="sm"
                  @click="askPublish(a)"
                >
                  <NavIcon name="upload" :size="14" />
                  <span class="ml-1">{{ t('tutoring2.tutor.activities.publishCta') }}</span>
                </Button>
                <Button v-if="canManage" variant="ghost" size="sm" @click="openCompose(a)">
                  {{ t('tutoring2.common.newLabel') === 'Baru' ? 'Edit' : 'Edit' }}
                </Button>
                <Button v-if="canManage" variant="ghost" size="sm" @click="onDelete(a)">
                  {{ t('tutoring2.common.delete') }}
                </Button>
              </div>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>

    <!-- FAB — new activity -->
    <button
      v-if="canManage"
      type="button"
      class="fixed bottom-24 right-6 z-30 h-14 w-14 rounded-2xl bg-brand-cobalt text-white shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 grid place-items-center"
      :aria-label="t('tutoring2.tutor.activities.newCta')"
      @click="openCompose()"
    >
      <NavIcon name="plus" :size="22" />
    </button>

    <!-- Compose panel — simple overlay (no shared FormSheet because the
         panel needs a rich editor block that would blow past sheet size). -->
    <div
      v-if="composeOpen"
      class="fixed inset-0 z-40 bg-slate-900/50 backdrop-blur-sm grid place-items-center px-4"
      @click.self="closeCompose"
    >
      <form
        class="w-full max-w-lg rounded-3xl bg-white shadow-2xl p-5 space-y-4 max-h-[90vh] overflow-y-auto"
        @submit.prevent="submitCompose"
      >
        <div class="flex items-center justify-between">
          <h3 class="text-base font-bold text-slate-900">
            {{ editingId ? t('tutoring2.tutor.activities.editTitle') : t('tutoring2.tutor.activities.newTitle') }}
          </h3>
          <button type="button" class="p-2 rounded-full hover:bg-slate-100" @click="closeCompose">
            <NavIcon name="x" :size="18" />
          </button>
        </div>

        <div class="space-y-1.5">
          <p class="text-xs font-bold text-slate-600 uppercase tracking-wider">{{ t('tutoring2.common.kind') }}</p>
          <div class="flex items-center gap-2 flex-wrap">
            <label
              v-for="k in ACTIVITY_KINDS"
              :key="k"
              class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border cursor-pointer text-xs font-bold"
              :class="draftKind === k ? 'bg-brand-cobalt/10 border-brand-cobalt text-brand-cobalt' : 'bg-white border-slate-200 text-slate-500'"
            >
              <input v-model="draftKind" type="radio" :value="k" class="sr-only" />
              {{ kindLabel(k) }}
            </label>
          </div>
        </div>

        <div class="space-y-1.5">
          <label for="activity-title" class="text-xs font-bold text-slate-600 uppercase tracking-wider">{{ t('tutoring2.common.title') }}</label>
          <input
            id="activity-title"
            v-model="draftTitle"
            type="text"
            :placeholder="t('tutoring2.tutor.activities.titlePlaceholder')"
            class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
          />
        </div>

        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-600 uppercase tracking-wider">{{ t('tutoring2.common.description') }}</label>
          <AppRichTextEditor
            v-model:html="draftDescription"
            :placeholder="t('tutoring2.tutor.activities.descriptionPlaceholder')"
            :min-height="180"
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div class="space-y-1.5">
            <label for="activity-due" class="text-xs font-bold text-slate-600 uppercase tracking-wider">{{ t('tutoring2.common.dueDate') }}</label>
            <input
              id="activity-due"
              v-model="draftDueAt"
              type="date"
              class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
            />
          </div>
          <div class="space-y-1.5">
            <label for="activity-max" class="text-xs font-bold text-slate-600 uppercase tracking-wider">{{ t('tutoring2.common.maxScore') }}</label>
            <input
              id="activity-max"
              v-model.number="draftMaxPoints"
              type="number"
              min="1"
              max="1000"
              class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-brand-cobalt focus:outline-none focus:ring-2 focus:ring-brand-cobalt/20"
            />
          </div>
        </div>

        <div class="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
          <Button variant="secondary" size="md" type="button" @click="closeCompose">{{ t('tutoring2.common.cancel') }}</Button>
          <Button variant="primary" size="md" type="submit" :loading="saving">{{ t('tutoring2.common.save') }}</Button>
        </div>
      </form>
    </div>

    <!-- Publish confirmation -->
    <div
      v-if="publishTarget"
      class="fixed inset-0 z-40 bg-slate-900/50 grid place-items-center px-4"
      @click.self="publishTarget = null"
    >
      <div class="w-full max-w-md rounded-3xl bg-white shadow-2xl p-6 space-y-3">
        <h3 class="text-base font-bold text-slate-900">{{ t('tutoring2.tutor.activities.publishConfirmTitle') }}</h3>
        <p class="text-sm text-slate-500">
          {{ t('tutoring2.tutor.activities.publishConfirmBody', { title: publishTarget.title }) }}
        </p>
        <div class="flex items-center justify-end gap-2 pt-2">
          <Button variant="secondary" size="md" @click="publishTarget = null">{{ t('tutoring2.common.cancel') }}</Button>
          <Button variant="primary" size="md" :loading="publishing" @click="confirmPublish">
            {{ t('tutoring2.tutor.activities.publishCta') }}
          </Button>
        </div>
      </div>
    </div>
  </div>
</template>
