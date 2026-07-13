<!--
  ResetPasswordModal.vue — admin resets a managed user's login password.

  Self-contained: the host passes a `resetFn` (the service call) plus a label.
  The modal collects the choice (auto-generate vs type a custom password),
  runs the reset, then shows the resulting password ONCE with a copy button.

  Used by admin Teacher + Student management (guru + wali). Backend contract:
  `{ password, was_generated }` — see TeacherService.resetPassword /
  StudentService.resetGuardianPassword.
-->
<script setup lang="ts">
import { ref, computed } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Modal title, e.g. "Reset Password Guru". */
  title: string;
  /** Who the password belongs to, shown as context (name/email). */
  subjectName?: string;
  /** The service call. Omitting the arg = let the server generate one. */
  resetFn: (password?: string) => Promise<{ password: string; was_generated: boolean }>;
}>();

const emit = defineEmits<{
  close: [];
  /** Fired once the reset succeeds, so the host can toast + refresh. */
  done: [];
}>();

type Mode = 'generate' | 'manual';
const mode = ref<Mode>('generate');
const password = ref('');
const showPassword = ref(false);
const submitting = ref(false);
const err = ref<string | null>(null);

const result = ref<{ password: string; was_generated: boolean } | null>(null);
const copied = ref(false);

const manualInvalid = computed(
  () => mode.value === 'manual' && password.value.trim().length < 6,
);

async function submit() {
  if (submitting.value) return;
  err.value = null;
  if (manualInvalid.value) {
    err.value = 'Password minimal 6 karakter.';
    return;
  }
  submitting.value = true;
  try {
    result.value = await props.resetFn(
      mode.value === 'manual' ? password.value.trim() : undefined,
    );
    emit('done');
  } catch (e) {
    err.value = (e as Error).message || 'Gagal mereset password.';
  } finally {
    submitting.value = false;
  }
}

async function copyPassword() {
  if (!result.value) return;
  try {
    await navigator.clipboard.writeText(result.value.password);
    copied.value = true;
    setTimeout(() => (copied.value = false), 1800);
  } catch {
    // Clipboard blocked (insecure context / permissions) — the value is
    // select-all-able in the box, so this is a non-fatal convenience.
  }
}
</script>

<template>
  <Modal :title="title" size="md" @close="emit('close')">
    <!-- Phase 1: choose how to reset -->
    <div v-if="!result" class="space-y-4">
      <p v-if="subjectName" class="text-2xs text-slate-500">
        Untuk <span class="font-bold text-slate-800">{{ subjectName }}</span>
      </p>

      <div class="grid grid-cols-2 gap-2">
        <button
          type="button"
          class="rounded-xl border-2 p-3 text-left transition-colors"
          :class="mode === 'generate'
            ? 'border-role-admin bg-role-admin/5'
            : 'border-slate-200 bg-white hover:border-slate-300'"
          @click="mode = 'generate'"
        >
          <div class="flex items-center gap-1.5">
            <NavIcon name="refresh-cw" :size="13" />
            <span class="text-[13px] font-bold text-slate-900">Buatkan otomatis</span>
          </div>
          <p class="text-3xs text-slate-500 mt-1">Sistem membuat password acak yang aman.</p>
        </button>
        <button
          type="button"
          class="rounded-xl border-2 p-3 text-left transition-colors"
          :class="mode === 'manual'
            ? 'border-role-admin bg-role-admin/5'
            : 'border-slate-200 bg-white hover:border-slate-300'"
          @click="mode = 'manual'"
        >
          <div class="flex items-center gap-1.5">
            <NavIcon name="edit" :size="13" />
            <span class="text-[13px] font-bold text-slate-900">Ketik sendiri</span>
          </div>
          <p class="text-3xs text-slate-500 mt-1">Tentukan password baru sendiri.</p>
        </button>
      </div>

      <div v-if="mode === 'manual'">
        <label class="block text-2xs font-bold text-slate-600 mb-1">Password baru</label>
        <div class="relative">
          <input
            :type="showPassword ? 'text' : 'password'"
            v-model="password"
            placeholder="Minimal 6 karakter"
            class="w-full rounded-xl border border-slate-300 px-3 py-2.5 pr-10 text-[13px] focus:border-role-admin focus:outline-none focus:ring-1 focus:ring-role-admin"
            @keyup.enter="submit"
          />
          <button
            type="button"
            class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            @click="showPassword = !showPassword"
          >
            <NavIcon :name="showPassword ? 'eye-off' : 'eye'" :size="15" />
          </button>
        </div>
      </div>

      <p class="text-3xs text-slate-500 bg-slate-50 rounded-xl p-3 leading-relaxed">
        Password lama akan langsung diganti. Berikan password baru ini ke user secara
        langsung — user juga bisa menggantinya sendiri setelah masuk, atau memakai
        login Google.
      </p>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-1">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="submitting"
          :disabled="submitting || manualInvalid"
          @click="submit"
        >
          Reset Password
        </Button>
      </div>
    </div>

    <!-- Phase 2: show the resulting password once -->
    <div v-else class="space-y-4">
      <div class="flex items-center gap-2 text-emerald-700">
        <NavIcon name="check-circle" :size="18" />
        <p class="text-[14px] font-bold">Password berhasil direset</p>
      </div>

      <div class="rounded-xl bg-amber-50 border border-amber-200 p-3">
        <p class="text-3xs font-bold text-amber-700 uppercase tracking-wider">
          Password baru
        </p>
        <div class="mt-1.5 flex items-center justify-between gap-3">
          <span class="font-mono font-black text-[16px] text-slate-900 select-all break-all">
            {{ result.password }}
          </span>
          <button
            type="button"
            class="flex-shrink-0 inline-flex items-center gap-1 rounded-lg bg-white border border-amber-300 px-2.5 py-1.5 text-2xs font-bold text-amber-800 hover:bg-amber-100"
            @click="copyPassword"
          >
            <NavIcon :name="copied ? 'check' : 'copy'" :size="12" />
            {{ copied ? 'Tersalin' : 'Salin' }}
          </button>
        </div>
      </div>

      <p class="text-3xs text-slate-500 leading-relaxed">
        Simpan &amp; berikan password ini sekarang — hanya ditampilkan sekali. Kalau
        hilang, cukup reset lagi.
      </p>

      <Button variant="primary" block @click="emit('close')">Selesai</Button>
    </div>
  </Modal>
</template>
