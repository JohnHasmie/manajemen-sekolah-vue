<!--
  AdminTutoringProgramDetailView — a program's packages + groups with
  inline create forms. Web mirror of the Flutter
  `tutoring_program_detail_screen.dart`. Completes the admin catalog
  flow: Program → Paket → Kelompok.

  programId from the route param; programName from the query.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutoringGroup, TutoringPackage } from '@/types/tutoring';

const route = useRoute();
const router = useRouter();
const toast = useToast();
const programId = String(route.params.programId ?? '');
const programName = String(route.query.name ?? 'Program');

function goEnroll() {
  router.push({
    name: 'admin.tutoring.enroll',
    params: { programId },
    query: { name: programName },
  });
}

const packages = ref<TutoringPackage[]>([]);
const groups = ref<TutoringGroup[]>([]);
const loading = ref(true);

const showPkgForm = ref(false);
const showGrpForm = ref(false);
const savingPkg = ref(false);
const savingGrp = ref(false);

const pkgForm = ref({
  name: '',
  total_sessions: '' as string | number,
  price: '' as string | number,
  modes: ['PREPAID'] as string[],
});
const grpForm = ref({ name: '', capacity: 10 });

const allModes: { key: string; label: string }[] = [
  { key: 'PREPAID', label: 'Prabayar' },
  { key: 'MONTHLY', label: 'Bulanan' },
  { key: 'PER_SESSION', label: 'Per Sesi' },
];

async function load() {
  loading.value = true;
  try {
    [packages.value, groups.value] = await Promise.all([
      TutoringService.getPackages(programId),
      TutoringService.getGroups(programId),
    ]);
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat detail.');
  } finally {
    loading.value = false;
  }
}

function toggleMode(key: string) {
  const arr = pkgForm.value.modes;
  const i = arr.indexOf(key);
  if (i >= 0) arr.splice(i, 1);
  else arr.push(key);
}

async function createPackage() {
  if (pkgForm.value.name.trim().length < 3) {
    toast.error('Nama paket minimal 3 karakter.');
    return;
  }
  if (pkgForm.value.modes.length === 0) {
    toast.error('Pilih minimal satu mode billing.');
    return;
  }
  savingPkg.value = true;
  try {
    await TutoringService.createPackage({
      program_id: programId,
      name: pkgForm.value.name.trim(),
      billing_modes_allowed: pkgForm.value.modes,
      total_sessions: pkgForm.value.total_sessions
        ? Number(pkgForm.value.total_sessions)
        : undefined,
      price: pkgForm.value.price ? Number(pkgForm.value.price) : undefined,
    });
    toast.success('Paket dibuat.');
    showPkgForm.value = false;
    pkgForm.value = { name: '', total_sessions: '', price: '', modes: ['PREPAID'] };
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal membuat paket.');
  } finally {
    savingPkg.value = false;
  }
}

