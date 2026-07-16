<!--
  TeacherCheckInView.vue — teacher self check-in/out (presensi harian teacher).

  One check-in per teaching day + an optional check-out (toggled per
  school by the admin). The teacher:
    1. Bootstraps config (settings + today's schedule + today's state).
    2. Takes a LIVE webcam selfie (face + school background) — enforced
       via getUserMedia; there is NO gallery upload by design (safe v1).
    3. Captures GPS when the school requires location (geofence verified
       server-side via haversine).
    4. Submits multipart check-in/out. The SERVER stamps the timestamps
       and computes present/late + geofence distance.

  AUTOMATIC-FIRST UX (this revision):
    - The moment the capture step is shown, the camera preview AND the
      GPS fix are kicked off IN PARALLEL, so by the time the teacher
      looks the camera is already live and the location is being fetched.
    - It collapses to essentially ONE primary action — "Presensi Masuk"
      / "Presensi Pulang" — which snapshots the live frame and submits in
      a single tap. No separate "Ambil foto" step.
    - Browser reality is handled gracefully: getUserMedia may be blocked
      without a user gesture or denied, and may be unavailable on an
      insecure origin. We auto-try, and on failure show a prominent
      "Nyalakan Kamera" button + targeted Indonesian guidance. Same for
      location (auto-try, retry button, accuracy + approximate hint).
    - Never hard-crashes; degrades per the admin config
      (camera_required / location_required).

  Layout:
    - BrandPageHeader (teacher gradient) with server clock + date
    - Status banner: belum presensi / sudah masuk / sudah pulang +
      late + outside-geofence feedback
    - Today's teaching schedule strip
    - Capture card: auto live webcam preview, auto GPS chip, notes, and
      a single submit action that snapshots + posts
    - History link
-->
<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import { useWebcamCapture } from '@/composables/useWebcamCapture';
import { useQrScanner } from '@/composables/useQrScanner';
import { useGeolocation } from '@/composables/useGeolocation';
import { useToast } from '@/composables/useToast';
import type {
  TeacherAttendanceConfig,
  TeacherAttendanceRecord,
} from '@/types/teacher-attendance';
import { teacherAttendanceStatusLabel } from '@/types/teacher-attendance';
import type { CheckInMethod } from '@/types/attendance-qr';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import CheckInShiftPicker from '@/components/feature/CheckInShiftPicker.vue';

const router = useRouter();
const route = useRoute();
const toast = useToast();

// This exact check-in view is mounted under BOTH the teacher subtree
// (`teacher.my-attendance`) and the staff subtree (`staff.my-attendance`).
// The check-in service is staff-aware server-side (Phase C: the
// /teacher-attendance/config + /check-in endpoints resolve the caller as
// teacher OR staff and write the correct personnel_type row), so the whole
// selfie + GPS + notes + submit flow is identical for both. The only
// role-specific concern is which "Riwayat" route to navigate to — derive it
// from the current route name so the same component serves both. The header
// gradient auto-tints per active role via BrandPageHeader's default.
const isStaffContext = computed(() =>
  String(route.name ?? '').startsWith('staff'),
);
const historyRouteName = computed(() =>
  isStaffContext.value
    ? 'staff.my-attendance.history'
    : 'teacher.my-attendance.history',
);
const cam = useWebcamCapture();
const qr = useQrScanner();
const geo = useGeolocation();
const { t } = useI18n();

// ── Check-in method (SELFIE vs QR_GATE) ─────────────────────────
// Mirrors the mobile SegmentedButton: the school's admin picks which
// methods are allowed (`settings.allowed_methods`); the teacher toggles
// between them here. SELFIE is the existing selfie+GPS flow; QR_GATE
// renders a live webcam scanner that decodes the school's rotating gate
// QR and posts the token. QR_CARD is OUT OF SCOPE for this self-service
// screen (it's an admin-scans-the-card flow), so it's never offered as a
// selectable segment here.
const method = ref<CheckInMethod>('SELFIE');

/** The methods the school allows, defaulting to SELFIE-only. */
const allowedMethods = computed<CheckInMethod[]>(
  () => settings.value?.allowed_methods ?? ['SELFIE'],
);
const qrGateAllowed = computed(() => allowedMethods.value.includes('QR_GATE'));

/**
 * Show the Selfie/QR toggle only when the school allows BOTH selfie AND
 * gate-QR. A SELFIE-only school (the default, and every existing school)
 * sees exactly today's UI — zero regression. QR_CARD alone never triggers
 * the toggle since it isn't a self-service method.
 */
const showMethodToggle = computed(
  () => allowedMethods.value.includes('SELFIE') && qrGateAllowed.value,
);

/** Segments for the toggle — Selfie + Scan QR Gerbang (i18n). */
const methodSegments = computed(() => [
  { key: 'SELFIE', label: t('tutor.sekolah.presensiTeacher.methodSelfie') },
  { key: 'QR_GATE', label: t('tutor.sekolah.presensiTeacher.methodQrGate') },
]);

/** True while the QR mode is the active method AND the form is shown. */
const isQrMode = computed(
  () => method.value === 'QR_GATE' && showCaptureForm.value,
);

/** True while a QR-token POST is in flight — guards against double-submit. */
const qrSubmitting = ref(false);

/**
 * SegmentedControl emits a plain string; narrow it back to an allowed
 * CheckInMethod before assigning. Ignores anything not currently allowed.
 */
function onMethodChange(key: string) {
  if (
    (key === 'SELFIE' || key === 'QR_GATE') &&
    allowedMethods.value.includes(key)
  ) {
    method.value = key;
  }
}

