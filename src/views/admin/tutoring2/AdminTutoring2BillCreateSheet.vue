<!--
  AdminTutoring2BillCreateSheet.vue — the manual "Tambah Tagihan"
  surface for web (`POST /tutoring-v2/bills`).

  WHY IT EXISTS. Bills have only ever been GENERATED: enrollment intake
  raises the first one and the monthly cron raises the rest. web-vue had
  no create surface at all, so AdminTutoring2BillingView's "+ Buat
  tagihan" CTA shipped `disabled` with the reason on the control —
  !1211's honesty pattern — and its docblock recorded the finishing
  steps this sheet performs. The mobile app grew the form first, so the
  mobile sheet is the spec and this mirrors its field set and
  behaviours.

  ── THE WIRE CONTRACT ───────────────────────────────────────────────
  `StoreBillRequest` (backend `app/Modules/Tutoring/Http/Requests`):

    student_id           required, uuid
    payment_type_id      required, uuid
    amount               required, numeric, min 0
    due_date             required, date
    source_type          required, in TUTORING_PREPAID | TUTORING_MONTHLY
                                     | TUTORING_SESSION
    bimbel_enrollment_id nullable, uuid
    bimbel_session_id    nullable, uuid
    month                nullable, string max 7 (YYYY-MM)
    description          nullable, string max 1000
    status               nullable, in unpaid|pending|partial|paid

  `source_type` is REQUIRED — omitting it is a 422, not a server
  default. The three accepted spellings are the `BillSource` enum's
  SCREAMING_SNAKE backed values, which is also what `GET
  /tutoring-v2/bills` filters on and what `BillResource` reads back.
  Lowercase `bimbel_prepaid`-style spellings are NOT accepted by the
  `in:` rule.

  `bimbel_session_id`, `month` and `status` are on the contract but not
  on this form, exactly as on mobile: a manual bill is composed against
  a student and a payment type, and inventing inputs for the cron's
  bookkeeping fields is a product decision this MR does not make.
  `status` is server-defaulted to `unpaid`.

  ── "KETERANGAN", AND WHY IT WAS ABSENT UNTIL NOW ───────────────────
  This field shipped LAST, on purpose. When this sheet was built,
  `description` went nowhere: no rule in `StoreBillRequest`, absent
  from the controller's `Bill::create([…])` allowlist, no column on
  `bills`, no key in `BillResource`. The mobile sheet already had the
  box, so its value was silently discarded; adding a second such input
  here would have doubled the defect rather than fixed it.

  That is all now live. `StoreBillRequest` validates
  `nullable|string|max:1000` and `BillResource` emits the key
  unconditionally, so the value survives the round trip and is read
  back on index and show alike.

  The label says KETERANGAN, matching the mobile form's `FormTextField`
  (`admin_bills_screen.dart`) word for word. The wire key stays
  `description` because that is what the server validates; the
  Indonesian noun lives only in the translation VALUE.

  MAX_DESCRIPTION_LENGTH is 1000, read off `StoreBillRequest` rather
  than assumed. The bound is enforced HERE so an over-long note is
  refused before a round trip, and the server's own 422 is mapped back
  onto the field if one arrives anyway — see `applyServerFieldErrors`.

  ── AN EMPTY OPTIONAL FIELD IS ABSENT, NOT `''` ─────────────────────
  Both optional fields on this sheet leave the key OFF the payload when
  blank, via the same conditional spread. `bimbel_enrollment_id` needs
  it because `''` is not a uuid and a blank the admin left on purpose
  would come back a 422. `description` needs it for the opposite
  reason: `nullable|string` ACCEPTS `''`, so a cleared box would be
  stored as an empty string and read back as one, which is not the same
  row as "this bill has no note". Absent is the only spelling that
  means nothing was typed.

  ── PICKERS, NOT TYPED IDS — AND NOT MODALS EITHER ──────────────────
  Siswa / Pendaftaran / Jenis pembayaran all choose from real API rows,
  so `student_id`, `bimbel_enrollment_id` and `payment_type_id` can only
  ever be ids the server issued.

  They are FormField `type="select"`, NOT the FilterFacetPickerModal
  the filter chips use, for the reason AdminTutoring2PayoutRatesView
  records when it solved this same problem: FormSheet IS a Modal, so a
  second Modal on top would stack two `Teleport to="body"` overlays at
  the same z-50 with two ESC handlers, and no screen in the repo does
  that.

  Siswa keeps the one thing a plain select would lose. `students` is a
  tenant-sized table, so the sheet carries a debounced "Cari siswa"
  field above it that refetches with `?search=` — a second FormField,
  not a second overlay. A client-side filter over "the page we happened
  to load" quietly reports "no match" for a student who exists, which is
  the difference between "no such siswa" and "not in the rows we
  fetched". The other two lists need no box: pendaftaran is one
  student's enrollments, and the payment-type endpoint returns the
  tenant's whole catalogue uncapped.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import { useToast } from '@/composables/useToast';
