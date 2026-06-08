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
       status pill). Row click → detail modal.
    4. Detail modal: full identity, social links, school summary, and
       the replayed wizard payload summary. Footer actions:
         • Aktivasi (approve) — confirm + optional note.
         • Tolak (reject) — confirm + optional reason.
       Both only enabled while the request is `pending`.

  Authorization is enforced server-side by the EnsureSuperAdmin
  middleware; a 403 surfaces as a friendly error state here.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { DemoRequestService } from '@/services/demo-request.service';
import {
  DEMO_REQUEST_STATUS_LABELS,
  DEMO_SOCIAL_LABELS,
  type DemoRequest,
  type DemoRequesterSocialMedia,
  type DemoRequestListMeta,
  type DemoRequestStatus,
} from '@/types/demo-request';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Pagination from '@/components/data/Pagination.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatDateTime } from '@/lib/format';
import type { Pagination as PaginationModel } from '@/types/api';

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

// ── Social-media helpers ──
function socialEntries(
  sm: DemoRequesterSocialMedia | null | undefined,
): { label: string; value: string }[] {
  if (!sm) return [];
  return (Object.keys(sm) as (keyof DemoRequesterSocialMedia)[])
    .filter((k) => sm[k]?.trim())
    .map((k) => ({ label: DEMO_SOCIAL_LABELS[k] ?? k, value: sm[k] as string }));
}

// ── Detail modal ──
const detailOpen = ref(false);
const detail = ref<DemoRequest | null>(null);
const detailLoading = ref(false);
const detailError = ref<string | null>(null);

async function openDetail(row: DemoRequest) {
  detailOpen.value = true;
  detail.value = row; // optimistic — list row already has identity + summary
  detailError.value = null;
  detailLoading.value = true;
  try {
    // Fetch the full detail incl. the replayed school_payload.
    detail.value = await DemoRequestService.show(row.id);
  } catch (e) {
    detailError.value = (e as Error).message;
  } finally {
    detailLoading.value = false;
  }
}

function closeDetail() {
  detailOpen.value = false;
  detail.value = null;
  detailError.value = null;
}

// ── Review actions (approve / reject) ──
type ReviewMode = 'approve' | 'reject';
const reviewMode = ref<ReviewMode | null>(null);
const reviewNote = ref('');
const reviewSubmitting = ref(false);
const reviewError = ref<string | null>(null);

function startReview(mode: ReviewMode) {
  reviewMode.value = mode;
  reviewNote.value = '';
  reviewError.value = null;
}

function cancelReview() {
  reviewMode.value = null;
  reviewNote.value = '';
  reviewError.value = null;
}

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

async function submitReview() {
  if (!detail.value || !reviewMode.value) return;
  reviewSubmitting.value = true;
  reviewError.value = null;
  try {
    if (reviewMode.value === 'approve') {
      await DemoRequestService.approve(detail.value.id, reviewNote.value);
      toast.value = {
        message:
          'Demo diaktivasi. Notifikasi aktivasi dikirim ke pemohon via email & WhatsApp.',
        tone: 'success',
      };
    } else {
      await DemoRequestService.reject(detail.value.id, reviewNote.value);
      toast.value = {
        message: 'Permintaan demo ditolak.',
        tone: 'success',
      };
    }
    cancelReview();
    closeDetail();
    await reload();
  } catch (e) {
    reviewError.value = (e as Error).message;
  } finally {
    reviewSubmitting.value = false;
  }
}

