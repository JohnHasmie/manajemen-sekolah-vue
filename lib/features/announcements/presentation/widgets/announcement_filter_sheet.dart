// Filter bottom sheet for admin announcement screen.
//
// Extracted from AdminAnnouncementScreenState._showFilterSheet().
// Accepts initial filter values and fires onApply with the chosen values.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Bottom-sheet widget for filtering announcements by priority, target, and status.
///
/// Like a Vue modal component that emits events back to the parent:
/// `onApply` fires when the user taps "Apply Filter".
class AnnouncementFilterSheet extends StatefulWidget {
  final String? initialPriority;
  final String? initialTarget;
  final String? initialStatus;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final void Function(
    String? priority,
    String? target,
    String? status,
  ) onApply;

  const AnnouncementFilterSheet({
    super.key,
    this.initialPriority,
    this.initialTarget,
    this.initialStatus,
    required this.primaryColor,
    required this.languageProvider,
    required this.onApply,
  });

  @override
  State<AnnouncementFilterSheet> createState() =>
      _AnnouncementFilterSheetState();
}

class _AnnouncementFilterSheetState extends State<AnnouncementFilterSheet> {
  String? _tempSelectedPrioritas;
  String? _tempSelectedTarget;
  String? _tempSelectedStatus;

  @override
  void initState() {
    super.initState();
    _tempSelectedPrioritas = widget.initialPriority;
    _tempSelectedTarget = widget.initialTarget;
    _tempSelectedStatus = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = widget.languageProvider;
    final primaryColor = widget.primaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // --- Pattern #11 Gradient Header ---
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.8),
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
                    Icon(
                      Icons.filter_list_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Filter',
                        'id': 'Filter',
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
                      _tempSelectedPrioritas = null;
                      _tempSelectedTarget = null;
                      _tempSelectedStatus = null;
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

          // --- Filter Content ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority Filter
                  Row(
                    children: [
                      Icon(
                        Icons.priority_high,
                        size: 16,
                        color: ColorUtils.slate600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Priority',
                          'id': 'Prioritas',
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
                    children: ['Penting', 'Biasa'].map((prioritas) {
                      final isSelected = _tempSelectedPrioritas == prioritas;
                      return FilterChip(
                        label: Text(prioritas),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _tempSelectedPrioritas =
                                selected ? prioritas : null;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: primaryColor.withValues(alpha: 0.15),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? primaryColor
                              : ColorUtils.slate700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        side: BorderSide(
                          color:
                              isSelected ? primaryColor : ColorUtils.slate300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Target Filter
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: ColorUtils.slate600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Target',
                          'id': 'Target',
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
                    ].map((item) {
                      final isSelected = _tempSelectedTarget == item['value'];
                      return FilterChip(
                        label: Text(item['label']!),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _tempSelectedTarget =
                                selected ? item['value'] : null;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: primaryColor.withValues(alpha: 0.15),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? primaryColor
                              : ColorUtils.slate700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        side: BorderSide(
                          color:
                              isSelected ? primaryColor : ColorUtils.slate300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Status Filter
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: ColorUtils.slate600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Status',
                          'id': 'Status',
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
                    ].map((item) {
                      final isSelected = _tempSelectedStatus == item['value'];
                      return FilterChip(
                        label: Text(item['label']!),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _tempSelectedStatus =
                                selected ? item['value'] : null;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: primaryColor.withValues(alpha: 0.15),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? primaryColor
                              : ColorUtils.slate700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        side: BorderSide(
                          color:
                              isSelected ? primaryColor : ColorUtils.slate300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // --- Pattern #11 Footer ---
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
                        _tempSelectedPrioritas,
                        _tempSelectedTarget,
                        _tempSelectedStatus,
                      );
                      AppNavigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
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
    );
  }
}
