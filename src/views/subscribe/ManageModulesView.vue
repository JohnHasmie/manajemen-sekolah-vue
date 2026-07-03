<!--
  ManageModulesView.vue — admin self-service module management.

  Three affordances, all driven by the same server truth (GET
  /billing/modules/mine):
    1. See what's active + billed this month + billed next month.
    2. Turn off a module at period-end (cancel_at_period_end=true) —
       stays entitled until expires_at, no refund, dropped from the
       renewal quote. Cancellable.
    3. Turn on a new module mid-cycle via prorata (POST /modules/add
       creates a bank-transfer addon; caller navigates to the
       transfer confirmation UX at /subscribe/addon/transfer/…).

  Matches the approved high-fidelity mockup (mockup_manage_modules.html):
   - Two-column layout — module rows left, sticky summary right.
   - Sections: Modul aktif → Akan berakhir → Tambah modul.
   - Confirm-cancel modal spells out access sampai tgl / no refund /
     bisa dibatalkan; prorata modal shows the exact days × daily rate
     × seat count breakdown the backend will actually charge.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { SubscriptionBillingService } from '@/services/billing.service';
import type {
  ModuleCatalog,
  MyModules,
  MyModuleRow,
  MyModulesSubscription,
  TenantType,
} from '@/types/subscription-billing';
import {
  CATEGORY_TINTS,
  MODULE_ICONS,
  isModuleHiddenFor,
  moduleLabel,
  moduleTagline,
  money,
  seatUnit,
} from '@/components/subscribe/moduleTokens';

const router = useRouter();
const auth = useAuthStore();

// ── State ──────────────────────────────────────────────────────────
const catalog = ref<ModuleCatalog | null>(null);
const mine = ref<MyModules>({ subscription: null, modules: [] });
const loading = ref(true);
const errorMessage = ref<string | null>(null);
const tenantType = ref<TenantType | null>(null);
const tenantName = ref<string>('');

// Confirm modal state — one modal for both cancel + add.
type ConfirmMode = 'cancel' | 'resume' | 'add';
const confirmMode = ref<ConfirmMode | null>(null);
const confirmKey = ref<string | null>(null);
const confirmBusy = ref(false);

// ── Derived ────────────────────────────────────────────────────────
const sub = computed<MyModulesSubscription | null>(() => mine.value.subscription);

const rowsByKey = computed<Map<string, MyModuleRow>>(() => {
  const m = new Map<string, MyModuleRow>();
  mine.value.modules.forEach((r) => m.set(r.module_key, r));
  return m;
});

const activeRows = computed<MyModuleRow[]>(() =>
  mine.value.modules.filter((r) => !r.cancel_at_period_end),
);
const cancelledRows = computed<MyModuleRow[]>(() =>
  mine.value.modules.filter((r) => r.cancel_at_period_end),
);

const availableCatalog = computed(() => {
  if (!catalog.value) return [] as { key: string; item: NonNullable<ModuleCatalog['optional'][string]> }[];
  const held = new Set(mine.value.modules.map((r) => r.module_key));
  const tt = tenantType.value;
  return Object.entries(catalog.value.optional)
    .filter(([key, item]) => {
      if (held.has(key)) return false;
      // Same sekolah↔bimbel visibility rule the wizard picker uses —
      // a bimbel admin never gets offered modules whose backend
      // endpoints don't route bimbel traffic (attendance_student etc.),
      // and vice versa.
      return !isModuleHiddenFor(key, item.group, tt);
    })
    .map(([key, item]) => ({ key, item }));
});

const monthlyThisPeriod = computed<number>(() =>
  mine.value.modules.reduce((sum, r) => sum + r.monthly_amount, 0),
);

const monthlyNextPeriod = computed<number>(() =>
  activeRows.value.reduce((sum, r) => sum + r.monthly_amount, 0),
);

const monthlyDelta = computed<number>(
  () => monthlyNextPeriod.value - monthlyThisPeriod.value,
);

const expiresDate = computed<string>(() => formatDate(sub.value?.expires_at));

const startsDate = computed<string>(() => formatDate(sub.value?.starts_at));

const daysRemaining = computed<number>(() => sub.value?.days_remaining ?? 0);

const initials = computed<string>(() =>
  (tenantName.value || auth.user?.name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0])
    .join('')
    .toUpperCase(),
);

const perUnitWord = computed<string>(() =>
  tenantType.value === 'bimbel' ? 'peserta' : 'siswa',
);

// The row targeted by whichever modal is open.
const confirmRow = computed<MyModuleRow | null>(() =>
  confirmKey.value ? rowsByKey.value.get(confirmKey.value) ?? null : null,
);
const confirmCatalogItem = computed(() =>
  confirmKey.value ? catalog.value?.optional[confirmKey.value] ?? null : null,
);

// Prorata preview: exactly matches AddModuleAction's formula
// (monthly × days_remaining / 30). Computed FE-side so we don't need
// a preview endpoint; the mutation still recomputes server-side.
const proratedAdd = computed<{ dailyRate: number; monthly: number; amount: number } | null>(() => {
  if (confirmMode.value !== 'add' || !confirmCatalogItem.value || !sub.value) return null;
  const item = confirmCatalogItem.value;
  const monthly =
    item.price_per_student * sub.value.student_count +
    item.price_per_staff * sub.value.staff_count;
  const days = Math.max(1, daysRemaining.value);
  const amount = Math.floor((monthly * days) / 30);
  const dailyRate = Math.floor(monthly / 30);
  return { dailyRate, monthly, amount };
});

