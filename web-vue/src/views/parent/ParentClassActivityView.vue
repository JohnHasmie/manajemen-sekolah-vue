<!--
  ParentClassActivityView.vue — Kegiatan Kelas feed for wali murid.

  Web port of Flutter's `parent_class_activity_screen.dart`. Flow:
    1. ParentPageHeader (built-in child chip pair when >1 child).
    2. Jenis filter chip — single-select bottom sheet (Tugas / Materi)
       with a Reset action when something is picked.
    3. Date-grouped feed — "HARI INI" / "KEMARIN" / "DD MMMM YYYY"
       section headers with ParentActivityCard rows inside.
    4. Tap a card → ParentActivityDetailModal (read-only) with the
       mobile detail rows (Guru / Mapel / Tanggal / Batas Waktu /
       Deskripsi / Materi / Sub-Bab tambahan). Opening a card also
       fires a single mark-read POST for that id.
    5. Auto mark-as-read via IntersectionObserver — cards visible
       ≥1s get queued; the queue flushes every 1s in batches.
-->
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useChildPicker } from '@/composables/useChildPicker';
import { ClassActivityService } from '@/services/class-activity.service';
import type { ClassActivity } from '@/types/class-activity';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Modal from '@/components/ui/Modal.vue';
import ParentActivityCard from '@/components/feature/ParentActivityCard.vue';
import ParentActivityDetailModal from '@/components/feature/ParentActivityDetailModal.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const { t } = useI18n();
const { activeChildId } = useChildPicker();

// ── Jenis filter (Tugas/Materi) — mirrors mobile's `_typeFilter` ──
type JenisFilter = 'tugas' | 'materi' | null;
const jenisFilter = ref<JenisFilter>(null);
const showJenisPicker = ref(false);

const jenisLabel = computed(() => {
  if (jenisFilter.value === 'tugas') return t('classActivity.task');
  if (jenisFilter.value === 'materi') return t('classActivity.material');
  return t('common.allTypes');
});
const hasActiveFilter = computed(() => jenisFilter.value !== null);

// ── List state ──
const items = ref<ClassActivity[]>([]);
const isLoading = ref(true);
const isFirstLoad = ref(true);
const loadError = ref<string | null>(null);
const detailTarget = ref<ClassActivity | null>(null);

async function reload() {
  if (!activeChildId.value) {
    items.value = [];
    isLoading.value = false;
    isFirstLoad.value = false;
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await ClassActivityService.list({ per_page: 200 });
    items.value = res.items;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
    isFirstLoad.value = false;
  }
}

watch(activeChildId, () => {
  isFirstLoad.value = true;
  reload();
});
onMounted(reload);
useAcademicYearWatcher(() => {
  isFirstLoad.value = true;
  reload();
});

// ── Client-side jenis filter (mirrors mobile's getter on activityList) ──
function jenisOf(a: ClassActivity): 'tugas' | 'materi' {
  const raw = (a.raw_type ?? '').toLowerCase().trim();
  if (raw === 'materi' || raw === 'material' || raw === 'info') return 'materi';
  if (a.type === 'assignment' || a.type === 'homework' || a.type === 'test') {
    return 'tugas';
  }
  return 'materi';
}

const filteredItems = computed<ClassActivity[]>(() => {
  if (!jenisFilter.value) return items.value;
  return items.value.filter((a) => jenisOf(a) === jenisFilter.value);
});

// ── Date grouping (HARI INI / KEMARIN / DD MMMM YYYY) ──
interface DateGroup {
  key: string;
  label: string;
  items: ClassActivity[];
}

