<!--
  AdminTutoringDashboardView — admin Home redesign matching the
  approved mockup admin_web_pages_beranda_groups frame 1:

    1. Navy hero with kicker + greeting + subtitle + 3-stat strip
       (Student / Group / Session mgg)
    2. Two-column body:
       LEFT col
         a. "Perlu perhatian" accent card (first no-tutor group,
            warning-tone amber stripe)
         b. "Lead panas" amber ribbon with "Lihat leads" CTA
         c. 2-col grid of two panels:
            - Group perlu tutor (rows of groups without tutor)
            - Bill tertunggak (top unpaid bills)
       RIGHT col
         - Yang baru feed (TutorActivityRow rows from
           getAdminActivity, limit 6)
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
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

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import TutorPrimaryCard from '@/components/feature/tutoring/TutorPrimaryCard.vue';
import TutorRibbon from '@/components/feature/tutoring/TutorRibbon.vue';
import TutorActivityRow from '@/components/feature/tutoring/TutorActivityRow.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const auth = useAuthStore();
const { t } = useI18n();

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
  if (h < 11) return t('admin.bimbel.dashboard.greeting_morning');
  if (h < 15) return t('admin.bimbel.dashboard.greeting_afternoon');
  if (h < 19) return t('admin.bimbel.dashboard.greeting_evening');
  return t('admin.bimbel.dashboard.greeting_night');
}
const firstName = computed(() => (auth.user?.name || 'Admin').split(/\s+/)[0]);

const heroStats = computed(() => {
  const s = stats.value;
  const groupsNoTutor = groups.value.filter((g) => !g.tutor_user_id).length;
  return [
    {
      label: t('admin.bimbel.dashboard.stat_students'),
      value: String(s?.students ?? 0),
      hint: s?.new_enrollments_today ? t('admin.bimbel.dashboard.stat_today_suffix', { count: s.new_enrollments_today }) : undefined,
    },
    {
      label: t('admin.bimbel.dashboard.stat_groups'),
      value: String(s?.groups ?? 0),
      hint: groupsNoTutor > 0 ? t('admin.bimbel.dashboard.stat_needs_attention', { count: groupsNoTutor }) : undefined,
    },
    {
      label: t('admin.bimbel.dashboard.stat_sessions_week'),
      value: String(s?.sessions_this_week ?? 0),
      hint: s?.sessions_today ? t('admin.bimbel.dashboard.stat_today_plain', { count: s.sessions_today }) : undefined,
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
  return t('admin.bimbel.dashboard.hot_lead_hint', { days, name: l.name });
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
  return t('admin.bimbel.dashboard.due_short', { date: d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="`${timeGreeting()} · ${t('admin.bimbel.dashboard.hero_kicker')}`"
      :title="t('admin.bimbel.dashboard.hero_title', { name: firstName })"
      :subtitle="t('admin.bimbel.dashboard.hero_subtitle', { school: auth.user?.school_name ?? 'Bimbel', count: stats?.students ?? 0 })"
      :stats="heroStats"
    />

    <div v-if="loading" class="py-16 text-center text-tutoring-text-mid">{{ t('admin.bimbel.dashboard.loading') }}</div>

    <div v-else class="grid gap-4 lg:grid-cols-3">
      <div class="space-y-3 lg:col-span-2">
        <TutorPrimaryCard
          v-if="attentionGroup"
          icon="alert-triangle"
          :kicker="t('admin.bimbel.dashboard.attention_kicker')"
          :title="t('admin.bimbel.dashboard.attention_title', { name: attentionGroup.name })"
          :subtitle="t('admin.bimbel.dashboard.attention_subtitle')"
          tone="warning"
        >
          <template #actions>
            <button
              type="button"
              class="inline-flex items-center gap-1.5 rounded-lg bg-amber-500 px-3.5 py-2 text-[14px] font-bold text-white hover:opacity-90"
              @click="goGroupDetail(attentionGroup)"
            >
              <NavIcon name="user-check" :size="13" /> {{ t('admin.bimbel.dashboard.assign_tutor') }}
            </button>
          </template>
        </TutorPrimaryCard>

        <TutorRibbon
          v-if="leads.length > 0"
          icon="sparkles"
          :label="t('admin.bimbel.dashboard.hot_lead_label')"
          :value="t('admin.bimbel.dashboard.hot_lead_value', { count: leads.length })"
          :hint="leadHintLine || undefined"
          tone="warning"
          clickable
          @click="goLeads"
        />

        <div class="grid gap-3 sm:grid-cols-2">
          <section class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
            <h4 class="mb-2 text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ t('admin.bimbel.dashboard.groups_needing_tutor') }}</h4>
            <div v-if="groupsNoTutor.length === 0" class="py-3 text-center text-[14px] text-tutoring-text-mid">
              {{ t('admin.bimbel.dashboard.all_groups_have_tutor') }}
            </div>
            <button
              v-for="g in groupsNoTutor.slice(0, 4)"
              :key="g.id"
              type="button"
              class="flex w-full items-center gap-2.5 border-b border-tutoring-border-soft py-2 text-left last:border-b-0 hover:bg-tutoring-border-soft/30"
              @click="goGroupDetail(g)"
            >
              <span class="grid h-7 w-7 flex-shrink-0 place-items-center rounded-lg bg-amber-500/15 text-amber-700 dark:text-amber-300">
                <NavIcon name="alert-triangle" :size="13" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-[14px] font-bold text-tutoring-text-hi">{{ g.name }}</p>
                <p class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.dashboard.no_tutor') }}</p>
              </div>
            </button>
          </section>

          <section class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
            <h4 class="mb-2 text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ t('admin.bimbel.dashboard.unpaid_bills') }}</h4>
            <div v-if="unpaidBills.length === 0" class="py-3 text-center text-[14px] text-tutoring-text-mid">
              {{ t('admin.bimbel.dashboard.no_unpaid_bills') }}
            </div>
            <div v-else>
              <div class="flex items-center justify-between border-b border-tutoring-border-soft pb-2 mb-1">
                <span class="text-[14px] text-tutoring-text-mid">{{ t('admin.bimbel.dashboard.total') }}</span>
                <span class="text-[15px] font-extrabold text-tutoring-text-hi">{{ formatRupiah(unpaidTotal) }}</span>
              </div>
              <button
                v-for="b in unpaidBills.slice(0, 3)"
                :key="b.id"
                type="button"
                class="flex w-full items-center gap-2.5 border-b border-tutoring-border-soft py-2 text-left last:border-b-0 hover:bg-tutoring-border-soft/30"
                @click="goBills"
              >
                <span class="grid h-7 w-7 flex-shrink-0 place-items-center rounded-lg bg-rose-500/15 text-rose-700 dark:text-rose-300">
                  <NavIcon name="wallet" :size="13" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-[14px] font-bold text-tutoring-text-hi">{{ formatRupiah(b.amount ?? 0) }}</p>
                  <p class="truncate text-[14px] text-tutoring-text-mid">
                    {{ [b.student_name, dueLabel(b.due_date)].filter(Boolean).join(' · ') }}
                  </p>
                </div>
              </button>
            </div>
          </section>
        </div>
      </div>

      <aside class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
        <h4 class="mb-2 text-[15px] font-bold tracking-tight text-tutoring-text-hi">{{ t('admin.bimbel.dashboard.whats_new') }}</h4>
        <div v-if="feed.length === 0" class="py-6 text-center text-[14px] text-tutoring-text-mid">
          {{ t('admin.bimbel.dashboard.no_new_activity') }}
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
