import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A premium section header for filter sheets with a tinted leading icon
/// and a bold title.
///
/// The [icon] parameter is optional — when omitted, [FilterSectionHeader]
/// auto-detects an appropriate icon from the [title] text using common
/// filter-type keywords (class, subject, status, grade, time, day, gender,
/// semester, etc.). Pass an explicit [icon] to override.
///
/// Example:
/// ```dart
/// // Auto-detect: title "Kelas" → Icons.class_outlined
/// FilterSectionHeader(title: 'Kelas', primaryColor: color)
///
/// // Explicit override
/// FilterSectionHeader(
///   title: 'Kelas',
///   icon: Icons.school,
///   primaryColor: color,
/// )
/// ```
class FilterSectionHeader extends StatelessWidget {
  /// The section title text.
  final String title;

  /// The leading icon. When null, auto-detected from [title].
  final IconData? icon;

  /// The primary color used for the icon and its tinted background.
  final Color primaryColor;

  /// Optional padding around the header. Defaults to `top: 0, bottom: 10`
  /// — the section header itself does NOT add leading whitespace. Inter-
  /// section spacing is the responsibility of the surrounding list (e.g.
  /// [TeacherFilterContent] via its `sectionSpacing`). Keeping the header
  /// flush-top lets the first section sit right below the bottom-sheet's
  /// gradient bar without an awkward 40+ px gap.
  final EdgeInsets padding;

  const FilterSectionHeader({
    super.key,
    required this.title,
    this.icon,
    required this.primaryColor,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  /// Resolves an icon from the title text by matching common keywords.
  ///
  /// Checks the lowercased [title] against known filter-type keywords.
  /// Returns [Icons.filter_list_rounded] as a safe fallback.
  static IconData resolveIcon(String title) {
    final lower = title.toLowerCase();

    // Class / Kelas — door with people
    if (lower.contains('kelas') || lower.contains('class')) {
      return Icons.meeting_room_outlined;
    }
    // Subject / Mata Pelajaran / Mapel — open book
    if (lower.contains('mapel') ||
        lower.contains('mata pelajaran') ||
        lower.contains('subject')) {
      return Icons.menu_book_rounded;
    }
    // Status — checklist
    if (lower.contains('status')) {
      return Icons.checklist_rounded;
    }
    // Grade level / Tingkat — stacked layers
    if (lower.contains('grade') ||
        lower.contains('tingkat') ||
        lower.contains('level')) {
      return Icons.layers_outlined;
    }
    // Day / Hari — single day on calendar
    if (lower.contains('hari') || lower.contains('day')) {
      return Icons.today_rounded;
    }
    // Time range / Rentang Waktu — date range
    if (lower.contains('waktu') ||
        lower.contains('time') ||
        lower.contains('rentang')) {
      return Icons.date_range_rounded;
    }
    // Semester — academic cap
    if (lower.contains('semester') || lower.contains('term')) {
      return Icons.school_outlined;
    }
    // Lesson hour / Jam Pelajaran — clock
    if (lower.contains('jam') ||
        lower.contains('hour') ||
        lower.contains('lesson hour')) {
      return Icons.schedule_rounded;
    }
    // Gender / Jenis Kelamin — person figures
    if (lower.contains('gender') || lower.contains('kelamin')) {
      return Icons.wc_rounded;
    }
    // Guardian / Wali Murid — family
    if (lower.contains('wali') || lower.contains('guardian')) {
      return Icons.family_restroom_rounded;
    }
    // Priority / Prioritas — flag
    if (lower.contains('prioritas') || lower.contains('priority')) {
      return Icons.flag_rounded;
    }
    // Target / Sasaran — group of people
    if (lower.contains('target') || lower.contains('sasaran')) {
      return Icons.groups_outlined;
    }
    // Teacher / Guru / Homeroom
    if (lower.contains('guru') ||
        lower.contains('teacher') ||
        lower.contains('homeroom')) {
      return Icons.person_outline_rounded;
    }
    // Payment / Pembayaran — wallet
    if (lower.contains('payment') || lower.contains('pembayaran')) {
      return Icons.account_balance_wallet_outlined;
    }
    // Month / Bulan — calendar month view
    if (lower.contains('bulan') || lower.contains('month')) {
      return Icons.calendar_month_rounded;
    }
    // Period / Periode — repeating event
    if (lower.contains('period') || lower.contains('periode')) {
      return Icons.event_repeat_rounded;
    }
    // Employment / Kepegawaian — badge
    if (lower.contains('employment') || lower.contains('kepegawaian')) {
      return Icons.badge_outlined;
    }

    // Fallback
    return Icons.filter_list_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = icon ?? resolveIcon(title);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              resolvedIcon,
              size: 16,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 10),
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
}
