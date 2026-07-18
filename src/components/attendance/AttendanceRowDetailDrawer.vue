<!--
  AttendanceRowDetailDrawer.vue — single-row detail panel opened from
  a Log Harian row on the pegawai attendance dashboard (MR-3 Opsi A).

  Right-side slide-over that shows one teacher_attendances row in
  full: status pills, Masuk / Pulang photo + jam + jarak, mini map
  with geofence circle + marker, and admin-only action buttons.

  Map rendering — we deliberately do NOT pull in Leaflet for MR-3.
  A hand-rolled SVG placeholder centred on the geofence with a marker
  offset by the row's check-in distance/bearing is enough to give the
  admin a spatial sense of the check-in. A follow-up MR can swap this
  for a real Leaflet mini-map without changing the drawer's public
  surface.

  The drawer is a "dumb" presentational component — the parent owns
  the open state and the row payload. On `close`, the parent clears
  its selection.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type {
  TeacherAttendanceRecord,
  TeacherAttendanceSettings,
} from '@/types/teacher-attendance';
import {
  teacherAttendanceEmployeeNumber,
  teacherAttendancePersonName,
  teacherAttendancePersonnelLabel,
  teacherAttendanceStatusLabel,
} from '@/types/teacher-attendance';

const props = defineProps<{
  open: boolean;
  row: TeacherAttendanceRecord | null;
  /**
   * Optional school settings so the map placeholder can plot the
   * canonical geofence centre + radius. When absent the map falls
   * back to a plain "no geofence" caption so the drawer still opens.
   */
  settings?: TeacherAttendanceSettings | null;
}>();

defineEmits<{
  close: [];
  note: [TeacherAttendanceRecord];
  verify: [TeacherAttendanceRecord];
}>();

