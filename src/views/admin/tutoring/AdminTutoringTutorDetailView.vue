<!--
  AdminTutoringTutorDetailView — full rewrite per mockup
  admin_redesign_w1_people frame 3.

  Hero (navy) with tutor name + meta + 3-stat strip (rating / jam /
  honor), then 2-col body: sessions list on left, honor + groups
  stacked on right.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringSession,
  TutoringTutorRow,
  TutorPayoutSummary,
} from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminConfirmDialog from '@/components/feature/tutoring/AdminConfirmDialog.vue';
import { useToast } from '@/composables/useToast';

const route = useRoute();
const router = useRouter();
const toast = useToast();
const userId = computed(() => String(route.params.userId || ''));

const showEdit = ref(false);
const editName = ref('');
const editBusy = ref(false);
const showDeactivate = ref(false);
const deactivateBusy = ref(false);

function openEdit() {
  editName.value = tutor.value?.name ?? '';
  showEdit.value = true;
}

async function submitEdit() {
  if (!tutor.value) return;
  if (editName.value.trim().length < 2) { toast.error('Nama minimal 2 huruf'); return; }
  editBusy.value = true;
  try {
    await TutoringService.updateTutor(tutor.value.user_id, { name: editName.value.trim() });
    toast.success('Profil tutor diperbarui.');
    showEdit.value = false;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.'); }
  finally { editBusy.value = false; }
}

async function confirmDeactivate() {
  if (!tutor.value) return;
  deactivateBusy.value = true;
  try {
    const r = await TutoringService.deactivateTutor(tutor.value.user_id);
    toast.success(r.groups_unassigned > 0
      ? `Tutor nonaktif. ${r.groups_unassigned} kelompok perlu tutor baru.`
      : 'Tutor nonaktif.');
    router.push({ name: 'admin.tutoring.tutors' });
  } catch (e) { toast.error(e instanceof Error ? e.message : 'Gagal menonaktifkan.'); }
  finally { deactivateBusy.value = false; }
}

const loading = ref(true);
const tutor = ref<TutoringTutorRow | null>(null);
const sessions = ref<TutoringSession[]>([]);
const payout = ref<TutorPayoutSummary | null>(null);

async function load() {
  const uid = userId.value;
  if (!uid) { loading.value = false; return; }
  loading.value = true;
  const now = new Date();
  const from = new Date(now.getTime() - 30 * 86_400_000);
  const to = new Date(now.getTime() + 14 * 86_400_000);
  try {
    const [tutors, sched, pay] = await Promise.all([
      TutoringService.getAdminTutors().catch(() => []),
      TutoringService.getAllSessions(from, to).catch(() => []),
      TutoringService.getPayoutSummary({ user_id: uid }).catch(() => null),
    ]);
    tutor.value = (tutors as TutoringTutorRow[]).find((t) => t.user_id === uid) ?? null;
    const myGroupIds = new Set((tutor.value?.groups ?? []).map((g) => g.id));
    sessions.value = (sched as TutoringSession[]).filter((s) => myGroupIds.has(s.group_id));
    payout.value = pay;
  } finally { loading.value = false; }
}
onMounted(load);
watch(userId, load);

const sessionsSorted = computed(() =>
  [...sessions.value].sort((a, b) => {
    const ta = a.scheduled_at ? new Date(a.scheduled_at).valueOf() : 0;
    const tb = b.scheduled_at ? new Date(b.scheduled_at).valueOf() : 0;
    return tb - ta;
  }).slice(0, 8),
);

const heroStats = computed(() => [
  {
    label: 'SESI 30H',
    value: String(tutor.value?.sessions_30d ?? 0),
    hint: `${sessions.value.filter((s) => s.status === 'DONE').length} DONE`,
  },
  {
    label: 'JAM BULAN INI',
    value: payout.value ? `${Math.round(payout.value.hours)}h` : '—',
    hint: payout.value?.period.label,
  },
  {
    label: 'HONOR BULAN INI',
    value: payout.value ? formatRupiah(payout.value.earnings) : '—',
    hint: payout.value ? `${payout.value.sessions_count} sesi` : undefined,
  },
]);

function whenLabel(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  const today = new Date();
  const isToday = d.toDateString() === today.toDateString();
  return isToday
    ? `Hari ini · ${d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}`
    : d.toLocaleString('id-ID', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1 text-[13px] text-bimbel-text-mid hover:text-bimbel-text-hi"
      @click="router.push({ name: 'admin.tutoring.tutors' })"
    >
      <NavIcon name="chevron-left" :size="13" /> Kembali ke daftar tutor
    </button>

    <TutorBerandaHero
      greeting="TUTOR · DETAIL"
      :title="tutor?.name ?? 'Memuat…'"
      :subtitle="tutor ? [tutor.groups[0]?.program, `${tutor.group_count} kelompok`, tutor.email].filter(Boolean).join(' · ') : undefined"
      :stats="heroStats"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[13px] font-bold text-white hover:bg-white/25"
          @click="openEdit"
        >
          <NavIcon name="edit" :size="13" class="inline -mt-0.5" /> Edit
        </button>
        <button
          type="button"
          class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[13px] font-bold text-rose-200 hover:bg-rose-500/30"
          @click="showDeactivate = true"
        >
          <NavIcon name="user-x" :size="13" class="inline -mt-0.5" /> Nonaktifkan
        </button>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[13px] font-bold"
          @click="router.push({ name: 'admin.tutoring.payouts' })"
        >
          <NavIcon name="wallet" :size="13" class="inline -mt-0.5" /> Atur honor
        </button>
      </template>
    </TutorBerandaHero>

    <div v-if="showEdit" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="showEdit = false">
      <div class="w-full max-w-md rounded-2xl bg-bimbel-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-bimbel-text-hi">Ubah profil tutor</h3>
        <p class="text-[13px] text-bimbel-text-mid">{{ tutor?.email }}</p>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Nama</span>
          <input v-model="editName" type="text" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="showEdit = false">Batal</button>
          <button type="button" :disabled="editBusy" class="flex-1 rounded-lg bg-bimbel-accent px-3 py-2 text-[13px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="submitEdit">{{ editBusy ? 'Menyimpan…' : 'Simpan' }}</button>
        </div>
      </div>
    </div>

    <AdminConfirmDialog
      :open="showDeactivate"
      title="Nonaktifkan tutor?"
      :message="`${tutor?.name ?? ''} akan dikeluarkan dari semua kelompok yang dia ajar dan kehilangan akses bimbel. Akun-nya tetap ada — admin bisa undang ulang nanti.`"
      confirm-label="Nonaktifkan"
      danger
      :busy="deactivateBusy"
      @cancel="showDeactivate = false"
      @confirm="confirmDeactivate"
    />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else class="grid gap-4 lg:grid-cols-3">
      <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 lg:col-span-2">
        <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Sesi mendatang & terakhir</h4>
        <div v-if="sessionsSorted.length === 0" class="py-6 text-center text-[13px] text-bimbel-text-mid">
          Belum ada sesi.
        </div>
        <div
          v-for="s in sessionsSorted"
          :key="s.id"
          class="flex items-center justify-between border-b border-bimbel-border-soft py-2.5 last:border-b-0"
        >
          <div class="min-w-0 flex-1">
            <p class="font-bold text-bimbel-text-hi truncate">
              {{ s.topic ?? 'Sesi terjadwal' }}
              <span class="text-bimbel-text-mid font-normal">· {{ s.group?.name ?? '—' }}</span>
            </p>
            <p class="text-[12px] text-bimbel-text-mid">{{ whenLabel(s.scheduled_at) }} · {{ s.duration_minutes }}m</p>
          </div>
          <span
            class="rounded-full px-2 py-0.5 text-[12px] font-bold"
            :class="s.status === 'DONE' ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300' : s.status === 'CANCELLED' ? 'bg-rose-500/15 text-rose-700 dark:text-rose-300' : 'bg-bimbel-accent-dim text-bimbel-accent'"
          >{{ s.status_label ?? s.status }}</span>
        </div>
      </section>

      <div class="space-y-3">
        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Honor & pencairan</h4>
          <p class="text-[13px] text-bimbel-text-mid">
            Basis: {{ payout?.rate.basis === 'PER_SESSION' ? 'per sesi' : 'per jam' }}
            <span class="font-bold text-bimbel-text-hi">· {{ payout ? formatRupiah(payout.rate.amount) : '—' }} / {{ payout?.rate.basis === 'PER_SESSION' ? 'sesi' : 'jam' }}</span>
          </p>
          <p v-if="payout?.rate.note" class="text-[12px] text-bimbel-text-mid">{{ payout.rate.note }}</p>
          <div v-if="payout" class="mt-2.5 flex items-center justify-between border-t border-bimbel-border-soft pt-2.5 text-[13px]">
            <span class="text-bimbel-text-mid">{{ payout.period.label }}</span>
            <span class="font-bold text-bimbel-text-hi">{{ formatRupiah(payout.earnings) }}</span>
          </div>
        </section>

        <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Kelompok diajar</h4>
          <div v-if="!tutor?.groups?.length" class="py-4 text-center text-[13px] text-bimbel-text-mid">
            Belum ada kelompok.
          </div>
          <div
            v-for="g in tutor?.groups ?? []"
            :key="g.id"
            class="border-b border-bimbel-border-soft py-2 last:border-b-0"
          >
            <p class="text-[13px] font-bold text-bimbel-text-hi">{{ g.name }}</p>
            <p v-if="g.program" class="text-[12px] text-bimbel-text-mid">{{ g.program }}</p>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>
