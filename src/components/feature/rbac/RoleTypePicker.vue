<script setup lang="ts">
/**
 * Custom select for role_type. Renders the same swatches as the role
 * cards so the picker visually previews what the new role will look
 * like in the list.
 *
 * Native `<select>` would be simpler but doesn't let us render the
 * icon-tile + hint pair per option — and the field is one of only 4
 * inputs on the create form, so the cost of a custom control is small.
 */
import { computed, ref } from 'vue';
import type { RbacRoleType } from '@/types/rbac';
import { swatchFor } from './RoleTypeSwatch';

const props = defineProps<{
  modelValue: RbacRoleType;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: RbacRoleType): void;
}>();

const open = ref(false);

const OPTIONS: { value: RbacRoleType; label: string; hint: string }[] = [
  { value: 'admin', label: 'Admin', hint: 'Akses penuh ke sekolah ini' },
  { value: 'teacher', label: 'Guru', hint: 'Kelas + input nilai' },
  { value: 'parent', label: 'Wali Murid', hint: 'Lihat data anak (read-only)' },
  { value: 'student', label: 'Siswa', hint: 'Lihat data sendiri (read-only)' },
  {
    value: 'staff',
    label: 'Staff',
    hint: 'TU, bendahara, penjaga, satpam, front-office',
  },
];

const current = computed(
  () => OPTIONS.find((o) => o.value === props.modelValue) ?? OPTIONS[4],
);
const swatch = computed(() => swatchFor(current.value.value));

function pick(value: RbacRoleType) {
  emit('update:modelValue', value);
  open.value = false;
}
</script>

<template>
  <div class="rt-picker" :class="{ 'rt-picker--open': open }">
    <button
      type="button"
      class="rt-picker__trigger"
      @click="open = !open"
      :aria-expanded="open"
    >
      <span
        class="rt-picker__icon"
        :style="{ background: swatch.background, color: swatch.iconColor }"
        aria-hidden="true"
      />
      <span class="rt-picker__body">
        <span class="rt-picker__label">{{ current.label }}</span>
        <span class="rt-picker__hint">{{ current.hint }}</span>
      </span>
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
        <path
          d="M3 5 L7 10 L11 5"
          stroke="#94a3b8"
          stroke-width="1.6"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>
    <ul v-if="open" class="rt-picker__menu" role="listbox">
      <li v-for="opt in OPTIONS" :key="opt.value">
        <button
          type="button"
          class="rt-picker__opt"
          :class="{ 'rt-picker__opt--active': opt.value === modelValue }"
          @click="pick(opt.value)"
        >
          <span
            class="rt-picker__icon"
            :style="{
              background: swatchFor(opt.value).background,
              color: swatchFor(opt.value).iconColor,
            }"
            aria-hidden="true"
          />
          <span class="rt-picker__body">
            <span class="rt-picker__label">{{ opt.label }}</span>
            <span class="rt-picker__hint">{{ opt.hint }}</span>
          </span>
        </button>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.rt-picker {
  position: relative;
}
.rt-picker__trigger {
  display: grid;
  grid-template-columns: 24px 1fr 14px;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 10px 14px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  cursor: pointer;
  text-align: left;
}
.rt-picker__trigger:hover {
  border-color: #cbd5e1;
}
.rt-picker__icon {
  width: 24px;
  height: 24px;
  border-radius: 6px;
}
.rt-picker__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.rt-picker__label {
  font-size: 13px;
  font-weight: 700;
  color: #0f172a;
}
.rt-picker__hint {
  font-size: 10px;
  color: #64748b;
}
.rt-picker__menu {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  right: 0;
  margin: 0;
  padding: 6px;
  list-style: none;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.1);
  z-index: 10;
}
.rt-picker__opt {
  display: grid;
  grid-template-columns: 24px 1fr;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 8px 10px;
  background: transparent;
  border: 0;
  border-radius: 8px;
  cursor: pointer;
  text-align: left;
}
.rt-picker__opt:hover {
  background: #f1f5f9;
}
.rt-picker__opt--active {
  background: #e8eef7;
}
</style>
