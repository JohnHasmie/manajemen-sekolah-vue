<!--
  AlertsPanel.vue — Alert tab body.
    · Webhook channel card — editable Slack webhook input + Tes ↗ +
      Simpan (backed by `monitoring_settings` DB row in MR-7).
    · Rule list with toggle per rule.

  Design note (MR-7): the webhook was previously env-only (compose
  HORIZON_SLACK_WEBHOOK, requiring a container recreate to rotate).
  It now lives in the DB so ops rotates it from this input without
  any SSH. `Tes ↗` optionally uses the *un-saved* value in the input,
  so an operator verifies the URL BEFORE clicking Simpan — a typo
  caught here prevents "save then wait for silent alerts".

  Rule toggle mutation is still deferred; visual switch only.
-->
<script setup lang="ts">
import { ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { MonitoringService, type AlertSettingsPayload } from '@/services/monitoring.service';

const props = defineProps<{ data: AlertSettingsPayload }>();
const emit = defineEmits<{ 'refresh': [] }>();

// Editable webhook input — seeded with a placeholder-friendly empty
// string. The server returns a *masked* preview (first 34 chars + …)
// for security, so we cannot round-trip the actual stored value.
// A save is treated as "operator typed a new webhook"; leaving empty
// and hitting Simpan clears the stored row.
const webhookDraft = ref('');
const channelDraft = ref(props.data.channel.name || '#kamil-edu-bugs');
const testing = ref(false);
const saving = ref(false);
const testResult = ref<{ ok: boolean; message: string } | null>(null);
const saveResult = ref<{ ok: boolean; message: string } | null>(null);

// If the parent refetches (e.g. after refresh poll), update the channel
// draft in case the operator changed it elsewhere.
watch(() => props.data.channel.name, (next) => {
  if (channelDraft.value === '' || channelDraft.value === '#kamil-edu-bugs') {
    channelDraft.value = next || '#kamil-edu-bugs';
  }
});

async function fireTest() {
  testing.value = true;
  testResult.value = null;
  saveResult.value = null;
  try {
    // Test the CURRENT input if the operator typed one; otherwise fall
    // back to the stored webhook. This is the "verify before save" flow.
    const res = await MonitoringService.testWebhook(webhookDraft.value || undefined);
    testResult.value = res.ok
      ? { ok: true, message: 'Pesan uji terkirim ke Slack.' }
      : { ok: false, message: res.error ?? 'Gagal kirim pesan uji.' };
  } finally {
    testing.value = false;
  }
}

async function saveWebhook() {
  saving.value = true;
  saveResult.value = null;
  testResult.value = null;
  try {
    const res = await MonitoringService.updateWebhook(
      webhookDraft.value,
      channelDraft.value !== '' ? channelDraft.value : undefined,
    );
    if (res.ok) {
      saveResult.value = { ok: true, message: 'Webhook tersimpan.' };
      webhookDraft.value = '';
      emit('refresh');
    } else {
      saveResult.value = { ok: false, message: res.error ?? 'Gagal menyimpan.' };
    }
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="space-y-4">
    <!-- Channel card -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm space-y-3">
      <div class="flex items-center justify-between">
        <p class="text-sm font-bold text-slate-900">Kirim alert ke Slack</p>
        <span
          v-if="data.channel.configured"
          class="text-xs font-bold px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700 inline-flex items-center gap-1"
        >
          <NavIcon name="check" :size="12" /> aktif
        </span>
        <span
          v-else
          class="text-xs font-bold px-2.5 py-1 rounded-full bg-amber-100 text-amber-700 inline-flex items-center gap-1"
        >
          <NavIcon name="alert-circle" :size="12" /> belum di-set
        </span>
      </div>

      <!-- Channel display name (informational; the webhook itself binds a channel Slack-side). -->
      <div class="flex items-center gap-2">
        <label class="text-xs text-slate-600 font-bold w-24 flex-none">Channel</label>
        <div class="relative flex-1">
          <NavIcon
            name="hash"
            :size="14"
            class="absolute left-3 top-2.5 text-slate-400"
          />
          <input
            v-model="channelDraft"
            type="text"
            placeholder="#kamil-edu-bugs"
            class="w-full pl-8 pr-3 py-2 text-sm border border-slate-200 rounded-lg focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none font-mono"
          />
        </div>
      </div>

      <!-- Webhook URL — editable, replaces the previous readonly display.
           Placeholder shows the current masked value so the operator
           knows a value exists without exposing it. -->
      <div class="flex items-start gap-2">
        <label class="text-xs text-slate-600 font-bold w-24 flex-none pt-2.5">Webhook</label>
        <div class="flex-1 space-y-1">
          <input
            v-model="webhookDraft"
            type="text"
            :placeholder="data.channel.webhook_masked || 'https://hooks.slack.com/services/...'"
            class="w-full px-3 py-2 text-xs border border-slate-200 rounded-lg focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none font-mono"
          />
          <p class="text-xs text-slate-400">
            <template v-if="data.channel.configured">
              Nilai tersimpan disembunyikan. Kosongkan + Simpan untuk menghapus.
            </template>
            <template v-else>
              URL webhook Slack incoming untuk channel di atas.
            </template>
          </p>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex flex-wrap items-center gap-2 justify-end">
        <button
          type="button"
          :disabled="testing || (webhookDraft === '' && !data.channel.configured)"
          class="px-3 py-1.5 text-xs font-bold rounded-lg border border-slate-300 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="fireTest"
        >
          <span v-if="testing">Menguji…</span>
          <span v-else>Tes ↗</span>
        </button>
        <button
          type="button"
          :disabled="saving"
          class="px-3 py-1.5 text-xs font-bold rounded-lg bg-brand-cobalt text-white hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="saveWebhook"
        >
          <span v-if="saving">Menyimpan…</span>
          <span v-else>Simpan</span>
        </button>
      </div>

      <!-- Feedback lines -->
      <p
        v-if="testResult"
        class="text-xs"
        :class="testResult.ok ? 'text-emerald-700' : 'text-rose-700'"
      >
        {{ testResult.message }}
      </p>
      <p
        v-if="saveResult"
        class="text-xs"
        :class="saveResult.ok ? 'text-emerald-700' : 'text-rose-700'"
      >
        {{ saveResult.message }}
      </p>
    </div>

    <!-- Rules -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <p class="text-sm font-bold text-slate-900 mb-3">Aturan alert</p>
      <div v-if="data.rules.length === 0" class="text-xs text-slate-500 py-2">
        Belum ada aturan (jalankan migrasi MR-4).
      </div>
      <ul v-else class="divide-y divide-slate-100">
        <li v-for="rule in data.rules" :key="rule.key" class="py-3 flex items-center justify-between gap-3">
          <div class="flex-1 min-w-0">
            <p class="text-sm font-bold text-slate-900">{{ rule.label }}</p>
            <p class="text-xs text-slate-500 mt-0.5 font-mono">
              {{ JSON.stringify(rule.threshold) }}
            </p>
            <p v-if="rule.last_fired_at" class="text-xs text-slate-400 mt-0.5">
              Terakhir: {{ rule.last_fired_at }}
            </p>
          </div>
          <!-- Visually accurate switch, disabled — mutation endpoint TBD. -->
          <span
            class="relative inline-block w-10 h-6 rounded-full transition-colors flex-none"
            :class="rule.enabled ? 'bg-emerald-500' : 'bg-slate-300'"
          >
            <span
              class="absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-all"
              :class="rule.enabled ? 'left-[18px]' : 'left-0.5'"
            />
          </span>
        </li>
      </ul>
    </div>
  </div>
</template>
