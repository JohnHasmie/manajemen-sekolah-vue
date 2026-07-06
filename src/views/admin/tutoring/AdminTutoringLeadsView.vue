<!--
  AdminTutoringLeadsView — calon student funnel (TRIAL → CONVERTED |
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
import { useConfirm } from '@/composables/useConfirm';
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
const { confirm } = useConfirm();

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

const FILTER_OPTIONS = computed<{ key: Filter; label: string }[]>(() => [
  { key: 'all', label: t('admin.bimbel.leads.filter_all') },
  { key: 'TRIAL', label: t('admin.bimbel.leads.filter_trial') },
  { key: 'CONVERTED', label: t('admin.bimbel.leads.filter_converted') },
  { key: 'DROPPED', label: t('admin.bimbel.leads.filter_dropped') },
]);
const activeFilterLabel = computed(
  () => FILTER_OPTIONS.value.find((o) => o.key === filter.value)?.label ?? t('admin.bimbel.leads.filter_all'),
);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getLeads({
      status: filter.value === 'all' ? undefined : filter.value,
    });
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.leads.load_fail'));
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
    toast.error(t('admin.bimbel.leads.name_min'));
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
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.leads.save_fail'));
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
    toast.error(t('admin.bimbel.leads.paste_id'));
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
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.leads.mark_fail'));
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
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.leads.drop_fail'));
  } finally {
    saving.value = false;
  }
}

