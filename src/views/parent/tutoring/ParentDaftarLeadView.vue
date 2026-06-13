<!--
  ParentDaftarLeadView — wali calon form. Mockup
  parent_web_pages_create_update frame 1: form di kiri, info card di kanan.
  Submits to TutoringService.createLead.
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
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="DAFTAR CALON"
      title="Daftarkan diri"
      subtitle="Form singkat — admin akan menghubungi Anda dalam 1×24 jam"
      :stats="[]"
    />

    <div class="grid gap-4 lg:grid-cols-5">
      <form
        class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-3 space-y-3"
        @submit.prevent="submit"
      >
        <h4 class="text-[12.5px] font-bold tracking-tight text-bimbel-text-hi">Data wali & anak</h4>
        <div class="grid gap-3 sm:grid-cols-2">
          <label class="block">
            <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Nama wali <span class="text-rose-500">*</span></span>
            <input v-model="form.name" type="text" required class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none" placeholder="Nama lengkap" />
          </label>
          <label class="block">
            <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">No HP / WA <span class="text-rose-500">*</span></span>
            <input v-model="form.phone" type="tel" required class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none" placeholder="08xx-xxxx-xxxx" />
          </label>
          <label class="block sm:col-span-2">
            <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Email</span>
            <input v-model="form.email" type="email" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none" placeholder="Opsional" />
          </label>
          <label class="block">
            <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Nama anak <span class="text-rose-500">*</span></span>
            <input v-model="form.childName" type="text" required class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none" placeholder="Nama lengkap anak" />
          </label>
          <label class="block">
            <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Jenjang / kelas</span>
            <input v-model="form.jenjang" type="text" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none" placeholder="SMP VIII / SMA X / ..." />
          </label>
        </div>
        <div>
          <p class="text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Program diminati <span class="text-rose-500">*</span></p>
          <div class="mt-2 flex flex-wrap gap-1.5">
            <button
              v-for="p in programs"
              :key="p.id"
              type="button"
              class="rounded-full border px-3 py-1.5 text-[11.5px] font-semibold"
              :class="
                selectedProgramId === p.id
                  ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
                  : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
              "
              @click="selectedProgramId = p.id"
            >{{ p.name }}</button>
          </div>
        </div>
        <label class="block">
          <span class="block text-[11px] font-bold uppercase tracking-wider text-bimbel-text-mid">Catatan untuk admin</span>
          <textarea v-model="form.notes" rows="2" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[12.5px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none" placeholder="Opsional — info tambahan"></textarea>
        </label>
        <div v-if="message" class="rounded-lg px-3 py-2 text-[11.5px]" :class="message.kind === 'ok' ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-rose-500/10 text-rose-700 dark:text-rose-300'">
          {{ message.text }}
        </div>
      </form>

      <aside class="space-y-3 lg:col-span-2">
        <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 text-[11.5px] text-bimbel-text-mid">
          <h5 class="mb-2 text-[12px] font-bold text-bimbel-text-hi">Setelah submit</h5>
          <ul class="space-y-1 list-disc pl-4">
            <li>Admin menghubungi via WA dalam 24 jam</li>
            <li>Jadwalkan trial gratis 1 sesi</li>
            <li>Jika cocok → diundang ke akun penuh</li>
          </ul>
          <p class="mt-3 pt-2 border-t border-bimbel-border-soft">
            Sudah punya akun?
            <a class="text-[#1a8fbe] dark:text-[#85d4f4] font-bold cursor-pointer" @click="router.push({ name: 'auth.login' })">Masuk di sini</a>
          </p>
        </div>
        <div class="flex gap-2">
          <button
            type="button"
            class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[12.5px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
            @click="router.back()"
          >Batal</button>
          <button
            type="button"
            :disabled="!canSubmit"
            class="flex-1 rounded-lg bg-[#21afe6] px-3 py-2 text-[12.5px] font-bold text-white hover:opacity-90 disabled:opacity-50"
            @click="submit"
          >{{ saving ? 'Mengirim…' : 'Kirim pendaftaran' }}</button>
        </div>
      </aside>
    </div>
  </div>
</template>