const requiresLabels = computed<string[]>(() => {
  if (confirmMode.value !== 'add' || !confirmCatalogItem.value || !catalog.value) return [];
  return confirmCatalogItem.value.requires
    .map((k) => catalog.value?.optional[k])
    .filter(Boolean)
    .map((it) => moduleLabel(it!, tenantType.value));
});

// ── Effects ────────────────────────────────────────────────────────
async function loadAll(): Promise<void> {
  loading.value = true;
  errorMessage.value = null;
  try {
    const [cat, m, tenants] = await Promise.all([
      SubscriptionBillingService.getModuleCatalog(),
      SubscriptionBillingService.getMyModules(),
      SubscriptionBillingService.getMyTenants().catch(() => []),
    ]);
    catalog.value = cat;
    mine.value = m;
    // Pick tenant type + display name from the tenant list — the modules
    // endpoint doesn't ship this, and it drives the sekolah/bimbel copy.
    const target =
      tenants.find((t) => t.id === m.subscription?.id) ??
      tenants.find((t) => t.subscription_status !== 'expired') ??
      tenants[0];
    if (target) {
      tenantType.value = target.tenant_type;
      tenantName.value = target.name;
    }
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  if (!auth.isAuthenticated) {
    router.replace('/subscribe');
    return;
  }
  loadAll();
});

// ── Actions ────────────────────────────────────────────────────────
function askCancel(key: string): void {
  confirmMode.value = 'cancel';
  confirmKey.value = key;
}
function askResume(key: string): void {
  confirmMode.value = 'resume';
  confirmKey.value = key;
}
function askAdd(key: string): void {
  confirmMode.value = 'add';
  confirmKey.value = key;
}
function closeModal(): void {
  if (confirmBusy.value) return;
  confirmMode.value = null;
  confirmKey.value = null;
}

async function doCancel(): Promise<void> {
  if (!sub.value || !confirmKey.value) return;
  confirmBusy.value = true;
  try {
    await SubscriptionBillingService.cancelModule({
      subscription_id: sub.value.id,
      module_key: confirmKey.value,
    });
    await loadAll();
    closeModal();
  } catch (e) {
    errorMessage.value = (e as Error).message;
    confirmBusy.value = false;
  } finally {
    confirmBusy.value = false;
  }
}
async function doResume(): Promise<void> {
  if (!sub.value || !confirmKey.value) return;
  confirmBusy.value = true;
  try {
    await SubscriptionBillingService.resumeModule({
      subscription_id: sub.value.id,
      module_key: confirmKey.value,
    });
    await loadAll();
    closeModal();
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    confirmBusy.value = false;
  }
}
async function doAdd(): Promise<void> {
  if (!sub.value || !confirmKey.value) return;
  confirmBusy.value = true;
  try {
    const created = await SubscriptionBillingService.addModule({
      subscription_id: sub.value.id,
      module_key: confirmKey.value,
    });
    // Backend returns a share_url that ends in /subscribe/addon/transfer/{token}.
    // Send the caller to the transfer confirmation page — same pattern as
    // the seat top-up flow.
    const token = shareTokenFromShareUrl(created.share_url);
    if (token) {
      router.push(`/subscribe/addon/transfer/${token}`);
      return;
    }
    // Fallback: reload the module list; the pending addon shows up in
    // ManageModulesView after admin approval anyway.
    await loadAll();
    closeModal();
  } catch (e) {
    errorMessage.value = (e as Error).message;
    confirmBusy.value = false;
  }
}

function shareTokenFromShareUrl(url: string | null | undefined): string | null {
  if (!url) return null;
  const parts = String(url).split('/subscribe/addon/transfer/');
  return parts[1]?.replace(/\/.*$/, '') ?? null;
}

// ── Helpers ────────────────────────────────────────────────────────
function tintFor(group: string): { bg: string; fg: string } {
  return CATEGORY_TINTS[group] ?? CATEGORY_TINTS.Default;
}
function iconFor(key: string): string {
  return MODULE_ICONS[key] ?? 'circle-plus';
}
function labelFor(key: string): string {
  const item = catalog.value?.optional[key];
  return item ? moduleLabel(item, tenantType.value) : key;
}
function taglineFor(key: string): string {
  const item = catalog.value?.optional[key];
  return item ? moduleTagline(item, tenantType.value) : '';
}
function seatBreakdown(row: MyModuleRow): string {
  if (!sub.value) return '';
  const parts: string[] = [];
  if (row.price_per_student_snapshot > 0) {
    parts.push(
      `${sub.value.student_count.toLocaleString('id-ID')} ${perUnitWord.value} × ${money(row.price_per_student_snapshot)}`,
    );
  }
  if (row.price_per_staff_snapshot > 0) {
    const staffWord = tenantType.value === 'bimbel' ? 'tutor' : 'guru';
    parts.push(`${sub.value.staff_count} ${staffWord} × ${money(row.price_per_staff_snapshot)}`);
  }
  return parts.join(' + ');
}
function seatSuffixFor(item: NonNullable<ModuleCatalog['optional'][string]>): string {
  return `${seatUnit(item, tenantType.value)} / bln`;
}
function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Intl.DateTimeFormat('id-ID', {
      day: 'numeric', month: 'short', year: 'numeric',
    }).format(new Date(iso));
  } catch { return '—'; }
}
</script>

