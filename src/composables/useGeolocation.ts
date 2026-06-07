/**
 * useGeolocation — one-shot GPS fix for PRESENSI GURU.
 *
 * Wraps `navigator.geolocation.getCurrentPosition` in a promise so the
 * presensi view can `await cam-then-gps` before submitting. The backend
 * verifies the coordinates against the school geofence (haversine) — we
 * just need an accurate-enough fix and a friendly Indonesian error when
 * the user denies permission or location is unavailable.
 */
import { ref } from 'vue';
import type { TeacherAttendanceGeo } from '@/types/teacher-attendance';

export function useGeolocation() {
  /** True while a fix is being acquired. */
  const isLocating = ref(false);
  /** The last successful fix. */
  const position = ref<TeacherAttendanceGeo | null>(null);
  /** Human Indonesian error if location can't be read. */
  const error = ref<string | null>(null);

  function describeError(e: GeolocationPositionError): string {
    switch (e.code) {
      case e.PERMISSION_DENIED:
        return 'Izin lokasi ditolak. Aktifkan akses lokasi di browser lalu coba lagi.';
      case e.POSITION_UNAVAILABLE:
        return 'Lokasi tidak tersedia. Pastikan GPS aktif lalu coba lagi.';
      case e.TIMEOUT:
        return 'Waktu pengambilan lokasi habis. Coba lagi di area dengan sinyal lebih baik.';
      default:
        return 'Gagal mengambil lokasi.';
    }
  }

  /**
   * Acquire a single fix. Resolves with the position (also stored in
   * `position`) or null on failure (with `error` set — does not throw).
   */
  async function locate(): Promise<TeacherAttendanceGeo | null> {
    error.value = null;
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
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
      error.value = describeError(e as GeolocationPositionError);
      return null;
    } finally {
      isLocating.value = false;
    }
  }

  function clear() {
    position.value = null;
    error.value = null;
  }

  return { isLocating, position, error, locate, clear };
}
