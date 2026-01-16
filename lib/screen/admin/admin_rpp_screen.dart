import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/excel_rpp_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class AdminRppScreen extends StatefulWidget {
  final String? teacherId;
  final String? teacherName;

  const AdminRppScreen({super.key, this.teacherId, this.teacherName});

  @override
  State<AdminRppScreen> createState() => _AdminRppScreenState();
}

class _AdminRppScreenState extends State<AdminRppScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _rppList = [];
  List<dynamic> _teacherList = [];
  bool _showTeacherList = true;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Pagination state
  int _currentPage = 1;
  final int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  // pagination meta kept server-side; not stored locally to avoid unused warnings
  Timer? _searchDebounce;

  // Filter States
  String?
  _selectedStatusFilter; // 'Pending', 'Approved', 'Rejected', or null for all
  bool _hasActiveFilter = false;

  late AnimationController _animationController;
  // animations: only controller is needed; per-card animations are created locally

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreData &&
          !_isLoading) {
        if (_showTeacherList && widget.teacherId == null) {
          _loadTeachersPaginated();
        } else {
          _loadRppPaginated();
        }
      }
    });

    // Check if we start with a specific teacher (e.g. from deeper navigation)
    if (widget.teacherId != null) {
      _showTeacherList = false;
      _selectedTeacherId = widget.teacherId;
      _selectedTeacherName = widget.teacherName;
      _loadRppPaginated(reset: true);
    } else {
      _showTeacherList = true;
      _loadTeachersPaginated(reset: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedStatusFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _hasActiveFilter = false;
    });
  }

  String _buildFilterSummary(LanguageProvider languageProvider) {
    List<String> filters = [];

    if (_selectedStatusFilter != null) {
      filters.add(
        '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $_selectedStatusFilter',
      );
    }

    return filters.join(' • ');
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Filter',
                          'id': 'Filter',
                        }),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempSelectedStatus = null;
                          });
                        },
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Reset',
                            'id': 'Reset',
                          }),
                          style: TextStyle(color: _getPrimaryColor()),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Filter
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Status',
                            'id': 'Status',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'All',
                                'id': 'Semua',
                              }),
                              value: null,
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = null;
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Menunggu',
                              value: 'Pending',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Pending';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Disetujui',
                              value: 'Approved',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Approved';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Ditolak',
                              value: 'Rejected',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Rejected';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        offset: Offset(0, -2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: _getPrimaryColor()),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Cancel',
                              'id': 'Batal',
                            }),
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
                            });
                            _checkActiveFilter();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPrimaryColor(),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Apply Filter',
                              'id': 'Terapkan Filter',
                            }),
                            style: TextStyle(color: Colors.white),
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
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: _getPrimaryColor().withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : Colors.grey.shade300,
      ),
    );
  }

  Future<void> _exportToExcel() async {
    await ExcelRppService.exportRppToExcel(rppList: _rppList, context: context);
  }

  Future<void> _loadRppByTeacher() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // deprecated: use paginated loader
      await _loadRppPaginated(reset: true);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadAllRpp() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Refresh using paginated endpoint
      await _loadRppPaginated(reset: true);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadTeachersPaginated({bool reset = false}) async {
    try {
      if (reset) {
        _currentPage = 1;
        _hasMoreData = true;
      }

      setState(() {
        if (reset) {
          _isLoading = true;
          _errorMessage = null;
          _teacherList = [];
        } else {
          _isLoadingMore = true;
        }
      });

      // Using the method from ApiTeacherService we checked earlier
      final result = await ApiTeacherService.getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );

      if (result['success'] == true || result['data'] != null) {
        final List<dynamic> data = result['data'] ?? [];
        final pagination = result['pagination'] ?? {};

        if (mounted) {
          setState(() {
            if (reset) {
              _teacherList = data;
            } else {
              _teacherList.addAll(data);
            }

            _hasMoreData =
                pagination['has_next_page'] ?? (data.length == _perPage);
            _isLoading = false;
            _isLoadingMore = false;
          });
          _animationController.forward();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage = 'Failed to load teachers';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadRppPaginated({bool reset = false}) async {
    try {
      if (reset) {
        _currentPage = 1;
        _hasMoreData = true;
      }

      setState(() {
        if (reset) {
          _isLoading = true;
          _errorMessage = null;
        } else {
          _isLoadingMore = true;
        }
      });

      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final result = await ApiService.getRppPaginated(
        page: _currentPage,
        limit: _perPage,
        teacherId: _selectedTeacherId,
        status: _selectedStatusFilter,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        academicYearId: academicYearId,
      );

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];

        final pagination = result['pagination'] ?? {};

        setState(() {
          if (reset) {
            _rppList = data;
          } else {
            _rppList.addAll(data);
          }

          _hasMoreData =
              pagination['has_next_page'] ?? (data.length == _perPage);
          _isLoading = false;
          _isLoadingMore = false;
        });

        _animationController.forward();
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Failed to load RPP';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _selectTeacher(Map<String, dynamic> teacher) {
    setState(() {
      _selectedTeacherId =
          teacher['user_id']?.toString() ??
          teacher['id'].toString(); // Try user_id first, fallback to id
      _selectedTeacherName = teacher['name'];
      _showTeacherList = false;
      _rppList = [];
      _searchController.clear();
      _currentPage = 1;
    });
    _loadRppPaginated(reset: true);
  }

  void _backToTeacherList() {
    setState(() {
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _showTeacherList = true;
      _rppList = [];
      _searchController.clear();
      _currentPage = 1;
    });
    _loadTeachersPaginated(reset: true);
  }

  void _handleSearch() {
    if (_showTeacherList && widget.teacherId == null) {
      _loadTeachersPaginated(reset: true);
    } else {
      _loadRppPaginated(reset: true);
    }
  }

  void _updateStatus(String rppId, String status) {
    final rpp = _rppList.firstWhere((rpp) => rpp['id'] == rppId);
    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        rppId: rppId,
        currentStatus: rpp['status'],
        currentNote: rpp['catatan'],
        onStatusUpdated: _loadAllRpp,
      ),
    );
  }

  void _viewRppDetail(Map<String, dynamic> rpp) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RppAdminDetailPage(rpp: rpp)),
    );
    // Refresh list after returning
    if (_showTeacherList && _selectedTeacherName != null) {
      _loadRppByTeacher();
    } else if (!_showTeacherList) {
      _loadRppByTeacher(); // Or logic to reload current list
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return Colors.green;
      case 'Pending':
      case 'Menunggu':
        return Colors.orange;
      case 'Rejected':
      case 'Ditolak':
        return Colors.red;
      case 'Draft':
      case 'draft':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // status icon helper not used currently

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor()],
    );
  }

  Widget _buildRppCard(Map<String, dynamic> rpp, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedBuilder(
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _viewRppDetail(rpp),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Strip biru di pinggir kiri
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: _getPrimaryColor(),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // Background pattern effect
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan judul dan status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rpp['judul'] ?? rpp['title'] ?? 'No Title',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '${rpp['mata_pelajaran_nama'] ?? rpp['subject_name'] ?? 'No Subject'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  rpp['status'],
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getStatusColor(
                                    rpp['status'],
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                rpp['status'] == 'Pending' ||
                                        rpp['status'] == 'Menunggu'
                                    ? 'Menunggu'
                                    : rpp['status'] == 'Approved' ||
                                          rpp['status'] == 'Disetujui'
                                    ? 'Disetujui'
                                    : rpp['status'] == 'draft' ||
                                          rpp['status'] == 'Draft'
                                    ? 'Draft'
                                    : 'Ditolak',
                                style: TextStyle(
                                  color: _getStatusColor(rpp['status']),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Informasi kelas dan guru
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.school,
                                color: _getPrimaryColor(),
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kelas',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    rpp['kelas_nama'] ??
                                        rpp['class_name'] ??
                                        'No Class',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.person,
                                color: _getPrimaryColor(),
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Guru',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    rpp['teacher_name'] ??
                                        rpp['guru_nama'] ??
                                        'No Teacher',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildActionButton(
                              icon: Icons.visibility,
                              label: 'Detail',
                              color: _getPrimaryColor(),
                              onPressed: () => _viewRppDetail(rpp),
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.edit,
                              label: 'Status',
                              color: _getPrimaryColor(),
                              onPressed: () =>
                                  _updateStatus(rpp['id'], rpp['status']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final delay = index * 0.05;
          final animation = CurvedAnimation(
            parent: _animationController,
            curve: Interval(delay, 1.0, curve: Curves.easeOut),
          );

          return FadeTransition(
            opacity: animation,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - animation.value)),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectTeacher(teacher),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        teacher['name'] != null && teacher['name'].isNotEmpty
                            ? teacher['name'][0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: _getPrimaryColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacher['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          teacher['employee_number'] != null
                              ? 'NIP: ${teacher['employee_number']}'
                              : 'No NIP',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading data...',
              'id': 'Memuat data...',
            }),
          );
        }

        if (_errorMessage != null) {
          return ErrorScreen(
            errorMessage: _errorMessage!,
            onRetry: _showTeacherList ? _loadTeachersPaginated : _loadAllRpp,
          );
        }

        // Apply filters for RPP list (Teacher list is filtered by backend)
        final filteredRpp = _rppList.where((rpp) {
          if (_showTeacherList)
            return true; // Don't filter if showing teachers (not used)

          final searchTerm = _searchController.text.toLowerCase();
          final matchesSearch =
              searchTerm.isEmpty ||
              (rpp['judul']?.toLowerCase().contains(searchTerm) ?? false) ||
              (rpp['mata_pelajaran_nama']?.toLowerCase().contains(searchTerm) ??
                  false) ||
              (rpp['teacher_name']?.toLowerCase().contains(searchTerm) ??
                  false) || // Updated to teacher_name
              (rpp['guru_nama']?.toLowerCase().contains(searchTerm) ??
                  false) || // Keep as fallback
              (rpp['kelas_nama']?.toLowerCase().contains(searchTerm) ?? false);

          // Status filter
          final matchesStatusFilter =
              _selectedStatusFilter == null ||
              rpp['status'] == _selectedStatusFilter;

          return matchesSearch && matchesStatusFilter;
        }).toList();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header
              Container(
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
                          onTap: () {
                            if (_showTeacherList) {
                              Navigator.pop(context);
                            } else {
                              if (widget.teacherId != null) {
                                // Came from outside with fixed teacher
                                Navigator.pop(context);
                              } else {
                                // Navigate back to teacher list
                                _backToTeacherList();
                              }
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showTeacherList
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Select Teacher',
                                        'id': 'Pilih Guru',
                                      })
                                    : (_selectedTeacherName != null
                                          ? 'RPP - $_selectedTeacherName'
                                          : languageProvider.getTranslatedText({
                                              'en': 'Manage RPP',
                                              'id': 'Kelola RPP',
                                            })),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_showTeacherList ||
                                  _selectedTeacherName == null)
                                SizedBox(height: 2),
                              if (_showTeacherList ||
                                  _selectedTeacherName == null)
                                Text(
                                  _showTeacherList
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Select a teacher to view RPP',
                                          'id': 'Pilih guru untuk melihat RPP',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Manage lesson plans',
                                          'id':
                                              'Kelola rencana pelaksanaan pembelajaran',
                                        }),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!_showTeacherList) // Only show options in RPP view
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'export':
                                  _exportToExcel();
                                  break;
                                case 'refresh':
                                  _loadRppByTeacher();
                                  break;
                              }
                            },
                            icon: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.download, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Export to Excel',
                                        'id': 'Export ke Excel',
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'refresh',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Refresh',
                                        'id': 'Refresh',
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search Bar
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
                                    onSubmitted: (_) => _handleSearch(),
                                    style: TextStyle(color: Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: _showTeacherList
                                          ? languageProvider.getTranslatedText({
                                              'en': 'Search Teacher...',
                                              'id': 'Cari Guru...',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en': 'Search RPP...',
                                              'id': 'Cari RPP...',
                                            }),
                                      hintStyle: TextStyle(color: Colors.grey),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.grey,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(right: 4),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.search,
                                      color: _getPrimaryColor(),
                                    ),
                                    onPressed: _handleSearch,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_showTeacherList) ...[
                          SizedBox(width: 8),
                          // Filter Button (RPP only)
                          Container(
                            decoration: BoxDecoration(
                              color: _hasActiveFilter
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Stack(
                              children: [
                                IconButton(
                                  onPressed: _showFilterSheet,
                                  icon: Icon(
                                    Icons.tune,
                                    color: _hasActiveFilter
                                        ? _getPrimaryColor()
                                        : Colors.white,
                                  ),
                                  tooltip: languageProvider.getTranslatedText({
                                    'en': 'Filter',
                                    'id': 'Filter',
                                  }),
                                ),
                                if (_hasActiveFilter)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: BoxConstraints(
                                        minWidth: 8,
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Filter Chips (RPP only)
                    if (!_showTeacherList && _hasActiveFilter) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _buildFilterSummary(languageProvider),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _clearAllFilters,
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _showTeacherList
                    ? (() {
                        final searchTerm = _searchController.text.toLowerCase();
                        final filteredTeachers = _teacherList.where((teacher) {
                          if (searchTerm.isEmpty) return true;
                          final name =
                              teacher['name']?.toString().toLowerCase() ?? '';
                          // Optional: Filter by NIP too if desired
                          // final nip = teacher['employee_number']?.toString().toLowerCase() ?? '';
                          return name.contains(searchTerm);
                        }).toList();

                        if (filteredTeachers.isEmpty) {
                          return EmptyState(
                            title: languageProvider.getTranslatedText({
                              'en': 'No Teachers',
                              'id': 'Tidak ada Guru',
                            }),
                            subtitle: _searchController.text.isNotEmpty
                                ? languageProvider.getTranslatedText({
                                    'en': 'No teachers found matching search',
                                    'id':
                                        'Tidak ditemukan guru dengan pencarian tersebut',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'No teacher data available',
                                    'id': 'Tidak ada data guru',
                                  }),
                            icon: Icons.people,
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () => _loadTeachersPaginated(reset: true),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(top: 16, bottom: 16),
                            itemCount:
                                filteredTeachers.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= filteredTeachers.length) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return _buildTeacherCard(
                                filteredTeachers[index],
                                index,
                              );
                            },
                          ),
                        );
                      })()
                    : (filteredRpp.isEmpty
                          ? EmptyState(
                              title: languageProvider.getTranslatedText({
                                'en': 'No RPP',
                                'id': 'Tidak ada RPP',
                              }),
                              subtitle:
                                  _searchController.text.isEmpty &&
                                      !_hasActiveFilter
                                  ? languageProvider.getTranslatedText({
                                      'en': 'No RPP data available',
                                      'id': 'Tidak ada data RPP',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'No search results found',
                                      'id': 'Tidak ditemukan hasil pencarian',
                                    }),
                              icon: Icons.description,
                            )
                          : RefreshIndicator(
                              onRefresh: _loadRppByTeacher,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.only(
                                  top: 16,
                                  bottom: 16,
                                  left: 5,
                                  right: 5,
                                ),
                                itemCount:
                                    filteredRpp.length +
                                    (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= filteredRpp.length) {
                                    // loading indicator
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final rpp = filteredRpp[index];
                                  return _buildRppCard(rpp, index);
                                },
                              ),
                            )),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ... (UpdateStatusDialog dan RppAdminDetailPage tetap sama seperti sebelumnya)
class UpdateStatusDialog extends StatefulWidget {
  final String rppId;
  final String currentStatus;
  final String? currentNote;
  final VoidCallback onStatusUpdated;

  const UpdateStatusDialog({
    super.key,
    required this.rppId,
    required this.currentStatus,
    this.currentNote,
    required this.onStatusUpdated,
  });

  @override
  State<UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends State<UpdateStatusDialog> {
  bool _isUpdating = false;
  late TextEditingController _catatanController;
  String _selectedStatus = 'Pending';

  @override
  void initState() {
    super.initState();
    _catatanController = TextEditingController(text: widget.currentNote ?? '');
    _mapInitialStatus();
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  void _mapInitialStatus() {
    // Map Indonesian/Display status to Backend/Value status
    String status = widget.currentStatus ?? 'Pending';
    if (status == 'Menunggu' || status == 'Pending') {
      _selectedStatus = 'Pending';
    } else if (status == 'Disetujui' || status == 'Approved') {
      _selectedStatus = 'Approved';
    } else if (status == 'Ditolak' || status == 'Rejected') {
      _selectedStatus = 'Rejected';
    } else {
      _selectedStatus = 'Pending';
    }
  }

  Future<void> _updateStatus() async {
    // Check if either status or note has changed
    bool statusChanged = _selectedStatus != widget.currentStatus;
    bool noteChanged = _catatanController.text != (widget.currentNote ?? '');

    if (!statusChanged && !noteChanged) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await ApiService.updateStatusRPP(
        widget.rppId,
        _selectedStatus,
        catatan: _catatanController.text.isNotEmpty
            ? _catatanController.text
            : null,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onStatusUpdated();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Status RPP berhasil diupdate')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update Status RPP'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items:
                  [
                    {'value': 'Pending', 'label': 'Menunggu'},
                    {'value': 'Approved', 'label': 'Disetujui'},
                    {'value': 'Rejected', 'label': 'Ditolak'},
                  ].map((status) {
                    return DropdownMenuItem(
                      value: status['value'],
                      child: Text(status['label']!),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _catatanController,
              decoration: InputDecoration(
                labelText: 'Catatan (Opsional)',
                border: OutlineInputBorder(),
                hintText: 'Berikan catatan untuk guru...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorUtils.primaryColor,
          ),
          child: _isUpdating
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// Halaman Detail RPP untuk Admin
class RppAdminDetailPage extends StatelessWidget {
  final Map<String, dynamic> rpp;

  const RppAdminDetailPage({super.key, required this.rpp});
  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Detail RPP',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _getPrimaryColor(),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'approve') {
                _showUpdateStatusDialog(context, 'Disetujui');
              } else if (value == 'reject') {
                _showUpdateStatusDialog(context, 'Ditolak');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'approve',
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Setujui RPP'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reject',
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Tolak RPP'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan status
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rpp['title'] ?? '-',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(rpp['status']),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      rpp['status'] == 'Pending' || rpp['status'] == 'Menunggu'
                          ? 'Menunggu'
                          : rpp['status'] == 'Approved' ||
                                rpp['status'] == 'Disetujui'
                          ? 'Disetujui'
                          : rpp['status'] == 'draft' || rpp['status'] == 'Draft'
                          ? 'Draft'
                          : 'Ditolak',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Informasi Detail
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi RPP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildDetailItem(
                    'Guru Pengajar',
                    rpp['teacher_name'] ?? rpp['teacher']?['name'] ?? '-',
                  ),
                  _buildDetailItem(
                    'Mata Pelajaran',
                    rpp['subject_name'] ?? rpp['mata_pelajaran_nama'] ?? '-',
                  ),
                  _buildDetailItem(
                    'Kelas',
                    rpp['class_name'] ?? rpp['kelas_nama'] ?? '-',
                  ),
                  _buildDetailItem(
                    'Tahun Ajaran',
                    '${rpp['academic_year'] ?? rpp['tahun_ajaran'] ?? '-'}',
                  ),
                  _buildDetailItem('Semester', rpp['semester'] ?? '-'),
                  _buildDetailItem(
                    'Tanggal Dibuat',
                    rpp['created_at']?.toString().substring(0, 10) ?? '-',
                  ),
                  if (rpp['catatan'] != null &&
                      rpp['catatan'].toString().isNotEmpty)
                    _buildDetailItem('Catatan', rpp['catatan']),

                  if (rpp['catatan_admin'] != null) ...[
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    Text(
                      'Catatan Admin',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      rpp['catatan_admin']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 16),

            // Isi RPP
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Isi RPP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildContentSection(
                    'Kompetensi Inti',
                    rpp['core_competence'],
                  ),
                  _buildContentSection(
                    'Kompetensi Dasar',
                    rpp['basic_competence'],
                  ),
                  _buildContentSection('Indikator', rpp['indicator']),
                  _buildContentSection(
                    'Tujuan Pembelajaran',
                    rpp['learning_objective'],
                  ),
                  _buildContentSection('Materi Pokok', rpp['main_material']),
                  _buildContentSection(
                    'Metode Pembelajaran',
                    rpp['learning_method'],
                  ),
                  _buildContentSection('Media/Alat', rpp['media_tools']),
                  _buildContentSection(
                    'Sumber Belajar',
                    rpp['learning_source'],
                  ),
                  _buildContentSection(
                    'Langkah-langkah Pembelajaran',
                    rpp['learning_activities'],
                  ),
                  _buildContentSection('Penilaian', rpp['assessment']),
                ],
              ),
            ),

            // File Attachment
            if (rpp['file_path'] != null) ...[
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lampiran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _downloadAndOpenFile(context, rpp['file_path']),
                      icon: Icon(Icons.download),
                      label: Text('Download RPP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUpdateStatusDialog(BuildContext context, String status) {
    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        rppId: rpp['id'],
        currentStatus: rpp['status'],
        currentNote: rpp['catatan'],
        onStatusUpdated: () {
          Navigator.pop(context); // Kembali ke list
        },
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(String title, String? content) {
    if (content == null || content.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              content,
              style: TextStyle(color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenFile(
    BuildContext context,
    String? filePath,
  ) async {
    if (filePath == null) return;

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mengunduh file...')));

      // Create proper URL
      // ApiService.baseUrl usually ends with /api
      // We need base URL without /api
      final baseUrlBase = ApiService.baseUrl.replaceAll('/api', '');
      String fileUrl;
      if (filePath.startsWith('http')) {
        fileUrl = filePath;
      } else {
        fileUrl = '$baseUrlBase/storage/$filePath';
      }

      print('Downloading from: $fileUrl');

      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = filePath.split('/').last;
        final file = File('${directory.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download berhasil! Membuka file...')),
        );

        final result = await OpenFile.open(file.path);

        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuka file: ${result.message}')),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengunduh file: $e')));
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return Colors.green;
      case 'Pending':
      case 'Menunggu':
        return Colors.orange;
      case 'Rejected':
      case 'Ditolak':
        return Colors.red;
      case 'Draft':
      case 'draft':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