async function createGroup() {
  if (grpForm.value.name.trim().length < 3) {
    toast.error('Nama kelompok minimal 3 karakter.');
    return;
  }
  savingGrp.value = true;
  try {
    await TutoringService.createGroup({
      program_id: programId,
      name: grpForm.value.name.trim(),
      capacity: grpForm.value.capacity,
    });
    toast.success('Kelompok dibuat.');
    showGrpForm.value = false;
    grpForm.value = { name: '', capacity: 10 };
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal membuat kelompok.');
  } finally {
    savingGrp.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-bold text-slate-800">{{ programName }}</h1>
      <button
        class="rounded-lg bg-indigo-900 px-3 py-2 text-sm font-semibold text-white"
        @click="goEnroll"
      >
        + Daftarkan Siswa
      </button>
    </div>

    <div v-if="loading" class="py-16 text-center text-slate-500">Memuat…</div>

    <template v-else>
      <!-- Packages -->
      <section class="mb-6">
        <div class="mb-2 flex items-center justify-between">
          <h2 class="font-bold text-slate-800">Paket</h2>
          <button
            class="text-sm font-semibold text-indigo-900"
            @click="showPkgForm = !showPkgForm"
          >
            {{ showPkgForm ? 'Tutup' : '+ Tambah' }}
          </button>
        </div>

        <div
          v-if="showPkgForm"
          class="mb-3 space-y-2 rounded-xl border border-slate-200 p-3"
        >
          <input
            v-model="pkgForm.name"
            placeholder="Nama paket (cth. Intensif 12 Sesi)"
            class="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <div class="flex gap-2">
            <input
              v-model="pkgForm.total_sessions"
              type="number"
              placeholder="Total sesi"
              class="w-full rounded-lg border border-slate-300 px-3 py-2"
            />
            <input
              v-model="pkgForm.price"
              type="number"
              placeholder="Harga (Rp)"
              class="w-full rounded-lg border border-slate-300 px-3 py-2"
            />
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="m in allModes"
              :key="m.key"
              type="button"
              class="rounded-full px-3 py-1 text-sm"
              :class="
                pkgForm.modes.includes(m.key)
                  ? 'bg-indigo-900 text-white'
                  : 'bg-slate-100 text-slate-700'
              "
              @click="toggleMode(m.key)"
            >
              {{ m.label }}
            </button>
          </div>
          <button
            :disabled="savingPkg"
            class="rounded-lg bg-indigo-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="createPackage"
          >
            {{ savingPkg ? 'Menyimpan…' : 'Simpan paket' }}
          </button>
        </div>

        <p v-if="packages.length === 0" class="text-sm text-slate-500">
          Belum ada paket.
        </p>
        <ul v-else class="space-y-2">
          <li
            v-for="p in packages"
            :key="p.id"
            class="rounded-xl border border-slate-200 p-3"
          >
            <div class="font-semibold text-slate-800">{{ p.name }}</div>
            <div class="text-sm text-slate-500">
              {{
                [
                  p.total_sessions ? p.total_sessions + ' sesi' : null,
                  p.price != null ? formatRupiah(p.price) : null,
                  p.billing_modes_allowed.join(', '),
                ]
                  .filter(Boolean)
                  .join(' · ')
              }}
            </div>
          </li>
        </ul>
      </section>

      <!-- Groups -->
      <section>
        <div class="mb-2 flex items-center justify-between">
          <h2 class="font-bold text-slate-800">Kelompok</h2>
          <button
            class="text-sm font-semibold text-indigo-900"
            @click="showGrpForm = !showGrpForm"
          >
            {{ showGrpForm ? 'Tutup' : '+ Tambah' }}
          </button>
        </div>

        <div
          v-if="showGrpForm"
          class="mb-3 space-y-2 rounded-xl border border-slate-200 p-3"
        >
          <input
            v-model="grpForm.name"
            placeholder="Nama kelompok (cth. Kelas UTBK Pagi)"
            class="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <input
            v-model.number="grpForm.capacity"
            type="number"
            placeholder="Kapasitas"
            class="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <button
            :disabled="savingGrp"
            class="rounded-lg bg-indigo-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="createGroup"
          >
            {{ savingGrp ? 'Menyimpan…' : 'Simpan kelompok' }}
          </button>
        </div>

        <p v-if="groups.length === 0" class="text-sm text-slate-500">
          Belum ada kelompok.
        </p>
        <ul v-else class="space-y-2">
          <li
            v-for="g in groups"
            :key="g.id"
            class="rounded-xl border border-slate-200 p-3"
          >
            <div class="font-semibold text-slate-800">{{ g.name }}</div>
            <div class="text-sm text-slate-500">
              {{
                [
                  'Kapasitas ' + g.capacity,
                  (g.enrollments_count ?? 0) + ' siswa',
                  g.tutor?.name ? 'Tutor: ' + g.tutor.name : null,
                ]
                  .filter(Boolean)
                  .join(' · ')
              }}
            </div>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
