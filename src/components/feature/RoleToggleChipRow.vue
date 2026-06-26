<!--
  RoleToggleChipRow.vue — horizontal chip strip for teacher role
  switching inside a brand gradient header.

  Web port of Flutter's `RoleToggleChipRow` (lib/core/widgets/
  role_toggle_chip_row.dart). Used by Schedule, Presensi, Activity
  Kelas, Gradebook, Rapor and Rekomendasi to let a teacher swap
  between their teaching schedule (Mengajar) and any homeroom
  classes they oversee (Parent 7B, Parent 8A …).

  Visual contract (mirrors Flutter `_RoleChip`):
    • Active chip:   solid white pill, brand-coloured avatar
                     circle, slate-900 label + slate-500 sub-label.
    • Inactive chip: 22% white solid fill, hairline white border,
                     40% white avatar circle, white label +
                     78%-white sub-label.

  Auto-hides when fewer than 2 roles exist — a one-option toggle
  is dead weight.
-->
<script setup lang="ts">
import { computed } from 'vue';

/** One option in the chip row. Mirrors Flutter's `RoleOption`. */
export interface RoleOption {
  /** Stable id returned in the update event. `'mengajar'` for the
   *  teaching view; `'parent:<classId>'` for homeroom chips. */
  id: string;
  /** Bold label inside the pill (e.g. `Mengajar`, `Parent 7B`). */
  shortName: string;
  /** Smaller sub-line below the label (e.g. `Kelas perwalian`). */
  subLabel?: string;
  /** Optional initials override for the avatar circle. */
  avatarInitials?: string;
}

const props = withDefaults(
  defineProps<{
    roles: RoleOption[];
    selectedRoleId: string;
    /** Active avatar fill colour. Defaults to brand cobalt. */
    accentColor?: string;
  }>(),
  {
    accentColor: '#1B6FB8',
  },
);

const emit = defineEmits<{
  'update:selectedRoleId': [string];
}>();

function initialsFor(role: RoleOption): string {
  if (role.avatarInitials && role.avatarInitials.length > 0) {
    return role.avatarInitials.toUpperCase();
  }
  const parts = role.shortName.trim().split(/\s+/);
  if (parts.length === 0 || parts[0].length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return (parts[0].slice(0, 1) + parts[parts.length - 1].slice(0, 1)).toUpperCase();
}

const visibleRoles = computed(() => props.roles);

function select(id: string) {
  if (id === props.selectedRoleId) return;
  emit('update:selectedRoleId', id);
}
</script>

<template>
  <!-- Hide entirely when the user has < 2 options. -->
  <div
    v-if="visibleRoles.length >= 2"
    role="tablist"
    class="flex items-stretch gap-1.5 w-full"
  >
    <button
      v-for="role in visibleRoles"
      :key="role.id"
      type="button"
      role="tab"
      :aria-selected="role.id === selectedRoleId"
      class="flex-1 min-w-0 inline-flex items-center gap-2 pl-1 pr-2.5 py-1 rounded-xl transition-all"
      :class="
        role.id === selectedRoleId
          ? 'bg-white shadow-sm'
          : 'bg-white/20 border border-white/70 hover:bg-white/25'
      "
      @click="select(role.id)"
    >
      <span
        class="w-6 h-6 rounded-full grid place-items-center text-[10px] font-bold leading-none flex-shrink-0"
        :style="
          role.id === selectedRoleId
            ? { background: accentColor, color: '#fff' }
            : { background: 'rgba(255,255,255,0.40)', color: '#fff' }
        "
      >
        {{ initialsFor(role) }}
      </span>
      <span class="flex flex-col items-start leading-none flex-1 min-w-0 text-left">
        <span
          class="text-[11px] font-bold truncate w-full"
          :class="role.id === selectedRoleId ? 'text-slate-900' : 'text-white'"
        >
          {{ role.shortName }}
        </span>
        <span
          v-if="role.subLabel"
          class="text-[9.5px] truncate w-full mt-0.5"
          :class="role.id === selectedRoleId ? 'text-slate-500' : 'text-white/80'"
        >
          {{ role.subLabel }}
        </span>
      </span>
    </button>
  </div>
</template>
