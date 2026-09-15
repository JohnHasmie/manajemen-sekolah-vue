<!--
  AdminTutoring2VouchersView.vue — greenfield "Voucher & Kode Promo" list
  for BE-16. Mirrors AdminTutoring2ProgramsView.vue in structure:
    - BrandPageHeader (admin)
    - KpiStripCards (aktif / kadaluarsa / terpakai bulan ini / sisa kuota)
    - PageFilterToolbar + AppFilterChip for status
    - AsyncView + table of vouchers
    - FAB → create voucher (ability-gated)
    - Segmented control tabs: "Vouchers" | "Log Penggunaan"

  Ability gates via `useMe().can(...)` — the `abilities` array from
  `GET /me`, which is SCOPED BY THE ACTIVE ROLE (`X-Active-Role`). Never
  `roles[].permission_keys`, which is unscoped and exists only to feed
  the role switcher. The sibling tutoring2 admin views (GroupDetail,
  Schedule, PayoutRequests, …) all read the same composable.
  Route-guard `needs: 'tutoring-module' + ability: tutoring.voucher.view`
  is set in the router.

  ── RECIPIENT TARGETING ─────────────────────────────────────────────

  A voucher used to be a code plus a quota and NO OWNER, which is why
  wali were never shown a voucher list at all. It can now name STUDENTS
  (not users — redemption is per-student via `enrollment_id`, so aiming
  at an account would sit coarser than the guard enforcing it).

  Two consequences on this screen:

    · A "Penerima" column, because a general promo and a personal one
      are handed out differently and an admin who cannot tell them apart
      gives out the wrong code. Rendered off `is_targeted` /
      `recipient_count`, both `isset`-gated server-side, so ABSENT is
      kept distinct from a real 0 — see `@/lib/absent-vs-zero`.
    · The cell is the control: clicking it opens
      AdminTutoring2VoucherRecipientsSheet. It lives there rather than in
      the Aksi cell because the read and the writes authorize DIFFERENT
      keys — `tutoring.voucher.view` opens the panel, and only
      `tutoring.voucher.manage` gets the add/remove controls inside it.
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
import MoneyInput from '@/components/ui/MoneyInput.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { countOrDash, EM_DASH, isCounted } from '@/lib/absent-vs-zero';
import { toLocalYmd } from '@/lib/local-date';
import AdminTutoring2VoucherRecipientsSheet from './AdminTutoring2VoucherRecipientsSheet.vue';
import { VouchersService } from '@/services/tutoring2/vouchers';
import { VOUCHER_STATUS } from '@/types/tutoring2/voucher';
import type {
  BimbelVoucher,
  VoucherCreatePayload,
  VoucherKind,
  VoucherStatus,
} from '@/types/tutoring2/voucher';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const { can } = useMe();

/**
 * One gate per ENDPOINT, not one gate per screen.
 *
 * `VoucherController` authorizes four different keys and they are not a
 * strict/relaxed family:
 *
 *   tutoring.voucher.view     → index / show / recipients (the READ of
 *                               who a promo is aimed at)
 *   tutoring.voucher.manage   → store / update / archive / attach /
 *                               detach recipients
 *   tutoring.voucher.redeem   → redeem
 *   tutoring.voucher.view_own → the WALI list (`/vouchers/my`) — never
 *                               this screen, and deliberately not a
 *                               filtered version of it
 *
 * `canViewRecipients` is therefore `.view` and not `.manage`: read-only
 * staff are entitled to see who holds a promo, they simply cannot change
 * it. Collapsing the pair would hide a list they are allowed to read.
 */
const canManage = computed(() => can('tutoring.voucher.manage'));
const canRedeem = computed(() => can('tutoring.voucher.redeem'));
const canViewRecipients = computed(() => can('tutoring.voucher.view'));

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

/**
 * The screen's glyph for "no cap". Used both per-row (`usesLabel`) and
 * by the "Sisa kuota" tile, so an admin reads the same mark for the same
 * fact in both places. Deliberately NOT `EM_DASH`: "unlimited" and "not
 * reported" are different answers and must not share a symbol.
 */
