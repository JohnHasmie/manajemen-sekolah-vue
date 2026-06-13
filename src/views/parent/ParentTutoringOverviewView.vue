<!--
  ParentTutoringOverviewView — wali Beranda.

  Layout matches the approved mockup (parent_web_pages_main frame 1):

    Hero  (azure, greeting + child-picker + 4 KPI stats)
    Two-col body:
      LEFT  : Hari ini (accent-stripe card) + Tagihan ribbon
      RIGHT : Yang baru feed (panel)

  Reads:
    - getChildOverview(studentId)         → bills + attendance + progress + upcoming
    - getStudentFeed(studentId)           → "Yang baru" rows
    - getPaymentAccount()                 → unused here, kept for ribbon CTA
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import { useChildPicker } from '@/composables/useChildPicker';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringChildOverview,
  TutoringFeedEvent,
} from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import ParentPrimaryCard from '@/components/feature/tutoring/ParentPrimaryCard.vue';
import ParentRibbon from '@/components/feature/tutoring/ParentRibbon.vue';
import ParentActivityRow from '@/components/feature/tutoring/ParentActivityRow.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const data = ref<TutoringChildOverview | null>(null);
const feed = ref<TutoringFeedEvent[]>([]);

async function load() {
  const sid = studentId.value;
  if (!sid) {
    loading.value = false;
    return;
  }
  loading.value = true;
  try {
    const [overview, f] = await Promise.all([
      TutoringService.getChildOverview(sid),
      TutoringService.getStudentFeed(sid, { limit: 8, sinceDays: 30 }).catch(
        () => [] as TutoringFeedEvent[],
      ),
    ]);
    data.value = overview;
    feed.value = f;
  } finally {
    loading.value = false;
  }
}
onMounted(load);
watch(studentId, load);

// ── Greeting ─────────────────────────────────────────────────────
function timeGreeting(): string {
  const h = new Date().getHours();
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 19) return 'Selamat sore';
  return 'Selamat malam';
}

const firstName = computed(() => {
  const n = auth.user?.name || 'Wali';
  return n.split(/\s+/)[0];
});

const childName = computed(() => activeChild()?.name || 'anak');

// ── KPI strip (4 cells) ──────────────────────────────────────────
const heroStats = computed(() => {
  const d = data.value;
  const upcoming = d?.upcomingSessions ?? [];
  const sesiMgg = upcoming.filter((s) => {
    if (!s.scheduled_at) return false;
    const t = new Date(s.scheduled_at).valueOf();
    const week = Date.now() + 7 * 86_400_000;
    return t <= week;
  }).length;
  const att = d?.attendance?.attendance_rate;
  const avgScore = d?.progress?.summary?.overall?.average;
  const unpaid = (d?.bills ?? []).filter((b) =>
    /unpaid|pending|due|overdue|belum/i.test(b.status ?? ''),
  );
  const unpaidTotal = unpaid.reduce((s, b) => s + (b.amount ?? 0), 0);
  const todayCount = upcoming.filter((s) => {
    if (!s.scheduled_at) return false;
    const d = new Date(s.scheduled_at);
    const now = new Date();
    return d.toDateString() === now.toDateString();
  }).length;
  return [
    {
      label: 'SESI MGG INI',
      value: String(sesiMgg),
      hint: todayCount > 0 ? `${todayCount} hari ini` : 'tidak ada hari ini',
    },
    {
      label: 'KEHADIRAN 30H',
      value: att == null ? '–' : `${att}%`,
      hint: d?.attendance?.total_recorded
        ? `${d.attendance.attended} dari ${d.attendance.total_recorded} hadir`
        : 'belum tercatat',
    },
    {
      label: 'RATA-RATA NILAI',
      value: avgScore == null ? '–' : String(Math.round(avgScore)),
      hint: d?.progress?.summary?.overall?.count
        ? `${d.progress.summary.overall.count} nilai`
        : 'belum ada',
    },
    {
      label: 'TAGIHAN AKTIF',
      value: unpaid.length === 0 ? 'Lunas' : formatRupiah(unpaidTotal),
      hint: unpaid.length === 0 ? 'tidak ada tagihan' : `${unpaid.length} tagihan`,
    },
  ];
});

// ── Hari ini card ────────────────────────────────────────────────
const heroNext = computed(() => data.value?.upcomingSessions?.[0] ?? null);

const heroNextCountdown = computed(() => {
  const ns = heroNext.value;
  if (!ns?.scheduled_at) return null;
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return null;
  const diffMin = (d.valueOf() - Date.now()) / 60_000;
  if (diffMin < 0) return 'mulai';
  if (diffMin < 60) return `${Math.round(diffMin)} menit lagi`;
  const h = diffMin / 60;
  if (h < 24) return `${Math.round(h)} jam lagi`;
  return `${Math.round(h / 24)} hari lagi`;
});

const heroNextTone = computed<'success' | 'brand'>(() => {
  const ns = heroNext.value;
  if (!ns?.scheduled_at) return 'brand';
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return 'brand';
  const diffH = (d.valueOf() - Date.now()) / 3_600_000;
  return diffH <= 24 ? 'success' : 'brand';
});