// ── Formatting helpers (kept local — the view has its own too but a
//    drawer shouldn't depend on a specific parent's helpers) ─────
function fmtTime(iso: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

function fmtDate(ymd: string | null | undefined): string {
  if (!ymd) return '-';
  return new Date(ymd).toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

function fmtDistance(m: number | null | undefined): string {
  if (m === null || m === undefined) return '-';
  if (m < 1000) return `${Math.round(m)} m`;
  return `${(m / 1000).toFixed(2)} km`;
}

/** Working duration in HH:mm; null when either leg is missing. */
const durationLabel = computed<string | null>(() => {
  const r = props.row;
  if (!r?.check_in_at || !r?.check_out_at) return null;
  const inMs = new Date(r.check_in_at).getTime();
  const outMs = new Date(r.check_out_at).getTime();
  if (!Number.isFinite(inMs) || !Number.isFinite(outMs)) return null;
  const diffMin = Math.max(0, Math.round((outMs - inMs) / 60000));
  const h = Math.floor(diffMin / 60);
  const m = diffMin % 60;
  return `${h}j ${m}m`;
});

// ── Map placeholder geometry ──────────────────────────────────────
// Compute a stylised bounding box centred on the geofence, with the
// marker offset proportionally to the reported check-in distance.
const MAP_VB = 180; // square viewBox
const MAP_CENTRE = MAP_VB / 2;

/**
 * Effective geofence radius in metres (falls back to a sensible
 * default so the SVG circle still renders when settings are missing).
 */
const effectiveRadius = computed(() => {
  const r = Number(props.settings?.geofence_radius_m ?? 150);
  return Number.isFinite(r) && r > 0 ? r : 150;
});

/**
 * SVG radius for the geofence — 60% of the half-viewbox so the marker
 * has room to render outside the circle on `outside_geofence=true`
 * rows without escaping the panel.
 */
const mapRadiusSvg = 0.55 * MAP_CENTRE;

/**
 * Marker offset from the centre, scaled so that a distance equal to
 * the geofence radius lands on the circle edge. Anything larger clips
 * to 1.4× radius so the marker never leaves the panel entirely.
 */
const markerOffsetSvg = computed(() => {
  const d = Number(props.row?.check_in_distance_m ?? 0);
  if (!Number.isFinite(d) || d <= 0) return 0;
  const ratio = Math.min(1.4, d / effectiveRadius.value);
  return ratio * mapRadiusSvg;
});

/** Deterministic bearing seeded off the row id so the marker doesn't
 *  jitter between renders. */
const markerAngle = computed(() => {
  const id = props.row?.id ?? '';
  let seed = 0;
  for (let i = 0; i < id.length; i++) seed = (seed * 31 + id.charCodeAt(i)) >>> 0;
  return (seed % 360) * (Math.PI / 180);
});

const markerXY = computed(() => {
  const offset = markerOffsetSvg.value;
  return {
    x: MAP_CENTRE + offset * Math.cos(markerAngle.value),
    y: MAP_CENTRE + offset * Math.sin(markerAngle.value),
  };
});

const hasCoords = computed(() => {
  const r = props.row;
  return (
    r?.check_in_lat !== null &&
    r?.check_in_lat !== undefined &&
    r?.check_in_lng !== null &&
    r?.check_in_lng !== undefined
  );
});
</script>

<template>
  <div>
    <!-- Backdrop -->
    <Transition
      enter-active-class="transition-opacity duration-200"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 bg-slate-900/50 z-40 backdrop-blur-sm"
        @click="$emit('close')"
      />
    </Transition>

    <!-- Panel -->
    <Transition
      enter-active-class="transition-transform duration-250 ease-out"
      enter-from-class="translate-x-full"
      enter-to-class="translate-x-0"
      leave-active-class="transition-transform duration-200 ease-in"
      leave-from-class="translate-x-0"
      leave-to-class="translate-x-full"
    >
      <aside
        v-if="open"
        class="fixed inset-y-0 right-0 w-full sm:w-[440px] bg-white border-l border-slate-200 z-50 flex flex-col shadow-2xl"
        role="dialog"
        aria-modal="true"
      >
        <!-- Header -->
        <header
          class="px-5 py-4 border-b border-slate-100 flex items-start justify-between gap-3"
        >
          <div class="min-w-0">
            <p
              class="text-3xs font-bold text-slate-400 uppercase tracking-widest"
            >
              Detail Kehadiran
            </p>
            <h2 class="text-[15px] font-black text-slate-900 truncate mt-0.5">
              {{ row ? teacherAttendancePersonName(row) : 'Detail' }}
            </h2>
            <p class="text-2xs text-slate-500 mt-0.5">
              {{ fmtDate(row?.date) }}
            </p>
          </div>
          <button
            type="button"
            class="p-2 rounded-full hover:bg-slate-100 text-slate-500"
            aria-label="Tutup panel"
            @click="$emit('close')"
          >
            <NavIcon name="x" :size="18" />
          </button>
        </header>

        <!-- Body -->
        <div v-if="row" class="flex-1 overflow-y-auto p-5 space-y-4">
          <!-- Status pills -->
          <div class="flex flex-wrap items-center gap-2">
            <span
              class="text-2xs font-bold px-2 py-1 rounded-full"
              :class="
                row.personnel_type === 'staff'
                  ? 'bg-violet-100 text-violet-700'
                  : 'bg-sky-100 text-sky-700'
              "
            >
              {{ teacherAttendancePersonnelLabel(row.personnel_type) }}
            </span>
            <span
              class="text-2xs font-bold px-2 py-1 rounded-full"
              :class="
                row.status === 'late'
                  ? 'bg-amber-100 text-amber-700'
                  : 'bg-emerald-100 text-emerald-700'
              "
            >
              {{ teacherAttendanceStatusLabel(row.status) }}
            </span>
            <span
              v-if="teacherAttendanceEmployeeNumber(row)"
              class="text-2xs font-bold px-2 py-1 rounded-full bg-slate-100 text-slate-600"
            >
              NIP {{ teacherAttendanceEmployeeNumber(row) }}
            </span>
            <span
              v-if="!row.is_workday"
              class="text-2xs font-bold px-2 py-1 rounded-full bg-slate-100 text-slate-500"
            >
              Libur
            </span>
            <span
              v-if="row.overtime_minutes > 0"
              class="text-2xs font-bold px-2 py-1 rounded-full bg-indigo-100 text-indigo-700"
            >
              Lembur +{{ row.overtime_minutes }}m
            </span>
          </div>

          <!-- Masuk / Pulang blocks -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <!-- Masuk -->
            <section
              class="rounded-2xl border border-slate-200 overflow-hidden bg-white"
            >
              <header
                class="px-3 py-2 bg-emerald-50 border-b border-emerald-100 flex items-center gap-2"
              >
                <NavIcon
                  name="arrow-right"
                  :size="13"
                  class="text-emerald-700"
                />
                <p
                  class="text-3xs font-bold text-emerald-700 uppercase tracking-widest"
                >
                  Masuk
                </p>
              </header>
              <div class="p-3 space-y-2">
                <div v-if="row.check_in_photo_url" class="rounded-xl overflow-hidden bg-slate-100">
                  <img
                    :src="row.check_in_photo_url"
                    :alt="`Foto masuk ${teacherAttendancePersonName(row)}`"
                    loading="lazy"
                    referrerpolicy="no-referrer"
                    class="w-full h-32 object-cover"
                  />
                </div>
                <div
                  v-else
                  class="h-32 rounded-xl bg-slate-50 border border-dashed border-slate-200 grid place-items-center text-2xs text-slate-400"
                >
                  Tidak ada foto
                </div>
                <p class="text-lg font-black text-slate-900 tabular-nums">
                  {{ fmtTime(row.check_in_at) }}
                </p>
                <p class="text-2xs text-slate-500">
                  Jarak: <span class="font-bold text-slate-700">{{ fmtDistance(row.check_in_distance_m) }}</span>
                  <span
                    v-if="row.check_in_outside_geofence"
                    class="ml-1.5 text-red-600 font-bold"
                  >
                    · Luar area
                  </span>
                </p>
                <p
                  v-if="row.check_in_lat !== null && row.check_in_lng !== null"
                  class="text-3xs text-slate-400 tabular-nums"
                >
                  {{ row.check_in_lat }}, {{ row.check_in_lng }}
                </p>
              </div>
            </section>

            <!-- Pulang -->
            <section
              class="rounded-2xl border border-slate-200 overflow-hidden bg-white"
            >
              <header
                class="px-3 py-2 bg-sky-50 border-b border-sky-100 flex items-center gap-2"
              >
                <NavIcon
                  name="log-out"
                  :size="13"
                  class="text-sky-700"
                />
                <p
                  class="text-3xs font-bold text-sky-700 uppercase tracking-widest"
                >
                  Pulang
                </p>
              </header>
              <div class="p-3 space-y-2">
                <div v-if="row.check_out_photo_url" class="rounded-xl overflow-hidden bg-slate-100">
                  <img
                    :src="row.check_out_photo_url"
                    :alt="`Foto pulang ${teacherAttendancePersonName(row)}`"
                    loading="lazy"
                    referrerpolicy="no-referrer"
                    class="w-full h-32 object-cover"
                  />
                </div>
                <div
                  v-else
                  class="h-32 rounded-xl bg-slate-50 border border-dashed border-slate-200 grid place-items-center text-2xs text-slate-400"
                >
                  Belum absen pulang
                </div>
                <p class="text-lg font-black text-slate-900 tabular-nums">
                  {{ fmtTime(row.check_out_at) }}
                </p>
                <p class="text-2xs text-slate-500">
                  Durasi:
                  <span class="font-bold text-slate-700">{{ durationLabel ?? '-' }}</span>
                </p>
                <p
                  v-if="row.check_out_lat !== null && row.check_out_lng !== null"
                  class="text-3xs text-slate-400 tabular-nums"
                >
                  {{ row.check_out_lat }}, {{ row.check_out_lng }}
                </p>
              </div>
            </section>
          </div>

          <!-- Mini map placeholder (SVG, no external map lib) -->
          <section
            class="rounded-2xl border border-slate-200 overflow-hidden bg-white"
          >
            <header
              class="px-3 py-2 border-b border-slate-100 flex items-center justify-between gap-2"
            >
              <div class="flex items-center gap-2">
                <NavIcon
                  name="map-pin"
                  :size="13"
                  class="text-slate-500"
                />
                <p
                  class="text-3xs font-bold text-slate-500 uppercase tracking-widest"
                >
                  Peta &amp; Geofence
                </p>
              </div>
              <span
                v-if="hasCoords"
                class="text-3xs font-bold text-slate-400"
              >
                radius {{ effectiveRadius }} m
              </span>
            </header>
            <div class="p-3">
              <div
                v-if="hasCoords"
                class="rounded-xl bg-slate-50 border border-slate-100 overflow-hidden"
              >
                <svg
                  :viewBox="`0 0 ${MAP_VB} ${MAP_VB}`"
                  class="w-full h-40"
                  role="img"
                  aria-label="Peta perkiraan geofence dan titik check-in"
                >
                  <!-- Faux grid -->
                  <defs>
                    <pattern
                      id="mapgrid"
                      width="20"
                      height="20"
                      patternUnits="userSpaceOnUse"
                    >
                      <path
                        d="M 20 0 L 0 0 0 20"
                        fill="none"
                        stroke="#e2e8f0"
                        stroke-width="0.5"
                      />
                    </pattern>
                  </defs>
                  <rect
                    :width="MAP_VB"
                    :height="MAP_VB"
                    fill="url(#mapgrid)"
                  />
                  <!-- Geofence circle -->
                  <circle
                    :cx="MAP_CENTRE"
                    :cy="MAP_CENTRE"
                    :r="mapRadiusSvg"
                    fill="rgba(16,185,129,0.10)"
                    stroke="#10b981"
                    stroke-width="1.5"
                    stroke-dasharray="4 3"
                  />
                  <!-- Centre pin -->
                  <circle
                    :cx="MAP_CENTRE"
                    :cy="MAP_CENTRE"
                    r="3"
                    fill="#10b981"
                  />
                  <text
                    :x="MAP_CENTRE + 6"
                    :y="MAP_CENTRE + 4"
                    font-size="8"
                    fill="#0f766e"
                    font-weight="600"
                  >
                    Sekolah
                  </text>
                  <!-- Marker (check-in) -->
                  <circle
                    :cx="markerXY.x"
                    :cy="markerXY.y"
                    r="6"
                    :fill="row.check_in_outside_geofence ? '#ef4444' : '#1b6fb8'"
                    stroke="white"
                    stroke-width="2"
                  />
                  <line
                    :x1="MAP_CENTRE"
                    :y1="MAP_CENTRE"
                    :x2="markerXY.x"
                    :y2="markerXY.y"
                    :stroke="row.check_in_outside_geofence ? '#ef4444' : '#1b6fb8'"
                    stroke-width="1"
                    stroke-dasharray="2 2"
                    opacity="0.6"
                  />
                </svg>
                <p class="px-3 py-2 text-3xs text-slate-400">
                  Visualisasi perkiraan (bukan peta sebenarnya). Peta interaktif
                  hadir di iterasi berikutnya.
                </p>
              </div>
              <div
                v-else
                class="h-32 rounded-xl bg-slate-50 border border-dashed border-slate-200 grid place-items-center text-2xs text-slate-400"
              >
                Koordinat check-in tidak tercatat.
              </div>
            </div>
          </section>

          <!-- Notes -->
          <section
            v-if="row.notes"
            class="rounded-2xl border border-slate-200 bg-white p-3"
          >
            <p
              class="text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1"
            >
              Catatan
            </p>
            <p class="text-[12.5px] text-slate-700 leading-relaxed">
              {{ row.notes }}
            </p>
          </section>
        </div>

        <div v-else class="flex-1 grid place-items-center p-6 text-2xs text-slate-400">
          Baris kehadiran tidak tersedia.
        </div>

        <!-- Footer actions -->
        <footer
          v-if="row"
          class="px-5 py-3 border-t border-slate-100 flex items-center gap-2"
        >
          <button
            type="button"
            class="flex-1 px-3 py-2 rounded-xl border border-slate-200 text-[12.5px] font-bold text-slate-700 hover:bg-slate-50 transition-colors inline-flex items-center justify-center gap-1.5"
            @click="$emit('note', row)"
          >
            <NavIcon name="edit" :size="13" />Catat Catatan
          </button>
          <button
            type="button"
            class="flex-1 px-3 py-2 rounded-xl bg-role-admin text-white text-[12.5px] font-bold hover:opacity-90 transition-opacity inline-flex items-center justify-center gap-1.5"
            @click="$emit('verify', row)"
          >
            <NavIcon name="check-circle" :size="13" />Verifikasi Manual
          </button>
        </footer>
      </aside>
    </Transition>
  </div>
</template>
