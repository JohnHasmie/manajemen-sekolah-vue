<!--
  SubscribeAddonTransferView — post-addon-purchase transfer confirmation.

  Serves the /subscribe/addon/transfer/{token} URL that
  ManageModulesView.vue navigates to after POST /billing/modules/add
  succeeds. The addon payload (order_id, amount, bank_transfer_info,
  share_url) is passed via `history.state.addon` — no re-fetch needed
  because the admin who just created it already has the data in
  memory from the api response.

  Deep-link case (someone pastes the URL later) shows a warm
  fallback pointing back to Kelola Modul, since the public
  addon-lookup endpoint isn't built yet. Follow-up: add
  `GET /billing/public/addon-transfer/{token}` mirroring the
  subscription share_token endpoint so a bendahara can open the
  forwarded link without auth.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { ModuleAddonCreated } from '@/types/subscription-billing';

const route = useRoute();
const router = useRouter();

const token = computed<string>(() => (route.params.token as string) ?? '');
const addon = ref<ModuleAddonCreated | null>(null);
const copied = ref<'link' | 'account' | 'reference' | null>(null);

onMounted(() => {
  // Fast path: doAdd() pushes the AddonCreated payload into
  // history.state before navigating so the view paints immediately
  // with real data (no round-trip, no auth loop).
  const state = window.history.state as { addon?: ModuleAddonCreated } | null;
  if (state?.addon && typeof state.addon === 'object') {
    addon.value = state.addon;
  }
  // If state is empty (deep-link, page refresh, WA-forwarded URL)
  // we intentionally leave `addon.value === null` and render the
  // fallback below. Fetching by token needs a public endpoint that
  // doesn't exist yet — tracked as a follow-up.
});

function money(v: number): string {
  const n = Math.max(0, Math.round(v));
  return 'Rp ' + new Intl.NumberFormat('id-ID').format(n);
}

async function copyToClipboard(kind: 'link' | 'account' | 'reference', value: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(value);
    copied.value = kind;
    window.setTimeout(() => {
      if (copied.value === kind) copied.value = null;
    }, 2000);
  } catch {
    // Clipboard API can fail in some contexts; silent fallback is fine
    // — the value is still visible on screen for manual copy.
  }
}

