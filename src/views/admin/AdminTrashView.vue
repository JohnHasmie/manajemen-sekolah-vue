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
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRelative } from '@/lib/format';
import { TrashService } from '@/services/trash.service';
import type { TrashGroup, TrashImpact, TrashItem, TrashType } from '@/types/trash';

const { t } = useI18n();

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

// Quota banner — how many trashed rows still hold a paid seat, broken down.
const quotaGroups = computed(() => populated.value.filter((g) => g.quota));
const quotaCount = computed(() =>
  quotaGroups.value.reduce((sum, g) => sum + g.count, 0),
);
const quotaBreakdown = computed(() =>
  quotaGroups.value
    .map((g) => `${g.count} ${g.label.toLowerCase()}`)
    .join(' · '),
);

const confirmWord = computed(() => t('admin.trash.confirmWord'));
const canPurge = computed(
  () => confirmText.value.trim().toUpperCase() === confirmWord.value.toUpperCase(),
);

const typeChipClass: Record<TrashType, string> = {
  teacher: 'bg-violet-100 text-violet-700',
  student: 'bg-sky-100 text-sky-700',
  subject: 'bg-emerald-100 text-emerald-700',
};
const typeAvatarColor: Record<TrashType, string> = {
  teacher: '#7c3aed',
  student: '#1b6fb8',
  subject: '#15803d',
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

    <!-- Quota banner — how much trashed data still costs a seat. -->
    <div
      class="flex items-center gap-3 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3"
    >
      <span
        class="grid h-9 w-9 flex-shrink-0 place-items-center rounded-xl bg-white text-lg text-amber-600"
        aria-hidden="true"
      >📊</span>
      <div class="min-w-0">
        <p class="text-sm font-bold text-amber-800">
          {{ quotaCount > 0
            ? t('admin.trash.quotaTitle', { count: quotaCount })
            : t('admin.trash.quotaEmpty') }}
        </p>
        <p v-if="quotaCount > 0" class="mt-0.5 text-xs text-amber-700">
          <span v-if="quotaBreakdown">{{ quotaBreakdown }} — </span>{{ t('admin.trash.quotaSubtitle') }}
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
          <p class="text-3xs font-black uppercase tracking-widest text-slate-400">
            {{ group.label }}
          </p>
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
                  <span
                    v-if="group.quota"
                    class="rounded-md bg-amber-100 px-1.5 py-0.5 font-black uppercase tracking-wide text-amber-700"
                  >{{ t('admin.trash.quotaChip') }}</span>
                  <span v-if="item.deleted_at">· {{ t('admin.trash.deletedAgo', { time: formatRelative(item.deleted_at) }) }}</span>
                  <span
                    v-if="daysUntilPurge(item) !== null && daysUntilPurge(item)! <= 7"
                    class="font-semibold text-amber-600"
                  >· {{ t('admin.trash.purgeSoon', { n: daysUntilPurge(item) }) }}</span>
                </div>
              </div>
              <div class="flex flex-shrink-0 items-center gap-2">
                <Button
                  variant="success"
                  size="sm"
                  :loading="busyId === item.id"
                  :disabled="!!busyId"
                  @click="onRestore(item)"
                >{{ t('admin.trash.restore') }}</Button>
                <Button
                  variant="danger"
                  size="sm"
                  :disabled="!!busyId"
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

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
