<!--
  AdminTutoring2LeadsView.vue — greenfield "Leads / Calon Siswa"
  admin funnel (WEB-8, backed by BE-15).

  Mirrors AdminTutoring2ProgramsView.vue / EnrollmentsView.vue in
  layout: BrandPageHeader → KpiStripCards → PageFilterToolbar (+ chips)
  → AsyncView wrapping the table → floating "+ Tambah Lead" CTA. Data
  loads via `useDataRefresh(loader)` and re-runs when the debounced
  search, either filter chip, or the active academic year changes.

  Modal stack (all local, no route param — the detail sheet lives in
  the same view so the admin's filter state and scroll position stay
  intact when they inspect/convert/drop leads):
    - "Tambah Lead" modal  — CreateLeadPayload; source + name required
    - Detail sheet         — full editable form + activity note
    - "Convert" modal      — ConvertLeadPayload (delegates to BE-3
                             CreateEnrollmentAction server-side)
    - "Drop" confirmation  — free-text reason, appends to notes

  IDENTIFIERS ARE PICKED, NEVER TYPED. The Convert modal shipped with
  `student_id` and `package_id` as free-text boxes carrying `st-…` /
  `pk-…` placeholders. Those ids are v4 UUIDs, ConvertLeadRequest
  validates `['required','uuid']`, and no admin can produce one by
  hand — so the button could not be completed by anybody, and every
  attempt came back "the student id field must be a valid uuid".
  Student is now a searchable picker over `/tutoring-v2/students`;
  package and learning group are program-scoped <select>s; the start
  date is a real date control. The Convert button stays disabled until
  the form holds a combination the server can accept.

  Convert also needs the lead's `interest_program_id` — ConvertLeadAction
  checks it FIRST — and no control on this screen could set it, so a
  lead created here was born unconvertible. Create + Detail now carry a
  "Program yang diminati" select, and Convert explains the gap (and
  where to close it) rather than relaying the server's 422.

  Ability gates (server-side authoritative — this only hides UI the
  user can't act on):
    - reads (list/detail)             → tutoring.lead.view
    - writes (create/convert/drop/    → tutoring.lead.manage
      update/destroy)

  KPI monthly counters are computed from the current in-memory page
  (list is capped at 100 per fetch — same as the sibling enrollments
  view). A future MR can promote these to a dedicated BE
  `/tutoring-v2/leads/summary` endpoint if the funnel gets deep enough
  that a page-slice count reads misleading.
-->
<script setup lang="ts">
import { computed, onMounted, ref, toRaw, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Modal from '@/components/ui/Modal.vue';
import FormField, { type FormFieldOption } from '@/components/ui/FormField.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { extractError } from '@/lib/api-error';
import { toLocalYmd } from '@/lib/local-date';
import { TutoringLeadsService } from '@/services/tutoring2/leads';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import {
  TutoringBimbelService,
  type BimbelLearningGroup,
  type BimbelPackage,
  type BimbelProgram,
} from '@/services/tutoring-bimbel.service';
import type { BimbelStudent } from '@/types/tutoring2/student';
import {
  LEAD_SOURCE_LABEL,
  LEAD_SOURCE_VALUES,
  LEAD_STATUS_LABEL,
  LEAD_STATUS_VALUES,
  isLeadConvertible,
  type BimbelLead,
  type ConvertLeadPayload,
  type CreateLeadPayload,
  type LeadSource,
  type LeadStatus,
  type UpdateLeadPayload,
} from '@/types/tutoring2/lead';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t, te } = useI18n();
const toast = useToast();
const { can } = useMe();

// ─── Ability shortcuts ─────────────────────────────────────────────
// `can` reads the /me `abilities` snapshot which is scoped by the
// currently active X-Active-Role (see reference_authz_client_gating_rule).
// The controller re-authorises server-side; these gates only hide
// affordances the user can't act on.
const canView = computed(() => can('tutoring.lead.view'));
const canManage = computed(() => can('tutoring.lead.manage'));

// ─── Filter + search state ─────────────────────────────────────────
const search = ref('');
const statusFilter = ref<LeadStatus | ''>('');
const sourceFilter = ref<LeadSource | ''>('');

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

/** Small i18n helper — falls back to the enum's Indonesian label if the
 *  view's i18n bundle hasn't been extended yet. Keeps this file
 *  translation-safe without a locale-bundle PR blocker. */
function tOr(key: string, fallback: string): string {
  return te(key) ? t(key) : fallback;
}

/**
 * Every write path below reports failure through the same three-rung
 * ladder, so no two of them read differently:
 *
 *   1. `extractError(e)`  — what the server said, when that text is
 *                           author-written (see @/lib/api-error for
 *                           which statuses are refused and why).
 *   2. `e.message`        — what the transport said. Keeps an
 *                           offline/timeout failure reading exactly as
 *                           it does today.
 *   3. a per-action generic.
 *
 * `extractError` used to be copy-pasted into this file and three
 * payout views. It now lives in @/lib/api-error as a single
 * implementation — fixing it in one copy would have left four that
 * silently disagree.
 */
function reportFailure(e: unknown, genericKey: string, generic: string): void {
  toast.error(
    extractError(e) ??
      (e as { message?: string })?.message ??
      tOr(genericKey, generic),
  );
}

// ─── Data load ─────────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringLeadsService.list({
    per_page: 100,
    status: statusFilter.value || undefined,
    source: sourceFilter.value || undefined,
  });
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return items;
  return items.filter(
    (l) =>
      (l.name ?? '').toLowerCase().includes(q) ||
      (l.phone ?? '').toLowerCase().includes(q) ||
      (l.email ?? '').toLowerCase().includes(q),
  );
});

watch([debouncedSearch, statusFilter, sourceFilter], () => {
  reload();
});

