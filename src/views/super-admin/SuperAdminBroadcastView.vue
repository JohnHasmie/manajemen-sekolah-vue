<!--
  SuperAdminBroadcastView.vue — Platform-wide WhatsApp broadcast dashboard for Super Admins.

  Securely routes WhatsApp messages through Laravel's backend FonnteService. The frontend
  exposes configuration sliders and recipient resolution, then sequentially hits the send API.
  Includes a dynamic progress monitor and terminal emulator for live logs.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { DemoRequestService } from '@/services/demo-request.service';
import { SuperAdminBroadcastService, type ResolvedRecipient } from '@/services/super-admin-broadcast.service';
import type { DemoRequest } from '@/types/demo-request';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();

// ── State variables ──
const targetType = ref<'manual' | 'school_admins'>('manual');
const manualNumbersText = ref('');
const messageTemplate = ref('');
const sendDelay = ref(2); // delay in seconds

// Schools listing (for school admins resolution)
const schools = ref<DemoRequest[]>([]);
const isSchoolsLoading = ref(false);
const selectedSchoolIds = ref<string[]>([]);
const schoolSearch = ref('');

// Resolved recipients & parsing state
const resolvedRecipients = ref<ResolvedRecipient[]>([]);
const isResolving = ref(false);
const targetList = ref<ResolvedRecipient[]>([]);

// Sending state machines
const status = ref<'idle' | 'sending' | 'paused' | 'completed'>('idle');
const logs = ref<string[]>([]);
const consoleRef = ref<HTMLDivElement | null>(null);
const templateTextarea = ref<HTMLTextAreaElement | null>(null);

// Metrics tracker
const metrics = ref({
  total: 0,
  success: 0,
  failed: 0,
  currentIndex: 0,
});

// ── Load approved demo request schools ──
async function loadSchools() {
  isSchoolsLoading.value = true;
  try {
    const res = await DemoRequestService.list({ status: 'approved', per_page: 100 });
    schools.value = res.items.filter((item) => item.activated_school_id);
  } catch (e) {
    console.error('Failed to load schools', e);
    logMessage(`Gagal memuat daftar sekolah: ${(e as Error).message}`, 'error');
  } finally {
    isSchoolsLoading.value = false;
  }
}

onMounted(() => {
  loadSchools();
});

// ── Filter and selection logic ──
const filteredSchools = computed(() => {
  const q = schoolSearch.value.trim().toLowerCase();
  if (!q) return schools.value;
  return schools.value.filter((s) =>
    (s.school_summary.name || '').toLowerCase().includes(q) ||
    (s.school_summary.city || '').toLowerCase().includes(q)
  );
});

const allSchoolsSelected = computed(() => {
  if (filteredSchools.value.length === 0) return false;
  return filteredSchools.value.every((s) =>
    selectedSchoolIds.value.includes(s.activated_school_id as string)
  );
});

function toggleAllSchools() {
  const currentFilteredIds = filteredSchools.value
    .map((s) => s.activated_school_id)
    .filter((id): id is string => !!id);

  if (allSchoolsSelected.value) {
    // Deselect filtered
    selectedSchoolIds.value = selectedSchoolIds.value.filter(
      (id) => !currentFilteredIds.includes(id)
    );
  } else {
    // Select filtered
    const union = new Set([...selectedSchoolIds.value, ...currentFilteredIds]);
    selectedSchoolIds.value = Array.from(union);
  }
}

// ── Resolve contacts from backend ──
async function handleResolveRecipients() {
  if (selectedSchoolIds.value.length === 0) {
    logMessage('Silakan pilih setidaknya satu sekolah terlebih dahulu.', 'warn');
    return;
  }
  isResolving.value = true;
  logMessage(`Memuat kontak administrator untuk ${selectedSchoolIds.value.length} sekolah pilihan...`, 'info');
  try {
    const data = await SuperAdminBroadcastService.resolveRecipients(selectedSchoolIds.value);
    resolvedRecipients.value = data;
    logMessage(`Berhasil menemukan ${data.length} kontak admin sekolah aktif.`, 'success');
  } catch (e) {
    logMessage(`Gagal memuat kontak admin: ${(e as Error).message}`, 'error');
  } finally {
    isResolving.value = false;
  }
}

