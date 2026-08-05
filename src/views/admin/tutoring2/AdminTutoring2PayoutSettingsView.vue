<!--
  AdminTutoring2PayoutSettingsView.vue — WEB-16 (BE-24 settings +
  BE-26 monthly close).

  Two sections stacked in one page:

    1. Payout settings form — cycle + default rate kind + minimum
       payout threshold + free-form notes. PUT is a partial patch
       (backend uses `sometimes` on every rule) so we only send what
       changed. Ability: view=`tutoring.payout.settings.view`,
       write=`tutoring.payout.settings.manage`.

    2. Monthly close panel — pick a `YYYY-MM`, click "Tutup Bulan"
       (POST /close-month). 409 is handled as a friendly "sudah
       ditutup pada …" message rather than a red toast. List of closes
       shows below with a per-row "Buka Kembali" (DELETE) confirm.
       Ability: `tutoring.payout.close_month`.

  The brief mentioned `autoclose_day` + `payment_method` fields; those
  don't exist server-side today. The form leaves that surface as a
  clearly-marked "Segera hadir" note so the visual doesn't create a
  false expectation. When BE-24 adds them, the FE change is one
  additional FormField each and the PUT payload picks them up
  automatically (they're already typed on UpdatePayoutSettingsPayload).
-->
<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import FormField from '@/components/ui/FormField.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { toLocalYm } from '@/lib/local-date';
import { PayoutsService } from '@/services/tutoring2/payouts';
import type {
  PayoutClose,
  PayoutSettings,
  UpdatePayoutSettingsPayload,
} from '@/types/tutoring2/payout';

const { t } = useI18n();
const toast = useToast();
const { can } = useMe();

const canManage = computed(() => can('tutoring.payout.settings.manage'));
const canClose = computed(() => can('tutoring.payout.close_month'));

// ─── Settings ───────────────────────────────────────────────────────

interface SettingsBundle {
  settings: PayoutSettings;
  closes: PayoutClose[];
}

const { state, reload } = useDataRefresh<SettingsBundle>(async () => {
  const [settings, closesRes] = await Promise.all([
    PayoutsService.getSettings(),
    PayoutsService.listCloses({ per_page: 24 }),
  ]);
  return { settings, closes: closesRes.items };
});

const form = reactive<UpdatePayoutSettingsPayload>({
  cycle: 'monthly',
  default_kind: 'per_session',
  minimum_payout: null,
  notes: '',
});
const isSaving = ref(false);

// When the bundle loads / reloads, sync the form with the server truth.
function hydrate(s: PayoutSettings) {
  form.cycle = s.cycle;
  form.default_kind = s.default_kind;
  form.minimum_payout = s.minimum_payout;
  form.notes = s.notes ?? '';
}

// useDataRefresh doesn't accept an onLoad callback; watch state for
// the first success and hydrate the form. Extra reloads (after Save)
// will call this again with the fresh row.
watch(state, (s) => {
  if (s.status === 'content') {
    hydrate((s.data as SettingsBundle).settings);
  }
});

async function saveSettings() {
  isSaving.value = true;
  try {
    // Send everything; `notes` under min:2 would 422 an empty string,
    // so drop it from the patch when the user cleared the field.
    const payload: UpdatePayoutSettingsPayload = {
      cycle: form.cycle,
      default_kind: form.default_kind,
      minimum_payout: form.minimum_payout ?? null,
    };
    if (form.notes && form.notes.length >= 2) payload.notes = form.notes;
    await PayoutsService.updateSettings(payload);
    toast.success(t('tutoring2.admin.payoutSettings.saved'));
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.saveFailed'));
  } finally {
    isSaving.value = false;
  }
}

// ─── Monthly close ──────────────────────────────────────────────────

const closeMonthInput = ref(toLocalYm());
const closeNote = ref('');
const isClosing = ref(false);
const closeError = ref<string | null>(null);

async function closeMonth() {
  closeError.value = null;
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(closeMonthInput.value)) {
    closeError.value = t('tutoring2.admin.payoutSettings.errMonthFormat');
    return;
  }
  isClosing.value = true;
  try {
    await PayoutsService.closeMonth({
      month: closeMonthInput.value,
      note: closeNote.value.trim() || undefined,
    });
    toast.success(t('tutoring2.admin.payoutSettings.monthClosed', { month: closeMonthInput.value }));
    closeNote.value = '';
    await reload();
  } catch (e) {
    // 409 = already closed. The BE echoes the existing row on
    // response.data.data.closed_at so we can surface the timestamp.
    const err = e as { response?: { status?: number; data?: { data?: PayoutClose; message?: string } } };
    if (err?.response?.status === 409) {
      const existing = err.response.data?.data;
      const when = existing?.closed_at ? formatIsoDate(existing.closed_at) : '—';
      closeError.value = t('tutoring2.admin.payoutSettings.errAlreadyClosed', {
        month: closeMonthInput.value,
        when,
      });
    } else {
      closeError.value = extractError(e) ?? t('tutoring2.common.actionFailed');
    }
  } finally {
    isClosing.value = false;
  }
}