// ─── KPI derivation from the current page ──────────────────────────
// Uses the local-timezone Ymd to avoid the toISOString() WIB day-drop
// documented in reference_web_vue_local_date.
const currentMonthPrefix = computed(() => {
  const now = new Date();
  return toLocalYmd(now).slice(0, 7); // "YYYY-MM"
});

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelLead[];
  const baru = items.filter((l) => l.status === 'new').length;
  const pipeline = items.filter(
    (l) => l.status === 'contacted' || l.status === 'trial',
  ).length;
  const monthPrefix = currentMonthPrefix.value;
  const convertedThisMonth = items.filter(
    (l) =>
      l.status === 'converted' &&
      (l.updated_at ?? '').slice(0, 7) === monthPrefix,
  ).length;
  const droppedThisMonth = items.filter(
    (l) =>
      l.status === 'dropped' &&
      (l.updated_at ?? '').slice(0, 7) === monthPrefix,
  ).length;
  return [
    {
      icon: 'sparkles',
      label: tOr('tutoring2.admin.leads.kpiBaru', 'Baru'),
      value: String(baru),
      tone: baru > 0 ? 'amber' : undefined,
    },
    {
      icon: 'users',
      label: tOr('tutoring2.admin.leads.kpiPipeline', 'Dalam pipeline'),
      value: String(pipeline),
    },
    {
      icon: 'circle-check',
      label: tOr('tutoring2.admin.leads.kpiConvertedMonth', 'Konversi bulan ini'),
      value: String(convertedThisMonth),
      tone: convertedThisMonth > 0 ? 'green' : undefined,
    },
    {
      icon: 'x-circle',
      label: tOr('tutoring2.admin.leads.kpiDroppedMonth', 'Batal bulan ini'),
      value: String(droppedThisMonth),
      tone: droppedThisMonth > 0 ? 'red' : undefined,
    },
  ];
});

// ─── Table helpers ─────────────────────────────────────────────────
function statusTone(status: LeadStatus | null | undefined): StatusBadgeTone {
  switch (status) {
    case 'new': return 'info';
    case 'contacted': return 'info';
    case 'trial': return 'warning';
    case 'converted': return 'success';
    case 'dropped': return 'neutral';
    default: return 'neutral';
  }
}

function statusLabel(l: BimbelLead): string {
  return l.status_label ?? (l.status ? LEAD_STATUS_LABEL[l.status] : '—');
}

function sourceLabel(l: BimbelLead): string {
  return l.source_label ?? (l.source ? LEAD_SOURCE_LABEL[l.source] : '—');
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return toLocalYmd(d);
}

// ─── Modal orchestration ───────────────────────────────────────────
type Sheet = 'none' | 'create' | 'detail' | 'convert' | 'drop';
const openSheet = ref<Sheet>('none');
const activeLead = ref<BimbelLead | null>(null);
const submitting = ref(false);

const statusOptions = LEAD_STATUS_VALUES.map((v) => ({
  value: v,
  label: LEAD_STATUS_LABEL[v],
}));
const sourceOptions = LEAD_SOURCE_VALUES.map((v) => ({
  value: v,
  label: LEAD_SOURCE_LABEL[v],
}));
const billingModeOptions = [
  { value: 'prepaid', label: 'Prabayar (paket)' },
  { value: 'monthly', label: 'SPP bulanan' },
  { value: 'per_session', label: 'Per sesi' },
];

// ─── Reference data behind the identifier pickers ──────────────────
//
// This screen used to ask the admin to TYPE the identifiers into
// free-text boxes: `student_id` with an `st-…` placeholder and
// `package_id` with `pk-…`. Those ids are v4 UUIDs — the placeholders
// described a format the API has never emitted — and
// ConvertLeadRequest validates `['required','uuid']`, so every attempt
// came back "the student id field must be a valid uuid" (reported by
// Luay, 2026-09). A control that cannot be satisfied is worse than no
// control at all, so all three identifiers are now chosen from the
// real endpoints and the form only ever submits ids the server issued.
//
// Loading is TOLERANT (Promise.allSettled) and every loader records
// WHY its list is empty. The house rule from
// AdminTutoring2GroupCreateSheet and
// AdminTutoring2EnrollmentsView.loadFacetOptions: a 403 or an empty
// catalogue must leave a disabled field that says so — an open
// dropdown with nothing in it is the same lie in a new shape.

const programs = ref<BimbelProgram[]>([]);

/**
 * Non-archived programs, as <select> options.
 *
 * `selectedId` keeps an already-chosen program visible even if it has
 * since been archived: dropping it would blank the select on a lead
 * that DOES have a program, which reads as "not set" and invites the
 * admin to overwrite it. Archived entries are labelled, not hidden.
 */
function programOptionsFor(
  selectedId: string | null | undefined,
): FormFieldOption[] {
  return programs.value
    .filter((p) => p.status !== 'archived' || p.id === selectedId)
    .map((p) => ({
      value: p.id,
      label:
        p.status === 'archived'
          ? `${p.name} (${tOr('tutoring2.common.archived', 'diarsipkan')})`
          : p.name,
    }));
}

async function loadPrograms(): Promise<void> {
  const [res] = await Promise.allSettled([
    TutoringBimbelService.listPrograms({ per_page: 200 }),
  ]);
  if (res.status === 'fulfilled') programs.value = res.value.items;
}

onMounted(() => {
  if (canView.value) void loadPrograms();
});

// ─── Student picker (server-side search) ───────────────────────────
// Deliberately NOT a <select> over a loaded page: a bimbel tenant's
// student table is unbounded, and a client-side filter over "the first
// N we happened to fetch" answers "tidak ada" for students who exist.
// TutoringStudentsService.list() searches name / student_number /
// guardian_name / guardian_email server-side, so the query goes where
// the rows are.
const STUDENT_PAGE_SIZE = 50;
const students = ref<BimbelStudent[]>([]);
const studentsLoading = ref(false);
/** Why the list is empty — never left blank while the list is. */
const studentsEmptyReason = ref('');
const showStudentPicker = ref(false);
/** The picked row, kept whole so the trigger can show a NAME. */
const selectedStudent = ref<BimbelStudent | null>(null);

const studentOptions = computed<FacetOption[]>(() =>
  students.value.map((st) => ({
    key: st.id,
    label: st.name,
    meta:
      [st.student_number, st.guardian_name].filter(Boolean).join(' · ') ||
      undefined,
  })),
);

