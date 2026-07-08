<!--
  SuperAdminDiscountCodesView.vue — /super-admin/discount-codes

  Katalog kode diskon. Fla mengelola dari sini. Filter + search di
  header, list table di body, klik row → detail drawer atau langsung
  edit modal. Add/Edit/Delete gets handled inline via the form modal.

  Backend contract: MR !358 SuperAdminDiscountCodesController.
  Every write goes through DiscountCodeService which throws Errors
  with human copy (from the response body when possible).

  Auth gate: `meta.superAdmin: true` at the router level + backend
  middleware. A non-super-admin who bookmarks this page gets a 403
  from the service layer and a friendly error banner.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { DiscountCodeService } from '@/services/discount-code.service';
import type {
  DiscountCodeDetail,
  DiscountCodeEffectiveStatus,
  DiscountCodeListMeta,
  DiscountCodeListParams,
  DiscountCodeRow,
} from '@/types/discount-code';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRupiah } from '@/lib/format';
import DiscountCodeFormModal from './DiscountCodeFormModal.vue';
import DiscountCodeRedemptionsModal from './DiscountCodeRedemptionsModal.vue';

const rows = ref<DiscountCodeRow[]>([]);
const meta = ref<DiscountCodeListMeta | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// ── Filters ────────────────────────────────────────────────────
const search = ref('');
const statusFilter = ref<DiscountCodeEffectiveStatus | ''>('');
const sort = ref<'newest' | 'oldest' | 'redemptions_desc' | 'redemptions_asc'>('newest');
const page = ref(1);
const PER_PAGE = 25;

// ── Modal / toast state ────────────────────────────────────────
const formOpen = ref(false);
// null = create; detail = edit. Loaded on-demand (list is compact, form is detail).
const editing = ref<DiscountCodeDetail | null>(null);
const openingForm = ref(false);
const deletingId = ref<string | null>(null);

// Redemptions ledger — audit trail modal. Opens per row via "Riwayat"
// button. Not lazy-loaded — the row already carries used_count so we
// know whether it's worth showing at all (button disabled when 0).
const ledgerRow = ref<DiscountCodeRow | null>(null);

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

let searchTimer: number | null = null;

// ── Load ───────────────────────────────────────────────────────
async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const params: DiscountCodeListParams = {
      page: page.value,
      per_page: PER_PAGE,
      sort: sort.value,
    };
    if (search.value.trim() !== '') params.search = search.value.trim();
    if (statusFilter.value !== '') params.status = statusFilter.value;

    const res = await DiscountCodeService.list(params);
    rows.value = res.items;
    meta.value = res.meta;
  } catch (e) {
    loadError.value = (e as Error).message;
    rows.value = [];
    meta.value = null;
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => { void reload(); });

// Debounced search — 300 ms is comfortable for keyboards but not so
// long that the user thinks the list is broken.
watch(search, () => {
  if (searchTimer !== null) window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => {
    page.value = 1;
    void reload();
  }, 300);
});
watch([statusFilter, sort], () => {
  page.value = 1;
  void reload();
});
watch(page, () => { void reload(); });

// ── Metric strip ───────────────────────────────────────────────
const totalRows = computed(() => meta.value?.total ?? 0);
const activeCount = computed(() => rows.value.filter((r) => r.effective_status === 'active').length);
const exhaustedCount = computed(() => rows.value.filter((r) => r.effective_status === 'exhausted').length);

// ── Actions ────────────────────────────────────────────────────
async function openCreate() {
  editing.value = null;
  formOpen.value = true;
}

async function openEdit(row: DiscountCodeRow) {
  openingForm.value = true;
  try {
    editing.value = await DiscountCodeService.show(row.id);
    formOpen.value = true;
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    openingForm.value = false;
  }
}

function onSaved(detail: DiscountCodeDetail) {
  const wasCreate = editing.value === null;
  formOpen.value = false;
  editing.value = null;
  toast.value = {
    message: wasCreate
      ? `Kode ${detail.code} berhasil dibuat.`
      : `Kode ${detail.code} tersimpan.`,
    tone: 'success',
  };
  void reload();
}

