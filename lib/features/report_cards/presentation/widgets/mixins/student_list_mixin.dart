import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';
import 'package:manajemensekolah/features/report_cards/presentation/'
    'screens/report_card_detail_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Mixin for building the student list section.
mixin StudentListMixin {
  /// Abstract getter for build context (provided by State).
  BuildContext get context;

  /// Abstract getter for widget data.
  Widget get widgetParent;

  /// Get the selected class from widget.
  Map<String, dynamic>? getSelectedClass();

  /// Get the onDownloadPdf callback from widget.
  void Function(Map<String, dynamic> student)? getOnDownloadPdf();

  /// Get the onReturnFromDetail callback from widget.
  VoidCallback? getOnReturnFromDetail();

  /// Build the student list view with filtered students.
  Widget buildStudentList(List<dynamic> filteredStudents) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: filteredStudents.length,
        itemBuilder: (context, index) {
          final student = filteredStudents[index];
          return _buildStudentCard(context, student, index);
        },
      ),
    );
  }

  /// Build an individual student card with status and actions.
  Widget _buildStudentCard(BuildContext context, dynamic student, int index) {
    final model = Student.fromJson(student as Map<String, dynamic>);
    final name = model.name.isNotEmpty ? model.name : 'Siswa';
    final hasRaport = student['has_raport'] ?? false;
    final status = student['raport_status'] ?? 'Belum ada';
    final nis = model.studentNumber.isNotEmpty ? model.studentNumber : '-';
    final isFinal =
        status.toLowerCase() == 'final' || status.toLowerCase() == 'published';
    final statusInfo = _getStatusInfo(hasRaport, status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _onStudentTap(context, student, name),
          borderRadius: BorderRadius.circular(12),
          child: _buildCardContent(
            index,
            name,
            nis,
            statusInfo,
            isFinal,
            student,
          ),
        ),
      ),
    );
  }

  /// Build the card content row layout.
  Widget _buildCardContent(
    int index,
    String name,
    String nis,
    Map<String, Object> statusInfo,
    bool isFinal,
    dynamic student,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: _buildRowChildren(
          index,
          name,
          nis,
          statusInfo,
          isFinal,
          student,
        ),
      ),
    );
  }

  /// Build the children widgets for the card row.
  List<Widget> _buildRowChildren(
    int index,
    String name,
    String nis,
    Map<String, Object> statusInfo,
    bool isFinal,
    dynamic student,
  ) {
    return [
      _buildNumberBadge(index),
      const SizedBox(width: 10),
      _buildStudentInfo(name, nis),
      _buildStatusBadge(
        statusInfo['bg'] as Color,
        statusInfo['fg'] as Color,
        statusInfo['icon'] as IconData,
        statusInfo['label'] as String,
      ),
      if (isFinal) ...[const SizedBox(width: 6), _buildPdfButton(student)],
      const SizedBox(width: 4),
      Icon(Icons.chevron_right, size: 18, color: ColorUtils.slate300),
    ];
  }

  /// Build the number badge widget.
  Widget _buildNumberBadge(int index) {
    final badgeColor = ColorUtils.getRoleColor('guru');

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badgeColor.withValues(alpha: 0.12),
            badgeColor.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: badgeColor,
          ),
        ),
      ),
    );
  }

  /// Build the student name and NIS section.
  Widget _buildStudentInfo(String name, String nis) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'NIS: $nis',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
          ),
        ],
      ),
    );
  }

  /// Build the status badge widget.
  Widget _buildStatusBadge(
    Color bgColor,
    Color fgColor,
    IconData icon,
    String label,
  ) {
    return StatusBadge(
      label: label,
      color: fgColor,
      icon: icon,
      iconSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      fontSize: 10,
    );
  }

  /// Build the PDF download button.
  Widget _buildPdfButton(dynamic student) {
    return GestureDetector(
      onTap: () {
        final callback = getOnDownloadPdf();
        if (callback != null) {
          callback(student as Map<String, dynamic>);
        }
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: ColorUtils.error600.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.picture_as_pdf_outlined,
          size: 14,
          color: ColorUtils.error600,
        ),
      ),
    );
  }

  /// Determine status styling based on raport state.
  Map<String, Object> _getStatusInfo(bool hasRaport, String status) {
    if (!hasRaport) {
      return {
        'bg': ColorUtils.slate100,
        'fg': ColorUtils.slate500,
        'icon': Icons.edit_note,
        'label': 'Belum Isi',
      };
    } else if (status.toLowerCase() == 'draft') {
      return {
        'bg': ColorUtils.warning600.withValues(alpha: 0.08),
        'fg': ColorUtils.warning600,
        'icon': Icons.save_outlined,
        'label': 'Draft',
      };
    }
    return {
      'bg': ColorUtils.success600.withValues(alpha: 0.08),
      'fg': ColorUtils.success600,
      'icon': Icons.check_circle_outline,
      'label': 'Selesai',
    };
  }

  /// Handle student card tap navigation.
  void _onStudentTap(BuildContext context, dynamic student, String name) {
    final selectedClass = getSelectedClass();
    final onReturn = getOnReturnFromDetail();

    final model = Student.fromJson(student as Map<String, dynamic>);
    AppNavigator.push(
      context,
      ReportCardDetailScreen(
        studentClassId: model.studentClassId ?? '',
        studentName: name,
        className: selectedClass?['name'] ?? '',
      ),
    ).then((_) {
      if (onReturn != null) {
        onReturn();
      }
    });
  }
}
