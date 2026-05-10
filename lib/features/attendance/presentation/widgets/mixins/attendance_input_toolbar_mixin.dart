// UI builder methods for AttendanceInputMode toolbar section.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Abstract contract for state required by the mixin.
///
/// Trimmed alongside the toolbar simplification: the inline status
/// chip row + bulk-row chips were retired (counts live in the brand
/// KPI strip above; bulk actions live in Aksi cepat), so the
/// per-student-status getters they relied on are no longer needed
/// here.
abstract class _InputToolbarStateGetter {
  /// Language provider for translations.
  LanguageProvider get toolbarLanguage;

  /// Primary color for toolbar buttons.
  Color get toolbarPrimaryColor;

  /// Callback when search changes.
  VoidCallback get onToolbarSearchChanged;

  /// Callback when quick actions pressed.
  VoidCallback get onToolbarQuickActionsPressed;

  /// Search controller for the toolbar.
  TextEditingController get toolbarSearchController;
}

/// UI builder methods for the attendance input toolbar.
mixin AttendanceInputToolbarMixin implements _InputToolbarStateGetter {
  // Required from State.
  void setState(VoidCallback fn);
  BuildContext get context;

  /// Builds the toolbar — just the search row + Aksi cepat trigger.
  ///
  /// The status chip row was removed: the four counts are already
  /// shown in the brand KPI strip above (Hadir · Sakit · Izin · Alpa)
  /// so the inline chips just duplicated information and ate vertical
  /// space. The bulk-row "Semua Hadir / Sisanya Alpa" was retired
  /// earlier for the same reason — Aksi cepat hosts both actions.
  Widget buildToolbar() {
    final primary = toolbarPrimaryColor;
    final lang = toolbarLanguage;
    final tr = lang.getTranslatedText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: _buildSearchRow(primary, tr),
    );
  }

  /// Builds search bar and quick actions row.
  Widget _buildSearchRow(
    Color primary,
    String Function(Map<String, String>) tr,
  ) {
    return Row(
      children: [
        Expanded(child: _buildSearchField(primary, tr)),
        const SizedBox(width: 8),
        _buildQuickActionsButton(primary, tr),
      ],
    );
  }

  /// Builds the compact search text field. Search icon lives inside
  /// the field as a prefix; the trailing IconButton was redundant
  /// (TextField submits on enter) and just ate horizontal space.
  Widget _buildSearchField(
    Color primary,
    String Function(Map<String, String>) tr,
  ) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: toolbarSearchController,
        onChanged: (_) => onToolbarSearchChanged(),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: tr({'en': 'Search student...', 'id': 'Cari siswa...'}),
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: primary, size: 18),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      ),
    );
  }

  /// Builds the quick actions button — square 40 to match the
  /// compact search field height.
  Widget _buildQuickActionsButton(
    Color primary,
    String Function(Map<String, String>) tr,
  ) {
    return SizedBox(
      height: 40,
      width: 40,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          onTap: onToolbarQuickActionsPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(color: ColorUtils.slate200),
            ),
            alignment: Alignment.center,
            child: Tooltip(
              message: tr({'en': 'Quick Attendance', 'id': 'Presensi Cepat'}),
              child: Icon(
                Icons.checklist_rtl,
                color: primary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
