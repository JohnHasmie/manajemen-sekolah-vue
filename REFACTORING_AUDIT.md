# Refactoring Plan — Audit Results
**Last updated:** April 14, 2026 (session 7 — LessonPlan 16 files, PaginatedListView 5 files, FormFieldSection assessed)

---

## Phase 0 — Shared Design System & Component Library

Adoption counts are live file counts (files that import + call the component, excluding the `core/widgets/` definition files).

### 0.1 RoleToggle
**Status:** ✅ ADOPTED
- Used across attendance, schedule, class_activity, grades role-toggle mixins

### 0.2 SearchFilterBar
**Status:** ✅ ADOPTED
- Used in attendance, schedule, grades, class_activity, finance, lesson_plan filter sheets and screens

### 0.3 ActiveFilterChips
**Status:** ✅ ADOPTED (8 direct adopters)
- grade_recap_filter_mixin, admin_schedule_filter_mixin, admin_schedule_header, teacher_schedule_filter_mixin, schedule_header_ui_mixin, attendance_filter_helper → admin_report_header, finance_filter_mixin → finance_payment_types_tab, class_finance_report_screen

### 0.4 FilterBottomSheet
**Status:** ✅ ADOPTED (via AppFilterBottomSheet in most filter sheets)

### 0.5 FilterChipGrid
**Status:** ✅ ADOPTED (7 files)
- attendance_filter_ui_mixin (4 sections), filter_dialog_content (class/subject), filter_content_mixin (status), plus 4 others

### 0.6 StatusBadge
**Status:** ✅ WIDELY ADOPTED (13 files)
- attendance (descriptive_builder_mixin, teacher_attendance_detail_card, admin_attendance_summary_card, parent_attendance_item)
- lesson_plans (card_builders_mixin, lesson_plan_admin_card)
- report_cards (student_list_mixin, report_card_header, report_card_status_badge)
- finance (bill_status_cell, pending_payment_card)
- subjects (subject_class_ui_builder_mixin)

### 0.7 StatSummaryCard / StatSummaryRow
**Status:** ✅ ADOPTED (4 files)
- finance_dashboard_stats, admin_detail_ui_stats_mixin, parent_attendance_monthly_summary, quiz_stats_bar

### 0.8 AppDataTable
**Status:** ❌ NOT ADOPTED (0 usage)
- All tables remain custom per-screen. Low priority — tables are highly heterogeneous.

### 0.9 SectionHeader
**Status:** ✅ DONE (97+ instances)

### 0.10 TeacherPageHeader
**Status:** ✅ ADOPTED (8 files)
- teacher_schedule, teacher_attendance, grades, teacher_class_activity, parent_attendance, teacher_material, teacher_lesson_plan, parent_announcement

### 0.11 PaginatedListView
**Status:** ⚠️ PARTIAL (5 files)
- Adopted in teacher_list_content, admin_student_management_screen, announcement_list_content, admin_classroom_management_screen, subject_ui_builder_mixin (admin_subject_management_screen)
- **Not converting:** admin_finance_screen (dual tab pagination), admin_attendance_report_screen (dual views) — too complex for simple swap

### 0.12 FormFieldSection / FormDropdownField / FormTextField
**Status:** ⚠️ PARTIAL — visual mismatch prevents further adoption
- 6 schedule dropdowns only; major forms (add_activity, lesson_plan, teacher_form, student_form) still use inline fields
- **Assessment:** FormFieldSection uses label-above-field layout, but all dialog forms use label-inside-field (`labelText` float). Each feature has its own extracted `*DialogTextField` / `*DialogDropdown` widget (student, subject, finance, classroom, teacher) with consistent inline-label styling. Adopting FormFieldSection would change the visual UX — not a safe refactor without design approval.

### 0.13 HomeroomClassSelector
**Status:** ❌ NOT ADOPTED (0 usage)

### 0.14 ViewToggleButton
**Status:** ✅ DONE (6+ locations)

