<!--
  DemoResetProgress.vue — full-viewport blocking screen shown while a
  demo school is being reset (delete + re-provision = ~30-120s).

  Why a takeover and not a modal:
    - Reset is a multi-step server operation (delete cascade, fresh
      provision, scenario seeding) that we measure in seconds, not
      milliseconds. A modal feels dismissable; an operator could close
      the tab and end up wondering whether their data is half-wiped.
    - The takeover signals "this is a session-level operation" and
      also gives us the room to show the user WHAT is happening (the
      step list) instead of one anonymous spinner.
    - We also intercept beforeunload while active so a refresh / back
      button doesn't kill the request mid-seed.

  Why client-side stepped progress (and not a backend stream):
    - ProvisionDemoSchoolAction runs as one long DB transaction; it
      doesn't currently emit phase events. Wiring SSE / polling would
      be a meaningful backend MR for cosmetic value.
    - Most apps (Linear, Stripe, Vercel) do exactly this — show a
      believable stepped timeline that completes when the HTTP request
      resolves. The wall-clock truth comes from the actual response.
    - The component caps animation at the last phase if the response
      is slower than the timer; if the response is faster than the
      timer, we hard-jump to "Hampir selesai…" and resolve.

  Parent contract:
    - Mount the component while the API call is in flight; unmount it
      when the call resolves (the parent does logout + redirect).
    - Pass `:active="true"` to start the animation + register the
      beforeunload guard.
    - When done (success or fail), parent flips `:active` to false to
      tear down — the component animates to 100% as it unmounts.

  Accessibility:
    - role="dialog" + aria-modal so screen-readers announce takeover.
    - aria-live="polite" on the status line so the current phase is
      narrated when it changes.
-->
<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue';

const props = defineProps<{
  /** True while the reset request is in flight. */
  active: boolean;
  /** Display name of the demo school being reset (header chip). */
  schoolName?: string | null;
  /**
   * Optional override for total expected seconds. Defaults to 60 —
   * the median we've observed across small/medium demos. The component
   * holds at "almost done" if the HTTP response outlives the budget.
   */
  expectedSeconds?: number;
}>();

/**
 * The 5 phases the user sees. Wall-clock durations roughly mirror
 * ProvisionDemoSchoolAction's internal stages so the steps feel
 * truthful even though we're not reading server events. The last
 * phase ("Hampir selesai…") is the holding pen — we stay there until
 * the parent unmounts us.
 */
type Phase = {
  key: string;
  title: string;
  /** seconds the phase is "running" before it ticks done */
  dur: number;
};
const PHASES: Phase[] = [
  { key: 'wipe', title: 'Membersihkan data lama', dur: 10 },
  { key: 'school', title: 'Membangun struktur sekolah & tahun ajaran', dur: 8 },
  { key: 'roster', title: 'Menyiapkan roster guru & siswa', dur: 22 },
  { key: 'schedule', title: 'Menyusun jadwal & mata pelajaran', dur: 12 },
  { key: 'scenarios', title: 'Mengisi skenario demo (nilai, kehadiran, RPP…)', dur: 8 },
];

const elapsed = ref(0); // seconds since active flipped on
let intervalId: number | null = null;

function startTimer() {
  if (intervalId !== null) return;
  intervalId = window.setInterval(() => {
    elapsed.value += 1;
  }, 1000);
}

function stopTimer() {
  if (intervalId === null) return;
  window.clearInterval(intervalId);
  intervalId = null;
}

watch(
  () => props.active,
  (a) => {
    if (a) {
      elapsed.value = 0;
      startTimer();
    } else {
      stopTimer();
    }
  },
  { immediate: true },
);

/**
 * Block tab close / refresh / navigation while a reset is in flight.
 * We do NOT add the listener unless active to avoid annoying the user
 * during normal page life.
 */
function beforeUnloadHandler(e: BeforeUnloadEvent) {
  e.preventDefault();
  // Most browsers ignore the returned message and show their own,
  // but assigning is required for the prompt to appear at all.
  e.returnValue = '';
}

watch(
  () => props.active,
  (a) => {
    if (a) {
      window.addEventListener('beforeunload', beforeUnloadHandler);
    } else {
      window.removeEventListener('beforeunload', beforeUnloadHandler);
    }
  },
  { immediate: true },
);

