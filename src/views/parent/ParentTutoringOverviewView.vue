<!--
  ParentTutoringOverviewView — parent Home.

  Mockup-exact layout: hero + 3-cell KPI strip + "SESI HARI INI" tinted
  card (with conditional red bill ribbon) + "YANG BARU" feed card.

  Reads:
    - TutoringService.getChildOverview(studentId) → upcoming/attendance/bills/progress
    - TutoringService.getStudentFeed(studentId)   → "Yang baru" rows
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import { useChildPicker } from '@/composables/useChildPicker';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringChildOverview,
  TutoringFeedEvent,
} from '@/types/tutoring';

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const auth = useAuthStore();
const { children, activeChildId } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const data = ref<TutoringChildOverview | null>(null);
const feed = ref<TutoringFeedEvent[]>([]);

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  try {
    const [overview, f] = await Promise.all([
      TutoringService.getChildOverview(sid),
      TutoringService
        .getStudentFeed(sid, { limit: 8, sinceDays: 30 })
        .catch(() => [] as TutoringFeedEvent[]),
    ]);
    data.value = overview;
    feed.value = f;
  } finally {
    loading.value = false;
  }
}
onMounted(load);
watch(studentId, load);

// ── Hero copy ─────────────────────────────────────────────────────
const firstName = computed(() => {
  const n = auth.user?.name || 'Wali';
  return n.split(/\s+/)[0];
});
const childCount = computed(() => children.value.length || 1);
const schoolName = computed(() => auth.user?.school_name || 'bimbel');

// ── KPI 1: kehadiran ─────────────────────────────────────────────
function pct(n: number, d: number): number {
  if (!d) return 0;
  return Math.round((n / d) * 100);
}

const attKpi = computed(() => {
  const a = data.value?.attendance;
  if (!a || !a.total_recorded) {
    return { attended: 0, total: 0, meta: 'belum tercatat' };
  }
  const p = pct(a.attended, a.total_recorded);
  return {
    attended: a.attended,
    total: a.total_recorded,
    meta: `${p}% · target ≥80%`,
  };
});

