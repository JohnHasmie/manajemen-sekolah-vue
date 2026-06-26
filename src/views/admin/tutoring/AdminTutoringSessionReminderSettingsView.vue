<!--
  AdminTutoringSessionReminderSettingsView — bimbel admin sets which
  offsets the cron uses when sending reminders.

  Two tabs:
    - Session      → offsets in MINUTES before scheduled_at  (tutor + parent)
    - Bill   → offsets in DAYS before due_date         (parent only)

  Each tab keeps its own draft offset list + save/reset action. Cron
  reads each list per-tenant on every 5-minute tick.

  Empty lists are server-rejected — Save is disabled until at least
  one offset is picked.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();
const tab = ref<'session' | 'bill'>('session');

// ── SESSION (minutes) ──────────────────────────────────────────
const sessionLoading = ref(true);
const sessionSaving = ref(false);
const sessionOffsets = ref<number[]>([]);
const sessionIsDefault = ref(false);
const sessionMax = ref(7 * 24 * 60);
const sessionCustomInput = ref<string>('');

const SESSION_PRESETS = computed<{ v: number; label: string }[]>(() => [
  { v: 7 * 24 * 60, label: t('admin.bimbel.session_reminder_settings.preset_1week') },
  { v: 2 * 24 * 60, label: t('admin.bimbel.session_reminder_settings.preset_2days') },
  { v: 1 * 24 * 60, label: t('admin.bimbel.session_reminder_settings.preset_1day') },
  { v: 12 * 60, label: t('admin.bimbel.session_reminder_settings.preset_12hours') },
  { v: 6 * 60, label: t('admin.bimbel.session_reminder_settings.preset_6hours') },
  { v: 3 * 60, label: t('admin.bimbel.session_reminder_settings.preset_3hours') },
  { v: 60, label: t('admin.bimbel.session_reminder_settings.preset_1hour') },
  { v: 30, label: t('admin.bimbel.session_reminder_settings.preset_30min') },
  { v: 15, label: t('admin.bimbel.session_reminder_settings.preset_15min') },
  { v: 10, label: t('admin.bimbel.session_reminder_settings.preset_10min') },
  { v: 5, label: t('admin.bimbel.session_reminder_settings.preset_5min') },
]);

function fmtMin(min: number): string {
  if (min % (24 * 60) === 0) {
    const d = min / (24 * 60);
    return d === 1 ? t('admin.bimbel.session_reminder_settings.fmt_day_one') : t('admin.bimbel.session_reminder_settings.fmt_days', { count: d });
  }
  if (min % 60 === 0) return t('admin.bimbel.session_reminder_settings.fmt_hours', { count: min / 60 });
  return t('admin.bimbel.session_reminder_settings.fmt_minutes', { count: min });
}
const sessionSorted = computed(() => [...sessionOffsets.value].sort((a, b) => b - a));

async function loadSession() {
  sessionLoading.value = true;
  try {
    const res = await TutoringService.getSessionReminderOffsets();
    sessionOffsets.value = res.offsets_minutes;
    sessionIsDefault.value = res.is_default;
    sessionMax.value = res.max_offset_minutes;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.session_reminder_settings.load_session_fail'));
  } finally {
    sessionLoading.value = false;
  }
}
function toggleSession(v: number) {
  const i = sessionOffsets.value.indexOf(v);
  if (i === -1) sessionOffsets.value.push(v);
  else sessionOffsets.value.splice(i, 1);
}
function addSessionCustom() {
  const n = parseInt(sessionCustomInput.value, 10);
  if (!Number.isFinite(n) || n < 1 || n > sessionMax.value) {
    toast.error(t('admin.bimbel.session_reminder_settings.range_session_invalid', { max: sessionMax.value }));
    return;
  }
  if (sessionOffsets.value.includes(n)) {
    toast.info(t('admin.bimbel.session_reminder_settings.duplicate_min', { value: fmtMin(n) }));
    return;
  }
  if (sessionOffsets.value.length >= 10) {
    toast.error(t('admin.bimbel.session_reminder_settings.max_reached'));
    return;
  }
  sessionOffsets.value.push(n);
  sessionCustomInput.value = '';
}
function removeSession(v: number) {
  const i = sessionOffsets.value.indexOf(v);
  if (i !== -1) sessionOffsets.value.splice(i, 1);
}
async function saveSession() {
  if (sessionOffsets.value.length === 0) {
    toast.error(t('admin.bimbel.session_reminder_settings.must_have_one'));
    return;
  }
  sessionSaving.value = true;
  try {
    const res = await TutoringService.updateSessionReminderOffsets(sessionOffsets.value);
    sessionOffsets.value = res.offsets_minutes;
    sessionIsDefault.value = res.is_default;
    toast.success(t('admin.bimbel.session_reminder_settings.saved_session'));
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.session_reminder_settings.save_fail'));
  } finally {
    sessionSaving.value = false;
  }
}
async function resetSession() {
  sessionOffsets.value = [1440, 60];
  await saveSession();
}

