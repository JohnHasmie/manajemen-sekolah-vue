<!--
  AdminTutoring2PayoutRatesView.vue — WEB-16 (BE-24 rates).

  Admin view: honorarium catalogue per tutor. One row per rate; a
  tutor's LIVE rate is the highest `effective_from ≤ today` where
  `effective_until` is null OR future-dated. "Akhiri rate" stamps
  today's date on `effective_until` (POST /rates/{id}/end) so the row
  drops out of the LIVE set without deleting historical rows — payout
  history keeps referencing the exact rate that was in force at the
  time (see PayoutRateKind::PerSession semantics).

  All writes gate on `tutoring.payout.rates.manage`; reads gate on
  `tutoring.payout.view_all`. The controller also enforces these but
  hiding the FAB / disable actions in the UI keeps the affordance
  honest for non-admin managers.

  ── The tutor field ──

  "Tambah rate" picks its tutor from a NAME list. It used to be a free
  text input whose placeholder read "UUID tutor (BE-1x sedang menyiapkan
  picker)" — a required field that asked an admin to paste a UUID, on a
  form they cannot submit without it. The picker it was waiting for
  arrived long ago; `TutoringTutorsService.list` is the same source the
  Kelompok Belajar and Pengajuan Payout filters use.

  Deliberately a <FormField type="select"> and NOT the
  <FilterFacetPickerModal> the filter chips use: FormSheet IS a Modal, so
  a second Modal on top would stack two `Teleport to="body"` overlays at
  the same z-50 with two ESC handlers, and no screen in the repo does
  that. `type="select"` is what the Jenis field two rows down already
  does, so this stays the thin fit FormField was extracted for.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { extractError } from '@/lib/api-error';
import { toLocalYmd } from '@/lib/local-date';
import { useMoneyModel } from '@/composables/useMoneyModel';
import { PayoutsService } from '@/services/tutoring2/payouts';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { StatusBadgeTone } from '@/types/status-badge';
import type {
  PayoutRate,
  PayoutRateKind,
  UpsertPayoutRatePayload,
} from '@/types/tutoring2/payout';
import { PAYOUT_RATE_KINDS } from '@/types/tutoring2/payout';
import type { Tutor } from '@/types/tutoring2/tutor';

const { t } = useI18n();
const toast = useToast();
const { can } = useMe();

const canManage = computed(() => can('tutoring.payout.rates.manage'));

// ─── Filters ────────────────────────────────────────────────────────

const search = ref('');
const kindFilter = ref<string>(''); // '' | PayoutRateKind
const activeOnly = ref(false);

const { state, reload } = useDataRefresh(async () => {
  const { items } = await PayoutsService.listRates({
    per_page: 100,
    active_only: activeOnly.value || undefined,
  });
  return items;
});
watch([kindFilter, activeOnly], () => reload());

// ─── Tutor options for the rate sheet ───────────────────────────────

const tutors = ref<Tutor[]>([]);

/**
 * The sheet's tutor dropdown, by NAME.
 *
 * Inactive tutors stay in the list — a rate can legitimately be recorded
 * for someone deactivated after the period it covers — but they are
 * LABELLED so nobody attaches a fresh rate to a departed tutor by
 * accident. `active` is deliberately not forwarded to the service: the
 * Kelompok Belajar and Pengajuan Payout pickers ask for both too, and
 * silently hiding a tutor an admin is looking for is the same class of
 * problem as showing them a UUID.
 */
const tutorOptions = computed<FormFieldOption[]>(() =>
  tutors.value.map((tu) => ({
    value: tu.id,
    label: tu.is_active
      ? tu.name
      : `${tu.name} (${t('tutoring2.admin.tutors.statusInactive')})`,
  })),
);

/**
 * Load the tutor list once, tolerantly. Reads on this screen gate on
 * `tutoring.payout.view_all` while the tutor list gates on its own
 * ability, so the two really can diverge — a rejection here must leave a
 * disabled field that SAYS why, not a silently empty dropdown and not an
 * unhandled rejection that takes the rate table down with it.
 */
