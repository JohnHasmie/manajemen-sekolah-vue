# Kamiledu Flutter App — Comprehensive Refactoring Plan

## Codebase Summary

| Metric | Current | Target |
|--------|---------|--------|
| Total Dart files (non-generated) | 429 | ~600–650 (more, smaller files) |
| Total lines of code | 136,003 | ~105,000 (less duplication) |
| Files over 500 lines | 60+ | 0 |
| Files over 1,000 lines | 35 | 0 |
| Largest file | 2,161 lines | < 500 lines |
| Average method length | 60–150 lines | < 40 lines |
| Shared core widgets | 11 (some unused) | ~35 (all actively used) |
| New shared widgets built | 20 of ~25 done | all done |
| Duplicated UI patterns | 17 major patterns | 0 (all in shared library) |

---

## Phase 0 — Shared Design System & Component Library — Priority: 🔴 HIGHEST

> **Do this FIRST.** Building shared components before splitting screens means every
> refactored screen immediately uses the shared library instead of just moving
> duplication from one file to another.

All new components live in `lib/core/widgets/` and are imported by feature screens.

### Existing Core Widgets (audit & enhance)
| Widget | File | Status |
|--------|------|--------|
| `GradientPageHeader` | `gradient_page_header.dart` | ✅ Exists — only used by admin screens, needs enhancement |
| `EnhancedSearchBar` | `enhanced_search_bar.dart` | ⚠️ Exists — **NOT USED by any screen** |
| `EmptyState` | `empty_state.dart` | ✅ Exists — used inconsistently |
| `SkeletonListLoading` | `skeleton_loading.dart` | ✅ Exists — used inconsistently |
| `TabSwitcher` | `tab_switcher.dart` | ✅ Exists — limited usage |
| `ConfirmationDialog` | `confirmation_dialog.dart` | ✅ Exists |
| `ModernDatePicker` | `modern_date_picker.dart` | ✅ Exists |
| `ErrorHandler` | `error_handler.dart` | ✅ Exists |
| `ErrorScreen` | `error_screen.dart` | ✅ Exists |
| `LoadingScreen` | `loading_screen.dart` | ✅ Exists |

---

### 0.1 `RoleToggle` — Homeroom/Teaching View Switcher
**File:** `lib/core/widgets/role_toggle.dart`
**Duplicated in:** 5+ screens (attendance, schedule, grades, class activity, materials)
**Current duplication:** ~30 lines × 5 = ~150 lines of identical code

```dart
/// Animated toggle switch for Teaching ↔ Homeroom (Wali Kelas) view.
/// Replaces 5+ identical `_buildRoleToggle()` implementations.
class RoleToggle extends StatelessWidget {
  final bool isHomeroomView;
  final ValueChanged<bool> onChanged;
  final Color primaryColor;
  final String? homeroomClassName;  // Shows "Kelas 10A" instead of generic label
  final String teachingLabel;       // Default: 'Mengajar' / 'Teaching'
  final String homeroomLabel;       // Default: 'Wali Kelas' / 'Homeroom'
}
```

**Screens to migrate:**
- [ ] `teacher_attendance_screen.dart` → `_buildRoleToggle()` (lines ~1056–1082)
- [ ] `teacher_schedule_screen.dart` → `_buildRoleToggle()` (lines ~1046–1058)
- [ ] `teacher_class_activity_screen.dart` → `_buildRoleToggle()` (lines ~898–920)
- [ ] `teacher_grade_input_screen.dart` → `_buildRoleToggle()` (lines ~207–220)
- [ ] `teacher_grade_recap_overview.dart` → `_buildRoleToggle()` (lines ~138–149)

---

### 0.2 `SearchFilterBar` — Search Input + Filter Button Combo
**File:** `lib/core/widgets/search_filter_bar.dart`
**Duplicated in:** 8+ screens
**Current duplication:** ~30 lines × 8 = ~240 lines of identical code

```dart
/// Search text field with adjacent filter icon button.
/// Used inside gradient headers on a semi-transparent background.
/// Replaces 8+ identical search + filter Row() implementations.
class SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilter;      // Shows badge dot on filter icon
  final bool transparentStyle;     // true = white/alpha (in headers), false = solid white (in body)
  final Color? primaryColor;
}
```

**Also:** Enhance existing `EnhancedSearchBar` to support the transparent header variant, OR deprecate it in favor of `SearchFilterBar`.

**Screens to migrate:**
- [ ] `teacher_attendance_screen.dart` → search + filter Row (lines ~988–1008)
- [ ] `teacher_schedule_screen.dart` → search + filter Row
- [ ] `teacher_grade_input_screen.dart` → search + filter Row (lines ~169–202)
- [ ] `teacher_grade_recap_overview.dart` → search + filter Row (lines ~152–181)
- [ ] `teacher_material_screen.dart` → search + filter Row
- [ ] `teacher_class_activity_screen.dart` → search + filter Row
- [ ] `admin_teacher_management_screen.dart` → search + filter Row
- [ ] `admin_student_management_screen.dart` → search + filter Row

---

### 0.3 `ActiveFilterChips` — Dismissible Filter Tag Row
**File:** `lib/core/widgets/active_filter_chips.dart`
**Duplicated in:** 8+ screens
**Current duplication:** ~60 lines × 8 = ~480 lines of identical code

```dart
/// Horizontal scrollable row of active filter chips with remove buttons.
/// Replaces 8+ identical `_buildFilterChips()` / `_buildFilterTag()` methods.
class ActiveFilterChips extends StatelessWidget {
  final List<ActiveFilter> filters;    // List of currently active filters
  final VoidCallback? onClearAll;      // Optional "Clear all" button
  final EdgeInsets? padding;
}

/// Data model for a single active filter chip.
class ActiveFilter {
  final String label;                  // e.g., "Semester: 1", "Day: Monday"
  final VoidCallback onRemove;         // Callback to remove this filter
  final Color? color;                  // Optional chip color
  final IconData? icon;                // Optional leading icon
}
```

**Screens to migrate:**
- [ ] `teacher_schedule_screen.dart` → filter chips (lines ~626–703)
- [ ] `teacher_attendance_screen.dart` → `_buildFilterTag()` (lines ~1028–1030)
- [ ] `teacher_grade_input_screen.dart` → `_buildFilterChips()` (lines ~234–260)
- [ ] `teacher_grade_recap_overview.dart` → `_buildFilterChips()` (lines ~195–207)
- [ ] `parent_attendance_screen.dart` → filter chips (lines ~765–829)
- [ ] `admin_attendance_report_screen.dart` → filter chips
- [ ] `admin_schedule_management_screen.dart` → filter chips
- [ ] `admin_finance_screen.dart` → filter chips

---

### 0.4 `FilterBottomSheet` — Reusable Filter Sheet Scaffold
**File:** `lib/core/widgets/filter_bottom_sheet.dart`
**Duplicated in:** 6+ dedicated filter sheet files + 10+ inline `showModalBottomSheet` calls
**Current duplication:** ~150 lines × 6 = ~900 lines of identical structure

```dart
/// Base scaffold for filter bottom sheets with header, scrollable content,
/// and Apply/Reset footer buttons.
/// Replaces identical structure in 6+ filter sheet files.
class FilterBottomSheet extends StatelessWidget {
  final String title;
  final Widget content;               // The filter options (chips, dropdowns, etc.)
  final VoidCallback onApply;
  final VoidCallback onReset;
  final Color? primaryColor;
  final double? maxHeightFactor;       // Default: 0.7 of screen height
}

/// Helper to show a FilterBottomSheet with consistent styling.
Future<void> showFilterSheet({
  required BuildContext context,
  required String title,
  required Widget content,
  required VoidCallback onApply,
  required VoidCallback onReset,
  Color? primaryColor,
});
```

