<!--
  MultiGeofenceSettingsPanel.vue — admin panel for the multi-location
  geofence CRUD (Slack 1783559232 → backend MR !375). Sits under the
  legacy single-loc Geofence section in `AdminAttendanceConfigView.vue`.

  Layout:
    · Header row (title + count + "Tambah" button)
    · Empty state OR list of location cards (name + coords + radius +
      chips for primary/inactive + edit/delete actions)
    · Add/edit modal with lat/lng/radius/name + toggles + interactive
      map picker (reuses `GeofenceMapPicker.vue`)

  API contract:
    · GET    /teacher-attendance/geofences
    · POST   /teacher-attendance/geofences
    · PATCH  /teacher-attendance/geofences/{id}
    · DELETE /teacher-attendance/geofences/{id}
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import GeofenceMapPicker from '@/components/feature/GeofenceMapPicker.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import type {
  TeacherAttendanceGeofence,
  TeacherAttendanceGeofenceDraft,
} from '@/types/teacher-attendance';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';

const props = defineProps<{
  schoolLat?: number | null;
  schoolLng?: number | null;
}>();

const toast = useToast();
const { confirm } = useConfirm();

const rows = ref<TeacherAttendanceGeofence[]>([]);
const loading = ref(true);
const error = ref<string | null>(null);

const modalOpen = ref(false);
const editingId = ref<string | null>(null);
const draft = ref<TeacherAttendanceGeofenceDraft>({
  name: '',
  latitude: 0,
  longitude: 0,
  radius_m: 150,
  is_primary: false,
  is_active: true,
});
const saving = ref(false);

