<!--
  TutorRatingsView — tutor's own rating dashboard. Mockup
  tutor_web_pages_profile_rating frame 3.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutorRatingsSummary } from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';

const { t } = useI18n();

const data = ref<TutorRatingsSummary | null>(null);
const loading = ref(true);
const filter = ref<'all' | '5' | '4' | 'low'>('all');

async function load() {
  loading.value = true;
  try {
    const stars =
      filter.value === '5' ? [5]
      : filter.value === '4' ? [4]
      : filter.value === 'low' ? [1, 2, 3]
      : undefined;
    data.value = await TutoringService.getTutorRatingsSummary({ stars });
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(filter, load);

const stars5pct = computed(() => {
  const d = data.value;
  if (!d || d.overall.count === 0) return 0;
  return Math.round(((d.distribution['5'] ?? 0) / d.overall.count) * 100);
});

function relTime(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 60) return t('tutor.bimbel.ratings.rel_min_ago', { n: Math.max(1, Math.floor(diffMin)) });
  const h = Math.floor(diffMin / 60);
  if (h < 24) return t('tutor.bimbel.ratings.rel_hour_ago', { n: h });
  const days = Math.floor(h / 24);
  if (days < 7) return t('tutor.bimbel.ratings.rel_day_ago', { n: days });
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

function stars(rating: number): string {
  return '★'.repeat(Math.round(rating)) + '☆'.repeat(5 - Math.round(rating));
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('tutor.bimbel.ratings.greeting')"
      :title="t('tutor.bimbel.ratings.title')"
      :subtitle="`${t('tutor.bimbel.ratings.subtitle_prefix')} · ${data?.overall.window_label ?? t('tutor.bimbel.ratings.window_default')}`"
      :stats="[]"
    >
      <template #actions>
        <div class="flex gap-1 rounded-full bg-white/10 ring-1 ring-white/20 p-1">
          <button
            v-for="opt in [
              { id: 'all' as const, label: t('tutor.bimbel.ratings.filter_all') },
              { id: '5' as const, label: t('tutor.bimbel.ratings.filter_5') },
              { id: '4' as const, label: t('tutor.bimbel.ratings.filter_4') },
              { id: 'low' as const, label: t('tutor.bimbel.ratings.filter_low') },
            ]"
            :key="opt.id"
            type="button"
            class="rounded-full px-3 py-1 text-[12px] font-semibold"
            :class="filter === opt.id ? 'bg-white text-bimbel-accent' : 'text-white/80'"
            @click="filter = opt.id"
          >{{ opt.label }}</button>
        </div>
      </template>
    </TutorHomeHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">{{ t('tutor.bimbel.ratings.loading') }}</div>

    <template v-else-if="data">
      <div class="grid gap-2.5 grid-cols-2 md:grid-cols-4">
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">{{ t('tutor.bimbel.ratings.kpi_average') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-bimbel-text-hi">{{ data.overall.avg?.toFixed(1) ?? '–' }}</p>
          <p class="text-amber-500 text-[16px] tracking-widest">{{ data.overall.avg != null ? stars(data.overall.avg) : '' }}</p>
        </div>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">{{ t('tutor.bimbel.ratings.kpi_reviews') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-bimbel-text-hi">{{ data.overall.count }}</p>
          <p class="text-[12px] text-bimbel-text-mid">
            {{ data.overall.delta != null && data.overall.delta !== 0 ? (data.overall.delta > 0 ? `+${data.overall.delta}` : data.overall.delta) + ' ' + t('tutor.bimbel.ratings.kpi_delta_vs_month') : t('tutor.bimbel.ratings.kpi_delta_none') }}
          </p>
        </div>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">{{ t('tutor.bimbel.ratings.kpi_5_pct') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-bimbel-text-hi">{{ stars5pct }}%</p>
          <p class="text-[12px] text-bimbel-text-mid">{{ t('tutor.bimbel.ratings.kpi_5_of', { count: data.distribution['5'] ?? 0, total: data.overall.count }) }}</p>
        </div>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">{{ t('tutor.bimbel.ratings.kpi_response') }}</p>
          <p class="mt-1 text-[22px] font-extrabold text-bimbel-text-hi">{{ data.response.rate ?? '–' }}%</p>
          <p class="text-[12px] text-bimbel-text-mid">{{ t('tutor.bimbel.ratings.kpi_response_of', { rated: data.response.rated_sessions, done: data.response.done_sessions }) }}</p>
        </div>
      </div>

      <!-- Per-group breakdown (mirrors mobile tutor_ratings_screen.dart). -->
      <div v-if="data.groups.length" class="space-y-2">
        <h4 class="text-[14px] font-bold text-bimbel-text-hi pt-2">{{ t('tutor.bimbel.ratings.per_group_heading') }}</h4>
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 space-y-2">
          <div
            v-for="(g, i) in data.groups"
            :key="g.group_id"
            class="flex items-center gap-3 py-1.5"
            :class="i < data.groups.length - 1 ? 'border-b border-bimbel-border-soft' : ''"
          >
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-bimbel-text-hi truncate">{{ g.group_name }}</p>
              <p class="text-[11px] text-bimbel-text-mid">{{ g.count }} {{ t('tutor.bimbel.ratings.reviews_suffix') }}</p>
            </div>
            <div class="text-right flex-shrink-0">
              <p class="text-[16px] font-extrabold text-bimbel-text-hi">{{ g.avg?.toFixed(1) ?? '–' }}</p>
              <p class="text-amber-500 text-[12px] tracking-wider">{{ g.avg != null ? stars(g.avg) : '' }}</p>
            </div>
          </div>
        </div>
      </div>

      <div class="space-y-2">
        <h4 class="text-[14px] font-bold text-bimbel-text-hi pt-2">{{ t('tutor.bimbel.ratings.comments_heading') }}</h4>
        <div v-if="data.recent.length === 0" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
          {{ t('tutor.bimbel.ratings.empty_comments') }}
        </div>
        <div
          v-for="r in data.recent"
          :key="r.id"
          class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5"
        >
          <div class="flex items-center gap-2 text-[13px] text-bimbel-text-mid mb-1">
            <span class="grid h-7 w-7 place-items-center rounded-full bg-bimbel-accent-dim text-bimbel-accent text-[12px] font-bold">
              {{ (r.student_name ?? '?')[0]?.toUpperCase() }}
            </span>
            <span>{{ r.student_name ?? t('tutor.bimbel.ratings.student_fallback') }}</span>
            <span v-if="r.group_name" class="rounded-full bg-bimbel-accent-dim text-bimbel-accent px-2 py-0.5 text-[12px]">{{ r.group_name }}</span>
            <span class="text-[12px] text-bimbel-text-lo">· {{ relTime(r.created_at) }}</span>
            <span class="ml-auto text-amber-500 text-[14px] tracking-wider">{{ stars(r.rating) }}</span>
          </div>
          <p v-if="r.comment" class="text-[13px] text-bimbel-text-mid leading-relaxed">{{ r.comment }}</p>
          <p v-else class="text-[12px] text-bimbel-text-lo italic">{{ t('tutor.bimbel.ratings.no_comment') }}</p>
        </div>
      </div>
    </template>
  </div>
</template>
