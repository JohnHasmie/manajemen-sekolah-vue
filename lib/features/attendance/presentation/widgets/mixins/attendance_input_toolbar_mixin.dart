// UI builder methods for AttendanceInputMode toolbar section.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/status_chip.dart';

/// Abstract contract for state required by the mixin.
abstract class _InputToolbarStateGetter {
  /// Language provider for translations.
  LanguageProvider get toolbarLanguage;

  /// Primary color for toolbar buttons.
  Color get toolbarPrimaryColor;

  /// Filtered list of students to check if empty.
  List<dynamic> get toolbarFilteredStudents;

  /// Attendance status map for counting.
  Map<String, String> get toolbarAttendanceStatus;

  /// Callback when search changes.
  VoidCallback get onToolbarSearchChanged;

  /// Callback when quick actions pressed.
  VoidCallback get onToolbarQuickActionsPressed;

  /// Search controller for the toolbar.
  TextEditingController get toolbarSearchController;

  /// Bulk-row chip — override every student → hadir.
  /// Optional. When null the chip is hidden.
  VoidCallback? get onToolbarMarkAllHadir;

  /// Bulk-row chip — fill students without a status with alpa.
  /// Optional. When null the chip is hidden.
  VoidCallback? get onToolbarFillRemainingAlpa;
}