// Clear state when switching target mode
watch(targetType, () => {
  status.value = 'idle';
  resetMetrics();
  logs.value = [];
  targetList.value = [];
});

function resetMetrics() {
  metrics.value = {
    total: 0,
    success: 0,
    failed: 0,
    currentIndex: 0,
  };
}

// ── Placeholders quick insert ──
function insertPlaceholder(placeholder: string) {
  const ta = templateTextarea.value;
  if (!ta) {
    messageTemplate.value += placeholder;
    return;
  }
  const start = ta.selectionStart;
  const end = ta.selectionEnd;
  const text = messageTemplate.value;
  messageTemplate.value = text.substring(0, start) + placeholder + text.substring(end);
  setTimeout(() => {
    ta.focus();
    ta.setSelectionRange(start + placeholder.length, start + placeholder.length);
  }, 10);
}

// ── Logging terminal helper ──
function logMessage(text: string, level: 'info' | 'success' | 'error' | 'warn' = 'info') {
  const timestamp = new Date().toLocaleTimeString();
  logs.value.push(`[${level.toUpperCase()}] [${timestamp}] ${text}`);
  setTimeout(() => {
    if (consoleRef.value) {
      consoleRef.value.scrollTop = consoleRef.value.scrollHeight;
    }
  }, 50);
}

function getLogClass(log: string): string {
  if (log.includes('[SUCCESS]')) return 'text-emerald-400';
  if (log.includes('[ERROR]')) return 'text-rose-400';
  if (log.includes('[WARN]')) return 'text-amber-400';
  return 'text-slate-300';
}

// ── Broadcaster loop execution ──
async function startBroadcast() {
  if (!messageTemplate.value.trim()) {
    logMessage('Templat pesan tidak boleh kosong.', 'warn');
    return;
  }

  if (targetType.value === 'manual') {
    if (!manualNumbersText.value.trim()) {
      logMessage('Silakan masukkan nomor WhatsApp manual.', 'warn');
      return;
    }
    const lines = manualNumbersText.value.split(/[\n,]+/);
    const parsedNumbers = lines
      .map((num) => num.replace(/[^0-9]/g, '').trim())
      .filter((num) => num.length > 0);

    if (parsedNumbers.length === 0) {
      logMessage('Tidak ditemukan nomor WhatsApp manual yang valid.', 'warn');
      return;
    }

    targetList.value = parsedNumbers.map((num) => ({
      name: 'Penerima',
      phone_number: num,
      school_name: '-',
    }));
  } else {
    if (resolvedRecipients.value.length === 0) {
      logMessage('Harap muat kontak penerima sekolah terlebih dahulu.', 'warn');
      return;
    }
    targetList.value = [...resolvedRecipients.value];
  }

  if (status.value === 'idle' || status.value === 'completed') {
    resetMetrics();
    metrics.value.total = targetList.value.length;
    logs.value = [];
    logMessage(`Memulai pengiriman pesan ke ${metrics.value.total} target...`, 'info');
  } else if (status.value === 'paused') {
    logMessage(`Melanjutkan pengiriman dari antrean ke-${metrics.value.currentIndex + 1}...`, 'info');
  }

  status.value = 'sending';
  runSendingLoop();
}