async function onDelete(row: DiscountCodeRow) {
  if (row.used_count > 0) {
    toast.value = {
      message: 'Kode ini sudah pernah dipakai — ganti status ke Archived untuk menyembunyikan.',
      tone: 'error',
    };
    return;
  }
  const yes = window.confirm(`Hapus kode ${row.code}? Aksi ini tidak bisa dibatalkan.`);
  if (!yes) return;

  deletingId.value = row.id;
  try {
    await DiscountCodeService.destroy(row.id);
    toast.value = { message: `Kode ${row.code} dihapus.`, tone: 'success' };
    void reload();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    deletingId.value = null;
  }
}

// ── Display helpers ────────────────────────────────────────────
const STATUS_LABEL: Record<DiscountCodeEffectiveStatus, string> = {
  active: 'Aktif',
  draft: 'Draft',
  paused: 'Ditahan',
  archived: 'Diarsipkan',
  expired: 'Kadaluarsa',
  exhausted: 'Kuota habis',
  not_yet_active: 'Belum aktif',
};

function statusTone(s: DiscountCodeEffectiveStatus): string {
  return {
    active: 'ok',
    draft: 'neutral',
    paused: 'warn',
    archived: 'neutral',
    expired: 'muted',
    exhausted: 'warn',
    not_yet_active: 'info',
  }[s] ?? 'neutral';
}

function valueLabel(row: DiscountCodeRow): string {
  return row.type === 'percent' ? `-${row.value}%` : `-${formatRupiah(row.value)}`;
}

function durationLabel(row: DiscountCodeRow): string {
  return row.duration_months === null
    ? 'Seumur langganan'
    : `${row.duration_months} bulan`;
}
</script>