onMounted(() => {
  if (props.active) {
    startTimer();
    window.addEventListener('beforeunload', beforeUnloadHandler);
  }
});

onBeforeUnmount(() => {
  stopTimer();
  window.removeEventListener('beforeunload', beforeUnloadHandler);
});

/**
 * Compute which phase is currently active and which are done. The
 * mapping is a cumulative-sum walk — phase i is "running" iff
 * elapsed has crossed the end of phase i-1 but not the end of i.
 * Cap the active phase at PHASES.length-1 so "Hampir selesai…" holds
 * indefinitely when the API outlives the timer budget.
 */
const phaseStates = computed(() => {
  let acc = 0;
  let activeIdx = PHASES.length - 1;
  for (let i = 0; i < PHASES.length; i += 1) {
    acc += PHASES[i].dur;
    if (elapsed.value < acc) {
      activeIdx = i;
      break;
    }
  }
  return PHASES.map((p, i) => ({
    ...p,
    state:
      i < activeIdx ? 'done'
      : i === activeIdx ? 'active'
      : 'pending',
    // How long this phase ran (for the "Ns" label on done rows).
    elapsedAtEnd:
      i < activeIdx
        ? PHASES.slice(0, i + 1).reduce((s, x) => s + x.dur, 0)
        : null,
  }));
});

const currentPhase = computed(
  () => phaseStates.value.find((p) => p.state === 'active') ?? phaseStates.value[phaseStates.value.length - 1],
);

const doneCount = computed(
  () => phaseStates.value.filter((p) => p.state === 'done').length,
);

const totalBudget = computed(
  () => props.expectedSeconds ?? PHASES.reduce((s, p) => s + p.dur, 0),
);

/**
 * Percentage shown in the centre of the ring. Caps at 95% while we
 * wait on the API — only the parent flipping `active` to false (via
 * unmount on success) takes us visually to 100%, which prevents the
 * "stuck at 100%" effect that makes UIs feel broken.
 */
const percent = computed(() => {
  const pct = Math.round((elapsed.value / totalBudget.value) * 100);
  return Math.min(95, Math.max(0, pct));
});

const remainingLabel = computed(() => {
  const remaining = Math.max(0, totalBudget.value - elapsed.value);
  if (remaining < 1) return 'Hampir selesai…';
  return `Estimasi ~${remaining} detik tersisa`;
});

// Ring stroke offset — circumference 264 for r=42.
const RING_CIRC = 264;
const ringDashOffset = computed(
  () => RING_CIRC - (RING_CIRC * percent.value) / 100,
);
</script>

