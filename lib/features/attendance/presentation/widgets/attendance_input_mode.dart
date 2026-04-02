// The "Add Attendance" tab body: form + toolbar + student list + submit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_item.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class AttendanceInputMode extends ConsumerStatefulWidget {
  final bool isLoadingInput;
  final Widget inputFormWidget;
  final String? selectedSubjectId;
  final List<Student> filteredStudentList;
  final Map<String, String> attendanceStatus;
  final bool isSubmitting;
  final Color primaryColor;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onQuickActionsPressed;
  final void Function(String studentId, String status) onStatusChanged;
  final VoidCallback onSubmit;
  final ScrollController? scrollController;

  const AttendanceInputMode({
    super.key,
    required this.isLoadingInput,
    required this.inputFormWidget,
    required this.selectedSubjectId,
    required this.filteredStudentList,
    required this.attendanceStatus,
    required this.isSubmitting,
    required this.primaryColor,
    required this.searchController,
    required this.onSearchChanged,
    required this.onQuickActionsPressed,
    required this.onStatusChanged,
    required this.onSubmit,
    this.scrollController,
  });

  @override
  ConsumerState<AttendanceInputMode> createState() =>
      _AttendanceInputModeState();
}

class _AttendanceInputModeState extends ConsumerState<AttendanceInputMode> {
  bool _compactMode = false;

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (widget.isLoadingInput) {
      return SkeletonListLoading(itemCount: 4, infoTagCount: 1);
    }

    return Column(
      children: [
        // 1. Form Section
        widget.inputFormWidget,

        // 2. Toolbar: search + summary pills + toggle + quick actions
        if (widget.selectedSubjectId != null)
          _buildToolbar(languageProvider),

        // 3. Student List
        Expanded(
          child: widget.selectedSubjectId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 56, color: ColorUtils.slate300),
                        const SizedBox(height: 16),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Please select Class and Subject first',
                            'id': 'Silakan pilih Kelas dan Mapel terlebih dahulu',
                          }),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColorUtils.slate600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Or ensure you have a schedule for the selected date',
                            'id': 'Atau pastikan anda memiliki jadwal pada tanggal yang dipilih',
                          }),
                          style: TextStyle(fontSize: 12, color: ColorUtils.slate400),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : widget.filteredStudentList.isEmpty
              ? EmptyState(
                  title: languageProvider.getTranslatedText({
                    'en': 'No Students',
                    'id': 'Tidak ada siswa',
                  }),
                  subtitle: languageProvider.getTranslatedText({
                    'en': 'No students found for selected class',
                    'id': 'Tidak ada siswa untuk kelas yang dipilih',
                  }),
                  icon: Icons.people_outline,
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(top: 4, bottom: 80),
                  itemCount: widget.filteredStudentList.length,
                  itemBuilder: (context, index) => AttendanceStudentItem(
                    student: widget.filteredStudentList[index],
                    currentStatus:
                        widget.attendanceStatus[widget.filteredStudentList[index].id] ?? 'hadir',
                    languageProvider: languageProvider,
                    onStatusChanged: widget.onStatusChanged,
                    index: index,
                    compactMode: _compactMode,
                  ),
                ),
        ),

        // 4. Submit Button
        if (widget.selectedSubjectId != null && widget.filteredStudentList.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: widget.isSubmitting ? null : widget.onSubmit,
                    icon: widget.isSubmitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      widget.isSubmitting
                          ? languageProvider.getTranslatedText({'en': 'Saving...', 'id': 'Menyimpan...'})
                          : languageProvider.getTranslatedText({'en': 'Save Attendance', 'id': 'Simpan Absensi'}),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Toolbar matching teacher schedule screen style:
  /// Row 1: [Search field] [toggle] [quick actions]
  /// Row 2: Summary chips with full status names
  Widget _buildToolbar(LanguageProvider languageProvider) {
    // Count from ALL students (attendanceStatus map), not just filtered list.
    // This ensures the summary always shows the full class totals
    // regardless of active search filter.
    int hadir = 0, terlambat = 0, sakit = 0, izin = 0, alpha = 0;
    for (final status in widget.attendanceStatus.values) {
      switch (status.toLowerCase()) {
        case 'hadir': hadir++; break;
        case 'terlambat': terlambat++; break;
        case 'sakit': sakit++; break;
        case 'izin': izin++; break;
        case 'alpha': alpha++; break;
        default: hadir++; break;
      }
    }
    final total = widget.attendanceStatus.length;
    final primary = widget.primaryColor;

    String tr(Map<String, String> m) => languageProvider.getTranslatedText(m);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          // Row 1: Search + action buttons (matching schedule screen)
          Row(
            children: [
              // Search bar
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.searchController,
                          onChanged: (_) => widget.onSearchChanged(),
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
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search, color: primary, size: 20),
                          onPressed: () => FocusScope.of(context).unfocus(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Toggle view button
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: _compactMode ? primary.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: _compactMode ? primary : ColorUtils.slate200,
                    width: _compactMode ? 1.5 : 1,
                  ),
                ),
                child: IconButton(
                  onPressed: () => setState(() => _compactMode = !_compactMode),
                  icon: Icon(
                    _compactMode ? Icons.density_small : Icons.view_agenda_outlined,
                    color: _compactMode ? primary : ColorUtils.slate600,
                    size: 20,
                  ),
                  tooltip: _compactMode
                      ? tr({'en': 'Descriptive view', 'id': 'Tampilan deskriptif'})
                      : tr({'en': 'Compact view', 'id': 'Tampilan ringkas'}),
                ),
              ),
              const SizedBox(width: 8),
              // Quick actions button
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                child: IconButton(
                  onPressed: widget.onQuickActionsPressed,
                  icon: Icon(Icons.checklist_rtl, color: primary, size: 20),
                  tooltip: tr({'en': 'Quick Attendance', 'id': 'Presensi Cepat'}),
                ),
              ),
            ],
          ),
          // Row 2: Summary chips with full names
          if (widget.filteredStudentList.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _StatusChip(label: tr({'en': 'Present', 'id': 'Hadir'}), count: hadir, color: ColorUtils.success600, isSelected: hadir > 0, primary: primary),
                  const SizedBox(width: 6),
                  _StatusChip(label: tr({'en': 'Late', 'id': 'Terlambat'}), count: terlambat, color: ColorUtils.violet700, isSelected: terlambat > 0, primary: primary),
                  const SizedBox(width: 6),
                  _StatusChip(label: tr({'en': 'Sick', 'id': 'Sakit'}), count: sakit, color: ColorUtils.warning600, isSelected: sakit > 0, primary: primary),
                  const SizedBox(width: 6),
                  _StatusChip(label: tr({'en': 'Permission', 'id': 'Izin'}), count: izin, color: ColorUtils.info600, isSelected: izin > 0, primary: primary),
                  const SizedBox(width: 6),
                  _StatusChip(label: tr({'en': 'Absent', 'id': 'Alpha'}), count: alpha, color: ColorUtils.error600, isSelected: alpha > 0, primary: primary),
                  const SizedBox(width: 8),
                  // Total
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text(
                      '$total ${tr({'en': 'students', 'id': 'siswa'})}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorUtils.slate600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated chip matching schedule filter chip style.
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final Color primary;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(
          color: isSelected ? color : ColorUtils.slate300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : ColorUtils.slate500,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : ColorUtils.slate400,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
