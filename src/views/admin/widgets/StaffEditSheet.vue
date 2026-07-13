<!--
  StaffEditSheet.vue — create / edit a staff member.

  Create mode (staff === null): full form incl. email, an optional RBAC role
  to grant, and an initial-password choice (auto-generate vs type). This is
  the "tambah staf baru dari nol" flow — the account is minted server-side.

  Edit mode (staff set): only the mutable data-record fields (name, jabatan,
  no. hp). Email is the login identity and role changes go through the RBAC
  "Tambah anggota" flow, so both are shown read-only.

  Emits `save(payload)`; the host runs the service call so it can surface the
  returned initial password once (create) or a toast (edit).
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { StaffMember, StaffRole } from '@/types/staff';

const props = defineProps<{
  /** null = create mode; a member = edit mode. */
  staff: StaffMember | null;
  /** Assignable RBAC roles for the "Akses" picker (create mode). */
  roles: StaffRole[];
  isSaving: boolean;
}>();

const emit = defineEmits<{
  close: [];
  save: [payload: Record<string, unknown>];
}>();

const { t: $t } = useI18n();

const isEdit = computed(() => props.staff !== null);

const name = ref(props.staff?.name ?? '');
const email = ref(props.staff?.email ?? '');
const position = ref(props.staff?.position ?? '');
const phone = ref(props.staff?.phone ?? '');
const roleId = ref<number | null>(props.staff?.roles?.[0]?.id ?? null);

type PwMode = 'generate' | 'manual';
const pwMode = ref<PwMode>('generate');
const password = ref('');
const showPassword = ref(false);

const err = ref<string | null>(null);

const emailInvalid = computed(
  () => !isEdit.value && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value.trim()),
);
const manualPwInvalid = computed(
  () => !isEdit.value && pwMode.value === 'manual' && password.value.trim().length < 6,
);
const canSubmit = computed(
  () =>
    name.value.trim().length >= 2 &&
    position.value.trim().length >= 2 &&
    (isEdit.value || (!emailInvalid.value && !manualPwInvalid.value)),
);

function submit() {
  err.value = null;
  if (!canSubmit.value) {
    err.value = $t('admin.staff.formIncomplete');
    return;
  }

  if (isEdit.value) {
    emit('save', {
      name: name.value.trim(),
      position: position.value.trim(),
      phone: phone.value.trim() || null,
    });
    return;
  }

  emit('save', {
    name: name.value.trim(),
    email: email.value.trim(),
    position: position.value.trim(),
    phone: phone.value.trim() || null,
    role_id: roleId.value ?? undefined,
    // Omit password entirely in generate mode → the server mints one.
    ...(pwMode.value === 'manual' ? { password: password.value.trim() } : {}),
  });
}

const inputClass =
  'w-full rounded-xl border border-slate-300 px-3 py-2.5 text-[13px] focus:border-role-admin focus:outline-none focus:ring-1 focus:ring-role-admin';
const labelClass = 'block text-2xs font-bold text-slate-600 mb-1';
</script>