const heroNextWhen = computed(() => {
  const ns = heroNext.value;
  if (!ns?.scheduled_at) return '';
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return '';
  const isToday = d.toDateString() === new Date().toDateString();
  return d.toLocaleString('id-ID', {
    weekday: isToday ? undefined : 'short',
    day: isToday ? undefined : 'numeric',
    month: isToday ? undefined : 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
});

// ── Tagihan ribbon ───────────────────────────────────────────────
const unpaidBills = computed(() =>
  (data.value?.bills ?? []).filter((b) =>
    /unpaid|pending|due|overdue|belum/i.test(b.status ?? ''),
  ),
);
const unpaidTotal = computed(() =>
  unpaidBills.value.reduce((s, b) => s + (b.amount ?? 0), 0),
);
const unpaidHint = computed(() => {
  const list = unpaidBills.value;
  if (list.length === 0) return '';
  const first = list[0];
  const due = first.due_date ? new Date(first.due_date) : null;
  const lbl = due
    ? `Jatuh tempo ${due.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}`
    : 'Jatuh tempo segera';
  return list.length > 1 ? `${lbl} · +${list.length - 1} lagi` : lbl;
});

function goPayFirstBill() {
  const first = unpaidBills.value[0];
  if (!first) return;
  router.push({ name: 'parent.tutoring.bill-pay', params: { billId: first.id } });
}

function goToTagihan() {
  router.push({ name: 'parent.tutoring.tagihan' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · BERANDA"
      :title="`Halo, ${firstName}`"
      :subtitle="`${timeGreeting()} · Wali dari ${childName}`"
      :stats="heroStats"
    >
      <template #actions>
        <ParentChildPickerChip />
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-[#0c447c] px-3 py-1.5 text-[12px] font-bold hover:bg-white/95"
          @click="router.push({ name: 'parent.tutoring.enroll-new' })"
        >
          <NavIcon name="plus" :size="13" />
          Daftar program
        </button>
      </template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-16 text-center text-bimbel-text-mid">
      Memuat…
    </div>

    <template v-else>
      <div class="grid gap-3 lg:grid-cols-3">
        <div class="space-y-3 lg:col-span-2">
          <ParentPrimaryCard
            v-if="heroNext"
            icon="calendar"
            kicker="HARI INI"
            :title="heroNext.topic || (heroNext.group as any)?.name || 'Sesi terjadwal'"
            :subtitle="
              [
                (heroNext.group as any)?.program?.name,
                heroNext.room ? `ruang ${heroNext.room}` : null,
                heroNext.duration_minutes ? `${heroNext.duration_minutes} menit` : null,
                heroNextWhen,
              ].filter(Boolean).join(' · ') || undefined
            "
            :tone="heroNextTone"
            :chip="heroNextCountdown ?? undefined"
          >
            <template #actions>
              <a
                v-if="heroNext.meeting_url"
                :href="heroNext.meeting_url"
                target="_blank"
                rel="noopener"
                class="inline-flex items-center gap-1.5 rounded-lg bg-[#21afe6] px-3.5 py-2 text-[12px] font-bold text-white hover:opacity-90"
              >
                <NavIcon name="link" :size="13" /> Buka Meet
              </a>
              <button
                type="button"
                class="inline-flex items-center gap-1.5 rounded-lg border border-bimbel-border px-3.5 py-2 text-[12px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
                @click="router.push({ name: 'parent.tutoring.sesi' })"
              >
                Lihat jadwal
              </button>
            </template>
          </ParentPrimaryCard>

          <div
            v-else
            class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-6 text-center text-sm text-bimbel-text-mid"
          >
            Tidak ada sesi hari ini.
          </div>

          <ParentRibbon
            v-if="unpaidBills.length > 0"
            icon="wallet"
            label="TAGIHAN AKTIF"
            :value="formatRupiah(unpaidTotal)"
            :hint="unpaidHint"
            tone="warning"
            action-label="Bayar"
            @action="goPayFirstBill"
            @click="goToTagihan"
          />
          <ParentRibbon
            v-else
            icon="check-circle"
            label="TAGIHAN"
            value="Lunas semua"
            hint="Belum ada tagihan aktif bulan ini"
            tone="success"
            clickable
            @click="goToTagihan"
          />
        </div>

        <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
          <h4 class="mb-2 text-[12px] font-bold tracking-tight text-bimbel-text-hi">
            Yang baru
          </h4>
          <div v-if="feed.length === 0" class="py-6 text-center text-[12px] text-bimbel-text-mid">
            Belum ada aktivitas baru.
          </div>
          <ParentActivityRow
            v-for="(e, i) in feed.slice(0, 8)"
            :key="i"
            compact
            :type="e.type"
            :title="e.title"
            :subtitle="e.subtitle"
            :occurred-at="e.occurred_at"
          />
        </aside>
      </div>
    </template>
  </div>
</template>
