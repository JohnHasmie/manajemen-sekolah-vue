<!--
  ForgotPasswordModal.vue — port of `forgot_password_sheet.dart`.
  Single email field, posts to /auth/forgot-password. Throttled server-side.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { AuthService } from '@/services/auth.service';
import Modal from '@/components/ui/Modal.vue';

const emit = defineEmits<{ close: [] }>();

const email = ref('');
const isLoading = ref(false);
const message = ref<string | null>(null);
const error = ref<string | null>(null);

async function handleSubmit() {
  if (!email.value.trim()) {
    error.value = 'Email wajib diisi.';
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    const res = await AuthService.forgotPassword(email.value.trim());
    message.value = res.message;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}
</script>

<template>
  <Modal
    title="Lupa kata sandi"
    subtitle="Masukkan email akun Anda. Kami akan mengirimkan tautan untuk mengatur ulang kata sandi."
    @close="emit('close')"
  >
    <div v-if="message" class="space-y-md">
      <div
        class="rounded-xl bg-status-success-soft text-emerald-900 px-md py-sm text-sm border border-emerald-200"
      >
        {{ message }}
      </div>
      <button
        type="button"
        class="w-full rounded-xl bg-brand hover:bg-brand-700 text-white font-semibold py-sm"
        @click="emit('close')"
      >
        Tutup
      </button>
    </div>

    <form v-else class="space-y-md" @submit.prevent="handleSubmit">
      <div>
        <label for="forgot-email" class="block text-sm font-medium text-slate-700 mb-1">Email</label>
        <input
          id="forgot-email"
          v-model="email"
          type="email"
          autocomplete="email"
          placeholder="nama@sekolah.sch.id"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm placeholder:text-slate-400 focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
          :disabled="isLoading"
        />
      </div>

      <p v-if="error" class="text-sm text-status-danger">{{ error }}</p>

      <div class="grid grid-cols-2 gap-2">
        <button
          type="button"
          class="rounded-xl border border-slate-300 hover:bg-slate-50 py-sm text-sm font-medium"
          @click="emit('close')"
        >
          Batal
        </button>
        <button
          type="submit"
          class="rounded-xl bg-brand hover:bg-brand-700 disabled:bg-brand/60 text-white font-semibold py-sm text-sm"
          :disabled="isLoading"
        >
          {{ isLoading ? 'Mengirim…' : 'Kirim tautan' }}
        </button>
      </div>
    </form>
  </Modal>
</template>
