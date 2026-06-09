<!--
  AdminTutoringProgramsView — manage bimbel programs: list with
  package/group counts, create via inline form, delete (handles the
  backend's 409 FK-restrict). Web mirror of the Flutter
  `tutoring_programs_screen.dart`.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringProgram } from '@/types/tutoring';

const toast = useToast();
const loading = ref(true);
const error = ref<string | null>(null);
const programs = ref<TutoringProgram[]>([]);

const showForm = ref(false);
const saving = ref(false);
const form = ref({ name: '', target_education_level: '', description: '' });

async function load() {
  loading.value = true;
  error.value = null;
  try {
    programs.value = await TutoringService.getPrograms();
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Gagal memuat program.';
  } finally {
    loading.value = false;
  }
}

async function create() {
  if (form.value.name.trim().length < 3) {
    toast.error('Nama program minimal 3 karakter.');
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createProgram({
      name: form.value.name.trim(),
      target_education_level:
        form.value.target_education_level.trim() || undefined,
      description: form.value.description.trim() || undefined,
    });
    toast.success('Program dibuat.');
    showForm.value = false;
    form.value = { name: '', target_education_level: '', description: '' };
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal membuat program.');
  } finally {
    saving.value = false;
  }
}

async function remove(p: TutoringProgram) {
  if (!window.confirm(`Hapus program "${p.name}"?`)) return;
  try {
    await TutoringService.deleteProgram(p.id);
    toast.success('Program dihapus.');
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menghapus program.');
  }
}

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <header class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-bold text-slate-800">Program Bimbel</h1>
      <button
        class="rounded-lg bg-indigo-900 px-4 py-2 text-sm font-semibold text-white"
        @click="showForm = !showForm"
      >
        {{ showForm ? 'Tutup' : '+ Program' }}
      </button>
    </header>

    <!-- Create form -->
    <section
      v-if="showForm"
      class="mb-4 space-y-3 rounded-2xl border border-slate-200 p-4"
    >
      <input
        v-model="form.name"
        placeholder="Nama program (cth. Intensif UTBK 2026)"
        class="w-full rounded-lg border border-slate-300 px-3 py-2"
      />
      <input
        v-model="form.target_education_level"
        placeholder="Target jenjang (opsional, cth. SMA)"
        class="w-full rounded-lg border border-slate-300 px-3 py-2"
      />
      <textarea
        v-model="form.description"
        placeholder="Deskripsi (opsional)"
        rows="2"
        class="w-full rounded-lg border border-slate-300 px-3 py-2"
      />
      <button
        :disabled="saving"
        class="rounded-lg bg-indigo-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        @click="create"
      >
        {{ saving ? 'Menyimpan…' : 'Simpan' }}
      </button>
    </section>

    <div v-if="loading" class="py-16 text-center text-slate-500">Memuat…</div>
    <div v-else-if="error" class="rounded-xl border border-red-200 bg-red-50 p-6 text-center">
      <p class="text-red-700">{{ error }}</p>
      <button class="mt-3 text-sm font-semibold text-red-700 underline" @click="load">
        Coba lagi
      </button>
    </div>
    <p v-else-if="programs.length === 0" class="py-12 text-center text-slate-500">
      Belum ada program. Tambah lewat tombol + Program.
    </p>
    <ul v-else class="space-y-2.5">
      <li
        v-for="p in programs"
        :key="p.id"
        class="flex items-center justify-between rounded-2xl border border-slate-200 p-4"
      >
        <div>
          <div class="font-bold text-slate-800">{{ p.name }}</div>
          <div class="text-sm text-slate-500">
            {{
              [
                p.target_education_level,
                (p.packages_count ?? 0) + ' paket',
                (p.groups_count ?? 0) + ' kelompok',
              ]
                .filter(Boolean)
                .join(' · ')
            }}
          </div>
        </div>
        <button
          class="text-sm font-semibold text-red-600"
          @click="remove(p)"
        >
          Hapus
        </button>
      </li>
    </ul>
  </div>
</template>
