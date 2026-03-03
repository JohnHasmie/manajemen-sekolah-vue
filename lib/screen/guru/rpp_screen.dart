import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/guru/rpp_ai_result_screen.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
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

class RppScreenState extends State<RppScreen> {
  List<dynamic> _rppList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String? _selectedStatusFilter;
  bool _hasActiveFilter = false;

  @override
  void initState() {
    super.initState();
    _loadRpp();
  }

  @override
  void dispose() {
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
                // Header (Pattern #11 gradient)
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Filter',
                                  'id': 'Filter',
                                }),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedStatus = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Reset',
                                'id': 'Reset',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: ColorUtils.slate700,
                            ),
                            SizedBox(width: 8),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Status',
                                'id': 'Status',
                              }),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.slate900,
                              ),
                            ),
                          ],
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

                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.05),
                        offset: Offset(0, -2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(color: ColorUtils.slate600),
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
                              padding: EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Apply Filter',
                                'id': 'Terapkan Filter',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
      selectedColor: _getPrimaryColor().withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate300,
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
    final languageProvider = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: ColorUtils.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Choose Action',
                'id': 'Pilih Aksi',
              }),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate900,
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showRppFormDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getPrimaryColor().withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 32,
                            color: _getPrimaryColor(),
                          ),
                          SizedBox(height: 12),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Upload Manual',
                              'id': 'Upload Manual',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getPrimaryColor(),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showGenerateRppFormDialog();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ColorUtils.success600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ColorUtils.success600.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 32,
                            color: ColorUtils.success600,
                          ),
                          SizedBox(height: 12),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Generate AI',
                              'id': 'Generate AI',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.success600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRppFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RppFormDialog(teacherId: widget.teacherId, onSaved: _loadRpp),
      ),
    );
  }

  void _showGenerateRppFormDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GenerateRppFormDialog(
          teacherId: widget.teacherId,
          onSaved: _loadRpp,
        ),
      ),
    );
  }

  void _editRpp(Map<String, dynamic> rpp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RppFormDialog(
          teacherId: widget.teacherId,
          onSaved: _loadRpp,
          rppData: rpp,
        ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.error600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
              backgroundColor: ColorUtils.success600,
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
              backgroundColor: ColorUtils.error600,
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
        return ColorUtils.success600;
      case 'Menunggu':
      case 'Pending':
        return ColorUtils.warning600;
      case 'Ditolak':
      case 'Rejected':
        return ColorUtils.error600;
      case 'Draft':
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return 'Disetujui';
      case 'Pending':
      case 'Menunggu':
        return 'Menunggu';
      case 'Draft':
      case 'draft':
        return 'Draft';
      case 'Rejected':
      case 'Ditolak':
        return 'Ditolak';
      default:
        return status ?? '-';
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
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    Color? tagColor,
  }) {
    final color = tagColor ?? ColorUtils.slate500;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildRppCard(Map<String, dynamic> rpp, int index) {
    final accentColor = ColorUtils.getColorForIndex(index);
    final statusColor = _getStatusColor(rpp['status'] ?? '');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _lihatDetailRpp(rpp),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + title/subject + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rpp['judul'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            rpp['mata_pelajaran_nama'] ?? 'No Subject',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate50,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusLabel(rpp['status']),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),
                // Info tags: class
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildInfoTag(
                      icon: Icons.class_,
                      label: rpp['kelas_nama'] ?? 'No Class',
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.visibility_outlined,
                      color: _getPrimaryColor(),
                      onPressed: () => _lihatDetailRpp(rpp),
                    ),
                    SizedBox(width: 8),
                    _buildCircleActionButton(
                      icon: Icons.edit_outlined,
                      color: ColorUtils.warning600,
                      onPressed: () => _editRpp(rpp),
                    ),
                    SizedBox(width: 8),
                    _buildCircleActionButton(
                      icon: Icons.delete_outlined,
                      color: ColorUtils.error600,
                      onPressed: () => _deleteRpp(rpp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 36,
              color: ColorUtils.slate400,
            ),
          ),
          SizedBox(height: 20),
          Text(
            AppLocalizations.noRppCreated.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.clickPlusToCreate.tr,
            style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ColorUtils.error600,
              ),
            ),
            SizedBox(height: 20),
            Text(
              AppLocalizations.error.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadRpp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(AppLocalizations.retry.tr),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
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
                  color: _getPrimaryColor().withValues(alpha: 0.3),
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
                          color: Colors.white.withValues(alpha: 0.2),
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
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _loadRpp,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
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
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: ColorUtils.slate800),
                                decoration: InputDecoration(
                                  hintText: languageProvider.getTranslatedText({
                                    'en': 'Search RPP...',
                                    'id': 'Cari RPP...',
                                  }),
                                  hintStyle: TextStyle(
                                    color: ColorUtils.slate400,
                                  ),
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
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
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
                                  color: ColorUtils.error600,
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
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
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
            child: _isLoading
                ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                : _errorMessage != null
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add, color: Colors.white),
      ),
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

  // File Upload Logic Removed - Using simplified version

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

  Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    VoidCallback? onTap,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        onTap: onTap,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<dynamic>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final primaryColor = _getPrimaryColor();
    final isEditMode = widget.rppData != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Pattern #10 gradient)
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: ColorUtils.heroGradient(primaryColor: primaryColor),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isEditMode ? Icons.edit_note : Icons.add_task,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditMode
                                ? languageProvider.getTranslatedText({
                                    'en': 'Edit RPP',
                                    'id': 'Edit RPP',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Add New RPP',
                                    'id': 'Tambah RPP Baru',
                                  }),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            isEditMode
                                ? languageProvider.getTranslatedText({
                                    'en': 'Update RPP details',
                                    'id': 'Perbarui detail RPP',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Create a new RPP document',
                                    'id': 'Buat dokumen RPP baru',
                                  }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      controller: _judulController,
                      label: '${AppLocalizations.title.tr} *',
                      icon: Icons.title_rounded,
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Enter RPP title',
                        'id': 'Masukkan judul RPP',
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.titleRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedMataPelajaranId,
                      label: '${AppLocalizations.subject.tr} *',
                      icon: Icons.book_outlined,
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
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedClassId,
                      label: '${AppLocalizations.class_.tr} *',
                      icon: Icons.class_outlined,
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
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedSemester,
                      label: '${AppLocalizations.semester.tr} *',
                      icon: Icons.calendar_view_month_rounded,
                      items: ['Ganjil', 'Genap'].map((semester) {
                        return DropdownMenuItem(
                          value: semester,
                          child: Text(semester),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSemester = value;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: _tahunAjaranController,
                      label: '${AppLocalizations.academicYear.tr} *',
                      icon: Icons.calendar_today_rounded,
                      hintText: '2024/2025',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.academicYearRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // File upload section
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'File Attachment',
                        'id': 'Lampiran File',
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        border: Border.all(color: ColorUtils.slate200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _selectedFileName != null
                                  ? ColorUtils.info600.withValues(alpha: 0.1)
                                  : ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _selectedFileName != null
                                  ? Icons.description_rounded
                                  : Icons.upload_file_rounded,
                              color: _selectedFileName != null
                                  ? ColorUtils.info600
                                  : ColorUtils.slate400,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName ??
                                      languageProvider.getTranslatedText({
                                        'en': 'No file selected',
                                        'id': 'Belum ada file dipilih',
                                      }),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedFileName != null
                                        ? ColorUtils.slate800
                                        : ColorUtils.slate400,
                                    fontWeight: _selectedFileName != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedFileName == null)
                                  Text(
                                    'PDF, DOC, DOCX',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ColorUtils.slate400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isEditMode &&
                              widget.rppData!['file_path'] != null)
                            GestureDetector(
                              onTap: _viewCurrentFile,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: ColorUtils.info600.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ColorUtils.info600.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: ColorUtils.info600,
                                ),
                              ),
                            ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showFilePickerDialog,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Choose',
                                  'id': 'Pilih',
                                }),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
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
          ),

          // Footer Buttons (Enhanced Pattern)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        AppLocalizations.cancel.tr,
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isUploading
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEditMode
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Update',
                                      'id': 'Perbarui',
                                    })
                                  : AppLocalizations.save.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
}

