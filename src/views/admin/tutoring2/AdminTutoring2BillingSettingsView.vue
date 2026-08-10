<!--
  AdminTutoring2BillingSettingsView.vue — tenant-wide billing settings
  for the bimbel admin (greenfield replacement for
  `admin/tutoring/AdminTutoringBillingSettingsView.vue`).

  Route: /admin/tutoring2/settings/billing
  Endpoints:
    GET|PUT /tutoring-v2/settings/bill-reminders   reminder offsets
    GET|PUT /tutoring-v2/billing-settings          payment destination

  ── History, because this file used to say the opposite ──────────────

  This view shipped documenting `GET|PUT /tutoring-v2/billing-settings`
  as NON-EXISTENT, with a list of five dropped features and the routes
  each would need. That was true when written. Four of the five are now
  live and wired above, so the list has been removed rather than left to
  mislead the next reader into re-planning work that is already done.

  What the v2 route deliberately does NOT carry, and why:

    Tenant-wide billing-mode toggles (allow_prepaid / allow_monthly /
    allow_per_session / default_mode). The columns still exist for v1,
    but in v2 the allowed modes live PER PACKAGE
    (`bimbel_packages.allowed_billing_modes`) and the chosen mode PER
    ENROLLMENT (`bimbel_enrollments.billing_mode`). A tenant-wide switch
    would be a NEW concept and a second, competing source of truth for
    the same question — a product decision, not a port. Do not add it
    here on the assumption that v1 having it makes it a gap.

  ── STILL GENUINELY MISSING ──────────────────────────────────────────

    QRIS image upload. Needs POST /tutoring-v2/billing-settings/qris.
    The identically-named v1 route exists, but inside the LEGACY
    `Route::prefix('tutoring')` group — a different group serving a
    different controller. Same path is not the same endpoint; check the
    group boundaries before concluding a route exists (v2 spans lines
    1102-1328 of routes/api.php, v1 spans 1330-1593).

    Until it ships, `qris_image_url` is read-only here: it is displayed
    to parents if a v1 upload set it, and cannot be changed from this
    screen. The API rejects a caller-supplied URL by design, so this is
    not a field to wire up hopefully.
-->
<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { TutoringBillingSettingsService } from '@/services/tutoring2/billing-settings';
import { TutoringReminderSettingsService } from '@/services/tutoring2/reminder-settings';
import type {
  BillingSettings,
  BillingSettingsUpdatePayload,
} from '@/types/tutoring2/billing';
import type { ReminderSettings } from '@/types/tutoring2/reminder-settings';

const { t } = useI18n();
const toast = useToast();

const MINUTES_PER_DAY = 1440;

/**
 * Offered offsets, in DAYS before the due date. Converted to the
 * wire's minutes on the way out. Every value stays inside the
 * server's 1..10080-minute bound (7 days is the ceiling, hence 7 is
 * the largest preset).
 */
const PRESET_DAYS = [1, 2, 3, 5, 7] as const;

/** Currently ticked offsets, in minutes. */
const selectedOffsets = ref<number[]>([]);
const saving = ref(false);

/**
 * ⚠ "Turn reminders off entirely" is NOT offered, and that is not an
 * oversight. BE-9's design is "empty offsets array = disabled" (see the
 * ReminderSettingsController docblock, which says so explicitly), but
 * `UpdateReminderSettingsRequest` validates
 * `'offsets' => ['required', 'array', 'min:0', 'max:20']` — and
 * Laravel's `required` rejects an empty array outright
 * (`ValidatesAttributes::validateRequired` returns false when
 * `is_countable($value) && count($value) < 1`). `min:0` on an array is
 * a no-op here because `required` has already failed.
 *
 * So a PUT with `offsets: []` 422s, and a master toggle wired to it
 * would be a switch that always throws. We therefore require at least
 * one offset and disable Save when none is picked, rather than
 * shipping a control that cannot do what it says.
 *
 * Backend fix that would unlock the toggle: swap `required` for
 * `present` in `UpdateReminderSettingsRequest::rules()`.
 */
