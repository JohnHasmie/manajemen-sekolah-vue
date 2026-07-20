<!--
  AdminReadinessView.vue — /admin/readiness ("Pusat Kendali Sekolah")

  Admin command-center page. The hero metric is a computed Skor
  Kesiapan Sekolah %, not points-vs-others — admins have no peers, so a
  leaderboard would read hollow. Below the hero, dimensions decompose
  the score, and two lanes list actionable items:
    · Lane A "Perlu dilengkapi" (completion_needed) — SCORED completeness
      gaps, deep-linking into the CRUD screens that fix them.
    · Lane B "Perlu perhatian" (attention_needed) — operational items,
      NOT scored, reusing PriorityInboxItem shape and PriorityInbox.vue.

  Level/streak/delta chips only render once the BE-4 habit-layer ships;
  until then the payload returns them null and the chip row hides
  itself so the layout doesn't leave an empty band.

  Locked design choices worth calling out:
    · CORE feature — no `module:` middleware server-side, gated only by
      the `readiness.view` RBAC ability. That's why the route meta above
      is a plain `ability`, not `needs: '...-context'`.
    · The `target_route` on Lane A items is a BACKEND hint (a snake_case
      key like `admin_teacher_management`) — the view maps it to a real
      Vue route name via `mapRouteName`. Unmapped hints render a
      disabled CTA + console.warn so the miss is visible in QA.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import LevelXpRing from '@/components/feature/gamification/LevelXpRing.vue';
import PriorityInbox, { type PriorityItem } from '@/components/feature/PriorityInbox.vue';
import AdminBadgeTile from '@/components/feature/readiness/AdminBadgeTile.vue';
import { useAuthStore } from '@/stores/auth';
import {
  ReadinessService,
  type ReadinessPayload,
  type ReadinessCompletionItem,
  type ReadinessDimension,
  type ReadinessBadgeCatalogItem,
} from '@/services/readiness.service';
// Backend Lane-A/B `target_route` hints are snake_case keys that don't
// exist as literal Vue route names; the mapping lives in a shared helper
// (also consumed by the dashboard panel + control-center chips) so the
// three surfaces never drift.
import { resolveReadinessRouteName as mapRouteName } from '@/lib/readiness-nav';

const auth = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const state = ref<AsyncState<ReadinessPayload>>({ status: 'loading' });
const payload = ref<ReadinessPayload | null>(null);

const schoolName = computed<string>(
  () => auth.user?.school_name ?? auth.user?.name ?? 'Sekolah',
);
const headerKicker = computed(() => `ADMIN · ${schoolName.value}`);

// Ring semantics: LevelXpRing renders a filled arc equal to
// `xpInLevel / (xpInLevel + xpForNextLevel)`, so passing score+
// (100-score) makes the arc represent completeness pct.
const scoreForRing = computed(() => Math.max(0, Math.min(100, payload.value?.score ?? 0)));
const remainingForRing = computed(() => 100 - scoreForRing.value);

// Per-dimension fill colour follows the same reading as the KPI strip:
// cobalt when the dimension is "healthy" (≥80%), amber when it needs
// attention (<80%), slate when it isn't scored (module not entitled).
function dimensionBarClass(dim: ReadinessDimension): string {
  if (dim.pct === null) return 'bg-slate-300';
  if (dim.pct >= 80) return 'bg-brand-cobalt';
  return 'bg-amber-500';
}

function dimensionTagLabel(dim: ReadinessDimension): string {
  if (dim.required_modules.length === 0) return t('admin.readiness.tagCore');
  return t('admin.readiness.tagModule', { module: dim.required_modules[0] });
}

function severityDotClass(sev: string): string {
  switch (sev) {
    case 'critical':
      return 'bg-red-500';
    case 'warning':
      return 'bg-amber-500';
    default:
      return 'bg-slate-400';
  }
}

// Lane B — reuse PriorityInbox.vue. Its item type is structurally
// identical to `ReadinessAttentionItem`, but keep the mapping explicit
// so a shape drift on either side is caught by the compiler.
const attentionItems = computed<PriorityItem[]>(() => {
  const items = payload.value?.attention_needed ?? [];
  return items.map((item) => ({
    id: item.id,
    type: item.type,
    severity: item.severity,
    label: item.label,
    subtitle: item.subtitle,
    count: item.count,
    occurred_at: item.occurred_at,
    target_route: item.target_route,
    target_params: item.target_params,
  }));
});