// RppDetailPage tetap sama seperti sebelumnya
// Helper to download and open file
Future<void> _downloadAndOpenFile(BuildContext context, String filePath) async {
  try {
    // Construct full URL properly
    // If ApiService.baseUrl is "https://edu-api.kamillabs.com/api"
    // Static files are usually at "https://edu-api.kamillabs.com/uploads/..."
    // We stripping the '/api' suffix to get the root.
    final rootUrl = ApiService.baseUrl.replaceFirst('/api', '');

    // Ensure filePath doesn't double slash and is properly combined
    String cleanPath = filePath;
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }

    final fullUrl = '$rootUrl$cleanPath';

    if (kDebugMode) {
      print('Downloading file from: $fullUrl');
    }

    final languageProvider = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.getTranslatedText({
            'en': 'Downloading file...',
            'id': 'Mengunduh file...',
          }),
        ),
      ),
    );

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
    } else if (response.statusCode == 404) {
      throw Exception(
        languageProvider.getTranslatedText({
          'en': 'File not found on server',
          'id': 'File tidak ditemukan di server',
        }),
      );
    } else {
      throw Exception(
        '${languageProvider.getTranslatedText({'en': 'Failed to download file', 'id': 'Gagal mengunduh file'})}: ${response.statusCode}',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error opening file: $e');
    }

    String message = e.toString().replaceFirst('Exception: ', '');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ColorUtils.error600),
    );
  }
}

