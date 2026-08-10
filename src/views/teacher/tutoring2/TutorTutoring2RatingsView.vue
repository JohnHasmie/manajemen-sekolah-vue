<!--
  TutorTutoring2RatingsView.vue — self-ratings dashboard for the
  logged-in tutor (WEB-13, wires BE-20 TutorRatingsController::showSelf).

  Route: /teacher/tutoring2/ratings
  Endpoint: GET /tutoring-v2/tutors/me/ratings — deliberately bypasses
  `tutoring.tutor.view` on the backend, so this view does NOT gate on
  it either.

  Layout:
    1. BrandPageHeader
    2. Hero — big avg display + total ratings + star row
    3. Distribution bar chart — one row per rating 5..1 with a
       proportional bar (widest for the most-frequent rating)
    4. Recent comments — up to 5 latest notes with rating pill
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { RatingsService } from '@/services/tutoring2/ratings';
import type { TutorRatingSummary } from '@/types/tutoring2/rating';

const { t } = useI18n();

const { state, reload } = useDataRefresh(async () => {
  return await RatingsService.getSelf();
}, {
  // The summary object always comes back, with zeroes when nobody has
  // rated this tutor — so without a predicate the empty state can never
  // fire. Note the computed below already reads `status === 'empty'`:
  // the author expected this to work.
  isEmpty: (d) => (d?.total_ratings ?? 0) === 0,
});

const summary = computed<TutorRatingSummary | null>(() => {
  return state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as TutorRatingSummary | undefined) ?? null)
    : null;
});

const avgDisplay = computed(() => {
  const v = summary.value?.avg_rating;
  return v == null ? '—' : v.toFixed(1);
});

const totalDisplay = computed(() => summary.value?.total_ratings ?? 0);

// Distribution rendered top-down 5 → 1 so the highest rating anchors
// the top row (mirrors app store / marketplace conventions).
const distributionRows = computed(() => {
  const dist = summary.value?.distribution ?? { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  const max = Math.max(1, ...[dist[1], dist[2], dist[3], dist[4], dist[5]]);
  return [5, 4, 3, 2, 1].map((star) => {
    const count = dist[star as 1 | 2 | 3 | 4 | 5] ?? 0;
    const pct = Math.round((count / max) * 100);
    return { star, count, pct };
  });
});

const notes = computed(() => summary.value?.last_5_notes ?? []);

function formatWhen(iso?: string | null): string {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.ratings.title')"
      :meta="state.status === 'loading'
        ? t('tutoring2.common.loading')
        : t('tutoring2.tutor.ratings.meta', { count: totalDisplay })"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="2"
      :empty-title="t('tutoring2.tutor.ratings.emptyTitle')"
      :empty-description="t('tutoring2.tutor.ratings.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div v-if="!summary || totalDisplay === 0" class="rounded-3xl border border-slate-100 bg-white p-6 text-center text-sm text-slate-500 shadow-sm">
          {{ t('tutoring2.tutor.ratings.emptyDesc') }}
        </div>
        <template v-else>
          <!-- Hero -->
          <div class="rounded-3xl border border-slate-100 bg-white p-6 shadow-sm flex items-center gap-6">
            <div class="text-center">
              <p class="text-6xl font-black text-brand-cobalt leading-none">{{ avgDisplay }}</p>
              <p class="text-xs text-slate-500 mt-1">{{ t('tutoring2.tutor.ratings.outOf') }}</p>
              <div class="flex items-center justify-center gap-0.5 mt-2">
                <NavIcon
                  v-for="s in 5"
                  :key="s"
                  name="star"
                  :size="16"
                  :class="s <= Math.round(summary.avg_rating ?? 0) ? 'text-amber-500' : 'text-slate-300'"
                />
              </div>
            </div>
            <div class="flex-1 min-w-0 space-y-1">
              <p class="text-sm font-bold text-slate-900">{{ t('tutoring2.tutor.ratings.averageLabel') }}</p>
              <p class="text-xs text-slate-500">
                {{ t('tutoring2.tutor.ratings.basedOn', { count: totalDisplay }) }}
              </p>
            </div>
          </div>

          <!-- Distribution -->
          <div class="rounded-3xl border border-slate-100 bg-white p-6 shadow-sm space-y-3">
            <h3 class="text-sm font-bold text-slate-900">{{ t('tutoring2.tutor.ratings.distributionTitle') }}</h3>
            <ul class="space-y-2">
              <li v-for="row in distributionRows" :key="row.star" class="flex items-center gap-3">
                <span class="w-8 text-xs font-bold text-slate-700 flex items-center gap-0.5">
                  {{ row.star }}
                  <NavIcon name="star" :size="12" class="text-amber-500" />
                </span>
                <div class="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
                  <div
                    class="h-full bg-brand-cobalt rounded-full transition-all"
                    :style="{ width: row.pct + '%' }"
                  />
                </div>
                <span class="w-10 text-right text-xs text-slate-500">{{ row.count }}</span>
              </li>
            </ul>
          </div>

          <!-- Recent comments -->
          <div class="rounded-3xl border border-slate-100 bg-white p-6 shadow-sm space-y-3">
            <h3 class="text-sm font-bold text-slate-900">{{ t('tutoring2.tutor.ratings.notesTitle') }}</h3>
            <div v-if="notes.length === 0" class="text-sm text-slate-500 py-4 text-center">
              {{ t('tutoring2.tutor.ratings.notesEmpty') }}
            </div>
            <ul v-else class="divide-y divide-slate-100">
              <li v-for="(note, i) in notes" :key="i" class="py-3 space-y-1">
                <div class="flex items-center gap-2">
                  <StatusBadge :label="`${note.rating} / 5`" tone="info" uppercase />
                  <span class="text-2xs text-slate-500">{{ formatWhen(note.created_at) }}</span>
                </div>
                <p class="text-sm text-slate-700 whitespace-pre-line">{{ note.notes }}</p>
              </li>
            </ul>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
