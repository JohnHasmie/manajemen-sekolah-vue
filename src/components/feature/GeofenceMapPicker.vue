<!--
  GeofenceMapPicker.vue — interactive OpenStreetMap picker for the school
  geofence centre (Presensi Guru → Geofence Sekolah).

  OSM/Leaflet (no API key, no cost) per Yahya's choice. The admin drags the
  pin or taps the map to set the centre; we emit the picked coordinates and
  the parent writes them into the lat/long fields. A circle shows the radius.

  Uses a CSS divIcon for the pin (not Leaflet's default PNG marker) to avoid
  the well-known Vite/bundler broken-marker-image issue — no asset imports
  needed.
-->
<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

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
  map?.remove();
  map = null;
});
</script>

<template>
  <div
    ref="mapEl"
    class="w-full h-64 rounded-lg overflow-hidden border border-slate-200 relative z-0"
  ></div>
</template>
