import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/'
    'presentation/screens/'
    'parent_report_card_detail_screen.dart';

/// Mixin for UI builder methods (header, filter, content states).
mixin ReportCardUIBuilderMixin {
  // Abstract state access
  void setState(VoidCallback fn);
  BuildContext get context;

  // State fields
  late bool isLoading;
  late String errorMessage;
  late List<dynamic> studentsData;
  late Map<String, dynamic> parentData;
  late String selectedTermId;

  // Data access methods (from ReportCardDataMixin)
  Color getPrimaryColor();
  LinearGradient getCardGradient();
  Future<void> loadData({bool useCache = true});
  Future<void> forceRefresh();

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: AppSpacing.md),
          _buildHeaderTitle(),
          _buildHeaderMenu(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => AppNavigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'E-Raport',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Lihat raport akademik siswa',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) {
        if (value == 'refresh') forceRefresh();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
              const SizedBox(width: AppSpacing.sm),
              Text(AppLocalizations.updateData.tr),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text(
            'Semester:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: DropdownButton<String>(
              value: selectedTermId,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '1', child: Text('Ganjil')),
                DropdownMenuItem(value: '2', child: Text('Genap')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedTermId = val);
                  loadData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContentArea() {
    if (isLoading) {
      return const SkeletonListLoading();
    }

    if (errorMessage.isNotEmpty && studentsData.isEmpty) {
      return _buildErrorState();
    }

    if (studentsData.isEmpty) {
      return _buildEmptyState();
    }

    return _buildStudentsList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orange[300],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: loadData,
              child: Text(AppLocalizations.tryAgain.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Belum ada E-Raport yang dipublikasikan\n'
            'pada semester ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: studentsData.length,
        itemBuilder: (context, index) {
          final student = studentsData[index];
          final reportCard = student['reportCard'];

          // Parent only sees published raports
          if (reportCard == null || reportCard['status'] != 'published') {
            return const SizedBox.shrink();
          }

          return _buildStudentCard(student, reportCard);
        },
      ),
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> student,
    Map<String, dynamic> reportCard,
  ) {
    final studentName = student['student']['name'] ?? 'Siswa';
    final studentInitial = studentName[0].toUpperCase();
    final studentNIS = student['student']['nis'] ?? '-';

    return Card(
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: () {
          AppNavigator.push(
            context,
            ParentReportCardDetailScreen(
              reportCardData: reportCard,
              studentName: studentName,
              userRole: 'wali',
              studentData: student['student'],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildStudentAvatar(studentInitial),
              const SizedBox(width: AppSpacing.lg),
              _buildStudentInfo(studentName, studentNIS),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(String initial) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
      child: Text(
        initial,
        style: TextStyle(
          color: ColorUtils.corporateBlue600,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildStudentInfo(String name, String nis) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('NIS: $nis', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