const reopenTarget = ref<PayoutClose | null>(null);
const isReopening = ref(false);
async function confirmReopen() {
  if (!reopenTarget.value) return;
  isReopening.value = true;
  try {
    await PayoutsService.reopenMonth(reopenTarget.value.id);
    toast.success(t('tutoring2.admin.payoutSettings.reopened', { month: reopenTarget.value.period_month }));
    reopenTarget.value = null;
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.actionFailed'));
  } finally {
    isReopening.value = false;
  }
}

// ─── Helpers ────────────────────────────────────────────────────────

function extractError(e: unknown): string | null {
  const err = e as { response?: { data?: { message?: string; errors?: Record<string, string[]> } } };
  const msg = err?.response?.data?.message;
  if (msg) return msg;
  const errors = err?.response?.data?.errors;
  if (errors) {
    const first = Object.values(errors)[0];
    if (Array.isArray(first) && first.length > 0) return first[0];
  }
  return null;
}

function formatIsoDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

const cycleOptions = [
  { value: 'monthly', label: t('tutoring2.admin.payoutSettings.cycle.monthly') },
  { value: 'biweekly', label: t('tutoring2.admin.payoutSettings.cycle.biweekly') },
];
const defaultKindOptions = [
  { value: 'per_session', label: t('tutoring2.admin.payoutRates.kind.per_session') },
  { value: 'monthly_salary', label: t('tutoring2.admin.payoutRates.kind.monthly_salary') },
  { value: 'percent_revenue', label: t('tutoring2.admin.payoutRates.kind.percent_revenue') },
];
</script>

