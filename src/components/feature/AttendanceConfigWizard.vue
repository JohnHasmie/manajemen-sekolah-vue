<!--
  AttendanceConfigWizard.vue — 5-step guided flow for admin presensi
  settings.

  The full settings screen (AdminAttendanceConfigView) exposes 30+
  controls across four dense sections — the audit called it the most
  daunting page in the app. This wizard doesn't replace the flat form
  (power users prefer it); it OFFERS a step-by-step path for first-
  time admins who need orientation:

    1. Metode      → allowed_methods[], camera_required, location_required
    2. Lokasi      → geofence lat/lng (map or manual), radius, reject vs flag
    3. QR Gerbang  → rotation minutes, geofence-for-QR, student cards
                     (skipped when no QR method was picked in step 1)
    4. Waktu       → checkout_enabled, late_grace_minutes
    5. Tinjau      → summary + one Save button that fires the same
                     TeacherAttendanceService.updateSettings the flat
                     form uses, so both surfaces stay contract-compatible

  Emits `saved` with the updated settings so the parent view can
  refresh its form without a second GET.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import { useToast } from '@/composables/useToast';
import type { TeacherAttendanceSettings } from '@/types/teacher-attendance';
import type { CheckInMethod } from '@/types/attendance-qr';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import GeofenceMapPicker from '@/components/feature/GeofenceMapPicker.vue';
import AttendanceShiftPanel from '@/components/feature/AttendanceShiftPanel.vue';

const props = defineProps<{
  /** Current settings — the wizard opens with these values pre-filled. */
  initial: TeacherAttendanceSettings;
}>();

const emit = defineEmits<{
  close: [];
  /** Fired with the fresh settings the server returned after save. */
  saved: [TeacherAttendanceSettings];
}>();

const toast = useToast();

// ── Wizard state ────────────────────────────────────────────────────
type StepKey = 'metode' | 'lokasi' | 'qr' | 'waktu' | 'shift' | 'tinjau';
type StepDef = { key: StepKey; label: string };
const step = ref(0);
const saving = ref(false);

/** Working copy — mutated per step, committed via updateSettings in step 5. */
const draft = ref<TeacherAttendanceSettings>(structuredClone(props.initial));

// Method toggles drive `allowed_methods[]` on save. SELFIE stays in
// the array (mobile parity — the backend enforces ≥1 method, selfie
// is the baseline every school keeps).
const qrGateEnabled = ref(
  (props.initial.allowed_methods ?? ['SELFIE']).includes('QR_GATE'),
);
const qrCardEnabled = ref(
  (props.initial.allowed_methods ?? ['SELFIE']).includes('QR_CARD'),
);

// Geofence lat/lng are edited as strings so an empty field reads as
// "use the school pin" (null) rather than 0 — matches the flat form.
const geofenceLatStr = ref(
  props.initial.geofence_lat != null ? String(props.initial.geofence_lat) : '',
);
const geofenceLngStr = ref(
  props.initial.geofence_lng != null ? String(props.initial.geofence_lng) : '',
);

// Re-sync if the parent passes fresh initial settings (e.g. the wizard
// is re-opened after a save from the flat form on the same session).
watch(
  () => props.initial,
  (v) => {
    draft.value = structuredClone(v);
    qrGateEnabled.value = (v.allowed_methods ?? ['SELFIE']).includes('QR_GATE');
    qrCardEnabled.value = (v.allowed_methods ?? ['SELFIE']).includes('QR_CARD');
    geofenceLatStr.value = v.geofence_lat != null ? String(v.geofence_lat) : '';
    geofenceLngStr.value = v.geofence_lng != null ? String(v.geofence_lng) : '';
  },
);

