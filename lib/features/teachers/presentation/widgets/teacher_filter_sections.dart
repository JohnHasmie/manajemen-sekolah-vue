import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

/// Gender filter section widget.
class TeacherGenderSection extends StatelessWidget {
  const TeacherGenderSection({
    super.key,
    required this.selectedValue,
    required this.availableGenders,
    required this.onSelected,
    required this.languageProvider,
    required this.primaryColor,
  });

  /// Currently selected gender value.
  final String? selectedValue;

  /// Available gender options from backend.
  final List<dynamic> availableGenders;

  /// Callback when a gender is selected.
  final Function(String?) onSelected;

  /// Language/translation provider.
  final dynamic languageProvider;

  /// Role color.
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: languageProvider.getTranslatedText({
            'en': 'Gender',
            'id': 'Jenis Kelamin',
          }),
          icon: Icons.transgender_rounded,
          primaryColor: primaryColor,
        ),
        FilterChipGrid<String?>(
          options: [
            FilterOption(
              value: null,
              label: languageProvider.getTranslatedText({
                'en': 'All',
                'id': 'Semua',
              }),
            ),
            ...availableGenders.map((gender) => FilterOption(
                  value: gender['value'].toString(),
                  label: gender['label'],
                )),
          ],
          selectedValue: selectedValue,
          onSelected: onSelected,
          selectedColor: primaryColor,
        ),
      ],
    );
  }
}

/// Employment status filter section widget.
class TeacherEmploymentStatusSection extends StatelessWidget {
  const TeacherEmploymentStatusSection({
    super.key,
    required this.selectedValue,
    required this.availableEmploymentStatus,
    required this.onSelected,
    required this.languageProvider,
    required this.primaryColor,
  });

  /// Currently selected employment status value.
  final String? selectedValue;

  /// Available employment status options.
  final List<dynamic> availableEmploymentStatus;

  /// Callback when employment status is selected.
  final Function(String?) onSelected;

  /// Language/translation provider.
  final dynamic languageProvider;

  /// Role color.
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: languageProvider.getTranslatedText({
            'en': 'Employment Status',
            'id': 'Status Kepegawaian',
          }),
          icon: Icons.work_outline_rounded,
          primaryColor: primaryColor,
        ),
        FilterChipGrid<String?>(
          options: [
            FilterOption(
              value: null,
              label: languageProvider.getTranslatedText({
                'en': 'All',
                'id': 'Semua',
              }),
            ),
            ...availableEmploymentStatus.map((status) => FilterOption(
                  value: status['value'].toString(),
                  label: status['label'],
                )),
          ],
          selectedValue: selectedValue,
          onSelected: onSelected,
          selectedColor: primaryColor,
        ),
      ],
    );
  }
}

/// Teaching class filter section widget.
class TeacherClassSection extends StatelessWidget {
  const TeacherClassSection({
    super.key,
    required this.selectedValue,
    required this.availableClass,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
  });

  /// Currently selected teaching class value.
  final String? selectedValue;

  /// Available class options from backend.
  final List<dynamic> availableClass;

  /// Callback when class selection changes.
  final ValueChanged<String?> onChanged;

  /// Language/translation provider.
  final dynamic languageProvider;

  /// Role color.
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: languageProvider.getTranslatedText({
            'en': 'Teaching Class',
            'id': 'Kelas Ajar',
          }),
          icon: Icons.school_outlined,
          primaryColor: primaryColor,
        ),
        FilterChipGrid<String?>(
          options: [
            FilterOption(
              value: null,
              label: languageProvider.getTranslatedText({
                'en': 'All',
                'id': 'Semua',
              }),
            ),
            ...availableClass.map((classItem) {
              final model = Classroom.fromJson(classItem as Map<String, dynamic>);
              return FilterOption(value: model.id, label: model.name);
            }),
          ],
          selectedValue: selectedValue,
          onSelected: onChanged,
          selectedColor: primaryColor,
        ),
      ],
    );
  }
}

/// Homeroom teacher status filter section widget.
class TeacherHomeroomSection extends StatelessWidget {
  const TeacherHomeroomSection({
    super.key,
    required this.selectedValue,
    required this.onSelected,
    required this.languageProvider,
    required this.primaryColor,
  });

  /// Currently selected homeroom status value.
  final String? selectedValue;

  /// Callback when homeroom status is selected.
  final Function(String?) onSelected;

  /// Language/translation provider.
  final dynamic languageProvider;

  /// Role color.
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: languageProvider.getTranslatedText({
            'en': 'Homeroom Teacher Status',
            'id': 'Status Wali Kelas',
          }),
          icon: Icons.groups_outlined,
          primaryColor: primaryColor,
        ),
        FilterChipGrid<String?>(
          options: [
            FilterOption(
              value: null,
              label: languageProvider.getTranslatedText({
                'en': 'All',
                'id': 'Semua',
              }),
            ),
            FilterOption(
              value: 'wali_kelas',
              label: languageProvider.getTranslatedText({
                'en': 'Homeroom Teacher',
                'id': 'Wali Kelas',
              }),
            ),
            FilterOption(
              value: 'guru_biasa',
              label: languageProvider.getTranslatedText({
                'en': 'Regular Teacher',
                'id': 'Bukan Wali Kelas',
              }),
            ),
          ],
          selectedValue: selectedValue,
          onSelected: onSelected,
          selectedColor: primaryColor,
        ),
      ],
    );
  }
}
