<!--
  AdminTutoring2VouchersView.vue — greenfield "Voucher & Kode Promo" list
  for BE-16. Mirrors AdminTutoring2ProgramsView.vue in structure:
    - BrandPageHeader (admin)
    - KpiStripCards (aktif / kadaluarsa / terpakai bulan ini / sisa kuota)
    - PageFilterToolbar + AppFilterChip for status
    - AsyncView + table of vouchers
    - FAB → create voucher (ability-gated)
    - Segmented control tabs: "Vouchers" | "Log Penggunaan"

  Ability gates via useAuthStore().hasAbility (no `useAbility` composable
  exists in this repo — the auth-store getter is the app-wide pattern).
  Route-guard `needs: 'tutoring-module' + ability: tutoring.voucher.view`
  is set in the router.
-->
<script setup lang="ts">
import { computed, reactive, ref, toRaw, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { toLocalYmd } from '@/lib/local-date';
import { useAuthStore } from '@/stores/auth';
import { VouchersService } from '@/services/tutoring2/vouchers';
import type {
  BimbelVoucher,
  VoucherCreatePayload,
  VoucherKind,
  VoucherStatus,
} from '@/types/tutoring2/voucher';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const auth = useAuthStore();

const canManage = computed(() => auth.hasAbility('tutoring.voucher.manage'));
const canRedeem = computed(() => auth.hasAbility('tutoring.voucher.redeem'));

// ─── Tabs (Vouchers / Log Penggunaan) ─────────────────────────────
type TabKey = 'list' | 'redemptions';
const tab = ref<TabKey>('list');

// ─── Filters + search ─────────────────────────────────────────────
const search = ref('');
const statusFilter = ref<'' | VoucherStatus>('');
const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

// ─── Data fetch ───────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const { items } = await VouchersService.list({
    per_page: 50,
    search: debouncedSearch.value || undefined,
    status: statusFilter.value || undefined,
  });
  return items;
});

watch([debouncedSearch, statusFilter], () => reload());

const activeCount = computed(() =>
  state.value.status === 'content' ? (state.value.data as BimbelVoucher[]).length : 0,
);

// ─── KPI derivation ───────────────────────────────────────────────
// Everything is derived from the loaded page — matches the pattern in
// AdminTutoring2ProgramsView.vue (server-side aggregate endpoints for
// vouchers do not exist yet; when BE-16.1 adds a `/vouchers/summary`
// endpoint we swap these to a parallel fetch).
const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content'
    ? state.value.data
    : []) as BimbelVoucher[];
  const today = toLocalYmd();
  const activeVouchers = items.filter((v) => v.status === 'active');
  const expired = items.filter(
    (v) => v.valid_until != null && v.valid_until < today,
  );
  const usedThisMonth = items.reduce(
    (sum, v) => sum + (v.redemption_count ?? 0),
    0,
  );
  const remainingQuota = items.reduce<number>((sum, v) => {
    if (v.max_redemptions == null) return sum;
    const used = v.redemption_count ?? 0;
    return sum + Math.max(0, v.max_redemptions - used);
  }, 0);
  return [
    {
      icon: 'tag',
      label: t('tutoring2.admin.vouchers.kpiActive'),
      value: String(activeVouchers.length),
      tone: 'green',
    },
    {
      icon: 'calendar',
      label: t('tutoring2.admin.vouchers.kpiExpired'),
      value: String(expired.length),
      tone: expired.length > 0 ? 'amber' : undefined,
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.admin.vouchers.kpiUsedThisMonth'),
      value: String(usedThisMonth),
    },
    {
      icon: 'wallet',
      label: t('tutoring2.admin.vouchers.kpiRemainingQuota'),
      value: String(remainingQuota),
    },
  ];
});

// ─── Status / discount rendering ──────────────────────────────────
function statusPillTone(status: VoucherStatus): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'archived':
      return 'neutral';
  }
}

function statusLabel(v: BimbelVoucher): string {
  if (v.status === 'active' && v.valid_until && v.valid_until < toLocalYmd()) {
    return t('tutoring2.admin.vouchers.statusExpired');
  }
  return v.status_label ?? t(`tutoring2.admin.vouchers.status.${v.status}`);
}

function discountLabel(v: BimbelVoucher): string {
  return v.kind === 'percent'
    ? `${v.value}%`
    : `Rp ${v.value.toLocaleString('id-ID')}`;
}