<template>
  <div class="space-y-lg pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.payoutSettings.title')"
      :meta="t('tutoring2.admin.payoutSettings.meta')"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="4"
      :empty-title="t('tutoring2.admin.payoutSettings.title')"
      empty-description=""
      @retry="reload"
    >
      <template #default>
        <!-- Section A — settings form -->
        <section class="rounded-3xl border border-slate-100 bg-white p-lg shadow-sm space-y-4">
          <div>
            <h2 class="text-base font-black text-slate-900">
              {{ t('tutoring2.admin.payoutSettings.settingsTitle') }}
            </h2>
            <p class="text-2xs text-slate-500">
              {{ t('tutoring2.admin.payoutSettings.settingsSubtitle') }}
            </p>
          </div>

          <div class="grid gap-3 md:grid-cols-2">
            <FormField
              v-model="form.cycle"
              :label="t('tutoring2.admin.payoutSettings.cycleLabel')"
              type="select"
              :options="cycleOptions"
              :disabled="!canManage"
            />
            <FormField
              v-model="form.default_kind"
              :label="t('tutoring2.admin.payoutSettings.defaultKindLabel')"
              type="select"
              :options="defaultKindOptions"
              :disabled="!canManage"
            />
            <FormField
              v-model.number="form.minimum_payout"
              :label="t('tutoring2.admin.payoutSettings.minPayoutLabel') + ' (Rp)'"
              type="number"
              :min="0"
              number-model
              :disabled="!canManage"
              :placeholder="t('tutoring2.admin.payoutSettings.minPayoutPh')"
            />
            <FormField
              v-model="form.notes"
              :label="t('tutoring2.common.notes')"
              type="textarea"
              :rows="2"
              :disabled="!canManage"
            />
          </div>

          <div class="flex items-center justify-between pt-2">
            <p class="text-2xs text-slate-400">
              {{ t('tutoring2.admin.payoutSettings.comingSoon') }}
            </p>
            <Button
              :disabled="!canManage"
              :loading="isSaving"
              @click="saveSettings"
            >
              {{ t('tutoring2.common.save') }}
            </Button>
          </div>
        </section>

        <!-- Section B — monthly close -->
        <section class="rounded-3xl border border-slate-100 bg-white p-lg shadow-sm space-y-4">
          <div>
            <h2 class="text-base font-black text-slate-900">
              {{ t('tutoring2.admin.payoutSettings.closeTitle') }}
            </h2>
            <p class="text-2xs text-slate-500">
              {{ t('tutoring2.admin.payoutSettings.closeSubtitle') }}
            </p>
          </div>

          <div class="flex flex-wrap items-end gap-3">
            <FormField
              v-model="closeMonthInput"
              :label="t('tutoring2.common.period')"
              type="text"
              placeholder="YYYY-MM"
              :disabled="!canClose"
            />
            <FormField
              v-model="closeNote"
              :label="t('tutoring2.common.notes') + ' (' + t('tutoring2.common.optional') + ')'"
              type="text"
              :disabled="!canClose"
            />
            <Button
              :disabled="!canClose"
              :loading="isClosing"
              variant="primary"
              @click="closeMonth"
            >
              {{ t('tutoring2.admin.payoutSettings.closeCta') }}
            </Button>
          </div>

          <p v-if="closeError" class="text-xs text-status-danger">{{ closeError }}</p>

          <!-- List of closes -->
          <div class="rounded-2xl border border-slate-100 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                  <th class="px-4 py-2 font-bold">{{ t('tutoring2.common.period') }}</th>
                  <th class="px-4 py-2 font-bold">{{ t('tutoring2.admin.payoutSettings.closedAt') }}</th>
                  <th class="px-4 py-2 font-bold">{{ t('tutoring2.admin.payoutSettings.closedBy') }}</th>
                  <th class="px-4 py-2 font-bold">{{ t('tutoring2.common.notes') }}</th>
                  <th class="px-4 py-2 font-bold text-right">{{ t('tutoring2.common.actions') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="c in ((state.status === 'content' ? (state.data as SettingsBundle).closes : []) as PayoutClose[])"
                  :key="c.id"
                  class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
                >
                  <td class="px-4 py-2 font-semibold text-slate-900">{{ c.period_month }}</td>
                  <td class="px-4 py-2 text-slate-600">{{ formatIsoDate(c.closed_at) }}</td>
                  <td class="px-4 py-2 text-slate-600">{{ c.closed_by?.name ?? '—' }}</td>
                  <td class="px-4 py-2 text-slate-600 truncate max-w-xs">{{ c.note ?? '—' }}</td>
                  <td class="px-4 py-2 text-right">
                    <Button
                      v-if="canClose"
                      variant="ghost"
                      size="sm"
                      @click="reopenTarget = c"
                    >
                      {{ t('tutoring2.admin.payoutSettings.reopenCta') }}
                    </Button>
                  </td>
                </tr>
                <tr v-if="state.status === 'content' && ((state.data as SettingsBundle).closes.length === 0)">
                  <td colspan="5" class="px-4 py-6 text-center text-2xs text-slate-400">
                    {{ t('tutoring2.admin.payoutSettings.noClosesYet') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <p class="text-2xs text-slate-400 flex items-center gap-2">
          <StatusBadge :label="t('tutoring2.common.tip')" tone="info" uppercase />
          {{ t('tutoring2.admin.payoutSettings.tenantNote') }}
        </p>
      </template>
    </AsyncView>

    <ConfirmationDialog
      v-if="reopenTarget"
      :title="t('tutoring2.admin.payoutSettings.reopenConfirmTitle')"
      :message="t('tutoring2.admin.payoutSettings.reopenConfirmMsg', { month: reopenTarget.period_month })"
      :confirm-label="t('tutoring2.admin.payoutSettings.reopenCta')"
      :cancel-label="t('tutoring2.common.cancel')"
      :loading="isReopening"
      danger
      :impact="[
        t('tutoring2.admin.payoutSettings.impactReopenFreesUnique'),
        t('tutoring2.admin.payoutSettings.impactReopenAllowsWrites'),
      ]"
      @confirm="confirmReopen"
      @close="reopenTarget = null"
    />
  </div>
</template>