function ymd(iso: string): string {
  if (!iso) {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return iso.split('T')[0];
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Uppercase month names track the active i18n locale so date headings
// flip to "APRIL 2026" (English) vs "APRIL 2026" / "MEI 2026" (Indonesian).
const MONTHS_UPPER = computed<string[]>(() => [
  t('parent.activity.monthLong.jan'),
  t('parent.activity.monthLong.feb'),
  t('parent.activity.monthLong.mar'),
  t('parent.activity.monthLong.apr'),
  t('parent.activity.monthLong.may'),
  t('parent.activity.monthLong.jun'),
  t('parent.activity.monthLong.jul'),
  t('parent.activity.monthLong.aug'),
  t('parent.activity.monthLong.sep'),
  t('parent.activity.monthLong.oct'),
  t('parent.activity.monthLong.nov'),
  t('parent.activity.monthLong.dec'),
]);

function dateHeader(key: string): string {
  const d = new Date(key);
  if (!Number.isFinite(d.getTime())) return key.toUpperCase();
  const today = new Date();
  const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const p0 = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diffDays = Math.round((t0.getTime() - p0.getTime()) / 86_400_000);
  if (diffDays === 0) return t('common.today');
  if (diffDays === 1) return t('common.yesterday');
  return `${d.getDate()} ${MONTHS_UPPER.value[d.getMonth()]} ${d.getFullYear()}`;
}

const groupedItems = computed<DateGroup[]>(() => {
  const map = new Map<string, ClassActivity[]>();
  for (const a of filteredItems.value) {
    const key = ymd(a.date);
    if (!map.has(key)) map.set(key, []);
    map.get(key)!.push(a);
  }
  const keys = Array.from(map.keys()).sort((a, b) => b.localeCompare(a));
  return keys.map((k) => ({ key: k, label: dateHeader(k), items: map.get(k)! }));
});

// ── Async state ──
const listState = computed<AsyncState<ClassActivity[]>>(() => {
  if (isLoading.value && isFirstLoad.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (filteredItems.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredItems.value };
});

const emptyTitle = computed(() =>
  items.value.length > 0 && filteredItems.value.length === 0
    ? t('classActivity.noFilterMatch')
    : t('classActivity.empty'),
);
const emptyDescription = computed(() =>
  items.value.length > 0 && filteredItems.value.length === 0
    ? t('common.tryResetFilter')
    : t('classActivity.noActivitiesRecorded'),
);

// ── Auto mark-as-read (IntersectionObserver) ──
const pendingReadIds = new Set<string>();
const visibleSince = new Map<string, number>();
const MIN_VISIBLE_MS = 1000;
const FLUSH_EVERY_MS = 1000;
let flushTimer: ReturnType<typeof setInterval> | null = null;
let observer: IntersectionObserver | null = null;

function setupObserver() {
  if (typeof window === 'undefined' || !('IntersectionObserver' in window)) return;
  observer = new IntersectionObserver(
    (entries) => {
      const now = Date.now();
      for (const e of entries) {
        const id = (e.target as HTMLElement).dataset.activityId;
        if (!id) continue;
        if (e.isIntersecting) {
          if (!visibleSince.has(id)) visibleSince.set(id, now);
        } else {
          visibleSince.delete(id);
        }
      }
    },
    { threshold: 0.6 },
  );
}

function flushReadBatch() {
  if (!visibleSince.size) {
    if (pendingReadIds.size > 0) doFlush();
    return;
  }
  const now = Date.now();
  for (const [id, since] of visibleSince) {
    if (now - since < MIN_VISIBLE_MS) continue;
    const it = items.value.find((x) => x.id === id);
    if (it && it.is_read === false) pendingReadIds.add(id);
    visibleSince.delete(id);
  }
  if (pendingReadIds.size > 0) doFlush();
}

async function doFlush() {
  const ids = Array.from(pendingReadIds);
  pendingReadIds.clear();
  try {
    await ClassActivityService.markAsRead(ids);
    for (const it of items.value) {
      if (ids.includes(it.id)) it.is_read = true;
    }
  } catch {
    if (pendingReadIds.size < 200) {
      for (const id of ids) pendingReadIds.add(id);
    }
  }
}

onMounted(() => {
  setupObserver();
  flushTimer = setInterval(flushReadBatch, FLUSH_EVERY_MS);
});
onBeforeUnmount(() => {
  if (flushTimer) {
    clearInterval(flushTimer);
    flushTimer = null;
  }
  if (observer) {
    observer.disconnect();
    observer = null;
  }
  if (pendingReadIds.size > 0) doFlush();
});

function bindCard(el: Element | null) {
  if (!observer || !el) return;
  observer.observe(el);
}

// ── Detail flow — opening a card immediately marks it read ──
async function openDetail(a: ClassActivity) {
  detailTarget.value = a;
  if (a.is_read === false) {
    a.is_read = true;
    try {
      await ClassActivityService.markAsRead([a.id]);
    } catch {
      // observer will retry next pass
    }
  }
}

// ── Bottom-sheet pickers ──
function pickJenis(value: JenisFilter) {
  jenisFilter.value = value;
  showJenisPicker.value = false;
}
function resetFilter() {
  jenisFilter.value = null;
}
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- HEADER -->
    <ParentPageHeader
      kicker="Akademik · Kegiatan Kelas"
      title="Kegiatan Kelas"
      :interpolate-child="false"
      meta="Catatan kegiatan dari guru"
    />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar hide-search>
      <template #chips>
        <div class="flex items-center gap-2 flex-wrap">
          <AppFilterChip
            label="Jenis"
            :value="jenisLabel"
            icon-name="filter"
            tone="violet"
            @click="showJenisPicker = true"
          />
          <button
            v-if="hasActiveFilter"
            type="button"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-xl border border-slate-200 text-[10px] font-bold uppercase tracking-widest text-slate-500 hover:bg-slate-50"
            @click="resetFilter"
          >
            <NavIcon name="x" :size="10" />
            Reset
          </button>
        </div>
      </template>
    </PageFilterToolbar>

    <!-- LIST -->
    <AsyncView
      :state="listState"
      :empty-title="emptyTitle"
      :empty-description="emptyDescription"
      empty-icon="activity"
      @retry="reload"
    >
      <template #default>
        <div class="space-y-5">
          <section
            v-for="group in groupedItems"
            :key="group.key"
            class="space-y-2"
          >
            <h3
              class="text-[11px] font-bold text-slate-500 uppercase tracking-widest px-1"
            >
              {{ group.label }}
            </h3>
            <div class="space-y-2">
              <div
                v-for="it in group.items"
                :key="it.id"
                :ref="(el) => bindCard(el as Element | null)"
                :data-activity-id="it.id"
              >
                <ParentActivityCard :activity="it" @click="openDetail" />
              </div>
            </div>
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- DETAIL MODAL -->
    <ParentActivityDetailModal
      v-if="detailTarget"
      :activity="detailTarget"
      @close="detailTarget = null"
    />

    <!-- JENIS PICKER -->
    <Modal
      v-if="showJenisPicker"
      title="Filter Jenis Kegiatan"
      @close="showJenisPicker = false"
    >
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors"
            :class="{
              'bg-role-wali/5 text-role-wali font-bold': jenisFilter === null,
            }"
            @click="pickJenis(null)"
          >
            {{ t('common.allTypes') }}
          </button>
        </li>
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors flex items-center gap-2"
            :class="{
              'bg-role-wali/5 text-role-wali font-bold': jenisFilter === 'tugas',
            }"
            @click="pickJenis('tugas')"
          >
            <span
              class="w-5 h-5 rounded-md grid place-items-center bg-amber-100 text-amber-700"
            >
              <NavIcon name="check-square" :size="11" />
            </span>
            {{ t('classActivity.task') }}
          </button>
        </li>
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors flex items-center gap-2"
            :class="{
              'bg-role-wali/5 text-role-wali font-bold': jenisFilter === 'materi',
            }"
            @click="pickJenis('materi')"
          >
            <span
              class="w-5 h-5 rounded-md grid place-items-center bg-emerald-100 text-emerald-700"
            >
              <NavIcon name="book" :size="11" />
            </span>
            {{ t('classActivity.material') }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
