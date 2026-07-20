<!--
  AttendanceRowDetailDrawer.vue — single-row detail panel opened from
  a Log Harian row on the pegawai attendance dashboard (MR-3 Opsi A).

  Right-side slide-over that shows one teacher_attendances row in
  full: status pills, Masuk / Pulang photo + jam + jarak, an
  interactive Leaflet/OSM mini-map with geofence circle + Masuk /
  Pulang markers, and admin-only action buttons.

  Map rendering — FU-3 of the Pulang parity series swapped the
  original stylised SVG placeholder for a real Leaflet map (OSM
  tiles) so the admin can pan/zoom and see the actual streets around
  each check-in. The Leaflet setup mirrors GeofenceMapPicker.vue:
  divIcon pins (no PNG marker assets → no Vite bundler pain), OSM
  tile layer with attribution, and a green geofence circle at
  settings.effective_geofence_lat/lng (falling back to the school
  pin, and finally to the check-in coord if settings are unknown).

  The drawer is a "dumb" presentational component — the parent owns
  the open state and the row payload. On `close`, the parent clears
  its selection.
-->
<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
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

/**
 * Effective geofence radius in metres (falls back to a sensible
 * default so the Leaflet circle still renders when settings are missing).
 */
const effectiveRadius = computed(() => {
  const r = Number(props.settings?.geofence_radius_m ?? 150);
  return Number.isFinite(r) && r > 0 ? r : 150;
});

/** True when the row has usable check-in coordinates to plot. */
const hasCheckInCoords = computed(() => {
  const r = props.row;
  return (
    r?.check_in_lat !== null &&
    r?.check_in_lat !== undefined &&
    r?.check_in_lng !== null &&
    r?.check_in_lng !== undefined
  );
});

/** True when the row has usable check-out coordinates to plot. */
const hasCheckOutCoords = computed(() => {
  const r = props.row;
  return (
    r?.check_out_lat !== null &&
    r?.check_out_lat !== undefined &&
    r?.check_out_lng !== null &&
    r?.check_out_lng !== undefined
  );
});

/**
 * Effective geofence centre — settings override (geofence_lat/lng),
 * falling back to the school pin (school_latitude/school_longitude)
 * or the teacher config bootstrap alias (effective_geofence_lat/lng).
 * `null` when none of them are set — the map will still render
 * centred on a check-in/out coord, just without a geofence circle.
 */
const geofenceCentre = computed<[number, number] | null>(() => {
  const s = props.settings;
  if (!s) return null;
  const lat =
    s.geofence_lat ?? s.effective_geofence_lat ?? s.school_latitude ?? null;
  const lng =
    s.geofence_lng ?? s.effective_geofence_lng ?? s.school_longitude ?? null;
  if (lat == null || lng == null) return null;
  return [Number(lat), Number(lng)];
});

/**
 * True when the drawer has enough coordinates to render a real map —
 * either a check-in/out coord OR a known school geofence centre. When
 * false, the map section falls back to the "koordinat tidak tercatat"
 * caption so the drawer still opens cleanly on rows with no GPS.
 */
const canRenderMap = computed(
  () =>
    hasCheckInCoords.value ||
    hasCheckOutCoords.value ||
    geofenceCentre.value !== null,
);

// ── Leaflet lifecycle ─────────────────────────────────────────────
// The drawer is re-mounted each time it opens (v-if on the aside),
// but Vue keeps <script setup> state alive so any prior Leaflet
// instance MUST be torn down before we re-init or the tile layer
// leaks + the second setView call throws "Map container is already
// initialized". We `remove()` the map before every rebuild.
const mapContainer = ref<HTMLDivElement | null>(null);
let leafletMap: L.Map | null = null;

