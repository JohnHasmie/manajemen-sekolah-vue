<!--
  ParentTutoring2VouchersView.vue — wali voucher wallet + redemption for
  one child (CLEAN-2 Phase 2 · greenfield replacement for the legacy
  `parent/tutoring/ParentVouchersView.vue`).

  Route: /parent/tutoring2/vouchers/:studentId
  Endpoints:
    GET  /tutoring-v2/vouchers                 — the tenant's vouchers
    GET  /tutoring-v2/enrollments?student_id=… — redemption target
    GET  /tutoring-v2/bills?student_id=…       — redemption target
    POST /tutoring-v2/vouchers/{id}/redeem     — apply to a bill

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. NO ARCHIVE. `VouchersService.archive` exists but it is an admin
     lifecycle action (AdminTutoring2VouchersView owns it, gated on
     `tutoring.voucher.manage`). Exposing it to a wali would let a
     parent retire a promo for the whole tenant. Not imported here.

  2. The field names changed. v1 had `type: PERCENTAGE|FIXED`, `value`,
     `max_uses`, `used_count`, `is_active`. BE-16 has
     `kind: percent|fixed`, `value`, `max_redemptions`,
     `redemption_count`, `status: active|archived`. The legacy
     "Gratis 1 sesi" special-case (kind=percent + value=100) is kept —
     it is a display nicety, not a backend concept.

  3. REDEMPTION IS NEW. The legacy screen was read-only: it listed codes
     and you quoted one at the desk. `POST /vouchers/{id}/redeem`
     requires BOTH an `enrollment_id` and a `bill_id`, and the backend
     re-checks that both belong to a child of the caller. That is why
     this view is child-scoped: `:studentId` selects whose enrollments
     and unpaid bills fill the redeem sheet.

  ⚠️ V2 ABILITY GAP (verified against PermissionCatalog::
     parentTutoringDefaults() + VoucherController):

     - GET  /tutoring-v2/vouchers        gates on `tutoring.voucher.view`
     - POST /tutoring-v2/vouchers/{id}/redeem gates on
                                         `tutoring.voucher.redeem`

     The wali default set holds `.redeem` but NOT `.view` — so a parent
     can redeem a voucher they cannot list. The legacy v1
     TutoringVoucherController had no `authorize()` call at all, which is
     why the old screen rendered for a parent.

     We do not paper over this: when `.view` is missing the list is not
     requested (a guaranteed 403) and the view explains why. Backend fix:
     add `tutoring.voucher.view` — or a scoped `_view_own` twin that
     returns only vouchers valid for the caller's children — to the wali
     defaults. Reported under V2_GAPS.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import SegmentedControl, {
  type SegmentOption,
} from '@/components/filters/SegmentedControl.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import Modal from '@/components/ui/Modal.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { toLocalYmd } from '@/lib/local-date';
import { useAuthStore } from '@/stores/auth';
import { VouchersService } from '@/services/tutoring2/vouchers';
import {
  TutoringBimbelService,
  type BimbelBill,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';
import type { BimbelVoucher, VoucherStatus } from '@/types/tutoring2/voucher';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const route = useRoute();
const toast = useToast();
const auth = useAuthStore();

/** Child scope — same mechanism as ParentTutoring2AttendanceView. */
const studentId = computed(() => String(route.params.studentId ?? ''));

// Gated on `/me` abilities (X-Active-Role-scoped), never on
// roles[].permission_keys.
const canViewVouchers = computed(() => auth.hasAbility('tutoring.voucher.view'));
const canRedeem = computed(() => auth.hasAbility('tutoring.voucher.redeem'));

// ── Data ──────────────────────────────────────────────────────────
interface VoucherBundle {
  vouchers: BimbelVoucher[];
  enrollments: BimbelEnrollment[];
  bills: BimbelBill[];
}

const { state, reload } = useDataRefresh<VoucherBundle>(async () => {
  const sid = studentId.value;
  // Fetch the full voucher set (no `status` filter) so the History tab
  // can be derived client-side — the BE index filters one status at a
  // time and we want both buckets in one round trip.
  const [vouchers, enrollments, bills] = await Promise.all([
    canViewVouchers.value
      ? VouchersService.list({ per_page: 100 }).then((r) => r.items)
      : Promise.resolve<BimbelVoucher[]>([]),
    sid
      ? TutoringBimbelService.listEnrollments({ student_id: sid, per_page: 50 }).then(
          (r) => r.items,
        )
      : Promise.resolve<BimbelEnrollment[]>([]),
    sid
      ? TutoringBimbelService.listBills({
          student_id: sid,
          status: 'unpaid',
          per_page: 50,
        }).then((r) => r.items)
      : Promise.resolve<BimbelBill[]>([]),
  ]);
  return { vouchers, enrollments, bills };
}, {
  // Enrollments and bills are context for redeeming; the page is ABOUT
  // vouchers, so no vouchers is empty even when the other two have rows.
  isEmpty: (d) => d.vouchers.length === 0,
});

const bundle = computed<VoucherBundle | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as VoucherBundle | undefined) ?? null)
    : null,
);