class RppDetailPage extends StatelessWidget {
  final Map<String, dynamic> rpp;

  const RppDetailPage({super.key, required this.rpp});

  Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Disetujui':
      case 'Approved':
        return ColorUtils.success600;
      case 'Menunggu':
      case 'Pending':
        return ColorUtils.warning600;
      case 'Ditolak':
      case 'Rejected':
        return ColorUtils.error600;
      case 'Draft':
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'Approved':
      case 'Disetujui':
        return 'Disetujui';
      case 'Pending':
      case 'Menunggu':
        return 'Menunggu';
      case 'Draft':
      case 'draft':
        return 'Draft';
      case 'Rejected':
      case 'Ditolak':
        return 'Ditolak';
      default:
        return status ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final statusColor = _getStatusColor(rpp['status']);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Pattern #7 Inline Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.85),
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
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
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
                        AppLocalizations.rppDetails.tr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if ((rpp['judul'] ?? '').isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          rpp['judul'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Status card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rpp['judul'] ?? 'No Title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _getStatusLabel(rpp['status']),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Info Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'RPP Information',
                            'id': 'Informasi RPP',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate600,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildDetailItem(
                          languageProvider.getTranslatedText({
                            'en': 'Subject',
                            'id': 'Mata Pelajaran',
                          }),
                          rpp['mata_pelajaran_nama'] ?? '-',
                        ),
                        _buildDetailItem(
                          languageProvider.getTranslatedText({
                            'en': 'Class',
                            'id': 'Kelas',
                          }),
                          rpp['kelas_nama'] ?? '-',
                        ),
                        _buildDetailItem(
                          languageProvider.getTranslatedText({
                            'en': 'Academic Year',
                            'id': 'Tahun Ajaran',
                          }),
                          '${rpp['semester'] ?? '-'} ${rpp['tahun_ajaran'] ?? '-'}',
                        ),
                        if (rpp['catatan'] != null &&
                            rpp['catatan'].toString().isNotEmpty)
                          _buildDetailItem(
                            languageProvider.getTranslatedText({
                              'en': 'Notes',
                              'id': 'Catatan',
                            }),
                            rpp['catatan'],
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // File Section
                  if (rpp['file_path'] != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ColorUtils.slate200),
                        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              _downloadAndOpenFile(context, rpp['file_path']),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: ColorUtils.info600.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: ColorUtils.info600,
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Attached File',
                                          'id': 'File Terlampir',
                                        }),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ColorUtils.slate900,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        rpp['file_path'].split('/').last,
                                        style: TextStyle(
                                          color: ColorUtils.slate500,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.download_rounded,
                                  color: ColorUtils.slate400,
                                ),
                              ],
                            ),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class GenerateRppFormDialog extends StatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;

  const GenerateRppFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
  });

  @override
  State<GenerateRppFormDialog> createState() => _GenerateRppFormDialogState();
}