<template>
  <div class="dcv-page">
    <BrandPageHeader
      title="Kode diskon"
      subtitle="Katalog kupon yang dipakai di form subscribe. Buat, ubah, atau arsipkan dari sini."
    />

    <div class="dcv-strip">
      <div class="dcv-metric">
        <div class="dcv-metric-num">{{ totalRows }}</div>
        <div class="dcv-metric-lbl">Total kode</div>
      </div>
      <div class="dcv-metric">
        <div class="dcv-metric-num dcv-metric-ok">{{ activeCount }}</div>
        <div class="dcv-metric-lbl">Aktif di halaman ini</div>
      </div>
      <div class="dcv-metric">
        <div class="dcv-metric-num dcv-metric-warn">{{ exhaustedCount }}</div>
        <div class="dcv-metric-lbl">Kuota habis di halaman ini</div>
      </div>

      <button type="button" class="dcv-btn primary" @click="openCreate">
        + Buat kode
      </button>
    </div>

    <div class="dcv-filters">
      <input
        v-model="search"
        type="search"
        class="dcv-search"
        placeholder="Cari kode atau deskripsi…"
      />
      <select v-model="statusFilter" class="dcv-select">
        <option value="">Semua status</option>
        <option value="active">Aktif</option>
        <option value="draft">Draft</option>
        <option value="paused">Ditahan</option>
        <option value="expired">Kadaluarsa</option>
        <option value="exhausted">Kuota habis</option>
        <option value="not_yet_active">Belum aktif</option>
        <option value="archived">Diarsipkan</option>
      </select>
      <select v-model="sort" class="dcv-select">
        <option value="newest">Terbaru</option>
        <option value="oldest">Terlama</option>
        <option value="redemptions_desc">Paling sering dipakai</option>
        <option value="redemptions_asc">Paling jarang dipakai</option>
      </select>
    </div>

    <div v-if="isLoading" class="dcv-loading">Memuat kode diskon…</div>
    <div v-else-if="loadError" class="dcv-err">{{ loadError }}</div>
    <div v-else-if="rows.length === 0" class="dcv-empty">
      Belum ada kode. Klik <b>+ Buat kode</b> untuk mulai.
    </div>

    <table v-else class="dcv-table">
      <thead>
        <tr>
          <th>Kode</th>
          <th>Diskon</th>
          <th>Durasi</th>
          <th>Pemakaian</th>
          <th>Berlaku</th>
          <th>Status</th>
          <th class="dcv-th-actions"></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.id" class="dcv-tr">
          <td>
            <div class="dcv-code">{{ row.code }}</div>
            <div class="dcv-desc">{{ row.description }}</div>
          </td>
          <td class="dcv-value">{{ valueLabel(row) }}</td>
          <td class="dcv-mono">{{ durationLabel(row) }}</td>
          <td>
            <div class="dcv-usage">
              <span class="dcv-usage-num">{{ row.used_count }}</span>
              <span class="dcv-usage-sep">/</span>
              <span class="dcv-usage-max">{{ row.max_uses ?? '∞' }}</span>
            </div>
            <div v-if="row.usage_pct !== null" class="dcv-usage-bar">
              <div class="dcv-usage-bar-fill" :style="{ width: `${row.usage_pct}%` }" />
            </div>
          </td>
          <td class="dcv-mono">
            <template v-if="row.valid_until">
              sd {{ row.valid_until.slice(0, 10) }}
            </template>
            <template v-else>—</template>
          </td>
          <td>
            <span class="dcv-badge" :data-tone="statusTone(row.effective_status)">
              {{ STATUS_LABEL[row.effective_status] }}
            </span>
          </td>
          <td class="dcv-td-actions">
            <button
              type="button"
              class="dcv-btn ghost"
              :disabled="row.used_count === 0"
              :title="row.used_count === 0 ? 'Belum ada yang pakai' : 'Lihat riwayat pemakaian'"
              @click="ledgerRow = row"
            >
              Riwayat
            </button>
            <button
              type="button"
              class="dcv-btn ghost"
              :disabled="openingForm"
              @click="openEdit(row)"
            >
              Ubah
            </button>
            <button
              type="button"
              class="dcv-btn danger"
              :disabled="deletingId === row.id || row.used_count > 0"
              :title="row.used_count > 0 ? 'Sudah dipakai — arsipkan saja' : ''"
              @click="onDelete(row)"
            >
              {{ deletingId === row.id ? '…' : 'Hapus' }}
            </button>
          </td>
        </tr>
      </tbody>
    </table>

    <div v-if="meta && meta.last_page > 1" class="dcv-pagination">
      <button
        type="button"
        class="dcv-btn ghost"
        :disabled="page <= 1"
        @click="page -= 1"
      >
        Sebelumnya
      </button>
      <span class="dcv-pagination-info">
        Halaman {{ meta.current_page }} dari {{ meta.last_page }}
      </span>
      <button
        type="button"
        class="dcv-btn ghost"
        :disabled="page >= meta.last_page"
        @click="page += 1"
      >
        Berikutnya
      </button>
    </div>

    <DiscountCodeFormModal
      v-if="formOpen"
      :code="editing"
      @close="formOpen = false"
      @saved="onSaved"
    />

    <DiscountCodeRedemptionsModal
      v-if="ledgerRow"
      :code="ledgerRow"
      @close="ledgerRow = null"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>

<style scoped>
.dcv-page {
  padding: 20px 24px 40px;
  max-width: 1200px;
  margin: 0 auto;
  display: flex; flex-direction: column; gap: 16px;
}