async function loadStudents(query = ''): Promise<void> {
  const q = query.trim();
  studentsLoading.value = true;
  const [res] = await Promise.allSettled([
    TutoringStudentsService.list({
      per_page: STUDENT_PAGE_SIZE,
      active: true,
      search: q || undefined,
    }),
  ]);
  studentsLoading.value = false;
  if (res.status === 'fulfilled') {
    students.value = res.value.items;
    studentsEmptyReason.value = res.value.items.length
      ? ''
      : q
        ? tOr(
            'tutoring2.admin.leads.studentNoMatch',
            'Tidak ada siswa aktif yang cocok dengan pencarian itu.',
          )
        : tOr(
            'tutoring2.admin.leads.studentNone',
            'Belum ada siswa aktif. Daftarkan siswanya lewat menu Data Siswa lebih dulu.',
          );
    return;
  }
  students.value = [];
  studentsEmptyReason.value = tOr(
    'tutoring2.admin.leads.studentLoadFailed',
    'Daftar siswa gagal dimuat. Periksa izin akses Anda, lalu buka ulang jendela ini.',
  );
}

const applyStudentSearch = useDebounceFn((q: string) => {
  void loadStudents(q);
}, 300);

function pickStudent(id: string): void {
  const found = id ? (students.value.find((st) => st.id === id) ?? null) : null;
  selectedStudent.value = found;
  convertForm.value.student_id = found?.id ?? '';
  // Clear the inline "Siswa wajib dipilih" the moment the requirement
  // is met. Without this the red line stays under a field that is now
  // correctly filled, and only disappears on the next submit.
  if (found) convertErrors.value.student_id = '';
}

// ─── Package + learning-group pickers (program-scoped) ─────────────
// Both endpoints are scoped to the lead's interest program, which is
// also the program CreateEnrollmentAction enrols into — so a package
// or group from any other program would be refused ("Paket bukan milik
// program ini."). Scoping the LIST is what stops that from ever being
// offered.
const packages = ref<BimbelPackage[]>([]);
const groups = ref<BimbelLearningGroup[]>([]);
// Two refs per list, not one, because the two messages are different
// KINDS of thing and the sheet must not dress one as the other.
// `*EmptyReason` is guidance about an OPTIONAL field ("this program
// has no packages yet — carry on without one"); `*LoadError` is an
// actual failure the admin should react to. They used to share a ref
// that was piped into FormField's red `error` line, so "Program ini
// belum punya paket" rendered as if the form had rejected something.
const packagesEmptyReason = ref('');
const packagesLoadError = ref('');
const groupsEmptyReason = ref('');
const groupsLoadError = ref('');

const packageOptions = computed<FormFieldOption[]>(() =>
  packages.value
    .filter((pk) => pk.status !== 'archived')
    .map((pk) => ({
      value: pk.id,
      label:
        pk.status === 'draft'
          ? `${pk.name} (${tOr('tutoring2.common.draft', 'draf')})`
          : pk.name,
    })),
);

// No seat count in the label, deliberately. `seated_count` is emitted
// by LearningGroupController::show() only — index(), which is what
// listGroups() calls, never sets the attribute, so
// LearningGroupResource's `whenHas` drops it from every row here. A
// "(penuh 8/10)" suffix computed from `seated_count ?? 0` would have
// read 0 seats for every group forever, i.e. never render — and the
// fixture that made it look exercised had to invent a field the list
// endpoint cannot return. Known limitation, stated in the MR: an admin
// can still pick a group that is already full and only learn it from
// CreateEnrollmentAction's refusal. The honest fix is server-side —
// have index() aggregate the seat count in one query — not a client
// guess.
const groupOptions = computed<FormFieldOption[]>(() =>
  groups.value
    .filter((g) => g.status !== 'closed')
    .map((g) => ({ value: g.id, label: g.name })),
);

async function loadConvertScope(programId: string | null): Promise<void> {
  packages.value = [];
  groups.value = [];
  packagesEmptyReason.value = '';
  packagesLoadError.value = '';
  groupsEmptyReason.value = '';
  groupsLoadError.value = '';
  // No interest program → nothing to scope to. The sheet already
  // explains that case in full, so don't add a second message here.
  if (!programId) return;

  const [pkgRes, grpRes] = await Promise.allSettled([
    TutoringBimbelService.listPackages(programId, { per_page: 100 }),
    TutoringBimbelService.listGroups({ per_page: 100, program_id: programId }),
  ]);

  if (pkgRes.status === 'fulfilled') {
    packages.value = pkgRes.value.items;
    packagesEmptyReason.value = packageOptions.value.length
      ? ''
      : tOr(
          'tutoring2.admin.leads.packageNone',
          'Program ini belum punya paket. Lanjutkan tanpa paket, atau buat paketnya di menu Program.',
        );
  } else {
    packagesLoadError.value = tOr(
      'tutoring2.admin.leads.packageLoadFailed',
      'Daftar paket gagal dimuat.',
    );
  }

  if (grpRes.status === 'fulfilled') {
    groups.value = grpRes.value.items;
    groupsEmptyReason.value = groupOptions.value.length
      ? ''
      : tOr(
          'tutoring2.admin.leads.groupNone',
          'Program ini belum punya kelompok belajar aktif. Lanjutkan tanpa kelompok.',
        );
  } else {
    groupsLoadError.value = tOr(
      'tutoring2.admin.leads.groupLoadFailed',
      'Daftar kelompok gagal dimuat.',
    );
  }
}

// ─── Create modal state ────────────────────────────────────────────
// `interest_program_id` is accepted by StoreLeadRequest and is the
// FIRST thing ConvertLeadAction checks. It had no control on this
// screen at all, so every lead created here was born unconvertible —
// the 422 waiting immediately behind the uuid one.
const createForm = ref<CreateLeadPayload>({
  name: '',
  phone: '',
  email: '',
  source: 'website',
  interest_program_id: null,
  notes: '',
});
function resetCreateForm() {
  createForm.value = {
    name: '',
    phone: '',
    email: '',
    source: 'website',
    interest_program_id: null,
    notes: '',
  };
}
function openCreate() {
  if (!canManage.value) return;
  resetCreateForm();
  openSheet.value = 'create';
}
async function submitCreate() {
  if (!createForm.value.name.trim()) {
    toast.error(tOr('tutoring2.admin.leads.errNameRequired', 'Nama wajib diisi'));
    return;
  }
  submitting.value = true;
  try {
    // structuredClone via toRaw — see reference_vue_structuredclone_reactive.
    const payload = structuredClone(toRaw(createForm.value));
    if (!payload.interest_program_id) delete payload.interest_program_id;
    await TutoringLeadsService.create(payload);
    toast.success(tOr('tutoring2.admin.leads.toastCreated', 'Lead ditambahkan'));
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    reportFailure(
      e,
      'tutoring2.admin.leads.errCreateFailed',
      'Gagal menambahkan lead',
    );
  } finally {
    submitting.value = false;
  }
}

