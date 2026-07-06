<!--
  SuperAdminTenantModulesView.vue — grant/revoke modules on any tenant.

  Two-pane surface:
    - LEFT: tenant picker with search (same shape as SuperAdminSchoolsView's
      tenants list, filtered to `paid` scope by default because comp/grant
      operations only make sense on tenants with an active subscription).
    - RIGHT: full module list for the selected tenant. Each row shows the
      entitlement state (Aktif · comp / paid / Belum aktif), the current
      per-seat snapshot, and either a "Grant · gratis" or "Cabut" button.

  All mutations flow through SuperAdminBillingService which hits
  /billing/admin/tenants/{schoolId}/modules — the tenant's cached
  entitlement is refreshed server-side before the response returns, so
  reloading the list picks up truth in one round-trip.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { SuperAdminTenantService } from '@/services/super-admin-tenant.service';
import { SuperAdminBillingService } from '@/services/super-admin-billing.service';
import type { PlatformTenant } from '@/types/super-admin-tenant';
import type { AdminTenantModuleRow } from '@/types/super-admin-billing';
import { tenantLabel } from '@/lib/tenantTokens';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useConfirm } from '@/composables/useConfirm';

const { confirm } = useConfirm();

// ── Tenant picker state ─────────────────────────────────────────────
const tenantSearch = ref('');
const tenants = ref<PlatformTenant[]>([]);
const tenantsLoading = ref(false);
const tenantsError = ref<string | null>(null);
const selectedTenant = ref<PlatformTenant | null>(null);

// ── Module list state ───────────────────────────────────────────────
const modules = ref<AdminTenantModuleRow[]>([]);
const modulesLoading = ref(false);
const modulesError = ref<string | null>(null);
const rowBusyKey = ref<string | null>(null);
const successToast = ref<string | null>(null);

// ── Derived ─────────────────────────────────────────────────────────
/**
 * Group the modules by their catalog group so the grid reads like the
 * subscribe picker (Absensi / Akademik / Guru / Keuangan / AI ...).
 */
const groupedModules = computed<{ name: string; items: AdminTenantModuleRow[] }[]>(() => {
  const groups: Record<string, AdminTenantModuleRow[]> = {};
  modules.value.forEach((row) => {
    (groups[row.group] ??= []).push(row);
  });
  return Object.entries(groups)
    .map(([name, items]) => ({ name, items }))
    .sort((a, b) => a.name.localeCompare(b.name));
});

const entitledCount = computed<number>(
  () => modules.value.filter((r) => r.entitled).length,
);
const compCount = computed<number>(
  () => modules.value.filter((r) => r.entitled && r.source === 'comp').length,
);

// ── Effects ─────────────────────────────────────────────────────────
async function loadTenants(): Promise<void> {
  tenantsLoading.value = true;
  tenantsError.value = null;
  try {
    const res = await SuperAdminTenantService.list({
      scope: 'paid',
      search: tenantSearch.value.trim() || undefined,
      per_page: 40,
      page: 1,
    });
    tenants.value = res.items;
  } catch (e) {
    tenantsError.value = (e as Error).message;
  } finally {
    tenantsLoading.value = false;
  }
}

async function loadModules(): Promise<void> {
  if (!selectedTenant.value) {
    modules.value = [];
    return;
  }
  modulesLoading.value = true;
  modulesError.value = null;
  try {
    modules.value = await SuperAdminBillingService.listModules(selectedTenant.value.id);
  } catch (e) {
    modulesError.value = (e as Error).message;
    modules.value = [];
  } finally {
    modulesLoading.value = false;
  }
}

// Debounced search — 300ms so keystrokes don't hammer the API.
let searchTimer: number | null = null;
watch(tenantSearch, () => {
  if (searchTimer !== null) window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(loadTenants, 300) as unknown as number;
});

// Refetch modules on tenant switch.
watch(selectedTenant, loadModules);

onMounted(loadTenants);

// ── Actions ─────────────────────────────────────────────────────────
function pickTenant(t: PlatformTenant): void {
  selectedTenant.value = t;
  successToast.value = null;
}

function toastSuccess(msg: string): void {
  successToast.value = msg;
  window.setTimeout(() => {
    if (successToast.value === msg) successToast.value = null;
  }, 3500);
}

