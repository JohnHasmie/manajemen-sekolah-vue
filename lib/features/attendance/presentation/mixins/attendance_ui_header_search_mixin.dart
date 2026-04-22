import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Builds search-related header components:
/// search fields, view toggle, and filter buttons.
mixin AttendanceUIHeaderSearchMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──
  Color get primaryColor;
  bool get isTimelineView;
  bool get hasActiveFilter;

  TextEditingController get searchController;

  void toggleView();
  void showFilterDialog(LanguageProvider lp);

  Future<void> refreshGroupedAttendance();

  Widget _buildViewToggleBtn() {
    return GestureDetector(
      onTap: toggleView,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isTimelineView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildSearchRow(LanguageProvider lp, Color p) {
    return Row(
      children: [
        Expanded(child: _buildSearchField(lp, p)),
        const SizedBox(width: AppSpacing.sm),
        _buildFilterButton(lp, p),
      ],
    );
  }

  Widget _buildSearchField(LanguageProvider lp, Color p) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: lp.getTranslatedText({
                  'en': 'Search class or subject...',
                  'id': 'Cari kelas atau mapel...',
                }),
                hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) {
                refreshGroupedAttendance();
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(Icons.search, color: p, size: 20),
              onPressed: () {
                refreshGroupedAttendance();
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(LanguageProvider lp, Color p) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: hasActiveFilter
            ? Colors.white
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: () => showFilterDialog(lp),
            icon: Icon(
              Icons.tune,
              color: hasActiveFilter ? p : Colors.white,
              size: 20,
            ),
          ),
          if (hasActiveFilter)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ColorUtils.error600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static LinearGradient _getCardGradient() {
    final p = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [p, p.withValues(alpha: 0.7)],
    );
  }

  static Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  Widget buildMainScreenHeaderPart(LanguageProvider lp, Color p) {
    return Column(
      children: [
        _buildHeaderTopRow(lp, p),
        const SizedBox(height: AppSpacing.md),
        _buildSearchRow(lp, p),
      ],
    );
  }

  Widget _buildHeaderTopRow(LanguageProvider lp, Color p) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => AppNavigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildHeaderTitle(lp)),
        _buildViewToggleBtn(),
      ],
    );
  }

  Widget _buildHeaderTitle(LanguageProvider lp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lp.getTranslatedText({'en': 'Attendance', 'id': 'Presensi'}),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isHomeroomView && selectedHomeroomClass != null
              ? lp.getTranslatedText({
                  'en': 'Homeroom class attendance overview',
                  'id': 'Rekap presensi kelas perwalian',
                })
              : lp.getTranslatedText({
                  'en':
                      'Track and manage student '
                      'attendance',
                  'id': 'Pantau dan kelola presensi siswa',
                }),
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  bool get isHomeroomView;
  Map<String, dynamic>? get selectedHomeroomClass;
}
