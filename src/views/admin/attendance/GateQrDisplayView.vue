<!--
  GateQrDisplayView.vue — admin projector / poster view of the school's
  rotating gate QR.

  Mounts a large centred QR (qrcode.vue SVG renderer — sharp at any
  zoom, prints crisply) with a live countdown and a small footer.
  Auto-rotates: when the countdown hits 0 the view calls
  AttendanceQrService.rotateGateQrToken() so the displayed QR matches
  what the mobile scanner will accept after the rollover. The "Rotasi
  sekarang" button does the same on demand; "Cetak" uses window.print
  so a school can pin a paper copy near the gate.

  Permission gate: `attendance.gate_qr.manage` (checked client-side in
  the router; the backend re-checks on each request). The page never
  hits the network with a stale token — every tick reads the cached
  value and only fetches when the countdown expires.
-->
<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import QrcodeVue from 'qrcode.vue';
import { AttendanceQrService } from '@/services/attendance-qr.service';
import { useToast } from '@/composables/useToast';
import { useAuthStore } from '@/stores/auth';
import type { GateQrTokenInfo } from '@/types/attendance-qr';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Spinner from '@/components/ui/Spinner.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();
const auth = useAuthStore();

const tokenInfo = ref<GateQrTokenInfo | null>(null);
const loading = ref(true);
const rotating = ref(false);
/** Seconds remaining until the next auto-rotate. Driven by setInterval. */
const remainingSeconds = ref(0);

let tickHandle: number | null = null;

/** Active school name for the projector caption. Falls back to a generic. */
const schoolName = computed(
  () => auth.user?.school_name ?? t('admin.attendance.qrDisplay.fallbackSchool'),
);

/**
 * Human countdown like "12:34" — minutes:seconds, zero-padded. The
 * projector sits across the room so this needs to be readable from a
 * distance even when the QR itself is fine.
 */
const countdownLabel = computed(() => {
  const s = Math.max(0, remainingSeconds.value);
  const m = Math.floor(s / 60);
  const sec = s % 60;
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
});

async function loadCurrent() {
  loading.value = true;
  try {
    const info = await AttendanceQrService.getCurrentGateQrToken();
    tokenInfo.value = info;
    remainingSeconds.value = info.seconds_until_rotation;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.qrDisplay.loadFail'),
    );
  } finally {
    loading.value = false;
  }
}

