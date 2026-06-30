<script setup lang="ts">
/**
 * Frame D · Tambah role kustom (modal).
 *
 * Triggered from AdminRolesView's "+ Tambah Role" CTA. On success
 * navigates the parent to the new role's detail page so the admin
 * can fine-tune permissions immediately.
 *
 * Visual contract: web-vue/_design/rbac/AdminWeb_RBAC_School_v1.svg
 * (frame D).
 */
import { computed, ref, watch } from 'vue';
import { useRbacStore } from '@/stores/rbac';
import type { RbacRole, RbacRoleType } from '@/types/rbac';
import RoleTypePicker from '@/components/feature/rbac/RoleTypePicker.vue';

const props = defineProps<{
  open: boolean;
  schoolId: string;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'created', role: RbacRole): void;
}>();

const rbac = useRbacStore();

const name = ref('');
const keyOverride = ref<string | null>(null);
const roleType = ref<RbacRoleType>('staff');
const presetSource = ref<'empty' | 'admin' | 'teacher' | 'staff'>('empty');
const submitting = ref(false);
const error = ref<string | null>(null);

watch(
  () => props.open,
  (next) => {
    if (next) {
      name.value = '';
      keyOverride.value = null;
      roleType.value = 'staff';
      presetSource.value = 'empty';
      error.value = null;
    }
  },
);

function deriveKey(input: string): string {
  let k = input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
  if (k && !/^[a-z]/.test(k)) k = `r_${k}`;
  return k;
}

const effectiveKey = computed(() => keyOverride.value ?? deriveKey(name.value));
const keyIsAuto = computed(() => keyOverride.value === null);

const canSubmit = computed(
  () =>
    !submitting.value &&
    name.value.trim().length >= 2 &&
    effectiveKey.value.length >= 2 &&
    /^[a-z][a-z0-9_]*$/.test(effectiveKey.value),
);

const presets = computed<{
  value: typeof presetSource.value;
  label: string;
  count: number;
}[]>(() => {
  const out: { value: typeof presetSource.value; label: string; count: number }[] = [
    { value: 'empty', label: 'Kosong', count: 0 },
  ];
  for (const role of rbac.roles) {
    if (role.role_type === 'admin' && role.is_system) {
      out.push({
        value: 'admin',
        label: 'Salin Admin',
        count: role.permission_keys?.length ?? 0,
      });
    }
    if (role.role_type === 'teacher' && role.is_system) {
      out.push({
        value: 'teacher',
        label: 'Salin Guru',
        count: role.permission_keys?.length ?? 0,
      });
    }
  }
  return out;
});

function presetKeys(): string[] {
  if (presetSource.value === 'empty') return [];
  const source = rbac.roles.find(
    (r) => r.is_system && r.role_type === presetSource.value,
  );
  return source?.permission_keys ?? [];
}

async function submit() {
  if (!canSubmit.value) return;
  submitting.value = true;
  error.value = null;
  const created = await rbac.createRole(props.schoolId, {
    key: effectiveKey.value,
    label: name.value.trim(),
    role_type: roleType.value,
    permission_keys: presetKeys(),
  });
  submitting.value = false;
  if (created) {
    emit('created', created);
  } else {
    error.value =
      rbac.rolesError ??
      'Gagal membuat role. Coba periksa nama dan key teknis.';
  }
}
</script>