**Filter sheets to migrate:**
- [ ] `attendance_filter_sheet.dart` → use `FilterBottomSheet` as scaffold
- [ ] `attendance_report_filter_sheet.dart` → use `FilterBottomSheet` as scaffold
- [ ] `schedule_filter_sheet.dart` → use `FilterBottomSheet` as scaffold
- [ ] `teacher_schedule_filter_sheet.dart` → use `FilterBottomSheet` as scaffold
- [ ] `announcement_filter_sheet.dart` → use `FilterBottomSheet` as scaffold
- [ ] `grade_filter_dialog.dart` → use `FilterBottomSheet` as scaffold
- [ ] All inline `showModalBottomSheet(...)` filter calls in screens

---

### 0.5 `FilterChipGrid` — Selectable Chip Options Grid
**File:** `lib/core/widgets/filter_chip_grid.dart`
**Duplicated in:** Every filter sheet builds FilterChip grids identically
**Current duplication:** ~25 lines × 15+ instances = ~375 lines

```dart
/// A Wrap of FilterChips for selecting one or multiple options.
/// Used inside FilterBottomSheet for each filter category.
class FilterChipGrid<T> extends StatelessWidget {
  final List<FilterOption<T>> options;
  final T? selectedValue;              // Single select
  final Set<T>? selectedValues;        // Multi select
  final ValueChanged<T> onSelected;
  final Color? selectedColor;
  final bool multiSelect;              // Default: false
}

/// Data model for a single filter option.
class FilterOption<T> {
  final T value;
  final String label;
  final int? count;                    // Optional badge count
  final IconData? icon;
}
```

**Usages to migrate (inside filter sheets):**
- [x] Status filters (Hadir/Sakit/Izin/Alpha) — migrated in filter_content_mixin.dart
- [x] Day filters (Senin/Selasa/.../Jumat) — migrated in attendance_filter_ui_mixin.dart
- [ ] Semester filters (1/2)
- [x] Class filters (10A/10B/11A/...) — migrated in filter_dialog_content.dart
- [ ] Category filters (announcement types)
- [x] Subject filters — migrated in filter_dialog_content.dart & attendance_filter_ui_mixin.dart

---

### 0.6 `StatusBadge` — Colored Status Label
**File:** `lib/core/widgets/status_badge.dart`
**Duplicated in:** Attendance screens, lesson plan screens, report card screens, grade screens
**Current duplication:** ~12 lines × 20+ instances = ~240 lines

```dart
/// Small colored badge showing a status label (e.g., "Hadir", "Pending", "Approved").
/// Replaces 20+ identical Container + Text + decoration patterns.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;              // Default: 10
  final EdgeInsets? padding;
  final IconData? icon;               // Optional leading icon

  /// Named constructors for common statuses:
  const StatusBadge.hadir({...});     // Green
  const StatusBadge.sakit({...});     // Orange
  const StatusBadge.izin({...});      // Blue
  const StatusBadge.alpha({...});     // Red
  const StatusBadge.pending({...});   // Yellow
  const StatusBadge.approved({...});  // Green
  const StatusBadge.rejected({...});  // Red
}
```

**Screens to migrate:**
- [ ] `attendance_student_item.dart` → status containers (lines ~141–157)
- [ ] `attendance_input_mode.dart` → status badges
- [ ] `attendance_results_mode.dart` → status badges
- [ ] `admin_attendance_report_screen.dart` → status badges
- [ ] `parent_attendance_screen.dart` → status badges
- [ ] `lesson_plan_detail_screen.dart` → approval status badges
- [ ] `admin_lesson_plan_screen.dart` → status badges
- [x] `admin_report_card_screen.dart` → status badges — migrated in report_card_status_badge.dart replaced with StatusBadge
- [x] `descriptive_builder_mixin.dart` → status badges — migrated
- [x] `teacher_attendance_detail_card_mixin.dart` → status badges — migrated
- [x] `student_list_mixin.dart` → status badges (report cards) — migrated
- [x] `report_card_header.dart` → status badges — migrated
- [x] `bill_status_cell.dart` → status badges (finance) — migrated
- [x] `lesson_plans/card_builders_mixin.dart` → buildStatusBadge + buildStatusDot collapsed into StatusBadge
- [x] `finance/pending_payment_card.dart` → "Menunggu" inline pill replaced with StatusBadge
- [x] `subjects/subject_class_ui_builder_mixin.dart` → buildStatusIndicator (Terdaftar/Tambahkan) replaced with StatusBadge
- [x] `attendance/admin_attendance_summary_card.dart` → inline info tags replaced with StatusBadge (3 replacements)
- [x] `attendance/parent_attendance_item.dart` → inline tags replaced with StatusBadge (3 replacements); `parent_attendance_info_tag.dart` deleted as dead file
- [x] `lesson_plans/lesson_plan_admin_card.dart` → `_buildInfoTag()` helper removed, calls replaced with StatusBadge (2 replacements)

---

### 0.7 `StatSummaryCard` — Metric Card with Icon
**File:** `lib/core/widgets/stat_summary_card.dart`
**Duplicated in:** Dashboard, attendance reports, finance, grade recaps
**Current duplication:** ~40 lines × 8+ instances = ~320 lines

```dart
/// A card displaying a single statistic with icon, value, and label.
/// Used in summary rows at the top of management/report screens.
class StatSummaryCard extends StatelessWidget {
  final String label;
  final String value;                  // e.g., "156", "92%"
  final IconData icon;
  final Color color;
  final String? subtitle;             // Optional secondary text
  final VoidCallback? onTap;
  final double? width;                // Fixed width or Expanded
}

/// A horizontal row of StatSummaryCards with equal spacing.
class StatSummaryRow extends StatelessWidget {
  final List<StatSummaryCard> cards;
  final EdgeInsets? padding;
  final double spacing;               // Default: AppSpacing.md
}
```

**Screens to migrate:**
- [ ] `dashboard_screen.dart` → summary cards
- [x] `admin_attendance_report_screen.dart` → stat cards — migrated in admin_detail_ui_stats_mixin.dart
- [x] `admin_finance_screen.dart` → finance summary cards — migrated in finance_dashboard_stats.dart
- [ ] `teacher_grade_recap_screen.dart` → grade summary cards
- [ ] `attendance_summary_card.dart` → consolidate with this
- [ ] `attendance_stat_card.dart` → replace with this
- [x] `parent_attendance_monthly_summary.dart` → 5 attendance stat items — migrated
- [x] `quiz_stats_bar.dart` → materials stats — migrated

---

### 0.8 `AppDataTable` — Scrollable Data Table
**File:** `lib/core/widgets/app_data_table.dart`
**Duplicated in:** Grade book, attendance reports, schedule table, finance reports
**Current duplication:** ~100 lines × 5+ instances = ~500 lines

```dart
/// A horizontally scrollable data table with sticky header, alternating
/// row colors, and optional sorting.
/// Replaces 5+ custom SingleChildScrollView + Column table implementations.
class AppDataTable extends StatelessWidget {
  final List<AppTableColumn> columns;
  final List<List<Widget>> rows;       // Each inner list = one row's cells
  final Color? headerColor;            // Default: primaryColor
  final Color? evenRowColor;           // Default: white
  final Color? oddRowColor;            // Default: ColorUtils.slate50
  final ValueChanged<int>? onRowTap;
  final bool stickyHeader;            // Default: true
  final bool showBorder;              // Default: true
  final double? rowHeight;
}

/// Column definition for AppDataTable.
class AppTableColumn {
  final String label;
  final double width;
  final TextAlign align;               // Default: TextAlign.start
  final bool sortable;                 // Default: false
}
```

