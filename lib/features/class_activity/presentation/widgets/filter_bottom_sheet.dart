// Filter bottom sheet widget for the class-activity screen.
// Extracted from teacher_class_activity_screen.dart to reduce file size.
// Like a Vue child component that emits 'apply' with the selected filter values.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Bottom sheet that lets the user pick a date-range filter
/// ('today', 'week', or 'month').
///
/// Call [FilterBottomSheet.show] to display it.
/// [onApply] is called with the selected filter value (or null to clear).
class FilterBottomSheet extends StatefulWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String? initialDateFilter;
  final void Function(String? dateFilter) onApply;

  const FilterBottomSheet({
    super.key,
    required this.primaryColor,
    required this.languageProvider,
    required this.initialDateFilter,
    required this.onApply,
  });

  /// Helper to open this sheet as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required Color primaryColor,
    required LanguageProvider languageProvider,
    required String? initialDateFilter,
    required void Function(String? dateFilter) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        initialDateFilter: initialDateFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String? _tempDateFilter;

  @override
  void initState() {
    super.initState();
    _tempDateFilter = widget.initialDateFilter;
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: widget.primaryColor),
          ),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, String? selectedValue) {
    final isSelected = selectedValue == value;
    return GestureDetector(
      onTap: () => setState(
        () => _tempDateFilter = isSelected ? null : value,
      ),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.primaryColor.withValues(alpha: 0.1)
              : ColorUtils.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? widget.primaryColor : ColorUtils.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? widget.primaryColor : ColorUtils.slate600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = widget.languageProvider;
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.primaryColor,
                  widget.primaryColor.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Filter Activities',
                          'id': 'Filter Kegiatan',
                        }),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _tempDateFilter = null),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        backgroundColor: Colors.white.withValues(
                          alpha: 0.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Reset',
                          'id': 'Reset',
                        }),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    languageProvider.getTranslatedText({
                      'en': 'Date Range',
                      'id': 'Rentang Tanggal',
                    }),
                    Icons.calendar_today_rounded,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        languageProvider.getTranslatedText({
                          'en': 'Today',
                          'id': 'Hari Ini',
                        }),
                        'today',
                        _tempDateFilter,
                      ),
                      _buildChip(
                        languageProvider.getTranslatedText({
                          'en': 'This Week',
                          'id': 'Minggu Ini',
                        }),
                        'week',
                        _tempDateFilter,
                      ),
                      _buildChip(
                        languageProvider.getTranslatedText({
                          'en': 'This Month',
                          'id': 'Bulan Ini',
                        }),
                        'month',
                        _tempDateFilter,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        foregroundColor: ColorUtils.slate700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        AppNavigator.pop(context);
                        widget.onApply(_tempDateFilter);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Apply Filter',
                          'id': 'Terapkan Filter',
                        }),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
