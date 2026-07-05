/**
 * useQrScanner — live webcam QR-GATE scanner for PRESENSI (self check-in).
 *
 * The web app had NO QR decoder, so this composable adds one. It mirrors
 * the mobile app's `mobile_scanner` UX (see
 * `lib/features/teacher_attendance/.../teacher_attendance_screen.dart`):
 * open the camera, watch frames, and fire a callback with the decoded
 * gate-QR token so the caller can POST it.
 *
 * DECODE STRATEGY (both, best-first):
 *   1. Native `BarcodeDetector` when the browser exposes it (Chrome/Edge/
 *      Android WebView) — fast, hardware-accelerated, off the main thread.
 *   2. `jsqr` (npm) fallback for Safari/Firefox, which lack BarcodeDetector.
 *      We draw the current <video> frame onto an offscreen canvas and run
 *      jsQR over the pixel buffer.
 * If a browser has neither a camera nor jsqr can load, start() degrades
 * gracefully with a categorised error + Indonesian message (NEVER throws),
 * exactly like `useWebcamCapture` — the view then tells the user to use the
 * mobile app.
 *
 * Analogy for the Laravel/Vue reader: this is a thin "poller" — like a
 * `setInterval` that re-reads a source each tick and calls back on a hit —
 * except it runs on `requestAnimationFrame` (synced to the browser paint)
 * so the scan loop never outruns the video's frame rate.
 *
 * LIFECYCLE — the caller MUST call stop() when leaving QR mode or on
 * unmount so the camera track is released and the privacy light goes off.
 * We also auto-stop on component unmount as a safety net.
 *
 * Usage:
 *   const qr = useQrScanner();
 *   await qr.start(videoEl, (token) => submit(token)); // begins scanning
 *   qr.stop();                                         // release the camera
 */
import { computed, onUnmounted, ref } from 'vue';
// Type-only import of jsQR's default export signature. The runtime module
// is loaded lazily via dynamic import() below so it stays out of the main
// bundle for browsers that use the native BarcodeDetector path.
import type jsQRType from 'jsqr';

/**
 * Categorised scanner failure so the view can render targeted guidance.
 * Same taxonomy as `useWebcamCapture` (camera acquisition shares the
 * failure modes) plus `unsupported` meaning "no decode path at all".
 */
export type QrScannerErrorKind =
  | null
  | 'unsupported'
  | 'insecure'
  | 'denied'
  | 'not-found'
  | 'in-use'
  | 'unknown';

/** Minimal shape of the `BarcodeDetector` API we rely on (not in lib.dom). */
interface BarcodeDetectorLike {
  detect(source: CanvasImageSource): Promise<Array<{ rawValue: string }>>;
}
interface BarcodeDetectorCtor {
  new (options?: { formats?: string[] }): BarcodeDetectorLike;
  getSupportedFormats?: () => Promise<string[]>;
}