async function loadTutorOptions() {
  const [res] = await Promise.allSettled([
    TutoringTutorsService.list({ per_page: 200 }),
  ]);
  if (res.status === 'fulfilled') tutors.value = res.value.items;
}

onMounted(loadTutorOptions);

const filteredRates = computed<PayoutRate[]>(() => {
  const rates = state.value.status === 'content' ? (state.value.data as PayoutRate[]) : [];
  const q = search.value.trim().toLowerCase();
  return rates.filter((r) => {
    if (kindFilter.value && r.kind !== kindFilter.value) return false;
    if (q && !(r.tutor_name ?? r.tutor_id).toLowerCase().includes(q)) return false;
    return true;
  });
});

// A rate is "live" if effective_from ≤ today and effective_until is
// null or strictly future — matches the backend's LIVE set logic on
// PayoutRate::pickForSession.
function isRateLive(r: PayoutRate): boolean {
  const today = toLocalYmd();
  if (r.effective_from > today) return false;
  if (r.effective_until && r.effective_until <= today) return false;
  return true;
}

// ─── KPI ────────────────────────────────────────────────────────────

const kpiCards = computed<KpiCard[]>(() => {
  const rows = filteredRates.value;
  const live = rows.filter(isRateLive).length;
  const perSession = rows.filter((r) => r.kind === 'per_session').length;
  const monthly = rows.filter((r) => r.kind === 'monthly_salary').length;
  return [
    { icon: 'wallet', label: t('tutoring2.admin.payoutRates.kpiLive'), value: String(live) },
    { icon: 'calendar-check', label: t('tutoring2.admin.payoutRates.kpiPerSession'), value: String(perSession) },
    { icon: 'file-text', label: t('tutoring2.admin.payoutRates.kpiMonthly'), value: String(monthly) },
    { icon: 'clock', label: t('tutoring2.admin.payoutRates.kpiTotal'), value: String(rows.length), tone: 'slate' },
  ];
});

// ─── Row detail ─────────────────────────────────────────────────────

/**
 * Expanding a row costs no request: `notes`, `created_at` and
 * `updated_at` already ride along on the LIST response (RateResource
 * ships all three) and are already typed on PayoutRate — the table just
 * never had a surface for them. There is no GET /payouts/rates/{id} to
 * route to, so this mirrors the expandable row on Pengajuan Payout
 * rather than inventing a second detail idiom.
 */
const expandedId = ref<string | null>(null);
function toggleExpand(id: string) {
  expandedId.value = expandedId.value === id ? null : id;
}

// ─── Sheet + confirm state ──────────────────────────────────────────

const showSheet = ref(false);
const isSaving = ref(false);
const form = ref<UpsertPayoutRatePayload>({
  tutor_id: '',
  kind: 'per_session',
  value: 0,
  effective_from: toLocalYmd(),
  effective_until: null,
  notes: '',
});
const formError = ref<string | null>(null);

/**
 * `null` = the sheet is creating a rate; a rate id = it is editing that
 * row. Only used to drive the title and to LOCK the three key fields —
 * the id itself is never sent, because the write is an upsert (see
 * openEditSheet).
 */
const editingId = ref<string | null>(null);
const isEditing = computed(() => editingId.value !== null);

function openNewSheet() {
  form.value = {
    tutor_id: '',
    kind: 'per_session',
    value: 0,
    effective_from: toLocalYmd(),
    effective_until: null,
    notes: '',
  };
  editingId.value = null;
  formError.value = null;
  showSheet.value = true;
}

