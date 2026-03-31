// Extracted export-month selection dialog for admin attendance report.
//
// Like a Vue modal component: receives academic-year data as props and
// emits an onExport callback with the list of months the user selected.
// All local checkbox state lives inside this widget -- the parent only
// reacts once the user confirms.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A dialog that lets an admin choose one or more months to export.
///
/// Like a Vue `<ExportMonthDialog>` component:
/// - [activeYearName]   – props: display name of the academic year, e.g. "2024/2025"
/// - [activeYearString] – props: slash-separated year string used to build the
///                        month grid, e.g. "2024/2025"
/// - [onExport]         – emit: fires with the sorted list of selected months
///                        so the parent can call its `_processExport` method
///
/// Call [AttendanceExportDialog.show] from the parent instead of constructing
/// this widget directly -- it wraps [showDialog] for you.
class AttendanceExportDialog extends ConsumerStatefulWidget {
  const AttendanceExportDialog({
    super.key,
    required this.activeYearName,
    required this.activeYearString,
    required this.onExport,
  });

  final String activeYearName;
  final String activeYearString;

  /// Called with the user's selected months (already sorted) when they tap Export.
  final void Function(List<DateTime> months) onExport;

  /// Convenience factory: presents this dialog via [showDialog].
  ///
  /// Reads the academic-year data from Riverpod internally so the call-site
  /// only needs the [onExport] callback -- like `this.$emit('export', months)`
  /// in Vue.
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required void Function(List<DateTime> months) onExport,
  }) {
    final academicYearProvider = ref.read(academicYearRiverpod);
    final activeYearName =
        academicYearProvider.selectedAcademicYear?['name'] as String? ??
        '${DateTime.now().year}/${DateTime.now().year + 1}';
    final activeYearString =
        academicYearProvider.selectedAcademicYear?['year']?.toString() ??
        '${DateTime.now().year}/${DateTime.now().year + 1}';

    showDialog(
      context: context,
      builder: (_) => AttendanceExportDialog(
        activeYearName: activeYearName,
        activeYearString: activeYearString,
        onExport: onExport,
      ),
    );
  }

  @override
  ConsumerState<AttendanceExportDialog> createState() =>
      _AttendanceExportDialogState();
}

class _AttendanceExportDialogState
    extends ConsumerState<AttendanceExportDialog> {
  // Local checkbox state -- like Vue's data() { return { selectedMonths: [] } }
  final List<DateTime> _selectedMonths = [];

  // Build 12 months starting from July of the academic start year.
  // Like a Vue computed property that derives month options from the year prop.
  late final List<DateTime> _months = _buildMonths();

  List<DateTime> _buildMonths() {
    int startYear = DateTime.now().year;
    try {
      final parts = widget.activeYearString.split('/');
      if (parts.isNotEmpty) startYear = int.parse(parts[0]);
    } catch (_) {}

    return List.generate(12, (i) => DateTime(startYear, 7 + i, 1));
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);

    return AlertDialog(
      title: Text(
        languageProvider.getTranslatedText({
          'en': 'Export Attendance',
          'id': 'Export Absensi',
        }),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Academic year label -- like a read-only Vue prop displayed in the template.
            Text(
              'Tahun Ajaran ${widget.activeYearName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Select month(s) to export:',
                'id': 'Pilih bulan yang akan diexport:',
              }),
              style: TextStyle(fontSize: 12, color: ColorUtils.slate400),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Month checklist -- like a v-for with v-model on each checkbox.
            Expanded(
              child: ListView.builder(
                itemCount: _months.length,
                itemBuilder: (context, index) {
                  final date = _months[index];
                  final label = DateFormat(
                    'MMMM yyyy',
                    languageProvider.currentLanguage,
                  ).format(date);
                  final isSelected = _selectedMonths.contains(date);

                  return CheckboxListTile(
                    title: Text(label),
                    value: isSelected,
                    onChanged: (val) {
                      // setState here is scoped to this widget only --
                      // like mutating a local data() property in Vue.
                      setState(() {
                        if (val == true) {
                          _selectedMonths.add(date);
                        } else {
                          _selectedMonths.remove(date);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => AppNavigator.pop(context),
          child: Text(
            languageProvider.getTranslatedText({
              'en': 'Cancel',
              'id': 'Batal',
            }),
          ),
        ),
        ElevatedButton(
          // Disable the button until at least one month is selected --
          // like `:disabled="selectedMonths.length === 0"` in Vue.
          onPressed: _selectedMonths.isEmpty
              ? null
              : () {
                  AppNavigator.pop(context);
                  // Sort before emitting so the parent always gets an
                  // ordered list regardless of the tap order.
                  final sorted = List<DateTime>.from(_selectedMonths)..sort();
                  widget.onExport(sorted);
                },
          child: const Text('Export'),
        ),
      ],
    );
  }
}