**Screens to migrate:**
- [ ] `grade_book_screen.dart` → custom table (lines ~500+)
- [ ] `teacher_grade_input_screen.dart` → grade input table (lines ~567–651)
- [ ] `admin_attendance_report_screen.dart` → report table
- [ ] `teacher_schedule_table_view.dart` → schedule grid (829 lines)
- [ ] `class_finance_report_screen.dart` → payment table
- [ ] `report_card_detail_screen.dart` → grades table

---

### 0.9 `SectionHeader` — Section Title with Optional Action
**File:** `lib/core/widgets/section_header.dart`
**Duplicated in:** Almost every screen that has titled sections
**Current duplication:** ~10 lines × 30+ instances = ~300 lines

```dart
/// A section title row with optional trailing action button/link.
/// Replaces repeated Row(children: [Text(title), Spacer(), TextButton(...)]) patterns.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;            // e.g., "View All", "Edit"
  final VoidCallback? onActionTap;
  final IconData? actionIcon;
  final TextStyle? titleStyle;
  final EdgeInsets padding;            // Default: symmetric(horizontal: 16)
}
```

---

### 0.10 `TeacherPageHeader` — Enhanced Gradient Header for Teacher/Parent Screens
**File:** `lib/core/widgets/teacher_page_header.dart`
**Duplicated in:** All teacher and parent screens build custom gradient headers
**Current duplication:** ~80 lines × 10+ screens = ~800 lines

```dart
/// Extended gradient header that adds role toggle, search bar, and filter
/// chips to the base GradientPageHeader.
/// Specifically designed for teacher/parent screens that need the full
/// header experience (back + title + role toggle + search + filters).
class TeacherPageHeader extends StatelessWidget {
  // Base header props (delegates to GradientPageHeader)
  final String title;
  final String subtitle;
  final Color primaryColor;
  final VoidCallback? onBackPressed;
  final Widget? actionMenu;

  // Role toggle props (optional)
  final bool showRoleToggle;
  final bool isHomeroomView;
  final ValueChanged<bool>? onRoleChanged;
  final String? homeroomClassName;
  final bool hasHomeroomClasses;       // Only show toggle if teacher has homeroom

  // Search + filter props (optional)
  final bool showSearchFilter;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilter;

  // Active filter chips (optional)
  final List<ActiveFilter>? activeFilters;
  final VoidCallback? onClearAllFilters;
}
```

**Screens to migrate (replaces entire header sections):**
- [ ] `teacher_attendance_screen.dart` → header section (lines ~953–1082)
- [ ] `teacher_schedule_screen.dart` → header section (lines ~1003–1059)
- [ ] `teacher_grade_input_screen.dart` → header section (lines ~141–260)
- [ ] `teacher_grade_recap_overview.dart` → header section (lines ~119–207)
- [ ] `teacher_class_activity_screen.dart` → header section (lines ~810–935)
- [x] `teacher_material_screen.dart` → header section — migrated in material_build_mixin.dart
- [x] `teacher_lesson_plan_screen.dart` → header section — migrated in lesson_plan_header.dart
- [x] `parent_attendance_screen.dart` → header section
- [x] `parent_announcement_screen.dart` → header section — migrated in header_search_mixin.dart
- [ ] `parent_class_activity_screen.dart` → header section

---

### 0.11 `PaginatedListView` — Infinite Scroll List with Loading Footer
**File:** `lib/core/widgets/paginated_list_view.dart`
**Duplicated in:** Every screen with pagination duplicates scroll listener + loading indicator
**Current duplication:** ~40 lines × 10+ screens = ~400 lines

```dart
/// ListView with built-in scroll-based pagination, loading footer,
/// and empty state handling.
/// Replaces 10+ identical ScrollController + _isLoadingMore + _hasMoreData patterns.
class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;
  final Widget? emptyState;            // Shown when items is empty
  final Widget? loadingState;          // Shown during initial load
  final Widget? separator;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
}
```

**Screens to migrate:**
- [ ] `teacher_attendance_screen.dart` → `_isLoadingMore` + scroll listener
- [ ] `parent_attendance_screen.dart` → pagination logic
- [ ] `parent_announcement_screen.dart` → pagination logic
- [ ] `notification_list_screen.dart` → pagination logic
- [x] `admin_teacher_management_screen.dart` → pagination logic — migrated in teacher_list_content.dart
- [x] `admin_student_management_screen.dart` → pagination logic — migrated
- [x] `announcement_list_content.dart` → pagination logic — migrated in announcement_list_content.dart + admin_announcement_screen.dart

---

### 0.12 `FormFieldSection` — Labeled Form Input
**File:** `lib/core/widgets/form_field_section.dart`
**Duplicated in:** Every form dialog/sheet builds label + input + validation identically
**Current duplication:** ~20 lines × 30+ instances = ~600 lines

```dart
/// A labeled form field with title, optional required marker, and child input.
/// Replaces repeated Column(children: [Text(label), SizedBox, TextField/Dropdown]) patterns.
class FormFieldSection extends StatelessWidget {
  final String label;
  final bool isRequired;               // Shows red asterisk
  final Widget child;                  // TextField, DropdownButtonFormField, DatePicker, etc.
  final String? helperText;
  final String? errorText;
  final EdgeInsets padding;            // Default: bottom: 16
}

/// Pre-built dropdown form field with consistent styling.
class FormDropdownField<T> extends StatelessWidget {
  final String label;
  final bool isRequired;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hintText;
}

/// Pre-built text form field with consistent styling.
class FormTextField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final TextEditingController controller;
  final String? hintText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
}
```

**Forms to migrate:**
- [ ] `add_activity_dialog.dart` (1,473 lines) → form fields
- [ ] `schedule_form_dialog.dart` (1,362 lines) → form fields
- [ ] `teacher_form_dialog.dart` (792 lines) → form fields
- [ ] `student_add_edit_dialog.dart` (678 lines) → form fields
- [ ] `announcement_form_sheet.dart` (818 lines) → form fields
- [ ] `lesson_plan_form_dialog.dart` (940 lines) → form fields
- [ ] `generate_lesson_plan_form_dialog.dart` (1,051 lines) → form fields
- [ ] `payment_type_form_sheet.dart` (704 lines) → form fields

---

### 0.13 `HomeroomClassSelector` — Homeroom Class Dropdown
**File:** `lib/core/widgets/homeroom_class_selector.dart`
**Duplicated in:** Every screen that supports homeroom view has a class picker dropdown
**Current duplication:** ~25 lines × 5+ screens = ~125 lines

```dart
/// Dropdown for selecting which homeroom class to view when teacher
/// has multiple homeroom classes.
/// Shows below the RoleToggle when isHomeroomView is true.
class HomeroomClassSelector extends StatelessWidget {
  final List<Map<String, dynamic>> homeroomClasses;
  final Map<String, dynamic>? selectedClass;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Color? primaryColor;
}
```

---

### 0.14 `ViewToggleButton` — Card/Table/Timeline View Switcher
**File:** `lib/core/widgets/view_toggle_button.dart`
**Duplicated in:** Schedule, attendance, materials, grades screens
**Current duplication:** ~15 lines × 6+ screens = ~90 lines

```dart
/// Small icon button that toggles between view modes (card ↔ table ↔ timeline).
/// Replaces duplicated GestureDetector + Icon patterns in headers.
class ViewToggleButton extends StatelessWidget {
  final ViewMode currentMode;
  final ValueChanged<ViewMode> onChanged;
  final List<ViewMode> availableModes;  // Which modes this screen supports
  final Color? activeColor;
}

enum ViewMode {
  card(icon: Icons.view_agenda_outlined, label: 'Card'),
  table(icon: Icons.table_chart_outlined, label: 'Table'),
  timeline(icon: Icons.timeline_outlined, label: 'Timeline'),
  list(icon: Icons.list_outlined, label: 'List'),
  grid(icon: Icons.grid_view_outlined, label: 'Grid');

  final IconData icon;
  final String label;
  const ViewMode({required this.icon, required this.label});
}
```

