<!--
  SuperAdminOverviewView.vue — "Ringkasan Platform" overview page.

  The KamilEdu-team landing surface for the dedicated /super-admin area.
  Shows four headline cards summarising the demo-request pipeline:

    1. Total Sekolah        — total tenants on the platform.
    2. Demo Aktif           — currently-activated demos (approved requests).
    3. Permintaan Pending   — demo requests awaiting review.
    4. Demo Akan Berakhir   — activated demos expiring within 3 days.

  DATA SOURCING (no fabricated numbers):
    - Cards 2/3/4 are computed from the EXISTING super-admin endpoint
      GET /demo-requests (DemoRequestService.list). Pending uses the
      `pending` filter's total; Demo Aktif uses the `approved` filter's
      total; Akan Berakhir counts approved rows whose `demo_expires_at`
      falls within the next 3 days.
    - Card 1 (Total Sekolah) has NO platform-wide schools endpoint in
      the services layer yet, so it renders a tasteful "—" placeholder
      with an "endpoint coming soon" hint rather than a made-up number.

  Authorisation is enforced server-side by EnsureSuperAdmin; a 403
  surfaces here as a friendly inline error on the affected cards.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterLink } from 'vue-router';
import { DemoRequestService } from '@/services/demo-request.service';
import type { DemoRequest } from '@/types/demo-request';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';
import { formatDateTime } from '@/lib/format';

const { t } = useI18n();

// ── Load state ─────────────────────────────────────────────────────
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// Totals straight from the paginated meta (authoritative, not a
// page-length count).
const pendingTotal = ref<number | null>(null);
const approvedTotal = ref<number | null>(null);
// Approved rows (most-recent page) used to surface upcoming expiries.
const approvedRows = ref<DemoRequest[]>([]);

const EXPIRY_WINDOW_DAYS = 3;

/**
 * Number of activated demos expiring within EXPIRY_WINDOW_DAYS. Counted
 * client-side from the approved rows we already fetched. This is a
 * best-effort signal scoped to the first page of approved requests —
 * when a dedicated endpoint lands it can return an exact total.
 */
const expiringSoon = computed<DemoRequest[]>(() => {
  const now = Date.now();
  const horizon = now + EXPIRY_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  return approvedRows.value.filter((r) => {
    if (!r.demo_expires_at) return false;
    const t = new Date(r.demo_expires_at).getTime();
    return !Number.isNaN(t) && t >= now && t <= horizon;
  });
});

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    // Two cheap calls: one for the pending total, one for the approved
    // (active demo) total + their expiry dates. `per_page` is bumped on
    // the approved call so the expiry scan covers more rows.
    const [pending, approved] = await Promise.all([
      DemoRequestService.list({ status: 'pending', per_page: 1, page: 1 }),
      DemoRequestService.list({ status: 'approved', per_page: 100, page: 1 }),
    ]);
    pendingTotal.value = pending.meta.total;
    approvedTotal.value = approved.meta.total;
    approvedRows.value = approved.items;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

// ── Card model ─────────────────────────────────────────────────────
interface OverviewCard {
  key: string;
  labelKey: string;
  icon: string;
  /** Resolved value, or null while loading / unavailable. */
  value: () => number | null;
  /** True when no backend source exists yet → show placeholder. */
  unavailable?: boolean;
  hintKey?: string;
  tone: 'navy' | 'emerald' | 'amber' | 'rose';
}

const cards: OverviewCard[] = [
  {
    key: 'totalSchools',
    labelKey: 'superAdmin.overview.totalSchools',
    icon: 'school',
    value: () => null,
    unavailable: true,
    hintKey: 'superAdmin.overview.endpointComingSoon',
    tone: 'navy',
  },
  {
    key: 'activeDemos',
    labelKey: 'superAdmin.overview.activeDemos',
    icon: 'rocket',
    value: () => approvedTotal.value,
    tone: 'emerald',
  },
  {
    key: 'pendingRequests',
    labelKey: 'superAdmin.overview.pendingRequests',
    icon: 'clock',
    value: () => pendingTotal.value,
    tone: 'amber',
  },
  {
    key: 'expiringSoon',
    labelKey: 'superAdmin.overview.expiringSoon',
    icon: 'alert-triangle',
    value: () => (isLoading.value ? null : expiringSoon.value.length),
    hintKey: 'superAdmin.overview.expiringSoonHint',
    tone: 'rose',
  },
];

// Tailwind tone tokens per card (kept off the role palette so the
// overview reads as a distinct platform surface while still living in
// the same theme).
const toneClasses: Record<OverviewCard['tone'], { ring: string; icon: string; chip: string }> = {
  navy: {
    ring: 'ring-role-admin/10',
    icon: 'bg-role-admin-soft text-role-admin',
    chip: 'text-role-admin',
  },
  emerald: {
    ring: 'ring-emerald-500/10',
    icon: 'bg-emerald-50 text-emerald-600',
    chip: 'text-emerald-600',
  },
  amber: {
    ring: 'ring-amber-500/10',
    icon: 'bg-amber-50 text-amber-600',
    chip: 'text-amber-600',
  },
  rose: {
    ring: 'ring-rose-500/10',
    icon: 'bg-rose-50 text-rose-600',
    chip: 'text-rose-600',
  },
};

