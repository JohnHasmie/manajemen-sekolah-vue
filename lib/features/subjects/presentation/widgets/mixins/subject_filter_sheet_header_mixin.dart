import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin providing header building for filter sheet.
mixin SubjectFilterSheetHeaderMixin {
  /// Provides access to BuildContext for media queries.
  BuildContext get context;

  /// Provides access to ref for language translation.
  WidgetRef get ref;

  /// Provides access to setState.
  void setState(VoidCallback fn);

  /// Public abstract getter to access temp status.
  String? getTempStatus();

  /// Public abstract setter to modify temp status.
  void setTempStatus(String? value);

  /// Public abstract getter to access temp class status.
  String? getTempClassStatus();

  /// Public abstract setter to modify temp class status.
  void setTempClassStatus(String? value);

  /// Public abstract getter to access temp grade level.
  String? getTempGradeLevel();

  /// Public abstract setter to modify temp grade level.
  void setTempGradeLevel(String? value);

  /// Public abstract getter to access temp class name.
  String? getTempClassName();

  /// Public abstract setter to modify temp class name.
  void setTempClassName(String? value);

  /// Handles reset button press.
  void _onResetPressed() {
    setState(() {
      setTempStatus(null);
      setTempClassStatus(null);
      setTempGradeLevel(null);
      setTempClassName(null);
    });
  }

  /// Builds the filter icon box.
  Widget _buildFilterIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(Icons.filter_list, color: Colors.white, size: 20),
    );
  }

  /// Builds the header title.
  Widget _buildHeaderTitle(String title) {
    return Expanded(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Builds the reset button.
  Widget _buildResetButton(String resetText) {
    return TextButton(
      onPressed: _onResetPressed,
      child: Text(
        resetText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  /// Builds the gradient header with title and reset button.
  Widget buildHeader() {
    final lang = ref.watch(languageRiverpod);
    final title = lang.getTranslatedText({
      'en': 'Filter Subjects',
      'id': 'Filter Mata Pelajaran',
    });
    final resetText = lang.getTranslatedText({'en': 'Reset', 'id': 'Reset'});

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
        children: [
          _buildFilterIcon(),
          const SizedBox(width: AppSpacing.md),
          _buildHeaderTitle(title),
          _buildResetButton(resetText),
        ],
      ),
    );
  }
}
