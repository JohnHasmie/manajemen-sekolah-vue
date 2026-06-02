<!--
  Step 10 — Done. Shows summary stats + the 3 credentials (admin =
  Google login, guru/wali = generated emails+passwords). Click-to-
  copy on the password fields. Does NOT mention 30-day expiry — the
  dashboard banner will reveal that next.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { useToast } from '@/composables/useToast';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';

const wizard = useDemoWizardStore();
const auth = useAuthStore();
const toast = useToast();

const summary = computed(() => wizard.result?.summary);
const credentials = computed(() => wizard.result?.credentials ?? []);

async function copyValue(value: string, label: string) {
  try {
    await navigator.clipboard.writeText(value);
    toast.success(`${label} disalin.`);
  } catch {
    toast.error('Gagal menyalin.');
  }
}

const roleIcon: Record<string, string> = {
  admin: 'shield',
  'admin (multi)': 'shield',
  teacher: 'user-check',
  parent: 'heart',
};
</script>

<template>
  <div>
    <div v-if="wizard.isProvisioning" class="text-center py-12">
      <Spinner size="lg" />
      <p class="mt-4 text-[14px] font-bold text-slate-700">Sedang membangun sekolah Anda…</p>
      <p class="text-[12px] text-slate-500 mt-1">Ini biasanya butuh beberapa detik.</p>
    </div>

    <div v-else-if="!wizard.result" class="text-center py-12 text-slate-500 text-[13px]">
      Tekan tombol "Buat sekolah demo" di langkah Skenario untuk memulai.
    </div>

    <div v-else>
      <div class="w-16 h-16 rounded-full bg-emerald-100 mx-auto mb-4 flex items-center justify-center">
        <NavIcon name="check" :size="32" class="text-emerald-600" />
      </div>
      <h2 class="text-[22px] font-black text-slate-900 text-center mb-1">
        Sekolah demo Anda siap!
      </h2>
      <p class="text-center text-[13px] text-slate-600 mb-5">
        Simpan kredensial di bawah — Anda butuh untuk coba 3 role.
      </p>

      <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
        Data dasar
      </p>
      <div class="grid grid-cols-3 sm:grid-cols-6 gap-2 mb-4">
        <div
          v-for="s in [
            { n: summary?.guru ?? 0, l: 'guru' },
            { n: summary?.kelas ?? 0, l: 'kelas' },
            { n: summary?.siswa ?? 0, l: 'siswa' },
            { n: summary?.wali ?? 0, l: 'wali' },
            { n: summary?.jadwal ?? 0, l: 'jadwal' },
            { n: summary?.tagihan ?? 0, l: 'tagihan' },
          ]"
          :key="s.l"
          class="bg-slate-50 rounded-lg py-2 text-center"
        >
          <div class="text-[17px] font-black text-slate-900">{{ s.n }}</div>
          <div class="text-[10px] text-slate-500">{{ s.l }}</div>
        </div>
      </div>

      <template
        v-if="
          (summary?.kehadiran ?? 0) + (summary?.rpp ?? 0) + (summary?.pengumuman ?? 0) +
          (summary?.progress_subbab ?? 0) + (summary?.kegiatan_kelas ?? 0) +
          (summary?.nilai ?? 0) + (summary?.pembayaran ?? 0) +
          (summary?.pengumuman_event ?? 0) + (summary?.notifikasi ?? 0) +
          (summary?.rapor_draft ?? 0) + (summary?.submission_late ?? 0) +
          (summary?.audit_log ?? 0) > 0
        "
      >
        <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase mb-2">
          Skenario
        </p>
        <div class="grid grid-cols-3 sm:grid-cols-6 gap-2 mb-6">
          <div
            v-for="s in [
              { n: summary?.kehadiran ?? 0, l: 'kehadiran' },
              { n: summary?.rpp ?? 0, l: 'RPP' },
              { n: summary?.pengumuman ?? 0, l: 'pengumuman' },
              { n: summary?.progress_subbab ?? 0, l: 'progress' },
              { n: summary?.kegiatan_kelas ?? 0, l: 'kegiatan' },
              { n: summary?.nilai ?? 0, l: 'nilai' },
              { n: summary?.pembayaran ?? 0, l: 'bayar' },
              { n: summary?.pengumuman_event ?? 0, l: 'event' },
              { n: summary?.notifikasi ?? 0, l: 'notif' },
              { n: summary?.rapor_draft ?? 0, l: 'rapor' },
              { n: summary?.submission_late ?? 0, l: 'telat' },
              { n: summary?.audit_log ?? 0, l: 'log' },
            ]"
            :key="s.l"
            class="bg-role-admin/5 border border-role-admin/15 rounded-lg py-2 text-center"
          >
            <div class="text-[17px] font-black text-role-admin">{{ s.n }}</div>
            <div class="text-[10px] text-slate-500">{{ s.l }}</div>
          </div>
        </div>
      </template>

      <div class="flex items-end justify-between mb-2">
        <p class="text-[10.5px] font-bold tracking-widest text-slate-500 uppercase">
          3 akun untuk 3 sudut pandang
        </p>
      </div>
      <div
        class="bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 mb-3 flex items-start gap-2"
      >
        <NavIcon name="alert-circle" :size="14" class="text-amber-600 mt-0.5 flex-shrink-0" />
        <p class="text-[11.5px] text-amber-900 leading-snug">
          <strong>Akun Google Anda jadi ADMIN sekolah</strong> — dapat akses penuh ke semua
          data demo. Untuk merasakan POV guru atau wali yang sebenarnya (lihat jadwal
          mengajar / data anak), <strong>login dengan 2 akun di bawah di tab browser private</strong>.
          Jangan ketik password manual; pakai tombol <NavIcon name="copy" :size="11" class="inline-block -mt-0.5" /> salin
          supaya tidak salah karakter.
        </p>
      </div>
      <div class="grid gap-2 sm:grid-cols-3">
        <div
          v-for="cred in credentials"
          :key="cred.email"
          class="rounded-lg p-3 border"
          :class="
            cred.is_self
              ? 'bg-role-admin/5 border-role-admin/30'
              : 'bg-slate-50 border-slate-200'
          "
        >
          <div class="flex items-center gap-2 mb-1.5">
            <NavIcon :name="roleIcon[cred.role] ?? 'user'" :size="16" class="text-role-admin" />
            <span class="text-[10px] font-bold tracking-wider text-slate-500 uppercase">
              {{ cred.role }}
            </span>
            <span v-if="cred.is_self" class="ml-auto text-[10px] text-emerald-700 bg-emerald-100 px-1.5 py-0.5 rounded-full font-bold">
              Anda
            </span>
            <span v-else class="ml-auto text-[10px] text-slate-500 bg-slate-200 px-1.5 py-0.5 rounded-full font-bold">
              Demo
            </span>
          </div>
          <div class="flex items-center gap-1 mb-1">
            <code class="font-mono text-[11px] text-slate-900 truncate flex-1">{{ cred.email }}</code>
            <button
              type="button"
              class="text-slate-400 hover:text-role-admin shrink-0"
              :title="'Salin email'"
              @click="copyValue(cred.email, 'Email')"
            >
              <NavIcon name="copy" :size="12" />
            </button>
          </div>
          <div class="flex items-center gap-1">
            <code class="font-mono text-[11px] text-slate-500 truncate flex-1">
              {{ cred.password ?? (cred.note ?? 'Login Google') }}
            </code>
            <button
              v-if="cred.password"
              type="button"
              class="text-slate-400 hover:text-role-admin shrink-0"
              :title="'Salin password'"
              @click="copyValue(cred.password!, 'Password')"
            >
              <NavIcon name="copy" :size="12" />
            </button>
          </div>
          <p
            v-if="!cred.is_self"
            class="text-[10px] text-slate-500 mt-1.5 leading-snug"
          >
            Login dengan kartu ini untuk lihat sudut pandang
            {{ cred.role === 'teacher' ? 'guru — jadwal mengajar, nilai, RPP' : 'wali — tagihan anak, nilai anak, kehadiran anak' }}.
          </p>
        </div>
      </div>

      <p class="text-[11.5px] text-slate-500 mt-4 text-center leading-snug">
        Klik <strong>Masuk dashboard demo</strong> di bawah untuk masuk sebagai admin
        dengan akun Google Anda. Jangan tutup tab — buka tab incognito baru untuk
        login pakai akun guru / wali demo.
      </p>
    </div>
  </div>
</template>