<template>
  <div class="mm-page">
    <!-- Nav (same chrome as /subscribe) -->
    <div class="mm-nav">
      <div class="mm-logo">K</div>
      <div class="mm-brand">
        <div class="mm-brand-name">KamilEdu</div>
        <div class="mm-brand-tag">Langganan · Kelola modul</div>
      </div>
      <div class="mm-nav-right">
        <a
          href="https://wa.me/6285179819002"
          target="_blank"
          rel="noopener"
          class="mm-nav-link"
        >
          <i class="ti ti-message-circle" aria-hidden="true" />
          Bantuan
        </a>
        <router-link to="/" class="mm-nav-link">
          <i class="ti ti-arrow-left" aria-hidden="true" />
          Kembali ke dashboard
        </router-link>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mm-loading">
      <div class="mm-spinner" aria-hidden="true"></div>
      <div>Memuat modul langganan…</div>
    </div>

    <!-- No active subscription -->
    <div v-else-if="!sub" class="mm-empty">
      <div class="mm-empty-card">
        <div class="mm-empty-h1">Belum ada langganan aktif</div>
        <p class="mm-empty-sub">
          Halaman ini menampilkan modul yang aktif di langganan Anda.
          Belum ada langganan yang bisa dikelola — silakan mulai dulu.
        </p>
        <button type="button" class="btn primary" @click="router.push('/subscribe')">
          Mulai langganan
          <i class="ti ti-arrow-right" aria-hidden="true" />
        </button>
      </div>
    </div>

    <!-- Main content -->
    <template v-else>
      <!-- Hero strip -->
      <div class="mm-hero">
        <div class="mm-hero-avatar">{{ initials }}</div>
        <div class="mm-hero-body">
          <div class="mm-hero-kicker">
            {{ tenantName || 'Langganan Anda' }} ·
            {{ tenantType === 'bimbel' ? 'Bimbel / kursus' : 'Sekolah formal' }}
          </div>
          <h1 class="mm-hero-h1">Kelola modul langganan Anda</h1>
          <div class="mm-hero-meta">
            <span>Periode berjalan {{ startsDate }} – {{ expiresDate }}</span>
            <span>{{ sub.student_count }} {{ perUnitWord }} · {{ sub.staff_count }}
              {{ tenantType === 'bimbel' ? 'tutor' : 'guru' }}</span>
            <span>Sisa {{ daysRemaining }} hari</span>
          </div>
        </div>
        <div class="mm-hero-side">
          <span class="pill is-active">Aktif</span>
          <div class="mm-hero-side-sub">Perpanjangan otomatis</div>
        </div>
      </div>

      <p v-if="errorMessage" class="mm-err">{{ errorMessage }}</p>

      <div class="mm-body">
        <!-- MAIN column -->
        <div class="mm-main">
          <!-- MODUL AKTIF -->
          <section class="mm-sec">
            <header class="mm-sec-head">
              <span class="mm-sec-lbl">Modul aktif</span>
              <span class="mm-sec-count">{{ activeRows.length }}</span>
              <span class="mm-sec-hint">Diperpanjang otomatis bulan depan</span>
            </header>

            <div v-if="!activeRows.length" class="mm-sec-empty">
              Tidak ada modul aktif di langganan ini.
            </div>

            <article
              v-for="row in activeRows"
              :key="`a-${row.module_key}`"
              class="mm-row"
            >
              <div
                class="mm-row-icon"
                :style="{
                  background: tintFor(catalog?.optional[row.module_key]?.group ?? 'Default').bg,
                  color: tintFor(catalog?.optional[row.module_key]?.group ?? 'Default').fg,
                }"
              >
                <i :class="`ti ti-${iconFor(row.module_key)}`" aria-hidden="true" />
              </div>
              <div class="mm-row-body">
                <div class="mm-row-title">
                  {{ labelFor(row.module_key) }}
                  <span
                    class="pill"
                    :class="row.source === 'comp' ? 'is-comp' : 'is-active'"
                  >{{ row.source === 'comp' ? 'Gratis · hadiah' : 'Aktif' }}</span>
                </div>
                <div class="mm-row-sub">
                  {{ taglineFor(row.module_key) }}
                  <span v-if="seatBreakdown(row)"> · <strong>{{ seatBreakdown(row) }}</strong></span>
                </div>
              </div>
              <div class="mm-row-price">
                <template v-if="row.source === 'comp'">
                  Rp 0
                  <span class="u">Gratis</span>
                </template>
                <template v-else>
                  {{ money(row.monthly_amount) }}
                  <span class="u">/ bln</span>
                </template>
              </div>
              <div class="mm-row-action">
                <button
                  v-if="row.source !== 'comp'"
                  type="button"
                  class="row-cta is-danger"
                  @click="askCancel(row.module_key)"
                >Matikan modul</button>
              </div>
            </article>
          </section>

          <!-- AKAN BERAKHIR -->
          <section v-if="cancelledRows.length" class="mm-sec">
            <header class="mm-sec-head">
              <span class="mm-sec-lbl">Akan berakhir {{ expiresDate }}</span>
              <span class="mm-sec-count">{{ cancelledRows.length }}</span>
              <span class="mm-sec-hint">Tidak dihitung di tagihan bulan depan</span>
            </header>

            <div class="mm-note-strip">
              <i class="ti ti-alert-triangle" aria-hidden="true" />
              <div>
                Modul di bawah ini <strong>tetap aktif sampai {{ expiresDate }}</strong> — sudah dibayar untuk periode ini,
                tidak ada refund. Perpanjangan otomatis <strong>tidak</strong> akan menyertakan modul tersebut. Anda bisa
                membatalkan keputusan ini kapan saja sebelum periode berakhir.
              </div>
            </div>

            <article
              v-for="row in cancelledRows"
              :key="`c-${row.module_key}`"
              class="mm-row is-cancel"
            >
              <div
                class="mm-row-icon"
                :style="{
                  background: tintFor(catalog?.optional[row.module_key]?.group ?? 'Default').bg,
                  color: tintFor(catalog?.optional[row.module_key]?.group ?? 'Default').fg,
                }"
              >
                <i :class="`ti ti-${iconFor(row.module_key)}`" aria-hidden="true" />
              </div>
              <div class="mm-row-body">
                <div class="mm-row-title">
                  {{ labelFor(row.module_key) }}
                  <span class="pill is-warn">Aktif sampai {{ expiresDate }}</span>
                </div>
                <div class="mm-row-sub">
                  {{ taglineFor(row.module_key) }}
                  <span v-if="seatBreakdown(row)"> · <strong>{{ seatBreakdown(row) }}</strong></span>
                  · tersisa {{ daysRemaining }} hari
                </div>
              </div>
              <div class="mm-row-price">
                {{ money(row.monthly_amount) }}
                <span class="u">/ bln, terakhir</span>
              </div>
              <div class="mm-row-action">
                <button type="button" class="row-cta is-resume" @click="askResume(row.module_key)">
                  <i class="ti ti-refresh" aria-hidden="true" />
                  Batalkan penonaktifan
                </button>
              </div>
            </article>
          </section>

          <!-- TAMBAH MODUL -->
          <section v-if="availableCatalog.length" class="mm-sec">
            <header class="mm-sec-head">
              <span class="mm-sec-lbl">Tambah modul</span>
              <span class="mm-sec-count">{{ availableCatalog.length }}</span>
              <span class="mm-sec-hint">Biaya prorata untuk sisa periode berjalan</span>
            </header>

            <article
              v-for="{ key, item } in availableCatalog"
              :key="`v-${key}`"
              class="mm-row is-avail"
            >
              <div
                class="mm-row-icon"
                :style="{ background: tintFor(item.group).bg, color: tintFor(item.group).fg }"
              >
                <i :class="`ti ti-${iconFor(key)}`" aria-hidden="true" />
              </div>
              <div class="mm-row-body">
                <div class="mm-row-title">{{ moduleLabel(item, tenantType) }}</div>
                <div class="mm-row-sub">
                  {{ moduleTagline(item, tenantType) }} ·
                  <template v-if="item.price_per_student > 0">
                    {{ sub.student_count }} {{ perUnitWord }} × {{ money(item.price_per_student) }}
                  </template>
                  <template v-if="item.price_per_student > 0 && item.price_per_staff > 0"> + </template>
                  <template v-if="item.price_per_staff > 0">
                    {{ sub.staff_count }} {{ tenantType === 'bimbel' ? 'tutor' : 'guru' }} × {{ money(item.price_per_staff) }}
                  </template>
                </div>
              </div>
              <div class="mm-row-price">
                {{ money(item.price_per_student * sub.student_count + item.price_per_staff * sub.staff_count) }}
                <span class="u">/ bln, +prorata</span>
              </div>
              <div class="mm-row-action">
                <button type="button" class="row-cta is-add" @click="askAdd(key)">
                  <i class="ti ti-plus" aria-hidden="true" />
                  Tambahkan
                </button>
              </div>
            </article>
          </section>
        </div>

        <!-- SIDE column (sticky summary) -->
        <aside class="mm-side">
          <div class="side-card">
            <div class="side-kicker">Tagihan bulan ini</div>
            <div class="side-total">{{ money(monthlyThisPeriod) }}</div>
            <div class="side-total-sub">
              {{ mine.modules.length }} modul aktif · sudah dibayar {{ startsDate }}
            </div>
          </div>

          <div class="side-card side-preview">
            <div class="side-kicker">Perpanjangan otomatis</div>
            <div class="side-title">{{ expiresDate }}</div>
            <div class="side-total">{{ money(monthlyNextPeriod) }}</div>
            <span v-if="monthlyDelta < 0" class="side-delta">
              <i class="ti ti-arrow-down-right" aria-hidden="true" />
              −{{ money(-monthlyDelta) }} ·
              {{ cancelledRows.length }} modul berakhir
            </span>
            <span v-else-if="monthlyDelta === 0" class="side-delta neutral">
              Sama dengan bulan ini
            </span>
          </div>
        </aside>
      </div>
    </template>

    <!-- ═════════ Modal — Matikan modul ═════════ -->
    <div
      v-if="confirmMode === 'cancel' && confirmRow"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-cancel-title"
      @click.self="closeModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon warn"><i class="ti ti-alert-triangle" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-cancel-title" class="mm-modal-title">
              Matikan modul <em>{{ labelFor(confirmRow.module_key) }}</em>?
            </div>
            <div class="mm-modal-sub">
              Modul akan berhenti diperpanjang mulai <strong>{{ expiresDate }}</strong>. Fitur tetap bisa
              dipakai sampai tanggal itu — sudah dibayar untuk periode ini, tidak ada refund.
            </div>
          </div>
        </div>
        <ul class="mm-bullet">
          <li>Guru &amp; wali kelas tetap bisa akses <strong>sampai {{ expiresDate }}</strong>.</li>
          <li>Perpanjangan otomatis di {{ expiresDate }} <strong>tidak</strong> menyertakan modul ini
            (hemat {{ money(confirmRow.monthly_amount) }}/bln).</li>
          <li>Bisa diaktifkan kembali sebelum {{ expiresDate }} — cukup satu klik, tanpa biaya tambahan.</li>
          <li class="x">Setelah {{ expiresDate }} data terkait menjadi read-only. Ekspor tersedia 30 hari lagi.</li>
        </ul>
        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="confirmBusy" @click="closeModal">
            Batal, tetap aktif
          </button>
          <button class="btn warn" :disabled="confirmBusy" @click="doCancel">
            <template v-if="confirmBusy">Memproses…</template>
            <template v-else>Ya, matikan di {{ expiresDate }}</template>
          </button>
        </div>
      </div>
    </div>

    <!-- ═════════ Modal — Batalkan penonaktifan ═════════ -->
    <div
      v-if="confirmMode === 'resume' && confirmRow"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-resume-title"
      @click.self="closeModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon good"><i class="ti ti-refresh" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-resume-title" class="mm-modal-title">
              Aktifkan kembali <em>{{ labelFor(confirmRow.module_key) }}</em>?
            </div>
            <div class="mm-modal-sub">
              Modul akan ikut diperpanjang otomatis di <strong>{{ expiresDate }}</strong> dengan tarif snapshot
              yang sudah Anda bayarkan. Tidak ada biaya tambahan sekarang.
            </div>
          </div>
        </div>
        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="confirmBusy" @click="closeModal">Batal</button>
          <button class="btn primary" :disabled="confirmBusy" @click="doResume">
            <template v-if="confirmBusy">Memproses…</template>
            <template v-else>Ya, aktifkan kembali</template>
          </button>
        </div>
      </div>
    </div>

    <!-- ═════════ Modal — Tambahkan modul (prorata) ═════════ -->
    <div
      v-if="confirmMode === 'add' && confirmCatalogItem && sub"
      class="mm-scrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mm-add-title"
      @click.self="closeModal"
    >
      <div class="mm-modal">
        <div class="mm-modal-head">
          <div class="mm-modal-icon add"><i class="ti ti-plus" aria-hidden="true" /></div>
          <div class="mm-modal-body">
            <div id="mm-add-title" class="mm-modal-title">
              Tambahkan <em>{{ moduleLabel(confirmCatalogItem, tenantType) }}</em>
            </div>
            <div class="mm-modal-sub">
              {{ moduleTagline(confirmCatalogItem, tenantType) }} Modul aktif otomatis begitu pembayaran masuk —
              biasanya di bawah 15 menit lewat Midtrans, atau maks 1×24 jam lewat transfer.
            </div>
          </div>
        </div>

        <div class="mm-quote">
          <div class="mm-quote-row">
            <span class="mm-quote-lbl">Sisa periode berjalan</span>
            <span class="mm-quote-val">{{ daysRemaining }} hari</span>
          </div>
          <div v-if="proratedAdd" class="mm-quote-row">
            <span class="mm-quote-lbl">Tarif harian × seat</span>
            <span class="mm-quote-val">{{ money(proratedAdd.dailyRate) }} / hari</span>
          </div>
          <div v-if="proratedAdd" class="mm-quote-row">
            <span class="mm-quote-lbl">Bulan depan (mulai {{ expiresDate }})</span>
            <span class="mm-quote-val">{{ money(proratedAdd.monthly) }} / bln</span>
          </div>
          <div class="mm-quote-sep"></div>
          <div v-if="proratedAdd" class="mm-quote-row total">
            <span class="mm-quote-lbl">Bayar sekarang (prorata)</span>
            <span class="mm-quote-val">{{ money(proratedAdd.amount) }}</span>
          </div>
        </div>

        <ul class="mm-bullet mm-bullet-tight">
          <li>Aktif otomatis begitu pembayaran diverifikasi.</li>
          <li>Bulan depan sudah ikut perpanjangan otomatis.</li>
          <li v-if="requiresLabels.length" class="x">
            Modul ini butuh <strong>{{ requiresLabels.join(', ') }}</strong> aktif — hubungi kami lewat Bantuan
            jika belum tersedia di langganan Anda.
          </li>
          <li v-else>Bisa dimatikan kapan saja lewat halaman ini.</li>
        </ul>

        <div class="mm-modal-cta">
          <button class="btn ghost" :disabled="confirmBusy" @click="closeModal">Batal</button>
          <button class="btn primary" :disabled="confirmBusy" @click="doAdd">
            <template v-if="confirmBusy">Memproses…</template>
            <template v-else>
              Bayar {{ proratedAdd ? money(proratedAdd.amount) : '' }} &amp; aktifkan
              <i class="ti ti-arrow-right" aria-hidden="true" />
            </template>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.mm-page {
  min-height: 100vh;
  background: #FBFCFE;
  color: #0F172A;
  font-family: var(--font-sans);
  display: flex; flex-direction: column;
}