### 0.15 ActionConfirmSheet
**Status:** ✅ WIDELY ADOPTED (10 files)
- student_deletion_helper, classroom_deletion_helper, teacher_crud_mixin, subject_actions_mixin, lesson_plan_crud_mixin, embedded_activity_delete_mixin, finance_action_mixin, admin_schedule_dialogs_mixin, grade_recap_unsaved_changes_dialog, announcement_delete_dialog

### 0.16 DragHandle
**Status:** ✅ DONE (used in AppBottomSheet and FilterBottomSheet internals + direct call sites)

### 0.17 BottomSheetHeader
**Status:** ✅ DONE (used via AppBottomSheet / FilterBottomSheet composites)

### 0.18 BottomSheetFooter
**Status:** ✅ DONE (used via AppBottomSheet / FilterBottomSheet composites)

### 0.19 AppBottomSheet
**Status:** ✅ ADOPTED (4 files)
- activity_type_bottom_sheet, grade_column_options_sheet, teacher_selection_sheet, material_generate_sheet

### 0.20 AppAlertDialog
**Status:** ✅ ADOPTED (7 files)
- login_auth_handler, dashboard dialog_mixin, lesson_plan_ai_regeneration_mixin, lesson_plan_ui_mixin, generate_lesson_plan_api_mixin, grade_recap_delete_chapter_dialog, admin_report_card_actions_mixin

### Phase 0 Summary (current)
| Status | Count | Items |
|--------|-------|-------|
| ✅ DONE / ADOPTED | 16 | 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.9, 0.10, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20 |
| ⚠️ PARTIAL | 2 | 0.11 (PaginatedListView), 0.12 (FormFieldSection) |
| ❌ NOT ADOPTED | 2 | 0.8 (AppDataTable), 0.13 (HomeroomClassSelector) |

---

## Phase 1 — Critical Screens (file-size targets): ✅ ALL UNDER 400 LINES

| Item | File | Lines Now | Shared Components? |
|------|------|-----------|--------------------|
| 1.1 | teacher_material_screen.dart | 172 | ✅ TeacherPageHeader |
| 1.2 | teacher_schedule_screen.dart | 329 | ✅ TeacherPageHeader + ActiveFilterChips |
| 1.3 | teacher_attendance_screen.dart | 350 | ✅ TeacherPageHeader |
| 1.4 | admin_lesson_plan_screen.dart | 360 | partial (custom admin header) |
| 1.5 | add_activity_dialog.dart | 403 | ❌ (no FormFieldSection yet) |
| 1.6 | admin_teacher_management_screen.dart | 320 | ✅ PaginatedListView |
| 1.7 | admin_attendance_report_screen.dart | 372 | partial |
| 1.8 | teacher_grade_recap_screen.dart | 390 | partial |

---

## Phase 2 — Large Screens: ✅ ALL UNDER 400 LINES

All 19 files (grade_book_screen, admin_schedule_management, class_promotion_wizard, schedule_form_dialog, teacher_lesson_plan_screen, lesson_plan_detail_screen, admin_finance_screen, admin_classroom_management_screen, admin_class_activity_screen, parent_announcement_screen, sub_chapter_detail_screen, teacher_class_activity_screen, admin_subject_management_screen, parent_attendance_screen, admin_announcement_screen, day_session_management_sheet, generate_lesson_plan_form_dialog, admin_report_card_screen, parent_class_activity_screen) are under 400 lines.

---

## Phase 3 — Medium Files: ✅ ALL UNDER TARGETS

All Phase 3 screens, controllers, and services are under their target line counts (400 for screens, 500 for controllers/services).

---

## Phase 4 — Architectural Improvements

### 4.1 Eliminate `part` file usage
**Status:** ⚠️ PARTIAL (investigated, most deferred)
- Generated `.g.dart` / `.freezed.dart` part files: ✅ expected, keep as-is
- Non-generated `part` directives remain in `language_utils_*` (7 files) and `color_utils_mappings.dart`
- Both cannot be safely converted due to private cross-references (`_k` constants, `_adjustColor()`)
- **Recommendation:** Leave as-is; convert only if refactoring the underlying utilities

