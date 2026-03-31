// Teacher filter bottom sheet widget.
//
// Extracted from TeacherAdminScreenState._showFilterSheet() to keep the
// management screen under the line-count budget.
//
// Like a Vue modal component — receives initial filter values as props and
// emits the confirmed selection via [onApply].
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_status_chip.dart';

/// Bottom-sheet widget for filtering the teacher list.
///
/// Receives the current filter state as constructor parameters and returns
/// the confirmed selection through [onApply].  The parent is responsible for
/// calling [showModalBottomSheet] and passing in the reference data lists.
class TeacherFilterSheet extends StatefulWidget {
  const TeacherFilterSheet({
    super.key,
    required this.initialHomeroom,
    required this.initialGender,
    required this.initialEmploymentStatus,
    required this.initialTeachingClass,
    required this.initialShowAll,
    required this.availableGenders,
    required this.availableEmploymentStatus,
    required this.availableClass,
    required this.languageProvider,
    required this.onApply,
  });

  /// Current homeroom filter value passed from the parent screen.
  final String? initialHomeroom;

  /// Current gender filter value passed from the parent screen.
  final String? initialGender;

  /// Current employment-status filter value passed from the parent screen.
  final String? initialEmploymentStatus;

  /// Current teaching-class filter value passed from the parent screen.
  final String? initialTeachingClass;

  /// Whether "Show All Teachers" toggle is currently on.
  final bool initialShowAll;

  /// Gender options loaded from the backend (list of {label, value} maps).
  final List<dynamic> availableGenders;

  /// Employment-status options loaded from the backend.
  final List<dynamic> availableEmploymentStatus;

  /// Class options loaded from the backend.
  final List<dynamic> availableClass;

  /// Language/translation provider — read once from parent so the sheet does
  /// not need its own Riverpod ref.
  final dynamic languageProvider;

  /// Called when the user taps "Apply Filter".
  ///
  /// Parameters (in order): homeroom, gender, employmentStatus,
  /// teachingClassId, showAll.
  final void Function(
    String? homeroom,
    String? gender,
    String? employmentStatus,
    String? teachingClassId,
    bool showAll,
  ) onApply;

  @override
  TeacherFilterSheetState createState() => TeacherFilterSheetState();
}

/// Mutable state for [TeacherFilterSheet].
///
/// Like Vue's `data()` inside the modal component — holds temporary selections
/// that are only committed to the parent when the user confirms.
class TeacherFilterSheetState extends State<TeacherFilterSheet> {
  // Temporary (uncommitted) filter selections — like v-model bindings inside a
  // modal that are only emitted on "Save".
  late String? _tempSelectedHomeroom;
  late String? _tempSelectedGender;
  late String? _tempSelectedEmploymentStatus;
  late String? _tempSelectedTeachingClass;
  late bool _showAllTeachers;