const canSave = computed(() => selectedOffsets.value.length > 0);

// The loader seeds the editable form, so the two default watchers are
// switched OFF: reminder offsets are tenant-wide (not academic-year
// scoped) and the payload carries no server-localised strings, so a
// year/locale switch has nothing to re-fetch — it would only clobber
// whatever the admin had half-typed.
const { state, reload } = useDataRefresh<ReminderSettings>(
  async () => {
    // Two independent settings surfaces on one screen. The payment
    // destination is fetched in parallel and tolerated on failure: the
    // reminder form is usable without it, and a 500 on one panel should
    // not take the whole settings page down.
    const [settings, billing] = await Promise.all([
      TutoringReminderSettingsService.getBillReminders(),
      TutoringBillingSettingsService.get().catch(() => null),
    ]);
    seedForm(settings);
    if (billing) seedPaymentForm(billing);
    paymentLoadFailed.value = billing === null;
    return settings;
  },
  { watchAcademicYear: false, watchLocale: false },
);

// ── Payment destination ──────────────────────────────────────────
//
// The bank block a wali is shown on their Bayar screen. Until !713 there
// was no v2 route for it, so this panel did not exist and a parent could
// see what they owed with no way to discover where to send it.

const paymentLoadFailed = ref(false);
const savingPayment = ref(false);

const paymentForm = reactive({
  bank_name: '',
  bank_account_number: '',
  bank_account_holder: '',
  payment_instructions: '',
  payment_gateway_enabled: false,
  payment_gateway_provider: '',
});

/**
 * The values as last loaded/saved. The patch below is computed against
 * this rather than against "whatever is in the inputs", which is what
 * makes a partial save safe.
 */
let paymentBaseline: BillingSettings | null = null;

const paymentSettings = ref<BillingSettings | null>(null);

function seedPaymentForm(s: BillingSettings): void {
  paymentBaseline = s;
  paymentSettings.value = s;
  paymentForm.bank_name = s.bank_name ?? '';
  paymentForm.bank_account_number = s.bank_account_number ?? '';
  paymentForm.bank_account_holder = s.bank_account_holder ?? '';
  paymentForm.payment_instructions = s.payment_instructions ?? '';
  paymentForm.payment_gateway_enabled = s.payment_gateway_enabled;
  paymentForm.payment_gateway_provider = s.payment_gateway_provider ?? '';
}

/** An input left blank means "no value", not the empty string. */
function normalise(v: string): string | null {
  const trimmed = v.trim();
  return trimmed === '' ? null : trimmed;
}

/**
 * Only the fields that actually CHANGED.
 *
 * The API distinguishes absent from present-and-null: absent leaves a
 * field alone, null clears it. Posting the whole form would therefore be
 * destructive in the ordinary case — a tenant whose bank details were
 * entered once and never re-typed would have them cleared the moment an
 * admin edited the instructions box, and one production tenant has
 * exactly that data.
 *
 * So this diffs against the loaded baseline and sends nothing else.
 */
function buildPaymentPatch(): BillingSettingsUpdatePayload {
  const base = paymentBaseline;
  const patch: BillingSettingsUpdatePayload = {};
  if (!base) return patch;

  const text = [
    'bank_name',
    'bank_account_number',
    'bank_account_holder',
    'payment_instructions',
  ] as const;
  for (const key of text) {
    const next = normalise(paymentForm[key]);
    if (next !== (base[key] ?? null)) patch[key] = next;
  }

  if (paymentForm.payment_gateway_enabled !== base.payment_gateway_enabled) {
    patch.payment_gateway_enabled = paymentForm.payment_gateway_enabled;
  }

  const provider = normalise(paymentForm.payment_gateway_provider);
  if (provider !== (base.payment_gateway_provider ?? null)) {
    patch.payment_gateway_provider = provider as 'midtrans' | 'xendit' | null;
  }

  return patch;
}