### 4.2 Replace `Map<String, dynamic>` with typed models
**Status:** ⚠️ FOUNDATION LAID
- 11 @freezed models now exist: Student, Attendance, AttendanceSummary, User, TeacherGradeState, ParentFinanceState, **Teacher**, **Classroom**, **LessonPlan**, **Subject**, **Schedule (new)**
- `Schedule` model normalizes Indonesian ↔ English keys across the full timetable shape (`mata_pelajaran_id/nama` → `subject_id/name`, `kelas_id/nama` → `class_id/name`, `guru_id/nama` → `teacher_id/name`, `hari_id/nama` → `day_id/name`, `jam_ke`/`hour_number` → `lesson_hour`, `jam_pelajaran_id` → `lesson_hour_id`, `jam_mulai`/`jam_selesai` → `start_time`/`end_time`) and collapses nested `day`/`hari` Maps (with `name`/`nama`) and `semester` (Map or String) into flat fields
- **Adopted internally in (24 files):** `schedule_card_data_mixin.dart` (5 fallback chains collapsed), `admin_schedule_card.dart` (subject/teacher/class name), `schedule_export_service.dart` (validateScheduleData — ~50 lines collapsed), `schedule_table_navigation_mixin.dart` (13 Map accesses → 3 model reads), `grid_timetable_mixin.dart` (7 accesses: _extractDayIds, _createGridItem, _formatTimeSlot), `schedule_filtering_mixin.dart` (partial — _extractScheduleNames, _matchesTeacher, _matchesClass; `_matchesLessonHour` deliberately skipped — nested Map), `schedule_card_header.dart` (hour box, subject/class/time rows, semester check), `schedule_detail_dialog.dart` (4 ScheduleDetailItem values + header subtitle), `schedule_card_summary_sheet.dart` (dayName/startTime/endTime/subjectName/className), `conflict_resolution_dialog.dart` (subject/teacher/class/time display), `session_action_buttons_mixin.dart` (subjectName/className), `schedule_table_data_mixin.dart` (classId/subjectId/dayId), `schedule_table_session_row_mixin.dart` (lessonHour/startTime/endTime), `schedule_table_day_helpers_mixin.dart` (dayId/dayName in resolveDayName), `schedule_table_time_helpers_mixin.dart` (startTime/endTime in 4 methods), `formatting_filtering_mixin.dart` (formatTime + formatScheduleDays fallbacks), `schedule_card_attendance_detail.dart` (dayName/lessonHour/startTime/endTime), `schedule_timing_mixin.dart` (getDayNameFromSchedule/isHourPastCheck/isHourCurrentCheck/startTimeMinutesValue), `schedule_card_action_mixin.dart` (lessonHour for attendance dialog), `teacher_schedule_filter_helper.dart` (extractDayIds fallback + search/class/sort fields), `schedule_form_dialog.dart` (teacher/subject/class/day/lessonHour IDs in edit form), `excel_import_export_mixin.dart` (dayId for enrichment)
- **Deliberately not migrated:** `_matchesLessonHour` in schedule_filtering_mixin (schedule['lesson_hour'] is a nested Map, not a flat int); `days_ids` polymorphic List/String branches (kept as raw Map access); `semester_id`/`academic_year_id` form fields (not in Schedule model, separate domain); data service layer files (schedule_service, schedule_conflict_service, etc. — operate on API payloads directly)
- `Subject` model normalizes Indonesian ↔ English keys (`nama`/`name`, `kode`/`code`, `jumlah_kelas`/`class_count`, `kelas_names`/`class_names`) + bool/int/string coercion for `is_active` and `class_count`; has `initial` and `classNameList` helper getters
- **Adopted internally in (24 files):** `subject_card.dart` (6 Map accesses), `subject_actions_mixin.dart` (3), `subject_class_ui_mixin.dart` (1, via `_resolveSubjectName` helper), `subject_class_management_page.dart` (3, via `_subjectName` helper and typed `getSubjectId`), `subject_export_service.dart` (validateSubjectData — id/code/name/class_names via model), `subject_data_helper.dart` (extractFilterOptions + loadMoreSubjects use `model.classNameList`), `subject_filter_helper.dart` (getFilteredSubjects — name/code/classCount/classNameList), `attendance_filter_ui_mixin.dart` (buildSubjectChips), `attendance_filter_helper.dart` (subject chip label), `teacher_form_builders_mixin.dart` (_buildSubjectCheckboxes + _toggleSubject), `schedule_subject_dropdown.dart` (dropdown id/name), `admin_subject_card.dart` (class_activity drill-down name), `class_activity_navigation_mixin.dart` (getFilteredSubjects name search), `attendance_input_form.dart` (subject dropdown), `lesson_plan_form_dialog.dart` (subject dropdown), `generate_lesson_plan_form_dialog.dart` (subject dropdown), `material_ui_helpers_mixin.dart` (getSelectedSubjectName), `subject_row_widget.dart` (name/code), `grade_book_screen.dart` (subtitle subject name), `grade_input_form.dart` (subject detail item), `grade_input_ui_builder_mixin.dart` (form header subject name), `grade_recap_dialog_mixin.dart` (initialSubject Map), `teacher_grade_input_screen.dart` (openGradeBook subject Map), `grade_recap_content_mixin.dart` (buildSubjectRow name)
- **Deliberately not migrated:** `schedule_form_mixin.dart` + `activity_data_loading_mixin.dart` use only id comparisons (low ROI)
- `LessonPlan` model normalizes Indonesian ↔ English keys (`judul`/`title`, `mata_pelajaran_nama`/`subject_name`, `kelas_nama`/`class_name`, `guru_nama`/`teacher_name`, `tahun_ajaran`/`academic_year`, `catatan`/`notes`, `catatan_admin`/`admin_notes`) plus nested `teacher.name`; has `createdAtDate`, `hasAdminNotes`, `hasNotes` getters
- **Adopted internally in (16 files):** `card_builders_mixin.dart` (11 Map accesses → typed model), `lesson_plan_admin_card.dart` (8 Map accesses), `lesson_plan_card.dart` (3), `header_builder_mixin.dart` (2), `dialog_management_mixin.dart` (3), `lesson_plan_crud_mixin.dart` (delete confirmation title), `admin_lesson_plan_screen.dart` (search filter — title/subjectName/teacherName/className), `lesson_plan_export_mixin.dart` (PDF/TXT filename), `lesson_plan_ai_result_data_mixin.dart` (title/subjectName init), `generate_lesson_plan_form_mixin.dart` (subjectName/className from API response), `lesson_plan_helpers_mixin.dart` (getDisplayTitle via model), `lesson_plan_admin_detail_page.dart` (status), `teacher_lesson_plan_screen.dart` (status), `lesson_plan_export_service.dart` (validation via model — title/subjectName/className/teacherName/semester/academicYear/status/createdAt), `lesson_plan_header_info_card.dart` (title/subjectName/className/semester/academicYear/teacherName/status via model), `lesson_plan_form_dialog.dart` (title/academicYear/semester via model in edit initState)
- `Classroom` model normalizes `homeroom_teacher` and `wali_kelas` (both as Map/List/flat) + Indonesian keys (`nama`, `tingkat`, `jumlah_siswa`, `wali_kelas_nama`, `wali_kelas_name`) + `student_count` as int/string; has `hasHomeroomTeacher` getter
- **Adopted internally in (23 files):** `class_detail_dialog.dart`, `classroom_card.dart`, `grade_recap_class_card.dart`, `classroom_export_service.dart` (validateClassData — collapsed 10-line polymorphic homeroom_teacher block into `model.homeroomTeacherName`), `classroom_action_mixin.dart` (`_ensureHomeroomTeacherInList` — collapsed 10-line List/Map/flat fallback into model), `classroom_add_edit_sheet.dart` (initState — collapsed 15-line name/gradeLevel/homeroom fallback chain into 3 model getters), `subject_class_ui_builder_mixin.dart` (buildClassInfo — name/gradeLevel/homeroomTeacherName), `subject_class_filter_mixin.dart` (getFilteredClasses — name/gradeLevel/homeroomTeacherName + id), `subject_class_actions_mixin.dart` (quick-add list tile title/subtitle), `attendance_filter_helper.dart` (class chip label), `schedule_class_dropdown.dart` (dropdown id/name), `attendance_report_filter_sheet.dart` (class chip grid), `attendance_class_list_view.dart` (class name/gradeLevel), `class_report_tab.dart` (class card name/studentCount + navigation), `attendance_input_form.dart` (class dropdown), `teacher_filter_sections.dart` (class dropdown), `subject_class_data_mixin.dart` (add/remove confirmation messages), `student_filter_sheet_filters_mixin.dart` (class filter chips), `student_detail_ui_builder_mixin.dart` (class history name), `finance ui_builder_mixin.dart` (class title), `subject_class_management_page.dart` (remove confirmation), `lesson_plan_form_dialog.dart` (class dropdown), `subject_export_service.dart` (class name list join)
- Classroom model `_standardizeJson` extended with `homeroom_teacher_id` ← `wali_kelas_id` flat fallback (to preserve the pre-existing behaviour in classroom_add_edit_sheet)
- `Teacher` model handles nested `user`, List/Map `homeroom_class`, Indonesian ↔ English keys (incl. `nip`/`nuptk`/`nomor_induk` → `employee_number`), with `initials` and `isHomeroomTeacher` getters
- **Adopted internally in (38 files):** `teacher_card.dart`, `teacher_detail_card_builders_mixin.dart`, `teacher_detail_ui_builders_mixin.dart`, `teacher_detail_screen.dart`, `admin_teacher_card.dart`, `teacher_select_card.dart`, `teacher_selection_sheet.dart`, `schedule_teacher_dropdown.dart`, `promotion_homeroom_teacher_dropdown.dart`, `classroom_form_fields.dart`, `material_navigation_mixin.dart`, `teacher_attendance_screen.dart`, `attendance_data_mixin.dart`, `attendance_state_mixin.dart`, `class_activity_navigation_mixin.dart`, `teacher_form_init_mixin.dart`, `grade_book_controller.dart` (id/role), `teacher_grade_controller.dart` (id/role), `teacher_grade_state.dart` (hashCode/equals), `grade_input_form_mixin.dart` (teacher_id), `grade_form_submission_mixin.dart` (teacher_id), `grade_form_data_mixin.dart` (role color), `teacher_grade_recap_screen.dart` (role color), `teacher_attendance_detail_actions_mixin.dart` (teacherId param), `attendance_input_mixin.dart` (teacher id), `teacher_attendance_detail.dart` (teacherId param), `material_data_mixin.dart` (cache keys + subject load), `material_progress_mixin.dart` (progress save/load), `material_resolve_mixin.dart` (getSubjectsForClass), `material_chapter_mixin.dart` (cache key), `material_data_load_mixin.dart` (loadData), `data_loading_mixin.dart` (recommendation teacher id), `recommendation_class_screen.dart` (role color), `result_navigation_mixin.dart` (role color), `teacher_report_card_screen.dart` (id/role), `teacher_crud_mixin.dart` (delete id), `result_fetch_mixin.dart` (teacher_id → model.id via teacher_id alias), `teacher_report_card_overview.dart` (teacher_id → model.id via teacher_id alias)
- **Deliberately not migrated:** `teacher_detail_ui_helpers_mixin.dart` (plural `homeroom_classes` list logic exceeds current model scope), `teacher_provider.dart` (`userData['nama']` is a User map, not Teacher), `edit_form_state_mixin.dart` + `header_mixin.dart` (typed as `Map<String, String>`, not `Map<String, dynamic>`)
- `Student` model extended with `gender`, `dateOfBirth`, `guardianEmail` optional fields; `initials` getter; `_standardizeJson` now normalizes `nis`/`nisn` → `student_number`, `jenis_kelamin` → `gender`, `tanggal_lahir`/`tgl_lahir` → `date_of_birth`, `parent_email`/`email_wali` → `guardian_email`, and `student_name` (report-card APIs) → `name`
- **Adopted internally in:** `student_card.dart`, `student_detail_screen.dart`, `student_detail_ui_builder_mixin.dart` (buildPersonalInfoCard / buildParentInfoCard / buildProfileHeaderCard — 10 Map accesses replaced), `promotion_student_selection_sheet.dart`, `class_promotion_step4_summary.dart`, `parent_student_selector.dart` (class_activity dropdown), `parent_grade_student_selector.dart`, `add_activity_student_selector.dart` (collapsed name/nama + student_number/nis fallback chains), `class_finance_table.dart` (name/student_number cell + id lookup), `ui_builder_mixin.dart` (finance search filter), `student_ui_builder_mixin.dart` (finance student name/NIS builders), `dialog_mixin.dart` (dashboard child picker — uses `model.initials`), `student_list_mixin.dart` (recommendations list — avatar/name/NIS), `student_list_mixin.dart` (report_cards list — name/NIS/studentClassId), `admin_report_card_body.dart` (admin list — initials/name/NIS), `admin_report_card_actions_mixin.dart` (raport detail navigation + PDF download — name/NIS), `teacher_report_card_export_mixin.dart` (teacher PDF download — name), `recommendation_result_screen.dart` (header name), `result_fetch_mixin.dart` (recommendations cache key + fetch — collapsed student_id/id chain into `model.id`), `parent_grade_data_loading_mixin.dart` (filter by guardianEmail/guardianName/id), `parent_activity_data_loading_mixin.dart` (same filter logic), `admin_student_management_screen.dart` (gender extraction), `student_export_service.dart` (Excel export rows — 9 fields via model)
- **Student model extension (this session):** `_standardizeJson` now also falls back `id` ← `student_id` for recommendation APIs
- `Announcement` model converted from plain Dart class to Freezed with `_standardizeJson` normalizing: `judul` → `title`, `isi`/`konten` → `content`, `kategori` → `category`, `tanggal`/`date` → `created_at`, and `is_read` collapsed from `null`/`true`/`false`/`1`/`0`/`'1'`/`'0'` into a proper `bool` (default `true` — matches existing "null = already read" UI semantics)
- **Adopted internally in:** `read_tracking_mixin.dart` + `admin_read_tracking_mixin.dart` (collapsed 5-line `isRead` fallback chain into `!model.isRead`), `announcement_card.dart` (title/content/isUnread via model), `announcement_card_mixin.dart` (_isUnread + card content), `announcement_detail_dialog.dart` (header title/date + content body), `announcement_form_sheet.dart` (edit-form initial values), `ui_interaction_mixin.dart` (search filter title/content)

