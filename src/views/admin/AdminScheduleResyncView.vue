<!--
  AdminScheduleResyncView.vue — "Sinkronkan Jadwal ke Mapel" (Part A2).

  Heal-forward tool: after a delete-then-reimport of mapel, active
  schedules can point at a soft-deleted (orphan) subject — the slot
  survives but its mapel name renders empty. This wizard lists every
  orphan slot with a suggested + alternative active mapel (ranked by
  name/grade similarity) so the admin can re-link them all in one pass
  instead of hand-editing dozens of rows.

  Flow:
    GET /schedule/resync/preview → per-orphan mapping table.
    Each orphan gets a dropdown: suggested (similarity% badge) +
    alternatives + "Lewati" (skip). POST /schedule/resync/apply sends
    only the resolved (non-skipped) mappings.

  Entry points: "Sinkronkan Jadwal" button on the Jadwal page (shown when
  preview.total > 0) + the post-import toast CTA on the Mapel page.
-->
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import {
  ScheduleService,
  type ResyncOrphan,
  type ResyncPreview,
  type ResyncSubjectOption,
} from '@/services/schedule.service';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t: $t } = useI18n();
const router = useRouter();

const preview = ref<ResyncPreview | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const isApplying = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// schedule_id → chosen target_subject_id. Empty string ('') = "Lewati"
// (skip). reactive so v-model on a freshly-keyed select stays reactive.
const selections = reactive<Record<string, string>>({});

// Sentinel for the "Lewati" option — must not collide with any real
// subject id. Empty string reads cleanly as "no target".
const SKIP = '';

const state = computed<AsyncState<ResyncOrphan[]>>(() => {
  if (isLoading.value) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (!preview.value || preview.value.total === 0) return { status: 'empty' };
  return { status: 'content', data: preview.value.orphans };
});

/** Combined, deduped option list for an orphan (suggested first). */
function optionsFor(orphan: ResyncOrphan): ResyncSubjectOption[] {
  const seen = new Set<string>();
  const out: ResyncSubjectOption[] = [];
  const push = (opt: ResyncSubjectOption | null) => {
    if (!opt || !opt.id || seen.has(opt.id)) return;
    seen.add(opt.id);
    out.push(opt);
  };
  push(orphan.suggested);
  for (const alt of orphan.alternatives) push(alt);
  return out;
}

/** Similarity of the currently-selected option (null = skipped/none). */
function selectedSimilarity(orphan: ResyncOrphan): number | null {
  const chosen = selections[orphan.schedule_id];
  if (!chosen) return null;
  const opt = optionsFor(orphan).find((o) => o.id === chosen);
  return opt ? opt.similarity : null;
}

function gradeText(grade: string | number | null): string {
  if (grade === null || grade === undefined || grade === '') return '';
  return $t('admin.schedule.resync.gradePrefix', { grade });
}

/** How many orphans currently have a resolved (non-skip) target. */
const resolvedCount = computed(() => {
  if (!preview.value) return 0;
  return preview.value.orphans.filter(
    (o) => selections[o.schedule_id] && selections[o.schedule_id] !== SKIP,
  ).length;
});