function displayValue(card: OverviewCard): string {
  if (card.unavailable) return '—';
  const v = card.value();
  if (v === null) return '—';
  return String(v);
}
</script>

<template>
  <div class="space-y-5 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="t('superAdmin.kicker')"
      :title="t('superAdmin.overview.title')"
      :meta="t('superAdmin.overview.subtitle')"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 px-3 py-1.5 text-xs font-bold text-white transition"
        @click="load"
      >
        <NavIcon name="refresh-cw" :size="14" />
        {{ t('common.refresh') }}
      </button>
    </BrandPageHeader>

    <!-- ERROR BANNER (load-level) -->
    <p
      v-if="loadError"
      class="text-xs text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3"
    >
      {{ loadError }}
    </p>

    <!-- SUMMARY CARDS -->
    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
      <div
        v-for="card in cards"
        :key="card.key"
        class="bg-white rounded-2xl border border-slate-200 ring-4 p-5 flex flex-col gap-3 transition hover:shadow-sm"
        :class="toneClasses[card.tone].ring"
      >
        <div class="flex items-center justify-between">
          <div
            class="w-11 h-11 rounded-xl grid place-items-center"
            :class="toneClasses[card.tone].icon"
          >
            <NavIcon :name="card.icon" :size="20" />
          </div>
          <Spinner v-if="isLoading && !card.unavailable" size="sm" />
        </div>
        <div>
          <p class="text-3xl font-black text-slate-900 tabular-nums leading-none">
            {{ displayValue(card) }}
          </p>
          <p class="text-xs font-bold text-slate-500 mt-2">
            {{ t(card.labelKey) }}
          </p>
          <p
            v-if="card.hintKey"
            class="text-[11px] text-slate-400 mt-1"
          >
            {{ t(card.hintKey) }}
          </p>
        </div>
      </div>
    </div>

    <!-- QUICK ACTIONS -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <RouterLink
        to="/super-admin/demo-requests"
        class="group bg-white rounded-2xl border border-slate-200 p-5 flex items-center gap-4 hover:border-role-admin/40 hover:shadow-sm transition"
      >
        <div class="w-12 h-12 rounded-xl bg-role-admin-soft text-role-admin grid place-items-center flex-shrink-0">
          <NavIcon name="clipboard-list" :size="22" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="font-bold text-slate-900">{{ t('superAdmin.nav.demoRequests') }}</p>
          <p class="text-xs text-slate-500 mt-0.5">
            {{ t('superAdmin.overview.demoRequestsCta') }}
          </p>
        </div>
        <NavIcon
          name="chevron-right"
          :size="20"
          class="text-slate-300 group-hover:text-role-admin transition flex-shrink-0"
        />
      </RouterLink>

      <RouterLink
        to="/super-admin/schools"
        class="group bg-white rounded-2xl border border-slate-200 p-5 flex items-center gap-4 hover:border-role-admin/40 hover:shadow-sm transition"
      >
        <div class="w-12 h-12 rounded-xl bg-role-admin-soft text-role-admin grid place-items-center flex-shrink-0">
          <NavIcon name="school" :size="22" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="font-bold text-slate-900">{{ t('superAdmin.nav.schools') }}</p>
          <p class="text-xs text-slate-500 mt-0.5">
            {{ t('superAdmin.overview.schoolsCta') }}
          </p>
        </div>
        <NavIcon
          name="chevron-right"
          :size="20"
          class="text-slate-300 group-hover:text-role-admin transition flex-shrink-0"
        />
      </RouterLink>
    </div>

    <!-- EXPIRING-SOON LIST (only when we have any) -->
    <section
      v-if="!isLoading && expiringSoon.length"
      class="bg-white rounded-2xl border border-slate-200 p-5"
    >
      <div class="flex items-center gap-2 mb-3">
        <div class="w-8 h-8 rounded-lg bg-rose-50 text-rose-600 grid place-items-center">
          <NavIcon name="alert-triangle" :size="16" />
        </div>
        <h2 class="text-sm font-black text-slate-900">
          {{ t('superAdmin.overview.expiringSoonTitle') }}
        </h2>
      </div>
      <ul class="divide-y divide-slate-100">
        <li
          v-for="row in expiringSoon"
          :key="row.id"
          class="flex items-center gap-3 py-2.5"
        >
          <div class="w-9 h-9 rounded-lg bg-slate-50 text-slate-400 grid place-items-center flex-shrink-0">
            <NavIcon name="school" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-bold text-slate-900 truncate">
              {{ row.school_summary.name ?? t('superAdmin.schools.unnamed') }}
            </p>
            <p class="text-[11px] text-slate-400 truncate">
              {{ row.full_name }}
            </p>
          </div>
          <span class="text-[11px] font-bold text-rose-600 tabular-nums flex-shrink-0">
            {{ formatDateTime(row.demo_expires_at) || '—' }}
          </span>
        </li>
      </ul>
    </section>
  </div>
</template>