/**
 * Open the SAME sheet, prefilled from an existing row.
 *
 * No new endpoint is involved. POST /payouts/rates is an upsert whose
 * dedup key is (school_id, tutor_id, kind, effective_from) —
 * UpsertPayoutRateAction runs updateOrCreate on exactly that tuple, with
 * a partial unique index behind it. So re-submitting a row whose three
 * key fields are untouched UPDATES it, and `submitSheet` needs no branch
 * at all. Editing was already reachable end-to-end; the only thing
 * missing was a button that filled the form in for you, which left an
 * admin re-typing the tutor, jenis and start date from memory until the
 * tuple happened to match.
 *
 * That is also exactly why the template disables those three fields in
 * edit mode: change any one of them and updateOrCreate stops matching
 * the original row and silently CREATES a second rate while the first
 * stays live — a forked honorarium history, the precise failure the
 * versioning design exists to prevent.
 *
 * Deliberately NOT gated on isRateLive. Fixing a mistyped value on a
 * future-dated rate is the case with no control at all today: "Akhiri"
 * is live-only, and there is no delete route.
 */
function openEditSheet(r: PayoutRate) {
  form.value = {
    tutor_id: r.tutor_id,
    kind: r.kind,
    value: r.value,
    effective_from: r.effective_from,
    effective_until: r.effective_until,
    notes: r.notes ?? '',
  };
  editingId.value = r.id;
  formError.value = null;
  showSheet.value = true;
}

/**
 * An empty "Berakhir" means OPEN ENDED, and has to stay distinguishable
 * from a real date all the way to the wire.
 *
 * `<input type="date">` — like the text box before it — reports a
 * cleared field as `''`, so binding it straight into the payload posts
 * `effective_until: ''`. That is not the same request as omitting it:
 * it leans on Laravel's ConvertEmptyStringsToNull middleware to mean
 * "no end date", and the day anything strips or reorders that
 * middleware, `''` starts failing the `date` rule — or worse, lands as
 * a non-null end stamp. A rate with a wrongly-stamped `effective_until`
 * drops out of the LIVE set silently: no error, the tutor simply stops
 * being paid at that rate.
 *
 * So normalise here, at the one place the payload is built.
 */
function normalizeOpenEnded(v: string | null | undefined): string | null {
  const s = (v ?? '').trim();
  return s === '' ? null : s;
}

async function submitSheet() {
  formError.value = null;
  if (!form.value.tutor_id || form.value.value <= 0) {
    formError.value = t('tutoring2.admin.payoutRates.errFill');
    return;
  }
  if (form.value.kind === 'percent_revenue' && form.value.value > 100) {
    formError.value = t('tutoring2.admin.payoutRates.errPercentBounds');
    return;
  }
  const effectiveUntil = normalizeOpenEnded(form.value.effective_until);
  // The `min` attribute greys out earlier days in the picker but does
  // not stop a TYPED one, and the backend answers that with a 422 whose
  // wording an admin has to decode. Say it here instead. Equal dates are
  // fine — `after_or_equal` — a one-day rate is legitimate.
  if (effectiveUntil && effectiveUntil < form.value.effective_from) {
    formError.value = t('tutoring2.admin.payoutRates.errUntilBeforeFrom');
    return;
  }
  isSaving.value = true;
  try {
    await PayoutsService.upsertRate({ ...form.value, effective_until: effectiveUntil });
    toast.success(t('tutoring2.admin.payoutRates.saved'));
    showSheet.value = false;
    await reload();
  } catch (e) {
    formError.value = extractError(e) ?? t('tutoring2.common.saveFailed');
  } finally {
    isSaving.value = false;
  }
}

const endTarget = ref<PayoutRate | null>(null);
const isEnding = ref(false);
async function confirmEnd() {
  if (!endTarget.value) return;
  isEnding.value = true;
  try {
    await PayoutsService.endRate(endTarget.value.id);
    toast.success(t('tutoring2.admin.payoutRates.ended'));
    endTarget.value = null;
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.actionFailed'));
  } finally {
    isEnding.value = false;
  }
}

// ─── Helpers ────────────────────────────────────────────────────────