async function grantComp(row: AdminTenantModuleRow): Promise<void> {
  if (!selectedTenant.value) return;
  rowBusyKey.value = row.module_key;
  try {
    await SuperAdminBillingService.grantModule({
      schoolId: selectedTenant.value.id,
      module_key: row.module_key,
      source: 'comp',
    });
    toastSuccess(`${row.label} diaktifkan sebagai gratis (comp).`);
    await loadModules();
  } catch (e) {
    modulesError.value = (e as Error).message;
  } finally {
    rowBusyKey.value = null;
  }
}

async function grantPaid(row: AdminTenantModuleRow): Promise<void> {
  if (!selectedTenant.value) return;
  rowBusyKey.value = row.module_key;
  try {
    await SuperAdminBillingService.grantModule({
      schoolId: selectedTenant.value.id,
      module_key: row.module_key,
      source: 'paid',
    });
    toastSuccess(`${row.label} diaktifkan sebagai berbayar.`);
    await loadModules();
  } catch (e) {
    modulesError.value = (e as Error).message;
  } finally {
    rowBusyKey.value = null;
  }
}

async function revokeAtPeriodEnd(row: AdminTenantModuleRow): Promise<void> {
  if (!selectedTenant.value) return;
  rowBusyKey.value = row.module_key;
  try {
    await SuperAdminBillingService.revokeModule({
      schoolId: selectedTenant.value.id,
      module_key: row.module_key,
      atPeriodEnd: true,
    });
    toastSuccess(`${row.label} akan dihentikan di akhir periode.`);
    await loadModules();
  } catch (e) {
    modulesError.value = (e as Error).message;
  } finally {
    rowBusyKey.value = null;
  }
}

async function revokeNow(row: AdminTenantModuleRow): Promise<void> {
  if (!selectedTenant.value) return;
  if (
    !(await confirm({
      title: 'Cabut modul sekarang?',
      message: `Akses ${row.label} akan hilang seketika. Untuk pencabutan di akhir periode, gunakan tombol "Cabut · akhir periode".`,
      danger: true,
      confirmLabel: 'Cabut sekarang',
    }))
  )
    return;
  rowBusyKey.value = row.module_key;
  try {
    await SuperAdminBillingService.revokeModule({
      schoolId: selectedTenant.value.id,
      module_key: row.module_key,
      atPeriodEnd: false,
    });
    toastSuccess(`${row.label} dicabut seketika.`);
    await loadModules();
  } catch (e) {
    modulesError.value = (e as Error).message;
  } finally {
    rowBusyKey.value = null;
  }
}

// ── Helpers ────────────────────────────────────────────────────────
function tenantTypeLabel(t: PlatformTenant): string {
  return tenantLabel('tenantType', t.tenant_type);
}

function formatMoney(n: number): string {
  return 'Rp ' + new Intl.NumberFormat('id-ID').format(Math.max(0, Math.round(n)));
}

/**
 * Human-friendly price snippet. Some modules charge per-student only
 * (attendance_class, attendance_gate, grades, finance), some per-staff
 * only (attendance_staff / AI), a few per both (communication). Only
 * render the units that carry a non-zero rate so a per-student module
 * doesn't say "+ Rp 0 / guru".
 */
function priceSnippet(row: AdminTenantModuleRow): string {
  const parts: string[] = [];
  if (row.price_per_student > 0) parts.push(`${formatMoney(row.price_per_student)}/siswa`);
  if (row.price_per_staff > 0) parts.push(`${formatMoney(row.price_per_staff)}/guru`);
  return parts.length ? parts.join(' · ') + ' / bln' : 'Gratis';
}
</script>

