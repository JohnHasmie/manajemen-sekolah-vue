import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class RppScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const RppScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  RppScreenState createState() => RppScreenState();
}

class RppScreenState extends State<RppScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _rppList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String? _selectedStatusFilter;
  bool _hasActiveFilter = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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

    _loadRpp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
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
            height: MediaQuery.of(context).size.height * 0.4,
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
                            _loadRpp();
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

  Future<void> _loadRpp() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final rppData = await ApiService.getRPP(
        teacherId: widget.teacherId,
        search: _searchController.text,
        status: _selectedStatusFilter,
        academicYearId: academicYearId,
      );

      setState(() {
        _rppList = rppData;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      if (kDebugMode) print('Load RPP error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  void _tambahRpp() {
    showDialog(
      context: context,
      builder: (context) =>
          RppFormDialog(teacherId: widget.teacherId, onSaved: _loadRpp),
    );
  }

  void _editRpp(Map<String, dynamic> rpp) {
    showDialog(
      context: context,
      builder: (context) => RppFormDialog(
        teacherId: widget.teacherId,
        onSaved: _loadRpp,
        rppData: rpp,
      ),
    );
  }

  Future<void> _deleteRpp(Map<String, dynamic> rpp) async {
    final languageProvider = context.read<LanguageProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.confirmDelete.tr),
        content: Text(
          languageProvider.getTranslatedText({
            'en': 'Are you sure you want to delete RPP "${rpp['judul']}"?',
            'id': 'Apakah Anda yakin ingin menghapus RPP "${rpp['judul']}"?',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.cancel.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              AppLocalizations.delete.tr,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteRPP(rpp['id']);
        _loadRpp();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getTranslatedText({
                  'en': 'RPP deleted successfully',
                  'id': 'RPP berhasil dihapus',
                }),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) print('Delete RPP error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${languageProvider.getTranslatedText({'en': 'Failed to delete RPP: ', 'id': 'Gagal menghapus RPP: '})}${ErrorUtils.getFriendlyMessage(e)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _lihatDetailRpp(Map<String, dynamic> rpp) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RppDetailPage(rpp: rpp)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Approved':
        return Colors.green;
      case 'Menunggu':
      case 'Pending':
        return Colors.orange;
      case 'Ditolak':
      case 'Rejected':
        return Colors.red;
      case 'draft':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Approved':
        return Icons.check_circle;
      case 'Menunggu':
      case 'Pending':
        return Icons.access_time;
      case 'Ditolak':
      case 'Rejected':
        return Icons.cancel;
      case 'draft':
        return Icons.drafts;
      default:
        return Icons.help;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor],
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
            onTap: () => _lihatDetailRpp(rpp),
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
                  // Strip berwarna di pinggir kiri
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
                                    rpp['judul'] ?? 'No Title',
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
                                    '${rpp['mata_pelajaran_nama'] ?? 'No Subject'}',
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
                                    : rpp['status'] == 'draft'
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

                        // Informasi kelas
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
                                    rpp['kelas_nama'] ?? 'No Class',
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

                        SizedBox(height: 12),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildActionButton(
                              icon: Icons.visibility,
                              label: 'Detail',
                              color: _getPrimaryColor(),
                              onPressed: () => _lihatDetailRpp(rpp),
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.edit,
                              label: 'Edit',
                              color: _getPrimaryColor(),
                              onPressed: () => _editRpp(rpp),
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete,
                              label: 'Hapus',
                              color: Colors.red,
                              onPressed: () => _deleteRpp(rpp),
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
          border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            AppLocalizations.noRppCreated.tr,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.clickPlusToCreate.tr,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${AppLocalizations.error.tr}: $_errorMessage'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRpp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPrimaryColor(),
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.retry.tr),
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
          return Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_getPrimaryColor()),
              ),
            ),
          );
        }

        final filteredRpp = _rppList;

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header dengan gradient
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
                          onTap: () => Navigator.pop(context),
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
                                AppLocalizations.rppList.tr,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                AppLocalizations.viewAndManageRpp.tr,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadRpp,
                          tooltip: AppLocalizations.refresh.tr,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search Bar with Filter Button
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
                                      hintText: languageProvider
                                          .getTranslatedText({
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
                                    onSubmitted: (_) {
                                      _loadRpp();
                                    },
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(right: 4),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.search,
                                      color: _getPrimaryColor(),
                                    ),
                                    onPressed: _loadRpp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Filter Button
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
                    ),

                    // Filter Chips
                    if (_hasActiveFilter) ...[
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
                child: _errorMessage != null
                    ? _buildErrorState()
                    : filteredRpp.isEmpty
                    ? _buildEmptyState(languageProvider)
                    : RefreshIndicator(
                        onRefresh: _loadRpp,
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            top: 16,
                            bottom: 16,
                            left: 5,
                            right: 5,
                          ),
                          itemCount: filteredRpp.length,
                          itemBuilder: (context, index) {
                            final rpp = filteredRpp[index];
                            return _buildRppCard(rpp, index);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _tambahRpp,
            backgroundColor: _getPrimaryColor(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}

// RppFormDialog tetap sama seperti sebelumnya
class RppFormDialog extends StatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;
  final Map<String, dynamic>? rppData;

  const RppFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
    this.rppData,
  });

  @override
  State<RppFormDialog> createState() => _RppFormDialogState();
}

