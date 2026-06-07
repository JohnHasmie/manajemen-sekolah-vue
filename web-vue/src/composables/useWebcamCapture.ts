/**
 * useWebcamCapture — live webcam selfie capture for PRESENSI GURU.
 *
 * "Safe v1" requires the photo to be a LIVE camera capture (no gallery
 * upload). On the web we enforce this by sourcing frames straight from
 * `navigator.mediaDevices.getUserMedia` and snapshotting the active
 * <video> stream into a canvas → Blob. There is no <input type=file>
 * fallback by design.
 *
 * AUTO-FIRST design: the presensi view auto-calls start() the moment the
 * capture step mounts so the camera is already live by the time the
 * teacher looks. But getUserMedia can be blocked when called without a
 * user gesture, denied outright, or unavailable on an insecure origin —
 * so start() NEVER throws and always sets a categorised `errorKind` +
 * friendly Indonesian `error`, letting the UI show a prominent
 * "Nyalakan Kamera" tap-to-retry button plus specific guidance.
 *
 * Usage:
 *   const cam = useWebcamCapture();
 *   await cam.start(videoEl);          // attaches the stream to your <video>
 *   const blob = await cam.snapshot(); // current frame as a JPEG Blob
 *   cam.stop();                        // release the camera when done
 *
 * The caller owns the <video> element; we just wire the stream to it.
 * Always call stop() in onUnmounted to free the device + privacy light.
 */
import { computed, onUnmounted, ref } from 'vue';

/**
 * Categorised camera failure so the view can render targeted guidance.
 *  - `unsupported`  → browser lacks getUserMedia
 *  - `insecure`     → page is not HTTPS/localhost (getUserMedia blocked)
 *  - `denied`       → permission denied / blocked (NotAllowedError)
 *  - `not-found`    → device has no camera
 *  - `in-use`       → camera busy in another app (NotReadableError)
 *  - `unknown`      → anything else
 */
export type WebcamErrorKind =
  | null
  | 'unsupported'
  | 'insecure'
  | 'denied'
  | 'not-found'
  | 'in-use'
  | 'unknown';

export function useWebcamCapture() {
  /** True once a live stream is attached and playing. */
  const isActive = ref(false);
  /** True while start() is negotiating camera permission. */
  const isStarting = ref(false);
  /** Human Indonesian error if the camera can't be opened. */
  const error = ref<string | null>(null);
  /** Machine-readable failure category for targeted UI guidance. */
  const errorKind = ref<WebcamErrorKind>(null);

  let stream: MediaStream | null = null;
  let videoEl: HTMLVideoElement | null = null;

  /** Whether this browser exposes the camera API at all. */
  const isSupported = computed(
    () =>
      typeof navigator !== 'undefined' &&
      !!navigator.mediaDevices?.getUserMedia,
  );

  /**
   * Whether the page runs in a secure context. getUserMedia only works
   * on HTTPS or localhost; on plain HTTP it throws. We surface this up
   * front so the UI can explain it instead of showing a vague error.
   */
  const isSecure = computed(() => {
    if (typeof window === 'undefined') return true;
    if (typeof window.isSecureContext === 'boolean') {
      return window.isSecureContext;
    }
    const host = window.location?.hostname ?? '';
    return (
      window.location?.protocol === 'https:' ||
      host === 'localhost' ||
      host === '127.0.0.1' ||
      host === '::1'
    );
  });

  /** Map a getUserMedia rejection to a (kind, message) pair. */
  function describeError(e: unknown): {
    kind: WebcamErrorKind;
    message: string;
  } {
    const name = (e as { name?: string })?.name ?? '';
    if (name === 'NotAllowedError' || name === 'SecurityError') {
      return {
        kind: 'denied',
        message:
          'Izin kamera ditolak. Aktifkan akses kamera untuk situs ini lalu coba lagi.',
      };
    }
    if (name === 'NotFoundError' || name === 'DevicesNotFoundError') {
      return {
        kind: 'not-found',
        message: 'Kamera tidak ditemukan pada perangkat ini.',
      };
    }
    if (
      name === 'NotReadableError' ||
      name === 'TrackStartError' ||
      name === 'AbortError'
    ) {
      return {
        kind: 'in-use',
        message:
          'Kamera sedang dipakai aplikasi lain. Tutup aplikasi tersebut lalu coba lagi.',
      };
    }
    return {
      kind: 'unknown',
      message:
        'Tidak dapat membuka kamera. Pastikan perangkat memiliki kamera aktif lalu coba lagi.',
    };
  }

  /**
   * Open the camera and attach it to the given <video>. Prefers the
   * front ("user") camera for a selfie. Resolves to true once the stream
   * is playing; on failure resolves false and sets `error`/`errorKind`
   * (NEVER throws — safe to auto-call on mount).
   */
  async function start(el: HTMLVideoElement): Promise<boolean> {
    error.value = null;
    errorKind.value = null;

    if (!isSecure.value) {
      errorKind.value = 'insecure';
      error.value =
        'Kamera hanya bisa diakses lewat koneksi aman (HTTPS). Buka halaman ini dengan alamat https:// lalu coba lagi.';
      return false;
    }
    if (!isSupported.value) {
      errorKind.value = 'unsupported';
      error.value =
        'Browser ini tidak mendukung akses kamera. Coba gunakan Chrome/Safari versi terbaru.';
      return false;
    }

    // If a stream is already live on a previous element, release it first.
    if (stream) stop();

    isStarting.value = true;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false,
      });
      videoEl = el;
      el.srcObject = stream;
      el.muted = true;
      el.setAttribute('playsinline', 'true');
      await el.play().catch(() => {
        // Some browsers reject play() if not user-gesture-triggered;
        // the frame still renders, so this is non-fatal.
      });
      isActive.value = true;
      return true;
    } catch (e) {
      const { kind, message } = describeError(e);
      errorKind.value = kind;
      error.value = message;
      isActive.value = false;
      // Make sure no half-open track lingers.
      if (stream) {
        stream.getTracks().forEach((t) => t.stop());
        stream = null;
      }
      return false;
    } finally {
      isStarting.value = false;
    }
  }

  /**
   * Capture the current video frame as a JPEG Blob. Returns null if the
   * stream isn't ready. The selfie is mirrored to match what the user
   * sees on screen (front cameras are previewed mirrored).
   */
  async function snapshot(quality = 0.85): Promise<Blob | null> {
    if (!videoEl || !isActive.value) return null;
    const w = videoEl.videoWidth;
    const h = videoEl.videoHeight;
    if (!w || !h) return null;
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    if (!ctx) return null;
    // Mirror horizontally so the saved selfie matches the preview.
    ctx.translate(w, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(videoEl, 0, 0, w, h);
    return new Promise<Blob | null>((resolve) => {
      canvas.toBlob((blob) => resolve(blob), 'image/jpeg', quality);
    });
  }

  /** Release the camera + clear the <video>. Safe to call repeatedly. */
  function stop() {
    if (stream) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
    }
    if (videoEl) {
      videoEl.srcObject = null;
      videoEl = null;
    }
    isActive.value = false;
    isStarting.value = false;
  }

  onUnmounted(stop);

  return {
    isActive,
    isStarting,
    error,
    errorKind,
    isSupported,
    isSecure,
    start,
    snapshot,
    stop,
  };
}
