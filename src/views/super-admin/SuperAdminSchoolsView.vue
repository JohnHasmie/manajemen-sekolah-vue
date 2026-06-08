<!--
  SuperAdminSchoolsView.vue — "Sekolah / Tenant" list for super-admins.

  Lists the platform tenants with their demo status + expiry. There is
  NO platform-wide schools/tenant endpoint in the services layer yet —
  `AuthService.listSchools()` is user-scoped (a super-admin has no
  schools of their own), so it can't power a tenant directory.

  Rather than invent a backend endpoint, this page derives the tenant
  rows it CAN show from the EXISTING super-admin endpoint
  GET /demo-requests (approved rows = activated demo tenants, each with
  a name, education level, city, and `demo_expires_at`). A clear notice
  explains that paying/non-demo tenants will appear once a dedicated
  schools endpoint exists. If even the demo-request feed is empty the
  page shows a tasteful empty state — it never crashes.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { DemoRequestService } from '@/services/demo-request.service';
import type { DemoRequest, DemoRequestStatus } from '@/types/demo-request';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDateTime } from '@/lib/format';

const { t } = useI18n();

// ── List state ─────────────────────────────────────────────────────
const rows = ref<DemoRequest[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    // Activated demos are our best available proxy for "tenants" until a
    // dedicated schools endpoint exists. Pull a generous page.
    const res = await DemoRequestService.list({
      status: 'approved',
      per_page: 100,
      page: 1,
    });
    rows.value = res.items;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

const listState = computed<AsyncState<DemoRequest[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

// ── Expiry helpers ─────────────────────────────────────────────────
const EXPIRING_WINDOW_DAYS = 3;

type DemoState = 'active' | 'expiringSoon' | 'expired';

function demoState(row: DemoRequest): DemoState {
  if (!row.demo_expires_at) return 'active';
  const exp = new Date(row.demo_expires_at).getTime();
  if (Number.isNaN(exp)) return 'active';
  const now = Date.now();
  if (exp < now) return 'expired';
  if (exp <= now + EXPIRING_WINDOW_DAYS * 24 * 60 * 60 * 1000) {
    return 'expiringSoon';
  }
  return 'active';
}

const STATE_TONE: Record<DemoState, string> = {
  active: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  expiringSoon: 'bg-amber-50 text-amber-700 border-amber-200',
  expired: 'bg-slate-100 text-slate-500 border-slate-200',
};

function stateLabel(row: DemoRequest): string {
  return t(`superAdmin.schools.state.${demoState(row)}`);
}

// Map the underlying demo-request status to a small "tenant type" chip.
function tenantType(status: DemoRequestStatus): string {
  // Everything we can list today is a demo tenant.
  return status === 'approved'
    ? t('superAdmin.schools.typeDemo')
    : t('superAdmin.schools.typeOther');
}
</script>

<template>
  <div class="space-y-5 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="t('superAdmin.kicker')"
      :title="t('superAdmin.schools.title')"
      :meta="t('superAdmin.schools.subtitle')"
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

    <!-- COVERAGE NOTICE — be honest about what the list covers today. -->
    <div
      class="flex items-start gap-3 rounded-2xl border border-role-admin/15 bg-role-admin-soft/40 px-4 py-3"
    >
      <div class="text-role-admin mt-0.5 flex-shrink-0">
        <NavIcon name="alert-circle" :size="18" />
      </div>
      <p class="text-xs text-slate-600 leading-relaxed">
        {{ t('superAdmin.schools.coverageNotice') }}
      </p>
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
            class="w-10 h-10 rounded-xl bg-role-admin-soft text-role-admin grid place-items-center flex-shrink-0"
          >
            <NavIcon name="school" :size="18" />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-slate-900 truncate">
                {{ row.school_summary.name ?? t('superAdmin.schools.unnamed') }}
              </span>
              <span
                class="text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full border"
                :class="STATE_TONE[demoState(row)]"
              >
                {{ stateLabel(row) }}
              </span>
              <span
                class="text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full bg-slate-100 text-slate-500"
              >
                {{ tenantType(row.status) }}
              </span>
            </div>
            <p class="text-xs text-slate-500 mt-0.5 truncate">
              <span v-if="row.school_summary.education_level">
                {{ row.school_summary.education_level }}
              </span>
              <span v-if="row.school_summary.city">
                · {{ row.school_summary.city }}
              </span>
              <span v-if="row.school_summary.npsn">
                · NPSN {{ row.school_summary.npsn }}
              </span>
            </p>
          </div>
          <div class="text-right flex-shrink-0">
            <p class="text-[10px] text-slate-400 uppercase tracking-wide">
              {{ t('superAdmin.schools.expiresAt') }}
            </p>
            <p class="text-xs font-bold text-slate-700 tabular-nums mt-0.5">
              {{ formatDateTime(row.demo_expires_at) || '—' }}
            </p>
          </div>
        </div>
      </div>
    </AsyncView>
  </div>
</template>
