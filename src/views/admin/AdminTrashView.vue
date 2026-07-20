<!--
  AdminTrashView.vue — "Data Terhapus" (the school recycle bin).

  Admin-only. Lists soft-deleted rows (guru/siswa/mapel) grouped by type, with a
  quota banner up top, group tabs, and per-row Pulihkan / Hapus-permanen. A
  permanent delete first fetches the cascade impact and requires typing the
  confirm word, since it is irreversible. Backed by TrashService → /trash.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import SegmentedControl, {
  type SegmentOption,
} from '@/components/filters/SegmentedControl.vue';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRelative } from '@/lib/format';
import { useAuthStore } from '@/stores/auth';
import { ScheduleConflictError, TrashService } from '@/services/trash.service';
import type {
  DependencyCandidate,
  ScheduleConflict,
  ScheduleDependency,
  ScheduleDependencyKind,
  ScheduleResolution,
  TrashGroup,
  TrashImpact,
  TrashItem,
  TrashType,
} from '@/types/trash';

const { t } = useI18n();
const auth = useAuthStore();

// view = see the bin (read-only); manage = restore + permanent delete. A
// view-only role sees a read-only bin with the action affordances hidden.
const canManage = computed(() => auth.hasAbility('school.trash.manage'));

const groups = ref<TrashGroup[]>([]);
const total = ref(0);
const retentionDays = ref(30);
const isLoading = ref(true);
const error = ref<string | null>(null);
const activeTab = ref<'all' | TrashType>('all');
const busyId = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── permanent-delete impact modal ──────────────────────────────────────
const impactTarget = ref<TrashItem | null>(null);
const impact = ref<TrashImpact | null>(null);
const impactLoading = ref(false);
const confirmText = ref('');
const isPurging = ref(false);