import { extractError } from '@/lib/api-error';
import { toLocalYmd } from '@/lib/local-date';
import {
  TutoringBimbelService,
  type BimbelBill,
  type BimbelEnrollment,
  type BimbelPaymentTypeOption,
} from '@/services/tutoring-bimbel.service';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type { BimbelStudent } from '@/types/tutoring2/student';

const props = withDefaults(
  defineProps<{
    /**
     * Whether the caller holds `tutoring.payment_type.view` — the key
     * `Tutoring\PaymentTypeController::index` authorizes.
     *
     * Resolved by the PARENT and injected, exactly as the mobile sheet
     * does it: it keeps this component a plain form with one boolean,
     * which is also what makes the without-the-ability case testable
     * without faking a store. False means the catalogue cannot be
     * fetched at all, so the field says so instead of offering a
     * dropdown whose only possible outcome is a 403.
     */
    canViewPaymentTypes?: boolean;
  }>(),
  { canViewPaymentTypes: true },
);

const emit = defineEmits<{
  close: [];
  /** Fires after a successful create — the parent reloads its list. */
  saved: [bill: BimbelBill];
}>();

const { t } = useI18n();
const toast = useToast();

/** One page of picker rows. Mirrors the mobile picker's page size. */
const PICKER_PAGE_SIZE = 50;

/**
 * Mirrors `StoreBillRequest`'s `description => max:1000`. Read off the
 * FormRequest, not guessed — the sheet must refuse exactly what the
 * server would, no earlier and no later.
 */
const MAX_DESCRIPTION_LENGTH = 1000;

// ── Chosen values ───────────────────────────────────────────────────

const studentId = ref('');
const enrollmentId = ref('');
/**
 * The chosen payment type is held WHOLE, not as a bare id: the row's
 * `amount` is what prefills Nominal, and `prefillAmountFrom` needs the
 * PREVIOUS row's amount to tell an untouched prefill from a figure the
 * admin authored.
 */
const paymentType = ref<BimbelPaymentTypeOption | null>(null);

const sourceType = ref<string>('TUTORING_PREPAID');
const amount = ref<number | null>(null);
const dueDate = ref<string>('');
/** Free-text "Keterangan". Optional; blank means the key is not sent. */
const description = ref<string>('');

const isSaving = ref(false);
const errors = ref<Record<string, string>>({});

// ── Row caches ──────────────────────────────────────────────────────

const students = ref<BimbelStudent[]>([]);
const studentsLoading = ref(false);
const studentSearch = ref('');

const enrollments = ref<BimbelEnrollment[]>([]);
const enrollmentsLoading = ref(false);

const paymentTypes = ref<BimbelPaymentTypeOption[]>([]);
const paymentTypesLoading = ref(false);
const paymentTypesFailed = ref(false);

// ── Jenis pembayaran ────────────────────────────────────────────────

/**
 * Fetched EAGERLY on mount rather than when the field is first touched,
 * because the FIELD's affordance depends on the answer: a tenant with
 * no payment types must be told so in the field, not handed an empty
 * dropdown.
 */
onMounted(() => {
  void loadStudents();
  if (props.canViewPaymentTypes) void loadPaymentTypes();
});