<template>
  <Modal
    :title="isEdit ? $t('admin.staff.formEditTitle') : $t('admin.staff.formCreateTitle')"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- Nama -->
      <div>
        <label :class="labelClass">{{ $t('admin.staff.fieldName') }}</label>
        <input v-model="name" :class="inputClass" :placeholder="$t('admin.staff.fieldNamePlaceholder')" />
      </div>

      <!-- Email (create only; read-only in edit) -->
      <div>
        <label :class="labelClass">{{ $t('admin.staff.fieldEmail') }}</label>
        <input
          v-if="!isEdit"
          v-model="email"
          type="email"
          :class="inputClass"
          placeholder="nama@email.com"
        />
        <p
          v-else
          class="rounded-xl bg-slate-50 border border-slate-200 px-3 py-2.5 text-[13px] text-slate-500"
        >
          {{ staff?.email || '—' }}
        </p>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <!-- Jabatan -->
        <div>
          <label :class="labelClass">{{ $t('admin.staff.fieldPosition') }}</label>
          <input v-model="position" :class="inputClass" :placeholder="$t('admin.staff.fieldPositionPlaceholder')" />
        </div>
        <!-- No. HP -->
        <div>
          <label :class="labelClass">
            {{ $t('admin.staff.fieldPhone') }}
            <span class="text-slate-400 font-medium">{{ $t('admin.staff.optional') }}</span>
          </label>
          <input v-model="phone" :class="inputClass" placeholder="08…" />
        </div>
      </div>

      <!-- Akses (role) — create only -->
      <div v-if="!isEdit">
        <label :class="labelClass">{{ $t('admin.staff.fieldAccess') }}</label>
        <select v-model="roleId" :class="inputClass">
          <option :value="null">{{ $t('admin.staff.accessNone') }}</option>
          <option v-for="r in roles" :key="r.id" :value="r.id">{{ r.label }}</option>
        </select>
      </div>
      <!-- In edit mode the role is managed via RBAC; show it read-only. -->
      <div v-else>
        <label :class="labelClass">{{ $t('admin.staff.fieldAccess') }}</label>
        <p class="rounded-xl bg-slate-50 border border-slate-200 px-3 py-2.5 text-[13px] text-slate-600">
          {{ staff?.roles?.length ? staff.roles.map((r) => r.label).join(', ') : $t('admin.staff.noAccess') }}
        </p>
      </div>

      <!-- Password — create only -->
      <div v-if="!isEdit">
        <label :class="labelClass">{{ $t('admin.staff.fieldPassword') }}</label>
        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="rounded-xl border-2 p-2.5 text-left transition-colors"
            :class="pwMode === 'generate'
              ? 'border-role-admin bg-role-admin/5'
              : 'border-slate-200 bg-white hover:border-slate-300'"
            @click="pwMode = 'generate'"
          >
            <div class="flex items-center gap-1.5">
              <NavIcon name="refresh-cw" :size="12" />
              <span class="text-[12px] font-bold text-slate-900">{{ $t('admin.staff.pwGenerate') }}</span>
            </div>
            <p class="text-3xs text-slate-500 mt-0.5">{{ $t('admin.staff.pwGenerateHint') }}</p>
          </button>
          <button
            type="button"
            class="rounded-xl border-2 p-2.5 text-left transition-colors"
            :class="pwMode === 'manual'
              ? 'border-role-admin bg-role-admin/5'
              : 'border-slate-200 bg-white hover:border-slate-300'"
            @click="pwMode = 'manual'"
          >
            <div class="flex items-center gap-1.5">
              <NavIcon name="edit" :size="12" />
              <span class="text-[12px] font-bold text-slate-900">{{ $t('admin.staff.pwManual') }}</span>
            </div>
            <p class="text-3xs text-slate-500 mt-0.5">{{ $t('admin.staff.pwManualHint') }}</p>
          </button>
        </div>
        <div v-if="pwMode === 'manual'" class="relative mt-2">
          <input
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            :class="[inputClass, 'pr-10']"
            :placeholder="$t('admin.staff.pwPlaceholder')"
            @keyup.enter="submit"
          />
          <button
            type="button"
            class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
            @click="showPassword = !showPassword"
          >
            <NavIcon :name="showPassword ? 'eye-off' : 'eye'" :size="15" />
          </button>
        </div>
      </div>

      <p class="text-3xs text-slate-500 bg-slate-50 rounded-xl p-3 leading-relaxed">
        {{ isEdit ? $t('admin.staff.editHint') : $t('admin.staff.createHint') }}
      </p>

      <p v-if="err" class="text-2xs text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ err }}
      </p>

      <div class="grid grid-cols-2 gap-2 pt-1">
        <Button variant="secondary" block @click="emit('close')">{{ $t('common.cancel') }}</Button>
        <Button
          variant="primary"
          block
          :loading="isSaving"
          :disabled="isSaving || !canSubmit"
          @click="submit"
        >
          {{ $t('admin.staff.save') }}
        </Button>
      </div>
    </div>
  </Modal>
</template>
