<!--
  AlertsPanel.vue — Alert tab body.

  Slack destination now supports TWO delivery lanes (MR-9 BE):
    · Bot token (chat.postMessage) — preferred; one token, any channel
      the bot is invited to, edit `channel` in DB to re-route
    · Incoming webhook — legacy; one webhook = one channel

  This panel exposes BOTH so the operator can pick whichever their
  workspace has. If both are set, backend routes via bot token
  (SlackAlertNotifier precedence). Active lane is surfaced in the
  header chip so the operator always knows which channel is live.

  Verify-before-save: the "Tes ↗" button sends whatever is in the
  input fields (bot token + channel, or webhook) BEFORE Simpan, so a
  typo is caught early instead of "save then wait for silent alerts".
-->
<script setup lang="ts">
import { ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { MonitoringService, type AlertSettingsPayload } from '@/services/monitoring.service';

const props = defineProps<{ data: AlertSettingsPayload }>();
const emit = defineEmits<{ 'refresh': [] }>();

// Editable input drafts. Server never returns the actual stored values
// (they're secrets); the masked previews go in placeholders so the
// operator sees "something is stored" without seeing the secret.
const webhookDraft = ref('');
const botTokenDraft = ref('');
const channelDraft = ref(props.data.channel.name || '#kamil-edu-bugs');

const testing = ref(false);
const saving = ref(false);
const testResult = ref<{ ok: boolean; message: string; lane?: string } | null>(null);
const saveResult = ref<{ ok: boolean; message: string } | null>(null);

// If the parent refetches (e.g. after refresh poll), sync channel draft
// unless the operator has already edited it away from the stored value.
watch(() => props.data.channel.name, (next) => {
  if (channelDraft.value === '' || channelDraft.value === '#kamil-edu-bugs') {
    channelDraft.value = next || '#kamil-edu-bugs';
  }
});

// Which lane will the backend actually use right now? Comes from the
// GetAlertSettingsAction response — mirrors SlackAlertNotifier
// precedence (bot_token > webhook > none).
function laneLabel(): string {
  if (props.data.channel.active_lane === 'bot_token') return 'Bot token';
  if (props.data.channel.active_lane === 'webhook') return 'Webhook';
  return 'belum di-set';
}

function laneChipClass(): string {
  if (props.data.channel.active_lane === 'none') return 'bg-amber-100 text-amber-700';
  return 'bg-emerald-100 text-emerald-700';
}

async function fireTest() {
  testing.value = true;
  testResult.value = null;
  saveResult.value = null;
  try {
    // Send drafts as overrides. Backend picks lane using same precedence
    // as runtime notifier — bot_token wins if supplied.
    const res = await MonitoringService.testWebhook({
      bot_token: botTokenDraft.value || undefined,
      channel: channelDraft.value || undefined,
      webhook: webhookDraft.value || undefined,
    });
    testResult.value = res.ok
      ? {
          ok: true,
          message: `Pesan uji terkirim ke Slack (${res.lane === 'bot_token' ? 'bot token' : 'webhook'}).`,
          lane: res.lane,
        }
      : {
          ok: false,
          message: res.error ?? 'Gagal kirim pesan uji.',
        };
  } finally {
    testing.value = false;
  }
}

async function saveConfig() {
  saving.value = true;
  saveResult.value = null;
  testResult.value = null;
  try {
    const res = await MonitoringService.updateWebhook({
      // Only send fields the operator touched to avoid clobbering stored
      // values on empty inputs. The service treats undefined = skip.
      webhook: webhookDraft.value !== '' ? webhookDraft.value : undefined,
      bot_token: botTokenDraft.value !== '' ? botTokenDraft.value : undefined,
      channel: channelDraft.value !== '' ? channelDraft.value : undefined,
    });
    if (res.ok) {
      saveResult.value = { ok: true, message: 'Konfigurasi tersimpan.' };
      webhookDraft.value = '';
      botTokenDraft.value = '';
      emit('refresh');
    } else {
      saveResult.value = { ok: false, message: res.error ?? 'Gagal menyimpan.' };
    }
  } finally {
    saving.value = false;
  }
}

async function clearField(field: 'webhook' | 'bot_token') {
  saving.value = true;
  saveResult.value = null;
  try {
    const res = await MonitoringService.updateWebhook({
      [field]: '',
    });
    if (res.ok) {
      saveResult.value = { ok: true, message: field === 'bot_token' ? 'Bot token dihapus.' : 'Webhook dihapus.' };
      emit('refresh');
    } else {
      saveResult.value = { ok: false, message: res.error ?? 'Gagal menghapus.' };
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
          class="text-xs font-bold px-2.5 py-1 rounded-full inline-flex items-center gap-1"
          :class="laneChipClass()"
        >
          <NavIcon
            :name="data.channel.active_lane === 'none' ? 'alert-circle' : 'check'"
            :size="12"
          />
          Lane: {{ laneLabel() }}
        </span>
      </div>

      <!-- Channel display -->
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

      <!-- Bot token (preferred lane) -->
      <div class="flex items-start gap-2">
        <label class="text-xs text-slate-600 font-bold w-24 flex-none pt-2.5">
          Bot token
          <span class="block font-normal text-slate-400">preferred</span>
        </label>
        <div class="flex-1 space-y-1">
          <div class="flex gap-2">
            <input
              v-model="botTokenDraft"
              type="password"
              :placeholder="data.channel.bot_token_masked || 'xoxb-...'"
              class="flex-1 px-3 py-2 text-xs border border-slate-200 rounded-lg focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none font-mono"
            />
            <button
              v-if="data.channel.bot_token_configured"
              type="button"
              :disabled="saving"
              class="px-2 py-1.5 text-xs font-bold rounded-lg border border-rose-200 text-rose-600 hover:bg-rose-50 disabled:opacity-50"
              @click="clearField('bot_token')"
              title="Hapus bot token tersimpan"
            >
              <NavIcon name="trash" :size="14" />
            </button>
          </div>
          <p class="text-xs text-slate-400">
            <template v-if="data.channel.bot_token_configured">
              Token tersimpan. Bot harus jadi member di channel di atas
              (undang via <code>/invite &#64;bot</code>).
            </template>
            <template v-else>
              Slack app OAuth Bot User token. Diprioritaskan di atas webhook —
              flexible per-channel.
            </template>
          </p>
        </div>
      </div>

      <!-- Webhook (legacy lane) -->
      <div class="flex items-start gap-2">
        <label class="text-xs text-slate-600 font-bold w-24 flex-none pt-2.5">
          Webhook
          <span class="block font-normal text-slate-400">alternatif</span>
        </label>
        <div class="flex-1 space-y-1">
          <div class="flex gap-2">
            <input
              v-model="webhookDraft"
              type="password"
              :placeholder="data.channel.webhook_masked || 'https://hooks.slack.com/services/...'"
              class="flex-1 px-3 py-2 text-xs border border-slate-200 rounded-lg focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none font-mono"
            />
            <button
              v-if="data.channel.webhook_configured"
              type="button"
              :disabled="saving"
              class="px-2 py-1.5 text-xs font-bold rounded-lg border border-rose-200 text-rose-600 hover:bg-rose-50 disabled:opacity-50"
              @click="clearField('webhook')"
              title="Hapus webhook tersimpan"
            >
              <NavIcon name="trash" :size="14" />
            </button>
          </div>
          <p class="text-xs text-slate-400">
            <template v-if="data.channel.webhook_configured">
              Webhook tersimpan. Channel di-fix di URL, dipakai kalau bot token kosong.
            </template>
            <template v-else>
              Incoming webhook Slack — legacy, channel fixed ke URL.
            </template>
          </p>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex flex-wrap items-center gap-2 justify-end">
        <button
          type="button"
          :disabled="testing || (
            botTokenDraft === ''
            && webhookDraft === ''
            && !data.channel.configured
          )"
          class="px-3 py-1.5 text-xs font-bold rounded-lg border border-slate-300 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="fireTest"
        >
          <span v-if="testing">Menguji…</span>
          <span v-else>Tes ↗</span>
        </button>
        <button
          type="button"
          :disabled="saving || (botTokenDraft === '' && webhookDraft === '' && channelDraft === (data.channel.name || '#kamil-edu-bugs'))"
          class="px-3 py-1.5 text-xs font-bold rounded-lg bg-brand-cobalt text-white hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="saveConfig"
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
