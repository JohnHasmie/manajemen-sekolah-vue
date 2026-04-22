import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';

/// UI-related methods for TeacherAdminScreen
/// Responsible for building UI components like filter chips
mixin TeacherUiMixin on ConsumerState<TeacherAdminScreen> {
  // Abstract bridge to state
  String? get selectedClassId;
  String? get selectedHomeroomFilter;
  String? get selectedGender;
  String? get selectedEmploymentStatus;
  String? get selectedTeachingClassId;
  bool get hasActiveFilter;

  List<dynamic> get availableClass;
  List<dynamic> get availableGenders;
  List<dynamic> get availableEmploymentStatus;

  Future<void> loadData({bool resetPage = true, bool useCache = true});
  void checkActiveFilter();

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  List<Widget> buildFilterChipWidgets() {
    final languageProvider = ref.read(languageRiverpod);
    final chips = buildFilterChips(languageProvider);
    return chips.map((filter) {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        child: Chip(
          label: Text(
            filter['label'],
            style: TextStyle(
              fontSize: 12,
              color: _getPrimaryColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
          deleteIcon: Icon(Icons.close, size: 16, color: _getPrimaryColor()),
          onDeleted: filter['onRemove'],
          backgroundColor: _getPrimaryColor().withValues(alpha: 0.1),
          side: BorderSide(
            color: _getPrimaryColor().withValues(alpha: 0.3),
            width: 1,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          labelPadding: const EdgeInsets.only(left: 4),
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> buildFilterChips(
    LanguageProvider languageProvider,
  );
}
