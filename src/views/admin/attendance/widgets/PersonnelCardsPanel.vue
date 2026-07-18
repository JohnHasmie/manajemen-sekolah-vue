<!--
  PersonnelCardsPanel.vue — Guru / Staf tab body for the Kartu QR
  Personal hub. Preserves the ORIGINAL account-based flow:

    - Rows from `/attendance/personnel-cards/list` (keyed on `user_id`)
    - Selection posts to `/personnel-cards/issue`
    - Revoke posts to `/personnel-cards/{cardId}`
    - PDF via `/personnel-cards/export.pdf`

  The role toggle that used to live on the header ("Semua / Guru / Staf
  / Siswa") is now driven by the parent tab — this panel reads a fixed
  `role` prop (teacher or staff) and never asks the server for the
  other roles. Siswa gets its own dedicated panel (StudentCardsPanel)
  because students are account-less; there was no way to serve both
  from one endpoint honestly.

  History: earlier iterations sourced rows from `TeacherService.list`
  as a fallback and used `teachers.id` in the selection set. That broke
  both issue + PDF export — the backend rejected every id as
  `not_a_school_member` because it never mapped teacher-id → user-id.
  See mobile!392 + fix in the personnel-cards contract.
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
import Spinner from '@/components/ui/Spinner.vue';
import EmptyState from '@/components/data/EmptyState.vue';
import SkeletonList from '@/components/data/SkeletonList.vue';
import PaginationWidget from '@/components/data/Pagination.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';

const props = defineProps<{
  /** Server-side role filter. Teacher tab passes 'teacher', Staf passes 'staff'. */
  role: Extract<PersonnelRole, 'teacher' | 'staff'>;
}>();

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const rows = ref<PersonnelCardListRow[]>([]);
const pagination = ref<Pagination | null>(null);
/** Set of selected user_id values — the backend keys on user_id. */
const selected = ref<Set<string>>(new Set());
/** Free-text search box over name + email + NIP (server-side). */
const searchQuery = ref('');
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
      role: props.role,
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
watch(hasCardFilter, () => {
  currentPage.value = 1;
  void load();
});
// The parent keys the panel on tab so this prop never changes on-panel;
// still, guard the load in case a future usage swaps role dynamically.
watch(
  () => props.role,
  () => {
    selected.value = new Set();
    searchQuery.value = '';
    hasCardFilter.value = 'all';
    currentPage.value = 1;
    void load();
  },
);

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
 * from the pre-rebuild page.
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

onMounted(load);
</script>

<template>
  <div class="space-y-md">
    <!-- Action row — Terbitkan + Unduh PDF for the current selection.
         Sits above the filter row so an admin who already has a
         selection can act on it without scrolling past the search box.
         Buttons are disabled until at least one row is picked. -->
    <div
      class="flex flex-wrap items-center justify-between gap-2 bg-white border border-slate-200 rounded-2xl px-4 py-3"
    >
      <p class="text-2xs font-bold uppercase tracking-widest text-slate-500">
        {{ selectedCount }} dipilih
      </p>
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl border border-slate-300 text-slate-700 hover:bg-slate-50 px-md py-1.5 text-sm font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          :disabled="selectedCount === 0 || exporting"
          @click="exportSelectedPdf"
        >
          <Spinner v-if="exporting" size="sm" />
          <NavIcon v-else name="download" :size="14" />
          {{ t('admin.attendance.cards.exportPdf') }}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 rounded-xl bg-role-admin text-white hover:opacity-90 px-md py-1.5 text-sm font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          :disabled="selectedCount === 0 || issuing"
          @click="issueSelected"
        >
          <Spinner v-if="issuing" size="sm" />
          <NavIcon v-else name="id-card" :size="14" />
          {{ t('admin.attendance.cards.issue', { count: selectedCount }) }}
        </button>
      </div>
    </div>

    <!-- Filter row (shared PageFilterToolbar). The has-card status
         select rides the #chips slot; the built-in search input is
         driven by v-model:search. Canonical `focus:ring-2` + text-sm
         so it matches every other admin filter row. -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      :search-placeholder="t('admin.attendance.cards.searchPh')"
      :search-min-width="220"
    >
      <template #chips>
        <select
          v-model="hasCardFilter"
          class="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:ring-2 focus:ring-brand/20 focus:border-brand"
        >
          <option value="all">
            {{ t('admin.attendance.cards.hasCardAll') }}
          </option>
          <option value="yes">
            {{ t('admin.attendance.cards.hasCardYes') }}
          </option>
          <option value="no">
            {{ t('admin.attendance.cards.hasCardNo') }}
          </option>
        </select>
      </template>
    </PageFilterToolbar>

    <!-- Loading shell — reuses the shared SkeletonList so the layout
         locks before rows arrive (no jank when the fetch resolves). -->
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
        <thead
          class="bg-slate-50 text-xs uppercase tracking-wider text-slate-500"
        >
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
              {{ row.user_email || '–' }}
            </td>
            <td class="px-3 py-2.5">
              <!-- Has-card pill: green when active, muted slate when
                   not. Reads at a glance so the admin doesn't have to
                   hunt the Aksi column. -->
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

    <!-- Server-side pagination — /list returns 20 rows per page by
         default. Hidden while loading and when there's a single page. -->
    <div v-if="pagination && pagination.total_pages > 1" class="pt-2">
      <PaginationWidget :pagination="pagination" @change="onPageChange" />
    </div>
  </div>
</template>
