<!--
  PersonnelCardManagerView.vue — admin "Kartu QR Personal" hub.

  Three tabs sharing the same page shell:

    ┌─────────────────────────────────────────────────────────────┐
    │  BrandPageHeader "Kartu QR Personal"                        │
    ├─────────────────────────────────────────────────────────────┤
    │  [ Guru ] [ Staf ] [ Siswa ]     (URL: ?tab=guru|staf|siswa)│
    └─────────────────────────────────────────────────────────────┘
       │           │           │
       │           │           └─ StudentCardsPanel  (backend MR !484)
       │           └─── PersonnelCardsPanel role=staff
       └─────────────── PersonnelCardsPanel role=teacher

  Guru + Staf keep the ORIGINAL account-based path — they read from
  `/attendance/personnel-cards/list`, key selection on `user_id`, and
  post issue/revoke/export against the personnel endpoints.

  Siswa is the NEW account-less path (backend MR !484) — students never
  have a `users` account, so it reads `/attendance/student-cards` keyed
  on `student_id`. Rendered by `StudentCardsPanel.vue` (kept in a child
  component to keep this file focused on tab wiring). The panel gates
  itself on the `issue_student_cards` opt-in and renders a warm,
  actionable empty state (one-click enable) when the flag is off — that
  was the "sudah menginput siswa tapi tab kosong" bug on prod.

  The tab is URL-driven (`?tab=`) so deep-links from Data Siswa land
  directly on the Siswa panel without a click.
-->
<script setup lang="ts">
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PersonnelCardsPanel from './widgets/PersonnelCardsPanel.vue';
import StudentCardsPanel from './widgets/StudentCardsPanel.vue';

type TabKey = 'guru' | 'staf' | 'siswa';

const route = useRoute();
const router = useRouter();

interface TabDef {
  key: TabKey;
  label: string;
  icon: string;
}

// Kicker/title stay identical to the pre-rebuild copy so bookmarks +
// muscle memory don't feel a naming change; only the body layout is
// reworked.
const TABS: TabDef[] = [
  { key: 'guru', label: 'Guru', icon: 'user-check' },
  { key: 'staf', label: 'Staf', icon: 'briefcase' },
  { key: 'siswa', label: 'Siswa', icon: 'users' },
];

/**
 * Resolve the active tab from `?tab=` on the URL. Any unknown value
 * (missing, typo, legacy) collapses to `guru` — the safest default,
 * that being the tab most schools will land on first.
 */
const activeTab = computed<TabKey>(() => {
  const raw = String(route.query.tab ?? '').toLowerCase();
  if (raw === 'staf' || raw === 'siswa') return raw;
  return 'guru';
});

/**
 * Tab click — mirror to the URL so a refresh / bookmark reproduces the
 * exact tab the user was viewing. `router.replace` (not push) so the
 * browser Back button doesn't tour the tab history — it jumps back to
 * wherever the admin came from before landing on this page.
 */
function goTab(key: TabKey) {
  if (activeTab.value === key) return;
  const next = { ...route.query, tab: key };
  router.replace({ query: next });
}

/**
 * On mount / after a router transition, normalise the URL if `?tab=`
 * was omitted. Keeps the query string self-documenting so a link the
 * admin copies out of the address bar always tells the recipient which
 * tab they'll land on.
 */
watch(
  () => route.query.tab,
  (val) => {
    if (val == null) {
      const next = { ...route.query, tab: activeTab.value };
      router.replace({ query: next });
    }
  },
  { immediate: true },
);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Presensi QR"
      title="Kartu QR Personal"
      meta="Terbitkan, cabut, dan cetak kartu QR untuk guru, staf, dan siswa."
    />

    <!-- Tab nav — same treatment as AdminAnnouncementsHub so the two
         hubs feel consistent. `flex-1` on each button so the trio
         stretches evenly across the container regardless of label
         length; overflow-x-auto for tiny mobile widths where the
         labels still push past. -->
    <nav
      class="bg-white border border-slate-200 rounded-2xl p-1.5 flex items-center gap-1 overflow-x-auto"
      role="tablist"
      aria-label="Tab kartu QR personal"
    >
      <button
        v-for="tab in TABS"
        :key="tab.key"
        type="button"
        role="tab"
        :aria-selected="activeTab === tab.key"
        class="flex-1 inline-flex items-center justify-center gap-2 px-3 py-2 rounded-xl text-[12px] font-bold transition-all whitespace-nowrap"
        :class="
          activeTab === tab.key
            ? 'bg-role-admin text-white shadow'
            : 'text-slate-500 hover:text-slate-900 hover:bg-slate-50'
        "
        @click="goTab(tab.key)"
      >
        <NavIcon :name="tab.icon" :size="13" />
        {{ tab.label }}
      </button>
    </nav>

    <!-- Body — one panel per tab. Keyed on the tab so state (selection,
         filter, current page) resets when the admin switches tabs — a
         "Guru" selection carrying over into "Staf" would be nonsense.
         Personnel panel handles both teacher + staff by passing the
         role prop; student panel has its own dedicated shape. -->
    <PersonnelCardsPanel
      v-if="activeTab === 'guru'"
      key="guru"
      role="teacher"
    />
    <PersonnelCardsPanel
      v-else-if="activeTab === 'staf'"
      key="staf"
      role="staff"
    />
    <StudentCardsPanel v-else key="siswa" />
  </div>
</template>
