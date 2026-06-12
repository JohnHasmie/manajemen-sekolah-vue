<!--
  AdminTutoringLeadsView — calon siswa funnel (TRIAL → CONVERTED |
  DROPPED). Admin manages the lead list, creates new ones (e.g.
  walk-in inquiry), and converts to enrollment by routing to the
  existing enroll flow with the lead's name/email/program prefilled.

  After the enroll flow returns, the admin can manually mark the lead
  CONVERTED with the resulting enrollment id (the enroll screen
  doesn't yet auto-call back, so we expose a small "Tandai converted"
  control on TRIAL rows).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type { TutoringLead, TutoringProgram } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type Filter = 'all' | 'TRIAL' | 'CONVERTED' | 'DROPPED';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const loading = ref(true);
const rows = ref<TutoringLead[]>([]);
const programs = ref<TutoringProgram[]>([]);
const filter = ref<Filter>('all');
const showFilterPicker = ref(false);

const showCreate = ref(false);
const fName = ref('');
const fEmail = ref('');
const fPhone = ref('');
const fProgramId = ref<string>('');
const fSource = ref('');
const fNotes = ref('');
const saving = ref(false);

const showConvert = ref(false);
const convertLead = ref<TutoringLead | null>(null);
const convertEnrollmentId = ref('');

const showDrop = ref(false);
const dropLead = ref<TutoringLead | null>(null);
const dropNotes = ref('');

const FILTER_OPTIONS = [
  { key: 'all' as Filter, label: 'Semua' },
  { key: 'TRIAL' as Filter, label: 'Trial' },
  { key: 'CONVERTED' as Filter, label: 'Converted' },
  { key: 'DROPPED' as Filter, label: 'Dropped' },
];
const activeFilterLabel = computed(
  () => FILTER_OPTIONS.find((o) => o.key === filter.value)?.label ?? 'Semua',
);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getLeads({
      status: filter.value === 'all' ? undefined : filter.value,
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat leads.');
  } finally {
    loading.value = false;
  }
}

async function loadPrograms() {
  try {
    programs.value = await TutoringService.getPrograms();
  } catch {/* non-fatal */}
}

onMounted(async () => {
  await Promise.all([load(), loadPrograms()]);
});
watch(filter, load);

function openCreate() {
  fName.value = '';
  fEmail.value = '';
  fPhone.value = '';
  fProgramId.value = '';
  fSource.value = '';
  fNotes.value = '';
  showCreate.value = true;
}

async function submitCreate() {
  if (fName.value.trim().length < 2) {
    toast.error('Nama minimal 2 karakter.');
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createLead({
      name: fName.value.trim(),
      email: fEmail.value.trim() || undefined,
      phone: fPhone.value.trim() || undefined,
      program_id: fProgramId.value || undefined,
      source: fSource.value.trim() || undefined,
      notes: fNotes.value.trim() || undefined,
    });
    showCreate.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.');
  } finally {
    saving.value = false;
  }
}

function goEnroll(lead: TutoringLead) {
  // Open admin enroll prefilled. The enroll flow saves enrollments
  // independently; admin returns + uses "Tandai converted" with the
  // resulting enrollment id.
  router.push({
    name: 'admin.tutoring.enroll',
    params: { programId: lead.program_id ?? '' },
    query: {
      name: lead.program_name ?? '',
      leadName: lead.name,
      leadEmail: lead.email ?? '',
    },
  });
}

function openConvert(lead: TutoringLead) {
  convertLead.value = lead;
  convertEnrollmentId.value = '';
  showConvert.value = true;
}

async function submitConvert() {
  if (!convertLead.value) return;
  if (!convertEnrollmentId.value.trim()) {
    toast.error('Tempel enrollment ID dari hasil enroll.');
    return;
  }
  saving.value = true;
  try {
    await TutoringService.convertLead(
      convertLead.value.id,
      convertEnrollmentId.value.trim(),
    );
    showConvert.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menandai.');
  } finally {
    saving.value = false;
  }
}

function openDrop(lead: TutoringLead) {
  dropLead.value = lead;
  dropNotes.value = '';
  showDrop.value = true;
}

async function submitDrop() {
  if (!dropLead.value) return;
  saving.value = true;
  try {
    await TutoringService.dropLead(
      dropLead.value.id,
      dropNotes.value.trim() || undefined,
    );
    showDrop.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal drop.');
  } finally {
    saving.value = false;
  }
}

async function remove(lead: TutoringLead) {
  if (!window.confirm(`Hapus "${lead.name}" dari daftar?`)) return;
  try {
    await TutoringService.deleteLead(lead.id);
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menghapus.');
  }
}

function pickFilter(k: Filter) {
  filter.value = k;
  showFilterPicker.value = false;
}

// Aggregates for the KPI strip — always count the full snapshot
// loaded for the active filter (so when filter=TRIAL, the cards
// describe what the page shows).
const trialCount = computed(
  () => rows.value.filter((r) => r.status === 'TRIAL').length,
);
const convertedCount = computed(
  () => rows.value.filter((r) => r.status === 'CONVERTED').length,
);
const droppedCount = computed(
  () => rows.value.filter((r) => r.status === 'DROPPED').length,
);
const conversionRate = computed(() => {
  const denom = convertedCount.value + droppedCount.value;
  if (denom === 0) return null;
  return Math.round((convertedCount.value / denom) * 100);
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'users',
    label: 'Total lead',
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'clock',
    label: 'Trial',
    value: trialCount.value,
    tone: 'amber',
  },
  {
    icon: 'check-circle',
    label: 'Converted',
    value: convertedCount.value,
    suffix:
      conversionRate.value != null ? `${conversionRate.value}% rate` : undefined,
    tone: 'green',
  },
  {
    icon: 'x-circle',
    label: 'Dropped',
    value: droppedCount.value,
    tone: droppedCount.value > 0 ? 'red' : 'slate',
  },
]);