function onCompletionTap(item: ReadinessCompletionItem) {
  const name = mapRouteName(item.target_route);
  if (!name) return;
  router.push({ name, params: item.target_params as Record<string, string> });
}

// ── Habit-layer chip helpers (BE-4) ────────────────────────────────
// All three fields are server-authoritative. Delta gets an extra layer
// of formatting (sign + tone) because a signed integer alone reads as
// noisy in the row of chips.

const deltaTone = computed<'up' | 'down' | 'flat' | null>(() => {
  const d = payload.value?.delta_pct;
  if (d === null || d === undefined) return null;
  if (d > 0) return 'up';
  if (d < 0) return 'down';
  return 'flat';
});

const deltaChipClass = computed(() => {
  switch (deltaTone.value) {
    case 'up':
      return 'bg-emerald-100 text-emerald-700';
    case 'down':
      return 'bg-red-100 text-red-700';
    case 'flat':
      return 'bg-slate-100 text-slate-600';
    default:
      return '';
  }
});

const deltaChipIcon = computed<string>(() => {
  switch (deltaTone.value) {
    case 'up':
      return 'trending-up';
    case 'down':
      return 'trending-down';
    default:
      return 'minus';
  }
});

/** Signed pct string, e.g. `+5`, `-3`, `0`. Consumed by the i18n arg. */
const deltaPctSigned = computed<string>(() => {
  const d = payload.value?.delta_pct ?? 0;
  return d > 0 ? `+${d}` : String(d);
});

/** True when the whole habit chip row is empty (first-visit fresh school). */
const habitRowEmpty = computed<boolean>(() => {
  const p = payload.value;
  if (!p) return true;
  const noLevel = p.level === null;
  const noStreak = p.streak === null || p.streak === 0;
  const noDelta = p.delta_pct === null;
  return noLevel && noStreak && noDelta;
});

// ── Badges (BE-5) ──────────────────────────────────────────────────
// Server returns `{ catalog, earned }` on the same payload. Match each
// catalog entry against earned by code — an entry appears in `earned`
// with `is_new: true` for 48h post-award, else `earned`, else `locked`.

function badgeStateFor(code: string): 'earned' | 'new' | 'locked' {
  const earned = payload.value?.badges?.earned ?? [];
  const hit = earned.find((b) => b.code === code);
  if (!hit) return 'locked';
  return hit.is_new ? 'new' : 'earned';
}

const badgeCatalog = computed<ReadinessBadgeCatalogItem[]>(
  () => payload.value?.badges?.catalog ?? [],
);

const badgesEarnedCount = computed<number>(
  () => payload.value?.badges?.earned?.length ?? 0,
);

function onAttentionTap(item: PriorityItem) {
  const name = mapRouteName(item.target_route);
  if (!name) {
    // Lane B routes are backend-owned — an unmapped hint here just
    // means no deep-link, not a broken screen.
    return;
  }
  router.push({ name, params: item.target_params as Record<string, string> });
}

async function load() {
  state.value = { status: 'loading' };
  try {
    const data = await ReadinessService.get();
    payload.value = data;
    state.value = { status: 'content', data };
  } catch (e) {
    state.value = { status: 'error', error: (e as Error).message };
  }
}