const UNLIMITED = '∞';

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
  // `VoucherController::index` never eager-loads `redemptions`, so
  // `VoucherResource`'s `whenLoaded` drops `redemption_count` from every
  // row on this screen. `?? 0` turned that silence into "nobody redeemed
  // anything": the usage tile read 0 forever and the quota tile reported
  // every voucher as untouched. Count only the vouchers that answered,
  // and say "—" when none did.
  const redemptionCounts = items.flatMap((v) =>
    isCounted(v.redemption_count) ? [v.redemption_count] : [],
  );
  // An EMPTY list has a real answer: nothing has been redeemed, so 0.
  // "—" is reserved for a non-empty list that told us nothing — the
  // over-correction of rendering "—" for a knowable zero is the same
  // conflation as `?? 0`, just pointing the other way.
  const used =
    items.length === 0
      ? 0
      : redemptionCounts.length === 0
        ? null
        : redemptionCounts.reduce((sum, n) => sum + n, 0);
  const usedPartialSuffix =
    redemptionCounts.length > 0 && redemptionCounts.length < items.length
      ? t('tutoring2.admin.vouchers.kpiCountedSuffix', {
          count: redemptionCounts.length,
        })
      : undefined;

  // ── Remaining quota ─────────────────────────────────────────────
  // Only CAPPED vouchers have a quota to have any of left, so they are
  // the population for this tile — and they separate three facts a
  // single number cannot carry:
  //
  //   • no vouchers at all       → 0. Nothing is on offer.
  //   • vouchers, none capped    → ∞. Every code is uncapped, so the
  //                                remaining quota is unlimited. This is
  //                                KNOWN, and rendering "—" for it was
  //                                the same two-facts-merged error in a
  //                                third direction: "no cap exists"
  //                                reported as "the server didn't say".
  //                                `∞` is already this screen's glyph
  //                                for an absent cap (see `usesLabel`).
  //   • capped, none counted     → "—". Genuinely unknown: we know the
  //                                caps but not how much is spent.
  const capped = items.filter(
    (v): v is BimbelVoucher & { max_redemptions: number } => v.max_redemptions != null,
  );
  // Project to the remaining-seats numbers themselves rather than
  // filtering and asserting later — `isCounted` is a type guard, so this
  // arithmetic needs no `!`.
  const cappedRemaining = capped.flatMap((v) =>
    isCounted(v.redemption_count)
      ? [Math.max(0, v.max_redemptions - v.redemption_count)]
      : [],
  );
  const remainingQuota: number | null | typeof UNLIMITED =
    items.length === 0
      ? 0
      : capped.length === 0
        ? UNLIMITED
        : cappedRemaining.length === 0
          ? null
          : cappedRemaining.reduce((sum, n) => sum + n, 0);
  const quotaPartialSuffix =
    cappedRemaining.length > 0 && cappedRemaining.length < capped.length
      ? t('tutoring2.admin.vouchers.kpiCountedSuffix', {
          count: cappedRemaining.length,
        })
      : undefined;
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
      value: used == null ? EM_DASH : String(used),
      suffix: usedPartialSuffix,
    },
    {
      icon: 'wallet',
      label: t('tutoring2.admin.vouchers.kpiRemainingQuota'),
      value:
        remainingQuota == null
          ? EM_DASH
          : remainingQuota === UNLIMITED
            ? UNLIMITED
            : String(remainingQuota),
      suffix: quotaPartialSuffix,
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
  // "—" while the list withholds the count; a redeemed-zero voucher
  // still reads "0 / 50".
  const used = countOrDash(v.redemption_count);
  const max = v.max_redemptions;
  return max == null ? `${used} / ${UNLIMITED}` : `${used} / ${max}`;
}

// ─── General vs personal ──────────────────────────────────────────
//
// The whole point of recipient targeting: a code shown as an ordinary
// promo but silently redeemable by only three students would be a
// control that lies, and so would the reverse.

/**
 * True when this row is a PERSONAL voucher — someone was explicitly
 * named on it.
 *
 * Branches on the server-DERIVED `is_targeted` and falls back to the
 * count it is derived from. They cannot disagree (`VoucherResource`
 * computes the flag from the number in the same `isset` gate), so the
 * fallback exists only for a payload that carried one and not the other.
 * `null` means the server said nothing at all — see `recipientsLabel`.
 */
function isTargeted(v: BimbelVoucher): boolean | null {
  if (typeof v.is_targeted === 'boolean') return v.is_targeted;
  if (isCounted(v.recipient_count)) return v.recipient_count > 0;
  return null;
}