---

### 0.15 `ActionConfirmSheet` — Confirmation Bottom Sheet ✅ ADOPTED
**File:** `lib/core/widgets/action_confirm_sheet.dart`
**Duplicated in:** Delete, approve, reject, submit confirmations across screens
**Current duplication:** ~30 lines × 15+ instances = ~450 lines

**Adopted in these files:**
- `student_deletion_helper.dart` 
- `classroom_deletion_helper.dart`
- `teacher_crud_mixin.dart`
- `subject_actions_mixin.dart`
- `lesson_plan_crud_mixin.dart`
- `embedded_activity_delete_mixin.dart`
- `finance_action_mixin.dart` (2 methods)
- `admin_schedule_dialogs_mixin.dart`
- `grade_recap_unsaved_changes_dialog.dart`
- `announcement_delete_dialog.dart`

```dart
/// A confirmation bottom sheet with icon, title, message, and confirm/cancel buttons.
/// Replaces 15+ inline showModalBottomSheet confirmation patterns.
class ActionConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;            // e.g., "Delete", "Approve"
  final String cancelText;             // Default: "Cancel"
  final Color confirmColor;            // Default: Colors.red for destructive
  final IconData icon;
  final VoidCallback onConfirm;
  final bool isDestructive;            // Default: false

  /// Show as bottom sheet helper.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    ...
  });
}
```

---

### Phase 0 Summary — Estimated Impact

| Component | New Lines | Lines Eliminated (duplication) | Screens Affected |
|-----------|-----------|-------------------------------|-----------------|
| `RoleToggle` | ~80 | ~150 | 5+ |
| `SearchFilterBar` | ~100 | ~240 | 8+ |
| `ActiveFilterChips` | ~60 | ~480 | 8+ |
| `FilterBottomSheet` | ~120 | ~900 | 6+ sheets + 10+ inline |
| `FilterChipGrid` | ~70 | ~375 | 15+ instances |
| `StatusBadge` | ~90 | ~240 | 8+ |
| `StatSummaryCard` | ~80 | ~320 | 6+ |
| `AppDataTable` | ~150 | ~500 | 5+ |
| `SectionHeader` | ~40 | ~300 | 30+ |
| `TeacherPageHeader` | ~120 | ~800 | 10+ |
| `PaginatedListView` | ~100 | ~400 | 10+ |
| `FormFieldSection` | ~120 | ~600 | 8+ |
| `HomeroomClassSelector` | ~50 | ~125 | 5+ |
| `ViewToggleButton` | ~60 | ~90 | 6+ |
| `ActionConfirmSheet` | ~80 | ~450 | 15+ |
| `DragHandle` | ~20 | ~200 | 14+ |
| `BottomSheetHeader` | ~70 | ~600 | 20+ |
| `BottomSheetFooter` | ~60 | ~500 | 25+ |
| `AppBottomSheet` | ~100 | ~800 | 40+ |
| `AppAlertDialog` | ~90 | ~500 | 27+ |
| **Totals** | **~1,660 new** | **~8,570 removed** | — |

**Net reduction: ~6,910 lines** of duplicated code, while improving consistency across the entire app.

---

### 0.16 `DragHandle` — Bottom Sheet Drag Indicator ✅ DONE
**File:** `lib/core/widgets/drag_handle.dart`
**Duplicated in:** 14+ bottom sheets with identical Container(width: 40, height: 4, ...) patterns
**Current duplication:** ~14 lines × 14 = ~200 lines

```dart
/// A small pill-shaped drag indicator for bottom sheets.
/// Two variants: default (grey on white) and .onGradient() (white on gradient).
class DragHandle extends StatelessWidget {
  const DragHandle({...});
  const DragHandle.onGradient({...});
}
```

**Screens migrated:**
- [x] `filter_bottom_sheet.dart` → replaced inline drag handle
- [x] `action_confirm_sheet.dart` → replaced inline drag handle
- [x] `activity_type_bottom_sheet.dart` → migrated via AppBottomSheet
- [x] `grade_selection_dialog.dart` → migrated via AppBottomSheet
- [ ] `attendance_filter_sheet.dart` → inline Container
- [ ] `dashboard_account_sheet.dart` → inline Container
- [ ] `modern_date_picker.dart` → inline Container
- [ ] 7+ more feature sheets

---

### 0.17 `BottomSheetHeader` — Gradient Header with Icon & Title ✅ DONE
**File:** `lib/core/widgets/bottom_sheet_header.dart`
**Duplicated in:** 20+ bottom sheets with gradient + icon-box + title + close button
**Current duplication:** ~30 lines × 20 = ~600 lines

```dart
/// Gradient header with icon-in-rounded-box, title, optional subtitle,
/// and close button. Includes DragHandle.onGradient() automatically.
class BottomSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color primaryColor;
  final Widget? trailing;  // e.g., Reset button
}
```

**Screens migrated:**
- [x] `activity_type_bottom_sheet.dart` → migrated via AppBottomSheet
- [x] `grade_selection_dialog.dart` → migrated via AppBottomSheet
- [ ] `attendance_filter_sheet.dart` → `_buildGradientHeader()`
- [ ] `modern_date_picker.dart` → inline gradient header
- [ ] 16+ more feature sheets

---

### 0.18 `BottomSheetFooter` — Cancel/Apply Button Row ✅ DONE
**File:** `lib/core/widgets/bottom_sheet_footer.dart`
**Duplicated in:** 25+ bottom sheets with identical Cancel/Apply button pairs
**Current duplication:** ~20 lines × 25 = ~500 lines

```dart
/// Footer with secondary (outlined) and primary (elevated) buttons.
/// Handles safe-area bottom padding automatically.
class BottomSheetFooter extends StatelessWidget {
  final String primaryLabel;
  final String secondaryLabel;
  final Color primaryColor;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final bool primaryEnabled;
}
```

**Screens migrated:**
- [x] `filter_bottom_sheet.dart` → replaced inline footer
- [x] `grade_selection_dialog.dart` → migrated via AppBottomSheet
- [ ] `attendance_filter_sheet.dart` → `_buildFooter()`
- [ ] 22+ more feature sheets

---

### 0.19 `AppBottomSheet` — Full Bottom Sheet Scaffold ✅ DONE
**File:** `lib/core/widgets/app_bottom_sheet.dart`
**Composes:** `DragHandle` + `BottomSheetHeader` + scrollable content + `BottomSheetFooter`
**Replaces:** 40+ showModalBottomSheet boilerplate patterns

**Adopted in these files:**
- `activity_type_bottom_sheet.dart`
- `grade_column_options_sheet.dart`
- `teacher_selection_sheet.dart`
- `material_generate_sheet.dart`

```dart
/// Full bottom sheet scaffold with static show() helper.
/// Supports gradient header mode and simple (plain) header mode.
class AppBottomSheet extends StatelessWidget {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color primaryColor,
    required Widget content,
    Widget? footer,
    ...
  });
}
```

**Usage — replaces 40+ sheets' boilerplate with one call.**

---

### 0.20 `AppAlertDialog` — Standardized Alert Dialog ✅ DONE
**File:** `lib/core/widgets/app_alert_dialog.dart`
**Duplicated in:** 27+ scattered AlertDialog / showDialog patterns
**Current duplication:** ~20 lines × 27 = ~500 lines