class _RppFormDialogState extends State<RppFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _tahunAjaranController = TextEditingController();

  String? _selectedMataPelajaranId;
  String? _selectedClassId;
  String? _selectedSemester = 'Ganjil';
  String? _selectedFileName;
  File? _selectedFile;
  bool _isUploading = false;

  List<dynamic> _mataPelajaranList = [];
  List<dynamic> _kelasList = [];

  @override
  void initState() {
    super.initState();
    _loadMataPelajaranByGuru();

    // Jika mode edit, isi field dengan data RPP
    if (widget.rppData != null) {
      _judulController.text =
          widget.rppData!['judul'] ?? widget.rppData!['title'] ?? '';
      _tahunAjaranController.text =
          widget.rppData!['academic_year'] ??
          widget.rppData!['tahun_ajaran'] ??
          '';
      _selectedMataPelajaranId =
          (widget.rppData!['subject_id'] ??
                  widget.rppData!['mata_pelajaran_id'])
              ?.toString();
      _selectedClassId =
          (widget.rppData!['class_id'] ?? widget.rppData!['kelas_id'])
              ?.toString();
      _selectedSemester = widget.rppData!['semester'] ?? 'Ganjil';
      _selectedFileName = widget.rppData!['file_path'];

      if (_selectedMataPelajaranId != null) {
        _loadKelasByMataPelajaran(_selectedMataPelajaranId!);
      }
    } else {
      // Mode tambah baru: set default tahun ajaran
      _tahunAjaranController.text = DateTime.now().year.toString();
    }
  }

  Future<void> _loadMataPelajaranByGuru() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran',
      );
      setState(() {
        // Backend returns {success: true, data: [...], pagination: {...}}
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
      if (kDebugMode) {
        print('Loaded ${_mataPelajaranList.length} mata pelajaran');
        if (_mataPelajaranList.isNotEmpty) {
          print('DEBUG SUBJECT ITEM: ${_mataPelajaranList.first}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading mata pelajaran by guru: $e');
      }
      _loadAllMataPelajaran();
    }
  }

  Future<void> _loadAllMataPelajaran() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        // Backend might return {success: true, data: [...]} or direct array
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading all mata pelajaran: $e');
      }
    }
  }

  Future<void> _loadKelasByMataPelajaran(String mataPelajaranId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$mataPelajaranId',
      );
      setState(() {
        // Backend might return {success: true, data: [...]} or direct array
        if (result is Map && result['data'] is List) {
          _kelasList = result['data'];
        } else if (result is List) {
          _kelasList = result;
        } else {
          _kelasList = [];
        }
      });
      if (kDebugMode) {
        print(
          'Loaded ${_kelasList.length} kelas for mata pelajaran $mataPelajaranId',
        );
        if (_kelasList.isNotEmpty) {
          print('DEBUG CLASS ITEM: ${_kelasList.first}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading kelas by mata pelajaran: $e');
        setState(() {
          _kelasList = [];
        });
      }
    }
  }

  void _showFilePickerDialog() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        PlatformFile file = result.files.first;

        // Pastikan file benar-benar ada
        File selectedFile = File(file.path!);
        bool fileExists = await selectedFile.exists();

        print('File picked: ${file.name}');
        print('File path: ${file.path}');
        print('File exists: $fileExists');
        print('File size: ${file.size} bytes');

        if (fileExists) {
          setState(() {
            _selectedFileName = file.name;
            _selectedFile = selectedFile;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error picking file: $e');
    }
  }

  Future<void> _viewCurrentFile() async {
    final filePath = widget.rppData?['file_path'];
    if (filePath != null) {
      // Use the helper function defined at the bottom of the file
      await _downloadAndOpenFile(context, filePath);
    }
  }

  void _setSelectedFile(String fileName) {
    setState(() {
      _selectedFileName = fileName;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String? filePath;

      // Debug: Cek apakah file ada
      print('File selected: $_selectedFile');
      print('File name: $_selectedFileName');

      if (_selectedFile != null) {
        try {
          print('Starting file upload...');
          final uploadResult = await ApiService.uploadFileRPP(_selectedFile!);
          print('Upload result: $uploadResult');

          filePath = uploadResult['file_path'];
          print('File uploaded successfully: $filePath');
        } catch (uploadError) {
          print('Error during file upload: $uploadError');
          // Tetap lanjut tanpa file jika upload gagal
          filePath = null;
        }
      } else {
        print('No file selected for upload');
      }

      // Debug data yang akan dikirim
      print('Submitting RPP data:');
      print('- Guru ID: ${widget.teacherId}');
      print('- Mata Pelajaran ID: $_selectedMataPelajaranId');
      print('- Kelas ID: $_selectedClassId');
      print('- Judul: ${_judulController.text}');
      print('- File Path: $filePath');

      final rppData = {
        'subject_id': _selectedMataPelajaranId,
        'class_id': _selectedClassId,
        'title': _judulController.text,
        'semester': _selectedSemester,
        'academic_year': _tahunAjaranController.text,
        'file_path': filePath ?? _selectedFileName,
      };

      // Submit data RPP (mode edit atau tambah)
      if (widget.rppData != null) {
        // Mode edit
        await ApiService.updateRPP(widget.rppData!['id'], rppData);
        print('RPP updated successfully');
      } else {
        // Mode tambah baru
        rppData['teacher_id'] = widget.teacherId;
        await ApiService.tambahRPP(rppData);
        print('RPP created successfully');
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();

      final languageProvider = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.rppData != null
                ? languageProvider.getTranslatedText({
                    'en': 'RPP updated successfully',
                    'id': 'RPP berhasil diupdate',
                  })
                : AppLocalizations.rppCreatedSuccess.tr,
          ),
        ),
      );
    } catch (e) {
      print('Error creating RPP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.error.tr}: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return AlertDialog(
      title: Text(
        widget.rppData != null
            ? languageProvider.getTranslatedText({
                'en': 'Edit RPP',
                'id': 'Edit RPP',
              })
            : AppLocalizations.createRpp.tr,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _judulController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.title.tr} *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.titleRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.subject.tr} *',
                ),
                items: _mataPelajaranList.map((mp) {
                  return DropdownMenuItem(
                    value: mp['id'],
                    child: Text(
                      mp['name'] ??
                          mp['nama'] ??
                          mp['subject_name'] ??
                          'Tanpa Nama',
                    ),
                  );
                }).toList(),
                initialValue: _selectedMataPelajaranId,
                onChanged: (value) {
                  setState(() {
                    _selectedMataPelajaranId = value.toString();
                    _selectedClassId = null;
                  });
                  _loadKelasByMataPelajaran(value.toString());
                },
                validator: (value) {
                  if (value == null) {
                    return AppLocalizations.subjectRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.class_.tr} *',
                ),
                items: _kelasList.map((kelas) {
                  return DropdownMenuItem(
                    value: kelas['id'],
                    child: Text(
                      kelas['name'] ??
                          kelas['nama'] ??
                          kelas['class_name'] ??
                          'Tanpa Nama',
                    ),
                  );
                }).toList(),
                initialValue: _selectedClassId,
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value.toString();
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return AppLocalizations.classNameRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.semester.tr} *',
                ),
                items: ['Ganjil', 'Genap'].map((semester) {
                  return DropdownMenuItem(
                    value: semester,
                    child: Text(semester),
                  );
                }).toList(),
                initialValue: _selectedSemester,
                onChanged: (value) {
                  setState(() {
                    _selectedSemester = value;
                  });
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _tahunAjaranController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.academicYear.tr} *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.academicYearRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFileName ??
                            languageProvider.getTranslatedText({
                              'en': 'No file selected',
                              'id': 'Belum ada file dipilih',
                            }),
                        style: TextStyle(
                          color: _selectedFileName != null
                              ? Colors.black87
                              : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.rppData != null &&
                        widget.rppData!['file_path'] != null)
                      IconButton(
                        icon: Icon(Icons.visibility, color: Colors.blue),
                        onPressed: _viewCurrentFile,
                        tooltip: 'Lihat File',
                      ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _showFilePickerDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Choose',
                          'id': 'Pilih',
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.cancel.tr),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submitForm,
          child: _isUploading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(),
                )
              : Text(AppLocalizations.save.tr),
        ),
      ],
    );
  }
}