<template>
  <div class="flex flex-col gap-6 p-6 max-w-[1400px] mx-auto">
    <BrandPageHeader
      title="Kelola modul tenant"
      subtitle="Grant, revoke, atau kompl (comp) modul untuk tenant manapun. Perubahan langsung ter-refresh di cache entitlement."
    />

    <div class="grid grid-cols-1 lg:grid-cols-[360px_minmax(0,1fr)] gap-6">
      <!-- ══ LEFT: tenant picker ══ -->
      <aside class="bg-white border border-slate-200 rounded-xl overflow-hidden self-start">
        <div class="p-4 border-b border-slate-100">
          <label class="block text-[10.5px] font-semibold uppercase tracking-wider text-slate-500 mb-1.5">
            Cari tenant berbayar
          </label>
          <input
            v-model="tenantSearch"
            type="search"
            placeholder="nama sekolah / bimbel…"
            class="w-full text-[13px] px-3 py-2 border border-slate-300 rounded-lg
                   focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
          />
        </div>

        <div v-if="tenantsError" class="p-4 text-xs text-rose-700 bg-rose-50 border-b border-rose-200">
          {{ tenantsError }}
        </div>

        <div v-if="tenantsLoading && tenants.length === 0" class="p-6 text-center text-xs text-slate-500">
          Memuat tenant…
        </div>

        <div v-else-if="tenants.length === 0" class="p-6 text-center text-xs text-slate-400">
          Tidak ada tenant berbayar cocok.
        </div>

        <ul v-else class="max-h-[640px] overflow-y-auto divide-y divide-slate-100">
          <li v-for="t in tenants" :key="t.id">
            <button
              type="button"
              class="w-full text-left px-4 py-3 flex items-start gap-3 hover:bg-slate-50 transition"
              :class="selectedTenant?.id === t.id ? 'bg-blue-50/70 border-l-2 border-blue-600' : ''"
              @click="pickTenant(t)"
            >
              <div
                class="w-9 h-9 rounded-lg grid place-items-center flex-shrink-0
                       text-[13px] font-semibold"
                :class="t.tenant_type === 'tutoring'
                  ? 'bg-emerald-50 text-emerald-700'
                  : 'bg-blue-50 text-blue-700'"
              >
                {{ (t.name || '?').slice(0, 2).toUpperCase() }}
              </div>
              <div class="min-w-0 flex-1">
                <div class="text-[13px] font-semibold text-slate-900 truncate">{{ t.name }}</div>
                <div class="text-2xs text-slate-500 mt-0.5 flex items-center gap-1.5">
                  <span>{{ tenantTypeLabel(t) }}</span>
                  <span class="text-slate-300">·</span>
                  <span>{{ t.student_count }}/{{ t.staff_count }}</span>
                  <span v-if="t.subscription_status !== 'active'" class="text-slate-300">·</span>
                  <span
                    v-if="t.subscription_status !== 'active'"
                    class="text-amber-700"
                  >{{ t.subscription_status }}</span>
                </div>
              </div>
            </button>
          </li>
        </ul>
      </aside>

      <!-- ══ RIGHT: module list for selected tenant ══ -->
      <section>
        <!-- Empty state — no tenant picked -->
        <div
          v-if="!selectedTenant"
          class="bg-white border border-dashed border-slate-300 rounded-xl p-12 text-center"
        >
          <div class="mx-auto w-12 h-12 rounded-full bg-slate-100 grid place-items-center mb-3">
            <i class="ti ti-arrow-left text-slate-400 text-xl" aria-hidden="true" />
          </div>
          <div class="text-[14px] font-semibold text-slate-700">
            Pilih tenant di panel kiri
          </div>
          <p class="text-[12.5px] text-slate-500 mt-1 max-w-sm mx-auto">
            Daftar modul tenant muncul di sini. Anda bisa memberi (grant) modul
            baru sebagai comp/paid, atau mencabutnya seketika maupun di akhir
            periode.
          </p>
        </div>

        <!-- Loaded -->
        <template v-else>
          <div class="bg-white border border-slate-200 rounded-xl p-5 mb-4">
            <div class="flex items-start gap-3">
              <div
                class="w-11 h-11 rounded-lg grid place-items-center flex-shrink-0
                       text-[14px] font-semibold"
                :class="selectedTenant.tenant_type === 'tutoring'
                  ? 'bg-emerald-50 text-emerald-700'
                  : 'bg-blue-50 text-blue-700'"
              >
                {{ selectedTenant.name.slice(0, 2).toUpperCase() }}
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-[15px] font-semibold text-slate-900">
                  {{ selectedTenant.name }}
                </div>
                <div class="text-[12px] text-slate-500 mt-0.5">
                  {{ tenantTypeLabel(selectedTenant) }} ·
                  {{ selectedTenant.student_count }} siswa ·
                  {{ selectedTenant.staff_count }} guru/staf
                </div>
              </div>
              <div class="text-right text-[12px] text-slate-600">
                <div class="font-semibold text-slate-900">
                  {{ entitledCount }} modul aktif
                </div>
                <div class="text-slate-400 mt-0.5">
                  {{ compCount }} gratis (comp)
                </div>
              </div>
            </div>
          </div>

          <!-- Errors + toast -->
          <div
            v-if="modulesError"
            class="mb-3 text-[12px] text-rose-700 bg-rose-50 border border-rose-200 rounded-lg px-3 py-2"
          >{{ modulesError }}</div>
          <div
            v-if="successToast"
            class="mb-3 text-[12px] text-emerald-800 bg-emerald-50 border border-emerald-200 rounded-lg px-3 py-2"
          >{{ successToast }}</div>

          <!-- Loading -->
          <div v-if="modulesLoading" class="text-[12.5px] text-slate-500 py-6 text-center">
            Memuat modul tenant…
          </div>

          <!-- Grouped list -->
          <div v-else class="space-y-6">
            <section v-for="g in groupedModules" :key="g.name">
              <div class="text-[10.5px] font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                {{ g.name }}
              </div>
              <div class="space-y-2">
                <article
                  v-for="row in g.items"
                  :key="row.module_key"
                  class="bg-white border border-slate-200 rounded-xl px-4 py-3
                         flex items-center gap-3"
                  :class="row.entitled
                    ? row.cancel_at_period_end
                      ? 'bg-amber-50/60 border-amber-200'
                      : row.source === 'comp'
                        ? 'bg-violet-50/40 border-violet-200'
                        : ''
                    : ''"
                >
                  <div class="min-w-0 flex-1">
                    <div class="flex items-center gap-2 flex-wrap">
                      <span class="text-[13.5px] font-semibold text-slate-900">
                        {{ row.label }}
                      </span>
                      <!-- Status pill -->
                      <span
                        v-if="!row.entitled"
                        class="text-3xs font-semibold uppercase tracking-wide
                               px-2 py-0.5 rounded-full
                               bg-slate-100 text-slate-500"
                      >Belum aktif</span>
                      <span
                        v-else-if="row.cancel_at_period_end"
                        class="text-3xs font-semibold uppercase tracking-wide
                               px-2 py-0.5 rounded-full
                               bg-amber-100 text-amber-800"
                      >Akan berakhir</span>
                      <span
                        v-else-if="row.source === 'comp'"
                        class="text-3xs font-semibold uppercase tracking-wide
                               px-2 py-0.5 rounded-full
                               bg-violet-100 text-violet-800"
                      >Gratis · comp</span>
                      <span
                        v-else
                        class="text-3xs font-semibold uppercase tracking-wide
                               px-2 py-0.5 rounded-full
                               bg-emerald-100 text-emerald-800"
                      >Aktif · paid</span>
                    </div>
                    <div class="text-[11.5px] text-slate-500 mt-1 tabular-nums">
                      <span class="font-mono text-[10.5px] text-slate-400 mr-2">{{ row.module_key }}</span>
                      {{ priceSnippet(row) }}
                    </div>
                  </div>

                  <!-- Actions -->
                  <div class="flex-shrink-0 flex items-center gap-2">
                    <template v-if="!row.entitled">
                      <button
                        type="button"
                        class="text-[11.5px] font-semibold px-3 py-1.5 rounded-lg
                               bg-violet-600 text-white hover:bg-violet-700
                               disabled:opacity-50 disabled:cursor-not-allowed"
                        :disabled="rowBusyKey === row.module_key"
                        @click="grantComp(row)"
                      >Grant · gratis</button>
                      <button
                        type="button"
                        class="text-[11.5px] font-semibold px-3 py-1.5 rounded-lg
                               border border-slate-300 text-slate-700 hover:bg-slate-50
                               disabled:opacity-50 disabled:cursor-not-allowed"
                        :disabled="rowBusyKey === row.module_key"
                        @click="grantPaid(row)"
                      >Grant · paid</button>
                    </template>
                    <template v-else>
                      <button
                        v-if="!row.cancel_at_period_end"
                        type="button"
                        class="text-[11.5px] font-semibold px-3 py-1.5 rounded-lg
                               border border-amber-300 text-amber-800 hover:bg-amber-50
                               disabled:opacity-50 disabled:cursor-not-allowed"
                        :disabled="rowBusyKey === row.module_key"
                        @click="revokeAtPeriodEnd(row)"
                      >Cabut · akhir periode</button>
                      <button
                        type="button"
                        class="text-[11.5px] font-semibold px-3 py-1.5 rounded-lg
                               border border-rose-300 text-rose-700 hover:bg-rose-50
                               disabled:opacity-50 disabled:cursor-not-allowed"
                        :disabled="rowBusyKey === row.module_key"
                        @click="revokeNow(row)"
                      >Cabut sekarang</button>
                    </template>
                  </div>
                </article>
              </div>
            </section>
          </div>
        </template>
      </section>
    </div>
  </div>
</template>