### 4.3 Standardize state management
**Status:** ⚠️ IN PROGRESS
- Riverpod (StateNotifier / AsyncNotifier) is the default for new features
- `LanguageProvider` still uses `ChangeNotifierProvider` — migration to Riverpod `Notifier` is invasive (touches localization calls in virtually every screen) and deferred
- Many screens use mixins for state instead of Riverpod controllers — acceptable where the state is UI-only

### 4.4 Deprecate unused widgets
**Status:** ✅ MOSTLY DONE
- 29 dead widget files deleted across sessions (teacher details, attendance, grade_recap subwidgets, material quiz cards, etc.)
- `EnhancedSearchBar` retained due to 1 usage in `subject_class_management_page.dart`
- Multiple attendance stat card variants consolidated into `StatSummaryCard`

### 4.5 Extract common screen patterns
**Status:** ❌ NOT DONE
- Generic `AdminManagementScreen<T>` / `DetailScreen<T>` not created
- Admin screens remain structurally heterogeneous; extraction risk > reward at this point

---

## Phase 5 — Code Quality & Cleanup

### 5.1 Remove dead code — ✅ MOSTLY DONE
- 34 + 29 = 63 dead widget/utility files removed (~6,000+ lines)
- No `// ignore: unused_field` annotations remain
- `dart fix --apply` run (17 fixes + 2,224 prior fixes)