onMounted(() => {
  void load();
});
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="headerKicker"
      :title="t('admin.readiness.title')"
      :meta="t('admin.readiness.subtitle')"
    />

    <AsyncView :state="state" @retry="load">
      <template #default>
        <template v-if="payload">
          <!-- Unsupported tenant (e.g. bimbel MVP) — the endpoint answers
               `supported: false`. Skip every other section so the page
               reads as a soft empty state instead of a "0% siap" scare. -->
          <div
            v-if="!payload.supported"
            class="rounded-2xl bg-white border border-slate-100 shadow-sm p-8 text-center space-y-3"
          >
            <div class="w-14 h-14 rounded-full bg-slate-100 text-slate-500 grid place-items-center mx-auto">
              <NavIcon name="info" :size="24" />
            </div>
            <p class="text-sm font-bold text-slate-700">
              {{ t('admin.readiness.unsupported') }}
            </p>
          </div>

          <template v-else>
            <!-- Hero row: score ring + dimensions. On md+ the score card
                 sits at a fixed 240px so the dimensions card fills the
                 remaining width; below md they stack. -->
            <section class="grid grid-cols-1 md:grid-cols-[240px_1fr] gap-4">
              <!-- Score card -->
              <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-5 flex flex-col items-center gap-3">
                <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
                  {{ t('admin.readiness.scoreLabel') }}
                </p>
                <LevelXpRing
                  :level="scoreForRing"
                  :xp-in-level="scoreForRing"
                  :xp-for-next-level="remainingForRing"
                  :level-title="t('admin.readiness.scoreLabel')"
                  size="lg"
                />

                <!-- Habit chips row — BE-4 fills level / streak / delta.
                     Each chip renders independently: a first-visit fresh
                     school with only `level=1` gets the level chip and
                     nothing else, no empty band. When ALL three fall
                     null, a soft hint replaces the row so the space
                     doesn't read as "loading". -->
                <div
                  v-if="!habitRowEmpty"
                  class="flex items-center gap-2 flex-wrap justify-center"
                >
                  <span
                    v-if="payload.level !== null"
                    class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-violet-100 text-violet-700 text-3xs font-bold"
                  >
                    <NavIcon name="star" :size="12" />
                    {{ t('admin.readiness.levelChip', { level: payload.level }) }}
                  </span>
                  <span
                    v-if="payload.streak !== null && payload.streak > 0"
                    class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-orange-100 text-orange-700 text-3xs font-bold"
                  >
                    <NavIcon name="flame" :size="12" />
                    {{ t('admin.readiness.streakChip', { days: payload.streak }) }}
                  </span>
                  <span
                    v-if="payload.delta_pct !== null"
                    class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-3xs font-bold"
                    :class="deltaChipClass"
                  >
                    <NavIcon :name="deltaChipIcon" :size="12" />
                    {{ t('admin.readiness.deltaWeek', { pct: deltaPctSigned }) }}
                  </span>
                </div>

                <!-- First-visit hint — none of the three chips have
                     signal yet. Server-side snapshotting kicks in on
                     the next daily job; the hint sets that expectation. -->
                <p
                  v-else
                  class="text-2xs text-slate-500 text-center leading-snug"
                >
                  {{ t('admin.readiness.habitHint') }}
                </p>
              </div>

              <!-- Dimensions card -->
              <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-5">
                <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">
                  {{ t('admin.readiness.dimensionsHeader') }}
                </p>
                <ul class="space-y-3 mt-4">
                  <li
                    v-for="dim in payload.dimensions"
                    :key="dim.key"
                    class="space-y-1.5"
                  >
                    <div class="flex items-center justify-between gap-2">
                      <div class="flex items-center gap-2 min-w-0">
                        <p class="text-sm font-bold text-slate-800 truncate">
                          {{ t(`admin.readiness.dimensions.${dim.key}`) }}
                        </p>
                        <span
                          class="text-3xs font-bold px-2 py-0.5 rounded-full uppercase tracking-widest flex-shrink-0"
                          :class="dim.required_modules.length === 0
                            ? 'bg-slate-100 text-slate-500'
                            : 'bg-sky-50 text-sky-700'"
                        >
                          {{ dimensionTagLabel(dim) }}
                        </span>
                      </div>
                      <span class="text-sm font-black text-slate-900 flex-shrink-0">
                        {{ dim.pct !== null ? `${dim.pct}%` : '—' }}
                      </span>
                    </div>
                    <div class="h-2 rounded-full bg-slate-100 overflow-hidden">
                      <div
                        class="h-full rounded-full transition-all"
                        :class="dimensionBarClass(dim)"
                        :style="{ width: `${dim.pct ?? 0}%` }"
                      ></div>
                    </div>
                  </li>
                </ul>
              </div>
            </section>

            <!-- Lane A — Perlu dilengkapi (scored) -->
            <section class="rounded-2xl bg-white border border-slate-100 shadow-sm p-5 space-y-3">
              <header class="flex items-center gap-2 flex-wrap">
                <h3 class="text-sm font-black text-slate-900 uppercase tracking-tight">
                  {{ t('admin.readiness.laneA') }}
                </h3>
                <span
                  v-if="payload.completion_needed.length > 0"
                  class="text-3xs font-black px-2 py-0.5 rounded-full bg-red-50 text-red-700"
                >
                  {{ payload.completion_needed.length }}
                </span>
                <span class="text-2xs text-slate-500 font-bold ml-auto">
                  {{ t('admin.readiness.laneAHint') }}
                </span>
              </header>

              <div
                v-if="payload.completion_needed.length === 0"
                class="rounded-xl border border-emerald-100 bg-emerald-50 p-4 flex items-center gap-3"
              >
                <span class="w-9 h-9 rounded-full bg-emerald-100 text-emerald-600 grid place-items-center flex-shrink-0">
                  <NavIcon name="check-circle" :size="18" />
                </span>
                <p class="text-sm font-bold text-emerald-800">
                  {{ t('admin.readiness.allClear') }}
                </p>
              </div>

              <ul v-else class="space-y-2.5">
                <li
                  v-for="item in payload.completion_needed"
                  :key="item.key"
                  class="flex items-start gap-3 p-3 rounded-xl border border-slate-100 hover:border-brand-cobalt/30 hover:shadow-sm transition-all"
                >
                  <span
                    class="w-2 h-2 rounded-full mt-2 flex-shrink-0"
                    :class="severityDotClass(item.severity)"
                    aria-hidden="true"
                  ></span>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-bold text-slate-900 truncate">
                      {{ item.label }}
                    </p>
                    <p class="text-2xs text-slate-500 mt-0.5 line-clamp-1">
                      {{ item.subtitle }}
                    </p>
                  </div>
                  <button
                    type="button"
                    class="text-2xs font-black uppercase tracking-widest px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1 flex-shrink-0"
                    :class="mapRouteName(item.target_route)
                      ? 'bg-brand-cobalt/10 text-brand-cobalt hover:bg-brand-cobalt/20'
                      : 'bg-slate-100 text-slate-400 cursor-not-allowed'"
                    :disabled="!mapRouteName(item.target_route)"
                    @click="onCompletionTap(item)"
                  >
                    {{ t('common.fix') }}
                    <NavIcon name="arrow-right" :size="12" />
                  </button>
                </li>
              </ul>
            </section>

            <!-- Lane B — Perlu perhatian (operational, unscored) -->
            <section class="rounded-2xl bg-white border border-slate-100 shadow-sm p-5 space-y-3">
              <header class="flex items-center gap-2 flex-wrap">
                <h3 class="text-sm font-black text-slate-900 uppercase tracking-tight">
                  {{ t('admin.readiness.laneB') }}
                </h3>
                <span
                  v-if="attentionItems.length > 0"
                  class="text-3xs font-black px-2 py-0.5 rounded-full bg-slate-100 text-slate-600"
                >
                  {{ attentionItems.length }}
                </span>
                <span class="text-2xs text-slate-500 font-bold ml-auto">
                  {{ t('admin.readiness.laneBHint') }}
                </span>
              </header>

              <div
                v-if="attentionItems.length === 0"
                class="rounded-xl border border-slate-100 bg-slate-50 p-4 flex items-center gap-3"
              >
                <span class="w-9 h-9 rounded-full bg-slate-100 text-slate-500 grid place-items-center flex-shrink-0">
                  <NavIcon name="check-circle" :size="18" />
                </span>
                <p class="text-sm font-bold text-slate-700">
                  {{ t('admin.readiness.allCalm') }}
                </p>
              </div>

              <PriorityInbox
                v-else
                :items="attentionItems"
                :show-header="false"
                @item-tap="onAttentionTap"
              />
            </section>

            <!-- Pencapaian (Badges) — BE-5. The catalog always renders
                 in full (locked tiles for what isn't earned yet) so the
                 admin sees the roadmap of what's still to unlock, not
                 just a possibly-empty "earned" row on day 1. Server
                 owns copy (label + description in payload.badges.catalog)
                 so the FE only decides state + icon per code. -->
            <section
              v-if="badgeCatalog.length > 0"
              class="rounded-2xl bg-white border border-slate-100 shadow-sm p-5 space-y-3"
            >
              <header class="flex items-center gap-2 flex-wrap">
                <h3 class="text-sm font-black text-slate-900 uppercase tracking-tight">
                  {{ t('admin.readiness.badgesHeader') }}
                </h3>
                <span class="text-3xs font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 ml-auto">
                  {{ t('admin.readiness.badgesCounter', {
                    earned: badgesEarnedCount,
                    total: badgeCatalog.length,
                  }) }}
                </span>
              </header>
              <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
                <AdminBadgeTile
                  v-for="item in badgeCatalog"
                  :key="item.code"
                  :code="item.code"
                  :label="item.label"
                  :description="item.description"
                  :state="badgeStateFor(item.code)"
                />
              </div>
            </section>
          </template>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
