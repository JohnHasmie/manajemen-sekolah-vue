<!--
  AdminTutoring2VoucherRecipientsSheet.vue — "Penerima voucher", the
  admin surface for aiming one promo code at named students.

  ── WHY IT EXISTS ───────────────────────────────────────────────────

  A bimbel voucher used to be a code plus a usage quota and NOTHING
  ELSE — no owner. That absence is also why wali were never shown a
  voucher list: with no property to narrow by, any parent-facing list
  would have handed every parent every promo code in the lembaga.

  `bimbel_voucher_recipients` supplies the missing owner, and these are
  the only controls that write it. Until an admin can pick recipients,
  no voucher has any, and every voucher in every tenant stays general by
  default.

  ── A RECIPIENT IS A STUDENT, NOT A USER OR A WALI ──────────────────

  Deliberate backend decision, mirrored here rather than softened.
  Redemption is already per-student via `enrollment_id`, so targeting a
  user account would sit COARSER than the guard enforcing it: a wali
  with two children could discount the wrong child's bill. The picker
  below therefore chooses students, and `student_ids` is what goes on
  the wire.

  ── THE WIRE CONTRACT ───────────────────────────────────────────────

  Read off `routes/api.php` + `VoucherController` + the FormRequest, not
  assumed:

    GET    /tutoring-v2/vouchers/{id}/recipients
             → VoucherController::recipients     → `tutoring.voucher.view`
    POST   /tutoring-v2/vouchers/{id}/recipients
             → VoucherController::attachRecipients → `tutoring.voucher.manage`
             body: { student_ids: uuid[] }  required | min:1 | max:500 | distinct
    DELETE /tutoring-v2/vouchers/{id}/recipients/{studentId}
             → VoucherController::detachRecipient  → `tutoring.voucher.manage`

  THE READ AND THE WRITES DO NOT SHARE A KEY, which is why this sheet
  takes TWO booleans rather than one. Read-only staff hold
  `tutoring.voucher.view` and are entitled to see who a promo is aimed
  at; only `.manage` may change it. Collapsing both into a single
  `canManage` would have hidden a list those staff are allowed to read.

  The read key is also deliberately the TENANT-WIDE `.view` and not the
  wali-scoped `.view_own`: "who else holds this promo" is precisely the
  question a parent must never be able to ask.

  ── BOTH WRITES ARE IDEMPOTENT, AND 0 IS A SUCCESS ──────────────────

  Re-attaching an existing recipient returns `attached_count: 0`;
  detaching a non-recipient returns `detached_count: 0`. Neither is an
  error — the end state the admin asked for is already true — so the
  toast says so instead of reporting a failure.

  ── THE TWO DIRECTIONS ARE NOT SYMMETRIC, AND THE COPY SAYS SO ──────

  Attaching the FIRST recipient NARROWS a code that may already be
  circulating: from then on only the named students may redeem it, and
  `RedeemVoucherAction` holds an admin redeeming on a family's behalf to
  the same rule. A narrowing cannot leak anything, but it is a real
  behaviour change and the sheet warns before it, not after.

  Detaching the LAST recipient WIDENS the voucher back to a general
  promo — "no recipients" is by definition untargeted, so the code
  becomes spendable by anyone who knows it, capped only by
  `max_redemptions`. That is the one operation here that loosens access,
  and a reader who only saw the button label would expect the opposite,
  so the warning is on screen BEFORE the last Hapus is pressed.

  ── ONE OVERLAY, NOT TWO ────────────────────────────────────────────

  Built on `Modal` with a plain `FormField type="select"` picker and NO
  nested dialog, for the reason AdminTutoring2BillCreateSheet and
  AdminTutoring2GroupAddStudentSheet both record: a second Modal on top
  (FilterFacetPickerModal, ConfirmationDialog) stacks two
  `Teleport to="body"` overlays at the same z-50 with two ESC handlers,
  and no screen in the repo does that. The "last recipient" confirmation
  is therefore an inline warning line, not a confirm dialog.

  `students` is a tenant-sized table, so the picker carries a debounced
  "Cari siswa" field that refetches with `?search=` — server-side,
  because a client-side filter over "the page we happened to load"
  reports "no match" for a student who exists.

  ── THE PICKER PAGE IS A PAGE, AND SAYS SO ──────────────────────────

  `StudentController::index` caps `per_page` server-side:
  `paginate(min((int) $request->input('per_page', 20), 100))`. Asking
  for more than 100 silently returns 100. This sheet asks for
  PICKER_PAGE_SIZE and, when the server fills the page, says out loud
  that the list is partial rather than letting an admin conclude a
  student does not exist.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import Modal from '@/components/ui/Modal.vue';
