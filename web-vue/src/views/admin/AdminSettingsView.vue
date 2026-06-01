<!--
  AdminSettingsView.vue - school settings hub.
  Sections: school profile, levels, time periods, system, data backup.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';

const router = useRouter();

const showResetModal = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

interface SettingsGroup {
  title: string;
  items: { icon: string; label: string; desc: string; to?: string; action?: () => void; danger?: boolean }[];
}

const groups: SettingsGroup[] = [
  {
    title: 'Profil Sekolah',
    items: [
      { icon: 'home', label: 'Profil sekolah', desc: 'Nama, alamat, jenjang sekolah', to: '/admin/settings/school' },
      { icon: 'calendar', label: 'Tahun ajaran', desc: 'Atur tahun ajaran aktif & semester', to: '/admin/settings/kelola-tahun-ajaran' },
    ],
  },
  {
    title: 'Operasional',
    items: [
      { icon: 'calendar', label: 'Jam pelajaran', desc: 'Sesi mengajar, jam mulai-selesai, hari aktif', to: '/admin/schedule/lesson-hours' },
      { icon: 'wallet', label: 'Tagihan & biaya', desc: 'Jenis tagihan, nominal default, jatuh tempo', to: '/admin/finance/jenis' },
    ],
  },
  {
    title: 'Data',
    items: [
      { icon: 'layers', label: 'Manajemen data', desc: 'Siswa · Guru · Kelas · Mata pelajaran', to: '/admin/settings/data' },
      { icon: 'file-text', label: 'Backup data', desc: 'Unduh backup database ke lokal' },
      { icon: 'edit', label: 'Reset data demo', desc: 'Hapus semua data demo (tidak dapat dibatalkan)', danger: true },
    ],
  },
  {
    title: 'Sistem',
    items: [
      { icon: 'bell', label: 'Notifikasi', desc: 'Konfigurasi push notification & email' },
      { icon: 'sparkles', label: 'AI integrations', desc: 'API key, kuota, penggunaan' },
    ],
  },
];

function open(it: SettingsGroup['items'][number]) {
  if (it.to) router.push(it.to);
  else if (it.action) it.action();
  else if (it.danger) showResetModal.value = true;
  else toast.value = { message: 'Halaman pengaturan ini sedang dikerjakan.', tone: 'error' };
}
</script>

<template>
  <div class="space-y-md">
    <header>
      <h1 class="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
        Pengaturan Sekolah
      </h1>
      <p class="text-xs text-slate-400 font-bold uppercase tracking-widest mt-1">
        Konfigurasi sekolah, sistem, dan data
      </p>
    </header>

    <div v-for="g in groups" :key="g.title" class="space-y-2">
      <h3 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest px-1">{{ g.title }}</h3>
      <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <button
          v-for="(it, idx) in g.items"
          :key="it.label"
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-slate-50 transition-colors"
          :class="[idx > 0 ? 'border-t border-slate-100' : '']"
          @click="open(it)"
        >
          <div
            class="w-9 h-9 rounded-lg grid place-items-center flex-shrink-0"
            :class="it.danger ? 'bg-red-100 text-red-700' : 'bg-role-admin/10 text-role-admin'"
          >
            <NavIcon :name="it.icon" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold" :class="it.danger ? 'text-red-700' : 'text-slate-900'">{{ it.label }}</p>
            <p class="text-[11px] text-slate-500 truncate">{{ it.desc }}</p>
          </div>
          <span class="text-slate-300">→</span>
        </button>
      </section>
    </div>

    <Modal v-if="showResetModal" title="Reset data demo" subtitle="Tindakan ini menghapus seluruh data demo dan tidak dapat dibatalkan." @close="showResetModal = false">
      <div class="space-y-md">
        <div class="bg-red-50 border border-red-200 rounded-xl p-3 text-[12px] text-red-700 leading-relaxed">
          <strong>Peringatan:</strong> Semua data siswa, guru, nilai, dan kehadiran akan dihapus permanen.
        </div>
        <div class="grid grid-cols-2 gap-2">
          <Button variant="secondary" block @click="showResetModal = false">Batal</Button>
          <Button variant="danger" block @click="showResetModal = false">Ya, reset</Button>
        </div>
      </div>
    </Modal>

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