// ── Step definitions ────────────────────────────────────────────────
// The QR step is skipped when the admin picks selfie-only in step 1 —
// nothing on it applies. `steps` is computed so the progress indicator
// and Next/Back correctly account for the skip.
const steps = computed<StepDef[]>(() => {
  const base: StepDef[] = [
    { key: 'metode', label: 'Metode' },
    { key: 'lokasi', label: 'Lokasi' },
  ];
  if (qrGateEnabled.value || qrCardEnabled.value) {
    base.push({ key: 'qr', label: 'QR Gerbang' });
  }
  base.push({ key: 'waktu', label: 'Waktu' });
  // Shift step comes after Waktu — schools with a single shift only
  // ever set max_daily_shifts_per_person = 1 and leave the list empty,
  // so this step gracefully renders "belum ada shift" for them.
  base.push({ key: 'shift', label: 'Shift' });
  base.push({ key: 'tinjau', label: 'Tinjau' });
  return base;
});
const currentStep = computed(() => steps.value[step.value] ?? steps.value[0]);
const isLastStep = computed(() => step.value >= steps.value.length - 1);
const canGoBack = computed(() => step.value > 0);

// ── Coord parsing helpers (identical to the flat form) ──────────────
function parseCoord(raw: string): number | null {
  const t = raw.trim();
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}
function onMapPick(p: { lat: number; lng: number }): void {
  geofenceLatStr.value = String(p.lat);
  geofenceLngStr.value = String(p.lng);
}

// ── Client-side range validation (matches backend bounds) ───────────
function validateAll(): string | null {
  const lat = parseCoord(geofenceLatStr.value);
  const lng = parseCoord(geofenceLngStr.value);
  if (lat != null && (lat < -90 || lat > 90)) {
    return 'Latitude geofence harus antara -90 dan 90.';
  }
  if (lng != null && (lng < -180 || lng > 180)) {
    return 'Longitude geofence harus antara -180 dan 180.';
  }
  if (draft.value.geofence_radius_m < 10 || draft.value.geofence_radius_m > 5000) {
    return 'Radius geofence harus antara 10 dan 5000 meter.';
  }
  if (draft.value.late_grace_minutes < 0 || draft.value.late_grace_minutes > 600) {
    return 'Toleransi keterlambatan harus antara 0 dan 600 menit.';
  }
  const rot = draft.value.gate_qr_rotation_minutes ?? 15;
  if (rot < 1 || rot > 60) {
    return 'Rotasi QR gerbang harus antara 1 dan 60 menit.';
  }
  return null;
}

// ── Step navigation ─────────────────────────────────────────────────
function next(): void {
  if (isLastStep.value) return;
  step.value += 1;
}
function back(): void {
  if (!canGoBack.value) return;
  step.value -= 1;
}
function jumpTo(idx: number): void {
  if (idx < 0 || idx >= steps.value.length) return;
  step.value = idx;
}

// ── Save (fires once at step 5) ─────────────────────────────────────
async function save(): Promise<void> {
  const err = validateAll();
  if (err) {
    toast.error(err);
    return;
  }
  const allowedMethods: CheckInMethod[] = ['SELFIE'];
  if (qrGateEnabled.value) allowedMethods.push('QR_GATE');
  if (qrCardEnabled.value) allowedMethods.push('QR_CARD');
  saving.value = true;
  try {
    const saved = await TeacherAttendanceService.updateSettings({
      camera_required: draft.value.camera_required,
      location_required: draft.value.location_required,
      checkout_enabled: draft.value.checkout_enabled,
      geofence_lat: parseCoord(geofenceLatStr.value),
      geofence_lng: parseCoord(geofenceLngStr.value),
      geofence_radius_m: draft.value.geofence_radius_m,
      reject_outside_geofence: draft.value.reject_outside_geofence,
      late_grace_minutes: draft.value.late_grace_minutes,
      allowed_methods: allowedMethods,
      gate_qr_rotation_minutes: draft.value.gate_qr_rotation_minutes ?? 15,
      geofence_required_for_qr: !!draft.value.geofence_required_for_qr,
      issue_student_cards: !!draft.value.issue_student_cards,
    });
    toast.success('Pengaturan kehadiran tersimpan.');
    emit('saved', saved);
    emit('close');
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    saving.value = false;
  }
}