async function loadPaymentTypes(): Promise<void> {
  paymentTypesLoading.value = true;
  paymentTypesFailed.value = false;
  try {
    const rows = await TutoringBimbelService.listPaymentTypes();
    paymentTypes.value = rows;
    // Preselect the tenant's SYSTEM type when the server marked one.
    // That is the row the enrollment and per-session billing hooks
    // already anchor their automatic bills to, so a manual bill lands
    // in the same bucket instead of asking the admin to guess which of
    // several similarly-named rows is "the" one.
    const preset = rows.find((r) => r.is_default);
    if (preset && !paymentType.value) selectPaymentType(preset.id);
  } catch {
    paymentTypesFailed.value = true;
  } finally {
    paymentTypesLoading.value = false;
  }
}

/**
 * Why Jenis pembayaran cannot be chosen right now, or '' when it can.
 *
 * ONE getter, TWO consumers — the field renders it as its explanation
 * and `validate()` reuses it as the field error — so the form can never
 * refuse a submit for a reason it did not already show.
 */
const paymentTypeBlocker = computed<string>(() => {
  if (!props.canViewPaymentTypes) return t('tutoring2.admin.billCreate.ptNoAbility');
  if (paymentTypesLoading.value) return t('tutoring2.admin.billCreate.ptLoading');
  if (paymentTypesFailed.value) return t('tutoring2.admin.billCreate.ptFailed');
  if (paymentTypes.value.length === 0) return t('tutoring2.admin.billCreate.ptEmpty');
  return '';
});

function selectPaymentType(id: string): void {
  const next = paymentTypes.value.find((p) => p.id === id);
  if (!next) return;
  const previous = paymentType.value;
  paymentType.value = next;
  prefillAmountFrom(previous, next);
  delete errors.value.payment_type_id;
}

/**
 * Copies the chosen type's default nominal into Nominal — but ONLY
 * while that box still holds a value the admin did not author.
 * Anything they typed themselves survives switching type, because a
 * one-off bill for an amount other than the catalogue default is the
 * ordinary reason to be on this form at all.
 */
function prefillAmountFrom(
  previous: BimbelPaymentTypeOption | null,
  next: BimbelPaymentTypeOption,
): void {
  if (next.amount <= 0) return;
  const untouched =
    amount.value === null ||
    (previous !== null && previous.amount > 0 && amount.value === Math.round(previous.amount));
  if (!untouched) return;
  amount.value = Math.round(next.amount);
}

// ── Fetching rows ───────────────────────────────────────────────────

/**
 * Students, filtered SERVER-side. `StudentController::index` honours
 * `search` (a case-insensitive LIKE over name / student_number /
 * guardian_name / guardian_email), so the box is forwarded rather than
 * filtering the page in hand.
 *
 * `active` is stated explicitly rather than left to the default:
 * omitting it does NOT mean "all" on the server, which reads a missing
 * param as true.
 */
async function loadStudents(): Promise<void> {
  studentsLoading.value = true;
  const query = studentSearch.value.trim();
  try {
    const res = await TutoringStudentsService.list({
      per_page: PICKER_PAGE_SIZE,
      active: true,
      ...(query ? { search: query } : {}),
    });
    students.value = res.items;
  } catch {
    students.value = [];
  } finally {
    studentsLoading.value = false;
  }
}

const debouncedStudentReload = useDebounceFn(() => void loadStudents(), 300);
watch(studentSearch, () => debouncedStudentReload());

/**
 * Pendaftaran belonging to the CHOSEN student. `EnrollmentController::
 * index` has no `search` parameter (it filters student / program /
 * learning_group / status / billing_mode only) — harmless here, because
 * the list is one student's enrollments rather than the whole tenant's.
 */
async function loadEnrollments(): Promise<void> {
  if (!studentId.value) {
    enrollments.value = [];
    return;
  }
  enrollmentsLoading.value = true;
  try {
    const res = await TutoringBimbelService.listEnrollments({
      per_page: PICKER_PAGE_SIZE,
      student_id: studentId.value,
    });
    enrollments.value = res.items;
  } catch {
    enrollments.value = [];
  } finally {
    enrollmentsLoading.value = false;
  }
}

