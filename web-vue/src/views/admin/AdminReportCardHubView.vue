<!--
  AdminReportCardHubView.vue — admin rapor hub (Mockup #08).

  Web port of `admin_raport_hub_screen.dart`. Replaces the fake
  placeholder data with real `/raports/admin-pipeline` wire-up.

  Layout:
    1. BrandPageHeader (admin)
    2. RaportPipelineStrip — 4-node Draft → Diperiksa → Terbit →
       Dibagikan; tap to filter by pipeline stage
    3. PageFilterToolbar — periode display chip + search
    4. Per-tingkat group cards with kelas mini-chips
       (tone-coded by status_tone) — tap chip to drill in
    5. Multi-select on chips → sticky BulkActionBar with publish

  Endpoints:
    GET  /raports/admin-pipeline    — full tier tree + KPI
    POST /raports/publish           — bulk publish per class
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { ReportCardService } from '@/services/report-card.service';
import type {
  AdminRaportPipeline,
  KelasMiniChip,
  PipelineKey,
  TingkatGroup,
  ReportCardStatus,
} from '@/types/report-card';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import Modal from '@/components/ui/Modal.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const router = useRouter();

// ── Data state ──
const pipeline = ref<AdminRaportPipeline | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const activeFilter = ref<PipelineKey | 'all'>('all');

// UI Modals / Sheets state
const showStatusModal = ref(false);
const showMoreMenuModal = ref(false);
const sendNotification = ref(true);
const expandedTingkats = ref<Record<string, boolean>>({});

// Selection (kelas chips) for bulk publish
const selectedChipIds = ref<Set<string>>(new Set());
const isPublishing = ref(false);
const confirmBulkPublish = ref(false);

const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

// ── Loader ──
async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    pipeline.value = await ReportCardService.getAdminPipeline();
    // Initialize first tingkat expanded on load
    if (pipeline.value?.tingkats.length) {
      const firstTingkat = String(pipeline.value.tingkats[0].tingkat);
      if (expandedTingkats.value[firstTingkat] === undefined) {
        expandedTingkats.value[firstTingkat] = true;
      }
    }
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(reload);
useAcademicYearWatcher(reload);

// ── Derived ──
const pipelineNodes = computed(() => pipeline.value?.pipeline ?? []);
const tingkats = computed(() => pipeline.value?.tingkats ?? []);

// Filter chips by status when activeFilter set (matches Flutter status label check)
function chipMatches(chip: KelasMiniChip): boolean {
  if (activeFilter.value === 'all') return true;
  const label = (chip.status_label ?? '').toLowerCase().trim();
  const wanted = (activeFilter.value === 'reviewed' ? 'diperiksa' : activeFilter.value === 'published' ? 'terbit' : activeFilter.value === 'distributed' ? 'dibagikan' : 'draft');
  return label === wanted;
}

const visibleTingkats = computed<TingkatGroup[]>(() => {
  return tingkats.value
    .map((t) => ({
      ...t,
      classes: t.classes.filter(chipMatches),
    }))
    .filter((t) => t.classes.length > 0);
});

const listState = computed<AsyncState<TingkatGroup[]>>(() => {
  if (isLoading.value && !pipeline.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleTingkats.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleTingkats.value };
});

const selectedCount = computed(() => selectedChipIds.value.size);

const headerMeta = computed(() => {
  const p = pipeline.value;
  if (!p) return 'Memuat ringkasan rapor sekolah…';
  const totalClasses = p.total_classes ?? 0;
  return `${totalClasses} kelas · ${periodLabel.value}`;
});

const periodLabel = computed(() => {
  const p = pipeline.value?.period;
  if (!p) return 'Periode aktif';
  const ay = p.academic_year_label ?? '';
  const sem = p.semester_label ?? '';
  return ay && sem ? `${ay} ${sem}` : 'Periode aktif';
});

const statusChipValue = computed(() => {
  if (activeFilter.value === 'all') return 'Semua';
  if (activeFilter.value === 'draft') return 'Draft';
  if (activeFilter.value === 'reviewed') return 'Diperiksa';
  if (activeFilter.value === 'published') return 'Terbit';
  if (activeFilter.value === 'distributed') return 'Dibagikan';
  return activeFilter.value;
});

// Selection info for bulk publish modal
const selectedClassesInfo = computed(() => {
  const p = pipeline.value;
  if (!p) return { names: '', studentCount: 0, tingkatLabels: '' };
  
  const selectedClasses = p.tingkats
    .flatMap((t) => t.classes)
    .filter((c) => selectedChipIds.value.has(c.id));
    
  const names = selectedClasses.map((c) => c.name).join(', ');
  const studentCount = selectedClasses.reduce((sum, c) => sum + (c.student_count ?? 0), 0);
  
  const tingkatsFound = new Set<string>();
  p.tingkats.forEach((t) => {
    if (t.classes.some((c) => selectedChipIds.value.has(c.id))) {
      tingkatsFound.add(`Tingkat ${t.tingkat}`);
    }
  });
  const tingkatLabels = Array.from(tingkatsFound).join(', ');

  // Format label: Tingkat VII · 7A, 7B | Tingkat VIII · 8A
  const listLabels: string[] = [];
  p.tingkats.forEach((t) => {
    const matched = t.classes.filter(c => selectedChipIds.value.has(c.id)).map(c => c.name);
    if (matched.length > 0) {
      listLabels.push(`Tingkat ${t.tingkat} · ${matched.join(', ')}`);
    }
  });

  return { 
    names, 
    studentCount, 
    tingkatLabels,
    formattedLabels: listLabels.join(' | ')
  };
});

// Expand/Collapse methods
function toggleTingkat(tingkat: string | number) {
  const k = String(tingkat);
  expandedTingkats.value[k] = !expandedTingkats.value[k];
}

function isTingkatExpanded(tingkat: string | number): boolean {
  const k = String(tingkat);
  if (expandedTingkats.value[k] === undefined) {
    const list = tingkats.value;
    if (list.length > 0 && String(list[0].tingkat) === k) {
      expandedTingkats.value[k] = true;
    } else {
      expandedTingkats.value[k] = false;
    }
  }
  return expandedTingkats.value[k];
}

// ── Pipeline tone ──
function pipelineToneClass(key: PipelineKey, active: boolean): string {
  if (active) {
    switch (key) {
      case 'draft':
        return 'bg-slate-100 text-slate-700 border-slate-300';
      case 'reviewed':
        return 'bg-amber-50 text-amber-800 border-amber-300';
      case 'published':
        return 'bg-emerald-50 text-emerald-800 border-emerald-300';
      case 'distributed':
        return 'bg-brand-cobalt/10 text-brand-cobalt border-brand-cobalt';
    }
  }
  return 'bg-white text-slate-600 border-slate-200 hover:border-role-admin/40';
}

function pipelineDotClass(key: PipelineKey): string {
  switch (key) {
    case 'draft':
      return 'bg-slate-400';
    case 'reviewed':
      return 'bg-amber-500';
    case 'published':
      return 'bg-emerald-500';
    case 'distributed':
      return 'bg-brand-cobalt';
  }
}

// ── Selection / actions ──
function toggleSelect(id: string) {
  const next = new Set(selectedChipIds.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selectedChipIds.value = next;
}

function clearSelection() {
  selectedChipIds.value = new Set();
}

function isSelected(id: string): boolean {
  return selectedChipIds.value.has(id);
}

function pipelineClick(key: PipelineKey) {
  activeFilter.value = activeFilter.value === key ? 'all' : key;
}

function chipClick(chip: KelasMiniChip) {
  // If we're in selection mode (≥1 selected), toggle. Otherwise drill.
  if (selectedChipIds.value.size > 0) {
    toggleSelect(chip.id);
    return;
  }
  router.push({
    name: 'admin.report-cards.class',
    params: { classId: chip.id },
  });
}

function chipLongPress(chip: KelasMiniChip) {
  toggleSelect(chip.id);
}

// Bulk print targets first selected class
function bulkPrint() {
  if (selectedChipIds.value.size === 0) return;
  const firstId = Array.from(selectedChipIds.value)[0];
  router.push({
    name: 'admin.report-cards.class',
    params: { classId: firstId }
  });
}

// ── Bulk publish ──
async function publishSelected() {
  if (selectedChipIds.value.size === 0) return;
  isPublishing.value = true;
  let okCount = 0;
  let failCount = 0;
  try {
    for (const classId of Array.from(selectedChipIds.value)) {
      try {
        const res = await ReportCardService.publishClass({ class_id: classId });
        okCount += res.published_count;
      } catch {
        failCount += 1;
      }
    }
    toast.value = {
      message:
        failCount === 0
          ? `${okCount} rapor diterbitkan.`
          : `${okCount} terbit, ${failCount} gagal. Coba lagi yang gagal.`,
      tone: failCount === 0 ? 'success' : 'error',
    };
    clearSelection();
    await reload();
  } finally {
    isPublishing.value = false;
    confirmBulkPublish.value = false;
  }
}

// Tone-coded badge for kelas mini-chip
function chipBadgeClass(tone: string | undefined): string {
  switch (tone) {
    case 'good':
      return 'bg-emerald-100 text-emerald-700';
    case 'warn':
      return 'bg-amber-100 text-amber-700';
    case 'bad':
      return 'bg-red-100 text-red-700';
    default:
      return 'bg-slate-100 text-slate-600';
  }
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      kicker="Akademik · Penilaian"
      title="Hub Rapor Sekolah"
      :meta="headerMeta"
      :live-dot="false"
    >
      <button
        type="button"
        class="w-9 h-9 rounded-full flex items-center justify-center bg-white/10 border border-white/20 text-white hover:bg-white/20 transition relative"
        @click="showStatusModal = true"
      >
        <NavIcon name="filter" :size="15" />
        <span
          v-if="activeFilter !== 'all'"
          class="absolute -top-1 -right-1 w-2.5 h-2.5 rounded-full bg-amber-500 border border-white"
        />
      </button>
      <button
        type="button"
        class="w-9 h-9 rounded-full flex items-center justify-center bg-white/10 border border-white/20 text-white hover:bg-white/20 transition"
        @click="showMoreMenuModal = true"
      >
        <NavIcon name="more-horizontal" :size="15" />
      </button>

      <template #role-toggle>
        <div class="flex flex-wrap gap-2">
          <!-- Periode Chip -->
          <div
            class="inline-flex items-center gap-2.5 rounded-xl border border-white/10 bg-white/5 text-white/90 px-3 py-1.5 min-w-[150px]"
          >
            <span class="flex flex-col items-start min-w-0 leading-none">
              <span class="text-[8.5px] font-bold text-white/50 uppercase tracking-widest">Periode</span>
              <span class="text-[12.5px] font-bold truncate mt-0.5">{{ periodLabel }}</span>
            </span>
          </div>

          <!-- Status Chip -->
          <button
            type="button"
            class="inline-flex items-center gap-2.5 rounded-xl border border-white/20 bg-white/10 text-white hover:bg-white/20 transition px-3 py-1.5"
            @click="showStatusModal = true"
          >
            <span class="flex flex-col items-start min-w-0 leading-none text-left">
              <span class="text-[8.5px] font-bold text-white/50 uppercase tracking-widest">Status</span>
              <span class="text-[12.5px] font-bold truncate mt-0.5">{{ statusChipValue }}</span>
            </span>
            <NavIcon name="chevron-down" :size="12" class="opacity-70 ml-1.5" />
          </button>
        </div>
      </template>
    </BrandPageHeader>

    <!-- PIPELINE STRIP -->
    <section
      v-if="pipelineNodes.length > 0"
      class="bg-white border border-slate-200 rounded-2xl p-3"
    >
      <p class="text-[9.5px] font-bold text-slate-500 uppercase tracking-widest mb-2 px-1">
        Pipeline Rapor
      </p>
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
        <button
          v-for="node in pipelineNodes"
          :key="node.key"
          type="button"
          class="rounded-xl border px-3 py-2.5 transition text-left"
          :class="pipelineToneClass(node.key, activeFilter === node.key)"
          @click="pipelineClick(node.key)"
        >
          <div class="flex items-center gap-2">
            <span
              class="w-2 h-2 rounded-full"
              :class="pipelineDotClass(node.key)"
            />
            <span class="text-[10.5px] font-bold uppercase tracking-widest flex-1">
              {{ node.label }}
            </span>
          </div>
          <p class="text-2xl font-black mt-1.5 tabular-nums leading-none">
            {{ node.count }}
          </p>
        </button>
      </div>
      <p
        v-if="activeFilter !== 'all'"
        class="text-[10px] text-slate-400 mt-2 text-center"
      >
        Filter aktif: <strong>{{
          pipelineNodes.find((n) => n.key === activeFilter)?.label
        }}</strong> — klik lagi untuk reset
      </p>
    </section>

    <!-- TINGKAT TREE -->
    <AsyncView
      :state="listState"
      :empty-title="
        activeFilter !== 'all'
          ? 'Tidak ada kelas cocok'
          : 'Belum ada data rapor'
      "
      empty-description="Pipeline ini akan terisi setelah guru mengajukan nilai akhir."
      empty-icon="users"
      @retry="reload"
    >
      <div class="space-y-4">
        <section
          v-for="tg in visibleTingkats"
          :key="tg.tingkat"
          class="bg-white border border-slate-200 rounded-2xl p-4"
        >
          <header 
            class="flex items-center gap-2 mb-3 cursor-pointer select-none"
            @click="toggleTingkat(tg.tingkat)"
          >
            <span class="text-[11px] font-black text-slate-900 uppercase tracking-widest">
              Tingkat {{ tg.tingkat }}
            </span>
            <span class="text-[10px] text-slate-400 tabular-nums">
              · {{ tg.class_count }} kelas · {{ tg.student_count }} siswa
            </span>
            <span class="flex-1"></span>
            <span
              v-if="tg.reviewed_pct !== undefined"
              class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 tabular-nums"
            >
              {{ Math.round(tg.reviewed_pct) }}% diperiksa
            </span>
            <span
              v-if="tg.alert"
              class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-700 inline-flex items-center gap-1"
            >
              <NavIcon name="bell" :size="10" />
              Perlu perhatian
            </span>
            <NavIcon 
              :name="isTingkatExpanded(tg.tingkat) ? 'chevron-up' : 'chevron-down'" 
              :size="14" 
              class="text-slate-400 ml-1.5"
            />
          </header>
          
          <div 
            v-show="isTingkatExpanded(tg.tingkat)" 
            class="flex flex-wrap gap-2 pt-1"
          >
            <button
              v-for="chip in tg.classes"
              :key="chip.id"
              type="button"
              class="rounded-xl border px-3 py-2 transition text-left min-w-[120px]"
              :class="
                isSelected(chip.id)
                  ? 'bg-role-admin text-white border-role-admin shadow-sm'
                  : 'bg-white text-slate-700 border-slate-200 hover:border-role-admin/40'
              "
              @click="chipClick(chip)"
              @contextmenu.prevent="chipLongPress(chip)"
            >
              <div class="flex items-center gap-1.5">
                <NavIcon
                  v-if="isSelected(chip.id)"
                  name="check-circle"
                  :size="11"
                />
                <span class="text-[12px] font-bold">{{ chip.name }}</span>
              </div>
              <div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
                <span
                  v-if="chip.status_label"
                  class="text-[9.5px] font-bold px-1.5 py-0.5 rounded-full uppercase tracking-wider"
                  :class="
                    isSelected(chip.id)
                      ? 'bg-white/20 text-white'
                      : chipBadgeClass(chip.status_tone)
                  "
                >
                  {{ chip.status_label }}
                </span>
                <span
                  v-if="chip.student_count !== undefined"
                  class="text-[9.5px] tabular-nums"
                  :class="
                    isSelected(chip.id) ? 'text-white/80' : 'text-slate-500'
                  "
                >
                  {{ chip.student_count }} siswa
                </span>
              </div>
            </button>
          </div>
        </section>
      </div>
    </AsyncView>

    <!-- BULK ACTION BAR (Styled in navy brand, matching Flutter) -->
    <section
      v-if="selectedCount > 0"
      class="sticky bottom-4 z-30 flex items-center gap-3 px-4 py-3 bg-[#0A1F4D] text-white rounded-2xl shadow-lg border border-white/10"
    >
      <button
        type="button"
        class="w-7 h-7 rounded-full bg-white/20 flex items-center justify-center text-white hover:bg-white/30 transition-colors"
        @click="clearSelection"
      >
        <NavIcon name="x" :size="13" />
      </button>
      <div class="flex flex-col min-w-0 leading-none">
        <span class="text-[11px] font-black text-white">{{ selectedCount }} kelas dipilih</span>
        <span class="text-[9.5px] text-white/70 truncate mt-1 max-w-[200px] sm:max-w-xs md:max-w-md">
          {{ selectedClassesInfo.formattedLabels }}
        </span>
      </div>
      <span class="flex-1"></span>
      <button
        type="button"
        class="text-[11px] font-bold text-white/80 hover:text-white border border-white/30 hover:border-white px-3 py-2 rounded-xl transition"
        :disabled="isPublishing"
        @click="bulkPrint"
      >
        Cetak
      </button>
      <button
        type="button"
        class="text-[11px] font-black text-[#0A1F4D] bg-white hover:bg-white/95 px-3 py-2 rounded-xl transition disabled:opacity-50"
        :disabled="isPublishing"
        @click="confirmBulkPublish = true"
      >
        {{ isPublishing ? 'Menerbitkan…' : 'Terbit' }}
      </button>
    </section>

    <!-- CONFIRM BULK PUBLISH (Premium Modal layout, matching Flutter) -->
    <Modal
      v-slot:default
      v-if="confirmBulkPublish"
      title="Terbitkan Rapor"
      :subtitle="`${selectedCount} kelas siap terbit`"
      size="sm"
      @close="confirmBulkPublish = false"
    >
      <div class="space-y-4">
        <!-- Overview info -->
        <div class="bg-[#0A1F4D] text-white rounded-2xl p-4">
          <p class="text-[10px] font-bold text-white/60 uppercase tracking-widest">Kelas Terpilih</p>
          <p class="text-[12.5px] font-medium leading-relaxed mt-1">
            {{ selectedClassesInfo.tingkatLabels }} · {{ selectedClassesInfo.names }} · {{ selectedClassesInfo.studentCount }} siswa
          </p>
        </div>

        <!-- Impact items -->
        <div class="space-y-2">
          <p class="text-[9.5px] font-bold text-slate-400 uppercase tracking-widest">Dampak</p>
          
          <div class="bg-slate-50 border border-slate-200 rounded-xl p-3">
            <p class="text-[11.5px] font-bold text-slate-800">Notifikasi otomatis</p>
            <p class="text-[10.5px] text-slate-500 mt-0.5">{{ selectedClassesInfo.studentCount }} wali murid akan menerima push</p>
          </div>
          
          <div class="bg-slate-50 border border-slate-200 rounded-xl p-3">
            <p class="text-[11.5px] font-bold text-slate-800">Akses parent role</p>
            <p class="text-[10.5px] text-slate-500 mt-0.5">Rapor lengkap + ringkasan terbuka untuk di-download</p>
          </div>

          <div class="bg-amber-50 border border-amber-200 text-amber-900 rounded-xl p-3">
            <p class="text-[11.5px] font-bold text-amber-800">Tindakan tidak dapat dibatalkan</p>
            <p class="text-[10.5px] text-amber-700/80 mt-0.5">Ubah kembali ke Diperiksa harus dilakukan manual per kelas</p>
          </div>
        </div>

        <!-- Toggle Switch -->
        <div class="border border-slate-200 rounded-xl p-3 flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-[11.5px] font-bold text-slate-800">Kirim notifikasi push</span>
            <span class="text-[10px] text-slate-500">Wali murid akan menerima alert di HP</span>
          </div>
          <!-- Simple Toggle Switch -->
          <button
            type="button"
            class="relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none"
            :class="sendNotification ? 'bg-[#0A1F4D]' : 'bg-slate-200'"
            @click="sendNotification = !sendNotification"
          >
            <span
              aria-hidden="true"
              class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
              :class="sendNotification ? 'translate-x-5' : 'translate-x-0'"
            />
          </button>
        </div>

        <!-- Confirm buttons -->
        <div class="flex gap-2 pt-2">
          <Button
            variant="secondary"
            class="flex-1"
            :disabled="isPublishing"
            @click="confirmBulkPublish = false"
          >
            Batal
          </Button>
          <Button
            variant="primary"
            class="flex-1 bg-[#0A1F4D] hover:bg-[#0A1F4D]/95 text-white"
            :loading="isPublishing"
            :disabled="isPublishing"
            @click="publishSelected"
          >
            Terbitkan {{ selectedCount }} kelas
          </Button>
        </div>
      </div>
    </Modal>

    <!-- STATUS FILTER MODAL (Wired to activeFilter) -->
    <Modal
      v-slot:default
      v-if="showStatusModal"
      title="Filter status rapor"
      subtitle="Pilih satu status untuk menyaring tingkat otomatis"
      size="sm"
      @close="showStatusModal = false"
    >
      <div class="space-y-1">
        <button
          v-for="opt in [
            { key: 'all', label: 'Semua Status', icon: 'layers' },
            { key: 'draft', label: 'Draft', icon: 'edit' },
            { key: 'reviewed', label: 'Diperiksa', icon: 'check-square' },
            { key: 'published', label: 'Terbit', icon: 'send' },
            { key: 'distributed', label: 'Dibagikan', icon: 'share' },
          ]"
          :key="opt.key"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors flex items-center gap-3"
          :class="
            activeFilter === opt.key
              ? 'bg-[#0A1F4D]/10 text-[#0A1F4D]'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="
            activeFilter = opt.key;
            showStatusModal = false;
          "
        >
          <span class="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-[#0A1F4D] flex-shrink-0">
            <NavIcon :name="opt.icon" :size="15" />
          </span>
          <span class="flex-1">{{ opt.label }}</span>
          <NavIcon
            v-if="activeFilter === opt.key"
            name="check-circle"
            :size="16"
            class="text-[#0A1F4D]"
          />
        </button>
      </div>
    </Modal>

    <!-- MORE MENU MODAL -->
    <Modal
      v-slot:default
      v-if="showMoreMenuModal"
      title="Pilihan Lainnya"
      size="sm"
      @close="showMoreMenuModal = false"
    >
      <div class="space-y-1">
        <button
          type="button"
          class="w-full text-left px-3 py-3 rounded-xl hover:bg-slate-50 transition-colors flex items-center gap-3"
          @click="
            showMoreMenuModal = false;
            bulkPrint();
          "
        >
          <span class="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-[#0A1F4D] flex-shrink-0">
            <NavIcon name="file-text" :size="15" />
          </span>
          <div class="flex flex-col leading-none">
            <span class="text-[13px] font-bold text-slate-800">Cetak rapor</span>
            <span class="text-[10px] text-slate-400 mt-1">Buka alur cetak per kelas</span>
          </div>
        </button>

        <button
          type="button"
          class="w-full text-left px-3 py-3 rounded-xl hover:bg-slate-50 transition-colors flex items-center gap-3"
          @click="
            showMoreMenuModal = false;
            reload();
          "
        >
          <span class="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-[#0A1F4D] flex-shrink-0">
            <NavIcon name="refresh-cw" :size="15" />
          </span>
          <div class="flex flex-col leading-none">
            <span class="text-[13px] font-bold text-slate-800">Muat ulang data</span>
            <span class="text-[10px] text-slate-400 mt-1">Ambil pipeline + kelas terbaru dari server</span>
          </div>
        </button>

        <button
          v-if="activeFilter !== 'all'"
          type="button"
          class="w-full text-left px-3 py-3 rounded-xl hover:bg-slate-50 transition-colors flex items-center gap-3 border-t border-slate-100"
          @click="
            showMoreMenuModal = false;
            activeFilter = 'all';
          "
        >
          <span class="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-[#0A1F4D] flex-shrink-0">
            <NavIcon name="x" :size="15" />
          </span>
          <div class="flex flex-col leading-none">
            <span class="text-[13px] font-bold text-slate-800">Bersihkan filter</span>
            <span class="text-[10px] text-slate-400 mt-1">Tampilkan semua status</span>
          </div>
        </button>
      </div>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