// ── Presentation helpers for the review step ────────────────────────
function methodSummary(): string {
  const parts: string[] = ['Selfie'];
  if (qrGateEnabled.value) parts.push('QR Gerbang');
  if (qrCardEnabled.value) parts.push('QR Kartu');
  return parts.join(' + ');
}
function locationSummary(): string {
  const lat = parseCoord(geofenceLatStr.value);
  const lng = parseCoord(geofenceLngStr.value);
  const pinStr =
    lat != null && lng != null
      ? `${lat.toFixed(5)}, ${lng.toFixed(5)}`
      : 'Pakai titik sekolah default';
  return `${pinStr} · ${draft.value.geofence_radius_m} m · ${draft.value.reject_outside_geofence ? 'Tolak di luar radius' : 'Boleh di luar (ditandai)'}`;
}
function qrSummary(): string {
  const rot = draft.value.gate_qr_rotation_minutes ?? 15;
  const parts = [`Rotasi ${rot} menit`];
  if (draft.value.geofence_required_for_qr) parts.push('geofence wajib');
  if (draft.value.issue_student_cards) parts.push('kartu siswa aktif');
  return parts.join(' · ');
}
function timeSummary(): string {
  const grace = draft.value.late_grace_minutes;
  const graceStr = grace > 0 ? `Toleransi ${grace} menit` : 'Tanpa toleransi';
  const checkout = draft.value.checkout_enabled
    ? 'Presensi pulang aktif'
    : 'Presensi pulang nonaktif';
  return `${checkout} · ${graceStr}`;
}

const showsQrStep = computed(
  () => qrGateEnabled.value || qrCardEnabled.value,
);
</script>

