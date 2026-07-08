<!--
  DiscountCodeFormModal.vue — create/edit sheet used by
  SuperAdminDiscountCodesView.

  Renders inside a Modal. When `code` prop is null → create mode
  with sensible defaults; when a DiscountCodeDetail is passed →
  edit mode with fields hydrated. Emits `saved` with the returned
  detail so the parent can splice it into the list.

  Backend validation is authoritative — this form does light
  client-side gating (required fields, percent 1-90) to catch
  obvious typos before the round trip, but every error message
  the user actually sees comes from the backend so we never drift
  out of sync.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import { DiscountCodeService } from '@/services/discount-code.service';
import type {
  CreateDiscountCodePayload,
  DiscountCodeDetail,
  DiscountCodeStatus,
  DiscountCodeTargetScope,
  DiscountCodeType,
} from '@/types/discount-code';

const props = defineProps<{
  /** null → create mode; detail → edit mode. */
  code: DiscountCodeDetail | null;
}>();

const emit = defineEmits<{
  close: [];
  saved: [detail: DiscountCodeDetail];
}>();

const isEdit = computed(() => props.code !== null);

// ── Form state ─────────────────────────────────────────────────
// Kept flat + primitive so v-model bindings stay simple. Reset on
// `code` prop change so opening the modal for a different row
// hydrates cleanly.
const form = ref({
  code: '',
  description: '',
  type: 'percent' as DiscountCodeType,
  value: 10,
  duration_months: null as number | null,
  max_uses: null as number | null,
  min_amount_monthly: 0,
  valid_from: '' as string,
  valid_until: '' as string,
  first_time_only: false,
  status: 'draft' as DiscountCodeStatus,
  target_scope: 'all' as DiscountCodeTargetScope,
  target_keys_text: '' as string, // comma-separated in UI
  tenant_scope_ids_text: '' as string,
});

const saving = ref(false);
const errorMessage = ref<string | null>(null);

watch(
  () => props.code,
  (c) => {
    errorMessage.value = null;
    if (c === null) {
      form.value = {
        code: '',
        description: '',
        type: 'percent',
        value: 10,
        duration_months: null,
        max_uses: null,
        min_amount_monthly: 0,
        valid_from: '',
        valid_until: '',
        first_time_only: false,
        status: 'draft',
        target_scope: 'all',
        target_keys_text: '',
        tenant_scope_ids_text: '',
      };
    } else {
      form.value = {
        code: c.code,
        description: c.description,
        type: c.type,
        value: c.value,
        duration_months: c.duration_months,
        max_uses: c.max_uses,
        min_amount_monthly: c.min_amount_monthly,
        valid_from: c.valid_from ? c.valid_from.slice(0, 10) : '',
        valid_until: c.valid_until ? c.valid_until.slice(0, 10) : '',
        first_time_only: c.first_time_only,
        status: c.status,
        target_scope: c.target_scope,
        target_keys_text: (c.target_keys ?? []).join(', '),
        tenant_scope_ids_text: (c.tenant_scope_ids ?? []).join(', '),
      };
    }
  },
  { immediate: true },
);

// ── Derived hints ──────────────────────────────────────────────
const valueLabel = computed(() =>
  form.value.type === 'percent' ? 'Nilai (%)' : 'Nominal (Rp)',
);
const valueMax = computed(() => (form.value.type === 'percent' ? 90 : 100_000_000));

const isRenameLocked = computed(() =>
  isEdit.value && (props.code?.used_count ?? 0) > 0,
);

