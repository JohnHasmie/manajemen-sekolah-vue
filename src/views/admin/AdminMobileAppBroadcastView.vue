<!--
  AdminMobileAppBroadcastView.vue — remedial WA blast page reached from
  the `users_with_mobile_app` readiness lane item (backend MR-A/E).

  MR-F redesign: multi-role. The screen now surfaces guru + staf + wali
  murid in a single flow, with a role filter chip row at top, per-role
  editable templates, and a grouped recipient list.

  Server-side spacing (10s between messages) is unchanged — the FE only
  kicks off the batch; delayed jobs on Horizon handle cadence, so the
  operator can leave the tab.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import {
  ALL_ROLES,
  DEFAULT_TEMPLATES,
  MobileAppBroadcastService,
  ROLE_LABELS,
  type BatchSummary,
  type BroadcastRole,
  type MobileAppRecipient,
} from '@/services/mobile-app-broadcast.service';

const loading = ref(true);
const recipients = ref<MobileAppRecipient[]>([]);
const perRoleTotals = ref<Partial<Record<BroadcastRole, number>>>({});
const excludedMissingPhonePerRole = ref<Partial<Record<BroadcastRole, number>>>({});

// Role filter — clicking a chip toggles that role in/out of the blast.
// Default: every role WITH recipients pre-selected. A role with 0
// recipients starts un-selected (nothing to send).
const selectedRoles = ref<Set<BroadcastRole>>(new Set());

const selected = ref<Set<string>>(new Set());

// Per-role editable templates + which role's textarea is currently open.
const templates = ref<Record<BroadcastRole, string>>({ ...DEFAULT_TEMPLATES });
const openTemplateRole = ref<BroadcastRole | null>(null);

const batches = ref<BatchSummary[]>([]);
const submitting = ref(false);
const flash = ref<{ ok: boolean; message: string } | null>(null);

const lastBatch = computed<BatchSummary | null>(
  () => (batches.value.length > 0 ? batches.value[0] : null),
);

const recipientsInSelectedRoles = computed(() =>
  recipients.value.filter((r) => selectedRoles.value.has(r.role)),
);

const groupedRecipients = computed<Record<BroadcastRole, MobileAppRecipient[]>>(() => {
  const out: Record<BroadcastRole, MobileAppRecipient[]> = {
    teacher: [],
    staff: [],
    parent: [],
  };
  for (const r of recipients.value) out[r.role].push(r);
  return out;
});

const selectedCount = computed(() => selected.value.size);

const etaMinutes = computed(() => Math.ceil((selectedCount.value * 10) / 60));

const canSubmit = computed(() => {
  if (submitting.value) return false;
  if (selectedCount.value === 0) return false;
  for (const role of ALL_ROLES) {
    if (!selectedRoles.value.has(role)) continue;
    const t = templates.value[role].trim();
    if (t.length < 20 || t.length > 1000) return false;
  }
  return true;
});

async function loadAll() {
  loading.value = true;
  try {
    const [rec, bat] = await Promise.all([
      MobileAppBroadcastService.getRecipients(),
      MobileAppBroadcastService.getBatches(),
    ]);
    recipients.value = rec.data;
    perRoleTotals.value = rec.meta.per_role_totals ?? {};
    excludedMissingPhonePerRole.value = rec.meta.excluded_missing_phone_per_role ?? {};
    // Default role selection: only roles that actually have recipients.
    selectedRoles.value = new Set(
      ALL_ROLES.filter((role) => (perRoleTotals.value[role] ?? 0) > 0),
    );
    // Auto-select every recipient in the selected roles.
    selected.value = new Set(
      rec.data.filter((r) => selectedRoles.value.has(r.role)).map((r) => r.user_id),
    );
    // Open the first non-empty template accordion for quick preview.
    const firstActive = ALL_ROLES.find((r) => selectedRoles.value.has(r));
    openTemplateRole.value = firstActive ?? null;
    batches.value = bat;
  } finally {
    loading.value = false;
  }
}

