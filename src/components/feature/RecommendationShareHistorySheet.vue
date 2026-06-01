<!--
  RecommendationShareHistorySheet.vue — Riwayat Pengiriman (Frame J).

  Web port of `recommendation_share_history_sheet.dart`. Cobalt-themed
  modal showing the per-recipient timeline + Ingatkan Ulang / Tarik
  Pesan / Edit & Kirim Ulang actions.

  Layout per recipient:
    ┌─────────────────────────────────────────────────────────┐
    │ 👤 Bu Sari (Ibu)                          [⋮ Aksi]      │
    │ ─────────────────────────────────────────                │
    │ ● Dikirim   30 Mei 09:00                                 │
    │ │           via Push + WA                                │
    │ ● Dibaca    30 Mei 11:14                                 │
    │ │                                                        │
    │ ● Dibalas   30 Mei 13:42                                 │
    │   "Siap Pak, akan kami dampingi malam ini."             │
    └─────────────────────────────────────────────────────────┘

  Per-recipient actions (header pop-up):
    - Ingatkan Ulang → restamp sent_at + bump resend_count
    - Tarik Pesan    → revoke + grey out the row
    - Edit & Kirim Ulang → opens a mini inline editor below the row

  Footer: Bagikan Lagi → closes this sheet + opens share sheet for
  a fresh send (parent does the swap).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { RecommendationService } from '@/services/recommendations.service';
import {
  TONE_LABELS,
  type LearningRecommendation,
  type RecShareRecipient,
  type RecTone,
} from '@/types/recommendations';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import { formatRelative } from '@/lib/format';

const props = defineProps<{
  rec: LearningRecommendation;
}>();

const emit = defineEmits<{
  close: [];
  /** User hit "Bagikan Lagi" — parent swaps in the share sheet. */
  openShare: [];
  /**
   * Any per-recipient action succeeded; parent should refetch the rec
   * detail to pull the latest share_recipients + counters.
   */
  changed: [];
}>();

