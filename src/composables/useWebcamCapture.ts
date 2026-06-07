/**
 * useWebcamCapture — live webcam selfie capture for PRESENSI GURU.
 *
 * "Safe v1" requires the photo to be a LIVE camera capture (no gallery
 * upload). On the web we enforce this by sourcing frames straight from
 * `navigator.mediaDevices.getUserMedia` and snapshotting the active
 * <video> stream into a canvas → Blob. There is no <input type=file>
 * fallback by design.
 *
 * Usage:
 *   const cam = useWebcamCapture();
 *   await cam.start(videoEl);   // attaches the stream to your <video>
 *   const blob = await cam.snapshot();  // current frame as a JPEG Blob
 *   cam.stop();                 // release the camera when done
 *
 * The caller owns the <video> element; we just wire the stream to it.
 * Always call stop() in onUnmounted to free the device + privacy light.
 */
import { onUnmounted, ref } from 'vue';

export function useWebcamCapture() {
  /** True once a live stream is attached and playing. */
  const isActive = ref(false);
  /** True while start() is negotiating camera permission. */
  const isStarting = ref(false);
  /** Human Indonesian error if the camera can't be opened. */
  const error = ref<string | null>(null);

  let stream: MediaStream | null = null;
  let videoEl: HTMLVideoElement | null = null;

  /** Map a getUserMedia rejection to a friendly Indonesian message. */
  function describeError(e: unknown): string {
    const name = (e as { name?: string })?.name ?? '';
    if (name === 'NotAllowedError' || name === 'SecurityError') {
      return 'Izin kamera ditolak. Aktifkan akses kamera di browser lalu coba lagi.';
    }
    if (name === 'NotFoundError' || name === 'DevicesNotFoundError') {
      return 'Kamera tidak ditemukan pada perangkat ini.';
    }
    if (name === 'NotReadableError') {
      return 'Kamera sedang digunakan aplikasi lain. Tutup aplikasi tersebut lalu coba lagi.';
    }
    return 'Tidak dapat membuka kamera. Pastikan perangkat memiliki kamera aktif.';
  }

  /**
   * Open the camera and attach it to the given <video>. Prefers the
   * front ("user") camera for a selfie. Resolves once the stream is
   * playing; rejects via the `error` ref (does not throw).
   */
  async function start(el: HTMLVideoElement): Promise<boolean> {
    error.value = null;
    if (
      typeof navigator === 'undefined' ||
      !navigator.mediaDevices?.getUserMedia
    ) {
      error.value = 'Browser ini tidak mendukung akses kamera.';
      return false;
    }
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
      error.value = describeError(e);
      isActive.value = false;
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
  }

  onUnmounted(stop);

  return { isActive, isStarting, error, start, snapshot, stop };
}