function toggleRole(role: BroadcastRole) {
  const next = new Set(selectedRoles.value);
  if (next.has(role)) {
    next.delete(role);
    // De-selecting a role also un-checks its recipients.
    const nextSelected = new Set(selected.value);
    for (const r of groupedRecipients.value[role]) nextSelected.delete(r.user_id);
    selected.value = nextSelected;
    if (openTemplateRole.value === role) openTemplateRole.value = null;
  } else {
    next.add(role);
    // Re-add all this role's recipients.
    const nextSelected = new Set(selected.value);
    for (const r of groupedRecipients.value[role]) nextSelected.add(r.user_id);
    selected.value = nextSelected;
    if (openTemplateRole.value === null) openTemplateRole.value = role;
  }
  selectedRoles.value = next;
}

function toggleRecipient(userId: string) {
  const next = new Set(selected.value);
  if (next.has(userId)) next.delete(userId);
  else next.add(userId);
  selected.value = next;
}

function toggleAllInRole(role: BroadcastRole) {
  const ids = groupedRecipients.value[role].map((r) => r.user_id);
  const allSelected = ids.length > 0 && ids.every((id) => selected.value.has(id));
  const next = new Set(selected.value);
  if (allSelected) {
    for (const id of ids) next.delete(id);
  } else {
    for (const id of ids) next.add(id);
  }
  selected.value = next;
}

function templateCharCount(role: BroadcastRole): number {
  return templates.value[role].length;
}

async function trigger() {
  if (!canSubmit.value) return;
  submitting.value = true;
  flash.value = null;
  try {
    // Only send templates for roles that are actually being blasted.
    const payloadTemplates: Partial<Record<BroadcastRole, string>> = {};
    for (const role of ALL_ROLES) {
      if (selectedRoles.value.has(role)) payloadTemplates[role] = templates.value[role];
    }
    const res = await MobileAppBroadcastService.trigger(
      payloadTemplates,
      Array.from(selected.value),
    );
    if (res.ok) {
      const perRoleParts: string[] = [];
      for (const role of ALL_ROLES) {
        const n = res.data.queued_per_role[role] ?? 0;
        if (n > 0) perRoleParts.push(`${n} ${ROLE_LABELS[role].toLowerCase()}`);
      }
      flash.value = {
        ok: true,
        message: `${res.data.queued} pesan dijadwalkan (${perRoleParts.join(' · ')}) — jeda ${res.data.interval_seconds} detik.`,
      };
      await Promise.all([loadAll()]);
    } else {
      const retry = res.retryAfterSeconds
        ? ` Coba lagi dalam ${Math.ceil(res.retryAfterSeconds / 60)} menit.`
        : '';
      flash.value = { ok: false, message: res.error + retry };
    }
  } finally {
    submitting.value = false;
  }
}

function formatDateTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return '—';
  }
}

onMounted(() => {
  void loadAll();
});
</script>

