import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_settings_services.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};

  final Color primaryColor = Color(0xFF4361EE);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiSettingsService.getProfile();
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Load profile error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.read<LanguageProvider>().getTranslatedText(AppLocalizations.failedToLoadProfile)}: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _profileData['name']);
    final phoneController = TextEditingController(
      text: _profileData['phone_number'],
    );
    final addressController = TextEditingController(
      text: _profileData['address'],
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.read<LanguageProvider>().getTranslatedText(
            AppLocalizations.editProfile,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.read<LanguageProvider>().getTranslatedText(
                    AppLocalizations.fullName,
                  ),
                ),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: context.read<LanguageProvider>().getTranslatedText(
                    AppLocalizations.phoneNumber,
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: context.read<LanguageProvider>().getTranslatedText(
                    AppLocalizations.address,
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.read<LanguageProvider>().getTranslatedText(
                AppLocalizations.cancel,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiSettingsService.updateProfile(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  address: addressController.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  _loadProfile();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.read<LanguageProvider>().getTranslatedText(
                          AppLocalizations.profileUpdatedSuccess,
                        ),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (kDebugMode) print('Update profile error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${context.read<LanguageProvider>().getTranslatedText(AppLocalizations.failedToUpdateProfile)}: ${ErrorUtils.getFriendlyMessage(e)}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text(
              context.read<LanguageProvider>().getTranslatedText(
                AppLocalizations.save,
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(context: context, builder: (context) => _ChangePasswordDialog());
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
          context.watch<LanguageProvider>().getTranslatedText(
            AppLocalizations.userProfile,
          ),
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context
                                    .watch<LanguageProvider>()
                                    .getTranslatedText(
                                      AppLocalizations.personalInformation,
                                    ),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, color: primaryColor),
                                onPressed: _showEditProfileDialog,
                                tooltip: 'Edit Profil',
                              ),
                            ],
                          ),
                          Divider(),
                          SizedBox(height: 10),
                          _buildInfoRow(
                            context.read<LanguageProvider>().getTranslatedText(
                              AppLocalizations.fullName,
                            ),
                            _profileData['name'] ?? '',
                            Icons.person,
                          ),
                          _buildInfoRow(
                            'Email',
                            _profileData['email'] ?? '',
                            Icons.email,
                          ),
                          _buildInfoRow(
                            'No. Telepon',
                            _profileData['phone_number'] ?? '',
                            Icons.phone,
                          ),
                          _buildInfoRow(
                            'Alamat',
                            _profileData['address'] ?? '',
                            Icons.location_on,
                          ),
                          Divider(),
                          SizedBox(height: 10),
                          Text(
                            context.read<LanguageProvider>().getTranslatedText(
                              AppLocalizations.accountInformation,
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildInfoRow(
                            context.read<LanguageProvider>().getTranslatedText(
                              AppLocalizations.role,
                            ),
                            (_profileData['role'] != null &&
                                    _profileData['role'].isNotEmpty)
                                ? _profileData['role'][0].toUpperCase() +
                                      _profileData['role'].substring(1)
                                : '',
                            Icons.badge,
                          ),
                          _buildInfoRow(
                            context.read<LanguageProvider>().getTranslatedText(
                              AppLocalizations.school,
                            ),
                            _profileData['school_name'] ?? '',
                            Icons.school,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: Icon(Icons.lock_outline, color: Colors.white),
                      label: Text(
                        context.watch<LanguageProvider>().getTranslatedText(
                          AppLocalizations.changePassword,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  @override
  __ChangePasswordDialogState createState() => __ChangePasswordDialogState();
}

class __ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiSettingsService.updatePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText(
              AppLocalizations.passwordChangedSuccess,
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Update password error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.read<LanguageProvider>().getTranslatedText(AppLocalizations.failedToChangePassword)}: ${ErrorUtils.getFriendlyMessage(e)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.read<LanguageProvider>().getTranslatedText(
          AppLocalizations.changePassword,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPasswordField(
                controller: _oldPasswordController,
                label: context.read<LanguageProvider>().getTranslatedText(
                  AppLocalizations.oldPassword,
                ),
                obscure: _obscureOld,
                onToggle: () => setState(() => _obscureOld = !_obscureOld),
              ),
              SizedBox(height: 16),
              _buildPasswordField(
                controller: _newPasswordController,
                label: context.read<LanguageProvider>().getTranslatedText(
                  AppLocalizations.newPassword,
                ),
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: context.read<LanguageProvider>().getTranslatedText(
                  AppLocalizations.confirmPassword,
                ),
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (val) {
                  if (val != _newPasswordController.text)
                    return context.read<LanguageProvider>().getTranslatedText(
                      AppLocalizations.passwordMismatch,
                    );
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            context.read<LanguageProvider>().getTranslatedText(
              AppLocalizations.cancel,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updatePassword,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Text(
                  context.read<LanguageProvider>().getTranslatedText(
                    AppLocalizations.save,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator:
          validator ??
          (val) => val == null || val.isEmpty
              ? context.read<LanguageProvider>().getTranslatedText(
                  AppLocalizations.required,
                )
              : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