const vouchers = computed<BimbelVoucher[]>(() => bundle.value?.vouchers ?? []);
const enrollments = computed<BimbelEnrollment[]>(() => bundle.value?.enrollments ?? []);
const unpaidBills = computed<BimbelBill[]>(() => bundle.value?.bills ?? []);

const childName = computed<string | null>(
  () => enrollments.value.find((e) => e.student_name)?.student_name ?? null,
);

// ── Availability buckets ──────────────────────────────────────────
// `valid_from` / `valid_until` are YYYY-MM-DD calendar days, so we
// compare against a LOCAL ymd string — never `toISOString().slice(0,10)`,
// which is UTC and would call a voucher expired 7 hours early in WIB.
function isExpired(v: BimbelVoucher): boolean {
  return v.valid_until != null && v.valid_until < toLocalYmd();
}

function isNotYetValid(v: BimbelVoucher): boolean {
  return v.valid_from != null && v.valid_from > toLocalYmd();
}

function isQuotaUsedUp(v: BimbelVoucher): boolean {
  return v.max_redemptions != null && (v.redemption_count ?? 0) >= v.max_redemptions;
}

/** Usable right now: active, in-window, and with quota left. */
function isAvailable(v: BimbelVoucher): boolean {
  return (
    v.status === 'active' && !isExpired(v) && !isNotYetValid(v) && !isQuotaUsedUp(v)
  );
}

const availableVouchers = computed(() => vouchers.value.filter(isAvailable));
const historyVouchers = computed(() => vouchers.value.filter((v) => !isAvailable(v)));

/** Expiring within a week — drives the "segera berakhir" emphasis. */
const EXPIRING_SOON_DAYS = 7;
function isExpiringSoon(v: BimbelVoucher): boolean {
  if (!v.valid_until || !isAvailable(v)) return false;
  const limit = new Date();
  limit.setDate(limit.getDate() + EXPIRING_SOON_DAYS);
  return v.valid_until <= toLocalYmd(limit);
}

// ── Tabs ──────────────────────────────────────────────────────────
// Typed as a plain string because <SegmentedControl> emits `string`;
// narrowing it to a union here would make the v-model binding
// unassignable under strict mode.
const tab = ref<string>('available');

const tabOptions = computed<SegmentOption[]>(() => [
  {
    key: 'available',
    label: t('tutoring2.parent.vouchers.tabAvailable'),
    meta: String(availableVouchers.value.length),
  },
  {
    key: 'history',
    label: t('tutoring2.parent.vouchers.tabHistory'),
    meta: String(historyVouchers.value.length),
  },
]);