// ── Submit ─────────────────────────────────────────────────────
async function submit() {
  errorMessage.value = null;

  // Cheap client gating for obvious typos. Every message shown is
  // still driven by the backend on save() failure — this only
  // catches the pre-flight cases.
  if (form.value.code.trim().length < 4) {
    errorMessage.value = 'Kode minimal 4 karakter.';
    return;
  }
  if (form.value.description.trim().length < 5) {
    errorMessage.value = 'Deskripsi minimal 5 karakter.';
    return;
  }
  if (form.value.type === 'percent' && (form.value.value < 1 || form.value.value > 90)) {
    errorMessage.value = 'Diskon persen harus antara 1-90%.';
    return;
  }

  const targetKeys = form.value.target_scope === 'all'
    ? []
    : form.value.target_keys_text
        .split(',')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);

  const tenantScopeIds = form.value.tenant_scope_ids_text
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  const payload: CreateDiscountCodePayload = {
    code: form.value.code,
    description: form.value.description,
    type: form.value.type,
    value: form.value.value,
    duration_months: form.value.duration_months,
    max_uses: form.value.max_uses,
    min_amount_monthly: form.value.min_amount_monthly,
    valid_from: form.value.valid_from === '' ? null : form.value.valid_from,
    valid_until: form.value.valid_until === '' ? null : form.value.valid_until,
    first_time_only: form.value.first_time_only,
    status: form.value.status,
    target_scope: form.value.target_scope,
    target_keys: form.value.target_scope === 'all' ? null : targetKeys,
    tenant_scope_ids: tenantScopeIds.length > 0 ? tenantScopeIds : null,
  };

  saving.value = true;
  try {
    const detail = isEdit.value && props.code
      ? await DiscountCodeService.update(props.code.id, payload)
      : await DiscountCodeService.create(payload);
    emit('saved', detail);
  } catch (e) {
    errorMessage.value = (e as Error).message;
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <Modal
    :title="isEdit ? `Ubah kode ${code?.code ?? ''}` : 'Buat kode diskon'"
    subtitle="Katalog dipakai di sidebar subscribe. Pastikan kode + deskripsi enak dibaca customer."
    size="lg"
    @close="emit('close')"
  >
    <form class="dcform" @submit.prevent="submit">
      <div class="dcform-row">
        <label class="dcform-lbl" for="dc-code">Kode</label>
        <input
          id="dc-code"
          v-model="form.code"
          type="text"
          maxlength="24"
          class="dcform-in"
          :disabled="isRenameLocked"
          placeholder="WELCOME20"
        />
        <div v-if="isRenameLocked" class="dcform-hint">
          Kode ini sudah pernah dipakai — nama tidak bisa diganti. Arsipkan lalu buat kode baru bila perlu.
        </div>
      </div>

      <div class="dcform-row">
        <label class="dcform-lbl" for="dc-desc">Deskripsi</label>
        <textarea
          id="dc-desc"
          v-model="form.description"
          class="dcform-in"
          rows="2"
          placeholder="Diskon onboarding sekolah baru — berlaku 3 bulan pertama."
        ></textarea>
      </div>

      <div class="dcform-grid">
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-type">Tipe</label>
          <select id="dc-type" v-model="form.type" class="dcform-in">
            <option value="percent">Persen (%)</option>
            <option value="fixed">Nominal (Rp)</option>
          </select>
        </div>
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-value">{{ valueLabel }}</label>
          <input
            id="dc-value"
            v-model.number="form.value"
            type="number"
            min="1"
            :max="valueMax"
            class="dcform-in"
          />
        </div>
      </div>

      <div class="dcform-grid">
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-dur">Durasi (bulan)</label>
          <input
            id="dc-dur"
            v-model.number="form.duration_months"
            type="number"
            min="1"
            max="60"
            class="dcform-in"
            placeholder="Kosongkan = seumur langganan"
          />
        </div>
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-max">Maks. pemakaian</label>
          <input
            id="dc-max"
            v-model.number="form.max_uses"
            type="number"
            min="1"
            class="dcform-in"
            placeholder="Kosongkan = tidak terbatas"
          />
        </div>
      </div>

      <div class="dcform-grid">
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-from">Berlaku sejak</label>
          <input id="dc-from" v-model="form.valid_from" type="date" class="dcform-in" />
        </div>
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-until">Berlaku sampai</label>
          <input id="dc-until" v-model="form.valid_until" type="date" class="dcform-in" />
        </div>
      </div>

      <div class="dcform-row">
        <label class="dcform-lbl" for="dc-min">Min. belanja (Rp / bulan)</label>
        <input id="dc-min" v-model.number="form.min_amount_monthly" type="number" min="0" class="dcform-in" />
      </div>

      <div class="dcform-row">
        <label class="dcform-lbl">
          <input v-model="form.first_time_only" type="checkbox" />
          Hanya untuk tenant baru (belum pernah berlangganan)
        </label>
      </div>

      <div class="dcform-grid">
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-status">Status</label>
          <select id="dc-status" v-model="form.status" class="dcform-in">
            <option value="draft">Draft</option>
            <option value="active">Active</option>
            <option value="paused">Paused</option>
            <option value="archived">Archived</option>
          </select>
        </div>
        <div class="dcform-row">
          <label class="dcform-lbl" for="dc-scope">Scope</label>
          <select id="dc-scope" v-model="form.target_scope" class="dcform-in">
            <option value="all">Semua modul/paket</option>
            <option value="modules">Modul tertentu</option>
            <option value="bundle">Paket tertentu</option>
          </select>
        </div>
      </div>

      <div v-if="form.target_scope !== 'all'" class="dcform-row">
        <label class="dcform-lbl" for="dc-keys">Target keys (comma-separated)</label>
        <input
          id="dc-keys"
          v-model="form.target_keys_text"
          type="text"
          class="dcform-in"
          placeholder="grades, attendance_class, ai_rpp"
        />
        <div class="dcform-hint">Contoh: <code>grades, attendance_class</code></div>
      </div>

      <div class="dcform-row">
        <label class="dcform-lbl" for="dc-tenants">Tenant allowlist (uuid, opsional)</label>
        <input
          id="dc-tenants"
          v-model="form.tenant_scope_ids_text"
          type="text"
          class="dcform-in"
          placeholder="Kosongkan = semua tenant boleh"
        />
      </div>

      <p v-if="errorMessage" class="dcform-err">{{ errorMessage }}</p>

      <div class="dcform-actions">
        <button type="button" class="dcform-btn ghost" :disabled="saving" @click="emit('close')">
          Batal
        </button>
        <button type="submit" class="dcform-btn primary" :disabled="saving">
          {{ saving ? 'Menyimpan…' : isEdit ? 'Simpan perubahan' : 'Buat kode' }}
        </button>
      </div>
    </form>
  </Modal>
</template>

<style scoped>
.dcform { display: flex; flex-direction: column; gap: 14px; }
.dcform-row { display: flex; flex-direction: column; gap: 5px; }
.dcform-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.dcform-lbl {
  font-size: 12px; font-weight: 600; color: #334155;
  display: flex; align-items: center; gap: 6px;
}
.dcform-in {
  padding: 8px 10px;
  border: 1px solid #CBD5E1;
  border-radius: 8px;
  background: #fff;
  font-size: 13px;
  color: #0F172A;
  outline: none;
  transition: border-color 0.12s, box-shadow 0.12s;
}
.dcform-in:focus { border-color: #1B6FB8; box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.12); }
.dcform-in:disabled { background: #F8FAFC; color: #94A3B8; cursor: not-allowed; }
.dcform-hint { font-size: 11px; color: #64748B; }
.dcform-hint code {
  font-family: -apple-system, "SF Mono", monospace;
  background: #F1F5F9; padding: 1px 4px; border-radius: 4px;
}
.dcform-err {
  background: #FEF2F2; color: #B91C1C;
  border: 1px solid #FECACA; border-radius: 8px;
  padding: 8px 10px; font-size: 12px;
}
.dcform-actions {
  display: flex; gap: 8px; justify-content: flex-end;
  padding-top: 8px; border-top: 1px solid #F1F5F9;
}
.dcform-btn {
  padding: 8px 16px; font-size: 12px; font-weight: 700;
  border: none; border-radius: 8px; cursor: pointer;
}
.dcform-btn.ghost { background: #F1F5F9; color: #334155; }
.dcform-btn.ghost:hover { background: #E2E8F0; }
.dcform-btn.primary { background: #1B6FB8; color: #fff; }
.dcform-btn.primary:hover { background: #185FA5; }
.dcform-btn:disabled { opacity: 0.55; cursor: default; }
</style>