const state = computed<AsyncState<TrashGroup[]>>(() => {
  if (isLoading.value && groups.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (total.value === 0) return { status: 'empty' };
  return { status: 'content', data: groups.value };
});

const populated = computed(() => groups.value.filter((g) => g.count > 0));

const tabs = computed<SegmentOption[]>(() => [
  { key: 'all', label: t('admin.trash.tabAll'), meta: String(total.value) },
  ...populated.value.map((g) => ({
    key: g.type,
    label: g.label,
    meta: String(g.count),
  })),
]);

const visibleGroups = computed(() =>
  activeTab.value === 'all'
    ? populated.value
    : populated.value.filter((g) => g.type === activeTab.value),
);

const confirmWord = computed(() => t('admin.trash.confirmWord'));
const canPurge = computed(
  () => confirmText.value.trim().toUpperCase() === confirmWord.value.toUpperCase(),
);

const typeChipClass: Record<TrashType, string> = {
  teacher: 'bg-violet-100 text-violet-700',
  student: 'bg-sky-100 text-sky-700',
  subject: 'bg-emerald-100 text-emerald-700',
  // Schedule wears the admin navy so it reads as the structural/org type.
  schedule: 'bg-indigo-100 text-indigo-700',
};
const typeAvatarColor: Record<TrashType, string> = {
  teacher: '#7c3aed',
  student: '#1b6fb8',
  subject: '#15803d',
  schedule: '#143068', // role-admin navy
};

/** Whole days until the auto-purge cron force-deletes a row (null if unknown). */
function daysUntilPurge(item: TrashItem): number | null {
  if (!item.purge_at) return null;
  const ms = new Date(item.purge_at).getTime() - Date.now();
  if (Number.isNaN(ms)) return null;
  return Math.max(0, Math.ceil(ms / 86_400_000));
}

async function reload(): Promise<void> {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await TrashService.list();
    groups.value = res.data;
    total.value = res.total;
    retentionDays.value = res.retention_days;
    // Snap back to "Semua" if the active tab emptied out after an action.
    if (activeTab.value !== 'all' && !populated.value.some((g) => g.type === activeTab.value)) {
      activeTab.value = 'all';
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function onRestore(item: TrashItem): Promise<void> {
  if (busyId.value) return;
  busyId.value = item.id;
  try {
    await TrashService.restore(item.type, item.id);
    toast.value = { message: t('admin.trash.toastRestored', { name: item.name }), tone: 'success' };
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message || t('admin.trash.toastError'), tone: 'error' };
  } finally {
    busyId.value = null;
  }
}

async function openImpact(item: TrashItem): Promise<void> {
  impactTarget.value = item;
  impact.value = null;
  confirmText.value = '';
  impactLoading.value = true;
  try {
    impact.value = await TrashService.impact(item.type, item.id);
  } catch {
    // Non-fatal — the modal still lets the admin proceed; we just can't
    // show the cascade preview.
    impact.value = null;
  } finally {
    impactLoading.value = false;
  }
}

function closeImpact(): void {
  impactTarget.value = null;
  impact.value = null;
  confirmText.value = '';
}

async function confirmPurge(): Promise<void> {
  const item = impactTarget.value;
  if (!item || !canPurge.value) return;
  isPurging.value = true;
  try {
    await TrashService.purge(item.type, item.id);
    toast.value = { message: t('admin.trash.toastPurged', { name: item.name }), tone: 'success' };
    closeImpact();
    await reload();
  } catch (e) {
    toast.value = { message: (e as Error).message || t('admin.trash.toastError'), tone: 'error' };
  } finally {
    isPurging.value = false;
  }
}

// ── schedule dependency-resolution modal ───────────────────────────────
//
// A trashed schedule may point at a subject/teacher/class that was ALSO
// deleted. Restoring it then needs a per-dependency decision. For a single
// schedule we fetch its real dependencies first; for "Pulihkan Semua" we show
// one generic policy (per dependency KIND) that the backend applies to every
// selected id.

/** One editable dependency row in the resolution dialog. */
interface DepRow {
  dependency: ScheduleDependencyKind;
  /** The trashed row's name — empty in bulk mode (policy is kind-wide). */
  oldName: string;
  candidates: DependencyCandidate[];
  /** Restoring this row would collide with an active same-name row. */
  hasConflict: boolean;
  choice: 'restore' | 'repoint' | 'skip';
  /** Selected candidate id when choice === 'repoint'. */
  repointId: string;
  /** Set after a 409 — restore is then off the table for this row. */
  blocked: boolean;
}

type RestoreMode = 'single' | 'bulk';

const restoreMode = ref<RestoreMode | null>(null); // null → dialog closed
const restoreItem = ref<TrashItem | null>(null); // single target
const restoreBulkIds = ref<string[]>([]); // bulk targets
const restoreBinLabel = ref('');
const restoreDeps = ref<DepRow[]>([]);
const restoreProbing = ref<string | null>(null); // item id being dependency-checked
const restoreSubmitting = ref(false);

/** Bulk mode offers restore/skip only — a single repoint target across a whole
 *  batch of different schedules is meaningless. */
const BULK_KINDS: readonly ScheduleDependencyKind[] = ['subject', 'teacher', 'class'];

function depI18nKey(dep: ScheduleDependencyKind): string {
  const suffix = dep === 'subject' ? 'Subject' : dep === 'teacher' ? 'Teacher' : 'Class';
  return `admin.trash.dep${suffix}`;
}
function depLabel(dep: ScheduleDependencyKind): string {
  return t(depI18nKey(dep));
}
function depNoun(dep: ScheduleDependencyKind): string {
  return depLabel(dep).toLowerCase();
}

/** Map a backend dependency into an editable row, defaulting away from a
 *  known-conflicting "restore" so the admin isn't nudged into a guaranteed 409. */
function depToRow(dep: ScheduleDependency): DepRow {
  const hasCandidates = dep.active_candidates.length > 0;
  let choice: DepRow['choice'] = 'restore';
  if (dep.has_conflict) choice = hasCandidates ? 'repoint' : 'skip';
  return {
    dependency: dep.dependency,
    oldName: dep.old_name,
    candidates: dep.active_candidates,
    hasConflict: dep.has_conflict,
    choice,
    repointId: hasCandidates ? dep.active_candidates[0].id : '',
    blocked: false,
  };
}

/** Serialise the rows into the wire resolution map. */
function buildResolution(rows: DepRow[]): ScheduleResolution {
  const out: ScheduleResolution = {};
  for (const r of rows) {
    const value =
      r.choice === 'restore' ? 'restore' : r.choice === 'skip' ? 'skip' : `repoint:${r.repointId}`;
    out[r.dependency] = value;
  }
  return out;
}

/** A row is unresolved when it wants to repoint but has no target selected. */
const restoreReady = computed(() =>
  restoreDeps.value.every((r) => r.choice !== 'repoint' || !!r.repointId),
);

function closeRestore(): void {
  restoreMode.value = null;
  restoreItem.value = null;
  restoreBulkIds.value = [];
  restoreBinLabel.value = '';
  restoreDeps.value = [];
  restoreSubmitting.value = false;
}

/** Dispatch: schedules go through the dependency flow, everything else is a
 *  bare restore (unchanged behaviour). */
function handleRestore(item: TrashItem): void {
  if (item.type === 'schedule') void onRestoreSchedule(item);
  else void onRestore(item);
}

/** Single schedule: probe dependencies, restore straight away when there are
 *  none, otherwise open the resolution dialog. */
async function onRestoreSchedule(item: TrashItem): Promise<void> {
  if (busyId.value || restoreProbing.value) return;
  restoreProbing.value = item.id;
  try {
    const res = await TrashService.scheduleDependencies(item.id);
    if (res.dependencies.length === 0) {
      await TrashService.restoreSchedule(item.id, {});
      toast.value = {
        message: t('admin.trash.toastRestored', { name: item.name }),
        tone: 'success',
      };
      await reload();
      return;
    }
    restoreItem.value = item;
    restoreBulkIds.value = [];
    restoreBinLabel.value = res.bin_label || item.name;
    restoreDeps.value = res.dependencies.map(depToRow);
    restoreMode.value = 'single';
  } catch (e) {
    toast.value = {
      message: (e as Error).message || t('admin.trash.toastError'),
      tone: 'error',
    };
  } finally {
    restoreProbing.value = null;
  }
}

/** "Pulihkan Semua" for the schedule group — open one blanket-policy dialog. */
function onRestoreAll(group: TrashGroup): void {
  if (busyId.value || restoreProbing.value) return;
  restoreItem.value = null;
  restoreBulkIds.value = group.items.map((i) => i.id);
  restoreBinLabel.value = '';
  restoreDeps.value = BULK_KINDS.map((dependency) => ({
    dependency,
    oldName: '',
    candidates: [],
    hasConflict: false,
    choice: 'restore',
    repointId: '',
    blocked: false,
  }));
  restoreMode.value = 'bulk';
}

/** Mark the dependencies the server rejected as conflicting: block restore and
 *  push them onto a repoint/skip so the admin can re-decide without another 409. */
function applyServerConflicts(conflicts: ScheduleConflict[]): void {
  for (const c of conflicts) {
    const row = restoreDeps.value.find((r) => r.dependency === c.dependency);
    if (!row) continue;
    row.blocked = true;
    row.hasConflict = true;
    if (c.active_candidates?.length && row.candidates.length === 0) {
      row.candidates = c.active_candidates;
      row.repointId = c.active_candidates[0].id;
    }
    if (row.choice === 'restore') {
      row.choice = row.candidates.length > 0 ? 'repoint' : 'skip';
    }
  }
}

async function applyRestore(): Promise<void> {
  if (restoreSubmitting.value || !restoreReady.value) return;
  restoreSubmitting.value = true;
  try {
    if (restoreMode.value === 'bulk') {
      const res = await TrashService.restoreBulk(
        'schedule',
        restoreBulkIds.value,
        buildResolution(restoreDeps.value),
      );
      const skipped = res.skipped.length;
      toast.value = {
        message:
          skipped > 0
            ? t('admin.trash.bulkResultSkipped', { restored: res.restored, skipped })
            : t('admin.trash.bulkResult', { restored: res.restored }),
        tone: 'success',
      };
      closeRestore();
      await reload();
      return;
    }

    const item = restoreItem.value;
    if (!item) return;
    await TrashService.restoreSchedule(item.id, buildResolution(restoreDeps.value));
    toast.value = {
      message: t('admin.trash.toastRestored', { name: item.name }),
      tone: 'success',
    };
    closeRestore();
    await reload();
  } catch (e) {
    if (e instanceof ScheduleConflictError) {
      // Keep the dialog open, mark the conflicting rows, and let the admin
      // repoint/skip them — the "decide" step for a name collision.
      applyServerConflicts(e.conflicts);
      toast.value = { message: t('admin.trash.conflictToast'), tone: 'error' };
    } else {
      toast.value = {
        message: (e as Error).message || t('admin.trash.toastError'),
        tone: 'error',
      };
    }
  } finally {
    restoreSubmitting.value = false;
  }
}

onMounted(reload);
</script>

<template>
  <div class="space-y-4">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.trash.kicker')"
      :title="t('admin.trash.title')"
      :meta="t('admin.trash.meta', { count: total, days: retentionDays })"
    />

    <!-- Quota note. Trashed rows do NOT hold a paid seat — GetSeatUsageAction
         excludes soft-deleted rows (!428) — so this reassures rather than
         warns. The only quota consequence left is that restoring a guru/siswa
         takes a seat back. -->
    <div
      class="flex items-start gap-3 rounded-2xl border border-sky-200 bg-sky-50 px-4 py-3"
    >
      <span
        class="grid h-9 w-9 flex-shrink-0 place-items-center rounded-xl bg-white text-sky-600"
      >
        <NavIcon name="info" :size="18" />
      </span>
      <div class="min-w-0">
        <p class="text-sm font-bold text-sky-900">
          {{ t('admin.trash.quotaFreeTitle') }}
        </p>
        <p class="mt-0.5 text-xs text-sky-700">
          {{ t('admin.trash.quotaFreeSubtitle') }}
        </p>
      </div>
    </div>

    <SegmentedControl
      v-if="total > 0"
      :model-value="activeTab"
      :options="tabs"
      @update:model-value="activeTab = $event as 'all' | TrashType"
    />

    <AsyncView
      :state="state"
      :empty-title="t('admin.trash.emptyTitle')"
      :empty-description="t('admin.trash.emptyDesc')"
      empty-icon="trash-2"
      @retry="reload"
    >
      <div class="space-y-5">
        <section v-for="group in visibleGroups" :key="group.type" class="space-y-2">
          <div class="flex items-center justify-between gap-2">
            <p class="text-3xs font-black uppercase tracking-widest text-slate-400">
              {{ group.label }}
            </p>
            <!-- Bulk restore is schedule-only (its endpoint + resolution flow
                 are schedule-specific). Show it once the group is worth a
                 blanket action rather than one-by-one. -->
            <Button
              v-if="canManage && group.type === 'schedule' && group.count > 1"
              variant="secondary"
              size="sm"
              :disabled="!!busyId || !!restoreProbing || !!restoreMode"
              @click="onRestoreAll(group)"
            >{{ t('admin.trash.restoreAll') }}</Button>
          </div>
          <ul class="space-y-2">
            <li
              v-for="item in group.items"
              :key="item.id"
              class="flex items-center gap-3 rounded-2xl border border-slate-200 bg-white px-3 py-2.5"
            >
              <InitialsAvatar :name="item.name" :size="40" :color="typeAvatarColor[item.type]" />
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">{{ item.name }}</p>
                <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-3xs text-slate-400">
                  <span
                    class="rounded-md px-1.5 py-0.5 font-black uppercase tracking-wide"
                    :class="typeChipClass[item.type]"
                  >{{ group.label }}</span>
                  <span v-if="item.deleted_at">· {{ t('admin.trash.deletedAgo', { time: formatRelative(item.deleted_at) }) }}</span>
                  <span
                    v-if="daysUntilPurge(item) !== null && daysUntilPurge(item)! <= 7"
                    class="font-semibold text-amber-600"
                  >· {{ t('admin.trash.purgeSoon', { n: daysUntilPurge(item) }) }}</span>
                </div>
              </div>
              <div v-if="canManage" class="flex flex-shrink-0 items-center gap-2">
                <Button
                  variant="success"
                  size="sm"
                  :loading="busyId === item.id || restoreProbing === item.id"
                  :disabled="!!busyId || !!restoreProbing"
                  @click="handleRestore(item)"
                >{{ t('admin.trash.restore') }}</Button>
                <Button
                  variant="danger"
                  size="sm"
                  :disabled="!!busyId || !!restoreProbing"
                  @click="openImpact(item)"
                >{{ t('admin.trash.deleteShort') }}</Button>
              </div>
            </li>
          </ul>
        </section>
      </div>
    </AsyncView>

    <!-- Permanent-delete impact + type-to-confirm modal -->
    <Modal
      v-if="impactTarget"
      size="md"
      :title="t('admin.trash.impactTitle', { name: impactTarget.name })"
      :subtitle="t('admin.trash.impactSubtitle', { type: impact?.label ?? '' })"
      @close="closeImpact"
    >
      <div class="space-y-4">
        <div
          v-if="impactLoading"
          class="flex items-center justify-center gap-2 py-6 text-sm text-slate-400"
        >
          <Spinner size="sm" /> {{ t('admin.trash.impactLoading') }}
        </div>

        <template v-else>
          <div class="rounded-xl border border-red-200 bg-red-50 p-3">
            <p class="text-sm leading-relaxed text-red-900">
              {{ t('admin.trash.impactWarn', { name: impactTarget.name }) }}
            </p>
          </div>

          <ul v-if="impact && impact.related.length > 0" class="space-y-1.5">
            <li
              v-for="(rel, idx) in impact.related"
              :key="idx"
              class="flex items-center gap-2 text-sm text-slate-700"
            >
              <span class="h-1.5 w-1.5 flex-shrink-0 rounded-full bg-red-400" aria-hidden="true" />
              <span class="flex-1">{{ rel.label }}</span>
              <span class="font-black tabular-nums text-red-600">{{ rel.count }}</span>
            </li>
          </ul>
          <p v-else class="text-sm text-slate-500">{{ t('admin.trash.impactNone') }}</p>

          <div class="rounded-xl border-2 border-red-100 p-3">
            <label class="mb-1.5 block text-xs text-slate-500">
              {{ t('admin.trash.confirmPrompt', { word: confirmWord }) }}
            </label>
            <input
              v-model="confirmText"
              type="text"
              autocomplete="off"
              class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm font-mono uppercase tracking-wide focus:border-red-400 focus:outline-none focus:ring-2 focus:ring-red-200"
              :placeholder="confirmWord"
              @keyup.enter="confirmPurge"
            />
          </div>

          <div class="flex justify-end gap-2 pt-1">
            <Button variant="secondary" :disabled="isPurging" @click="closeImpact">
              {{ t('admin.trash.cancel') }}
            </Button>
            <Button
              variant="danger"
              :disabled="!canPurge"
              :loading="isPurging"
              @click="confirmPurge"
            >{{ t('admin.trash.delete') }}</Button>
          </div>
        </template>
      </div>
    </Modal>

    <!-- Schedule dependency-resolution modal (single restore + bulk policy) -->
    <Modal
      v-if="restoreMode"
      size="lg"
      :title="restoreMode === 'bulk' ? t('admin.trash.resolveBulkTitle') : t('admin.trash.resolveTitle')"
      :subtitle="
        restoreMode === 'bulk'
          ? t('admin.trash.resolveBulkSubtitle', { count: restoreBulkIds.length })
          : restoreBinLabel
      "
      @close="closeRestore"
    >
      <div class="space-y-4">
        <div class="rounded-xl border border-indigo-200 bg-indigo-50 p-3">
          <p class="text-sm leading-relaxed text-indigo-900">
            {{
              restoreMode === 'bulk'
                ? t('admin.trash.resolveBulkIntro')
                : t('admin.trash.resolveIntro')
            }}
          </p>
        </div>

        <ul class="space-y-3">
          <li
            v-for="dep in restoreDeps"
            :key="dep.dependency"
            class="rounded-2xl border border-slate-200 p-3"
          >
            <div class="mb-2 flex items-center gap-2">
              <span
                class="rounded-md px-1.5 py-0.5 text-3xs font-black uppercase tracking-wide"
                :class="typeChipClass.schedule"
              >{{ depLabel(dep.dependency) }}</span>
              <span v-if="dep.oldName" class="truncate text-xs text-slate-500">
                {{ t('admin.trash.depWas', { name: dep.oldName }) }}
              </span>
            </div>

            <div class="space-y-1.5">
              <!-- Restore the trashed row -->
              <label
                class="flex items-start gap-2 text-sm"
                :class="dep.blocked ? 'cursor-not-allowed opacity-50' : 'cursor-pointer'"
              >
                <input
                  type="radio"
                  class="mt-0.5"
                  :name="`resolve-${dep.dependency}`"
                  value="restore"
                  :checked="dep.choice === 'restore'"
                  :disabled="dep.blocked"
                  @change="dep.choice = 'restore'"
                />
                <span class="flex-1 text-slate-700">
                  {{ t('admin.trash.choiceRestore', { noun: depNoun(dep.dependency) }) }}
                </span>
              </label>
              <p
                v-if="dep.hasConflict || dep.blocked"
                class="ml-6 text-xs font-semibold text-amber-600"
              >
                {{ t('admin.trash.conflictWarn', { noun: depNoun(dep.dependency) }) }}
              </p>

              <!-- Repoint to an active row (single mode only — a batch-wide
                   single target is meaningless) -->
              <label
                v-if="dep.candidates.length > 0"
                class="flex items-start gap-2 text-sm cursor-pointer"
              >
                <input
                  type="radio"
                  class="mt-0.5"
                  :name="`resolve-${dep.dependency}`"
                  value="repoint"
                  :checked="dep.choice === 'repoint'"
                  @change="dep.choice = 'repoint'"
                />
                <span class="flex-1 text-slate-700">
                  {{ t('admin.trash.choiceRepoint') }}
                  <select
                    v-model="dep.repointId"
                    class="mt-1.5 block w-full rounded-lg border border-slate-300 px-2 py-1.5 text-sm focus:border-indigo-400 focus:outline-none focus:ring-2 focus:ring-indigo-200 disabled:opacity-50"
                    :disabled="dep.choice !== 'repoint'"
                    @focus="dep.choice = 'repoint'"
                  >
                    <option
                      v-for="cand in dep.candidates"
                      :key="cand.id"
                      :value="cand.id"
                    >{{ cand.name }}</option>
                  </select>
                </span>
              </label>

              <!-- Skip — leave the schedule pointing at the trashed row -->
              <label class="flex items-start gap-2 text-sm cursor-pointer">
                <input
                  type="radio"
                  class="mt-0.5"
                  :name="`resolve-${dep.dependency}`"
                  value="skip"
                  :checked="dep.choice === 'skip'"
                  @change="dep.choice = 'skip'"
                />
                <span class="flex-1 text-slate-700">{{ t('admin.trash.choiceSkip') }}</span>
              </label>
            </div>
          </li>
        </ul>

        <div class="flex justify-end gap-2 pt-1">
          <Button variant="secondary" :disabled="restoreSubmitting" @click="closeRestore">
            {{ t('admin.trash.cancel') }}
          </Button>
          <Button
            variant="success"
            :disabled="!restoreReady"
            :loading="restoreSubmitting"
            @click="applyRestore"
          >{{ t('admin.trash.restore') }}</Button>
        </div>
      </div>
    </Modal>

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