/**
 * A pendaftaran belongs to exactly ONE student. Keeping the old pick
 * after the student changes would post student B together with student
 * A's enrollment id — and the server would TAKE it, because
 * `bimbel_enrollment_id` is validated as a uuid and nothing more.
 */
watch(studentId, () => {
  enrollmentId.value = '';
  enrollments.value = [];
  delete errors.value.student_id;
  void loadEnrollments();
});

// ── Option lists ────────────────────────────────────────────────────

const unnamed = () => t('tutoring2.admin.billCreate.unnamed');

const studentOptions = computed<FormFieldOption[]>(() =>
  students.value.map((s) => ({
    value: s.id,
    label: [s.name.trim() || unnamed(), s.student_number?.trim()]
      .filter(Boolean)
      .join(' · '),
  })),
);

/**
 * True when the server filled a whole page, so the list in hand is
 * provably partial. Said out loud under the field — an admin who cannot
 * find a student needs to know the list is a page, not the roster.
 */
const studentsTruncated = computed(
  () => students.value.length >= PICKER_PAGE_SIZE,
);

const enrollmentOptions = computed<FormFieldOption[]>(() =>
  enrollments.value.map((e) => ({
    value: e.id,
    // The programme is what names an enrollment to a human.
    label: [
      (e.program_name ?? '').trim() || unnamed(),
      (e.learning_group_name ?? '').trim(),
      e.status_label ?? e.status,
    ]
      .filter(Boolean)
      .join(' · '),
  })),
);

const statusLabel = (row: BimbelPaymentTypeOption) =>
  row.status.toLowerCase() === 'active'
    ? t('tutoring2.admin.billCreate.ptActive')
    : t('tutoring2.admin.billCreate.ptInactive');

const periodLabel = (row: BimbelPaymentTypeOption) => {
  switch (row.period.toLowerCase()) {
    case 'monthly':
      return t('tutoring2.admin.billCreate.periodMonthly');
    case 'yearly':
      return t('tutoring2.admin.billCreate.periodYearly');
    case 'once':
      return t('tutoring2.admin.billCreate.periodOnce');
    // An unknown period falls through to ITSELF rather than to a wrong
    // Indonesian word.
    default:
      return row.period;
  }
};

/**
 * Payment-type rows. `status` earns a place on EVERY label because the
 * endpoint does not filter to active — a paused type is offerable on
 * purpose (its docblock says so out loud), and an admin billing against
 * one should be able to see that is what they did. A picker that
 * silently omits rows is the harder failure to diagnose.
 */
const paymentTypeOptions = computed<FormFieldOption[]>(() =>
  paymentTypes.value.map((row) => ({
    value: row.id,
    label: [
      row.name.trim() || unnamed(),
      row.is_default ? t('tutoring2.admin.billCreate.ptDefault') : '',
      statusLabel(row),
      periodLabel(row),
    ]
      .filter(Boolean)
      .join(' · '),
  })),
);

const sourceTypeOptions = computed<FormFieldOption[]>(() => [
  { value: 'TUTORING_PREPAID', label: t('tutoring2.admin.billCreate.sourcePrepaid') },
  { value: 'TUTORING_MONTHLY', label: t('tutoring2.admin.billCreate.sourceMonthly') },
  { value: 'TUTORING_SESSION', label: t('tutoring2.admin.billCreate.sourceSession') },
]);

// ── Due-date bounds ─────────────────────────────────────────────────

/**
 * The same window the mobile date picker offers: 30 days back to a year
 * ahead. Advisory chrome for the native picker, not a rule — the server
 * accepts any parseable date.
 *
 * Computed through `toLocalYmd`, NEVER `toISOString().slice(0, 10)`.
 * The latter returns the UTC day: in WIB (UTC+7) every moment before
 * 07:00 local stringifies as YESTERDAY, so a bound computed that way is
 * a day out for the whole Indonesian morning.
 */
function shiftedYmd(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return toLocalYmd(d);
}
const dueDateMin = computed(() => shiftedYmd(-30));
const dueDateMax = computed(() => shiftedYmd(365));