// ── BILL (days) ────────────────────────────────────────────────
const billLoading = ref(true);
const billSaving = ref(false);
const billOffsets = ref<number[]>([]);
const billIsDefault = ref(false);
const billMax = ref(30);
const billCustomInput = ref<string>('');

const BILL_PRESETS = computed<{ v: number; label: string }[]>(() => [
  { v: 14, label: t('admin.bimbel.session_reminder_settings.preset_2weeks') },
  { v: 7, label: t('admin.bimbel.session_reminder_settings.preset_1week') },
  { v: 5, label: t('admin.bimbel.session_reminder_settings.preset_5days') },
  { v: 3, label: t('admin.bimbel.session_reminder_settings.preset_3days') },
  { v: 2, label: t('admin.bimbel.session_reminder_settings.preset_2days') },
  { v: 1, label: t('admin.bimbel.session_reminder_settings.preset_1day') },
  { v: 0, label: t('admin.bimbel.session_reminder_settings.preset_due_day') },
]);

function fmtDay(d: number): string {
  if (d === 0) return t('admin.bimbel.session_reminder_settings.fmt_due_day');
  if (d === 1) return t('admin.bimbel.session_reminder_settings.fmt_day_before');
  return t('admin.bimbel.session_reminder_settings.fmt_days_before', { count: d });
}
const billSorted = computed(() => [...billOffsets.value].sort((a, b) => b - a));

async function loadBill() {
  billLoading.value = true;
  try {
    const res = await TutoringService.getBillReminderOffsets();
    billOffsets.value = res.offsets_days;
    billIsDefault.value = res.is_default;
    billMax.value = res.max_offset_days;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.session_reminder_settings.load_bill_fail'));
  } finally {
    billLoading.value = false;
  }
}
function toggleBill(v: number) {
  const i = billOffsets.value.indexOf(v);
  if (i === -1) billOffsets.value.push(v);
  else billOffsets.value.splice(i, 1);
}
function addBillCustom() {
  const n = parseInt(billCustomInput.value, 10);
  if (!Number.isFinite(n) || n < 0 || n > billMax.value) {
    toast.error(t('admin.bimbel.session_reminder_settings.range_day_invalid', { max: billMax.value }));
    return;
  }
  if (billOffsets.value.includes(n)) {
    toast.info(t('admin.bimbel.session_reminder_settings.duplicate_day', { value: fmtDay(n) }));
    return;
  }
  if (billOffsets.value.length >= 10) {
    toast.error(t('admin.bimbel.session_reminder_settings.max_reached'));
    return;
  }
  billOffsets.value.push(n);
  billCustomInput.value = '';
}
function removeBill(v: number) {
  const i = billOffsets.value.indexOf(v);
  if (i !== -1) billOffsets.value.splice(i, 1);
}
async function saveBill() {
  if (billOffsets.value.length === 0) {
    toast.error(t('admin.bimbel.session_reminder_settings.must_have_one'));
    return;
  }
  billSaving.value = true;
  try {
    const res = await TutoringService.updateBillReminderOffsets(billOffsets.value);
    billOffsets.value = res.offsets_days;
    billIsDefault.value = res.is_default;
    toast.success(t('admin.bimbel.session_reminder_settings.saved_bill'));
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.session_reminder_settings.save_fail'));
  } finally {
    billSaving.value = false;
  }
}
async function resetBill() {
  billOffsets.value = [3];
  await saveBill();
}

onMounted(() => {
  loadSession();
  loadBill();
});
</script>