/* Nav */
.mm-nav {
  background: #FFFFFF;
  padding: 14px 22px;
  border-bottom: 0.5px solid #E7ECF3;
  display: flex; align-items: center; gap: 14px;
}
.mm-logo {
  width: 30px; height: 30px; border-radius: 8px;
  background: linear-gradient(135deg, #1B6FB8 0%, #113E75 100%);
  color: #fff; display: grid; place-items: center;
  font-weight: 600; font-size: 13px;
}
.mm-brand { display: flex; flex-direction: column; }
.mm-brand-name { font-size: 13.5px; font-weight: 600; letter-spacing: -0.1px; }
.mm-brand-tag { font-size: 10.5px; color: #64748B; margin-top: 1px; }
.mm-nav-right { margin-left: auto; display: flex; align-items: center; gap: 16px; }
.mm-nav-link {
  color: #64748B; text-decoration: none;
  font-size: 12px;
  display: inline-flex; align-items: center; gap: 6px;
}
.mm-nav-link:hover { color: #1B6FB8; }

/* Loading + empty */
.mm-loading {
  flex: 1;
  display: grid; place-items: center;
  color: #64748B; font-size: 13px;
  gap: 12px;
}
.mm-spinner {
  width: 22px; height: 22px;
  border: 2px solid #E2E8F0;
  border-top-color: #1B6FB8;
  border-radius: 50%;
  animation: mm-spin 0.8s linear infinite;
}
@keyframes mm-spin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) {
  .mm-spinner { animation: none; }
}
.mm-empty {
  flex: 1;
  display: grid; place-items: center;
  padding: 32px 22px;
}
.mm-empty-card {
  max-width: 420px;
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 14px;
  padding: 28px 24px;
  text-align: center;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04), 0 8px 24px rgba(15, 23, 42, 0.06);
}
.mm-empty-h1 { font-size: 18px; font-weight: 600; letter-spacing: -0.2px; }
.mm-empty-sub { font-size: 12.5px; color: #64748B; margin: 8px 0 18px; line-height: 1.55; }

/* Hero */
.mm-hero {
  padding: 22px 24px 18px;
  background: linear-gradient(180deg, #FBFDFF 0%, #FBFCFE 100%);
  border-bottom: 0.5px solid #E7ECF3;
  display: flex; align-items: flex-start; gap: 14px;
}
.mm-hero-avatar {
  width: 44px; height: 44px; border-radius: 10px;
  background: #E6F1FB; color: #113E75;
  display: grid; place-items: center;
  font-weight: 600; font-size: 14px;
  flex-shrink: 0;
}
.mm-hero-body { flex: 1; min-width: 0; }
.mm-hero-kicker {
  font-size: 10.5px; font-weight: 600;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: #1B6FB8;
}
.mm-hero-h1 {
  font-size: 20px; font-weight: 600;
  letter-spacing: -0.3px;
  margin: 2px 0 4px;
  text-wrap: balance;
}
.mm-hero-meta {
  font-size: 12px; color: #64748B;
  display: flex; gap: 14px; flex-wrap: wrap;
}
.mm-hero-meta span:not(:first-child)::before {
  content: "·"; margin-right: 10px; color: #94A3B8;
}
.mm-hero-side {
  display: flex; flex-direction: column; align-items: flex-end; gap: 6px;
  flex-shrink: 0;
}
.mm-hero-side-sub { font-size: 10.5px; color: #94A3B8; }

/* Body layout */
.mm-body {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 320px;
  background: #fff;
  flex: 1;
}
.mm-main { padding: 22px 24px 32px; min-width: 0; }
.mm-side {
  background: #F7FAFD;
  border-left: 0.5px solid #E7ECF3;
  padding: 22px 20px 24px;
  display: flex; flex-direction: column; gap: 14px;
  position: sticky; top: 0;
  align-self: flex-start;
  max-height: 100vh; overflow: auto;
}

.mm-err {
  margin: 0 24px 12px;
  font-size: 12px; color: #B91C1C;
  padding: 10px 12px;
  border-radius: 8px;
  background: #FEE2E2;
  border: 0.5px solid #FCA5A5;
}

/* Sections */
.mm-sec + .mm-sec { margin-top: 24px; }
.mm-sec-head {
  display: flex; align-items: center; gap: 10px;
  margin: 6px 0 12px;
}
.mm-sec-lbl {
  font-size: 10.5px; font-weight: 600;
  letter-spacing: 0.7px; text-transform: uppercase;
  color: #64748B;
}
.mm-sec-count {
  background: #E7ECF3; color: #64748B;
  padding: 1px 8px; border-radius: 999px;
  font-size: 10.5px; font-weight: 600;
}
.mm-sec-hint {
  font-size: 11px; color: #94A3B8;
  margin-left: auto;
}
.mm-sec-empty {
  padding: 20px 14px;
  text-align: center;
  color: #94A3B8; font-size: 11.5px;
  border: 0.5px dashed #E7ECF3;
  border-radius: 10px;
}

/* Row */
.mm-row {
  background: #fff;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 14px 16px;
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr) auto auto;
  align-items: center;
  gap: 14px;
  margin-bottom: 10px;
}
.mm-row-icon {
  width: 40px; height: 40px; border-radius: 10px;
  display: grid; place-items: center;
  font-size: 18px;
  flex-shrink: 0;
}
.mm-row-body { min-width: 0; }
.mm-row-title {
  font-size: 13.5px; font-weight: 600; color: #0F172A;
  display: flex; align-items: center; gap: 8px;
  letter-spacing: -0.1px;
  flex-wrap: wrap;
}
.mm-row-sub {
  font-size: 11.5px; color: #64748B;
  margin-top: 3px;
  font-variant-numeric: tabular-nums;
  line-height: 1.45;
}
.mm-row-sub strong { color: #0F172A; font-weight: 500; }
.mm-row-price {
  font-size: 13px; font-weight: 600; color: #0F172A;
  font-variant-numeric: tabular-nums;
  text-align: right;
  white-space: nowrap;
}
.mm-row-price .u {
  display: block; font-size: 10px;
  color: #64748B; font-weight: 500;
  letter-spacing: 0.2px;
}
.mm-row-action {
  display: flex; align-items: center; gap: 8px;
}

.mm-row.is-cancel {
  background: #FFFBEB;
  border-color: #FDE68A;
}
.mm-row.is-cancel .mm-row-sub { color: #92400E; }

.mm-row.is-avail {
  background: #FBFDFF;
  border: 0.5px dashed #C7DBEF;
}
.mm-row.is-avail .mm-row-title { color: #185FA5; font-weight: 500; }

/* Row CTA */
.row-cta {
  font-family: inherit;
  background: transparent; color: #64748B;
  border: 0.5px solid #E2E8F0;
  padding: 7px 12px; border-radius: 8px;
  font-size: 11.5px; font-weight: 500;
  cursor: pointer;
  display: inline-flex; align-items: center; gap: 6px;
  white-space: nowrap;
}
.row-cta:hover { color: #1B6FB8; border-color: #C7DBEF; }
.row-cta.is-danger { color: #B91C1C; border-color: #FCA5A5; }
.row-cta.is-danger:hover { background: #FEF2F2; }
.row-cta.is-add {
  background: #1B6FB8; color: #fff; border-color: #1B6FB8;
}
.row-cta.is-add:hover { background: #113E75; }
.row-cta.is-resume {
  background: #DCFCE7; color: #0F6E56;
  border-color: transparent;
}
.row-cta.is-resume:hover { background: #BBF7D0; }

/* Pills */
.pill {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 10px; font-weight: 600;
  padding: 2px 8px; border-radius: 999px;
  letter-spacing: 0.2px;
  line-height: 1.5;
}
.pill.is-active { background: #DCFCE7; color: #0F6E56; }
.pill.is-active::before {
  content: ""; width: 6px; height: 6px; border-radius: 50%;
  background: #1D9E75; display: inline-block;
}
.pill.is-warn { background: #FEF3C7; color: #B45309; }
.pill.is-comp { background: #EDE9FE; color: #6D28D9; }

/* Note strip inside cancelled section */
.mm-note-strip {
  background: #FEF3C7;
  border: 0.5px solid #FDE68A;
  border-radius: 10px;
  padding: 10px 12px;
  display: flex; align-items: flex-start; gap: 10px;
  font-size: 11.5px; color: #78350F;
  line-height: 1.5;
  margin-bottom: 12px;
}
.mm-note-strip i { color: #B45309; font-size: 14px; flex-shrink: 0; margin-top: 1px; }
.mm-note-strip strong { color: #78350F; font-weight: 600; }

/* Sidebar cards */
.side-card {
  background: #fff;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 14px 16px;
}
.side-kicker {
  font-size: 10px; font-weight: 600;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: #64748B;
  margin-bottom: 6px;
}
.side-title {
  font-size: 13px; font-weight: 600;
  color: #0F172A; letter-spacing: -0.1px;
}
.side-total {
  font-size: 24px; font-weight: 700;
  color: #113E75; letter-spacing: -0.5px;
  font-variant-numeric: tabular-nums;
  margin-top: 4px;
}
.side-total-sub {
  font-size: 11px; color: #64748B;
  margin-top: 4px;
  line-height: 1.4;
}
.side-preview { background: #F0F7FF; border-color: transparent; }
.side-preview .side-total { font-size: 20px; }
.side-delta {
  display: inline-flex; align-items: center; gap: 4px;
  background: rgba(15, 111, 86, 0.12);
  color: #0F6E56;
  padding: 3px 8px; border-radius: 6px;
  font-size: 11px; font-weight: 600;
  margin-top: 8px;
}
.side-delta i { font-size: 13px; }
.side-delta.neutral {
  background: rgba(100, 116, 139, 0.12);
  color: #475569;
}

/* Modal */
.mm-scrim {
  position: fixed; inset: 0;
  background: rgba(15, 23, 42, 0.42);
  display: grid; place-items: center;
  padding: 22px;
  z-index: 40;
}
.mm-modal {
  background: #fff;
  border: 0.5px solid #E2E8F0;
  border-radius: 14px;
  padding: 22px 22px 20px;
  max-width: 520px; width: 100%;
  box-shadow: 0 20px 60px rgba(15, 23, 42, 0.20);
}
.mm-modal-head {
  display: flex; align-items: flex-start; gap: 12px;
  margin-bottom: 14px;
}
.mm-modal-icon {
  width: 40px; height: 40px; border-radius: 10px;
  display: grid; place-items: center;
  flex-shrink: 0; font-size: 18px;
}
.mm-modal-icon.warn { background: #FEF3C7; color: #B45309; }
.mm-modal-icon.add { background: #E6F1FB; color: #1B6FB8; }
.mm-modal-icon.good { background: #DCFCE7; color: #0F6E56; }
.mm-modal-body { flex: 1; min-width: 0; }
.mm-modal-title {
  font-size: 16px; font-weight: 600; letter-spacing: -0.2px;
  text-wrap: balance;
}
.mm-modal-title em { font-style: normal; color: #1B6FB8; }
.mm-modal-icon.warn ~ .mm-modal-body .mm-modal-title em { color: #B45309; }
.mm-modal-icon.good ~ .mm-modal-body .mm-modal-title em { color: #0F6E56; }
.mm-modal-sub {
  font-size: 12.5px; color: #64748B;
  margin-top: 4px; line-height: 1.5;
}
.mm-modal-sub strong { color: #0F172A; font-weight: 500; }

.mm-bullet {
  background: #FBFCFE;
  border-radius: 10px;
  padding: 12px 14px;
  margin: 8px 0 0;
  font-size: 12px; color: #64748B;
  line-height: 1.55;
  list-style: none;
}
.mm-bullet-tight { margin-top: 12px; }
.mm-bullet li {
  padding-left: 22px;
  position: relative;
  margin: 4px 0;
}
.mm-bullet li::before {
  content: "✓"; position: absolute; left: 4px;
  color: #0F6E56; font-weight: 700;
}
.mm-bullet li.x::before { content: "×"; color: #991B1B; }
.mm-bullet strong { color: #0F172A; font-weight: 600; }

/* Quote box */
.mm-quote {
  background: #FBFCFE;
  border: 0.5px solid #E7ECF3;
  border-radius: 10px;
  padding: 12px 14px;
  margin-top: 14px;
  font-variant-numeric: tabular-nums;
}
.mm-quote-row {
  display: flex; justify-content: space-between; align-items: baseline;
  padding: 4px 0;
  font-size: 12.5px;
}
.mm-quote-lbl { color: #64748B; }
.mm-quote-val { color: #0F172A; font-weight: 500; }
.mm-quote-sep {
  height: 1px; background: #E7ECF3;
  margin: 6px -14px;
}
.mm-quote-row.total .mm-quote-lbl { color: #0F172A; font-weight: 600; }
.mm-quote-row.total .mm-quote-val { color: #113E75; font-weight: 700; font-size: 15px; }

/* Modal footer */
.mm-modal-cta {
  display: flex; gap: 10px; margin-top: 16px;
}
.btn {
  font-family: inherit; cursor: pointer;
  padding: 9px 14px; border-radius: 8px;
  font-size: 12.5px; font-weight: 500;
  display: inline-flex; align-items: center; justify-content: center; gap: 6px;
  border: 0.5px solid transparent;
  flex: 1;
}
.btn:disabled { opacity: 0.6; cursor: not-allowed; }
.btn.ghost { background: #fff; color: #64748B; border-color: #E2E8F0; }
.btn.ghost:hover:not(:disabled) { color: #1B6FB8; border-color: #C7DBEF; }
.btn.warn { background: #B45309; color: #fff; }
.btn.warn:hover:not(:disabled) { background: #92400E; }
.btn.primary { background: #1B6FB8; color: #fff; }
.btn.primary:hover:not(:disabled) { background: #113E75; }

@media (max-width: 900px) {
  .mm-body { grid-template-columns: 1fr; }
  .mm-side { border-left: none; border-top: 0.5px solid #E7ECF3; position: static; max-height: none; }
}
@media (max-width: 640px) {
  .mm-row { grid-template-columns: 40px 1fr; }
  .mm-row-price { grid-column: 2 / 3; text-align: left; }
  .mm-row-action { grid-column: 2 / 3; }
}
</style>
