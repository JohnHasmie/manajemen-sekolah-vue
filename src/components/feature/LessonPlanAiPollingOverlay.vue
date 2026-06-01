<!--
  LessonPlanAiPollingOverlay.vue — fullscreen overlay shown while the
  kamiledu-ai service generates a lesson plan.

  Same shape as MaterialAiPollingOverlay but RPP-flavored copy
  (sections are different: tujuan / kegiatan / penilaian instead of
  kuis / referensi). Status messages cycle every 2.5s; elapsed
  counter shows mm:ss.

  Caller wires this with v-if="busy" so the overlay only mounts
  during the polling loop. The "Tutup & lanjut nanti" link emits
  `cancel` — the parent decides whether to abort the poll timer.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    /** Overlay visible. Use v-if upstream so timers reset cleanly. */
    visible: boolean;
    /** Display title — defaults to "Memproses RPP AI". */
    title?: string;
    /** Subtitle — context line ("K13 · Bab 3 · Energi"). */
    subtitle?: string;
    /** ETA in seconds. Drives the "estimasi ~00:45" chip. */
    estimatedSeconds?: number;
    /** When true, hides the cancel link. */
    hideCancel?: boolean;
  }>(),
  { estimatedSeconds: 45, hideCancel: false },
);

const emit = defineEmits<{ cancel: [] }>();

// RPP-specific status copy. Same cadence as Materi (~2.5s).
const STATUS_MESSAGES = [
  'Membaca silabus & konteks…',
  'Menyusun identitas RPP…',
  'Merancang kompetensi & indikator…',
  'Menulis tujuan pembelajaran…',
  'Merancang langkah kegiatan…',
  'Menyusun penilaian…',
  'Memoles hasil akhir…',
  'Hampir selesai…',
];

const messageIdx = ref(0);
const elapsedSec = ref(0);
let messageTimer: ReturnType<typeof setInterval> | null = null;
let elapsedTimer: ReturnType<typeof setInterval> | null = null;

function startTimers() {
  stopTimers();
  messageIdx.value = 0;
  elapsedSec.value = 0;
  messageTimer = setInterval(() => {
    if (messageIdx.value < STATUS_MESSAGES.length - 1) {
      messageIdx.value += 1;
    }
  }, 2500);
  elapsedTimer = setInterval(() => {
    elapsedSec.value += 1;
  }, 1000);
}

function stopTimers() {
  if (messageTimer) {
    clearInterval(messageTimer);
    messageTimer = null;
  }
  if (elapsedTimer) {
    clearInterval(elapsedTimer);
    elapsedTimer = null;
  }
}

onMounted(() => {
  if (props.visible) startTimers();
});

onBeforeUnmount(stopTimers);

watch(
  () => props.visible,
  (next) => {
    if (next) startTimers();
    else stopTimers();
  },
);

const status = computed(() => STATUS_MESSAGES[messageIdx.value]);

function fmtTime(sec: number): string {
  const m = Math.floor(sec / 60)
    .toString()
    .padStart(2, '0');
  const s = (sec % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
}

const elapsedLabel = computed(() => fmtTime(elapsedSec.value));
const etaLabel = computed(() => fmtTime(props.estimatedSeconds));

const progressPct = computed(() => {
  if (props.estimatedSeconds <= 0) return 50;
  return Math.min(95, Math.round((elapsedSec.value / props.estimatedSeconds) * 100));
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="fixed inset-0 z-[60] bg-slate-900/70 backdrop-blur-sm flex items-center justify-center p-4"
    >
      <div class="w-full max-w-md bg-white rounded-3xl shadow-2xl overflow-hidden">
        <div
          class="relative px-6 pt-7 pb-5 bg-gradient-to-br from-brand-cobalt to-violet-700 text-white"
        >
          <div class="relative mx-auto w-16 h-16 flex items-center justify-center">
            <span class="absolute inset-0 rounded-full bg-white/15 animate-ping" />
            <span class="absolute inset-2 rounded-full bg-white/25 animate-pulse" />
            <NavIcon name="sparkles" :size="28" class="relative z-10" />
          </div>
          <p class="text-center text-[10px] uppercase tracking-widest font-bold mt-3 text-white/70">
            AI Bekerja
          </p>
          <h2 class="text-center text-lg font-black mt-1">
            {{ title ?? 'Memproses RPP AI' }}
          </h2>
          <p
            v-if="subtitle"
            class="text-center text-[12px] text-white/80 mt-1 line-clamp-1 px-4"
          >
            {{ subtitle }}
          </p>
        </div>

        <div class="px-6 pt-5 pb-4 space-y-4">
          <div class="text-center">
            <p class="text-[14px] font-semibold text-slate-900 transition-opacity duration-300">
              {{ status }}
            </p>
            <p class="text-[11px] text-slate-400 mt-1 tabular-nums">
              {{ elapsedLabel }} dari estimasi {{ etaLabel }}
            </p>
          </div>

          <div class="h-1.5 rounded-full overflow-hidden bg-slate-100">
            <div
              class="h-full bg-gradient-to-r from-brand-cobalt to-violet-600 transition-all duration-500"
              :style="{ width: `${progressPct}%` }"
            />
          </div>

          <ul class="space-y-1.5 text-[11px] text-slate-600">
            <li class="flex items-center gap-2">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 flex-shrink-0" />
              Hasil tersimpan otomatis sebagai Draf
            </li>
            <li class="flex items-center gap-2">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 flex-shrink-0" />
              Aman untuk tinggalkan halaman ini
            </li>
            <li class="flex items-center gap-2">
              <span class="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0" />
              Periksa & edit tiap bagian sebelum kirim ke admin
            </li>
          </ul>
        </div>

        <footer
          v-if="!hideCancel"
          class="px-6 py-3 border-t border-slate-100 flex justify-end"
        >
          <button
            type="button"
            class="text-[12px] font-bold text-slate-500 hover:text-red-600 transition"
            @click="emit('cancel')"
          >
            Tutup &amp; lanjut nanti
          </button>
        </footer>
      </div>
    </div>
  </Teleport>
</template>
