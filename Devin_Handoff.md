# Devin Handoff — KamilEdu Mobile UI Redesign

> **Goal:** hand the entire UI redesign work to [Devin](https://app.devin.ai/) so it executes the P0 bug fixes, then P1 (bottom nav shell), then P2-P5, while you review and merge.
>
> **What Devin gets:** repo access + 4 source-of-truth docs (`CLAUDE.md`, `UI_Redesign_Audit.md`, `P1_BottomNav_Spec.md`, `P0_PR_Plan.md`) + the `_baseline/` screenshot folder.
>
> **How you drive it:** copy-paste a prompt per session, review the merge request, repeat.

This doc is a checklist. Work it top to bottom.

---

## Phase 0 — Pre-flight (do this before opening Devin)

### 0.1 Make 4 product decisions

These block specific PRs. Write your answer next to each item — Devin will read this doc.

- [ ] **PR-8 scope** — Verifikasi tab. Inline `[✓][✗]` icons on each row + reuse existing `verification_dialog.dart` as the confirm sheet? **Default: yes.**  → Your answer: ____
- [ ] **PR-10 payment flow** — `(a)` in-app payment gateway (Midtrans/Xendit) or `(b)` bank transfer + receipt upload reusing existing payment-proof pipeline? **Default: (b).**  → Your answer: ____
- [ ] **PR-12 brand string** — `(a)` "KamilEdu" everywhere / `(b)` "Manajemen Sekolah" everywhere / `(c)` "KamilEdu" on login + "Manajemen Sekolah" as in-app feature label. **Default: (c).**  → Your answer: ____
- [ ] **PR-13 timing** — ship Class Activity reflow now or defer to P6? **Default: defer.**  → Your answer: ____

Also answer the **10 open questions in `P1_BottomNav_Spec.md` § 10** (Q1-Q10) before kicking off the P1 session. Until those are answered, Devin will not be able to start P1.

### 0.2 Repo prep

```bash
# from your laptop, in the kamiledu-mobile-flutter repo:

git checkout main          # or whatever your shipping branch is
git pull origin main
git checkout -b redesign/p0-bug-sweep   # parent branch for the P0 sprint
git push -u origin redesign/p0-bug-sweep
```

Devin will branch each PR off this. After each PR merges into `redesign/p0-bug-sweep`, you do a single squash-merge of the parent branch into `main` at the end.

### 0.3 Make sure these files are committed to the repo

Devin reads from the repo, not from your laptop. Confirm these are tracked + pushed:

- [ ] `CLAUDE.md` (project working rules)
- [ ] `UI_Redesign_Audit.md` (the 921-line audit)
- [ ] `P1_BottomNav_Spec.md` (the 430-line P1 spec)
- [ ] `P0_PR_Plan.md` (the 470-line PR plan)
- [ ] `_baseline/CAPTURE_CHECKLIST.md` and `_baseline/{shared,admin,teacher,parent}/*.png` (the 75 screenshots)

Run:

```bash
git add CLAUDE.md UI_Redesign_Audit.md P1_BottomNav_Spec.md P0_PR_Plan.md _baseline/
git commit -m "docs(redesign): land audit, P1 spec, P0 plan, baseline screenshots"
git push origin redesign/p0-bug-sweep
```

---

## Phase 1 — Devin onboarding (one-time, ~15 min)

### 1.1 Account + repo connection

1. Sign up / sign in at https://app.devin.ai/.
2. **Settings → Integrations → GitLab** → connect.
3. Authorize Devin for the `kamil-labs/kamil-edu/mobile/edu_frontend_core_mobile` repo. Devin needs:
   - read repo
   - create branches
   - open merge requests
4. Settings → Repository defaults → set the default base branch to `redesign/p0-bug-sweep` for this project.

### 1.2 Environment config (so Devin can run `dart analyze` + `dart format`)

In Devin's repo settings → **Environment**, add:

```bash
# Flutter SDK install (Devin's snapshot machine)
git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
export PATH="$PATH:/opt/flutter/bin"
flutter doctor
flutter pub get
```

Or, if Devin has a Flutter preset (it does — pick "Flutter / Dart"), just select it. Confirm version is **3.9.0+**.

After setup, run a smoke test in Devin:

```bash
dart --version             # expect: Dart 3.9+
flutter --version          # expect: Flutter 3.x with Dart 3.9+
flutter pub get            # populates .dart_tool/
dart analyze lib/          # baseline analyzer — should be clean before any work
```

If `dart analyze` already has warnings on the base branch, capture them so Devin knows what to ignore vs. what it introduced.

### 1.3 Give Devin its persistent knowledge

In Devin's project knowledge panel (the equivalent of "AGENTS.md"), paste this:

```
You are working on KamilEdu Mobile, a Flutter app (project name: manajemensekolah).
Repo: GitLab kamil-labs/kamil-edu/mobile/edu_frontend_core_mobile.
Flutter SDK: 3.9.0+. Dart 3.9+.

YOUR PROJECT RULES live in CLAUDE.md at the repo root. Read it first, every session.
The "one rule" is: Satu implementasi, tiga role — reach for shared widgets in
lib/core/widgets/ before building anything. The full shared catalog is in
lib/core/widgets/README.md.

THE REDESIGN IS DOCUMENTED IN THESE FILES:
- UI_Redesign_Audit.md — the 921-line audit (what's wrong + reflow proposals + 19 P0 bugs).
- P1_BottomNav_Spec.md — implementation spec for the bottom nav shell.
- P0_PR_Plan.md — 13 scoped PRs to fix the P0 bugs. Each session in this project
  corresponds to one PR from this plan.

YOUR WORKFLOW:
1. Read CLAUDE.md + the relevant section of P0_PR_Plan.md or P1_BottomNav_Spec.md.
2. Branch off redesign/p0-bug-sweep with name redesign/<pr-id>-<short-slug>.
3. Implement the change strictly to the scope described in the PR section.
4. Run dart format on touched files. Run dart analyze on the touched feature dir.
5. Open a merge request titled exactly the way P0_PR_Plan.md specifies the commit.
6. In the MR description, link the relevant section of P0_PR_Plan.md and list
   verification steps from that section.

WHAT NOT TO DO:
- Do not commit changes outside the PR's stated scope. If you find unrelated bugs,
  open a separate task; don't bundle.
- Do not deviate from CLAUDE.md conventions: Bahasa Indonesia for UI, ColorUtils for
  colors, AppNavigator for navigation, AppSpacing for paddings, SnackBarUtils for
  toasts. No Colors.{xxx} hex literals.
- Do not skip dart format / dart analyze.
- Do not commit Co-Authored-By trailers other than: Co-Authored-By: Devin
  <devin-ai-integration[bot]@users.noreply.github.com>

WHEN STUCK:
- If a file's structure doesn't match the PR plan (e.g. file moved, widget renamed),
  STOP and report rather than guess. Reply with what you found and what's missing.
- If a decision is required (the PR section says "scope decision required"), STOP
  and ask. Do not pick yourself.
```

### 1.4 Test session — verify Devin can read the repo

Open a new Devin session. Paste this short prompt:

```
Read CLAUDE.md, UI_Redesign_Audit.md (executive summary + P0 bugs section only), and
P0_PR_Plan.md (effort summary table only). Then reply with:
1. Which file is the project working contract?
2. How many P0 bugs are listed?
3. List the 13 PRs from P0_PR_Plan.md by id and title.

Do not make any code changes.
```

Expect: Devin replies with `CLAUDE.md`, `19`, and the PR-1…PR-13 list. If any of these are wrong, Devin's repo access or context loading is broken — fix that before kicking off real work.

---

## Phase 2 — Run the P0 sprint (PR-1 through PR-13)

For each PR below, **open a fresh Devin session**, paste the prompt verbatim, wait, review the MR, merge.

### PR-1 prompt

```
Task: PR-1 from P0_PR_Plan.md — Role-color contract sweep.

Read:
- CLAUDE.md (entire file)
- P0_PR_Plan.md § PR-1 (entire section, including verification + commit message)
- UI_Redesign_Audit.md § "P0 bugs" (rows 5, 6 only, for context)
- lib/core/utils/color_utils.dart (entire file)

Goal: every AppBar in the app derives its color from ColorUtils.getRoleColor(role).
Fix the two known leaks (notifications + parent billing) and sweep for any others.

Branch: redesign/pr1-role-color-sweep
Base branch: redesign/p0-bug-sweep

Constraints:
- Do not touch files outside the role-color scope.
- Do not introduce new color tokens — use what's in color_utils.dart.
- If a screen takes role as a constructor param, use it. If not, infer from auth state
  (check existing patterns in lib/features/dashboard/).

Verification (run before opening the MR):
1. dart format lib/features/notifications lib/features/finance
2. dart analyze lib/features/notifications lib/features/finance
3. grep -rn "Colors\.green\|Colors\.blue\|Colors\.purple" lib/features/*/presentation/screens/
   — should be empty after sweep
4. Capture before/after screenshots if you have a test device; otherwise note in MR
   "screenshot diff pending human review"

Open MR with the title and description from P0_PR_Plan.md § PR-1's "Conventional commit"
block. Tag the MR with: ui-redesign, p0.
```

### PR-2 prompt

```
Task: PR-2 from P0_PR_Plan.md — Dashboard hero + label-wrap polish.

Read:
- CLAUDE.md (Tone & Formatting + Don't-dos sections)
- P0_PR_Plan.md § PR-2
- UI_Redesign_Audit.md § A1 + § P1 (parent dashboard)
- lib/features/dashboard/presentation/widgets/dashboard_hero_section.dart
- lib/features/dashboard/presentation/widgets/quick_action_button.dart
- lib/features/dashboard/presentation/widgets/parent_menu_items_mixin.dart

Goal: fix three small visual bugs:
1. Admin hero text contrast (dark grey on near-black → white).
2. "Pengaturan" QuickAction tile label wraps to "Pengatura\nn" — shorten to "Setelan".
3. Parent Akses Cepat "Pengumuman" tile truncates to "Pengumum…" — shorten or fix
   tile width.

Branch: redesign/pr2-dashboard-polish
Base branch: redesign/p0-bug-sweep

Constraints: no structural changes — these are 3 surgical fixes.

Verification:
1. dart format on touched files
2. dart analyze lib/features/dashboard
3. Read the two _baseline/ images (admin/01_dashboard.png, parent/01_dashboard.png) to
   confirm what the current state is before changing.
4. Note in MR: "Hero text WCAG AA target ≥ 4.5:1 — pending screenshot verification."

Open MR per P0_PR_Plan.md § PR-2 commit message block.
```

### PR-3 prompt

```
Task: PR-3 from P0_PR_Plan.md — Auth, clear stale error toast on login success.

Read:
- CLAUDE.md
- P0_PR_Plan.md § PR-3
- lib/features/auth/presentation/screens/login_screen.dart (entire file)
- lib/core/utils/snackbar_utils.dart (entire file)
- lib/core/utils/error_utils.dart (entire file)

Goal: when login succeeds, dismiss any pending error snackbars before transitioning
to the school/role picker step.

Branch: redesign/pr3-auth-toast-fix
Base branch: redesign/p0-bug-sweep

Investigation steps (do these first, report back what you find):
1. Identify where the school picker (S2) and role picker (S3) are implemented — are
   they separate screens, or multi-step states inside login_screen.dart?
2. Identify where "Email atau password salah" is shown.
3. Identify where login success transitions to the next step.

Then implement:
- Call ScaffoldMessenger.of(context).clearSnackBars() (or add a SnackBarUtils.dismiss
  helper if one doesn't exist) at the success-handler boundary.

Verification:
1. dart format + dart analyze on touched files.
2. Manual repro steps written into the MR body:
   - Enter wrong creds → tap MASUK → toast appears
   - Enter correct creds → tap MASUK → toast should dismiss before role picker shows
3. Same fix should apply to school picker (S2) — verify both transitions.

Open MR per P0_PR_Plan.md § PR-3 commit block.
```

### PR-4 prompt

```
Task: PR-4 from P0_PR_Plan.md — Drop trash icon on attendance report rows.

Read:
- CLAUDE.md (Don't-dos section especially)
- P0_PR_Plan.md § PR-4
- lib/features/attendance/presentation/screens/admin_attendance_report_screen.dart

Goal: remove the per-row delete affordance from admin attendance report. Attendance
records are an audit trail; admins should not be able to delete individual entries.

Branch: redesign/pr4-attendance-no-delete
Base branch: redesign/p0-bug-sweep

Constraints:
- Only remove the visible IconButton; preserve the underlying delete handler in case
  it's used by bulk-mode or 3-dot overflow.
- ~15 minute fix. If you find the change requires touching more than 2 files, STOP
  and report.

Verification:
1. dart format + dart analyze on the touched file.
2. Note in MR: screenshot diff against _baseline/admin/11_attendance_report.png — trash
  icon should be gone from each row.

Open MR per P0_PR_Plan.md § PR-4 commit block.
```

### PR-5 prompt

```
Task: PR-5 from P0_PR_Plan.md — RPP scoping fix (admin Kelola RPP shows all teachers).

Read:
- CLAUDE.md
- P0_PR_Plan.md § PR-5
- UI_Redesign_Audit.md § A12 (entire section, including the recommendation)
- lib/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart
- lib/features/dashboard/presentation/widgets/admin_menu_items_mixin.dart (look for the
  "Kelola RPP" tile route)
- lib/features/lesson_plans/presentation/widgets/ (look for filter sheet content)

Goal: when admin reaches "Kelola RPP" from the dashboard menu, show ALL teachers'
RPPs (not pre-scoped to one teacher) with a teacher chip on each row.

Branch: redesign/pr5-rpp-scoping
Base branch: redesign/p0-bug-sweep

Implementation:
1. Title becomes "Semua RPP" (or "Kelola RPP" — match the menu tile label).
2. Each row gains a teacher chip (similar to other admin list rows).
3. Filter sheet adds a teacher filter chip section — extend TeacherFilterContent if
   needed, per CLAUDE.md "extend, don't duplicate" guidance.

Verification:
1. dart format + dart analyze on lib/features/lesson_plans
2. Manual: dashboard → Kelola RPP → see RPPs from all teachers, with teacher chip
3. Filter by teacher → narrows to one teacher's RPPs

Open MR per P0_PR_Plan.md § PR-5 commit block.
```

### PR-6 prompt

```
Task: PR-6 from P0_PR_Plan.md — Schedule matrix duplicate-row investigation.

Read:
- P0_PR_Plan.md § PR-6
- UI_Redesign_Audit.md § A6 (the 🔴 Critical observation)
- _baseline/admin/06_schedule_matrix.png (note what's visually duplicated)
- lib/features/schedule/presentation/screens/admin_schedule_management_screen.dart
- lib/features/schedule/presentation/widgets/ (matrix view widgets)
- lib/core/widgets/frozen_column_table.dart

Goal: every "Jam 1" row in the matrix view shows the same two entries
("B. Arab 8B" + "Bahasa Indonesia 7B"). Find out whether this is bad seed data or a
render bug, then fix.

Branch: redesign/pr6-schedule-matrix-investigation
Base branch: redesign/p0-bug-sweep

Investigation steps (report findings before fixing):
1. Hit the schedule API endpoint manually — does the response have distinct entries
   per slot, or duplicates?
2. If API is correct, the bug is in the matrix builder. Check whether it's iterating
   slots correctly or accidentally referencing slots[0] inside the row builder.
3. If API is wrong, identify whether seed data or aggregation query needs fixing.

After investigation, post a comment in the session with your finding before
implementing the fix.

Verification:
1. dart format + dart analyze
2. Re-screenshot the matrix view; rows should show distinct entries per time slot.
3. If the fix was on the API side, document in MR which endpoint/aggregation was
   touched.

Open MR per P0_PR_Plan.md § PR-6 commit block (description depends on root cause).
```

### PR-7 prompt — the big sweep

```
Task: PR-7 from P0_PR_Plan.md — Per-row action sweep (Theme 7).

Read:
- CLAUDE.md (entire file, especially the "one rule" and the don't-dos)
- P0_PR_Plan.md § PR-7
- UI_Redesign_Audit.md § "Theme 7 — Per-row destructive actions are systemic"
- lib/core/widgets/README.md (BulkActionBar section)
- lib/core/widgets/admin_crud_scaffold/ (entire folder)

Goal: drop per-row edit-pen + trash-icon across 8+ admin CRUD screens. Convention
becomes:
- tap row → opens detail/edit sheet
- long-press → enters bulk-select mode (uses existing BulkActionBar)
- FAB → adds new

Branch: redesign/pr7-per-row-sweep
Base branch: redesign/p0-bug-sweep

Files to touch (verify each exists first):
- lib/features/students/presentation/screens/admin_student_management_screen.dart
- lib/features/teachers/presentation/screens/admin_teacher_management_screen.dart
- lib/features/classrooms/presentation/screens/admin_classroom_management_screen.dart
- lib/features/subjects/presentation/screens/admin_subject_management_screen.dart
- lib/features/schedule/presentation/screens/admin_schedule_management_screen.dart
- lib/features/announcements/presentation/screens/admin_announcement_screen.dart
- lib/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart
- lib/features/finance/presentation/widgets/payment_type_card.dart
- lib/features/finance/presentation/widgets/billing_card.dart

Constraints:
- Mechanical sweep. Each file change should be a few-line delete (the trailing icon
  Row), plus wiring tap-to-edit if not already wired.
- DO NOT delete the underlying delete handlers — they're reachable via bulk-mode and
  3-dot overflow.
- DO NOT add features. Just remove the per-row icons.
- If a screen doesn't have per-row icons, skip it and note in MR.

Verification:
1. dart format on all touched files.
2. dart analyze on lib/features/ (whole dir, since this touches 8+ files).
3. Manual smoke test note in MR: each affected screen — tap row opens edit, long-press
   enters bulk mode, FAB adds.
4. grep -rn "IconButton.*delete\|Icons.delete" lib/features/*/presentation/screens/
   should show fewer hits than before.

Open MR per P0_PR_Plan.md § PR-7 commit block. THIS IS A LARGE PR — review may take
longer; that's expected.
```

### PR-8 prompt (if you decided "yes" on the scope)

```
Task: PR-8 from P0_PR_Plan.md — Verifikasi tab redesign (drop mega-button-per-row).

PRECONDITION: confirm with project owner that the recommendation in P0_PR_Plan.md
§ PR-8 ("inline check/reject icons + reuse verification_dialog as confirm sheet") is
approved. If not approved, STOP and ask.

Read:
- CLAUDE.md
- P0_PR_Plan.md § PR-8
- UI_Redesign_Audit.md § A7 (Verifikasi tab section)
- lib/features/finance/presentation/widgets/finance_verification_tab.dart
- lib/features/finance/presentation/widgets/pending_payment_card.dart
- lib/features/finance/presentation/widgets/verification_dialog.dart

Goal: each pending verification row becomes compact, with inline [check][reject] icons
on the right. Tap check → opens verification_dialog as confirm sheet (with payment
proof preview, Approve/Cancel). Tap reject → opens reject sheet (textarea for reason
+ Tolak/Cancel).

Branch: redesign/pr8-verifikasi-redesign
Base branch: redesign/p0-bug-sweep

Implementation:
1. Update pending_payment_card.dart row layout: avatar + student name + meta + spacer
   + ✓-circle + ✗-circle.
2. Wire ✓ → opens existing verification_dialog refactored as a sheet (use
   AppBottomSheet + BottomSheetFooter per CLAUDE.md "composition pattern").
3. Add new widget: lib/features/finance/presentation/widgets/reject_payment_sheet.dart
   with a reason textarea.

Verification:
1. dart format + dart analyze lib/features/finance
2. Seed test data with 5+ pending payments. Verifikasi tab should show 5+ compact
   rows, not 5 mega-buttons.
3. Tap ✓ on a row → confirm sheet opens. Tap ✗ → reject sheet opens.

Open MR per P0_PR_Plan.md § PR-8 commit block.
```

### PR-9 prompt

```
Task: PR-9 from P0_PR_Plan.md — Parent empty Kelas: data path bug.

Read:
- CLAUDE.md
- P0_PR_Plan.md § PR-9
- UI_Redesign_Audit.md § P2, P3, P4 (P4 is the working example)

Investigation FIRST (do not implement until you have a finding to report):
1. Open lib/features/class_activity/presentation/screens/parent_class_activity_screen.dart
   — find where it renders "Kelas: 7A" successfully. Identify the data source field.
2. Open lib/features/attendance/presentation/screens/parent_attendance_screen.dart
   and lib/features/grades/presentation/screens/parent_grade_screen.dart — identify
   their data sources for the same child profile card.
3. Diff: same model field referenced? same API call? same fallback?
4. Likely culprit: P4 hits a different endpoint that includes class join, while P2/P3
   hit a leaner endpoint that omits it.

Report your finding in the session, then implement.

Branch: redesign/pr9-parent-kelas-bug
Base branch: redesign/p0-bug-sweep

Verification:
1. dart format + dart analyze on touched files
2. Manual: all three parent screens (P2/P3/P4) should show the same Kelas value for
   the same child.
3. If the fix was backend (different endpoint or join), document in MR which path
   was changed.

Open MR per P0_PR_Plan.md § PR-9.
```

### PR-10 prompt (after deciding option a or b)

```
Task: PR-10 from P0_PR_Plan.md — Parent Billing Bayar Sekarang flow.

PRECONDITION: confirm decision on payment flow:
- Option (a): in-app payment gateway (Midtrans/Xendit) — heavier, needs SDK
- Option (b): bank transfer + receipt upload — lighter, reuses payment-proof pipeline

If decision not yet made, STOP and ask. The default in P0_PR_Plan.md is (b).

Read (if (b)):
- CLAUDE.md
- P0_PR_Plan.md § PR-10
- UI_Redesign_Audit.md § P6 (entire section, including the reflow sketch)
- lib/features/finance/presentation/screens/parent_billing_screen.dart
- lib/features/finance/presentation/widgets/billing_card.dart
- lib/features/finance/presentation/widgets/verification_dialog.dart (existing
  payment-proof pattern on admin side)
- lib/core/widgets/app_bottom_sheet.dart + bottom_sheet_footer.dart

Goal: parent billing rows get due-date, "Bayar Sekarang" CTA, and metode i18n fix.
Tap CTA → opens payment_transfer_sheet with bank details + "Unggah Bukti" upload.

Branch: redesign/pr10-bayar-sekarang
Base branch: redesign/p0-bug-sweep

Implementation:
1. Update billing_card.dart row layout per the audit's reflow sketch:
   title + amount + period + due-date + "Belum Bayar" pill + Bayar Sekarang CTA.
2. New widget: lib/features/finance/presentation/widgets/payment_transfer_sheet.dart
   — uses AppBottomSheet + BottomSheetFooter. Shows bank account details + receipt
   upload affordance.
3. Backend integration: confirm existing payment-proof endpoint accepts parent-
   initiated proofs. If yes, wire it. If no, document the backend change needed
   and STOP.
4. i18n: ONCE → Sekali, MONTHLY → Bulanan. Find the strings — likely hardcoded in
   parent_billing_screen.dart or in lib/l10n/.

Verification:
1. dart format + dart analyze lib/features/finance
2. Manual: parent → Tagihan → tap Bayar Sekarang → sheet with bank details + upload.
3. Upload a test receipt → admin's Verifikasi tab shows the new pending entry.
4. Confirm AppBar is purple (PR-1 should have already fixed this — if not, address
   here too).

Open MR per P0_PR_Plan.md § PR-10.
```

### PR-11 prompt

```
Task: PR-11 from P0_PR_Plan.md — Parent Announcements polish (date + priority + grouping).

Read:
- CLAUDE.md
- P0_PR_Plan.md § PR-11
- UI_Redesign_Audit.md § P5 + § T11 (teacher version is the model)
- lib/features/announcements/presentation/screens/parent_announcement_screen.dart
- lib/features/announcements/presentation/screens/teacher_announcement_screen.dart
  (mirror its date-section grouping pattern)

Goal: parent announcement rows currently lack date, priority pill, and date-section
grouping. Bring parent in line with teacher version.

Branch: redesign/pr11-parent-announcements
Base branch: redesign/p0-bug-sweep

Implementation:
1. Row composition: icon + title + body preview + meta-row (date + audience + Penting
   pill if applicable).
2. Date-section grouping: sections by month ("April 2026", "Maret 2026") with priority
   counts in the section header.
3. Reuse the section-builder pattern from teacher_announcement_screen.dart — extract
   into a shared widget if both versions can use it.

Verification:
1. dart format + dart analyze lib/features/announcements
2. Screenshot diff vs _baseline/parent/05_announcements.png — each row shows date +
   Penting pill, sections grouped by month.

Open MR per P0_PR_Plan.md § PR-11.
```

### PR-12 prompt (after deciding brand option)

```
Task: PR-12 from P0_PR_Plan.md — Login polish (Lupa Password + brand).

PRECONDITION: confirm brand decision (a / b / c). Default is (c): "KamilEdu" on
login, "Manajemen Sekolah" as in-app feature label. If not decided, STOP and ask.

Read:
- CLAUDE.md
- P0_PR_Plan.md § PR-12
- UI_Redesign_Audit.md § S1
- lib/features/auth/presentation/screens/login_screen.dart
- lib/l10n/ (i18n strings)

Goal: add "Lupa Password?" link below password field; add forgot-password sheet;
standardize brand string per decision.

Branch: redesign/pr12-login-polish
Base branch: redesign/p0-bug-sweep

Implementation:
1. "Lupa Password?" navy text-link, right-aligned, below password field.
2. New sheet: lib/features/auth/presentation/sheets/forgot_password_sheet.dart —
   email input + "Kirim Tautan Reset" button. Uses AppBottomSheet + BottomSheetFooter.
3. Backend: confirm a password-reset endpoint exists. If not, scope is bigger — STOP
   and document.
4. Brand: apply per decision (a/b/c). Update login_screen.dart and any AppBar that
   referenced the wrong string.

Verification:
1. dart format + dart analyze
2. Manual: login screen → Lupa Password link visible → tap → sheet opens → submit
   email → success toast.
3. Brand string consistent across login + AppBars.

Open MR per P0_PR_Plan.md § PR-12.
```

### PR-13 prompt (only if you decided to ship now)

```
Task: PR-13 from P0_PR_Plan.md — Class Activity reflow (time-scoped feed).

PRECONDITION: confirm with project owner this is shipping in P0 sprint, not deferred
to P6. The default in P0_PR_Plan.md is to defer.

If shipping: read P0_PR_Plan.md § PR-13 + UI_Redesign_Audit.md § A14 + the entire
file at lib/features/class_activity/presentation/screens/admin_class_activity_screen.dart
and rebuild as a chronological activity feed with today/week/month segment.
Per-teacher drill becomes a secondary filter chip, not a default navigation step.

Branch: redesign/pr13-class-activity-feed
Base branch: redesign/p0-bug-sweep

This is a 2-day refactor. Take your time. Open the MR with detailed before/after
notes.
```

---

## Phase 3 — Review gates between sessions

For each MR Devin opens:

1. **Read the diff.** Don't skip. Devin is good but it makes mistakes.
2. **Check the verification steps** Devin claims it ran. If `dart analyze` output isn't shown, ask Devin to paste it.
3. **Pull the branch locally + run the app on a device.** Visual diffs need eyes.
4. **Approve + merge into `redesign/p0-bug-sweep`.** Use squash-merge to keep the parent branch clean.
5. **If something's wrong:** comment on the MR with the specific issue. Devin will revise.

After PR-1 through PR-12 are merged into `redesign/p0-bug-sweep`, you do one final review of the parent branch and merge into `main`.

---

## Phase 4 — Recovery procedures

### Devin says "I can't find file X"

The repo state may have shifted. Reply with: `Run \`find lib -name "<filename>"\` and report the actual path. Then update your plan to use that path.`

### Devin's MR has unrelated changes

Comment: `Please drop changes outside the stated PR scope. Revert the unrelated edits and force-push to the same branch.`

### Devin gets stuck on a decision

The prompts say "STOP and ask" for decision points. If Devin pushed code without asking on a STOP-and-ask, comment: `Please revert. The PR plan required a product decision before this change.`

### Devin's `dart analyze` has new errors

Comment with the specific errors. Devin will fix. If Devin claims they're pre-existing, you can verify by checking out the base branch yourself — no work needed if true.

### Devin uses Colors.{xxx} hex literals

CLAUDE.md violation. Comment: `Per CLAUDE.md, no hex literals in presentation code — use ColorUtils. Please refactor.`

---

## Phase 5 — After P0, hand off P1 (bottom nav shell)

Once `redesign/p0-bug-sweep` is merged into `main`, kick off P1:

```
Task: Implement P1 (bottom nav shell) per P1_BottomNav_Spec.md.

Read:
- CLAUDE.md (entire)
- P1_BottomNav_Spec.md (entire — this is a 430-line spec; budget time to read it)
- UI_Redesign_Audit.md § "Information Architecture reflow" (Proposal 1)

Pre-flight: confirm answers to Q1-Q10 from P1_BottomNav_Spec.md § 10. If any are
unanswered, STOP and ask.

Branch: redesign/p1-bottom-nav-shell
Base branch: main

Implementation: follow P1_BottomNav_Spec.md § 9 (file plan) verbatim. The doc lists
18 new files and 6 modified files. Build incrementally:

Sub-PR 1: shell skeleton — RoleShell, ShellState, ShellNotifier, role_tabs.dart,
shell_nav.dart, shell_tab.dart. No tabs wired yet. Feature flag kEnableShell = false.

Sub-PR 2: admin tabs — wrap existing AdminDashboardBody as Beranda; build hub
roots (AdminOrangHubScreen, AdminAkademikHubScreen). Migrate admin menu mixin
to ShellNav.goTo. Flip kEnableShell only on internal builds.

Sub-PR 3: teacher tabs — same pattern.

Sub-PR 4: parent tabs — same pattern.

Sub-PR 5: FCM rewire — fcm_notification_router becomes thin wrapper around
ShellNav.goTo (or delete per Q10).

Sub-PR 6: feature flag removal + legacy dashboard branch deletion.

Each sub-PR opens its own MR. Don't bundle.

Verification per sub-PR is in P1_BottomNav_Spec.md § 8 (testing checklist).
```

---

## Estimated Devin cost / time

- **P0 sprint** (PR-1 through PR-12): ~10 dev-days of Devin time. At Devin's rate (varies by plan), budget accordingly. Calendar time is shorter — most PRs run in parallel.
- **P1 implementation**: ~3 weeks of incremental sub-PRs.
- **Your time**: ~2-4 hours per day reviewing MRs during the sprint. Less once a rhythm forms.

---

## TL;DR — your daily loop during the sprint

1. Morning: copy a PR prompt from this doc, paste into a fresh Devin session, hit submit.
2. Midday: check Devin's progress. Answer questions if Devin pinged you.
3. Afternoon: review the MR Devin opened. Merge or comment.
4. Repeat with the next PR.

The hard work is decision-making and review. Devin does the typing.