<template>
  <div class="space-y-4 pb-12">
    <BrandPageHeader
      :kicker="t('admin.bimbel.session_reminder_settings.kicker')"
      :title="t('admin.bimbel.session_reminder_settings.title')"
      :subtitle="t('admin.bimbel.session_reminder_settings.subtitle')"
    />

    <!-- Tab bar -->
    <div class="flex gap-1 border-b border-tutoring-border-soft">
      <button
        type="button"
        class="px-4 py-2 text-[13px] font-bold border-b-2 transition-colors"
        :class="
          tab === 'session'
            ? 'border-tutoring-hero text-tutoring-hero'
            : 'border-transparent text-tutoring-text-mid hover:text-tutoring-text-hi'
        "
        @click="tab = 'session'"
      >{{ t('admin.bimbel.session_reminder_settings.tab_session') }}</button>
      <button
        type="button"
        class="px-4 py-2 text-[13px] font-bold border-b-2 transition-colors"
        :class="
          tab === 'bill'
            ? 'border-tutoring-hero text-tutoring-hero'
            : 'border-transparent text-tutoring-text-mid hover:text-tutoring-text-hi'
        "
        @click="tab = 'bill'"
      >{{ t('admin.bimbel.session_reminder_settings.tab_bill') }}</button>
    </div>

    <!-- SESSION TAB -->
    <template v-if="tab === 'session'">
      <div v-if="sessionLoading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.session_reminder_settings.loading') }}</div>
      <template v-else>
        <section class="rounded-2xl bg-tutoring-panel border border-tutoring-border-soft p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-[14px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.session_reminder_settings.session_active_title') }}</h3>
            <span v-if="sessionIsDefault" class="text-[11px] font-bold uppercase tracking-wider bg-tutoring-amber-dim text-amber-700 px-2 py-0.5 rounded-full">{{ t('admin.bimbel.session_reminder_settings.default_pill') }}</span>
          </div>
          <p class="text-[13px] text-tutoring-text-mid mb-3">
            {{ t('admin.bimbel.session_reminder_settings.session_active_hint', { count: sessionSorted.length }) }}
          </p>
          <div v-if="sessionSorted.length" class="flex gap-2 flex-wrap">
            <div v-for="m in sessionSorted" :key="m" class="inline-flex items-center gap-1.5 rounded-full bg-tutoring-accent-dim text-tutoring-hero px-3 py-1.5 text-[13px] font-bold">
              {{ fmtMin(m) }}
              <button type="button" class="rounded-full hover:bg-tutoring-hero/15 p-0.5 -mr-1" :aria-label="t('admin.bimbel.session_reminder_settings.remove_aria')" @click="removeSession(m)"><NavIcon name="x" :size="13" /></button>
            </div>
          </div>
          <p v-else class="text-[13px] text-red-700">{{ t('admin.bimbel.session_reminder_settings.empty_warning') }}</p>
        </section>

        <section class="rounded-2xl bg-tutoring-panel border border-tutoring-border-soft p-4">
          <h3 class="text-[14px] font-bold text-tutoring-text-hi mb-3">{{ t('admin.bimbel.session_reminder_settings.preset_title') }}</h3>
          <div class="flex gap-1.5 flex-wrap">
            <button v-for="p in SESSION_PRESETS" :key="p.v" type="button"
              class="rounded-full px-3 py-1.5 text-[13px] font-bold transition-colors"
              :class="sessionOffsets.includes(p.v) ? 'bg-tutoring-hero text-white' : 'bg-tutoring-bg text-tutoring-text-mid hover:text-tutoring-text-hi'"
              @click="toggleSession(p.v)"
            >{{ p.label }}</button>
          </div>
        </section>

        <section class="rounded-2xl bg-tutoring-panel border border-tutoring-border-soft p-4">
          <h3 class="text-[14px] font-bold text-tutoring-text-hi mb-2">{{ t('admin.bimbel.session_reminder_settings.custom_min_title') }}</h3>
          <p class="text-[13px] text-tutoring-text-mid mb-3">{{ t('admin.bimbel.session_reminder_settings.custom_min_hint', { max: sessionMax }) }}</p>
          <div class="flex gap-2">
            <input v-model="sessionCustomInput" type="number" min="1" :max="sessionMax" :placeholder="t('admin.bimbel.session_reminder_settings.custom_min_ph')"
              class="flex-1 rounded-md bg-tutoring-bg px-3 py-2 text-[13px] text-tutoring-text-hi focus:outline-none"
              @keydown.enter="addSessionCustom"
            />
            <button type="button" class="rounded-md bg-tutoring-bg text-tutoring-text-mid border border-tutoring-border-soft px-4 py-2 text-[13px] font-bold hover:bg-tutoring-border-soft" @click="addSessionCustom">{{ t('admin.bimbel.session_reminder_settings.add') }}</button>
          </div>
        </section>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="rounded-lg bg-tutoring-bg text-tutoring-text-mid border border-tutoring-border-soft px-4 py-2.5 text-[13px]" @click="resetSession">{{ t('admin.bimbel.session_reminder_settings.reset_default') }}</button>
          <button type="button" class="rounded-lg bg-tutoring-hero text-white px-4 py-2.5 text-[13px] font-bold disabled:opacity-50"
            :disabled="sessionSaving || sessionOffsets.length === 0" @click="saveSession">
            {{ sessionSaving ? t('admin.bimbel.session_reminder_settings.saving') : t('admin.bimbel.session_reminder_settings.save') }}
          </button>
        </div>
      </template>
    </template>

    <!-- BILL TAB -->
    <template v-else>
      <div v-if="billLoading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.session_reminder_settings.loading') }}</div>
      <template v-else>
        <section class="rounded-2xl bg-tutoring-panel border border-tutoring-border-soft p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-[14px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.session_reminder_settings.bill_active_title') }}</h3>
            <span v-if="billIsDefault" class="text-[11px] font-bold uppercase tracking-wider bg-tutoring-amber-dim text-amber-700 px-2 py-0.5 rounded-full">{{ t('admin.bimbel.session_reminder_settings.default_pill') }}</span>
          </div>
          <p class="text-[13px] text-tutoring-text-mid mb-3">
            {{ t('admin.bimbel.session_reminder_settings.bill_active_hint') }}
          </p>
          <div v-if="billSorted.length" class="flex gap-2 flex-wrap">
            <div v-for="d in billSorted" :key="d" class="inline-flex items-center gap-1.5 rounded-full bg-tutoring-accent-dim text-tutoring-hero px-3 py-1.5 text-[13px] font-bold">
              {{ fmtDay(d) }}
              <button type="button" class="rounded-full hover:bg-tutoring-hero/15 p-0.5 -mr-1" :aria-label="t('admin.bimbel.session_reminder_settings.remove_aria')" @click="removeBill(d)"><NavIcon name="x" :size="13" /></button>
            </div>
          </div>
          <p v-else class="text-[13px] text-red-700">{{ t('admin.bimbel.session_reminder_settings.empty_warning') }}</p>
        </section>

        <section class="rounded-2xl bg-tutoring-panel border border-tutoring-border-soft p-4">
          <h3 class="text-[14px] font-bold text-tutoring-text-hi mb-3">{{ t('admin.bimbel.session_reminder_settings.preset_title') }}</h3>
          <div class="flex gap-1.5 flex-wrap">
            <button v-for="p in BILL_PRESETS" :key="p.v" type="button"
              class="rounded-full px-3 py-1.5 text-[13px] font-bold transition-colors"
              :class="billOffsets.includes(p.v) ? 'bg-tutoring-hero text-white' : 'bg-tutoring-bg text-tutoring-text-mid hover:text-tutoring-text-hi'"
              @click="toggleBill(p.v)"
            >{{ p.label }}</button>
          </div>
        </section>

        <section class="rounded-2xl bg-tutoring-panel border border-tutoring-border-soft p-4">
          <h3 class="text-[14px] font-bold text-tutoring-text-hi mb-2">{{ t('admin.bimbel.session_reminder_settings.custom_day_title') }}</h3>
          <p class="text-[13px] text-tutoring-text-mid mb-3">{{ t('admin.bimbel.session_reminder_settings.custom_day_hint', { max: billMax }) }}</p>
          <div class="flex gap-2">
            <input v-model="billCustomInput" type="number" min="0" :max="billMax" :placeholder="t('admin.bimbel.session_reminder_settings.custom_day_ph')"
              class="flex-1 rounded-md bg-tutoring-bg px-3 py-2 text-[13px] text-tutoring-text-hi focus:outline-none"
              @keydown.enter="addBillCustom"
            />
            <button type="button" class="rounded-md bg-tutoring-bg text-tutoring-text-mid border border-tutoring-border-soft px-4 py-2 text-[13px] font-bold hover:bg-tutoring-border-soft" @click="addBillCustom">{{ t('admin.bimbel.session_reminder_settings.add') }}</button>
          </div>
        </section>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="rounded-lg bg-tutoring-bg text-tutoring-text-mid border border-tutoring-border-soft px-4 py-2.5 text-[13px]" @click="resetBill">{{ t('admin.bimbel.session_reminder_settings.reset_default') }}</button>
          <button type="button" class="rounded-lg bg-tutoring-hero text-white px-4 py-2.5 text-[13px] font-bold disabled:opacity-50"
            :disabled="billSaving || billOffsets.length === 0" @click="saveBill">
            {{ billSaving ? t('admin.bimbel.session_reminder_settings.saving') : t('admin.bimbel.session_reminder_settings.save') }}
          </button>
        </div>
      </template>
    </template>
  </div>
</template>
