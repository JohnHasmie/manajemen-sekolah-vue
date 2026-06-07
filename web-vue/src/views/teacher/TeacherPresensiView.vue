<!--
  TeacherPresensiView.vue — PRESENSI GURU (presensi harian guru).

  One check-in per teaching day + an optional check-out (toggled per
  school by the admin). The teacher:
    1. Bootstraps config (settings + today's schedule + today's state).
    2. Takes a LIVE webcam selfie (face + school background) — enforced
       via getUserMedia; there is NO gallery upload by design (safe v1).
    3. Captures GPS when the school requires location (geofence verified
       server-side via haversine).
    4. Submits multipart check-in/out. The SERVER stamps the timestamps
       and computes present/late + geofence distance.

  Layout:
    - BrandPageHeader (guru gradient) with server clock + date
    - Status banner: belum presensi / sudah masuk / sudah pulang +
      late + outside-geofence feedback
    - Today's teaching schedule strip
    - Capture card: webcam preview → snapshot, GPS chip, notes, submit
    - History link
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import { useWebcamCapture } from '@/composables/useWebcamCapture';
import { useGeolocation } from '@/composables/useGeolocation';
import { useToast } from '@/composables/useToast';
import type {
  TeacherAttendanceConfig,
  TeacherAttendanceRecord,
} from '@/types/teacher-attendance';
import { teacherAttendanceStatusLabel } from '@/types/teacher-attendance';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';

const router = useRouter();
const toast = useToast();
const cam = useWebcamCapture();
const geo = useGeolocation();

// ── Bootstrap state ─────────────────────────────────────────────
const config = ref<TeacherAttendanceConfig | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

// ── Capture state ───────────────────────────────────────────────
type Mode = 'check-in' | 'check-out';
const videoRef = ref<HTMLVideoElement | null>(null);
/** The last snapshot blob + its preview object URL. */
const photoBlob = ref<Blob | null>(null);
const photoUrl = ref<string | null>(null);
const notes = ref('');
const submitting = ref(false);

// Refresh the displayed clock once per minute.
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

// ── Methods labels (which were captured) ────────────────────────
const requiredMethodsLabel = computed(() => {
  const parts: string[] = [];
  if (cameraRequired.value) parts.push('Foto selfie');
  if (locationRequired.value) parts.push('Lokasi GPS');
  if (parts.length === 0) return 'Tanpa syarat tambahan';
  return parts.join(' + ');
});

// ── Validation: can we submit? ──────────────────────────────────
const photoSatisfied = computed(
  () => !cameraRequired.value || !!photoBlob.value,
);
const locationSatisfied = computed(
  () => !locationRequired.value || !!geo.position.value,
);
const canSubmit = computed(
  () => photoSatisfied.value && locationSatisfied.value && !submitting.value,
);

// ── Bootstrap ───────────────────────────────────────────────────
async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    config.value = await TeacherAttendanceService.config();
    // Auto-start the camera when a capture form is needed + camera is
    // required, so the teacher sees the live preview immediately.
    if (showCaptureForm.value && cameraRequired.value) {
      // Wait a tick so the <video> is mounted.
      await new Promise((r) => setTimeout(r, 0));
      if (videoRef.value) await cam.start(videoRef.value);
    }
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => {
  reload();
  tickTimer = setInterval(() => (nowTick.value = Date.now()), 60_000);
});

onUnmounted(() => {
  if (tickTimer) clearInterval(tickTimer);
  cam.stop();
  if (photoUrl.value) URL.revokeObjectURL(photoUrl.value);
});

// ── Camera actions ──────────────────────────────────────────────
async function startCamera() {
  if (videoRef.value) await cam.start(videoRef.value);
}

async function takeSnapshot() {
  const blob = await cam.snapshot();
  if (!blob) {
    toast.error('Gagal mengambil foto. Pastikan kamera aktif.');
    return;
  }
  if (photoUrl.value) URL.revokeObjectURL(photoUrl.value);
  photoBlob.value = blob;
  photoUrl.value = URL.createObjectURL(blob);
  // Free the camera once we have the still — the privacy light turns off.
  cam.stop();
}

async function retakePhoto() {
  if (photoUrl.value) URL.revokeObjectURL(photoUrl.value);
  photoBlob.value = null;
  photoUrl.value = null;
  await startCamera();
}

// ── Location action ─────────────────────────────────────────────
async function captureLocation() {
  const pos = await geo.locate();
  if (!pos && geo.error.value) toast.error(geo.error.value);
}