<template>
  <Teleport to="body">
    <div
      v-if="active"
      role="dialog"
      aria-modal="true"
      aria-labelledby="demo-reset-progress-title"
      class="fixed inset-0 z-[60] bg-slate-50 flex flex-col"
    >
      <!-- Header chrome -->
      <header class="bg-white border-b border-slate-200">
        <div class="max-w-3xl mx-auto px-6 py-3 flex items-center gap-3">
          <div class="w-8 h-8 rounded-lg bg-brand-dark-blue text-white text-sm font-black grid place-items-center flex-shrink-0">K</div>
          <div class="flex-1 min-w-0">
            <p id="demo-reset-progress-title" class="text-[12.5px] font-bold text-slate-900 leading-tight">
              KamilEdu · Reset Data Demo
            </p>
            <p class="text-[11px] text-slate-500 truncate">
              {{ schoolName || 'Sekolah demo' }}
            </p>
          </div>
          <span class="text-[11px] text-slate-400 inline-flex items-center gap-1">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>
            Sesi terkunci
          </span>
        </div>
      </header>

      <!-- Main -->
      <main class="flex-1 flex items-center justify-center px-6 py-8 overflow-y-auto">
        <div class="w-full max-w-md flex flex-col items-center">
          <!-- Big circular progress -->
          <div class="relative w-24 h-24 mb-4">
            <svg viewBox="0 0 100 100" class="w-full h-full -rotate-90" aria-hidden="true">
              <circle cx="50" cy="50" r="42" fill="none" stroke="#E2E8F0" stroke-width="6"></circle>
              <circle
                cx="50"
                cy="50"
                r="42"
                fill="none"
                stroke="#185FA5"
                stroke-width="6"
                stroke-linecap="round"
                :stroke-dasharray="RING_CIRC"
                :stroke-dashoffset="ringDashOffset"
                style="transition: stroke-dashoffset 0.6s ease;"
              ></circle>
            </svg>
            <div class="absolute inset-0 flex flex-col items-center justify-center">
              <span class="text-[22px] font-black text-slate-900 leading-none tabular-nums">{{ percent }}%</span>
              <span class="text-[10px] text-slate-400 mt-0.5">{{ doneCount }} dari {{ PHASES.length }}</span>
            </div>
          </div>

          <!-- Status line -->
          <p
            class="text-[16px] font-bold text-slate-900 text-center"
            aria-live="polite"
          >
            {{ currentPhase.title }}
          </p>
          <div class="mt-2 inline-flex items-center gap-1.5 px-3 py-1 bg-slate-100 rounded-full">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" class="text-slate-400"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15 14"/></svg>
            <span class="text-[12px] text-slate-600 tabular-nums">{{ remainingLabel }}</span>
          </div>

          <!-- Step list -->
          <ul class="mt-6 w-full space-y-2">
            <li
              v-for="(p, i) in phaseStates"
              :key="p.key"
              class="flex items-center gap-3 px-2.5 py-2 rounded-lg"
              :class="{
                'bg-slate-100': p.state === 'done',
                'bg-blue-50 border border-blue-200': p.state === 'active',
                'border border-dashed border-slate-200': p.state === 'pending',
              }"
            >
              <span
                class="w-[22px] h-[22px] rounded-full grid place-items-center flex-shrink-0"
                :class="{
                  'bg-emerald-500 text-white': p.state === 'done',
                  'bg-brand-dark-blue text-white': p.state === 'active',
                  'bg-slate-100 text-slate-400': p.state === 'pending',
                }"
              >
                <svg
                  v-if="p.state === 'done'"
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <polyline points="20 6 9 17 4 12"/>
                </svg>
                <svg
                  v-else-if="p.state === 'active'"
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  class="animate-spin"
                >
                  <circle cx="12" cy="12" r="9" stroke="white" stroke-width="3" stroke-opacity="0.35"/>
                  <path d="M21 12a9 9 0 0 1-9 9" stroke="white" stroke-width="3" stroke-linecap="round"/>
                </svg>
                <span v-else class="text-[10px] font-bold">{{ i + 1 }}</span>
              </span>
              <span
                class="flex-1 text-[12.5px] leading-snug"
                :class="{
                  'text-slate-600': p.state === 'done',
                  'font-bold text-blue-900': p.state === 'active',
                  'text-slate-400': p.state === 'pending',
                }"
              >{{ p.title }}</span>
              <span
                v-if="p.state === 'done'"
                class="text-[11px] text-slate-400 tabular-nums"
              >{{ p.elapsedAtEnd }}s</span>
              <span
                v-else-if="p.state === 'active'"
                class="text-[11px] text-blue-700"
              >berjalan…</span>
            </li>
          </ul>

          <!-- Reassurance bar -->
          <div class="mt-5 w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl flex justify-center gap-5 flex-wrap">
            <span class="inline-flex items-center gap-1.5 text-[11.5px] text-slate-600">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
              Login Anda tetap aman
            </span>
            <span class="inline-flex items-center gap-1.5 text-[11.5px] text-slate-600">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 22h14"/><path d="M5 2h14"/><path d="M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22"/><path d="M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2"/></svg>
              Masa aktif demo tidak berubah
            </span>
          </div>
        </div>
      </main>

      <!-- Footer warning -->
      <footer class="bg-slate-100 border-t border-slate-200 px-6 py-2.5 flex items-center gap-2">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#b45309" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" class="flex-shrink-0"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        <span class="text-[11.5px] text-slate-600 flex-1">
          Mohon jangan tutup tab atau muat ulang halaman selama proses berjalan.
        </span>
      </footer>
    </div>
  </Teleport>
</template>