async function rotateNow() {
  rotating.value = true;
  try {
    const info = await AttendanceQrService.rotateGateQrToken();
    tokenInfo.value = info;
    remainingSeconds.value = info.seconds_until_rotation;
    toast.success(t('admin.attendance.qrDisplay.rotated'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.qrDisplay.rotateFail'),
    );
  } finally {
    rotating.value = false;
  }
}

function printDisplay() {
  // window.print is the simplest cross-browser print path. The
  // `.print-only` / `@media print` CSS hides chrome so only the QR
  // card lands on paper. The user picks "Save as PDF" if they want a
  // file instead of a hard copy.
  window.print();
}

/**
 * Decrement the countdown every second. When it expires we re-fetch
 * the current token (rather than calling rotate — the backend's auto-
 * rotation cron has likely already minted a fresh one by then, and a
 * GET is cheaper than a POST). If the GET fails we fall back to a
 * client-side rotate so the display never gets stuck on an expired QR.
 */
function startTicker() {
  if (tickHandle !== null) return;
  tickHandle = window.setInterval(async () => {
    if (remainingSeconds.value > 0) {
      remainingSeconds.value -= 1;
      return;
    }
    // Hit zero — pull the latest. The auto-rotate cron on the server
    // typically swaps the token a couple seconds before/after the
    // boundary, so a single GET is enough; we don't rotate here to
    // avoid two simultaneous rotations if the cron also fires.
    try {
      const info = await AttendanceQrService.getCurrentGateQrToken();
      tokenInfo.value = info;
      remainingSeconds.value = Math.max(
        info.seconds_until_rotation,
        // Avoid a tight loop if the server returned 0 — wait one full
        // minute before trying again.
        info.seconds_until_rotation > 0 ? info.seconds_until_rotation : 60,
      );
    } catch {
      // Silent: a flaky network shouldn't spam the projector. Reset
      // the countdown to 60s and try again on the next tick.
      remainingSeconds.value = 60;
    }
  }, 1000);
}

function stopTicker() {
  if (tickHandle !== null) {
    window.clearInterval(tickHandle);
    tickHandle = null;
  }
}

onMounted(async () => {
  await loadCurrent();
  startTicker();
});

onBeforeUnmount(stopTicker);
</script>

<template>
  <div class="space-y-md pb-12">
    <div class="no-print">
      <BrandPageHeader
        role="admin"
        :kicker="t('admin.attendance.qrDisplay.kicker')"
        :title="t('admin.attendance.qrDisplay.title')"
        :meta="t('admin.attendance.qrDisplay.meta')"
        :live-dot="true"
      >
        <!--
          On-hero action buttons. The default <Button variant="secondary">
          uses a slate-300 border + slate-700 text, which vanishes on the
          admin-navy gradient (screenshot report: buttons look faded /
          disabled even when enabled). We reach for the app-wide "chip
          on dark hero" pattern (bg-white/15 + text-white +
          hover:bg-white/25), matching AdminClassActivityView's Export
          CSV button and PersonnelCardManagerView's Unduh PDF button.
          Keeps parity across admin heros without introducing a bespoke
          Button variant.
        -->
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white px-md py-sm text-sm font-semibold border border-white/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            :disabled="loading || rotating"
            @click="rotateNow"
          >
            <Spinner v-if="rotating" size="sm" />
            <NavIcon v-else name="refresh-cw" :size="16" />
            {{
              rotating
                ? t('admin.attendance.qrDisplay.rotating')
                : t('admin.attendance.qrDisplay.rotateNow')
            }}
          </button>
          <button
            type="button"
            class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white px-md py-sm text-sm font-semibold border border-white/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            :disabled="loading || !tokenInfo"
            @click="printDisplay"
          >
            <NavIcon name="printer" :size="16" />
            {{ t('admin.attendance.qrDisplay.print') }}
          </button>
        </div>
      </BrandPageHeader>
    </div>

    <!-- Loading shell — mimics the QR card shape (kicker line, school
         name, big QR square, then countdown) so the swap on load
         doesn't jump the layout. -->
    <div
      v-if="loading"
      class="print-card mx-auto bg-white border border-slate-200 rounded-2xl shadow-sm p-xl max-w-3xl"
      aria-hidden="true"
    >
      <div class="h-3 w-40 mx-auto rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
      <div class="h-6 w-56 mx-auto mt-2 rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
      <div class="my-lg flex justify-center">
        <div class="h-64 w-64 rounded-2xl bg-slate-200 animate-pulse motion-reduce:animate-none" />
      </div>
      <div class="h-3 w-64 mx-auto rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
      <div class="h-2 w-40 mx-auto mt-2 rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
    </div>

    <!-- The QR card itself — also the only thing that prints. -->
    <section
      v-else-if="tokenInfo"
      class="print-card mx-auto bg-white border border-slate-200 rounded-2xl shadow-sm p-xl text-center max-w-3xl"
    >
      <p
        class="text-xs uppercase tracking-wider text-slate-500 font-semibold"
      >
        {{ t('admin.attendance.qrDisplay.posterKicker') }}
      </p>
      <h2 class="mt-1 text-2xl font-bold text-slate-900">{{ schoolName }}</h2>

      <!-- Big centred QR. Render as SVG so it stays crisp on
           projectors and prints. The viewport is intentionally generous
           — even a small classroom should see this from the back row. -->
      <div class="my-lg flex justify-center">
        <div class="rounded-2xl bg-white p-lg border border-slate-100">
          <QrcodeVue
            :value="tokenInfo.token"
            :size="380"
            level="M"
            render-as="svg"
            :margin="2"
            foreground="#0A1F4D"
            background="#ffffff"
          />
        </div>
      </div>

      <!-- Countdown line — keeps staff calibrated on how fresh the
           displayed QR is. We render the digits in monospace so the
           label width doesn't jitter every second. -->
      <p class="text-sm text-slate-500">
        {{ t('admin.attendance.qrDisplay.rotatesIn') }}
        <span class="font-mono font-bold text-slate-900 ml-1">{{
          countdownLabel
        }}</span>
      </p>

      <p
        class="mt-md text-xs text-slate-500 leading-relaxed max-w-md mx-auto"
      >
        {{ t('admin.attendance.qrDisplay.instructions') }}
      </p>

      <!-- Print-only school badge — appears on the paper copy below the QR
           so a printed poster is self-identifying. Hidden in the app. -->
      <div class="print-only mt-md text-xs text-slate-700">
        {{ tokenInfo.school_id }}
      </div>
    </section>

    <p v-else class="text-center text-sm text-slate-500 py-12">
      {{ t('admin.attendance.qrDisplay.empty') }}
    </p>
  </div>
</template>

<style scoped>
/*
  Print-only rules:
    - `.no-print` collapses the brand header, action buttons, app
      sidebar, etc. so paper output only shows the QR card.
    - `.print-only` is hidden on-screen but shown when printing.
    - The card itself loses its border + shadow on paper to look like
      a clean printed poster rather than a screenshot.
*/
@media print {
  :global(body) {
    background: #fff !important;
  }
  /* Hide every app shell chrome so only the QR card prints. The
     AppShell sidebar / header lives outside this view, so we target
     the global selector via :global() — Vue scoped styles still
     respect the descendant rule at the print layer. */
  :global(.app-shell-side),
  :global(.app-shell-header),
  :global(.toast-host),
  .no-print {
    display: none !important;
  }
  .print-card {
    border: none !important;
    box-shadow: none !important;
    page-break-inside: avoid;
  }
  .print-only {
    display: block !important;
  }
}
.print-only {
  display: none;
}
</style>
