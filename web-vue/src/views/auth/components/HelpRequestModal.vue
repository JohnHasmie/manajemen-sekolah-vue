<!--
  HelpRequestModal.vue — port of `login_help_sheet.dart`.
  Posts to /auth/help-request which writes a row to login_help_requests
  and emails the support inbox.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { AuthService } from '@/services/auth.service';
import Modal from '@/components/ui/Modal.vue';

const emit = defineEmits<{ close: [] }>();

const name = ref('');
const email = ref('');
const school = ref('');
const message = ref('');

const isLoading = ref(false);
const successMessage = ref<string | null>(null);
const error = ref<string | null>(null);

async function handleSubmit() {
  if (!name.value.trim() || !email.value.trim() || !message.value.trim()) {
    error.value = 'Nama, email, dan pesan wajib diisi.';
    return;
  }
  isLoading.value = true;
  error.value = null;
  try {
    const res = await AuthService.submitHelpRequest({
      name: name.value.trim(),
      email: email.value.trim(),
      requestedSchoolName: school.value.trim() || undefined,
      message: message.value.trim(),
    });
    successMessage.value = res.message;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}
</script>

<template>
  <Modal
    title="Hubungi admin"
    subtitle="Tim KamilEdu akan membalas permintaan Anda melalui email."
    @close="emit('close')"
  >
    <div v-if="successMessage" class="space-y-md">
      <div
        class="rounded-xl bg-status-success-soft text-emerald-900 px-md py-sm text-sm border border-emerald-200"
      >
        {{ successMessage }}
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
        <label for="help-name" class="block text-sm font-medium text-slate-700 mb-1">Nama lengkap</label>
        <input
          id="help-name"
          v-model="name"
          type="text"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
          :disabled="isLoading"
        />
      </div>
      <div>
        <label for="help-email" class="block text-sm font-medium text-slate-700 mb-1">Email</label>
        <input
          id="help-email"
          v-model="email"
          type="email"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
          :disabled="isLoading"
        />
      </div>
      <div>
        <label for="help-school" class="block text-sm font-medium text-slate-700 mb-1">
          Nama sekolah <span class="text-slate-400 font-normal">(opsional)</span>
        </label>
        <input
          id="help-school"
          v-model="school"
          type="text"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
          :disabled="isLoading"
        />
      </div>
      <div>
        <label for="help-message" class="block text-sm font-medium text-slate-700 mb-1">Pesan</label>
        <textarea
          id="help-message"
          v-model="message"
          rows="4"
          placeholder="Jelaskan kendala yang Anda alami…"
          class="w-full rounded-xl border border-slate-300 px-md py-sm text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none resize-none"
          :disabled="isLoading"
        ></textarea>
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
          {{ isLoading ? 'Mengirim…' : 'Kirim permintaan' }}
        </button>
      </div>
    </form>
  </Modal>
</template>