// RppDetailPage tetap sama seperti sebelumnya
// Helper to download and open file
Future<void> _downloadAndOpenFile(BuildContext context, String filePath) async {
  try {
    // Construct full URL
    // Remove /uploads prefix or handle correctly if it's relative
    // If filePath starts with /uploads, append to baseUrl (stripping /api if needed or just use host)
    // ApiService.baseUrl usually implies /api or just host?
    // Let's assume ApiService.baseUrl is "http://host:port/api"
    // And static files are at "http://host:port/uploads/..."
    // We need to parse baseUrl to get root.

    final baseUrl = ApiService.baseUrl;
    final uri = Uri.parse(baseUrl);
    final rootUrl = '${uri.scheme}://${uri.host}:${uri.port}';

    // Ensure filePath doesn't double slash
    final cleanPath = filePath.startsWith('/') ? filePath : '/$filePath';
    final fullUrl = '$rootUrl$cleanPath';

    if (kDebugMode) {
      print('Downloading file from: $fullUrl');
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Mengunduh file...')));

    final response = await http.get(Uri.parse(fullUrl));

    if (response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      // Extract filename
      final fileName = cleanPath.split('/').last;
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(response.bodyBytes);

      if (kDebugMode) {
        print('File saved to: ${file.path}');
      }

      await OpenFile.open(file.path);
    } else {
      throw Exception('Failed to download file: ${response.statusCode}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error opening file: $e');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal membuka file: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class RppDetailPage extends StatelessWidget {
  final Map<String, dynamic> rpp;

  const RppDetailPage({super.key, required this.rpp});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA), // Light grey background
      body: CustomScrollView(
        slivers: [
          // Header Gradient with Back Button
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.getRoleColor('guru').withOpacity(0.8),
                    ColorUtils.getRoleColor('guru'),
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: EdgeInsets.only(left: 56, bottom: 16),
                title: Text(
                  AppLocalizations.rppDetails.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Card
                  _buildDetailCard(
                    title: languageProvider.getTranslatedText({
                      'en': 'Title',
                      'id': 'Judul',
                    }),
                    content: rpp['judul'] ?? 'No Title',
                    icon: Icons.title,
                    isTitle: true,
                  ),
                  SizedBox(height: 16),

                  // Info Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.book,
                            label: languageProvider.getTranslatedText({
                              'en': 'Subject',
                              'id': 'Mata Pelajaran',
                            }),
                            value: rpp['mata_pelajaran_nama'] ?? '-',
                          ),
                          Divider(),
                          _buildDetailRow(
                            icon: Icons.class_,
                            label: languageProvider.getTranslatedText({
                              'en': 'Class',
                              'id': 'Kelas',
                            }),
                            value: rpp['kelas_nama'] ?? '-',
                          ),
                          Divider(),
                          _buildDetailRow(
                            icon: Icons.calendar_today,
                            label: languageProvider.getTranslatedText({
                              'en': 'Academic Year',
                              'id': 'Tahun Ajaran',
                            }),
                            value:
                                '${rpp['semester'] ?? '-'} ${rpp['tahun_ajaran'] ?? '-'}',
                          ),
                          Divider(),
                          _buildDetailRow(
                            icon: Icons.info_outline,
                            label: languageProvider.getTranslatedText({
                              'en': 'Status',
                              'id': 'Status',
                            }),
                            value: rpp['status'] ?? '-',
                            valueColor: _getStatusColor(rpp['status']),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // File Section
                  if (rpp['file_path'] != null)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () =>
                            _downloadAndOpenFile(context, rpp['file_path']),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.blue,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Attached File',
                                        'id': 'File Terlampir',
                                      }),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      rpp['file_path'].split('/').last,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.download_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required String content,
    required IconData icon,
    bool isTitle = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isTitle
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isTitle ? Colors.blue : Colors.grey[700],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: isTitle ? 18 : 16,
                      fontWeight: isTitle ? FontWeight.bold : FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Disetujui':
      case 'Approved':
        return Colors.green;
      case 'Menunggu':
      case 'Pending':
        return Colors.orange;
      case 'Ditolak':
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
