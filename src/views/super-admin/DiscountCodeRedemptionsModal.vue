<!--
  DiscountCodeRedemptionsModal.vue — audit ledger for one discount
  code. Backed by GET /billing/admin/discount-codes/{id}/redemptions
  (super_admin-gated).

  Rendered inline from SuperAdminDiscountCodesView when Fla clicks
  "Riwayat" on a row. Paginated (25/page) — a viral campaign can
  outgrow a single screen fast.

  Row shape: raw IDs (subscription, tenant, redeemed_by_user). No
  join to schools/users at the backend for MVP — Fla can copy the
  UUID to the tenant admin search if she needs a name. Keeping the
  first version shallow makes it obvious what the ledger IS (an
  audit trail) vs a management surface.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import { DiscountCodeService } from '@/services/discount-code.service';
import type {
  DiscountCodeListMeta,
  DiscountCodeRedemption,
  DiscountCodeRow,
} from '@/types/discount-code';
import { formatRupiah } from '@/lib/format';

const props = defineProps<{
  code: DiscountCodeRow;
}>();

const emit = defineEmits<{ close: [] }>();

const rows = ref<DiscountCodeRedemption[]>([]);
const meta = ref<DiscountCodeListMeta | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

const page = ref(1);
const PER_PAGE = 25;

async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await DiscountCodeService.redemptions(props.code.id, {
      page: page.value,
      per_page: PER_PAGE,
    });
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
watch(page, () => { void reload(); });

// ── Derived summary ────────────────────────────────────────────
// Total Rp redeemed = sum of `discount_amount_applied` across ALL
// rows of the current page. Kept honest (not cross-page) so the
// number visually reconciles with what the user is looking at.
const totalRupiahThisPage = computed(() =>
  rows.value.reduce((acc, r) => acc + (r.discount_amount_applied || 0), 0),
);

function shortId(id: string | null | undefined): string {
  if (!id) return '—';
  // UUID prefix + tail is enough for eyeballing across rows without
  // hogging table width. Full UUID is available on hover/copy.
  return `${id.slice(0, 8)}…${id.slice(-4)}`;
}

async function copyId(id: string | null | undefined) {
  if (!id) return;
  try {
    await navigator.clipboard.writeText(id);
  } catch { /* non-fatal — clipboard permissions or non-secure ctx */ }
}

