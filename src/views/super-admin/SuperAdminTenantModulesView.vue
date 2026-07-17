<!--
  SuperAdminTenantModulesView.vue — grant/revoke modules on any tenant.

  Two-pane surface:
    - LEFT: tenant picker with search (same shape as SuperAdminSchoolsView's
      tenants list, filtered to `paid` scope by default because comp/grant
      operations only make sense on tenants with an active subscription).
    - RIGHT: full module list for the selected tenant. Each row shows the
      entitlement state (Aktif · comp / paid / Belum aktif), the current
      per-seat snapshot, and either a "Grant · gratis" or "Cabut" button.
      Bundle-sourced rows get a "via Paket X" sub-badge so it's obvious
      the entitlement is inherited, not a standalone grant.

  All mutations flow through SuperAdminBillingService which hits
  /billing/admin/tenants/{schoolId}/modules — the tenant's cached
  entitlement is refreshed server-side before the response returns, so
  reloading the list picks up truth in one round-trip.

  Regression fix (MTs Muhammadiyah, Jul 2026): the page used to iterate
  the catalog and look up each module in a `subscription_modules` map;
  bundle-only tenants (one row `bundle_complete`) matched nothing and
  every module rendered "BELUM AKTIF" while the gate correctly unlocked
  ten member modules. Backend now expands bundles; this view renders the
  bundle_source badge + a dedicated "Paket aktif" tile so super-admin
  understands the source of the flood of green pills.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { SuperAdminTenantService } from '@/services/super-admin-tenant.service';
import { SuperAdminBillingService } from '@/services/super-admin-billing.service';
import type { PlatformTenant } from '@/types/super-admin-tenant';
import type {
  AdminTenantModuleRow,
  AdminTenantBundleRow,
  AdminTenantSubscriptionSnapshot,
} from '@/types/super-admin-billing';
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
const activeBundles = ref<AdminTenantBundleRow[]>([]);
const subscription = ref<AdminTenantSubscriptionSnapshot | null>(null);
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

// The row counters walk the expanded module list so a bundle-only
// tenant is credited for every member module — pre-fix, entitledCount
// read `0` for an MTs-Muhammadiyah-style tenant that owned everything
// via `bundle_complete` because no individual row was flagged entitled.
const entitledCount = computed<number>(
  () => modules.value.filter((r) => r.entitled).length,
);
const compCount = computed<number>(
  () => modules.value.filter((r) => r.entitled && r.source === 'comp').length,
);
const bundleSourcedCount = computed<number>(
  () => modules.value.filter((r) => r.entitled && r.bundle_source !== null).length,
);

/**
 * Whether the header tile should render strikethrough pricing + a
 * discount badge. Guarded so a subscription with no discount (or a
 * partially-populated `applied_discount` from an unpatched backend)
 * still renders cleanly — we only paint the strikethrough when the
 * paid amount is genuinely LESS than the pre-discount monthly.
 */
const hasDiscount = computed<boolean>(() => {
  const s = subscription.value;
  return s !== null
    && s.applied_discount !== null
    && s.amount < s.monthly_amount;
});

const discountLabel = computed<string | null>(() => {
  const d = subscription.value?.applied_discount;
  if (!d) return null;
  if (d.type === 'percent' && d.value !== null) {
    return `${d.value}% off`;
  }
  if (d.type === 'nominal' && d.discount_amount > 0) {
    return `Hemat ${formatMoney(d.discount_amount)}`;
  }
  return d.code ?? 'Diskon aktif';
});

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
    activeBundles.value = [];
    subscription.value = null;
    return;
  }
  modulesLoading.value = true;
  modulesError.value = null;
  try {
    const payload = await SuperAdminBillingService.listModules(selectedTenant.value.id);
    modules.value = payload.modules;
    activeBundles.value = payload.bundles;
    subscription.value = payload.subscription;
  } catch (e) {
    modulesError.value = (e as Error).message;
    modules.value = [];
    activeBundles.value = [];
    subscription.value = null;
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

function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Intl.DateTimeFormat('id-ID', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    }).format(new Date(iso));
  } catch {
    return '—';
  }
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