// ── Validation + submit ─────────────────────────────────────────────

function validate(): boolean {
  const next: Record<string, string> = {};
  if (!studentId.value) next.student_id = t('tutoring2.admin.billCreate.errStudent');
  if (!paymentType.value) {
    // The blocker wording when there is nothing to choose, so the form
    // never refuses a submit for a reason it did not already show.
    next.payment_type_id =
      paymentTypeBlocker.value || t('tutoring2.admin.billCreate.errPaymentType');
  }
  if (amount.value === null || amount.value <= 0) {
    next.amount = t('tutoring2.admin.billCreate.errAmount');
  }
  if (!dueDate.value) next.due_date = t('tutoring2.admin.billCreate.errDueDate');
  // Measured on the TRIMMED text, because that is the string `submit`
  // actually posts — bounding the raw box would refuse a note whose
  // only excess is trailing whitespace the server never sees.
  if (description.value.trim().length > MAX_DESCRIPTION_LENGTH) {
    next.description = t('tutoring2.admin.billCreate.errDescriptionTooLong', {
      max: MAX_DESCRIPTION_LENGTH,
    });
  }
  errors.value = next;
  return Object.keys(next).length === 0;
}

/**
 * Put a 422's per-field wording back under the field it belongs to.
 *
 * `extractError` already lifts the server's FIRST message into the
 * toast, which is the right banner-level behaviour and stays. This adds
 * the missing half: a bag like `{description: ["…may not be greater
 * than 1000 characters."]}` should mark the Keterangan box, not just
 * float a sentence over a form whose fields all look fine.
 *
 * Keys are WIRE names, which is exactly how `errors` is keyed, so an
 * unrecognised field simply never renders rather than needing a map.
 */
function applyServerFieldErrors(err: unknown): void {
  const bag = (
    err as { response?: { data?: { errors?: Record<string, string[]> } } }
  )?.response?.data?.errors;
  if (!bag) return;
  const next = { ...errors.value };
  for (const [field, messages] of Object.entries(bag)) {
    const first = Array.isArray(messages) ? messages[0] : String(messages);
    if (first) next[field] = first;
  }
  errors.value = next;
}