**Adopted in these files:**
- `login_auth_handler_mixin.dart`
- `dialog_mixin.dart` (dashboard)
- `lesson_plan_ai_regeneration_mixin.dart`
- `lesson_plan_ui_mixin.dart`
- `generate_lesson_plan_api_mixin.dart`
- `grade_recap_delete_chapter_dialog.dart`
- `admin_report_card_actions_mixin.dart`
- `grade_recap_unsaved_changes_dialog.dart` + 5 other inline showDialogs

```dart
/// Alert dialog with gradient header, message, and confirm/cancel buttons.
/// Supports info-only mode (showCancel: false) and extra content.
class AppAlertDialog extends StatelessWidget {
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.warning_rounded,
    Color confirmColor = Colors.red,
    ...
  });
}
```

**Screens migrated:**
- [x] `grade_recap_unsaved_changes_dialog.dart` — migrated
- [x] `grade_recap_delete_chapter_dialog.dart` — migrated
- [ ] `attendance_export_dialog.dart` → inline AlertDialog
- [ ] 24+ more inline showDialog calls

---

## Phase 1 — Critical Screens (2,000–1,500 lines) — Priority: 🔴 HIGH

✅ **COMPLETED** — All files in this phase have been split using mixin-based decomposition. All are now under 400 lines.

These are the largest files and should be refactored first. Each file needs to be split into 4–6 smaller files. **Use Phase 0 shared components** wherever possible.

### 1.1 `teacher_material_screen.dart` (2,161 lines)
**Path:** `lib/features/materials/presentation/screens/`
- [ ] Replace custom header → `TeacherPageHeader`
- [ ] Replace search/filter → `SearchFilterBar`
- [ ] Replace filter chips → `ActiveFilterChips`
- [ ] Extract `_MaterialOverviewSection` widget → `material_overview_section.dart`
- [ ] Extract `_SubjectSelectorDropdowns` widget → `material_subject_selector.dart`
- [ ] Extract `_ChapterTreeView` widget → `material_chapter_tree.dart`
- [ ] Extract `_SubChapterCheckboxList` widget → `material_sub_chapter_list.dart`
- [ ] Extract `_AIGenerationControls` widget → `material_ai_generation_controls.dart`
- [ ] Extract `_ProgressTracker` widget → `material_progress_tracker.dart`
- [ ] Move all data-fetching logic → `teacher_material_controller.dart` (new controller)
- [ ] Move search/filter state → `material_filter_state.dart`

### 1.2 `teacher_schedule_screen.dart` (1,571 lines)
**Path:** `lib/features/schedule/presentation/screens/`
- [ ] Replace custom header → `TeacherPageHeader` (with role toggle + search)
- [ ] Replace filter chips → `ActiveFilterChips`
- [ ] Replace role toggle → `RoleToggle`
- [ ] Extract `_ScheduleDaySummary` widget → `schedule_day_summary.dart`
- [ ] Move static cache fields + data loading → into existing `teacher_schedule_controller.dart`
- [ ] Move FCM sync logic → `schedule_sync_mixin.dart`
- [ ] Move tour/onboarding → `schedule_tour_helper.dart`

### 1.3 `teacher_attendance_screen.dart` (1,547 lines)
**Path:** `lib/features/attendance/presentation/screens/`
- [ ] Replace custom header → `TeacherPageHeader` (with role toggle + search)
- [ ] Replace role toggle → `RoleToggle`
- [ ] Replace search + filter → `SearchFilterBar`
- [ ] Extract `_AttendanceGroupedListView` widget → `attendance_grouped_list.dart`
- [ ] Extract `_AttendanceTimelineView` widget → `attendance_timeline_view.dart`
- [ ] Replace pagination → `PaginatedListView`
- [ ] Move data loading + state → `teacher_attendance_controller.dart` (new)
- [ ] Convert `teacher_attendance_screen_helpers.dart` (part file) → standalone import

### 1.4 `admin_lesson_plan_screen.dart` (1,505 lines)
**Path:** `lib/features/lesson_plans/presentation/screens/`
- [ ] Replace header → `GradientPageHeader` (admin variant)
- [ ] Replace status badges → `StatusBadge`
- [ ] Extract `_LessonPlanListView` widget → `admin_lesson_plan_list.dart`
- [ ] Extract `_LessonPlanFilterSection` → `admin_lesson_plan_filter.dart`
- [ ] Extract `_LessonPlanActionButtons` → `lesson_plan_actions.dart`
- [ ] Move filter/sort/search logic → `admin_lesson_plan_controller.dart`

### 1.5 `add_activity_dialog.dart` (1,473 lines)
**Path:** `lib/features/class_activity/presentation/widgets/`
- [ ] Replace form fields → `FormFieldSection` / `FormDropdownField` / `FormTextField`
- [ ] Extract `_ActivityAttachmentPicker` → `activity_attachment_picker.dart`
- [ ] Extract `_ActivityScheduleSelector` → `activity_schedule_selector.dart`
- [ ] Extract `_ActivityTypeSelector` → `activity_type_selector.dart`
- [ ] Extract form validation → `activity_form_validator.dart`
- [ ] Move API submit logic → `activity_form_controller.dart`

### 1.6 `admin_teacher_management_screen.dart` (1,456 lines)
**Path:** `lib/features/teachers/presentation/screens/`
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace search → `SearchFilterBar`
- [ ] Replace pagination → `PaginatedListView`
- [ ] Extract `_TeacherListCard` widget → `teacher_list_card.dart`
- [ ] Extract `_TeacherStatsSummary` → `teacher_stats_summary.dart` (use `StatSummaryRow`)
- [ ] Extract `_TeacherBulkActions` → `teacher_bulk_actions.dart`
- [ ] Move data/state management → `admin_teacher_controller.dart`

### 1.7 `admin_attendance_report_screen.dart` (1,450 lines)
**Path:** `lib/features/attendance/presentation/screens/`
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace table → `AppDataTable`
- [ ] Replace status badges → `StatusBadge`
- [ ] Replace stat cards → `StatSummaryRow`
- [ ] Extract `_AttendanceChartSection` → `attendance_report_chart.dart`
- [ ] Extract `_AttendanceExportActions` → `attendance_report_export.dart`
- [ ] Simplify controller (885 lines) → split chart logic into `attendance_chart_builder.dart`

### 1.8 `teacher_grade_recap_screen.dart` (1,447 lines)
**Path:** `lib/features/grades/presentation/screens/`
- [ ] Replace header → `TeacherPageHeader`
- [ ] Replace table → `AppDataTable`
- [ ] Replace stat summary → `StatSummaryRow`
- [ ] Extract `_GradeRecapFilter` → `grade_recap_filter.dart`
- [ ] Extract `_GradeRecapExport` → `grade_recap_export.dart`
- [ ] Move data processing → `teacher_grade_recap_controller.dart`

---

## Phase 2 — Large Screens (1,400–1,000 lines) — Priority: 🟠 HIGH

✅ **COMPLETED** — All files in this phase have been split using mixin-based decomposition. All are now under 400 lines.

### 2.1 `grade_book_screen.dart` (1,381 lines)
- [ ] Replace table → `AppDataTable`
- [ ] Extract `_GradeBookHeader` → `grade_book_header.dart`
- [ ] Extract `_GradeInputRow` → `grade_book_input_row.dart`
- [ ] Simplify `grade_book_controller.dart` (722 lines) → extract calculation helpers

### 2.2 `admin_schedule_management_screen.dart` (1,377 lines)
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace search → `SearchFilterBar`
- [ ] Extract `_ScheduleGrid` → `admin_schedule_grid.dart`
- [ ] Extract `_ScheduleBulkActions` → `admin_schedule_bulk_actions.dart`
- [ ] Simplify `admin_schedule_controller.dart` (1,192 lines) → split into:
  - `admin_schedule_data_controller.dart` (CRUD operations)
  - `admin_schedule_view_controller.dart` (UI state, filtering)
  - `schedule_conflict_checker.dart` (validation logic)