/**
 * ABSENT IS NOT "UMUM" here, and that is the trap this helper exists to
 * avoid. A voucher whose payload carries no `recipient_count` has NOT
 * told us it is a general promo — labelling it one would invite an admin
 * to circulate a code that may in fact be reserved for three families.
 * An em-dash says "unknown"; only a real, reported 0 says "umum".
 */
function recipientsLabel(v: BimbelVoucher): string {
  const targeted = isTargeted(v);
  if (targeted === null) return EM_DASH;
  if (!targeted) return t('tutoring2.admin.vouchers.recipientsGeneral');
  return t('tutoring2.admin.vouchers.recipientsPersonal', {
    count: v.recipient_count ?? 0,
  });
}

function recipientsTone(v: BimbelVoucher): string {
  const targeted = isTargeted(v);
  if (targeted === null) return 'bg-slate-50 text-slate-400';
  return targeted
    ? 'bg-brand-cobalt/10 text-brand-cobalt'
    : 'bg-slate-100 text-slate-600';
}

// ─── Recipient sheet ──────────────────────────────────────────────

/** The voucher whose recipients are open; `null` = sheet closed. */
const recipientsTarget = ref<BimbelVoucher | null>(null);

function openRecipients(v: BimbelVoucher) {
  // Gated on the key `VoucherController::recipients` itself authorizes,
  // not on `.manage` — a read-only viewer may open this panel.
  if (!canViewRecipients.value) return;
  recipientsTarget.value = v;
}

function closeRecipients() {
  recipientsTarget.value = null;
}

/**
 * An attach or detach just landed, so `recipient_count` / `is_targeted`
 * on EVERY row of the loaded page is now potentially stale — the sheet
 * hands back one refreshed voucher, but splicing a single row into
 * `useDataRefresh`'s state would leave the KPI strip computing over a
 * mixture of pre- and post-write numbers. Reload the page instead: an
 * admin write is rare, and a list that cannot be trusted is worse than
 * one extra request.
 */
async function onRecipientsChanged() {
  await reload();
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

/**
 * Error surface for the row-level status toggle (Arsipkan / Aktifkan
 * kembali).
 *
 * It cannot be `saveError`: that one renders *inside* the Ubah sheet,
 * and the sheet is closed when an admin presses a row button — the
 * message would land in a panel nobody is looking at. So this reuses
 * `submit()`'s idiom (catch → prefer the backend `message` → fall back
 * to a translated sentence) and gives it a home the admin can actually
 * see, above the table.
 */
const rowActionError = ref<string | null>(null);

/**
 * The unwrap `submit()` has always done, lifted out so all three write
 * paths read a 403/422/500 the same way. Axios puts the backend body on
 * `error.response.data`; anything else (a network drop, a thrown
 * non-error) yields `undefined` and the caller's fallback wins.
 */
function backendMessage(e: unknown): string | undefined {
  return (e as { response?: { data?: { message?: string } } })?.response?.data
    ?.message;
}

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
    saveError.value =
      backendMessage(e) ?? t('tutoring2.admin.vouchers.errorSaveFailed');
  } finally {
    saving.value = false;
  }
}

/**
 * ─── Why both halves carry a catch ───────────────────────────────────
 *
 * `archiveVoucher` shipped as a bare `await` with nothing around it, and
 * `unarchiveVoucher` was written to mirror it exactly rather than
 * quietly upgrading one side of a two-way toggle. That symmetry was the
 * right instinct and the wrong resting place: an unhandled rejection
 * skips `reload()`, so a 403 (ability revoked between page load and
 * click), a 422, or a 500 produced a button that did nothing and said
 * nothing — the row kept its old status and the admin had no way to
 * tell a refused write from a slow one.
 *
 * Both now surface into `rowActionError` and both `return` before
 * `reload()`, so a failed write never leaves the screen looking like it
 * succeeded. Keep them symmetric: whatever one does, the other does.
 */
async function archiveVoucher(v: BimbelVoucher) {
  if (!canManage.value) return;
  rowActionError.value = null;
  try {
    await VouchersService.archive(v.id);
  } catch (e: unknown) {
    rowActionError.value =
      backendMessage(e) ?? t('tutoring2.admin.vouchers.errorArchiveFailed');
    return;
  }
  await reload();
}