async function remove(lead: TutoringLead) {
  if (
    !(await confirm({
      message: t('admin.bimbel.leads.delete_confirm', { name: lead.name }),
      danger: true,
      confirmLabel: t('common.delete'),
    }))
  )
    return;
  try {
    await TutoringService.deleteLead(lead.id);
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.leads.delete_fail'));
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
    label: t('admin.bimbel.leads.kpi_total'),
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'clock',
    label: t('admin.bimbel.leads.kpi_trial'),
    value: trialCount.value,
    tone: 'amber',
  },
  {
    icon: 'check-circle',
    label: t('admin.bimbel.leads.kpi_converted'),
    value: convertedCount.value,
    suffix:
      conversionRate.value != null ? t('admin.bimbel.leads.kpi_converted_rate', { rate: conversionRate.value }) : undefined,
    tone: 'green',
  },
  {
    icon: 'x-circle',
    label: t('admin.bimbel.leads.kpi_dropped'),
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
  if (status === 'CONVERTED') return t('admin.bimbel.leads.pill_converted');
  if (status === 'TRIAL') return t('admin.bimbel.leads.pill_trial');
  return t('admin.bimbel.leads.pill_dropped');
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.leads.kicker')"
      :title="t('admin.bimbel.leads.title')"
      :meta="t('admin.bimbel.leads.meta', { total: rows.length, converted: convertedCount })"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-tutoring-panel text-tutoring-accent text-[13px] font-bold hover:bg-tutoring-panel/90"
        @click="openCreate"
      >
        <NavIcon name="plus" :size="13" />
        {{ t('admin.bimbel.leads.new_lead') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          :label="t('admin.bimbel.leads.filter_status')"
          :value="activeFilterLabel"
          icon-name="users"
          tone="amber"
          @click="showFilterPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('admin.bimbel.leads.empty')"
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
          lead.source ? t('admin.bimbel.leads.source_prefix', { source: lead.source }) : null,
          lead.created_at ? t('admin.bimbel.leads.registered', { date: formatDateShort(lead.created_at) }) : null,
        ].filter(Boolean).join(' · ')"
      >
        <template #trailing>
          <span class="inline-flex items-center gap-1.5">
            <button
              v-if="lead.status === 'TRIAL'"
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider text-tutoring-accent hover:underline px-1.5"
              @click.stop="goEnroll(lead)"
            >
              {{ t('admin.bimbel.leads.btn_enroll') }}
            </button>
            <button
              v-if="lead.status === 'TRIAL'"
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider text-tutoring-green hover:underline px-1.5"
              @click.stop="openConvert(lead)"
            >
              {{ t('admin.bimbel.leads.btn_mark') }}
            </button>
            <button
              v-if="lead.status === 'TRIAL'"
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider text-tutoring-red hover:underline px-1.5"
              @click.stop="openDrop(lead)"
            >
              {{ t('admin.bimbel.leads.btn_drop') }}
            </button>
            <TutoringStatusPill
              :label="pillLabel(lead.status)"
              :tone="pillTone(lead.status)"
            />
            <button
              type="button"
              class="p-1.5 rounded-lg text-tutoring-text-lo hover:text-tutoring-red hover:bg-tutoring-red-soft"
              :title="t('admin.bimbel.leads.delete_title')"
              @click.stop="remove(lead)"
            >
              <NavIcon name="trash-2" :size="14" />
            </button>
          </span>
        </template>
      </TutoringListTile>
    </div>

    <!-- Filter picker -->
    <Modal v-if="showFilterPicker" :title="t('admin.bimbel.leads.filter_modal')" @close="showFilterPicker = false">
      <ul class="space-y-1">
        <li v-for="o in FILTER_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-bg"
            :class="{ 'bg-tutoring-accent/5 text-tutoring-accent font-bold': filter === o.key }"
            @click="pickFilter(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>

    <!-- Create modal -->
    <Modal v-if="showCreate" :title="t('admin.bimbel.leads.modal_new')" @close="showCreate = false">
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.leads.field_name') }}
          </span>
          <input
            v-model="fName"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
          />
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="block">
            <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
              {{ t('admin.bimbel.leads.field_email') }}
            </span>
            <input
              v-model="fEmail"
              type="email"
              class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
            />
          </label>
          <label class="block">
            <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
              {{ t('admin.bimbel.leads.field_phone') }}
            </span>
            <input
              v-model="fPhone"
              class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
            />
          </label>
        </div>
        <label class="block">
          <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.leads.field_program') }}
          </span>
          <select
            v-model="fProgramId"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
          >
            <option value="">{{ t('admin.bimbel.leads.field_program_none') }}</option>
            <option v-for="p in programs" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.leads.field_source') }}
          </span>
          <input
            v-model="fSource"
            :placeholder="t('admin.bimbel.leads.source_ph')"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('admin.bimbel.leads.field_notes') }}
          </span>
          <textarea
            v-model="fNotes"
            rows="3"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent resize-none"
          />
        </label>
        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
            @click="showCreate = false"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-tutoring-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="submitCreate"
          >
            {{ saving ? t('tutoring.common.saving') : t('admin.bimbel.leads.save') }}
          </button>
        </div>
      </div>
    </Modal>

    <!-- Convert modal -->
    <Modal v-if="showConvert" :title="t('admin.bimbel.leads.modal_convert')" @close="showConvert = false">
      <p class="text-sm text-tutoring-text-mid mb-3">
        {{ t('admin.bimbel.leads.convert_hint') }}
      </p>
      <input
        v-model="convertEnrollmentId"
        :placeholder="t('admin.bimbel.leads.convert_ph')"
        class="w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
      />
      <div class="flex items-center gap-2 justify-end mt-4">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
          @click="showConvert = false"
        >
          {{ t('admin.bimbel.leads.cancel') }}
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-tutoring-green hover:bg-tutoring-green/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submitConvert"
        >
          {{ saving ? t('admin.bimbel.leads.saving') : t('admin.bimbel.leads.convert_btn') }}
        </button>
      </div>
    </Modal>

    <!-- Drop modal -->
    <Modal v-if="showDrop" :title="t('admin.bimbel.leads.modal_drop')" @close="showDrop = false">
      <p class="text-sm text-tutoring-text-mid mb-3">
        {{ t('admin.bimbel.leads.drop_hint') }}
      </p>
      <textarea
        v-model="dropNotes"
        rows="3"
        :placeholder="t('admin.bimbel.leads.drop_ph')"
        class="w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-status-danger/20 focus:border-status-danger resize-none"
      />
      <div class="flex items-center gap-2 justify-end mt-4">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
          @click="showDrop = false"
        >
          {{ t('admin.bimbel.leads.cancel') }}
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-tutoring-red hover:bg-tutoring-red/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submitDrop"
        >
          {{ saving ? t('admin.bimbel.leads.saving') : t('admin.bimbel.leads.drop_btn') }}
        </button>
      </div>
    </Modal>
  </div>
</template>
