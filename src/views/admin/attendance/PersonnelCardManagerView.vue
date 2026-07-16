<!--
  PersonnelCardManagerView.vue — admin batch-issue + revoke + PDF export
  for personnel QR cards. The source of truth is the dedicated
  `/attendance/personnel-cards/list` endpoint (backend api!234). Each
  row carries a `user_id` (canonical selection key — the issue endpoint
  keys on `users_schools.user_id`, NOT `teachers.id`) plus an inline
  `card` summary that tells us whether the personnel already has an
  active card.

  History: earlier iterations sourced rows from `TeacherService.list`
  as a fallback and used `teachers.id` in the selection set. That broke
  both issue + PDF export — the backend rejected every id as
  `not_a_school_member` because it never mapped teacher-id → user-id.
  See mobile!392 (documented TODO) + this fix.

  Actions:
    - Terbitkan Kartu (N) → POST /personnel-cards/issue { user_ids }
    - Unduh PDF          → GET  /personnel-cards/export.pdf?user_ids[]=…
    - Cabut (per row)    → DELETE /personnel-cards/{card.id}
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { AttendanceQrService } from '@/services/attendance-qr.service';
import { useToast } from '@/composables/useToast';
import type {
  PersonnelCardIssueResult,
  PersonnelCardListRow,
  PersonnelRole,
} from '@/types/attendance-qr';
import type { Pagination } from '@/types/api';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Spinner from '@/components/ui/Spinner.vue';
import EmptyState from '@/components/data/EmptyState.vue';
import SkeletonList from '@/components/data/SkeletonList.vue';
import PaginationWidget from '@/components/data/Pagination.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const rows = ref<PersonnelCardListRow[]>([]);
const pagination = ref<Pagination | null>(null);
/** Set of selected user_id values — the backend keys on user_id. */
const selected = ref<Set<string>>(new Set());
/** Free-text search box over name + email + NIP (server-side). */
const searchQuery = ref('');
/** Role filter — matches backend `role=teacher|staff|student|all`. */
const roleFilter = ref<'all' | PersonnelRole>('all');
/** hasCard filter — 'all' = both, 'yes' = has-card, 'no' = no-card. */
const hasCardFilter = ref<'all' | 'yes' | 'no'>('all');
const currentPage = ref(1);
const perPage = 20;

const issuing = ref(false);
const exporting = ref(false);
/** Per-row revoke spinner state, keyed by user_id. */
const revoking = ref<Set<string>>(new Set());

/**
 * Fetch a page of personnel with their current card state. Called on
 * mount, whenever the filters change, and after every mutation
 * (issue / revoke) so the "Sudah punya kartu?" column stays truthful.
 */
async function load() {
  loading.value = true;
  try {
    const res = await AttendanceQrService.listPersonnelCards({
      role: roleFilter.value,
      has_card:
        hasCardFilter.value === 'all'
          ? undefined
          : hasCardFilter.value === 'yes',
      search: searchQuery.value.trim() || undefined,
      page: currentPage.value,
      per_page: perPage,
    });
    rows.value = res.items;
    pagination.value = res.pagination;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.loadFail'),
    );
  } finally {
    loading.value = false;
  }
}

/**
 * Debounced re-fetch on search change. A tiny 250 ms window avoids
 * firing one request per keystroke while still feeling live.
 */
let searchTimer: number | null = null;
function scheduleSearchReload() {
  if (searchTimer !== null) window.clearTimeout(searchTimer);
  searchTimer = window.setTimeout(() => {
    currentPage.value = 1;
    void load();
  }, 250);
}

watch(searchQuery, scheduleSearchReload);
watch([roleFilter, hasCardFilter], () => {
  currentPage.value = 1;
  void load();
});

function onPageChange(page: number) {
  currentPage.value = page;
  void load();
}

function toggleRow(row: PersonnelCardListRow) {
  const next = new Set(selected.value);
  if (next.has(row.user_id)) next.delete(row.user_id);
  else next.add(row.user_id);
  selected.value = next;
}

function toggleAllOnPage() {
  const next = new Set(selected.value);
  const allSelected = rows.value.every((r) => next.has(r.user_id));
  for (const r of rows.value) {
    if (allSelected) next.delete(r.user_id);
    else next.add(r.user_id);
  }
  selected.value = next;
}

const selectedCount = computed(() => selected.value.size);
const allOnPageSelected = computed(
  () =>
    rows.value.length > 0 &&
    rows.value.every((r) => selected.value.has(r.user_id)),
);

/**
 * Build a human summary of an issue-response so the toast tells the
 * admin how many cards landed vs were skipped. Mirrors the phrasing
 * from the earlier revision — no behavioural change.
 */