const paymentDirty = computed(() => {
  // Touch every field so the computed re-evaluates on any edit.
  void paymentForm.bank_name;
  void paymentForm.bank_account_number;
  void paymentForm.bank_account_holder;
  void paymentForm.payment_instructions;
  void paymentForm.payment_gateway_enabled;
  void paymentForm.payment_gateway_provider;
  return Object.keys(buildPaymentPatch()).length > 0;
});

async function savePayment(): Promise<void> {
  const patch = buildPaymentPatch();
  // Nothing changed — do not send an empty PUT just because the button
  // was pressed.
  if (Object.keys(patch).length === 0) return;

  savingPayment.value = true;
  try {
    const saved = await TutoringBillingSettingsService.update(patch);
    seedPaymentForm(saved);
    toast.success(t('tutoring2.admin.billingSettings.paymentSaved'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring2.admin.billingSettings.saveFailed'),
    );
  } finally {
    savingPayment.value = false;
  }
}

/**
 * Seed the editable form from the server row. Offsets that don't match
 * a preset (e.g. saved by the legacy screen, or by a future custom
 * input) are KEPT in `selectedOffsets` so saving from this screen
 * never silently drops them — they just render as an extra read-only
 * chip below the presets.
 */
function seedForm(settings: ReminderSettings): void {
  selectedOffsets.value = [...settings.offsets];
}

const presetOptions = computed(() =>
  PRESET_DAYS.map((days) => ({
    minutes: days * MINUTES_PER_DAY,
    label: t('tutoring2.admin.billingSettings.daysBefore', { count: days }),
  })),
);

const presetMinutes = computed(() => new Set(presetOptions.value.map((o) => o.minutes)));

/** Saved offsets this screen has no preset for — shown, not silently dropped. */
const customOffsets = computed(() =>
  selectedOffsets.value.filter((m) => !presetMinutes.value.has(m)).sort((a, b) => a - b),
);

function isSelected(minutes: number): boolean {
  return selectedOffsets.value.includes(minutes);
}

function toggleOffset(minutes: number): void {
  const next = new Set(selectedOffsets.value);
  if (next.has(minutes)) next.delete(minutes);
  else next.add(minutes);
  selectedOffsets.value = [...next].sort((a, b) => a - b);
}

/** Render an arbitrary minute offset as human copy ("3 hari sebelum"). */
function offsetLabel(minutes: number): string {
  if (minutes % MINUTES_PER_DAY === 0) {
    return t('tutoring2.admin.billingSettings.daysBefore', {
      count: minutes / MINUTES_PER_DAY,
    });
  }
  if (minutes % 60 === 0) {
    return t('tutoring2.admin.billingSettings.hoursBefore', { count: minutes / 60 });
  }
  return t('tutoring2.admin.billingSettings.minutesBefore', { count: minutes });
}

async function save(): Promise<void> {
  if (!canSave.value) return;
  saving.value = true;
  try {
    const offsets = [...selectedOffsets.value].sort((a, b) => a - b);
    const saved = await TutoringReminderSettingsService.updateBillReminders({ offsets });
    seedForm(saved);
    toast.success(t('tutoring2.admin.billingSettings.saved'));
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutoring2.admin.billingSettings.saveFailed'));
  } finally {
    saving.value = false;
  }
}

/** The five legacy controls with no v2 backend — see the file header. */
const droppedFeatures = computed(() => [
  t('tutoring2.admin.billingSettings.droppedModes'),
  t('tutoring2.admin.billingSettings.droppedBank'),
  t('tutoring2.admin.billingSettings.droppedQris'),
  t('tutoring2.admin.billingSettings.droppedInstructions'),
  t('tutoring2.admin.billingSettings.droppedGateway'),
]);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.billingSettings.title')"
      :meta="
        state.status === 'loading'
          ? t('tutoring2.common.loading')
          : t('tutoring2.admin.billingSettings.meta')
      "
    />

    <AsyncView :state="state" loading-variant="list" :loading-rows="3" @retry="reload">
      <template #default>
        <section class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
          <h2 class="text-sm font-bold text-slate-900">
            {{ t('tutoring2.admin.billingSettings.remindersTitle') }}
          </h2>
          <p class="mt-0.5 text-2xs text-slate-500">
            {{ t('tutoring2.admin.billingSettings.remindersHint') }}
          </p>

          <fieldset class="mt-4">
            <legend class="text-2xs font-bold uppercase tracking-widest text-slate-400">
              {{ t('tutoring2.admin.billingSettings.offsetsLegend') }}
            </legend>
            <div class="mt-2 flex flex-wrap gap-1.5">
              <button
                v-for="opt in presetOptions"
                :key="opt.minutes"
                type="button"
                class="rounded-xl border px-3 py-1.5 text-2xs font-bold transition"
                :class="
                  isSelected(opt.minutes)
                    ? 'border-brand-cobalt bg-brand-cobalt text-white'
                    : 'border-slate-200 bg-white text-slate-600 hover:border-brand-cobalt/50'
                "
                :aria-pressed="isSelected(opt.minutes)"
                @click="toggleOffset(opt.minutes)"
              >
                {{ opt.label }}
              </button>
            </div>

            <!-- Offsets saved elsewhere that have no preset here. Kept
                 so saving from this screen can't quietly delete them. -->
            <p v-if="customOffsets.length > 0" class="mt-2 text-2xs text-slate-500">
              {{ t('tutoring2.admin.billingSettings.customOffsetsNote') }}
              <span class="font-bold">
                {{ customOffsets.map(offsetLabel).join(' · ') }}
              </span>
            </p>

            <!-- See the `canSave` comment: the backend cannot persist
                 an empty offsets array, so we block the save instead of
                 letting it 422. -->
            <p v-if="!canSave" class="mt-2 text-2xs text-amber-700">
              {{ t('tutoring2.admin.billingSettings.noOffsetsWarning') }}
            </p>
          </fieldset>

          <button
            type="button"
            :disabled="saving || !canSave"
            class="mt-4 w-full rounded-xl bg-brand-cobalt px-4 py-2.5 text-sm font-bold text-white transition hover:bg-brand-cobalt/90 disabled:opacity-50"
            @click="save"
          >
            {{
              saving
                ? t('tutoring2.admin.billingSettings.saving')
                : t('tutoring2.admin.billingSettings.save')
            }}
          </button>
        </section>

        <!--
          PAYMENT DESTINATION — what a wali sees on their Bayar screen.

          Saving sends only the fields that CHANGED. The API treats an
          absent key as "leave alone" and an explicit null as "clear", so
          posting the whole form would wipe a bank account the admin
          never touched. See buildPaymentPatch().
        -->
        <section class="mt-3 rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h2 class="text-sm font-bold text-slate-900">
                {{ t('tutoring2.admin.billingSettings.paymentTitle') }}
              </h2>
              <p class="mt-0.5 text-2xs text-slate-500">
                {{ t('tutoring2.admin.billingSettings.paymentDesc') }}
              </p>
            </div>
            <span
              v-if="paymentSettings && !paymentSettings.has_payable_destination"
              class="shrink-0 rounded-full bg-amber-100 px-2 py-0.5 text-2xs font-semibold text-amber-800"
            >
              {{ t('tutoring2.admin.billingSettings.notPayable') }}
            </span>
          </div>

          <p v-if="paymentLoadFailed" class="mt-3 text-2xs text-amber-700">
            {{ t('tutoring2.admin.billingSettings.paymentLoadFailed') }}
          </p>

          <div v-else class="mt-3 space-y-3">
            <label class="block">
              <span class="text-2xs font-semibold text-slate-600">
                {{ t('tutoring2.admin.billingSettings.bankName') }}
              </span>
              <input
                v-model="paymentForm.bank_name"
                type="text"
                maxlength="80"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm"
              />
            </label>

            <label class="block">
              <span class="text-2xs font-semibold text-slate-600">
                {{ t('tutoring2.admin.billingSettings.accountNumber') }}
              </span>
              <input
                v-model="paymentForm.bank_account_number"
                type="text"
                inputmode="numeric"
                maxlength="40"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm tabular-nums"
              />
            </label>

            <label class="block">
              <span class="text-2xs font-semibold text-slate-600">
                {{ t('tutoring2.admin.billingSettings.accountHolder') }}
              </span>
              <input
                v-model="paymentForm.bank_account_holder"
                type="text"
                maxlength="120"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm"
              />
            </label>

            <label class="block">
              <span class="text-2xs font-semibold text-slate-600">
                {{ t('tutoring2.admin.billingSettings.instructions') }}
              </span>
              <textarea
                v-model="paymentForm.payment_instructions"
                rows="3"
                maxlength="5000"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm"
              ></textarea>
              <!-- Shown to parents verbatim, and rendered as plain text
                   on their side — say so, so nobody types HTML expecting
                   it to format. -->
              <span class="mt-1 block text-2xs text-slate-400">
                {{ t('tutoring2.admin.billingSettings.instructionsHint') }}
              </span>
            </label>

            <label class="flex items-center gap-2">
              <input v-model="paymentForm.payment_gateway_enabled" type="checkbox" />
              <span class="text-2xs font-semibold text-slate-600">
                {{ t('tutoring2.admin.billingSettings.gatewayEnabled') }}
              </span>
            </label>

            <label v-if="paymentForm.payment_gateway_enabled" class="block">
              <span class="text-2xs font-semibold text-slate-600">
                {{ t('tutoring2.admin.billingSettings.gatewayProvider') }}
              </span>
              <select
                v-model="paymentForm.payment_gateway_provider"
                class="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm"
              >
                <option value="">—</option>
                <option value="midtrans">Midtrans</option>
                <option value="xendit">Xendit</option>
              </select>
              <span
                v-if="paymentSettings?.payment_gateway_configured"
                class="mt-1 block text-2xs text-emerald-700"
              >
                {{ t('tutoring2.admin.billingSettings.gatewayConfigured') }}
              </span>
            </label>

            <div class="flex justify-end pt-1">
              <button
                type="button"
                class="rounded-xl bg-cobalt-600 px-4 py-2 text-2xs font-bold text-white disabled:opacity-40"
                :disabled="!paymentDirty || savingPayment"
                @click="savePayment"
              >
                {{ savingPayment ? t('common.saving') : t('common.save') }}
              </button>
            </div>
          </div>
        </section>

        <!-- Honest gap notice. No dead buttons, no placeholder inputs
             that silently discard what the admin types. -->
        <section class="mt-3 rounded-3xl border border-slate-200 bg-slate-50 p-4">
          <div class="flex items-start gap-2.5">
            <span class="grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-slate-200 text-slate-600">
              <NavIcon name="info" :size="14" />
            </span>
            <div class="min-w-0 flex-1">
              <h2 class="text-2xs font-bold text-slate-900">
                {{ t('tutoring2.admin.billingSettings.gapTitle') }}
              </h2>
              <p class="mt-0.5 text-2xs text-slate-600">
                {{ t('tutoring2.admin.billingSettings.gapDesc') }}
              </p>
              <ul class="mt-2 space-y-0.5">
                <li v-for="f in droppedFeatures" :key="f" class="text-2xs text-slate-500">
                  · {{ f }}
                </li>
              </ul>
            </div>
          </div>
        </section>
      </template>
    </AsyncView>
  </div>
</template>
