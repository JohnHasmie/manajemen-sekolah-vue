<!--
  AdminFinanceTagihanView.vue — admin · Tagihan tab.

  Pulls `GET /finance/bill-groups` and renders one card per
  (payment_type × class × academic_year) bucket. Cards are grouped by
  Tingkat (grade_level) so the admin can scan kelas 7/8/9 separately.

  Filters:
    - Status   (semua / berjalan / lunas / telat)
    - Jenis    (single payment type — fetched from /payment-types)

  Tapping a card drills into the per-student detail (AdminFinanceBillGroupDetailView).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { FinanceService } from '@/services/finance.service';
import type { BillGroup, BillTingkatBucket, PaymentType } from '@/types/billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import BillGroupCard from '@/components/feature/BillGroupCard.vue';
import { formatRupiah } from '@/lib/format';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

defineProps<{ moneyFlow?: unknown }>();

const router = useRouter();

const groups = ref<BillGroup[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const paymentTypes = ref<PaymentType[]>([]);

type StatusFilter = 'all' | 'unpaid' | 'paid' | 'pending';
const statusFilter = ref<StatusFilter>('all');
const paymentTypeFilter = ref<string>('');
const search = ref('');

const STATUS_OPTS: { key: StatusFilter; label: string }[] = [
  { key: 'all', label: 'Semua status' },
  { key: 'unpaid', label: 'Belum lunas' },
  { key: 'pending', label: 'Menunggu' },
  { key: 'paid', label: 'Lunas' },
];

const showStatusSheet = ref(false);
const showJenisSheet = ref(false);

async function loadGroups() {
  isLoading.value = true;
  error.value = null;
  try {
    const filters: Parameters<typeof FinanceService.billGroups>[0] = {};
    if (statusFilter.value !== 'all') filters.status = statusFilter.value;
    if (paymentTypeFilter.value) filters.payment_type_id = paymentTypeFilter.value;
    groups.value = await FinanceService.billGroups(filters);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadPaymentTypes() {
  try {
    paymentTypes.value = await FinanceService.listPaymentTypes({ status: 'active' });
  } catch {
    paymentTypes.value = [];
  }
}

onMounted(() => {
  void loadPaymentTypes();
  void loadGroups();
});
useAcademicYearWatcher(loadGroups);

watch([statusFilter, paymentTypeFilter], () => void loadGroups());

// Search filters client-side (server doesn't support search on bill-groups).
const filteredGroups = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return groups.value;
  return groups.value.filter((g) => {
    const hay = `${g.payment_type_name} ${g.class_name} ${g.year_label ?? ''}`.toLowerCase();
    return hay.includes(q);
  });
});

// Group by Tingkat (grade_level).
const tingkatBuckets = computed<BillTingkatBucket[]>(() => {
  const map = new Map<string, BillGroup[]>();
  for (const g of filteredGroups.value) {
    const key = g.class_grade_level ?? '—';
    const list = map.get(key) ?? [];
    list.push(g);
    map.set(key, list);
  }
  const buckets: BillTingkatBucket[] = [];
  for (const [gradeLevel, list] of map) {
    const total_amount = list.reduce((s, g) => s + g.total_amount, 0);
    const paid_amount = list.reduce((s, g) => s + g.paid_amount, 0);
    // Distinct classes inside this tingkat — drives the "Per kelas:"
    // drill chips so admins can jump straight to the per-class
    // student-by-student report.
    const seen = new Set<string>();
    const classes: { id: string; name: string }[] = [];
    for (const g of list) {
      if (seen.has(g.class_id)) continue;
      seen.add(g.class_id);
      classes.push({ id: g.class_id, name: g.class_name });
    }
    classes.sort((a, b) => a.name.localeCompare(b.name));
    buckets.push({
      grade_level: gradeLevel,
      label: gradeLevel === '—' ? 'Tanpa tingkat' : `Tingkat ${gradeLevel}`,
      groups: list,
      classes,
      total_amount,
      paid_amount,
      outstanding_amount: Math.max(0, total_amount - paid_amount),
    });
  }
  // Sort: numeric tingkat ascending, then "—" last.
  buckets.sort((a, b) => {
    if (a.grade_level === '—') return 1;
    if (b.grade_level === '—') return -1;
    const na = Number(a.grade_level);
    const nb = Number(b.grade_level);
    if (Number.isFinite(na) && Number.isFinite(nb)) return na - nb;
    return a.grade_level.localeCompare(b.grade_level);
  });
  return buckets;
});

const listState = computed<AsyncState<BillTingkatBucket[]>>(() => {
  if (isLoading.value && groups.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (tingkatBuckets.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: tingkatBuckets.value };
});

const statusChipValue = computed(
  () => STATUS_OPTS.find((o) => o.key === statusFilter.value)?.label ?? 'Semua',
);
const jenisChipValue = computed(() => {
  if (!paymentTypeFilter.value) return 'Semua jenis';
  return paymentTypes.value.find((t) => t.id === paymentTypeFilter.value)?.name ?? '—';
});

function openGroup(g: BillGroup) {
  router.push({
    name: 'admin.finance.tagihan.detail',
    params: { classId: g.class_id, paymentTypeId: g.payment_type_id },
    query: { academicYearId: g.academic_year_id ?? '' },
  });
}
</script>

<template>
  <section class="space-y-md">
    <PageFilterToolbar
      v-model:search="search"
      search-placeholder="Cari jenis atau kelas..."
      :search-min-width="240"
    >
      <template #chips>
        <AppFilterChip
          icon-name="filter"
          label="Status"
          :value="statusChipValue"
          tone="amber"
          @click="showStatusSheet = true"
        />
        <AppFilterChip
          icon-name="layers"
          label="Jenis"
          :value="jenisChipValue"
          tone="violet"
          @click="showJenisSheet = true"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="listState"
      empty-title="Belum ada tagihan"
      empty-description="Generate tagihan dari tab Jenis Pembayaran."
      empty-icon="credit-card"
      @retry="loadGroups"
    >
      <template #default>
        <div class="space-y-4">
          <section
            v-for="bucket in tingkatBuckets"
            :key="bucket.grade_level"
            class="space-y-2"
          >
            <header class="flex items-center justify-between px-1">
              <h3 class="text-[11px] font-black text-slate-700 uppercase tracking-widest">
                {{ bucket.label }}
                <span class="ml-1 text-slate-400">· {{ bucket.groups.length }} bucket</span>
              </h3>
              <span class="text-[10px] font-bold text-amber-700">
                Sisa {{ formatRupiah(bucket.outstanding_amount) }}
              </span>
            </header>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <BillGroupCard
                v-for="g in bucket.groups"
                :key="`${g.payment_type_id}-${g.class_id}-${g.academic_year_id}`"
                :group="g"
                @click="openGroup"
              />
            </div>

            <!-- Per-class drill links — one chip per distinct class
                 inside this tingkat so admins can jump straight to the
                 student-by-student outstanding view. -->
            <div
              v-if="bucket.classes.length > 0"
              class="flex items-center gap-1.5 flex-wrap pt-1 px-1"
            >
              <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mr-1">
                Per kelas:
              </span>
              <button
                v-for="c in bucket.classes"
                :key="c.id"
                type="button"
                class="px-2.5 py-1 rounded-lg text-[11px] font-bold bg-white border border-slate-200 text-slate-600 hover:border-role-admin hover:text-role-admin transition-colors inline-flex items-center gap-1"
                @click="$router.push({
                  name: 'admin.finance.class',
                  params: { classId: c.id },
                  query: { className: c.name },
                })"
              >
                {{ c.name }}
                <NavIcon name="chevron-right" :size="11" />
              </button>
            </div>
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- Status sheet -->
    <Modal
      v-if="showStatusSheet"
      title="Filter Status"
      size="sm"
      @close="showStatusSheet = false"
    >
      <div class="space-y-1">
        <button
          v-for="opt in STATUS_OPTS"
          :key="opt.key"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="
            statusFilter === opt.key
              ? 'bg-role-admin/10 text-role-admin'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="
            statusFilter = opt.key;
            showStatusSheet = false;
          "
        >
          {{ opt.label }}
        </button>
      </div>
    </Modal>

    <!-- Jenis sheet -->
    <Modal
      v-if="showJenisSheet"
      title="Filter Jenis Pembayaran"
      size="sm"
      @close="showJenisSheet = false"
    >
      <div class="space-y-1 max-h-96 overflow-y-auto">
        <button
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="
            paymentTypeFilter === ''
              ? 'bg-role-admin/10 text-role-admin'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="
            paymentTypeFilter = '';
            showJenisSheet = false;
          "
        >
          Semua jenis
        </button>
        <button
          v-for="pt in paymentTypes"
          :key="pt.id"
          type="button"
          class="w-full text-left px-3 py-2.5 rounded-xl text-[13px] font-bold transition-colors"
          :class="
            paymentTypeFilter === pt.id
              ? 'bg-role-admin/10 text-role-admin'
              : 'text-slate-700 hover:bg-slate-50'
          "
          @click="
            paymentTypeFilter = pt.id;
            showJenisSheet = false;
          "
        >
          {{ pt.name }}
          <span class="block text-[10px] text-slate-500 font-medium mt-0.5">
            {{ pt.period }} · {{ formatRupiah(pt.amount) }}
          </span>
        </button>
      </div>
    </Modal>
  </section>
</template>