export function useQrScanner() {
  /** True once a live stream is attached and the scan loop is running. */
  const isActive = ref(false);
  /** True while start() is negotiating camera permission. */
  const isStarting = ref(false);
  /** Human Indonesian error if the scanner can't be opened. */
  const error = ref<string | null>(null);
  /** Machine-readable failure category for targeted UI guidance. */
  const errorKind = ref<QrScannerErrorKind>(null);

  let stream: MediaStream | null = null;
  let videoEl: HTMLVideoElement | null = null;
  let rafId: number | null = null;
  let canvas: HTMLCanvasElement | null = null;
  let ctx: CanvasRenderingContext2D | null = null;
  let detector: BarcodeDetectorLike | null = null;
  /** Lazily-imported jsQR decoder (only loaded when BarcodeDetector is absent). */
  let jsqrDecode: typeof jsQRType | null = null;
  /** The caller's success callback for a decoded token. */
  let onToken: ((token: string) => void) | null = null;
  /**
   * Guards against firing the same decode twice. The caller also gates on
   * an in-flight POST, but this stops a burst of identical frames from
   * queueing N callbacks before the caller flips its busy flag.
   */
  let handled = false;

  /** Whether this browser exposes the camera API at all. */
  const isSupported = computed(
    () =>
      typeof navigator !== 'undefined' &&
      !!navigator.mediaDevices?.getUserMedia,
  );

  /** Whether the page runs in a secure context (getUserMedia needs HTTPS). */
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
    kind: QrScannerErrorKind;
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
        'Tidak dapat membuka kamera untuk memindai QR. Pastikan perangkat memiliki kamera aktif lalu coba lagi.',
    };
  }

  /**
   * Prepare a decode path: prefer native BarcodeDetector, else lazily
   * import jsQR. Returns false (and sets `unsupported`) only when NEITHER
   * is available — a genuinely dead end where the user must fall back to
   * the mobile app.
   */
  async function ensureDecoder(): Promise<boolean> {
    if (detector || jsqrDecode) return true;

    // 1. Native BarcodeDetector (Chromium/Android).
    const Ctor = (window as unknown as { BarcodeDetector?: BarcodeDetectorCtor })
      .BarcodeDetector;
    if (Ctor) {
      try {
        // Only claim support when it can actually do qr_code.
        const formats = (await Ctor.getSupportedFormats?.()) ?? ['qr_code'];
        if (formats.includes('qr_code')) {
          detector = new Ctor({ formats: ['qr_code'] });
          return true;
        }
      } catch {
        // Fall through to jsQR.
      }
    }

    // 2. jsQR fallback (Safari/Firefox). Dynamic import keeps it out of the
    //    main bundle for browsers that never need it.
    try {
      const mod = await import('jsqr');
      jsqrDecode = mod.default;
      return !!jsqrDecode;
    } catch {
      errorKind.value = 'unsupported';
      error.value =
        'Browser ini tidak dapat memindai QR. Gunakan aplikasi mobile untuk scan QR.';
      return false;
    }
  }

  /** Decode the current video frame; returns the token string or null. */
  async function decodeFrame(): Promise<string | null> {
    if (!videoEl) return null;
    const w = videoEl.videoWidth;
    const h = videoEl.videoHeight;
    if (!w || !h) return null;

    // Native path — hand the <video> straight to the detector.
    if (detector) {
      try {
        const results = await detector.detect(videoEl);
        const raw = results?.[0]?.rawValue?.trim();
        return raw && raw.length > 0 ? raw : null;
      } catch {
        return null;
      }
    }

    // jsQR path — draw to canvas, read pixels, decode.
    if (jsqrDecode) {
      if (!canvas) {
        canvas = document.createElement('canvas');
        ctx = canvas.getContext('2d', { willReadFrequently: true });
      }
      if (!ctx) return null;
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
      }
      ctx.drawImage(videoEl, 0, 0, w, h);
      let image: ImageData;
      try {
        image = ctx.getImageData(0, 0, w, h);
      } catch {
        // Cross-origin taint or a transient read failure — skip this frame.
        return null;
      }
      const result = jsqrDecode(image.data, w, h, {
        inversionAttempts: 'dontInvert' as const,
      });
      const raw = result?.data?.trim();
      return raw && raw.length > 0 ? raw : null;
    }

    return null;
  }

  /** The rAF scan loop. Stops itself the moment a token is handled. */
  function tick() {
    if (!isActive.value || handled) return;
    void decodeFrame().then((token) => {
      if (!isActive.value || handled) return;
      if (token) {
        // One-shot: mark handled so a burst of identical frames doesn't
        // fire the callback repeatedly. The caller re-arms via resume().
        handled = true;
        onToken?.(token);
        return; // don't schedule another frame until resume()
      }
      rafId = requestAnimationFrame(tick);
    });
  }

  /**
   * Open the camera (prefers the REAR/environment camera — you point it at
   * a poster, not at your face), attach it to `el`, and start scanning.
   * Calls `onDetect(token)` once per decoded QR. Resolves true when the
   * scan loop is live; on failure resolves false and sets error/errorKind
   * (NEVER throws — safe to auto-call).
   */
  async function start(
    el: HTMLVideoElement,
    onDetect: (token: string) => void,
  ): Promise<boolean> {
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

    // If a stream is already live, release it first (idempotent restart).
    if (stream) stop();

    isStarting.value = true;
    try {
      // Prepare the decoder BEFORE opening the camera so an "unsupported"
      // browser never even lights the camera up.
      const decoderReady = await ensureDecoder();
      if (!decoderReady) {
        isStarting.value = false;
        return false;
      }

      stream = await navigator.mediaDevices.getUserMedia({
        video: {
          // Point at the world, not the user — the gate QR is on a poster.
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false,
      });
      videoEl = el;
      onToken = onDetect;
      handled = false;
      el.srcObject = stream;
      el.muted = true;
      el.setAttribute('playsinline', 'true');
      await el.play().catch(() => {
        // Some browsers reject play() without a user gesture; the frames
        // still flow, so this is non-fatal.
      });
      isActive.value = true;
      rafId = requestAnimationFrame(tick);
      return true;
    } catch (e) {
      const { kind, message } = describeError(e);
      errorKind.value = kind;
      error.value = message;
      isActive.value = false;
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
   * Re-arm the scanner after a decode was handled (e.g. the POST failed and
   * the caller wants to keep scanning, or after a cool-down). Cheap — it
   * just clears the one-shot guard and restarts the rAF loop; the camera
   * stream stays live.
   */
  function resume() {
    if (!isActive.value) return;
    handled = false;
    if (rafId == null) rafId = requestAnimationFrame(tick);
  }

  /** Release the camera + tear down the loop. Safe to call repeatedly. */
  function stop() {
    if (rafId != null) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
    if (stream) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
    }
    if (videoEl) {
      videoEl.srcObject = null;
      videoEl = null;
    }
    onToken = null;
    handled = false;
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
    resume,
    stop,
  };
}