async function runSendingLoop() {
  while (metrics.value.currentIndex < metrics.value.total && status.value === 'sending') {
    const idx = metrics.value.currentIndex;
    const recipient = targetList.value[idx];

    // Placeholder replace
    let text = messageTemplate.value;
    text = text.replace(/{name}/g, recipient.name);
    text = text.replace(/{school_name}/g, recipient.school_name);

    logMessage(`[${idx + 1}/${metrics.value.total}] Mengirim pesan ke ${recipient.name} (${recipient.phone_number})...`, 'info');

    try {
      const res = await SuperAdminBroadcastService.sendBroadcast(recipient.phone_number, text);
      if (res.success) {
        metrics.value.success++;
        logMessage(`[SUCCESS] Berhasil dikirim ke ${recipient.name} - ${recipient.school_name} (${recipient.phone_number}).`, 'success');
      } else {
        metrics.value.failed++;
        logMessage(`[ERROR] Gagal mengirim ke ${recipient.name}: ${res.message}`, 'error');
      }
    } catch (e) {
      metrics.value.failed++;
      logMessage(`[ERROR] Gagal mengirim ke ${recipient.name}: ${(e as Error).message}`, 'error');
    }

    metrics.value.currentIndex++;

    // Enforce throttle delay if not at the end
    if (metrics.value.currentIndex < metrics.value.total && status.value === 'sending') {
      logMessage(`Menunggu jeda pengiriman ${sendDelay.value} detik...`, 'info');
      await new Promise((resolve) => setTimeout(resolve, sendDelay.value * 1000));
    }
  }

  if (metrics.value.currentIndex >= metrics.value.total) {
    status.value = 'completed';
    logMessage(`Pengiriman pesan broadcast selesai. Sukses: ${metrics.value.success}, Gagal: ${metrics.value.failed}`, 'success');
  }
}

function pauseBroadcast() {
  status.value = 'paused';
  logMessage('Broadcast dijeda oleh administrator.', 'warn');
}

function stopAndReset() {
  status.value = 'idle';
  resetMetrics();
  logs.value = [];
  logMessage('Broadcast dihentikan dan seluruh log direset.', 'info');
}

const progressPercent = computed(() => {
  if (metrics.value.total === 0) return 0;
  return Math.round((metrics.value.currentIndex / metrics.value.total) * 100);
});
</script>