async function loadPreview(): Promise<void> {
  isLoading.value = true;
  error.value = null;
  try {
    const res = await ScheduleService.resyncPreview();
    preview.value = res;
    // Default each orphan to its suggested mapel (or skip when none).
    for (const key of Object.keys(selections)) delete selections[key];
    for (const orphan of res.orphans) {
      selections[orphan.schedule_id] = orphan.suggested?.id ?? SKIP;
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function apply(): Promise<void> {
  if (!preview.value || resolvedCount.value === 0) return;
  isApplying.value = true;
  try {
    const mappings = preview.value.orphans
      .filter((o) => selections[o.schedule_id] && selections[o.schedule_id] !== SKIP)
      .map((o) => ({
        schedule_id: o.schedule_id,
        target_subject_id: selections[o.schedule_id],
      }));
    const res = await ScheduleService.resyncApply(mappings);
    if (res.failed.length > 0) {
      toast.value = {
        message: $t('admin.schedule.resync.appliedPartial', {
          updated: res.updated,
          failed: res.failed.length,
        }),
        tone: 'error',
      };
    } else {
      toast.value = {
        message: $t('admin.schedule.resync.applied', { updated: res.updated }),
        tone: 'success',
      };
    }
    // Reload so freshly-linked slots drop off the list; the ones that
    // failed (or were skipped) remain for another pass.
    await loadPreview();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isApplying.value = false;
  }
}

function goBack(): void {
  router.push({ name: 'admin.schedule' });
}

onMounted(loadPreview);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="$t('admin.shared.kicker')"
      :title="$t('admin.schedule.resync.title')"
      :meta="$t('admin.schedule.resync.meta', { count: preview?.total ?? 0 })"
    >
      <button
        type="button"
        class="text-2xs font-bold text-white/90 hover:text-white px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 transition-colors flex items-center gap-1.5"
        @click="goBack"
      >
        <NavIcon name="arrow-left" :size="12" />
        {{ $t('admin.schedule.resync.back') }}
      </button>
    </BrandPageHeader>

    <!-- Explainer banner — why these slots are here + what "Terapkan" does. -->
    <div
      class="rounded-2xl border border-amber-200 bg-amber-50 p-4"
      role="note"
    >
      <p class="text-3xs font-black uppercase tracking-widest text-amber-700 flex items-center gap-1.5">
        <NavIcon name="link" :size="12" />
        {{ $t('admin.schedule.resync.explainerBadge') }}
      </p>
      <p class="text-[13px] text-amber-900 mt-1.5 leading-relaxed">
        {{ $t('admin.schedule.resync.explainerBody') }}
      </p>
    </div>

    <AsyncView
      :state="state"
      :empty-title="$t('admin.schedule.resync.emptyTitle')"
      :empty-description="$t('admin.schedule.resync.emptyDesc')"
      empty-icon="check-circle"
      @retry="loadPreview"
    >
      <ul class="space-y-2">
        <li
          v-for="o in preview?.orphans ?? []"
          :key="o.schedule_id"
          class="rounded-2xl border border-slate-200 bg-white p-3 sm:p-4"
        >
          <div class="flex flex-col sm:flex-row sm:items-center gap-3">
            <!-- OLD (orphan) side -->
            <div class="min-w-0 flex-1">
              <p class="text-3xs font-bold uppercase tracking-widest text-slate-400">
                {{ $t('admin.schedule.resync.oldLabel') }}
              </p>
              <p class="text-[14px] font-black text-slate-900 truncate">
                {{ o.old_name || '—' }}
                <span v-if="gradeText(o.old_grade)" class="text-slate-400 font-bold">
                  · {{ gradeText(o.old_grade) }}
                </span>
              </p>
              <p class="text-2xs text-slate-500 truncate mt-0.5">
                {{ o.bin_label }}
              </p>
            </div>

            <NavIcon
              name="arrow-right"
              :size="16"
              class="hidden sm:block text-slate-300 flex-shrink-0"
            />

            <!-- NEW (target) side -->
            <div class="min-w-0 flex-1">
              <label
                :for="`resync-${o.schedule_id}`"
                class="text-3xs font-bold uppercase tracking-widest text-slate-400"
              >
                {{ $t('admin.schedule.resync.newLabel') }}
              </label>
              <div class="flex items-center gap-2 mt-0.5">
                <select
                  :id="`resync-${o.schedule_id}`"
                  v-model="selections[o.schedule_id]"
                  class="block w-full rounded-lg border border-slate-300 px-2 py-2 text-[13px] font-bold text-slate-900 focus:border-role-admin focus:outline-none focus:ring-2 focus:ring-role-admin/20"
                >
                  <option
                    v-for="opt in optionsFor(o)"
                    :key="opt.id"
                    :value="opt.id"
                  >
                    {{ opt.name
                    }}{{ gradeText(opt.grade) ? ` · ${gradeText(opt.grade)}` : '' }} ({{ opt.similarity }}%)
                  </option>
                  <option :value="SKIP">
                    {{ $t('admin.schedule.resync.skip') }}
                  </option>
                </select>
                <span
                  v-if="selectedSimilarity(o) !== null"
                  class="flex-shrink-0 text-4xs font-black uppercase tracking-wider px-2 py-1 rounded-full"
                  :class="
                    (selectedSimilarity(o) ?? 0) >= 80
                      ? 'bg-emerald-100 text-emerald-700'
                      : 'bg-amber-100 text-amber-700'
                  "
                >
                  {{ selectedSimilarity(o) }}%
                </span>
                <span
                  v-else
                  class="flex-shrink-0 text-4xs font-black uppercase tracking-wider px-2 py-1 rounded-full bg-slate-100 text-slate-500"
                >
                  {{ $t('admin.schedule.resync.skippedBadge') }}
                </span>
              </div>
              <p
                v-if="optionsFor(o).length === 0"
                class="text-2xs text-amber-600 mt-1"
              >
                {{ $t('admin.schedule.resync.noMatch') }}
              </p>
            </div>
          </div>
        </li>
      </ul>
    </AsyncView>

    <!-- Sticky apply bar — only when there is at least one orphan. -->
    <section
      v-if="state.status === 'content'"
      class="fixed bottom-4 left-1/2 -translate-x-1/2 z-30 bg-white border border-slate-200 rounded-2xl shadow-lg p-3 flex items-center gap-3 max-w-2xl w-[calc(100%-2rem)]"
    >
      <p class="text-2xs font-bold text-slate-700 flex-1">
        {{ $t('admin.schedule.resync.resolvedCount', {
          resolved: resolvedCount,
          total: preview?.total ?? 0,
        }) }}
      </p>
      <Button
        variant="primary"
        size="sm"
        :loading="isApplying"
        :disabled="resolvedCount === 0"
        @click="apply"
      >
        <NavIcon name="check" :size="12" />
        {{ $t('admin.schedule.resync.apply', { count: resolvedCount }) }}
      </Button>
    </section>

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
