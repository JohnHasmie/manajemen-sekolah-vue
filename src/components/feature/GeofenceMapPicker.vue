<!--
  GeofenceMapPicker.vue — interactive OpenStreetMap picker for the school
  geofence centre (Presensi Guru → Geofence Sekolah).

  OSM/Leaflet (no API key, no cost) per Yahya's choice. The admin drags the
  pin or taps the map to set the centre; we emit the picked coordinates and
  the parent writes them into the lat/long fields. A circle shows the radius.

  A search box (Nominatim, the OSM geocoder — also key-free) sits above the
  map: type a place/address, pick a result, and the map + pin + lat/long jump
  there. Same OSM data as the tiles, so results line up with what's drawn.

  Uses a CSS divIcon for the pin (not Leaflet's default PNG marker) to avoid
  the well-known Vite/bundler broken-marker-image issue — no asset imports
  needed.
-->
<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';

const props = defineProps<{
  lat: number | null;
  lng: number | null;
  radius: number;
  /** Fallback centre (school pin) when lat/lng are empty. */
  fallbackLat?: number | null;
  fallbackLng?: number | null;
}>();

const emit = defineEmits<{
  (e: 'pick', payload: { lat: number; lng: number }): void;
}>();

// Centre of Indonesia — used only when neither a geofence point nor a
// school pin is available, so the admin still sees a sensible starting map.
const DEFAULT_CENTER: [number, number] = [-2.5, 118];

const mapEl = ref<HTMLDivElement | null>(null);
let map: L.Map | null = null;
let marker: L.Marker | null = null;
let circle: L.Circle | null = null;

const pinIcon = L.divIcon({
  className: 'geofence-pin',
  html:
    '<div style="width:18px;height:18px;border-radius:50% 50% 50% 0;' +
    'background:#2563eb;border:2px solid #fff;transform:rotate(-45deg);' +
    'box-shadow:0 1px 4px rgba(0,0,0,.45)"></div>',
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

function initialCenter(): { center: [number, number]; hasPoint: boolean } {
  if (props.lat != null && props.lng != null) {
    return { center: [props.lat, props.lng], hasPoint: true };
  }
  if (props.fallbackLat != null && props.fallbackLng != null) {
    return { center: [props.fallbackLat, props.fallbackLng], hasPoint: false };
  }
  return { center: DEFAULT_CENTER, hasPoint: false };
}

function round6(n: number): number {
  return Math.round(n * 1e6) / 1e6;
}

function emitPick(ll: L.LatLng) {
  circle?.setLatLng(ll);
  emit('pick', { lat: round6(ll.lat), lng: round6(ll.lng) });
}

// When there's no geofence point and no school pin to fall back on, ask the
// browser for the admin's current location and recentre there instead of
// sitting on the country-wide default view. On success we also drop the pin
// and fill the fields, so the geofence defaults to "here" — the admin can
// still drag it or clear the coordinates to use the school pin. If permission
// is denied/unavailable we silently keep the default view.
function geolocateToCurrent() {
  if (!('geolocation' in navigator)) return;
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      if (!map || !marker) return;
      const ll = L.latLng(pos.coords.latitude, pos.coords.longitude);
      map.setView(ll, 16);
      marker.setLatLng(ll);
      emitPick(ll);
    },
    () => {
      /* denied or unavailable — keep the default view */
    },
    { enableHighAccuracy: true, timeout: 8000, maximumAge: 60000 },
  );
}

// ── Nominatim place search ────────────────────────────────────────────────
// Geocoding via the public OSM Nominatim endpoint (no API key). Its usage
// policy asks for ≤1 request/sec, so we debounce keystrokes and guard against
// out-of-order responses with a sequence counter.
interface NominatimResult {
  place_id: number;
  lat: string;
  lon: string;
  display_name: string;
}

const searchQuery = ref('');
const searchResults = ref<NominatimResult[]>([]);
const searching = ref(false);
const showResults = ref(false);
const searched = ref(false);
let searchTimer: ReturnType<typeof setTimeout> | null = null;
let searchSeq = 0;

function onSearchInput() {
  if (searchTimer) clearTimeout(searchTimer);
  const q = searchQuery.value.trim();
  if (q.length < 3) {
    searchResults.value = [];
    showResults.value = false;
    searched.value = false;
    return;
  }
  searchTimer = setTimeout(runSearch, 450);
}

async function runSearch() {
  if (searchTimer) {
    clearTimeout(searchTimer);
    searchTimer = null;
  }
  const q = searchQuery.value.trim();
  if (q.length < 3) return;
  const seq = ++searchSeq;
  searching.value = true;
  showResults.value = true;
  try {
    const url =
      'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=6&q=' +
      encodeURIComponent(q);
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    const data = res.ok ? await res.json() : [];
    if (seq !== searchSeq) return; // a newer query superseded this one
    searchResults.value = Array.isArray(data) ? (data as NominatimResult[]) : [];
  } catch {
    if (seq === searchSeq) searchResults.value = [];
  } finally {
    if (seq === searchSeq) {
      searching.value = false;
      searched.value = true;
    }
  }
}

function selectResult(r: NominatimResult) {
  const lat = Number(r.lat);
  const lng = Number(r.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !map || !marker) return;
  const ll = L.latLng(lat, lng);
  map.setView(ll, 16);
  marker.setLatLng(ll);
  emitPick(ll);
  searchQuery.value = r.display_name;
  searchResults.value = [];
  showResults.value = false;
  searched.value = false;
}

function clearSearch() {
  searchQuery.value = '';
  searchResults.value = [];
  showResults.value = false;
  searched.value = false;
}

// Delay hiding so a click on a result registers before the list closes.
function closeResultsSoon() {
  setTimeout(() => (showResults.value = false), 150);
}

onMounted(() => {
  if (!mapEl.value) return;
  const { center, hasPoint } = initialCenter();

  map = L.map(mapEl.value).setView(center, hasPoint ? 16 : 5);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap',
  }).addTo(map);

  marker = L.marker(center, { draggable: true, icon: pinIcon }).addTo(map);
  circle = L.circle(center, {
    radius: props.radius || 100,
    color: '#2563eb',
    weight: 1,
    fillColor: '#2563eb',
    fillOpacity: 0.12,
  }).addTo(map);

  marker.on('dragend', () => emitPick(marker!.getLatLng()));
  map.on('click', (e: L.LeafletMouseEvent) => {
    marker?.setLatLng(e.latlng);
    emitPick(e.latlng);
  });

  // The settings card can be hidden/animating on first paint; recompute
  // the map size once it is visible so tiles fill the container.
  setTimeout(() => map?.invalidateSize(), 0);

  // No saved geofence point and no school pin → start at the admin's current
  // location rather than the country-wide default.
  const hasFallback = props.fallbackLat != null && props.fallbackLng != null;
  if (!hasPoint && !hasFallback) geolocateToCurrent();
});