// ── State ──
const recipients = ref<RecShareRecipient[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
// Per-recipient in-flight flag — keyed by recipient.id so multiple
// actions on different rows don't cross-disable.
const busyIds = ref<Set<string>>(new Set());
const openActionFor = ref<string | null>(null);
// Inline edit editor state — only one row open at a time.
const editingFor = ref<string | null>(null);
const editMessage = ref<string>('');
const editTone = ref<RecTone>('warm');

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    recipients.value = await RecommendationService.getShareStatus(props.rec.id);
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

// ── Helpers ──
function fmtIso(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
}

function channelLabel(r: RecShareRecipient): string {
  const c = r.channels;
  if (!c) return '';
  const parts: string[] = [];
  if (c.push) parts.push('Push');
  if (c.whatsapp) parts.push('WA');
  return parts.length > 0 ? `via ${parts.join(' + ')}` : '';
}

function isRevoked(r: RecShareRecipient): boolean {
  return !!r.revoked_at;
}

function toggleActions(id: string) {
  openActionFor.value = openActionFor.value === id ? null : id;
}

// ── Actions ──
async function remind(r: RecShareRecipient) {
  busyIds.value.add(r.id);
  openActionFor.value = null;
  try {
    await RecommendationService.remindRecipient({
      rec_id: props.rec.id,
      recipient_id: r.id,
    });
    await load();
    emit('changed');
  } finally {
    busyIds.value.delete(r.id);
  }
}

// Confirm modal for "Tarik Pesan" — captures the target row so the
// dialog's Confirm handler can call the actual revoke once the
// teacher accepts.
const revokeTarget = ref<RecShareRecipient | null>(null);

function revoke(r: RecShareRecipient) {
  openActionFor.value = null;
  revokeTarget.value = r;
}

async function confirmRevoke() {
  const r = revokeTarget.value;
  revokeTarget.value = null;
  if (!r) return;
  busyIds.value.add(r.id);
  try {
    await RecommendationService.revokeRecipient({
      rec_id: props.rec.id,
      recipient_id: r.id,
    });
    await load();
    emit('changed');
  } finally {
    busyIds.value.delete(r.id);
  }
}

function openEdit(r: RecShareRecipient) {
  editingFor.value = r.id;
  editMessage.value = r.last_message ?? '';
  editTone.value = (r.last_tone as RecTone) ?? 'warm';
  openActionFor.value = null;
}

async function saveEdit(r: RecShareRecipient) {
  busyIds.value.add(r.id);
  try {
    await RecommendationService.editAndResendRecipient({
      rec_id: props.rec.id,
      recipient_id: r.id,
      message: editMessage.value.trim() || undefined,
      tone: editTone.value,
    });
    editingFor.value = null;
    await load();
    emit('changed');
  } finally {
    busyIds.value.delete(r.id);
  }
}

const TONE_OPTIONS: { key: RecTone; emoji: string; label: string }[] = [
  { key: 'warm', emoji: '😊', label: TONE_LABELS.warm },
  { key: 'formal', emoji: '📋', label: TONE_LABELS.formal },
  { key: 'concise', emoji: '⚡', label: TONE_LABELS.concise },
  { key: 'detailed', emoji: '🎯', label: TONE_LABELS.detailed },
];

// Derive a per-recipient ordered timeline of events for rendering.
function timelineFor(r: RecShareRecipient): Array<{
  key: 'sent' | 'delivered' | 'read' | 'replied' | 'revoked';
  label: string;
  iso?: string | null;
  reply?: string | null;
  channel?: string;
}> {
  const out: ReturnType<typeof timelineFor> = [];
  if (r.sent_at) {
    out.push({
      key: 'sent',
      label: r.resend_count && r.resend_count > 1
        ? `Dikirim ulang (${r.resend_count}×)`
        : 'Dikirim',
      iso: r.sent_at,
      channel: channelLabel(r),
    });
  }
  if (r.delivered_at) {
    out.push({ key: 'delivered', label: 'Tersampaikan', iso: r.delivered_at });
  }
  if (r.read_at) {
    out.push({ key: 'read', label: 'Dibaca', iso: r.read_at });
  }
  if (r.replied_at) {
    out.push({
      key: 'replied',
      label: 'Dibalas',
      iso: r.replied_at,
      reply: r.reply_text,
    });
  }
  if (r.revoked_at) {
    out.push({ key: 'revoked', label: 'Ditarik', iso: r.revoked_at });
  }
  return out;
}

const TIMELINE_TONE: Record<
  'sent' | 'delivered' | 'read' | 'replied' | 'revoked',
  { dot: string; text: string }
> = {
  sent: { dot: 'bg-brand-cobalt', text: 'text-brand-cobalt' },
  delivered: { dot: 'bg-slate-400', text: 'text-slate-600' },
  read: { dot: 'bg-emerald-500', text: 'text-emerald-700' },
  replied: { dot: 'bg-violet-600', text: 'text-violet-700' },
  revoked: { dot: 'bg-red-500', text: 'text-red-700' },
};

const hasAnyRecipient = computed(() => recipients.value.length > 0);
</script>

<template>
  <Modal
    title="Riwayat Pengiriman"
    :subtitle="rec.title"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-3">
      <!-- LOADING -->
      <div v-if="isLoading" class="py-8 text-center">
        <div class="inline-block w-6 h-6 rounded-full border-2 border-slate-200 border-t-brand-cobalt animate-spin" />
        <p class="text-[11px] text-slate-500 mt-3">Memuat riwayat…</p>
      </div>

      <!-- ERROR -->
      <div
        v-else-if="loadError"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-3 text-[12px] text-red-700"
      >
        <p class="font-bold mb-1">Gagal memuat riwayat</p>
        <p>{{ loadError }}</p>
        <button
          type="button"
          class="mt-2 text-[11px] font-bold text-red-700 underline"
          @click="load"
        >
          Coba lagi
        </button>
      </div>

      <!-- EMPTY -->
      <div v-else-if="!hasAnyRecipient" class="py-6 text-center">
        <span class="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-slate-100 text-slate-400">
          <NavIcon name="send" :size="20" />
        </span>
        <p class="text-[13px] font-bold text-slate-700 mt-3">Belum ada pengiriman</p>
        <p class="text-[11px] text-slate-500 mt-1">
          Tap "Bagikan Lagi" di bawah untuk mulai mengirim ke wali.
        </p>
      </div>

      <!-- RECIPIENTS -->
      <div v-else class="space-y-3">
        <article
          v-for="r in recipients"
          :key="r.id"
          class="bg-white border border-slate-200 rounded-2xl px-3.5 py-3"
          :class="isRevoked(r) ? 'opacity-60' : ''"
        >
          <!-- HEADER -->
          <div class="flex items-center gap-2.5">
            <span
              class="w-9 h-9 rounded-xl bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0 text-[12px] font-black"
            >
              {{ r.parent_name.slice(0, 1).toUpperCase() }}
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[12.5px] font-bold text-slate-900 truncate">
                {{ r.parent_name }}
              </p>
              <p class="text-[10.5px] text-slate-500 mt-0.5">
                <template v-if="r.parent_relation">
                  {{ r.parent_relation }}
                </template>
                <template v-else>Wali</template>
                <template v-if="r.resend_count && r.resend_count > 1">
                  · {{ r.resend_count }}× kirim
                </template>
              </p>
            </div>
            <!-- Action menu trigger -->
            <div class="relative">
              <button
                type="button"
                class="w-7 h-7 rounded-lg grid place-items-center text-slate-500 hover:bg-slate-100"
                :disabled="busyIds.has(r.id) || isRevoked(r)"
                :aria-label="`Aksi untuk ${r.parent_name}`"
                @click="toggleActions(r.id)"
              >
                <NavIcon name="list" :size="13" />
              </button>
              <!-- Pop-out menu -->
              <div
                v-if="openActionFor === r.id"
                class="absolute right-0 top-8 z-10 w-44 bg-white border border-slate-200 rounded-xl shadow-lg py-1"
              >
                <button
                  type="button"
                  class="w-full text-left px-3 py-2 text-[12px] hover:bg-slate-50 flex items-center gap-2"
                  @click="remind(r)"
                >
                  <NavIcon name="bell" :size="12" />
                  Ingatkan Ulang
                </button>
                <button
                  type="button"
                  class="w-full text-left px-3 py-2 text-[12px] hover:bg-slate-50 flex items-center gap-2"
                  @click="openEdit(r)"
                >
                  <NavIcon name="edit" :size="12" />
                  Edit & Kirim Ulang
                </button>
                <button
                  type="button"
                  class="w-full text-left px-3 py-2 text-[12px] text-red-700 hover:bg-red-50 flex items-center gap-2"
                  @click="revoke(r)"
                >
                  <NavIcon name="x" :size="12" />
                  Tarik Pesan
                </button>
              </div>
            </div>
          </div>

          <!-- TIMELINE -->
          <div class="relative mt-3 pl-4">
            <span
              class="absolute left-[5px] top-1 bottom-1 w-px bg-slate-200"
              aria-hidden="true"
            />
            <div
              v-for="(ev, idx) in timelineFor(r)"
              :key="ev.key + idx"
              class="relative pb-2 last:pb-0"
            >
              <span
                class="absolute -left-4 top-1 w-2.5 h-2.5 rounded-full ring-2 ring-white"
                :class="TIMELINE_TONE[ev.key].dot"
              />
              <div class="flex items-baseline gap-2 flex-wrap">
                <span
                  class="text-[11.5px] font-bold"
                  :class="TIMELINE_TONE[ev.key].text"
                >
                  {{ ev.label }}
                </span>
                <span class="text-[10.5px] text-slate-400 tabular-nums">
                  {{ fmtIso(ev.iso) }}
                  <template v-if="ev.iso">
                    · {{ formatRelative(ev.iso) }}
                  </template>
                </span>
              </div>
              <p
                v-if="ev.channel"
                class="text-[10.5px] text-slate-500 mt-0.5"
              >
                {{ ev.channel }}
              </p>
              <blockquote
                v-if="ev.reply"
                class="mt-1.5 text-[12px] text-violet-900 leading-relaxed border-l-2 border-violet-300 pl-2.5 italic"
              >
                {{ ev.reply }}
              </blockquote>
            </div>
          </div>

          <!-- Inline editor (Edit & Kirim Ulang) -->
          <div
            v-if="editingFor === r.id"
            class="mt-3 pt-3 border-t border-slate-100 space-y-2"
          >
            <div class="flex flex-wrap gap-1">
              <button
                v-for="opt in TONE_OPTIONS"
                :key="opt.key"
                type="button"
                class="px-2.5 py-1 rounded-full text-[10.5px] font-bold transition border inline-flex items-center gap-1"
                :class="
                  editTone === opt.key
                    ? 'bg-brand-cobalt text-white border-brand-cobalt'
                    : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
                "
                @click="editTone = opt.key"
              >
                <span>{{ opt.emoji }}</span>
                {{ opt.label }}
              </button>
            </div>
            <textarea
              v-model="editMessage"
              rows="2"
              placeholder="Ubah pesan…"
              class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[12px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-y"
              :disabled="busyIds.has(r.id)"
            />
            <div class="flex items-center gap-2">
              <Button
                variant="secondary"
                size="sm"
                @click="editingFor = null"
              >
                Batal
              </Button>
              <Button
                variant="primary"
                size="sm"
                :loading="busyIds.has(r.id)"
                @click="saveEdit(r)"
              >
                <NavIcon name="send" :size="12" />
                Kirim Ulang
              </Button>
            </div>
          </div>
        </article>
      </div>

      <!-- FOOTER -->
      <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
        <Button variant="secondary" block @click="emit('close')">
          Tutup
        </Button>
        <Button variant="primary" block @click="emit('openShare')">
          <NavIcon name="send" :size="13" />
          Bagikan Lagi
        </Button>
      </div>
    </div>

    <ConfirmationDialog
      v-if="revokeTarget"
      title="Tarik pesan rekomendasi"
      :message="`Tarik pesan ke ${revokeTarget.parent_name}? Mereka tidak akan bisa membuka pesan lagi.`"
      confirm-label="Tarik pesan"
      danger
      @close="revokeTarget = null"
      @confirm="confirmRevoke"
    />
  </Modal>
</template>
