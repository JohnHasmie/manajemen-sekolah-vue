// Class-level finance report screen - shows billing/payment status per student.
//
// Like `pages/admin/finance/class-report.vue` - displays a per-class finance report
// showing each student's payment status, grouped by month and payment type.
// Supports filtering by student name, payment type, month, and payment status.
//
// In Laravel terms, this consumes the billing endpoints filtered by class_id,
// similar to `Bill::where('class_id', $id)->with('student')->get()`.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_manual_payment_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_payment_options_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_report_filter_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_table.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// Class finance report screen - shows billing/payment details for a specific class.
///
/// Takes [classId] and [className] as required props (like Vue route params).
/// This is a [StatefulWidget] with local state for students, bills, and filters.
class ClassFinanceReportScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ClassFinanceReportScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassFinanceReportScreen> createState() =>
      _ClassFinanceReportScreenState();
}

/// Mutable state for [ClassFinanceReportScreen].
///
/// Key state (like Vue `data()`):
/// - [_students] - list of students in the class
/// - [_billsByStudent] - map of student ID -> their bills (like a Vue computed groupBy)
/// - [_monthGroups] - bills grouped by month for display
/// - Filter states: [_searchQuery], [_selectedPaymentTypeId], [_selectedStatus]
///
/// setState() triggers re-render like Vue's reactivity system.
class _ClassFinanceReportScreenState extends State<ClassFinanceReportScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _students = [];
  Map<String, List<dynamic>> _billsByStudent = {};
  List<MonthGroup> _monthGroups = [];
  File? selectedFile;

  // Filters
  String _searchQuery = '';
  String? _selectedPaymentTypeId;
  String? _selectedMonthKey;
  String _selectedStatus =
      'Semua'; // 'Semua', 'Lunas', 'Belum Dibayar', 'Belum Diverifikasi'

  /// Like Vue's `mounted()` - loads students and billing data on screen open.
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Fetches students, payment types, and bills for this class, then groups data.
  /// Like a Vue method calling multiple API endpoints in sequence and computing derived data.
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // 1. Fetch Students
      final studentsResponse = await _apiService.get(
        '/student/class/${widget.classId}',
      );
      List<dynamic> students = [];
      if (studentsResponse is Map) {
        if (studentsResponse.containsKey('data')) {
          students = studentsResponse['data'];
        } else if (studentsResponse.containsKey('students')) {
          students = studentsResponse['students'];
        }
      } else if (studentsResponse is List) {
        students = studentsResponse;
      }

      // 2. Fetch All Payment Types
      final paymentTypesResponse = await _apiService.get('/payment-types');
      List<dynamic> allPaymentTypes = [];
      if (paymentTypesResponse is List) {
        allPaymentTypes = paymentTypesResponse;
      } else if (paymentTypesResponse is Map &&
          paymentTypesResponse.containsKey('data')) {
        allPaymentTypes = paymentTypesResponse['data'];
      }

      // 3. Fetch Bills
      final billsResponse = await FinanceService.getBillsPaginated(
        limit: 1000,
        classId: widget.classId,
      );

      List<dynamic> bills = [];
      if (billsResponse['data'] != null) {
        bills = billsResponse['data'];
      }

      // 4. Group bills by Student ID
      final Map<String, List<dynamic>> billsByStudent = {};
      for (var bill in bills) {
        final studentId = bill['student_id']?.toString();
        if (studentId != null) {
          if (!billsByStudent.containsKey(studentId)) {
            billsByStudent[studentId] = [];
          }
          billsByStudent[studentId]!.add(bill);
        }
      }

      // 5. Build Column Structure (Months -> Payment Types)
      _monthGroups = _buildMonthGroups(bills, allPaymentTypes);

      if (mounted) {
        setState(() {
          _students = students;
          _billsByStudent = billsByStudent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  // UPDATED LOGIC: Month-Specific Columns based on created_at
  List<MonthGroup> _buildMonthGroups(
    List<dynamic> bills,
    List<dynamic> allPaymentTypes,
  ) {
    final Map<String, dynamic> paymentTypeMap = {
      for (var pt in allPaymentTypes) pt['id'].toString(): pt,
    };

    // 1. Determine Academic Year Start from earliest due_date
    int startYear = DateTime.now().year;
    DateTime? earliestDate;

    for (var bill in bills) {
      if (bill['due_date'] != null) {
        try {
          final DateTime d = DateTime.parse(bill['due_date']);
          if (earliestDate == null || d.isBefore(earliestDate)) {
            earliestDate = d;
          }
        } catch (_) {}
      }
    }

    if (earliestDate != null) {
      final DateTime d = earliestDate;
      // Many schools start academic year in July (7)
      if (d.month >= 7) {
        startYear = d.year;
      } else {
        startYear = d.year - 1;
      }
    }

    // 2. Generate 12 Months
    final List<String> monthKeys = [];
    for (int i = 0; i < 12; i++) {
      int monthNum = 7 + i;
      int year = startYear;
      if (monthNum > 12) {
        monthNum -= 12;
        year += 1;
      }
      final String key = '$year-${monthNum.toString().padLeft(2, '0')}';
      monthKeys.add(key);
    }

    final Map<int, String> monthNames = {
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

    final List<MonthGroup> groups = [];

    // 3. Build Groups - DYNAMIC active types per month
    for (var monthKey in monthKeys) {
      final DateTime date = DateTime.parse('$monthKey-01');
      final String displayMonth = monthNames[date.month]!;

      // Find bills for THIS month (using due_date)
      final List<dynamic> monthlyBills = bills.where((b) {
        final String dueDate = b['due_date'] ?? '';
        // Approximate month match
        String bMonth = '';
        if (dueDate.length >= 7) bMonth = dueDate.substring(0, 7);
        return bMonth == monthKey;
      }).toList();

      // Find unique payment types in these bills
      final Set<String> activeTypeIds = {};
      for (var b in monthlyBills) {
        if (b['payment_type_id'] != null) {
          activeTypeIds.add(b['payment_type_id'].toString());
        }
      }

      // Sort types
      final List<String> sortedIds = activeTypeIds.toList();
      sortedIds.sort((a, b) {
        final String nameA = paymentTypeMap[a]?['name'] ?? '';
        final String nameB = paymentTypeMap[b]?['name'] ?? '';
        return nameA.compareTo(nameB);
      });

      final List<PaymentTypeColumn> columns = [];
      for (var typeId in sortedIds) {
        final data = paymentTypeMap[typeId];
        columns.add(
          PaymentTypeColumn(id: typeId, name: data?['name'] ?? 'Unknown'),
        );
      }

      // Add group (even if empty, as requested "months should still appear")
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

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      final double value = double.parse(amount.toString());
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(value);
    } catch (e) {
      return 'Rp $amount';
    }
  }

  String _getFileTypeText(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'Gambar JPEG';
      case 'png':
        return 'Gambar PNG';
      case 'pdf':
        return 'Dokumen PDF';
      default:
        return 'File $extension';
    }
  }

  Future<void> _pickImage(StateSetter setDialogState) async {
    try {
      final ImagePicker picker = ImagePicker();
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.chooseSource.tr),
          content: Text(AppLocalizations.chooseImageSource.tr),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context, ImageSource.gallery),
              child: Text(AppLocalizations.gallery.tr),
            ),
            TextButton(
              onPressed: () => AppNavigator.pop(context, ImageSource.camera),
              child: Text(AppLocalizations.camera.tr),
            ),
          ],
        ),
      );

      if (source != null) {
        final XFile? file = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (file != null && context.mounted) {
          setDialogState(() {
            selectedFile = File(file.path);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickPDF(StateSetter setDialogState) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setDialogState(() {
          selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
    }
  }

  Future<void> _pickFile(StateSetter setDialogState) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.chooseFileType.tr),
        content: Text(AppLocalizations.uploadPaymentProof.tr),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, 'image'),
            child: Text(AppLocalizations.imageCameraGallery.tr),
          ),
          TextButton(
            onPressed: () => AppNavigator.pop(context, 'pdf'),
            child: Text(AppLocalizations.pdfDocument.tr),
          ),
        ],
      ),
    );

    if (action == 'image') {
      await _pickImage(setDialogState);
    } else if (action == 'pdf') {
      await _pickPDF(setDialogState);
    }
  }

  void _showManualPaymentForm(dynamic bill) {
    final paymentMethodController = TextEditingController(text: 'Tunai');
    final amountController = TextEditingController(
      text: (bill['amount'] ?? 0).toString(),
    );
    final paymentDateController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    selectedFile = null;

    showDialog(
      context: context,
      builder: (context) => ClassFinanceManualPaymentDialog(
        bill: bill,
        primaryColor: _getPrimaryColor(),
        selectedFile: selectedFile,
        formatCurrency: _formatCurrency,
        onPickFile: _pickFile,
        getFileTypeText: _getFileTypeText,
        paymentMethodController: paymentMethodController,
        amountController: amountController,
        paymentDateController: paymentDateController,
        onSave: ({
          required String paymentMethod,
          required double amount,
          required String date,
          File? file,
        }) {
          _uploadManualPayment(
            bill: bill,
            paymentMethod: paymentMethod,
            amount: amount,
            date: date,
            file: file,
          );
        },
      ),
    );
  }

  Future<void> _uploadManualPayment({
    required dynamic bill,
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => Center(child: CircularProgressIndicator()),
      );

      if (file != null) {
        await _apiService.uploadFile(
          '/payment/manual',
          file,
          fileField: 'payment_receipt',
          data: {
            'bill_id': bill['id'],
            'payment_method': paymentMethod,
            'amount': amount.toString(),
            'payment_date': date,
            'status': 'verified',
          },
        );
      } else {
        await _apiService.post('/payment/manual', {
          'bill_id': bill['id'],
          'payment_method': paymentMethod,
          'amount': amount.toString(),
          'payment_date': date,
          'status': 'verified',
        });
      }

      if (mounted) AppNavigator.pop(context); // Close loading
      _loadData(); // Refresh table

      // ignore: use_build_context_synchronously
      SnackBarUtils.showSuccess(context, AppLocalizations.paymentRecordedSuccessfully.tr);
    } catch (e) {
      if (mounted) AppNavigator.pop(context);
      // ignore: use_build_context_synchronously
      SnackBarUtils.showError(context, '${AppLocalizations.error.tr}: $e');
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            // Keep the gradient header visible during loading
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getPrimaryColor(),
                    _getPrimaryColor().withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => AppNavigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.className,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Laporan Keuangan',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: SkeletonListLoading(itemCount: 6, infoTagCount: 1),
              ),
            ),
          ],
        ),
      );
    }
    if (_errorMessage?.isNotEmpty == true) {
      return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
    }

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Custom Gradient Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Back Button & Title
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.className,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          AppSpacing.v2,
                          Text(
                            'Laporan Keuangan',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Search Bar & Filter Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari siswa...',
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            prefixIcon: Icon(
                              Icons.search,
                              color: ColorUtils.slate400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.toLowerCase();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: _showFilterSheet,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color:
                              (_selectedStatus != 'Semua' ||
                                  _selectedMonthKey != null ||
                                  _selectedPaymentTypeId != null)
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color:
                              (_selectedStatus != 'Semua' ||
                                  _selectedMonthKey != null ||
                                  _selectedPaymentTypeId != null)
                              ? _getPrimaryColor()
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter Chips
          if (_selectedStatus != 'Semua' ||
              _selectedMonthKey != null ||
              _selectedPaymentTypeId != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedStatus != 'Semua')
                    _buildFilterChip(
                      label: 'Status: $_selectedStatus',
                      onDeleted: () =>
                          setState(() => _selectedStatus = 'Semua'),
                    ),
                  if (_selectedMonthKey != null)
                    _buildFilterChip(
                      label:
                          'Bulan: ${_monthGroups.firstWhere(
                            (m) => m.monthKey == _selectedMonthKey,
                            orElse: () => MonthGroup(monthKey: '', monthName: _selectedMonthKey!, paymentTypes: []),
                          ).monthName}',
                      onDeleted: () => setState(() => _selectedMonthKey = null),
                    ),
                  if (_selectedPaymentTypeId != null)
                    _buildFilterChip(
                      label:
                          'Jenis: Pembayaran Terpilih', // Hard to get name without lookup, keeping simple or could lookup
                      onDeleted: () =>
                          setState(() => _selectedPaymentTypeId = null),
                    ),
                ],
              ),
            ),

          // Main Table Content
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _students.isEmpty
                  ? const EmptyState(
                      title: 'Tidak ada siswa',
                      subtitle: 'Kelas ini belum memiliki siswa',
                      icon: Icons.people_outline,
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ClassFinanceTable(
                        students: _students,
                        billsByStudent: _billsByStudent,
                        monthGroups: _monthGroups,
                        searchQuery: _searchQuery,
                        selectedPaymentTypeId: _selectedPaymentTypeId,
                        selectedMonthKey: _selectedMonthKey,
                        selectedStatus: _selectedStatus,
                        onBillTap: _showPaymentOptions,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: _getPrimaryColor()),
      ),
      backgroundColor: _getPrimaryColor().withValues(alpha: 0.1),
      deleteIcon: Icon(Icons.close, size: 16, color: _getPrimaryColor()),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: _getPrimaryColor().withValues(alpha: 0.2)),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClassFinanceReportFilterSheet(
        primaryColor: _getPrimaryColor(),
        selectedStatus: _selectedStatus,
        selectedMonthKey: _selectedMonthKey,
        selectedPaymentTypeId: _selectedPaymentTypeId,
        monthGroups: _monthGroups,
        onStatusChanged: (val) => setState(() => _selectedStatus = val),
        onMonthChanged: (val) => setState(() => _selectedMonthKey = val),
        onPaymentTypeChanged: (val) =>
            setState(() => _selectedPaymentTypeId = val),
      ),
    );
  }


  void _showPaymentOptions(dynamic bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClassFinancePaymentOptionsSheet(
        bill: bill,
        primaryColor: _getPrimaryColor(),
        onManualPay: () => _showManualPaymentForm(bill),
        onCancelPayment: () => _processManualPayment(bill, false),
        onViewDetail: () => _showDetailDialog(bill),
      ),
    );
  }

  Future<void> _processManualPayment(dynamic bill, bool markAsPaid) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => Center(child: CircularProgressIndicator()),
      );

      if (markAsPaid) {
        // "Bayar Manual" (Mark as Paid)
        // Check if there is an existing PENDING payment to update instead of creating new
        String? pendingPaymentId;
        if (bill['payments'] != null && (bill['payments'] as List).isNotEmpty) {
          final payList = List.from(bill['payments']);
          // Find latest pending payment
          final pendingPay = payList.lastWhere(
            (p) => p['status'] == 'pending',
            orElse: () => null,
          );
          if (pendingPay != null) {
            pendingPaymentId = pendingPay['id'].toString();
          }
        }

        if (pendingPaymentId != null) {
          // UPDATE existing pending payment to VERIFIED
          await _apiService.put('/payment/manual/$pendingPaymentId', {
            'status': 'verified',
            'amount': bill['amount'] ?? bill['bill_amount'] ?? 0,
            'payment_method': 'Manual',
            'payment_date': DateTime.now().toIso8601String(),
            // update verifier handled by backend if needed
          });
        } else {
          // CREATE new Verified Payment
          await _apiService.post('/payment/manual', {
            'bill_id': bill['id'],
            'amount': bill['amount'] ?? bill['bill_amount'] ?? 0,
            'payment_method': 'Manual',
            'payment_date': DateTime.now().toIso8601String(),
            'status': 'verified',
          });
        }
      } else {
        // Cancel Payment (Set to Pending)
        // 1. Try to find existing verified payment to cancel
        String? paymentIdToCancel;
        if (bill['payments'] != null && (bill['payments'] as List).isNotEmpty) {
          // Sort or find the latest verified one
          final payList = List.from(bill['payments']);
          // Assuming latest is last or sort by date if possible, but taking 'verified' one is safest
          final verifiedPay = payList.lastWhere(
            (p) => p['status'] == 'verified',
            orElse: () => null,
          );
          if (verifiedPay != null) {
            paymentIdToCancel = verifiedPay['id'].toString();
          }
        }

        if (paymentIdToCancel != null) {
          // Update Payment Status
          await _apiService.put('/payment/manual/$paymentIdToCancel', {
            'status': 'pending',
            'amount': bill['amount'] ?? 0, // Required by validation usually
            'payment_method': 'Manual',
            'payment_date': DateTime.now().toIso8601String(),
          });
        }

        // 2. Also Force Update Bill Status to Pending (Redundancy)
        try {
          await _apiService.put('/bills/${bill['id']}', {'status': 'pending'});
        } catch (_) {}
      }

      if (mounted) AppNavigator.pop(context); // Close loading
      _loadData(); // Refresh table

      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          markAsPaid ? AppLocalizations.paymentRecordedSuccessfully.tr : AppLocalizations.paymentCancelled.tr,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNavigator.pop(context);
        SnackBarUtils.showError(context, '${AppLocalizations.error.tr}: $e');
      }
    }
  }

  void _showDetailDialog(dynamic bill) {
    if (bill == null) return;

    // Helper for formatting currency locally in dialog
    String formatRupiah(dynamic value) {
      if (value == null) return 'Rp 0';
      return 'Rp $value';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail Tagihan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                'Status',
                bill['status'] == 'verified' ? 'Lunas' : 'Belum Lunas',
              ),
              _detailRow(
                'Jumlah',
                formatRupiah(
                  bill['amount'] ?? bill['bill_amount'] ?? bill['total_amount'],
                ),
              ),
              _detailRow(
                'Tanggal Buat',
                bill['created_at']?.toString().split('T')[0] ?? '-',
              ),
              _detailRow(
                'Jatuh Tempo',
                bill['due_date']?.toString().split('T')[0] ?? '-',
              ),
              _detailRow('Keterangan', bill['description'] ?? '-'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => AppNavigator.pop(context),
              child: Text(AppLocalizations.close.tr),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: ColorUtils.slate600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

