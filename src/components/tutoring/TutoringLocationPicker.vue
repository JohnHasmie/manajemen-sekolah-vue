<!--
  TutoringLocationPicker.vue — Nominatim/Leaflet location picker for the
  register-demo conversational wizard's bimbel path.

  Same Leaflet/OSM foundation as `GeofenceMapPicker.vue` (no API key, no
  cost), but tuned for an address-picker scenario instead of a geofence:
    - emits the full picked location ({lat, lng, address, city})
    - no radius circle
    - on every pin move + on every search-result selection, runs a
      Nominatim reverse-geocode so we can resolve the picked point's
      street address + city (the city auto-fills the bimbel.city field
      so we can skip that question)
    - bigger map (taller than the geofence picker) since this is the
      primary input on its question.

  Nominatim usage policy asks for ≤1 request/sec. We debounce search
  keystrokes (450ms) and guard reverse-geocode calls with a sequence
  counter to drop out-of-order replies. No external CDN — relies on
  the `leaflet` npm package + its bundled CSS.
-->
<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref } from 'vue';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import NavIcon from '@/components/feature/NavIcon.vue';

export interface PickedLocation {
  lat: number;
  lng: number;
  /** Full display name from Nominatim. */
  address: string | null;
  /** Best-effort city derived from the Nominatim address object. */
  city: string | null;
}

const props = defineProps<{
  lat: number | null;
  lng: number | null;
  /** Optional initial address to show in the search field. */
  address?: string | null;
}>();

const emit = defineEmits<{
  (e: 'pick', payload: PickedLocation): void;
}>();

/** Centre of Indonesia — used until the user picks or grants geolocation. */
const DEFAULT_CENTER: [number, number] = [-2.5, 118];

const mapEl = ref<HTMLDivElement | null>(null);
let map: L.Map | null = null;
let marker: L.Marker | null = null;

const pinIcon = L.divIcon({
  className: 'bimbel-pin',
  html:
    '<div style="width:18px;height:18px;border-radius:50% 50% 50% 0;' +
    'background:#4F46E5;border:2px solid #fff;transform:rotate(-45deg);' +
    'box-shadow:0 1px 4px rgba(0,0,0,.45)"></div>',
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

function initialCenter(): { center: [number, number]; hasPoint: boolean } {
  if (props.lat != null && props.lng != null) {
    return { center: [props.lat, props.lng], hasPoint: true };
  }
  return { center: DEFAULT_CENTER, hasPoint: false };
}

function round6(n: number): number {
  return Math.round(n * 1e6) / 1e6;
}

/**
 * Run a Nominatim reverse-geocode for the picked lat/lng, then emit the
 * pick with the resolved address + best-effort city. Emit is fired in
 * BOTH branches (reverse ok / reverse failed) so the parent always sees
 * the click — never a silent drop.
 */
let reverseSeq = 0;
async function emitPickWithReverse(ll: L.LatLng): Promise<void> {
  const seq = ++reverseSeq;
  const base: PickedLocation = {
    lat: round6(ll.lat),
    lng: round6(ll.lng),
    address: null,
    city: null,
  };
  // Fire-and-forget the reverse call so the parent sees a pick
  // immediately even if Nominatim is slow / down. The address/city
  // fields land in a follow-up emit when (and if) the call returns.
  emit('pick', base);
  try {
    const url =
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&addressdetails=1&lat=' +
      encodeURIComponent(String(ll.lat)) +
      '&lon=' +
      encodeURIComponent(String(ll.lng));
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!res.ok || seq !== reverseSeq) return;
    const data = await res.json();
    if (seq !== reverseSeq) return;
    const a = data.address ?? {};
    // Nominatim's address object varies by country. For Indonesia we
    // prefer `city` → `town` → `village` → `municipality` → `county`.
    const city =
      a.city ||
      a.town ||
      a.village ||
      a.municipality ||
      a.county ||
      null;
    emit('pick', {
      ...base,
      address: typeof data.display_name === 'string' ? data.display_name : null,
      city,
    });
  } catch {
    // Reverse failed — caller still has the base lat/lng from above.
  }
}

// Centre of Indonesia is unhelpful for most users; ask the browser for
// the current location on first mount and recentre + drop the pin
// there. Permission-denied keeps the default view, no nag.
function geolocateToCurrent(): void {
  if (!('geolocation' in navigator) || !map || !marker) return;
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      if (!map || !marker) return;
      const ll = L.latLng(pos.coords.latitude, pos.coords.longitude);
      map.setView(ll, 16);
      marker.setLatLng(ll);
      emitPickWithReverse(ll);
    },
    () => {
      /* denied or unavailable — keep the default view */
    },
    { enableHighAccuracy: true, timeout: 8000, maximumAge: 60000 },
  );
}

