<!--
  TagihReminderModal.vue — admin tagih reminder sheet.

  Picks a channel (WhatsApp / Email) and confirms sending. Logs the
  reminder server-side (POST /finance/bills/{id}/remind), incrementing
  reminder_count and stamping last_reminded_at. The actual outbound
  message is dispatched by a downstream job.
-->
<script setup lang="ts">
import { ref } from 'vue';
import { FinanceService } from '@/services/finance.service';
import type { Bill } from '@/types/billing';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatRupiah } from '@/lib/format';

const props = defineProps<{
  bills: Bill[]; // single or batch
}>();

const emit = defineEmits<{
  close: [];
  sent: [{ count: number; channel: 'whatsapp' | 'email' }];
}>();

const channel = ref<'whatsapp' | 'email'>('whatsapp');
const isSending = ref(false);
const error = ref<string | null>(null);

async function send() {
  isSending.value = true;
  error.value = null;
  let count = 0;
  try {
    for (const b of props.bills) {
      try {
        await FinanceService.remindBill(b.id, channel.value);
        count++;
      } catch (e) {
        // skip on per-bill error (e.g. already paid)
        if (!error.value) error.value = (e as Error).message;
      }
    }
    emit('sent', { count, channel: channel.value });
    emit('close');
  } finally {
    isSending.value = false;
  }
}

const totalOutstanding = props.bills.reduce((s, b) => s + b.amount, 0);
</script>

<template>
  <Modal
    title="Kirim Pengingat Tagihan"
    :subtitle="`${bills.length} tagihan akan diingatkan ke wali murid`"
    size="md"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <div class="bg-slate-50 rounded-xl p-3 flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-amber-100 text-amber-700 grid place-items-center">
          <NavIcon name="bell" :size="18" />
        </div>
        <div class="flex-1">
          <p class="text-[12px] font-bold text-slate-900">{{ bills.length }} tagihan</p>
          <p class="text-[11px] text-slate-500">
            Total: {{ formatRupiah(totalOutstanding) }}
          </p>
        </div>
      </div>

      <div>
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">
          Kanal pengingat
        </p>
        <div class="grid grid-cols-2 gap-2">
          <button
            type="button"
            class="rounded-xl p-3 text-left border-2 transition-all"
            :class="
              channel === 'whatsapp'
                ? 'border-emerald-500 bg-emerald-50'
                : 'border-slate-200 hover:border-slate-300'
            "
            @click="channel = 'whatsapp'"
          >
            <div class="flex items-center gap-2">
              <NavIcon name="message-circle" :size="16" class="text-emerald-700" />
              <span class="text-[13px] font-bold text-slate-900">WhatsApp</span>
            </div>
            <p class="text-[11px] text-slate-500 mt-1">Kirim via WA Business</p>
          </button>
          <button
            type="button"
            class="rounded-xl p-3 text-left border-2 transition-all"
            :class="
              channel === 'email'
                ? 'border-brand-cobalt bg-brand-cobalt/5'
                : 'border-slate-200 hover:border-slate-300'
            "
            @click="channel = 'email'"
          >
            <div class="flex items-center gap-2">
              <NavIcon name="mail" :size="16" class="text-brand-cobalt" />
              <span class="text-[13px] font-bold text-slate-900">Email</span>
            </div>
            <p class="text-[11px] text-slate-500 mt-1">Kirim via email wali</p>
          </button>
        </div>
      </div>

      <p v-if="error" class="text-[11px] text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
        {{ error }}
      </p>

      <div class="grid grid-cols-2 gap-2">
        <Button variant="secondary" block @click="emit('close')">Batal</Button>
        <Button
          variant="primary"
          block
          :loading="isSending"
          :disabled="isSending || bills.length === 0"
          @click="send"
        >
          Kirim Pengingat
        </Button>
      </div>
    </div>
  </Modal>
</template>