### 2.3 `class_promotion_wizard.dart` (1,363 lines)
- [ ] Extract each wizard step → separate widget files:
  - `promotion_step_select_source.dart`
  - `promotion_step_select_target.dart`
  - `promotion_step_review.dart`
  - `promotion_step_confirm.dart`
- [ ] Extract `_PromotionProgressIndicator` → `promotion_progress.dart`
- [ ] Move wizard state → `class_promotion_controller.dart`

### 2.4 `schedule_form_dialog.dart` (1,362 lines)
- [ ] Replace form fields → `FormFieldSection` / `FormDropdownField`
- [ ] Extract `_TimeSlotPicker` → `schedule_time_slot_picker.dart`
- [ ] Extract `_DaySelector` → `schedule_day_selector.dart`
- [ ] Extract `_TeacherSubjectPicker` → `schedule_teacher_subject_picker.dart`
- [ ] Extract `_ConflictWarning` → `schedule_conflict_warning.dart`
- [ ] Move validation logic → `schedule_form_validator.dart`

### 2.5 `teacher_lesson_plan_screen.dart` (1,347 lines)
- [ ] Replace header → `TeacherPageHeader`
- [ ] Replace status badges → `StatusBadge`
- [ ] Extract `_LessonPlanCard` → `teacher_lesson_plan_card.dart`
- [ ] Extract `_LessonPlanFilter` → `teacher_lesson_plan_filter.dart`
- [ ] Move data logic → `teacher_lesson_plan_controller.dart`

### 2.6 `lesson_plan_detail_screen.dart` (1,310 lines)
- [ ] Replace status badges → `StatusBadge`
- [ ] Extract `_LessonPlanHeader` → `lesson_plan_detail_header.dart`
- [ ] Extract `_LessonPlanContentSection` → `lesson_plan_content_section.dart`
- [ ] Extract `_LessonPlanAttachments` → `lesson_plan_attachments.dart`
- [ ] Extract `_LessonPlanApprovalSection` → `lesson_plan_approval.dart`

### 2.7 `admin_finance_screen.dart` (1,302 lines)
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace stat cards → `StatSummaryRow`
- [ ] Replace table → `AppDataTable`
- [ ] Extract `_FinanceDashboard` → `finance_dashboard_summary.dart`
- [ ] Move logic → split `admin_finance_controller.dart` (703 lines)

### 2.8 `admin_classroom_management_screen.dart` (1,251 lines)
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace search → `SearchFilterBar`
- [ ] Extract `_ClassroomListCard` → `classroom_list_card.dart`
- [ ] Extract `_ClassroomDetailSheet` → `classroom_detail_sheet.dart`
- [ ] Extract `_ClassroomFormDialog` → `classroom_form_dialog.dart`
- [ ] Move logic → `admin_classroom_controller.dart`

### 2.9 `admin_class_activity_screen.dart` (1,242 lines)
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace stat cards → `StatSummaryRow`
- [ ] Extract `_ActivityListView` → `admin_activity_list.dart`
- [ ] Extract `_ActivityFilterBar` → `admin_activity_filter.dart`
- [ ] Move logic → `admin_class_activity_controller.dart`

### 2.10 `parent_announcement_screen.dart` (1,211 lines)
- [ ] Replace header → `TeacherPageHeader` (parent variant)
- [ ] Replace pagination → `PaginatedListView`
- [ ] Extract `_AnnouncementCard` → `parent_announcement_card.dart`
- [ ] Extract `_AnnouncementDetail` → `parent_announcement_detail.dart`
- [ ] Move logic → `parent_announcement_controller.dart`

### 2.11 `sub_chapter_detail_screen.dart` (1,205 lines)
- [ ] Extract `_SubChapterContent` → `sub_chapter_content.dart`
- [ ] Extract `_SubChapterQuillEditor` → `sub_chapter_editor.dart`
- [ ] Extract `_SubChapterActions` → `sub_chapter_actions.dart`

### 2.12 `teacher_class_activity_screen.dart` (1,171 lines)
- [ ] Replace header → `TeacherPageHeader` (with role toggle)
- [ ] Replace role toggle → `RoleToggle`
- [ ] Extract `_ClassActivityList` → `teacher_activity_list.dart`
- [ ] Extract `_ClassActivityFilter` → `teacher_activity_filter.dart`

### 2.13 `admin_subject_management_screen.dart` (1,115 lines)
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace search → `SearchFilterBar`
- [ ] Extract `_SubjectListView` → `admin_subject_list.dart`
- [ ] Extract `_SubjectFormDialog` → `admin_subject_form.dart`
- [ ] Simplify `admin_subject_controller.dart` (700 lines)

### 2.14 `parent_attendance_screen.dart` (1,106 lines)
- [ ] Replace header → `TeacherPageHeader` (parent variant)
- [ ] Replace filter chips → `ActiveFilterChips`
- [ ] Replace status badges → `StatusBadge`
- [ ] Extract `_AttendanceCalendar` → `parent_attendance_calendar.dart`
- [ ] Extract `_AttendanceDaySummary` → `parent_attendance_summary.dart`

### 2.15 `admin_announcement_screen.dart` (1,071 lines)
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace search → `SearchFilterBar`
- [ ] Extract `_AnnouncementList` → `admin_announcement_list.dart`
- [ ] Move logic → `admin_announcement_controller.dart`

### 2.16 `day_session_management_sheet.dart` (1,051 lines)
- [ ] Replace form fields → `FormFieldSection`
- [ ] Extract `_SessionTimeEditor` → `session_time_editor.dart`
- [ ] Extract `_SessionDayList` → `session_day_list.dart`
- [ ] Extract `_SessionTemplateSelector` → `session_template_selector.dart`

### 2.17 `generate_lesson_plan_form_dialog.dart` (1,051 lines)
- [ ] Replace form fields → `FormFieldSection` / `FormDropdownField`
- [ ] Extract `_LessonPlanPromptEditor` → `lesson_plan_prompt_editor.dart`
- [ ] Extract `_LessonPlanTemplateSelector` → `lesson_plan_template_selector.dart`
- [ ] Extract `_LessonPlanPreview` → `lesson_plan_preview.dart`
- [ ] Move AI generation logic → `lesson_plan_generator_controller.dart`

### 2.18 `admin_report_card_screen.dart` (1,029 lines)
- [ ] Replace header → `GradientPageHeader`
- [ ] Replace status badges → `StatusBadge`
- [ ] Extract `_ReportCardList` → `admin_report_card_list.dart`
- [ ] Extract `_ReportCardFilter` → `admin_report_card_filter.dart`

### 2.19 `parent_class_activity_screen.dart` (1,016 lines)
- [ ] Replace header → `TeacherPageHeader` (parent variant)
- [ ] Extract `_ParentActivityList` → `parent_activity_list.dart`
- [ ] Extract `_ParentActivityDetail` → `parent_activity_detail.dart`

---

## Phase 3 — Large Files (999–500 lines) — Priority: 🟡 MEDIUM

✅ **COMPLETED** — All files in this phase have been split using mixin-based decomposition. All are now under 400 lines.