function goManage(): void {
  void router.push('/subscribe/manage-modules');
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 py-8 px-4">
    <div class="max-w-lg mx-auto">
      <header class="mb-6 text-center">
        <p class="text-2xs font-black uppercase tracking-widest text-brand-cobalt">
          Pesanan modul
        </p>
        <h1 class="text-2xl font-bold text-slate-900 mt-1">
          Selesaikan pembayaran
        </h1>
        <p class="text-sm text-slate-500 mt-1.5">
          Modul aktif otomatis setelah pembayaran diverifikasi.
        </p>
      </header>

      <!-- Have data — full transfer instructions. -->
      <section
        v-if="addon"
        class="rounded-2xl border border-slate-200 bg-white p-6"
      >
        <div class="text-center">
          <div class="w-12 h-12 rounded-full bg-emerald-100 text-emerald-700 grid place-items-center mx-auto">
            <NavIcon name="check-circle" :size="24" />
          </div>
          <h2 class="mt-3 text-lg font-bold text-slate-900">
            Pesanan berhasil dibuat
          </h2>
          <p class="mt-1 text-sm text-slate-600 leading-relaxed">
            Transfer sesuai instruksi di bawah. Modul <strong>{{ addon.module_key }}</strong>
            aktif otomatis dalam ~15 menit lewat Midtrans, atau maks 1×24 jam via transfer manual.
          </p>
        </div>

        <div class="mt-5 rounded-lg bg-slate-50 p-4 space-y-2 text-[13px]">
          <div class="flex justify-between items-center">
            <span class="text-slate-500">Kode pesanan</span>
            <button
              type="button"
              class="font-mono font-semibold text-slate-900 hover:text-brand-cobalt"
              @click="copyToClipboard('reference', addon.order_id)"
            >
              {{ addon.order_id }}
              <span v-if="copied === 'reference'" class="ml-1 text-emerald-600 text-2xs">✓ tersalin</span>
            </button>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">Jumlah</span>
            <span class="font-semibold text-slate-900">{{ money(addon.amount) }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">Prorata sisa periode</span>
            <span class="font-semibold text-slate-900">{{ addon.days_remaining }} hari</span>
          </div>
        </div>

        <div class="mt-4 rounded-lg border border-slate-200 p-4 space-y-2 text-[13px]">
          <p class="text-2xs font-bold text-slate-500 uppercase tracking-widest mb-2">
            Transfer bank
          </p>
          <div class="flex justify-between">
            <span class="text-slate-500">Bank</span>
            <span class="font-semibold text-slate-900">{{ addon.bank_transfer_info.bank_name }}</span>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-slate-500">No. rekening</span>
            <button
              type="button"
              class="font-mono font-semibold text-slate-900 hover:text-brand-cobalt"
              @click="copyToClipboard('account', addon.bank_transfer_info.account_number)"
            >
              {{ addon.bank_transfer_info.account_number }}
              <span v-if="copied === 'account'" class="ml-1 text-emerald-600 text-2xs">✓ tersalin</span>
            </button>
          </div>
          <div class="flex justify-between">
            <span class="text-slate-500">Atas nama</span>
            <span class="font-semibold text-slate-900">{{ addon.bank_transfer_info.account_holder }}</span>
          </div>
        </div>

        <p class="mt-4 text-[12px] text-slate-500 leading-relaxed">
          <strong>Cantumkan kode pesanan</strong> di berita transfer supaya bendahara bisa cocokkan pembayaran otomatis.
        </p>

        <!-- Shareable link — bendahara/PIC keuangan bisa buka halaman ini
             tanpa masuk aplikasi (fallback deep-link belum jalan, tapi
             link bisa diteruskan sebagai referensi manual). -->
        <div class="mt-4">
          <p class="text-2xs font-bold text-slate-500 uppercase tracking-widest mb-1">
            Link untuk bendahara
          </p>
          <div class="flex items-center gap-2 rounded-lg bg-slate-50 border border-slate-200 px-3 py-2">
            <input
              type="text"
              readonly
              class="flex-1 bg-transparent text-2xs font-mono text-slate-700 outline-none"
              :value="addon.share_url"
            />
            <button
              type="button"
              class="text-2xs font-bold text-brand-cobalt hover:underline"
              @click="copyToClipboard('link', addon.share_url)"
            >
              {{ copied === 'link' ? '✓ Tersalin' : 'Salin' }}
            </button>
          </div>
        </div>

        <Button
          variant="primary"
          size="lg"
          block
          class="mt-6"
          @click="goManage"
        >
          Kembali ke Kelola Modul
        </Button>
      </section>

      <!-- Deep-link fallback — user pasted URL directly (or refreshed
           the page), so we don't have the addon data. Guide back to
           Kelola Modul where the pending addon is still visible. -->
      <section
        v-else
        class="rounded-2xl border border-amber-200 bg-amber-50 p-6"
      >
        <div class="text-center">
          <div class="w-12 h-12 rounded-full bg-amber-100 text-amber-700 grid place-items-center mx-auto">
            <NavIcon name="info" :size="24" />
          </div>
          <h2 class="mt-3 text-lg font-bold text-amber-900">
            Data pesanan tidak tersedia
          </h2>
          <p class="mt-1 text-sm text-amber-800 leading-relaxed">
            Halaman ini menampilkan instruksi transfer modul yang baru dibuat.
            Jika kamu membuka link ini setelah tab lama ditutup, buka Kelola Modul
            untuk melihat pesanan yang masih menunggu pembayaran.
          </p>
          <p class="mt-3 text-[12px] text-amber-700 font-mono">
            Token: {{ token || '(kosong)' }}
          </p>
        </div>
        <Button
          variant="primary"
          size="lg"
          block
          class="mt-5"
          @click="goManage"
        >
          Buka Kelola Modul
        </Button>
      </section>
    </div>
  </div>
</template>