function summariseResults(results: PersonnelCardIssueResult[]): string {
  const ok = results.filter((r) => r.status === 'ok').length;
  const skipped = results.filter((r) => r.status === 'skipped');
  const errored = results.filter((r) => r.status === 'error');
  const parts: string[] = [t('admin.attendance.cards.issued', { count: ok })];
  if (skipped.length > 0) {
    parts.push(t('admin.attendance.cards.skipped', { count: skipped.length }));
  }
  if (errored.length > 0) {
    parts.push(t('admin.attendance.cards.errored', { count: errored.length }));
  }
  return parts.join(' · ');
}

async function issueSelected() {
  if (selected.value.size === 0) return;
  issuing.value = true;
  try {
    const ids = Array.from(selected.value);
    const results = await AttendanceQrService.issuePersonnelCards(ids);
    toast.success(summariseResults(results));
    selected.value = new Set();
    // Refresh so the "Sudah punya kartu?" column reflects the new state.
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.issueFail'),
    );
  } finally {
    issuing.value = false;
  }
}

async function exportSelectedPdf() {
  if (selected.value.size === 0) return;
  exporting.value = true;
  try {
    const ids = Array.from(selected.value);
    const ts = new Date().toISOString().slice(0, 10);
    await AttendanceQrService.exportPersonnelCardsPdf(
      ids,
      `kartu-qr-personel-${ts}.pdf`,
    );
    toast.success(t('admin.attendance.cards.exported'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.exportFail'),
    );
  } finally {
    exporting.value = false;
  }
}

/**
 * Single-row revoke — uses `row.card.id` directly (the card row's
 * primary key), which is much cleaner than resolving via user_id at
 * the backend. `card` is guaranteed non-null when the button is
 * clickable (the template hides Cabut when the row has no card).
 */
async function revokeRow(row: PersonnelCardListRow) {
  if (!row.card) return;
  const cardId = row.card.id;
  const userId = row.user_id;
  if (revoking.value.has(userId)) return;
  const next = new Set(revoking.value);
  next.add(userId);
  revoking.value = next;
  try {
    await AttendanceQrService.revokePersonnelCard(cardId);
    toast.success(
      t('admin.attendance.cards.revoked', { name: row.user_name }),
    );
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.revokeFail'),
    );
  } finally {
    const after = new Set(revoking.value);
    after.delete(userId);
    revoking.value = after;
  }
}

/** Localized label for a personnel role — the tiny badge in the table. */
function roleLabel(role: PersonnelRole): string {
  switch (role) {
    case 'staff':
      return t('admin.attendance.cards.roleStaff');
    case 'student':
      return t('admin.attendance.cards.roleStudent');
    case 'teacher':
    default:
      return t('admin.attendance.cards.roleTeacher');
  }
}

onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.attendance.cards.kicker')"
      :title="t('admin.attendance.cards.title')"
      :meta="t('admin.attendance.cards.meta')"
    >
      <div class="flex flex-wrap items-center gap-2">
        <!--
          On-hero action buttons. The default <Button variant="secondary">
          uses a slate-300 border + slate-700 text, which vanishes on the
          admin-navy gradient. We reach for the app-wide "chip on dark
          hero" pattern (bg-white/15 + text-white + hover:bg-white/25),
          which is what AdminClassActivityView uses for its Export CSV
          button on the same gradient. Keeps parity across admin heros
          without introducing a new Button variant just for this page.
        -->
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 text-white px-md py-sm text-sm font-semibold border border-white/30 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          :disabled="selectedCount === 0 || exporting"
          @click="exportSelectedPdf"
        >
          <Spinner v-if="exporting" size="sm" />
          <NavIcon v-else name="download" :size="16" />
          {{ t('admin.attendance.cards.exportPdf') }}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl bg-white text-slate-900 hover:bg-white/90 px-md py-sm text-sm font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          :disabled="selectedCount === 0 || issuing"
          @click="issueSelected"
        >
          <Spinner v-if="issuing" size="sm" />
          <NavIcon v-else name="id-card" :size="16" />
          {{ t('admin.attendance.cards.issue', { count: selectedCount }) }}
        </button>
      </div>
    </BrandPageHeader>

    <!-- Filter row: search + role dropdown + has-card dropdown. All
         server-side; changing any triggers a re-fetch (debounced for
         the text box, immediate for the selects). The master checkbox
         operates on the currently-loaded page. -->
    <div class="flex flex-wrap items-center gap-2">
      <div class="relative flex-1 min-w-[220px]">
        <input
          v-model="searchQuery"
          type="search"
          :placeholder="t('admin.attendance.cards.searchPh')"
          class="w-full rounded-xl border border-slate-200 bg-white pl-9 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/30 focus:border-role-admin"
        />
        <NavIcon
          name="search"
          :size="14"
          class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
        />
      </div>
      <select
        v-model="roleFilter"
        class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/30 focus:border-role-admin"
      >
        <option value="all">{{ t('admin.attendance.cards.roleAll') }}</option>
        <option value="teacher">
          {{ t('admin.attendance.cards.roleTeacher') }}
        </option>
        <option value="staff">
          {{ t('admin.attendance.cards.roleStaff') }}
        </option>
        <option value="student">
          {{ t('admin.attendance.cards.roleStudent') }}
        </option>
      </select>
      <select
        v-model="hasCardFilter"
        class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/30 focus:border-role-admin"
      >
        <option value="all">
          {{ t('admin.attendance.cards.hasCardAll') }}
        </option>
        <option value="yes">
          {{ t('admin.attendance.cards.hasCardYes') }}
        </option>
        <option value="no">{{ t('admin.attendance.cards.hasCardNo') }}</option>
      </select>
    </div>

    <!-- Loading shell — reuses the shared SkeletonList (name row +
         qr thumb column), same look-and-feel as every other admin
         list surface after the skeleton sweep. -->
    <SkeletonList v-if="loading" :rows="5" />

    <EmptyState
      v-else-if="rows.length === 0"
      :title="t('admin.attendance.cards.empty')"
      :description="t('admin.attendance.cards.emptyHint')"
    />

    <div
      v-else
      class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-xs uppercase tracking-wider text-slate-500">
          <tr>
            <th class="px-3 py-2.5 text-left w-10">
              <input
                type="checkbox"
                :checked="allOnPageSelected"
                class="h-4 w-4 rounded text-role-admin accent-role-admin"
                :aria-label="t('admin.attendance.cards.selectAll')"
                @change="toggleAllOnPage"
              />
            </th>
            <th class="px-3 py-2.5 text-left font-semibold">
              {{ t('admin.attendance.cards.colName') }}
            </th>
            <th class="px-3 py-2.5 text-left font-semibold">
              {{ t('admin.attendance.cards.colRole') }}
            </th>
            <th class="px-3 py-2.5 text-left font-semibold">
              {{ t('admin.attendance.cards.colEmail') }}
            </th>
            <th class="px-3 py-2.5 text-left font-semibold w-40">
              {{ t('admin.attendance.cards.colHasCard') }}
            </th>
            <th class="px-3 py-2.5 text-right font-semibold w-32">
              {{ t('admin.attendance.cards.colActions') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.user_id"
            class="border-t border-slate-100 hover:bg-slate-50 cursor-pointer"
            @click="toggleRow(row)"
          >
            <td class="px-3 py-2.5" @click.stop>
              <input
                type="checkbox"
                :checked="selected.has(row.user_id)"
                class="h-4 w-4 rounded text-role-admin accent-role-admin"
                :aria-label="t('admin.attendance.cards.selectRow')"
                @change="toggleRow(row)"
              />
            </td>
            <td class="px-3 py-2.5">
              <div class="font-semibold text-slate-900">
                {{ row.user_name || '–' }}
              </div>
            </td>
            <td class="px-3 py-2.5 text-slate-600">
              {{ roleLabel(row.role) }}
            </td>
            <td class="px-3 py-2.5 text-slate-600">
              {{ row.user_email || '–' }}
            </td>
            <td class="px-3 py-2.5">
              <!-- "Sudah punya kartu?" pill: green when a card is active,
                   muted slate when not. Reads at a glance so the admin
                   doesn't have to hunt the Aksi column. -->
              <span
                v-if="row.card"
                class="inline-flex items-center gap-1 rounded-full bg-emerald-50 text-emerald-700 px-2 py-0.5 text-xs font-semibold"
              >
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                {{ t('admin.attendance.cards.hasCardYes') }}
              </span>
              <span
                v-else
                class="inline-flex items-center gap-1 rounded-full bg-slate-100 text-slate-500 px-2 py-0.5 text-xs font-semibold"
              >
                <span class="w-1.5 h-1.5 rounded-full bg-slate-300"></span>
                {{ t('admin.attendance.cards.hasCardNo') }}
              </span>
            </td>
            <td class="px-3 py-2.5 text-right" @click.stop>
              <!-- Revoke is only meaningful when there IS a card. When
                   there isn't we leave the cell empty rather than
                   render a disabled button that suggests otherwise. -->
              <button
                v-if="row.card"
                type="button"
                class="text-xs font-semibold text-status-danger hover:underline disabled:opacity-50"
                :disabled="revoking.has(row.user_id)"
                @click="revokeRow(row)"
              >
                <span
                  v-if="revoking.has(row.user_id)"
                  class="inline-flex items-center gap-1"
                >
                  <Spinner size="sm" />
                  {{ t('admin.attendance.cards.revoking') }}
                </span>
                <span v-else>{{ t('admin.attendance.cards.revoke') }}</span>
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Server-side pagination — the /list endpoint returns 20 rows per
         page by default. Hidden while loading and when there's a single
         page (nothing to navigate). -->
    <div v-if="pagination && pagination.total_pages > 1" class="pt-2">
      <PaginationWidget :pagination="pagination" @change="onPageChange" />
    </div>
  </div>
</template>
