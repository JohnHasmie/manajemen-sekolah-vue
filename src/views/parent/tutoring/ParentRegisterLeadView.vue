<!--
  ParentRegisterLeadView — wali calon "daftar anak baru" form. New
  bimbel-token styled inputs, choice cards for program, secondary
  "Simpan draft" + primary "Kirim" CTA. Script (TutoringService.createLead
  payload, validation) unchanged.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringProgram } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const router = useRouter();

const programs = ref<TutoringProgram[]>([]);
const selectedProgramId = ref<string>('');
const form = ref({
  name: '',
  phone: '',
  email: '',
  childName: '',
  jenjang: '',
  notes: '',
});
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

async function loadPrograms() {
  try { programs.value = await TutoringService.getPrograms(); }
  catch {/* non-fatal */}
}
onMounted(loadPrograms);

const canSubmit = computed(() =>
  form.value.name.trim().length >= 2 &&
  form.value.phone.trim().length >= 8 &&
  form.value.childName.trim().length >= 2 &&
  !!selectedProgramId.value &&
  !saving.value,
);

async function submit() {
  if (!canSubmit.value) return;
  saving.value = true;
  message.value = null;
  try {
    await TutoringService.createLead({
      name: form.value.name,
      email: form.value.email || undefined,
      phone: form.value.phone,
      program_id: selectedProgramId.value,
      notes: [
        `Nama anak: ${form.value.childName}`,
        form.value.jenjang && `Jenjang: ${form.value.jenjang}`,
        form.value.notes && `Catatan: ${form.value.notes}`,
      ].filter(Boolean).join(' · '),
    });
    message.value = { kind: 'ok', text: 'Pendaftaran terkirim. Admin akan menghubungi Anda dalam 1×24 jam.' };
    form.value = { name: '', phone: '', email: '', childName: '', jenjang: '', notes: '' };
    selectedProgramId.value = '';
  } catch (e) {
    message.value = { kind: 'err', text: e instanceof Error ? e.message : 'Gagal mengirim pendaftaran.' };
  } finally { saving.value = false; }
}

function saveDraft() {
  // Local draft stash — non-fatal if quota fails.
  try {
    localStorage.setItem(
      'parent.registerLead.draft',
      JSON.stringify({ form: form.value, programId: selectedProgramId.value }),
    );
    message.value = { kind: 'ok', text: 'Draft disimpan di perangkat ini.' };
  } catch {/* ignore */}
}

