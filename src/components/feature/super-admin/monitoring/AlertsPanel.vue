<!--
  AlertsPanel.vue — Alert tab body.
    · Webhook channel card (Slack #kamil-edu-bugs pill + masked webhook + tes button)
    · Rule list with toggle per rule

  The toggle mutation is a follow-up (`PUT /alert-settings/{key}` — MR-4
  seeds but the mutation endpoint is deferred). For MVP the toggle is
  visually accurate but disabled — an operator changes rules via seed
  update while we scope out the write path.
-->
<script setup lang="ts">
import { ref } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { MonitoringService, type AlertSettingsPayload } from '@/services/monitoring.service';

defineProps<{ data: AlertSettingsPayload }>();

const testing = ref(false);
const testResult = ref<{ ok: boolean; message: string } | null>(null);

async function fireTest() {
  testing.value = true;
  testResult.value = null;
  try {
    const res = await MonitoringService.testWebhook();
    testResult.value = res.ok
      ? { ok: true, message: 'Pesan uji terkirim ke Slack.' }
      : { ok: false, message: res.error ?? 'Gagal kirim pesan uji.' };
  } finally {
    testing.value = false;
  }
}
</script>

<template>
  <div class="space-y-4">
    <!-- Channel card -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <p class="text-sm font-bold text-slate-900 mb-3">Kirim alert ke</p>
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-xs font-bold px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700 inline-flex items-center gap-1.5">
          <NavIcon name="hash" :size="12" />
          {{ data.channel.name || '#kamil-edu-bugs' }}
        </span>
        <input
          type="text"
          :value="data.channel.webhook_masked || 'Belum dikonfigurasi'"
          readonly
          class="flex-1 min-w-[200px] text-xs px-3 py-1.5 border border-slate-200 rounded-lg bg-slate-50 font-mono"
        />
        <button
          type="button"
          :disabled="testing || !data.channel.configured"
          class="px-3 py-1.5 text-xs font-bold rounded-lg border border-slate-300 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="fireTest"
        >
          <span v-if="testing">Menguji…</span>
          <span v-else>Tes ↗</span>
        </button>
      </div>
      <p
        v-if="testResult"
        class="text-xs mt-2"
        :class="testResult.ok ? 'text-emerald-700' : 'text-rose-700'"
      >
        {{ testResult.message }}
      </p>
      <p v-else-if="!data.channel.configured" class="text-xs text-amber-700 mt-2">
        HORIZON_SLACK_WEBHOOK belum di-set — alert engine akan silent.
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