### 3.1 Screens (500–999 lines) — Extract widgets + use shared components
| File | Lines | Action |
|------|-------|--------|
| `class_finance_report_screen.dart` | 996 | Use `AppDataTable` + `StatSummaryRow` + extract chart widget |
| `teacher_attendance_detail.dart` | 978 | Use `StatusBadge` + extract student list + actions |
| `lesson_plan_ai_result_screen.dart` | 975 | Split into result preview + edit + save sections |
| `report_card_detail_screen.dart` | 946 | Use `AppDataTable` for grades + extract sections |
| `lesson_plan_form_dialog.dart` | 940 | Use `FormFieldSection` + split into form sections |
| `schedule_card_item.dart` | 938 | Split into card header + body + actions |
| `subject_class_management_page.dart` | 890 | Split into class list + assignment + form |
| `recommendation_class_screen.dart` | 868 | Split into recommendation cards + filters |
| `dashboard_screen.dart` | 839 | Use `StatSummaryRow` + split dashboard sections by role |
| `teacher_schedule_table_view.dart` | 829 | Use `AppDataTable` + extract cell renderers |
| `parent_grade_screen.dart` | 822 | Use `StatusBadge` + split grade summary + subject list |
| `announcement_form_sheet.dart` | 818 | Use `FormFieldSection` + split form fields + preview |
| `admin_student_management_screen.dart` | 808 | Use `GradientPageHeader` + `SearchFilterBar` + `PaginatedListView` |
| `admin_attendance_detail.dart` | 806 | Use `AppDataTable` + `StatusBadge` + extract sections |
| `teacher_form_dialog.dart` | 792 | Use `FormFieldSection` + split into sections |
| `embedded_activity_list_screen.dart` | 766 | Split into list + filter + actions |
| `settings_screen.dart` | 765 | Split into settings sections |
| `student_detail_screen.dart` | 735 | Use `SectionHeader` + split profile + academics |
| `notification_list_screen.dart` | 695 | Use `PaginatedListView` + extract notification card |
| `teacher_report_card_screen.dart` | 691 | Use `StatusBadge` + split into list + actions |
| `student_add_edit_dialog.dart` | 678 | Use `FormFieldSection` + split into form sections |
| `teacher_detail_screen.dart` | 668 | Use `SectionHeader` + split profile + stats |
| `teacher_grade_input_screen.dart` | 661 | Use `TeacherPageHeader` + `AppDataTable` |
| `grade_input_form.dart` | 661 | Use `FormFieldSection` + split validation |

### 3.2 Controllers (500+ lines) — Extract helper classes
| File | Lines | Action |
|------|-------|--------|
| `admin_schedule_controller.dart` | 1,192 | Split into data + view + validation controllers |
| `admin_attendance_report_controller.dart` | 885 | Extract chart builder + data processor |
| `teacher_schedule_controller.dart` | 747 | Extract cache manager + filter logic |
| `grade_book_controller.dart` | 722 | Extract grade calculator + data mapper |
| `admin_finance_controller.dart` | 703 | Extract payment processor + report builder |
| `admin_subject_controller.dart` | 700 | Extract assignment logic + validation |

### 3.3 Services (500+ lines) — Extract domain-specific helpers
| File | Lines | Action |
|------|-------|--------|
| `subject_service.dart` | 852 | Split into subject CRUD + class assignment + curriculum service |

---

## Phase 4 — Architectural Improvements — Priority: 🟢 MEDIUM

### 4.1 Eliminate `part` file usage
✅ Investigated — `color_utils_mappings.dart` and 6 `language_utils` part files cannot be safely converted due to private cross-references (`_adjustColor()`, `_k` constants). Deferred.
- [ ] Convert `teacher_attendance_screen_helpers.dart` (part file) to standalone import
- [ ] Search for any other `part`/`part of` directives and convert to regular imports

### 4.2 Replace `Map<String, dynamic>` with typed models
- [x] **`Teacher` Freezed model** created at `lib/features/teachers/domain/models/teacher.dart` with generated `.freezed.dart` and `.g.dart` via `build_runner`. Handles nested `user`, List/Map `homeroom_class`, and Indonesian ↔ English key normalization. Ready for incremental adoption by screens passing `Map<String, dynamic>` teacher objects.
- [ ] Incrementally migrate `teacher` parameter call sites (teacher_card, teacher_detail_screen, teacher_crud_mixin, teacher_detail_card_builders_mixin, etc.) to use `Teacher` type
- [ ] Audit remaining `dynamic` map usage → replace with Freezed models where reused
- [ ] Key locations still pending:
  - `TeacherMaterialScreen.teacher`
  - `AttendancePage.teacher`
  - `_subjectList`, `_classList` (List<dynamic>) → typed lists
  - `_schedules`, `_overviewSummary` (List<dynamic>) → typed lists
  - `_homeroomClassesList` (List<dynamic>) → `List<HomeroomClass>`

### 4.3 Standardize state management
- [ ] Migrate remaining `StatefulWidget` screens with heavy local state to Riverpod controllers
- [ ] Pattern: screen holds only UI state (scroll position, animation) → data state moves to controller
- [ ] Migrate legacy `ChangeNotifierProvider` (LanguageProvider) to Riverpod `Notifier`
- [ ] Ensure all controllers use `AsyncNotifier` pattern consistently

### 4.4 Deprecate and remove unused widgets
✅ **COMPLETED** — 29 unused widget files deleted + `report_card_status_badge.dart` replaced with `StatusBadge`
- [x] Audit `EnhancedSearchBar` — replace with `SearchFilterBar` or refactor screens to use it
- [x] Consolidate `attendance_stat_card.dart` + `admin_attendance_summary_card.dart` → `StatSummaryCard`
- [x] Consolidate `attendance_summary_card.dart` → `StatSummaryCard`

### 4.5 Extract common screen patterns
- [ ] `AdminManagementScreen<T>` — generic scaffolding for all admin CRUD screens
  - Includes: `GradientPageHeader` + `SearchFilterBar` + add button + list/grid toggle + `PaginatedListView`
  - Used by: teacher, student, classroom, subject, announcement management
- [ ] `DetailScreen<T>` — generic detail view with header + tabs/sections
  - Used by: student detail, teacher detail, lesson plan detail, report card detail

---

## Phase 5 — Code Quality & Cleanup — Priority: 🔵 ONGOING

### 5.1 Remove dead code
⚠️ Partial — `dart fix --apply` run (17 fixes in 12 files). Full audit of commented-out code and unused methods still pending.
- [x] Remove unused imports (use `dart fix --apply`) — completed (17 fixes)
- [ ] Audit commented-out code blocks in all screens — pending
- [ ] Remove `// ignore: unused_field` annotations — either use or remove the fields
- [ ] Check for unused methods in services

### 5.2 Apply consistent naming
- [ ] Standardize file naming: `admin_*_screen.dart`, `teacher_*_screen.dart`, `parent_*_screen.dart`
- [ ] Standardize widget naming: `*Card`, `*List`, `*Filter`, `*Form`, `*Sheet`, `*Dialog`
- [ ] Ensure controller names match screen names

### 5.3 Documentation cleanup
- [ ] Remove Vue/Laravel comparison comments (they add noise for a Flutter team)
- [ ] Add dartdoc to all public classes and methods
- [ ] Add file-level documentation explaining the widget's responsibility

### 5.4 Format and lint
⚠️ Partial — `dart fix --apply` and `dart format` run (558 files formatted). `analysis_options.yaml` stricter rules not yet added.
- [x] Run `dart format -l 120 lib/` to enforce 120-character line limit — completed (558 files formatted)
- [x] Run `dart fix --apply` to auto-fix lint issues — completed
- [ ] Add/update `analysis_options.yaml` with stricter rules:
  ```yaml
  analyzer:
    errors:
      unused_import: error
      unused_local_variable: warning
    language:
      strict-casts: true
      strict-inference: true
  linter:
    rules:
      - prefer_const_constructors
      - prefer_const_declarations
      - avoid_unnecessary_containers
      - sized_box_for_whitespace
      - prefer_final_locals
      - lines_longer_than_80_chars: false  # using 120
  ```

---

## Phase 6 — Testing & Validation — Priority: 🔴 CRITICAL (per phase)