const programTone = (idx: number) =>
  ['blue', 'green', 'amber', 'blue', 'green'][idx % 5];
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · DAFTAR ANAK"
      title="Daftarkan anak baru"
      subtitle="Anak akan dibuat akun siswa baru di bimbel ini"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-lg bg-white px-3 py-1.5 text-[13px] font-bold text-bimbel-hero hover:bg-white/95"
          @click="router.back()"
        >
          <i class="ti ti-x text-[13px]"></i>
          Batal
        </button>
      </template>
    </ParentBerandaHero>

    <!-- 1. Data anak -->
    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      Data anak
    </p>
    <p class="text-[11px] text-bimbel-text-mid mb-1">Nama lengkap anak</p>
    <input
      v-model="form.childName"
      type="text"
      class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo block w-full mb-2 focus:outline-none"
      placeholder="Nama lengkap anak"
    />

    <div class="grid grid-cols-2 gap-2 mb-2">
      <div>
        <p class="text-[11px] text-bimbel-text-mid mb-1">Kelas</p>
        <select
          v-model="form.jenjang"
          class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[13px] text-bimbel-text-hi block w-full focus:outline-none"
        >
          <option value="">— pilih kelas —</option>
          <option value="SD 1">SD kelas 1</option>
          <option value="SD 2">SD kelas 2</option>
          <option value="SD 3">SD kelas 3</option>
          <option value="SD 4">SD kelas 4</option>
          <option value="SD 5">SD kelas 5</option>
          <option value="SD 6">SD kelas 6</option>
          <option value="SMP 7">SMP kelas 7</option>
          <option value="SMP 8">SMP kelas 8</option>
          <option value="SMP 9">SMP kelas 9</option>
          <option value="SMA 10">SMA kelas 10</option>
          <option value="SMA 11">SMA kelas 11</option>
          <option value="SMA 12">SMA kelas 12</option>
        </select>
      </div>
      <div>
        <p class="text-[11px] text-bimbel-text-mid mb-1">Sekolah asal</p>
        <input
          v-model="form.name"
          type="text"
          class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo block w-full focus:outline-none"
          placeholder="Nama sekolah"
        />
      </div>
    </div>

    <!-- contact (kept for valid payload but quiet styling) -->
    <div class="grid grid-cols-2 gap-2 mb-2">
      <div>
        <p class="text-[11px] text-bimbel-text-mid mb-1">No HP / WA wali</p>
        <input
          v-model="form.phone"
          type="tel"
          class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo block w-full focus:outline-none"
          placeholder="08xx-xxxx-xxxx"
        />
      </div>
      <div>
        <p class="text-[11px] text-bimbel-text-mid mb-1">Email wali (opsional)</p>
        <input
          v-model="form.email"
          type="email"
          class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo block w-full focus:outline-none"
          placeholder="opsional"
        />
      </div>
    </div>

    <!-- 2. Program -->
    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      Program yang diminati
    </p>
    <div v-if="!programs.length" class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-6 text-center text-[12px] text-bimbel-text-mid">
      Memuat daftar program…
    </div>
    <button
      v-for="(p, idx) in programs"
      :key="p.id"
      type="button"
      class="w-full rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3 mb-1.5 flex gap-2.5 items-center text-left"
      :class="selectedProgramId === p.id ? 'border-2 border-bimbel-hero p-[11px]' : ''"
      @click="selectedProgramId = p.id"
    >
      <span
        class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-lg"
        :class="
          programTone(idx) === 'green'
            ? 'bg-bimbel-green-dim text-green-700'
            : programTone(idx) === 'amber'
            ? 'bg-bimbel-amber-dim text-amber-700'
            : 'bg-bimbel-accent-dim text-bimbel-hero'
        "
      >
        <i class="ti ti-book-2 text-[18px]"></i>
      </span>
      <div class="min-w-0 flex-1">
        <p class="text-[13px] font-bold text-bimbel-text-hi truncate">{{ p.name }}</p>
        <p v-if="p.description" class="text-[11px] text-bimbel-text-mid truncate">{{ p.description }}</p>
      </div>
    </button>

    <!-- 3. Catatan ortu -->
    <p class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      Catatan orang tua (opsional)
    </p>
    <textarea
      v-model="form.notes"
      rows="3"
      placeholder="Misal: anak butuh fokus mapel Matematika, jadwal sore lebih pas, dll."
      class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo block w-full min-h-12 focus:outline-none"
    ></textarea>

    <div
      v-if="message"
      class="rounded-md mt-3 px-3 py-2 text-[12px]"
      :class="message.kind === 'ok' ? 'bg-bimbel-green-dim text-green-700' : 'bg-bimbel-red-dim text-red-700'"
    >{{ message.text }}</div>

    <!-- 4. CTA -->
    <div class="flex gap-2 mt-3">
      <button
        type="button"
        class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft text-[13px] font-bold px-3.5 py-2.5"
        @click="saveDraft"
      >Simpan draft</button>
      <button
        type="button"
        :disabled="!canSubmit"
        class="flex-1 rounded-lg bg-bimbel-hero text-white text-[13px] font-bold px-3.5 py-2.5 disabled:opacity-50"
        @click="submit"
      >{{ saving ? 'Mengirim…' : 'Kirim — admin akan hubungi dalam 1×24 jam' }}</button>
    </div>
  </div>
</template>