function pillTone(status: string): 'ok' | 'warn' | 'danger' {
  if (status === 'CONVERTED') return 'ok';
  if (status === 'TRIAL') return 'warn';
  return 'danger';
}
function pillLabel(status: string): string {
  if (status === 'CONVERTED') return 'Converted';
  if (status === 'TRIAL') return 'Trial';
  return 'Dropped';
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Lead / Calon Siswa"
      title="Lead Funnel"
      :meta="`${rows.length} lead · ${convertedCount} converted`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-panel text-bimbel-accent text-[12px] font-bold hover:bg-bimbel-panel/90"
        @click="openCreate"
      >
        <NavIcon name="plus" :size="13" />
        Lead baru
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          label="Status"
          :value="activeFilterLabel"
          icon-name="users"
          tone="amber"
          @click="showFilterPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      text="Belum ada lead. Klik &quot;+ Lead baru&quot; untuk menambah calon siswa."
      icon="users"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="lead in rows"
        :key="lead.id"
        icon="user"
        :title="lead.name"
        :subtitle="[
          lead.email,
          lead.phone,
          lead.program_name,
          lead.source ? `via ${lead.source}` : null,
          lead.created_at ? `Didaftar ${formatDateShort(lead.created_at)}` : null,
        ].filter(Boolean).join(' · ')"
      >
        <template #trailing>
          <span class="inline-flex items-center gap-1.5">
            <button
              v-if="lead.status === 'TRIAL'"
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider text-bimbel-accent hover:underline px-1.5"
              @click.stop="goEnroll(lead)"
            >
              Enroll
            </button>
            <button
              v-if="lead.status === 'TRIAL'"
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider text-bimbel-green hover:underline px-1.5"
              @click.stop="openConvert(lead)"
            >
              Tandai
            </button>
            <button
              v-if="lead.status === 'TRIAL'"
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider text-bimbel-red hover:underline px-1.5"
              @click.stop="openDrop(lead)"
            >
              Drop
            </button>
            <TutoringStatusPill
              :label="pillLabel(lead.status)"
              :tone="pillTone(lead.status)"
            />
            <button
              type="button"
              class="p-1.5 rounded-lg text-bimbel-text-lo hover:text-bimbel-red hover:bg-bimbel-red-soft"
              title="Hapus"
              @click.stop="remove(lead)"
            >
              <NavIcon name="trash-2" :size="14" />
            </button>
          </span>
        </template>
      </TutoringListTile>
    </div>

    <!-- Filter picker -->
    <Modal v-if="showFilterPicker" title="Filter Status" @close="showFilterPicker = false">
      <ul class="space-y-1">
        <li v-for="o in FILTER_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-bimbel-bg"
            :class="{ 'bg-bimbel-accent/5 text-bimbel-accent font-bold': filter === o.key }"
            @click="pickFilter(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- Create modal -->
    <Modal v-if="showCreate" title="Lead Baru" @close="showCreate = false">
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Nama
          </span>
          <input
            v-model="fName"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          />
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              Email (opsional)
            </span>
            <input
              v-model="fEmail"
              type="email"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              Telepon (opsional)
            </span>
            <input
              v-model="fPhone"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
        </div>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Program minat (opsional)
          </span>
          <select
            v-model="fProgramId"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          >
            <option value="">— Belum tentu —</option>
            <option v-for="p in programs" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Sumber (opsional)
          </span>
          <input
            v-model="fSource"
            placeholder="cth. IG ads, referral, walk-in"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Catatan (opsional)
          </span>
          <textarea
            v-model="fNotes"
            rows="3"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent resize-none"
          />
        </label>
        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-bimbel-text-mid hover:bg-bimbel-border-soft"
            @click="showCreate = false"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-bimbel-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="submitCreate"
          >
            {{ saving ? t('tutoring.common.saving') : 'Simpan' }}
          </button>
        </div>
      </div>
    </Modal>

    <!-- Convert modal -->
    <Modal v-if="showConvert" title="Tandai Converted" @close="showConvert = false">
      <p class="text-sm text-bimbel-text-mid mb-3">
        Setelah membuat enrollment di flow Daftarkan, tempel
        <strong>enrollment ID</strong> di sini agar lead tercatat
        sebagai sumber.
      </p>
      <input
        v-model="convertEnrollmentId"
        placeholder="enrollment_id"
        class="w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
      />
      <div class="flex items-center gap-2 justify-end mt-4">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-bimbel-text-mid hover:bg-bimbel-border-soft"
          @click="showConvert = false"
        >
          Batal
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-bimbel-green hover:bg-bimbel-green/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submitConvert"
        >
          {{ saving ? 'Menyimpan…' : 'Tandai converted' }}
        </button>
      </div>
    </Modal>

    <!-- Drop modal -->
    <Modal v-if="showDrop" title="Drop Lead" @close="showDrop = false">
      <p class="text-sm text-bimbel-text-mid mb-3">
        Alasan drop (opsional, masuk ke catatan):
      </p>
      <textarea
        v-model="dropNotes"
        rows="3"
        placeholder="cth. tidak sesuai jadwal, pindah tempat tinggal"
        class="w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-status-danger/20 focus:border-status-danger resize-none"
      />
      <div class="flex items-center gap-2 justify-end mt-4">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-bimbel-text-mid hover:bg-bimbel-border-soft"
          @click="showDrop = false"
        >
          Batal
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-bimbel-red hover:bg-bimbel-red/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submitDrop"
        >
          {{ saving ? 'Menyimpan…' : 'Drop' }}
        </button>
      </div>
    </Modal>
  </div>
</template>