<template>
  <div v-if="open" class="crm-overlay" @click.self="emit('close')">
    <div class="crm" role="dialog" aria-modal="true">
      <header class="crm__head">
        <div>
          <h3 class="crm__title">Tambah role kustom</h3>
          <p class="crm__sub">
            Cocok untuk Bendahara, Tata Usaha, penjaga sekolah, satpam, dst.
          </p>
        </div>
        <button
          type="button"
          class="crm__close"
          aria-label="Tutup"
          @click="emit('close')"
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path
              d="M3 3 L11 11 M11 3 L3 11"
              stroke="#64748b"
              stroke-width="1.8"
              stroke-linecap="round"
            />
          </svg>
        </button>
      </header>

      <div class="crm__body">
        <label class="crm__field">
          <span class="crm__label">Nama role</span>
          <input
            v-model="name"
            type="text"
            class="crm__input"
            placeholder="Bendahara Utama"
          />
          <span class="crm__hint">Tampil di UI dan di daftar role.</span>
        </label>

        <label class="crm__field">
          <span class="crm__label">Key teknis</span>
          <div class="crm__key">
            <input
              :value="effectiveKey"
              type="text"
              class="crm__input crm__input--mono"
              placeholder="bendahara_utama"
              @input="
                keyOverride =
                  ($event.target as HTMLInputElement).value || null
              "
            />
            <span v-if="keyIsAuto" class="crm__auto">AUTO</span>
          </div>
          <span class="crm__hint"
            >Otomatis dari nama. Hanya huruf kecil, angka, dan underscore.</span
          >
        </label>

        <div class="crm__field">
          <span class="crm__label">Tipe role</span>
          <RoleTypePicker v-model="roleType" />
        </div>

        <div class="crm__field">
          <div class="crm__label-row">
            <span class="crm__label">Permission awal</span>
            <span class="crm__label-hint">Pilih nanti di detail</span>
          </div>
          <div class="crm__presets">
            <button
              v-for="p in presets"
              :key="p.value"
              type="button"
              class="crm__preset"
              :class="{ 'crm__preset--active': presetSource === p.value }"
              @click="presetSource = p.value"
            >
              <span class="crm__preset-label">{{ p.label }}</span>
              <span class="crm__preset-count">{{ p.count }} permission</span>
            </button>
          </div>
        </div>

        <div v-if="error" class="crm__error">{{ error }}</div>
      </div>

      <footer class="crm__foot">
        <button
          type="button"
          class="crm__btn crm__btn--ghost"
          :disabled="submitting"
          @click="emit('close')"
        >
          Batal
        </button>
        <button
          type="button"
          class="crm__btn crm__btn--primary"
          :disabled="!canSubmit"
          @click="submit"
        >
          <span v-if="submitting">Membuat…</span>
          <span v-else>Buat &amp; lanjut atur permission</span>
        </button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.crm-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
  display: grid;
  place-items: center;
  z-index: 60;
  padding: 24px;
}
.crm {
  background: #ffffff;
  border-radius: 20px;
  width: min(540px, 100%);
  max-height: calc(100vh - 48px);
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 40px rgba(15, 23, 42, 0.25);
}
.crm__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  padding: 24px 24px 12px;
  gap: 16px;
}
.crm__title {
  margin: 0 0 4px;
  font-size: 18px;
  font-weight: 900;
  color: #0f172a;
}
.crm__sub {
  margin: 0;
  font-size: 12px;
  color: #64748b;
}
.crm__close {
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  background: #f1f5f9;
  border: 0;
  border-radius: 8px;
  cursor: pointer;
}
.crm__close:hover {
  background: #e2e8f0;
}
.crm__body {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 16px 24px;
  overflow-y: auto;
}
.crm__field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.crm__label-row {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
}
.crm__label {
  font-size: 12px;
  font-weight: 700;
  color: #0f172a;
}
.crm__label-hint {
  font-size: 11px;
  color: #64748b;
}
.crm__input {
  padding: 10px 14px;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 700;
  color: #0f172a;
  background: #ffffff;
  outline: none;
}
.crm__input:focus {
  border-color: #143068;
  box-shadow: 0 0 0 3px rgba(20, 48, 104, 0.1);
}
.crm__input--mono {
  font-family: ui-monospace, Menlo, monospace;
  background: #f8fafc;
}
.crm__key {
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: center;
  gap: 8px;
}
.crm__auto {
  padding: 4px 10px;
  background: #e8eef7;
  color: #143068;
  font-size: 9px;
  font-weight: 800;
  border-radius: 10px;
  letter-spacing: 0.4px;
}
.crm__hint {
  font-size: 10px;
  color: #64748b;
}
.crm__presets {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}
.crm__preset {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 12px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  cursor: pointer;
  text-align: center;
}
.crm__preset--active {
  background: #143068;
  border-color: #143068;
  color: #ffffff;
}
.crm__preset-label {
  font-size: 11px;
  font-weight: 700;
  color: inherit;
}
.crm__preset-count {
  font-size: 9px;
  color: rgba(255, 255, 255, 0.85);
}
.crm__preset:not(.crm__preset--active) .crm__preset-label {
  color: #143068;
}
.crm__preset:not(.crm__preset--active) .crm__preset-count {
  color: #64748b;
}
.crm__error {
  padding: 10px 12px;
  background: #fee2e2;
  color: #991b1b;
  border-radius: 10px;
  font-size: 11px;
}
.crm__foot {
  display: grid;
  grid-template-columns: 120px 1fr;
  gap: 12px;
  padding: 16px 24px;
  border-top: 1px solid #e2e8f0;
}
.crm__btn {
  padding: 12px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  border: 0;
}
.crm__btn--ghost {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  color: #0f172a;
}
.crm__btn--primary {
  background: #143068;
  color: #ffffff;
  font-weight: 800;
}
.crm__btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