  @override
  void initState() {
    super.initState();
    _tempSelectedHomeroom = widget.initialHomeroom;
    _tempSelectedGender = widget.initialGender;
    _tempSelectedEmploymentStatus = widget.initialEmploymentStatus;
    _tempSelectedTeachingClass = widget.initialTeachingClass;
    _showAllTeachers = widget.initialShowAll;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = widget.languageProvider;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header gradient (Pattern #11)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.corporateBlue600,
                    ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.filter_list_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Filter Teachers',
                          'id': 'Filter Guru',
                        }),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempSelectedHomeroom = null;
                        _tempSelectedGender = null;
                        _tempSelectedEmploymentStatus = null;
                        _tempSelectedTeachingClass = null;
                        _showAllTeachers = false;
                      });
                    },
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Reset',
                        'id': 'Reset',
                      }),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show All Teachers Toggle
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Show All Teachers',
                                    'id': 'Tampilkan Semua Guru',
                                  }),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: ColorUtils.slate800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en':
                                        'Include inactive (ignores academic year)',
                                    'id':
                                        'Termasuk tidak aktif (abaikan tahun ajaran)',
                                  }),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ColorUtils.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _showAllTeachers,
                            activeThumbColor: ColorUtils.corporateBlue600,
                            activeTrackColor: ColorUtils.corporateBlue600
                                .withValues(alpha: 0.4),
                            onChanged: (bool value) {
                              setState(() {
                                _showAllTeachers = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Gender Section
                    Row(
                      children: [
                        Icon(
                          Icons.transgender_rounded,
                          size: 16,
                          color: ColorUtils.slate600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Gender',
                            'id': 'Jenis Kelamin',
                          }),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TeacherStatusChip(
                          label: languageProvider.getTranslatedText({
                            'en': 'All',
                            'id': 'Semua',
                          }),
                          value: null,
                          selectedValue: _tempSelectedGender,
                          onSelected: () {
                            setState(() {
                              _tempSelectedGender = null;
                            });
                          },
                        ),
                        ...widget.availableGenders.map((gender) {
                          return TeacherStatusChip(
                            label: gender['label'],
                            value: gender['value'].toString(),
                            selectedValue: _tempSelectedGender,
                            onSelected: () {
                              setState(() {
                                _tempSelectedGender =
                                    gender['value'].toString();
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Employment Status Section
                    Row(
                      children: [
                        Icon(
                          Icons.work_outline_rounded,
                          size: 16,
                          color: ColorUtils.slate600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Employment Status',
                            'id': 'Status Kepegawaian',
                          }),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TeacherStatusChip(
                          label: languageProvider.getTranslatedText({
                            'en': 'All',
                            'id': 'Semua',
                          }),
                          value: null,
                          selectedValue: _tempSelectedEmploymentStatus,
                          onSelected: () {
                            setState(() {
                              _tempSelectedEmploymentStatus = null;
                            });
                          },
                        ),
                        ...widget.availableEmploymentStatus.map((status) {
                          return TeacherStatusChip(
                            label: status['label'],
                            value: status['value'].toString(),
                            selectedValue: _tempSelectedEmploymentStatus,
                            onSelected: () {
                              setState(() {
                                _tempSelectedEmploymentStatus =
                                    status['value'].toString();
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Teaching Class Section
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: ColorUtils.slate600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Teaching Class',
                            'id': 'Kelas Ajar',
                          }),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        border: Border.all(color: ColorUtils.slate200),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _tempSelectedTeachingClass,
                          hint: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Select Class',
                              'id': 'Pilih Kelas',
                            }),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Clear Selection',
                                  'id': 'Hapus Pilihan',
                                }),
                              ),
                            ),
                            ...widget.availableClass.map((classItem) {
                              return DropdownMenuItem<String>(
                                value: classItem['id'].toString(),
                                child: Text(classItem['name'].toString()),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _tempSelectedTeachingClass = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Homeroom Status Section
                    Row(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 16,
                          color: ColorUtils.slate600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Homeroom Teacher Status',
                            'id': 'Status Wali Kelas',
                          }),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TeacherStatusChip(
                          label: languageProvider.getTranslatedText({
                            'en': 'All',
                            'id': 'Semua',
                          }),
                          value: null,
                          selectedValue: _tempSelectedHomeroom,
                          onSelected: () {
                            setState(() {
                              _tempSelectedHomeroom = null;
                            });
                          },
                        ),
                        TeacherStatusChip(
                          label: languageProvider.getTranslatedText({
                            'en': 'Homeroom Teacher',
                            'id': 'Wali Kelas',
                          }),
                          value: 'wali_kelas',
                          selectedValue: _tempSelectedHomeroom,
                          onSelected: () {
                            setState(() {
                              _tempSelectedHomeroom = 'wali_kelas';
                            });
                          },
                        ),
                        TeacherStatusChip(
                          label: languageProvider.getTranslatedText({
                            'en': 'Regular Teacher',
                            'id': 'Bukan Wali Kelas',
                          }),
                          value: 'guru_biasa',
                          selectedValue: _tempSelectedHomeroom,
                          onSelected: () {
                            setState(() {
                              _tempSelectedHomeroom = 'guru_biasa';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer Buttons (Pattern #11)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: ColorUtils.slate200),
                ),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                          _tempSelectedHomeroom,
                          _tempSelectedGender,
                          _tempSelectedEmploymentStatus,
                          _tempSelectedTeachingClass,
                          _showAllTeachers,
                        );
                        AppNavigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.corporateBlue600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Apply Filter',
                          'id': 'Terapkan Filter',
                        }),
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