// ─── Detail sheet state ────────────────────────────────────────────
const detailForm = ref<UpdateLeadPayload>({});
async function openDetail(lead: BimbelLead) {
  activeLead.value = lead;
  detailForm.value = {
    name: lead.name,
    phone: lead.phone ?? '',
    email: lead.email ?? '',
    source: lead.source ?? 'website',
    status: lead.status ?? 'new',
    interest_program_id: lead.interest_program_id ?? null,
    notes: lead.notes ?? '',
  };
  openSheet.value = 'detail';
  // Fresh fetch so the sheet shows the latest server truth, not the
  // possibly-stale row from the list page.
  try {
    const fresh = await TutoringLeadsService.get(lead.id);
    activeLead.value = fresh;
    detailForm.value = {
      name: fresh.name,
      phone: fresh.phone ?? '',
      email: fresh.email ?? '',
      source: fresh.source ?? 'website',
      status: fresh.status ?? 'new',
      interest_program_id: fresh.interest_program_id ?? null,
      notes: fresh.notes ?? '',
    };
  } catch {
    // Non-fatal — keep the row we already have on screen.
  }
}
async function submitDetail() {
  if (!activeLead.value || !canManage.value) return;
  submitting.value = true;
  try {
    const payload = structuredClone(toRaw(detailForm.value));
    await TutoringLeadsService.update(activeLead.value.id, payload);
    toast.success(tOr('tutoring2.admin.leads.toastUpdated', 'Perubahan disimpan'));
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    // The status <select> in this sheet offers all five statuses while
    // UpdateLeadAction only accepts the moves in LeadStatus's DAG, so
    // "Tidak dapat pindah dari new ke converted." is a routine 422
    // here. It used to be replaced by axios's "Request failed with
    // status code 422", which told the admin nothing.
    //
    // The convert gate makes this the MORE important path, not the
    // less: with Konversi correctly hidden on a `new` lead, this
    // Select is the only way to move that lead forward.
    reportFailure(
      e,
      'tutoring2.admin.leads.errUpdateFailed',
      'Gagal menyimpan perubahan',
    );
  } finally {
    submitting.value = false;
  }
}

// ─── Convert modal state ───────────────────────────────────────────
const convertForm = ref<ConvertLeadPayload>({
  student_id: '',
  package_id: null,
  learning_group_id: null,
  billing_mode: 'monthly',
  start_date: null,
  notes: '',
});
/** Inline, per-field messages — shown under the control they belong to. */
const convertErrors = ref<{ student_id: string }>({ student_id: '' });

/**
 * The lead's interest program, which the server — not this form —
 * supplies to CreateEnrollmentAction. ConvertLeadAction's FIRST guard
 * refuses a lead that has none, so the sheet surfaces it as context
 * rather than letting the admin fill five fields and then be told the
 * lead was never eligible. The Detail sheet has a "Program yang
 * diminati" select, so this dead end now has an exit.
 */
const convertProgramId = computed<string | null>(
  () => activeLead.value?.interest_program_id ?? null,
);
const convertProgramName = computed<string>(() => {
  const id = convertProgramId.value;
  if (!id) return '';
  const known = programs.value.find((pg) => pg.id === id);
  return known?.name ?? activeLead.value?.interest_program_name ?? id;
});

/**
 * Billing modes the CHOSEN PACKAGE allows.
 *
 * CreateEnrollmentAction guard 4 refuses a mode outside the package's
 * `allowed_billing_modes`, so offering all three next to a package
 * that permits one is another button that cannot work. With no package
 * picked there is no such constraint and the full list stands.
 *
 * The tenant-level switch (guard 3) is NOT knowable from here — no
 * endpoint exposes the tenant's enabled modes — so that one still
 * arrives as a server message.
 */
const allowedBillingModes = computed<string[] | null>(() => {
  const id = convertForm.value.package_id;
  if (!id) return null;
  const pk = packages.value.find((p) => p.id === id);
  return pk?.allowed_billing_modes?.length ? pk.allowed_billing_modes : null;
});
const convertBillingModeOptions = computed(() => {
  const allowed = allowedBillingModes.value;
  if (!allowed) return billingModeOptions;
  return billingModeOptions.filter((o) => allowed.includes(o.value));
});

/** Everything that must be true before the POST can possibly succeed. */
const convertBlockedReason = computed<string>(() => {
  if (!convertProgramId.value) {
    return tOr(
      'tutoring2.admin.leads.convertNeedsProgram',
      'Lead ini belum punya program yang diminati, jadi belum bisa dikonversi. Buka Detail lead, pilih “Program yang diminati”, simpan, lalu ulangi konversi.',
    );
  }
  return '';
});
const canSubmitConvert = computed(
  () => !convertBlockedReason.value && !!convertForm.value.student_id,
);

/** Reset the package when it no longer belongs to the loaded program. */
watch(packageOptions, (opts) => {
  const id = convertForm.value.package_id;
  if (id && !opts.some((o) => o.value === id)) convertForm.value.package_id = null;
});
watch(groupOptions, (opts) => {
  const id = convertForm.value.learning_group_id;
  if (id && !opts.some((o) => o.value === id)) {
    convertForm.value.learning_group_id = null;
  }
});
// Picking a package can outlaw the currently-selected billing mode.
// Fall back to the package's first allowed mode rather than posting a
// combination the server is certain to refuse.
watch(convertBillingModeOptions, (opts) => {
  if (!opts.length) return;
  if (!opts.some((o) => o.value === convertForm.value.billing_mode)) {
    convertForm.value.billing_mode = opts[0]
      .value as ConvertLeadPayload['billing_mode'];
  }
});

