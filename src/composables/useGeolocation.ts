/**
 * useGeolocation — one-shot GPS fix for PRESENSI GURU.
 *
 * Wraps `navigator.geolocation.getCurrentPosition` in a promise so the
 * presensi view can acquire a fix in parallel with the camera before
 * submitting. The backend verifies the coordinates against the school
 * geofence (haversine) — we just need an accurate-enough fix and a
 * friendly Indonesian error when the user denies permission or location
 * is unavailable.
 *
 * AUTO-FIRST design: the view auto-calls locate() on mount. locate()
 * NEVER throws — on failure it resolves null and sets a categorised
 * `errorKind` + `error`, so the UI can show a retry button and targeted
 * guidance (denied / insecure / timeout). On desktop a Wi-Fi/IP fix can
 * be quite coarse, so we expose `accuracy` and an `isApproximate` hint.
 */
import { computed, ref } from 'vue';
import type { TeacherAttendanceGeo } from '@/types/teacher-attendance';

/** Categorised geolocation failure for targeted UI guidance. */
export type GeoErrorKind =
  | null
  | 'unsupported'
  | 'insecure'
  | 'denied'
  | 'unavailable'
  | 'timeout'
  | 'unknown';

/** Accuracy worse than this (metres) is flagged "approximate". */
const APPROXIMATE_ACCURACY_M = 100;

export function useGeolocation() {
  /** True while a fix is being acquired. */
  const isLocating = ref(false);
  /** The last successful fix. */
  const position = ref<TeacherAttendanceGeo | null>(null);
  /** Human Indonesian error if location can't be read. */
  const error = ref<string | null>(null);
  /** Machine-readable failure category for targeted UI guidance. */
  const errorKind = ref<GeoErrorKind>(null);

  /** Whether this browser exposes the geolocation API at all. */
  const isSupported = computed(
    () => typeof navigator !== 'undefined' && !!navigator.geolocation,
  );

  /** Whether the page runs in a secure context (HTTPS/localhost). */
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

  /**
   * True when we have a fix but it's coarse (typical on a desktop using
   * Wi-Fi/IP geolocation). The UI uses this to gently warn the teacher
   * the school geofence check may be off.
   */
  const isApproximate = computed(() => {
    const acc = position.value?.accuracy;
    return typeof acc === 'number' && acc > APPROXIMATE_ACCURACY_M;
  });

  function describeError(e: GeolocationPositionError): {
    kind: GeoErrorKind;
    message: string;
  } {
    switch (e.code) {
      case e.PERMISSION_DENIED:
        return {
          kind: 'denied',
          message:
            'Izin lokasi ditolak. Aktifkan akses lokasi untuk situs ini lalu coba lagi.',
        };
      case e.POSITION_UNAVAILABLE:
        return {
          kind: 'unavailable',
          message:
            'Lokasi tidak tersedia. Pastikan layanan lokasi/GPS aktif lalu coba lagi.',
        };
      case e.TIMEOUT:
        return {
          kind: 'timeout',
          message:
            'Waktu pengambilan lokasi habis. Coba lagi di area dengan sinyal lebih baik.',
        };
      default:
        return { kind: 'unknown', message: 'Gagal mengambil lokasi.' };
    }
  }

  /**
   * Acquire a single fix. Resolves with the position (also stored in
   * `position`) or null on failure (with `error`/`errorKind` set — does
   * not throw, so it is safe to auto-call on mount).
   */
  async function locate(): Promise<TeacherAttendanceGeo | null> {
    error.value = null;
    errorKind.value = null;

    if (!isSecure.value) {
      errorKind.value = 'insecure';
      error.value =
        'Lokasi hanya bisa diakses lewat koneksi aman (HTTPS). Buka halaman ini dengan alamat https:// lalu coba lagi.';
      return null;
    }
    if (!isSupported.value) {
      errorKind.value = 'unsupported';
      error.value = 'Browser ini tidak mendukung akses lokasi.';
      return null;
    }

    isLocating.value = true;
    try {
      const pos = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 15_000,
          maximumAge: 0,
        });
      });
      const geo: TeacherAttendanceGeo = {
        latitude: pos.coords.latitude,
        longitude: pos.coords.longitude,
        accuracy: pos.coords.accuracy,
      };
      position.value = geo;
      return geo;
    } catch (e) {
      const { kind, message } = describeError(e as GeolocationPositionError);
      errorKind.value = kind;
      error.value = message;
      return null;
    } finally {
      isLocating.value = false;
    }
  }

  function clear() {
    position.value = null;
    error.value = null;
    errorKind.value = null;
  }

  return {
    isLocating,
    position,
    error,
    errorKind,
    isSupported,
    isSecure,
    isApproximate,
    locate,
    clear,
  };
}
