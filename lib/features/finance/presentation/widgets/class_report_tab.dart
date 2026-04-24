import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';

/// Displays a scrollable list of class cards for the Finance → Class Report tab.
///
/// Like a Vue `<ClassReportTab>` component that receives its data as props.
/// Uses [ConsumerWidget] because [_buildClassSummary] needs to read
/// [academicYearRiverpod] to filter bills by the active academic year.
class ClassReportTab extends ConsumerWidget {
  const ClassReportTab({
    super.key,
    required this.isLoading,
    required this.classList,
    required this.studentsByClass,
    required this.billsByStudent,
  });

  /// Whether the parent screen is still fetching data.
  final bool isLoading;

  /// Raw class objects from the API (each is a `Map<String, dynamic>`).
  final List<dynamic> classList;

  /// Maps class ID → list of student objects for that class.
  final Map<String, List<dynamic>> studentsByClass;

  /// Maps student ID → list of bill objects for that student.
  final Map<String, List<dynamic>> billsByStudent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const SkeletonListLoading(itemCount: 6, infoTagCount: 1);
    }

    if (classList.isEmpty) {
      return const EmptyState(
        title: 'Belum ada data kelas',
        subtitle: 'Data kelas akan muncul di sini',
        icon: Icons.class_,
      );
    }

    return ListView.builder(
      itemCount: classList.length,
      itemBuilder: (context, index) {
        final classItem = classList[index];
        final classId = classItem['id']?.toString();
        final studentList = studentsByClass[classId] ?? [];

        return _buildClassCard(context, ref, classItem, studentList, index);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers (previously private methods on FinanceScreenState)
  // ---------------------------------------------------------------------------

  Widget _buildClassCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> classItem,
    List<dynamic> studentList,
    int index,
  ) {
    final primaryColor = ColorUtils.getRoleColor('admin');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: () {
          final classModel = Classroom.fromJson(classItem);
          AppNavigator.push(
            context,
            ClassFinanceReportScreen(
              classId: classModel.id,
              className: classModel.name,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: ColorUtils.slate200, width: 1),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(Icons.class_, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Classroom.fromJson(classItem).name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Classroom.fromJson(classItem).studentCount} siswa',
                      style: TextStyle(
                        color: ColorUtils.slate500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildClassSummary(ref, studentList),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: ColorUtils.slate500,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassSummary(WidgetRef ref, List<dynamic> studentList) {
    int totalLunas = 0;
    int totalPending = 0;
    int totalBelumBayar = 0;

    final academicYearProvider = ref.read(academicYearRiverpod);
    final selectedAcademicYearId = academicYearProvider
        .selectedAcademicYear?['id']
        ?.toString();

    for (final student in studentList) {
      final studentId = student['id']?.toString();
      final billList = billsByStudent[studentId] ?? [];

      for (final bill in billList) {
        // Filter based on academic year
        final billAcademicYearId = bill['academic_year_id']?.toString();
        if (selectedAcademicYearId != null &&
            billAcademicYearId != null &&
            billAcademicYearId != selectedAcademicYearId) {
          continue;
        }

        final status = bill['status'];

        // 1. Check Verified/Lunas
        if (status == 'verified') {
          totalLunas++;
        }
        // 2. Check Pending Verification (Menunggu)
        // Logic: Has a payment with status 'pending' (regardless of bill status being pending/unpaid)
        else {
          bool hasPendingPayment = false;
          if (bill['payments'] != null && bill['payments'] is List) {
            for (final p in bill['payments']) {
              final pStatus = p['status'];
              if (pStatus == 'pending' || pStatus == 'test_status') {
                hasPendingPayment = true;
                break;
              }
            }
          }

          if (hasPendingPayment) {
            totalPending++;
          } else {
            // 3. Fallback: Not Paid
            // Typically bill status is 'unpaid' or 'pending' here with no pending proof
            totalBelumBayar++;
          }
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (totalLunas > 0)
          _buildStatusIndicator(ColorUtils.success600, totalLunas),
        if (totalPending > 0)
          _buildStatusIndicator(ColorUtils.warning600, totalPending),
        if (totalBelumBayar > 0)
          _buildStatusIndicator(ColorUtils.error600, totalBelumBayar),
      ],
    );
  }

  Widget _buildStatusIndicator(Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