.dcv-strip {
  display: flex; gap: 12px; align-items: center;
  padding: 12px 14px;
  background: #F8FAFC; border: 1px solid #E2E8F0;
  border-radius: 12px;
}
.dcv-metric {
  padding: 4px 12px;
  border-right: 1px solid #E2E8F0;
}
.dcv-metric:last-of-type { border-right: none; }
.dcv-metric-num {
  font-size: 20px; font-weight: 700; color: #0F172A;
  font-variant-numeric: tabular-nums;
  line-height: 1.1;
}
.dcv-metric-ok { color: #16A34A; }
.dcv-metric-warn { color: #D97706; }
.dcv-metric-lbl {
  font-size: 10px; font-weight: 600; color: #64748B;
  letter-spacing: 0.3px;
  text-transform: uppercase;
}

.dcv-filters {
  display: flex; gap: 8px; flex-wrap: wrap;
}
.dcv-search, .dcv-select {
  padding: 8px 10px;
  border: 1px solid #CBD5E1;
  border-radius: 8px;
  background: #fff;
  font-size: 13px; color: #0F172A;
  outline: none;
}
.dcv-search { flex: 1; min-width: 200px; }
.dcv-search:focus, .dcv-select:focus {
  border-color: #1B6FB8;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.12);
}

.dcv-loading, .dcv-empty, .dcv-err {
  padding: 40px; text-align: center;
  border: 1px dashed #CBD5E1; border-radius: 12px;
  color: #64748B; font-size: 13px;
}
.dcv-err { color: #B91C1C; border-color: #FECACA; background: #FEF2F2; }

.dcv-table {
  width: 100%; border-collapse: collapse;
  background: #fff;
  border: 1px solid #E2E8F0; border-radius: 12px;
  overflow: hidden;
}
.dcv-table th {
  text-align: left;
  padding: 10px 12px;
  font-size: 11px; font-weight: 700;
  color: #64748B;
  text-transform: uppercase; letter-spacing: 0.4px;
  background: #F8FAFC;
  border-bottom: 1px solid #E2E8F0;
}
.dcv-table td {
  padding: 12px;
  font-size: 13px;
  border-bottom: 1px solid #F1F5F9;
  vertical-align: top;
}
.dcv-tr:last-child td { border-bottom: none; }
.dcv-th-actions { width: 1%; }
.dcv-td-actions {
  display: flex; gap: 6px; justify-content: flex-end;
  white-space: nowrap;
}
.dcv-code {
  font-family: -apple-system, "SF Mono", monospace;
  font-weight: 700; color: #0F172A;
  letter-spacing: 0.4px;
}
.dcv-desc {
  margin-top: 3px;
  font-size: 11.5px; color: #64748B;
  max-width: 280px;
  overflow: hidden; text-overflow: ellipsis;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
}
.dcv-value {
  font-weight: 700; color: #15803D;
  font-variant-numeric: tabular-nums;
}
.dcv-mono {
  font-size: 12px; color: #475569;
  font-variant-numeric: tabular-nums;
}
.dcv-usage {
  display: inline-flex; align-items: baseline; gap: 3px;
  font-variant-numeric: tabular-nums;
}
.dcv-usage-num { font-weight: 700; color: #0F172A; }
.dcv-usage-sep { color: #CBD5E1; }
.dcv-usage-max { color: #475569; }
.dcv-usage-bar {
  margin-top: 4px;
  height: 4px; background: #E2E8F0; border-radius: 2px;
  max-width: 100px; overflow: hidden;
}
.dcv-usage-bar-fill {
  height: 100%; background: #1B6FB8;
  transition: width 0.2s;
}

.dcv-badge {
  display: inline-block;
  padding: 3px 8px;
  font-size: 10.5px; font-weight: 700;
  border-radius: 6px;
  letter-spacing: 0.3px;
  white-space: nowrap;
}
.dcv-badge[data-tone="ok"]      { background: #DCFCE7; color: #166534; }
.dcv-badge[data-tone="warn"]    { background: #FEF3C7; color: #92400E; }
.dcv-badge[data-tone="info"]    { background: #DBEAFE; color: #1E40AF; }
.dcv-badge[data-tone="neutral"] { background: #F1F5F9; color: #475569; }
.dcv-badge[data-tone="muted"]   { background: #F1F5F9; color: #94A3B8; }

.dcv-btn {
  padding: 6px 12px;
  font-size: 12px; font-weight: 700;
  border: none; border-radius: 6px; cursor: pointer;
  white-space: nowrap;
}
.dcv-btn.primary { background: #1B6FB8; color: #fff; margin-left: auto; }
.dcv-btn.primary:hover { background: #185FA5; }
.dcv-btn.ghost { background: #F1F5F9; color: #334155; }
.dcv-btn.ghost:hover { background: #E2E8F0; }
.dcv-btn.danger { background: #FEF2F2; color: #B91C1C; }
.dcv-btn.danger:hover:not(:disabled) { background: #FEE2E2; }
.dcv-btn:disabled { opacity: 0.5; cursor: default; }

.dcv-pagination {
  display: flex; gap: 12px; align-items: center; justify-content: center;
  padding-top: 8px;
}
.dcv-pagination-info { font-size: 12px; color: #64748B; }
</style>