function kindLabel(kind: PayoutRateKind): string {
  return t(`tutoring2.admin.payoutRates.kind.${kind}`);
}

function kindTone(kind: PayoutRateKind): StatusBadgeTone {
  switch (kind) {
    case 'per_session': return 'info';
    case 'monthly_salary': return 'success';
    case 'percent_revenue': return 'warning';
  }
}

function formatValue(r: PayoutRate): string {
  if (r.kind === 'percent_revenue') return `${r.value}%`;
  return `Rp ${r.value.toLocaleString('id-ID')}`;
}

function truncateId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

// Same formatter as Pengajuan Payout: the audit timestamps arrive as
// ISO-8601 strings and are read by humans, not compared.
function formatIsoDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

function rateStatusLabel(r: PayoutRate): string {
  if (isRateLive(r)) return t('tutoring2.admin.payoutRates.status.live');
  if (r.effective_from > toLocalYmd()) return t('tutoring2.admin.payoutRates.status.future');
  return t('tutoring2.admin.payoutRates.status.ended');
}

function rateStatusTone(r: PayoutRate): StatusBadgeTone {
  if (isRateLive(r)) return 'success';
  if (r.effective_from > toLocalYmd()) return 'info';
  return 'neutral';
}

const kindOptions = PAYOUT_RATE_KINDS.map((k) => ({ value: k, label: kindLabel(k) }));

/**
 * `per_session` and `monthly_salary` are rupiah amounts and get the
 * thousand separators; `percent_revenue` is a 1-100 share and must not.
 * The field is the same control either way — only the grouping differs.
 */
const isRupiahRate = computed(() => form.value.kind !== 'percent_revenue');

// `UpsertPayoutRatePayload.value` is a plain `number`, so the empty
// field MoneyInput reports as `null` is absorbed back to 0 here; the
// `value <= 0` guard in submitSheet() still rejects it.
const rateValueModel = useMoneyModel(
  () => form.value.value,
  (n) => {
    form.value.value = n;
  },
);