async function submit(): Promise<void> {
  if (isSaving.value) return;
  if (!validate()) return;
  isSaving.value = true;
  try {
    const bill = await TutoringBimbelService.createBill({
      student_id: studentId.value,
      // Non-null assertion is safe: `validate()` cannot return true
      // while `paymentType` is null.
      payment_type_id: paymentType.value!.id,
      amount: amount.value!,
      due_date: dueDate.value,
      source_type: sourceType.value,
      // ABSENT, not `''`. `bimbel_enrollment_id` is `nullable|uuid`, and
      // an empty string is not a uuid — sending one turns "no
      // pendaftaran chosen" into a 422 on a field the admin left blank
      // on purpose.
      ...(enrollmentId.value ? { bimbel_enrollment_id: enrollmentId.value } : {}),
      // ABSENT, not `''`, for the reason the header records: the server
      // would STORE an empty string, and a bill whose note is `''`
      // reads back differently from one that has no note at all.
      ...(description.value.trim()
        ? { description: description.value.trim() }
        : {}),
    });
    toast.success(t('tutoring2.admin.billCreate.success'));
    emit('saved', bill);
    emit('close');
  } catch (err) {
    // Prefer the server's own words — a 422 the client-side checks
    // missed should explain itself rather than collapse into a generic
    // failure. `extractError` is the single implementation of that.
    toast.error(extractError(err) ?? t('tutoring2.admin.billCreate.errorGeneric'));
    // …and mark the offending field, so the admin can see WHICH box the
    // sentence is about. The sheet stays open holding what they typed.
    applyServerFieldErrors(err);
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <FormSheet
    :title="t('tutoring2.admin.billCreate.title')"
    :subtitle="t('tutoring2.admin.billCreate.subtitle')"
    :saving="isSaving"
    size="md"
    :save-label="t('tutoring2.admin.billCreate.submit')"
    @save="submit"
    @cancel="emit('close')"
  >
    <div class="space-y-3">
      <!-- Cari siswa. A second FormField rather than bespoke chrome
           inside the Siswa slot: FormField owns the one copy of the
           control look, and `form-field-control-chrome.spec.ts` fails
           any caller that pastes it. Narrows the select below by
           refetching SERVER-side. -->
      <FormField
        v-model="studentSearch"
        field="student_search"
        :label="t('tutoring2.admin.billCreate.studentSearchLabel')"
        :disabled="isSaving"
        :placeholder="t('tutoring2.admin.billCreate.studentSearchPh')"
      />

      <FormField
        v-model="studentId"
        type="select"
        field="student_id"
        :label="t('tutoring2.common.student')"
        :required="true"
        :disabled="isSaving"
        :options="studentOptions"
        :select-placeholder="t('tutoring2.admin.billCreate.studentPh')"
        :error="errors.student_id"
      />

      <p v-if="studentsLoading" class="-mt-1 text-xs text-slate-500">
        {{ t('tutoring2.admin.billCreate.loading') }}
      </p>
      <p
        v-else-if="studentsTruncated"
        data-testid="students-truncated"
        class="-mt-1 text-xs text-slate-500"
      >
        {{ t('tutoring2.admin.billCreate.studentsTruncated') }}
      </p>
      <p
        v-else-if="studentOptions.length === 0"
        class="-mt-1 text-xs text-slate-500"
      >
        {{ t('tutoring2.admin.billCreate.studentsEmpty') }}
      </p>

      <!-- Pendaftaran — optional, and always scoped to the chosen siswa. -->
      <FormField
        v-model="enrollmentId"
        type="select"
        field="bimbel_enrollment_id"
        :label="t('tutoring2.admin.billCreate.enrollmentLabel')"
        :disabled="isSaving || !studentId || enrollmentsLoading"
        :options="enrollmentOptions"
        :select-placeholder="
          studentId
            ? t('tutoring2.admin.billCreate.enrollmentPh')
            : t('tutoring2.admin.billCreate.enrollmentNeedsStudent')
        "
      />

      <!-- Jenis pembayaran. Its `amount` prefills Nominal; inactive rows
           stay listed WITH their status in the label. -->
      <FormField
        :model-value="paymentType?.id ?? ''"
        type="select"
        field="payment_type_id"
        :label="t('tutoring2.admin.billCreate.paymentTypeLabel')"
        :required="true"
        :disabled="isSaving || !!paymentTypeBlocker"
        :options="paymentTypeOptions"
        :select-placeholder="t('tutoring2.admin.billCreate.paymentTypePh')"
        :error="errors.payment_type_id || paymentTypeBlocker"
        @update:model-value="selectPaymentType(String($event))"
      />

      <FormField
        v-model="sourceType"
        type="select"
        field="source_type"
        :label="t('tutoring2.admin.billCreate.sourceLabel')"
        :required="true"
        :disabled="isSaving"
        :options="sourceTypeOptions"
      />

      <FormField
        v-model="amount"
        money
        field="amount"
        :label="t('tutoring2.admin.billCreate.amountLabel')"
        :required="true"
        :disabled="isSaving"
        :placeholder="t('tutoring2.admin.billCreate.amountPh')"
        :error="errors.amount"
      />

      <FormField
        v-model="dueDate"
        type="date"
        field="due_date"
        :label="t('tutoring2.admin.billCreate.dueDateLabel')"
        :required="true"
        :disabled="isSaving"
        :min="dueDateMin"
        :max="dueDateMax"
        :error="errors.due_date"
      />

      <!-- Keterangan — optional free text, the mobile sheet's wording.
           A textarea for the same reason mobile gives it `maxLines: 2`:
           it is a sentence about why this one-off bill exists, not a
           label. Blank means the key never reaches the wire. -->
      <FormField
        v-model="description"
        type="textarea"
        field="description"
        :rows="2"
        :label="t('tutoring2.admin.billCreate.descriptionLabel')"
        :disabled="isSaving"
        :placeholder="t('tutoring2.admin.billCreate.descriptionPh')"
        :error="errors.description"
      />
    </div>
  </FormSheet>
</template>
