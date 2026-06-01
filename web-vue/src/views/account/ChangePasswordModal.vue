<!--
  ChangePasswordModal.vue — port of Flutter's `change_password_dialog`.

  Three fields (current / new / confirm) with client-side validation:
    • current required
    • new ≥ 8 chars
    • new === confirm

  Submits via SettingsService.updatePassword and surfaces backend
  errors verbatim (the Laravel /profile/password endpoint returns
  "Password lama tidak sesuai" / "Konfirmasi password tidak cocok"
  etc. — friendlier than swallowing them).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { SettingsService } from '@/services/settings.service';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const emit = defineEmits<{
  close: [];
  success: [];
}>();

const oldPw = ref('');
const newPw = ref('');
const confirmPw = ref('');
const showOld = ref(false);
const showNew = ref(false);
const showConfirm = ref(false);
const isSaving = ref(false);
const formError = ref<string | null>(null);

const newPwOk = computed(() => newPw.value.length >= 8);
const matches = computed(() => newPw.value === confirmPw.value);
const canSubmit = computed(
  () =>
    !!oldPw.value &&
    newPwOk.value &&
    matches.value &&
    !isSaving.value,
);

async function submit() {
  formError.value = null;
  if (!oldPw.value) {
    formError.value = 'Masukkan password lama.';
    return;
  }
  if (!newPwOk.value) {
    formError.value = 'Password baru minimal 8 karakter.';
    return;
  }
  if (!matches.value) {
    formError.value = 'Konfirmasi password tidak cocok.';
    return;
  }
  isSaving.value = true;
  try {
    await SettingsService.updatePassword({
      old_password: oldPw.value,
      new_password: newPw.value,
      confirm_password: confirmPw.value,
    });
    emit('success');
    emit('close');
  } catch (e) {
    formError.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <Modal
    title="Ubah Kata Sandi"
    subtitle="Pilih password baru minimal 8 karakter"
    size="sm"
    @close="emit('close')"
  >
    <form class="space-y-3" @submit.prevent="submit">
      <div>
        <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
          Password Lama
        </label>
        <div class="mt-1 relative">
          <input
            v-model="oldPw"
            :type="showOld ? 'text' : 'password'"
            autocomplete="current-password"
            class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 pr-10 text-[13px] text-slate-900 outline-none focus:border-role-admin"
          />
          <button
            type="button"
            class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            @click="showOld = !showOld"
          >
            <NavIcon :name="showOld ? 'eye' : 'eye'" :size="14" />
          </button>
        </div>
      </div>

      <div>
        <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
          Password Baru
        </label>
        <div class="mt-1 relative">
          <input
            v-model="newPw"
            :type="showNew ? 'text' : 'password'"
            autocomplete="new-password"
            class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 pr-10 text-[13px] text-slate-900 outline-none focus:border-role-admin"
          />
          <button
            type="button"
            class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            @click="showNew = !showNew"
          >
            <NavIcon :name="showNew ? 'eye' : 'eye'" :size="14" />
          </button>
        </div>
        <p
          v-if="newPw && !newPwOk"
          class="text-[10.5px] text-amber-700 mt-1"
        >
          Password baru harus minimal 8 karakter.
        </p>
      </div>

      <div>
        <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
          Konfirmasi Password Baru
        </label>
        <div class="mt-1 relative">
          <input
            v-model="confirmPw"
            :type="showConfirm ? 'text' : 'password'"
            autocomplete="new-password"
            class="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 pr-10 text-[13px] text-slate-900 outline-none focus:border-role-admin"
          />
          <button
            type="button"
            class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            @click="showConfirm = !showConfirm"
          >
            <NavIcon :name="showConfirm ? 'eye' : 'eye'" :size="14" />
          </button>
        </div>
        <p
          v-if="confirmPw && !matches"
          class="text-[10.5px] text-red-700 mt-1"
        >
          Konfirmasi password tidak cocok.
        </p>
      </div>

      <p
        v-if="formError"
        class="text-[11.5px] font-bold text-red-700 bg-red-50 border border-red-200 rounded-lg px-3 py-2"
      >
        {{ formError }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-1">
        <Button
          type="button"
          variant="secondary"
          block
          :disabled="isSaving"
          @click="emit('close')"
        >
          Batal
        </Button>
        <Button
          type="submit"
          variant="primary"
          block
          :disabled="!canSubmit"
        >
          {{ isSaving ? 'Menyimpan…' : 'Simpan' }}
        </Button>
      </div>
    </form>
  </Modal>
</template>
