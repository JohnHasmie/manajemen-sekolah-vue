<!--
  SuperAdminIncompleteRegistrationsView.vue — "Registrasi Belum Selesai".

  Lists ABANDONED demo registrations: people who started the register-demo
  wizard but never finished/submitted it, so the KamilEdu team can see
  "sampai mana" each one got and follow up.

  Source: GET /api/demo-incomplete-registrations
  (DemoIncompleteRegistrationController) — demo_wizard_states with
  completed_at=NULL whose user has NO submitted demo_request. Returns the
  requester identity (from the Google sign-in user), a "step X of Y"
  progress indicator, and last-active time. Paginated, newest active
  first.

  Gated client-side by the super-admin router guard (meta.superAdmin) AND
  server-side by the EnsureSuperAdmin middleware; a 403 surfaces as a
  friendly error state.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { DemoAccountService } from '@/services/demo-account.service';
import type {
  IncompleteRegistration,
  IncompleteRegistrationListMeta,
} from '@/types/demo-account';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Pagination from '@/components/data/Pagination.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDateTime, formatRelative } from '@/lib/format';
import type { Pagination as PaginationModel } from '@/types/api';

const { t } = useI18n();

const PER_PAGE = 20;

// ── List state ──────────────────────────────────────────────────────
const rows = ref<IncompleteRegistration[]>([]);
const meta = ref<IncompleteRegistrationListMeta | null>(null);
const page = ref(1);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await DemoAccountService.listIncomplete({
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

function goToPage(p: number) {
  page.value = p;
  reload();
}

onMounted(reload);

const listState = computed<AsyncState<IncompleteRegistration[]>>(() => {
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
  if (!meta.value) return t('superAdmin.incomplete.loadingMeta');
  return t('superAdmin.incomplete.countMeta', { count: meta.value.total });
});

// Progress bar tone: the further along, the warmer (closer to finishing).
function progressTone(percent: number): string {
  if (percent >= 75) return 'bg-emerald-400';
  if (percent >= 40) return 'bg-amber-400';
  return 'bg-slate-300';
}

function displayName(row: IncompleteRegistration): string {
  return (
    row.requester?.name?.trim() ||
    row.requester?.email?.trim() ||
    t('superAdmin.incomplete.unknownUser')
  );
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="t('superAdmin.kicker')"
      :title="t('superAdmin.incomplete.title')"
      :meta="headerMeta"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 px-3 py-1.5 text-xs font-bold text-white transition"
        @click="reload"
      >
        <NavIcon name="refresh-cw" :size="14" />
        {{ t('common.refresh') }}
      </button>
    </BrandPageHeader>

    <!-- EXPLAINER -->
    <div
      class="flex items-start gap-3 rounded-2xl border border-role-admin/15 bg-role-admin-soft/40 px-4 py-3"
    >
      <div class="text-role-admin mt-0.5 flex-shrink-0">
        <NavIcon name="info" :size="18" />
      </div>
      <p class="text-xs text-slate-600 leading-relaxed">
        {{ t('superAdmin.incomplete.explainer') }}
      </p>
    </div>

    <!-- LIST -->
    <AsyncView
      :state="listState"
      :empty-title="t('superAdmin.incomplete.emptyTitle')"
      :empty-description="t('superAdmin.incomplete.emptyDescription')"
      empty-icon="inbox"
      @retry="reload"
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
            <NavIcon name="user" :size="18" />
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-slate-900 truncate">
                {{ displayName(row) }}
              </span>
              <span
                class="text-3xs font-bold uppercase tracking-wide px-2 py-0.5 rounded-full bg-amber-50 text-amber-700 border border-amber-200"
              >
                {{
                  t('superAdmin.incomplete.stepBadge', {
                    current: row.display_step,
                    total: row.total_steps,
                  })
                }}
              </span>
            </div>

            <p
              v-if="row.requester?.email"
              class="text-xs text-slate-500 mt-0.5 truncate"
            >
              {{ row.requester.email }}
            </p>
            <p
              v-if="row.school_name_draft"
              class="text-xs text-slate-400 mt-0.5 truncate"
            >
              {{ t('superAdmin.incomplete.draftSchool') }}:
              {{ row.school_name_draft }}
            </p>

            <!-- Progress bar -->
            <div class="mt-2 flex items-center gap-2">
              <div
                class="h-1.5 flex-1 rounded-full bg-slate-100 overflow-hidden"
              >
                <div
                  class="h-full rounded-full transition-all"
                  :class="progressTone(row.progress_percent)"
                  :style="{ width: `${row.progress_percent}%` }"
                ></div>
              </div>
              <span
                class="text-3xs font-bold text-slate-400 tabular-nums w-9 text-right"
              >
                {{ row.progress_percent }}%
              </span>
            </div>
          </div>

          <!-- Last active -->
          <div class="text-right flex-shrink-0">
            <p
              class="text-3xs text-slate-400 uppercase tracking-wide flex items-center justify-end gap-1"
            >
              <NavIcon name="clock" :size="11" />
              {{ t('superAdmin.incomplete.lastActive') }}
            </p>
            <p class="text-xs font-bold text-slate-700 mt-0.5">
              {{ formatRelative(row.last_active_at) || '—' }}
            </p>
            <p class="text-3xs text-slate-400 tabular-nums mt-0.5">
              {{ formatDateTime(row.last_active_at) }}
            </p>
          </div>
        </div>
      </div>

      <Pagination
        v-if="paginationModel"
        :pagination="paginationModel"
        class="mt-4"
        @change="goToPage"
      />
    </AsyncView>
  </div>
</template>
