<!--
  SuperAdminSchoolsView.vue — "Sekolah / Tenant" directory.

  Splits every platform tenant into three tabs backed by
  GET /super-admin/tenants:
    - Aktif (paid): schools.is_demo=false — the tenants actually
      paying us.
    - Demo: schools.is_demo=true — trial tenants with a 7-day TTL.
    - Semua: no filter.

  Previously this page listed approved demo-requests (the only
  super-admin-facing tenant surface we had), which meant paid tenants
  were invisible and we had to disclose that in a coverage notice.
  With the new /super-admin/tenants endpoint we drop the DemoRequest
  crutch entirely and render straight from `schools`.

  Row projection includes latest subscription status + expiry, seat
  counts (correctly derived per tenant_type — bimbel reads tutors
  from users_roles, sekolah reads from the teachers+staff tables),
  and — for demo tenants — the demo TTL.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { SuperAdminTenantService } from '@/services/super-admin-tenant.service';
import type {
  PlatformTenant,
  PlatformTenantMeta,
  TenantScope,
} from '@/types/super-admin-tenant';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Pagination from '@/components/data/Pagination.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDateTime } from '@/lib/format';
import type { Pagination as PaginationModel } from '@/types/api';

const { t } = useI18n();

// ── Tab + list state ───────────────────────────────────────────────
type TabKey = TenantScope;
const TABS: { key: TabKey; labelKey: string }[] = [
  { key: 'paid', labelKey: 'superAdmin.schools.tabs.paid' },
  { key: 'demo', labelKey: 'superAdmin.schools.tabs.demo' },
  { key: 'all', labelKey: 'superAdmin.schools.tabs.all' },
];
const activeTab = ref<TabKey>('paid');
const search = ref('');
const page = ref(1);
const PER_PAGE = 20;

const rows = ref<PlatformTenant[]>([]);
const meta = ref<PlatformTenantMeta | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await SuperAdminTenantService.list({
      scope: activeTab.value,
      search: search.value || undefined,
      per_page: PER_PAGE,
      page: page.value,
    });
    rows.value = res.items;
    meta.value = res.meta;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

function setTab(key: TabKey) {
  if (activeTab.value === key) return;
  activeTab.value = key;
  page.value = 1;
  load();
}

function goToPage(p: number) {
  page.value = p;
  load();
}

// Debounce search — 300ms so we don't fire on every keystroke.
let searchTimer: number | null = null;
watch(search, () => {
  if (searchTimer !== null) window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => {
    page.value = 1;
    load();
  }, 300) as unknown as number;
});

onMounted(load);

