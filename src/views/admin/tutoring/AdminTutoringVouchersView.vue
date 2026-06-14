<!--
  AdminTutoringVouchersView — generate / manage promo codes.

  Admin sets discount type (% or rupiah), value, optional max uses +
  validity window, and toggles activation. Used count is read-only.

  Parents apply a voucher in the enroll flow (separate view); this
  screen is the source-of-truth for codes themselves.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type { TutoringVoucher } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringStatusPill from '@/components/feature/tutoring/TutoringStatusPill.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const rows = ref<TutoringVoucher[]>([]);

const showCreate = ref(false);
const fCode = ref('');
const fType = ref<'PERCENTAGE' | 'AMOUNT'>('PERCENTAGE');
const fValue = ref<number>(10);
const fMaxUses = ref<string>('');
const fValidFrom = ref('');
const fValidUntil = ref('');
const fNotes = ref('');
const saving = ref(false);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getVouchers();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat voucher.');
  } finally {
    loading.value = false;
  }
}
onMounted(load);

function openCreate() {
  fCode.value = '';
  fType.value = 'PERCENTAGE';
  fValue.value = 10;
  fMaxUses.value = '';
  fValidFrom.value = '';
  fValidUntil.value = '';
  fNotes.value = '';
  showCreate.value = true;
}

async function submit() {
  const code = fCode.value.trim().toUpperCase();
  if (!/^[A-Z0-9_-]{3,40}$/.test(code)) {
    toast.error('Kode 3-40 karakter A-Z, 0-9, "_" atau "-".');
    return;
  }
  if (fValue.value < 1) {
    toast.error('Nilai minimal 1.');
    return;
  }
  if (fType.value === 'PERCENTAGE' && fValue.value > 100) {
    toast.error('Persentase 1..100.');
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createVoucher({
      code,
      type: fType.value,
      value: fValue.value,
      max_uses: fMaxUses.value ? Number(fMaxUses.value) : null,
      valid_from: fValidFrom.value || null,
      valid_until: fValidUntil.value || null,
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

async function toggleActive(v: TutoringVoucher) {
  try {
    await TutoringService.updateVoucher(v.id, { is_active: !v.is_active });
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal mengubah status.');
  }
}

async function remove(v: TutoringVoucher) {
  if (!window.confirm(`Hapus voucher "${v.code}"?`)) return;
  try {
    await TutoringService.deleteVoucher(v.id);
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menghapus.');
  }
}

function copyCode(code: string) {
  navigator.clipboard.writeText(code);
  toast.success(`Kode ${code} disalin.`);
}

function valueLabel(v: TutoringVoucher): string {
  if (v.type === 'PERCENTAGE') return `${v.value}%`;
  return formatRupiah(v.value);
}

const activeCount = computed(() => rows.value.filter((v) => v.is_active).length);
const totalRedemptions = computed(
  () => rows.value.reduce((s, v) => s + v.used_count, 0),
);
const expiredOrCapped = computed(() => {
  const now = Date.now();
  return rows.value.filter((v) => {
    if (v.max_uses != null && v.used_count >= v.max_uses) return true;
    if (v.valid_until && Date.parse(v.valid_until) < now) return true;
    return false;
  }).length;
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'wallet',
    label: 'Total voucher',
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: 'Aktif',
    value: activeCount.value,
    tone: 'green',
  },
  {
    icon: 'sparkles',
    label: 'Redemption',
    value: totalRedemptions.value,
    tone: 'violet',
  },
  {
    icon: 'x-circle',
    label: 'Habis / kedaluwarsa',
    value: expiredOrCapped.value,
    tone: expiredOrCapped.value > 0 ? 'amber' : 'slate',
  },
]);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Voucher / Promo"
      title="Voucher Diskon"
      :meta="`${rows.length} voucher · ${activeCount} aktif`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-bimbel-panel text-bimbel-accent text-[13px] font-bold hover:bg-bimbel-panel/90"
        @click="openCreate"
      >
        <NavIcon name="plus" :size="13" />
        Voucher baru
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" />

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      text="Belum ada voucher. Klik &quot;+ Voucher baru&quot; untuk menggenerate kode promo."
      icon="wallet"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="v in rows"
        :key="v.id"
        icon="wallet"
        :title="v.code"
        :subtitle="[
          v.type === 'PERCENTAGE' ? `Diskon ${v.value}%` : `Diskon ${formatRupiah(v.value)}`,
          v.max_uses != null
            ? `${v.used_count}/${v.max_uses} pakai`
            : `${v.used_count} pakai`,
          v.valid_until ? `s/d ${formatDateShort(v.valid_until)}` : null,
          v.notes,
        ].filter(Boolean).join(' · ')"
      >
        <template #trailing>
          <span class="inline-flex items-center gap-1.5">
            <button
              type="button"
              class="p-1.5 rounded-lg text-bimbel-text-mid hover:text-bimbel-accent hover:bg-bimbel-accent/5"
              title="Salin kode"
              @click.stop="copyCode(v.code)"
            >
              <NavIcon name="external-link" :size="14" />
            </button>
            <button
              type="button"
              class="text-[10.5px] font-bold uppercase tracking-wider px-1.5 hover:underline"
              :class="v.is_active ? 'text-bimbel-amber' : 'text-bimbel-green'"
              @click.stop="toggleActive(v)"
            >
              {{ v.is_active ? 'Nonaktif' : 'Aktif' }}
            </button>
            <TutoringStatusPill
              :label="v.is_active ? 'Aktif' : 'Mati'"
              :tone="v.is_active ? 'ok' : 'neutral'"
            />
            <button
              type="button"
              class="p-1.5 rounded-lg text-bimbel-text-lo hover:text-bimbel-red hover:bg-bimbel-red-soft"
              title="Hapus"
              @click.stop="remove(v)"
            >
              <NavIcon name="trash-2" :size="14" />
            </button>
          </span>
        </template>
      </TutoringListTile>
    </div>

    <Modal v-if="showCreate" title="Voucher Baru" @close="showCreate = false">
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Kode
          </span>
          <input
            v-model="fCode"
            placeholder="UTBK20OFF"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm font-mono uppercase tracking-wider focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          />
          <p class="text-[12px] text-bimbel-text-mid mt-1">
            3–40 karakter: A-Z, 0-9, "_" atau "-". Otomatis uppercase.
          </p>
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              Tipe
            </span>
            <select
              v-model="fType"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            >
              <option value="PERCENTAGE">Persentase (%)</option>
              <option value="AMOUNT">Rupiah (Rp)</option>
            </select>
          </label>
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              Nilai
            </span>
            <input
              v-model.number="fValue"
              type="number"
              :min="1"
              :max="fType === 'PERCENTAGE' ? 100 : undefined"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
        </div>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Maks. pakai (opsional)
          </span>
          <input
            v-model="fMaxUses"
            type="number"
            min="1"
            placeholder="cth. 100 — kosongkan untuk tak terbatas"
            class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
          />
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              Berlaku dari (opsional)
            </span>
            <input
              v-model="fValidFrom"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
          <label class="block">
            <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
              Sampai (opsional)
            </span>
            <input
              v-model="fValidUntil"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-bimbel-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-bimbel-accent"
            />
          </label>
        </div>
        <label class="block">
          <span class="text-[10.5px] font-bold text-bimbel-text-mid uppercase tracking-wider">
            Catatan (opsional)
          </span>
          <textarea
            v-model="fNotes"
            rows="2"
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
            @click="submit"
          >
            {{ saving ? t('tutoring.common.saving') : 'Simpan' }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
