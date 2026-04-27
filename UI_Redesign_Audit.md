# UI Redesign Audit — KamilEdu Mobile

**Date opened:** 2026-04-24
**Last updated:** 2026-04-27 (per-screen audits filled from baseline screenshots)
**Author:** Claude (grounded in code walk + three-role Admin Refactor just shipped + 75 baseline captures)
**Status:** ✅ IA analysis, cross-cutting themes, and per-screen audits complete. Ready for prioritization + handoff.

## Purpose

The post-refactor state is clean at the component level — every admin screen is on `AdminCrudScaffold`, every sheet is on `AppEditBottomSheet` / `AppBottomSheet`, every filter is on `AppFilterBottomSheet`. But the **product surface still feels messy**: menus are overloaded, categories are fuzzy, and common tasks require too many pushes. This document identifies the root causes and proposes a reflow.

The audit is deliberately separated into two parts:

1. **Information Architecture (IA)** — how screens are grouped and reached. This is the root cause of the "messy" feeling and is the highest-impact area to redesign first.
2. **Per-screen layout** — density, hierarchy, and grouping inside each screen. Cheaper to fix, but lower impact until IA is settled.

---

## Executive summary — the three root causes

1. **Menu categories don't match user mental models.** Teacher "Penilaian" holds Lesson Plans (planning, not assessment) and Announcements (communication, not assessment). Admin "Data Management" holds Input Grades. When a category promises one thing and delivers five, users scan every tile every time — that *is* the messy feeling.
2. **The dashboard is doing six jobs at once.** It's a hero-stats page, a pending-inbox, a quick-action launcher, a categorized menu, a today-schedule slider, *and* a modal host for finance/attendance popups. Each of those is defensible; together they flatten every opportunity for visual hierarchy.
3. **Deep flows always return to the dashboard.** There is no bottom nav, no persistent sidebar, no tab-scoped back behaviour — so moving from "check RPP review queue" to "respond to a pending payment verification" is three full pushes + three back-presses. The dashboard becomes the de-facto router, which makes *it* feel over-stuffed even though the individual sections are reasonable.

Fix those three and most per-screen critique becomes optional polish.

---

## Cross-cutting themes

### Theme 1 — Overloaded menu categories

From `teacher_menu_items_mixin.dart`, `admin_menu_items_mixin.dart`, `parent_menu_items_mixin.dart`:

**Teacher — "Pembelajaran" (4 items):** Jadwal Mengajar, Kegiatan Kelas, Absensi Siswa, Materi Pembelajaran.
**Teacher — "Penilaian" (6 items):** Input Nilai, Rekap Nilai, Raport, **RPP**, **Pengumuman**, **Rekomendasi Belajar**.

RPP is a *planning* tool, Pengumuman is *communication*, Rekomendasi Belajar is *AI insight*. Forcing them into "Penilaian" creates three problems: (a) users scan a 6-item list to find a 2-item intent, (b) "Penilaian" stops being a useful concept, (c) there's no home for future communication or AI features.

**Admin — "Manajemen Data" (3 items):** Manage Data, Jadwal, **Input Nilai**. Grading isn't data management.
**Admin — "Akademik" (5 items):** Pengumuman, Kegiatan Kelas, Absensi Report, RPP, Raport. Announcements are not academic; they're communication.
**Admin — "Keuangan" (2 items):** Finance + **Pengaturan Sekolah**. Settings is not finance — it's here as overflow.

**Parent — flat 6-item list.** No grouping; not a problem at 6 items but the order (Announcements → Class Activities → Grades → Presence → Billing → Report Card) mixes communication, monitoring, and admin.

### Theme 2 — The dashboard carries too much

`dashboard_screen.dart` mixes in 4 behavioural mixins (`Helpers`, `ContentBuilders`, `Cards`, `Dialog`) and consumes 29 widget files under `dashboard/presentation/widgets/`. It renders (in order):

1. Gradient header with `SchoolPill`
2. Hero stats row (3 stat cells)
3. Pending inbox card (4 inbox items)
4. Quick action grid (4 tiles)
5. Categorized menu (7–10 tiles grouped into 2–3 sections)
6. Today's schedule slider (teacher only)
7. Finance / attendance popup dialogs (hosted as modal children)

Individually all reasonable. Stacked, the first-fold (before the user scrolls) is: 1 header + 3 stats + 4 inbox + 4 quick actions = **12 interactive elements competing for first-two-seconds attention**. Hero stats and the pending inbox both fight to be "the thing the user sees first." Quick actions and the categorized menu are semantically the same thing rendered twice.

### Theme 3 — No persistent navigation shell

There's no `BottomNavigationBar`, no `NavigationRail`, no drawer, no tabs. Every screen is `AppNavigator.push(...)`. Deep flows like *finance → verify → back to hub → drill into class report → back → generate bills* stack four pushes and four back-presses. The user ends up returning to the dashboard to "re-route" — which makes the dashboard feel essential, which makes it overloaded, which makes the app feel messy. A classic IA trap.

### Theme 4 — Duplicated settings / hub surfaces

Settings currently lives across:

- `settings_screen.dart` — account settings
- `system_settings_screen.dart` — admin hub (T4.5)
- `school_settings_screen.dart` — school profile
- `school_level_settings_screen.dart` — per-level (tingkat) settings
- `time_settings_screen.dart` — jam pelajaran
- `data_management_screen.dart` — master data

Admin can reach Master Data via **both** a top-level menu tile ("Manajemen Data" → `data_management_screen`) *and* via System Settings → Manajemen Data (same screen). System Settings hub resolves half of the overlap but the top-level menu tile still points past it, so the two paths compete.

### Theme 5 — Grade feature fragmented across 5 screens

`teacher_grade_input_screen`, `teacher_grade_recap_screen`, `admin_grade_overview_screen`, `grade_book_screen`, `parent_grade_screen`. Each is defensible in isolation, but together they form a 5-screen feature with no shared "Grade Center" entry point. Users (especially wali-kelas teachers) end up bouncing between recap ↔ input ↔ report card to complete a single grading task.

### Theme 6 — Wali-kelas bolted on, not designed in

Teachers with a homeroom class get a `RoleToggle` on Grade Recap and Attendance to flip between *guru* and *wali-kelas* context. The toggle is in-screen, per-screen, and re-implemented each time. It works, but it's signposting that the IA doesn't really accommodate the wali-kelas workflow — it assumes "teacher" is one role, then papers over the fact that it isn't.

---

## Information Architecture reflow (proposal)

### Proposal 1 — Persistent bottom navigation per role

Give every role a 4–5 tab bottom navigation so the *current task* always has a persistent home. The dashboard stops being the router.

**Admin (5 tabs):**
1. **Beranda** — dashboard (stats + inbox only, no overflow menu)
2. **Orang** — Siswa, Guru, Kelas (merged Manajemen Data entry)
3. **Akademik** — Mapel, Jadwal, RPP, Raport, Rekap Nilai, Absensi Report, Kegiatan Kelas
4. **Keuangan** — Finance hub (includes verification, billing, reports, payment types)
5. **Sistem** — System Settings hub (pengumuman, pengaturan sekolah, pengguna, data master)

