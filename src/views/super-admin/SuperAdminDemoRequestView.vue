<!--
  SuperAdminDemoRequestView.vue — SUPER-ADMIN demo-request review hub.

  Moved from views/admin/AdminDemoRequestView.vue into the dedicated
  /super-admin area. Behaviour is unchanged — the legacy
  /admin/demo-requests path now redirects to /super-admin/demo-requests
  (see router/index.ts), so existing links + the super-admin login
  short-circuit keep working.

  KamilEdu-team page (NOT a per-school admin surface). A demo
  registration now submits a PENDING `demo_requests` row instead of
  auto-activating; the team reviews each one here and *activates*
  (approves) it — which provisions the demo school + account, sets a
  7-day expiry, and notifies the requester via email + WhatsApp.

  Layout (matches the admin design system):
    1. <BrandPageHeader role="admin"> — kicker + meta line.
    2. Status filter chips (Menunggu default · Disetujui · Ditolak ·
       Kedaluwarsa · Semua) → reload list.
    3. List of request rows (requester identity + school summary +
       status pill). Row click → the full detail page
       (super-admin.demo-requests.detail), which renders EVERY form
       input the requester submitted plus the inline Approve/Reject
       actions (only enabled while the request is `pending`).

  Authorization is enforced server-side by the EnsureSuperAdmin
  middleware; a 403 surfaces as a friendly error state here.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { DemoRequestService } from '@/services/demo-request.service';
import {
  DEMO_REQUEST_STATUS_LABELS,
  type DemoRequest,
  type DemoRequestListMeta,
  type DemoRequestStatus,
} from '@/types/demo-request';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Pagination from '@/components/data/Pagination.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDateTime } from '@/lib/format';
import type { Pagination as PaginationModel } from '@/types/api';

const router = useRouter();

// ── Filter chips ──
type StatusFilter = DemoRequestStatus | 'all';
const STATUS_FILTERS: { key: StatusFilter; label: string }[] = [
  { key: 'pending', label: 'Menunggu' },
  { key: 'approved', label: 'Disetujui' },
  { key: 'rejected', label: 'Ditolak' },
  { key: 'expired', label: 'Kedaluwarsa' },
  { key: 'all', label: 'Semua' },
];
// Default to pending — the team's working queue.
const statusFilter = ref<StatusFilter>('pending');

// ── List state ──
const rows = ref<DemoRequest[]>([]);
const meta = ref<DemoRequestListMeta | null>(null);
const page = ref(1);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

const PER_PAGE = 20;

async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await DemoRequestService.list({
      status: statusFilter.value === 'all' ? undefined : statusFilter.value,
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

function setStatus(s: StatusFilter) {
  if (statusFilter.value === s) return;
  statusFilter.value = s;
  page.value = 1;
  reload();
}

function goToPage(p: number) {
  page.value = p;
  reload();
}

onMounted(reload);

// ── List as AsyncView state ──
const listState = computed<AsyncState<DemoRequest[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

// Map our list meta to the shared <Pagination> model.
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
  if (!meta.value) return 'Memuat permintaan…';
  const label =
    STATUS_FILTERS.find((f) => f.key === statusFilter.value)?.label ?? 'Semua';
  return `${meta.value.total} permintaan · ${label}`;
});

// ── Status pill styling ──
function statusTone(status: DemoRequestStatus): string {
  switch (status) {
    case 'pending':
      return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'approved':
      return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    case 'rejected':
      return 'bg-red-50 text-red-700 border-red-200';
    case 'expired':
      return 'bg-slate-100 text-slate-500 border-slate-200';
  }
}

function statusLabel(status: DemoRequestStatus): string {
  return DEMO_REQUEST_STATUS_LABELS[status] ?? status;
}

// ── Row → full detail page ──
// Each row opens the dedicated detail view, which renders EVERY form
// input the requester submitted plus the inline Approve/Reject actions.
function goToDetail(row: DemoRequest) {
  router.push({
    name: 'super-admin.demo-requests.detail',
    params: { id: row.id },
  });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      kicker="Platform · Super Admin"
      title="Permintaan Demo"
      :meta="headerMeta"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 px-3 py-1.5 text-xs font-bold text-white transition"
        @click="reload"
      >
        <NavIcon name="refresh-cw" :size="14" />
        Muat ulang
      </button>
    </BrandPageHeader>

    <!-- STATUS FILTER CHIPS -->
    <div class="flex flex-wrap items-center gap-2">
      <button
        v-for="f in STATUS_FILTERS"
        :key="f.key"
        type="button"
        class="rounded-full px-3.5 py-1.5 text-xs font-bold border transition"
        :class="
          statusFilter === f.key
            ? 'bg-role-admin text-white border-role-admin'
            : 'bg-white text-slate-500 border-slate-200 hover:bg-slate-50'
        "
        @click="setStatus(f.key)"
      >
        {{ f.label }}
      </button>
    </div>

    <!-- LIST -->
    <AsyncView
      :state="listState"
      empty-title="Tidak ada permintaan"
      empty-description="Belum ada permintaan demo pada filter ini."
      empty-icon="inbox"
      @retry="reload"
    >
      <div class="space-y-2">
        <button
          v-for="row in rows"
          :key="row.id"
          type="button"
          class="w-full text-left bg-white border border-slate-200 rounded-2xl p-4 hover:border-role-admin/40 hover:shadow-sm transition flex items-start gap-3"
          @click="goToDetail(row)"
        >
          <div
            class="w-10 h-10 rounded-xl bg-role-admin-soft text-role-admin grid place-items-center flex-shrink-0"
          >
            <NavIcon name="school" :size="18" />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-slate-900 truncate">
                {{ row.school_summary.name ?? 'Sekolah tanpa nama' }}
              </span>
              <span
                class="text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full border"
                :class="statusTone(row.status)"
              >
                {{ statusLabel(row.status) }}
              </span>
            </div>
            <p class="text-xs text-slate-500 mt-0.5 truncate">
              {{ row.full_name }} · {{ row.jabatan }}
              <span v-if="row.school_summary.city">
                · {{ row.school_summary.city }}
              </span>
              <span v-if="row.school_summary.education_level">
                · {{ row.school_summary.education_level }}
              </span>
            </p>
            <p class="text-[11px] text-slate-400 mt-1 tabular-nums">
              Diajukan {{ formatDateTime(row.created_at) || '—' }}
            </p>
          </div>
          <span
            class="hidden sm:inline-flex items-center gap-1 text-[11px] font-bold text-role-admin mt-2 flex-shrink-0"
          >
            Lihat detail
            <NavIcon name="chevron-right" :size="16" />
          </span>
          <NavIcon
            name="chevron-right"
            :size="18"
            class="sm:hidden text-slate-300 mt-2 flex-shrink-0"
          />
        </button>
      </div>

      <div v-if="paginationModel" class="mt-5">
        <Pagination :pagination="paginationModel" @change="goToPage" />
      </div>
    </AsyncView>
  </div>
</template>