<template>
  <div class="space-y-5 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="t('superAdmin.kicker')"
      :title="t('superAdmin.broadcast.title')"
      :meta="t('superAdmin.broadcast.subtitle')"
    />

    <!-- CORE BROADCAST HUB CONTAINER -->
    <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
      <!-- CONFIGURATION SECTION (LEFT) -->
      <div class="lg:col-span-7 bg-white border border-slate-200 rounded-card p-6 shadow-card space-y-6">
        <h3 class="text-sm font-bold text-slate-800 flex items-center gap-2 border-b border-slate-100 pb-3">
          <NavIcon name="settings" class="text-brand" :size="16" />
          Konfigurasi Broadcast
        </h3>

        <!-- RECIPIENT MODE SELECTOR -->
        <div class="space-y-2">
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wide">
            {{ t('superAdmin.broadcast.form.targetType') }}
          </label>
          <div class="grid grid-cols-2 gap-3">
            <button
              type="button"
              class="flex items-center justify-center gap-2 rounded-xl py-3 text-xs font-bold border transition"
              :class="
                targetType === 'manual'
                  ? 'bg-role-admin-soft text-role-admin border-role-admin/35 shadow-sm'
                  : 'bg-slate-50 text-slate-500 border-slate-200 hover:bg-slate-100'
              "
              @click="targetType = 'manual'"
            >
              <NavIcon name="edit-2" :size="14" />
              {{ t('superAdmin.broadcast.form.manual') }}
            </button>
            <button
              type="button"
              class="flex items-center justify-center gap-2 rounded-xl py-3 text-xs font-bold border transition"
              :class="
                targetType === 'school_admins'
                  ? 'bg-role-admin-soft text-role-admin border-role-admin/35 shadow-sm'
                  : 'bg-slate-50 text-slate-500 border-slate-200 hover:bg-slate-100'
              "
              @click="targetType = 'school_admins'"
            >
              <NavIcon name="school" :size="14" />
              {{ t('superAdmin.broadcast.form.schoolAdmins') }}
            </button>
          </div>
        </div>

        <!-- RECIPIENTS DETAILS -->
        <div v-show="targetType === 'manual'" class="space-y-2">
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wide">
            Daftar Nomor WhatsApp
          </label>
          <textarea
            v-model="manualNumbersText"
            :placeholder="t('superAdmin.broadcast.form.manualPlaceholder')"
            rows="4"
            class="w-full text-xs border border-slate-200 rounded-xl px-3.5 py-3 focus:outline-none focus:ring-1 focus:ring-brand font-mono leading-relaxed"
          ></textarea>
        </div>

        <div v-show="targetType === 'school_admins'" class="space-y-3">
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wide">
            Pilih Sekolah Target
          </label>

          <!-- Search list mapping -->
          <div class="border border-slate-200 rounded-xl overflow-hidden bg-slate-50">
            <div class="p-3 bg-white border-b border-slate-200 flex gap-2 items-center">
              <div class="relative flex-1">
                <input
                  v-model="schoolSearch"
                  type="text"
                  :placeholder="t('superAdmin.broadcast.form.schoolSelectPlaceholder')"
                  class="w-full text-xs border border-slate-200 rounded-lg pl-8 pr-3 py-1.5 focus:outline-none focus:ring-1 focus:ring-brand"
                />
                <div class="absolute left-2.5 top-2.5 text-slate-400">
                  <NavIcon name="search" :size="12" />
                </div>
              </div>
              <button
                type="button"
                @click="toggleAllSchools"
                class="text-[10px] font-bold text-role-admin hover:underline whitespace-nowrap"
              >
                {{ allSchoolsSelected ? 'Kosongkan Semua' : 'Pilih Semua' }}
              </button>
            </div>
            
            <div class="max-h-40 overflow-y-auto p-2 space-y-1">
              <div
                v-for="school in filteredSchools"
                :key="school.id"
                class="flex items-center gap-2 px-2 py-1.5 hover:bg-slate-100 rounded-lg transition"
              >
                <input
                  type="checkbox"
                  :id="'school-' + school.id"
                  :value="school.activated_school_id"
                  v-model="selectedSchoolIds"
                  class="rounded text-brand focus:ring-brand w-3.5 h-3.5 cursor-pointer"
                />
                <label
                  :for="'school-' + school.id"
                  class="text-xs text-slate-700 font-medium cursor-pointer select-none truncate flex-1"
                >
                  {{ school.school_summary.name }}
                  <span class="text-[10px] text-slate-400">({{ school.school_summary.city }})</span>
                </label>
              </div>
              <div v-if="filteredSchools.length === 0" class="text-center py-6 text-slate-400 text-xs">
                Tidak ada sekolah ditemukan.
              </div>
            </div>
          </div>

          <!-- Resolve Action -->
          <div class="flex items-center justify-between gap-4 bg-slate-50 p-3 rounded-xl border border-slate-100">
            <span class="text-xs text-slate-500 font-medium">
              {{ selectedSchoolIds.length }} sekolah terpilih.
              <span v-if="resolvedRecipients.length > 0" class="text-emerald-600 font-bold block">
                {{ t('superAdmin.broadcast.form.resolvedCount', { count: resolvedRecipients.length }) }}
              </span>
            </span>
            <button
              type="button"
              class="inline-flex items-center gap-1.5 rounded-xl bg-role-admin px-3.5 py-2 text-xs font-bold text-white hover:bg-slate-800 transition shadow-sm disabled:opacity-50"
              :disabled="selectedSchoolIds.length === 0 || isResolving"
              @click="handleResolveRecipients"
            >
              <NavIcon v-if="isResolving" name="refresh-cw" class="animate-spin" :size="13" />
              <NavIcon v-else name="users" :size="13" />
              {{ t('superAdmin.broadcast.form.resolveButton') }}
            </button>
          </div>
        </div>

        <!-- MESSAGE CONTENT BUILDER -->
        <div class="space-y-2">
          <div class="flex justify-between items-center">
            <label class="text-xs font-bold text-slate-500 uppercase tracking-wide">
              {{ t('superAdmin.broadcast.form.messageLabel') }}
            </label>
            <!-- Variables tags -->
            <div class="flex gap-1.5">
              <button
                type="button"
                class="bg-slate-100 hover:bg-slate-200 text-slate-600 px-2 py-0.5 rounded text-[10px] font-bold border border-slate-200 transition"
                @click="insertPlaceholder('{name}')"
              >
                + {Nama}
              </button>
              <button
                type="button"
                class="bg-slate-100 hover:bg-slate-200 text-slate-600 px-2 py-0.5 rounded text-[10px] font-bold border border-slate-200 transition"
                @click="insertPlaceholder('{school_name}')"
              >
                + {Sekolah}
              </button>
            </div>
          </div>
          <textarea
            ref="templateTextarea"
            v-model="messageTemplate"
            :placeholder="t('superAdmin.broadcast.form.messagePlaceholder')"
            rows="5"
            class="w-full text-xs border border-slate-200 rounded-xl px-3.5 py-3 focus:outline-none focus:ring-1 focus:ring-brand leading-relaxed"
          ></textarea>
          <div class="flex justify-between items-center text-[10px] text-slate-400">
            <span>Dynamic replace placeholder: <code class="font-mono bg-slate-100 px-1 py-0.5 rounded">{name}</code>, <code class="font-mono bg-slate-100 px-1 py-0.5 rounded">{school_name}</code></span>
            <span>{{ messageTemplate.length }} karakter</span>
          </div>
        </div>

        <!-- DELAY CONTROL -->
        <div class="space-y-2">
          <div class="flex justify-between items-center text-xs font-bold text-slate-500 uppercase tracking-wide">
            <span>{{ t('superAdmin.broadcast.form.delayLabel') }}</span>
            <span class="text-brand font-mono">{{ sendDelay }}s</span>
          </div>
          <input
            v-model.number="sendDelay"
            type="range"
            min="1"
            max="10"
            step="1"
            class="w-full h-1.5 bg-slate-100 rounded-lg appearance-none cursor-pointer accent-brand"
          />
          <p class="text-[10px] text-slate-400">
            Jeda antarpengiriman pesan WhatsApp untuk menghindari deteksi spam dari gateway WhatsApp.
          </p>
        </div>
      </div>

      <!-- PROGRESS & LOGGER CONSOLE (RIGHT) -->
      <div class="lg:col-span-5 flex flex-col gap-6">
        <!-- STATUS & METRICS -->
        <div class="bg-white border border-slate-200 rounded-card p-6 shadow-card space-y-5">
          <div class="flex justify-between items-center border-b border-slate-100 pb-3">
            <h3 class="text-sm font-bold text-slate-800 flex items-center gap-2">
              <NavIcon name="activity" class="text-brand" :size="16" />
              {{ t('superAdmin.broadcast.progress.status') }}
            </h3>

            <!-- State pill -->
            <span
              class="text-[10px] font-bold uppercase tracking-wide px-2.5 py-0.5 rounded-full border"
              :class="
                status === 'sending'
                  ? 'bg-blue-50 text-blue-700 border-blue-200'
                  : status === 'paused'
                  ? 'bg-amber-50 text-amber-700 border-amber-200'
                  : status === 'completed'
                  ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                  : 'bg-slate-100 text-slate-500 border-slate-200'
              "
            >
              {{
                status === 'sending'
                  ? t('superAdmin.broadcast.progress.sending')
                  : status === 'paused'
                  ? t('superAdmin.broadcast.progress.paused')
                  : status === 'completed'
                  ? t('superAdmin.broadcast.progress.completed')
                  : t('superAdmin.broadcast.progress.idle')
              }}
            </span>
          </div>

          <!-- Progress bar -->
          <div class="space-y-1">
            <div class="flex justify-between text-xs font-bold text-slate-700">
              <span>Progress</span>
              <span>{{ progressPercent }}%</span>
            </div>
            <div class="w-full bg-slate-100 rounded-full h-2">
              <div
                class="bg-brand h-2 rounded-full transition-all duration-300"
                :style="{ width: progressPercent + '%' }"
              ></div>
            </div>
          </div>

          <!-- Metrics grid -->
          <div class="grid grid-cols-4 gap-2 text-center">
            <div class="bg-slate-50 rounded-xl p-2.5 border border-slate-100">
              <span class="text-[10px] text-slate-400 block font-bold uppercase tracking-wider">
                Total
              </span>
              <span class="text-lg font-bold text-slate-800 tabular-nums">
                {{ metrics.total }}
              </span>
            </div>
            <div class="bg-slate-50 rounded-xl p-2.5 border border-slate-100">
              <span class="text-[10px] text-slate-400 block font-bold uppercase tracking-wider">
                Proses
              </span>
              <span class="text-lg font-bold text-slate-800 tabular-nums">
                {{ metrics.currentIndex }}
              </span>
            </div>
            <div class="bg-emerald-50/50 rounded-xl p-2.5 border border-emerald-100/50">
              <span class="text-[10px] text-emerald-600/70 block font-bold uppercase tracking-wider">
                Sukses
              </span>
              <span class="text-lg font-bold text-emerald-600 tabular-nums">
                {{ metrics.success }}
              </span>
            </div>
            <div class="bg-rose-50/50 rounded-xl p-2.5 border border-rose-100/50">
              <span class="text-[10px] text-rose-600/70 block font-bold uppercase tracking-wider">
                Gagal
              </span>
              <span class="text-lg font-bold text-rose-600 tabular-nums">
                {{ metrics.failed }}
              </span>
            </div>
          </div>

          <!-- ACTION BUTTON CONTROLS -->
          <div class="flex gap-2">
            <!-- Start / Resume / Pause toggle -->
            <button
              v-if="status !== 'sending'"
              type="button"
              class="flex-1 bg-role-admin text-white text-xs font-bold rounded-xl py-3 hover:bg-slate-800 transition shadow-sm flex items-center justify-center gap-2"
              @click="startBroadcast"
            >
              <NavIcon name="play" :size="14" />
              {{ status === 'paused' ? 'Lanjutkan' : t('superAdmin.broadcast.form.sendButton') }}
            </button>
            <button
              v-else
              type="button"
              class="flex-1 bg-amber-500 text-white text-xs font-bold rounded-xl py-3 hover:bg-amber-600 transition shadow-sm flex items-center justify-center gap-2"
              @click="pauseBroadcast"
            >
              <NavIcon name="pause" :size="14" />
              {{ t('superAdmin.broadcast.form.stopButton') }}
            </button>

            <!-- Reset -->
            <button
              type="button"
              class="bg-slate-100 text-slate-600 border border-slate-200 text-xs font-bold rounded-xl px-4 py-3 hover:bg-slate-200 transition"
              @click="stopAndReset"
            >
              Reset
            </button>
          </div>
        </div>

        <!-- TERMINAL SIMULATOR FOR LOGS -->
        <div class="bg-slate-900 border border-slate-800 rounded-card p-5 shadow-card flex flex-col flex-1 min-h-[300px]">
          <div class="flex justify-between items-center border-b border-slate-800 pb-2 mb-3">
            <span class="text-xs font-bold text-slate-400 font-mono flex items-center gap-1.5">
              <span class="w-2.5 h-2.5 rounded-full bg-red-500 inline-block"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-yellow-500 inline-block"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-green-500 inline-block"></span>
              Terminal Output
            </span>
            <span class="text-[10px] text-slate-500 font-mono">Live</span>
          </div>

          <div
            ref="consoleRef"
            class="flex-1 overflow-y-auto font-mono text-[10px] leading-relaxed space-y-1.5 select-text h-64 pr-2 custom-scrollbar bg-slate-950/80 p-3 rounded-lg border border-slate-800/80"
          >
            <div v-for="(log, idx) in logs" :key="idx" :class="getLogClass(log)" class="break-words">
              {{ log }}
            </div>
            <div v-if="logs.length === 0" class="text-slate-500 italic py-12 text-center">
              {{ t('superAdmin.broadcast.progress.noLogs') }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Monospace custom scrollbar styling */
.custom-scrollbar::-webkit-scrollbar {
  width: 5px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background: #334155;
  border-radius: 9999px;
}
.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: #475569;
}
</style>