function formatRedeemedAt(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('id-ID', {
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}
</script>

<template>
  <Modal
    :title="`Riwayat pemakaian — ${code.code}`"
    :subtitle="code.description"
    size="xl"
    @close="emit('close')"
  >
    <div class="dcr-summary">
      <div class="dcr-summary-metric">
        <div class="dcr-summary-num">{{ code.used_count }}</div>
        <div class="dcr-summary-lbl">Total pemakaian</div>
      </div>
      <div v-if="code.max_uses !== null" class="dcr-summary-metric">
        <div class="dcr-summary-num">{{ code.max_uses }}</div>
        <div class="dcr-summary-lbl">Kuota maksimum</div>
      </div>
      <div v-if="code.usage_pct !== null" class="dcr-summary-metric">
        <div class="dcr-summary-num">{{ code.usage_pct }}%</div>
        <div class="dcr-summary-lbl">Terpakai</div>
      </div>
    </div>

    <div v-if="isLoading" class="dcr-msg">Memuat riwayat…</div>
    <div v-else-if="loadError" class="dcr-msg dcr-msg-err">{{ loadError }}</div>
    <div v-else-if="rows.length === 0" class="dcr-msg">
      Belum ada yang pakai kode ini.
    </div>

    <template v-else>
      <div class="dcr-page-total">
        Halaman ini: <b>{{ rows.length }} redemption</b> ·
        total diskon <b>{{ formatRupiah(totalRupiahThisPage) }}</b>
      </div>

      <div class="dcr-table-wrap">
        <table class="dcr-table">
          <thead>
            <tr>
              <th>Waktu</th>
              <th>Tenant</th>
              <th>Subscription</th>
              <th>User</th>
              <th class="dcr-th-num">Bulan</th>
              <th class="dcr-th-num">Diskon dipakai</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in rows" :key="r.id">
              <td class="dcr-mono">{{ formatRedeemedAt(r.redeemed_at) }}</td>
              <td>
                <button
                  type="button"
                  class="dcr-id"
                  :title="r.tenant_id ?? undefined"
                  @click="copyId(r.tenant_id)"
                >
                  {{ shortId(r.tenant_id) }}
                </button>
              </td>
              <td>
                <button
                  type="button"
                  class="dcr-id"
                  :title="r.subscription_id"
                  @click="copyId(r.subscription_id)"
                >
                  {{ shortId(r.subscription_id) }}
                </button>
              </td>
              <td>
                <button
                  type="button"
                  class="dcr-id"
                  :title="r.redeemed_by_user_id ?? undefined"
                  :disabled="!r.redeemed_by_user_id"
                  @click="copyId(r.redeemed_by_user_id)"
                >
                  {{ shortId(r.redeemed_by_user_id) }}
                </button>
              </td>
              <td class="dcr-td-num dcr-mono">
                {{ r.subscription_month_index ?? '—' }}
              </td>
              <td class="dcr-td-num dcr-mono dcr-amount">
                {{ formatRupiah(r.discount_amount_applied) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="meta && meta.last_page > 1" class="dcr-pagination">
        <button
          type="button"
          class="dcr-btn ghost"
          :disabled="page <= 1"
          @click="page -= 1"
        >
          Sebelumnya
        </button>
        <span class="dcr-pagination-info">
          Halaman {{ meta.current_page }} dari {{ meta.last_page }} · {{ meta.total }} total
        </span>
        <button
          type="button"
          class="dcr-btn ghost"
          :disabled="page >= meta.last_page"
          @click="page += 1"
        >
          Berikutnya
        </button>
      </div>
    </template>

    <div class="dcr-actions">
      <button type="button" class="dcr-btn primary" @click="emit('close')">
        Tutup
      </button>
    </div>
  </Modal>
</template>

<style scoped>
.dcr-summary {
  display: flex; gap: 24px;
  padding: 10px 14px;
  background: #F8FAFC; border: 1px solid #E2E8F0;
  border-radius: 10px;
  margin-bottom: 14px;
}
.dcr-summary-metric { display: flex; flex-direction: column; gap: 2px; }
.dcr-summary-num {
  font-size: 18px; font-weight: 700; color: #0F172A;
  font-variant-numeric: tabular-nums;
  line-height: 1.1;
}
.dcr-summary-lbl {
  font-size: 10px; font-weight: 600; color: #64748B;
  letter-spacing: 0.3px; text-transform: uppercase;
}

.dcr-msg {
  padding: 40px; text-align: center;
  border: 1px dashed #CBD5E1; border-radius: 10px;
  color: #64748B; font-size: 13px;
}
.dcr-msg-err { color: #B91C1C; border-color: #FECACA; background: #FEF2F2; }

.dcr-page-total {
  font-size: 11.5px; color: #64748B;
  margin-bottom: 10px; padding: 0 2px;
}
.dcr-page-total b { color: #0F172A; font-weight: 700; }

.dcr-table-wrap {
  border: 1px solid #E2E8F0; border-radius: 10px;
  overflow-x: auto;
}
.dcr-table { width: 100%; border-collapse: collapse; }
.dcr-table th {
  text-align: left;
  padding: 8px 10px;
  font-size: 10.5px; font-weight: 700;
  color: #64748B;
  text-transform: uppercase; letter-spacing: 0.4px;
  background: #F8FAFC;
  border-bottom: 1px solid #E2E8F0;
  white-space: nowrap;
}
.dcr-th-num { text-align: right; }
.dcr-table td {
  padding: 8px 10px;
  font-size: 12px;
  border-bottom: 1px solid #F1F5F9;
  color: #334155;
}
.dcr-table tr:last-child td { border-bottom: none; }
.dcr-td-num { text-align: right; }
.dcr-amount { color: #15803D; font-weight: 700; }

.dcr-mono {
  font-variant-numeric: tabular-nums;
  font-family: -apple-system, "SF Mono", monospace;
  font-size: 11.5px;
}

.dcr-id {
  font-family: -apple-system, "SF Mono", monospace;
  font-size: 11px; color: #1B6FB8;
  background: transparent; border: none; padding: 2px 4px;
  border-radius: 4px; cursor: pointer;
}
.dcr-id:hover:not(:disabled) { background: #EFF6FF; }
.dcr-id:disabled { color: #94A3B8; cursor: default; }

.dcr-pagination {
  display: flex; gap: 12px; align-items: center; justify-content: center;
  padding-top: 10px;
}
.dcr-pagination-info { font-size: 11.5px; color: #64748B; }

.dcr-actions {
  display: flex; justify-content: flex-end;
  padding-top: 10px; margin-top: 10px;
  border-top: 1px solid #F1F5F9;
}
.dcr-btn {
  padding: 6px 14px;
  font-size: 12px; font-weight: 700;
  border: none; border-radius: 6px; cursor: pointer;
}
.dcr-btn.ghost { background: #F1F5F9; color: #334155; }
.dcr-btn.ghost:hover:not(:disabled) { background: #E2E8F0; }
.dcr-btn.primary { background: #1B6FB8; color: #fff; }
.dcr-btn.primary:hover { background: #185FA5; }
.dcr-btn:disabled { opacity: 0.5; cursor: default; }
</style>