function openConvert(lead: BimbelLead) {
  if (!canManage.value) return;
  // Same inclusion set as the two Konversi buttons' v-if, so this
  // defense-in-depth guard can't be looser than the affordance it
  // backs. Deliberately NOT the exclusion set used by openDrop —
  // dropping a `new` lead is legal server-side, converting one is not.
  if (!isLeadConvertible(lead.status)) {
    toast.error(
      tOr(
        'tutoring2.admin.leads.errNotConvertible',
        'Lead hanya bisa dikonversi dari status Dihubungi atau Trial',
      ),
    );
    return;
  }
  activeLead.value = lead;
  convertForm.value = {
    student_id: '',
    package_id: null,
    learning_group_id: null,
    billing_mode: 'monthly',
    start_date: toLocalYmd(new Date()),
    notes: '',
  };
  convertErrors.value = { student_id: '' };
  selectedStudent.value = null;
  showStudentPicker.value = false;
  openSheet.value = 'convert';
  // Both are tolerant and independent — an unavailable package list
  // must not stop the admin picking a student.
  void loadStudents();
  void loadConvertScope(lead.interest_program_id ?? null);
}
async function submitConvert() {
  if (!activeLead.value) return;
  // The student field is a picker, so its value is either an id the
  // server issued or nothing at all — there is no third case where a
  // typo reaches the wire. This guard exists so the empty case is
  // answered here, in Indonesian, next to the control, instead of as a
  // 422 reading "the student id field must be a valid uuid".
  if (!convertForm.value.student_id) {
    convertErrors.value.student_id = tOr(
      'tutoring2.admin.leads.errStudentRequired',
      'Siswa wajib dipilih',
    );
    toast.error(
      tOr('tutoring2.admin.leads.errStudentRequired', 'Siswa wajib dipilih'),
    );
    return;
  }
  // ConvertLeadAction refuses a lead with no interest program before it
  // looks at anything else. Saying so here — where the fix is one sheet
  // away — beats relaying the server's version of the same sentence.
  if (convertBlockedReason.value) {
    toast.error(convertBlockedReason.value);
    return;
  }
  convertErrors.value.student_id = '';
  submitting.value = true;
  try {
    const payload = structuredClone(toRaw(convertForm.value));
    // Prune blank optional strings so the BE validator doesn't reject them.
    if (!payload.package_id) delete payload.package_id;
    if (!payload.learning_group_id) delete payload.learning_group_id;
    if (!payload.start_date) delete payload.start_date;
    if (!payload.notes) delete payload.notes;
    await TutoringLeadsService.convert(activeLead.value.id, payload);
    toast.success(
      tOr('tutoring2.admin.leads.toastConverted', 'Lead dikonversi ke pendaftaran'),
    );
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    // The status gate above cannot make this unreachable: a lead that
    // IS `contacted` but has no `interest_program_id` is still refused,
    // with a different message — and CreateEnrollmentAction adds seven
    // more 422s (archived program, seat-full group, duplicate active
    // enrollment, …). Show whatever the server actually said.
    reportFailure(
      e,
      'tutoring2.admin.leads.errConvertFailed',
      'Gagal mengonversi lead',
    );
  } finally {
    submitting.value = false;
  }
}

// ─── Drop modal state ──────────────────────────────────────────────
const dropReason = ref('');
function openDrop(lead: BimbelLead) {
  if (!canManage.value) return;
  if (lead.status === 'converted' || lead.status === 'dropped') {
    toast.error(
      tOr(
        'tutoring2.admin.leads.errTerminal',
        'Lead sudah berada di status terminal',
      ),
    );
    return;
  }
  activeLead.value = lead;
  dropReason.value = '';
  openSheet.value = 'drop';
}
async function submitDrop() {
  if (!activeLead.value) return;
  submitting.value = true;
  try {
    await TutoringLeadsService.drop(activeLead.value.id, {
      notes: dropReason.value.trim() || null,
    });
    toast.success(tOr('tutoring2.admin.leads.toastDropped', 'Lead ditandai batal'));
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    reportFailure(
      e,
      'tutoring2.admin.leads.errDropFailed',
      'Gagal membatalkan lead',
    );
  } finally {
    submitting.value = false;
  }
}