// Wizard payload summary helpers (best-effort, payload is optional).
const payloadSummary = computed(() => {
  const p = detail.value?.school_payload;
  if (!p) return null;
  return {
    teachers: p.teachers?.count ?? null,
    studentsPerClass: p.students?.per_class ?? null,
    scenarios: p.scenarios?.enabled?.length ?? 0,
  };
});
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
          @click="openDetail(row)"
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
          <NavIcon
            name="chevron-right"
            :size="18"
            class="text-slate-300 mt-2 flex-shrink-0"
          />
        </button>
      </div>

      <div v-if="paginationModel" class="mt-5">
        <Pagination :pagination="paginationModel" @change="goToPage" />
      </div>
    </AsyncView>

    <!-- DETAIL MODAL -->
    <Modal
      v-if="detailOpen && detail"
      size="lg"
      :title="detail.school_summary.name ?? 'Permintaan Demo'"
      :subtitle="`Diajukan ${formatDateTime(detail.created_at) || '—'}`"
      @close="closeDetail"
    >
      <div
        v-if="detailLoading"
        class="flex items-center gap-2 text-xs text-slate-400 mb-3"
      >
        <Spinner size="sm" /> Memuat detail lengkap…
      </div>

      <p
        v-if="detailError"
        class="text-xs text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2 mb-3"
      >
        {{ detailError }}
      </p>

      <!-- Status banner -->
      <div
        class="rounded-xl border px-3 py-2 text-xs font-bold mb-4 inline-flex items-center gap-2"
        :class="statusTone(detail.status)"
      >
        <span class="w-1.5 h-1.5 rounded-full bg-current"></span>
        {{ statusLabel(detail.status) }}
        <span
          v-if="detail.status === 'approved' && detail.demo_expires_at"
          class="font-medium opacity-80"
        >
          · berlaku s.d. {{ formatDateTime(detail.demo_expires_at) }}
        </span>
      </div>

      <!-- Requester identity -->
      <section class="mb-4">
        <h3
          class="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-2"
        >
          Identitas Pemohon
        </h3>
        <dl class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
          <div>
            <dt class="text-[11px] text-slate-400">Nama lengkap</dt>
            <dd class="font-semibold text-slate-900">{{ detail.full_name }}</dd>
          </div>
          <div>
            <dt class="text-[11px] text-slate-400">NIP</dt>
            <dd class="font-semibold text-slate-900">{{ detail.nip }}</dd>
          </div>
          <div>
            <dt class="text-[11px] text-slate-400">Jabatan</dt>
            <dd class="font-semibold text-slate-900">{{ detail.jabatan }}</dd>
          </div>
          <div>
            <dt class="text-[11px] text-slate-400">WhatsApp</dt>
            <dd class="font-semibold text-slate-900">{{ detail.whatsapp }}</dd>
          </div>
          <div v-if="detail.requester?.email" class="col-span-2">
            <dt class="text-[11px] text-slate-400">Email akun</dt>
            <dd class="font-semibold text-slate-900">
              {{ detail.requester?.email }}
            </dd>
          </div>
        </dl>

        <div
          v-if="socialEntries(detail.social_media).length"
          class="mt-3 flex flex-wrap gap-1.5"
        >
          <span
            v-for="s in socialEntries(detail.social_media)"
            :key="s.label"
            class="inline-flex items-center gap-1 text-[11px] font-medium bg-slate-100 text-slate-600 rounded-full px-2.5 py-1"
          >
            <span class="font-bold text-slate-500">{{ s.label }}:</span>
            <span class="truncate max-w-[180px]">{{ s.value }}</span>
          </span>
        </div>
      </section>

      <!-- School summary -->
      <section class="mb-4">
        <h3
          class="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-2"
        >
          Data Sekolah
        </h3>
        <dl class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
          <div>
            <dt class="text-[11px] text-slate-400">Nama sekolah</dt>
            <dd class="font-semibold text-slate-900">
              {{ detail.school_summary.name ?? '—' }}
            </dd>
          </div>
          <div>
            <dt class="text-[11px] text-slate-400">Jenjang</dt>
            <dd class="font-semibold text-slate-900">
              {{ detail.school_summary.education_level ?? '—' }}
            </dd>
          </div>
          <div>
            <dt class="text-[11px] text-slate-400">Kota</dt>
            <dd class="font-semibold text-slate-900">
              {{ detail.school_summary.city ?? '—' }}
            </dd>
          </div>
          <div>
            <dt class="text-[11px] text-slate-400">NPSN</dt>
            <dd class="font-semibold text-slate-900">
              {{ detail.school_summary.npsn ?? '—' }}
            </dd>
          </div>
        </dl>

        <!-- Replayed wizard payload summary -->
        <div
          v-if="payloadSummary"
          class="mt-3 grid grid-cols-2 sm:grid-cols-4 gap-2"
        >
          <div class="rounded-xl bg-slate-50 border border-slate-100 px-3 py-2">
            <p class="text-[10px] text-slate-400 uppercase tracking-wide">Guru</p>
            <p class="text-sm font-bold text-slate-900 tabular-nums">
              {{ payloadSummary.teachers ?? '—' }}
            </p>
          </div>
          <div class="rounded-xl bg-slate-50 border border-slate-100 px-3 py-2">
            <p class="text-[10px] text-slate-400 uppercase tracking-wide">
              Siswa/kelas
            </p>
            <p class="text-sm font-bold text-slate-900 tabular-nums">
              {{ payloadSummary.studentsPerClass ?? '—' }}
            </p>
          </div>
          <div class="rounded-xl bg-slate-50 border border-slate-100 px-3 py-2">
            <p class="text-[10px] text-slate-400 uppercase tracking-wide">
              Skenario
            </p>
            <p class="text-sm font-bold text-slate-900 tabular-nums">
              {{ payloadSummary.scenarios }}
            </p>
          </div>
          <div class="rounded-xl bg-slate-50 border border-slate-100 px-3 py-2">
            <p class="text-[10px] text-slate-400 uppercase tracking-wide">
              Sekolah aktif
            </p>
            <p class="text-sm font-bold text-slate-900">
              {{ detail.activated_school_id ? 'Ya' : 'Belum' }}
            </p>
          </div>
        </div>
      </section>

      <!-- Review history (if reviewed) -->
      <section
        v-if="detail.reviewed_at || detail.review_note"
        class="mb-4 rounded-xl bg-slate-50 border border-slate-100 px-3 py-2.5"
      >
        <h3
          class="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-1"
        >
          Catatan Review
        </h3>
        <p v-if="detail.review_note" class="text-sm text-slate-700">
          {{ detail.review_note }}
        </p>
        <p v-if="detail.reviewed_at" class="text-[11px] text-slate-400 mt-1">
          Ditinjau {{ formatDateTime(detail.reviewed_at) }}
        </p>
      </section>

      <!-- REVIEW FORM (inline, shown after picking an action) -->
      <section
        v-if="reviewMode"
        class="rounded-xl border px-3.5 py-3 mb-3"
        :class="
          reviewMode === 'approve'
            ? 'border-emerald-200 bg-emerald-50/50'
            : 'border-red-200 bg-red-50/50'
        "
      >
        <p class="text-xs font-bold text-slate-700 mb-2">
          <template v-if="reviewMode === 'approve'">
            Aktivasi demo ini? Sekolah & akun demo akan dibuat, masa
            berlaku 7 hari, dan pemohon diberi tahu via email & WhatsApp.
          </template>
          <template v-else>
            Tolak permintaan demo ini? Pemohon tidak akan diaktivasi.
          </template>
        </p>
        <label class="block text-[11px] font-semibold text-slate-500 mb-1">
          {{ reviewMode === 'approve' ? 'Catatan (opsional)' : 'Alasan (opsional)' }}
        </label>
        <textarea
          v-model="reviewNote"
          rows="2"
          maxlength="1000"
          class="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/30"
          :placeholder="
            reviewMode === 'approve'
              ? 'Catatan internal untuk aktivasi…'
              : 'Alasan penolakan…'
          "
        ></textarea>
        <p
          v-if="reviewError"
          class="text-xs text-red-600 mt-2"
        >
          {{ reviewError }}
        </p>
        <div class="flex items-center justify-end gap-2 mt-3">
          <Button variant="ghost" size="sm" @click="cancelReview">
            Batal
          </Button>
          <Button
            :variant="reviewMode === 'approve' ? 'success' : 'danger'"
            size="sm"
            :loading="reviewSubmitting"
            @click="submitReview"
          >
            {{ reviewMode === 'approve' ? 'Konfirmasi Aktivasi' : 'Konfirmasi Tolak' }}
          </Button>
        </div>
      </section>

      <!-- FOOTER ACTIONS -->
      <footer
        v-if="!reviewMode"
        class="flex items-center justify-end gap-2 pt-2 border-t border-slate-100"
      >
        <Button variant="secondary" size="sm" @click="closeDetail">
          Tutup
        </Button>
        <template v-if="detail.status === 'pending'">
          <Button variant="danger" size="sm" @click="startReview('reject')">
            <NavIcon name="x" :size="14" />
            Tolak
          </Button>
          <Button variant="success" size="sm" @click="startReview('approve')">
            <NavIcon name="check" :size="14" />
            Aktivasi
          </Button>
        </template>
        <span
          v-else
          class="text-[11px] text-slate-400"
        >
          Permintaan ini sudah {{ statusLabel(detail.status).toLowerCase() }}.
        </span>
      </footer>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
