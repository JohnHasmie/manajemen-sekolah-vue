# UI Redesign — Capture Checklist

**Goal:** build a baseline snapshot of every primary screen across all three roles so we can audit density, hierarchy, and reflow opportunities before the redesign pass.

## How to capture

1. Run the app on a device or simulator (Samsung device preferred — it's the primary target and has the nav-bar safe-area quirk we care about).
2. Sign in as the right role for each section below.
3. For each row: navigate to the screen in the app, take a screenshot, save it into the matching folder with the exact filename listed.
4. When a screen has meaningful variants (empty state, long list, bulk-select mode, filter open), capture each and suffix the filename: `_empty.png`, `_long.png`, `_bulk.png`, `_filter.png`. The base `.png` should be the most representative state (not empty, not error, default filters).
5. File format: **PNG**, portrait orientation, 1x device pixel ratio is fine.

## Folder layout

```
_baseline/
├── CAPTURE_CHECKLIST.md    ← this file
├── shared/                 ← login, dashboard router, notifications
├── admin/                  ← admin role screens
├── teacher/                ← teacher role screens (incl. wali-kelas variants)
└── parent/                 ← parent role screens
```

---

## Shared / Entry (3 screens)

Save into `_baseline/shared/`.

| # | Filename | Screen | Notes |
|---|---|---|---|
| S1 | `01_login.png` | Login | From cold start, before signing in |
| S2 | `02_choose_school.png` | Post-login dashboard routing screen | If there's a role-picker or splash, capture it; otherwise skip |
| S3 | `03_dashboard_router.png` | Post-login dashboard routing screen | If there's a role-picker or splash, capture it; otherwise skip |
| S4 | `04_notifications.png` | Notification list | Open from any role after signing in |

---

## Admin role (13 screens + sub-screens)

Sign in as a super-admin with access to multiple schools if possible (so `SchoolPill` shows). Save into `_baseline/admin/`.

### Dashboard & navigation
| # | Filename | Screen | Notes |
|---|---|---|---|
| A1 | `01_dashboard.png` | Admin Dashboard | Entry state — HeroStats + PendingInbox + QuickActions visible |
| A1b | `01_dashboard_long.png` | Admin Dashboard scrolled | Scroll to bottom to show everything |

### Manajemen Data (5 screens × CRUD variants)
| # | Filename | Screen | Notes |
|---|---|---|---|
| A2 | `02_students_list.png` | Admin Student Management — default list | Default view with some data |
| A2b | `02_students_filter.png` | Same — filter sheet open | Tap the filter icon |
| A2c | `02_students_bulk.png` | Same — long-press to enter bulk mode | Show BulkActionBar |
| A2d | `02_students_edit.png` | Same — edit sheet open | Tap "+" or edit an existing row |
| A3 | `03_teachers_list.png` | Admin Teacher Management | Default |
| A3b | `03_teachers_edit.png` | Same — edit sheet open | |
| A4 | `04_classrooms_list.png` | Admin Classroom Management | Default |
| A4b | `04_classrooms_edit.png` | Same — edit sheet open | |
| A5 | `05_subjects_list.png` | Admin Subject Management | Default |
| A5b | `05_subjects_edit.png` | Same — edit sheet open | |
| A6 | `06_schedule_list.png` | Admin Schedule Management — list view | Default (list mode) |
| A6b | `06_schedule_matrix.png` | Same — matrix mode | Tap the view-toggle button |
| A6c | `06_schedule_edit.png` | Same — edit sheet open | |

### Keuangan
| # | Filename | Screen | Notes |
|---|---|---|---|
| A7 | `07_finance_hub.png` | Admin Finance Hub | Top of hub |
| A7b | `07_finance_hub_long.png` | Same — scrolled | Show all sections |
| A7c | `07_finance_verify.png` | Same — payment verification sheet | Tap a pending row |
| A7d | `07_finance_billing.png` | Same — generate bills sheet | Tap the generate action |
| A8 | `08_finance_report.png` | Admin Finance Report | Default period | i dont know the ss is right or not
| A9 | `09_finance_class_report.png` | Class Finance Report (drill-down from hub) | Tap a class row |

### Sistem
| # | Filename | Screen | Notes |
|---|---|---|---|
| A10 | `10_announcements_list.png` | Admin Announcements | Default |
| A10b | `10_announcements_compose.png` | Same — compose sheet open | |
| A11 | `11_attendance_report.png` | Admin Attendance Report | Default |
| A11b | `11_attendance_report_filter.png` | Same — filter open | |
| A12 | `12_lesson_plans.png` | Admin Lesson Plans | Default |
| A12b | `12_lesson_plans_regen.png` | Same — regen sheet open | |
| A13 | `13_report_cards.png` | Admin Report Cards | Default |
| A14 | `14_class_activity.png` | Admin Class Activity | Default |
| A15 | `15_grade_overview.png` | Admin Grade Overview (matrix) | Default |

### Pengaturan
| # | Filename | Screen | Notes |
|---|---|---|---|
| A16 | `16_system_settings.png` | System Settings hub | Entry state with SchoolPill.expanded |
| A17 | `17_school_settings.png` | School profile settings | |
| A18 | `18_school_level_settings.png` | Tingkat / level settings | |
| A19 | `19_time_settings.png` | Waktu pembelajaran settings | |
| A20 | `20_data_management.png` | Data management | |
| A21 | `21_account_settings.png` | Account settings | |

---

## Teacher role (18 screens + variants)

Sign in as a **wali-kelas teacher** so we capture both the regular-teacher and wali-kelas surfaces. Save into `_baseline/teacher/`.

### Dashboard & Navigation
| # | Filename | Screen | Notes |
|---|---|---|---|
| T1 | `01_dashboard.png` | Teacher Dashboard | Entry state |
| T1b | `01_dashboard_long.png` | Same — scrolled | |

### Pembelajaran
| # | Filename | Screen | Notes |
|---|---|---|---|
| T2 | `02_lesson_plans.png` | Teacher Lesson Plans | Default |
| T2b | `02_lesson_plans_detail.png` | Lesson Plan detail | Tap a plan |
| T2c | `02_lesson_plans_ai_result.png` | Lesson Plan AI result | From AI-generated flow |
| T3 | `03_materials.png` | Teacher Materials | Default |
| T3b | `03_materials_sub_chapter.png` | Sub-chapter detail | Tap a sub-chapter |
| T4 | `04_schedule.png` | Teacher Schedule | Default |

### Nilai (guru + wali-kelas)
| # | Filename | Screen | Notes |
|---|---|---|---|
| T5 | `05_grade_recap.png` | Teacher Grade Recap (guru role) | Default |
| T5b | `05_grade_recap_walikelas.png` | Same — toggled to wali-kelas | Use role toggle |
| T5c | `05_grade_recap_table.png` | Same — table view | Use view toggle |
| T6 | `06_grade_input.png` | Teacher Grade Input | Default |
| T6b | `06_grade_input_editor.png` | Same — grade editor sheet open | |
| T7 | `07_grade_book.png` | Grade Book | If reachable |

### Kehadiran
| # | Filename | Screen | Notes |
|---|---|---|---|
| T8 | `08_attendance.png` | Teacher Attendance (guru) | Default |
| T8b | `08_attendance_walikelas.png` | Same — wali-kelas toggle | |

### Kegiatan Kelas
| # | Filename | Screen | Notes |
|---|---|---|---|
| T9 | `09_class_activity.png` | Teacher Class Activity | Default |
| T9b | `09_class_activity_embedded.png` | Embedded Activity List | If reachable via drill-down |
| T9c | `09_class_activity_add.png` | Same — add activity sheet | |

### Rekomendasi Belajar
| # | Filename | Screen | Notes |
|---|---|---|---|
| T10 | `10_recommendation_class.png` | Recommendation Class list | |
| T10b | `10_recommendation_student.png` | Recommendation Student list | Tap a class |
| T10c | `10_recommendation_edit.png` | Recommendation Edit | Tap a row |
| T10d | `10_recommendation_result.png` | Recommendation Result | After generating |

### Pengumuman + Rapor
| # | Filename | Screen | Notes |
|---|---|---|---|
| T11 | `11_announcements.png` | Teacher Announcements | |
| T12 | `12_report_card.png` | Teacher Report Card | |
| T12b | `12_report_card_detail.png` | Report Card detail | |

### Detail screens (accessible across teacher flows)
| # | Filename | Screen | Notes |
|---|---|---|---|
| T13 | `13_student_detail.png` | Student detail | Tap a student |
| T14 | `14_teacher_detail.png` | Teacher detail | If reachable |

---

## Parent role (7 screens)

Sign in as an orang-tua (parent) account. Save into `_baseline/parent/`.

| # | Filename | Screen | Notes |
|---|---|---|---|
| P1 | `01_dashboard.png` | Parent Dashboard | Entry state |
| P2 | `02_attendance.png` | Parent Attendance | Child's attendance |
| P3 | `03_grades.png` | Parent Grades | |
| P4 | `04_class_activity.png` | Parent Class Activity | |
| P5 | `05_announcements.png` | Parent Announcements | |
| P6 | `06_billing.png` | Parent Billing | |
| P7 | `07_report_card.png` | Parent Report Card list | |
| P7b | `07_report_card_detail.png` | Same — detail | |

---

## After you finish capturing

Drop me a message like **"screenshots ready"** and I'll walk the folder tree, match each file against the audit doc, and fill in the per-screen analysis (current composition, density/hierarchy/grouping issues, reflow proposals).

You don't need to capture every row in one sitting — I can start the audit on whatever's dropped in so far if you want partial feedback first. Just tell me which subset is ready.