**Teacher (4 tabs):**
1. **Beranda** — dashboard (today's schedule + inbox)
2. **Mengajar** — Jadwal, RPP, Materi, Kegiatan Kelas (all planning/teaching)
3. **Nilai & Absensi** — Input Nilai, Rekap Nilai, Absensi, Raport (all assessment/monitoring)
4. **Lainnya** — Pengumuman, Rekomendasi Belajar (wali-kelas only), Profil akun

**Parent (4 tabs):**
1. **Beranda** — child snapshot (today's attendance, new grades, unread announcements)
2. **Akademik** — Nilai, Kegiatan Kelas, Raport
3. **Kehadiran** — Absensi (with child selector if multi-anak)
4. **Keuangan** — Tagihan + riwayat pembayaran

**Why this works:**
- Category names describe *intent*, not *implementation*.
- Inbox badges (pending verifikasi, unread RPP review) appear on tab icons → discoverable without opening the dashboard.
- Deep flows stay within one tab — a parent checking grades never gets lost.
- Dashboard can shrink to just "Beranda" content (status + inbox) because the rest of navigation is in the tab bar.

### Proposal 2 — Dashboard becomes a real "today" page

After the tab bar lands, strip the dashboard to:

1. **Greeting + school pill** (header stays)
2. **Today's surface** (role-dependent):
   - Admin: "3 pembayaran menunggu verifikasi · 2 RPP siap review · Rp 4.2jt tagihan jatuh tempo hari ini"
   - Teacher: today's schedule slider + "Anda mengajar 4 kelas hari ini"
   - Parent: "Lia tadi pagi hadir · Nilai baru Matematika · 1 pengumuman belum dibaca"
3. **Pending inbox** (exactly one prominent card, tappable to the backing tab)
4. Nothing else. Quick actions and categorized menu move into the tabs.

This is a focused "what matters today" surface instead of an everything page.

### Proposal 3 — Fold wali-kelas into an actual role

Wali-kelas is a *role* (assigned at class-assignment time) not a *mode toggle*. The reflow:

- Teacher bottom nav stays 4 tabs for everyone.
- If the signed-in teacher has a homeroom class, the **Beranda** tab shows a "Kelas Wali: VII A" section with per-class KPIs (absensi today, nilai outstanding, pengumuman draft).
- Wali-kelas-only surfaces (Rekomendasi Belajar, full-class Absensi view) appear under **Lainnya**, not as toggles on existing screens.
- The `RoleToggle` widget comes out of the per-screen headers entirely. Grade Recap and Attendance default to "subjects I teach" for everyone — for wali-kelas, the Beranda card links to the whole-class view directly.

---

## Per-screen layout audit (skeleton — fill when screenshots land)

Each entry uses the design-critique framework (first impression, usability, visual hierarchy, consistency, accessibility, what works, priority recommendations). Code-readable info is filled in now; the screenshot-dependent judgments are marked `[awaiting screenshot]`.

> When you drop screenshots into `_baseline/`, I'll annotate every `[awaiting screenshot]` marker with real feedback and produce a reflow sketch (ASCII wireframe) per screen that warrants one.

### Shared / Entry

#### S1 — Login (`login_screen.dart`)
- **Current composition:** single navy-gradient screen, white card with rounded corners holds the logo (graduation-cap), brand "Kamil Edu", email field with envelope-prefix icon, password field with lock-prefix and eye-suffix, full-width "MASUK" button (filled blue), and a secondary "Masuk dengan Google" outlined button below.
- **First impression:** clean, well-balanced, professionally styled. The card-on-gradient pattern reads as "premium SaaS" and matches the role-color contract (admin navy is the right hero color here since admin is the most-frequent first sign-in).
- **What works:** card elevation feels just right (not too heavy); icon prefixes telegraph field intent; password eye toggle is present; Google sign-in offered as a real second option, not a tiny link.
- **Issues:**
  - **No "Lupa Password" link** anywhere on the form. The recovery path requires the user to leave the app or contact admin. For a school product where parents may forget passwords mid-semester, this is a real friction point.
  - **No "Ingat Saya" / Remember-me toggle.** Mobile-first apps that hold tokens for weeks usually still surface a remember-me preference for shared-device cases.
  - **Branding label uses "Kamil Edu" (with space)** while the AppBar elsewhere says "Manajemen Sekolah". Brand name doesn't match the in-app product label — pick one (recommend "KamilEdu" everywhere or split: "KamilEdu" as brand + "Manajemen Sekolah" as feature label).
- **Priority recommendations:**
  1. Add "Lupa Password?" text link below the password field, right-aligned, before the MASUK button.
  2. Pick a single brand string and use it consistently across login + dashboards.
  3. Optional: surface "Ingat saya selama 30 hari" checkbox above MASUK (low priority, nice-to-have).

#### S2 — Pilih Sekolah (school picker, post-login if multi-school)
- **Current composition:** same navy-gradient bg + white card; title "Pilih Sekolah", greeting "Halo Mas Yahya", subtitle "Silakan pilih sekolah untuk melanjutkan", then a stack of school cards (school icon + name + address + chevron), and a green "Kembali ke Login" link.
- **First impression:** dedicated screen for school selection (good — handles the multi-school admin case explicitly rather than burying it in a popup). Card pattern matches the login screen, which gives flow continuity.
- **What works:** address shown under each school name disambiguates same-name branches; chevron telegraphs "tap to enter"; "Kembali ke Login" provides an out.
- **Issues:**
  - **Two-card list with no filter/search** is fine for 2-3 schools, but admins with 5+ school access (district admins) will struggle without a search bar. Code path supports many schools, UI doesn't.
  - **"Kembali ke Login"** is *green* while every other affordance on the screen is navy/blue. Inconsistent — should be navy for stay-on-brand, or a small text link not styled as a CTA.
- **Priority recommendations:**
  1. Add a search field above the list when school count exceeds 4.
  2. Standardize "Kembali ke Login" to a small navy text link (not green button-like).

#### S3 — Pilih Peran (role picker, post-school)
- **Current composition:** same card pattern; title "Pilih Peran", greeting + "Sekolah: SMP Kamil Edu A", then role cards (Administrator with shield icon, Teacher with person icon), each with description and chevron. "Kembali ke Login" green link below.
- **What works:** explicit role selection prevents accidentally landing in the wrong role for users who legitimately have multiple (rare but real — a homeroom teacher who's also acting principal).
- **Issues:**
  - **A red error toast "Email atau password salah" is showing on this screen** even though the user is past login. Either the toast is stale from a prior login attempt and isn't getting dismissed on flow advance, or it leaked from a different state. This is a bug, flag it for fix.
  - **Login → School → Role** is a 3-step gate before the dashboard. For users with one school + one role (the common case), is this skipped? If yes, fine. If no, that's a 2-step delay every cold start. *Open question for engineering: does the picker skip when n=1?*
  - **Role card descriptions** ("Akses sebagai Administrator", "Akses sebagai Pengguna") are filler. "Pengguna" is generic — should match the role name ("Akses sebagai Guru" if they're a teacher).
- **Priority recommendations:**
  1. Fix the stale "Email atau password salah" toast leaking into role-picker (P0 bug).
  2. Confirm and document: role picker skips when user has a single role. If not, add the skip.
  3. Replace generic "Akses sebagai Pengguna" with role-specific copy.

#### S4 — Notifications (`notification_list_screen.dart`)
- **Current composition:** **green** AppBar (different color from the role-color contract — admin uses navy, teacher teal, parent violet — green is the parent role color, but this screen serves all roles), title "Notifikasi" with "1 belum dibaca" subtitle, "mark all read" double-checkmark icon at top-right. Body: single notification card with rounded blue megaphone-icon badge + "Pengumuman Sekolah" title + body preview + clock-icon + "7 jam yang lalu" + small blue dot for unread state.
- **What works:** card composition is clean (icon + title + body + meta-row); unread blue dot is subtle but visible; mark-all-read is one tap.
- **Issues:**
  - **AppBar color is green (parent role)** while the admin role this user is signed in as uses navy throughout. This screen looks like it was lifted from the parent flow without applying the active role color. Colors-as-metadata principle from CLAUDE.md violated.
  - **No grouping** by day ("Hari ini", "Kemarin", "Minggu lalu"). With 1 notification it's fine; at 30 it'll be a flat scroll.
  - **No swipe-to-archive / swipe-to-delete** affordances visible. Code path uses DELETE on tap-mark-read — there's no "soft archive" middle state.
  - **No row CTA / chevron** indicating that tapping the notification opens the related screen. Users have to learn that "tap takes me to the announcement" by trial.
  - **Vast empty space** below the single card. Empty-state messaging could fill the lower half: "Anda akan dihubungi di sini ketika ada pengumuman, perubahan jadwal, atau hal mendesak."
- **Priority recommendations:**
  1. **P0**: AppBar color should match the active role (use `ColorUtils.getRoleColor(role)`).
  2. Group notifications by day section (Hari ini / Kemarin / dst.).
  3. Add explicit chevron (or remove and rely on whole-row tap with subtle hover state).
  4. Consider swipe-actions: swipe-right to mark read, swipe-left to dismiss.
  5. Empty / sparse-state messaging fills below the list.

### Admin

#### A1 — Admin Dashboard (`admin_dashboard_body.dart`)
- **Current composition (verified from screenshots):** white AppBar with logo + "Manajemen Sekolah" title + globe (lang) + bell (badge: 1) + person avatar → **dark-navy hero card** "Halo, Mas · Admin sekolah" with a pill "Terhubung realtime · 16:27" → HeroStats row (3 cards: 57 Siswa Aktif / 7 Guru / 0 Verifikasi menunggu) → PendingInboxCard ("Perlu tindakan" header + "Lihat semua" link + green-checkmark "Semua beres" empty state) → QuickActionGrid (4 tiles: Siswa / Keuangan / Laporan / **Pengatura\nn**) → "Modul lain" section header with right-side "Input nilai" pen-icon action → categorized menu in 3 sections: MANAJEMEN DATA (Kelola Data, Kelola Jadwal, Nilai), AKADEMIK & KOMUNIKASI (Pengumuman badge:1, Kegiatan Kelas, Laporan Presensi, Kelola RPP, Raport Siswa), KEUANGAN & PENGATURAN (Keuangan, …).
- **First impression:** dense, but visually clean. The dark hero band gives a strong "header" anchor; HeroStats cards are well-color-coded (blue/green/orange numerals); pending-inbox empty state is friendly. Then it gets noisy: QuickActions and Categorized menu both feel "primary" and the user has to pick one.
- **Issues (verified visually):**
  - **🔴 Critical: Hero card text contrast.** "Halo, Mas · Admin sekolah" is dark-grey text on a near-black gradient — barely readable. WCAG AA fails this on most devices. Either lighten the text to white/off-white or lighten the gradient bg.
  - **🔴 Critical: "Pengatura\nn" text wraps** in the QuickActionGrid because the label is too long for the tile width. Either truncate with ellipsis ("Pengatur…"), drop to "Setelan" / "Settings", or shorten to 8 chars max.
  - **🟡 Moderate: Two semantic duplications.** "Siswa" in QuickActionGrid (top) → "Kelola Data" in Manajemen Data section (below) likely route to the same destination. "Keuangan" in QuickActions (top) → "Keuangan" in Keuangan & Pengaturan (bottom) is *literally* the same destination and label. The QuickActionGrid is redundant with the categorized menu beneath it.
  - **🟡 Moderate: "Modul lain" header is the wrong label.** These aren't "other modules" — they're the *primary* navigation modules. The label reads as if everything below is secondary.
  - **🟡 Moderate: "Input nilai" floating header-action** with a pen icon next to "Modul lain" is disorienting. It looks like a section action ("edit modules") but is actually a deep-link to the grading screen. Move it into the menu or remove.
  - **🟡 Moderate: Empty pending-inbox card** takes ~80px of vertical space to say "nothing to do." Either hide when empty or compress to a one-line caption.
  - **🟢 Minor: Three-section categorized menu** with ALL-CAPS section labels is genuinely good organization — the sections (Manajemen Data / Akademik & Komunikasi / Keuangan & Pengaturan) are reasonable. The problem isn't the categories themselves, it's that they're competing with a 4-tile shortcut grid above them.
- **What works well:**
  - HeroStats numbers are large and color-coded (blue for siswa, green for guru, orange for verifikasi) — instantly scannable.
  - Pending-inbox card with empty-state green check + "Semua beres" is a delightful detail.
  - Categorized menu uses pastel-blue icon squares with consistent treatment — visually unified.
  - Status bar shows real connection indicator ("Terhubung realtime · 16:27") which is a nice trust signal.
- **Reflow sketch (post-P1+P2 — what Beranda becomes):**
  ```
  ┌──────────────────────────────────────┐
  │ [logo] Manajemen Sekolah  🌐 🔔 👤   │  ← AppBar (existing)
  ├──────────────────────────────────────┤
  │ ┌──── Halo, Pak Yahya ────────────┐  │  ← Lightened hero
  │ │ Admin · SMP Kamil Edu A         │  │     (text WCAG AA)
  │ │ ● Realtime · 16:27              │  │
  │ └─────────────────────────────────┘  │
  │                                      │
  │  57         7         0              │  ← HeroStats unchanged
  │  Siswa      Guru      Verifikasi    │
  │                                      │
  │ ┌─────── Hari ini ──────────────┐    │  ← NEW "today" card
  │ │ • 2 RPP siap review  [→]      │    │     replaces both
  │ │ • 3 pembayaran menunggu  [→]  │    │     QuickActions and
  │ │ • Rp 4.2jt tagihan jatuh tempo│    │     "Modul lain" header
  │ └───────────────────────────────┘    │
  └──────────────────────────────────────┘
  [bottomnav] Beranda · Orang · Akademik · Keuangan · Sistem
  ```
  Categorized menu items move into their owning bottom-nav tabs (Orang / Akademik / Keuangan / Sistem). Beranda holds *only* greeting + KPIs + "what needs attention today."
- **Priority recommendations:**
  1. **P0**: Fix hero card text contrast (text → white). Fix "Pengatura\nn" wrap.
  2. **P0**: After P1 (bottom nav) lands, delete QuickActionGrid + categorized menu. Replace with the "Hari ini" card sketched above.
  3. **P1**: Compress empty pending-inbox card to a one-line caption.
  4. **P1**: Move "Input nilai" header-action into Akademik tab as a primary tile (it's a real screen, not a dashboard action).
  5. **P2**: Decide consistent brand label ("KamilEdu" vs "Manajemen Sekolah"); apply across login + AppBar.

#### A2 — Students (`admin_student_management_screen.dart`)
- **Current composition (verified):** navy-gradient AppBar with back arrow + "Manajemen Siswa" + "Kelola dan pantau siswa" subtitle + 3-dot overflow → search bar full-width with filter-icon button on the right → list of student rows → blue + FAB at bottom-right.
- **Row anatomy:** pastel circular avatar with letter initial → name (bold) → eye-icon + "-" placeholder + gender pill ("Laki-laki" / "Perempuan") on second line → green-bordered "Active" pill + blue pen-icon (edit) + red trash-icon (delete) on the right.
- **What works:**
  - Avatar pastel palette (lavender, mint, peach, pink, cream, lilac) is readable and varied — landed nicely after #112.
  - 7 rows fit before FAB occludes the last — reasonable density.
  - "Active" pill is consistent with the row-level status pattern across screens.
- **Issues:**
  - **🟡 Moderate: 5 actions per row.** Avatar (visual only), name+meta (tap target?), Active pill (status), edit pen, delete trash. The pen and trash on every row are *redundant* with the FAB and (presumably) bulk-mode. They add visual noise and tempt accidental deletes.
  - **🟡 Moderate: Eye-icon + "-"** on each row is unclear. If it's a "view profile" affordance, what is it gated on? If it's truncation of a hidden field, why show the icon?
  - **🟡 Moderate: Filter sheet is dense** — Nama Wali Murid (text input), Status (3 chips), Kelas (8+ chips with year suffixes), Jenis Kelamin (more chips below cut-off). Wraps to 3 chip-rows just for Kelas. Useful but heavy.
  - **🟢 Minor: Overflow menu** (Perbarui Data / Export ke Excel / Import dari Excel / Download Template) is well-organized but **buried** behind a 3-dot. Import/Export is a high-value action for school onboarding — surface as a secondary header button or a "Data" submenu.
- **Edit sheet (variant):**
  - Fields: Nama / NIS / Kelas (dropdown) / Alamat / Tanggal Lahir / Jenis Kelamin (dropdown), each with a leading icon and floating label.
  - Yellow "Ganti Akun Wali / Gunakan User Wali Lain" card with a toggle — a useful but visually disconnected affordance. Looks like an alert; probably should be a regular toggle row inside the form.
- **Priority recommendations:**
  1. **P1**: Drop per-row edit + delete icons. Tap-the-row → opens detail/edit sheet. Long-press → enters bulk-select mode. FAB stays for "+ Add". This single change reclaims ~20% of row width and removes accidental-delete risk.
  2. **P1**: Clarify the eye-icon + "-" — either hook it up to a visible field (NIS? class?) or remove.
  3. **P2**: Promote import/export to a row-of-icons or "Data" submenu, not a 3-dot child.
  4. **P2**: Refactor the yellow "Ganti Akun Wali" card into a regular form row to match the rest of the sheet's visual system.

#### A3 — Teachers (`admin_teacher_management_screen.dart`)
- **Current composition (verified):** identical row pattern to A2. Each row: pastel-circle initial avatar → name (bold) → calendar-icon + class chip ("7A") + email (truncated with "…") on multi-line → blue "Wali Kelas" pill OR green "Aktif" pill + edit/delete icons.
- **What works:** the "Wali Kelas" badge surfaces homeroom-teacher status at a glance — important admin context.
- **Issues:**
  - **🟡 Moderate: "Wali Kelas" pill and "Aktif" pill conflict semantically.** Wali Kelas is a *role*, Aktif is a *status*. A teacher who is both wali-kelas AND active just shows "Wali Kelas" — Aktif disappears. So you can't tell from this list whether a wali-kelas teacher is active or inactive. The status pill should probably be its own field, with "Wali Kelas" as a separate inline tag.
  - **🟡 Moderate: Email truncation** ("a_prastyanto@student.uns.a…") is uninformative — better to truncate the *local part* (a_prastyanto@uns.a…) or hide email behind tap-detail.
  - **Same per-row edit/delete issues as A2.**
- **Priority recommendations:**
  1. **P1**: Separate role tag (Wali Kelas) from status tag (Aktif/Tidak Aktif) — render side-by-side or stack. Don't conflate.
  2. **P1**: Email truncation strategy — either show domain ("@uns.ac.id") or hide email from the row, surface only on detail.
  3. Same row-action cleanup as A2.

#### A4 — Classrooms (`admin_classroom_management_screen.dart`)
- **Current composition (verified):** big colored circle with class number ("7", "7", "8", "8", "9") as the avatar → name (7A / 7B / 8A) bold → building-icon + "Kelas 7 SMP" tingkat → person-icon + wali-kelas name (Agil, Aldi, Ari, Mas Yahya, Andro) → right side: blue dot + "16 siswa" pill + edit/delete icons.
- **What works:** number-as-avatar is distinct from student/teacher rows — good visual differentiation by entity type. Multi-line composition (name on top, tingkat + wali below) reads well. "16 siswa" pill is the right level of summary.
- **Issues:**
  - **🟢 Minor: Rendering wali-kelas as just first name** ("Agil", "Aldi") — fine for the seed data but breaks down with same-firstname collisions in larger schools. Consider full name or "Agil S." with last-name initial.
  - **Same per-row edit/delete pattern issue.**
- **Priority recommendations:**
  1. **P1**: As A2/A3 — drop edit/delete icons, use tap+long-press.
  2. **P2**: Wali-kelas name format — full name with sensible truncation.

#### A5 — Subjects (`admin_subject_management_screen.dart`)
- **Current composition (verified):** colored letter avatar (B, B, B, I, I — using mapel initial which collides for B.Arab/B.Inggris/Bahasa Indonesia and IPA/IPS) → name + small code chip (BAR, BIN, BHI, IPA, IPS) + green-dot "Aktif" status inline → secondary line: book-icon "5 Kelas" + classroom-icon "7A, 7B, 8A, 8B, 9A" → edit/delete on right.
- **What works:** code chip + status dot inline keeps the row tight. Class list "7A, 7B, 8A, 8B, 9A" gives at-a-glance scope.
- **Issues:**
  - **🟡 Moderate: Avatar initial collisions.** "B" appears 3x for B.Arab/B.Inggris/Bahasa Indonesia in different colors. The color helps disambiguate but the letter is redundant. Use the *kode* ("BAR", "BIN", "BHI") as the avatar text to make it unique.
  - **🟡 Moderate: AppBar title "Manajemen Mata Pelajaran" wraps onto two lines** because it's the longest entity title. Either shorten ("Mata Pelajaran" alone is fine — the "Manajemen" prefix adds nothing in context) or use a smaller AppBar text size for this screen only.
  - **🟢 Minor: No KKM / bobot visible.** Either intentional (those are class-level config) or the row is showing only metadata. If KKM/bobot are subject-level, expose on tap-detail.
- **Priority recommendations:**
  1. **P1**: Use 3-letter kode as avatar text (BAR/BIN/BHI/IPA/IPS) — eliminates B/I collisions.
  2. **P1**: Shorten AppBar title to "Mata Pelajaran" everywhere (not just when it wraps).
  3. **P2**: Confirm whether KKM/bobot are surfaced anywhere; if subject-level, show on detail.

#### A6 — Schedule (`admin_schedule_management_screen.dart`)
- **Current composition (verified):**
  - **List view:** colored calendar icon avatar → subject (B.Arab / Matematika) + teacher name on multi-line → class chip (8B, 7B) + day chip (Rabu/Senin/Selasa) + time pill (07:00 - 11:45 etc) → edit/delete on right. View-toggle button next to 3-dot in AppBar flips to matrix.
  - **Matrix view:** frozen left column "Jam 1 / 07:00 / 07:45" → day columns (Senin, Selasa, …) horizontally scrolling. Each cell shows stacked entries when multiple subjects share a slot ("B. Arab 8B" + "Bahasa Indonesia 7B").
- **What works:** dual-view toggle (T4.1) is a real win — list for editing, matrix for visual scanning. Frozen left column on matrix preserves time-of-day context while scrolling days. Subject + teacher + class + day + time on a list row is dense but legible.
- **Issues:**
  - **🔴 Critical: Matrix view rendering bug or test-data issue.** Every "Jam 1" row in the screenshot shows the *same two entries* ("B. Arab 8B" + "Bahasa Indonesia 7B"). Either the test data has duplicates across rows (unlikely; should be different time slots) or the row data is being repeated incorrectly. Investigate before redesigning.
  - **🟡 Moderate: Matrix horizontal scroll past Selasa.** On Samsung portrait (~411dp), only Senin + half of Selasa visible. With 5-6 day columns, user has to scroll a lot to see Friday. Could compress day columns (shorter labels: "Sen / Sel / Rab" instead of "Senin / Selasa / Rabu") to fit more days at once.
  - **🟡 Moderate: List view rows have 3 chips below the title** (class, day, time). These could combine: "8B · Rabu · 07:00–11:45" as a single meta-row, saving vertical space.
- **Priority recommendations:**
  1. **P0**: Investigate matrix view duplicate-row bug.
  2. **P1**: Shorter day-column labels (3-char) to fit all 5-6 days on Samsung portrait without scroll.
  3. **P1**: Collapse list-row chip stack into a single inline meta-line.
  4. **P2**: Same row-action cleanup as A2/A3.

#### A7 — Finance Hub (`admin_finance_screen.dart`)
- **Current composition (verified):** the screen is built as a 4-tab hub (Phase 2 refactor) with internal tabs:
  - **Dasbor** (active by default): KPI row (3 cards: Belum Dibayar / Terverifikasi / Menunggu) → conditional alert card "Pembayaran Menunggu Verifikasi" with badge + orange CTA → "Tagihan Berjalan" section (list of active billings: Uang Pangkal Rp 5.000.000 · 3 Tagihan, SPP March Rp 500.000 · 10 Tagihan, …) with red trash on each.
  - **Jenis Pembayaran**: search + filter + "3 jenis pembayaran ditemukan" + list of payment types (SPP / Uang Pangkal / Kegiatan Tahunan) with colored card icon, amount, period chip ("Bulanan" / "sekali bayar"), "Aktif" pill, and 3 inline action icons (regen / edit / delete). FAB to add.
  - **Verifikasi**: list of pending verification rows. Each row: avatar + "Siswa Lama 6B #3" + class chip + "Menunggu" pill + meta-row (SPP / Rp 500.000 / 2026-04-15 timestamp) + a full-width blue "Verifikasi" button.
  - **Laporan Kelas**: simple drill-down list of classes (7A/7B/8A/8B/9A) with class-icon + name + student count + chevron.
- **What works:**
  - 4-tab hub structure is a real improvement over the pre-T2.1 multi-screen sprawl. One "Keuangan" → 4 sub-domains is a clean mental model.
  - The "Pembayaran Menunggu Verifikasi" alert card on Dasbor uses orange bg + badge + prominent CTA — a good escalation pattern that earns its visual weight.
  - Generate Tagihan modal (12 month chips with green-check selection state, year dropdown) is intuitive and AI-themed (sparkle icon).
  - Empty state on Dasbor ("Belum ada tagihan yang digenerate") + clean KPI 0/0/0 states is graceful.
- **Issues:**
  - **🟡 Moderate: Tab label "Jenis Pembayaran" truncates to "Jenis Pemba…"** in the tab bar — fits 4 tabs in the header strip but loses readability. Either shorten to "Jenis" + tooltip, or use 2-line tab labels.
  - **🟡 Moderate: KPI card color semantics are off.** Belum Dibayar = orange, Terverifikasi = green, Menunggu = *blue*. "Menunggu" is the most actionable state (admin needs to do something), so it should be the *most attention-grabbing* color (orange / yellow / red). Currently it reads as least urgent because blue is the "neutral info" color in the rest of the app. Suggested mapping: Belum Dibayar = red/danger, Menunggu = orange/warning, Terverifikasi = green/success.
  - **🔴 Critical: Verifikasi tab layout doesn't scale.** Each pending row is a card with its own full-width "Verifikasi" CTA button. With 5 pending payments, that's 5 giant buttons stacked — the tab becomes mostly buttons. Pattern should be: a list of pending rows (compact), each tap-to-open a verify sheet. Or a row of action icons inline (verify-check, reject-x) instead of a full-width button per row.
  - **🟡 Moderate: Jenis Pembayaran rows have 3 inline action icons** (refresh-regen-circle / pen-edit / trash-delete) again — same per-row-action anti-pattern as A2/A3/A4/A5. Drop them; rely on tap-to-edit + long-press-to-bulk.
  - **🟡 Moderate: Tagihan Berjalan rows on Dasbor have a red trash icon as the only inline action** — surprising single-action UX. Tap-to-detail or long-press-to-archive would be more conventional.
  - **🟢 Minor: Tab order** — currently Dasbor / Jenis Pembayaran / Verifikasi / Laporan Kelas. The most actionable tab (Verifikasi) is third. Suggested order: Dasbor / Verifikasi / Jenis Pembayaran / Laporan Kelas (or move Verifikasi to second).
- **Reflow sketch (Verifikasi tab):**
  ```
  Before:                       After:
  ┌──────────────────────┐      ┌──────────────────────────┐
  │ S  Siswa Lama 6B #3  │      │ S Siswa Lama 6B #3       │
  │    Kelas 6B          │      │   SPP · Rp 500k · 4/15   │
  │ [SPP][500k][2026..]  │      │   ────────── [✓][✗]     │
  │                      │      └──────────────────────────┘
  │ [───── Verifikasi ──]│      ┌──────────────────────────┐
  └──────────────────────┘      │ A Ahmad H. 7A            │
  (one mega-button/row)         │   SPP · Rp 500k · 4/16   │
                                │   ────────── [✓][✗]     │
                                └──────────────────────────┘
                                (tight rows, inline approve/reject)
  ```
- **Priority recommendations:**
  1. **P0**: Verifikasi tab — replace mega-button-per-row with inline check/x action icons. Tap row opens detail sheet.
  2. **P0**: Re-color KPI cards by semantic urgency (Menunggu = orange, Belum Dibayar = red, Terverifikasi = green).
  3. **P1**: Shorten "Jenis Pembayaran" tab label to "Jenis" or use 2-line label.
  4. **P1**: Reorder tabs so the highest-action one (Verifikasi) is second.
  5. **P2**: Same row-action cleanup as A2-A6 across Jenis Pembayaran and Tagihan Berjalan rows.

#### A8 — Finance Report (handled inside the A7 hub via the "Jenis Pembayaran" + "Laporan Kelas" tabs)
- The pre-T2.1 standalone "Finance Report" screen folded into A7 hub. No separate audit needed.
- **Priority recommendations:** captured under A7.

#### A9 — Class Finance Report (drill-down from Laporan Kelas tab)
- **Current composition (verified):** Laporan Kelas tab shows a simple list of classes. Tapping a class drills into a per-class report (which uses the `ClassFinanceTable` shared widget — not separately captured but the entry surface is clean).
- **What works:** simple class picker, no over-engineering. Class avatar + student count gives enough scope at a glance.
- **Priority recommendations:** none specific — clean as-is. Once P1 lands, this stays inside the Keuangan tab as the existing drill-down.

#### A10 — Announcements (`admin_announcement_screen.dart`)
- **Current composition (verified):** AdminCrudScaffold pattern. Each row: blue megaphone-icon avatar (orange variant for important) + title (Test 31 / Test 2 / Test) + body preview + meta-row (date "31/03/2026 12:44" + audience pill "Semua Pengguna") + edit-pen + delete-trash on right. Last row has additional orange "⚠ Penting" priority pill. FAB to add.
- **What works:** priority shown only when set (no "Biasa" pill cluttering normal rows). Audience pill ("Semua Pengguna") gives clear targeting context. Megaphone-icon color (blue/orange) doubles as a priority signal.
- **Issues:**
  - **🟡 Same per-row edit/delete anti-pattern as A2-A6.**
  - **🟢 Minor: Date format mixes DD/MM/YYYY HH:MM** in a single field — readable but heavy. Could split into "31 Mar · 12:44" with date + time separated.
  - **🟢 Minor: No "scheduled" / "draft" / "published" status visible.** All rows look published. If draft state exists in the model, should be reflected as a third pill.
- **Compose sheet (A10b):** Title bar + form: Judul / Konten / Prioritas (dropdown, default Biasa) / Role Target (dropdown, default Semua Pengguna) / Tanggal Mulai + Tanggal Berakhir (side-by-side cards) / Lampiran upload zone with cloud-icon + "Ketuk untuk unggah file" + format hint "PDF, DOC, DOCX, JPG, PNG (Max 5MB)". Bottom: Batal / Simpan.
- **What works:** clear field layout, side-by-side date pair is space-efficient, attachment upload is well-affordanced (cloud icon + dashed border).
- **Issues:**
  - **🟡 Konten field is a small text input** (2 lines visible) with no rich-text affordance. For announcements, support for bold/links/lists is genuinely useful — `AppQuillEditor` from the shared catalog should fit here.
  - **🟢 Minor: No "Schedule for later"** option — only Tanggal Mulai/Berakhir visible-from window. If draft → schedule → publish is the intended flow, surface it explicitly.
- **Priority recommendations:**
  1. **P1**: Swap Konten input for `AppQuillEditor` (rich text for announcements).
  2. **P1**: Same row-action cleanup pattern as A2-A6.
  3. **P2**: Surface draft / scheduled / published status as an explicit pill on each row.

#### A11 — Attendance Report (`admin_attendance_report_screen.dart`)
- **Current composition (verified):** AppBar with view-toggle button + 3-dot. Search "Cari absensi…" + filter button. Each row is a *session* card: blue book-icon avatar + subject name (B. Arab) + class chip ("7A · Jam ke-1") + day/date ("Senin, 13 April 2026") + stats row (green "16 Hadir" / red "0 Absen" / blue "16 Siswa" / "Detail" link) + full-width green progress bar + "100% Kehadiran" caption + red trash icon on the top-right.
- **What works:** progress bar with percentage caption is genuinely useful at a glance. Hadir/Absen/Total stats inline give density.
- **Issues:**
  - **🔴 Critical: Red trash icon on a *report* row** — admins should not be able to delete attendance records (audit trail / compliance). Either this deletes only the local cache (still confusing) or it's a destructive bug. Investigate.
  - **🟡 Moderate: "Detail" rendered as a chip** in the stats row alongside "16 Hadir / 0 Absen" — looks like a stat, behaves like a CTA. Confusing affordance.
  - **🟡 Moderate: Vertical density is low** — each session takes ~140px (multi-line title + chip-row + progress bar + caption), so only 3 fit per scroll. For a 30-class school over a week, that's a lot of scrolling.
  - **🟢 Minor: View-toggle in AppBar** (next to 3-dot) suggests a matrix/calendar view exists — verify and capture if so.
- **Reflow sketch (compressed row):**
  ```
  Before (~140px):                    After (~80px):
  ┌─────────────────────┐             ┌──────────────────────────┐
  │ B. Arab             │ [trash]     │ B. Arab · 7A · Jam 1     │
  │ 7A · Jam ke-1       │             │ Senin, 13 Apr · 16/16 ✓  │
  │ Senin, 13 April 2026│             │ ████████████████ 100%    │
  │ [16 Hadir][0 Absen]…│             └──────────────────────────┘
  │ ███████████████ 100%│             (5-6 fit per scroll)
  └─────────────────────┘
  ```
- **Priority recommendations:**
  1. **P0**: Audit the trash icon — confirm scope of deletion or remove entirely.
  2. **P1**: Compress row layout per sketch (saves ~40% vertical space).
  3. **P1**: Move "Detail" off the stats row into a dedicated tap-row affordance.

#### A12 — Lesson Plans (`admin_lesson_plan_screen.dart`)
- **Current composition (verified):** AppBar title is "RPP - Agil" — *teacher-scoped*, suggesting this screen is reached after picking a teacher. Search + filter. Single visible RPP card: blue document-icon avatar + title ("bilangan bulat") + subject ("Matematika") + status pill ("Draft", teal-bordered) + class chip ("8A") + author chip ("Agil") + eye-icon (view) + pen-icon (edit). Lots of empty space below.
- **What works:** status pill ("Draft" in teal) is well-styled, color-coded. Class + author chips give scope at a glance.
- **Issues:**
  - **🔴 Critical: Title is "RPP - Agil"** — this means the screen is teacher-scoped, but admin reaches it from the dashboard menu directly (label was "Kelola RPP"). Either:
    (a) admin first picks a teacher (then this title makes sense, but where's that picker?), or
    (b) this is a per-teacher view but is mislabeled when reached from admin (should be "Semua RPP" with teacher chip on each row).
    Investigate and clarify.
  - **🟡 Moderate: Eye + pen on the right** — view-and-edit are conceptually duplicate (tap row could open detail, which has its own edit). Drop one.
  - **🟢 Minor: Empty-space below single row** — sparse. If list pagination is in play, fine; if it's the full set, an empty-state callout would help.
- **A12b Regen sheet:** not separately captured, but T4.7 confirms it's on `AppBottomSheet` + `BottomSheetFooter`. Skipping per-screen audit.
- **Priority recommendations:**
  1. **P0**: Resolve the "RPP - Agil" scoping bug — either show all admin-visible RPPs with teacher chip, or expose the teacher-picker step explicitly.
  2. **P1**: Drop the duplicate eye-icon (tap row → detail).

#### A13 — Report Cards (`admin_report_card_screen.dart`)
- **Current composition (verified):** AppBar "Manajemen Raport · Unduh dan publikasikan raport kelas". Class picker dropdown ("9A") at top. List of students: pastel-letter avatar + name + NIS ("SA0041…SA0045") + orange "Draft" status pill + red PDF icon + chevron. Bottom action bar: green "Export Excel" + blue "Kirim ke Wali" buttons (full-width pair, ~50% each).
- **What works:** class picker as the primary scope control is appropriate (raport is class-level work). Bottom action bar with two buttons is a clear bulk-action surface.
- **Issues:**
  - **🟡 Moderate: Red PDF icon next to status** — ambiguous. Is it download? View? Print? The chevron next to it implies "tap row to view" so the PDF icon is redundant. Drop it.
  - **🟡 Moderate: All students show "Draft" pill** — implies all are unpublished. The Kirim ke Wali button presumably bulk-publishes. But there's no per-row "publish" / "ready to publish" distinction visible. After publishing, what does the row look like? Capture the published variant.
  - **🟡 Moderate: Two-button bottom bar feels heavy.** Pattern more typical for sheets. For a list screen, a FAB with speed-dial (Export / Kirim ke Wali) would be more conventional.
- **Priority recommendations:**
  1. **P1**: Drop the red PDF icon; tap-row already opens detail.
  2. **P1**: Capture and clarify the published-row state and how publish flow works.
  3. **P2**: Consider FAB-with-speed-dial instead of bottom-button-bar.

#### A14 — Class Activity (`admin_class_activity_screen.dart`)
- **Current composition (verified):** AppBar "Kegiatan Kelas · Lihat semua kegiatan guru". Search guru bar. Then a *list of teachers* (Agil / Aldi / Andro / Ari / Laily / Mas Yahya, etc) — same row shape as A3 Manajemen Guru but read-only (chevron only, no edit/delete actions visible on right). Tap drills into per-teacher activities.
- **What works:** pattern is consistent with A3 (visual continuity for an admin who's just been browsing teachers). Read-only chevron correctly signals navigation, not modification.
- **Issues:**
  - **🔴 Critical: Title says "Kegiatan Kelas" but the screen content is a guru list.** This is a 3-tap drill (Admin Dashboard → Kegiatan Kelas → pick teacher → see their activities). For an admin who wants to see "what's happening in school today," 3 taps to see *one* teacher's activity is wrong. Need a "today's activity across all teachers" landing first, with the per-teacher drill as a secondary path.
  - **🟡 Moderate: No visible date/period filter** at the top — admin can't ask "what was scheduled this week?" without picking a teacher first.
  - **🟢 Minor: Search bar says "Cari guru..."** in a screen titled "Kegiatan Kelas" — the implementation leak (you're really searching teachers) confirms the IA mismatch.
- **Reflow sketch:**
  ```
  Current:                        Proposed:
  ┌─────────────────────┐         ┌─────────────────────┐
  │ Kegiatan Kelas      │         │ Kegiatan Kelas      │
  │ "Lihat kegiatan…"   │         │ Hari ini · 12 sesi  │
  │ [Cari guru…]        │         │ [Hari ini ▼]        │
  ├─────────────────────┤         │                     │
  │ A  Agil          ▶  │         │ ┌──────── 09:00 ──┐ │
  │ A  Aldi          ▶  │         │ │ B.Arab · 7A     │ │
  │ A  Andro         ▶  │         │ │ Agil · 16 hadir │ │
  │ A  Ari           ▶  │         │ └────────────────┘ │
  └─────────────────────┘         │ [...next session]   │
  (3-tap drill required)          └─────────────────────┘
                                  (1-tap to see today)
  ```
- **Priority recommendations:**
  1. **P1**: Make the top-level Kegiatan Kelas screen a *time-scoped activity feed* (today / week / month). Move the per-teacher drill to a tab or filter.
  2. **P2**: After P1 lands, the per-teacher drill becomes a long-press action on a teacher chip, not a default navigation step.

#### A15 — Rekap Nilai / Grade Overview (`admin_grade_overview_screen.dart`)
- **Current composition (verified):** AppBar "Rekap Nilai · Rekap nilai seluruh sekolah". Search guru bar. **Big blue gradient hero card**: 73.1 Rata-rata · 51.8% Lulus · 535 Total Nilai → rainbow distribution bar (green ≥80: 212 / orange 60-79: 212 / red <60: 111) → meta "7 guru · 40 siswa". "Per Guru" section: each row has teacher name + meta ("1 mapel · 3 kelas · 134 nilai") + colored Avg pill (78.3 amber / 67.1 red / 72.3 amber) + thin progress bar + "% lulus" + per-subject score chips below ("Bahasa Indonesia 78", "Matematika 90", "B. Arab 67").
- **What works (this is the strongest admin surface in the app):**
  - Hero card with school-wide KPIs is genuinely informative and well-composed — Rata-rata, Lulus%, Total all visible at a glance.
  - Distribution bar with color-coded segments and explicit counts (≥80 / 60-79 / <60) doubles as legend + data viz.
  - Per-guru rows are dense but readable: avg pill is the right size (large enough to read, small enough to not dominate), progress bar at the right reinforces the avg, subject chips at the bottom add color.
  - Color semantics are *consistent*: green = pass, orange = caution, red = below KKM. Used in distribution bar, in avg pills, in subject chips.
- **Issues:**
  - **🟢 Minor: Density** — only 3 teachers visible per scroll because of the 4-line per-guru row. Compressing to 3 lines (drop the "x mapel · y kelas · z nilai" sub-meta into a tooltip) would surface more.
  - **🟢 Minor: Hero card width** vs the per-guru cards isn't perfectly aligned visually — hero card appears to extend slightly further.
- **Priority recommendations:** none P0/P1. This screen is a model for what the rest of the admin surface could look like. **Use this as the visual reference when redesigning A1 and A11.**

#### A16 — System Settings hub (`system_settings_screen.dart`)
- **Current composition (verified):** AppBar "Pengaturan Sistem · Kelola sekolah, pengguna, dan preferensi". Top tile: "Sekolah / Admin sekolah" school-context card. Section "Manajemen Sistem": Profil sekolah → Waktu pembelajaran → Manajemen data → Naik kelas & kelulusan (with teal "Segera" pill = coming soon). Section "Notifikasi & Akun": Pengaturan notifikasi (Segera) → Pengguna sistem (Segera) → Profil akun.
- **What works:** clean two-section grouping; "Segera" pills clearly mark unimplemented features (good honesty); each tile has icon + title + sub-label + chevron — consistent.
- **Issues:**
  - **🔴 Critical IA: Settings is reachable from two paths.** "Manajemen data" tile here goes to `data_management_screen` (A20), but the dashboard's MANAJEMEN DATA section *also* has "Kelola Data" which goes to the *same* `data_management_screen`. So admin can reach Kelola Siswa via:
    - Dashboard → Manajemen Data section → Kelola Data → 4 tiles → Kelola Siswa (4 taps)
    - Dashboard → Pengaturan tile → Pengaturan Sistem → Manajemen data → Kelola Data → 4 tiles → Kelola Siswa (5 taps)
    - Dashboard → Quick Action "Siswa" → Kelola Siswa (1 tap)
    Three paths, two of them through unnecessary intermediate hubs.
  - **🟡 Moderate: 3 of 7 tiles are "Segera"** — feels half-built. Either remove unimplemented tiles, or move them to a "Coming soon" footer.
- **Priority recommendations:** addressed by P4 (Settings consolidation).

#### A17 — School profile (`school_settings_screen.dart`)
- **Current composition (verified):** AppBar "Pengaturan Umum · Jenjang & informasi sekolah" + edit pen icon top-right. Section header "Informasi Sekolah · Kelola informasi dasar sekolah Anda". 3 read-only field cards: Nama Sekolah (SMP Kamil Edu A) / Alamat Sekolah / Jenjang Pendidikan (SMP). Each is its own card with leading icon + label + bold value.
- **What works:** read-only-with-edit-pen pattern (the same one used in account settings) is consistent. Field cards are clean.
- **Issues:**
  - **🟡 Moderate: 3 cards × 1 field each** = a lot of card chrome for very little data. Group into a single card with field rows.
  - **🟡 Moderate: Edit pen in AppBar** — clear affordance, but tapping it likely flips the read-only fields into editable inputs, which means re-rendering 3 cards as 3 input fields. A modal-edit sheet (using `AppEditBottomSheet`) would be more consistent with the rest of the app's edit pattern.
- **Priority recommendations:**
  1. **P1**: Consolidate 3 single-field cards into 1 multi-row card.
  2. **P2**: Edit flow → use `AppEditBottomSheet` for consistency.

#### A18 — School level settings (`school_level_settings_screen.dart`)
- *Not separately captured (file `18_school_level_settings.png` exists but content not read in this pass).* Per Theme 4 + P4 proposal: should fold into A17 as a tingkat sub-tab.

#### A19 — Time settings (`time_settings_screen.dart`)
- **Current composition (verified):** AppBar "Pengaturan Waktu · Jadwal & waktu pembelajaran". Section "Jam Aktif Harian · Pilih hari untuk mengatur jam pelajaran". 7 day cards in a vertical list: Senin / Selasa / Rabu / Kamis / Jumat (each "7 Jam Pelajaran") / Sabtu ("4 Jam Pelajaran") / Minggu ("Belum ada sesi") — each with a colored calendar avatar in 7 different colors and a chevron.
- **What works:** rainbow-of-7-colors keyed to days is delightful and informative. Each row's sub-label gives a useful summary.
- **Issues:**
  - **🟢 Minor: Minggu shows "Belum ada sesi"** as the sub-label, while the others show "X Jam Pelajaran". An explicit "0 Jam Pelajaran · Tidak aktif" or a dimmed state would be more consistent.
- **Priority recommendations:** none P0/P1. Clean as-is.

#### A20 — Data management (`data_management_screen.dart`)
- **Current composition (verified):** AppBar "Kelola Data · Kelola semua data master sistem". Just 4 tiles: Kelola Siswa / Kelola Guru / Kelola Kelas / Kelola Mata Pelajaran. Each tile: blue icon + label + chevron. Massive empty space below.
- **What works:** absolutely consistent (4 tiles match the 4 master entities) and visually clean.
- **Issues:**
  - **🔴 Critical IA: This screen exists to be a hub of 4 tiles, but those 4 destinations are *also* directly accessible from the dashboard's quick actions and categorized menu.** It's pure indirection that adds zero value. Each tile here is one-tap-one-tile, with a screen full of empty space below.
- **Priority recommendations:** addressed by P4. Once P1 (bottom nav) lands, the 4 master entities become tab-roots inside the "Orang" tab (Siswa/Guru/Kelas) + "Akademik" tab (Mapel) — this hub screen *deletes entirely*.

#### A21 — Account settings (`settings_screen.dart`)
- **Current composition (verified):** AppBar "Profil Pengguna" + edit pen + 3-dot. **Big navy hero band** with circular avatar (letter "M") + name "Mas Yahya" + email + "Admin" pill. Two grouped cards: "Informasi Pribadi" (Nama Lengkap / Email / No. Telepon: - / Alamat: -) and "Informasi Akun" (Peran: Admin / Sekolah: SMP Kamil Edu A). Bottom: full-width navy "Ubah Kata Sandi" button.
- **What works:** big avatar in hero is appropriate for profile screens. Two grouped sections (Pribadi vs Akun) are well-organized. Bottom CTA is a single clear action.
- **Issues:**
  - **🟡 Moderate: Empty fields show "-"** placeholder — could be "Belum diisi · Tambah" tap link to make completion discoverable.
  - **🟢 Minor: Single bottom CTA "Ubah Kata Sandi"** feels like only one option exists. Sign-out, change-language, delete-account, and similar account-level actions need a home — likely in the 3-dot, but unverified.
- **Priority recommendations:**
  1. **P2**: Empty-field tap → "Tambah" affordance.
  2. **P2**: Verify 3-dot menu contents and add Sign out / Language / Delete account if missing.

### Teacher

#### T1 — Teacher Dashboard (dashboard_screen.dart with role='guru')
- **Current composition (verified):** white AppBar with **green logo** + "Manajemen Sekolah" + globe + bell (badge:1) + person → **green gradient hero band** with "Selamat Malam · Mas Yahya 🌙" greeting + "2025/2026 Semester Genap - 2026" pill → 4 KPI tiles (47 Siswa / 4 Kelas / 0 Hari Ini / 18 RPP) → "Akses Cepat" 4-tile quick action grid (Jadwal / Absensi / Aktivitas / Nilai) → "Ringkasan Hari Ini" 2-card grid (No classes today / Absensi Hari Ini empty) → continued-material card ("B. Arab · 7A · 4/8 Bab · Selanjutnya: Lingkungan Se…" with progress dots) + RPP status card ("18 RPP · Lesson Plans" with 3-color dots: 2 Disetujui / 1 Ditolak / 15 Menunggu) → "MENGAJAR" section (Jadwal Mengajar / Kegiatan Kelas / Absensi Siswa / Materi Pembelajaran) → "PENILAIAN & PERENCANAAN" section (Nilai / Rekap Nilai / Raport / RPP Saya / Pengumuman badge:1 / Rekomendasi Belajar).
- **What works (this is significantly better than admin's dashboard):**
  - Time-aware greeting "Selamat Malam · Mas Yahya 🌙" is delightful and personable.
  - "Hari Ini" KPI tile (currently 0) is *role-relevant* — admins don't need this, teachers do.
  - "Ringkasan Hari Ini" 2-card grid for today's schedule + today's attendance is tightly scoped to the "what's happening *now*" mental model.
  - **Continued-material card** ("4/8 Bab · Selanjutnya: Lingkungan Se…") is a beautifully smart "where you left off" pattern — *reuse this elsewhere* (e.g. Materi list, Recommendation flow continuation).
  - **RPP status card** with 3-color dots (Disetujui/Ditolak/Menunggu) is the cleanest at-a-glance status surface in the app.
  - Section name "PENILAIAN & PERENCANAAN" in the screen is better than the code's "Penilaian" — the label evolved past the mixin.
- **Issues:**
  - **🟡 Same Akses Cepat duplication as admin** — Jadwal/Absensi/Aktivitas/Nilai in the quick grid all also appear in the categorized menu below. Two paths to the same destination.
  - **🟡 "PENILAIAN & PERENCANAAN" section still has 6 items** — Nilai + Rekap Nilai + Raport + RPP Saya + Pengumuman + Rekomendasi Belajar. Mixes assessment (Nilai/Rekap/Raport), planning (RPP), communication (Pengumuman), AI (Rekomendasi). After P1, these split across "Nilai & Absensi" tab and "Lainnya" tab.
- **Priority recommendations:**
  1. **P0**: After P1 (bottom nav), trim dashboard to: greeting + KPIs + Ringkasan Hari Ini + RPP status + continued-material card. Drop both the Akses Cepat and the categorized menu (their items move into tabs).
  2. **P1**: Without P1 (short-term): remove the Akses Cepat 4-tile (it's redundant with the menu).
  3. **P2**: Promote the continued-material card pattern into Beranda for parent (continued grade-check) and admin (continued draft pengumuman).

#### T2 — Lesson Plans / Daftar RPP (`teacher_lesson_plan_screen.dart`)
- **Current composition (verified):** green AppBar "Daftar RPP · Lihat dan kelola dokumen RPP Anda" + view-toggle. Search + filter. Subject-grouped card: "B. Arab · 14 RPP" hero with **4 status pills inline** (2 Disetujui / 9 Draft / 1 Menunggu / 1 Ditolak — color-coded dots). Then 3 RPP rows: vertical green/blue rule + "Rencana Pelaksanaan Pembelajaran (RPP…" title + class chip + date + Draft pill (teal). Footer: "11 RPP lainnya · Lihat Semua". FAB to add.
- **What works:** subject-grouped card with status-summary header is excellent. Status counts inline are color-coded consistently with the dashboard's RPP card.
- **Issues:**
  - **🔴 Critical: Title "Rencana Pelaksanaan Pembelajaran (RPP…)" repeats verbatim across all rows** — that's the document type, not the topic. Titles should be the *topic* ("Lingkungan Sekolah", "Makanan dan Minuman"). Truncated boilerplate fills the row.
  - **🟢 Minor: Vertical color rule on left of each row** — green/blue alternation isn't tied to status. Either tie it (Disetujui=green, Draft=teal, Menunggu=orange, Ditolak=red) or drop it.
- **T2b Detail RPP sheet:** modal-like full-screen with X + edit-pen + 3-dot. Hero "Detail RPP" + AI regen card ("Regenerasi Semua Field · Generate ulang seluruh konten RPP dengan AI"). Title block centered ALL-CAPS "RENCANA PELAKSANAAN PEMBELAJARAN (RPP)" + "Bahasa Arab: Makanan dan Minuman (At-Thaam wasy-Syarab) Kelas VII". Meta table (Mata Pelajaran / Kelas / Semester / Tahun Ajaran / Guru / Status). Sections: Kompetensi Inti (KI) with star icon, KI-1, KI-2, …
  - **Issue:** "RPP" appears 5+ times (title, header, body, multiple meta rows). Compress.
  - **Issue:** All-caps centered "RENCANA PELAKSANAAN PEMBELAJARAN (RPP)" reads as print-document-y in mobile. Drop or replace with a small label.
- **T2c AI result:** not deeply audited, but uses the same pattern as Detail RPP. Same recommendations apply.
- **Priority recommendations:**
  1. **P0**: Use the topic as the row title, not the document-type boilerplate.
  2. **P1**: Tie the left vertical rule color to RPP status.
  3. **P1**: Compress RPP detail header — drop the all-caps centered title, drop redundant "RPP" mentions.

#### T3 — Materials / Materi Pembelajaran (`teacher_material_screen.dart`)
- **Current composition (verified):** green AppBar + role-toggle (Mengajar / Wali Kelas) + search + filter. Each row: progress-ring (44% / 63% / 34% / 50%) + "Kelas: 7A / 7B / 8A / 8B" + "B. Arab" subject + meta-row (book-icon "24 sub-bab · checkmark-icon 14 selesai · sparkle-icon 0 AI / 2 AI / 5 AI") + green "8 bab" pill + "Lihat Bab" link.
- **What works:**
  - Progress ring shows real % completion — not just a count. Earns its visual weight.
  - "AI" sparkle count surfaces feature engagement (how much of this class's material is AI-generated). Smart instrumentation visible to user.
  - 4 rows per scroll — appropriate density.
- **Issues:**
  - **🟡 Role-toggle (Mengajar/Wali Kelas) here too** — but for materi, the toggle scope-changes are less obvious. Mengajar mode = subjects I teach. Wali Kelas mode = ?? all subjects in homeroom class? If yes, the wali-kelas mode shows other teachers' materi which is consumption, not management. Confusing.
  - **🟢 Minor: "0 AI" / "2 AI" / "5 AI"** — when count is 0, the chip still renders. Could hide when zero.
- **T3b Sub-chapter detail:** not separately audited but the entry pattern looks clean. AI-content surfaces strongly.
- **Priority recommendations:**
  1. **P1**: Clarify wali-kelas mode for Materi — either remove the toggle (subject-scoped feature, not class-scoped) or document the read-only-other-teachers' scope.
  2. **P2**: Hide "0 AI" chip when count is zero.

#### T4 — Teacher Schedule (`teacher_schedule_screen.dart`)
- **Current composition (verified):** green AppBar + view-toggle (matrix/list) + role-toggle (Mengajar/Wali Kelas) + search + filter. Day-grouped sections ("Senin · 3 sesi" / "Selasa · 2 sesi"). Each row: jam-number purple square avatar + subject (B. Arab) + time (07:00 - 07:45) + class chip (8B/7A/7B). **Below each row: 3 contextual action chips: green "Presensi" / "Materi" / "Kegiatan Kelas".**
- **What works (one of the strongest UX patterns in the app):**
  - **The 3-action chip row beneath each schedule entry** is brilliant. From a single schedule row, the teacher can drill to mark attendance, open the material, or log an activity — *without* navigating away to a different menu. This is the kind of contextual action surface a daily teaching workflow needs.
  - Day-grouped sections with session count gives at-a-glance week shape.
  - Jam-number colored avatar (instead of generic icon) makes each row scannable.
- **Issues:**
  - **🟡 Same role-toggle pattern.** Wali Kelas mode for schedule = the homeroom class's full timetable across all subjects. Useful for the wali-kelas — they want to see when their class is busy. Toggle is *defensible* here.
  - **🟡 The 3 contextual action chips duplicate destinations** that are also in the categorized menu (Kegiatan Kelas / Materi / Absensi). After P1, the schedule row's chips become *deep-links into other tabs* (Kegiatan Kelas → Mengajar tab, etc) — they need to handle cross-tab navigation cleanly.
- **Priority recommendations:**
  1. **P1**: Keep the 3-chip pattern after P1 lands; ensure cross-tab navigation works (use ShellNav from the P1 spec).
  2. **P2**: Schedule view-toggle — capture the matrix variant if not yet shipped.

#### T5 — Rekap Nilai / Grade Recap (`teacher_grade_recap_screen.dart`)
- **Current composition (Mengajar mode):** green AppBar + role-toggle. Search + filter. **Big green hero card**: 0% gauge + "Belum Progres Rekap · Rata-rata penyelesaian rekap nilai" + KPI strip "4 Kelas · 47 Siswa · - Rata-rata". List of class > subject collapsible: 7A (16 siswa · 1 mapel · 0%) → B. Arab (0/16 siswa · 8 bab · red "0" badge); 7B (11 siswa · 1 mapel); 8A (10 siswa · 1 mapel).
- **Wali Kelas mode (T5b):** same shell, but hero shows 1 Kelas · 10 Siswa (homeroom only); list shows 8B as the class with **5 mapel children** (Bahasa Indonesia · Mb Flashy / IPA · Laily / IPS · Aldi / Matematika · Andro / +1) — *with subject teachers' names*, because in wali-kelas mode the user is consuming colleagues' grading data.
- **T5c Table view:** view-toggle flips to FrozenColumnTable; column widths fit Samsung portrait per existing implementation.
- **What works:**
  - Hero card with progress gauge is consistent with admin A15 — design system reuse.
  - Class > subject hierarchy with expandable rows handles the wali-kelas's "5 mapel under 1 class" case correctly.
  - **Wali-kelas mode is materially different data scope, not a cosmetic flip** — and that's the whole reason for the toggle. The audit's Theme 6 was right that wali-kelas isn't "designed in," but the toggle is doing real work.
- **Issues:**
  - **🟡 Role-toggle still adds two-tab cognitive load** to a daily-use screen. After P1+P3, the wali-kelas view becomes a Beranda card link (per Proposal 3) and the toggle drops out.
  - **🟢 Minor: "0%" gauge on the hero is visually heavy** when the number isn't actionable. With 0 progress, replace with a more inviting "Mulai input nilai" CTA.
- **Priority recommendations:** addressed by P3. Until then, keep the toggle — it's earning its place.

#### T6 — Grade Input / Buku Nilai (`teacher_grade_input_screen.dart`)
- **Current composition (verified):** green AppBar "Buku Nilai · B. Arab - 7A" + view-toggle + download + close. Search siswa + 7 assessment-type chips (UH/Ulangan / Tugas / UTS / UAS / PTS / +1 truncated). Each row: # + student name + ID + score (color-coded by predikat) + chevron.
- **Edit sheet (T6b — ModernGradeEditorSheet):** title bar "Ubah Nilai · TUGAS" + X close. Student card. **Big red value "20 / 100" with red bar + "E · Perlu Bimbingan" red predikat pill**. Number input "Nilai (0-100)". Quick-adjust chip row "-5 / -1 / +1 / +5". "Detail lainnya" expandable. Bottom: red-outline "Hapus" + green-filled "Simpan Perubahan".
- **What works (this is the most polished individual screen in the app):**
  - **Color-coded score with predikat pill** — instant qualitative read of a quantitative number. E (Perlu Bimbingan) red is unmissable.
  - **Quick-adjust chips (-5/-1/+1/+5)** are touch-friendly and faster than typing for small corrections.
  - Big red horizontal bar shows score relative to 100 — visualization without bloat.
  - Bottom Hapus/Simpan pair is conventional and clean.
- **Issues:**
  - **🟢 Minor: 7 assessment-type chips with 1 truncated** ("PTS / P…") — likely PAS or Praktek. Same wrap-on-narrow-screen issue as filter sheets. Could scroll horizontally with momentum.
- **Priority recommendations:** none P0/P1. **Use the edit sheet as a model for any future score-input or numeric-input pattern.**

#### T7 — Grade Book / Buku Nilai (`grade_book_screen.dart`)
- The screenshot at `07_grade_book.png` is the same Buku Nilai screen reachable via T6's view-toggle (likely the table mode). No separately-rooted Grade Book screen distinct from T6.
- **Priority recommendations:** confirm the screen file isn't legacy-orphaned. If it IS reachable from T6 view-toggle and shares state, fine. If it's a parallel implementation, retire it (P5 — Grade unification).

#### T8 — Teacher Attendance / Presensi (`teacher_attendance_screen.dart`)
- **Mengajar mode (T8 verified):** green AppBar + role-toggle (Mengajar/Wali Kelas). Search "Cari kelas atau mapel…" + filter. Each row: **circular progress gauge (89% / 98% / 100%)** + "Kelas: 8B / 7B / 8A" + subject + 2-line meta (date + per-day hadir count "10/10 hadir / 1/1 hadir") + green pertemuan-count pill (26 / 5 / 5) + "Lihat Semua" link. FAB.
- **Wali Kelas mode (T8b verified):** toggle right tab now reads **"Kelas 8B"** instead of "Wali Kelas" — clever role-context labeling. List shows subjects taught in 8B by *other* teachers (B. Arab · Mas Yahya, IPS · Aldi, Matematika · Andro) with their respective attendance %s (89% / 65% / 63%).
- **What works:**
  - **Circular gauge with %** is consistent with T3 Materi and admin A15 — design language reuse.
  - **Wali-kelas tab labeled with the class number** ("Kelas 8B") is a small but smart touch — the user's mental model is "my class," and the UI matches.
  - Per-day attendance breakdown ("Senin 20 Apr · 10/10 hadir; Rabu 15 Apr · 1/1 hadir") in the row meta is dense but readable.
- **Issues:**
  - **🟡 Same role-toggle theme.** Like T5, the toggle is earning its place because the data scope is materially different.
  - **🟢 Minor: 65% / 63% rates on the wali-kelas view** — these are *other teachers'* attendance rates. The wali-kelas can see them but probably can't fix them. Should the row be visually muted (read-only color) when the user can't act on it?
- **Priority recommendations:**
  1. **P1**: When P3 lands (wali-kelas folded out), the toggle drops; the wali-kelas data lives under a Beranda card "Kelas Wali: 8B".
  2. **P2**: In wali-kelas mode, visually mute rows where the user can't take action (read-only context).

#### T9 — Teacher Class Activity / Kegiatan Kelas (`teacher_class_activity_screen.dart`)
- **Current composition (verified):** green AppBar + role-toggle. Search + filter. Each row: green class-icon + "Kelas: 8A / 7B / 7A" + "B. Arab" subject + green "4 / 3 / 1 kegiatan" pill on the right. **Sub-rows under each class: 3 colored book/exam-icon entries** ("Lingkungan Sekolah" / "Makanan dan Minuman" / "Peringatan Maulid Rasul") with dates. "Lihat Semua" link. FAB.
- **What works:** compressed nested view (class-card with 3 most-recent activity sub-rows) gives at-a-glance recent-activity per class without requiring a drill.
- **Issues:**
  - **🟡 Sub-row icon color** (green for materials? orange for assessments?) — unclear semantic. Document or unify.
- **T9b Embedded Activity List, T9c Add Activity sheet:** pattern is consistent with the rest. Not separately audited beyond confirming they're on `AppBottomSheet`.
- **Priority recommendations:**
  1. **P2**: Document or unify the sub-row icon color semantic.

#### T10 — Recommendation flow (`recommendation_class_screen.dart`)
- **Current composition (verified — entry only):** green AppBar "Rekomendasi Belajar · Pilih kelas untuk melihat rekomendasi" + role-toggle + search + view-toggle. Per-class card pattern with two states:
  - **Active state (8B):** "10 siswa · 27 rekomendasi aktif" + green "Siswa" pill + 3-status row (27 Total / 27 Belum / 10 Penting) + "Riwayat (1 sesi) · 3 hari lalu · On Demand · 27 rekomendasi · 10 penting" history block + green-filled "Generate Rekomendasi AI" CTA.
  - **Empty state (7A, 7B):** "Belum ada rekomendasi" + green-bordered "Mulai Generate Rekomendasi" CTA.
- **What works:**
  - State-aware CTA styling (filled green for active class, outline-green for empty class) is a nice visual gradient of urgency.
  - Per-class history block surfaces past generation runs — useful for AI features where regen-cost matters.
  - Status row (Total / Belum / Penting) is consistent with the rest of the app.
- **Issues:**
  - **🟡 4-screen drill** (audit's existing finding): class → student → edit → result. The class card is great as a hub, but once you tap "Generate" it drops you into a multi-screen wizard.
- **T10b/c/d:** not separately audited. The flow is on the audit's list for collapsing into 2 screens (class view → bottom sheet for student picker; merge edit + result).
- **Priority recommendations:**
  1. **P1**: Collapse student-picker into a bottom sheet on the class card.
  2. **P1**: Merge edit + result into a single screen with inline regenerate.

#### T11 — Teacher Announcements (`teacher_announcement_screen.dart`)
- **Current composition (verified):** green AppBar + view-toggle + search + filter. **Date-grouped section "Maret 2026"** with priority-counts in the section header (orange dot 1 / blue dot 2 / 3 total). Rows: title + body preview + meta (date + audience "Semua") + chevron. "Penting" pill on important rows.
- **What works:**
  - Date-section grouping with priority counts in the header is a smart pattern (handles long announcement lists gracefully).
  - Read-only flow (no FAB to compose, since teachers don't author school-wide announcements).
- **Issues:**
  - **🟢 Minor: Priority counts in section header** are orange/blue dots without legend. New users won't know orange=Penting and blue=Biasa.
- **Priority recommendations:**
  1. **P2**: Add a tiny legend below the section header (or use chip labels instead of bare dots).

#### T12 — Teacher Report Card / Raport (`teacher_report_card_screen.dart`)
- **Current composition (verified):** green AppBar "Raport · Kelola raport siswa" + view-toggle. Search. **"Ringkasan" KPI card**: 10 Total Siswa / 1 Terisi / 1 Draft / 9 Belum + Progress Keseluruhan 10%. Class card 8B with 10% ring + "1/10" + "Draft 1" pill + chevron.
- **What works:** Ringkasan KPI card with 4 stats + overall progress is a model for any "track-many-things-status" screen.
- **Issues:**
  - **🟢 Minor: Wali-kelas-only screen** (raport editing requires homeroom). When a non-wali-kelas teacher reaches this, what's shown? Empty state probably needs explicit copy.
- **T12b Report card detail:** not deeply audited; pattern looks clean (the captures `12_report_card_detail.png` and `12_report_card_detail_2.png` are the per-student raport printouts).
- **Priority recommendations:**
  1. **P2**: Confirm and write copy for the non-wali-kelas empty state.

#### T13 — Student detail / T14 — Teacher detail
- *Not separately captured (low-priority deep surfaces).* Recommendations from the audit skeleton stand: breadcrumb-lite header showing entry context.

### Parent

#### P1 — Parent Dashboard
- **Current composition (verified):** white AppBar with **purple logo** + "Manajemen Sekolah" + globe + bell + person → **purple/violet gradient hero band** "Selamat Malam · Mas Yahya 🌙" + "2025/2026 Semester Genap - 2026" pill → 4 KPI tiles (1 Anak / 0 Info / 0 Nilai / 0 Absen with eye/chat/star/calendar icons) → "Akses Cepat" 2-tile grid (Pengumum… *truncated* / Tagihan) → "Ringkasan Hari Ini" 2x2 card grid (1 Anak Saya · Siswa terdaftar / 0 Nilai Baru · Pembaruan terbaru / Kehadiran Anak [Pekanan ▼] · Belum ada data kehadiran siswa / 0 Pengumuman · Info terbaru) → "MENU" section with Pengumuman tile.
- **What works:**
  - Same pleasant time-aware greeting + emoji pattern as teacher dashboard.
  - "Ringkasan Hari Ini" 2x2 grid is well-suited to parent's check-in mental model — Anak Saya / Nilai Baru / Kehadiran / Pengumuman maps to the four daily questions a parent has.
  - Period dropdown (Pekanan) on the Kehadiran card is a smart inline filter.
- **Issues:**
  - **🟡 "Pengumum…"** truncates in the Akses Cepat tile (label too long for the 2-tile grid). Same anti-pattern as admin's "Pengatura\nn".
  - **🟡 Eye-icon for "Anak" KPI tile** is unclear. Star for Nilai also non-obvious. Replace with people-icon and 100-icon respectively.
  - **🟡 Same Akses Cepat / Menu duplication** — Pengumuman and Tagihan in Akses Cepat are also in the Menu below.
- **Priority recommendations:**
  1. **P0**: After P1 (bottom nav), reduce Beranda to: greeting + KPIs + Ringkasan Hari Ini 2x2 grid only. Drop Akses Cepat and Menu.
  2. **P1**: Without P1: shorten "Pengumum…" label or expand the tile width.
  3. **P1**: Replace eye/star KPI icons with semantically clearer ones.
  4. **P1**: Surface child picker as a compact pill in the AppBar (like SchoolPill) for multi-anak parents.

#### P2 — Parent Attendance / Kehadiran Anak (`parent_attendance_screen.dart`)
- **Current composition (verified):** purple AppBar "Kehadiran Anak · Anak Mas Yahya 1" + 3-dot. Search + filter. Child profile card (avatar + "Anak Mas Yahya 1" + NIS + "Kelas:" *blank*). **"Rekap Tahunan" card**: 100% gauge + "Tingkat Kehadiran" + 5-stat row (7 Hadir green / 0 Telat blue / 0 Izin purple / 0 Sakit orange / 0 Alpha red). "Riwayat Absensi" section: rows with date avatar (30 Mar / 26 Mar) + subject (Penjaskes) + day + green "Hadir" pill + red dot.
- **What works:**
  - 5-status row with color-coded counts (Hadir/Telat/Izin/Sakit/Alpha) is the cleanest at-a-glance attendance summary I've seen across the app — color = status, count = magnitude.
  - Date-as-avatar (30 Mar) for each Riwayat row is a great compression pattern.
  - Per-row "Hadir" pill confirms status; red dot suggests unread/new.
- **Issues:**
  - **🔴 Critical: "Kelas:" field on the child profile is empty.** Should show "7A" or whatever class. Either backend missing data or parent-screen state bug.
  - **🟡 Red dot at the right of each Riwayat row** — unclear semantic. Unread notification? Below threshold? Document or remove.
- **Priority recommendations:**
  1. **P0**: Fix the empty "Kelas:" field.
  2. **P1**: Document or drop the red-dot indicator on each Riwayat row.

#### P3 — Parent Grades / Nilai Akademik Anak (`parent_grade_screen.dart`)
- **Current composition (verified):** purple AppBar "Nilai Akademik Anak · Pantau Nilai Anak" + 3-dot. "Pilih Anak" dropdown card with child meta. List of grade rows: **big color-coded score (88.0 / 92.0 / 85.0 / 90.0 / 82.0)** + subject (Seni Budaya / Bahasa Indonesia / Matematika / B. Arab) + assessment chip (UH / Tugas) + date + teacher chip + **red dot** on right.
- **What works:**
  - Big color-coded score on the left is the focus — exactly what a parent looks for first.
  - Per-row meta (assessment type + date + teacher) gives enough context without crowding.
- **Issues:**
  - **🟡 Score color semantic unclear:** 88.0 = green, 92.0 = blue, 85.0 = green, 90.0 = green, 82.0 = green. Why is 92 blue and 90 green? Possibly: green = average-or-above, blue = exemplary (≥90), but unclear without legend. Document the threshold or unify.
  - **🟡 Red dot on every row** — same unclear-semantic as P2.
  - **🟡 "Kelas: -"** in the Pilih Anak card again empty — same data bug as P2.
- **Priority recommendations:**
  1. **P0**: Fix the empty "Kelas:" field (likely shared bug across parent screens).
  2. **P1**: Document or unify the score-color semantic (consider matching admin A15: green=pass, orange=caution, red=below KKM).
  3. **P1**: Document or drop the red-dot indicator.

#### P4 — Parent Class Activity / Aktivitas Kelas Anak (`parent_class_activity_screen.dart`)
- **Current composition (verified):** purple AppBar + 3-dot. "**2 Anak**" pill. "Pilih Anak" dropdown showing "Anak Mas Yahya 1 (A) · Kelas: 7A · NIS: T10001A". List of activity rows: green book-icon avatar + activity title (Diskusi Kelompok / Tugas Mandiri / Materi / Latihan Soal) + subject (Matematika / B. Arab) + body preview + meta-row (MATERI pill / date / Semua audience pill).
- **What works:**
  - Multi-anak handled with explicit "2 Anak" pill + dropdown (clear scoping).
  - Body preview on activity rows is genuinely useful — parent can scan without tapping into each.
  - Type pill (MATERI) categorizes content. Helps differentiate "homework" from "lesson reference."
- **Issues:**
  - **🟢 Minor: Class shown ("7A")** in the dropdown — different from P2/P3 where Kelas was blank. Either data is just missing in those (more likely), or this screen has a different data source. Investigate.
- **Priority recommendations:** none P0/P1. Clean as-is.

#### P5 — Parent Announcements / Pengumuman (`parent_announcement_screen.dart`)
- **Current composition (verified):** purple AppBar "Pengumuman · Lihat pengumuman sekolah". Search. Simple flat list: avatar (megaphone icon, blue or orange) + title + body preview. No date / no time-since / no chevron. Last row's orange megaphone implies priority but no explicit pill.
- **Issues:**
  - **🔴 Critical: No date / time-since on parent announcement rows.** Teacher version (T11) groups by month with priority counts. Parent version is sparser — but missing the date is a real loss for parents who want "what's new today vs. older."
  - **🟡 No "Penting" pill** visible — only the orange icon implies priority.
  - **🟡 Different visual treatment from teacher version** — teacher has date-section grouping with priority counts in section headers. Parent has none of this. Inconsistent.
- **Priority recommendations:**
  1. **P0**: Add date/time-since to each row.
  2. **P1**: Add explicit "Penting" pill (orange) for priority items, matching teacher T11.
  3. **P1**: Adopt date-section grouping pattern from T11 for consistency.

#### P6 — Parent Billing / Tagihan Sekolah (`parent_billing_screen.dart`)
- **Current composition (verified):** **BLUE AppBar (not purple!)** "Tagihan Sekolah" + filter + refresh. Search "Cari tagihan…". 2 child-avatar circles (active blue + inactive grey). Each tagihan card: title (Uang Pangkal / SPP) + "-" placeholder + red "⚠ Belum Bayar" pill + 2-column "Jumlah" Rp 2.500.000 + "Metode" ONCE / MONTHLY.
- **What works:**
  - "Belum Bayar" red pill is unmissable — exactly the right escalation for an unpaid bill.
  - 2-column Jumlah/Metode layout is clean.
  - Child avatar circles for picker are visually warm.
- **Issues:**
  - **🔴 Critical: BLUE AppBar instead of purple** — breaks the role-color contract. Parent role is purple everywhere else; this screen looks like it was built before the contract was set, or imported from a different role's flow.
  - **🔴 Critical: "Metode: ONCE / MONTHLY"** in English. Everywhere else in the app is Bahasa Indonesia. Should be "Sekali" / "Bulanan".
  - **🔴 Critical: No "Bayar Sekarang" CTA visible.** How does the parent actually pay the bill? Is it an out-of-app workflow (transfer + upload receipt)? If yes, that flow needs an explicit affordance ("Bayar via Transfer" → opens steps + upload). If in-app, the CTA is missing.
  - **🟡 "-" placeholder** on each row (where the bill description / due-date should be) is uninformative.
  - **🟢 Minor: Different status bar styling** (white time on the dark AppBar) confirms this screen has a *separate theme implementation* from the rest of parent — explains the blue.
- **Reflow sketch:**
  ```
  ┌────────────────────────────────────────┐
  │ ← Tagihan Sekolah          🔍 ⚙        │  ← Purple AppBar
  ├────────────────────────────────────────┤
  │  [Anak 1 ●][Anak 2]  ─ Cari tagihan…  │
  │                                        │
  │  ┌────────────────────────────┐        │
  │  │ Uang Pangkal               │        │
  │  │ Rp 2.500.000 · Sekali bayar│        │
  │  │ Jatuh tempo: 30 Apr 2026   │        │
  │  │ ⚠ Belum Bayar              │        │
  │  │ ─────────── [Bayar Sekarang]│       │
  │  └────────────────────────────┘        │
  │  ┌────────────────────────────┐        │
  │  │ SPP April                  │        │
  │  │ Rp 500.000 · Bulanan        │        │
  │  │ Jatuh tempo: 5 Mei 2026    │        │
  │  │ ⚠ Belum Bayar              │        │
  │  │ ─────────── [Bayar Sekarang]│       │
  │  └────────────────────────────┘        │
  └────────────────────────────────────────┘
  ```
- **Priority recommendations:**
  1. **P0**: Fix AppBar color to purple (role-color contract).
  2. **P0**: Translate ONCE/MONTHLY to Sekali/Bulanan.
  3. **P0**: Add explicit "Bayar Sekarang" CTA per row + define the payment flow (in-app or transfer+upload).
  4. **P0**: Add due-date to each row.
  5. **P1**: Replace "-" placeholder with descriptive secondary text.

#### P7 — Parent Report Card / E-Raport list (`parent_report_card_screen.dart`)
- **Current composition (verified):** purple AppBar "E-Raport · Lihat raport akademik siswa" + 3-dot. Semester dropdown "Genap". List of children: pastel-letter avatar + child name + NIS + chevron.
- **What works:** simple, clean. Per-anak chevron drill is the right pattern.
- **Priority recommendations:** none.

#### P7b — Parent Report Card detail / E-Raport (`parent_report_card_detail_screen.dart`)
- **Current composition (verified):** purple AppBar "Raport: Anak Mas Yahya 1 (A) · Detail E-Raport Siswa". Centered child card (avatar + name + NIS / NISN). Section "Sikap" (Spiritual : A - / Sosial : A -). Section "Nilai Mata Pelajaran" with table (Mata Pelajaran / Pengetahuan columns: Matematika 90 (A) / Bahasa Indonesia 88 (A) / IPA 95 (A)). Floating-action blue "Cetak PDF" button bottom-right.
- **What works:**
  - Print-document-y layout (centered child card, section headers, table) is appropriate for an official document — matches user expectations of a real raport.
  - "Cetak PDF" as the primary CTA is correct for this screen.
- **Issues:**
  - **🟢 Minor: "Pengetahuan" column** without companion "Keterampilan" / "Sikap-numeric" columns suggests the table is partial. Confirm this is intentional vs. data-not-yet-loaded.
- **Priority recommendations:** none P0/P1.

---

## Priority redesign proposals (sprint-ready)

Ranked by impact × reversibility.

### P1 — Persistent bottom navigation shell *(2–3 day spike)*
**Impact:** highest. Fixes the root cause behind "messy menus" and reduces dashboard overload in the same change.
**Work:** new `RoleNavShell` widget hosting 4–5 tabs per role; route existing screens as tab children; keep deep pushes working inside each tab via a nested `Navigator`.
**Risk:** medium — requires auditing every existing `AppNavigator.push` call for cross-tab vs same-tab intent. Can ship behind a feature flag.

### P2 — Dashboard reduction to "today" page *(1 day, follows P1)*
**Impact:** high. Rebalances the first-two-seconds of every session.
**Work:** strip `admin_dashboard_body`, `teacher_dashboard_body`, `parent_dashboard_body` to: header + today-card + pending-inbox. Move QuickActionGrid and categorized menus into their respective tabs.
**Risk:** low — existing shared components stay, just fewer of them on dashboard.

### P3 — Fold wali-kelas into the IA *(2 days, after P1)*
**Impact:** medium-high. Removes two per-screen toggles and a mental-model wart.
**Work:** introduce wali-kelas Beranda card; remove `RoleToggle` from `teacher_grade_recap_screen` and `teacher_attendance_screen` (each screen always reads *from the teacher's POV*, wali-kelas-only views land under a dedicated Beranda tile).
**Risk:** low.

### P4 — Settings cluster consolidation *(1 day)*
**Impact:** medium. Eliminates "two paths to Manajemen Data."
**Work:** remove the top-level Manajemen Data menu tile for admin (it's already inside the System Settings hub). Merge `school_settings_screen` + `school_level_settings_screen` into one screen with a tingkat sub-tab. Keep `time_settings_screen` separate.
**Risk:** very low.

### P5 — Grade feature unification *(2 days, optional)*
**Impact:** medium. Reduces grade-related screens from 5 to 2–3.
**Work:** merge `teacher_grade_input` + `teacher_grade_recap` into a single "Nilai" screen with two tabs (Input, Rekap). Retire `grade_book_screen` if unused (confirm first). Keep admin/parent variants separate.
**Risk:** medium — grade input is high-traffic, any regression is painful.

### P6 — Per-screen density pass *(ongoing, after screenshots)*
**Impact:** low-medium per screen, cumulative.
**Work:** drop into each `[awaiting screenshot]` section above and do the design-critique pass. Typical fixes: two-line row treatments where fields are currently four-across, right-align numeric columns, collapse status-chip + badge duplication into one.
**Risk:** very low — cosmetic.

---

## P0 bugs surfaced by the screenshot pass

These are *visual-evidence* defects that don't require P1+ structural work — they can be fixed today, independently of the redesign. Listed in rough impact order.

| # | Severity | Screen | Bug |
|---|---|---|---|
| 1 | 🔴 a11y | A1 Admin Dashboard | Hero card text "Halo, Mas · Admin sekolah" is dark grey on near-black — fails WCAG AA. Lighten text to white. |
| 2 | 🔴 layout | A1 Admin Dashboard | "Pengatura\nn" QuickAction tile label wraps onto two lines. Shorten to "Setelan" or truncate. |
| 3 | 🔴 layout | P1 Parent Dashboard | "Pengumum…" tile label truncates in Akses Cepat. Same pattern as #2. |
| 4 | 🔴 bug | S3 Pilih Peran | Stale "Email atau password salah" toast leaks from login into the role-picker screen. |
| 5 | 🔴 contract | S4 Notifications | AppBar is green (parent role color) when signed in as admin. Should use `ColorUtils.getRoleColor(role)`. |
| 6 | 🔴 contract | P6 Parent Billing | AppBar is blue, not purple. Role-color contract violation. |
| 7 | 🔴 i18n | P6 Parent Billing | "Metode: ONCE / MONTHLY" in English while everything else is Bahasa. Translate to Sekali / Bulanan. |
| 8 | 🔴 missing | P6 Parent Billing | No "Bayar Sekarang" CTA. How does the parent actually pay? Define + add the flow. |
| 9 | 🔴 missing | P6 Parent Billing | No due-date visible on tagihan rows. |
| 10 | 🔴 missing | P5 Parent Announcements | No date/time-since on announcement rows. Teacher version has it, parent doesn't. |
| 11 | 🔴 data | P2/P3 Parent | "Kelas:" field on child profile cards is empty in P2 and P3, populated in P4. Investigate the data path. |
| 12 | 🔴 scaling | A7 Verifikasi tab | Mega-button-per-row pattern doesn't scale beyond 1-2 rows. Replace with inline check/x icons. |
| 13 | 🔴 bug | A6 Schedule matrix | Every "Jam 1" row in the matrix shows the same two entries. Either bad seed data or a render bug — verify. |
| 14 | 🔴 IA | A12 RPP | Title says "RPP - Agil" — teacher-scoped — but reached from admin's "Kelola RPP" menu. Show all RPPs with teacher chip, or expose the picker step. |
| 15 | 🔴 destructive | A11 Attendance Report | Red trash icon on every report row. Admins shouldn't be able to delete attendance audit records. |
| 16 | 🔴 IA | A14 Class Activity | Title "Kegiatan Kelas" but content is a guru-list. Should be a time-scoped activity feed, with per-teacher drill secondary. |
| 17 | 🟡 brand | S1 Login | Brand string mismatch: "Kamil Edu" on login, "Manajemen Sekolah" everywhere else. Pick one. |
| 18 | 🟡 missing | S1 Login | No "Lupa Password" link. |
| 19 | 🟡 IA | A20 Data Management | Pure-indirection hub. Multiple paths lead to the same 4 master entities. Delete after P1. |

Most of these are <1 day fixes. Bundling them into a "P0 polish pass" before P1 ships would meaningfully lift perceived quality.

---

## Cross-cutting findings beyond the original 6 themes

The screenshot pass surfaced patterns the code-only audit missed:

### Theme 7 — Per-row destructive actions are systemic

Every admin CRUD list (A2 / A3 / A4 / A5 / A6 / A10 / A11 / A12 + A7 sub-tabs) renders a **red trash icon on every row**. The pattern:

- Adds 2 actions per row (edit-pen + trash) that are redundant with FAB and presumably bulk-mode.
- Makes accidental deletes one fat-finger away.
- Eats ~20% of row width.

Switching to the conventional pattern — *tap-row to detail/edit, long-press to enter bulk-select mode, FAB to add* — recovers space and reduces destructive-tap risk across **8+ admin screens at once**. Worth a single-PR sweep.

### Theme 8 — Role-color contract is leaky

The contract is: admin = navy, teacher = green, parent = purple. Two screens break it:

- **Notifications** (S4) renders with a green AppBar regardless of active role.
- **Parent Billing** (P6) renders with a blue AppBar when parent should be purple — and the screen also has different status-bar styling, suggesting a separate theme implementation.

These aren't just cosmetic — role color is a *navigational signal* that tells users which role's surface they're in. Two leaks erode that signal.

### Theme 9 — Wali-kelas toggle is doing real work

The audit's Theme 6 framed wali-kelas as "bolted on, not designed in." The screenshots soften that read. The role-toggle on T4 / T5 / T8 / T3 / T9 isn't just a cosmetic flip — it's a **scope change** on the data shown:

- **Mengajar mode**: subjects I teach (4 classes / 47 siswa for Mas Yahya).
- **Wali Kelas mode**: my homeroom class only (1 class / 10 siswa), but showing **other teachers' grades / attendance** in that class.

The data scope is materially different. The toggle is *earning* its place. P3 (fold wali-kelas into IA) should not delete the toggle naively — it should preserve the scope-switch semantics behind a Beranda card. The teacher attendance screen even labels the right tab as "Kelas 8B" in wali-kelas mode (instead of generic "Wali Kelas"), which is the kind of small touch that suggests the feature was thought about more than the audit gave credit for.

### Theme 10 — Reusable patterns the rest of the app should steal

Several screens have well-designed atoms that should be promoted to shared components or applied elsewhere:

- **A15 Rekap Nilai's color-coded distribution bar** (≥80 / 60-79 / <60 with counts inline) — perfect for any "score distribution" surface. Reuse on parent's grade detail.
- **T1 Teacher dashboard's RPP status card** with 3-color dots (Disetujui / Ditolak / Menunggu) — model for any "approval-pipeline status" widget. Reuse for admin pengumuman draft state, parent billing payment state.
- **T1 Teacher dashboard's continued-material card** ("4/8 Bab · Selanjutnya: Lingkungan Se…") — the "where you left off" pattern. Reuse for teacher RPP "next chapter to draft", parent "next subject to check."
- **T6 ModernGradeEditorSheet's quick-adjust chips (-5/-1/+1/+5)** — reusable for any numeric input that benefits from increments (attendance count overrides, billing partial payments).
- **T8 Wali-kelas tab labeled with class number** ("Kelas 8B" instead of "Wali Kelas") — the principle "context-aware labels beat generic" applies broadly.
- **A1 Admin "Terhubung realtime · 16:27" pill** — trust signal, low-cost addition. Should appear on every Beranda.

### Theme 11 — AI features are well-affordanced with sparkle iconography

The sparkle icon (✨) appears consistently on AI surfaces: Rekomendasi Belajar Generate CTA, RPP Regenerasi, Materi AI count. This is a coherent visual language for "AI-powered" that users can learn. **Keep the sparkle** as the AI tell across the app — *do not* dilute it with non-AI features.

---

## How we'll use this doc

1. **P0 bug pass (this week):** burn down the 19 P0 bugs above. Most are <1 day fixes; cumulative effect is large.
2. **P1 implementation (week 2-3):** build the bottom nav shell per `P1_BottomNav_Spec.md`. Settle Q1-Q10 there before starting.
3. **P2-P4 (week 3-4):** ship dashboard reduction, wali-kelas Beranda card, settings consolidation. All depend on P1 being live.
4. **Theme 7 sweep (1 PR):** drop per-row edit/delete across 8+ admin screens. Ship as one focused refactor — it's a CLAUDE.md "one rule" application.
5. **Theme 10 promotions:** as P5/P6 work happens, harvest reusable atoms into `lib/core/widgets/` and document.
6. **Handoff to design-handoff skill:** once Q1-Q10 of P1 are settled, run `design:design-handoff` to turn it into a dev-ready spec with tokens, states, breakpoints, animation timings.