// ── Submit ──────────────────────────────────────────────────────
async function submit() {
  if (!canSubmit.value) {
    if (!photoSatisfied.value) toast.error('Foto selfie wajib diambil.');
    else if (!locationSatisfied.value)
      toast.error('Lokasi GPS wajib diaktifkan.');
    return;
  }
  submitting.value = true;
  try {
    const payload = {
      photo: photoBlob.value,
      latitude: geo.position.value?.latitude ?? null,
      longitude: geo.position.value?.longitude ?? null,
      notes: notes.value.trim() || null,
    };
    let result: TeacherAttendanceRecord;
    if (mode.value === 'check-out') {
      result = await TeacherAttendanceService.checkOut(payload);
      toast.success('Presensi pulang berhasil dicatat.');
    } else {
      result = await TeacherAttendanceService.checkIn(payload);
      const lateMsg = result.status === 'late' ? ' (tercatat terlambat)' : '';
      toast.success(`Presensi masuk berhasil dicatat${lateMsg}.`);
    }
    // Reset the form + reload the live state.
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
  geo.clear();
  cam.stop();
}

function gotoHistory() {
  router.push('/teacher/my-attendance/history');
}
</script>

<template>
  <div class="space-y-md">
    <!-- ── Header ─────────────────────────────────────────────── -->
    <BrandPageHeader
      role="guru"
      kicker="Presensi Guru · Harian"
      title="Presensi Hari Ini"
      :meta="serverDate"
      live-dot
    >
      <div class="text-right">
        <p class="text-2xl font-black text-white tracking-tight leading-none">
          {{ clockNow }}
        </p>
        <p
          class="text-[10px] font-bold text-white/80 uppercase tracking-widest mt-1"
        >
          Waktu Server
        </p>
      </div>
    </BrandPageHeader>

    <!-- ── Loading / error ────────────────────────────────────── -->
    <div
      v-if="isLoading"
      class="flex items-center justify-center py-xl text-slate-400"
    >
      <Spinner size="md" />
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
        Coba lagi
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
            Presensi hari ini selesai
          </p>
          <p class="text-[11.5px] text-emerald-700 mt-0.5">
            Masuk {{ fmtTime(record?.check_in_at) }} · Pulang
            {{ fmtTime(record?.check_out_at) }}
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
            Sudah presensi masuk · {{ fmtTime(record?.check_in_at) }}
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
              · <span class="text-red-600 font-bold">di luar area sekolah</span>
            </template>
            <template v-else-if="record?.check_in_distance_m != null">
              · {{ record.check_in_distance_m }} m dari sekolah
            </template>
          </p>
          <p v-if="!checkoutEnabled" class="text-[11px] text-slate-400 mt-1">
            Presensi pulang tidak diaktifkan untuk sekolah ini.
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
            Belum presensi masuk
          </p>
          <p class="text-[11.5px] text-amber-700 mt-0.5">
            <template v-if="config.late_after">
              Batas tepat waktu: {{ lateAfterLabel }}
              <span v-if="config.first_teaching_start" class="text-amber-600">
                (mengajar pertama {{ firstStartLabel }})
              </span>
            </template>
            <template v-else
              >Tidak ada jadwal mengajar terdeteksi hari ini.</template
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
            Jadwal Mengajar Hari Ini
            <span class="text-slate-400 font-medium"
              >· {{ config.today_schedule.length }} sesi</span
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
        class="bg-white border border-slate-200 rounded-2xl p-4 sm:p-5 space-y-md"
      >
        <div class="flex items-center justify-between gap-2">
          <div>
            <p class="text-[13px] font-black text-slate-900">
              {{ mode === 'check-out' ? 'Presensi Pulang' : 'Presensi Masuk' }}
            </p>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Syarat: {{ requiredMethodsLabel }}
            </p>
          </div>
          <span
            class="text-[10px] font-bold uppercase tracking-widest px-2 py-1 rounded-full"
            :class="
              mode === 'check-out'
                ? 'bg-violet-100 text-violet-700'
                : 'bg-emerald-100 text-emerald-700'
            "
          >
            {{ mode === 'check-out' ? 'Pulang' : 'Masuk' }}
          </span>
        </div>

        <!-- Camera capture -->
        <div v-if="cameraRequired">
          <p
            class="text-[11px] font-bold text-slate-600 mb-2 flex items-center gap-1.5"
          >
            <NavIcon name="camera" :size="13" class="text-brand-cobalt" />
            Foto Selfie (wajah + latar sekolah)
          </p>

          <!-- Preview of captured still -->
          <div
            v-if="photoUrl"
            class="relative rounded-xl overflow-hidden bg-slate-900 aspect-video"
          >
            <img
              :src="photoUrl"
              alt="Foto presensi"
              class="w-full h-full object-cover"
            />
            <button
              type="button"
              class="absolute bottom-2 right-2 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/90 text-slate-800 text-[11px] font-bold hover:bg-white"
              @click="retakePhoto"
            >
              <NavIcon name="refresh-cw" :size="12" />Ambil ulang
            </button>
          </div>

          <!-- Live camera preview -->
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
              <div
                v-if="!cam.isActive.value && !cam.isStarting.value"
                class="absolute inset-0 grid place-items-center text-center px-4"
              >
                <div>
                  <NavIcon
                    name="camera"
                    :size="28"
                    class="text-white/70 mx-auto mb-2"
                  />
                  <p class="text-[12px] text-white/80 font-medium">
                    {{ cam.error.value ?? 'Kamera belum aktif' }}
                  </p>
                </div>
              </div>
              <div
                v-if="cam.isStarting.value"
                class="absolute inset-0 grid place-items-center"
              >
                <Spinner size="md" />
              </div>
            </div>
            <div class="flex items-center gap-2">
              <Button
                v-if="!cam.isActive.value"
                variant="secondary"
                size="sm"
                block
                :loading="cam.isStarting.value"
                @click="startCamera"
              >
                <NavIcon name="camera" :size="13" />Aktifkan kamera
              </Button>
              <Button
                v-else
                variant="primary"
                size="sm"
                block
                @click="takeSnapshot"
              >
                <NavIcon name="camera" :size="13" />Ambil foto
              </Button>
            </div>
            <p
              v-if="cam.error.value"
              class="text-[11px] text-red-600 font-medium"
            >
              {{ cam.error.value }}
            </p>
          </div>
        </div>

        <!-- Location capture -->
        <div v-if="locationRequired">
          <p
            class="text-[11px] font-bold text-slate-600 mb-2 flex items-center gap-1.5"
          >
            <NavIcon name="map-pin" :size="13" class="text-brand-cobalt" />
            Lokasi GPS
          </p>
          <div
            class="flex items-center gap-3 rounded-xl border p-3"
            :class="
              geo.position.value
                ? 'border-emerald-200 bg-emerald-50'
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
              <NavIcon name="map-pin" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <template v-if="geo.position.value">
                <p class="text-[12px] font-bold text-emerald-800">
                  Lokasi terdeteksi
                </p>
                <p class="text-[11px] text-emerald-700 tabular-nums">
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
              <template v-else>
                <p class="text-[12px] font-bold text-slate-600">
                  Lokasi belum diambil
                </p>
                <p class="text-[11px] text-slate-400">
                  Server memverifikasi jarak ke sekolah (geofence).
                </p>
              </template>
            </div>
            <Button
              variant="secondary"
              size="sm"
              :loading="geo.isLocating.value"
              @click="captureLocation"
            >
              {{ geo.position.value ? 'Perbarui' : 'Ambil lokasi' }}
            </Button>
          </div>
          <p
            v-if="geo.error.value"
            class="text-[11px] text-red-600 font-medium mt-1.5"
          >
            {{ geo.error.value }}
          </p>
        </div>

        <!-- Notes -->
        <div>
          <label class="text-[11px] font-bold text-slate-600 mb-1.5 block">
            Catatan (opsional)
          </label>
          <textarea
            v-model="notes"
            rows="2"
            maxlength="1000"
            placeholder="Mis. ada keperluan dinas, dsb."
            class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[13px] text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30 resize-none"
          ></textarea>
        </div>

        <!-- Submit -->
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
          {{
            mode === 'check-out'
              ? 'Presensi Pulang Sekarang'
              : 'Presensi Masuk Sekarang'
          }}
        </Button>
        <p class="text-[10.5px] text-slate-400 text-center -mt-1">
          Waktu presensi dicatat oleh server, bukan jam perangkat Anda.
        </p>
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
          <p class="text-[13px] font-bold text-slate-900">Riwayat Presensi</p>
          <p class="text-[11px] text-slate-500">Lihat catatan presensi Anda</p>
        </div>
        <span class="text-slate-300">→</span>
      </button>
    </template>
  </div>
</template>
