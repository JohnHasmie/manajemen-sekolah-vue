<!--
  AdminTutoringDashboardView — admin Beranda redesign matching the
  approved mockup admin_web_pages_beranda_groups frame 1:

    1. Navy hero with kicker + greeting + subtitle + 3-stat strip
       (Siswa / Kelompok / Sesi mgg)
    2. Two-column body:
       LEFT col
         a. "Perlu perhatian" accent card (first no-tutor group,
            warning-tone amber stripe)
         b. "Lead panas" amber ribbon with "Lihat leads" CTA
         c. 2-col grid of two panels:
            - Kelompok perlu tutor (rows of groups without tutor)
            - Tagihan tertunggak (top unpaid bills)
       RIGHT col
         - Yang baru feed (TutorActivityRow rows from
           getAdminActivity, limit 6)
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import { formatRupiah } from '@/lib/format';
import type {
  TutoringAdminStats,
  TutoringBill,
  TutoringFeedEvent,
  TutoringGroup,
  TutoringLead,
} from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import TutorPrimaryCard from '@/components/feature/tutoring/TutorPrimaryCard.vue';
import TutorRibbon from '@/components/feature/tutoring/TutorRibbon.vue';
import TutorActivityRow from '@/components/feature/tutoring/TutorActivityRow.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const auth = useAuthStore();

const loading = ref(true);
const stats = ref<TutoringAdminStats | null>(null);
const groups = ref<TutoringGroup[]>([]);
const bills = ref<TutoringBill[]>([]);
const leads = ref<TutoringLead[]>([]);
const feed = ref<TutoringFeedEvent[]>([]);

async function load() {
  loading.value = true;
  try {
    const [s, g, b, l, f] = await Promise.all([
      TutoringService.getAdminStats().catch(() => null),
      TutoringService.getAllGroups().catch(() => [] as TutoringGroup[]),
      TutoringService.getAllBills().catch(() => [] as TutoringBill[]),
      TutoringService.getLeads({ status: 'TRIAL' }).catch(() => [] as TutoringLead[]),
      TutoringService.getAdminActivity({ limit: 8 }).catch(() => [] as TutoringFeedEvent[]),
    ]);
    stats.value = s;
    groups.value = g;
    bills.value = b;
    leads.value = l;
    feed.value = f;
  } finally { loading.value = false; }
}
onMounted(load);

function timeGreeting(): string {
  const h = new Date().getHours();
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 19) return 'Selamat sore';
  return 'Selamat malam';
}
const firstName = computed(() => (auth.user?.name || 'Admin').split(/\s+/)[0]);

const heroStats = computed(() => {
  const s = stats.value;
  const groupsNoTutor = groups.value.filter((g) => !g.tutor_user_id).length;
  return [
    {
      label: 'SISWA',
      value: String(s?.students ?? 0),
      hint: s?.new_enrollments_today ? `+${s.new_enrollments_today} hari ini` : undefined,
    },
    {
      label: 'KELOMPOK',
      value: String(s?.groups ?? 0),
      hint: groupsNoTutor > 0 ? `${groupsNoTutor} perlu perhatian` : undefined,
    },
    {
      label: 'SESI MGG',
      value: String(s?.sessions_this_week ?? 0),
      hint: s?.sessions_today ? `${s.sessions_today} hari ini` : undefined,
    },
  ];
});

const attentionGroup = computed(() => groups.value.find((g) => !g.tutor_user_id) ?? null);
const groupsNoTutor = computed(() => groups.value.filter((g) => !g.tutor_user_id));

const unpaidBills = computed(() =>
  bills.value
    .filter((b) => /unpaid|pending|due|overdue|belum/i.test(b.status ?? ''))
    .sort((a, b) => {
      const da = a.due_date ? new Date(a.due_date).valueOf() : Infinity;
      const db = b.due_date ? new Date(b.due_date).valueOf() : Infinity;
      return da - db;
    }),
);
const unpaidTotal = computed(() => unpaidBills.value.reduce((s, b) => s + (b.amount ?? 0), 0));

const oldestLead = computed(() => {
  const sorted = [...leads.value].sort((a, b) => {
    const da = a.created_at ? new Date(a.created_at).valueOf() : 0;
    const db = b.created_at ? new Date(b.created_at).valueOf() : 0;
    return da - db;
  });
  return sorted[0] ?? null;
});
const leadHintLine = computed(() => {
  const l = oldestLead.value;
  if (!l) return '';
  const days = l.created_at
    ? Math.floor((Date.now() - new Date(l.created_at).valueOf()) / 86_400_000)
    : 0;
  return `terlama ${days} hari lalu · ${l.name}`;
});