/**
 * The counterpart to `archiveVoucher` — archiving shipped with no way
 * back, so an archived voucher was a one-way door on this screen even
 * though the backend has always accepted the reverse.
 *
 * There is no `/vouchers/{id}/unarchive` route; the flip goes through
 * the ordinary update endpoint, whose `UpdateVoucherRequest` validates
 * `status` against the backend `VoucherStatus` enum and whose
 * `UpdateVoucherAction` writes it in its key-by-key loop. So this is a
 * one-field PUT, not a new endpoint.
 *
 * Deliberately mirrors `archiveVoucher` beat for beat — same manage
 * gate, no confirm step, same `reload()` afterwards — so the two halves
 * of one toggle cannot drift apart.
 */
async function unarchiveVoucher(v: BimbelVoucher) {
  if (!canManage.value) return;
  rowActionError.value = null;
  try {
    await VouchersService.update(v.id, { status: VOUCHER_STATUS.active });
  } catch (e: unknown) {
    rowActionError.value =
      backendMessage(e) ?? t('tutoring2.admin.vouchers.errorUnarchiveFailed');
    return;
  }
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

      <!--
        Row-action failures land here rather than in the Ubah sheet: the
        sheet is closed when Arsipkan / Aktifkan kembali are pressed, so
        `saveError`'s slot would never be on screen at that moment.
      -->
      <p
        v-if="rowActionError"
        data-testid="row-action-error"
        role="alert"
        class="mb-3 rounded-xl bg-red-50 px-3 py-2 text-xs font-semibold text-red-600"
      >
        {{ rowActionError }}
      </p>

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
                  <!-- Inserted AFTER "Terpakai" on purpose: the sibling
                       spec addresses cells positionally, and appending
                       here leaves the earlier indices untouched. -->
                  <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.vouchers.colRecipients') }}</th>
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
                  <!--
                    The cell IS the control. Kept out of the Aksi cell
                    because opening it needs only `tutoring.voucher.view`
                    — the same key that let the admin onto this screen —
                    while everything in that cell needs `.manage`.
                  -->
                  <td class="px-4 py-3">
                    <button
                      v-if="canViewRecipients"
                      type="button"
                      data-testid="recipients-cell-button"
                      :title="t('tutoring2.admin.vouchers.recipientsManage')"
                      class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold transition-opacity hover:opacity-80"
                      :class="recipientsTone(v)"
                      @click="openRecipients(v)"
                    >
                      {{ recipientsLabel(v) }}
                    </button>
                    <span
                      v-else
                      data-testid="recipients-cell-static"
                      class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
                      :class="recipientsTone(v)"
                    >
                      {{ recipientsLabel(v) }}
                    </span>
                  </td>
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
                      <!--
                        Mutually exclusive with Arsipkan above: the row
                        always offers exactly one direction of the
                        toggle. The status literals are checked against
                        the `VoucherStatus` union, so a renamed case is
                        a compile error here rather than a button that
                        never appears.
                      -->
                      <button
                        v-if="canManage && v.status === 'archived'"
                        type="button"
                        class="text-xs font-bold text-slate-500 hover:text-emerald-600"
                        @click="unarchiveVoucher(v)"
                      >
                        {{ t('tutoring2.admin.vouchers.unarchive') }}
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
              <!-- One control, two meanings: a `fixed` voucher is a
                   rupiah amount and gets the thousand separators, a
                   `percent` one is a 1-100 share and must not. -->
              <MoneyInput
                v-model="form.value"
                :grouping="form.kind === 'fixed'"
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
      Recipient targeting. Mounted at the ROOT of the view, never inside
      the create/edit sheet: `FormSheet` IS a `Modal`, so a second one
      nested in it would stack two `Teleport to="body"` overlays at the
      same z-index with two ESC handlers. Only one of the two can be
      open at a time here, so nothing stacks.
    -->
    <AdminTutoring2VoucherRecipientsSheet
      v-if="recipientsTarget"
      :voucher="recipientsTarget"
      :can-manage="canManage"
      @close="closeRecipients"
      @changed="onRecipientsChanged"
    />

    <!--
      Hidden ability marker — kept so an accidental teardown of the
      `useMe` import in a future refactor breaks the template compile
      rather than silently disabling the redeem gate.
    -->
    <span v-if="canRedeem" class="sr-only">redeem-enabled</span>
  </div>
</template>