// External changes (manual lat/long typing) move the pin to match.
watch(
  () => [props.lat, props.lng] as const,
  ([la, ln]) => {
    if (la == null || ln == null || !map || !marker) return;
    const ll = L.latLng(la, ln);
    marker.setLatLng(ll);
    circle?.setLatLng(ll);
    map.setView(ll, Math.max(map.getZoom(), 15));
  },
);

watch(
  () => props.radius,
  (r) => circle?.setRadius(r || 100),
);

onBeforeUnmount(() => {
  if (searchTimer) clearTimeout(searchTimer);
  map?.remove();
  map = null;
});
</script>

<template>
  <div class="space-y-2">
    <!-- Place/address search (Nominatim, OSM geocoder — no API key). -->
    <div class="relative">
      <div
        class="flex items-center gap-2 bg-white rounded-lg px-3 py-2 border border-slate-200"
      >
        <NavIcon name="search" :size="14" class="text-slate-400 shrink-0" />
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Cari tempat atau alamat…"
          class="flex-1 text-[13px] text-slate-900 outline-none placeholder-slate-400 bg-transparent"
          @input="onSearchInput"
          @keydown.enter.prevent="runSearch"
          @focus="searchResults.length > 0 && (showResults = true)"
          @blur="closeResultsSoon"
        />
        <Spinner v-if="searching" size="sm" class="text-slate-400 shrink-0" />
        <button
          v-else-if="searchQuery"
          type="button"
          class="text-slate-400 hover:text-slate-600 text-sm leading-none shrink-0"
          aria-label="Bersihkan pencarian"
          @click="clearSearch"
        >
          ✕
        </button>
      </div>

      <ul
        v-if="showResults && searchResults.length > 0"
        class="absolute left-0 right-0 mt-1 z-[1100] max-h-56 overflow-auto bg-white rounded-lg border border-slate-200 shadow-lg"
      >
        <li
          v-for="r in searchResults"
          :key="r.place_id"
          class="px-3 py-2 text-[12px] text-slate-700 hover:bg-slate-50 cursor-pointer border-b border-slate-100 last:border-0"
          @mousedown.prevent="selectResult(r)"
        >
          {{ r.display_name }}
        </li>
      </ul>
      <div
        v-else-if="showResults && searched && !searching"
        class="absolute left-0 right-0 mt-1 z-[1100] bg-white rounded-lg border border-slate-200 shadow-lg px-3 py-2 text-[12px] text-slate-400"
      >
        Tidak ada hasil untuk “{{ searchQuery.trim() }}”.
      </div>
    </div>

    <div
      ref="mapEl"
      class="w-full h-64 rounded-lg overflow-hidden border border-slate-200 relative z-0"
    ></div>
  </div>
</template>
