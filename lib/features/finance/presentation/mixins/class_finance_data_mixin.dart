import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// Data loading and grouping logic for class finance report.
mixin ClassFinanceDataMixin on State<ClassFinanceReportScreen> {
  // State variables (assumed to be in the State class)
  late ApiService apiService;
  late List<dynamic> students;
  late Map<String, List<dynamic>> billsByStudent;
  late List<MonthGroup> monthGroups;
  late bool isLoadingData;
  late String? errorMessage;

  /// Fetches students, payment types, and bills for the class.
  Future<void> loadData() async {
    try {
      setState(() {
        isLoadingData = true;
        errorMessage = '';
      });

      final newStudents = await fetchStudents();
      final paymentTypes = await fetchPaymentTypes();
      final bills = await fetchBills();
      final newBillsByStudent = groupBillsByStudent(bills);
      monthGroups = buildMonthGroups(bills, paymentTypes);

      if (mounted) {
        setState(() {
          students = newStudents;
          billsByStudent = newBillsByStudent;
          isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = ErrorUtils.getFriendlyMessage(e);
          isLoadingData = false;
        });
      }
    }
  }

  /// Fetches students from API.
  Future<List<dynamic>> fetchStudents() async {
    final response = await apiService.get('/student/class/${getClassId()}');
    if (response is Map) {
      if (response.containsKey('data')) {
        return response['data'];
      } else if (response.containsKey('students')) {
        return response['students'];
      }
    } else if (response is List) {
      return response;
    }
    return [];
  }

  /// Fetches payment types from API.
  Future<List<dynamic>> fetchPaymentTypes() async {
    final response = await apiService.get('/payment-types');
    if (response is List) {
      return response;
    } else if (response is Map && response.containsKey('data')) {
      return response['data'];
    }
    return [];
  }

  /// Fetches bills from API.
  Future<List<dynamic>> fetchBills() async {
    final response = await FinanceService.getBillsPaginated(
      limit: 1000,
      classId: getClassId(),
      academicYearId: widget.academicYearId,
    );
    return response['data'] ?? [];
  }

  /// Groups bills by student ID.
  Map<String, List<dynamic>> groupBillsByStudent(List<dynamic> bills) {
    final result = <String, List<dynamic>>{};
    for (final bill in bills) {
      final studentId = bill['student_id']?.toString();
      if (studentId != null) {
        result.putIfAbsent(studentId, () => []).add(bill);
      }
    }
    return result;
  }

  /// Builds month groups with dynamic payment types.
  List<MonthGroup> buildMonthGroups(
    List<dynamic> bills,
    List<dynamic> allPaymentTypes,
  ) {
    final paymentTypeMap = buildPaymentTypeMap(allPaymentTypes);
    final startYear = getAcademicStartYear(bills);
    final monthKeys = generateMonthKeys(startYear);
    final monthNames = getMonthNames();
    final groups = <MonthGroup>[];

    for (final monthKey in monthKeys) {
      final date = DateTime.parse('$monthKey-01');
      final displayMonth = monthNames[date.month]!;
      final monthlyBills = getMonthlyBills(bills, monthKey);
      final columns = buildPaymentColumns(monthlyBills, paymentTypeMap);

      groups.add(
        MonthGroup(
          monthKey: monthKey,
          monthName: displayMonth,
          paymentTypes: columns,
        ),
      );
    }
    return groups;
  }

  Map<String, dynamic> buildPaymentTypeMap(List<dynamic> types) {
    return {for (final pt in types) pt['id'].toString(): pt};
  }

  int getAcademicStartYear(List<dynamic> bills) {
    int startYear = DateTime.now().year;
    DateTime? earliest;

    for (final bill in bills) {
      if (bill['due_date'] != null) {
        try {
          final d = DateTime.parse(bill['due_date']);
          if (earliest == null || d.isBefore(earliest)) {
            earliest = d;
          }
        } catch (_) {}
      }
    }

    if (earliest != null && earliest.month >= 7) {
      startYear = earliest.year;
    } else if (earliest != null) {
      startYear = earliest.year - 1;
    }
    return startYear;
  }

  List<String> generateMonthKeys(int startYear) {
    final keys = <String>[];
    for (int i = 0; i < 12; i++) {
      int month = 7 + i;
      int year = startYear;
      if (month > 12) {
        month -= 12;
        year += 1;
      }
      final key = '$year-${month.toString().padLeft(2, '0')}';
      keys.add(key);
    }
    return keys;
  }

  Map<int, String> getMonthNames() {
    return {
      1: 'Januari',
      2: 'Februari',
      3: 'Maret',
      4: 'April',
      5: 'Mei',
      6: 'Juni',
      7: 'Juli',
      8: 'Agustus',
      9: 'September',
      10: 'Oktober',
      11: 'November',
      12: 'Desember',
    };
  }

  List<dynamic> getMonthlyBills(List<dynamic> bills, String monthKey) {
    return bills.where((b) {
      final dueDate = b['due_date'] ?? '';
      final bMonth = dueDate.length >= 7 ? dueDate.substring(0, 7) : '';
      return bMonth == monthKey;
    }).toList();
  }

  List<PaymentTypeColumn> buildPaymentColumns(
    List<dynamic> monthlyBills,
    Map<String, dynamic> typeMap,
  ) {
    final activeIds = <String>{};
    for (final b in monthlyBills) {
      if (b['payment_type_id'] != null) {
        activeIds.add(b['payment_type_id'].toString());
      }
    }

    final sortedIds = activeIds.toList();
    sortedIds.sort((a, b) {
      final nameA = typeMap[a]?['name'] ?? '';
      final nameB = typeMap[b]?['name'] ?? '';
      return nameA.compareTo(nameB);
    });

    return [
      for (final typeId in sortedIds)
        PaymentTypeColumn(
          id: typeId,
          name: typeMap[typeId]?['name'] ?? 'Unknown',
        ),
    ];
  }

  /// Must be implemented by the State class to provide classId
  String getClassId();
}