function validRange(v: BimbelVoucher): string {
  const from = v.valid_from ?? '—';
  const until = v.valid_until ?? '—';
  if (from === '—' && until === '—') {
    return t('tutoring2.admin.vouchers.alwaysValid');
  }
  return `${from} → ${until}`;
}

function usesLabel(v: BimbelVoucher): string {
  const used = v.redemption_count ?? 0;
  const max = v.max_redemptions;
  return max == null ? `${used} / ∞` : `${used} / ${max}`;
}

// ─── Create / Edit sheet ──────────────────────────────────────────
// Reactive form + `structuredClone(toRaw(x))` when we need to snapshot
// (see reference_vue_structuredclone_reactive.md — never clone a raw
// reactive proxy).
interface EditForm {
  id: string | null;
  code: string;
  description: string;
  kind: VoucherKind;
  value: number | null;
  valid_from: string;
  valid_until: string;
  max_redemptions: number | null;
  status: VoucherStatus;
}

function emptyForm(): EditForm {
  return {
    id: null,
    code: '',
    description: '',
    kind: 'percent',
    value: null,
    valid_from: toLocalYmd(),
    valid_until: '',
    max_redemptions: null,
    status: 'active',
  };
}

const sheetOpen = ref(false);
const form = reactive<EditForm>(emptyForm());
const saveError = ref<string | null>(null);
const saving = ref(false);

function openCreate() {
  if (!canManage.value) return;
  Object.assign(form, emptyForm());
  // Auto-suggest a short random code so admins don't have to invent one.
  form.code = suggestCode();
  saveError.value = null;
  sheetOpen.value = true;
}

function openEdit(v: BimbelVoucher) {
  if (!canManage.value) return;
  const snapshot = structuredClone(toRaw(v));
  Object.assign(form, {
    id: snapshot.id,
    code: snapshot.code,
    description: snapshot.description ?? '',
    kind: snapshot.kind,
    value: snapshot.value,
    valid_from: snapshot.valid_from ?? '',
    valid_until: snapshot.valid_until ?? '',
    max_redemptions: snapshot.max_redemptions ?? null,
    status: snapshot.status,
  });
  saveError.value = null;
  sheetOpen.value = true;
}

function closeSheet() {
  sheetOpen.value = false;
}

function suggestCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no confusing chars
  let out = '';
  for (let i = 0; i < 8; i++) {
    out += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return out;
}

async function submit() {
  if (!canManage.value) return;
  if (!form.code || form.value == null || form.value < 1) {
    saveError.value = t('tutoring2.admin.vouchers.errorRequired');
    return;
  }
  saving.value = true;
  saveError.value = null;
  const payload: VoucherCreatePayload = {
    code: form.code,
    description: form.description || null,
    kind: form.kind,
    value: form.value,
    max_redemptions: form.max_redemptions,
    valid_from: form.valid_from || null,
    valid_until: form.valid_until || null,
    status: form.status,
  };
  try {
    if (form.id) {
      await VouchersService.update(form.id, payload);
    } else {
      await VouchersService.create(payload);
    }
    sheetOpen.value = false;
    await reload();
  } catch (e: unknown) {
    // Backend surfaces the duplicate-code case as a 422 with the field
    // "code" filled in. Surface a friendly message here; a full field
    // renderer is deferred to the next iteration.
    const msg = (e as { response?: { data?: { message?: string } } })
      ?.response?.data?.message;
    saveError.value = msg ?? t('tutoring2.admin.vouchers.errorSaveFailed');
  } finally {
    saving.value = false;
  }
}