const visibleVouchers = computed<BimbelVoucher[]>(() =>
  tab.value === 'history' ? historyVouchers.value : availableVouchers.value,
);

// ── KPIs ──────────────────────────────────────────────────────────
const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'wallet',
    label: t('tutoring2.parent.vouchers.kpiAvailable'),
    value: String(availableVouchers.value.length),
    tone: 'brand',
  },
  {
    icon: 'clock',
    label: t('tutoring2.parent.vouchers.kpiExpiringSoon'),
    value: String(vouchers.value.filter(isExpiringSoon).length),
    tone: 'amber',
  },
  {
    icon: 'check-circle',
    label: t('tutoring2.parent.vouchers.kpiUsed'),
    value: String(
      vouchers.value.reduce((sum, v) => sum + (v.redemption_count ?? 0), 0),
    ),
    tone: 'green',
  },
  {
    icon: 'file-text',
    label: t('tutoring2.parent.vouchers.kpiOpenBills'),
    value: String(unpaidBills.value.length),
  },
]);

// ── Display helpers ───────────────────────────────────────────────
function rupiah(v: number): string {
  return `Rp ${v.toLocaleString('id-ID')}`;
}

function discountLabel(v: BimbelVoucher): string {
  if (v.kind === 'percent') {
    // Legacy nicety: a 100% voucher reads as "free", not "100%".
    return v.value === 100
      ? t('tutoring2.parent.vouchers.freeLabel')
      : `${v.value}%`;
  }
  return rupiah(v.value);
}

function validityLabel(v: BimbelVoucher): string {
  if (isExpired(v)) {
    return t('tutoring2.parent.vouchers.expiredOn', { date: v.valid_until });
  }
  if (isNotYetValid(v)) {
    return t('tutoring2.parent.vouchers.validFrom', { date: v.valid_from });
  }
  if (v.valid_until) {
    return t('tutoring2.parent.vouchers.validUntil', { date: v.valid_until });
  }
  return t('tutoring2.parent.vouchers.noExpiry');
}

function quotaLabel(v: BimbelVoucher): string {
  const used = v.redemption_count ?? 0;
  return v.max_redemptions == null
    ? t('tutoring2.parent.vouchers.quotaUnlimited', { used })
    : t('tutoring2.parent.vouchers.quotaLimited', {
        used,
        max: v.max_redemptions,
      });
}

function statusLabel(v: BimbelVoucher): string {
  if (v.status === 'active' && isExpired(v)) {
    return t('tutoring2.parent.vouchers.statusExpired');
  }
  if (v.status === 'active' && isQuotaUsedUp(v)) {
    return t('tutoring2.parent.vouchers.statusUsedUp');
  }
  return v.status_label ?? t(`tutoring2.status.${v.status}`);
}

/**
 * Voucher status → tone. Byte-identical to `statusPillTone` in
 * AdminTutoring2VouchersView (active → success, archived → neutral) so
 * one voucher never reads a different colour to a wali than to an admin.
 * If you change one, change both.
 *
 * Expiry/quota exhaustion is deliberately NOT re-toned here (the admin
 * view doesn't either) — it is conveyed by the label plus the dimmed
 * card treatment in the template.
 */
function statusTone(status: VoucherStatus): StatusBadgeTone {
  switch (status) {
    case 'active':
      return 'success';
    case 'archived':
      return 'neutral';
  }
}

// ── Redeem sheet ──────────────────────────────────────────────────
const redeemTarget = ref<BimbelVoucher | null>(null);
const redeemEnrollmentId = ref('');
const redeemBillId = ref('');
const redeemError = ref<string | null>(null);
const redeeming = ref(false);

const enrollmentOptions = computed<FormFieldOption[]>(() =>
  enrollments.value.map((e) => ({
    value: e.id,
    label: [e.program_name, e.learning_group_name].filter(Boolean).join(' · ')
      || `${t('tutoring2.common.program')} ${e.program_id.slice(0, 8)}`,
  })),
);

