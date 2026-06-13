<!--
  ParentUbahSandiView — wali ubah kata sandi page. Mockup
  parent_web_pages_create_update frame 4: 2-col layout (form left,
  tips on right).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { SettingsService } from '@/services/settings.service';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();

const current = ref('');
const next = ref('');
const confirm = ref('');
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

const strength = computed(() => {
  const p = next.value;
  if (!p) return 0;
  let score = 0;
  if (p.length >= 8) score++;
  if (/[A-Z]/.test(p) && /[a-z]/.test(p)) score++;
  if (/\d/.test(p)) score++;
  if (/[^\w\s]/.test(p)) score++;
  return score;
});

const strengthLabel = computed(() => {
  if (strength.value === 0) return 'Belum diisi';
  if (strength.value === 1) return 'Lemah';
  if (strength.value === 2) return 'Sedang';
  if (strength.value === 3) return 'Kuat · sandi diterima';
  return 'Sangat kuat';
});

const strengthColor = computed(() => {
  if (strength.value <= 1) return '#e24b4a';
  if (strength.value === 2) return '#f59e0b';
  return '#1d9e75';
});

const canSubmit = computed(() =>
  current.value.length >= 6 &&
  next.value.length >= 8 &&
  next.value === confirm.value &&
  !saving.value,
);

async function submit() {
  if (!canSubmit.value) return;
  saving.value = true;
  message.value = null;
  try {
    await SettingsService.updatePassword({
      old_password: current.value,
      new_password: next.value,
      confirm_password: confirm.value,
    });
    message.value = { kind: 'ok', text: 'Kata sandi berhasil diperbarui.' };
    current.value = '';
    next.value = '';
    confirm.value = '';
  } catch (e) {
    message.value = {
      kind: 'err',
      text: e instanceof Error ? e.message : 'Gagal memperbarui sandi.',
    };
  } finally { saving.value = false; }
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-[12px] text-bimbel-text-mid hover:text-bimbel-text-hi"
      @click="router.push({ name: 'parent.tutoring.profil' })"
    >
      <NavIcon name="chevron-left" :size="13" /> Kembali ke profil
    </button>

    <ParentBerandaHero
      kicker="BIMBEL · UBAH SANDI"
      title="Ubah kata sandi"
      subtitle="Gunakan sandi yang kuat dan tidak dipakai di akun lain"
      :stats="[]"
    />

    <div class="grid gap-4 lg:grid-cols-5">
      <form
        class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-3 space-y-3"
        @submit.prevent="submit"
      >
        <h4 class="text-[13px] font-bold tracking-tight text-bimbel-text-hi">Kata sandi baru</h4>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Sandi saat ini</span>
          <input
            v-model="current"
            type="password"
            required
            class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
          />
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Sandi baru</span>
          <input
            v-model="next"
            type="password"
            required
            minlength="8"
            class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
          />
          <span class="mt-0.5 block text-[12px] text-bimbel-text-lo">Minimal 8 karakter · campur huruf besar/kecil & angka</span>
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Konfirmasi sandi</span>
          <input
            v-model="confirm"
            type="password"
            required
            class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
          />
        </label>
        <div>
          <p class="text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Kekuatan sandi</p>
          <div class="mt-1 flex gap-1">
            <div
              v-for="i in 4"
              :key="i"
              class="h-1.5 flex-1 rounded-full"
              :style="{ background: strength >= i ? strengthColor : 'var(--bimbel-border)' }"
            />
          </div>
          <p class="mt-1 text-[12px]" :style="{ color: strengthColor }">{{ strengthLabel }}</p>
        </div>
        <div v-if="message" class="rounded-lg px-3 py-2 text-[12px]" :class="message.kind === 'ok' ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-rose-500/10 text-rose-700 dark:text-rose-300'">
          {{ message.text }}
        </div>
        <div class="flex gap-2 pt-2">
          <button
            type="button"
            class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
            @click="router.push({ name: 'parent.tutoring.profil' })"
          >Batal</button>
          <button
            type="submit"
            :disabled="!canSubmit"
            class="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-[13px] font-bold text-white hover:opacity-90 disabled:opacity-50"
          >{{ saving ? 'Menyimpan…' : 'Simpan sandi baru' }}</button>
        </div>
      </form>

      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4 lg:col-span-2 h-fit">
        <h4 class="mb-2 text-[13px] font-bold tracking-tight text-bimbel-text-hi">Tips sandi kuat</h4>
        <ul class="space-y-1.5 text-[12px] text-bimbel-text-mid list-disc pl-4">
          <li>Minimal 8 karakter</li>
          <li>Campur huruf besar, kecil, dan angka</li>
          <li>Hindari nama anak / tanggal lahir</li>
          <li>Jangan pakai sandi yang sama dengan akun lain</li>
        </ul>
      </aside>
    </div>
  </div>
</template>