// ── Bootstrap state ─────────────────────────────────────────────
const config = ref<TeacherAttendanceConfig | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// ── Capture state ───────────────────────────────────────────────
type Mode = 'check-in' | 'check-out';
const videoRef = ref<HTMLVideoElement | null>(null);
/** Separate <video> element for the QR scanner (rear camera, no mirror). */
const qrVideoRef = ref<HTMLVideoElement | null>(null);
const notes = ref('');
const submitting = ref(false);
/**
 * Which shift the user is checking in for (MR 4d). Auto-selected by
 * CheckInShiftPicker on mount to the shift covering `now`, overridable
 * via click. Sent as `shift_id` on the check-in POST; null on single-
 * shift schools so the backend NULLS-NOT-DISTINCT unique keeps working.
 */
const pickedShiftId = ref<string | null>(null);
/**
 * Shift ids the user already checked in for today, derived from the
 * config's `state.today_records[]` (backend MR !367). Older backend
 * builds omit the field — the computed defaults to an empty list so
 * multi-shift schools running an older API still see the picker,
 * they just don't get the "mute completed shift" cue. Nulls (single-
 * shift rows on multi-shift days? impossible, but defensive) are
 * filtered out so the picker's Set lookup stays clean.
 */
const completedShiftIds = computed<string[]>(() => {
  const rows = config.value?.state?.today_records ?? [];
  return rows
    .map((r) => r.shift_id)
    .filter((id): id is string => typeof id === 'string' && id.length > 0);
});
/** True once the parallel auto camera+location kick-off has run. */
const autoStarted = ref(false);

// Refresh the displayed clock once per second so the header ticks live.
const nowTick = ref(Date.now());
let tickTimer: ReturnType<typeof setInterval> | null = null;

// ── Derived: settings + state ───────────────────────────────────
const settings = computed(() => config.value?.settings ?? null);
const state = computed(() => config.value?.state ?? null);
const record = computed(() => state.value?.record ?? null);

const cameraRequired = computed(() => settings.value?.camera_required ?? false);
const locationRequired = computed(
  () => settings.value?.location_required ?? false,
);
const checkoutEnabled = computed(
  () => settings.value?.checkout_enabled ?? false,
);

const hasCheckedIn = computed(() => state.value?.has_checked_in ?? false);
const hasCheckedOut = computed(() => state.value?.has_checked_out ?? false);
const canCheckOut = computed(() => state.value?.can_check_out ?? false);

/**
 * The active capture mode. Once checked-in, the page flips to the
 * check-out flow (when enabled). When fully done, no capture form.
 */
const mode = computed<Mode>(() =>
  hasCheckedIn.value ? 'check-out' : 'check-in',
);

/** Whether a capture form should be shown at all. */
const showCaptureForm = computed(() => {
  if (!hasCheckedIn.value) return true; // need check-in
  return canCheckOut.value; // need check-out and it's allowed
});

const primaryActionLabel = computed(() =>
  mode.value === 'check-out'
    ? t('tutor.sekolah.presensiTeacher.checkOutLabel')
    : t('tutor.sekolah.presensiTeacher.checkInLabel'),
);

const serverDate = computed(() => {
  void nowTick.value;
  const iso = config.value?.server_time;
  const d = iso ? new Date(iso) : new Date();
  return d.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
});

const clockNow = computed(() => {
  void nowTick.value;
  return new Date().toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
});