const billOptions = computed<FormFieldOption[]>(() =>
  unpaidBills.value.map((b) => ({
    value: b.id,
    label: `${b.payment_type_name ?? t('tutoring2.common.amount')} · ${rupiah(b.amount)}${
      b.due_date ? ` · ${b.due_date}` : ''
    }`,
  })),
);

const canSubmitRedeem = computed(
  () =>
    canRedeem.value &&
    Boolean(redeemTarget.value) &&
    Boolean(redeemEnrollmentId.value) &&
    Boolean(redeemBillId.value) &&
    !redeeming.value,
);

function openRedeem(v: BimbelVoucher) {
  if (!canRedeem.value) return;
  redeemTarget.value = v;
  // Pre-select when there is exactly one sensible target, which is the
  // common case for a single-program child.
  redeemEnrollmentId.value =
    enrollments.value.length === 1 ? (enrollments.value[0]?.id ?? '') : '';
  redeemBillId.value =
    unpaidBills.value.length === 1 ? (unpaidBills.value[0]?.id ?? '') : '';
  redeemError.value = null;
}

function closeRedeem() {
  redeemTarget.value = null;
  redeemError.value = null;
}

async function submitRedeem() {
  const voucher = redeemTarget.value;
  if (!voucher || !canSubmitRedeem.value) return;
  redeeming.value = true;
  redeemError.value = null;
  try {
    await VouchersService.redeem(voucher.id, {
      enrollment_id: redeemEnrollmentId.value,
      bill_id: redeemBillId.value,
    });
    closeRedeem();
    toast.success(t('tutoring2.parent.vouchers.redeemSuccess'));
    await reload();
  } catch (e: unknown) {
    const err = e as { response?: { status?: number; data?: { message?: string } } };
    // The backend returns a specific 403 message when the enrollment or
    // bill does not belong to one of the caller's children — surface it
    // verbatim rather than a generic failure.
    redeemError.value =
      err?.response?.data?.message ?? t('tutoring2.parent.vouchers.redeemFailed');
  } finally {
    redeeming.value = false;
  }
}

