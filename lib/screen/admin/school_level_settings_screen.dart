import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_settings_services.dart';

class SchoolLevelSettingsScreen extends StatefulWidget {
  const SchoolLevelSettingsScreen({super.key});

  @override
  State<SchoolLevelSettingsScreen> createState() =>
      _SchoolLevelSettingsScreenState();
}

class _SchoolLevelSettingsScreenState extends State<SchoolLevelSettingsScreen> {
  String _schoolName = '';
  String _schoolAddress = '';
  String _selectedJenjang = 'SMA';
  final List<String> _jenjangOptions = ['SD', 'SMP', 'SMA', 'SMK'];

  bool _isLoading = true;
  final Color primaryColor = Color(0xFF4361EE);

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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat pengaturan: $e')));
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
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Informasi Sekolah',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Sekolah',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Alamat Sekolah',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: tempJenjang,
                  decoration: InputDecoration(
                    labelText: 'Jenjang Sekolah',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _jenjangOptions.map((jenjang) {
                    return DropdownMenuItem(
                      value: jenjang,
                      child: Text(jenjang),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => tempJenjang = value);
                    }
                  },
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Batal'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ApiSettingsService.updateSchoolSettings(
                            schoolName: nameController.text,
                            address: addressController.text,
                            jenjang: tempJenjang,
                          );

                          if (mounted) {
                            Navigator.pop(context);
                            _loadSettings(); // Reload data
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pengaturan berhasil disimpan'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menyimpan: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Simpan',
                        style: TextStyle(color: Colors.white),
                      ),
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

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Pengaturan Umum',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _showEditDialog,
              icon: Icon(Icons.edit, color: primaryColor),
              tooltip: 'Edit Informasi',
            ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Sekolah',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Kelola informasi dasar sekolah Anda.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 24),
                    _buildInfoCard('Nama Sekolah', _schoolName, Icons.school),
                    SizedBox(height: 16),
                    _buildInfoCard(
                      'Alamat Sekolah',
                      _schoolAddress,
                      Icons.location_on,
                    ),
                    SizedBox(height: 16),
                    _buildInfoCard(
                      'Jenjang Pendidikan',
                      _selectedJenjang,
                      Icons.stairs,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