function goLeads() { router.push({ name: 'admin.tutoring.leads' }); }
function goBills() { router.push({ name: 'admin.tutoring.bills' }); }
function goGroupDetail(g: TutoringGroup) {
  router.push({ name: 'admin.tutoring.group-detail', params: { groupId: g.id } });
}
function dueLabel(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return `jt ${d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}`;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      :greeting="`${timeGreeting()} · BIMBEL · BERANDA`"
      :title="`Halo, ${firstName}`"
      :subtitle="`${auth.user?.school_name ?? 'Bimbel'} · ${stats?.students ?? 0} siswa aktif`"
      :stats="heroStats"
    />

    <div v-if="loading" class="py-16 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else class="grid gap-4 lg:grid-cols-3">
      <div class="space-y-3 lg:col-span-2">
        <TutorPrimaryCard
          v-if="attentionGroup"
          icon="alert-triangle"
          kicker="PERLU PERHATIAN"
          :title="`Kelompok ${attentionGroup.name} belum punya tutor`"
          subtitle="Klik untuk pilih tutor cadangan agar sesi minggu ini tidak terlewat."
          tone="warning"
        >
          <template #actions>
            <button
              type="button"
              class="inline-flex items-center gap-1.5 rounded-lg bg-amber-500 px-3.5 py-2 text-[13px] font-bold text-white hover:opacity-90"
              @click="goGroupDetail(attentionGroup)"
            >
              <NavIcon name="user-check" :size="13" /> Tugaskan tutor
            </button>
          </template>
        </TutorPrimaryCard>

        <TutorRibbon
          v-if="leads.length > 0"
          icon="sparkles"
          label="LEAD PANAS"
          :value="`${leads.length} calon belum di-follow-up`"
          :hint="leadHintLine || undefined"
          tone="warning"
          clickable
          @click="goLeads"
        />

        <div class="grid gap-3 sm:grid-cols-2">
          <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
            <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Kelompok perlu tutor</h4>
            <div v-if="groupsNoTutor.length === 0" class="py-3 text-center text-[13px] text-bimbel-text-mid">
              Semua kelompok ada tutor.
            </div>
            <button
              v-for="g in groupsNoTutor.slice(0, 4)"
              :key="g.id"
              type="button"
              class="flex w-full items-center gap-2.5 border-b border-bimbel-border-soft py-2 text-left last:border-b-0 hover:bg-bimbel-border-soft/30"
              @click="goGroupDetail(g)"
            >
              <span class="grid h-7 w-7 flex-shrink-0 place-items-center rounded-lg bg-amber-500/15 text-amber-700 dark:text-amber-300">
                <NavIcon name="alert-triangle" :size="13" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-[14px] font-bold text-bimbel-text-hi">{{ g.name }}</p>
                <p class="text-[13px] text-bimbel-text-mid">belum ada tutor</p>
              </div>
            </button>
          </section>

          <section class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
            <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Tagihan tertunggak</h4>
            <div v-if="unpaidBills.length === 0" class="py-3 text-center text-[13px] text-bimbel-text-mid">
              Tidak ada tagihan tertunggak.
            </div>
            <div v-else>
              <div class="flex items-center justify-between border-b border-bimbel-border-soft pb-2 mb-1">
                <span class="text-[13px] text-bimbel-text-mid">Total</span>
                <span class="text-[15px] font-extrabold text-bimbel-text-hi">{{ formatRupiah(unpaidTotal) }}</span>
              </div>
              <button
                v-for="b in unpaidBills.slice(0, 3)"
                :key="b.id"
                type="button"
                class="flex w-full items-center gap-2.5 border-b border-bimbel-border-soft py-2 text-left last:border-b-0 hover:bg-bimbel-border-soft/30"
                @click="goBills"
              >
                <span class="grid h-7 w-7 flex-shrink-0 place-items-center rounded-lg bg-rose-500/15 text-rose-700 dark:text-rose-300">
                  <NavIcon name="wallet" :size="13" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-[14px] font-bold text-bimbel-text-hi">{{ formatRupiah(b.amount ?? 0) }}</p>
                  <p class="truncate text-[13px] text-bimbel-text-mid">
                    {{ [b.student_name, dueLabel(b.due_date)].filter(Boolean).join(' · ') }}
                  </p>
                </div>
              </button>
            </div>
          </section>
        </div>
      </div>

      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5">
        <h4 class="mb-2 text-[15px] font-bold tracking-tight text-bimbel-text-hi">Yang baru</h4>
        <div v-if="feed.length === 0" class="py-6 text-center text-[13px] text-bimbel-text-mid">
          Belum ada aktivitas baru.
        </div>
        <TutorActivityRow
          v-for="(e, i) in feed.slice(0, 6)"
          :key="i"
          compact
          :type="e.type"
          :title="e.title"
          :subtitle="e.subtitle"
          :occurred-at="e.occurred_at"
        />
      </aside>
    </div>
  </div>
</template>