### 5.2 Apply consistent naming — ⚠️ NOT AUDITED IN DETAIL

### 5.3 Documentation cleanup — ⚠️ NOT AUDITED IN DETAIL

### 5.4 Format and lint — ✅ DONE
- `analysis_options.yaml` configured (page_width 80, prefer_const_constructors, prefer_final_locals, avoid_print, 400-line file cap)
- `dart format` run across 558 files
- Code quality check script at `/tool/code_quality_check.dart`

---

## Overall Completion Summary

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 0 | Shared Components — BUILT | ✅ 20/20 |
| Phase 0 | Shared Components — ADOPTED | ✅ 16 fully adopted, 3 partial, 2 unused (AppDataTable, HomeroomClassSelector) |
| Phase 1 | Critical Screen Splitting | ✅ All under 400 lines |
| Phase 1 | Shared Component Migration | ⚠️ 3/8 fully migrated, 5/8 partial |
| Phase 2 | Large Screen Splitting | ✅ All 19 under 400 lines |
| Phase 3 | Medium Files | ✅ All under target |
| Phase 4.1 | Part file elimination | ⚠️ Deferred (private cross-refs) |
| Phase 4.2 | Typed models | ⚠️ 11 Freezed models created + adopted (Teacher 38 files, Schedule 25, Subject 24, Classroom 23, Student 22, LessonPlan 16, Announcement 6, + Attendance/AttendanceSummary/User/TeacherGradeState/ParentFinanceState) |
| Phase 4.3 | State management | ⚠️ Riverpod default; LanguageProvider deferred |
| Phase 4.4 | Dead widget cleanup | ✅ 63 files deleted |
| Phase 4.5 | Generic screen patterns | ❌ Not started |
| Phase 5.1 | Dead code | ✅ Done |
| Phase 5.4 | Format + lint | ✅ Done |
| Phase 5.2 / 5.3 | Naming / docs audit | ⚠️ Pending |