async function load() {
  loading.value = true;
  error.value = null;
  try {
    rows.value = await TeacherAttendanceService.listGeofences();
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(load);

function openCreate() {
  editingId.value = null;
  draft.value = {
    name: '',
    latitude: props.schoolLat ?? 0,
    longitude: props.schoolLng ?? 0,
    radius_m: 150,
    is_primary: rows.value.length === 0,
    is_active: true,
  };
  modalOpen.value = true;
}

function openEdit(row: TeacherAttendanceGeofence) {
  editingId.value = row.id;
  draft.value = {
    id: row.id,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    radius_m: row.radius_m,
    is_primary: row.is_primary,
    is_active: row.is_active,
  };
  modalOpen.value = true;
}

function onMapPick(p: { lat: number; lng: number }) {
  draft.value.latitude = p.lat;
  draft.value.longitude = p.lng;
}

async function save() {
  if (!draft.value.name.trim()) {
    toast.error('Nama lokasi wajib diisi.');
    return;
  }
  if (draft.value.radius_m < 20 || draft.value.radius_m > 5000) {
    toast.error('Radius harus antara 20 dan 5000 meter.');
    return;
  }
  saving.value = true;
  try {
    if (editingId.value) {
      await TeacherAttendanceService.updateGeofence(editingId.value, draft.value);
      toast.success('Lokasi diperbarui.');
    } else {
      await TeacherAttendanceService.createGeofence(draft.value);
      toast.success('Lokasi ditambahkan.');
    }
    modalOpen.value = false;
    editingId.value = null;
    await load();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    saving.value = false;
  }
}

async function remove(row: TeacherAttendanceGeofence) {
  const ok = await confirm({
    title: 'Hapus lokasi?',
    body: `Yakin hapus "${row.name}"? Presensi guru akan mengabaikan lokasi ini setelah dihapus.`,
    confirmLabel: 'Hapus',
  });
  if (!ok) return;
  try {
    await TeacherAttendanceService.deleteGeofence(row.id);
    toast.success('Lokasi dihapus.');
    await load();
  } catch (e) {
    toast.error((e as Error).message);
  }
}

const totalActive = computed(() => rows.value.filter((r) => r.is_active).length);
</script>

<template>
  <section
    id="section-geofence-multi"
    class="bg-white border border-slate-200 rounded-2xl p-4 space-y-md scroll-mt-32"
  >
    <header class="flex items-start justify-between gap-3">
      <div>
        <h3 class="text-[13px] font-black text-slate-900">
          Multi-Lokasi (Kampus Ganda)
        </h3>
        <p class="text-2xs text-slate-500 mt-0.5">
          Untuk sekolah dengan &gt;1 tempat. Presensi guru lulus jika berada
          di dalam radius <b>salah satu</b> lokasi. Jika daftar ini kosong,
          sistem pakai koordinat tunggal di atas.
        </p>
      </div>
      <Button variant="solid" size="sm" @click="openCreate">
        <NavIcon name="plus" :size="14" />
        <span class="ml-1">Tambah</span>
      </Button>
    </header>

    <div v-if="loading" class="py-6 text-center">
      <Spinner size="md" class="mx-auto" />
    </div>
    <div
      v-else-if="error"
      class="bg-red-50 border border-red-200 rounded-xl p-3 text-[12px] text-red-700"
    >
      {{ error }}
      <button class="ml-2 font-bold underline" @click="load">Coba lagi</button>
    </div>

    <div
      v-else-if="rows.length === 0"
      class="bg-slate-50 border border-slate-200 rounded-xl p-6 text-center text-[12.5px] text-slate-500"
    >
      <NavIcon name="map-pin" :size="24" class="mx-auto text-slate-400 mb-2" />
      Belum ada lokasi kampus tambahan. Sistem sekarang pakai satu titik
      pusat di atas.
      <div class="mt-2">
        <button
          class="text-role-admin font-bold underline"
          @click="openCreate"
        >
          Tambah lokasi pertama
        </button>
      </div>
    </div>

    <ul v-else class="space-y-2">
      <li
        v-for="row in rows"
        :key="row.id"
        class="border border-slate-200 rounded-xl p-3 flex items-start gap-3"
        :class="row.is_active ? '' : 'opacity-60'"
      >
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <p class="text-[13px] font-bold text-slate-900 truncate">
              {{ row.name }}
            </p>
            <span
              v-if="row.is_primary"
              class="bg-role-admin/10 text-role-admin text-3xs font-bold px-2 py-0.5 rounded-full"
            >
              Utama
            </span>
            <span
              v-if="!row.is_active"
              class="bg-slate-100 text-slate-500 text-3xs font-bold px-2 py-0.5 rounded-full"
            >
              Nonaktif
            </span>
          </div>
          <p class="text-2xs text-slate-500 mt-0.5 tabular-nums">
            {{ row.latitude.toFixed(6) }}, {{ row.longitude.toFixed(6) }} · Radius {{ row.radius_m }} m
          </p>
        </div>
        <div class="flex items-center gap-1 flex-shrink-0">
          <button
            class="p-2 hover:bg-slate-50 rounded-lg text-slate-500 hover:text-role-admin"
            title="Ubah"
            @click="openEdit(row)"
          >
            <NavIcon name="edit" :size="14" />
          </button>
          <button
            class="p-2 hover:bg-red-50 rounded-lg text-slate-500 hover:text-red-600"
            title="Hapus"
            @click="remove(row)"
          >
            <NavIcon name="trash" :size="14" />
          </button>
        </div>
      </li>
    </ul>

    <p v-if="rows.length > 0" class="text-3xs text-slate-400 tabular-nums">
      {{ rows.length }} lokasi ({{ totalActive }} aktif).
    </p>

    <!-- ── Add / Edit modal ─────────────────────────────────────── -->
    <div
      v-if="modalOpen"
      class="fixed inset-0 z-50 bg-slate-900/50 flex items-end sm:items-center justify-center p-3 sm:p-6"
      @click.self="modalOpen = false"
    >
      <div
        class="bg-white rounded-2xl w-full max-w-lg max-h-[92vh] overflow-y-auto shadow-xl"
      >
        <header class="flex items-center gap-3 p-4 border-b border-slate-200">
          <h3 class="flex-1 text-[14px] font-black text-slate-900">
            {{ editingId ? 'Ubah Lokasi' : 'Tambah Lokasi Baru' }}
          </h3>
          <button
            class="p-2 hover:bg-slate-100 rounded-lg text-slate-500"
            @click="modalOpen = false"
          >
            <NavIcon name="x" :size="14" />
          </button>
        </header>

        <div class="p-4 space-y-md">
          <div>
            <label
              class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
            >
              Nama Lokasi
            </label>
            <input
              v-model="draft.name"
              type="text"
              placeholder="mis. Kampus Utama / Kampus B Sukamaju"
              class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
              maxlength="120"
            />
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label
                class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Latitude
              </label>
              <input
                v-model.number="draft.latitude"
                type="number"
                step="any"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
              />
            </div>
            <div>
              <label
                class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Longitude
              </label>
              <input
                v-model.number="draft.longitude"
                type="number"
                step="any"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
              />
            </div>
          </div>

          <GeofenceMapPicker
            :lat="draft.latitude || null"
            :lng="draft.longitude || null"
            :radius="draft.radius_m"
            :fallback-lat="props.schoolLat ?? null"
            :fallback-lng="props.schoolLng ?? null"
            @pick="onMapPick"
          />

          <div>
            <label
              class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
            >
              Radius (meter)
            </label>
            <div class="flex items-center gap-3">
              <input
                v-model.number="draft.radius_m"
                type="range"
                min="20"
                max="1000"
                step="10"
                class="flex-1"
              />
              <input
                v-model.number="draft.radius_m"
                type="number"
                min="20"
                max="5000"
                class="w-24 rounded-lg border border-slate-200 px-2 py-1 text-[13px] tabular-nums text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
              />
              <span class="text-2xs text-slate-500">m</span>
            </div>
            <p class="text-3xs text-slate-400 mt-1">Rentang 20 – 5000 m.</p>
          </div>

          <label class="flex items-center gap-3 cursor-pointer">
            <input
              v-model="draft.is_primary"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
            <span class="text-[12.5px] text-slate-700">
              <span class="font-bold">Utama.</span> Lokasi utama sekolah —
              lokasi lain otomatis diturunkan jika ini di-set.
            </span>
          </label>

          <label class="flex items-center gap-3 cursor-pointer">
            <input
              v-model="draft.is_active"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
            <span class="text-[12.5px] text-slate-700">
              <span class="font-bold">Aktif.</span> Dipakai untuk cek radius
              presensi. Matikan sementara tanpa hapus.
            </span>
          </label>
        </div>

        <footer class="flex items-center gap-2 p-4 border-t border-slate-200 justify-end">
          <Button variant="ghost" size="sm" @click="modalOpen = false">
            Batal
          </Button>
          <Button variant="solid" size="sm" :loading="saving" @click="save">
            {{ editingId ? 'Simpan' : 'Tambah' }}
          </Button>
        </footer>
      </div>
    </div>
  </section>
</template>