function bundlePriceSnippet(b: AdminTenantBundleRow): string {
  const parts: string[] = [];
  if (b.price_per_student > 0) parts.push(`${formatMoney(b.price_per_student)}/siswa`);
  if (b.price_per_staff > 0) parts.push(`${formatMoney(b.price_per_staff)}/guru`);
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
                  <template v-if="bundleSourcedCount > 0">
                    · {{ bundleSourcedCount }} via paket
                  </template>
                </div>
              </div>
            </div>

            <!-- Subscription pricing sub-tile — strikethrough monthly +
                 actual amount + discount badge. Only rendered when the
                 tenant has an active subscription. Mirrors the LANGGANAN
                 ANDA tile pattern from the self-service Kelola Modul
                 page so both surfaces read the same. -->
            <div
              v-if="subscription"
              class="mt-4 pt-4 border-t border-slate-100
                     flex flex-wrap items-end justify-between gap-3"
            >
              <div class="min-w-0">
                <div class="text-[10.5px] font-semibold uppercase tracking-wider text-slate-500">
                  Tagihan bulan ini
                </div>
                <div class="mt-1 flex items-end gap-2 flex-wrap">
                  <div class="text-[20px] font-bold text-slate-900 tabular-nums leading-none">
                    {{ formatMoney(subscription.amount) }}
                  </div>
                  <div
                    v-if="hasDiscount"
                    class="text-[13px] text-slate-400 line-through tabular-nums leading-tight"
                  >
                    {{ formatMoney(subscription.monthly_amount) }}
                  </div>
                  <span
                    v-if="hasDiscount && discountLabel"
                    class="text-3xs font-semibold uppercase tracking-wide
                           px-2 py-0.5 rounded-full
                           bg-rose-100 text-rose-800"
                  >{{ discountLabel }}</span>
                </div>
                <div
                  v-if="hasDiscount && subscription.applied_discount?.code"
                  class="text-[11.5px] text-slate-500 mt-1.5"
                >
                  Kode <span class="font-mono font-semibold text-slate-700">{{ subscription.applied_discount.code }}</span>
                  <template v-if="subscription.applied_discount.duration_months">
                    · berlaku {{ subscription.applied_discount.duration_months }} bulan
                  </template>
                  <template v-if="subscription.applied_discount.valid_until">
                    · hingga {{ formatDate(subscription.applied_discount.valid_until) }}
                  </template>
                </div>
                <div
                  v-if="hasDiscount && subscription.applied_discount?.description"
                  class="text-[11px] text-slate-500 mt-0.5"
                >{{ subscription.applied_discount.description }}</div>
              </div>
              <div class="text-right text-[12px] text-slate-600 space-y-0.5">
                <div>
                  <span class="text-slate-400">Paket:</span>
                  <span class="ml-1 font-semibold text-slate-800">{{ subscription.plan === 'yearly' ? 'Tahunan' : 'Bulanan' }}</span>
                </div>
                <div>
                  <span class="text-slate-400">Berakhir:</span>
                  <span class="ml-1 text-slate-700">{{ formatDate(subscription.expires_at) }}</span>
                  <span
                    v-if="subscription.days_remaining > 0"
                    class="ml-1 text-slate-400"
                  >({{ subscription.days_remaining }} hari lagi)</span>
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

          <template v-else>
            <!-- ══ Paket aktif tile ══
                 Only rendered when the tenant holds at least one bundle.
                 Each package shows its member roster so super-admin can
                 spot at a glance where the flood of green module badges
                 below is inherited from. -->
            <section v-if="activeBundles.length > 0" class="mb-6">
              <div class="text-[10.5px] font-semibold uppercase tracking-wider text-slate-500 mb-2 px-1">
                Paket aktif
              </div>
              <div class="space-y-2">
                <article
                  v-for="bundle in activeBundles"
                  :key="bundle.module_key"
                  class="bg-white border border-blue-200 rounded-xl px-4 py-3
                         flex items-start gap-3"
                  :class="bundle.cancel_at_period_end ? 'bg-amber-50/60 border-amber-200' : 'bg-blue-50/40'"
                >
                  <div
                    class="w-9 h-9 rounded-lg grid place-items-center flex-shrink-0
                           bg-blue-100 text-blue-700"
                    aria-hidden="true"
                  >
                    <i class="ti ti-package text-lg" />
                  </div>
                  <div class="min-w-0 flex-1">
                    <div class="flex items-center gap-2 flex-wrap">
                      <span class="text-[13.5px] font-semibold text-slate-900">{{ bundle.label }}</span>
                      <span
                        v-if="bundle.cancel_at_period_end"
                        class="text-3xs font-semibold uppercase tracking-wide
                               px-2 py-0.5 rounded-full
                               bg-amber-100 text-amber-800"
                      >Akan berakhir</span>
                      <span
                        v-else-if="bundle.source === 'comp'"
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
                      <span class="font-mono text-[10.5px] text-slate-400 mr-2">{{ bundle.module_key }}</span>
                      {{ bundlePriceSnippet(bundle) }}
                    </div>
                    <div class="text-[11px] text-slate-600 mt-1.5">
                      <span class="text-slate-400">Termasuk:</span>
                      <span class="ml-1">
                        {{ bundle.members.map((m) => m.label).join(' · ') }}
                      </span>
                    </div>
                  </div>
                </article>
              </div>
            </section>

            <!-- ══ Modules grouped by catalog group ══ -->
            <div class="space-y-6">
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
                          : row.bundle_source
                            ? 'bg-blue-50/30 border-blue-200'
                            : ''
                      : ''"
                  >
                    <div class="min-w-0 flex-1">
                      <div class="flex items-center gap-2 flex-wrap">
                        <span class="text-[13.5px] font-semibold text-slate-900">
                          {{ row.label }}
                        </span>
                        <!-- Status pill: not-entitled / expiring / comp / paid.
                             Entitled rows inherited from a bundle also carry
                             a SUB-badge so it's obvious the module isn't a
                             standalone grant. -->
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
                        >Aktif · comp</span>
                        <span
                          v-else
                          class="text-3xs font-semibold uppercase tracking-wide
                                 px-2 py-0.5 rounded-full
                                 bg-emerald-100 text-emerald-800"
                        >Aktif</span>
                        <span
                          v-if="row.entitled && row.bundle_source"
                          class="text-3xs font-semibold uppercase tracking-wide
                                 px-2 py-0.5 rounded-full
                                 bg-blue-100 text-blue-800"
                          :title="`Diaktifkan lewat ${row.bundle_label ?? row.bundle_source}`"
                        >via {{ row.bundle_label ?? row.bundle_source }}</span>
                      </div>
                      <div class="text-[11.5px] text-slate-500 mt-1 tabular-nums">
                        <span class="font-mono text-[10.5px] text-slate-400 mr-2">{{ row.module_key }}</span>
                        {{ priceSnippet(row) }}
                      </div>
                    </div>

                    <!-- Actions.
                         Bundle-sourced rows intentionally do NOT expose a
                         "Cabut sekarang" button — you can't revoke a
                         member module without breaking the whole bundle.
                         Super-admin can still comp-grant an override
                         (individual row wins over bundle source), which
                         we keep visible even when the bundle already
                         entitles the module. -->
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
                      <template v-else-if="row.bundle_source && row.source !== 'comp'">
                        <!-- Bundle-inherited row with no standalone
                             override → offer a comp override only. -->
                        <span
                          class="text-[11px] text-slate-400 italic mr-1"
                          title="Modul ini diaktifkan lewat paket; cabut paket untuk menonaktifkan seluruh anggota."
                        >dari paket</span>
                        <button
                          type="button"
                          class="text-[11.5px] font-semibold px-3 py-1.5 rounded-lg
                                 border border-violet-300 text-violet-700 hover:bg-violet-50
                                 disabled:opacity-50 disabled:cursor-not-allowed"
                          :disabled="rowBusyKey === row.module_key"
                          @click="grantComp(row)"
                          title="Tambah baris comp sebagai override individu (paket tetap aktif)."
                        >Override · comp</button>
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
        </template>
      </section>
    </div>
  </div>
</template>