### Pre-existing Test Failures (37 failures, 17 files — deferred)
These test files were already broken before the Freezed model widening work. All failures are in widget/navigation tests unrelated to model adoption. To be fixed in a dedicated test-fix session.

1. `test/core/router/app_navigator_test.dart`
2. `test/core/widgets/confirmation_dialog_test.dart`
3. `test/features/attendance/presentation/widgets/attendance_quick_status_button_test.dart`
4. `test/features/attendance/presentation/widgets/parent_attendance_info_tag_test.dart`
5. `test/features/attendance/presentation/widgets/parent_attendance_stat_item_test.dart`
6. `test/features/class_activity/presentation/widgets/activity_detail_row_test.dart`
7. `test/features/class_activity/presentation/widgets/activity_empty_state_test.dart`
8. `test/features/class_activity/presentation/widgets/activity_type_option_tile_test.dart`
9. `test/features/classrooms/presentation/widgets/classroom_card_test.dart`
10. `test/features/dashboard/presentation/admin_dashboard_navigation_test.dart`
11. `test/features/grades/presentation/widgets/grade_recap_app_bar_test.dart`
12. `test/features/grades/presentation/widgets/grade_recap_class_list_test.dart`
13. `test/features/grades/presentation/widgets/grade_recap_editable_cell_test.dart`
14. `test/features/grades/presentation/widgets/grade_recap_info_tag_test.dart`
15. `test/features/grades/presentation/widgets/grade_recap_subject_list_test.dart`
16. `test/features/recommendations/presentation/widgets/recommendation_material_item_test.dart`
17. `test/features/schedule/presentation/widgets/schedule_card_item_test.dart`

### Remaining High-Value Work
1. **Widen existing Freezed model adoption** — gap-audit Teacher, Classroom, LessonPlan, Student for any remaining raw `Map<String, dynamic>` accesses that could use the model
2. **Fix 37 pre-existing test failures** — see list above
3. **Migrate `LanguageProvider` to Riverpod `Notifier`** (touches many files; plan carefully before starting)
4. **Close remaining Phase 0 gaps**: PaginatedListView in admin_finance_screen/admin_attendance_report_screen (0.11 — dual-tab/dual-view pagination, complex), FormFieldSection (0.12 — **assessed: visual mismatch** — all dialogs use inline-label `labelText` style, FormFieldSection uses label-above; would require either a new `FormFieldSection.inline()` variant or design approval to change the UX)
5. **Phase 5.2/5.3** — naming and docs audit (not yet started)
6. **Leave alone:** AppDataTable (0 adoption, low ROI), HomeroomClassSelector (0 adoption, niche), non-generated part files (private cross-refs), Phase 4.5 generic screen extraction (risk > reward)