// ── KPI 2: rata-rata grade ───────────────────────────────────────
const scoreKpi = computed(() => {
  const s = data.value?.progress?.summary?.overall;
  const avg = s?.average;
  if (avg == null) return { value: '–', meta: 'belum ada nilai' };
  const fmt = avg
    .toLocaleString('id-ID', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
    .replace('.', ',');
  let meta = `${s?.count ?? 0} nilai tercatat`;
  if (s?.latest != null) {
    const diff = s.latest - avg;
    if (Math.abs(diff) >= 1) {
      meta = diff >= 0
        ? `Naik ${Math.round(diff)} pts`
        : `Turun ${Math.abs(Math.round(diff))} pts`;
    }
  }
  return { value: fmt, meta };
});

// ── KPI 3: bill jatuh tempo ───────────────────────────────────
const unpaidBills = computed(() =>
  (data.value?.bills ?? []).filter((b) =>
    /unpaid|pending|due|overdue|belum/i.test(b.status ?? ''),
  ),
);

const billKpi = computed(() => {
  const list = unpaidBills.value;
  if (list.length === 0) {
    return { value: 'Lunas', meta: 'tidak ada tagihan aktif', unpaid: false };
  }
  const total = list.reduce((s, b) => s + (b.amount ?? 0), 0);
  return {
    value: formatRupiah(total),
    meta: `${list.length} tagihan tertunggak`,
    unpaid: true,
  };
});

// ── SESI HARI INI card ───────────────────────────────────────────
const heroNext = computed(() => data.value?.upcomingSessions?.[0] ?? null);

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

const heroNextTitle = computed(() => {
  const ns = heroNext.value;
  if (!ns) return 'Sesi terjadwal';
  const program = ns.group?.program?.name;
  const group = ns.group?.name;
  if (ns.topic) return ns.topic;
  if (program && group) return `${program} · ${group}`;
  return group || program || 'Sesi terjadwal';
});

const heroNextSub = computed(() => {
  const ns = heroNext.value;
  if (!ns) return '';
  return [
    ns.tutor?.name,
    ns.room ? `ruang ${ns.room}` : null,
    ns.duration_minutes ? `${ns.duration_minutes} menit` : null,
  ]
    .filter(Boolean)
    .join(' · ');
});

// ── Top unpaid bill ribbon ──────────────────────────────────────
const topUnpaid = computed(() => {
  const b = unpaidBills.value[0];
  if (!b) return null;
  const label = b.source_label ?? b.source_type ?? 'Tagihan';
  const amountFmt = b.amount != null ? formatRupiah(b.amount) : '—';
  let dueLine = 'belum dibayar';
  if (b.due_date) {
    const due = new Date(b.due_date);
    if (!Number.isNaN(due.valueOf())) {
      const fmt = due.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
      dueLine = `Jatuh tempo ${fmt} · belum dibayar`;
    }
  }
  return { id: b.id, label, amountFmt, dueLine };
});

// ── Feed icon mapping (no fixed palette tokens, use inline style) ──
type FeedStyle = { background: string; color: string };
function feedIconName(ev: TutoringFeedEvent): string {
  switch (ev.type) {
    case 'note':
    case 'score':
      return 'star';
    case 'announcement':
    case 'announcement_posted':
      return 'megaphone';
    case 'bill':
    case 'bill_paid':
      return 'wallet';
    case 'attendance':
      return 'check-circle';
    case 'session_done':
      return 'calendar';
    case 'new_submission':
      return 'book';
    default:
      return 'bell';
  }
}
function feedIconStyle(ev: TutoringFeedEvent): FeedStyle {
  switch (ev.type) {
    case 'note':
    case 'score':
    case 'new_submission':
      return { background: 'rgba(245, 158, 11, 0.18)', color: '#b45309' };
    case 'announcement':
    case 'announcement_posted':
      return { background: 'rgba(139, 92, 246, 0.18)', color: '#6d28d9' };
    case 'bill':
    case 'bill_paid':
    case 'attendance':
      return { background: 'rgba(16, 185, 129, 0.18)', color: '#047857' };
    case 'session_done':
      return { background: 'rgba(33, 175, 230, 0.18)', color: '#0c447c' };
    default:
      return { background: 'var(--tutoring-border-soft, rgba(0,0,0,0.06))', color: '#475569' };
  }
}

function relTime(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 1) return 'baru';
  if (diffMin < 60) return `${Math.floor(diffMin)} menit lalu`;
  const h = diffMin / 60;
  if (h < 24) return `${Math.floor(h)} jam lalu`;
  const days = Math.floor(h / 24);
  if (days === 1) return 'Kemarin';
  if (days < 7) return `${days} hari lalu`;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

// ── Navigation ───────────────────────────────────────────────────
function goSesi() {
  router.push({ name: 'parent.tutoring.sessions' });
}
function goEnroll() {
  router.push({ name: 'parent.tutoring.enroll-new' });
}
function goPayBill() {
  const id = topUnpaid.value?.id;
  if (!id) return;
  router.push({ name: 'parent.tutoring.pay-bill', params: { billId: id } });
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentHomeHero
      :kicker="t('wali.sekolah.tutoringOverview.kicker')"
      :title="t('wali.sekolah.tutoringOverview.title', { name: firstName })"
      :subtitle="t('wali.sekolah.tutoringOverview.subtitle', { count: childCount, school: schoolName })"
      :stats="[]"
    >
      <template #actions>
        <ParentChildPickerChip />
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-tutoring-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="goEnroll"
        >
          <NavIcon name="plus" :size="13" />{{ t('wali.sekolah.tutoringOverview.enroll') }}
        </button>
      </template>
    </ParentHomeHero>

    <div v-if="loading" class="py-16 text-center text-tutoring-text-mid">{{ t('wali.sekolah.tutoringOverview.loading') }}</div>

    <template v-else>
      <!-- KPI strip (3 cells) -->
      <div class="grid grid-cols-3 gap-2">
        <div class="rounded-lg bg-tutoring-bg p-3">
          <p class="text-[12px] text-tutoring-text-mid">{{ t('wali.sekolah.tutoringOverview.sessionsThisMonth') }}</p>
          <p class="text-[20px] font-extrabold text-tutoring-text-hi leading-none mt-0.5">
            {{ attKpi.attended }}<span class="text-[14px] text-tutoring-text-mid font-normal">/{{ attKpi.total }}</span>
          </p>
          <p class="text-[12px] text-tutoring-text-lo mt-1">{{ attKpi.meta }}</p>
        </div>
        <div class="rounded-lg bg-tutoring-bg p-3">
          <p class="text-[12px] text-tutoring-text-mid">{{ t('wali.sekolah.tutoringOverview.averageScore') }}</p>
          <p class="text-[20px] font-extrabold text-tutoring-text-hi leading-none mt-0.5">{{ scoreKpi.value }}</p>
          <p class="text-[12px] text-tutoring-text-lo mt-1">{{ scoreKpi.meta }}</p>
        </div>
        <div class="rounded-lg bg-tutoring-bg p-3">
          <p class="text-[12px] text-tutoring-text-mid">{{ t('wali.sekolah.tutoringOverview.billsDue') }}</p>
          <p
            class="text-[20px] font-extrabold leading-none mt-0.5"
            :class="billKpi.unpaid ? 'text-red-800' : 'text-tutoring-text-hi'"
          >
            {{ billKpi.value }}
          </p>
          <p class="text-[12px] text-tutoring-text-lo mt-1">{{ billKpi.meta }}</p>
        </div>
      </div>

      <!-- Session hari ini -->
      <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3">{{ t('wali.sekolah.tutoringOverview.todaysSession') }}</p>
      <div
        v-if="heroNext"
        class="rounded-xl bg-tutoring-accent-dim border border-tutoring-accent/30 p-3.5 flex gap-3 items-center"
      >
        <div class="w-10 h-10 rounded-lg bg-tutoring-accent/30 text-tutoring-hero grid place-items-center flex-shrink-0">
          <NavIcon name="school" :size="20" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[12px] text-tutoring-hero tracking-wider font-bold uppercase">{{ heroNextTimeKicker }}</p>
          <p class="text-[14px] font-bold text-tutoring-hero">{{ heroNextTitle }}</p>
          <p class="text-[13px] text-tutoring-hero/80">{{ heroNextSub }}</p>
        </div>
        <button
          type="button"
          class="bg-tutoring-hero text-white px-3 py-2 rounded-lg text-[13px] font-bold flex-shrink-0"
          @click="goSesi"
        >
          {{ t('wali.sekolah.tutoringOverview.viewDetail') }}
        </button>
      </div>
      <div
        v-else
        class="rounded-xl bg-tutoring-bg border border-tutoring-border-soft p-4 text-center text-[13px] text-tutoring-text-mid"
      >
        {{ t('wali.sekolah.tutoringOverview.noSessionToday') }}
      </div>

      <!-- Bill ribbon -->
      <div
        v-if="topUnpaid"
        class="rounded-lg bg-tutoring-red-dim border border-red-300 p-3 mt-2 flex items-center gap-2.5"
      >
        <div class="w-[30px] h-[30px] rounded-lg bg-red-200 text-red-900 grid place-items-center flex-shrink-0">
          <NavIcon name="wallet" :size="16" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-bold text-red-900">{{ topUnpaid.label }} – {{ topUnpaid.amountFmt }}</p>
          <p class="text-[12px] text-red-800">{{ topUnpaid.dueLine }}</p>
        </div>
        <button
          type="button"
          class="bg-red-900 text-white text-[12px] font-bold px-2.5 py-1.5 rounded-md flex-shrink-0"
          @click="goPayBill"
        >
          {{ t('wali.sekolah.tutoringOverview.payNow') }}
        </button>
      </div>

      <!-- YANG BARU feed -->
      <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3">{{ t('wali.sekolah.tutoringOverview.whatsNew') }}</p>
      <div class="rounded-xl bg-tutoring-panel border border-tutoring-border-soft p-3.5">
        <div
          v-for="(ev, i) in feed"
          :key="i"
          class="flex gap-2.5 py-2.5 border-b border-tutoring-border-soft last:border-b-0"
        >
          <div
            class="w-8 h-8 rounded-lg grid place-items-center flex-shrink-0"
            :style="feedIconStyle(ev)"
          >
            <NavIcon :name="feedIconName(ev)" :size="14" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[14px] font-bold text-tutoring-text-hi">{{ ev.title }}</p>
            <p class="text-[12px] text-tutoring-text-mid">{{ ev.subtitle }}</p>
          </div>
          <span class="text-[12px] text-tutoring-text-lo flex-shrink-0">{{ relTime(ev.occurred_at) }}</span>
        </div>
        <p v-if="!feed.length" class="text-center text-[13px] text-tutoring-text-mid py-6">{{ t('wali.sekolah.tutoringOverview.noActivity') }}</p>
      </div>
    </template>
  </div>
</template>