const metaLabel = computed(() => {
  if (state.value.status === 'loading') return t('tutoring2.common.loading');
  return t('tutoring2.parent.vouchers.meta', {
    child: childName.value ?? t('tutoring2.common.student'),
    count: availableVouchers.value.length,
  });
});
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.vouchers.title')"
      :meta="metaLabel"
    />

    <!--
      Ability wall — see the header block. Without `tutoring.voucher.view`
      the list request is a guaranteed 403, so we never fire it.
    -->
    <div
      v-if="!canViewVouchers"
      class="rounded-3xl border border-slate-100 bg-white p-6 text-center shadow-sm"
    >
      <p class="text-sm font-bold text-slate-900">
        {{ t('tutoring2.parent.vouchers.noPermissionTitle') }}
      </p>
      <p class="mt-2 text-2xs text-slate-500">
        {{ t('tutoring2.parent.vouchers.noPermissionDesc') }}
      </p>
    </div>

    <template v-else>
      <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

      <SegmentedControl v-model="tab" :options="tabOptions" />

      <AsyncView
        :state="state"
        loading-variant="cards"
        :loading-rows="4"
        :empty-title="t('tutoring2.parent.vouchers.emptyTitle')"
        :empty-description="t('tutoring2.parent.vouchers.emptyDesc')"
        @retry="reload"
      >
        <template #default>
          <div class="grid gap-3 sm:grid-cols-2">
            <article
              v-for="v in visibleVouchers"
              :key="v.id"
              class="rounded-3xl border bg-white p-4 shadow-sm"
              :class="[
                isAvailable(v)
                  ? 'border-slate-100'
                  : 'border-slate-100 opacity-60',
                isExpiringSoon(v) ? 'ring-1 ring-amber-400' : '',
              ]"
            >
              <div class="flex items-start justify-between gap-3">
                <p class="text-2xl font-black leading-none text-slate-900">
                  {{ discountLabel(v) }}
                </p>
                <StatusBadge
                  :label="statusLabel(v)"
                  :tone="statusTone(v.status)"
                  uppercase
                />
              </div>

              <p class="mt-2 text-2xs text-slate-500">
                {{ v.description || t('tutoring2.parent.vouchers.defaultDescription') }}
              </p>

              <p
                class="mt-3 inline-block rounded-lg bg-slate-100 px-2 py-1 font-mono text-xs tracking-wider text-slate-700"
              >
                {{ v.code }}
              </p>

              <p
                class="mt-2 text-2xs"
                :class="isExpiringSoon(v) ? 'font-semibold text-amber-700' : 'text-slate-400'"
              >
                {{ validityLabel(v) }}
                <span class="mx-1 text-slate-300">·</span>
                {{ quotaLabel(v) }}
              </p>

              <div v-if="canRedeem && isAvailable(v)" class="mt-3">
                <Button variant="primary" size="sm" @click="openRedeem(v)">
                  {{ t('tutoring2.parent.vouchers.redeemCta') }}
                </Button>
              </div>
            </article>

            <!--
              The two tabs split one fetch, so AsyncView's empty branch
              only fires when BOTH buckets are empty.
            -->
            <p
              v-if="visibleVouchers.length === 0"
              class="col-span-full rounded-3xl border border-slate-100 bg-white px-4 py-8 text-center text-sm text-slate-500 shadow-sm"
            >
              {{
                tab === 'history'
                  ? t('tutoring2.parent.vouchers.historyEmpty')
                  : t('tutoring2.parent.vouchers.availableEmpty')
              }}
            </p>
          </div>
        </template>
      </AsyncView>
    </template>

    <!-- Redeem sheet -->
    <Modal
      v-if="redeemTarget"
      :title="t('tutoring2.parent.vouchers.redeemTitle')"
      :subtitle="redeemTarget?.code"
      size="md"
      testid="voucher-redeem-modal"
      @close="closeRedeem"
    >
      <div class="space-y-3">
        <p class="text-2xs text-slate-500">
          {{ t('tutoring2.parent.vouchers.redeemHint') }}
        </p>

        <FormField
          v-model="redeemEnrollmentId"
          field="enrollment_id"
          type="select"
          required
          :label="t('tutoring2.parent.vouchers.redeemEnrollmentLabel')"
          :options="enrollmentOptions"
          :select-placeholder="t('tutoring2.parent.vouchers.redeemEnrollmentPh')"
        />
        <p v-if="enrollmentOptions.length === 0" class="text-xs text-slate-500">
          {{ t('tutoring2.parent.vouchers.noEnrollments') }}
        </p>

        <FormField
          v-model="redeemBillId"
          field="bill_id"
          type="select"
          required
          :label="t('tutoring2.parent.vouchers.redeemBillLabel')"
          :options="billOptions"
          :select-placeholder="t('tutoring2.parent.vouchers.redeemBillPh')"
        />
        <p v-if="billOptions.length === 0" class="text-xs text-slate-500">
          {{ t('tutoring2.parent.vouchers.noOpenBills') }}
        </p>

        <p v-if="redeemError" class="text-xs text-status-danger">{{ redeemError }}</p>

        <div class="flex justify-end gap-2 pt-1">
          <Button variant="ghost" size="sm" @click="closeRedeem">
            {{ t('tutoring2.common.cancel') }}
          </Button>
          <Button
            variant="primary"
            size="sm"
            :disabled="!canSubmitRedeem"
            :loading="redeeming"
            @click="submitRedeem"
          >
            {{ t('tutoring2.parent.vouchers.redeemConfirm') }}
          </Button>
        </div>
      </div>
    </Modal>
  </div>
</template>