<template>
  <div class="max-w-5xl mx-auto space-y-4 pb-8">
    <BrandPageHeader
      role="admin"
      kicker="Kesiapan Sekolah"
      title="Kirim WA install app"
      meta="Belum instal aplikasi mobile — kirim reminder ke guru, staf, dan wali murid sekaligus."
    />

    <!-- Last-batch summary -->
    <div
      v-if="lastBatch"
      class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm flex flex-wrap items-center gap-4"
    >
      <div class="flex-1 min-w-[200px]">
        <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">
          Blast terakhir
        </p>
        <p class="text-sm text-slate-900 mt-1">
          {{ formatDateTime(lastBatch.started_at) }}
          <span class="text-slate-500">·</span>
          {{ lastBatch.total }} pesan
        </p>
      </div>
      <div class="flex flex-wrap gap-2 text-xs">
        <span class="px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700 font-bold">
          {{ lastBatch.delivered }} terkirim
        </span>
        <span
          v-if="lastBatch.failed > 0"
          class="px-2.5 py-1 rounded-full bg-rose-100 text-rose-700 font-bold"
        >
          {{ lastBatch.failed }} gagal
        </span>
        <span
          v-if="lastBatch.queued > 0"
          class="px-2.5 py-1 rounded-full bg-amber-100 text-amber-700 font-bold"
        >
          {{ lastBatch.queued }} dalam antrean
        </span>
      </div>
    </div>

    <!-- 1 · Role filter -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">
        1 · Peran
      </p>
      <div class="mt-2 flex flex-wrap gap-2">
        <button
          v-for="role in ALL_ROLES"
          :key="role"
          type="button"
          :disabled="(perRoleTotals[role] ?? 0) === 0"
          class="px-3 py-1.5 text-xs font-bold rounded-full inline-flex items-center gap-2 border transition-colors"
          :class="selectedRoles.has(role)
            ? 'bg-brand-cobalt text-white border-brand-cobalt'
            : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed'"
          @click="toggleRole(role)"
        >
          <NavIcon v-if="selectedRoles.has(role)" name="check" :size="12" />
          {{ ROLE_LABELS[role] }}
          <span
            class="text-2xs px-1.5 py-0.5 rounded-full font-mono"
            :class="selectedRoles.has(role)
              ? 'bg-white/25 text-white'
              : 'bg-slate-100 text-slate-500'"
          >
            {{ perRoleTotals[role] ?? 0 }}
          </span>
        </button>
      </div>
      <p class="text-xs text-slate-500 mt-2">
        Klik peran untuk pilih. Template pesan disesuaikan otomatis per peran.
      </p>
    </div>

    <!-- 2 · Templates -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
      <div class="flex items-center justify-between">
        <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">
          2 · Template pesan
        </p>
        <span class="text-xs text-slate-400">Placeholder {name} otomatis diganti nama</span>
      </div>
      <div class="mt-3 space-y-2">
        <div
          v-for="role in ALL_ROLES"
          :key="role"
          class="border border-slate-200 rounded-lg overflow-hidden"
          :class="{ 'opacity-50': !selectedRoles.has(role) }"
        >
          <button
            type="button"
            class="w-full flex items-center gap-2 px-3 py-2.5 bg-slate-50 hover:bg-slate-100 text-left"
            @click="openTemplateRole = openTemplateRole === role ? null : role"
          >
            <NavIcon
              :name="openTemplateRole === role ? 'chevron-down' : 'chevron-right'"
              :size="14"
              class="text-slate-500"
            />
            <span class="text-sm font-bold text-slate-900">
              {{ ROLE_LABELS[role] }}
            </span>
            <span class="text-xs text-slate-500">
              · {{ perRoleTotals[role] ?? 0 }} penerima
            </span>
            <span
              class="ml-auto text-xs font-mono"
              :class="templateCharCount(role) > 1000 ? 'text-rose-600' : 'text-slate-400'"
            >
              {{ templateCharCount(role) }} / 1000
            </span>
          </button>
          <div v-if="openTemplateRole === role" class="p-3 bg-white">
            <textarea
              v-model="templates[role]"
              :disabled="!selectedRoles.has(role)"
              rows="6"
              class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:ring-2 focus:ring-brand/20 focus:border-brand outline-none font-mono disabled:bg-slate-50"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- 3 · Recipients -->
    <div class="bg-white border border-slate-100 rounded-2xl shadow-sm overflow-hidden">
      <div class="flex items-center justify-between p-4 border-b border-slate-100">
        <div>
          <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">
            3 · Penerima
          </p>
          <p class="text-sm text-slate-900 mt-1">
            <span class="font-bold">{{ selectedCount }}</span>
            / {{ recipientsInSelectedRoles.length }} dipilih
          </p>
        </div>
      </div>

      <div v-if="loading" class="p-6 text-center text-sm text-slate-500">
        Memuat daftar penerima…
      </div>
      <div
        v-else-if="recipientsInSelectedRoles.length === 0"
        class="p-6 text-center text-sm text-slate-500"
      >
        <NavIcon name="check-circle" :size="20" class="inline mb-2" />
        <p>Tidak ada penerima untuk peran yang dipilih.</p>
      </div>
      <div v-else class="max-h-[420px] overflow-y-auto">
        <template v-for="role in ALL_ROLES" :key="role">
          <template v-if="selectedRoles.has(role) && groupedRecipients[role].length > 0">
            <div
              class="sticky top-0 z-10 flex items-center gap-2 px-4 py-2 bg-slate-100 text-xs font-bold text-slate-600"
            >
              {{ ROLE_LABELS[role] }} · {{ groupedRecipients[role].length }}
              <button
                type="button"
                class="ml-auto text-xs font-bold text-slate-500 hover:text-slate-900"
                @click="toggleAllInRole(role)"
              >
                {{
                  groupedRecipients[role].every((r) => selected.has(r.user_id))
                    ? 'Batal semua'
                    : 'Pilih semua'
                }}
              </button>
            </div>
            <ul class="divide-y divide-slate-100">
              <li
                v-for="r in groupedRecipients[role]"
                :key="r.user_id"
                class="flex items-center gap-3 p-3 hover:bg-slate-50 cursor-pointer"
                @click="toggleRecipient(r.user_id)"
              >
                <input
                  type="checkbox"
                  :checked="selected.has(r.user_id)"
                  class="flex-none w-4 h-4 accent-brand-cobalt cursor-pointer"
                  @click.stop="toggleRecipient(r.user_id)"
                />
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-bold text-slate-900 truncate">{{ r.name }}</p>
                  <p class="text-xs text-slate-500 truncate">{{ r.email }}</p>
                </div>
                <span class="text-xs font-mono text-slate-500">
                  {{ r.phone_masked }}
                </span>
              </li>
            </ul>
          </template>
        </template>
      </div>

      <div
        v-if="excludedMissingPhonePerRole && Object.keys(excludedMissingPhonePerRole).length > 0"
        class="px-4 py-3 border-t border-slate-100 bg-amber-50 text-xs text-amber-800"
      >
        <NavIcon name="alert-circle" :size="12" class="inline" />
        Tidak muncul karena belum punya nomor HP di data:
        <template v-for="(n, role, i) in excludedMissingPhonePerRole" :key="String(role)">
          <template v-if="i > 0"> · </template>
          {{ n }} {{ ROLE_LABELS[role as BroadcastRole].toLowerCase() }}
        </template>
      </div>
    </div>

    <!-- Action -->
    <div class="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm space-y-3">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <div class="flex-1 min-w-0">
          <p class="text-sm font-bold text-slate-900">
            {{ selectedCount }} pesan siap kirim
          </p>
          <p class="text-xs text-slate-500 mt-0.5">
            Jeda 10 detik antar pesan · total ~{{ etaMinutes }} menit ·
            kamu boleh tutup tab, pengiriman jalan di server.
          </p>
        </div>
        <button
          type="button"
          :disabled="!canSubmit"
          class="px-4 py-2 text-sm font-bold rounded-lg bg-brand-cobalt text-white hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center gap-2"
          @click="trigger"
        >
          <NavIcon name="brand-whatsapp" :size="16" />
          {{ submitting ? 'Menjadwalkan…' : `Kirim ${selectedCount} pesan` }}
        </button>
      </div>
      <p
        v-if="flash"
        class="text-xs px-3 py-2 rounded-lg"
        :class="flash.ok ? 'bg-emerald-50 text-emerald-800' : 'bg-rose-50 text-rose-800'"
      >
        {{ flash.message }}
      </p>
    </div>
  </div>
</template>
