<!--
  ParentChangePasswordView — wali ubah kata sandi. 2-column layout:
  form on the left (label-col + input with eye/check icons + strength
  bar) and tips checklist on the right with live met/unmet state.
  Keeps SettingsService.updatePassword submit path.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { SettingsService } from '@/services/settings.service';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();

const form = ref({ current: '', next: '', confirm: '' });
const showCurrent = ref(false);
const showNext = ref(false);
const showConfirm = ref(false);
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

const tips = computed(() => {
  const next = form.value.next;
  return [
    { label: 'Minimal 8 karakter', met: next.length >= 8 },
    { label: 'Angka & huruf', met: /\d/.test(next) && /[a-z]/i.test(next) },
    { label: 'Karakter spesial', met: /[^a-z0-9]/i.test(next) },
    { label: 'Bukan kata umum', met: next.length > 0 && !['password', '12345678', 'qwerty'].includes(next.toLowerCase()) },
  ];
});

const strengthLevel = computed(() => tips.value.filter((t) => t.met).length);

const strengthBarCls = computed(() => {
  const lvl = strengthLevel.value;
  if (lvl <= 1) return 'bg-red-600';
  if (lvl <= 3) return 'bg-amber-500';
  return 'bg-green-600';
});

const strengthTextCls = computed(() => {
  const lvl = strengthLevel.value;
  if (lvl <= 1) return 'text-red-700';
  if (lvl <= 3) return 'text-amber-700';
  return 'text-green-700';
});

const strengthLabel = computed(() => {
  const lvl = strengthLevel.value;
  if (lvl === 0) return 'Belum diisi';
  if (lvl === 1) return 'Lemah — tambah panjang & variasi';
  if (lvl === 2) return 'Sedang — bisa lebih kuat';
  if (lvl === 3) return 'Kuat — sandi diterima';
  return 'Sangat kuat — bagus!';
});

const matches = computed(
  () => form.value.next.length > 0 && form.value.next === form.value.confirm,
);

const canSubmit = computed(
  () => strengthLevel.value >= 3 && matches.value && form.value.current.length > 0 && !saving.value,
);

function cancel() {
  router.push({ name: 'parent.tutoring.profile' });
}

async function submit() {
  if (!canSubmit.value) return;
  saving.value = true;
  message.value = null;
  try {
    await SettingsService.updatePassword({
      old_password: form.value.current,
      new_password: form.value.next,
      confirm_password: form.value.confirm,
    });
    message.value = { kind: 'ok', text: 'Kata sandi berhasil diperbarui.' };
    form.value = { current: '', next: '', confirm: '' };
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
      subtitle="Disarankan setiap 90 hari · terakhir diubah 4 bulan lalu"
      :stats="[]"
    />

    <div class="grid lg:grid-cols-2 gap-4">
      <div>
        <div
          class="grid items-center gap-3 border-b border-bimbel-border-soft py-2"
          style="grid-template-columns: 130px 1fr;"
        >
          <span class="text-[13px] text-bimbel-text-mid">Sandi sekarang</span>
          <div class="bg-bimbel-bg rounded-md px-3 py-2 text-[14px] flex justify-between items-center">
            <input
              v-model="form.current"
              :type="showCurrent ? 'text' : 'password'"
              class="bg-transparent flex-1 focus:outline-none text-bimbel-text-hi"
            />
            <button type="button" class="text-bimbel-text-mid" @click="showCurrent = !showCurrent">
              <NavIcon :name="showCurrent ? 'eye-off' : 'eye'" :size="14" />
            </button>
          </div>
        </div>

        <div
          class="grid items-center gap-3 border-b border-bimbel-border-soft py-2"
          style="grid-template-columns: 130px 1fr;"
        >
          <span class="text-[13px] text-bimbel-text-mid">Sandi baru</span>
          <div class="bg-bimbel-bg rounded-md px-3 py-2 text-[14px] flex justify-between items-center">
            <input
              v-model="form.next"
              :type="showNext ? 'text' : 'password'"
              class="bg-transparent flex-1 focus:outline-none text-bimbel-text-hi"
            />
            <button type="button" class="text-bimbel-text-mid" @click="showNext = !showNext">
              <NavIcon :name="showNext ? 'eye-off' : 'eye'" :size="14" />
            </button>
          </div>
        </div>

        <div class="pl-[142px]">
          <div class="flex gap-1 mt-1.5">
            <span
              v-for="i in 4"
              :key="i"
              :class="['flex-1 h-1 rounded-sm', i <= strengthLevel ? strengthBarCls : 'bg-bimbel-bg']"
            ></span>
          </div>
          <p class="text-[12px] mt-1" :class="strengthTextCls">{{ strengthLabel }}</p>
        </div>

        <div
          class="grid items-center gap-3 border-b border-bimbel-border-soft py-2"
          style="grid-template-columns: 130px 1fr;"
        >
          <span class="text-[13px] text-bimbel-text-mid">Konfirmasi</span>
          <div class="bg-bimbel-bg rounded-md px-3 py-2 text-[14px] flex justify-between items-center">
            <input
              v-model="form.confirm"
              :type="showConfirm ? 'text' : 'password'"
              class="bg-transparent flex-1 focus:outline-none text-bimbel-text-hi"
            />
            <NavIcon v-if="matches" name="check" :size="14" class="text-green-700" />
            <button v-else type="button" class="text-bimbel-text-mid" @click="showConfirm = !showConfirm">
              <NavIcon :name="showConfirm ? 'eye-off' : 'eye'" :size="14" />
            </button>
          </div>
        </div>

        <div
          v-if="message"
          class="rounded-md mt-3 px-3 py-2 text-[13px]"
          :class="message.kind === 'ok' ? 'bg-bimbel-green-dim text-green-700' : 'bg-bimbel-red-dim text-red-700'"
        >{{ message.text }}</div>

        <div class="flex gap-2 mt-3.5">
          <button
            type="button"
            class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft text-[14px] px-3.5 py-2.5"
            @click="cancel"
          >Batal</button>
          <button
            type="button"
            :disabled="!canSubmit"
            class="flex-1 rounded-lg bg-bimbel-hero text-white text-[14px] font-bold px-3.5 py-2.5 disabled:opacity-50"
            @click="submit"
          >{{ saving ? 'Menyimpan…' : 'Simpan kata sandi' }}</button>
        </div>
      </div>

      <div class="rounded-md bg-bimbel-bg p-3.5">
        <p class="text-[13px] font-bold text-bimbel-text-hi mb-1.5">Tips kata sandi kuat</p>
        <div class="grid grid-cols-2 gap-1.5">
          <div
            v-for="t in tips"
            :key="t.label"
            class="flex gap-1.5 items-center text-[12px]"
            :class="t.met ? 'text-green-700' : 'text-bimbel-text-lo'"
          >
            <NavIcon :name="t.met ? 'check' : 'x'" :size="13" />{{ t.label }}
          </div>
        </div>
        <div class="border-t border-bimbel-border-soft mt-3 pt-2.5 text-[12px] text-bimbel-text-mid leading-relaxed">
          Sandi disimpan ter-enkripsi. Jika lupa, gunakan reset via email yang terdaftar di profil.
        </div>
      </div>
    </div>
  </div>
</template>