/// UI builder methods for the attendance input toolbar.
mixin AttendanceInputToolbarMixin implements _InputToolbarStateGetter {
  // Required from State.
  void setState(VoidCallback fn);
  BuildContext get context;

  /// Builds the complete toolbar with search, buttons, and status chips.
  Widget buildToolbar() {
    final primary = toolbarPrimaryColor;
    final lang = toolbarLanguage;
    final tr = lang.getTranslatedText;

    final counts = _countAttendanceStatuses();
    final total = toolbarAttendanceStatus.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          _buildSearchRow(primary, tr),
          if (toolbarFilteredStudents.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildStatusChipsRow(
              counts['hadir']!,
              counts['terlambat']!,
              counts['sakit']!,
              counts['izin']!,
              counts['alpha']!,
              total,
              primary,
              tr,
            ),
          ],
          // Frame A bulk-row — "● Semua Hadir" + "● Sisanya Alpa".
          // Visible when at least one student is in the list and the
          // page wired the optional callbacks.
          if (toolbarFilteredStudents.isNotEmpty &&
              (onToolbarMarkAllHadir != null ||
                  onToolbarFillRemainingAlpa != null)) ...[
            const SizedBox(height: 8),
            _buildBulkRow(tr),
          ],
        ],
      ),
    );
  }

  /// Two-chip bulk row that mirrors the mockup's `.bulk-row` block.
  /// Each chip has a colored dot + label and fires the corresponding
  /// callback. Either chip can be null-and-hidden so the row degrades
  /// gracefully on read-only screens.
  Widget _buildBulkRow(String Function(Map<String, String>) tr) {
    return Row(
      children: [
        if (onToolbarMarkAllHadir != null)
          Expanded(
            child: _BulkChip(
              label: tr({'en': 'All Present', 'id': 'Semua Hadir'}),
              dotColor: ColorUtils.success600,
              onTap: onToolbarMarkAllHadir!,
            ),
          ),
        if (onToolbarMarkAllHadir != null && onToolbarFillRemainingAlpa != null)
          const SizedBox(width: 8),
        if (onToolbarFillRemainingAlpa != null)
          Expanded(
            child: _BulkChip(
              label: tr({'en': 'Remaining Absent', 'id': 'Sisanya Alpa'}),
              dotColor: ColorUtils.error600,
              onTap: onToolbarFillRemainingAlpa!,
            ),
          ),
      ],
    );
  }

  /// Counts attendance statuses from the map.
  Map<String, int> _countAttendanceStatuses() {
    int hadir = 0, terlambat = 0, sakit = 0, izin = 0, alpha = 0;
    for (final status in toolbarAttendanceStatus.values) {
      switch (status.toLowerCase()) {
        case 'hadir':
          hadir++;
        case 'terlambat':
          terlambat++;
        case 'sakit':
          sakit++;
        case 'izin':
          izin++;
        case 'alpha':
          alpha++;
        default:
          hadir++;
      }
    }
    return {
      'hadir': hadir,
      'terlambat': terlambat,
      'sakit': sakit,
      'izin': izin,
      'alpha': alpha,
    };
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

  /// Builds the search text field with icon.
  Widget _buildSearchField(
    Color primary,
    String Function(Map<String, String>) tr,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSearchTextField(tr)),
          _buildSearchIconButton(primary),
        ],
      ),
    );
  }

  /// Builds the search text field.
  Widget _buildSearchTextField(String Function(Map<String, String>) tr) {
    return TextField(
      controller: toolbarSearchController,
      onChanged: (_) => onToolbarSearchChanged(),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: tr({'en': 'Search student...', 'id': 'Cari siswa...'}),
        hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  /// Builds the search icon button.
  Widget _buildSearchIconButton(Color primary) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: Icon(Icons.search, color: primary, size: 20),
        onPressed: () => FocusScope.of(context).unfocus(),
      ),
    );
  }

  /// Builds the quick actions button.
  Widget _buildQuickActionsButton(
    Color primary,
    String Function(Map<String, String>) tr,
  ) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: IconButton(
        onPressed: onToolbarQuickActionsPressed,
        icon: Icon(Icons.checklist_rtl, color: primary, size: 20),
        tooltip: tr({'en': 'Quick Attendance', 'id': 'Presensi Cepat'}),
      ),
    );
  }

  /// Builds the row of status chips and total count.
  Widget _buildStatusChipsRow(
    int hadir,
    int terlambat,
    int sakit,
    int izin,
    int alpha,
    int total,
    Color primary,
    String Function(Map<String, String>) tr,
  ) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._buildStatusChips(
            hadir,
            terlambat,
            sakit,
            izin,
            alpha,
            primary,
            tr,
          ),
          const SizedBox(width: 8),
          _buildTotalChip(total, tr),
        ],
      ),
    );
  }

  /// Builds individual status chips.
  List<Widget> _buildStatusChips(
    int hadir,
    int terlambat,
    int sakit,
    int izin,
    int alpha,
    Color primary,
    String Function(Map<String, String>) tr,
  ) {
    final chips = [
      (tr({'en': 'Present', 'id': 'Hadir'}), hadir, ColorUtils.success600),
      (tr({'en': 'Late', 'id': 'Terlambat'}), terlambat, ColorUtils.violet700),
      (tr({'en': 'Sick', 'id': 'Sakit'}), sakit, ColorUtils.warning600),
      (tr({'en': 'Permission', 'id': 'Izin'}), izin, ColorUtils.info600),
      (tr({'en': 'Absent', 'id': 'Alpha'}), alpha, ColorUtils.error600),
    ];

    final widgets = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      final (label, count, color) = chips[i];
      widgets.add(
        StatusChip(
          label: label,
          count: count,
          color: color,
          isSelected: count > 0,
          primary: primary,
        ),
      );
      if (i < chips.length - 1) {
        widgets.add(const SizedBox(width: 6));
      }
    }
    return widgets;
  }

  /// Builds the total count chip.
  Widget _buildTotalChip(int total, String Function(Map<String, String>) tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        '$total ${tr({'en': 'students', 'id': 'siswa'})}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate600,
        ),
      ),
    );
  }
}

/// Frame A bulk-row chip — colored dot + label inside a dashed pill.
class _BulkChip extends StatelessWidget {
  final String label;
  final Color dotColor;
  final VoidCallback onTap;

  const _BulkChip({
    required this.label,
    required this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ColorUtils.slate200,
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
