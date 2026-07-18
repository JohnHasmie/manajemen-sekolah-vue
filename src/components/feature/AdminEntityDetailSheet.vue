<!--
  AdminEntityDetailSheet.vue — shared read-only detail sheet for admin
  Manajemen Data pages (Student / Teacher / Kelas / Mapel).

  Mirrors Flutter's `showAdminEntityDetailSheet`. The host supplies the
  entity title + subtitle + grouped sections (key/value pairs grouped
  by header). Footer has Edit / Hapus buttons.

  Sections are passed as a structured array so the same component
  renders Identitas / Academic / Penugasan / etc.
-->
<script setup lang="ts">
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';

export interface DetailRow {
  label: string;
  value: string | number | null | undefined;
  /** Optional small caption under the value (e.g. "Aktif sejak ..."). */
  hint?: string | null;
}

export interface DetailSection {
  title: string;
  rows: DetailRow[];
}

defineProps<{
  /** Headline (top hero). */
  title: string;
  subtitle?: string | null;
  /** Optional initials avatar. */
  avatarName?: string;
  /** Optional accent color for hero avatar. Defaults to role-admin. */
  avatarColor?: string;
  /** Structured detail sections rendered as label/value rows. */
  sections: DetailSection[];
  /** Hide Edit/Hapus footer (read-only when AY locked). */
  readOnly?: boolean;
  /** Optional pill text under the title (status badge). */
  statusPill?: { label: string; tone: 'green' | 'amber' | 'red' | 'slate' };
  /**
   * When set, renders a "Reset Password" action (label text) above the
   * Edit/Hapus row and emits `reset-password`. Only entities with a login
   * account (guru, wali) pass this; kelas/mapel omit it.
   */
  resetPasswordLabel?: string;
  /**
   * When set, renders a "Cetak Kartu QR" (or caller-supplied label)
   * action above Edit/Hapus and emits `print-card`. Currently used by
   * the Data Siswa detail sheet — one-shot inline print of a student's
   * QR card without navigating to the full Kartu QR manager.
   */
  printCardLabel?: string;
  /** Disable + spinner state for the print-card action (per-row export). */
  printCardLoading?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  edit: [];
  delete: [];
  'reset-password': [];
  'print-card': [];
}>();
</script>

<template>
  <Modal :title="title" size="md" @close="emit('close')">
    <div class="space-y-4">
      <!-- Hero -->
      <section class="flex items-start gap-3 bg-slate-50 rounded-2xl p-4">
        <InitialsAvatar
          v-if="avatarName"
          :name="avatarName"
          :size="48"
          :border-radius="14"
          :color="avatarColor ?? '#143068'"
        />
        <div class="flex-1 min-w-0">
          <p class="text-[14px] font-black text-slate-900 truncate">{{ title }}</p>
          <p v-if="subtitle" class="text-2xs text-slate-500 truncate mt-0.5">{{ subtitle }}</p>
          <span
            v-if="statusPill"
            class="inline-block text-4xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full mt-2"
            :class="{
              'bg-emerald-100 text-emerald-700': statusPill.tone === 'green',
              'bg-amber-100 text-amber-700': statusPill.tone === 'amber',
              'bg-red-100 text-red-700': statusPill.tone === 'red',
              'bg-slate-100 text-slate-600': statusPill.tone === 'slate',
            }"
          >
            {{ statusPill.label }}
          </span>
        </div>
      </section>

      <!-- Sections -->
      <section
        v-for="(section, sIdx) in sections"
        :key="sIdx"
        class="space-y-2"
      >
        <h3 class="text-3xs font-bold text-slate-400 uppercase tracking-widest px-1">
          {{ section.title }}
        </h3>
        <div class="bg-white border border-slate-200 rounded-2xl divide-y divide-slate-100">
          <div
            v-for="(row, rIdx) in section.rows"
            :key="rIdx"
            class="px-3 py-2.5 flex items-start justify-between gap-3"
          >
            <span class="text-[12px] text-slate-500 flex-shrink-0">{{ row.label }}</span>
            <div class="text-right flex-1 min-w-0">
              <p class="text-[12px] font-bold text-slate-900 break-words">
                {{ row.value !== null && row.value !== undefined && row.value !== '' ? row.value : '—' }}
              </p>
              <p v-if="row.hint" class="text-3xs text-slate-400 mt-0.5">{{ row.hint }}</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Footer actions -->
      <section v-if="!readOnly" class="space-y-2 pt-2">
        <Button
          v-if="printCardLabel"
          variant="secondary"
          block
          :loading="!!printCardLoading"
          @click="emit('print-card')"
        >
          <NavIcon name="printer" :size="13" />
          {{ printCardLabel }}
        </Button>
        <Button
          v-if="resetPasswordLabel"
          variant="secondary"
          block
          @click="emit('reset-password')"
        >
          <NavIcon name="lock" :size="13" />
          {{ resetPasswordLabel }}
        </Button>
        <div class="grid grid-cols-2 gap-2">
          <Button variant="danger" block @click="emit('delete')">
            <NavIcon name="trash-2" :size="13" />
            Hapus
          </Button>
          <Button variant="primary" block @click="emit('edit')">
            <NavIcon name="edit" :size="13" />
            Edit
          </Button>
        </div>
      </section>
      <Button v-else variant="secondary" block @click="emit('close')">Tutup</Button>
    </div>
  </Modal>
</template>