class _GenerateRppFormDialogState extends State<GenerateRppFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _tahunAjaranController = TextEditingController();

  String? _selectedMataPelajaranId;
  String? _selectedClassId;
  String? _selectedBabId;
  String? _selectedSubBabId;
  String? _selectedSemester = 'Ganjil';
  bool _isAutoGenerating = false;

  List<dynamic> _mataPelajaranList = [];
  List<dynamic> _kelasList = [];
  List<dynamic> _babList = [];
  List<dynamic> _subBabList = [];

  @override
  void initState() {
    super.initState();
    _loadMataPelajaranByGuru();
    _tahunAjaranController.text = DateTime.now().year.toString();
  }

  Future<void> _loadMataPelajaranByGuru() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.teacherId}/mata-pelajaran',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
    } catch (e) {
      _loadAllMataPelajaran();
    }
  }

  Future<void> _loadAllMataPelajaran() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        if (result is Map && result['data'] is List) {
          _mataPelajaranList = result['data'];
        } else if (result is List) {
          _mataPelajaranList = result;
        } else {
          _mataPelajaranList = [];
        }
      });
    } catch (e) {
      if (kDebugMode) print('Error loading all mata pelajaran: $e');
    }
  }

  Future<void> _loadKelasByMataPelajaran(String mataPelajaranId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/class-by-mata-pelajaran?mata_pelajaran_id=$mataPelajaranId',
      );
      setState(() {
        if (result is Map && result['data'] is List) {
          _kelasList = result['data'];
        } else if (result is List) {
          _kelasList = result;
        } else {
          _kelasList = [];
        }
      });
    } catch (e) {
      setState(() {
        _kelasList = [];
      });
    }
  }

  Future<void> _loadBabByMataPelajaran(String subjectId) async {
    try {
      final result = await ApiSubjectService.getBabMateri(subjectId: subjectId);
      setState(() {
        _babList = result;
      });
    } catch (e) {
      setState(() {
        _babList = [];
      });
    }
  }

  Future<void> _loadSubBabByBab(String babId) async {
    try {
      final result = await ApiSubjectService.getSubBabMateri(babId: babId);
      setState(() {
        _subBabList = result;
      });
    } catch (e) {
      setState(() {
        _subBabList = [];
      });
    }
  }

  // Helper untuk membersihkan HTML tag menjadi teks biasa
  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (html.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAutoGenerating = true;
    });

    try {
      // Simulasi generate RPP untuk saat ini (frontend saja sesuai request)
      // MOCK RESPONSE berdasarkan KamillLabs Edu AI API Documentation
      await Future.delayed(const Duration(seconds: 2));

      final mockRppResponse = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _judulController.text.isNotEmpty
            ? _judulController.text
            : 'RPP Judul Otomatis',
        // Menyimpan id untuk referensi, tapi menampilkan nama jika ada (di backend ini akan direlasikan)
        'subject_id': _selectedMataPelajaranId,
        'mata_pelajaran_nama':
            _mataPelajaranList.firstWhere(
              (m) => m['id'].toString() == _selectedMataPelajaranId,
              orElse: () => {'name': 'Mata Pelajaran'},
            )['name'] ??
            'Mata Pelajaran',
        'class_id': _selectedClassId,
        'kelas_nama':
            _kelasList.firstWhere(
              (k) => k['id'].toString() == _selectedClassId,
              orElse: () => {'name': 'Kelas'},
            )['name'] ??
            'Kelas',
        'semester': _selectedSemester,
        'tahun_ajaran': _tahunAjaranController.text,

        // 10 Field AI Generated
        'core_competence':
            '<p>Menghayati dan mengamalkan ajaran agama yang dianutnya. Menghayati dan mengamalkan perilaku jujur, disiplin, santun, peduli (gotong royong, kerjasama, toleran, damai), bertanggung jawab, responsif, dan pro-aktif dalam berinteraksi secara efektif sesuai dengan perkembangan anak di lingkungan, keluarga, sekolah, masyarakat dan lingkungan alam sekitar, bangsa, negara, kawasan regional, dan kawasan internasional.</p>',
        'basic_competence':
            '<p>3.1 Mendeskripsikan konsep dan penerapan materi terkait dalam kehidupan sehari-hari.</p><p>4.1 Menyelesaikan masalah kontekstual yang berkaitan dengan materi ini.</p>',
        'indicator':
            '<ol><li>Mengidentifikasi konsep dasar.</li><li>Menjelaskan langkah-langkah penyelesaian.</li><li>Menerapkan rumus/konsep pada soal cerita.</li></ol>',
        'learning_objective':
            '<ol><li>Melalui diskusi kelompok, siswa dapat menjelaskan konsep dasar dengan benar.</li><li>Diberikan latihan soal, siswa dapat menghitung nilai dengan tingkat akurasi 90%.</li><li>Melalui presentasi, siswa dapat menunjukkan penerapan konsep di dunia nyata.</li></ol>',
        'main_material':
            '<h3>Materi Pokok</h3><ul><li>Definisi dan Konsep Dasar</li><li>Karakteristik dan Sifat Utama</li><li>Contoh Penerapan dan Studi Kasus</li></ul>',
        'learning_method':
            '<p>Pendekatan: Scientific Learning</p><p>Model: Problem Based Learning (PBL)</p><p>Metode: Diskusi kelompok, tanya jawab, penugasan, dan presentasi.</p>',
        'media_tools':
            '<ul><li>Papan tulis dan spidol</li><li>Proyektor LCD dan Laptop</li><li>Lembar Kerja Peserta Didik (LKPD)</li><li>Aplikasi pendukung / Video Pembelajaran</li></ul>',
        'learning_source':
            '<ul><li>Buku Paket Siswa Kelas ${_kelasList.firstWhere((k) => k['id'].toString() == _selectedClassId, orElse: () => {'name': ''})['name'] ?? ''}</li><li>Internet / Modul Pengayaan Tambahan</li></ul>',
        'learning_activities':
            '<h3>Pendahuluan (15 menit)</h3><ul><li>Guru membuka dengan salam dan doa.</li><li>Guru mengecek kehadiran siswa.</li><li>Apersepsi: Guru mengaitkan materi sebelumnya dengan yang akan dipelajari hari ini.</li><li>Motivasi: Guru menyampaikan tujuan pembelajaran.</li></ul><h3>Kegiatan Inti (60 menit)</h3><ul><li><strong>Mengamati:</strong> Siswa mengamati video/gambar terkait materi.</li><li><strong>Menanya:</strong> Guru mendorong siswa mengajukan pertanyaan tentang apa yang diamati.</li><li><strong>Mengeksplorasi:</strong> Siswa dibagi dalam kelompok untuk mengerjakan LKPD.</li><li><strong>Mengasosiasi:</strong> Siswa mengolah data dan informasi yang didapat.</li><li><strong>Mengkomunikasikan:</strong> Setiap perwakilan kelompok mempresentasikan hasil diskusinya.</li></ul><h3>Kegiatan Penutup (15 menit)</h3><ul><li>Siswa bersama guru menyimpulkan pembelajaran.</li><li>Refleksi: Guru menanyakan perasaan siswa setelah belajar.</li><li>Guru memberikan tugas mandiri / PR.</li><li>Berdoa dan salam penutup.</li></ul>',
        'assessment':
            '<h3>1. Penilaian Sikap</h3><p>Observasi keaktifan dan kerjasama selama diskusi kelompok.</p><h3>2. Penilaian Pengetahuan</h3><p>Tes tertulis (pilihan ganda dan uraian) di akhir pelajaran.</p><h3>3. Penilaian Keterampilan</h3><p>Penilaian rubrik saat presentasi hasil kerja kelompok di depan kelas.</p>',

        // Metadata AI
        'status': 'draft',
        'ai_generated': true,
        'ai_model_used': 'claude-sonnet-4-5-20250929',
        'ai_tokens_used': 3200,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('Mock RPP Generated: ${mockRppResponse['title']}');
      }

      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog generate AI

      // Mapping 10 komponen AI ke format form RPP 3 Komponen (K-13)
      final mappedRppData = {
        'id': null, // Barudibuat, belum ada ID di database manual
        'judul': mockRppResponse['title'],
        'mata_pelajaran_id': mockRppResponse['subject_id'],
        'satuan_pendidikan': 'SD/MI', // Default yang dapat diedit
        'kelas_semester':
            '${mockRppResponse['kelas_nama']} / ${mockRppResponse['semester']}',
        'tema': mockRppResponse['title'], // Biasanya diisi judul
        'sub_tema': '',
        'pembelajaran_ke': '1',
        'alokasi_waktu': _tahunAjaranController
            .text, // Menyimpan tahun ajaran sementara atau default
        'waktu_pendahuluan': '15',
        'waktu_inti': '140',
        'waktu_penutup': '15',
        'tujuan_pembelajaran': _stripHtml(
          mockRppResponse['learning_objective'] as String? ?? '',
        ),
        // Karena form K-13 punya 3 input berbeda untuk kegiatan:
        // Kita menggunakan learning_activities AI di kegiatan_inti, atau bisa dipisah jika AI sangat terstruktur.
        // Untuk amannya, kita gabungkan semua learning activities AI ke 'kegiatan_inti' form
        'kegiatan_pendahuluan':
            '• Melakukan Pembukaan dengan Salam dan Membaca Doa\n• Mengaitkan Materi Sebelumnya dengan Materi yang akan dipelajari', // Placeholder bisa diganti stripHtml
        'kegiatan_inti': _stripHtml(
          mockRppResponse['learning_activities'] as String? ?? '',
        ),
        'kegiatan_penutup':
            '• Siswa membuat resume dengan bimbingan guru\n• Guru memeriksa pekerjaan siswa\n• Pemberian hadiah/pujian untuk pekerjaan yang benar',
        'penilaian': _stripHtml(mockRppResponse['assessment'] as String? ?? ''),
        'is_ai_generated': true,
      };

      // Buka halaman hasil AI RPP yang baru dibuat (K-13 Editor)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RppAiResultScreen(
            rppData: mappedRppData, // Kirim data yang sudah di mapping K-13
            teacherId: widget.teacherId,
            onSaved: () {
              widget.onSaved();
            },
          ),
        ),
      );

      final languageProvider = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'RPP successfully AI-generated.',
              'id': 'RPP berhasil di-generate AI.',
            }),
          ),
          backgroundColor: ColorUtils.success600,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.error.tr}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAutoGenerating = false;
        });
      }
    }
  }

  Color _getPrimaryColor() => ColorUtils.success600;

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required dynamic value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<dynamic>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final primaryColor = _getPrimaryColor();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Pattern #10 gradient)
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Generate RPP with AI',
                              'id': 'Generate RPP dengan AI',
                            }),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            languageProvider.getTranslatedText({
                              'en':
                                  'Create interactive RPP documents automatically',
                              'id': 'Buat dokumen RPP secara otomatis',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      controller: _judulController,
                      label: '${AppLocalizations.title.tr} *',
                      icon: Icons.title_rounded,
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Enter RPP title',
                        'id': 'Masukkan judul RPP',
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.titleRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedMataPelajaranId,
                      label: '${AppLocalizations.subject.tr} *',
                      icon: Icons.book_outlined,
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
                      onChanged: (value) {
                        setState(() {
                          _selectedMataPelajaranId = value.toString();
                          _selectedClassId = null;
                          _selectedBabId = null;
                          _selectedSubBabId = null;
                          _babList = [];
                          _subBabList = [];
                        });
                        _loadKelasByMataPelajaran(value.toString());
                        _loadBabByMataPelajaran(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return AppLocalizations.subjectRequired.tr;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedClassId,
                            label: '${AppLocalizations.class_.tr} *',
                            icon: Icons.class_outlined,
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
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedSemester,
                            label: '${AppLocalizations.semester.tr} *',
                            icon: Icons.calendar_view_month_rounded,
                            items: ['Ganjil', 'Genap'].map((semester) {
                              return DropdownMenuItem(
                                value: semester,
                                child: Text(semester),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSemester = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedBabId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Chapter', 'id': 'Bab'})} *',
                      icon: Icons.bookmark_border_rounded,
                      items: _babList.map((bab) {
                        return DropdownMenuItem(
                          value: bab['id'],
                          child: Text(
                            bab['judul_bab'] ??
                                bab['title'] ??
                                bab['judul'] ??
                                'Tanpa Nama',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBabId = value.toString();
                          _selectedSubBabId = null;
                          _subBabList = [];
                        });
                        _loadSubBabByBab(value.toString());
                      },
                      validator: (value) {
                        if (value == null) {
                          return languageProvider.getTranslatedText({
                            'en': 'Chapter is required',
                            'id': 'Bab harus dipilih',
                          });
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogDropdown(
                      value: _selectedSubBabId,
                      label:
                          '${languageProvider.getTranslatedText({'en': 'Sub Chapter', 'id': 'Sub Bab'})} (Opsional)',
                      icon: Icons.bookmark_add_outlined,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'None',
                              'id': 'Tidak ada',
                            }),
                            style: TextStyle(color: ColorUtils.slate400),
                          ),
                        ),
                        ..._subBabList.map((subBab) {
                          return DropdownMenuItem(
                            value: subBab['id'],
                            child: Text(
                              subBab['judul_sub_bab'] ??
                                  subBab['title'] ??
                                  subBab['judul'] ??
                                  'Tanpa Nama',
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSubBabId = value?.toString();
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: _tahunAjaranController,
                      label: '${AppLocalizations.academicYear.tr} *',
                      icon: Icons.calendar_today_rounded,
                      hintText: '2024/2025',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.academicYearRequired.tr;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer Buttons (Enhanced Pattern)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAutoGenerating
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        AppLocalizations.cancel.tr,
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAutoGenerating ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shadowColor: primaryColor.withValues(alpha: 0.4),
                      ),
                      child: _isAutoGenerating
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              languageProvider.getTranslatedText({
                                'en': 'Generate',
                                'id': 'Generate',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
}
