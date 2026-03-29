// Student filter bottom sheet — extracted from admin_student_management_screen.dart.
//
// Like a Vue modal component that owns its own local (temp) filter state,
// then calls [onApply] with the committed values when the user taps "Apply Filter".
// The parent screen is responsible for storing the final filter state and
// triggering a data reload — just as a Laravel controller handles the actual query.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/dashboard_typography.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

/// Shows a modal bottom sheet with status, class, gender and guardian filters.
///
/// [classList]             - available classes fetched from the API.
/// [primaryColor]          - role accent color.
/// [initialStatus]         - currently active status filter value.
/// [initialClassIds]       - currently active class filter IDs.
/// [initialGender]         - currently active gender filter value.
/// [initialGuardian]       - currently active guardian name filter.
/// [onApply]               - called when the user taps "Apply Filter"; receives
///                           the four new filter values.
void showStudentFilterSheet({
  required BuildContext context,
  required List<dynamic> classList,
  required Color primaryColor,
  required String? initialStatus,
  required List<String> initialClassIds,
  required String? initialGender,
  required String? initialGuardian,
  required void Function({
    required String? status,
    required List<String> classIds,
    required String? gender,
    required String? guardian,
  }) onApply,
  // i18n text helpers — passed in so this widget stays decoupled from providers.
  required String Function(Map<String, String> translations) translate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _StudentFilterSheetContent(
      classList: classList,
      primaryColor: primaryColor,
      initialStatus: initialStatus,
      initialClassIds: initialClassIds,
      initialGender: initialGender,
      initialGuardian: initialGuardian,
      onApply: onApply,
      translate: translate,
    ),
  );
}

/// Internal stateful widget that owns the "temp" filter state while the sheet
/// is open — analogous to a Vue component's local `data()` that hasn't been
/// committed to the parent store yet.
class _StudentFilterSheetContent extends StatefulWidget {
  final List<dynamic> classList;
  final Color primaryColor;
  final String? initialStatus;
  final List<String> initialClassIds;
  final String? initialGender;
  final String? initialGuardian;
  final void Function({
    required String? status,
    required List<String> classIds,
    required String? gender,
    required String? guardian,
  }) onApply;
  final String Function(Map<String, String> translations) translate;

  const _StudentFilterSheetContent({
    required this.classList,
    required this.primaryColor,
    required this.initialStatus,
    required this.initialClassIds,
    required this.initialGender,
    required this.initialGuardian,
    required this.onApply,
    required this.translate,
  });

  @override
  State<_StudentFilterSheetContent> createState() =>
      _StudentFilterSheetContentState();
}

