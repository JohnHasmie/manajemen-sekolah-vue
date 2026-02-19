import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_settings_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';

class SchoolLevelSettingsScreen extends StatefulWidget {
  const SchoolLevelSettingsScreen({super.key});

  @override
  State<SchoolLevelSettingsScreen> createState() => _SchoolLevelSettingsScreenState();
}

class _SchoolLevelSettingsScreenState extends State<SchoolLevelSettingsScreen> {
  String _schoolName = '';
  String _schoolAddress = '';
  String _selectedJenjang = 'SMA';
  final List<String> _jenjangOptions = ['SD', 'SMP', 'SMA', 'SMK'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiSettingsService.getSchoolSettings();
      setState(() {
        _schoolName = settings['school_name'] ?? '';
        _schoolAddress = settings['address'] ?? '';
        _selectedJenjang = settings['jenjang'] ?? 'SMA';
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) print('Load settings error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat pengaturan: ${ErrorUtils.getFriendlyMessage(e)}'),
            backgroundColor: ColorUtils.error600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: _schoolName);
    final addressController = TextEditingController(text: _schoolAddress);
    String tempJenjang = _selectedJenjang;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Header (Pattern #10)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ColorUtils.corporateBlue600,
                        ColorUtils.corporateBlue600.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.school_rounded, color: Colors.white, size: 22),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Informasi Sekolah',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Perbarui data informasi sekolah',
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Form Fields
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStyledTextField(
                        controller: nameController,
                        label: 'Nama Sekolah',
                        icon: Icons.school_outlined,
                      ),
                      SizedBox(height: 12),
                      _buildStyledTextField(
                        controller: addressController,
                        label: 'Alamat Sekolah',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempJenjang,
                        decoration: InputDecoration(
                          labelText: 'Jenjang Sekolah',
                          prefixIcon: Icon(Icons.stairs_rounded, color: ColorUtils.corporateBlue600, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ColorUtils.slate200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
                          ),
                          filled: true,
                          fillColor: ColorUtils.slate50,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        items: _jenjangOptions
                            .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setDialogState(() => tempJenjang = value);
                        },
                      ),
                    ],
                  ),
                ),
                // Footer
                Container(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate100)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Batal', style: TextStyle(color: ColorUtils.slate600)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ApiSettingsService.updateSchoolSettings(
                                  schoolName: nameController.text,
                                  address: addressController.text,
                                  jenjang: tempJenjang,
                                );
                                if (mounted) {
                                  navigator.pop();
                                  _loadSettings();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Pengaturan berhasil disimpan'),
                                      backgroundColor: ColorUtils.success600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (kDebugMode) print('Update settings error: $e');
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal menyimpan: ${ErrorUtils.getFriendlyMessage(e)}'),
                                      backgroundColor: ColorUtils.error600,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              padding: EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.corporateBlue600.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: ColorUtils.corporateBlue600, size: 22),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: ColorUtils.slate500, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColorUtils.slate900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ColorUtils.corporateBlue600,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Pengaturan Umum',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorUtils.corporateBlue600,
                ColorUtils.corporateBlue600.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _showEditDialog,
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_rounded, color: Colors.white, size: 18),
              ),
              tooltip: 'Edit Informasi',
            ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: ColorUtils.corporateBlue600))
          : RefreshIndicator(
              onRefresh: _loadSettings,
              color: ColorUtils.corporateBlue600,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.info_outline_rounded, color: ColorUtils.corporateBlue600, size: 17),
                          ),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informasi Sekolah',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate800),
                              ),
                              Text(
                                'Kelola informasi dasar sekolah Anda.',
                                style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildInfoCard('Nama Sekolah', _schoolName, Icons.school_rounded),
                    SizedBox(height: 12),
                    _buildInfoCard('Alamat Sekolah', _schoolAddress, Icons.location_on_rounded),
                    SizedBox(height: 12),
                    _buildInfoCard('Jenjang Pendidikan', _selectedJenjang, Icons.stairs_rounded),
                  ],
                ),
              ),
            ),
    );
  }
}