// ── Nominatim place search ────────────────────────────────────────────
interface NominatimResult {
  place_id: number;
  lat: string;
  lon: string;
  display_name: string;
}

const searchQuery = ref<string>(props.address ?? '');
const searchResults = ref<NominatimResult[]>([]);
const searching = ref(false);
const showResults = ref(false);
const searched = ref(false);
let searchTimer: ReturnType<typeof setTimeout> | null = null;
let searchSeq = 0;

function onSearchInput(): void {
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

async function runSearch(): Promise<void> {
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
      'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=6&countrycodes=id&q=' +
      encodeURIComponent(q);
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    const data = res.ok ? await res.json() : [];
    if (seq !== searchSeq) return;
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

function selectResult(r: NominatimResult): void {
  const lat = Number(r.lat);
  const lng = Number(r.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !map || !marker) return;
  const ll = L.latLng(lat, lng);
  map.setView(ll, 16);
  marker.setLatLng(ll);
  emitPickWithReverse(ll);
  searchQuery.value = r.display_name;
  searchResults.value = [];
  showResults.value = false;
  searched.value = false;
}

function closeResultsSoon(): void {
  setTimeout(() => {
    showResults.value = false;
  }, 150);
}

// ── Lifecycle ─────────────────────────────────────────────────────────

onMounted(() => {
  if (!mapEl.value) return;
  const { center, hasPoint } = initialCenter();
  map = L.map(mapEl.value, {
    center,
    zoom: hasPoint ? 16 : 5,
    zoomControl: true,
    scrollWheelZoom: true,
  });
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
    maxZoom: 19,
  }).addTo(map);
  marker = L.marker(center, {
    draggable: true,
    icon: pinIcon,
  }).addTo(map);
  marker.on('dragend', () => {
    const ll = marker!.getLatLng();
    emitPickWithReverse(ll);
  });
  map.on('click', (ev: L.LeafletMouseEvent) => {
    marker!.setLatLng(ev.latlng);
    emitPickWithReverse(ev.latlng);
  });
  // Auto-locate when nothing's pre-picked.
  if (!hasPoint) geolocateToCurrent();
});

onBeforeUnmount(() => {
  if (searchTimer) clearTimeout(searchTimer);
  map?.remove();
  map = null;
  marker = null;
});
</script>

<template>
  <div class="space-y-3">
    <!-- Search box + locate button -->
    <div class="relative">
      <div class="flex gap-2">
        <div class="relative flex-1">
          <NavIcon
            name="search"
            :size="15"
            class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
          />
          <input
            v-model="searchQuery"
            type="search"
            placeholder="Cari alamat atau nama tempat…"
            class="w-full pl-9 pr-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 transition"
            @input="onSearchInput"
            @blur="closeResultsSoon"
          />
        </div>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 px-3 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:border-brand-cobalt hover:text-brand-cobalt transition"
          @click="geolocateToCurrent"
        >
          <NavIcon name="map-pin" :size="14" />
          Lokasi saya
        </button>
      </div>

      <!-- Result dropdown -->
      <div
        v-if="showResults"
        class="absolute z-[1100] left-0 right-0 mt-1 bg-white border border-slate-200 rounded-xl shadow-card max-h-72 overflow-y-auto"
      >
        <div v-if="searching" class="px-3 py-3 text-[12px] text-slate-500">
          Mencari…
        </div>
        <template v-else-if="searchResults.length > 0">
          <button
            v-for="r in searchResults"
            :key="r.place_id"
            type="button"
            class="w-full text-left px-3 py-2.5 hover:bg-slate-50 transition flex items-start gap-2"
            @mousedown.prevent="selectResult(r)"
          >
            <NavIcon
              name="map-pin"
              :size="13"
              class="mt-0.5 text-brand-cobalt flex-shrink-0"
            />
            <span class="text-[12.5px] text-slate-700 leading-snug">
              {{ r.display_name }}
            </span>
          </button>
        </template>
        <div v-else-if="searched" class="px-3 py-3 text-[12px] text-slate-500">
          Tidak ada hasil. Coba kata kunci lain.
        </div>
      </div>
    </div>

    <!-- Map -->
    <div
      ref="mapEl"
      class="w-full rounded-xl border border-slate-200 overflow-hidden bg-slate-100"
      style="height: 320px"
    ></div>

    <p class="text-[11px] text-slate-400 leading-relaxed text-center">
      Tap di peta untuk pindahkan pin, atau seret pin ke lokasi tepat
      lembaga Anda. Data peta dari OpenStreetMap.
    </p>
  </div>
</template>