// ── Derived ────────────────────────────────────────────────────────
const listState = computed<AsyncState<PlatformTenant[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

const paginationModel = computed<PaginationModel | null>(() => {
  const m = meta.value;
  if (!m || m.last_page <= 1) return null;
  return {
    total_items: m.total,
    total_pages: m.last_page,
    current_page: m.current_page,
    per_page: m.per_page,
    has_next_page: m.current_page < m.last_page,
    has_prev_page: m.current_page > 1,
  };
});

const headerMeta = computed(() => {
  if (!meta.value) return t('superAdmin.schools.loading');
  const tabLabel = t(
    TABS.find((tab) => tab.key === activeTab.value)?.labelKey ?? '',
  );
  return t('superAdmin.schools.headerMeta', {
    count: meta.value.total,
    tab: tabLabel,
  });
});

// ── Row helpers ────────────────────────────────────────────────────
function tenantTypeLabel(row: PlatformTenant): string {
  return row.tenant_type === 'tutoring'
    ? t('superAdmin.schools.typeBimbel')
    : t('superAdmin.schools.typeSekolah');
}

function tenantTypeClass(row: PlatformTenant): string {
  return row.tenant_type === 'tutoring'
    ? 'bg-indigo-50 text-indigo-700 border-indigo-200'
    : 'bg-blue-50 text-blue-700 border-blue-200';
}

/**
 * Prefer the subscription-derived state (Aktif / Menunggu / Kadaluwarsa)
 * over the schools.status flag — the sub captures the customer's
 * lifecycle, the school flag is just a bookkeeping bit.
 */
function primaryState(row: PlatformTenant): {
  label: string;
  cls: string;
  icon: 'check-circle' | 'clock' | 'alert-triangle' | 'circle';
} {
  const ss = row.subscription_status;
  if (ss === 'active') {
    return {
      label: t('superAdmin.schools.state.subActive'),
      cls: 'bg-emerald-100 text-emerald-800 border-emerald-200',
      icon: 'check-circle',
    };
  }
  if (ss === 'pending_payment' || ss === 'awaiting_verify') {
    return {
      label: t('superAdmin.schools.state.subPending'),
      cls: 'bg-amber-100 text-amber-800 border-amber-200',
      icon: 'clock',
    };
  }
  if (ss === 'expired') {
    return {
      label: t('superAdmin.schools.state.subExpired'),
      cls: 'bg-rose-100 text-rose-800 border-rose-200',
      icon: 'alert-triangle',
    };
  }
  if (row.is_demo) {
    return {
      label: t('superAdmin.schools.state.demo'),
      cls: 'bg-amber-50 text-amber-700 border-amber-200',
      icon: 'clock',
    };
  }
  return {
    label: t('superAdmin.schools.state.inactive'),
    cls: 'bg-slate-100 text-slate-500 border-slate-200',
    icon: 'circle',
  };
}

const EXPIRING_WINDOW_DAYS = 3;
function demoExpirySoon(row: PlatformTenant): boolean {
  if (!row.is_demo || !row.demo_expires_at) return false;
  const exp = new Date(row.demo_expires_at).getTime();
  if (Number.isNaN(exp)) return false;
  return exp <= Date.now() + EXPIRING_WINDOW_DAYS * 24 * 60 * 60 * 1000
      && exp >= Date.now();
}

function activeUntil(row: PlatformTenant): string | null {
  // Paid rows show subscription expiry; demo rows show TTL.
  const iso = row.subscription_expires_at ?? row.demo_expires_at;
  return iso ? formatDateTime(iso) : null;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('superAdmin.kicker')"
      :title="t('superAdmin.schools.title')"
      :meta="headerMeta"
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

    <!-- Tabs + search -->
    <div class="flex flex-col sm:flex-row sm:items-center gap-3">
      <div class="flex items-center gap-2 flex-wrap">
        <button
          v-for="tab in TABS"
          :key="tab.key"
          type="button"
          class="rounded-full px-3.5 py-1.5 text-xs font-bold border transition"
          :class="
            activeTab === tab.key
              ? 'bg-role-admin text-white border-role-admin'
              : 'bg-white text-slate-500 border-slate-200 hover:bg-slate-50'
          "
          @click="setTab(tab.key)"
        >
          {{ t(tab.labelKey) }}
        </button>
      </div>
      <div class="relative flex-1 sm:max-w-xs">
        <NavIcon
          name="search"
          :size="14"
          class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
        />
        <input
          v-model="search"
          type="text"
          :placeholder="t('superAdmin.schools.searchPlaceholder')"
          class="w-full rounded-lg border border-slate-200 bg-white pl-8 pr-3 py-1.5 text-xs focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none"
        />
      </div>
    </div>

    <!-- LIST -->
    <AsyncView
      :state="listState"
      :empty-title="t('superAdmin.schools.emptyTitle')"
      :empty-description="t('superAdmin.schools.emptyDescription')"
      empty-icon="inbox"
      @retry="load"
    >
      <div class="space-y-2">
        <div
          v-for="row in rows"
          :key="row.id"
          class="bg-white border border-slate-200 rounded-2xl p-4 flex items-start gap-3"
        >
          <div
            class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
            :class="row.tenant_type === 'tutoring'
                ? 'bg-indigo-50 text-indigo-600'
                : 'bg-blue-50 text-blue-600'"
          >
            <NavIcon
              :name="row.tenant_type === 'tutoring' ? 'book-open' : 'school'"
              :size="18"
            />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-slate-900 truncate">
                {{ row.name || t('superAdmin.schools.unnamed') }}
              </span>
              <span
                class="text-3xs font-bold uppercase tracking-wide px-2 py-0.5 rounded border"
                :class="tenantTypeClass(row)"
              >
                {{ tenantTypeLabel(row) }}
              </span>
              <span
                class="text-3xs font-bold uppercase tracking-wide px-2 py-0.5 rounded-full border inline-flex items-center gap-1"
                :class="primaryState(row).cls"
              >
                <NavIcon :name="primaryState(row).icon" :size="10" />
                {{ primaryState(row).label }}
              </span>
              <span
                v-if="demoExpirySoon(row)"
                class="text-3xs font-bold uppercase tracking-wide px-2 py-0.5 rounded-full border bg-amber-50 text-amber-700 border-amber-200"
              >
                {{ t('superAdmin.schools.state.expiringSoon') }}
              </span>
            </div>
            <p class="text-xs text-slate-500 mt-1">
              <span class="tabular-nums font-semibold text-slate-700">{{ row.student_count }}</span>
              {{ t('superAdmin.schools.students') }}
              <span class="text-slate-300"> · </span>
              <span class="tabular-nums font-semibold text-slate-700">{{ row.staff_count }}</span>
              {{ row.tenant_type === 'tutoring'
                  ? t('superAdmin.schools.tutors')
                  : t('superAdmin.schools.staff') }}
              <template v-if="row.education_level">
                <span class="text-slate-300"> · </span>
                <span>{{ row.education_level }}</span>
              </template>
              <template v-if="row.city">
                <span class="text-slate-300"> · </span>
                <span>{{ row.city }}</span>
              </template>
            </p>
          </div>
          <div class="text-right flex-shrink-0 min-w-[110px]">
            <p class="text-3xs text-slate-400 uppercase tracking-wide">
              {{ row.is_demo && !row.subscription_expires_at
                  ? t('superAdmin.schools.demoExpiresAt')
                  : t('superAdmin.schools.subExpiresAt') }}
            </p>
            <p class="text-xs font-bold text-slate-700 tabular-nums mt-0.5">
              {{ activeUntil(row) ?? '—' }}
            </p>
            <p v-if="row.subscription_plan" class="text-3xs text-slate-400 mt-0.5">
              {{ row.subscription_plan === 'yearly'
                  ? t('subscribe.calc.yearly')
                  : t('subscribe.calc.monthly') }}
            </p>
          </div>
        </div>
      </div>

      <div v-if="paginationModel" class="mt-5">
        <Pagination :pagination="paginationModel" @change="goToPage" />
      </div>
    </AsyncView>
  </div>
</template>