function closeSheet() {
  openSheet.value = 'none';
  activeLead.value = null;
  showStudentPicker.value = false;
  selectedStudent.value = null;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="tOr('tutoring2.common.roleAdmin', 'Admin bimbel')"
      :title="tOr('tutoring2.admin.leads.title', 'Leads / Calon Siswa')"
      :meta="state.status === 'content'
        ? `${(state.data as BimbelLead[]).length} ${tOr('tutoring2.admin.leads.metaSuffix', 'lead')}`
        : tOr('tutoring2.common.loading', 'Memuat…')"
    />

    <!-- Read-guard: users without tutoring.lead.view get a plain empty
         message rather than a broken 403 fetch loop. -->
    <div
      v-if="!canView"
      class="rounded-3xl border border-slate-100 bg-white p-lg text-sm text-slate-600 shadow-sm"
    >
      {{ tOr('tutoring2.admin.leads.forbidden', 'Anda tidak memiliki izin untuk melihat leads.') }}
    </div>

    <template v-else>
      <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

      <PageFilterToolbar
        v-model:search="search"
        :search-placeholder="tOr('tutoring2.admin.leads.searchPh', 'Cari nama, nomor, atau email')"
      >
        <template #chips>
          <AppFilterChip
            :label="tOr('tutoring2.common.status', 'Status')"
            :value="statusFilter
              ? LEAD_STATUS_LABEL[statusFilter]
              : tOr('tutoring2.common.all', 'Semua')"
            icon-name="circle-check"
            :active="!!statusFilter"
            @click="statusFilter = statusFilter ? '' : 'new'"
          />
          <AppFilterChip
            :label="tOr('tutoring2.admin.leads.source', 'Sumber')"
            :value="sourceFilter
              ? LEAD_SOURCE_LABEL[sourceFilter]
              : tOr('tutoring2.common.all', 'Semua')"
            icon-name="megaphone"
            :active="!!sourceFilter"
            @click="sourceFilter = sourceFilter ? '' : 'whatsapp'"
          />
        </template>
      </PageFilterToolbar>

      <AsyncView
        :state="state"
        loading-variant="cards"
        :loading-rows="6"
        :empty-title="tOr('tutoring2.admin.leads.emptyTitle', 'Belum ada lead')"
        :empty-description="tOr('tutoring2.admin.leads.emptyDesc', 'Tambahkan calon siswa dari tombol di kanan bawah.')"
        @retry="reload"
      >
        <template #default="{ data }">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-hidden">
            <table class="w-full text-sm" data-testid="leads-table">
              <thead>
                <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.common.name', 'Nama') }}</th>
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.admin.leads.dateIn', 'Tanggal masuk') }}</th>
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.admin.leads.source', 'Sumber') }}</th>
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.common.status', 'Status') }}</th>
                  <th class="px-4 py-3 font-bold text-right">{{ tOr('tutoring2.common.actions', 'Aksi') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="l in (data as BimbelLead[])"
                  :key="l.id"
                  class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
                  data-testid="lead-row"
                >
                  <td class="px-4 py-3">
                    <button
                      type="button"
                      class="font-bold text-slate-900 hover:text-brand-cobalt text-left"
                      @click="openDetail(l)"
                    >{{ l.name }}</button>
                    <div v-if="l.phone || l.email" class="text-xs text-slate-500 mt-0.5">
                      {{ [l.phone, l.email].filter(Boolean).join(' · ') }}
                    </div>
                  </td>
                  <td class="px-4 py-3 text-slate-600">{{ fmtDate(l.created_at) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ sourceLabel(l) }}</td>
                  <td class="px-4 py-3">
                    <StatusBadge :label="statusLabel(l)" :tone="statusTone(l.status)" uppercase />
                  </td>
                  <td class="px-4 py-3 text-right">
                    <div class="inline-flex items-center gap-1">
                      <button
                        type="button"
                        class="px-2 py-1 rounded-lg text-xs font-semibold text-slate-600 hover:bg-slate-100"
                        @click="openDetail(l)"
                      >{{ tOr('tutoring2.common.detail', 'Detail') }}</button>
                      <button
                        v-if="canManage && isLeadConvertible(l.status)"
                        type="button"
                        data-testid="lead-convert-btn"
                        class="px-2 py-1 rounded-lg text-xs font-semibold text-emerald-700 hover:bg-emerald-50"
                        @click="openConvert(l)"
                      >{{ tOr('tutoring2.admin.leads.convert', 'Konversi') }}</button>
                      <button
                        v-if="canManage && l.status !== 'converted' && l.status !== 'dropped'"
                        type="button"
                        data-testid="lead-drop-btn"
                        class="px-2 py-1 rounded-lg text-xs font-semibold text-red-700 hover:bg-red-50"
                        @click="openDrop(l)"
                      >{{ tOr('tutoring2.admin.leads.drop', 'Batalkan') }}</button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
      </AsyncView>

      <button
        v-if="canManage"
        type="button"
        data-testid="lead-add-cta"
        class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
        @click="openCreate"
      >
        <span aria-hidden="true">+</span>
        {{ tOr('tutoring2.admin.leads.newCta', 'Tambah Lead') }}
      </button>
    </template>

    <!-- ── Create modal ─────────────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'create'"
      :title="tOr('tutoring2.admin.leads.newCta', 'Tambah Lead')"
      :subtitle="tOr('tutoring2.admin.leads.newSubtitle', 'Catat calon siswa baru untuk masuk pipeline.')"
      size="md"
      @close="closeSheet"
    >
      <form class="space-y-md" @submit.prevent="submitCreate">
        <FormField
          v-model="createForm.name"
          :label="tOr('tutoring2.common.name', 'Nama lengkap')"
          required
          :placeholder="'Nama lengkap'"
        />
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
          <FormField
            :model-value="createForm.phone ?? ''"
            :label="tOr('tutoring2.common.phone', 'Nomor telepon')"
            type="tel"
            :placeholder="'+62…'"
            @update:model-value="createForm.phone = String($event)"
          />
          <FormField
            :model-value="createForm.email ?? ''"
            :label="tOr('tutoring2.common.email', 'Email')"
            type="email"
            :placeholder="'email@…'"
            @update:model-value="createForm.email = String($event)"
          />
        </div>
        <FormField
          :model-value="createForm.source"
          :label="tOr('tutoring2.admin.leads.source', 'Sumber')"
          type="select"
          required
          :options="sourceOptions"
          @update:model-value="createForm.source = String($event) as LeadSource"
        />
        <FormField
          field="interest_program_id"
          :model-value="createForm.interest_program_id ?? ''"
          :label="tOr('tutoring2.admin.leads.interestProgram', 'Program yang diminati')"
          type="select"
          :options="programOptionsFor(createForm.interest_program_id)"
          :select-placeholder="tOr('tutoring2.admin.leads.interestProgramPh', 'Belum ditentukan')"
          :disabled="programs.length === 0"
          :error="programs.length === 0
            ? tOr('tutoring2.admin.leads.programsUnavailable', 'Daftar program belum tersedia — bisa diisi nanti dari Detail lead.')
            : ''"
          @update:model-value="createForm.interest_program_id = String($event) || null"
        />
        <p class="-mt-2 text-xs text-slate-500">
          {{ tOr('tutoring2.admin.leads.interestProgramHint', 'Program yang diminati harus terisi sebelum lead bisa dikonversi menjadi pendaftaran.') }}
        </p>
        <FormField
          :model-value="createForm.notes ?? ''"
          :label="tOr('tutoring2.common.notes', 'Catatan')"
          type="textarea"
          :rows="3"
          @update:model-value="createForm.notes = String($event)"
        />
        <div class="flex justify-end gap-2 pt-md border-t border-slate-100">
          <Button variant="ghost" type="button" @click="closeSheet">
            {{ tOr('tutoring2.common.cancel', 'Batal') }}
          </Button>
          <Button variant="primary" type="submit" :loading="submitting">
            {{ tOr('tutoring2.common.save', 'Simpan') }}
          </Button>
        </div>
      </form>
    </Modal>

    <!-- ── Detail sheet ─────────────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'detail' && activeLead"
      :title="activeLead.name"
      :subtitle="tOr('tutoring2.admin.leads.detailSubtitle', 'Riwayat, catatan, dan tindakan lead.')"
      size="lg"
      @close="closeSheet"
    >
      <div class="space-y-md">
        <div class="flex items-center gap-2">
          <StatusBadge :label="statusLabel(activeLead)" :tone="statusTone(activeLead.status)" uppercase />
          <span class="text-xs text-slate-500">
            {{ tOr('tutoring2.admin.leads.dateIn', 'Tanggal masuk') }}:
            {{ fmtDate(activeLead.created_at) }}
          </span>
        </div>

        <form class="space-y-md" @submit.prevent="submitDetail" data-testid="lead-detail-form">
          <FormField
            :model-value="detailForm.name ?? ''"
            :label="tOr('tutoring2.common.name', 'Nama lengkap')"
            :disabled="!canManage"
            @update:model-value="detailForm.name = String($event)"
          />
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
            <FormField
              :model-value="detailForm.phone ?? ''"
              :label="tOr('tutoring2.common.phone', 'Nomor telepon')"
              type="tel"
              :disabled="!canManage"
              @update:model-value="detailForm.phone = String($event)"
            />
            <FormField
              :model-value="detailForm.email ?? ''"
              :label="tOr('tutoring2.common.email', 'Email')"
              type="email"
              :disabled="!canManage"
              @update:model-value="detailForm.email = String($event)"
            />
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
            <FormField
              :model-value="detailForm.source ?? 'website'"
              :label="tOr('tutoring2.admin.leads.source', 'Sumber')"
              type="select"
              :options="sourceOptions"
              :disabled="!canManage"
              @update:model-value="detailForm.source = String($event) as LeadSource"
            />
            <FormField
              :model-value="detailForm.status ?? 'new'"
              :label="tOr('tutoring2.common.status', 'Status')"
              type="select"
              :options="statusOptions"
              :disabled="!canManage"
              @update:model-value="detailForm.status = String($event) as LeadStatus"
            />
          </div>
          <FormField
            field="interest_program_id"
            :model-value="detailForm.interest_program_id ?? ''"
            :label="tOr('tutoring2.admin.leads.interestProgram', 'Program yang diminati')"
            type="select"
            :options="programOptionsFor(detailForm.interest_program_id)"
            :select-placeholder="tOr('tutoring2.admin.leads.interestProgramPh', 'Belum ditentukan')"
            :disabled="!canManage || programs.length === 0"
            :error="programs.length === 0
              ? tOr('tutoring2.admin.leads.programsUnavailable', 'Daftar program belum tersedia — bisa diisi nanti dari Detail lead.')
              : ''"
            @update:model-value="detailForm.interest_program_id = String($event) || null"
          />
          <p class="-mt-2 text-xs text-slate-500">
            {{ tOr('tutoring2.admin.leads.interestProgramHint', 'Program yang diminati harus terisi sebelum lead bisa dikonversi menjadi pendaftaran.') }}
          </p>
          <FormField
            :model-value="detailForm.notes ?? ''"
            :label="tOr('tutoring2.admin.leads.activityLog', 'Catatan / aktivitas')"
            type="textarea"
            :rows="4"
            :disabled="!canManage"
            @update:model-value="detailForm.notes = String($event)"
          />

          <div class="flex flex-wrap justify-between gap-2 pt-md border-t border-slate-100">
            <div class="inline-flex gap-2">
              <Button
                v-if="canManage && isLeadConvertible(activeLead.status)"
                variant="ghost"
                type="button"
                data-testid="lead-detail-convert-btn"
                @click="openConvert(activeLead)"
              >
                {{ tOr('tutoring2.admin.leads.convert', 'Konversi ke pendaftaran') }}
              </Button>
              <Button
                v-if="canManage && activeLead.status !== 'converted' && activeLead.status !== 'dropped'"
                variant="ghost"
                type="button"
                data-testid="lead-detail-drop-btn"
                @click="openDrop(activeLead)"
              >
                {{ tOr('tutoring2.admin.leads.drop', 'Batalkan') }}
              </Button>
            </div>
            <div class="inline-flex gap-2">
              <Button variant="ghost" type="button" @click="closeSheet">
                {{ tOr('tutoring2.common.close', 'Tutup') }}
              </Button>
              <Button v-if="canManage" variant="primary" type="submit" :loading="submitting">
                {{ tOr('tutoring2.common.save', 'Simpan') }}
              </Button>
            </div>
          </div>
        </form>
      </div>
    </Modal>

    <!-- ── Convert modal ────────────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'convert' && activeLead"
      :title="tOr('tutoring2.admin.leads.convertTitle', 'Konversi ke pendaftaran')"
      :subtitle="activeLead.name"
      size="md"
      @close="closeSheet"
    >
      <form class="space-y-md" @submit.prevent="submitConvert" data-testid="lead-convert-form">
        <!-- The lead has no interest program, so the server would
             refuse this before reading any other field. Say so here,
             with the way out, instead of after five filled fields. -->
        <p
          v-if="convertBlockedReason"
          data-testid="lead-convert-blocked"
          class="rounded-2xl bg-amber-50 border border-amber-200 px-md py-sm text-sm text-amber-900"
        >
          {{ convertBlockedReason }}
        </p>

        <!-- Read-only context: the program the enrollment lands in is
             taken from the lead, never from this form. -->
        <p v-else class="text-sm text-slate-600">
          {{ tOr('tutoring2.common.program', 'Program') }}:
          <span class="font-semibold text-slate-900">{{ convertProgramName }}</span>
        </p>

        <p class="text-xs text-slate-500">
          {{
            tOr(
              'tutoring2.admin.leads.convertStudentHint',
              'Konversi memakai data siswa yang sudah terdaftar. Kalau calon siswa ini belum ada di menu Data Siswa, daftarkan dulu di sana, lalu kembali ke sini.',
            )
          }}
        </p>

        <!-- Student — a picker, not a text box. Its value is always an
             id the server issued, or nothing. -->
        <FormField
          :label="tOr('tutoring2.admin.leads.student', 'Siswa')"
          required
          :error="convertErrors.student_id"
        >
          <button
            type="button"
            data-testid="lead-convert-student-trigger"
            class="w-full rounded-xl border border-slate-300 px-md py-sm text-left text-sm focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            :class="selectedStudent ? 'text-slate-900' : 'text-slate-400'"
            @click="showStudentPicker = true"
          >
            <span v-if="selectedStudent">
              {{ selectedStudent.name }}
              <span v-if="selectedStudent.student_number" class="text-slate-500">
                · {{ selectedStudent.student_number }}
              </span>
            </span>
            <span v-else>
              {{ tOr('tutoring2.admin.leads.studentPickPh', 'Pilih siswa…') }}
            </span>
          </button>
        </FormField>

        <!-- FormField has no hint/description affordance — its only
             sub-control line is the red `error` one — so the muted
             sibling <p> below carries the guidance instead, matching
             the hint paragraph this same sheet already uses above.
             `error` is left for the one message that IS a failure. -->
        <div>
          <FormField
            field="package_id"
            :model-value="convertForm.package_id ?? ''"
            :label="tOr('tutoring2.admin.leads.package', 'Paket (opsional)')"
            type="select"
            :options="packageOptions"
            :select-placeholder="tOr('tutoring2.admin.leads.packageNonePh', 'Tanpa paket')"
            :disabled="packageOptions.length === 0"
            :error="packagesLoadError"
            @update:model-value="convertForm.package_id = String($event) || null"
          />
          <p
            v-if="packagesEmptyReason"
            data-testid="lead-convert-package-hint"
            class="text-xs text-slate-500 mt-1"
          >
            {{ packagesEmptyReason }}
          </p>
        </div>
        <div>
          <FormField
            field="learning_group_id"
            :model-value="convertForm.learning_group_id ?? ''"
            :label="tOr('tutoring2.admin.leads.learningGroup', 'Kelompok belajar (opsional)')"
            type="select"
            :options="groupOptions"
            :select-placeholder="tOr('tutoring2.admin.leads.groupNonePh', 'Tanpa kelompok')"
            :disabled="groupOptions.length === 0"
            :error="groupsLoadError"
            @update:model-value="convertForm.learning_group_id = String($event) || null"
          />
          <p
            v-if="groupsEmptyReason"
            data-testid="lead-convert-group-hint"
            class="text-xs text-slate-500 mt-1"
          >
            {{ groupsEmptyReason }}
          </p>
        </div>
        <FormField
          field="billing_mode"
          :model-value="convertForm.billing_mode"
          :label="tOr('tutoring2.common.billingMode', 'Skema tagihan')"
          type="select"
          required
          :options="convertBillingModeOptions"
          @update:model-value="convertForm.billing_mode = String($event) as ConvertLeadPayload['billing_mode']"
        />
        <!-- A native date control. The old free-text box with a
             'YYYY-MM-DD' placeholder was the same shape of problem as
             the id boxes, one size smaller: `start_date` validates as
             `date`, so a typo 422d.

             Bound the long way round — `:model-value` plus an explicit
             handler, the same idiom as the two id selects above —
             rather than with a plain `v-model`. A date input reports a
             CLEARED field as `''`, and this form's contract is that a
             missing start date is `null`: emptiness here means "let the
             backend default it", not "the empty string". `submitConvert`
             prunes a falsy `start_date` out of the payload as a second
             guard, so neither `''` nor `null` can reach the wire — but
             that pruning is one `!` away from being the only thing
             holding the meaning up, which is why the normalisation is
             also spelled out here. -->
        <FormField
          field="start_date"
          type="date"
          :model-value="convertForm.start_date ?? ''"
          :label="tOr('tutoring2.admin.leads.startDate', 'Tanggal mulai')"
          @update:model-value="convertForm.start_date = String($event ?? '') || null"
        />
        <FormField
          :model-value="convertForm.notes ?? ''"
          :label="tOr('tutoring2.common.notes', 'Catatan')"
          type="textarea"
          :rows="3"
          @update:model-value="convertForm.notes = String($event)"
        />
        <div class="flex justify-end gap-2 pt-md border-t border-slate-100">
          <Button variant="ghost" type="button" @click="closeSheet">
            {{ tOr('tutoring2.common.cancel', 'Batal') }}
          </Button>
          <Button
            variant="primary"
            type="submit"
            data-testid="lead-convert-submit"
            :loading="submitting"
            :disabled="!canSubmitConvert"
          >
            {{ tOr('tutoring2.admin.leads.convert', 'Konversi') }}
          </Button>
        </div>
      </form>
    </Modal>

    <!-- Student picker. Teleported to <body> by Modal, so it sits over
         the convert sheet rather than inside its <form> — its buttons
         can't submit anything. Search is served by the API, not by a
         filter over one loaded page. -->
    <FilterFacetPickerModal
      v-if="showStudentPicker"
      :title="tOr('tutoring2.admin.leads.studentPickTitle', 'Pilih siswa')"
      :subtitle="tOr('tutoring2.admin.leads.studentPickSubtitle', 'Cari nama, NIS, atau nama wali.')"
      :options="studentOptions"
      :selected="convertForm.student_id"
      server-search
      :loading="studentsLoading"
      :empty-text="studentsEmptyReason"
      :search-placeholder="tOr('tutoring2.admin.leads.studentSearchPh', 'Cari siswa…')"
      hide-all-reset
      @search="applyStudentSearch"
      @apply="pickStudent"
      @close="showStudentPicker = false"
    />

    <!-- ── Drop confirmation ───────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'drop' && activeLead"
      :title="tOr('tutoring2.admin.leads.dropTitle', 'Tandai lead sebagai batal')"
      :subtitle="activeLead.name"
      size="sm"
      @close="closeSheet"
    >
      <form class="space-y-md" @submit.prevent="submitDrop">
        <p class="text-sm text-slate-600">
          {{ tOr('tutoring2.admin.leads.dropHint', 'Beri alasan singkat — akan disimpan pada catatan lead.') }}
        </p>
        <FormField
          v-model="dropReason"
          type="textarea"
          :rows="3"
          :placeholder="tOr('tutoring2.admin.leads.dropReasonPh', 'Alasan pembatalan')"
        />
        <div class="flex justify-end gap-2 pt-md border-t border-slate-100">
          <Button variant="ghost" type="button" @click="closeSheet">
            {{ tOr('tutoring2.common.cancel', 'Batal') }}
          </Button>
          <Button variant="danger" type="submit" :loading="submitting">
            {{ tOr('tutoring2.admin.leads.drop', 'Batalkan lead') }}
          </Button>
        </div>
      </form>
    </Modal>
  </div>
</template>