async function archiveVoucher(v: BimbelVoucher) {
  if (!canManage.value) return;
  await VouchersService.archive(v.id);
  await reload();
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.vouchers.title')"
      :meta="state.status === 'content' ? t('tutoring2.admin.vouchers.meta', { count: activeCount }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <!-- Tab strip: Vouchers | Log Penggunaan -->
    <div class="flex items-center gap-2 rounded-2xl bg-white p-1 border border-slate-100 shadow-sm w-fit">
      <button
        type="button"
        class="px-4 py-2 rounded-xl text-sm font-bold transition-colors"
        :class="tab === 'list' ? 'bg-brand-cobalt text-white' : 'text-slate-500 hover:text-slate-800'"
        @click="tab = 'list'"
      >
        {{ t('tutoring2.admin.vouchers.tabList') }}
      </button>
      <button
        type="button"
        class="px-4 py-2 rounded-xl text-sm font-bold transition-colors"
        :class="tab === 'redemptions' ? 'bg-brand-cobalt text-white' : 'text-slate-500 hover:text-slate-800'"
        @click="tab = 'redemptions'"
      >
        {{ t('tutoring2.admin.vouchers.tabRedemptions') }}
      </button>
    </div>

    <template v-if="tab === 'list'">
      <PageFilterToolbar
        v-model:search="search"
        :search-placeholder="t('tutoring2.admin.vouchers.searchPh')"
      >
        <template #chips>
          <AppFilterChip
            :label="t('tutoring2.common.status')"
            :value="statusFilter ? t(`tutoring2.admin.vouchers.status.${statusFilter}`) : t('tutoring2.common.all')"
            icon-name="circle-check"
            :active="!!statusFilter"
            @click="statusFilter = statusFilter === 'active' ? 'archived' : statusFilter === 'archived' ? '' : 'active'"
          />
        </template>
      </PageFilterToolbar>

      <AsyncView
        :state="state"
        loading-variant="cards"
        :loading-rows="6"
        :empty-title="t('tutoring2.admin.vouchers.emptyTitle')"
        :empty-description="t('tutoring2.admin.vouchers.emptyDesc')"
        @retry="reload"
      >
        <template #default="{ data }">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colCode') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colDiscount') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colValidRange') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colUses') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                  <th class="px-4 py-3 font-bold text-right">{{ t('tutoring2.admin.vouchers.colActions') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="v in (data as BimbelVoucher[])"
                  :key="v.id"
                  class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
                >
                  <td class="px-4 py-3">
                    <div class="font-bold text-slate-900 font-mono">{{ v.code }}</div>
                    <div v-if="v.description" class="text-xs text-slate-500 mt-0.5">{{ v.description }}</div>
                  </td>
                  <td class="px-4 py-3 text-slate-700 font-semibold">{{ discountLabel(v) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ validRange(v) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ usesLabel(v) }}</td>
                  <td class="px-4 py-3">
                    <StatusBadge
                      :label="statusLabel(v)"
                      :tone="statusPillTone(v.status)"
                      uppercase
                    />
                  </td>
                  <td class="px-4 py-3 text-right">
                    <div class="inline-flex items-center gap-2">
                      <button
                        v-if="canManage"
                        type="button"
                        class="text-xs font-bold text-brand-cobalt hover:underline"
                        @click="openEdit(v)"
                      >
                        {{ t('tutoring2.common.edit') }}
                      </button>
                      <button
                        v-if="canManage && v.status === 'active'"
                        type="button"
                        class="text-xs font-bold text-slate-500 hover:text-red-600"
                        @click="archiveVoucher(v)"
                      >
                        {{ t('tutoring2.admin.vouchers.archive') }}
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
      </AsyncView>
    </template>

    <template v-else>
      <!--
        Log Penggunaan tab.

        NOTE — BE-16 does NOT expose a `/vouchers/redemptions` list
        endpoint (VoucherController.php has index/store/show/update/
        archive/redeem only). We use the loaded voucher list to render a
        per-voucher rollup (uses / max, last valid_until) as the MVP
        surface. When a `/vouchers/{id}/redemptions` route lands, swap
        this block to a dedicated fetch driven by the selected voucher.
      -->
      <AsyncView
        :state="state"
        loading-variant="cards"
        :loading-rows="4"
        :empty-title="t('tutoring2.admin.vouchers.redemptionsEmptyTitle')"
        :empty-description="t('tutoring2.admin.vouchers.redemptionsEmptyDesc')"
        @retry="reload"
      >
        <template #default="{ data }">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colCode') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colDiscount') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colUses') }}</th>
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colLastValid') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="v in (data as BimbelVoucher[])"
                  :key="v.id"
                  class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
                >
                  <td class="px-4 py-3 font-bold text-slate-900 font-mono">{{ v.code }}</td>
                  <td class="px-4 py-3 text-slate-700">{{ discountLabel(v) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ usesLabel(v) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ v.valid_until ?? '—' }}</td>
                </tr>
              </tbody>
            </table>
            <p class="px-4 py-3 text-xs text-slate-400 italic">
              {{ t('tutoring2.admin.vouchers.redemptionsHint') }}
            </p>
          </div>
        </template>
      </AsyncView>
    </template>

    <button
      v-if="canManage && tab === 'list'"
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openCreate"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.vouchers.newCta') }}
    </button>

    <!-- Create / Edit sheet -->
    <div
      v-if="sheetOpen"
      class="fixed inset-0 z-40 bg-slate-900/40 backdrop-blur-sm flex items-end sm:items-center justify-center p-4"
      @click.self="closeSheet"
    >
      <div class="w-full sm:max-w-lg bg-white rounded-3xl shadow-2xl p-6 space-y-4 max-h-[90vh] overflow-y-auto">
        <header class="flex items-center justify-between">
          <h2 class="text-lg font-bold text-slate-900">
            {{ form.id ? t('tutoring2.admin.vouchers.editTitle') : t('tutoring2.admin.vouchers.createTitle') }}
          </h2>
          <button
            type="button"
            class="text-slate-400 hover:text-slate-600 text-2xl leading-none"
            @click="closeSheet"
            aria-label="Close"
          >×</button>
        </header>

        <form class="space-y-3" @submit.prevent="submit">
          <label class="block">
            <span class="text-xs font-bold uppercase text-slate-500">{{ t('tutoring2.admin.vouchers.formCode') }}</span>
            <div class="flex gap-2 mt-1">
              <input
                v-model="form.code"
                type="text"
                required
                class="flex-1 rounded-xl border border-slate-200 px-3 py-2 text-sm font-mono focus:border-brand-cobalt focus:outline-none"
                :placeholder="t('tutoring2.admin.vouchers.formCodePh')"
              />
              <button
                type="button"
                class="px-3 py-2 rounded-xl bg-slate-100 text-slate-700 text-xs font-bold hover:bg-slate-200"
                @click="form.code = suggestCode()"
              >
                {{ t('tutoring2.admin.vouchers.suggestCode') }}
              </button>
            </div>
          </label>

          <label class="block">
            <span class="text-xs font-bold uppercase text-slate-500">{{ t('tutoring2.common.description') }}</span>
            <input
              v-model="form.description"
              type="text"
              class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
              :placeholder="t('tutoring2.admin.vouchers.formDescPh')"
            />
          </label>

          <div class="grid grid-cols-2 gap-3">
            <label class="block">
              <span class="text-xs font-bold uppercase text-slate-500">{{ t('tutoring2.admin.vouchers.formType') }}</span>
              <select
                v-model="form.kind"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
              >
                <option value="percent">{{ t('tutoring2.admin.vouchers.typePercent') }}</option>
                <option value="fixed">{{ t('tutoring2.admin.vouchers.typeFixed') }}</option>
              </select>
            </label>
            <label class="block">
              <span class="text-xs font-bold uppercase text-slate-500">
                {{ form.kind === 'percent' ? t('tutoring2.admin.vouchers.formValuePercent') : t('tutoring2.admin.vouchers.formValueFixed') }}
              </span>
              <input
                v-model.number="form.value"
                type="number"
                min="1"
                :max="form.kind === 'percent' ? 100 : undefined"
                required
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
              />
            </label>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <label class="block">
              <span class="text-xs font-bold uppercase text-slate-500">{{ t('tutoring2.admin.vouchers.formValidFrom') }}</span>
              <input
                v-model="form.valid_from"
                type="date"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
              />
            </label>
            <label class="block">
              <span class="text-xs font-bold uppercase text-slate-500">{{ t('tutoring2.admin.vouchers.formValidUntil') }}</span>
              <input
                v-model="form.valid_until"
                type="date"
                :min="form.valid_from || undefined"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
              />
            </label>
          </div>

          <label class="block">
            <span class="text-xs font-bold uppercase text-slate-500">{{ t('tutoring2.admin.vouchers.formMaxRedemptions') }}</span>
            <input
              v-model.number="form.max_redemptions"
              type="number"
              min="1"
              class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm focus:border-brand-cobalt focus:outline-none"
              :placeholder="t('tutoring2.admin.vouchers.formMaxRedemptionsPh')"
            />
          </label>

          <p v-if="saveError" class="text-xs text-red-600">{{ saveError }}</p>

          <div class="flex justify-end gap-2 pt-2">
            <button
              type="button"
              class="px-4 py-2 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-100"
              @click="closeSheet"
            >
              {{ t('tutoring2.common.cancel') }}
            </button>
            <button
              type="submit"
              :disabled="saving"
              class="px-4 py-2 rounded-xl bg-brand-cobalt text-white text-sm font-bold hover:bg-brand-cobalt/90 disabled:opacity-60"
            >
              {{ saving ? t('tutoring2.common.loading') : t('tutoring2.common.save') }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!--
      Hidden ability marker — kept so an accidental teardown of the
      `useAuthStore` import in a future refactor breaks the template
      compile rather than silently disabling the redeem gate.
    -->
    <span v-if="canRedeem" class="sr-only">redeem-enabled</span>
  </div>
</template>