import { useToast } from '@/composables/useToast';
import { extractError } from '@/lib/api-error';
import { isCounted } from '@/lib/absent-vs-zero';
import { VouchersService } from '@/services/tutoring2/vouchers';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type { BimbelStudent } from '@/types/tutoring2/student';
import type {
  BimbelVoucher,
  BimbelVoucherRecipient,
} from '@/types/tutoring2/voucher';

const props = withDefaults(
  defineProps<{
    /** The voucher whose recipients are being managed. */
    voucher: BimbelVoucher;
    /**
     * Whether the caller holds `tutoring.voucher.manage` — the key the
     * ATTACH and DETACH routes authorize.
     *
     * Resolved by the parent from `/me` abilities and injected, the way
     * AdminTutoring2BillCreateSheet takes `canViewPaymentTypes`: it
     * keeps this component a plain panel with two booleans, which is
     * also what makes the without-the-ability case testable without
     * faking a store.
     */
    canManage?: boolean;
  }>(),
  { canManage: false },
);

const emit = defineEmits<{
  close: [];
  /**
   * The refreshed voucher row handed back by whichever write just ran.
   *
   * Emitted rather than swallowed because it carries the new
   * `recipient_count` / `is_targeted`, and the list behind this sheet
   * renders the general-vs-personal badge off exactly those two keys.
   * A parent that ignores this must reload instead — what it must not
   * do is leave the badge showing the pre-write state.
   */
  changed: [voucher: BimbelVoucher];
}>();

const { t } = useI18n();
const toast = useToast();

/**
 * One page of picker rows. 50 rather than 100 for the same reason the
 * sibling sheets pick it: a select with 100 options is not a usable
 * control, and the search box is the real way to reach the rest. The
 * server would cap us at 100 anyway — see the header.
 */
const PICKER_PAGE_SIZE = 50;

// ── Current recipients ──────────────────────────────────────────────

const recipients = ref<BimbelVoucherRecipient[]>([]);
const recipientsLoading = ref(true);
const recipientsError = ref<string | null>(null);

async function loadRecipients(): Promise<void> {
  recipientsLoading.value = true;
  recipientsError.value = null;
  try {
    recipients.value = await VouchersService.listRecipients(props.voucher.id);
  } catch (err) {
    recipients.value = [];
    recipientsError.value =
      extractError(err) ?? t('tutoring2.admin.voucherRecipients.loadError');
  } finally {
    recipientsLoading.value = false;
  }
}

/**
 * `recipients.length` and not `props.voucher.recipient_count`.
 *
 * The prop is a snapshot taken when the list page was fetched; this ref
 * is what the recipients endpoint just said. After an attach or detach
 * the two disagree until the parent reloads, and the warning lines below
 * must describe the state the admin is looking at.
 */
const recipientCount = computed(() => recipients.value.length);

/** Zero recipients IS the general-promo state — not a missing answer. */
const isGeneral = computed(
  () => !recipientsLoading.value && recipientCount.value === 0,
);

/**
 * Shown before the FIRST attach. The narrowing is real and immediate, so
 * it is stated before the button rather than in a toast afterwards.
 */
const willBecomePersonal = computed(
  () => props.canManage && isGeneral.value && staged.value.length > 0,
);

/**
 * Shown while exactly one recipient remains: removing it widens the
 * voucher back to a code anyone who knows it may spend. This replaces
 * the confirm dialog a second Modal would have required.
 */
const removingLastWidens = computed(
  () => props.canManage && recipientCount.value === 1,
);

function recipientLabel(r: BimbelVoucherRecipient): string {
  const name =
    r.student_name?.trim() || t('tutoring2.admin.voucherRecipients.unnamed');
  const number = r.student_number?.trim();
  return number ? `${name} · ${number}` : name;
}

// ── The student picker ──────────────────────────────────────────────

const students = ref<BimbelStudent[]>([]);
const studentsLoading = ref(false);
/**
 * Set when the student list could not be fetched at all — most likely a
 * 403, because `StudentController::index` authorizes
 * `tutoring.student.view`, a DIFFERENT key from the voucher ones this
 * sheet is gated on. An admin who holds `tutoring.voucher.manage` but
 * not `tutoring.student.view` gets a named reason here instead of an
 * empty dropdown that reads as "this tenant has no students".
 */
