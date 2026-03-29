// Page for managing class assignments for a specific subject.
// Extracted from admin_subject_management_screen.dart to reduce file size.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/enhanced_search_bar.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

class SubjectClassManagementPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subject;

  const SubjectClassManagementPage({super.key, required this.subject});

  @override
  SubjectClassManagementPageState createState() =>
      SubjectClassManagementPageState();
}

class SubjectClassManagementPageState
    extends ConsumerState<SubjectClassManagementPage> {
  final ApiService apiService = ApiService();
  List<dynamic> availableClasses = [];
  List<dynamic> assignedClasses0 = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();

    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Load all available classes
      final allClassesResponse = await apiService.get('/class');

      // Load classes already assigned to this subject
      final assignedClassesRaw = await apiService.get(
        '${ApiEndpoints.classBySubject}?subject_id=${widget.subject['id'].toString()}',
      );

      // Handle Map format (pagination) or direct List
      List<dynamic> assignedClasses;
      if (assignedClassesRaw is Map<String, dynamic>) {
        assignedClasses = assignedClassesRaw['data'] ?? [];
      } else if (assignedClassesRaw is List) {
        assignedClasses = assignedClassesRaw;
      } else {
        assignedClasses = [];
      }

      // Handle both Map (pagination) and List formats for allClasses
      List<dynamic> allClasses;
      if (allClassesResponse is Map<String, dynamic>) {
        allClasses = allClassesResponse['data'] ?? [];
      } else if (allClassesResponse is List) {
        allClasses = allClassesResponse;
      } else {
        allClasses = [];
      }

      setState(() {
        availableClasses = allClasses;
        assignedClasses0 = assignedClasses;
        isLoading = false;
      });

      if (allClasses.isNotEmpty) {
        AppLogger.debug('subject', 'First class data: ${allClasses[0]}');
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: $error');
      }
    }
  }

  Future<void> addClassToSubject(Map<String, dynamic> classItem) async {
    try {
      await getIt<ApiSubjectService>().attachClass(
        widget.subject['id'].toString(),
        classItem['id'].toString(),
      );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Kelas ${classItem['name']} berhasil ditambahkan',
        );
      }

      loadData();
    } catch (error) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: $error');
      }
    }
  }

  Future<void> removeClassFromSubject(Map<String, dynamic> classItem) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: AppLocalizations.removeClass.tr,
        content:
            '${ref.read(languageRiverpod).getTranslatedText({'en': 'Are you sure you want to remove class', 'id': 'Yakin ingin menghapus kelas'})} ${classItem['name']} ${ref.read(languageRiverpod).getTranslatedText({'en': 'from this subject?', 'id': 'dari mata pelajaran ini?'})}',
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        await getIt<ApiSubjectService>().detachClass(
          widget.subject['id'].toString(),
          classItem['id'].toString(),
        );

        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            'Kelas ${classItem['name']} berhasil dihapus',
          );
        }

        loadData();
      } catch (error) {
        if (mounted) {
          SnackBarUtils.showError(context, 'Error: $error');
        }
      }
    }
  }

  // Method to quickly add classes
  void showQuickAddClassDialog() {
    final unassignedClasses = availableClasses.where((classItem) {
      return !isClassAssigned(classItem['id']);
    }).toList();

    if (unassignedClasses.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        'Semua kelas sudah ditambahkan ke mata pelajaran ini',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20, 20, 16, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          getPrimaryColor(),
                          getPrimaryColor().withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Kelas',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pilih kelas untuk ditambahkan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => AppNavigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pilih kelas yang ingin ditambahkan ke ${widget.subject['nama']}:',
                          style: TextStyle(
                            fontSize: 14,
                            color: ColorUtils.slate600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: AppSpacing.lg),

                        // Search bar dalam dialog
                        Container(
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Cari classItem...',
                              hintStyle: TextStyle(color: ColorUtils.slate400),
                              prefixIcon: Icon(
                                Icons.search,
                                color: ColorUtils.corporateBlue600,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setDialogState(() {});
                            },
                          ),
                        ),
                        SizedBox(height: AppSpacing.lg),

                        Container(
                          constraints: BoxConstraints(maxHeight: 300),
                          child: unassignedClasses.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 48,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'Semua kelas sudah ditambahkan',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: unassignedClasses.length,
                                  itemBuilder: (context, index) {
                                    final classItem = unassignedClasses[index];
                                    return Card(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      elevation: 1,
                                      child: ListTile(
                                        leading: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: getPrimaryColor().withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.class_,
                                            color: getPrimaryColor(),
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          classItem['name'] ?? 'Kelas',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (classItem['tingkat'] != null)
                                              Text(
                                                'Tingkat: ${classItem['tingkat']}',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            if (classItem['wali_kelas_nama'] !=
                                                null)
                                              Text(
                                                'Wali: ${classItem['wali_kelas_nama']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: ColorUtils.slate500,
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Container(
                                          decoration: BoxDecoration(
                                            color: getPrimaryColor(),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        onTap: () {
                                          AppNavigator.pop(context);
                                          addClassToSubject(classItem);
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Actions footer
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: ColorUtils.slate100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
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
                                color: ColorUtils.slate600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              AppNavigator.pop(context);
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                            child: Text(
                              'Lihat Semua',
                              style: TextStyle(fontWeight: FontWeight.w600),
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

  bool isClassAssigned(String classId) {
    return assignedClasses0.any((classItem) => classItem['id'] == classId);
  }

  List<dynamic> getFilteredClasses() {
    final searchTerm = searchController.text.toLowerCase();
    return availableClasses.where((classItem) {
      final className = classItem['name']?.toString().toLowerCase() ?? '';
      final classLevel = classItem['tingkat']?.toString().toLowerCase() ?? '';
      final homeroomTeacher =
          classItem['wali_kelas_nama']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          className.contains(searchTerm) ||
          classLevel.contains(searchTerm) ||
          homeroomTeacher.contains(searchTerm);

      final isAssigned = isClassAssigned(classItem['id']);

      final matchesFilter =
          selectedFilter == 'All' ||
          (selectedFilter == 'Assigned' && isAssigned) ||
          (selectedFilter == 'Unassigned' && !isAssigned);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget buildClassCard(
    Map<String, dynamic> classItem,
    int index,
    bool isAssigned,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAssigned
              ? ColorUtils.corporateBlue600.withValues(alpha: 0.3)
              : ColorUtils.slate200,
          width: isAssigned ? 1.5 : 1,
        ),
        boxShadow: ColorUtils.corporateShadow(
          elevation: isAssigned ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (isAssigned) {
              removeClassFromSubject(classItem);
            } else {
              addClassToSubject(classItem);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAssigned
                        ? ColorUtils.corporateBlue600.withValues(alpha: 0.1)
                        : ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isAssigned
                          ? ColorUtils.corporateBlue600.withValues(alpha: 0.2)
                          : ColorUtils.slate200,
                    ),
                  ),
                  child: Icon(
                    Icons.class_outlined,
                    color: isAssigned
                        ? ColorUtils.corporateBlue600
                        : ColorUtils.slate500,
                    size: 22,
                  ),
                ),
                SizedBox(width: AppSpacing.md),

                // Informasi kelas
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classItem['name'] ?? 'Kelas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (classItem['tingkat'] != null)
                            buildClassInfoTag(
                              Icons.layers_outlined,
                              'Tingkat ${classItem['tingkat']}',
                            ),
                          if (classItem['wali_kelas_nama'] != null)
                            buildClassInfoTag(
                              Icons.person_outline,
                              classItem['wali_kelas_nama'],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: AppSpacing.sm),
                // Status indicator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAssigned
                        ? ColorUtils.success600.withValues(alpha: 0.1)
                        : ColorUtils.corporateBlue600.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAssigned
                          ? ColorUtils.success600.withValues(alpha: 0.3)
                          : ColorUtils.corporateBlue600.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAssigned
                            ? Icons.check_circle_outline
                            : Icons.add_circle_outline,
                        size: 14,
                        color: isAssigned
                            ? ColorUtils.success600
                            : ColorUtils.corporateBlue600,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        isAssigned ? 'Terdaftar' : 'Tambahkan',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAssigned
                              ? ColorUtils.success600
                              : ColorUtils.corporateBlue600,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  Widget buildClassInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClasses = getFilteredClasses();
    final assignedCount = assignedClasses0.length;

    // Terjemahan filter options
    final languageProvider = ref.read(languageRiverpod);
    final translatedFilterOptions = [
      languageProvider.getTranslatedText({'en': 'All', 'id': 'Semua'}),
      languageProvider.getTranslatedText({'en': 'Assigned', 'id': 'Terdaftar'}),
      languageProvider.getTranslatedText({
        'en': 'Unassigned',
        'id': 'Belum Terdaftar',
      }),
    ];

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject['name'] ?? widget.subject['nama'] ?? 'Subject',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Manajemen Kelas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        backgroundColor: ColorUtils.corporateBlue600,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? SkeletonListLoading(itemCount: 6, infoTagCount: 2)
          : Column(
              children: [
                // Quick stats
                Container(
                  margin: EdgeInsets.all(AppSpacing.lg),
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ColorUtils.corporateBlue600,
                        ColorUtils.corporateBlue600.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ColorUtils.corporateShadow(elevation: 2.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      buildStatItem(
                        icon: Icons.class_,
                        value: availableClasses.length.toString(),
                        label: 'Total Kelas',
                        color: Colors.white,
                      ),
                      buildStatItem(
                        icon: Icons.check_circle,
                        value: assignedCount.toString(),
                        label: 'Terdaftar',
                        color: Colors.white,
                      ),
                      buildStatItem(
                        icon: Icons.add_circle,
                        value: (availableClasses.length - assignedCount)
                            .toString(),
                        label: 'Belum Terdaftar',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),

                EnhancedSearchBar(
                  controller: searchController,
                  hintText: 'Cari classItem...',
                  onChanged: (value) {
                    setState(() {});
                  },
                  filterOptions: translatedFilterOptions,
                  selectedFilter:
                      translatedFilterOptions[selectedFilter == 'All'
                          ? 0
                          : selectedFilter == 'Assigned'
                          ? 1
                          : 2],
                  onFilterChanged: (filter) {
                    final index = translatedFilterOptions.indexOf(filter);
                    setState(() {
                      selectedFilter = index == 0
                          ? 'All'
                          : index == 1
                          ? 'Assigned'
                          : 'Unassigned';
                    });
                  },
                  showFilter: true,
                ),

                if (filteredClasses.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${filteredClasses.length} kelas ditemukan',
                          style: TextStyle(
                            color: ColorUtils.slate500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: AppSpacing.xs),

                Expanded(
                  child: filteredClasses.isEmpty
                      ? EmptyState(
                          title: 'Tidak ada kelas',
                          subtitle:
                              searchController.text.isEmpty &&
                                  selectedFilter == 'All'
                              ? 'Semua kelas sudah ditampilkan'
                              : 'Tidak ditemukan hasil pencarian',
                          icon: Icons.class_outlined,
                        )
                      : ListView.builder(
                          itemCount: filteredClasses.length,
                          itemBuilder: (context, index) {
                            final classItem = filteredClasses[index];
                            final isAssigned = isClassAssigned(classItem['id']);
                            return buildClassCard(classItem, index, isAssigned);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: ref.read(academicYearRiverpod).isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: showQuickAddClassDialog,
              backgroundColor: getPrimaryColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }

  Widget buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}
