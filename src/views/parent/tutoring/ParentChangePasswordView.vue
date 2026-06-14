<!--
  ParentChangePasswordView — wali ubah kata sandi. 2-col layout: form
  on the left with row layout (label-col + input with eye/check icons),
  strength bar + label, tips checklist on the right with live state.
  Script (strength compute, submit) unchanged.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { SettingsService } from '@/services/settings.service';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';

const router = useRouter();

const current = ref('');
const next = ref('');
const confirm = ref('');
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

const showCurrent = ref(false);
const showNext = ref(false);
const showConfirm = ref(false);

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
  if (strength.value === 1) return 'Lemah — tambah panjang & variasi';
  if (strength.value === 2) return 'Sedang — bisa lebih kuat';
  if (strength.value === 3) return 'Kuat — sandi diterima';
  return 'Sangat kuat — bagus!';
});

const strengthTextClass = computed(() => {
  if (strength.value <= 1) return 'text-red-700';
  if (strength.value === 2) return 'text-amber-700';
  return 'text-green-700';
});

const strengthBarClass = computed(() => {
  if (strength.value <= 1) return 'bg-red-500';
  if (strength.value === 2) return 'bg-amber-500';
  return 'bg-green-700';
});

const tips = computed(() => [
  { label: 'Minimal 8 karakter', ok: next.value.length >= 8 },
  { label: 'Angka & huruf', ok: /[A-Za-z]/.test(next.value) && /\d/.test(next.value) },
  { label: 'Karakter spesial', ok: /[^\w\s]/.test(next.value) },
  { label: 'Bukan kata umum', ok: next.value.length >= 8 && !/^(password|12345678|qwerty)/i.test(next.value) },
]);

const matches = computed(() => confirm.value.length > 0 && next.value === confirm.value);

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
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · KEAMANAN"
      title="Ubah kata sandi"
      subtitle="Disarankan setiap 90 hari · gunakan sandi yang tidak dipakai di akun lain"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-lg bg-white px-3 py-1.5 text-[13px] font-bold text-bimbel-hero hover:bg-white/95"
          @click="router.push({ name: 'parent.tutoring.profile' })"
        >
          <i class="ti ti-arrow-left text-[13px]"></i>
          Kembali
        </button>
      </template>
    </ParentBerandaHero>

    <div class="grid gap-4 lg:grid-cols-2 mt-3">
      <!-- LEFT: form -->
      <div class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-3">
        <!-- Sandi sekarang -->
        <div class="grid grid-cols-[130px_1fr] gap-3 items-center py-2 border-b border-bimbel-border-soft">
          <span class="text-[12px] text-bimbel-text-mid">Sandi sekarang</span>
          <div class="flex justify-between items-center gap-2 rounded-md bg-bimbel-bg px-3 py-2">
            <input
              v-model="current"
              :type="showCurrent ? 'text' : 'password'"
              class="flex-1 bg-transparent text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:outline-none"
              placeholder="Masukkan sandi saat ini"
            />
            <button
              type="button"
              class="text-bimbel-text-mid hover:text-bimbel-text-hi"
              @click="showCurrent = !showCurrent"
            >
              <i class="ti text-[14px]" :class="showCurrent ? 'ti-eye-off' : 'ti-eye'"></i>
            </button>
          </div>
        </div>

        <!-- Sandi baru -->
        <div class="grid grid-cols-[130px_1fr] gap-3 items-center py-2 border-b border-bimbel-border-soft">
          <span class="text-[12px] text-bimbel-text-mid">Sandi baru</span>
          <div class="flex justify-between items-center gap-2 rounded-md bg-bimbel-bg px-3 py-2">
            <input
              v-model="next"
              :type="showNext ? 'text' : 'password'"
              minlength="8"
              class="flex-1 bg-transparent text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:outline-none"
              placeholder="Min 8 karakter"
            />
            <button
              type="button"
              class="text-bimbel-text-mid hover:text-bimbel-text-hi"
              @click="showNext = !showNext"
            >
              <i class="ti text-[14px]" :class="showNext ? 'ti-eye-off' : 'ti-eye'"></i>
            </button>
          </div>
        </div>

        <!-- Strength bar -->
        <div class="pl-[142px] py-2 border-b border-bimbel-border-soft">
          <div class="flex gap-1 mt-1.5">
            <div
              v-for="i in 4"
              :key="i"
              class="flex-1 h-1 rounded-sm"
              :class="strength >= i ? strengthBarClass : 'bg-bimbel-border-soft'"
            />
          </div>
          <p class="mt-1 text-[11px]" :class="strengthTextClass">{{ strengthLabel }}</p>
        </div>

        <!-- Konfirmasi -->
        <div class="grid grid-cols-[130px_1fr] gap-3 items-center py-2 border-b border-bimbel-border-soft">
          <span class="text-[12px] text-bimbel-text-mid">Konfirmasi</span>
          <div class="flex justify-between items-center gap-2 rounded-md bg-bimbel-bg px-3 py-2">
            <input
              v-model="confirm"
              :type="showConfirm ? 'text' : 'password'"
              class="flex-1 bg-transparent text-[13px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:outline-none"
              placeholder="Ulangi sandi baru"
            />
            <i
              v-if="matches"
              class="ti ti-check text-[14px] text-green-700"
            ></i>
            <button
              type="button"
              class="text-bimbel-text-mid hover:text-bimbel-text-hi"
              @click="showConfirm = !showConfirm"
            >
              <i class="ti text-[14px]" :class="showConfirm ? 'ti-eye-off' : 'ti-eye'"></i>
            </button>
          </div>
        </div>

        <div
          v-if="message"
          class="rounded-md mt-3 px-3 py-2 text-[12px]"
          :class="message.kind === 'ok' ? 'bg-bimbel-green-dim text-green-700' : 'bg-bimbel-red-dim text-red-700'"
        >{{ message.text }}</div>

        <div class="flex gap-2 mt-3.5">
          <button
            type="button"
            class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft text-[13px] font-bold px-3.5 py-2.5"
            @click="router.push({ name: 'parent.tutoring.profile' })"
          >Batal</button>
          <button
            type="button"
            :disabled="!canSubmit"
            class="flex-1 rounded-lg bg-bimbel-hero text-white text-[13px] font-bold px-3.5 py-2.5 disabled:opacity-50"
            @click="submit"
          >{{ saving ? 'Menyimpan…' : 'Simpan kata sandi' }}</button>
        </div>
      </div>

      <!-- RIGHT: tips -->
      <div class="rounded-md bg-bimbel-bg p-3.5 h-fit">
        <p class="text-[12px] font-bold text-bimbel-text-hi mb-1.5">Tips kata sandi kuat</p>
        <div class="grid grid-cols-2 gap-1.5">
          <div
            v-for="t in tips"
            :key="t.label"
            class="flex gap-1.5 items-center text-[11px]"
            :class="t.ok ? 'text-bimbel-text-hi' : 'text-bimbel-text-mid'"
          >
            <i
              class="ti text-[13px]"
              :class="t.ok ? 'ti-check text-green-700' : 'ti-x text-bimbel-text-lo'"
            ></i>
            <span>{{ t.label }}</span>
          </div>
        </div>
        <div class="border-t border-bimbel-border-soft mt-3 pt-2.5">
          <p class="text-[11px] text-bimbel-text-mid leading-relaxed">
            Sandi disimpan ter-enkripsi. Jika lupa, gunakan reset via email yang terdaftar di profil.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
