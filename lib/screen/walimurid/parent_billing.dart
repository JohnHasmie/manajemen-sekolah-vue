import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentBillingScreen extends StatefulWidget {
  const ParentBillingScreen({super.key});

  @override
  ParentBillingScreenState createState() => ParentBillingScreenState();
}

class ParentBillingScreenState extends State<ParentBillingScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _billingList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Pagination
  final ScrollController _scrollController = ScrollController();
  // int _currentPage = 1; // Unused
  // final int _perPage = 10; // Unused
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  // Map<String, dynamic>? _paginationMeta; // Unused

  // Student list
  List<Siswa> _students = [];
  String? _selectedStudentId;
  Siswa? _selectedStudent;

  // Track processed and pending read IDs
  final Set<String> _processedIds = {};
  final Set<String> _pendingReadIds = {};
  Timer? _markReadTimer;

  // Search and Enhanced Filters
  final TextEditingController _searchController = TextEditingController();

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      double value = double.parse(amount.toString());
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

  String? _selectedStatusFilter; // 'unpaid', 'pending', 'verified'
  String? _selectedPeriodeFilter; // 'bulanan', 'tahunan'
  bool _hasActiveFilter = false;

  // Animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  File? selectedFile;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    _loadInitialData();
  }

  @override
  void dispose() {
    // Flush pending read IDs before departing
    if (_pendingReadIds.isNotEmpty) {
      final idsToMark = List<String>.from(_pendingReadIds);
      _pendingReadIds.clear();
      _markAsReadBulk(idsToMark);
    }
    _markReadTimer?.cancel();
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Get user data from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString == null) throw Exception('User not logged in');
      final userData = json.decode(userString);
      final userId = userData['id'].toString();
      final guardianEmail = userData['email'];

      // Load students for this parent using ApiStudentService
      final allStudents = await ApiStudentService.getStudent(
        userId: userId,
        guardianEmail: guardianEmail,
      );

      // Filter students like in dashboard.dart
      List<dynamic> filteredStudents = [];

      // Check for siswa_id in user data first
      if (userData['siswa_id'] != null && userData['siswa_id'].isNotEmpty) {
        final student = allStudents.firstWhere(
          (student) => student['id'] == userData['siswa_id'],
          orElse: () => null,
        );
        if (student != null) {
          filteredStudents = [student];
        }
      }

      if (filteredStudents.isEmpty) {
        filteredStudents = allStudents.where((student) {
          final emailMatch = student['guardian_email'] == userData['email'];
          final nameMatch = student['guardian_name'] == userData['name'];
          final userIdMatch = student['user_id'].toString() == userId;
          return emailMatch || nameMatch || userIdMatch;
        }).toList();
      }

      if (filteredStudents.isNotEmpty) {
        _students = filteredStudents.map((s) => Siswa.fromJson(s)).toList();

        if (_students.isNotEmpty) {
          _selectedStudentId = _students[0].id;
          _selectedStudent = _students[0];
        }
      }

      await _loadTagihan();

      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (error) {
      if (kDebugMode) print('Load initial billing data error: $error');
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.getFriendlyMessage(error);
      });
    }
  }

  Future<void> _loadTagihan() async {
    if (_selectedStudentId == null) return;

    try {
      final response = await _apiService.get(
        '/bill/parent',
        params: {'student_id': _selectedStudentId},
      );
      setState(() {
        _billingList = response is List ? response : [];
      });

      // Automatically mark ALL finance notifications for this student as read when entering/switching student
      // This ensures the dashboard unread count is updated, even for notifications
      // not linked to a specific bill in the current list.
      ApiService.markBillRead(studentId: _selectedStudentId!);
    } catch (error) {
      if (kDebugMode) {
        print('Error loading tagihan: $error');
      }
    }
  }

  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingReadIds.isNotEmpty) {
        final idsToMark = List<String>.from(_pendingReadIds);
        _pendingReadIds.clear();
        _markAsReadBulk(idsToMark);
      }
    });
  }

  Future<void> _markAsReadBulk(List<String> ids) async {
    if (_selectedStudentId == null) return;

    // Optimistic Update
    if (mounted) {
      setState(() {
        for (var item in _billingList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });
    }

    try {
      await ApiService.markBillRead(
        studentId: _selectedStudentId!,
        billIds: ids,
      );
    } catch (e) {
      if (kDebugMode) print('Error marking bills read: $e');
    }
  }

  void _onItemVisible(String id, bool isRead) {
    if (!isRead && !_processedIds.contains(id)) {
      _processedIds.add(id);
      _pendingReadIds.add(id);
      _scheduleMarkRead();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreTagihan();
      }
    }
  }

  Future<void> _loadMoreTagihan() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // _currentPage++;
      // For now, since backend might not support pagination,
      // we'll just mark hasMoreData as false
      setState(() {
        _hasMoreData = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading more tagihan: $e');
      }
      setState(() {
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedStatusFilter != null || _selectedPeriodeFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedPeriodeFilter = null;
      _hasActiveFilter = false;
    });
    _loadData();
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedStatusFilter != null) {
      String statusText;
      switch (_selectedStatusFilter) {
        case 'unpaid':
          statusText = languageProvider.getTranslatedText({
            'en': 'Unpaid',
            'id': 'Belum Bayar',
          });
          break;
        case 'pending':
          statusText = languageProvider.getTranslatedText({
            'en': 'Pending',
            'id': 'Pending',
          });
          break;
        case 'verified':
          statusText = languageProvider.getTranslatedText({
            'en': 'Verified',
            'id': 'Lunas',
          });
          break;
        default:
          statusText = _selectedStatusFilter!;
      }
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedPeriodeFilter != null) {
      final periodeText = _selectedPeriodeFilter == 'bulanan'
          ? languageProvider.getTranslatedText({
              'en': 'Monthly',
              'id': 'Bulanan',
            })
          : languageProvider.getTranslatedText({
              'en': 'Yearly',
              'id': 'Tahunan',
            });
      filterChips.add({
        'label': '${AppLocalizations.paymentPeriod.tr}: $periodeText',
        'onRemove': () {
          setState(() {
            _selectedPeriodeFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    // final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;
    String? tempSelectedPeriode = _selectedPeriodeFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.filter.tr,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSelectedStatus = null;
                          tempSelectedPeriode = null;
                        });
                      },
                      child: Text(
                        AppLocalizations.reset.tr,
                        style: TextStyle(color: _getPrimaryColor()),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Filter
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.paymentStatus.tr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  [
                                    {
                                      'value': 'unpaid',
                                      'label': AppLocalizations.unpaid.tr,
                                    },
                                    {
                                      'value': 'pending',
                                      'label': AppLocalizations.pending.tr,
                                    },
                                    {
                                      'value': 'verified',
                                      'label': AppLocalizations.paid.tr,
                                    },
                                  ].map((item) {
                                    final isSelected =
                                        tempSelectedStatus == item['value'];
                                    return FilterChip(
                                      label: Text(item['label']!),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          tempSelectedStatus = selected
                                              ? item['value']
                                              : null;
                                        });
                                      },
                                      backgroundColor: Colors.grey.shade100,
                                      selectedColor: _getPrimaryColor()
                                          .withOpacity(0.2),
                                      checkmarkColor: _getPrimaryColor(),
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? _getPrimaryColor()
                                            : Colors.grey.shade700,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // Divider
                      Container(
                        height: 1,
                        color: Colors.grey.shade300,
                        margin: EdgeInsets.symmetric(vertical: 8),
                      ),

                      // Periode Filter
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.paymentPeriod.tr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  [
                                    {
                                      'value': 'bulanan',
                                      'label': AppLocalizations.monthly.tr,
                                    },
                                    {
                                      'value': 'tahunan',
                                      'label': AppLocalizations.yearly.tr,
                                    },
                                  ].map((item) {
                                    final isSelected =
                                        tempSelectedPeriode == item['value'];
                                    return FilterChip(
                                      label: Text(item['label']!),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          tempSelectedPeriode = selected
                                              ? item['value']
                                              : null;
                                        });
                                      },
                                      backgroundColor: Colors.grey.shade100,
                                      selectedColor: _getPrimaryColor()
                                          .withOpacity(0.2),
                                      checkmarkColor: _getPrimaryColor(),
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? _getPrimaryColor()
                                            : Colors.grey.shade700,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Apply Button
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: _getPrimaryColor()),
                        ),
                        child: Text(
                          AppLocalizations.cancel.tr,
                          style: TextStyle(color: _getPrimaryColor()),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatusFilter = tempSelectedStatus;
                            _selectedPeriodeFilter = tempSelectedPeriode;
                          });
                          _checkActiveFilter();
                          Navigator.pop(context);
                          _loadData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          AppLocalizations.apply.tr,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dalam tagihan_wali.dart - Perbaiki _pickImage
  Future<void> _pickImage(StateSetter setDialogState) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show option to choose from gallery or camera
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.chooseSource.tr),
          content: Text(AppLocalizations.chooseImageSource.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: Text(AppLocalizations.gallery.tr),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
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
          // Validasi yang lebih ketat
          final allowedExtensions = ['.jpg', '.jpeg', '.png'];
          final filePath = file.path.toLowerCase();
          final fileExtension = filePath.split('.').last;

          bool isValidFile = allowedExtensions.any(
            (ext) => filePath.endsWith(ext),
          );

          if (!isValidFile) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.unsupportedFileFormat.tr),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          setDialogState(() {
            selectedFile = File(file.path);
          });

          if (kDebugMode) {
            print('File selected: ${file.path}');
            print('File extension: $fileExtension');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Tambahkan method ini di tagihan_wali.dart
  Future<void> _pickPDF(StateSetter setDialogState) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        setDialogState(() {
          selectedFile = file;
        });

        if (kDebugMode) {
          print('PDF selected: ${file.path}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking PDF: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFile(StateSetter setDialogState) async {
    try {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.chooseFileType.tr),
          content: Text(AppLocalizations.uploadPaymentProof.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'image'),
              child: Text(AppLocalizations.imageCameraGallery.tr),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'pdf'),
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
    } catch (e) {
      if (kDebugMode) {
        print('Error picking file: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<dynamic> _getFilteredBilling() {
    return _billingList.where((item) {
      final searchTerm = _searchController.text.toLowerCase();
      final name =
          item['jenis_pembayaran_nama']?.toString().toLowerCase() ?? '';
      final description =
          item['jenis_pembayaran_deskripsi']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          name.contains(searchTerm) ||
          description.contains(searchTerm);

      // Status filter matching
      final matchesStatus =
          _selectedStatusFilter == null ||
          (_selectedStatusFilter == 'unpaid' && item['status'] == 'unpaid') ||
          (_selectedStatusFilter == 'pending' &&
              item['pembayaran_status'] == 'pending') ||
          (_selectedStatusFilter == 'verified' &&
              (item['status'] == 'verified' ||
                  item['pembayaran_status'] == 'verified'));

      // Period filter matching
      final matchesPeriode =
          _selectedPeriodeFilter == null ||
          item['periode']?.toString().toLowerCase() == _selectedPeriodeFilter;

      return matchesSearch && matchesStatus && matchesPeriode;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(Map<String, dynamic> billing) {
    if (billing['pembayaran_status'] == 'verified') {
      return AppLocalizations.paid.tr;
    } else if (billing['pembayaran_status'] == 'pending') {
      return AppLocalizations.waitingForVerification.tr;
    } else if (billing['pembayaran_status'] == 'rejected') {
      return AppLocalizations.rejected.tr;
    } else {
      return AppLocalizations.unpaid.tr;
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

  void _showUploadPaymentDialog(Map<String, dynamic> billing) {
    final paymentMethodController = TextEditingController();
    final amountController = TextEditingController(
      text: billing['jumlah'] != null
          ? _formatCurrency(billing['jumlah']).replaceAll('Rp ', '')
          : '',
    );
    final paymentDateController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: _getCardGradient(),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.upload,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.uploadPaymentProof.tr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Info Tagihan
                        _buildInfoItem(
                          AppLocalizations.paymentTypes.tr,
                          billing['jenis_pembayaran_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          AppLocalizations.billAmount.tr,
                          _formatCurrency(billing['jumlah']),
                        ),
                        _buildInfoItem(
                          AppLocalizations.student.tr,
                          billing['siswa_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          AppLocalizations.classString.tr,
                          billing['kelas_nama'] ?? '-',
                        ),

                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),

                        // Form Pembayaran
                        DropdownButtonFormField<String>(
                          initialValue: paymentMethodController.text.isNotEmpty
                              ? paymentMethodController.text
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Metode Pembayaran',
                            prefixIcon: Icon(
                              Icons.payment,
                              color: _getPrimaryColor(),
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Transfer Bank',
                              child: Text('Transfer Bank'),
                            ),
                            DropdownMenuItem(
                              value: 'Tunai',
                              child: Text('Tunai'),
                            ),
                            DropdownMenuItem(
                              value: 'Kartu Kredit/Debit',
                              child: Text('Kartu Kredit/Debit'),
                            ),
                            DropdownMenuItem(
                              value: 'Lainnya',
                              child: Text('Lainnya'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              paymentMethodController.text = value;
                            }
                          },
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: amountController,
                          label: 'Jumlah Bayar',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: paymentDateController,
                          label: 'Tanggal Bayar',
                          icon: Icons.calendar_today,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              paymentDateController.text = date
                                  .toString()
                                  .split(' ')[0];
                            }
                          },
                        ),
                        SizedBox(height: 12),

                        // Upload File
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedFile != null
                                  ? Colors.green
                                  : Colors.grey.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.upload_file,
                                color: selectedFile != null
                                    ? Colors.green
                                    : Colors.grey,
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                selectedFile != null
                                    ? 'File terpilih: ${selectedFile!.path.split('/').last}'
                                    : 'Pilih bukti pembayaran',
                                style: TextStyle(
                                  color: selectedFile != null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              SizedBox(height: 4),
                              if (selectedFile != null)
                                Text(
                                  _getFileTypeText(selectedFile!.path),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _pickFile(setDialogState),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getPrimaryColor(),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Pilih File',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Format: JPG, JPEG, PNG, PDF',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                selectedFile == null ||
                                    paymentMethodController.text.isEmpty ||
                                    amountController.text.isEmpty ||
                                    paymentDateController.text.isEmpty
                                ? null
                                : () async {
                                    try {
                                      // Upload file dan data
                                      await _uploadPayment(
                                        billingId: billing['id'],
                                        paymentMethod:
                                            paymentMethodController.text,
                                        amount: double.parse(
                                          amountController.text
                                              .replaceAll('.', '')
                                              .replaceAll(',', ''),
                                        ),
                                        paymentDate: paymentDateController.text,
                                        file: selectedFile!,
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        _loadData();

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Bukti pembayaran berhasil diupload',
                                            ),
                                            backgroundColor:
                                                Colors.green.shade400,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ErrorUtils.getFriendlyMessage(
                                                error,
                                              ),
                                            ),
                                            backgroundColor:
                                                Colors.red.shade400,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Upload',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentDetailDialog(Map<String, dynamic> billing) {
    final payment = billing['latest_payment'];
    if (payment == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Detail Pembayaran',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            _buildInfoItem('Status', _getStatusText(billing)),
            _buildInfoItem(
              'Metode Pembayaran',
              payment['payment_method'] ?? '-',
            ),
            _buildInfoItem('Tanggal Bayar', payment['payment_date'] ?? '-'),
            _buildInfoItem(
              'Jumlah Dibayar',
              _formatCurrency(payment['amount']),
            ),
            SizedBox(height: 24),
            if (payment['payment_receipt'] != null) ...[
              Text(
                'Bukti Pembayaran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${ApiService.baseUrl.replaceAll('/api', '')}/storage/${payment['payment_receipt']}',
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gagal memuat gambar',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPayment({
    required String billingId,
    required String paymentMethod,
    required double amount,
    required String paymentDate,
    required File file,
  }) async {
    try {
      // Validasi file type sebelum upload
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.pdf'];
      final filePath = file.path.toLowerCase();
      final fileExtension = filePath.split('.').last;

      if (!allowedExtensions.any((ext) => filePath.endsWith(ext))) {
        throw Exception(
          'Format file tidak didukung. Gunakan JPG, JPEG, PNG, atau PDF.',
        );
      }

      // print('=== UPLOAD DEBUG INFO ===');
      // print('File path: ${file.path}');
      // print('File extension: $fileExtension');
      // print('File size: ${await file.length()} bytes');
      // print('Tagihan ID: $billingId');
      // print('Metode Bayar: $metodeBayar');
      // print('Jumlah Bayar: $jumlahBayar');
      // print('Tanggal Bayar: $tanggalBayar');
      // print('========================');

      // Upload file menggunakan multipart
      await _apiService.uploadFile(
        '/payments',
        file,
        fileField: 'payment_receipt',
        data: {
          'bill_id': billingId,
          'payment_method': paymentMethod,
          'amount': amount.toString(),
          'payment_date': paymentDate,
        },
      );
    } catch (error) {
      print('Error upload pembayaran: $error');
      rethrow;
    }
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onTap: onTap,
        readOnly: onTap != null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildTagihanCard(Map<String, dynamic> billing, int index) {
    final status = _getStatusText(billing);
    final statusColor = _getStatusColor(
      billing['pembayaran_status'] ?? billing['status'],
    );

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (_getStatusText(billing) == 'Belum Bayar' ||
                  billing['pembayaran_status'] == 'rejected') {
                _showUploadPaymentDialog(billing);
              } else {
                _showPaymentDetailDialog(billing);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Builder(
                builder: (context) {
                  final isRead =
                      billing['is_read'] == true ||
                      billing['is_read'] == 1 ||
                      billing['is_read'] == '1' ||
                      billing['is_read'] == 'true';

                  return Container(
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        // Strip berwarna di pinggir kiri
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 6,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor(),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                          ),
                        ),

                        // Background pattern effect / Unread Indicator
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.grey.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: isRead
                                ? null
                                : Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.4),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),

                        // Status badge positioned
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        // Content
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Judul tagihan
                              Padding(
                                padding: EdgeInsets.only(right: 80),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      billing['jenis_pembayaran_nama'] ??
                                          'No Name',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      _formatCurrency(billing['jumlah']),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 8),

                              if (billing['jenis_pembayaran_deskripsi'] !=
                                      null &&
                                  billing['jenis_pembayaran_deskripsi']
                                      .isNotEmpty)
                                Text(
                                  billing['jenis_pembayaran_deskripsi'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                              SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    billing['siswa_nama'] ?? '-',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.school,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    billing['kelas_nama'] ?? '-',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 4),

                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Jatuh Tempo: ${billing['jatuh_tempo']?.split('T')[0] ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),

                              if (billing['pembayaran_status'] == 'rejected' &&
                                  billing['admin_notes'] != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 8),
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade100,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info,
                                            size: 12,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Catatan: ${billing['admin_notes']}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                              SizedBox(height: 12),

                              if (billing['pembayaran_status'] != 'verified' &&
                                  billing['pembayaran_status'] != 'pending')
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _showUploadPaymentDialog(billing),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _getPrimaryColor(),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text(
                                      AppLocalizations.payNow.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getPrimaryColor() {
    return Color(0xFF9333EA); // Warna purple untuk wali murid
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.7)],
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppLocalizations.myBills.tr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_billingList.any((b) => b['is_read'] == false))
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_billingList.where((b) => b['is_read'] == false).length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_selectedStudent != null)
                      Text(
                        _selectedStudent!.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                  ],
                ),
              ),
              if (_students.length > 1)
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(canvasColor: _getPrimaryColor().withOpacity(0.9)),
                  child: DropdownButton<String>(
                    value: _selectedStudentId,
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != _selectedStudentId) {
                        setState(() {
                          _selectedStudentId = newValue;
                          _selectedStudent = _students.firstWhere(
                            (s) => s.id == newValue,
                          );
                          _billingList = [];
                          _processedIds.clear();
                          _pendingReadIds.clear();
                        });
                        _loadTagihan();
                      }
                    },
                    underline: SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    items: _students.map<DropdownMenuItem<String>>((Siswa s) {
                      return DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(
                          s.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadData,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.searchBills.tr,
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) {
                            setState(() {});
                          },
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search, color: _getPrimaryColor()),
                          onPressed: () {
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _hasActiveFilter
                      ? Colors.white
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: IconButton(
                  onPressed: _showFilterSheet,
                  icon: Icon(
                    Icons.tune,
                    color: _hasActiveFilter ? _getPrimaryColor() : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(message: 'Memuat data tagihan...');
        }

        if (_errorMessage.isNotEmpty) {
          return ErrorScreen(errorMessage: _errorMessage, onRetry: _loadData);
        }

        final filteredBilling = _getFilteredBilling();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              _buildHeader(languageProvider),
              if (_hasActiveFilter)
                Container(
                  height: 50,
                  margin: EdgeInsets.only(top: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ..._buildFilterChips(languageProvider).map((filter) {
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(
                              filter['label'],
                              style: TextStyle(
                                fontSize: 12,
                                color: _getPrimaryColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            deleteIcon: Icon(
                              Icons.close,
                              size: 16,
                              color: _getPrimaryColor(),
                            ),
                            onDeleted: filter['onRemove'],
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: _getPrimaryColor().withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                      if (_hasActiveFilter)
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: _clearAllFilters,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.clear_all,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    AppLocalizations.reset.tr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: filteredBilling.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: 100),
                            EmptyState(
                              title: 'No Bills',
                              subtitle:
                                  _searchController.text.isEmpty &&
                                      !_hasActiveFilter
                                  ? 'All bills are paid'
                                  : 'No results found',
                              icon: Icons.receipt,
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              filteredBilling.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredBilling.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getPrimaryColor(),
                                  ),
                                ),
                              );
                            }
                            return Builder(
                              builder: (context) {
                                // Track visibility for read status
                                final bill = filteredBilling[index];
                                _onItemVisible(
                                  bill['id'].toString(),
                                  bill['is_read'] == true ||
                                      bill['is_read'] == 1 ||
                                      bill['is_read'] == 'true',
                                );
                                return _buildTagihanCard(
                                  filteredBilling[index],
                                  index,
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
