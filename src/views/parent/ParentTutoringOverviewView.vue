<!--
  ParentTutoringOverviewView — wali Beranda.

  Redesigned layout (approved mockup):

    Hero  (azure, kicker · greeting · child-picker + primary CTA)
    Body sections:
      1. KPI row (3 cells: sesi hadir, rata-rata nilai, tagihan)
      2. Section "SESI HARI INI" + accent-tinted primary card
      3. Conditional tagihan ribbon (red) when top unpaid bill exists
      4. Section "YANG BARU" + feed rows

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
import ParentActivityRow from '@/components/feature/tutoring/ParentActivityRow.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const { children, activeChildId, activeChild } = useChildPicker();

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

const childCount = computed(() => children.value.length || 1);

const schoolName = computed(() => auth.user?.school_name || 'bimbel');

// ── KPI strip (4 cells) ──────────────────────────────────────────
const heroStats = computed(() => {
  const d = data.value;
  const upcoming = d?.upcomingSessions ?? [];
  const sessionsThisWeek = upcoming.filter((s) => {
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
      value: String(sessionsThisWeek),
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

const heroNextTimeKicker = computed(() => {
  const ns = heroNext.value;
  if (!ns?.scheduled_at) return '';
  const d = new Date(ns.scheduled_at);
  if (Number.isNaN(d.valueOf())) return '';
  const time = d.toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
  const isToday = d.toDateString() === new Date().toDateString();
  const day = isToday
    ? 'HARI INI'
    : d
        .toLocaleDateString('id-ID', { weekday: 'short', day: 'numeric', month: 'short' })
        .toUpperCase();
  return `${day} · ${time}`;
});

const heroNextSubtitle = computed(() => {
  const ns = heroNext.value;
  if (!ns) return '';
  return [
    (ns.group as any)?.program?.name,
    ns.room ? `ruang ${ns.room}` : null,
    ns.duration_minutes ? `${ns.duration_minutes} menit` : null,
    heroNextCountdown.value,
  ]
    .filter(Boolean)
    .join(' · ');
});

// ── KPIs for the 3-col strip on the body ──────────────────────────
function pct(n: number, d: number): number {
  if (!d) return 0;
  return Math.round((n / d) * 100);
}

const attendanceKpi = computed(() => {
  const a = data.value?.attendance;
  if (!a || !a.total_recorded) {
    return {
      value: '–',
      meta: 'belum tercatat',
    };
  }
  const p = pct(a.attended, a.total_recorded);
  return {
    value: `${a.attended}/${a.total_recorded}`,
    meta: `${p}% · target ≥80%`,
  };
});

const scoreKpi = computed(() => {
  const summary = data.value?.progress?.summary?.overall;
  const avg = summary?.average;
  if (avg == null) {
    return { value: '–', meta: 'belum ada nilai' };
  }
  const fmt = avg
    .toLocaleString('id-ID', { maximumFractionDigits: 1, minimumFractionDigits: 1 })
    .replace('.', ',');
  let meta = `${summary?.count ?? 0} nilai tercatat`;
  if (summary?.best != null && summary?.latest != null) {
    const diff = summary.latest - avg;
    if (Math.abs(diff) >= 1) {
      meta = diff >= 0
        ? `Naik ${Math.round(diff)} pts`
        : `Turun ${Math.abs(Math.round(diff))} pts`;
    }
  }
  return { value: fmt, meta };
});

// ── Tagihan ribbon ───────────────────────────────────────────────
const unpaidBills = computed(() =>
  (data.value?.bills ?? []).filter((b) =>
    /unpaid|pending|due|overdue|belum/i.test(b.status ?? ''),
  ),
);

const billKpi = computed(() => {
  const list = unpaidBills.value;
  if (list.length === 0) {
    return { value: 'Lunas', meta: 'tidak ada tagihan aktif', urgent: false };
  }
  const total = list.reduce((s, b) => s + (b.amount ?? 0), 0);
  const first = list[0];
  let meta = first.source_label ?? first.source_type ?? 'SPP';
  if (first.due_date) {
    const due = new Date(first.due_date);
    if (!Number.isNaN(due.valueOf())) {
      const days = Math.ceil((due.valueOf() - Date.now()) / 86_400_000);
      const dueWord = days < 0
        ? `terlewat ${Math.abs(days)} hari`
        : days === 0
          ? 'jatuh tempo hari ini'
          : `${days} hari lagi`;
      meta = `${meta} · ${dueWord}`;
    }
  }
  return { value: formatRupiah(total), meta, urgent: true };
});

const topUnpaidBill = computed(() => unpaidBills.value[0] ?? null);

const topBillLabel = computed(() => {
  const b = topUnpaidBill.value;
  if (!b) return '';
  const src = b.source_label ?? b.source_type ?? 'Tagihan';
  const amt = b.amount != null ? formatRupiah(b.amount) : '—';
  return `${src} – ${amt}`;
});

const topBillHint = computed(() => {
  const b = topUnpaidBill.value;
  if (!b) return '';
  if (!b.due_date) return 'belum dibayar';
  const due = new Date(b.due_date);
  if (Number.isNaN(due.valueOf())) return 'belum dibayar';
  const label = due.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
  return `Jatuh tempo ${label} · belum dibayar`;
});

function goPayFirstBill() {
  const first = unpaidBills.value[0];
  if (!first) return;
  router.push({ name: 'parent.tutoring.pay-bill', params: { billId: first.id } });
}

function goToTagihan() {
  router.push({ name: 'parent.tutoring.bills' });
}

function goToSessions() {
  router.push({ name: 'parent.tutoring.sessions' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · WALI"
      :title="`Halo, Pak ${firstName}`"
      :subtitle="`Pantau perkembangan ${childCount} anak di ${schoolName}`"
      :stats="heroStats"
    >
      <template #actions>
        <ParentChildPickerChip />
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[13px] font-bold hover:bg-white/95"
          @click="router.push({ name: 'parent.tutoring.enroll-new' })"
        >
          <NavIcon name="plus" :size="13" />
          Daftar program
        </button>
      </template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-16 text-center text-bimbel-text-mid">
      Memuat… {{ timeGreeting() }}, {{ childName }}
    </div>

    <template v-else>
      <!-- 1. KPI row ------------------------------------------------ -->
      <div class="grid grid-cols-1 gap-2.5 sm:grid-cols-3">
        <div class="rounded-lg bg-bimbel-bg p-3">
          <p class="text-[11px] text-bimbel-text-mid">Sesi hadir bulan ini</p>
          <p class="text-[20px] font-extrabold text-bimbel-text-hi">
            {{ attendanceKpi.value }}
          </p>
          <p class="text-[11px] text-bimbel-text-lo">{{ attendanceKpi.meta }}</p>
        </div>
        <div class="rounded-lg bg-bimbel-bg p-3">
          <p class="text-[11px] text-bimbel-text-mid">Rata-rata nilai</p>
          <p class="text-[20px] font-extrabold text-bimbel-text-hi">
            {{ scoreKpi.value }}
          </p>
          <p class="text-[11px] text-bimbel-text-lo">{{ scoreKpi.meta }}</p>
        </div>
        <div class="rounded-lg bg-bimbel-bg p-3">
          <p class="text-[11px] text-bimbel-text-mid">Tagihan jatuh tempo</p>
          <p
            class="text-[20px] font-extrabold"
            :class="billKpi.urgent ? 'text-red-700' : 'text-bimbel-text-hi'"
          >
            {{ billKpi.value }}
          </p>
          <p class="text-[11px] text-bimbel-text-lo">{{ billKpi.meta }}</p>
        </div>
      </div>

      <!-- 2. SESI HARI INI ----------------------------------------- -->
      <div>
        <h3
          class="mb-2 text-[11px] font-bold uppercase tracking-[0.1em] text-bimbel-text-lo"
        >
          Sesi hari ini
        </h3>

        <div
          v-if="heroNext"
          class="flex items-center gap-3 rounded-xl border border-bimbel-accent/30 bg-bimbel-accent-dim p-4"
        >
          <div
            class="grid h-10 w-10 flex-shrink-0 place-items-center rounded-lg bg-bimbel-accent/30 text-bimbel-hero"
          >
            <NavIcon name="calendar" :size="18" />
          </div>
          <div class="min-w-0 flex-1">
            <p
              class="text-[11px] font-bold uppercase tracking-wider text-bimbel-hero"
            >
              {{ heroNextTimeKicker }}
            </p>
            <p class="truncate text-[14px] font-bold text-bimbel-hero">
              {{ heroNext.topic || (heroNext.group as any)?.name || 'Sesi terjadwal' }}
            </p>
            <p v-if="heroNextSubtitle" class="truncate text-[12px] text-bimbel-hero/80">
              {{ heroNextSubtitle }}
            </p>
          </div>
          <button
            type="button"
            class="rounded-lg bg-bimbel-hero px-3 py-2 text-[12px] font-bold text-white hover:opacity-90"
            @click="goToSessions"
          >
            Lihat detail
          </button>
        </div>

        <div
          v-else
          class="rounded-xl border border-bimbel-border-soft bg-bimbel-panel p-4 text-center text-[13px] text-bimbel-text-mid"
        >
          Tidak ada sesi hari ini.
        </div>

        <!-- 3. Tagihan ribbon (conditional) ------------------------ -->
        <div
          v-if="topUnpaidBill"
          class="mt-2 flex items-center gap-2.5 rounded-lg border border-red-300 bg-bimbel-red-dim p-3"
        >
          <div
            class="grid h-[30px] w-[30px] flex-shrink-0 place-items-center rounded-lg bg-red-200 text-red-900"
          >
            <NavIcon name="wallet" :size="14" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="truncate text-[12px] font-bold text-red-900">
              {{ topBillLabel }}
            </p>
            <p class="truncate text-[11px] text-red-800">
              {{ topBillHint }}
            </p>
          </div>
          <button
            type="button"
            class="rounded-md bg-red-900 px-2.5 py-1.5 text-[11px] font-bold text-white hover:opacity-90"
            @click="goPayFirstBill"
          >
            Bayar sekarang
          </button>
        </div>
      </div>

      <!-- 4. YANG BARU -------------------------------------------- -->
      <div>
        <h3
          class="mb-2 text-[11px] font-bold uppercase tracking-[0.1em] text-bimbel-text-lo"
        >
          Yang baru
        </h3>
        <div
          class="rounded-xl border border-bimbel-border-soft bg-bimbel-panel px-3"
        >
          <div
            v-if="feed.length === 0"
            class="py-6 text-center text-[13px] text-bimbel-text-mid"
          >
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
        </div>
      </div>
    </template>
  </div>
</template>