class _StudentFilterSheetContentState
    extends State<_StudentFilterSheetContent> {
  late String? _tempStatus;
  late List<String> _tempClassIds;
  late String? _tempGender;
  late String? _tempGuardian;

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.initialStatus;
    _tempClassIds = List.from(widget.initialClassIds);
    _tempGender = widget.initialGender;
    _tempGuardian = widget.initialGuardian;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.translate;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Gradient header with "Reset" button
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.primaryColor,
                    widget.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.white, size: 24),
                      SizedBox(width: AppSpacing.md),
                      Text(
                        t({'en': 'Filter Students', 'id': 'Filter Siswa'}),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempStatus = null;
                        _tempClassIds.clear();
                        _tempGender = null;
                        _tempGuardian = null;
                      });
                    },
                    child: Text(
                      t({'en': 'Reset', 'id': 'Reset'}),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable filter content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Guardian filter ──────────────────────────────────
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.family_restroom,
                            size: 18,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            t({
                              'en': 'Guardian Name',
                              'id': 'Nama Wali Murid',
                            }),
                            style: DashboardTypography.subtitle(
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Autocomplete<String>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.length < 2) {
                              return const Iterable<String>.empty();
                            }
                            return await getIt<ApiStudentService>()
                                .getGuardians(textEditingValue.text);
                          },
                      onSelected: (String selection) {
                        setState(() {
                          _tempGuardian = selection;
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        if (_tempGuardian != null &&
                            textEditingController.text.isEmpty) {
                          textEditingController.text = _tempGuardian!;
                        }
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: t({
                              'en': 'Search Guardian',
                              'id': 'Cari Wali Murid',
                            }),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: ColorUtils.slate300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: ColorUtils.slate300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: widget.primaryColor,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.person_search,
                              color: ColorUtils.slate400,
                            ),
                            suffixIcon: _tempGuardian != null
                                ? IconButton(
                                    icon: Icon(Icons.close),
                                    onPressed: () {
                                      textEditingController.clear();
                                      setState(() {
                                        _tempGuardian = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: AppSpacing.xl),

                    // ── Status filter ────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            t({'en': 'Status', 'id': 'Status'}),
                            style: DashboardTypography.subtitle(
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChoiceChip(
                          label: t({'en': 'All', 'id': 'Semua'}),
                          value: null,
                          selectedValue: _tempStatus,
                          primaryColor: widget.primaryColor,
                          onSelected: () =>
                              setState(() => _tempStatus = null),
                        ),
                        _FilterChoiceChip(
                          label: t({'en': 'Active', 'id': 'Aktif'}),
                          value: 'active',
                          selectedValue: _tempStatus,
                          primaryColor: widget.primaryColor,
                          onSelected: () =>
                              setState(() => _tempStatus = 'active'),
                        ),
                        _FilterChoiceChip(
                          label: t({'en': 'Inactive', 'id': 'Tidak Aktif'}),
                          value: 'inactive',
                          selectedValue: _tempStatus,
                          primaryColor: widget.primaryColor,
                          onSelected: () =>
                              setState(() => _tempStatus = 'inactive'),
                        ),
                      ],
                    ),

                    SizedBox(height: AppSpacing.xxl),

                    // ── Class filter ─────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.class_outlined,
                            size: 18,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            t({'en': 'Class', 'id': 'Kelas'}),
                            style: DashboardTypography.subtitle(
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.classList.map((classItem) {
                        final classId = classItem['id'].toString();
                        final isSelected = _tempClassIds.contains(classId);

                        return FilterChip(
                          label: Text(
                            classItem['name'] ??
                                classItem['nama'] ??
                                'Unknown',
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _tempClassIds.add(classId);
                              } else {
                                _tempClassIds.remove(classId);
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: widget.primaryColor.withValues(
                            alpha: 0.15,
                          ),
                          checkmarkColor: widget.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? widget.primaryColor
                                : ColorUtils.slate700,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? widget.primaryColor
                                : ColorUtils.slate300,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: AppSpacing.xxl),

                    // ── Gender filter ────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.transgender,
                            size: 18,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            t({'en': 'Gender', 'id': 'Jenis Kelamin'}),
                            style: DashboardTypography.subtitle(
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChoiceChip(
                          label: t({'en': 'All', 'id': 'Semua'}),
                          value: null,
                          selectedValue: _tempGender,
                          primaryColor: widget.primaryColor,
                          onSelected: () =>
                              setState(() => _tempGender = null),
                        ),
                        _FilterChoiceChip(
                          label: t({'en': 'Male', 'id': 'Laki-laki'}),
                          value: 'M',
                          selectedValue: _tempGender,
                          primaryColor: widget.primaryColor,
                          onSelected: () => setState(() => _tempGender = 'M'),
                        ),
                        _FilterChoiceChip(
                          label: t({'en': 'Female', 'id': 'Perempuan'}),
                          value: 'F',
                          selectedValue: _tempGender,
                          primaryColor: widget.primaryColor,
                          onSelected: () => setState(() => _tempGender = 'F'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Sticky footer: Cancel + Apply Filter
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ColorUtils.slate200)),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        t({'en': 'Cancel', 'id': 'Batal'}),
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                          status: _tempStatus,
                          classIds: _tempClassIds,
                          gender: _tempGender,
                          guardian: _tempGuardian,
                        );
                        AppNavigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        t({'en': 'Apply Filter', 'id': 'Terapkan Filter'}),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable ChoiceChip for filter bottom sheets.
///
/// Null [value] represents "All / no filter" — the chip is selected when
/// [selectedValue] is also null (both null == equal).
class _FilterChoiceChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? selectedValue;
  final Color primaryColor;
  final VoidCallback onSelected;

  const _FilterChoiceChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? primaryColor : ColorUtils.slate300,
      ),
    );
  }
}