### 6.1 After each file refactoring
- [ ] Run `dart analyze lib/` — zero errors
- [ ] Run `flutter build apk --debug` — successful build
- [ ] Manually verify the refactored screen works identically
- [ ] Run existing tests: `flutter test`

### 6.2 Add tests for extracted logic
- [ ] Unit tests for all new controllers
- [ ] Unit tests for extracted validators
- [ ] Unit tests for helper/utility classes
- [ ] Widget tests for shared components (Phase 0 widgets)

---

## Execution Order (Recommended)

### Sprint 1 (Week 1–2): Foundation + Design System
1. Phase 5.4 — Format and lint (establishes baseline)
2. Phase 4.1 — Eliminate `part` files
3. Phase 5.1 — Remove dead code
4. **Phase 0.1–0.6** — Build core shared components:
   - `RoleToggle`, `SearchFilterBar`, `ActiveFilterChips`
   - `FilterBottomSheet`, `FilterChipGrid`, `StatusBadge`
5. Phase 6 — Validate build still works

### Sprint 2 (Week 3–4): Design System Continued + First Screens
6. **Phase 0.7–0.15** — Build remaining shared components:
   - `StatSummaryCard`, `AppDataTable`, `SectionHeader`
   - `TeacherPageHeader`, `PaginatedListView`, `FormFieldSection`
   - `HomeroomClassSelector`, `ViewToggleButton`, `ActionConfirmSheet`
7. Phase 1.1 — `teacher_material_screen.dart` (2,161 lines)
8. Phase 1.2 — `teacher_schedule_screen.dart` (1,571 lines)

### Sprint 3 (Week 5–6): Critical Screens Part 1
9. Phase 1.3 — `teacher_attendance_screen.dart` (1,547 lines)
10. Phase 1.4 — `admin_lesson_plan_screen.dart` (1,505 lines)
11. Phase 1.5 — `add_activity_dialog.dart` (1,473 lines)
12. Phase 1.6 — `admin_teacher_management_screen.dart` (1,456 lines)

### Sprint 4 (Week 7–8): Critical Screens Part 2
13. Phase 1.7 — `admin_attendance_report_screen.dart` (1,450 lines)
14. Phase 1.8 — `teacher_grade_recap_screen.dart` (1,447 lines)
15. Phase 2.1–2.4 — Grade book, schedule management, class promotion, schedule form

### Sprint 5 (Week 9–10): Large Screens
16. Phase 2.5–2.10 — Teacher lesson plan, lesson plan detail, finance, classroom, class activity, announcements

### Sprint 6 (Week 11–12): Large Screens Continued
17. Phase 2.11–2.19 — Remaining 1,000+ line files

### Sprint 7 (Week 13–14): Medium Files + Controllers
18. Phase 3.1 — All 500–999 line screens (use shared components)
19. Phase 3.2 — All 500+ line controllers
20. Phase 3.3 — Large services

### Sprint 8 (Week 15–16): Architecture
21. Phase 4.2 — Replace `Map<String, dynamic>` with typed models
22. Phase 4.3 — Standardize state management
23. Phase 4.4 — Deprecate unused widgets
24. Phase 4.5 — Extract generic screen patterns

### Sprint 9 (Week 17–18): Polish
25. Phase 5.2 — Naming consistency
26. Phase 5.3 — Documentation
27. Phase 6.2 — Add tests

---

## Refactoring Template (How to Split a Screen)

For each oversized screen file, follow this pattern:

### Step 1: Replace with shared components
Identify which Phase 0 components can replace inline code:
- Custom header → `TeacherPageHeader` or `GradientPageHeader`
- Custom search row → `SearchFilterBar`
- Custom filter chips → `ActiveFilterChips`
- Custom role toggle → `RoleToggle`
- Custom tables → `AppDataTable`
- Custom form fields → `FormFieldSection`
- Custom status badges → `StatusBadge`

### Step 2: Identify remaining sections
Read the `build()` method and identify the 3–6 major UI sections not covered by shared components.

### Step 3: Create widget files
For each section, create a new file in the same `widgets/` directory:
```
features/{feature}/presentation/widgets/{feature}_{section_name}.dart
```

### Step 4: Extract the widget
```dart
// Before (in screen file, 200 lines):
Widget _buildChapterTree() {
  return Column(children: [ /* 200 lines of widget tree */ ]);
}

// After (new file: material_chapter_tree.dart):
class MaterialChapterTree extends StatelessWidget {
  final List<Chapter> chapters;
  final ValueChanged<Chapter> onChapterTap;
  final ValueChanged<Chapter> onCheckboxToggle;

  const MaterialChapterTree({
    super.key,
    required this.chapters,
    required this.onChapterTap,
    required this.onCheckboxToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [ /* same widget tree */ ]);
  }
}
```

### Step 5: Extract the controller
Move all data-fetching, caching, and business logic to a Riverpod controller:
```dart
// features/{feature}/presentation/controllers/{feature}_controller.dart
class TeacherMaterialController extends AsyncNotifier<TeacherMaterialState> {
  @override
  Future<TeacherMaterialState> build() async { /* load initial data */ }

  Future<void> loadSubjects() async { /* ... */ }
  Future<void> loadChapters(String subjectId) async { /* ... */ }
}
```

### Step 6: Simplify the screen
The screen file should only contain:
- Widget composition (combining shared + extracted widgets)
- Navigation calls
- Dialog/sheet triggers
- Scaffold + AppBar

Target: screen file under 200–300 lines.

---

## Total Refactoring Impact

| Category | Files Affected | Estimated New Files Created | Lines Saved |
|----------|---------------|----------------------------|-------------|
| Phase 0 (Design System) | Cross-cutting | 15 new shared components | ~5,970 |
| Phase 1 (Critical) | 8 screens | ~35 widget + controller files | ~3,000 |
| Phase 2 (Large) | 19 screens | ~60 widget + controller files | ~5,000 |
| Phase 3 (Medium) | 30 screens + 6 controllers + 1 service | ~70 files | ~4,000 |
| Phase 4 (Architecture) | Cross-cutting | ~5 generics + models | ~2,000 |
| **Total** | **64+ files refactored** | **~185 new smaller files** | **~20,000 lines** |

### Final Shared Component Library (after Phase 0)
```
lib/core/widgets/
├── action_confirm_sheet.dart        ← NEW
├── active_filter_chips.dart         ← NEW
├── app_data_table.dart              ← NEW
├── confirmation_dialog.dart         ✅ EXISTS
├── empty_state.dart                 ✅ EXISTS
├── enhanced_search_bar.dart         ⚠️ DEPRECATE (replace with search_filter_bar)
├── error_handler.dart               ✅ EXISTS
├── error_screen.dart                ✅ EXISTS
├── filter_bottom_sheet.dart         ← NEW
├── filter_chip_grid.dart            ← NEW
├── form_field_section.dart          ← NEW
├── gradient_page_header.dart        ✅ EXISTS (keep for admin screens)
├── homeroom_class_selector.dart     ← NEW
├── loading_screen.dart              ✅ EXISTS
├── modern_date_picker.dart          ✅ EXISTS
├── paginated_list_view.dart         ← NEW
├── role_toggle.dart                 ← NEW
├── search_filter_bar.dart           ← NEW
├── section_header.dart              ← NEW
├── skeleton_loading.dart            ✅ EXISTS
├── stat_summary_card.dart           ← NEW
├── status_badge.dart                ← NEW
├── tab_switcher.dart                ✅ EXISTS
├── teacher_page_header.dart         ← NEW
└── view_toggle_button.dart          ← NEW
```

---

*Generated: April 10, 2026*
*Updated: April 10, 2026 — Added Phase 0 (Shared Design System & Component Library)*
*Codebase: Kamiledu Mobile Flutter (136K lines, 429 Dart files)*
