import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';

mixin FilterMixin on ConsumerState<ReportCardOverviewPage> {
  String? get filterStatus;
  set filterStatus(String? value);

  Color get primaryColor => ColorUtils.getRoleColor('guru');

  int get activeFilterCount => (filterStatus != null ? 1 : 0);

  void clearFilters() {
    setState(() => filterStatus = null);
  }

  List<dynamic> getFilteredData(List<dynamic> classData, String searchQuery) {
    var list = classData;
    if (searchQuery.isNotEmpty) {
      list = list
          .where(
            (c) => (c['class_name']?.toString() ?? '').toLowerCase().contains(
              searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }
    if (filterStatus != null) {
      list = list.where((c) {
        // Backend rename: `total_raports` → `total_report_cards`.
        final total = c['total_report_cards'] ?? c['total_raports'] ?? 0;
        final draft = c['draft_count'] ?? 0;
        final studentCount = c['student_count'] ?? 0;
        switch (filterStatus) {
          case 'incomplete':
            return total < studentCount;
          case 'draft':
            return draft > 0;
          case 'complete':
            return total >= studentCount && draft == 0 && studentCount > 0;
          default:
            return true;
        }
      }).toList();
    }
    return list;
  }

  Widget buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 14, color: primaryColor),
          const SizedBox(width: 6),
          if (filterStatus != null)
            buildFilterChip(
              getFilterStatusLabel(),
              () => setState(() => filterStatus = null),
            ),
          const Spacer(),
          GestureDetector(
            onTap: clearFilters,
            child: Text(
              'Hapus',
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.error600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: primaryColor),
          ),
        ],
      ),
    );
  }

  String getFilterStatusLabel() {
    switch (filterStatus) {
      case 'incomplete':
        return 'Belum Lengkap';
      case 'draft':
        return 'Ada Draft';
      case 'complete':
        return 'Selesai';
      default:
        return '';
    }
  }

  void showFilterDialog(LanguageProvider lp);
}
