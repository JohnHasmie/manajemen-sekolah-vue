import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';

mixin GradeRecapFilterMixin on ConsumerState<GradeRecapOverviewPage> {
  // State variables (declared in state class)
  late String? filterClassId;
  late String? filterClassName;
  late String? filterSubjectId;
  late String? filterSubjectName;
  late Color primaryColor;

  void clearFilters() {
    setState(() {
      filterClassId = null;
      filterClassName = null;
      filterSubjectId = null;
      filterSubjectName = null;
    });
    loadData();
  }

  Widget buildFilterChips() {
    final filters = <ActiveFilter>[
      if (filterClassName != null)
        ActiveFilter(
          label: filterClassName!,
          onRemove: () {
            setState(() {
              filterClassId = null;
              filterClassName = null;
            });
            loadData();
          },
        ),
      if (filterSubjectName != null)
        ActiveFilter(
          label: filterSubjectName!,
          onRemove: () {
            setState(() {
              filterSubjectId = null;
              filterSubjectName = null;
            });
            loadData();
          },
        ),
    ];
    if (filters.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      child: ActiveFilterChips(
        filters: filters,
        primaryColor: primaryColor,
        onClearAll: clearFilters,
      ),
    );
  }

  Widget filterSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget filterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : ColorUtils.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryColor : ColorUtils.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? primaryColor : ColorUtils.slate600,
          ),
        ),
      ),
    );
  }

  // Methods/getters that subclasses must provide
  Future<void> loadData({bool useCache = true});
  List<Map<String, String>> get availableClasses;
}
