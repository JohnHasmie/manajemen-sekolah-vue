<!--
  ParentRecReplyModal.vue — Frame D ("Balas Homeroom Teacher") sheet.

  Web port of Flutter's `parent_recommendation_reply_sheet.dart`. Quick-
  reply chip strip (taps append, stacking nicely) plus a free-form
  Pesan textarea. Emits the trimmed reply on send.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';

const props = defineProps<{
  teacherName: string;
  subjectName?: string | null;
  initialText?: string | null;
}>();

const emit = defineEmits<{
  close: [];
  send: [string];
}>();

const text = ref(props.initialText ?? '');
const subtitle = computed(() =>
  props.subjectName
    ? `${props.teacherName} · ${props.subjectName}`
    : props.teacherName,
);

const QUICK_REPLIES = [
  '🙏 Terima kasih',
  '✅ Akan saya coba',
  '❓ Butuh penjelasan lebih',
  '🗓️ Bisa kapan saja',
  '⏰ Mungkin minggu depan',
];

function applyQuick(snippet: string) {
  const existing = text.value.trim();
  text.value = existing ? `${existing}\n${snippet}` : snippet;
}

const canSend = computed(() => text.value.trim().length > 0);

function send() {
  if (!canSend.value) return;
  emit('send', text.value.trim());
}
</script>

<template>
  <Modal title="Balas Wali Kelas" :subtitle="subtitle" size="lg" @close="emit('close')">
    <div class="space-y-4">
      <!-- Quick replies -->
      <section>
        <div class="flex items-baseline justify-between mb-2">
          <p class="text-2xs font-bold uppercase tracking-widest text-slate-500">
            Balasan cepat
          </p>
          <p class="text-3xs text-slate-400">· tap untuk pakai</p>
        </div>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="snippet in QUICK_REPLIES"
            :key="snippet"
            type="button"
            class="px-3 py-1.5 rounded-full border border-slate-200 bg-white text-2xs font-bold text-slate-700 hover:border-role-wali/40 hover:bg-role-wali/5 transition"
            @click="applyQuick(snippet)"
          >
            {{ snippet }}
          </button>
        </div>
      </section>

      <!-- Pesan textarea -->
      <section>
        <label
          class="text-2xs font-bold uppercase tracking-widest text-slate-500 mb-1.5 block"
        >
          Pesan untuk wali kelas
        </label>
        <textarea
          v-model="text"
          rows="5"
          placeholder="Tulis balasan Anda di sini…"
          class="w-full text-[13px] text-slate-800 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 leading-relaxed focus:outline-none focus:ring-2 focus:ring-role-wali/30 focus:border-role-wali"
        ></textarea>
        <p class="text-3xs text-slate-400 mt-1">
          {{ text.trim().length }} karakter
        </p>
      </section>

      <!-- Footer -->
      <div class="flex gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" @click="emit('close')">Batal</Button>
        <Button block :disabled="!canSend" @click="send">Kirim Balasan</Button>
      </div>
    </div>
  </Modal>
</template>