// divIcon helper — colored teardrop pin, mirrors GeofenceMapPicker.vue
// to sidestep the well-known Leaflet-default-marker Vite asset bug.
// `outside` swaps the fill for a red danger tint so out-of-geofence
// check-ins stay visually consistent with the "Luar area" pill above.
function makePinIcon(color: string, opts: { outside?: boolean } = {}): L.DivIcon {
  const fill = opts.outside ? '#ef4444' : color;
  return L.divIcon({
    className: 'attendance-drawer-pin',
    html:
      `<div style="width:16px;height:16px;border-radius:50% 50% 50% 0;` +
      `background:${fill};border:2px solid #fff;transform:rotate(-45deg);` +
      `box-shadow:0 1px 4px rgba(0,0,0,.35)"></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });
}

const SCHOOL_PIN_COLOR = '#10b981'; // emerald — matches the geofence circle
const CHECK_IN_PIN_COLOR = '#1b6fb8'; // blue — same as the Masuk pill
const CHECK_OUT_PIN_COLOR = '#8b5cf6'; // violet — same as the Pulang pill

/**
 * Escape untrusted numeric/text bits before we inline them into a
 * Leaflet popup HTML string. Row ids/dates are backend-controlled but
 * `notes` is admin-authored, so we run the same escape unconditionally.
 */
function esc(s: string | number | null | undefined): string {
  if (s === null || s === undefined) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Tear down the current Leaflet instance. Called on drawer close,
 * before a rebuild, and on component unmount so we never leak DOM.
 */
function disposeMap(): void {
  if (leafletMap) {
    leafletMap.remove();
    leafletMap = null;
  }
}

/**
 * Build (or rebuild) the Leaflet map for the currently-selected row.
 * Safe to call multiple times — always disposes the prior instance
 * first. Bails silently when there's nothing to plot.
 */
function buildMap(): void {
  disposeMap();
  if (!props.open || !props.row || !mapContainer.value) return;
  if (!canRenderMap.value) return;

  const row = props.row;
  // Center priority: geofence centre → check-in → check-out.
  const centre: [number, number] =
    geofenceCentre.value ??
    (hasCheckInCoords.value
      ? [row.check_in_lat as number, row.check_in_lng as number]
      : [row.check_out_lat as number, row.check_out_lng as number]);

  leafletMap = L.map(mapContainer.value, {
    zoomControl: true,
    scrollWheelZoom: false, // don't hijack drawer scroll
    doubleClickZoom: true,
    boxZoom: false,
    keyboard: false,
    dragging: true, // pan yes, no marker editing though
  }).setView(centre, 17);

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap contributors',
  }).addTo(leafletMap);

  const bounds = L.latLngBounds([centre]);

  // Geofence circle + school centre pin (only when settings give us
  // an actual coord — otherwise the drawer degrades to a marker-only
  // map centred on the check-in).
  if (geofenceCentre.value) {
    L.circle(geofenceCentre.value, {
      radius: effectiveRadius.value,
      color: SCHOOL_PIN_COLOR,
      weight: 2,
      fillColor: SCHOOL_PIN_COLOR,
      fillOpacity: 0.1,
    }).addTo(leafletMap);
    const schoolMarker = L.marker(geofenceCentre.value, {
      icon: makePinIcon(SCHOOL_PIN_COLOR),
      interactive: true,
      keyboard: false,
    }).addTo(leafletMap);
    schoolMarker.bindPopup(
      `<strong>Sekolah</strong><br/>Radius ${esc(effectiveRadius.value)} m`,
    );
    bounds.extend(geofenceCentre.value);
  }

  // Check-in marker — blue by default, red border via icon swap when
  // the row was flagged outside geofence.
  if (hasCheckInCoords.value) {
    const p: [number, number] = [
      row.check_in_lat as number,
      row.check_in_lng as number,
    ];
    const marker = L.marker(p, {
      icon: makePinIcon(CHECK_IN_PIN_COLOR, {
        outside: row.check_in_outside_geofence,
      }),
      keyboard: false,
    }).addTo(leafletMap);
    const timeLabel = row.check_in_at
      ? new Date(row.check_in_at).toLocaleTimeString('id-ID', {
          hour: '2-digit',
          minute: '2-digit',
        })
      : '-';
    const distLabel =
      row.check_in_distance_m != null
        ? `${Math.round(row.check_in_distance_m)} m dari sekolah`
        : 'jarak tidak tercatat';
    marker.bindPopup(
      `<strong>Masuk ${esc(timeLabel)}</strong><br/>${esc(distLabel)}` +
        (row.check_in_outside_geofence
          ? '<br/><span style="color:#dc2626;font-weight:600">Luar area</span>'
          : ''),
    );
    // Dashed connector from the geofence centre so the admin can see
    // the visual "arrow" of where the person actually checked in.
    if (geofenceCentre.value) {
      L.polyline([geofenceCentre.value, p], {
        color: row.check_in_outside_geofence ? '#ef4444' : CHECK_IN_PIN_COLOR,
        weight: 1.5,
        dashArray: '4 4',
        opacity: 0.6,
      }).addTo(leafletMap);
    }
    bounds.extend(p);
  }

  // Check-out marker — violet by default, red on outside_geofence.
  if (hasCheckOutCoords.value) {
    const p: [number, number] = [
      row.check_out_lat as number,
      row.check_out_lng as number,
    ];
    const marker = L.marker(p, {
      icon: makePinIcon(CHECK_OUT_PIN_COLOR, {
        outside: row.check_out_outside_geofence,
      }),
      keyboard: false,
    }).addTo(leafletMap);
    const timeLabel = row.check_out_at
      ? new Date(row.check_out_at).toLocaleTimeString('id-ID', {
          hour: '2-digit',
          minute: '2-digit',
        })
      : '-';
    const distLabel =
      row.check_out_distance_m != null
        ? `${Math.round(row.check_out_distance_m)} m dari sekolah`
        : 'jarak tidak tercatat';
    marker.bindPopup(
      `<strong>Pulang ${esc(timeLabel)}</strong><br/>${esc(distLabel)}` +
        (row.check_out_outside_geofence
          ? '<br/><span style="color:#dc2626;font-weight:600">Luar area</span>'
          : ''),
    );
    if (geofenceCentre.value) {
      L.polyline([geofenceCentre.value, p], {
        color: row.check_out_outside_geofence
          ? '#ef4444'
          : CHECK_OUT_PIN_COLOR,
        weight: 1.5,
        dashArray: '4 4',
        opacity: 0.6,
      }).addTo(leafletMap);
    }
    bounds.extend(p);
  }

  // Fit all markers + a bit of padding so nothing hugs the edge. Skip
  // when we only have one point (fitBounds on a single-point bounds
  // zooms to Leaflet's `maxZoom`, which is jarring).
  if (bounds.isValid()) {
    const cornerCount =
      (geofenceCentre.value ? 1 : 0) +
      (hasCheckInCoords.value ? 1 : 0) +
      (hasCheckOutCoords.value ? 1 : 0);
    if (cornerCount > 1) {
      leafletMap.fitBounds(bounds, { padding: [24, 24], maxZoom: 18 });
    }
  }

  // The drawer slide-in animation means the container's final size
  // isn't known on mount — nudge Leaflet to re-measure on the next
  // frame so the tiles fill the box instead of ending up half-blank.
  setTimeout(() => leafletMap?.invalidateSize(), 0);
}

// Rebuild whenever the drawer opens with a fresh row (or the settings
// arrive after mount). `open=false` disposes so the map doesn't hang
// around behind a hidden aside.
watch(
  () => [props.open, props.row?.id, props.settings?.geofence_lat, props.settings?.geofence_lng, props.settings?.school_latitude, props.settings?.school_longitude, props.settings?.geofence_radius_m] as const,
  ([open]) => {
    if (!open) {
      disposeMap();
      return;
    }
    // Wait for the aside + inner div to actually be in the DOM.
    nextTick(() => buildMap());
  },
  { immediate: true },
);

onBeforeUnmount(() => disposeMap());
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
                <p v-if="row.check_out_at" class="text-2xs text-slate-500">
                  Jarak: <span class="font-bold text-slate-700">{{ fmtDistance(row.check_out_distance_m) }}</span>
                  <span
                    v-if="row.check_out_outside_geofence"
                    class="ml-1.5 text-red-600 font-bold"
                  >
                    · Luar area
                  </span>
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

          <!-- Mini map — real Leaflet + OSM tiles (FU-3 pulang parity) -->
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
                v-if="geofenceCentre"
                class="text-3xs font-bold text-slate-400"
              >
                radius {{ effectiveRadius }} m
              </span>
            </header>
            <div class="p-3">
              <div
                v-if="canRenderMap"
                class="rounded-xl bg-slate-50 border border-slate-100 overflow-hidden"
              >
                <div
                  ref="mapContainer"
                  class="w-full h-40 relative z-0"
                  role="img"
                  aria-label="Peta lokasi geofence dan titik check-in dan check-out"
                ></div>
                <!-- Legend — colored dots + labels for each pin currently on the map. -->
                <div
                  class="px-3 py-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-3xs text-slate-500"
                >
                  <span
                    v-if="geofenceCentre"
                    class="inline-flex items-center gap-1.5"
                  >
                    <span
                      class="w-2 h-2 rounded-full inline-block"
                      style="background: #10b981"
                      aria-hidden="true"
                    />
                    <span class="font-bold text-slate-600"
                      >Sekolah ({{ effectiveRadius }} m)</span
                    >
                  </span>
                  <span
                    v-if="hasCheckInCoords"
                    class="inline-flex items-center gap-1.5"
                  >
                    <span
                      class="w-2 h-2 rounded-full inline-block"
                      style="background: #1b6fb8"
                      aria-hidden="true"
                    />
                    <span class="font-bold text-slate-600">Masuk</span>
                  </span>
                  <span
                    v-if="hasCheckOutCoords"
                    class="inline-flex items-center gap-1.5"
                  >
                    <span
                      class="w-2 h-2 rounded-full inline-block"
                      style="background: #8b5cf6"
                      aria-hidden="true"
                    />
                    <span class="font-bold text-slate-600">Pulang</span>
                  </span>
                  <span class="text-slate-400">
                    · Klik penanda untuk detail.
                  </span>
                </div>
              </div>
              <div
                v-else
                class="h-32 rounded-xl bg-slate-50 border border-dashed border-slate-200 grid place-items-center text-2xs text-slate-400"
              >
                Koordinat tidak tercatat.
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
