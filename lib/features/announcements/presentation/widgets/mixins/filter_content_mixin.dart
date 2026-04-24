import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

mixin FilterContentMixin {
  // Abstract state access
  void setState(VoidCallback fn);
  BuildContext get context;

  // State getters/setters
  String? get tempSelectedPrioritas;
  set tempSelectedPrioritas(String? value);

  String? get tempSelectedTarget;
  set tempSelectedTarget(String? value);

  String? get tempSelectedStatus;
  set tempSelectedStatus(String? value);

  // Access to widget properties
  LanguageProvider get languageProvider;
  Color get primaryColor;

  /// Builds the main filter content with three sections.
  Widget buildFilterContent() {
    return TeacherFilterContent(
      sections: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Priority',
                'id': 'Prioritas',
              }),
              icon: Icons.priority_high_rounded,
              primaryColor: primaryColor,
            ),
            FilterChipGrid<String>(
              options: [
                'Penting',
                'Biasa',
              ].map((p) => FilterOption(value: p, label: p)).toList(),
              selectedValue: tempSelectedPrioritas,
              onSelected: (val) => setState(() => tempSelectedPrioritas = val),
              selectedColor: primaryColor,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Target',
                'id': 'Target',
              }),
              icon: Icons.people_outline_rounded,
              primaryColor: primaryColor,
            ),
            FilterChipGrid<String>(
              options: _buildTargetOptions()
                  .map(
                    (o) => FilterOption(value: o['value']!, label: o['label']!),
                  )
                  .toList(),
              selectedValue: tempSelectedTarget,
              onSelected: (val) => setState(() => tempSelectedTarget = val),
              selectedColor: primaryColor,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Status',
                'id': 'Status',
              }),
              icon: Icons.info_outline_rounded,
              primaryColor: primaryColor,
            ),
            FilterChipGrid<String>(
              options: _buildStatusOptions()
                  .map(
                    (o) => FilterOption(value: o['value']!, label: o['label']!),
                  )
                  .toList(),
              selectedValue: tempSelectedStatus,
              onSelected: (val) => setState(() => tempSelectedStatus = val),
              selectedColor: primaryColor,
            ),
          ],
        ),
      ],
    );
  }

  /// Returns the list of target options.
  List<Map<String, String>> _buildTargetOptions() {
    return [
      {
        'value': 'Semua',
        'label': languageProvider.getTranslatedText({
          'en': 'All',
          'id': 'Semua',
        }),
      },
      {
        'value': 'Guru',
        'label': languageProvider.getTranslatedText({
          'en': 'Teachers',
          'id': 'Guru',
        }),
      },
      {
        'value': 'Siswa',
        'label': languageProvider.getTranslatedText({
          'en': 'Students',
          'id': 'Siswa',
        }),
      },
      {
        'value': 'Orang Tua',
        'label': languageProvider.getTranslatedText({
          'en': 'Parents',
          'id': 'Orang Tua',
        }),
      },
    ];
  }

  /// Returns the list of status options.
  List<Map<String, String>> _buildStatusOptions() {
    return [
      {
        'value': 'Aktif',
        'label': languageProvider.getTranslatedText({
          'en': 'Active',
          'id': 'Aktif',
        }),
      },
      {
        'value': 'Terjadwal',
        'label': languageProvider.getTranslatedText({
          'en': 'Scheduled',
          'id': 'Terjadwal',
        }),
      },
      {
        'value': 'Kedaluwarsa',
        'label': languageProvider.getTranslatedText({
          'en': 'Expired',
          'id': 'Kedaluwarsa',
        }),
      },
    ];
  }
}
