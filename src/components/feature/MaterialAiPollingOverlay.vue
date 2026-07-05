<!--
  MaterialAiPollingOverlay.vue — fullscreen modal shown while the
  kamiledu-ai service generates material content.

  Mirrors Flutter's `material_ai_polling_view.dart`:
    • Centered spinner + soft pulse
    • Rotating status messages every ~2s
        ("Membaca silabus…", "Merangkum materi…", "Menyusun kuis…",
         "Mencari referensi…", "Hampir selesai…")
    • Elapsed-time chip ("00:32 dari ~01:00")
    • Subtle cancel link bottom-right (closes overlay; caller decides
      whether to abort the poll loop)

  Visual is intentionally calm — generation can take 30-60s and
  flashy loaders feel anxious. Slate-900 backdrop with cobalt accent.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

interface Props {
  /** Modal visible. Caller uses v-if to mount only when polling. */
  visible: boolean;
  /** Display title — defaults to "Memproses Materi AI". */
  title?: string;
  /** Subtitle — context line ("Bab 3 · Energi & Perubahannya"). */
  subtitle?: string;
  /** ETA in seconds. Drives the "estimasi ~01:00" chip. */
  estimatedSeconds?: number;
  /** When true, hides the cancel link (when batch can't cancel). */
  hideCancel?: boolean;
  /**
   * Caller-driven timeout state. When the polling loop exceeds the
   * deadline, the caller flips this to true (instead of unmounting
   * the overlay) so the user sees an in-place Retry / Tutup choice
   * rather than a vanishing modal + disposable toast.
   */
  timedOut?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  estimatedSeconds: 60,
  hideCancel: false,
  timedOut: false,
});

const emit = defineEmits<{ cancel: []; retry: [] }>();

// ── Rotating status messages ──
//
// Same vocabulary as Flutter's polling view so a teacher who uses
// both apps sees the same wording.
const STATUS_MESSAGES = [
  'Membaca silabus dan konteks…',
  'Merangkum materi…',
  'Menyusun kuis pilihan ganda…',
  'Membuat soal esai…',
  'Mencari referensi pendukung…',
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
  // Cycle status messages every 2.5s — long enough to read but not
  // sluggish. Once we hit the last message we stay there until the
  // caller closes the overlay.
  messageTimer = setInterval(() => {
    if (messageIdx.value < STATUS_MESSAGES.length - 1) {
      messageIdx.value += 1;
    }
  }, 2500);
  // 1Hz elapsed-time counter for the chip.
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

// Re-arm timers when the overlay re-shows without unmounting.
// Caller pattern: <MaterialAiPollingOverlay v-if="busy" ... /> so
// this watcher is usually a no-op, but guards against parents
// using :visible toggle instead.
import { watch } from 'vue';
watch(
  () => props.visible,
  (next) => {
    if (next && !props.timedOut) startTimers();
    else stopTimers();
  },
);

// Freeze the elapsed counter the moment the caller flips into the
// timeout state — keeps the displayed elapsed time stable so users
// can read "01:32" without it ticking past while they decide whether
// to retry.
watch(
  () => props.timedOut,
  (next) => {
    if (next) stopTimers();
    else if (props.visible) startTimers();
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
  // Cap at 95% so the bar never claims "done" before the poll
  // resolves — the caller flips to closed once the material lands.
  return Math.min(95, Math.round((elapsedSec.value / props.estimatedSeconds) * 100));
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="fixed inset-0 z-[60] bg-slate-900/70 backdrop-blur-sm flex items-center justify-center p-4"
    >
      <div
        class="w-full max-w-md bg-white rounded-3xl shadow-2xl overflow-hidden"
      >
        <div class="relative px-6 pt-7 pb-5 bg-gradient-to-br from-brand-cobalt to-violet-700 text-white">
          <!-- Pulse halo around spinner -->
          <div class="relative mx-auto w-16 h-16 flex items-center justify-center">
            <span
              class="absolute inset-0 rounded-full bg-white/15 animate-ping"
            />
            <span
              class="absolute inset-2 rounded-full bg-white/25 animate-pulse"
            />
            <NavIcon name="sparkles" :size="28" class="relative z-10" />
          </div>
          <p class="text-center text-3xs uppercase tracking-widest font-bold mt-3 text-white/70">
            AI Bekerja
          </p>
          <h2 class="text-center text-lg font-black mt-1">
            {{ title ?? 'Memproses Materi AI' }}
          </h2>
          <p
            v-if="subtitle"
            class="text-center text-[12px] text-white/80 mt-1 line-clamp-1 px-4"
          >
            {{ subtitle }}
          </p>
        </div>

        <!-- ── Active polling body ── -->
        <template v-if="!timedOut">
          <div class="px-6 pt-5 pb-4 space-y-4">
            <!-- Live status line -->
            <div class="text-center">
              <p class="text-[14px] font-semibold text-slate-900 transition-opacity duration-300">
                {{ status }}
              </p>
              <p class="text-2xs text-slate-400 mt-1 tabular-nums">
                {{ elapsedLabel }} dari estimasi {{ etaLabel }}
              </p>
            </div>

            <!-- Progress strip -->
            <div class="h-1.5 rounded-full overflow-hidden bg-slate-100">
              <div
                class="h-full bg-gradient-to-r from-brand-cobalt to-violet-600 transition-all duration-500"
                :style="{ width: `${progressPct}%` }"
              />
            </div>

            <!-- Reassurance / step list -->
            <ul class="space-y-1.5 text-2xs text-slate-600">
              <li class="flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 flex-shrink-0" />
                Hasil tersimpan otomatis saat selesai
              </li>
              <li class="flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 flex-shrink-0" />
                Aman untuk tinggalkan halaman ini
              </li>
              <li class="flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0" />
                Periksa & edit hasil di tab Materi / Kuis / Referensi
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
        </template>

        <!-- ── Timeout body ── -->
        <template v-else>
          <div class="px-6 pt-5 pb-4 space-y-3">
            <div class="text-center">
              <p class="text-[14px] font-bold text-amber-700">
                Generasi memakan waktu lebih lama dari biasanya
              </p>
              <p class="text-[12px] text-slate-500 mt-1.5 leading-relaxed">
                AI belum mengembalikan hasil setelah
                <span class="tabular-nums font-bold text-slate-700">{{ elapsedLabel }}</span>.
                Jaringan AI mungkin sedang sibuk — coba ulangi sebentar
                lagi atau tutup dan periksa hasil di tab materi nanti.
              </p>
            </div>
            <ul class="space-y-1.5 text-2xs text-slate-600 mt-2 bg-amber-50 border border-amber-200 rounded-xl p-3">
              <li class="flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0" />
                Hasil yang sebelumnya tersimpan tidak hilang
              </li>
              <li class="flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0" />
                Coba ulangi atau refresh halaman ini setelah beberapa menit
              </li>
            </ul>
          </div>
          <footer class="px-6 py-3 border-t border-slate-100 flex justify-end gap-2">
            <button
              type="button"
              class="px-3 py-1.5 rounded-lg text-[12px] font-bold text-slate-600 hover:bg-slate-100 transition"
              @click="emit('cancel')"
            >
              Tutup
            </button>
            <button
              type="button"
              class="px-3 py-1.5 rounded-lg text-[12px] font-bold bg-brand-cobalt text-white hover:bg-brand-cobalt/90 transition inline-flex items-center gap-1.5"
              @click="emit('retry')"
            >
              <NavIcon name="refresh-cw" :size="12" />
              Coba lagi
            </button>
          </footer>
        </template>
      </div>
    </div>
  </Teleport>
</template>