const studentsError = ref<string | null>(null);
const studentSearch = ref('');
/** Transient: the select resets to '' the moment its value is staged. */
const picker = ref('');

async function loadStudents(): Promise<void> {
  studentsLoading.value = true;
  studentsError.value = null;
  const query = studentSearch.value.trim();
  try {
    const res = await TutoringStudentsService.list({
      per_page: PICKER_PAGE_SIZE,
      // Stated explicitly rather than left to the default: omitting it
      // does NOT mean "all" on the server, which reads a missing param
      // as true.
      active: true,
      ...(query ? { search: query } : {}),
    });
    students.value = res.items;
  } catch (err) {
    students.value = [];
    studentsError.value =
      extractError(err) ?? t('tutoring2.admin.voucherRecipients.studentsError');
  } finally {
    studentsLoading.value = false;
  }
}

const debouncedStudentReload = useDebounceFn(() => void loadStudents(), 300);
watch(studentSearch, () => debouncedStudentReload());

/** Already a recipient — attaching again is a server-side no-op. */
const attachedStudentIds = computed(
  () => new Set(recipients.value.map((r) => r.student_id)),
);

// ── Staging ─────────────────────────────────────────────────────────
//
// The endpoint takes an ARRAY of up to 500 ids, so naming several
// students is one request, not one per student. Choosing from the select
// stages a student (and clears the select) rather than posting
// immediately: an admin aiming a promo at a family should decide the
// whole list before the voucher narrows, because the first attach is
// what flips the code from general to personal.

interface StagedStudent {
  id: string;
  label: string;
}

const staged = ref<StagedStudent[]>([]);
const stagedIds = computed(() => new Set(staged.value.map((s) => s.id)));

function studentLabel(s: BimbelStudent): string {
  const name =
    s.name.trim() || t('tutoring2.admin.voucherRecipients.unnamed');
  const number = s.student_number?.trim();
  return number ? `${name} · ${number}` : name;
}

const studentOptions = computed<FormFieldOption[]>(() =>
  students.value
    .filter(
      (s) => !attachedStudentIds.value.has(s.id) && !stagedIds.value.has(s.id),
    )
    .map((s) => ({ value: s.id, label: studentLabel(s) })),
);

/**
 * True when the server filled a whole page, so the list in hand is
 * PROVABLY partial. Said out loud: an admin who cannot find a student
 * needs to know they are looking at a page, not at the roster.
 */
const studentsTruncated = computed(
  () => students.value.length >= PICKER_PAGE_SIZE,
);

watch(picker, (value) => {
  if (!value) return;
  const student = students.value.find((s) => s.id === value);
  // Reset first, so the select is empty again whether or not the row
  // resolved — a select stuck on a value it cannot stage is a dead
  // control.
  picker.value = '';
  if (!student) return;
  if (attachedStudentIds.value.has(student.id)) return;
  if (stagedIds.value.has(student.id)) return;
  staged.value = [...staged.value, { id: student.id, label: studentLabel(student) }];
});

function unstage(id: string): void {
  staged.value = staged.value.filter((s) => s.id !== id);
}

// ── Writes ──────────────────────────────────────────────────────────

const saving = ref(false);
/** The student_id currently being detached — disables just that row. */
const detachingId = ref<string | null>(null);

const busy = computed(() => saving.value || detachingId.value !== null);

async function submitAttach(): Promise<void> {
  if (!props.canManage) return;
  // `student_ids` is `required|array|min:1` — an empty array is a 422,
  // not a way to clear the list. Refuse locally rather than sending one
  // and reading the rejection back.
  if (staged.value.length === 0) return;
  if (busy.value) return;

  saving.value = true;
  try {
    const result = await VouchersService.attachRecipients(
      props.voucher.id,
      staged.value.map((s) => s.id),
    );
    staged.value = [];
    // Refresh the list from the server rather than splicing the staged
    // rows in: the response carries a voucher, not recipients, and the
    // denormalised student labels come from the recipients endpoint.
    await loadRecipients();
    emit('changed', result.voucher);
    toast.success(
      result.changedCount === 0
        ? t('tutoring2.admin.voucherRecipients.attachNoop')
        : t('tutoring2.admin.voucherRecipients.attachSuccess', {
            count: result.changedCount,
          }),
    );
  } catch (err) {
    toast.error(
      extractError(err) ??
        t('tutoring2.admin.voucherRecipients.attachFailed'),
    );
  } finally {
    saving.value = false;
  }
}