const valueHint = computed(() => {
  switch (form.value.kind) {
    case 'per_session': return t('tutoring2.admin.payoutRates.hintPerSession');
    case 'monthly_salary': return t('tutoring2.admin.payoutRates.hintMonthly');
    case 'percent_revenue': return t('tutoring2.admin.payoutRates.hintPercent');
  }
});
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.payoutRates.title')"
      :meta="state.status === 'content' ? t('tutoring2.admin.payoutRates.meta', { count: filteredRates.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.payoutRates.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.kind')"
          :value="kindFilter ? kindLabel(kindFilter as PayoutRateKind) : t('tutoring2.common.all')"
          icon-name="tag"
          :active="!!kindFilter"
          @click="kindFilter = kindFilter ? '' : 'per_session'"
        />
        <AppFilterChip
          :label="t('tutoring2.admin.payoutRates.filterActiveOnly')"
          :value="activeOnly ? t('tutoring2.common.on') : t('tutoring2.common.off')"
          icon-name="circle-check"
          :active="activeOnly"
          @click="activeOnly = !activeOnly"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.payoutRates.emptyTitle')"
      :empty-description="t('tutoring2.admin.payoutRates.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.kind') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutRates.value') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutRates.effectiveFrom') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutRates.effectiveUntil') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold text-right">{{ t('tutoring2.common.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="r in filteredRates" :key="r.id">
                <tr
                  class="border-b border-slate-100 hover:bg-slate-50 cursor-pointer"
                  @click="toggleExpand(r.id)"
                >
                  <td class="px-4 py-3 font-semibold text-slate-900">{{ r.tutor_name ?? truncateId(r.tutor_id) }}</td>
                  <td class="px-4 py-3">
                    <StatusBadge :label="kindLabel(r.kind)" :tone="kindTone(r.kind)" uppercase />
                  </td>
                  <td class="px-4 py-3 font-semibold text-slate-900">{{ formatValue(r) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ r.effective_from }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ r.effective_until ?? '—' }}</td>
                  <td class="px-4 py-3">
                    <StatusBadge :label="rateStatusLabel(r)" :tone="rateStatusTone(r)" uppercase />
                  </td>
                  <!--
                    The "Aksi" header used to sit over a single button that
                    only appeared for LIVE rates, so on a list of historical
                    rates the column was a header over nothing. Detail is
                    ungated (reading is not a write) and Ubah follows the
                    same `tutoring.payout.rates.manage` ability as Akhiri and
                    the FAB — the ability the sidebar entry itself gates on.
                  -->
                  <td class="px-4 py-3 text-right" @click.stop>
                    <div class="inline-flex flex-wrap justify-end gap-2">
                      <Button
                        variant="ghost"
                        size="sm"
                        :data-testid="`detail-${r.id}`"
                        @click="toggleExpand(r.id)"
                      >
                        {{ t('tutoring2.common.detail') }}
                      </Button>
                      <Button
                        v-if="canManage"
                        variant="secondary"
                        size="sm"
                        :data-testid="`edit-${r.id}`"
                        @click="openEditSheet(r)"
                      >
                        {{ t('tutoring2.common.edit') }}
                      </Button>
                      <Button
                        v-if="canManage && isRateLive(r)"
                        variant="secondary"
                        size="sm"
                        @click="endTarget = r"
                      >
                        {{ t('tutoring2.admin.payoutRates.endCta') }}
                      </Button>
                    </div>
                  </td>
                </tr>
                <tr
                  v-if="expandedId === r.id"
                  :data-testid="`detail-panel-${r.id}`"
                  class="bg-slate-50/60 border-b border-slate-100"
                >
                  <!-- 7 columns here, not the 6 of Pengajuan Payout. -->
                  <td colspan="7" class="px-4 py-4">
                    <div class="grid gap-3 md:grid-cols-2">
                      <div>
                        <p class="text-2xs uppercase tracking-wide text-slate-400 font-bold mb-1">
                          {{ t('tutoring2.common.notes') }}
                        </p>
                        <p class="text-xs text-slate-600 whitespace-pre-line">{{ r.notes || '—' }}</p>
                      </div>
                      <div>
                        <p class="text-2xs uppercase tracking-wide text-slate-400 font-bold mb-1">
                          {{ t('tutoring2.common.detail') }}
                        </p>
                        <ul class="space-y-1 text-xs text-slate-600">
                          <li>{{ t('tutoring2.admin.payoutRates.createdAt') }}: {{ formatIsoDate(r.created_at) }}</li>
                          <li>{{ t('tutoring2.admin.payoutRates.updatedAt') }}: {{ formatIsoDate(r.updated_at) }}</li>
                        </ul>
                      </div>
                    </div>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      v-if="canManage"
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openNewSheet"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.payoutRates.newCta') }}
    </button>

    <FormSheet
      v-if="showSheet"
      :title="isEditing ? t('tutoring2.admin.payoutRates.sheetEditTitle') : t('tutoring2.admin.payoutRates.sheetTitle')"
      :subtitle="isEditing ? t('tutoring2.admin.payoutRates.sheetEditSubtitle') : t('tutoring2.admin.payoutRates.sheetSubtitle')"
      :saving="isSaving"
      :save-label="t('tutoring2.common.save')"
      @save="submitSheet"
      @cancel="showSheet = false"
      @close="showSheet = false"
    >
      <div class="space-y-3">
        <!--
          Tutor / Jenis / Berlaku sejak are the upsert's dedup key, so in
          EDIT mode they are locked: editing one of them would not move
          the rate, it would quietly mint a second one alongside the
          original. The hint below says so in words, because a disabled
          field with no explanation is its own kind of lying control.
        -->
        <p v-if="isEditing" class="text-2xs text-slate-500">
          {{ t('tutoring2.admin.payoutRates.editLockedHint') }}
        </p>
        <!-- By name. An empty list disables the field and says why, in
             the error line, rather than opening a dropdown with nothing
             in it — the reason is worth reading, not hiding in a title
             tooltip on a form the admin is trying to fill. -->
        <FormField
          v-model="form.tutor_id"
          :label="t('tutoring2.common.tutor')"
          type="select"
          field="tutor_id"
          required
          :options="tutorOptions"
          :select-placeholder="t('tutoring2.admin.payoutRates.tutorSelectPh')"
          :disabled="isEditing || tutorOptions.length === 0"
          :error="!isEditing && tutorOptions.length === 0 ? t('tutoring2.admin.payoutRates.errNoTutors') : ''"
        />
        <FormField
          v-model="form.kind"
          :label="t('tutoring2.common.kind')"
          type="select"
          field="kind"
          required
          :options="kindOptions"
          :disabled="isEditing"
        />
        <FormField
          v-model="rateValueModel"
          :label="t('tutoring2.admin.payoutRates.value')"
          money
          field="value"
          :money-grouping="isRupiahRate"
          required
          :placeholder="valueHint"
        />
        <p class="text-2xs text-slate-500">{{ valueHint }}</p>
        <!--
          Both dates are `type="date"`, not a text box over a
          `YYYY-MM-DD` placeholder. The old form asked an admin to hand-
          type a machine format with no picker in ANY browser, and
          nothing stopped `2026-9-1` — a shape the API rejects — from
          being submitted. `type="date"` has a real calendar in every
          desktop browser this app targets (Safari 14.1+ included; it is
          `type="month"` that Safari leaves as a bare box, hence
          MonthPickerModal), and it can only ever emit a normalised
          `YYYY-MM-DD` or the empty string.

          `effective_from` stays LOCKED while editing: the write is an
          upsert keyed on (school_id, tutor_id, kind, effective_from), so
          moving the start date would not move the rate — it would mint a
          second one beside the still-live original.
        -->
        <FormField
          v-model="form.effective_from"
          :label="t('tutoring2.admin.payoutRates.effectiveFrom')"
          type="date"
          field="effective_from"
          required
          :disabled="isEditing"
        />
        <!--
          `min` mirrors the backend's `after_or_equal:effective_from` so
          the picker greys the impossible days out instead of letting the
          admin discover the rule via a 422. Same idiom as the voucher
          valid_from/valid_until pair. It is a courtesy, not the guard:
          a date input still accepts a TYPED out-of-range day, which is
          what the submit-time check below is for.
        -->
        <FormField
          v-model="form.effective_until"
          :label="t('tutoring2.admin.payoutRates.effectiveUntil') + ' (' + t('tutoring2.common.optional') + ')'"
          type="date"
          field="effective_until"
          :min="form.effective_from || undefined"
        />
        <FormField
          v-model="form.notes"
          :label="t('tutoring2.common.notes') + ' (' + t('tutoring2.common.optional') + ')'"
          type="textarea"
          :rows="2"
        />
        <p v-if="formError" class="text-xs text-status-danger">{{ formError }}</p>
      </div>
    </FormSheet>

    <ConfirmationDialog
      v-if="endTarget"
      :title="t('tutoring2.admin.payoutRates.endConfirmTitle')"
      :message="t('tutoring2.admin.payoutRates.endConfirmMsg', { name: endTarget.tutor_name ?? truncateId(endTarget.tutor_id) })"
      :confirm-label="t('tutoring2.admin.payoutRates.endCta')"
      :cancel-label="t('tutoring2.common.cancel')"
      :loading="isEnding"
      danger
      :impact="[
        t('tutoring2.admin.payoutRates.impactStopFuture'),
        t('tutoring2.admin.payoutRates.impactKeepHistory'),
      ]"
      @confirm="confirmEnd"
      @close="endTarget = null"
    />
  </div>
</template>