<template>
  <Modal
    title="Panduan Pengaturan Presensi"
    :subtitle="`Langkah ${step + 1} dari ${steps.length} · ${currentStep.label}`"
    size="lg"
    @close="$emit('close')"
  >
    <div class="space-y-4">
      <!-- STEP INDICATOR — clickable dots so a returning admin can
           jump back to any step to tweak a single field. -->
      <div class="flex items-center gap-1.5">
        <button
          v-for="(s, idx) in steps"
          :key="s.key"
          type="button"
          class="flex-1 h-1.5 rounded-full transition-colors"
          :class="
            idx <= step
              ? 'bg-role-admin'
              : 'bg-slate-200 hover:bg-slate-300'
          "
          :aria-label="`Langkah ${idx + 1} · ${s.label}`"
          @click="jumpTo(idx)"
        />
      </div>

      <!-- ─── Step 1: Metode ───────────────────────────────── -->
      <section v-if="currentStep.key === 'metode'" class="space-y-4">
        <div>
          <h3 class="text-[15px] font-black text-slate-900">Metode presensi</h3>
          <p class="text-[12px] text-slate-500 mt-1 leading-relaxed">
            Selfie selalu tersedia sebagai metode dasar. Aktifkan QR Gerbang
            kalau sekolah punya QR poster di gerbang, atau QR Kartu untuk
            kartu personel guru.
          </p>
        </div>
        <label
          class="flex items-start gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer"
        >
          <input
            v-model="qrGateEnabled"
            type="checkbox"
            class="mt-1 accent-role-admin"
          />
          <div>
            <p class="text-[13.5px] font-black text-slate-900">
              QR Gerbang
            </p>
            <p class="text-[11.5px] text-slate-500 mt-0.5">
              Guru scan QR poster gerbang. Poster otomatis berotasi supaya
              tidak bisa di-foto lalu dibagikan.
            </p>
          </div>
        </label>
        <label
          class="flex items-start gap-3 p-3 rounded-xl border border-slate-200 hover:bg-slate-50 cursor-pointer"
        >
          <input
            v-model="qrCardEnabled"
            type="checkbox"
            class="mt-1 accent-role-admin"
          />
          <div>
            <p class="text-[13.5px] font-black text-slate-900">
              QR Kartu
            </p>
            <p class="text-[11.5px] text-slate-500 mt-0.5">
              Setiap guru punya kartu QR unik yang mereka scan sendiri di
              perangkat mereka.
            </p>
          </div>
        </label>

        <div class="pt-2 border-t border-slate-100">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-2">
            Syarat presensi selfie
          </p>
          <label class="flex items-center gap-3 py-2 cursor-pointer">
            <input
              v-model="draft.camera_required"
              type="checkbox"
              class="accent-role-admin"
            />
            <span class="text-[12.5px] text-slate-800">
              Foto selfie wajib saat presensi
            </span>
          </label>
          <label class="flex items-center gap-3 py-2 cursor-pointer">
            <input
              v-model="draft.location_required"
              type="checkbox"
              class="accent-role-admin"
            />
            <span class="text-[12.5px] text-slate-800">
              GPS wajib saat presensi
            </span>
          </label>
        </div>
      </section>

      <!-- ─── Step 2: Lokasi ───────────────────────────────── -->
      <section v-else-if="currentStep.key === 'lokasi'" class="space-y-4">
        <div>
          <h3 class="text-[15px] font-black text-slate-900">Lokasi sekolah</h3>
          <p class="text-[12px] text-slate-500 mt-1 leading-relaxed">
            Klik peta untuk memilih titik sekolah, lalu atur radius yang
            masih dianggap "di sekolah". Kosongkan koordinat kalau ingin
            pakai titik default sekolah.
          </p>
        </div>
        <GeofenceMapPicker
          :lat="parseCoord(geofenceLatStr)"
          :lng="parseCoord(geofenceLngStr)"
          :radius="draft.geofence_radius_m"
          :fallback-lat="draft.school_latitude ?? null"
          :fallback-lng="draft.school_longitude ?? null"
          @pick="onMapPick"
        />
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
              Latitude
            </label>
            <input
              v-model="geofenceLatStr"
              type="text"
              inputmode="decimal"
              placeholder="-6.20000"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-mono outline-none focus:border-role-admin"
            />
          </div>
          <div>
            <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
              Longitude
            </label>
            <input
              v-model="geofenceLngStr"
              type="text"
              inputmode="decimal"
              placeholder="106.80000"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-mono outline-none focus:border-role-admin"
            />
          </div>
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Radius (meter)
          </label>
          <div class="mt-1 flex items-center gap-3">
            <input
              v-model.number="draft.geofence_radius_m"
              type="number"
              min="10"
              max="5000"
              class="w-24 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold outline-none focus:border-role-admin"
            />
            <p class="text-[11.5px] text-slate-500">
              Batas 10–5000 meter. 150 m biasanya cukup untuk sekolah dasar
              di komplek rumah.
            </p>
          </div>
        </div>
        <div class="pt-2 border-t border-slate-100">
          <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest mb-2">
            Kalau presensi di luar radius…
          </p>
          <label class="flex items-start gap-3 py-1.5 cursor-pointer">
            <input
              v-model="draft.reject_outside_geofence"
              type="radio"
              :value="true"
              class="mt-1 accent-role-admin"
            />
            <div>
              <p class="text-[12.5px] font-bold text-slate-900">Tolak presensi</p>
              <p class="text-[11px] text-slate-500">
                Guru harus di dalam radius. Cocok untuk sekolah yang ingin
                ketat.
              </p>
            </div>
          </label>
          <label class="flex items-start gap-3 py-1.5 cursor-pointer">
            <input
              v-model="draft.reject_outside_geofence"
              type="radio"
              :value="false"
              class="mt-1 accent-role-admin"
            />
            <div>
              <p class="text-[12.5px] font-bold text-slate-900">
                Boleh, tapi ditandai
              </p>
              <p class="text-[11px] text-slate-500">
                Presensi tetap tercatat, tapi laporan menandai "di luar
                sekolah". Cocok untuk kunjungan lapangan atau tugas luar.
              </p>
            </div>
          </label>
        </div>
      </section>

      <!-- ─── Step 3: QR Gerbang (only if a QR method was picked) ─── -->
      <section v-else-if="currentStep.key === 'qr'" class="space-y-4">
        <div>
          <h3 class="text-[15px] font-black text-slate-900">Pengaturan QR</h3>
          <p class="text-[12px] text-slate-500 mt-1 leading-relaxed">
            Rotasi otomatis mencegah QR di-foto lalu di-share ke grup WA.
            Kelipatan menit lebih rendah lebih aman, kelipatan lebih tinggi
            hemat cetak ulang poster.
          </p>
        </div>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Rotasi QR gerbang (menit)
          </label>
          <div class="mt-1 flex items-center gap-3">
            <input
              v-model.number="draft.gate_qr_rotation_minutes"
              type="number"
              min="1"
              max="60"
              class="w-24 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold outline-none focus:border-role-admin"
            />
            <p class="text-[11.5px] text-slate-500">1–60 menit. Default 15.</p>
          </div>
        </div>
        <label class="flex items-start gap-3 py-2 cursor-pointer">
          <input
            v-model="draft.geofence_required_for_qr"
            type="checkbox"
            class="mt-1 accent-role-admin"
          />
          <div>
            <p class="text-[12.5px] font-bold text-slate-900">
              Wajibkan geofence saat scan QR
            </p>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Kalau dimatikan, guru bisa scan QR gerbang dari mana saja —
              biasanya berguna untuk staf lapangan.
            </p>
          </div>
        </label>
        <label class="flex items-start gap-3 py-2 cursor-pointer">
          <input
            v-model="draft.issue_student_cards"
            type="checkbox"
            class="mt-1 accent-role-admin"
          />
          <div>
            <p class="text-[12.5px] font-bold text-slate-900">
              Terbitkan juga kartu siswa
            </p>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Selain guru/staf, siswa ikut dibuatkan kartu QR pribadi. Kalau
              baru mulai, biasanya mulai dari kartu guru dulu.
            </p>
          </div>
        </label>
      </section>

      <!-- ─── Step 4: Waktu ───────────────────────────────── -->
      <section v-else-if="currentStep.key === 'waktu'" class="space-y-4">
        <div>
          <h3 class="text-[15px] font-black text-slate-900">Waktu presensi</h3>
          <p class="text-[12px] text-slate-500 mt-1 leading-relaxed">
            Beberapa sekolah tidak menuntut presensi pulang, tinggal
            matikan saja di sini. Toleransi 0 menit = telat sedetik pun
            tercatat telat.
          </p>
        </div>
        <label class="flex items-start gap-3 py-2 cursor-pointer">
          <input
            v-model="draft.checkout_enabled"
            type="checkbox"
            class="mt-1 accent-role-admin"
          />
          <div>
            <p class="text-[12.5px] font-bold text-slate-900">
              Aktifkan presensi pulang
            </p>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Guru & staf ikut mengecek keluar di akhir hari. Bisa disetel
              per-aturan di tab "Aturan Jam Pulang" nanti.
            </p>
          </div>
        </label>
        <div>
          <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
            Toleransi keterlambatan (menit)
          </label>
          <div class="mt-1 flex items-center gap-3">
            <input
              v-model.number="draft.late_grace_minutes"
              type="number"
              min="0"
              max="600"
              class="w-24 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold outline-none focus:border-role-admin"
            />
            <p class="text-[11.5px] text-slate-500">
              0–600 menit. Setelah batas ini, presensi ditandai "Telat".
            </p>
          </div>
        </div>
      </section>

      <!-- ─── Step 5: Shift ──────────────────────────────── -->
      <section v-else-if="currentStep.key === 'shift'" class="space-y-4">
        <div>
          <h3 class="text-[15px] font-black text-slate-900">Shift kerja</h3>
          <p class="text-[12px] text-slate-500 mt-1 leading-relaxed">
            Sekolah reguler biasanya cukup pakai satu shift dan lewati saja
            langkah ini. Bimbel atau tempat kerja bergilir (pagi/sore/malam)
            bisa tambah beberapa shift di sini.
          </p>
        </div>
        <AttendanceShiftPanel
          :initial-max-daily-shifts="draft.max_daily_shifts_per_person ?? 1"
          @settings-changed="(p) => (draft.max_daily_shifts_per_person = p.max_daily_shifts_per_person)"
        />
      </section>

      <!-- ─── Step 6: Tinjau ─────────────────────────────── -->
      <section v-else class="space-y-3">
        <div>
          <h3 class="text-[15px] font-black text-slate-900">
            Tinjau pengaturan
          </h3>
          <p class="text-[12px] text-slate-500 mt-1 leading-relaxed">
            Cek ringkasan di bawah. Klik satu baris untuk kembali ke
            langkahnya kalau ada yang perlu diubah, atau langsung Simpan.
          </p>
        </div>
        <button
          type="button"
          class="w-full text-left bg-slate-50 hover:bg-slate-100 border border-slate-200 rounded-2xl p-3 flex items-center gap-3 transition-colors"
          @click="jumpTo(0)"
        >
          <span
            class="w-8 h-8 rounded-lg bg-white grid place-items-center text-[13px] font-black text-role-admin flex-shrink-0"
          >1</span>
          <span class="flex-1 min-w-0">
            <span class="block text-3xs font-bold text-slate-400 uppercase tracking-widest">
              Metode
            </span>
            <span class="block text-[12.5px] font-bold text-slate-800 truncate">
              {{ methodSummary() }}
            </span>
          </span>
        </button>
        <button
          type="button"
          class="w-full text-left bg-slate-50 hover:bg-slate-100 border border-slate-200 rounded-2xl p-3 flex items-center gap-3 transition-colors"
          @click="jumpTo(1)"
        >
          <span
            class="w-8 h-8 rounded-lg bg-white grid place-items-center text-[13px] font-black text-role-admin flex-shrink-0"
          >2</span>
          <span class="flex-1 min-w-0">
            <span class="block text-3xs font-bold text-slate-400 uppercase tracking-widest">
              Lokasi
            </span>
            <span class="block text-[12.5px] font-bold text-slate-800 truncate">
              {{ locationSummary() }}
            </span>
          </span>
        </button>
        <button
          v-if="showsQrStep"
          type="button"
          class="w-full text-left bg-slate-50 hover:bg-slate-100 border border-slate-200 rounded-2xl p-3 flex items-center gap-3 transition-colors"
          @click="jumpTo(2)"
        >
          <span
            class="w-8 h-8 rounded-lg bg-white grid place-items-center text-[13px] font-black text-role-admin flex-shrink-0"
          >3</span>
          <span class="flex-1 min-w-0">
            <span class="block text-3xs font-bold text-slate-400 uppercase tracking-widest">
              QR Gerbang
            </span>
            <span class="block text-[12.5px] font-bold text-slate-800 truncate">
              {{ qrSummary() }}
            </span>
          </span>
        </button>
        <button
          type="button"
          class="w-full text-left bg-slate-50 hover:bg-slate-100 border border-slate-200 rounded-2xl p-3 flex items-center gap-3 transition-colors"
          @click="jumpTo(showsQrStep ? 3 : 2)"
        >
          <span
            class="w-8 h-8 rounded-lg bg-white grid place-items-center text-[13px] font-black text-role-admin flex-shrink-0"
          >{{ showsQrStep ? 4 : 3 }}</span>
          <span class="flex-1 min-w-0">
            <span class="block text-3xs font-bold text-slate-400 uppercase tracking-widest">
              Waktu
            </span>
            <span class="block text-[12.5px] font-bold text-slate-800 truncate">
              {{ timeSummary() }}
            </span>
          </span>
        </button>
      </section>

      <!-- Footer nav — inline (Modal has no dedicated footer slot). -->
      <div class="flex items-center gap-2 pt-4 border-t border-slate-100">
        <Button
          variant="secondary"
          :disabled="!canGoBack"
          @click="back"
        >
          Kembali
        </Button>
        <div class="flex-1"></div>
        <Button
          v-if="!isLastStep"
          variant="primary"
          @click="next"
        >
          Lanjut →
        </Button>
        <Button
          v-else
          variant="primary"
          :loading="saving"
          @click="save"
        >
          Simpan pengaturan
        </Button>
      </div>
    </div>
  </Modal>
</template>