async function detach(recipient: BimbelVoucherRecipient): Promise<void> {
  if (!props.canManage) return;
  if (busy.value) return;

  detachingId.value = recipient.student_id;
  try {
    const result = await VouchersService.detachRecipient(
      props.voucher.id,
      // The STUDENT id, not the recipient-row id: the route is
      // `…/recipients/{studentId}` and the action deletes by
      // `student_id`. Sending `recipient.id` would delete nothing and
      // report a cheerful `detached_count: 0`.
      recipient.student_id,
    );
    await loadRecipients();
    emit('changed', result.voucher);
    toast.success(
      result.changedCount === 0
        ? t('tutoring2.admin.voucherRecipients.detachNoop')
        : t('tutoring2.admin.voucherRecipients.detachSuccess'),
    );
  } catch (err) {
    toast.error(
      extractError(err) ??
        t('tutoring2.admin.voucherRecipients.detachFailed'),
    );
  } finally {
    detachingId.value = null;
  }
}

onMounted(() => {
  void loadRecipients();
  // Only fetched when the caller can actually write: a read-only viewer
  // has nothing to do with a picker, and the students endpoint gates on
  // a key they may not hold.
  if (props.canManage) void loadStudents();
});

/**
 * Kept so the "server said nothing" case stays distinguishable in the
 * subtitle. `recipient_count` is `isset`-gated server-side, so an absent
 * key means the payload came from a path that did not run
 * `withRecipientCount()` — not that the voucher has no recipients.
 */
const snapshotCounted = computed(() => isCounted(props.voucher.recipient_count));
</script>

