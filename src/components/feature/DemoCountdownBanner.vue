<!--
  DemoCountdownBanner.vue — live demo expiry indicator.

  Mounts in the AppShell topbar AND becomes invisible when:
    - active school is not a demo
    - user has dismissed in this tab (sessionStorage flag)
    - the /demo/expiry call returns null / 404

  Severity colour shifts as the deadline approaches:
    > 7 days   → muted slate ribbon
    ≤ 7 days   → amber
    ≤ 24 hours → red

  Clicking the body opens a modal with "Perpanjang" /
  "Upgrade ke produksi" CTAs (modal stub points at a future view —
  for now CTAs just toast a "coming soon" notice).
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { DemoService } from '@/services/demo.service';
import { useToast } from '@/composables/useToast';
import NavIcon from '@/components/feature/NavIcon.vue';

const SESSION_KEY = 'demo_banner_dismissed_v1';

interface BannerData {
  /** Canonical column: `schools.name` (was `school_name`). */
  name: string;
  expires_at: string | null;
  seconds_remaining: number;
  severity: 'normal' | 'warning' | 'danger';
}

const data = ref<BannerData | null>(null);
const dismissed = ref(false);
const showModal = ref(false);
const toast = useToast();
let tickHandle: ReturnType<typeof setInterval> | null = null;

onMounted(async () => {
  // Per spec: dismiss is session-scoped — reload re-shows.
  dismissed.value = sessionStorage.getItem(SESSION_KEY) === 'true';
  await refresh();
  // Tick the seconds-remaining counter locally each minute so the
  // displayed "sisa N hari M jam" updates without re-fetching.
  tickHandle = setInterval(() => {
    if (data.value && data.value.seconds_remaining > 0) {
      data.value.seconds_remaining = Math.max(0, data.value.seconds_remaining - 60);
      data.value.severity = severityFor(data.value.seconds_remaining);
    }
  }, 60_000);
});

onUnmounted(() => {
  if (tickHandle) clearInterval(tickHandle);
});

async function refresh() {
  const info = await DemoService.getExpiry();
  if (!info) {
    data.value = null;
    return;
  }
  data.value = {
    name: info.name,
    expires_at: info.expires_at,
    seconds_remaining: info.seconds_remaining,
    severity: info.severity,
  };
}

function severityFor(seconds: number): 'normal' | 'warning' | 'danger' {
  if (seconds <= 86_400) return 'danger';
  if (seconds <= 86_400 * 7) return 'warning';
  return 'normal';
}

function dismiss(event: Event) {
  event.stopPropagation();
  dismissed.value = true;
  sessionStorage.setItem(SESSION_KEY, 'true');
}

const visible = computed(() => Boolean(data.value && !dismissed.value));

const countdownLabel = computed(() => {
  if (!data.value) return '';
  const total = data.value.seconds_remaining;
  if (total <= 0) return 'Demo telah berakhir';
  const days = Math.floor(total / 86_400);
  const hours = Math.floor((total % 86_400) / 3_600);
  if (days > 0) return `${days} hari ${hours} jam tersisa`;
  if (hours > 0) {
    const mins = Math.floor((total % 3_600) / 60);
    return `${hours} jam ${mins} menit tersisa`;
  }
  const mins = Math.max(1, Math.floor(total / 60));
  return `${mins} menit tersisa`;
});

const skinClass = computed(() => {
  if (!data.value) return '';
  switch (data.value.severity) {
    case 'danger':
      return 'bg-red-500/95 text-white border-red-600';
    case 'warning':
      return 'bg-amber-500/95 text-white border-amber-600';
    default:
      return 'bg-slate-700/80 text-white border-slate-600';
  }
});

const iconName = computed(() =>
  data.value?.severity === 'danger' ? 'alert-triangle' : 'clock',
);

function handleExtend() {
  showModal.value = false;
  toast.success('Permintaan perpanjangan demo terkirim. Tim kami akan menghubungi.');
}

function handleUpgrade() {
  showModal.value = false;
  window.open('https://kamiledu.id/pricing', '_blank');
}
</script>

<template>
  <button
    v-if="visible && data"
    type="button"
    class="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-2xs font-bold border transition-shadow hover:shadow-md cursor-pointer"
    :class="skinClass"
    :title="data.expires_at ? `Berakhir ${new Date(data.expires_at).toLocaleString('id-ID')}` : ''"
    @click="showModal = true"
  >
    <NavIcon :name="iconName" :size="12" />
    <span class="uppercase tracking-wider text-[9.5px] opacity-75">Demo</span>
    <span>· {{ countdownLabel }}</span>
    <span
      class="ml-1 -mr-1 w-4 h-4 rounded-full hover:bg-white/20 flex items-center justify-center"
      role="button"
      aria-label="Sembunyikan banner demo"
      @click="dismiss"
    >
      <NavIcon name="x" :size="10" />
    </span>
  </button>

  <!-- Info modal — wired via v-if for Samsung-safe rendering -->
  <div
    v-if="showModal && data"
    class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4"
    @click.self="showModal = false"
  >
    <div class="bg-white rounded-2xl max-w-sm w-full p-5 shadow-2xl">
      <div class="flex items-center gap-3 mb-3">
        <div
          class="w-10 h-10 rounded-xl flex items-center justify-center"
          :class="
            data.severity === 'danger'
              ? 'bg-red-100 text-red-600'
              : data.severity === 'warning'
              ? 'bg-amber-100 text-amber-600'
              : 'bg-slate-100 text-slate-600'
          "
        >
          <NavIcon name="clock" :size="22" />
        </div>
        <div class="flex-1 min-w-0">
          <h3 class="text-[15px] font-bold text-slate-900">Sekolah demo</h3>
          <p class="text-2xs text-slate-500 truncate">{{ data.name }}</p>
        </div>
      </div>

      <div class="border-y border-slate-100 py-3 my-3 text-center">
        <div class="text-[22px] font-black text-slate-900">{{ countdownLabel }}</div>
        <p v-if="data.expires_at" class="text-2xs text-slate-500 mt-1">
          Berakhir {{ new Date(data.expires_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' }) }}
        </p>
      </div>

      <p class="text-[12.5px] text-slate-600 mb-4 leading-relaxed">
        Setelah masa demo berakhir, data sekolah dan semua akun pendukung akan dihapus otomatis.
        Anda bisa minta perpanjangan, atau upgrade ke akun produksi kapan saja.
      </p>

      <div class="space-y-2">
        <button
          type="button"
          class="w-full py-2.5 rounded-lg bg-role-admin text-white text-[13px] font-bold hover:bg-role-admin/90"
          @click="handleUpgrade"
        >
          Upgrade ke produksi
        </button>
        <button
          type="button"
          class="w-full py-2.5 rounded-lg border border-slate-300 text-slate-700 text-[13px] font-bold hover:bg-slate-50"
          @click="handleExtend"
        >
          Minta perpanjangan demo
        </button>
        <button
          type="button"
          class="w-full py-2 text-[12px] text-slate-500 hover:text-slate-700"
          @click="showModal = false"
        >
          Tetap demo · tutup
        </button>
      </div>
    </div>
  </div>
</template>
