<!--
  ParentRecCompleteModal.vue — Frame E ("Tandai Selesai") sheet.

  Web port of Flutter's `parent_recommendation_complete_sheet.dart`.
  Confirms the parent applied the recommendation at home. Captures
  an optional note + a "notify teacher" toggle (defaults on).
-->
<script setup lang="ts">
import { ref } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  recommendationTitle: string;
  dueLabel?: string | null;
}>();

const emit = defineEmits<{
  close: [];
  /** Emits the confirmation payload — note (optional) + notifyTeacher flag. */
  confirm: [{ note: string; notifyTeacher: boolean }];
}>();

const note = ref('');
const notifyTeacher = ref(true);

function confirm() {
  emit('confirm', {
    note: note.value.trim(),
    notifyTeacher: notifyTeacher.value,
  });
}
</script>

<template>
  <Modal title="Tandai Selesai" size="lg" @close="emit('close')">
    <div class="space-y-4">
      <!-- Context card -->
      <section
        class="rounded-2xl border border-emerald-200 bg-emerald-50 p-3"
      >
        <div class="flex items-start gap-2.5">
          <div
            class="w-9 h-9 rounded-full bg-emerald-100 text-emerald-700 grid place-items-center flex-shrink-0"
          >
            <NavIcon name="check-circle" :size="18" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-2xs font-bold uppercase tracking-widest text-emerald-700">
              Konfirmasi penerapan
            </p>
            <p class="text-[13px] font-bold text-slate-900 mt-0.5 leading-snug">
              {{ recommendationTitle }}
            </p>
            <p
              v-if="dueLabel"
              class="text-2xs text-emerald-700/80 mt-1"
            >
              {{ dueLabel }}
            </p>
          </div>
        </div>
      </section>

      <!-- Note textarea (optional) -->
      <section>
        <label
          class="text-2xs font-bold uppercase tracking-widest text-slate-500 mb-1.5 block"
        >
          Catatan untuk wali kelas
          <span class="normal-case font-medium tracking-normal text-slate-400">
            · opsional
          </span>
        </label>
        <textarea
          v-model="note"
          rows="4"
          placeholder="Mis. Sudah dipraktikkan di rumah selama 3 hari…"
          class="w-full text-[13px] text-slate-800 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 leading-relaxed focus:outline-none focus:ring-2 focus:ring-role-wali/30 focus:border-role-wali"
        ></textarea>
      </section>

      <!-- Notify toggle -->
      <label
        class="flex items-start gap-3 p-3 rounded-xl border border-slate-200 bg-white cursor-pointer hover:bg-slate-50 transition"
      >
        <input
          v-model="notifyTeacher"
          type="checkbox"
          class="mt-0.5 w-4 h-4 accent-role-wali"
        />
        <div class="flex-1">
          <p class="text-[12.5px] font-bold text-slate-900">
            Beri tahu wali kelas
          </p>
          <p class="text-2xs text-slate-500 mt-0.5">
            Status rekomendasi juga akan ditandai selesai di sisi guru.
          </p>
        </div>
      </label>

      <!-- Footer -->
      <div class="flex gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" @click="emit('close')">Batal</Button>
        <Button block @click="confirm">Tandai Selesai</Button>
      </div>
    </div>
  </Modal>
</template>