function fmtTime(iso?: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

const lateAfterLabel = computed(() => fmtTime(config.value?.late_after));
const firstStartLabel = computed(() =>
  fmtTime(config.value?.first_teaching_start),
);

// ── Camera UI state helpers ─────────────────────────────────────
/** The contextual guidance shown when the camera can't auto-start. */
const cameraGuidance = computed(() => {
  switch (cam.errorKind.value) {
    case 'denied':
      return t('tutor.sekolah.presensiTeacher.camGuidanceDenied');
    case 'insecure':
      return t('tutor.sekolah.presensiTeacher.camGuidanceInsecure');
    case 'not-found':
      return t('tutor.sekolah.presensiTeacher.camGuidanceNotFound');
    case 'in-use':
      return t('tutor.sekolah.presensiTeacher.camGuidanceInUse');
    case 'unsupported':
      return t('tutor.sekolah.presensiTeacher.camGuidanceUnsupported');
    default:
      return t('tutor.sekolah.presensiTeacher.camGuidanceDefault');
  }
});

/** The contextual guidance shown when location can't be fetched. */
const locationGuidance = computed(() => {
  switch (geo.errorKind.value) {
    case 'denied':
      return t('tutor.sekolah.presensiTeacher.locGuidanceDenied');
    case 'insecure':
      return t('tutor.sekolah.presensiTeacher.locGuidanceInsecure');
    case 'unavailable':
      return t('tutor.sekolah.presensiTeacher.locGuidanceUnavailable');
    case 'timeout':
      return t('tutor.sekolah.presensiTeacher.locGuidanceTimeout');
    default:
      return t('tutor.sekolah.presensiTeacher.locGuidanceDefault');
  }
});

/** Contextual guidance shown when the QR scanner can't start. */
const qrGuidance = computed(() => {
  switch (qr.errorKind.value) {
    case 'denied':
      return t('tutor.sekolah.presensiTeacher.camGuidanceDenied');
    case 'insecure':
      return t('tutor.sekolah.presensiTeacher.camGuidanceInsecure');
    case 'not-found':
      return t('tutor.sekolah.presensiTeacher.qrGuidanceNoCamera');
    case 'in-use':
      return t('tutor.sekolah.presensiTeacher.camGuidanceInUse');
    case 'unsupported':
      return t('tutor.sekolah.presensiTeacher.qrGuidanceUnsupported');
    default:
      return t('tutor.sekolah.presensiTeacher.qrGuidanceDefault');
  }
});

// ── Validation: can we submit? ──────────────────────────────────
/**
 * Photo is satisfied either by a live camera ready to snapshot OR by a
 * still already captured. In the auto flow we snapshot at submit time,
 * so a LIVE camera counts as "ready".
 */
const photoSatisfied = computed(
  () => !cameraRequired.value || cam.isActive.value || !!photoUrl.value,
);
const locationSatisfied = computed(
  () => !locationRequired.value || !!geo.position.value,
);
const canSubmit = computed(
  () => photoSatisfied.value && locationSatisfied.value && !submitting.value,
);

/** A short "why is the button disabled" hint under the submit button. */
const blockedReason = computed<string | null>(() => {
  if (cameraRequired.value && !photoSatisfied.value) {
    return t('tutor.sekolah.presensiTeacher.blockedCamera');
  }
  if (locationRequired.value && !locationSatisfied.value) {
    return t('tutor.sekolah.presensiTeacher.blockedLocation');
  }
  return null;
});

// Captured still (optional manual snapshot preview). The auto flow does
// NOT need this; the submit button snapshots the live frame directly.
const photoBlob = ref<Blob | null>(null);
const photoUrl = ref<string | null>(null);

// ── Auto camera + location (in parallel) ────────────────────────
/**
 * Kick off the camera preview and the GPS fix AT THE SAME TIME so the
 * teacher never waits on a sequential chain. Both are best-effort and
 * degrade gracefully; neither throws.
 */
async function autoStartCapture() {
  if (autoStarted.value) return;
  if (!showCaptureForm.value) return;
  // In QR mode the selfie camera must stay off — the scanner owns the
  // camera. The mode watcher below drives the QR scanner separately.
  if (method.value === 'QR_GATE') return;
  autoStarted.value = true;

  const jobs: Promise<unknown>[] = [];

  if (cameraRequired.value) {
    // Wait a tick so the <video> element is mounted before attaching.
    await nextTick();
    if (videoRef.value) jobs.push(cam.start(videoRef.value));
  }
  if (locationRequired.value) {
    jobs.push(geo.locate());
  }

  await Promise.allSettled(jobs);
}

// ── QR scanner lifecycle ────────────────────────────────────────
/**
 * Start the live QR scanner: releases the selfie camera first (they can't
 * share the device), waits for the <video> to mount, then begins scanning.
 * On a decoded token it submits via [onQrToken]. Best-effort — degrades
 * gracefully via qr.errorKind/qr.error.
 */
async function startQrScanner() {
  cam.stop(); // free the selfie camera so the scanner can grab the device
  await nextTick();
  if (qrVideoRef.value) {
    await qr.start(qrVideoRef.value, onQrToken);
  }
}

/**
 * Handle a decoded gate-QR token. Same submit pipeline as the mobile app:
 * attach GPS only when the school requires it on QR (`geofence_required_for_qr`
 * → surfaced here via location_required for the self flow), POST, show the
 * verdict like the selfie flow, then reload. Guarded against double-submit
 * while a POST is in flight.
 */
async function onQrToken(token: string) {
  if (qrSubmitting.value || submitting.value) return;
  qrSubmitting.value = true;
  try {
    // Attach GPS when the school requires location; the server enforces the
    // geofence either way. locate() is best-effort — if it fails we still
    // POST and let the server decide (it may reject with a clear message).
    let lat: number | null = null;
    let lng: number | null = null;
    if (locationRequired.value) {
      await geo.locate();
      lat = geo.position.value?.latitude ?? null;
      lng = geo.position.value?.longitude ?? null;
    }
    const result = await TeacherAttendanceService.checkInWithQr({
      token,
      latitude: lat,
      longitude: lng,
    });
    toast.success(
      result.status === 'late'
        ? t('tutor.sekolah.presensiTeacher.checkInSuccessLate')
        : t('tutor.sekolah.presensiTeacher.checkInSuccess'),
    );
    resetForm();
    await reload();
  } catch (e) {
    toast.error((e as Error).message);
    // Keep scanning — re-arm the one-shot guard after a brief cool-down so
    // the same frame doesn't instantly re-fire.
    setTimeout(() => qr.resume(), 1500);
  } finally {
    qrSubmitting.value = false;
  }
}

/**
 * Drive the camera/scanner as the active method flips. Entering QR mode
 * tears down the selfie camera and starts the scanner; leaving it stops
 * the scanner and re-arms the selfie auto-capture.
 */
watch(isQrMode, (inQr) => {
  if (inQr) {
    void startQrScanner();
  } else {
    qr.stop();
    // Re-arm the selfie flow for the (now-active) selfie method.
    autoStarted.value = false;
    void autoStartCapture();
  }
});

/**
 * When the school removes a method the teacher had selected (admin flips
 * config, or QR_GATE was picked but is no longer allowed), fall back to the
 * first allowed method so the form never renders an unusable mode.
 */
watch(allowedMethods, (methods) => {
  if (methods.length > 0 && !methods.includes(method.value)) {
    method.value = methods[0];
  }
});

// ── Bootstrap ───────────────────────────────────────────────────
async function reload() {
  isLoading.value = true;
  loadError.value = null;
  autoStarted.value = false;
  try {
    config.value = await TeacherAttendanceService.config();
    // Preselect the first allowed method (mirrors mobile). If the current
    // selection is no longer allowed after a config change, fall back to
    // the first allowed one so the form is always usable.
    const allowed = config.value.settings.allowed_methods ?? ['SELFIE'];
    if (allowed.length > 0 && !allowed.includes(method.value)) {
      method.value = allowed[0];
    }
    // Only auto-start the selfie camera when SELFIE is the active method;
    // the isQrMode watcher owns the QR scanner otherwise.
    if (method.value !== 'QR_GATE') {
      await autoStartCapture();
    } else {
      await startQrScanner();
    }
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

// When the capture form first becomes visible (e.g. after a config
// refresh that flips state), make sure the auto kick-off has run.
watch(showCaptureForm, (visible) => {
  if (visible && !autoStarted.value) void autoStartCapture();
});

onMounted(() => {
  reload();
  tickTimer = setInterval(() => (nowTick.value = Date.now()), 1_000);
});

onUnmounted(() => {
  if (tickTimer) clearInterval(tickTimer);
  cam.stop();
  qr.stop();
  if (photoUrl.value) URL.revokeObjectURL(photoUrl.value);
});

// ── Camera actions ──────────────────────────────────────────────
/** Manual (tap-triggered) camera start used by the fallback button. */
async function startCamera() {
  await nextTick();
  if (videoRef.value) await cam.start(videoRef.value);
}

/** Drop any captured still and resume the live preview. */
async function retakePhoto() {
  if (photoUrl.value) URL.revokeObjectURL(photoUrl.value);
  photoBlob.value = null;
  photoUrl.value = null;
  await startCamera();
}

// ── Location action ─────────────────────────────────────────────
async function captureLocation() {
  await geo.locate();
}

// ── Submit (one-tap: snapshot live frame → post) ────────────────
async function submit() {
  // Snapshot the live frame at submit time so the photo is fresh and the
  // flow stays one-tap. Reuse an already-captured still if present.
  let blob = photoBlob.value;
  if (cameraRequired.value && !blob) {
    blob = await cam.snapshot();
    if (!blob) {
      toast.error(t('tutor.sekolah.presensiTeacher.snapshotFailed'));
      return;
    }
  }

  if (!canSubmit.value) {
    if (!photoSatisfied.value) toast.error(t('tutor.sekolah.presensiTeacher.toastEnableCamera'));
    else if (!locationSatisfied.value)
      toast.error(t('tutor.sekolah.presensiTeacher.toastGrabLocation'));
    return;
  }

  submitting.value = true;
  try {
    const payload = {
      photo: blob,
      latitude: geo.position.value?.latitude ?? null,
      longitude: geo.position.value?.longitude ?? null,
      notes: notes.value.trim() || null,
      shift_id: pickedShiftId.value,
    };
    let result: TeacherAttendanceRecord;
    if (mode.value === 'check-out') {
      result = await TeacherAttendanceService.checkOut(payload);
      toast.success(t('tutor.sekolah.presensiTeacher.checkOutSuccess'));
    } else {
      result = await TeacherAttendanceService.checkIn(payload);
      toast.success(
        result.status === 'late'
          ? t('tutor.sekolah.presensiTeacher.checkInSuccessLate')
          : t('tutor.sekolah.presensiTeacher.checkInSuccess'),
      );
    }
    // Reset the form + reload the live state (which re-arms auto-capture
    // for the check-out leg if it's now enabled).
    resetForm();
    await reload();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    submitting.value = false;
  }
}

function resetForm() {
  if (photoUrl.value) URL.revokeObjectURL(photoUrl.value);
  photoBlob.value = null;
  photoUrl.value = null;
  notes.value = '';
  pickedShiftId.value = null;
  geo.clear();
  cam.stop();
  qr.stop();
}

function gotoHistory() {
  router.push({ name: historyRouteName.value });
}
</script>

<template>
  <div class="space-y-md">
    <!-- ── Header ─────────────────────────────────────────────── -->
    <!-- No explicit `role` — BrandPageHeader defaults to the active role,
         so this same view tints teal for a teacher and amber for a staff
         user (mirrors the mobile app flipping personnel labels). -->
    <BrandPageHeader
      :kicker="t('tutor.sekolah.presensiTeacher.kicker')"
      :title="t('tutor.sekolah.presensiTeacher.title')"
      :meta="serverDate"
      live-dot
    >
      <div class="text-right">
        <p class="text-2xl font-black text-white tracking-tight leading-none">
          {{ clockNow }}
        </p>
        <p
          class="text-3xs font-bold text-white/80 uppercase tracking-widest mt-1"
        >
          {{ t('tutor.sekolah.presensiTeacher.serverTime') }}
        </p>
      </div>
    </BrandPageHeader>

    <!-- ── Loading / error ──────────────────────────────────────
         Skeleton mimics the config summary (badge row + 3 detail
         lines) so the swap on load doesn't jump. -->
    <div
      v-if="isLoading"
      class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3"
      aria-hidden="true"
    >
      <div class="flex items-center gap-2">
        <div class="h-7 w-7 rounded-lg bg-slate-200 animate-pulse motion-reduce:animate-none" />
        <div class="h-3 w-32 rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
      </div>
      <div class="h-5 w-2/3 rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
      <div class="space-y-2">
        <div class="h-2 w-full rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
        <div class="h-2 w-4/5 rounded bg-slate-200 animate-pulse motion-reduce:animate-none" />
      </div>
    </div>

    <div
      v-else-if="loadError"
      class="bg-red-50 border border-red-200 rounded-2xl p-4 text-center"
    >
      <NavIcon
        name="alert-triangle"
        :size="22"
        class="text-red-500 mx-auto mb-2"
      />
      <p class="text-[13px] font-bold text-red-700">{{ loadError }}</p>
      <Button variant="secondary" size="sm" class="mt-3" @click="reload">
        {{ t('tutor.sekolah.presensiTeacher.retry') }}
      </Button>
    </div>

    <template v-else-if="config">
      <!-- ── Status banner ────────────────────────────────────── -->
      <section
        v-if="hasCheckedOut"
        class="rounded-2xl p-4 sm:p-5 bg-emerald-50 border border-emerald-200 flex items-center gap-4"
      >
        <div
          class="w-12 h-12 rounded-2xl bg-emerald-100 text-emerald-700 grid place-items-center flex-shrink-0"
        >
          <NavIcon name="check-circle" :size="24" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-black text-emerald-800">
            {{ t('tutor.sekolah.presensiTeacher.doneToday') }}
          </p>
          <p class="text-[11.5px] text-emerald-700 mt-0.5">
            {{ t('tutor.sekolah.presensiTeacher.inOutTimes', { checkIn: fmtTime(record?.check_in_at), checkOut: fmtTime(record?.check_out_at) }) }}
          </p>
        </div>
      </section>

      <section
        v-else-if="hasCheckedIn"
        class="rounded-2xl p-4 sm:p-5 bg-brand-cobalt/5 border border-brand-cobalt/20 flex items-center gap-4"
      >
        <div
          class="w-12 h-12 rounded-2xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0"
        >
          <NavIcon name="check-square" :size="24" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-black text-slate-900">
            {{ t('tutor.sekolah.presensiTeacher.alreadyCheckedIn', { time: fmtTime(record?.check_in_at) }) }}
          </p>
          <p class="text-[11.5px] text-slate-600 mt-0.5">
            <span
              class="inline-flex items-center gap-1 font-bold"
              :class="
                record?.status === 'late'
                  ? 'text-amber-700'
                  : 'text-emerald-700'
              "
            >
              <span
                class="w-1.5 h-1.5 rounded-full"
                :class="
                  record?.status === 'late' ? 'bg-amber-500' : 'bg-emerald-500'
                "
              ></span>
              {{ teacherAttendanceStatusLabel(record?.status) }}
            </span>
            <template v-if="record?.check_in_outside_geofence">
              · <span class="text-red-600 font-bold">{{ t('tutor.sekolah.presensiTeacher.outsideGeofence') }}</span>
            </template>
            <template v-else-if="record?.check_in_distance_m != null">
              · {{ t('tutor.sekolah.presensiTeacher.distanceMeters', { meters: record.check_in_distance_m }) }}
            </template>
          </p>
          <p v-if="!checkoutEnabled" class="text-2xs text-slate-400 mt-1">
            {{ t('tutor.sekolah.presensiTeacher.checkOutDisabled') }}
          </p>
        </div>
      </section>

      <section
        v-else
        class="rounded-2xl p-4 sm:p-5 bg-amber-50 border border-amber-200 flex items-center gap-4"
      >
        <div
          class="w-12 h-12 rounded-2xl bg-amber-100 text-amber-700 grid place-items-center flex-shrink-0"
        >
          <NavIcon name="clock" :size="24" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-black text-amber-900">
            {{ t('tutor.sekolah.presensiTeacher.notYetCheckedIn') }}
          </p>
          <p class="text-[11.5px] text-amber-700 mt-0.5">
            <template v-if="config.late_after">
              {{ t('tutor.sekolah.presensiTeacher.onTimeLimit', { time: lateAfterLabel }) }}
              <span v-if="config.first_teaching_start" class="text-amber-600">
                {{ t('tutor.sekolah.presensiTeacher.firstTeaching', { time: firstStartLabel }) }}
              </span>
            </template>
            <template v-else
              >{{ t('tutor.sekolah.presensiTeacher.noScheduleToday') }}</template
            >
          </p>
        </div>
      </section>

      <!-- ── Today's schedule strip ───────────────────────────── -->
      <section
        v-if="config.today_schedule.length > 0"
        class="bg-white border border-slate-200 rounded-2xl p-4"
      >
        <div class="flex items-center gap-2 mb-3">
          <NavIcon name="calendar" :size="15" class="text-brand-cobalt" />
          <p class="text-[12px] font-bold text-slate-700">
            {{ t('tutor.sekolah.presensiTeacher.todaySchedule') }}
            <span class="text-slate-400 font-medium"
              >· {{ t('tutor.sekolah.presensiTeacher.sessionCount', { count: config.today_schedule.length }) }}</span
            >
          </p>
        </div>
        <ul class="space-y-1.5">
          <li
            v-for="s in config.today_schedule"
            :key="s.teaching_schedule_id"
            class="flex items-center gap-3 text-[12px]"
          >
            <span class="w-12 text-slate-500 font-bold tabular-nums">{{
              s.start_time
            }}</span>
            <span class="font-bold text-slate-900 flex-1 truncate">{{
              s.subject_name
            }}</span>
            <span
              class="bg-brand-cobalt/10 text-brand-cobalt px-2 py-0.5 rounded-full text-[10.5px] font-bold"
            >
              {{ s.class_name }}
            </span>
          </li>
        </ul>
      </section>

      <!-- ── Capture form ─────────────────────────────────────── -->
      <section
        v-if="showCaptureForm"
        class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
      >
        <!-- Card head -->
        <div
          class="flex items-center justify-between gap-2 px-4 sm:px-5 pt-4 pb-3 border-b border-slate-100"
        >
          <div class="flex items-center gap-2.5 min-w-0">
            <div
              class="w-9 h-9 rounded-xl grid place-items-center flex-shrink-0"
              :class="
                mode === 'check-out'
                  ? 'bg-violet-100 text-violet-700'
                  : 'bg-emerald-100 text-emerald-700'
              "
            >
              <NavIcon
                :name="mode === 'check-out' ? 'log-out' : 'check-square'"
                :size="17"
              />
            </div>
            <div class="min-w-0">
              <p class="text-[13px] font-black text-slate-900 leading-tight">
                {{ primaryActionLabel }}
              </p>
              <p
                class="text-[10.5px] text-slate-500 mt-0.5 inline-flex items-center gap-1"
              >
                <NavIcon name="zap" :size="11" class="text-brand-cobalt" />
                {{ t('tutor.sekolah.presensiTeacher.autoReady') }}
              </p>
            </div>
          </div>
          <span
            class="text-3xs font-bold uppercase tracking-widest px-2 py-1 rounded-full flex-shrink-0"
            :class="
              mode === 'check-out'
                ? 'bg-violet-100 text-violet-700'
                : 'bg-emerald-100 text-emerald-700'
            "
          >
            {{ mode === 'check-out' ? t('tutor.sekolah.presensiTeacher.badgeCheckOut') : t('tutor.sekolah.presensiTeacher.badgeCheckIn') }}
          </span>
        </div>

        <!-- ── Method toggle (Selfie / Scan QR Gerbang) ──────────── -->
        <!-- Only shown when the school allows BOTH selfie AND gate-QR. A
             SELFIE-only school never renders this and sees the exact
             original UI (zero regression). -->
        <div
          v-if="showMethodToggle"
          class="px-4 sm:px-5 pt-3 pb-1 flex items-center justify-center"
        >
          <SegmentedControl
            :model-value="method"
            :options="methodSegments"
            size="md"
            @update:model-value="onMethodChange"
          />
        </div>

        <!-- ── SELFIE mode body (existing flow, unchanged) ───────── -->
        <div v-if="method !== 'QR_GATE'" class="p-4 sm:p-5 space-y-md">
          <!-- ── Camera capture ── -->
          <div v-if="cameraRequired">
            <div class="flex items-center justify-between mb-2">
              <p
                class="text-2xs font-bold text-slate-600 flex items-center gap-1.5"
              >
                <NavIcon name="camera" :size="13" class="text-brand-cobalt" />
                {{ t('tutor.sekolah.presensiTeacher.selfiePhoto') }}
              </p>
              <span
                v-if="cam.isActive.value"
                class="inline-flex items-center gap-1 text-3xs font-bold text-emerald-600"
              >
                <span
                  class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"
                ></span>
                {{ t('tutor.sekolah.presensiTeacher.camActive') }}
              </span>
              <span
                v-else-if="cam.isStarting.value"
                class="inline-flex items-center gap-1 text-3xs font-bold text-slate-400"
              >
                {{ t('tutor.sekolah.presensiTeacher.camStarting') }}
              </span>
              <span
                v-else-if="cam.error.value"
                class="inline-flex items-center gap-1 text-3xs font-bold text-red-500"
              >
                <NavIcon name="alert-circle" :size="11" />
                {{ t('tutor.sekolah.presensiTeacher.camOff') }}
              </span>
            </div>

            <!-- Preview of captured still -->
            <div
              v-if="photoUrl"
              class="relative rounded-xl overflow-hidden bg-slate-900 aspect-video"
            >
              <img
                :src="photoUrl"
                :alt="t('tutor.sekolah.presensiTeacher.photoAlt')"
                class="w-full h-full object-cover"
              />
              <button
                type="button"
                class="absolute bottom-2 right-2 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/90 text-slate-800 text-2xs font-bold hover:bg-white"
                @click="retakePhoto"
              >
                <NavIcon name="refresh-cw" :size="12" />{{ t('tutor.sekolah.presensiTeacher.retake') }}
              </button>
            </div>

            <!-- Live camera preview (auto-started) -->
            <div v-else class="space-y-2">
              <div
                class="relative rounded-xl overflow-hidden bg-slate-900 aspect-video grid place-items-center"
              >
                <video
                  ref="videoRef"
                  class="w-full h-full object-cover"
                  style="transform: scaleX(-1)"
                  playsinline
                  muted
                ></video>

                <!-- Starting overlay -->
                <div
                  v-if="cam.isStarting.value"
                  class="absolute inset-0 grid place-items-center bg-slate-900/40"
                >
                  <div class="text-center">
                    <Spinner size="md" />
                    <p class="text-2xs text-white/80 font-medium mt-2">
                      {{ t('tutor.sekolah.presensiTeacher.preparingCamera') }}
                    </p>
                  </div>
                </div>

                <!-- Camera not yet live (auto-start blocked/denied) -->
                <div
                  v-else-if="!cam.isActive.value"
                  class="absolute inset-0 grid place-items-center text-center px-4 bg-slate-900/30"
                >
                  <div>
                    <NavIcon
                      :name="
                        cam.errorKind.value === 'insecure' ? 'shield' : 'camera'
                      "
                      :size="28"
                      class="text-white/70 mx-auto mb-2"
                    />
                    <p class="text-[12px] text-white/90 font-bold">
                      {{ cam.error.value ?? t('tutor.sekolah.presensiTeacher.camNotActive') }}
                    </p>
                  </div>
                </div>

                <!-- Live framing hint -->
                <div
                  v-if="cam.isActive.value"
                  class="absolute top-2 left-2 inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-black/40 text-white text-3xs font-bold"
                >
                  {{ t('tutor.sekolah.presensiTeacher.framingHint') }}
                </div>
              </div>

              <!-- Prominent tap-to-enable when auto-start failed -->
              <Button
                v-if="!cam.isActive.value && !cam.isStarting.value"
                variant="primary"
                size="sm"
                block
                :disabled="
                  cam.errorKind.value === 'insecure' ||
                  cam.errorKind.value === 'unsupported' ||
                  cam.errorKind.value === 'not-found'
                "
                @click="startCamera"
              >
                <NavIcon name="camera" :size="13" />{{ t('tutor.sekolah.presensiTeacher.enableCamera') }}
              </Button>

              <!-- Targeted guidance on failure -->
              <div
                v-if="cam.error.value && !cam.isActive.value"
                class="rounded-xl border p-3"
                :class="
                  cam.errorKind.value === 'insecure'
                    ? 'border-amber-200 bg-amber-50'
                    : 'border-red-200 bg-red-50'
                "
              >
                <p
                  class="text-2xs font-bold flex items-start gap-1.5"
                  :class="
                    cam.errorKind.value === 'insecure'
                      ? 'text-amber-800'
                      : 'text-red-700'
                  "
                >
                  <NavIcon
                    :name="
                      cam.errorKind.value === 'insecure'
                        ? 'shield'
                        : 'alert-circle'
                    "
                    :size="13"
                    class="flex-shrink-0 mt-px"
                  />
                  <span>{{ cameraGuidance }}</span>
                </p>
              </div>
            </div>
          </div>

          <!-- ── Location capture (auto-started in parallel) ── -->
          <div v-if="locationRequired">
            <p
              class="text-2xs font-bold text-slate-600 mb-2 flex items-center gap-1.5"
            >
              <NavIcon name="map-pin" :size="13" class="text-brand-cobalt" />
              {{ t('tutor.sekolah.presensiTeacher.gpsLocation') }}
            </p>
            <div
              class="flex items-center gap-3 rounded-xl border p-3"
              :class="
                geo.position.value
                  ? 'border-emerald-200 bg-emerald-50'
                  : geo.error.value
                    ? 'border-red-200 bg-red-50'
                    : 'border-slate-200 bg-slate-50'
              "
            >
              <div
                class="w-9 h-9 rounded-lg grid place-items-center flex-shrink-0"
                :class="
                  geo.position.value
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-white text-slate-400 border border-slate-200'
                "
              >
                <NavIcon
                  v-if="!geo.isLocating.value"
                  name="map-pin"
                  :size="16"
                />
                <Spinner v-else size="sm" />
              </div>
              <div class="flex-1 min-w-0">
                <template v-if="geo.position.value">
                  <p class="text-[12px] font-bold text-emerald-800">
                    {{ t('tutor.sekolah.presensiTeacher.locationDetected') }}
                  </p>
                  <p class="text-2xs text-emerald-700 tabular-nums">
                    {{ geo.position.value.latitude.toFixed(6) }},
                    {{ geo.position.value.longitude.toFixed(6) }}
                    <span
                      v-if="geo.position.value.accuracy"
                      class="text-emerald-600"
                    >
                      · ±{{ Math.round(geo.position.value.accuracy) }} m
                    </span>
                  </p>
                </template>
                <template v-else-if="geo.isLocating.value">
                  <p class="text-[12px] font-bold text-slate-600">
                    {{ t('tutor.sekolah.presensiTeacher.fetchingLocation') }}
                  </p>
                  <p class="text-2xs text-slate-400">
                    {{ t('tutor.sekolah.presensiTeacher.geofenceVerify') }}
                  </p>
                </template>
                <template v-else>
                  <p class="text-[12px] font-bold text-slate-600">
                    {{ t('tutor.sekolah.presensiTeacher.locationNotYet') }}
                  </p>
                  <p class="text-2xs text-slate-400">
                    {{ t('tutor.sekolah.presensiTeacher.geofenceVerify') }}
                  </p>
                </template>
              </div>
              <Button
                variant="secondary"
                size="sm"
                :loading="geo.isLocating.value"
                :disabled="
                  geo.errorKind.value === 'insecure' ||
                  geo.errorKind.value === 'unsupported'
                "
                @click="captureLocation"
              >
                {{ geo.position.value ? t('tutor.sekolah.presensiTeacher.refresh') : t('tutor.sekolah.presensiTeacher.retry') }}
              </Button>
            </div>

            <!-- Approximate-accuracy hint (common on desktop) -->
            <p
              v-if="geo.position.value && geo.isApproximate.value"
              class="text-[10.5px] text-amber-600 font-medium mt-1.5 flex items-start gap-1"
            >
              <NavIcon
                name="alert-circle"
                :size="11"
                class="flex-shrink-0 mt-px"
              />
              {{ t('tutor.sekolah.presensiTeacher.approximateHint') }}
            </p>

            <!-- Targeted guidance on failure -->
            <div
              v-if="geo.error.value && !geo.position.value"
              class="rounded-xl border p-3 mt-1.5"
              :class="
                geo.errorKind.value === 'insecure'
                  ? 'border-amber-200 bg-amber-50'
                  : 'border-red-200 bg-red-50'
              "
            >
              <p
                class="text-2xs font-bold flex items-start gap-1.5"
                :class="
                  geo.errorKind.value === 'insecure'
                    ? 'text-amber-800'
                    : 'text-red-700'
                "
              >
                <NavIcon
                  :name="
                    geo.errorKind.value === 'insecure'
                      ? 'shield'
                      : 'alert-circle'
                  "
                  :size="13"
                  class="flex-shrink-0 mt-px"
                />
                <span>{{ locationGuidance }}</span>
              </p>
            </div>
          </div>

          <!-- ── Notes ── -->
          <div>
            <label class="text-2xs font-bold text-slate-600 mb-1.5 block">
              {{ t('tutor.sekolah.presensiTeacher.notesLabel') }}
            </label>
            <textarea
              v-model="notes"
              rows="2"
              maxlength="1000"
              :placeholder="t('tutor.sekolah.presensiTeacher.notesPlaceholder')"
              class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[13px] text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30 resize-none"
            ></textarea>
          </div>

          <!-- ── Shift picker (multi-shift schools only) ──
               Renders nothing when config.shifts is empty, so single-
               shift schools see the same view they had before this MR.
               Auto-picks the shift covering `now` on mount; user can
               override by clicking a different card. -->
          <CheckInShiftPicker
            v-if="mode === 'check-in' && (config?.shifts?.length ?? 0) > 0"
            v-model="pickedShiftId"
            :shifts="config?.shifts ?? []"
            :completed-shift-ids="completedShiftIds"
          />

          <!-- ── Single primary action (snapshot live frame + post) ── -->
          <Button
            variant="primary"
            block
            :loading="submitting"
            :disabled="!canSubmit"
            @click="submit"
          >
            <NavIcon
              :name="mode === 'check-out' ? 'log-out' : 'check-square'"
              :size="15"
            />
            {{ t('tutor.sekolah.presensiTeacher.actionNow', { action: primaryActionLabel }) }}
          </Button>
          <p
            v-if="blockedReason"
            class="text-[10.5px] text-amber-600 font-medium text-center -mt-1"
          >
            {{ blockedReason }}
          </p>
          <p v-else class="text-[10.5px] text-slate-400 text-center -mt-1">
            {{ t('tutor.sekolah.presensiTeacher.autoPhotoHint') }}
          </p>
        </div>

        <!-- ── QR_GATE mode body (live scanner) ──────────────────── -->
        <!-- Mirrors the mobile scanner: point the REAR camera at the
             school's gate-QR poster; a successful decode auto-submits the
             token. No manual submit button — the scan IS the action. -->
        <div v-else class="p-4 sm:p-5 space-y-md">
          <div>
            <p
              class="text-2xs font-bold text-slate-600 mb-2 flex items-center gap-1.5"
            >
              <NavIcon name="camera" :size="13" class="text-brand-cobalt" />
              {{ t('tutor.sekolah.presensiTeacher.qrScanTitle') }}
            </p>

            <!-- Scanner viewport -->
            <div
              class="relative rounded-xl overflow-hidden bg-slate-900 aspect-video grid place-items-center"
            >
              <video
                ref="qrVideoRef"
                class="w-full h-full object-cover"
                playsinline
                muted
              ></video>

              <!-- Framing reticle (only while live) -->
              <div
                v-if="qr.isActive.value"
                class="absolute inset-0 grid place-items-center pointer-events-none"
              >
                <div
                  class="w-2/5 aspect-square rounded-2xl border-2 border-white/80"
                ></div>
              </div>

              <!-- Starting overlay -->
              <div
                v-if="qr.isStarting.value"
                class="absolute inset-0 grid place-items-center bg-slate-900/40"
              >
                <div class="text-center">
                  <Spinner size="md" />
                  <p class="text-2xs text-white/80 font-medium mt-2">
                    {{ t('tutor.sekolah.presensiTeacher.qrPreparing') }}
                  </p>
                </div>
              </div>

              <!-- Scanner not live (denied/unsupported/etc.) -->
              <div
                v-else-if="!qr.isActive.value"
                class="absolute inset-0 grid place-items-center text-center px-4 bg-slate-900/30"
              >
                <div>
                  <NavIcon
                    :name="
                      qr.errorKind.value === 'insecure' ? 'shield' : 'camera'
                    "
                    :size="28"
                    class="text-white/70 mx-auto mb-2"
                  />
                  <p class="text-[12px] text-white/90 font-bold">
                    {{ qr.error.value ?? t('tutor.sekolah.presensiTeacher.qrNotActive') }}
                  </p>
                </div>
              </div>

              <!-- Submitting overlay (a token was decoded, POST in flight) -->
              <div
                v-if="qrSubmitting"
                class="absolute inset-0 grid place-items-center bg-slate-900/60"
              >
                <div class="text-center">
                  <Spinner size="md" />
                  <p class="text-2xs text-white/90 font-bold mt-2">
                    {{ t('tutor.sekolah.presensiTeacher.qrSubmitting') }}
                  </p>
                </div>
              </div>

              <!-- Live scanning hint -->
              <div
                v-if="qr.isActive.value && !qrSubmitting"
                class="absolute top-2 left-2 inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-black/40 text-white text-3xs font-bold"
              >
                {{ t('tutor.sekolah.presensiTeacher.qrScanning') }}
              </div>
            </div>

            <!-- Tap-to-enable when the scanner failed to auto-start -->
            <Button
              v-if="!qr.isActive.value && !qr.isStarting.value"
              variant="primary"
              size="sm"
              block
              class="mt-2"
              :disabled="
                qr.errorKind.value === 'insecure' ||
                qr.errorKind.value === 'unsupported' ||
                qr.errorKind.value === 'not-found'
              "
              @click="startQrScanner"
            >
              <NavIcon name="camera" :size="13" />{{ t('tutor.sekolah.presensiTeacher.qrEnableCamera') }}
            </Button>

            <!-- Targeted guidance on failure -->
            <div
              v-if="qr.error.value && !qr.isActive.value"
              class="rounded-xl border p-3 mt-2"
              :class="
                qr.errorKind.value === 'insecure'
                  ? 'border-amber-200 bg-amber-50'
                  : 'border-red-200 bg-red-50'
              "
            >
              <p
                class="text-2xs font-bold flex items-start gap-1.5"
                :class="
                  qr.errorKind.value === 'insecure'
                    ? 'text-amber-800'
                    : 'text-red-700'
                "
              >
                <NavIcon
                  :name="
                    qr.errorKind.value === 'insecure' ? 'shield' : 'alert-circle'
                  "
                  :size="13"
                  class="flex-shrink-0 mt-px"
                />
                <span>{{ qrGuidance }}</span>
              </p>
            </div>

            <!-- Always-visible instruction line -->
            <p class="text-[10.5px] text-slate-400 text-center mt-2">
              {{ t('tutor.sekolah.presensiTeacher.qrHint') }}
            </p>
          </div>
        </div>
      </section>

      <!-- ── History link ─────────────────────────────────────── -->
      <button
        type="button"
        class="w-full flex items-center gap-3 bg-white border border-slate-200 rounded-2xl px-4 py-3 hover:bg-slate-50 transition-colors"
        @click="gotoHistory"
      >
        <div
          class="w-9 h-9 rounded-lg bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0"
        >
          <NavIcon name="clipboard-list" :size="16" />
        </div>
        <div class="flex-1 text-left">
          <p class="text-[13px] font-bold text-slate-900">{{ t('tutor.sekolah.presensiTeacher.historyTitle') }}</p>
          <p class="text-2xs text-slate-500">{{ t('tutor.sekolah.presensiTeacher.historySubtitle') }}</p>
        </div>
        <NavIcon name="arrow-right" :size="16" class="text-slate-300" />
      </button>
    </template>
  </div>
</template>