<template>
  <Modal
    testid="voucher-recipients-sheet"
    :title="t('tutoring2.admin.voucherRecipients.title')"
    :subtitle="t('tutoring2.admin.voucherRecipients.subtitle', { code: props.voucher.code })"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-md">
      <!--
        The general-vs-personal state, in words. An admin who cannot tell
        the two apart hands out the wrong code.
      -->
      <p
        v-if="!recipientsLoading && !recipientsError"
        data-testid="recipients-nature"
        class="rounded-xl px-3 py-2 text-xs font-semibold"
        :class="isGeneral ? 'bg-slate-100 text-slate-600' : 'bg-brand-cobalt/10 text-brand-cobalt'"
      >
        {{
          isGeneral
            ? t('tutoring2.admin.voucherRecipients.natureGeneral')
            : t('tutoring2.admin.voucherRecipients.naturePersonal', { count: recipientCount })
        }}
      </p>

      <p v-if="recipientsLoading" data-testid="recipients-loading" class="text-xs text-slate-500">
        {{ t('tutoring2.common.loading') }}
      </p>

      <div v-else-if="recipientsError" data-testid="recipients-error" class="space-y-2">
        <p role="alert" class="rounded-xl bg-red-50 px-3 py-2 text-xs font-semibold text-red-600">
          {{ recipientsError }}
        </p>
        <button
          type="button"
          class="text-xs font-bold text-brand-cobalt hover:underline"
          @click="loadRecipients"
        >
          {{ t('tutoring2.common.retry') }}
        </button>
      </div>

      <template v-else>
        <p
          v-if="recipientCount === 0"
          data-testid="recipients-empty"
          class="text-xs text-slate-500"
        >
          {{ t('tutoring2.admin.voucherRecipients.empty') }}
        </p>

        <ul v-else data-testid="recipients-list" class="divide-y divide-slate-100 rounded-xl border border-slate-100">
          <li
            v-for="r in recipients"
            :key="r.id"
            data-testid="recipient-row"
            class="flex items-center justify-between gap-3 px-3 py-2"
          >
            <span class="text-sm text-slate-800">{{ recipientLabel(r) }}</span>
            <button
              v-if="props.canManage"
              type="button"
              data-testid="recipient-remove"
              :data-student-id="r.student_id"
              :disabled="busy"
              class="text-xs font-bold text-slate-500 hover:text-red-600 disabled:opacity-50"
              @click="detach(r)"
            >
              {{ t('tutoring2.common.delete') }}
            </button>
          </li>
        </ul>

        <!--
          The WIDENING warning. Deliberately placed before the last Hapus
          rather than behind a confirm dialog: a second Modal would stack
          two teleported overlays with two ESC handlers, which no screen
          in this repo does.
        -->
        <p
          v-if="removingLastWidens"
          data-testid="recipients-last-warning"
          class="rounded-xl bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-700"
        >
          {{ t('tutoring2.admin.voucherRecipients.removeLastWarning') }}
        </p>
      </template>

      <!-- ── Add recipients — `tutoring.voucher.manage` only ────────── -->
      <div v-if="props.canManage" data-testid="recipients-add" class="space-y-3 border-t border-slate-100 pt-md">
        <h3 class="text-xs font-bold uppercase tracking-wide text-slate-500">
          {{ t('tutoring2.admin.voucherRecipients.addTitle') }}
        </h3>

        <FormField
          v-model="studentSearch"
          field="recipient_search"
          :label="t('tutoring2.admin.voucherRecipients.searchLabel')"
          :placeholder="t('tutoring2.admin.voucherRecipients.searchPh')"
          :disabled="busy"
        />

        <FormField
          v-model="picker"
          type="select"
          field="recipient_student_id"
          :label="t('tutoring2.common.student')"
          :options="studentOptions"
          :select-placeholder="t('tutoring2.admin.voucherRecipients.studentPh')"
          :disabled="busy || studentsLoading"
        />

        <p v-if="studentsLoading" class="-mt-1 text-xs text-slate-500">
          {{ t('tutoring2.common.loading') }}
        </p>
        <p
          v-else-if="studentsError"
          data-testid="students-error"
          class="-mt-1 text-xs text-red-600"
        >
          {{ studentsError }}
        </p>
        <p
          v-else-if="studentOptions.length === 0"
          data-testid="students-none"
          class="-mt-1 text-xs text-slate-500"
        >
          {{ t('tutoring2.admin.voucherRecipients.studentsNone') }}
        </p>
        <p
          v-else-if="studentsTruncated"
          data-testid="students-truncated"
          class="-mt-1 text-xs text-slate-500"
        >
          {{ t('tutoring2.admin.voucherRecipients.studentsTruncated', { count: PICKER_PAGE_SIZE }) }}
        </p>

        <div v-if="staged.length > 0" data-testid="recipients-staged" class="flex flex-wrap gap-2">
          <span
            v-for="s in staged"
            :key="s.id"
            data-testid="staged-chip"
            class="inline-flex items-center gap-2 rounded-full bg-brand-cobalt/10 px-3 py-1 text-xs font-semibold text-brand-cobalt"
          >
            {{ s.label }}
            <button
              type="button"
              data-testid="staged-remove"
              :disabled="busy"
              class="leading-none text-brand-cobalt/70 hover:text-brand-cobalt disabled:opacity-50"
              :aria-label="t('tutoring2.common.cancel')"
              @click="unstage(s.id)"
            >×</button>
          </span>
        </div>

        <!--
          The NARROWING warning. Attaching the first recipient turns a
          code that may already be circulating into one only these
          students can spend — including when an admin redeems on a
          family's behalf.
        -->
        <p
          v-if="willBecomePersonal"
          data-testid="recipients-first-warning"
          class="rounded-xl bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-700"
        >
          {{ t('tutoring2.admin.voucherRecipients.firstRecipientWarning') }}
        </p>
      </div>

      <p
        v-else
        data-testid="recipients-readonly"
        class="border-t border-slate-100 pt-md text-xs text-slate-500"
      >
        {{ t('tutoring2.admin.voucherRecipients.readOnlyNote') }}
      </p>

      <!--
        The snapshot the list page handed us said nothing about recipient
        counts, so the badge behind this sheet is rendering "—". Worth a
        line: the panel above is authoritative, the row behind it is not.
      -->
      <p
        v-if="!snapshotCounted"
        data-testid="recipients-snapshot-absent"
        class="text-2xs text-slate-400"
      >
        {{ t('tutoring2.admin.voucherRecipients.snapshotAbsent') }}
      </p>

      <BottomSheetFooter
        v-if="props.canManage"
        :primary-label="t('tutoring2.admin.voucherRecipients.attachSubmit')"
        :primary-disabled="staged.length === 0"
        :primary-loading="saving"
        @primary="submitAttach"
        @secondary="emit('close')"
      />
      <BottomSheetFooter
        v-else
        hide-secondary
        :primary-label="t('tutoring2.common.back')"
        @primary="emit('close')"
      />
    </div>
  </Modal>
</template>
